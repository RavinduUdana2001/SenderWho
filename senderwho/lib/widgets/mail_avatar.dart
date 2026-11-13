import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shows a supplied profile photo with stable initials while loading or offline.
class MailAvatar extends StatelessWidget {
  const MailAvatar({
    super.key,
    required this.name,
    this.size = 42,
    this.badge,
    this.label,
    this.imageUrl,
  });

  final String name;
  final double size;
  final Widget? badge;
  final String? label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF52C6DE),
      Color(0xFFB9CF65),
      Color(0xFFDDA5CE),
      Color(0xFFB69BE3),
      Color(0xFF88C5B3),
      Color(0xFFF0BB86),
    ];
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? '?'
        : words
              .take(2)
              .map((word) => word.characters.first)
              .join()
              .toUpperCase();
    final color =
        colors[name.toLowerCase().runes.fold<int>(0, (a, b) => a + b) %
            colors.length];
    return Semantics(
      image: true,
      label: label ?? name,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: size / 2,
              backgroundColor: color,
              child: Text(
                initials,
                style: TextStyle(
                  color: AppColors.brandNavy,
                  fontSize: size * .33,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (imageUrl != null)
              Positioned.fill(
                child: ClipOval(
                  child: Image.network(
                    imageUrl!,
                    key: ValueKey(imageUrl),
                    fit: BoxFit.cover,
                    gaplessPlayback: false,
                    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
                    cacheHeight: (size * MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
                    frameBuilder: (context, child, frame, synchronous) =>
                        AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 160),
                          child: child,
                        ),
                    errorBuilder: (_, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ),
            if (badge != null)
              Positioned(
                right: -2,
                bottom: -1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.pageBackground(context),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: badge!,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
