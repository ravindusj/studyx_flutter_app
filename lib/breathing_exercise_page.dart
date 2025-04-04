import 'package:flutter/material.dart';
import 'dart:async';
import 'services/breathing_service.dart';

class BreathingExercisePage extends StatefulWidget {
  const BreathingExercisePage({Key? key}) : super(key: key);

  @override
  State<BreathingExercisePage> createState() => _BreathingExercisePageState();
}

class _BreathingExercisePageState extends State<BreathingExercisePage>
    with SingleTickerProviderStateMixin {
  bool _isBreathingExerciseActive = false;
  double _breathingPaceValue = 5.0;
  late AnimationController _breathAnimationController;
  String _breathingPhase = "";
  Timer? _breathingTimer;
  int _completedCycles = 0;
  final int _targetCycles = 10;

  @override
  void initState() {
    super.initState();

    _breathAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_breathingPaceValue * 1000).toInt()),
    );
  }

  void _startBreathingExercise() {
    if (_isBreathingExerciseActive) return;

    _breathAnimationController.reset();

    setState(() {
      _isBreathingExerciseActive = true;
      _breathingPhase = "Inhale";
      _completedCycles = 0;
    });

    _breathAnimationController.duration = Duration(
      milliseconds: (_breathingPaceValue * 1000).toInt(),
    );

    _runBreathingCycle();
  }

  void _stopBreathingExercise() {
    _breathingTimer?.cancel();
    _breathAnimationController.reset();

    setState(() {
      _isBreathingExerciseActive = false;
      _breathingPhase = "";
    });
  }

  void _runBreathingCycle() {
    try {
      final phaseDuration = _breathingPaceValue;

      setState(() {
        _breathingPhase = "Inhale";
      });

      _breathAnimationController.reset();
      _breathAnimationController.forward();

      _breathingTimer = Timer.periodic(
        Duration(milliseconds: (phaseDuration * 1000).toInt()),
        (timer) {
          if (!_isBreathingExerciseActive || !mounted) {
            timer.cancel();
            return;
          }

          if (_breathingPhase == "Inhale") {
            setState(() {
              _breathingPhase = "Hold";
            });
          } else if (_breathingPhase == "Hold" &&
              _breathAnimationController.status == AnimationStatus.completed) {
            setState(() {
              _breathingPhase = "Exhale";
            });

            _breathAnimationController.reverse();
          } else if (_breathingPhase == "Exhale" &&
              _breathAnimationController.status == AnimationStatus.dismissed) {
            setState(() {
              _breathingPhase = "Hold";
            });
          } else if (_breathingPhase == "Hold" &&
              _breathAnimationController.status == AnimationStatus.dismissed) {
            setState(() {
              _completedCycles++;
              _breathingPhase = "Inhale";
            });

            if (_completedCycles >= _targetCycles) {
              _showCompletionDialog();
              return;
            }

            _breathAnimationController.forward();
          }
        },
      );
    } catch (e) {
      print("Error in breathing cycle: $e");
      _stopBreathingExercise();
    }
  }

  void _showCompletionDialog() {
    _stopBreathingExercise();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Exercise Complete!'),
            content: const Text(
              'Great job! You\'ve completed your breathing exercise.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _updateBreathingPace(double newValue) {
    setState(() {
      _breathingPaceValue = newValue;
    });

    if (_isBreathingExerciseActive) {
      _breathingTimer?.cancel();

      _breathAnimationController.duration = Duration(
        milliseconds: (newValue * 1000).toInt(),
      );

      _runBreathingCycle();
    }
  }

  @override
  void dispose() {
    _breathingTimer?.cancel();
    _breathAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Breathing Exercise'), elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 3, child: _buildBreathingAnimation(theme)),

            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isBreathingExerciseActive
                          ? _breathingPhase
                          : 'Ready to begin?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getPhaseColor(theme),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _isBreathingExerciseActive
                          ? _getBreathingInstructions()
                          : 'Set your breathing pace and start the exercise',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),

                    if (_isBreathingExerciseActive)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Cycle: ${_completedCycles + 1} of $_targetCycles',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Text('Slow'),
                        Expanded(
                          child: Slider(
                            value: _breathingPaceValue,
                            min: 3.0,
                            max: 10.0,
                            divisions: 7,
                            label:
                                '${_breathingPaceValue.toStringAsFixed(1)} sec',
                            onChanged:
                                _isBreathingExerciseActive
                                    ? null
                                    : (value) => _updateBreathingPace(value),
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                        const Text('Fast'),
                      ],
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: 200,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed:
                            _isBreathingExerciseActive
                                ? _stopBreathingExercise
                                : _startBreathingExercise,
                        icon: Icon(
                          _isBreathingExerciseActive
                              ? Icons.stop
                              : Icons.play_arrow,
                        ),
                        label: Text(
                          _isBreathingExerciseActive
                              ? 'Stop Exercise'
                              : 'Start Breathing',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isBreathingExerciseActive
                                  ? Colors.red.shade400
                                  : theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreathingAnimation(ThemeData theme) {
    return Center(
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.scaffoldBackgroundColor,
          border: Border.all(
            color: _getPhaseColor(theme).withOpacity(0.3),
            width: 4,
          ),
        ),
        child: AnimatedBuilder(
          animation: _breathAnimationController,
          builder: (context, child) {
            double animationValue;
            if (_breathingPhase == "Exhale") {
              animationValue = 1.0 - _breathAnimationController.value;
            } else if (_breathingPhase == "Hold") {
              if (_breathAnimationController.status ==
                  AnimationStatus.completed) {
                animationValue = 1.0;
              } else if (_breathAnimationController.status ==
                  AnimationStatus.dismissed) {
                animationValue = 0.0;
              } else {
                animationValue = _breathAnimationController.value;
              }
            } else {
              animationValue = _breathAnimationController.value;
            }

            animationValue = animationValue.clamp(0.0, 1.0);

            return Center(
              child: Container(
                width: 220 * (0.3 + (animationValue * 0.7)),
                height: 220 * (0.3 + (animationValue * 0.7)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getPhaseColor(theme).withOpacity(0.2),
                  border: Border.all(color: _getPhaseColor(theme), width: 2),
                ),
                child: Center(
                  child: Text(
                    _isBreathingExerciseActive ? _breathingPhase : "",
                    style: TextStyle(
                      color: _getPhaseColor(theme),
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getPhaseColor(ThemeData theme) {
    final Color inhaleColor = Colors.blue.shade400;
    final Color holdColor = Colors.green.shade500;
    final Color exhaleColor = Colors.purple.shade400;

    switch (_breathingPhase) {
      case "Inhale":
        return inhaleColor;
      case "Exhale":
        return exhaleColor;
      case "Hold":
        return holdColor;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _getBreathingInstructions() {
    switch (_breathingPhase) {
      case "Inhale":
        return "Breathe in slowly through your nose";
      case "Exhale":
        return "Breathe out slowly through your mouth";
      default:
        return "Hold your breath gently";
    }
  }
}
