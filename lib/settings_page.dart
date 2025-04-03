import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Customize your app experience',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            const SizedBox(height: 32),
            
            _buildSettingsSection(
              context, 
              'Appearance', 
              [
                _buildThemeSetting(context, themeProvider),
              ]
            ),
            
            const SizedBox(height: 16),
            
            if (user != null)
              _buildSettingsSection(
                context,
                'Account',
                [
                  _buildSettingItem(
                    context,
                    'Account Information',
                    'Update your profile details',
                    Icons.person_outline,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Account management coming soon!'),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  ),
                  _buildSettingItem(
                    context,
                    'Notifications',
                    'Manage notification preferences',
                    Icons.notifications_outlined,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Notification settings coming soon!'),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  ),
                ],
              ),
              
            const SizedBox(height: 16),
            
            _buildSettingsSection(
              context,
              'Support',
              [
                _buildSettingItem(
                  context,
                  'About',
                  'Version information and legal',
                  Icons.info_outline,
                  onTap: () {
                    _showAboutDialog(context);
                  }
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAboutDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    
    showAboutDialog(
      context: context,
      applicationName: 'StudyX',
      applicationVersion: 'v1.0.0',
      applicationIcon: Image.asset(
        'assets/images/logo.png',
        width: 50,
        height: 50,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.school,
          size: 50,
          color: isDarkMode ? accentColor : primaryColor,
        ),
      ),
      applicationLegalese: '© 2025 StudyX. All rights reserved.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'StudyX is an all-in-one study platform designed to help students organize their academic life, enhance productivity, and achieve better results.',
        ),
        const SizedBox(height: 16),
        Text(
          'Developed with ❤️ by 🇱🇰',
          style: TextStyle(
            color: isDarkMode ? accentColor : primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingsSection(
    BuildContext context, 
    String title, 
    List<Widget> items
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }
  
  Widget _buildThemeSetting(BuildContext context, ThemeProvider themeProvider) {
    final isDarkMode = themeProvider.isDarkMode;
    final accentColor = Theme.of(context).colorScheme.tertiary; 
    
    return SwitchListTile(
      title: const Text('Dark Mode'),
      subtitle: const Text('Use dark theme throughout the app'),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary,
          size: 26,
        ),
      ),
      value: isDarkMode,
      onChanged: (_) {
        themeProvider.toggleTheme();
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
  
  Widget _buildSettingItem(
    BuildContext context, 
    String title, 
    String subtitle, 
    IconData icon, 
    {VoidCallback? onTap}
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.tertiary; 
    
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon, 
          color: isDarkMode ? Colors.white : Theme.of(context).colorScheme.primary,
          size: 26,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDarkMode ? accentColor : Theme.of(context).colorScheme.primary,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
