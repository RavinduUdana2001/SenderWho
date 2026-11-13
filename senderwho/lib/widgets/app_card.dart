import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.elevated = false,
    this.showBorder = false,
    this.radius = 8,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final bool elevated;
  final bool showBorder;
  final double radius;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    final interactive = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      container: true,
      button: widget.onTap != null,
      child: AnimatedScale(
        scale: interactive && _pressed ? 0.992 : 1,
        duration: AppMotion.responsive(context, AppMotion.fast),
        curve: AppMotion.enter,
        child: Container(
          margin: widget.margin,
          decoration: BoxDecoration(borderRadius: radius),
          child: Material(
            color: widget.color ?? AppColors.pageBackground(context),
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: widget.showBorder
                  ? BorderSide(
                      color: widget.borderColor ?? AppColors.borderFor(context),
                    )
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onHighlightChanged: interactive
                  ? (pressed) => setState(() => _pressed = pressed)
                  : null,
              hoverColor: AppColors.primaryFor(context).withValues(alpha: 0.05),
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet flat panel shared by overview and account screens.
class AppGradientCard extends StatefulWidget {
  const AppGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = 8,
    this.solidInDark = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool solidInDark;

  @override
  State<AppGradientCard> createState() => _AppGradientCardState();
}

class _AppGradientCardState extends State<AppGradientCard> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.elevatedSurface(context),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
  }
}
