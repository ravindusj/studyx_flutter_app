import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SidebarMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final User? currentUser;

  static const Color selectedItemColor = Color(0xFFB8C9B8);

  const SidebarMenu({
    Key? key, 
    required this.selectedIndex,
    required this.onItemSelected,
    this.currentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;

    final coreItems = [
      _NavItem(Icons.dashboard_rounded, 'Dashboard', 0),
      _NavItem(Icons.edit_rounded, 'Notes', 1),
      _NavItem(Icons.check_circle_outline_rounded, 'To Do', 2),
      _NavItem(Icons.chat_rounded, 'Chat', 6),
    ];
    
    final studyItems = [
      _NavItem(Icons.trending_up_rounded, 'Progress Tracker', 3),
      _NavItem(Icons.timer_rounded, 'Deadline Tracker', 4),
      _NavItem(Icons.spa_rounded, 'Meditation', 5),
      _NavItem(Icons.restaurant_rounded, 'Canteen', 7),
      _NavItem(Icons.calculate_rounded, 'Math Solver', 8),
      _NavItem(Icons.auto_awesome, 'AI Tools', 9),
    ];
    
    final settingsItems = [
      _NavItem(Icons.settings_rounded, 'Settings', 10),
    ];
    
    final debugItems = kDebugMode ? [
      _NavItem(Icons.bug_report, 'Testing Tools', 11),
    ] : [];
    
    final allNavItems = [...coreItems, ...studyItems, ...settingsItems, ...debugItems];
    
    final validIndex = selectedIndex >= 0 && selectedIndex < allNavItems.length ? 
                      selectedIndex : 0;

    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...coreItems.map((item) => 
                  _buildNavItem(
                    context: context,
                    icon: item.icon,
                    title: item.title,
                    index: item.index,
                    isSelected: item.index == validIndex,
                  ),
                ),
                
                const Divider(height: 32, indent: 20, endIndent: 20),
                
                ...studyItems.map((item) => 
                  _buildNavItem(
                    context: context,
                    icon: item.icon,
                    title: item.title,
                    index: item.index,
                    isSelected: item.index == validIndex,
                  ),
                ),
                
                const Divider(height: 32, indent: 20, endIndent: 20),
                
                ...settingsItems.map((item) => 
                  _buildNavItem(
                    context: context,
                    icon: item.icon,
                    title: item.title,
                    index: item.index,
                    isSelected: item.index == validIndex,
                  ),
                ),
                
                if (debugItems.isNotEmpty) ...[
                  const Divider(height: 40, indent: 20, endIndent: 20),
                  
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 8, bottom: 8),
                    child: Text(
                      'DEVELOPER OPTIONS',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  
                  ...debugItems.map((item) => 
                    _buildNavItem(
                      context: context,
                      icon: item.icon,
                      title: item.title,
                      index: item.index,
                      isSelected: item.index == validIndex,
                      isDebug: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          if (currentUser != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: OutlinedButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: Icon(
                  Icons.logout_rounded,
                  color: isDarkMode ? Colors.grey.shade300 : null,
                  size: 18,
                ),
                label: Text(
                  'Sign Out',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey[700],
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    required bool isSelected,
    bool isDebug = false,
  }) {
    void handleTap() {
      debugPrint('Tapped on menu item: $title (index: $index)');
      onItemSelected(index);
    }
    
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final selectedBgColor = isDarkMode 
        ? (isDebug ? Colors.purple.withOpacity(0.15) : primaryColor.withOpacity(0.15))
        : (isDebug ? Colors.purple.shade100.withOpacity(0.7) : selectedItemColor.withOpacity(0.7)); 
        
    final selectedIconColor = isDarkMode
        ? (isDebug ? Colors.purpleAccent : Theme.of(context).colorScheme.tertiary)
        : (isDebug ? Colors.purple.shade800 : const Color(0xFF31493C));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: handleTap,
          splashColor: isDebug ? Colors.purple.withOpacity(0.1) : primaryColor.withOpacity(0.1),
          highlightColor: isDebug ? Colors.purple.withOpacity(0.1) : primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            decoration: BoxDecoration(
              color: isSelected ? selectedBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected 
                        ? selectedIconColor
                        : (isDebug 
                            ? (isDarkMode ? Colors.purple.shade200 : Colors.purple.shade400)
                            : (isDarkMode ? Colors.grey[400] : Colors.grey[700])),
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected 
                          ? selectedIconColor
                          : (isDebug 
                              ? (isDarkMode ? Colors.purple.shade200 : Colors.purple.shade700)
                              : (isDarkMode ? Colors.grey[300] : Colors.grey[800])),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (isSelected) ...[
                    const Spacer(),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: selectedIconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String title;
  final int index;

  _NavItem(this.icon, this.title, this.index);
}
