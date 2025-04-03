import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

import 'notification_service.dart';

class TodoNotificationService {
  static final TodoNotificationService _instance = TodoNotificationService._internal();
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final Map<String, Timer> _scheduledNotifications = {};
  
  factory TodoNotificationService() {
    return _instance;
  }
  
  TodoNotificationService._internal();
  
  Future<void> initialize() async {
    await _notificationService.initialize();
    
    if (await _notificationService.isTodoNotificationsEnabled()) {
      _startListeningForTodos();
    }
  }
  
  void _startListeningForTodos() {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final todosRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos');
    
    todosRef
        .where('completed', isEqualTo: false)
        .where('dueDate', isGreaterThan: Timestamp.now())
        .snapshots()
        .listen((snapshot) {
          _handleTodoUpdates(snapshot.docs);
        }, onError: (error) {
          debugPrint('Error listening to todos: $error');
        });
  }
  
  void _handleTodoUpdates(List<QueryDocumentSnapshot> todos) {
    final now = DateTime.now();
    
    final currentIds = todos.map((doc) => doc.id).toSet();
    _scheduledNotifications.keys
        .where((id) => !currentIds.contains(id))
        .toList()
        .forEach(_cancelNotification);
    
    for (final todo in todos) {
      final data = todo.data() as Map<String, dynamic>;
      final todoId = todo.id;
      
      if (data['dueDate'] == null) continue;
      
      final dueDate = (data['dueDate'] as Timestamp).toDate();
      final title = data['title'] as String;
      final priority = data['priority'] as int? ?? 0;
      
      if (dueDate.isAfter(now)) {
        _scheduleTodoNotifications(
          todoId: todoId,
          title: title,
          dueDate: dueDate,
          priority: priority,
        );
      }
    }
  }
  
  Future<void> _scheduleTodoNotifications({
    required String todoId,
    required String title,
    required DateTime dueDate,
    required int priority,
  }) async {
    _cancelNotification(todoId);
    
    final now = DateTime.now();
    
    final dueDateTime = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9, 0, 0
    );
    
    final oneDayBefore = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day - 1,
      9, 0, 0
    );
    
    final twoDaysBefore = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day - 2,
      9, 0, 0
    );
    
    final oneWeekBefore = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day - 7,
      9, 0, 0
    );
    
    if (dueDateTime.isAfter(now)) {
      _scheduleNotification(
        todoId: todoId,
        title: title,
        dueDate: dueDate,
        priority: priority,
        delay: dueDateTime.difference(now),
        reminderType: 'due_date',
      );
    }
    
    if (oneDayBefore.isAfter(now)) {
      _scheduleNotification(
        todoId: todoId,
        title: title,
        dueDate: dueDate,
        priority: priority,
        delay: oneDayBefore.difference(now),
        reminderType: 'one_day',
      );
    }
    
    if (twoDaysBefore.isAfter(now)) {
      _scheduleNotification(
        todoId: todoId,
        title: title,
        dueDate: dueDate,
        priority: priority,
        delay: twoDaysBefore.difference(now),
        reminderType: 'two_days',
      );
    }
    
    if (oneWeekBefore.isAfter(now)) {
      _scheduleNotification(
        todoId: todoId,
        title: title,
        dueDate: dueDate,
        priority: priority,
        delay: oneWeekBefore.difference(now),
        reminderType: 'one_week',
      );
    }
  }
  
  void _scheduleNotification({
    required String todoId,
    required String title,
    required DateTime dueDate,
    required int priority,
    required Duration delay,
    required String reminderType,
  }) {
    final timerId = '${todoId}_$reminderType';
    
    if (_scheduledNotifications.containsKey(timerId)) {
      _scheduledNotifications[timerId]?.cancel();
      _scheduledNotifications.remove(timerId);
    }
    
    final timer = Timer(delay, () {
      _notificationService.sendTodoNotification(
        todoId: todoId,
        title: title,
        dueDate: dueDate,
        priority: priority,
        reminderType: reminderType,
      );
      
      _scheduledNotifications.remove(timerId);
    });
    
    _scheduledNotifications[timerId] = timer;
    
    debugPrint('Scheduled $reminderType notification for "$title" in ${delay.inMinutes} minutes');
  }
  
  void _cancelNotification(String todoId) {
    final timersToRemove = _scheduledNotifications.keys
        .where((key) => key.startsWith('${todoId}_'))
        .toList();
        
    for (final timerId in timersToRemove) {
      _scheduledNotifications[timerId]?.cancel();
      _scheduledNotifications.remove(timerId);
    }
  }
  
  Future<void> testTodoNotification({
    required String todoId,
    required String title,
    required DateTime dueDate,
    required int priority,
    String reminderType = 'due_date',
  }) async {
    await _notificationService.sendTodoNotification(
      todoId: todoId,
      title: title,
      dueDate: dueDate,
      priority: priority,
      reminderType: reminderType,
    );
  }
  
  Future<void> onNotificationSettingsChanged() async {
    if (await _notificationService.isTodoNotificationsEnabled()) {
      _startListeningForTodos();
    } else {
      for (final timer in _scheduledNotifications.values) {
        timer.cancel();
      }
      _scheduledNotifications.clear();
    }
  }
  
  Future<void> scheduleAllTodoNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    if (!(await _notificationService.isTodoNotificationsEnabled())) {
      return;
    }
    
    final todosRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('todos');
    
    try {
      final snapshot = await todosRef
          .where('completed', isEqualTo: false)
          .where('dueDate', isGreaterThan: Timestamp.now())
          .get();
          
      _handleTodoUpdates(snapshot.docs);
    } catch (e) {
      debugPrint('Error fetching todos for notification scheduling: $e');
    }
  }
}
