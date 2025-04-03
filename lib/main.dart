import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart'; 
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'canteen_page.dart';
import 'chat_page.dart';
import 'auth_page.dart';
import 'main_app_scaffold.dart';
import 'theme.dart';
import 'notes_page.dart'; 
import 'dashboard_page.dart'; 
import 'settings_page.dart';
import 'providers/theme_provider.dart';
import 'ai_tools_page.dart';
import 'todo_page.dart';
import 'meditation_page.dart';
import 'services/notification_service.dart';
import 'notification_test_page.dart';
import 'progress_tracker_page.dart';
import 'services/study_session_service.dart';
import 'services/progress_notification_service.dart';
import 'services/audio_service.dart';
import 'math_solver_page.dart';
import 'deadline_tracker_page.dart';
import 'services/deadline_service.dart';


final GlobalKey<MainAppScaffoldState> mainAppScaffoldKey = GlobalKey<MainAppScaffoldState>();


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {

    await Firebase.initializeApp();
    debugPrint('Handling a background message: ${message.messageId}');
  } catch (e) {
    debugPrint('Error handling background message: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Error setting background message handler: $e');
    }
    
    try {
      await NotificationService().initialize();
      await ProgressNotificationService().initialize();
    } catch (e) {
      debugPrint('Error initializing notification services: $e');
    }
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => StudySessionService()),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => DeadlineService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'StudyX',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: const AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show splash screen while waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        // User is logged in
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        
        // User is not logged in
        return const AuthPage();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.school,
                size: 80,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'StudyX',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 16),
            LoadingAnimationWidget.stretchedDots(
              color: isDarkMode ? accentColor : primaryColor,
              size: 50,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final studySessionService = Provider.of<StudySessionService>(context);
    

    final List<Widget> screens = [
      const DashboardPage(),
      const NotesPage(),
      const TodoPage(),
      const ProgressTrackerPage(),
      const DeadlineTrackerPage(),
      const MeditationPage(),
      const ChatPage(),
      const CanteenPage(),
      const MathSolverPage(),
      const AiToolsPage(),
      const SettingsPage(),
      if (kDebugMode) const NotificationTestPage(),
    ];
    
    
    return MainAppScaffold(
      key: mainAppScaffoldKey,
      screens: screens,
    );
  }
}
