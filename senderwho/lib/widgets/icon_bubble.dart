import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.icon,
    this.size = 35,
    this.iconSize = 20,
    this.color = AppColors.primary,
    this.backgroundColor,
    this.label,
    this.labelColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color? backgroundColor;
  final String? label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final fill = backgroundColor ?? AppColors.softFill(context, color);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: label == null
          ? Icon(icon, color: color, size: iconSize)
          : Text(
              label!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: labelColor ?? Colors.white,
                fontSize: iconSize * 0.75,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
