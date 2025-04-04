import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'services/study_session_service.dart';
import 'services/progress_notification_service.dart'; 

class ProgressTrackerPage extends StatefulWidget {
  const ProgressTrackerPage({Key? key}) : super(key: key);

  @override
  State<ProgressTrackerPage> createState() => _ProgressTrackerPageState();
}

class _ProgressTrackerPageState extends State<ProgressTrackerPage> with SingleTickerProviderStateMixin {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  

  late CollectionReference _coursesCollection;
  late CollectionReference _studySessionsCollection;

  List<Course> _courses = [];
  Map<String, int> _weeklyStudyMinutes = {
    'Mon': 0,
    'Tue': 0,
    'Wed': 0,
    'Thu': 0,
    'Fri': 0,
    'Sat': 0,
    'Sun': 0,
  };
  
  
  bool _isLoading = true;
  

  late TabController _tabController;
  
 
  Timer? _uiUpdateTimer;
  
  final ProgressNotificationService _notificationService = ProgressNotificationService();
  bool _notificationsEnabled = true;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeFirebase();
    
   
    _initializeNotifications();
    
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startUiUpdateTimer();
    });
  }
  
  
  void _startUiUpdateTimer() {
    
    _uiUpdateTimer?.cancel();
    
    try {
   
      _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          final studySessionService = Provider.of<StudySessionService>(context, listen: false);
          if (studySessionService.hasActiveSession) {
            setState(() {
           
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error starting UI update timer: $e');
    }
  }
  
  Future<void> _initializeFirebase() async {
    final user = _auth.currentUser;
    if (user != null) {
   
      _coursesCollection = _firestore.collection('users/${user.uid}/courses');
      _studySessionsCollection = _firestore.collection('users/${user.uid}/studySessions');
      
     
      await _loadCourses();
      await _calculateWeeklyStudyTime();
      
      setState(() {
        _isLoading = false;
      });
    } else {
     
      setState(() {
        _isLoading = false;
      });
    }
  }
  
 
  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    
   
    final sessionNotificationsEnabled = await _notificationService.isSessionNotificationsEnabled();
    
    setState(() {
      _notificationsEnabled = sessionNotificationsEnabled;
    });
  }
  
  Future<void> _loadCourses() async {
    try {
      final snapshot = await _coursesCollection.get();
      
      setState(() {
        _courses = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          
          return Course(
            id: doc.id,
            name: data['name'] ?? '',
            code: data['code'] ?? '',
            credits: data['credits'] ?? 3,
            progress: data['progress'] ?? 0.0,
            color: Color(data['color'] ?? 0xFF4CAF50),
            studyTime: data['studyTime'] ?? 0,
            lastStudied: data['lastStudied'] != null 
                ? (data['lastStudied'] as Timestamp).toDate() 
                : DateTime.now(),
          );
        }).toList();
      });
      
      
      final studySessionService = context.read<StudySessionService>();
      if (studySessionService.hasActiveSession) {
        final activeCourseId = studySessionService.activeCourseId;
        final activeCourse = _courses.firstWhere(
          (course) => course.id == activeCourseId,
          orElse: () => _courses.first,
        );
        studySessionService.updateActiveCourse(activeCourse);
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load courses: $e');
    }
  }
  
  Future<void> _calculateWeeklyStudyTime() async {
    try {
      
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 7));
      
      final studySessions = await _studySessionsCollection
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('startTime', isLessThan: Timestamp.fromDate(weekEnd))
          .get();
      
      
      final Map<String, int> weeklyMinutes = {
        'Mon': 0,
        'Tue': 0,
        'Wed': 0,
        'Thu': 0,
        'Fri': 0,
        'Sat': 0,
        'Sun': 0,
      };
      
     
      for (var session in studySessions.docs) {
        final data = session.data() as Map<String, dynamic>;
        final startTime = (data['startTime'] as Timestamp).toDate();
        final duration = data['durationMinutes'] as int? ?? 0;
        
        
        final dayOfWeek = startTime.weekday;
        final dayName = weeklyMinutes.keys.elementAt(dayOfWeek - 1);
        
        weeklyMinutes[dayName] = (weeklyMinutes[dayName] ?? 0) + duration;
      }
      
      setState(() {
        _weeklyStudyMinutes = weeklyMinutes;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to calculate weekly study time: $e');
    }
  }
  
  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.stretchedDots(
          color: isDarkMode ? accentColor : primaryColor,
          size: 50,
        ),
      );
    }
    
    final double totalCredits = _courses.fold(0, (sum, course) => sum + course.credits);
    final double weightedProgress = totalCredits > 0 
        ? _courses.fold(0, (sum, course) => sum + (course.progress * course.credits / totalCredits))
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Study Progress',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Track your academic progress and study time',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: TabBar(
                controller: _tabController,
                indicatorColor: isDarkMode 
                  ? Colors.white 
                  : Theme.of(context).colorScheme.primary.withOpacity(0.9),
                labelColor: isDarkMode 
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
                unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDarkMode 
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary.withOpacity(0.9),
                ),
                overlayColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.hovered))
                      return isDarkMode 
                        ? Colors.white.withOpacity(0.1)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.7);
                    if (states.contains(MaterialState.pressed))
                      return isDarkMode 
                        ? Colors.white.withOpacity(0.2)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.8);
                    return null;
                  },
                ),
                tabs: const [
                  Tab(text: 'Progress'),
                  Tab(text: 'Study Time'),
                ],
              ),
          ),
          
          const SizedBox(height: 24),
          
         
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                
                _buildProgressTab(context, weightedProgress, totalCredits, isDarkMode),
                
             
                _buildStudyTimeTab(context, isDarkMode),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressTab(BuildContext context, double weightedProgress, double totalCredits, bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadCourses();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overall Progress',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getProgressColor(weightedProgress).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${(weightedProgress * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: _getProgressColor(weightedProgress),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Completion Rate',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${(weightedProgress * 100).round()}%',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: weightedProgress,
                            minHeight: 10,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(weightedProgress)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Total Credits: ${totalCredits.toInt()}',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Course Progress',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showAddCourseDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Course'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            
            _courses.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.book, color: Colors.grey, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'No courses added yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Add courses to track your progress',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _courses.length,
                  itemBuilder: (context, index) {
                    final course = _courses[index];
                    return _buildCourseItem(context, course);
                  },
                ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStudyTimeTab(BuildContext context, bool isDarkMode) {
  
    final studySessionService = context.watch<StudySessionService>();
    final activeCourse = studySessionService.activeCourse;
    final elapsedMinutes = studySessionService.elapsedMinutes;
    
   
    final totalStudyMinutes = _courses.fold(0, (sum, course) => sum + course.studyTime);
    final totalHours = totalStudyMinutes / 60;
    
    return RefreshIndicator(
      onRefresh: () async {
        await _calculateWeeklyStudyTime();
        await _loadCourses();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           
            if (activeCourse != null) ...[
              _buildActiveStudySessionCard(activeCourse, elapsedMinutes),
              const SizedBox(height: 24),
            ],
            
           
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Study Time',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                          
                            IconButton(
                              icon: Icon(
                                _notificationsEnabled
                                    ? Icons.notifications_active
                                    : Icons.notifications_off,
                                color: _notificationsEnabled
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                size: 20,
                              ),
                              onPressed: () => _showNotificationSettings(context),
                              tooltip: 'Study Notifications',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 12),
                          
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                  text: totalHours.toStringAsFixed(1),
                                  children: const [
                                    TextSpan(
                                      text: ' hrs',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      'Weekly Activity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                   
                    SizedBox(
                      height: 120,
                      child: _buildWeeklyStudyChart(),
                    ),
                    
                    
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _weeklyStudyMinutes.keys.map((day) {
                        return Text(
                          day,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
          
            Text(
              'Study Time by Course',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
        
            _courses.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.grey, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'No study data yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Start a study session to track your time',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _courses.length,
                  itemBuilder: (context, index) {
                    final course = _courses[index];
                    return _buildCourseStudyItem(context, course);
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseItem(BuildContext context, Course course) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${course.code} • ${course.credits} Credits',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getProgressColor(course.progress).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(course.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: _getProgressColor(course.progress),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${(course.progress * 100).round()}%',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: course.progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(course.color),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Studied: ${_formatStudyTime(course.studyTime)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Last studied: ${_getLastStudiedText(course.lastStudied)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startStudySession(course),
                    icon: const Icon(Icons.play_circle_fill),
                    label: const Text('Start Studying'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => _updateProgress(course),
                    icon: Icon(
                      Icons.add,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditCourseDialog(context, course);
                      } else if (value == 'delete') {
                        _confirmDeleteCourse(context, course);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Progress'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Remove Course'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseStudyItem(BuildContext context, Course course) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hours = course.studyTime / 60;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
          
            CircleAvatar(
              radius: 24,
              backgroundColor: course.color,
              child: Text(
                course.code.substring(0, min(2, course.code.length)),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last studied: ${_getLastStudiedText(course.lastStudied)}',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
           
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    text: hours.toStringAsFixed(1),
                    children: const [
                      TextSpan(
                        text: ' hrs',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _getStudyTimePercent(course),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
            
          
            IconButton(
              icon: const Icon(Icons.play_circle_fill),
              color: Colors.green,
              onPressed: () => _startStudySession(course),
              tooltip: 'Start Study Session',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveStudySessionCard(Course course, int elapsedMinutes) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final studySessionService = context.watch<StudySessionService>();
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    
    
    final elapsedSeconds = studySessionService.elapsedSeconds;
    
 
    final hours = elapsedSeconds ~/ 3600;
    final minutes = (elapsedSeconds % 3600) ~/ 60;
    final seconds = elapsedSeconds % 60;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
               
                const Text(
                  'Active Study Session',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      
                      StreamBuilder(
                        stream: Stream.periodic(const Duration(milliseconds: 500)),
                        builder: (context, snapshot) {
                          
                          final latestSeconds = context.read<StudySessionService>().elapsedSeconds;
                          final h = latestSeconds ~/ 3600;
                          final m = (latestSeconds % 3600) ~/ 60;
                          final s = latestSeconds % 60;
                          
                          return Text(
                            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            
            Row(
              children: [
               
                CircleAvatar(
                  radius: 24,
                  backgroundColor: course.color,
                  child: Text(
                    course.code.substring(0, min(2, course.code.length)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Started ${_getElapsedTimeText(context.read<StudySessionService>().startTime)}',
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            
            SizedBox(
              height: 30,
              child: Center(
                child: LoadingAnimationWidget.progressiveDots(
                  color: isDarkMode ? accentColor : primaryColor,
                  size: 50,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
          
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _endStudySession,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('End Study Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStudyChart() {
    final maxMinutes = _weeklyStudyMinutes.values.fold(0, 
      (max, value) => value > max ? value : max);
    
    return Row(
      children: _weeklyStudyMinutes.entries.map((entry) {
        final minutes = entry.value;
        
        final heightPercent = maxMinutes > 0 ? minutes / maxMinutes : 0;
        
        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${(minutes / 60).toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                
                height: (80 * heightPercent).toDouble(),
                width: 15,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showAddCourseDialog(BuildContext context) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final creditsController = TextEditingController();
    double progress = 0.0;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Add New Course'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Course Name',
                      hintText: 'Enter course name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Course Code',
                      hintText: 'E.g., CS101',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: creditsController,
                    decoration: const InputDecoration(
                      labelText: 'Credits',
                      hintText: 'Enter credit hours',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Text('Initial Progress: ${(progress * 100).toStringAsFixed(0)}%'),
                  Slider(
                    value: progress,
                    onChanged: (value) {
                      progress = value;
                      setStateDialog(() {});
                    },
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    label: '${(progress * 100).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final code = codeController.text.trim();
                  final creditsText = creditsController.text.trim();
                  
                  if (name.isNotEmpty && code.isNotEmpty && creditsText.isNotEmpty) {
                    final credits = int.tryParse(creditsText) ?? 3;
                    
                   
                    final colors = [
                      0xFF4CAF50,
                      0xFF2196F3, 
                      0xFFFFC107, 
                      0xFFE91E63, 
                      0xFF9C27B0, 
                      0xFF795548, 
                    ];
                    
                    final randomColor = colors[_courses.length % colors.length];
                    
                    try {
                      setState(() => _isLoading = true);
                      
                     
                      await _coursesCollection.add({
                        'name': name,
                        'code': code,
                        'credits': credits,
                        'progress': progress,
                        'color': randomColor,
                        'studyTime': 0,
                        'lastStudied': Timestamp.now(),
                        'createdAt': Timestamp.now(),
                      });
                      
                  
                      await _loadCourses();
                      
                      setState(() => _isLoading = false);
                      Navigator.pop(context);
                    } catch (e) {
                      setState(() => _isLoading = false);
                      _showErrorSnackBar('Failed to add course: $e');
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditCourseDialog(BuildContext context, Course course) {
    double newProgress = course.progress;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('Update Progress for ${course.code}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current Progress: ${(course.progress * 100).toStringAsFixed(0)}%'),
                const SizedBox(height: 16),
                Text('New Progress: ${(newProgress * 100).toStringAsFixed(0)}%'),
                Slider(
                  value: newProgress,
                  onChanged: (value) {
                    newProgress = value;
                    setStateDialog(() {});
                  },
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '${(newProgress * 100).toStringAsFixed(0)}%',
                  activeColor: course.color,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    setState(() => _isLoading = true);
                    
                  
                    await _coursesCollection.doc(course.id).update({
                      'progress': newProgress,
                    });
                    
                   
                    await _loadCourses();
                    
                    setState(() => _isLoading = false);
                    Navigator.pop(context);
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _showErrorSnackBar('Failed to update progress: $e');
                    Navigator.pop(context);
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateProgress(Course course) async {
    
    try {
      double newProgress = course.progress + 0.05;
      if (newProgress > 1.0) newProgress = 1.0;
      
     
      await _coursesCollection.doc(course.id).update({
        'progress': newProgress,
      });
      
      
      int newPercent = (newProgress * 100).round();
      int oldPercent = (course.progress * 100).round();
      
     
      if ((oldPercent < 25 && newPercent >= 25) ||
          (oldPercent < 50 && newPercent >= 50) ||
          (oldPercent < 75 && newPercent >= 75) ||
          (oldPercent < 100 && newPercent >= 100)) {
        _notificationService.notifyProgressMilestone(course.name, newPercent);
      }
      
  
      await _loadCourses();
    } catch (e) {
      _showErrorSnackBar('Failed to update progress: $e');
    }
  }

  void _confirmDeleteCourse(BuildContext context, Course course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Course'),
        content: Text('Are you sure you want to remove ${course.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                setState(() => _isLoading = true);
                
              
                await _coursesCollection.doc(course.id).delete();
                
             
                await _loadCourses();
                
                setState(() => _isLoading = false);
                Navigator.pop(context);
              } catch (e) {
                setState(() => _isLoading = false);
                _showErrorSnackBar('Failed to delete course: $e');
                Navigator.pop(context);
              }
            },
            child: const Text('Remove'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  
  void _startStudySession(Course course) {
    final studySessionService = context.read<StudySessionService>();
    
    if (studySessionService.hasActiveSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have an active study session')),
      );
      return;
    }
    
    
    studySessionService.startSession(course);
    
   
    _notificationService.notifySessionStart(course.name, course.code);
    
    
    _tabController.animateTo(1);
  }
  
  void _endStudySession() async {
    final studySessionService = context.read<StudySessionService>();
    
    if (!studySessionService.hasActiveSession) return;
    
    setState(() => _isLoading = true);
    
    try {
      
      final course = studySessionService.activeCourse!;
      final startTime = studySessionService.startTime;
      final elapsedSeconds = studySessionService.elapsedSeconds;
      
      
      final minutesToAdd = (elapsedSeconds > 0) 
          ? (elapsedSeconds / 60).ceil()  
          : 1; 
      
     
      await _studySessionsCollection.add({
        'courseId': course.id,
        'courseName': course.name,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.now(),
        'durationMinutes': minutesToAdd,
      });
      
      
      await _coursesCollection.doc(course.id).update({
        'studyTime': FieldValue.increment(minutesToAdd),
        'lastStudied': Timestamp.now(),
      });
      
     
      _notificationService.notifySessionEnd(course.name, minutesToAdd);
      
      
      final newTotalMinutes = course.studyTime + minutesToAdd;
      final newTotalHours = newTotalMinutes ~/ 60;
      
      
      if (newTotalHours >= 5 && course.studyTime < newTotalHours * 60 && newTotalHours % 5 == 0) {
        _notificationService.notifyStudyMilestone(course.name, newTotalHours);
      }
      
     
      studySessionService.endSession();
      
      
      await _calculateWeeklyStudyTime();
      
      
      await _loadCourses();
      
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${_formatDuration(minutesToAdd)} to ${course.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to save study session: $e');
      
      
      studySessionService.endSession();
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  String _formatStudyTime(int minutes) {
    final hours = minutes / 60;
    return '${hours.toStringAsFixed(1)} hrs';
  }
  
  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return hours > 0 
      ? '$hours:${mins.toString().padLeft(2, '0')} hrs'
      : '$mins min';
  }
  
  String _getStudyTimePercent(Course course) {
    final totalStudyMinutes = _courses.fold(0, (sum, c) => sum + c.studyTime);
    if (totalStudyMinutes == 0) return '0%';
    
    final percent = (course.studyTime / totalStudyMinutes * 100).toStringAsFixed(0);
    return '$percent%';
  }
  
  
 
    final difference = now.difference(lastStudied);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }
  

  String _getElapsedTimeText(DateTime startTime) {
    final now = DateTime.now();
    final difference = now.difference(startTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      return '$hours hour${hours > 1 ? 's' : ''} ${minutes > 0 ? '$minutes minute${minutes > 1 ? 's' : ''}' : ''} ago';
    }
  }
  
 
  Color _getProgressColor(double progress) {
    if (progress >= 0.7) {
      return Colors.green;
    } else if (progress >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  
  int min(int a, int b) {
    return a < b ? a : b;
  }
  
 
  void _showNotificationSettings(BuildContext context) async {
   
    final sessionNotificationsEnabled = await _notificationService.isSessionNotificationsEnabled();
    final goalNotificationsEnabled = await _notificationService.isGoalNotificationsEnabled();
    final dailyReminderEnabled = await _notificationService.isDailyReminderEnabled();
    final dailyReminderTime = await _notificationService.getDailyReminderTime();
    
   
    bool localSessionEnabled = sessionNotificationsEnabled;
    bool localGoalEnabled = goalNotificationsEnabled;
    bool localDailyEnabled = dailyReminderEnabled;
    TimeOfDay localReminderTime = dailyReminderTime;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Study Notifications'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: const Text('Study Session Alerts'),
                subtitle: const Text('Notifications when you start/end study sessions'),
                value: localSessionEnabled,
                onChanged: (value) {
                  setState(() {
                    localSessionEnabled = value;
                  });
                },
              ),
              
              SwitchListTile(
                title: const Text('Milestone Alerts'),
                subtitle: const Text('Notifications for progress and study time milestones'),
                value: localGoalEnabled,
                onChanged: (value) {
                  setState(() {
                    localGoalEnabled = value;
                  });
                },
              ),
              
              SwitchListTile(
                title: const Text('Daily Study Reminder'),
                subtitle: const Text('Receive a daily reminder to study'),
                value: localDailyEnabled,
                onChanged: (value) {
                  setState(() {
                    localDailyEnabled = value;
                  });
                },
              ),
              
              if (localDailyEnabled) ...[
                const SizedBox(height: 16),
                const Text('Reminder Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${localReminderTime.hour}:${localReminderTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: localReminderTime,
                    );
                    
                    if (pickedTime != null) {
                      setState(() {
                        localReminderTime = pickedTime;
                      });
                    }
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () async {
            
                await _notificationService.setSessionNotificationsEnabled(localSessionEnabled);
                await _notificationService.setGoalNotificationsEnabled(localGoalEnabled);
                await _notificationService.setDailyReminderEnabled(
                  localDailyEnabled, 
                  time: localReminderTime
                );
                
              
                if (mounted) {
                  setState(() {
                    _notificationsEnabled = localSessionEnabled;
                  });
                }
                
                
                if (context.mounted) {
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification settings updated'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }
}

class Course {
  final String id;
  final String name;
  final String code;
  final int credits;
  final double progress;
  final Color color;
  final int studyTime; 
  final DateTime lastStudied;

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.credits,
    required this.progress,
    required this.color,
    this.studyTime = 0,
    DateTime? lastStudied,
  }) : lastStudied = lastStudied ?? DateTime.now();
}
