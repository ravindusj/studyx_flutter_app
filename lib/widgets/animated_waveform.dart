import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedWaveform extends StatefulWidget {
  final bool isPlaying;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final int barCount;
  final double height;
  
  const AnimatedWaveform({
    Key? key,
    required this.isPlaying,
    required this.progress,
    this.activeColor = Colors.blue,
    this.inactiveColor = Colors.grey,
    this.barCount = 27,
    this.height = 20,
  }) : super(key: key);

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<double> _barHeights;
  final Random _random = Random(42);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _generateBarHeights();
    
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reset();
        _animationController.forward();
      }
    });
    
    if (widget.isPlaying) {
      _animationController.forward();
    }
  }
  
  @override
  void didUpdateWidget(AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _animationController.reset();
        _animationController.forward();
      } else {
        _animationController.stop();
      }
    }
    
    if (widget.barCount != oldWidget.barCount) {
      _generateBarHeights();
    }
  }
  
  void _generateBarHeights() {
    _barHeights = List.generate(widget.barCount, (index) {
      return 0.3 + 0.7 * (0.5 + 0.5 * sin(index / 2.5)) * 
             (0.5 + _random.nextDouble() * 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _WaveformPainter(
            barCount: widget.barCount,
            barHeights: _barHeights,
            progress: widget.progress,
            activeColor: widget.activeColor,
            inactiveColor: widget.inactiveColor,
            animationValue: _animationController.value,
            isPlaying: widget.isPlaying,
          ),
        );
      },
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

class _WaveformPainter extends CustomPainter {
  final int barCount;
  final List<double> barHeights;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final double animationValue;
  final bool isPlaying;
  
  const _WaveformPainter({
    required this.barCount,
    required this.barHeights,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.animationValue,
    required this.isPlaying,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final barWidth = 2.0;
    final spacing = (width - barWidth * barCount) / (barCount - 1);
    
    for (int i = 0; i < barCount; i++) {
      final isActive = i / barCount <= progress;
      
      double heightPercent = barHeights[i];
      
      if (isPlaying && isActive) {
        final animationOffset = sin(
          (animationValue * 2 * pi) + (i / barCount * pi)
        ) * 0.2;
        
        heightPercent = (heightPercent + animationOffset).clamp(0.2, 1.0);
      }
      
      final left = i * (barWidth + spacing);
      final barHeight = height * heightPercent;
      final top = (height - barHeight) / 2;
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(1),
      );
      
      canvas.drawRRect(
        rect,
        Paint()..color = isActive ? activeColor : inactiveColor,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.isPlaying != isPlaying;
  }
}
