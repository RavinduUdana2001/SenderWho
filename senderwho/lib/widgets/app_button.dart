import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
    this.height = 54,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final useGradient = backgroundColor == AppColors.primary;
    final effectiveBackground = backgroundColor == AppColors.subtle
        ? AppColors.trackFor(context)
        : backgroundColor;
    final effectiveForeground = foregroundColor == AppColors.muted
        ? AppColors.mutedFor(context)
        : foregroundColor;
    final effectiveOnPressed = loading ? null : onPressed;
    final progressColor = useGradient ? Colors.white : effectiveForeground;
    final labelContent = icon == null
        ? Text(label, key: const ValueKey('app-button-label'))
        : Row(
            key: const ValueKey('app-button-label'),
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final child = AnimatedSwitcher(
      duration: AppMotion.responsive(context, AppMotion.fast),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      child: loading
          ? SizedBox(
              key: const ValueKey('app-button-progress'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: progressColor,
              ),
            )
          : labelContent,
    );

    if (useGradient) {
      return Semantics(
        button: true,
        label: label,
        value: loading ? 'In progress' : null,
        excludeSemantics: true,
        enabled: effectiveOnPressed != null,
        child: AnimatedOpacity(
          opacity: effectiveOnPressed == null ? 0.5 : 1,
          duration: AppMotion.responsive(context, AppMotion.fast),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: effectiveOnPressed,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: AppColors.brandGradient,
                    ),
                    boxShadow: effectiveOnPressed == null
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.24),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Center(
                    child: DefaultTextStyle(
                      style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                      child: IconTheme(
                        data: const IconThemeData(color: Colors.white),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: label,
      value: loading ? 'In progress' : null,
      excludeSemantics: true,
      enabled: effectiveOnPressed != null,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: FilledButton(
          onPressed: effectiveOnPressed,
          style: FilledButton.styleFrom(
            backgroundColor: effectiveBackground,
            foregroundColor: effectiveForeground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
