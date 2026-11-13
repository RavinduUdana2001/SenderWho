import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../utils/app_navigation.dart';
import '../utils/mailbox_identity.dart';
import 'mail_avatar.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack,
    this.action,
    this.onBack,
    this.onTitleTap,
  });

  final String title;
  final String? subtitle;
  final bool? showBack;
  final Widget? action;
  final VoidCallback? onBack;
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) {
    final repository = RepositoryScope.read(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        repository.userProfile,
        repository.connectedAccounts,
        repository.activeMailbox,
      ]),
      builder: (context, _) {
        final identity = MailboxIdentity.resolve(
          mailbox: repository.activeMailbox.value,
          profile: repository.userProfile.value,
          userEmail: repository.userEmail,
        );
        // A popup or drawer must not change the page's Back button.
        final route = ModalRoute.of(context);
        final primaryTab =
            AppNavigation.primaryRoutes.contains(route?.settings.name) &&
            route?.settings.arguments == null &&
            showBack != true;
        final canPop = route?.isFirst == false;
        final visibleSubtitle = primaryTab ? null : subtitle;
        final back =
            !primaryTab &&
            showBack != false &&
            canPop &&
            (showBack == true ||
                AppNavigation.detailRoutes.contains(route?.settings.name) ||
                (AppNavigation.primaryRoutes.contains(route?.settings.name) &&
                    route?.settings.arguments != null));
        final accountButton = Hero(
          tag: 'profile-and-accounts',
          transitionOnUserGestures: true,
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              label: 'Profile and accounts, ${identity.email ?? identity.name}',
              hint: 'Open your profile and account menu',
              child: IconButton(
                key: const ValueKey('profile-account-button'),
                tooltip: 'Open menu',
                padding: const EdgeInsets.all(4),
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: MailAvatar(
                  key: ValueKey('header-avatar-${identity.email}'),
                  name: identity.name,
                  label: identity.email ?? identity.name,
                  imageUrl: identity.avatarUrl,
                  size: 34,
                  badge: Icon(
                    Icons.person_rounded,
                    size: 11,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final stackActions =
                action != null &&
                action is! IconButton &&
                !(action is Row &&
                    (action! as Row).children.every(
                      (child) => child is IconButton,
                    )) &&
                ((constraints.maxWidth < 340 && !primaryTab) ||
                    (primaryTab &&
                        action is Row &&
                        (action! as Row).children.any(
                          (child) => child is TextButton,
                        ) &&
                        constraints.maxWidth < 500) ||
                    (constraints.maxWidth < 400 &&
                        MediaQuery.textScalerOf(context).scale(14) > 16));
            if (primaryTab) {
              final titleStyle = Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);
              final height = math.max(
                48.0,
                MediaQuery.textScalerOf(
                      context,
                    ).scale(titleStyle?.fontSize ?? 21) *
                    (titleStyle?.height ?? 1.4),
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: height,
                      child: CustomMultiChildLayout(
                        delegate: _CenteredHeaderLayout(
                          Directionality.of(context),
                        ),
                        children: [
                          LayoutId(id: 'profile', child: accountButton),
                          if (!stackActions && action != null)
                            LayoutId(id: 'actions', child: action!),
                          LayoutId(
                            id: 'title',
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: InkWell(
                                onTap: onTitleTap,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (onTitleTap != null)
                                      const SizedBox(width: 19),
                                    Flexible(
                                      child: Text(
                                        title,
                                        key: const ValueKey('app-header-title'),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: titleStyle,
                                      ),
                                    ),
                                    if (onTitleTap != null)
                                      const Icon(
                                        Icons.expand_more_rounded,
                                        size: 19,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (stackActions)
                      Align(alignment: Alignment.centerRight, child: action!),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The account button always owns the first slot, including
                      // detail pages and narrow screens. Back has its own slot.
                      accountButton,
                      if (back)
                        FadeTransition(
                          // Keep the Back slot still while its icon enters.
                          // This also follows a native interactive Back gesture.
                          opacity: MediaQuery.disableAnimationsOf(context)
                              ? const AlwaysStoppedAnimation(1.0)
                              : (route?.animation ??
                                        const AlwaysStoppedAnimation(1.0))
                                    .drive(
                                      CurveTween(curve: Curves.easeOutCubic),
                                    ),
                          child: HeaderIconButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Back',
                            onPressed:
                                onBack ?? () => Navigator.maybePop(context),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: onTitleTap,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        title,
                                        key: const ValueKey('app-header-title'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    if (onTitleTap != null)
                                      const Icon(
                                        Icons.expand_more_rounded,
                                        size: 19,
                                      ),
                                  ],
                                ),
                              ),
                              if (visibleSubtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  visibleSubtitle,
                                  key: const ValueKey('app-header-subtitle'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (!stackActions && action != null) action!,
                    ],
                  ),
                  if (stackActions)
                    Align(alignment: Alignment.centerRight, child: action!),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Equal clearance on both sides keeps the title at the app bar's center,
/// even when the action group is wider than the profile button.
class _CenteredHeaderLayout extends MultiChildLayoutDelegate {
  _CenteredHeaderLayout(this.direction);
  final TextDirection direction;

  @override
  void performLayout(Size size) {
    final constraints = BoxConstraints.loose(size);
    final profile = layoutChild('profile', constraints);
    final actions = hasChild('actions')
        ? layoutChild('actions', constraints)
        : Size.zero;
    final inset = math.max(profile.width, actions.width) + 8;
    final title = layoutChild(
      'title',
      BoxConstraints(
        maxWidth: math.max(0, size.width - inset * 2),
        maxHeight: size.height,
      ),
    );
    final rtl = direction == TextDirection.rtl;
    positionChild('profile', Offset(rtl ? size.width - profile.width : 0, 0));
    if (hasChild('actions')) {
      positionChild('actions', Offset(rtl ? 0 : size.width - actions.width, 0));
    }
    positionChild(
      'title',
      Offset((size.width - title.width) / 2, (size.height - title.height) / 2),
    );
  }

  @override
  bool shouldRelayout(_CenteredHeaderLayout oldDelegate) =>
      direction != oldDelegate.direction;
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
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 24, color: AppColors.textFor(context)),
  );
}
