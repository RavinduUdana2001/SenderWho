import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class AppAnimatedProgressRing extends StatelessWidget {
  const AppAnimatedProgressRing({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.size,
    this.gradient,
    this.strokeWidth = 6,
    this.duration = const Duration(milliseconds: 760),
    this.child,
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double size;
  final Gradient? gradient;
  final double strokeWidth;
  final Duration duration;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: AppMotion.responsive(context, duration),
      curve: AppMotion.emphasized,
      builder: (context, progress, child) => SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (gradient == null)
              CircularProgressIndicator(
                value: progress,
                strokeWidth: strokeWidth,
                backgroundColor: backgroundColor,
                color: color,
                strokeCap: StrokeCap.round,
              )
            else
              CustomPaint(
                painter: _GradientProgressRingPainter(
                  progress: progress,
                  strokeWidth: strokeWidth,
                  backgroundColor: backgroundColor,
                  gradient: gradient!,
                ),
              ),
            if (child != null) Center(child: child),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _GradientProgressRingPainter extends CustomPainter {
  const _GradientProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.gradient,
  });

  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;
    final progressPaint = Paint()
      ..shader = gradient.createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.gradient != gradient;
  }
}

class AppAnimatedProgressBar extends StatelessWidget {
  const AppAnimatedProgressBar({
    super.key,
    required this.value,
    required this.color,
    required this.backgroundColor,
    this.height = 6,
    this.duration = const Duration(milliseconds: 720),
  });

  final double value;
  final Color color;
  final Color backgroundColor;
  final double height;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: AppMotion.responsive(context, duration),
        curve: AppMotion.emphasized,
        builder: (context, progress, _) => LinearProgressIndicator(
          minHeight: height,
          value: progress,
          color: color,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class AppAnimatedCount extends StatelessWidget {
  const AppAnimatedCount({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 620),
  });

  final int value;
  final String Function(int value) formatter;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: AppMotion.responsive(context, duration),
      curve: AppMotion.enter,
      builder: (context, animatedValue, _) => Text(
        formatter(animatedValue.round()),
        maxLines: 1,
        overflow: TextOverflow.fade,
        style: style,
      ),
    );
  }
}
