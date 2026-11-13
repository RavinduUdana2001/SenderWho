import 'package:flutter/material.dart';
import '../theme/app_motion.dart';

/// A single, subtle entrance. Reduced-motion preferences disable it.
class EntryReveal extends StatelessWidget {
  const EntryReveal({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.responsive(context, AppMotion.deliberate),
    curve: AppMotion.enter,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 10 * (1 - value)),
        child: child,
      ),
    ),
  );
}
