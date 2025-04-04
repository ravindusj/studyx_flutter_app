import 'dart:async';
import 'package:flutter/foundation.dart';

class BreathingService extends ChangeNotifier {
  static const String inhale = 'Inhale';
  static const String exhale = 'Exhale';
  static const String hold = 'Hold';

  String _currentPhase = '';
  double _breathingPace = 5.0;
  bool _isActive = false;
  Timer? _phaseTimer;
  int _cycleCount = 0;
  int _targetCycles = 10;

  String get currentPhase => _currentPhase;
  double get breathingPace => _breathingPace;
  bool get isActive => _isActive;
  int get cycleCount => _cycleCount;
  int get targetCycles => _targetCycles;

  void startBreathing(double pace, [int? cycles]) {
    if (_isActive) return;

    _breathingPace = pace;
    _isActive = true;
    _cycleCount = 0;
    _currentPhase = inhale;
    if (cycles != null) _targetCycles = cycles;
    notifyListeners();

    _scheduleNextPhase();
  }

  void stopBreathing() {
    _phaseTimer?.cancel();
    _isActive = false;
    _currentPhase = '';
    notifyListeners();
  }

  void setPace(double pace) {
    _breathingPace = pace;

    if (_isActive) {
      _phaseTimer?.cancel();
      _scheduleNextPhase();
    }

    notifyListeners();
  }

  void _scheduleNextPhase() {
    _phaseTimer = Timer(
      Duration(milliseconds: (_breathingPace * 1000).toInt()),
      () {
        if (!_isActive) return;

        if (_currentPhase == inhale) {
          _currentPhase = hold;
        } else if (_currentPhase == hold) {
          if (_cycleCount % 2 == 0) {
            _currentPhase = exhale;
          } else {
            _currentPhase = inhale;
            _cycleCount++;

            if (_cycleCount >= _targetCycles) {
              stopBreathing();
              return;
            }
          }
        } else if (_currentPhase == exhale) {
          _currentPhase = hold;
        }

        notifyListeners();
        _scheduleNextPhase();
      },
    );
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    super.dispose();
  }
}
