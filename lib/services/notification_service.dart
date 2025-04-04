import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  static const String canteenChannelId = 'canteen_notifications';
  static const String canteenChannelName = 'Canteen Notifications';
  static const String canteenChannelDescription = 'Notifications about canteen availability';
  
  static const String todoChannelId = 'todo_notifications';
  static const String todoChannelName = 'Todo Notifications';
  static const String todoChannelDescription = 'Reminders about your upcoming tasks';
  
  static const String prefCanteenNotificationsEnabled = 'canteen_notifications_enabled';
  static const String prefCanteenThreshold = 'canteen_threshold';
  
  static const String prefTodoNotificationsEnabled = 'todo_notifications_enabled';
  static const String prefTodoReminderTime = 'todo_reminder_time';
  static const String prefTodoDayBeforeEnabled = 'todo_day_before_enabled';
  static const String prefTodoReminderOptions = 'todo_reminder_options';
  
  static const int defaultThreshold = 30;
  
  static const int defaultReminderHours = 2;
  
  static const List<String> predefinedReminderTimes = [
    'due_date',
    'one_day',
    'two_days',
    'one_week',
  ];
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      tz.initializeTimeZones();
      
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
      
      try {
        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (NotificationResponse details) {
            debugPrint('Notification clicked: ${details.payload}');
            _handleNotificationClick(details.payload);
          },
        );
      } catch (e) {
        debugPrint('Error initializing local notifications: $e');
      }
      
      try {
        const AndroidNotificationChannel canteenChannel = AndroidNotificationChannel(
          canteenChannelId,
          canteenChannelName,
          description: canteenChannelDescription,
          importance: Importance.high,
        );
        
        const AndroidNotificationChannel todoChannel = AndroidNotificationChannel(
          todoChannelId,
          todoChannelName,
          description: todoChannelDescription,
          importance: Importance.high,
        );
        
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
            
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(canteenChannel);
          await androidPlugin.createNotificationChannel(todoChannel);
        }
      } catch (e) {
        debugPrint('Error creating notification channels: $e');
      }
      
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleForegroundMessage(message);
      });
      
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleBackgroundMessageOpen(message);
      });
      
      _initialized = true;
      debugPrint('Notification service initialized with permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('Error in notification service initialization: $e');
      _initialized = true;
    }
  }
  
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Handling foreground message: ${message.notification?.title}');
    
    if (message.notification != null) {
      final String channelId = _getChannelIdFromMessage(message);
      final String channelName = _getChannelNameFromMessage(message);
      final String channelDescription = _getChannelDescriptionFromMessage(message);
      
      _localNotifications.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            icon: '@mipmap/ic_launcher',
            color: _getColorFromMessage(message),
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }
  
  void _handleBackgroundMessageOpen(RemoteMessage message) {
    debugPrint('Notification clicked from background: ${message.notification?.title}');
    _handleNotificationClick(jsonEncode(message.data));
  }
  
  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final String? type = data['type'];
      
      if (type == 'canteen_update') {
        debugPrint('Canteen notification clicked: ${data['canteenId']}');
      } else if (type == 'todo_reminder') {
        debugPrint('Todo notification clicked: ${data['todoId']}');
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
  }
  
  String _getChannelIdFromMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'todo_reminder') {
      return todoChannelId;
    }
    return canteenChannelId;
  }
  
  String _getChannelNameFromMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'todo_reminder') {
      return todoChannelName;
    }
    return canteenChannelName;
  }
  
  String _getChannelDescriptionFromMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'todo_reminder') {
      return todoChannelDescription;
    }
    return canteenChannelDescription;
  }
  
  Color _getColorFromMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'todo_reminder') {
      final priority = int.tryParse(message.data['priority'] ?? '0') ?? 0;
      return _getTodoPriorityColor(priority);
    }
    
    final availability = double.tryParse(message.data['availability'] ?? '50') ?? 50;
    return _getStatusColor(availability);
  }
  
  Future<void> sendCanteenNotification({
    required String canteenId,
    required String canteenName,
    required double availability,
  }) async {
    if (!await isCanteenNotificationsEnabled()) return;
    
    final threshold = await getCanteenThreshold();
    if (availability > threshold) return;
    
    final String status = _getStatusText(availability);
    
    await _localNotifications.show(
      canteenId.hashCode,
      'Canteen Update: $canteenName',
      '$canteenName is now $status (${availability.round()}% available)',
      NotificationDetails(
        android: AndroidNotificationDetails(
          canteenChannelId,
          canteenChannelName,
          channelDescription: canteenChannelDescription,
          icon: '@mipmap/ic_launcher',
          color: _getStatusColor(availability),
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode({
        'type': 'canteen_update',
        'canteenId': canteenId,
        'availability': availability,
      }),
    );
    
    debugPrint('Sent notification for $canteenName (${availability.round()}% available)');
  }
  
  Future<void> sendTodoNotification({
    required String todoId,
    required String title,
    required DateTime dueDate,
    required int priority,
    String? reminderType,
  }) async {
    if (!await isTodoNotificationsEnabled()) return;
    
    String message;
    switch (reminderType) {
      case 'one_day':
        message = 'Due tomorrow: $title';
        break;
      case 'two_days':
        message = 'Due in 2 days: $title';
        break;
      case 'one_week':
        message = 'Due in a week: $title';
        break;
      case 'due_date':
        message = 'Due today: $title';
        break;
      default:
        message = 'Reminder: $title';
    }
    
    final notificationId = todoId.hashCode + (reminderType?.hashCode ?? 0);
    
    await _localNotifications.show(
      notificationId,
      'Task Reminder',
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          todoChannelId,
          todoChannelName,
          channelDescription: todoChannelDescription,
          icon: '@mipmap/ic_launcher',
          color: _getTodoPriorityColor(priority),
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode({
        'type': 'todo_reminder',
        'todoId': todoId,
        'priority': priority,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'reminderType': reminderType,
      }),
    );
    
    debugPrint('Sent todo reminder notification for: $title (${reminderType ?? "unknown"})');
  }
  
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    try {
      if (scheduledDate.isBefore(DateTime.now())) {
        debugPrint('Cannot schedule notification in the past: $scheduledDate');
        return;
      }
      
      final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);
      
      final details = notificationDetails ?? NotificationDetails(
        android: const AndroidNotificationDetails(
          'scheduled_notifications',
          'Scheduled Notifications',
          channelDescription: 'Notifications scheduled for future delivery',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: 
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      
      debugPrint('Scheduled notification "$title" for ${scheduledDate.toString()}');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }
  
  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
      debugPrint('Cancelled notification with ID: $id');
    } catch (e) {
      debugPrint('Error cancelling notification: $e');
    }
  }
  
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('Cancelled all pending notifications');
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }
  
  Future<bool> isCanteenNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefCanteenNotificationsEnabled) ?? false;
  }
  
  Future<void> setCanteenNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefCanteenNotificationsEnabled, enabled);
      
      try {
        if (enabled) {
          await _messaging.subscribeToTopic('canteen_updates');
        } else {
          await _messaging.unsubscribeFromTopic('canteen_updates');
        }
      } catch (e) {
        debugPrint('FCM topic subscription error: $e');
      }
    } catch (e) {
      debugPrint('Error setting notification preferences: $e');
    }
  }
  
  Future<int> getCanteenThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefCanteenThreshold) ?? defaultThreshold;
  }
  
  Future<void> setCanteenThreshold(int threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefCanteenThreshold, threshold);
  }
  
  Future<bool> isTodoNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefTodoNotificationsEnabled) ?? false;
  }
  
  Future<void> setTodoNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefTodoNotificationsEnabled, enabled);
      
      try {
        if (enabled) {
          await _messaging.subscribeToTopic('todo_reminders');
        } else {
          await _messaging.unsubscribeFromTopic('todo_reminders');
        }
      } catch (e) {
        debugPrint('FCM topic subscription error: $e');
      }
    } catch (e) {
      debugPrint('Error setting todo notification preferences: $e');
    }
  }
  
  Future<int> getReminderHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefTodoReminderTime) ?? defaultReminderHours;
  }
  
  Future<void> setReminderHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefTodoReminderTime, hours);
  }
  
  Future<bool> isDayBeforeReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefTodoDayBeforeEnabled) ?? true;
  }
  
  Future<void> setDayBeforeReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefTodoDayBeforeEnabled, enabled);
  }
  
  String _getStatusText(double availability) {
    if (availability <= 30) {
      return 'crowded';
    } else if (availability <= 70) {
      return 'moderately busy';
    } else {
      return 'available';
    }
  }
  
  Color _getStatusColor(double availability) {
    if (availability <= 30) {
      return Colors.red;
    } else if (availability <= 70) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
  
  Color _getTodoPriorityColor(int priority) {
    switch (priority) {
      case 2:
        return Colors.red;
      case 1:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
  
  Future<String?> getDeviceToken() async {
    return await _messaging.getToken();
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'general_notifications',
            'General Notifications',
            channelDescription: 'General application notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
      debugPrint('Showed notification: "$title"');
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
}
