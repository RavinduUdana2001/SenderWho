import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// A consistent primary action that also grows for larger accessibility text.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
    this.height = 50,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor, foregroundColor;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = backgroundColor == AppColors.primary;
    final danger = backgroundColor == AppColors.danger;
    final background = primary
        ? scheme.primary
        : danger
        ? scheme.error
        : backgroundColor == AppColors.subtle
        ? AppColors.trackFor(context)
        : backgroundColor;
    final foreground = foregroundColor == Colors.white && primary
        ? scheme.onPrimary
        : foregroundColor == Colors.white && danger
        ? scheme.onError
        : foregroundColor == AppColors.muted
        ? AppColors.mutedFor(context)
        : foregroundColor;
    return Semantics(
      button: true,
      enabled: onPressed != null && !loading,
      label: label,
      value: loading ? 'In progress' : null,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: loading ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              minimumSize: Size(48, height),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.responsive(context, AppMotion.fast),
              child: loading
                  ? SizedBox.square(
                      key: const ValueKey('app-button-progress'),
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Row(
                      key: const ValueKey('app-button-label'),
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(label, textAlign: TextAlign.center),
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
