import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/notification_service.dart';
import 'services/todo_notification_service.dart';

class TodoNotificationTestPage extends StatefulWidget {
  const TodoNotificationTestPage({Key? key}) : super(key: key);

  @override
  State<TodoNotificationTestPage> createState() => _TodoNotificationTestPageState();
}

class _TodoNotificationTestPageState extends State<TodoNotificationTestPage> {
  final NotificationService _notificationService = NotificationService();
  final TodoNotificationService _todoNotificationService = TodoNotificationService();
  
  bool _todoNotificationsEnabled = false;
  bool _isLoading = true;
  
  final List<Map<String, dynamic>> _todoTestScenarios = [
    {
      'name': 'Test Due Date Reminder',
      'description': 'Notification for the day of the deadline',
      'icon': Icons.event_available,
      'iconColor': Colors.green,
      'priority': 0,
      'reminderType': 'due_date',
    },
    {
      'name': 'Test 1 Day Before',
      'description': 'Notification for 1 day before deadline',
      'icon': Icons.today,
      'iconColor': Colors.blue,
      'priority': 1,
      'reminderType': 'one_day',
    },
    {
      'name': 'Test 2 Days Before',
      'description': 'Notification for 2 days before deadline',
      'icon': Icons.date_range,
      'iconColor': Colors.purple,
      'priority': 1,
      'reminderType': 'two_days',
    },
    {
      'name': 'Test 1 Week Before',
      'description': 'Notification for 1 week before deadline',
      'icon': Icons.calendar_month,
      'iconColor': Colors.orange,
      'priority': 2,
      'reminderType': 'one_week',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() => _isLoading = true);
    
    try {
      await _notificationService.initialize();
      await _todoNotificationService.initialize();
      
      final todoNotificationsEnabled = await _notificationService.isTodoNotificationsEnabled();
      
      if (mounted) {
        setState(() {
          _todoNotificationsEnabled = todoNotificationsEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _toggleTodoNotifications(bool value) async {
    await _notificationService.setTodoNotificationsEnabled(value);
    await _todoNotificationService.onNotificationSettingsChanged();
    if (mounted) {
      setState(() => _todoNotificationsEnabled = value);
    }
  }
  
  Future<void> _runTodoTest(Map<String, dynamic> scenario) async {
    if (!_todoNotificationsEnabled) {
      _showNotificationDisabledDialog(
        'todo',
        () => _toggleTodoNotifications(true),
      );
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need to be logged in to test notifications'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final loadingOverlay = _showLoadingOverlay();
    
    try {
      final String todoId = 'test-todo-${DateTime.now().millisecondsSinceEpoch}';
      final String title = 'Test Task ${scenario['priority'] == 2 ? '(High)' : scenario['priority'] == 1 ? '(Medium)' : '(Normal)'}';
      final DateTime dueDate = DateTime.now().add(const Duration(days: 7));
      final int priority = scenario['priority'] as int;
      final String reminderType = scenario['reminderType'] as String;
      
      await _todoNotificationService.testTodoNotification(
        todoId: todoId,
        title: title,
        dueDate: dueDate,
        priority: priority,
        reminderType: reminderType,
      );
      
      loadingOverlay.remove();
      _showTestSuccessMessage('Test notification sent!');
    } catch (e) {
      loadingOverlay.remove();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  OverlayEntry _showLoadingOverlay() {
    final overlay = OverlayEntry(
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Running test...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(overlay);
    return overlay;
  }
  
  void _showTestSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showNotificationDisabledDialog(String type, VoidCallback onEnable) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${type.substring(0, 1).toUpperCase()}${type.substring(1)} Notifications Disabled'),
        content: Text(
          'You need to enable $type notifications to run this test. Would you like to enable them now?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onEnable();
            },
            child: const Text('ENABLE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Reminders'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingsCard(
              isEnabled: _todoNotificationsEnabled,
              onToggle: _toggleTodoNotifications,
              title: 'Task Reminders',
              subtitle: _todoNotificationsEnabled
                  ? 'Automatic reminders for your tasks'
                  : 'Notifications are disabled',
              icon: _todoNotificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              iconColor: _todoNotificationsEnabled ? Colors.green : Colors.red,
              extraContent: _todoNotificationsEnabled
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        const Text(
                          'Reminder Schedule',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        
                        _buildInfoRow(Icons.calendar_today, 'On the due date'),
                        _buildInfoRow(Icons.today, '1 day before due date'),
                        _buildInfoRow(Icons.date_range, '2 days before due date'),
                        _buildInfoRow(Icons.calendar_month, '1 week before due date'),
                        
                        const SizedBox(height: 8),
                        Text(
                          'You will automatically receive reminders at these times',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            
            const SizedBox(height: 16),
            
            _buildTestScenariosCard(
              title: 'Test Reminder Notifications',
              scenarios: _todoTestScenarios,
              onTest: _runTodoTest,
            ),
            
            const SizedBox(height: 16),
            
            _buildResetCard(),
          ],
        ),
      ),
    );
  }
  
  Future<void> _resetNotificationSettings() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Task Reminders'),
        content: const Text('This will reset all task reminder settings to default. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RESET'),
          ),
        ],
      ),
    );
    
    if (shouldReset != true) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(NotificationService.prefTodoNotificationsEnabled);
    
    await _loadNotificationSettings();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task reminder settings reset'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }
  
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
  
  Widget _buildSettingsCard({
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    Widget? extraContent,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: onToggle,
                ),
              ],
            ),
            if (extraContent != null) extraContent,
          ],
        ),
      ),
    );
  }
  
  Widget _buildTestScenariosCard({
    required String title,
    required List<Map<String, dynamic>> scenarios,
    required Function(Map<String, dynamic>) onTest,
    IconData? icon,
    Color? iconColor,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Icon(icon, size: 20, color: iconColor ?? Colors.blue),
                if (icon != null)
                  const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            ...scenarios.map((scenario) {
              return _buildTestCard(scenario, () => onTest(scenario));
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResetCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reset Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reset all task reminder settings to their default values',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _resetNotificationSettings,
              icon: const Icon(Icons.restore),
              label: const Text('RESET SETTINGS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTestCard(Map<String, dynamic> scenario, VoidCallback onTest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scenario['iconColor'].withOpacity(0.2),
          child: Icon(scenario['icon'], color: scenario['iconColor'], size: 20),
        ),
        title: Text(scenario['name']),
        subtitle: Text(scenario['description']),
        trailing: ElevatedButton(
          onPressed: onTest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('TEST'),
        ),
      ),
    );
  }
}
