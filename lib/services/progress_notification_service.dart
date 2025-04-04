import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_init;
import 'dart:io' show Platform;

class ProgressNotificationService {
  static final ProgressNotificationService _instance = ProgressNotificationService._internal();
  
  factory ProgressNotificationService() => _instance;
  
  ProgressNotificationService._internal();
  
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  
  
  static const String _studyChannelId = 'study_session_channel';
  static const String _studyChannelName = 'Study Sessions';
  static const String _studyChannelDescription = 'Notifications for study sessions';
  
  static const String _goalChannelId = 'study_goal_channel';
  static const String _goalChannelName = 'Study Goals';
  static const String _goalChannelDescription = 'Notifications for study goals and progress';
  
  
  static const String _prefSessionNotifications = 'study_session_notifications_enabled';
  static const String _prefGoalNotifications = 'study_goal_notifications_enabled';
  static const String _prefDailyReminder = 'daily_study_reminder_enabled';
  static const String _prefDailyReminderTime = 'daily_study_reminder_time';
  

  Future<void> initialize() async {
    if (_isInitialized) return;
    
   
    tz_init.initializeTimeZones();
    
   
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    await _createNotificationChannels();
    
   
    await _setupDailyReminder();
    
    _isInitialized = true;
  }
  
 
  void _onNotificationTapped(NotificationResponse response) {

    debugPrint('Notification tapped: ${response.payload}');
  }
  
 
  Future<void> _createNotificationChannels() async {
 
    await _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
          const AndroidNotificationChannel(
            _studyChannelId,
            _studyChannelName,
            description: _studyChannelDescription,
            importance: Importance.high,
          ),
        );
    
    await _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
          const AndroidNotificationChannel(
            _goalChannelId,
            _goalChannelName,
            description: _goalChannelDescription,
            importance: Importance.high,
          ),
        );
  }
  
  
  
  Future<void> notifySessionStart(String courseName, String courseCode) async {
    if (!await isSessionNotificationsEnabled()) return;
    
    await _localNotifications.show(
      1, 
      'Study Session Started',
      'You started studying $courseName ($courseCode). Good luck!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _studyChannelId,
          _studyChannelName,
          channelDescription: _studyChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: Colors.green,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'study_session_started',
    );
  }
  
  
  Future<void> notifySessionEnd(String courseName, int durationMinutes) async {
    if (!await isSessionNotificationsEnabled()) return;
    
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    
    String durationText = '';
    if (hours > 0) {
      durationText = '$hours hour${hours > 1 ? 's' : ''}';
      if (minutes > 0) {
        durationText += ' $minutes minute${minutes > 1 ? 's' : ''}';
      }
    } else {
      durationText = '$minutes minute${minutes > 1 ? 's' : ''}';
    }
    
    await _localNotifications.show(
      2,
      'Study Session Completed',
      'You studied $courseName for $durationText. Great job!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _studyChannelId,
          _studyChannelName,
          channelDescription: _studyChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: Colors.green,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'study_session_ended',
    );
  }
  
  
  Future<void> notifyStudyMilestone(String courseName, int totalHours) async {
    if (!await isGoalNotificationsEnabled()) return;
    
    await _localNotifications.show(
      3, 
      'Study Milestone Reached!',
      'You\'ve studied $courseName for $totalHours hours in total. Keep it up!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _goalChannelId,
          _goalChannelName,
          channelDescription: _goalChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: Colors.purple,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'study_milestone',
    );
  }
  
  
  Future<void> notifyProgressMilestone(String courseName, int progressPercent) async {
    if (!await isGoalNotificationsEnabled()) return;
    
    await _localNotifications.show(
      4,
      'Course Progress Update',
      'Your progress in $courseName has reached $progressPercent%. Excellent work!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _goalChannelId,
          _goalChannelName,
          channelDescription: _goalChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: Colors.blue,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'progress_milestone',
    );
  }
  
  
  Future<bool> scheduleDailyReminder(TimeOfDay time) async {
    try {
      
      await _localNotifications.cancel(5);
      
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefDailyReminderTime, '${time.hour}:${time.minute}');
      
     
      final now = DateTime.now();
      final scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      
     
      final finalDate = scheduledDate.isBefore(now) 
          ? scheduledDate.add(const Duration(days: 1)) 
          : scheduledDate;
      
     
      try {
        
        await _localNotifications.zonedSchedule(
          5,
          'Time to Study',
          'Don\'t forget to make some progress on your courses today!',
          tz.TZDateTime.from(finalDate, tz.local),
          NotificationDetails(
            android: AndroidNotificationDetails(
              _goalChannelId,
              _goalChannelName,
              channelDescription: _goalChannelDescription,
              importance: Importance.high,
              priority: Priority.high,
              color: Colors.orange,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'daily_reminder',
        );
        return true;
      } catch (e) {
        debugPrint('Failed to schedule exact alarm: $e');
        
       
        if (e.toString().contains('exact_alarms_not_permitted')) {
          await _scheduleInexactReminder(time);
          return false;
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error scheduling daily reminder: $e');
      return false;
    }
  }
  
  
  Future<void> _scheduleInexactReminder(TimeOfDay time) async {
    try {
      
      await _localNotifications.periodicallyShow(
        5, 
        'Time to Study',
        'Remember to study your courses today!',
        RepeatInterval.daily,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _goalChannelId,
            _goalChannelName,
            channelDescription: _goalChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: Colors.orange,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'daily_reminder',
      );
      debugPrint('Scheduled inexact daily reminder as fallback');
      
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('using_inexact_reminders', true);
    } catch (e) {
      debugPrint('Error scheduling inexact reminder: $e');
    }
  }
  
 
  Future<void> _setupDailyReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_prefDailyReminder) ?? false;
      
      if (isEnabled) {
        final timeStr = prefs.getString(_prefDailyReminderTime) ?? '20:00';
        final parts = timeStr.split(':');
        
        try {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          
          await scheduleDailyReminder(TimeOfDay(hour: hour, minute: minute));
        } catch (e) {
          debugPrint('Invalid reminder time format: $e');
         
          await scheduleDailyReminder(const TimeOfDay(hour: 20, minute: 0));
        }
      }
    } catch (e) {
      debugPrint('Error setting up daily reminder: $e');
    }
  }
  
 
  Future<void> notifyDailySummary(int totalMinutesToday, List<String> coursesStudied) async {
    if (!await isGoalNotificationsEnabled()) return;
    
    final hours = totalMinutesToday ~/ 60;
    final minutes = totalMinutesToday % 60;
    
    String timeText = '';
    if (hours > 0) {
      timeText = '$hours hour${hours > 1 ? 's' : ''}';
      if (minutes > 0) {
        timeText += ' and $minutes minute${minutes > 1 ? 's' : ''}';
      }
    } else {
      timeText = '$minutes minute${minutes > 1 ? 's' : ''}';
    }
    
    String coursesText = coursesStudied.isEmpty 
        ? 'no courses' 
        : coursesStudied.length == 1 
          ? coursesStudied[0] 
          : '${coursesStudied.length} courses';
    
    await _localNotifications.show(
      6, 
      'Daily Study Summary',
      'Today you studied for $timeText across $coursesText. ${_getEncouragementMessage(totalMinutesToday)}',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _goalChannelId,
          _goalChannelName,
          channelDescription: _goalChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(
            'Today you studied for $timeText across $coursesText. ${_getEncouragementMessage(totalMinutesToday)}',
          ),
          color: Colors.teal,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'daily_summary',
    );
  }
  
  
  String _getEncouragementMessage(int totalMinutesToday) {
    if (totalMinutesToday == 0) {
      return 'Try to find some time to study tomorrow!';
    } else if (totalMinutesToday < 30) {
      return 'Every little bit helps. Try to study more tomorrow!';
    } else if (totalMinutesToday < 60) {
      return 'Nice start! Keep building your study habits.';
    } else if (totalMinutesToday < 120) {
      return 'Good job today! You\'re making progress.';
    } else if (totalMinutesToday < 180) {
      return 'Excellent study session today! Keep it up!';
    } else {
      return 'Wow! Outstanding dedication today. You\'re on your way to success!';
    }
  }
  

  
  Future<bool> isSessionNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefSessionNotifications) ?? true; 
  }
  
  Future<void> setSessionNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSessionNotifications, enabled);
  }
  

  Future<bool> isGoalNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefGoalNotifications) ?? true; 
  }
  
  Future<void> setGoalNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefGoalNotifications, enabled);
  }
  
 
  Future<bool> isDailyReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefDailyReminder) ?? false; 
  }
  
  Future<void> setDailyReminderEnabled(bool enabled, {TimeOfDay? time}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDailyReminder, enabled);
    
    if (enabled) {
      if (time != null) {
        await scheduleDailyReminder(time);
      } else {
        
        final timeStr = prefs.getString(_prefDailyReminderTime) ?? '20:00';
        final parts = timeStr.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        
        await scheduleDailyReminder(TimeOfDay(hour: hour, minute: minute));
      }
    } else {
     
      await _localNotifications.cancel(5);
    }
  }
  
 
  Future<TimeOfDay> getDailyReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_prefDailyReminderTime) ?? '20:00';
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    
    return TimeOfDay(hour: hour, minute: minute);
  }
}
