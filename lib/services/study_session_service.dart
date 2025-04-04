import 'package:flutter/foundation.dart';
import 'dart:async';

import '../progress_tracker_page.dart';

class StudySessionService extends ChangeNotifier {
 
  Course? _activeCourse;
  DateTime _startTime = DateTime.now();
  Timer? _timer;
  int _elapsedSeconds = 0;
  String? _activeCourseId;
  
 
  final _tickerStreamController = StreamController<int>.broadcast();
  Stream<int> get tickerStream => _tickerStreamController.stream;
  
  
  Course? get activeCourse => _activeCourse;
  DateTime get startTime => _startTime;
  int get elapsedSeconds => _elapsedSeconds;
  int get elapsedMinutes => _elapsedSeconds ~/ 60;
  bool get hasActiveSession => _activeCourse != null;
  String? get activeCourseId => _activeCourseId;
  
 
  void startSession(Course course) {
   
    _timer?.cancel();
    
 
    _activeCourse = course;
    _activeCourseId = course.id;
    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    
   
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      _elapsedSeconds++;
      
     
      if (!_tickerStreamController.isClosed) {
        _tickerStreamController.add(_elapsedSeconds);
      }
      
     
      if (_elapsedSeconds % 5 == 0) {
        notifyListeners();
      }
    });
    
    notifyListeners();
  }
  
 
  void endSession() {
   
    _timer?.cancel();
    
   
    _activeCourse = null;
    _activeCourseId = null;
    _elapsedSeconds = 0;
    
    notifyListeners();
  }
  
  
  void updateActiveCourse(Course course) {
    if (_activeCourseId == course.id) {
      _activeCourse = course;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _tickerStreamController.close();
    super.dispose();
  }
}
