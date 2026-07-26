import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/activity_insights_screen.dart';
import '../screens/all_senders_screen.dart';
import '../screens/bulk_clean_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/emails_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_filter_screen.dart';
import '../screens/security_alerts_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/top_senders_screen.dart';
import '../screens/unsubscribe_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../theme/theme_mode_controller.dart';
import 'senderwho_brand.dart';

class SenderDrawer extends StatelessWidget {
  const SenderDrawer({super.key, this.onSignOut});

  final Future<void> Function()? onSignOut;

  static const _items = [
    NavItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: DashboardScreen.routeName,
    ),
    NavItem(
      title: 'All Senders',
      icon: Icons.people_alt_outlined,
      route: AllSendersScreen.routeName,
    ),
    NavItem(
      title: 'Email Inbox',
      icon: Icons.inbox_outlined,
      route: EmailsScreen.routeName,
    ),
    NavItem(
      title: 'Categories',
      icon: Icons.layers_outlined,
      route: CategoriesScreen.routeName,
    ),
    NavItem(
      title: 'Bulk clean',
      icon: Icons.cleaning_services_outlined,
      route: BulkCleanScreen.routeName,
    ),
    NavItem(
      title: 'Unsubscribe',
      icon: Icons.block_outlined,
      route: UnsubscribeScreen.routeName,
    ),
    NavItem(
      title: 'Search / Filter',
      icon: Icons.tune_rounded,
      route: SearchFilterScreen.routeName,
    ),
    NavItem(
      title: 'Top Senders',
      icon: Icons.bar_chart_rounded,
      route: TopSendersScreen.routeName,
    ),
    NavItem(
      title: 'Activity',
      icon: Icons.insights_outlined,
      route: ActivityInsightsScreen.routeName,
    ),
    NavItem(
      title: 'Security Alerts',
      icon: Icons.warning_amber_rounded,
      route: SecurityAlertsScreen.routeName,
    ),
    NavItem(
      title: 'Settings',
      icon: Icons.settings_outlined,
      route: SettingsScreen.routeName,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    return Drawer(
      width: MediaQuery.sizeOf(context).width.clamp(0, 326).toDouble(),
      backgroundColor: AppColors.pageBackground(context),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: ColoredBox(
        color: AppColors.pageBackground(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(
                          'assets/branding/senderwho_app_icon_master.png',
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          semanticLabel: 'SenderWho',
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SenderWhoWordmark(fontSize: 22),
                          const SizedBox(height: 5),
                          const SenderWhoTagline(),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close menu',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _DrawerAccountControls(
                  profileSelected: currentRoute == ProfileScreen.routeName,
                ),
                const SizedBox(height: 19),
                Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 8),
                  child: Text(
                    'WORKSPACE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 8),
                      clipBehavior: Clip.hardEdge,
                      itemCount: _items.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 3),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _DrawerTile(
                          item: item,
                          selected:
                              currentRoute == item.route ||
                              ((currentRoute == null || currentRoute == '/') &&
                                  item.route == DashboardScreen.routeName),
                        );
                      },
                    ),
                  ),
                ),
                _SignOutTile(
                  onSignOut: onSignOut ?? senderWhoRepository.logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignOutTile extends StatefulWidget {
  const _SignOutTile({required this.onSignOut});

  final Future<void> Function() onSignOut;

  @override
  State<_SignOutTile> createState() => _SignOutTileState();
}

class _SignOutTileState extends State<_SignOutTile> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of SenderWho?'),
        content: const Text(
          'This signs out this device only. Your email connection stays linked, so returning users normally will not need to grant access again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const ValueKey('drawer-sign-out'),
      enabled: !_signingOut,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _signingOut
            ? const SizedBox.square(
                key: ValueKey('sign-out-loader'),
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : const Icon(
                Icons.logout_rounded,
                key: ValueKey('sign-out-icon'),
                color: AppColors.danger,
                size: 20,
              ),
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Text(
          _signingOut ? 'Signing out…' : 'Sign out',
          key: ValueKey(_signingOut ? 'signing-out-label' : 'sign-out-label'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: _signingOut ? AppColors.mutedFor(context) : AppColors.danger,
          ),
        ),
      ),
      onTap: _signingOut ? null : _signOut,
    );
  }
}

class _DrawerAccountControls extends StatelessWidget {
  const _DrawerAccountControls({required this.profileSelected});

  final bool profileSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const ValueKey('drawer-profile-button'),
              borderRadius: BorderRadius.circular(13),
              onTap: () => _openRootDestination(
                context,
                ProfileScreen.routeName,
                selected: profileSelected,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: profileSelected
                            ? AppColors.primary
                            : AppColors.softFill(context, AppColors.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: profileSelected
                            ? Colors.white
                            : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Account details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 7),
            color: AppColors.borderFor(context),
          ),
          const _DrawerThemeToggle(),
        ],
      ),
    );
  }
}

class _DrawerThemeToggle extends StatefulWidget {
  const _DrawerThemeToggle();

  @override
  State<_DrawerThemeToggle> createState() => _DrawerThemeToggleState();
}

class _DrawerThemeToggleState extends State<_DrawerThemeToggle> {
  bool _saving = false;

  Future<void> _setDarkMode(bool enabled) async {
    if (_saving) return;
    final controller = ThemeModeController.of(context);
    controller.setDarkMode(enabled);
    if (!senderWhoRepository.isAuthenticated) return;

    setState(() => _saving = true);
    final saved = await senderWhoRepository.updatePreferences(
      theme: enabled ? 'Dark' : 'Light',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) return;

    controller.setDarkMode(!enabled);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save the theme preference.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDark ? Icons.dark_mode_rounded : Icons.light_mode_outlined,
          color: AppColors.primary,
          size: 19,
        ),
        Tooltip(
          message: isDark ? 'Use light mode' : 'Use dark mode',
          child: Switch(
            key: const ValueKey('drawer-dark-mode-switch'),
            value: isDark,
            onChanged: _saving ? null : _setDarkMode,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: AppColors.mutedFor(context),
            inactiveTrackColor: AppColors.trackFor(context),
            trackOutlineColor: WidgetStatePropertyAll(
              AppColors.borderFor(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({required this.item, required this.selected});

  final NavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.softFill(context, AppColors.primary),
      selectedColor: AppColors.primary,
      dense: true,
      minLeadingWidth: 20,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      hoverColor: AppColors.softFill(context, AppColors.primary),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.softFill(context, AppColors.primary),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          item.icon,
          size: 17,
          color: selected ? Colors.white : AppColors.primary,
        ),
      ),
      title: Text(
        item.title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: selected ? AppColors.primary : AppColors.mutedFor(context),
      ),
      onTap: () {
        _openRootDestination(context, item.route, selected: selected);
      },
    );
  }
}

void _openRootDestination(
  BuildContext context,
  String route, {
  required bool selected,
}) {
  final navigator = Navigator.of(context);
  navigator.pop();
  if (selected) return;
  navigator.pushNamedAndRemoveUntil(route, (_) => false);
}
