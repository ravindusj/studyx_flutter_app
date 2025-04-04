import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/notification_service.dart';
import 'services/canteen_service.dart';

class CanteenNotificationTestPage extends StatefulWidget {
  const CanteenNotificationTestPage({Key? key}) : super(key: key);

  @override
  State<CanteenNotificationTestPage> createState() =>
      _CanteenNotificationTestPageState();
}

class _CanteenNotificationTestPageState
    extends State<CanteenNotificationTestPage> {
  final NotificationService _notificationService = NotificationService();
  final CanteenService _canteenService = CanteenService();

  bool _canteenNotificationsEnabled = false;
  int _canteenThreshold = 30;
  bool _isLoading = true;
  bool _showAdvancedOptions = false;

  final List<Map<String, dynamic>> _canteenTestScenarios = [
    {
      'name': 'Test Crowded Alert',
      'description': 'This simulates a canteen becoming very crowded',
      'icon': Icons.people,
      'iconColor': Colors.red,
      'before': 40.0,
      'after': 25.0,
    },
    {
      'name': 'Test Available Alert',
      'description': 'This simulates a canteen becoming available',
      'icon': Icons.check_circle,
      'iconColor': Colors.green,
      'before': 60.0,
      'after': 75.0,
    },
    {
      'name': 'Direct Alert Test',
      'description': 'Sends a test notification immediately',
      'icon': Icons.notifications_active,
      'iconColor': Colors.blue,
      'direct': true,
    },
  ];

  final List<Map<String, dynamic>> _advancedScenarios = [
    {
      'name': 'No Status Change Test',
      'description':
          'Tests that no notification is sent when status category doesn\'t change',
      'icon': Icons.science,
      'iconColor': Colors.purple,
      'before': 50.0,
      'after': 60.0,
    },
    {
      'name': 'Edge Case: Threshold Match',
      'description': 'Test when availability exactly matches threshold',
      'icon': Icons.bug_report,
      'iconColor': Colors.amber,
      'direct': true,
      'exactThreshold': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
    _initializeCanteenService();
  }

  Future<void> _initializeCanteenService() async {
    await _canteenService.initializeCanteens();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() => _isLoading = true);

    try {
      await _notificationService.initialize();
      final canteenNotificationsEnabled =
          await _notificationService.isCanteenNotificationsEnabled();
      final canteenThreshold = await _notificationService.getCanteenThreshold();

      if (mounted) {
        setState(() {
          _canteenNotificationsEnabled = canteenNotificationsEnabled;
          _canteenThreshold = canteenThreshold;
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

  Future<void> _toggleCanteenNotifications(bool value) async {
    await _notificationService.setCanteenNotificationsEnabled(value);
    if (mounted) {
      setState(() => _canteenNotificationsEnabled = value);
    }
  }

  Future<void> _setCanteenThreshold(int threshold) async {
    await _notificationService.setCanteenThreshold(threshold);
    if (mounted) {
      setState(() => _canteenThreshold = threshold);
    }
  }

  Future<void> _runCanteenTest(Map<String, dynamic> scenario) async {
    if (!_canteenNotificationsEnabled) {
      _showNotificationDisabledDialog(
        'canteen',
        () => _toggleCanteenNotifications(true),
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
      if (scenario.containsKey('direct') && scenario['direct'] == true) {
        const canteenId = 'edge-canteen';

        final availability =
            scenario.containsKey('exactThreshold') &&
                    scenario['exactThreshold'] == true
                ? _canteenThreshold.toDouble()
                : 20.0;

        await _notificationService.sendCanteenNotification(
          canteenId: canteenId,
          canteenName: _getCanteenName(canteenId),
          availability: availability,
        );

        loadingOverlay.remove();
        _showTestSuccessMessage('Test notification sent!');
        return;
      }

      const canteenId = 'edge-canteen';

      await _canteenService.updateCanteenAvailability(
        canteenId,
        scenario['before'],
        user.uid,
      );

      await Future.delayed(const Duration(seconds: 1));

      await _canteenService.updateCanteenAvailability(
        canteenId,
        scenario['after'],
        user.uid,
      );

      loadingOverlay.remove();
      _showTestSuccessMessage(
        'Test completed!\nCanteen changed from ${scenario['before'].round()}% to ${scenario['after'].round()}% availability',
      );
    } catch (e) {
      loadingOverlay.remove();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _getCanteenName(String canteenId) {
    switch (canteenId) {
      case 'edge-canteen':
        return 'Edge Canteen';
      case 'audi-canteen':
        return 'Audi Canteen';
      case 'hostel-canteen':
        return 'Hostel Canteen';
      default:
        return canteenId
            .replaceAll('-', ' ')
            .split(' ')
            .map(
              (word) =>
                  word.isNotEmpty
                      ? '${word[0].toUpperCase()}${word.substring(1)}'
                      : '',
            )
            .join(' ');
    }
  }

  Future<void> _resetNotificationSettings() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Notification Settings'),
            content: const Text(
              'This will reset all canteen notification settings to default. Continue?',
            ),
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
    await prefs.remove(NotificationService.prefCanteenNotificationsEnabled);
    await prefs.remove(NotificationService.prefCanteenThreshold);

    await _loadNotificationSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Canteen notification settings reset to default'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Canteen Notifications')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingsCard(
              isEnabled: _canteenNotificationsEnabled,
              onToggle: _toggleCanteenNotifications,
              title: 'Availability Alerts',
              subtitle:
                  _canteenNotificationsEnabled
                      ? 'Alert threshold: $_canteenThreshold%'
                      : 'Notifications are disabled',
              icon:
                  _canteenNotificationsEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
              iconColor:
                  _canteenNotificationsEnabled ? Colors.green : Colors.red,
              extraContent:
                  _canteenNotificationsEnabled
                      ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          const Text('Notification Threshold'),
                          Slider(
                            value: _canteenThreshold.toDouble(),
                            min: 10,
                            max: 70,
                            divisions: 6,
                            label: '$_canteenThreshold%',
                            activeColor: _getColorForPercentage(
                              _canteenThreshold.toDouble(),
                            ),
                            onChanged:
                                (value) => _setCanteenThreshold(value.round()),
                          ),
                          Text(
                            'You will be notified when canteen availability is less than $_canteenThreshold%',
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
              title: 'Test Scenarios',
              scenarios: _canteenTestScenarios,
              onTest: _runCanteenTest,
            ),

            const SizedBox(height: 16),

            _buildDeveloperModeToggle(),

            if (_showAdvancedOptions) ...[
              const SizedBox(height: 16),

              _buildTestScenariosCard(
                title: 'Advanced Test Scenarios',
                scenarios: _advancedScenarios,
                onTest: _runCanteenTest,
                icon: Icons.science,
                iconColor: Colors.purple,
              ),

              const SizedBox(height: 16),

              _buildResetCard(),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 70) {
      return Colors.green;
    } else if (percentage >= 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  OverlayEntry _showLoadingOverlay() {
    final overlay = OverlayEntry(
      builder:
          (context) => Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
      builder:
          (context) => AlertDialog(
            title: Text(
              '${type.substring(0, 1).toUpperCase()}${type.substring(1)} Notifications Disabled',
            ),
            content: Text(
              'You need to enable $type notifications to run this test. Would you like to enable them now?',
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
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
                      Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Switch(value: isEnabled, onChanged: onToggle),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Icon(icon, size: 20, color: iconColor ?? Colors.blue),
                if (icon != null) const SizedBox(width: 8),
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

  Widget _buildDeveloperModeToggle() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(Icons.code, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 8),
            const Text(
              'Developer Mode',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        subtitle: const Text('Show advanced testing options'),
        value: _showAdvancedOptions,
        onChanged: (value) {
          setState(() {
            _showAdvancedOptions = value;
          });
        },
        secondary: Icon(
          _showAdvancedOptions ? Icons.developer_mode : Icons.no_sim_outlined,
          color: _showAdvancedOptions ? Colors.blue : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildResetCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reset Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reset all canteen notification settings to their default values',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _resetNotificationSettings,
              icon: const Icon(Icons.restore),
              label: const Text('RESET SETTINGS'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> scenario, VoidCallback onTest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
