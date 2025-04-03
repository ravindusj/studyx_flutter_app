import 'package:flutter/material.dart';
import 'canteen_notification_test_page.dart';
import 'todo_notification_test_page.dart';
import 'deadline_notification_test_page.dart';

class NotificationTestPage extends StatelessWidget {
  const NotificationTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNavigationCard(
                context,
                title: 'Canteen Notifications',
                description: 'Configure canteen availability notifications',
                icon: Icons.restaurant,
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CanteenNotificationTestPage()),
                ),
              ),
              
              const SizedBox(height: 16),
              
              _buildNavigationCard(
                context,
                title: 'Task Reminders',
                description: 'Configure task reminder notifications',
                icon: Icons.task_alt,
                color: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TodoNotificationTestPage()),
                ),
              ),
              
              const SizedBox(height: 16),
              
              _buildNavigationCard(
                context,
                title: 'Deadline Reminders',
                description: 'Test notifications for deadline tracker',
                icon: Icons.alarm,
                color: Colors.red,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DeadlineNotificationTestPage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
