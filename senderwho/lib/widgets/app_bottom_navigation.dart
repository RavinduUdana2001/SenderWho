import 'package:flutter/material.dart';

import '../screens/all_senders_screen.dart';
import '../screens/bulk_clean_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/emails_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({super.key});

  static const _destinations =
      <({String label, IconData icon, IconData selectedIcon, String route})>[
        (
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          route: '/dashboard',
        ),
        (
          label: 'Inbox',
          icon: Icons.mail_outline_rounded,
          selectedIcon: Icons.mail_rounded,
          route: '/emails',
        ),
        (
          label: 'Senders',
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_alt_rounded,
          route: '/all-senders',
        ),
        (
          label: 'Clean',
          icon: Icons.cleaning_services_outlined,
          selectedIcon: Icons.cleaning_services_rounded,
          route: '/bulk-clean',
        ),
      ];

  Widget _pageFor(String route) => switch (route) {
    '/dashboard' => const DashboardScreen(),
    '/emails' => const EmailsScreen(),
    '/all-senders' => const AllSendersScreen(),
    '/bulk-clean' => const BulkCleanScreen(),
    _ => const DashboardScreen(),
  };

  int _selectedIndex(String? route) {
    if (route == null || route == '/' || route == '/dashboard') return 0;
    if (route == '/emails' || route == '/email-details') return 1;
    if ({
      '/all-senders',
      '/sender-details',
      '/categories',
      '/top-senders',
      '/search-filter',
    }.contains(route)) {
      return 2;
    }
    if ({
      '/bulk-clean',
      '/delete-emails',
      '/review-promotions',
      '/unsubscribe',
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
    final selectedIndex = _selectedIndex(currentRoute);
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
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFor(context),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
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
              if (currentRoute == destination.route) return;
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder<void>(
                  settings: RouteSettings(name: destination.route),
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      _pageFor(destination.route),
                ),
                (_) => false,
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
