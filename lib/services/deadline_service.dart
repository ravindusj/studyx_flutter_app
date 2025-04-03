import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/deadline.dart';

class DeadlineService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  
  List<Deadline> _deadlines = [];
  List<Deadline> _todaysDeadlines = [];
  List<Deadline> _upcomingDeadlines = [];
  bool _isLoading = false;
  Timer? _refreshTimer;


  List<Deadline> get deadlines => _deadlines;
  List<Deadline> get todaysDeadlines => _todaysDeadlines;
  List<Deadline> get upcomingDeadlines => _upcomingDeadlines;
  bool get isLoading => _isLoading;

  DeadlineService() {
 
    _init();
    
  
    _refreshTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      refreshDeadlines();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }


  Future<void> _init() async {
    await loadDeadlines();
    scheduleReminders();
  }

  
  Future<void> loadDeadlines() async {
    final user = _auth.currentUser;
    if (user == null) {
      _deadlines = [];
      _todaysDeadlines = [];
      _upcomingDeadlines = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('deadlines')
          .where('userId', isEqualTo: user.uid)
          .get();

      _deadlines = snapshot.docs.map((doc) => Deadline.fromFirestore(doc)).toList();
      
     
      _deadlines.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      
      
      _updateTodaysDeadlines();
      
      
      _updateUpcomingDeadlines();
      
      
      _updateDeadlineStatuses();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading deadlines: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  
  Future<Deadline?> addDeadline(Deadline deadline) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final docRef = await _firestore.collection('deadlines').add(deadline.toMap());
      
     
      final newDeadline = deadline.copyWith(id: docRef.id);
      
     
      _deadlines.add(newDeadline);
      
     
      _updateTodaysDeadlines();
      _updateUpcomingDeadlines();
      
     
      _scheduleRemindersForDeadline(newDeadline);
      
      notifyListeners();
      return newDeadline;
    } catch (e) {
      debugPrint('Error adding deadline: $e');
      return null;
    }
  }

  
  Future<bool> updateDeadline(Deadline deadline) async {
    try {
      await _firestore.collection('deadlines').doc(deadline.id).update(deadline.toMap());
      
     
      final index = _deadlines.indexWhere((d) => d.id == deadline.id);
      if (index >= 0) {
        _deadlines[index] = deadline;
        
        
        _updateTodaysDeadlines();
        _updateUpcomingDeadlines();
        
       
        _cancelRemindersForDeadline(deadline.id);
        _scheduleRemindersForDeadline(deadline);
        
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Error updating deadline: $e');
      return false;
    }
  }

  
  Future<bool> deleteDeadline(String id) async {
    try {
      await _firestore.collection('deadlines').doc(id).delete();
      
      
      _deadlines.removeWhere((d) => d.id == id);
      
      
      _updateTodaysDeadlines();
      _updateUpcomingDeadlines();
      
     
      _cancelRemindersForDeadline(id);
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting deadline: $e');
      return false;
    }
  }

 
  Future<bool> markAsCompleted(String id) async {
    try {
      final index = _deadlines.indexWhere((d) => d.id == id);
      if (index >= 0) {
        final deadline = _deadlines[index];
        final updatedDeadline = deadline.copyWith(
          status: DeadlineStatus.completed,
          completedAt: DateTime.now(),
        );
        
        await _firestore.collection('deadlines').doc(id).update(updatedDeadline.toMap());
        
       
        _deadlines[index] = updatedDeadline;
        
        
        _updateTodaysDeadlines();
        _updateUpcomingDeadlines();
        
       
        _cancelRemindersForDeadline(id);
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error marking deadline as completed: $e');
      return false;
    }
  }

  
  Future<bool> markAsInProgress(String id) async {
    try {
      final index = _deadlines.indexWhere((d) => d.id == id);
      if (index >= 0) {
        final deadline = _deadlines[index];
        final updatedDeadline = deadline.copyWith(
          status: DeadlineStatus.inProgress,
        );
        
        await _firestore.collection('deadlines').doc(id).update(updatedDeadline.toMap());
        
       
        _deadlines[index] = updatedDeadline;
        
        
        _updateTodaysDeadlines();
        _updateUpcomingDeadlines();
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error marking deadline as in progress: $e');
      return false;
    }
  }

  
  Future<void> refreshDeadlines() async {
    
    _updateDeadlineStatuses();
    
    
    await loadDeadlines();
  }

 
  List<Deadline> getDeadlinesByPriority(DeadlinePriority priority) {
    return _deadlines.where((d) => d.priority == priority).toList();
  }

  
  List<Deadline> getDeadlinesDueWithin({required Duration duration}) {
    final now = DateTime.now();
    final endTime = now.add(duration);
    
    return _deadlines.where((d) => 
      d.dueDate.isAfter(now) && 
      d.dueDate.isBefore(endTime) &&
      d.status != DeadlineStatus.completed
    ).toList();
  }

  
  List<Deadline> getOverdueDeadlines() {
    final now = DateTime.now();
    
    return _deadlines.where((d) => 
      d.dueDate.isBefore(now) && 
      d.status != DeadlineStatus.completed
    ).toList();
  }

  
  void _updateTodaysDeadlines() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    _todaysDeadlines = _deadlines.where((d) => 
      d.dueDate.isAfter(today) && 
      d.dueDate.isBefore(tomorrow)
    ).toList();
  }

 
  void _updateUpcomingDeadlines() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));
    
    _upcomingDeadlines = _deadlines.where((d) => 
      d.dueDate.isAfter(tomorrow) && 
      d.dueDate.isBefore(nextWeek) &&
      d.status != DeadlineStatus.completed
    ).toList();
  }

  
  void _updateDeadlineStatuses() {
    bool hasChanges = false;
    final now = DateTime.now();
    
    for (int i = 0; i < _deadlines.length; i++) {
      final deadline = _deadlines[i];
      
      
      if (deadline.status == DeadlineStatus.completed) continue;
      
      
      if (deadline.dueDate.isBefore(now) && deadline.status != DeadlineStatus.overdue) {
        
        _deadlines[i] = deadline.copyWith(status: DeadlineStatus.overdue);
        
        
        _firestore.collection('deadlines').doc(deadline.id).update({
          'status': DeadlineStatus.overdue.index,
        });
        
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      notifyListeners();
    }
  }

 
  List<Deadline> getRecommendedTasksForToday() {
 
    
    final List<Deadline> recommended = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    
    final overdueTasks = getOverdueDeadlines();
    if (overdueTasks.isNotEmpty) {
      overdueTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      recommended.addAll(overdueTasks.take(3));
    }
    
    
    final todaysCritical = _todaysDeadlines.where((d) => 
      d.priority == DeadlinePriority.critical && 
      d.status != DeadlineStatus.completed
    ).toList();
    recommended.addAll(todaysCritical);
    
    final todaysHigh = _todaysDeadlines.where((d) => 
      d.priority == DeadlinePriority.high && 
      d.status != DeadlineStatus.completed
    ).toList();
    recommended.addAll(todaysHigh);
    
    
    final todaysMedium = _todaysDeadlines.where((d) => 
      d.priority == DeadlinePriority.medium && 
      d.status != DeadlineStatus.completed
    ).toList();
    recommended.addAll(todaysMedium);
    
    
    final dayAfterTomorrow = tomorrow.add(const Duration(days: 1));
    final inProgressSoon = _deadlines.where((d) => 
      d.status == DeadlineStatus.inProgress &&
      d.dueDate.isAfter(today) &&
      d.dueDate.isBefore(dayAfterTomorrow)
    ).toList();
    recommended.addAll(inProgressSoon);
    
    
    return recommended.toSet().toList();
  }


  void scheduleReminders() {
    for (final deadline in _deadlines) {
      if (deadline.hasReminder && 
          deadline.status != DeadlineStatus.completed) {
        _scheduleRemindersForDeadline(deadline);
      }
    }
  }

  
  void _scheduleRemindersForDeadline(Deadline deadline) {
    if (!deadline.hasReminder || deadline.status == DeadlineStatus.completed) {
      return;
    }
    
    final now = DateTime.now();
    
   
    if (deadline.isOverdue) {
      return;
    }
    
  
    if (deadline.reminderTimes.isEmpty) {
     
      final List<DateTime> reminderTimes = [];
      
    
      final oneDayBefore = deadline.dueDate.subtract(const Duration(days: 1));
      if (oneDayBefore.isAfter(now)) {
        reminderTimes.add(oneDayBefore);
      }
      
    
      final oneHourBefore = deadline.dueDate.subtract(const Duration(hours: 1));
      if (oneHourBefore.isAfter(now)) {
        reminderTimes.add(oneHourBefore);
      }
      
     
      _firestore.collection('deadlines').doc(deadline.id).update({
        'reminderTimes': reminderTimes.map((dt) => Timestamp.fromDate(dt)).toList(),
      });
      
  
      _scheduleNotificationsForDeadline(deadline, reminderTimes);
    } else {
   
      final validReminderTimes = deadline.reminderTimes.where((dt) => dt.isAfter(now)).toList();
      _scheduleNotificationsForDeadline(deadline, validReminderTimes);
    }
  }


  void _scheduleNotificationsForDeadline(Deadline deadline, List<DateTime> reminderTimes) {
    for (final reminderTime in reminderTimes) {
      final String title;
      final String body;
      
     
      final daysUntilDue = deadline.dueDate.difference(reminderTime).inDays;
      
      if (daysUntilDue == 0) {
       
        final hoursUntilDue = deadline.dueDate.difference(reminderTime).inHours;
        title = 'Deadline Due Soon: ${deadline.title}';
        body = 'Task due in $hoursUntilDue ${hoursUntilDue == 1 ? 'hour' : 'hours'}.';
      } else if (daysUntilDue == 1) {
       
        title = 'Deadline Tomorrow: ${deadline.title}';
        body = 'Don\'t forget your task due tomorrow!';
      } else {
       
        title = 'Upcoming Deadline: ${deadline.title}';
        body = 'Task due in $daysUntilDue days.';
      }
      
     
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'deadline_reminders',
          'Deadline Reminders',
          channelDescription: 'Notifications for deadline reminders',
          importance: Importance.high,
          priority: Priority.high,
          color: deadline.priority.color,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      
    
      _notificationService.scheduleNotification(
        id: int.parse('${deadline.id.hashCode}${reminderTime.millisecondsSinceEpoch % 10000}'.substring(0, 9)), 
        title: title,
        body: body,
        scheduledDate: reminderTime,
        notificationDetails: notificationDetails,
        payload: 'deadline:${deadline.id}',
      );
    }
  }

 
  void _cancelRemindersForDeadline(String deadlineId) {
    
    final baseId = deadlineId.hashCode;
    
    
    for (int i = 0; i < 10; i++) {
      final notificationId = int.parse('$baseId$i'.substring(0, 9));
      _notificationService.cancelNotification(notificationId);
    }
  }

  
  Future<void> scheduleImmediateReminderForTesting(Deadline deadline) async {
    final now = DateTime.now();
    final timeUntilDeadline = deadline.dueDate.difference(now);
    
    
    String timeMessage;
    if (timeUntilDeadline.inHours <= 0) {
      timeMessage = 'in ${timeUntilDeadline.inMinutes} minutes';
    } else if (timeUntilDeadline.inHours < 24) {
      timeMessage = 'in ${timeUntilDeadline.inHours} hours';
    } else {
      timeMessage = 'in ${timeUntilDeadline.inDays} days';
    }
    
   
    String notificationTitle;
    String notificationBody;
    
    switch (deadline.priority) {
      case DeadlinePriority.high:
        notificationTitle = '⚠️ Urgent Deadline Approaching!';
        notificationBody = '${deadline.title} is due $timeMessage. This is a high priority task!';
        break;
      case DeadlinePriority.medium:
        notificationTitle = '⏰ Deadline Reminder';
        notificationBody = '${deadline.title} is due $timeMessage.';
        break;
      case DeadlinePriority.low:
        notificationTitle = '📝 Low Priority Deadline';
        notificationBody = 'Reminder: ${deadline.title} is due $timeMessage.';
        break;
      case DeadlinePriority.critical:
     
        throw UnimplementedError();
    }
    
    await _notificationService.showNotification(
      id: deadline.hashCode,
      title: notificationTitle,
      body: notificationBody,
      payload: 'deadline_${deadline.id}',
    );
  }
}
