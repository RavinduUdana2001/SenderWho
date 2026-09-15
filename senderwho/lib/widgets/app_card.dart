import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';

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
    this.showBorder = true,
    this.radius = AppRadii.md,
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
    final isDark = AppColors.isDark(context);
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
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: widget.elevated
                ? [
                    BoxShadow(
                      color: AppColors.shadowFor(context),
                      blurRadius: isDark ? 18 : 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: widget.color ?? AppColors.surface(context),
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: widget.showBorder
                  ? BorderSide(
                      color:
                          widget.borderColor ??
                          AppColors.borderFor(
                            context,
                          ).withValues(alpha: isDark ? 0.62 : 0.76),
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

/// A restrained brand surface for one high-priority card per screen.
/// Keeping this shared prevents decorative gradients from becoming visual
/// noise or diverging between light and dark mode.
class AppGradientCard extends StatefulWidget {
  const AppGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.radius = AppRadii.lg,
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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final useSolidSurface = isDark && widget.solidInDark;
    final radius = BorderRadius.circular(widget.radius);
    return Semantics(
      container: true,
      button: widget.onTap != null,
      child: AnimatedScale(
        scale: _pressed ? 0.992 : 1,
        duration: AppMotion.responsive(context, AppMotion.fast),
        curve: AppMotion.enter,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: useSolidSurface
                    ? AppColors.shadowFor(context)
                    : AppColors.brandBlue.withValues(
                        alpha: isDark ? 0.12 : 0.065,
                      ),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: useSolidSurface ? AppColors.darkElevatedCard : null,
                gradient: useSolidSurface
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: AppColors.brandGradientFor(context),
                      ),
                border: Border.all(
                  color: useSolidSurface
                      ? AppColors.darkBorder.withValues(alpha: 0.9)
                      : (isDark ? AppColors.onBrand : AppColors.brandBlue)
                            .withValues(alpha: 0.14),
                ),
              ),
              child: Stack(
                children: [
                  if (!useSolidSurface)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topRight,
                            radius: 1.15,
                            colors: [
                              AppColors.visualAccentFor(
                                context,
                                AppColors.cyan,
                              ).withValues(alpha: isDark ? 0.1 : 0.075),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: widget.onTap,
                    onHighlightChanged: widget.onTap == null
                        ? null
                        : (pressed) => setState(() => _pressed = pressed),
                    child: Padding(
                      padding: widget.padding,
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
