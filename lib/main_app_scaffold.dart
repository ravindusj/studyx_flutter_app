import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:provider/provider.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'services/study_session_service.dart';
import 'widgets/sidebar_menu.dart';
import 'note_editor_sheet.dart';
import 'utils/modal_route.dart';
import 'chatbot_page.dart';

typedef MainAppScaffoldState = _MainAppScaffoldState;

class MainAppScaffold extends StatefulWidget {
  final List<Widget> screens;
  final int initialIndex;
  
  const MainAppScaffold({
    Key? key,
    required this.screens, 
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  MainAppScaffoldState createState() => _MainAppScaffoldState();
}

class _MainAppScaffoldState extends State<MainAppScaffold> with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  bool _isSidebarOpen = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late User? _currentUser;
  
  bool _hideAppBar = false;
  
  final _key = GlobalKey<ExpandableFabState>();
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.screens.isEmpty ? 0 : 
                     widget.initialIndex >= widget.screens.length ? 0 : 
                     widget.initialIndex;
                     
    _currentUser = FirebaseAuth.instance.currentUser;
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleSidebar() {
    debugPrint("Toggling sidebar. Current state: $_isSidebarOpen");
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }
  
  void selectItem(int index) {
    if (index < 0 || index >= widget.screens.length) return;
    
    debugPrint('selectItem called with index: $index');
    
    setState(() {
      _selectedIndex = index;
      if (MediaQuery.of(context).size.width < 1200) {
        _isSidebarOpen = false;
        _animationController.reverse();
      }
    });
  }
  
  void _animateScreenTransition() {
  }

  void _selectItem(int index) => selectItem(index);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1200;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final List<int> pagesWithoutFAB = [2, 3, 4, 5, 6, 7, 8, 9, 10];
    
    final currentUser = _currentUser;
    final String displayName = currentUser?.displayName ?? 
                              (currentUser?.email?.split('@').first ?? 'User');
    final photoUrl = _currentUser?.photoURL;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    final isChatPage = _selectedIndex == 3;
    
    return NotificationListener<ChatGroupSelectedNotification>(
      onNotification: (notification) {
        setState(() {
          _hideAppBar = notification.isGroupSelected;
        });
        return true;
      },
      child: Consumer<StudySessionService>(
        builder: (context, studySessionService, _) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: _hideAppBar 
                ? null
                : AppBar(
                    backgroundColor: isDarkMode ? 
                        Theme.of(context).appBarTheme.backgroundColor : 
                        Theme.of(context).colorScheme.primary,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    titleSpacing: 0,
                    toolbarHeight: 64,
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: IconButton(
                            icon: AnimatedIcon(
                              icon: AnimatedIcons.menu_close,
                              progress: _animation,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: _toggleSidebar,
                            padding: const EdgeInsets.all(12),
                            iconSize: 30,
                            splashRadius: 32,
                          ),
                        ),
                        
                        Text(
                          _getPageTitle(), 
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        
                        const Spacer(),
                        
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined, 
                            color: Colors.white,
                          ),
                          onPressed: () {},
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: GestureDetector(
                            onTap: () {
                              _showProfileOptions(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.7), width: 1),
                              ),
                              child: photoUrl != null
                                ? CircleAvatar(
                                    radius: 16,
                                    backgroundImage: NetworkImage(photoUrl),
                                  )
                                : CircleAvatar(
                                    radius: 16,
                                    backgroundColor: accentColor,
                                    child: Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(10),
                      ),
                    ),
                  ),
            
            floatingActionButton: (_currentUser != null && !pagesWithoutFAB.contains(_selectedIndex) && !_hideAppBar)
              ? SpeedDial(
                  icon: Icons.keyboard_arrow_up,
                  activeIcon: Icons.close,
                  iconTheme: IconThemeData(
                    color: isDarkMode ? primaryColor : Colors.white,
                    size: 34,
                  ),
                  buttonSize: const Size(56, 56),
                  backgroundColor: isDarkMode ? accentColor : primaryColor,
                  overlayColor: Colors.black,
                  overlayOpacity: 0.5,
                  spacing: 15,
                  spaceBetweenChildren: 15,
                  elevation: 8.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  direction: SpeedDialDirection.up,
                  children: [
                    SpeedDialChild(
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: isDarkMode ? primaryColor : Colors.white,
                        size: 28,
                      ),
                      backgroundColor: isDarkMode ? accentColor : primaryColor,
                      label: 'Write Note',
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      labelBackgroundColor: Theme.of(context).cardColor,
                      onTap: () => _showNoteEditor(context),
                    ),
                    SpeedDialChild(
                      child: Icon(
                        Icons.auto_awesome,
                        color: isDarkMode ? primaryColor : Colors.white,
                        size: 28,
                      ),
                      backgroundColor: isDarkMode ? accentColor : primaryColor,
                      label: 'AI Assistant',
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      labelBackgroundColor: Theme.of(context).cardColor,
                      onTap: () => _showChatBot(context),
                    ),
                  ],
                )
              : null,
            
            body: GestureDetector(
              onHorizontalDragStart: !_isSidebarOpen ? (details) {
                if (details.globalPosition.dx < 20) {
                  setState(() {
                    _isSidebarOpen = true;
                    _animationController.forward();
                  });
                }
              } : null,
              onHorizontalDragEnd: _isSidebarOpen ? (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                  setState(() {
                    _isSidebarOpen = false;
                    _animationController.reverse();
                  });
                }
              } : null,
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    margin: EdgeInsets.only(
                      left: _isSidebarOpen && isDesktop ? 230 : 0,
                    ),
                    child: SafeArea(
                      top: false,
                      child: widget.screens.isEmpty
                          ? const Center(child: Text('No content available'))
                          : IndexedStack(
                              key: ValueKey<int>(_selectedIndex),
                              index: _selectedIndex,
                              children: widget.screens,
                            ),
                    ),
                  ),
                  
                  if (_isSidebarOpen && !isDesktop)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _toggleSidebar,
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                    ),
                  
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    left: _isSidebarOpen ? 0 : -230,
                    top: 5,
                    bottom: 6,
                    width: 230,
                    child: Material(
                      elevation: 16,
                      color: Colors.transparent,
                      child: SidebarMenu(
                        selectedIndex: _selectedIndex,
                        onItemSelected: _selectItem,
                        currentUser: _currentUser,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  String _getPageTitle() {
    final pageTitles = [
      'Dashboard',
      'Notes',
      'To Do',
      'Progress Tracker',
      'Deadline Tracker',
      'Meditation',
      'Chat',
      'Canteen',
      'Math Solver',
      'AI Tools',
      'Settings',
      'Testing Tools',
    ];
    
    if (_selectedIndex >= 0 && _selectedIndex < pageTitles.length) {
      return pageTitles[_selectedIndex];
    }
    
    return 'StudyX';
  }
  
  void _showProfileOptions(BuildContext context) {
    final currentUser = _currentUser;
    final String displayName = currentUser?.displayName ?? 
                              (currentUser?.email?.split('@').first ?? 'User');
    final email = currentUser?.email ?? 'No email available';
    final photoUrl = currentUser?.photoURL;
    
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: photoUrl != null
                ? CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(photoUrl),
                    onBackgroundImageError: (_, __) => Icon(
                      Icons.person,
                      size: 25,
                      color: primaryColor,
                    ),
                  )
                : CircleAvatar(
                    radius: 25,
                    backgroundColor: accentColor,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
              title: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(email),
            ),
            
            const Divider(height: 32),
            
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _selectItem(10);
              },
            ),
            
            ListTile(
              leading: Icon(
                Icons.logout_outlined,
                color: isDarkMode ? Colors.grey.shade300 : null,
              ),
              title: Text(
                'Sign Out',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade300 : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showNoteEditor(BuildContext context) {
    Navigator.of(context).push(
      ModalPageRoute(
        page: ModalNoteEditor(),
      ),
    );
  }
  
  void _showChatBot(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: const ChatbotPage(isModal: true),
            ),
          ),
        );
      },
    );
  }
}

class ChatGroupSelectedNotification extends Notification {
  final bool isGroupSelected;
  
  ChatGroupSelectedNotification(this.isGroupSelected);
}
