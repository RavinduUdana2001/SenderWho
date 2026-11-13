import 'package:flutter/material.dart';

import '../screens/all_senders_screen.dart';
import '../screens/bulk_clean_screen.dart';
import '../screens/unsubscribe_screen.dart';
import '../screens/emails_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../services/repository_scope.dart';
import '../utils/app_navigation.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({super.key});

  static const _destinations =
      <({String label, IconData icon, IconData selectedIcon, String route})>[
        (
          label: 'Senders',
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_alt_rounded,
          route: '/all-senders',
        ),
        (
          label: 'Inbox',
          icon: Icons.mail_outline_rounded,
          selectedIcon: Icons.mail_rounded,
          route: '/emails',
        ),
        (
          label: 'Unsubscribe',
          icon: Icons.unsubscribe_outlined,
          selectedIcon: Icons.unsubscribe_rounded,
          route: '/unsubscribe',
        ),
        (
          label: 'Clean',
          icon: Icons.cleaning_services_outlined,
          selectedIcon: Icons.cleaning_services_rounded,
          route: '/bulk-clean',
        ),
      ];

  Widget _pageFor(BuildContext context, String route) => switch (route) {
    '/unsubscribe' => UnsubscribeScreen(
      repository: RepositoryScope.read(context),
    ),
    '/emails' => EmailsScreen(repository: RepositoryScope.read(context)),
    '/all-senders' => AllSendersScreen(
      repository: RepositoryScope.read(context),
    ),
    '/bulk-clean' => BulkCleanScreen(repository: RepositoryScope.read(context)),
    _ => AllSendersScreen(repository: RepositoryScope.read(context)),
  };

  int _selectedIndex(String? route) {
    if (route == '/unsubscribe') return 2;
    if (route == '/emails' || route == '/email-details') return 1;
    if ({
      '/all-senders',
      '/sender-details',
      '/categories',
      '/top-senders',
      '/search-filter',
    }.contains(route)) {
      return 0;
    }
    if ({
      '/bulk-clean',
      '/delete-emails',
      '/review-promotions',
    }.contains(route)) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == null || currentRoute == '/') {
      return const SizedBox.shrink();
    }
    final observer = Navigator.of(
      context,
    ).widget.observers.whereType<AppNavigationObserver>().firstOrNull;
    final utilityPage = {
      '/settings',
      '/privacy-security',
      '/profile',
      '/connected-accounts',
      '/dashboard',
      '/activity',
      '/security-alerts',
      '/alert-details',
      '/inbox-health',
    }.contains(currentRoute);
    final selectedIndex = _selectedIndex(
      utilityPage ? observer?.lastMailboxRoute ?? currentRoute : currentRoute,
    );
    final isDark = AppColors.isDark(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(
          top: BorderSide(
            color: AppColors.borderFor(
              context,
            ).withValues(alpha: isDark ? 0.55 : 0.45),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (index) {
              final destination = _destinations[index];
              AppNavigation.open(
                context,
                destination.route,
                builder: (context) => _pageFor(context, destination.route),
              );
            },
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: _SelectedDestinationIcon(
                    icon: destination.selectedIcon,
                  ),
                  label: destination.label,
                  tooltip: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDestinationIcon extends StatelessWidget {
  const _SelectedDestinationIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.84, end: 1),
      duration: AppMotion.responsive(context, AppMotion.fast),
      curve: AppMotion.enter,
      child: Icon(icon),
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
    );
  }
}
