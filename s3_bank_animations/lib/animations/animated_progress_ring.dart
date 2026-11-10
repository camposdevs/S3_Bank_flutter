import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Anel de progresso que preenche de 0 até `progress` (0..1).
/// Pode substituir/ envolver o seu GoalProgressRing.
class AnimatedProgressRing extends StatelessWidget {
  const AnimatedProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.trackColor,
    this.size = 96,
    this.strokeWidth = 10,
    this.duration = const Duration(milliseconds: 1000),
    this.child,
  });

  final double progress;
  final Color color;
  final Color? trackColor;
  final double size;
  final double strokeWidth;
  final Duration duration;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final track = trackColor ?? color.withAlpha(40);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, child) => CustomPaint(
        painter: _RingPainter(value, color, track, strokeWidth),
        child: SizedBox(width: size, height: size, child: Center(child: child)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color, this.track, this.stroke);
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = track);
    canvas.drawArc(
        rect, -math.pi / 2, math.pi * 2 * value, false, base..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.stroke != stroke;
}
