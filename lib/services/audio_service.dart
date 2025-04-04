import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService with ChangeNotifier {

  static final AudioService _instance = AudioService._internal();
  
  factory AudioService() => _instance;
  
  AudioService._internal() {
    _initAudioPlayer();
  }
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _meditationTimer;
  int _remainingSeconds = 0;
  Map<String, dynamic>? _currentMeditationData;
  
 
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  int get remainingSeconds => _remainingSeconds;
  Map<String, dynamic>? get currentMeditationData => _currentMeditationData;
  String get currentMeditationTitle => _currentMeditationData?['title'] ?? '';
  
  void _initAudioPlayer() {
   
    _audioPlayer.onDurationChanged.listen((newDuration) {
      _duration = newDuration;
      notifyListeners();
    });
    
    _audioPlayer.onPositionChanged.listen((newPosition) {
      _position = newPosition;
      notifyListeners();
    });
    
    _audioPlayer.onPlayerComplete.listen((event) {
      _isPlaying = false;
      _position = Duration.zero;
      _stopMeditationTimer();
      notifyListeners();
    });
  }
  
  Future<void> playMeditation(Map<String, dynamic> meditation) async {
    final String audioPath = meditation['audio'].toString();
    final audioSource = AssetSource(audioPath);
    
   
    if (_isPlaying) {
      await _audioPlayer.stop();
      _stopMeditationTimer();
    }
    
    try {
     
      if (audioPath.isEmpty) {
        throw Exception("Audio file path is empty");
      }
      
     
      debugPrint('Attempting to play: $audioPath');
      
    
      await _audioPlayer.play(audioSource);
      
      _isPlaying = true;
      _currentMeditationData = meditation; 
      _position = Duration.zero;
      _remainingSeconds = meditation['seconds'] as int;
      notifyListeners();
      
     
      _startMeditationTimer();
      
    } catch (e) {
      debugPrint('Error playing meditation: $e');
      
   
      _isPlaying = true;
      _currentMeditationData = meditation;
      _remainingSeconds = meditation['seconds'] as int;
      notifyListeners();
      
      
      _startMeditationTimer();
      
      rethrow; 
    }
  }
  
  Future<void> pauseResume() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      _stopMeditationTimer();
    } else {
      await _audioPlayer.resume();
      _startMeditationTimer();
    }
    
    _isPlaying = !_isPlaying;
    notifyListeners();
  }
  
  Future<void> stop() async {
    await _audioPlayer.stop();
    _stopMeditationTimer();
    
    _isPlaying = false;
    _currentMeditationData = null;
    _position = Duration.zero;
    notifyListeners();
  }
  
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }
  
  void _startMeditationTimer() {
    _meditationTimer?.cancel();
    _meditationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _stopMeditationTimer();
      }
    });
  }
  
  void _stopMeditationTimer() {
    _meditationTimer?.cancel();
    _meditationTimer = null;
  }
  
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
  
  String formatRemainingTime() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _meditationTimer?.cancel();
    super.dispose();
  }
}
