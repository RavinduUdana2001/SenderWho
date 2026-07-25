import 'package:flutter/material.dart';

import '../screens/all_senders_screen.dart';
import '../screens/bulk_clean_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/emails_screen.dart';
import '../theme/app_colors.dart';

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
            ).withValues(alpha: isDark ? 0.65 : 0.85),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFor(context),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var index = 0; index < _destinations.length; index++)
                  Expanded(
                    child: _NavigationItem(
                      label: _destinations[index].label,
                      icon: _destinations[index].icon,
                      selectedIcon: _destinations[index].selectedIcon,
                      selected: selectedIndex == index,
                      onTap: () {
                        final destination = _destinations[index];
                        if (currentRoute == destination.route) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          PageRouteBuilder<void>(
                            settings: RouteSettings(name: destination.route),
                            transitionDuration: Duration.zero,
                            reverseTransitionDuration: Duration.zero,
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    _pageFor(destination.route),
                          ),
                          (_) => false,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedFor(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 42,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.softFill(context, AppColors.primary)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 21,
                  color: selected ? AppColors.primary : muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? AppColors.primary : muted,
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
