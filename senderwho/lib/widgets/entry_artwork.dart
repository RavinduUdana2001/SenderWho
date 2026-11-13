import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'senderwho_brand.dart';

/// Lightweight artwork: no blur layers, network assets, or looping animation.
class EntryBackdrop extends StatelessWidget {
  const EntryBackdrop({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF101218) : const Color(0xFFFAF9FD),
        gradient: RadialGradient(
          center: const Alignment(.85, -.8),
          radius: 1.35,
          colors: dark
              ? const [Color(0xFF272039), Color(0xFF101218)]
              : const [Color(0xFFEDE6FB), Color(0xFFFAF9FD)],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class EntryBrandScene extends StatelessWidget {
  const EntryBrandScene({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 280,
      height: 216,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _OrbitPainter(scheme.primary)),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: scheme.primary.withValues(alpha: .12)),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: .12),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: const SenderWhoLogo(
              key: ValueKey('onboarding-brand-icon'),
              size: 112,
            ),
          ),
          Positioned(
            left: 7,
            top: 31,
            child: _FloatingMark(
              icon: Icons.person_outline_rounded,
              color: scheme.primary,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 26,
            child: _FloatingMark(
              icon: Icons.done_all_rounded,
              color: AppColors.foregroundFor(context, AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingMark extends StatelessWidget {
  const _FloatingMark({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 25, color: color),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in [86.0, 104.0]) {
      paint.color = color.withValues(alpha: radius == 86 ? .13 : .07);
      canvas.drawCircle(center, radius, paint);
    }
    paint.style = PaintingStyle.fill;
    for (final angle in [-.75, 1.95, 3.05]) {
      final p = center + Offset(math.cos(angle), math.sin(angle)) * 104;
      paint.color = color.withValues(alpha: .35);
      canvas.drawCircle(p, 3, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => oldDelegate.color != color;
}

class EntryPrimaryButton extends StatelessWidget {
  const EntryPrimaryButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, AppColors.brandCyan, .24)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(double.infinity, 58),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Row(
          children: [
            Expanded(child: Text('Connect my inbox')),
            SizedBox(width: 12),
            Icon(Icons.arrow_forward_rounded, size: 21),
          ],
        ),
      ),
    );
  }
}
