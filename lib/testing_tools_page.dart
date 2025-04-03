import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_test_page.dart';
import 'services/notification_service.dart';
import 'services/canteen_service.dart';
import 'deadline_notification_test_page.dart';

class TestingToolsPage extends StatefulWidget {
  const TestingToolsPage({Key? key}) : super(key: key);

  @override
  State<TestingToolsPage> createState() => _TestingToolsPageState();
}

class _TestingToolsPageState extends State<TestingToolsPage> {
  final NotificationService _notificationService = NotificationService();
  final CanteenService _canteenService = CanteenService();
  bool _notificationsEnabled = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadServices();
  }
  
  Future<void> _loadServices() async {
    try {
      await _notificationService.initialize();
      await _canteenService.initializeCanteens();
      final notificationsEnabled = await _notificationService.isCanteenNotificationsEnabled();
      
      if (mounted) {
        setState(() {
          _notificationsEnabled = notificationsEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading services: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bug_report,
                  size: 32,
                  color: isDarkMode ? Colors.purpleAccent : Colors.purple.shade700,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Developer Testing Tools',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Use these tools to test app functionality',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These tools are only available in debug mode.',
                      style: TextStyle(
                        color: isDarkMode ? Colors.amber[300] : Colors.amber[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                children: [
                  _buildSectionHeader(
                    title: 'Canteen Notifications',
                    icon: Icons.restaurant_menu,
                    color: Colors.green,
                  ),
                  
                  _buildCanteenNotificationCards(),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader(
                    title: 'Firebase Services',
                    icon: Icons.cloud,
                    color: Colors.orange,
                  ),
                  
                  _buildFirebaseTestingCards(),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader(
                    title: 'UI & Performance',
                    icon: Icons.speed,
                    color: Colors.blue,
                  ),
                  
                  _buildUITestingCards(),
                  
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader(
                    title: 'Device Features',
                    icon: Icons.devices,
                    color: Colors.purple,
                  ),
                  
                  _buildDeviceTestingCards(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCanteenNotificationCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTestCard(
                title: 'Notification Settings',
                description: 'Manage and test canteen notification preferences',
                icon: Icons.settings_applications,
                iconColor: Colors.green,
                onTap: () => _navigateToNotificationTest(context),
                isEnabled: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTestCard(
                title: 'Quick Crowded Test',
                description: 'Send a test notification for a crowded canteen',
                icon: Icons.people,
                iconColor: Colors.red,
                onTap: () => _sendCrowdedCanteenTest(),
                isEnabled: _notificationsEnabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTestCard(
                title: 'Quick Available Test',
                description: 'Send a test notification for an available canteen',
                icon: Icons.check_circle,
                iconColor: Colors.green,
                onTap: () => _sendAvailableCanteenTest(),
                isEnabled: _notificationsEnabled,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTestCard(
                title: 'Sequence Test',
                description: 'Test multiple notifications in sequence',
                icon: Icons.replay,
                iconColor: Colors.blue,
                onTap: () => _runSequenceTest(),
                isEnabled: _notificationsEnabled,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTestCard(
                title: 'Deadline Reminders',
                description: 'Test deadline reminder notifications',
                icon: Icons.alarm,
                iconColor: Colors.purple,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DeadlineNotificationTestPage(),
                  ),
                ),
                isEnabled: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }
  
  Widget _buildFirebaseTestingCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTestCard(
                title: 'Firebase Connection',
                description: 'Test connectivity with Firebase backend',
                icon: Icons.sync,
                iconColor: Colors.orange,
                isComingSoon: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTestCard(
                title: 'Authentication',
                description: 'Test login and account verification',
                icon: Icons.lock,
                iconColor: Colors.orange,
                isComingSoon: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildUITestingCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTestCard(
                title: 'Theme Switcher',
                description: 'Test app appearance with different themes',
                icon: Icons.palette,
                iconColor: Colors.blue,
                isComingSoon: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTestCard(
                title: 'Performance Benchmark',
                description: 'Run speed and memory tests',
                icon: Icons.speed,
                iconColor: Colors.blue,
                isComingSoon: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildDeviceTestingCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTestCard(
                title: 'Camera & Microphone',
                description: 'Test device recording capabilities',
                icon: Icons.camera_alt,
                iconColor: Colors.purple,
                isComingSoon: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTestCard(
                title: 'Sensors & GPS',
                description: 'Test device sensors and location',
                icon: Icons.location_on,
                iconColor: Colors.purple,
                isComingSoon: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTestCard({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onTap,
    bool isComingSoon = false,
    bool isEnabled = true,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isDisabled = isComingSoon || !isEnabled;
    
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: isDisabled ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: isDisabled ? Colors.grey : iconColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDisabled 
                                ? Colors.grey 
                                : (isDarkMode ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDisabled ? Colors.grey : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (isComingSoon)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.purpleAccent : Colors.purple,
                  ),
                ),
              ),
            ),
          if (!isComingSoon && !isEnabled)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Notifications Off',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  void _navigateToNotificationTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationTestPage(),
      ),
    );
  }
  
  Future<void> _sendCrowdedCanteenTest() async {
    if (!_notificationsEnabled) {
      _showNotificationsDisabledDialog();
      return;
    }
    
    try {
      const String canteenId = 'edge-canteen';
      const String canteenName = 'Edge Canteen';
      const double availability = 20.0;
      
      await _notificationService.sendCanteenNotification(
        canteenId: canteenId,
        canteenName: canteenName,
        availability: availability,
      );
      
      _showTestSuccessMessage('Sent crowded canteen notification!');
    } catch (e) {
      _showErrorMessage('Failed to send notification: $e');
    }
  }
  
  Future<void> _sendAvailableCanteenTest() async {
    if (!_notificationsEnabled) {
      _showNotificationsDisabledDialog();
      return;
    }
    
    try {
      const String canteenId = 'audi-canteen';
      const String canteenName = 'Audi Canteen';
      const double availability = 80.0;
      
      await _notificationService.sendCanteenNotification(
        canteenId: canteenId,
        canteenName: canteenName,
        availability: availability,
      );
      
      _showTestSuccessMessage('Sent available canteen notification!');
    } catch (e) {
      _showErrorMessage('Failed to send notification: $e');
    }
  }
  
  Future<void> _runSequenceTest() async {
    if (!_notificationsEnabled) {
      _showNotificationsDisabledDialog();
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorMessage('You need to be logged in to run sequence tests');
      return;
    }
    
    final loadingOverlay = _showLoadingOverlay('Running sequence test...');
    
    try {
      await _canteenService.updateCanteenAvailability(
        'edge-canteen',
        50.0,
        user.uid,
      );
      
      await Future.delayed(const Duration(seconds: 2));
      
      await _canteenService.updateCanteenAvailability(
        'edge-canteen',
        25.0,
        user.uid,
      );
      
      await Future.delayed(const Duration(seconds: 2));
      
      await _canteenService.updateCanteenAvailability(
        'audi-canteen',
        55.0,
        user.uid,
      );
      
      await Future.delayed(const Duration(seconds: 2));
      
      await _canteenService.updateCanteenAvailability(
        'audi-canteen',
        85.0,
        user.uid,
      );
      
      loadingOverlay.remove();
      _showTestSuccessMessage('Sequence test completed. Check for notifications!');
    } catch (e) {
      loadingOverlay.remove();
      _showErrorMessage('Error during sequence test: $e');
    }
  }
  
  OverlayEntry _showLoadingOverlay(String message) {
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
                  Text(message),
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
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _showNotificationsDisabledDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications Disabled'),
        content: const Text(
          'You need to enable notifications to run this test. Would you like to enable them now?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _notificationService.setCanteenNotificationsEnabled(true);
              if (mounted) {
                setState(() {
                  _notificationsEnabled = true;
                });
              }
            },
            child: const Text('ENABLE'),
          ),
        ],
      ),
    );
  }
}
