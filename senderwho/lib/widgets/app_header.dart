import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.action,
    this.onBack,
  });

  final String title;
  final String? subtitle;

  /// Main destinations keep this false and expose the navigation menu.
  /// Detail and subflow screens opt in so Back always returns to their parent.
  final bool showBack;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: subtitle == null ? 44 : 52),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 58),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  key: const ValueKey('app-header-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    key: const ValueKey('app-header-subtitle'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: HeaderIconButton(
              icon: showBack ? Icons.arrow_back_rounded : Icons.menu_rounded,
              tooltip: showBack ? 'Back' : 'Open menu',
              onPressed: showBack
                  ? onBack ?? () => Navigator.maybePop(context)
                  : () => Scaffold.of(context).openDrawer(),
            ),
          ),
          if (action != null)
            Align(alignment: Alignment.topRight, child: action!),
        ],
      ),
    );
  }
}

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFor(context),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.elevatedSurface(context),
          side: BorderSide(
            color: AppColors.borderFor(context).withValues(alpha: 0.58),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 21, color: AppColors.textFor(context)),
      ),
    );
  }
}
