import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/activity_insights_screen.dart';
import '../screens/all_senders_screen.dart';
import '../screens/bulk_clean_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/connected_accounts_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/emails_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/security_alerts_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/unsubscribe_screen.dart';
import '../services/repository_scope.dart';
import '../utils/app_navigation.dart';
import '../utils/mailbox_identity.dart';
import '../theme/app_colors.dart';
import '../theme/theme_mode_controller.dart';
import 'mail_avatar.dart';

class SenderDrawer extends StatelessWidget {
  const SenderDrawer({super.key, this.onSignOut});
  final Future<void> Function()? onSignOut;

  static const _mail = [
    NavItem(
      title: 'All Senders',
      icon: Icons.people_outline_rounded,
      route: AllSendersScreen.routeName,
    ),
    NavItem(
      title: 'Email Inbox',
      icon: Icons.inbox_outlined,
      route: EmailsScreen.routeName,
    ),
  ];
  static const _account = [
    NavItem(
      title: 'Add another mailbox',
      icon: Icons.add_rounded,
      route: ConnectedAccountsScreen.routeName,
      arguments: ConnectedAccountsArguments(addMailbox: true),
    ),
    NavItem(
      title: 'Manage accounts',
      icon: Icons.person_outline_rounded,
      route: ConnectedAccountsScreen.routeName,
    ),
    NavItem(
      title: 'Settings',
      icon: Icons.settings_outlined,
      route: SettingsScreen.routeName,
    ),
    NavItem(
      title: 'Security Alerts',
      icon: Icons.shield_outlined,
      route: SecurityAlertsScreen.routeName,
    ),
  ];
  static const _tools = [
    NavItem(
      title: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: DashboardScreen.routeName,
    ),
    NavItem(
      title: 'Bulk clean',
      icon: Icons.cleaning_services_outlined,
      route: BulkCleanScreen.routeName,
    ),
    NavItem(
      title: 'Unsubscribe',
      icon: Icons.unsubscribe_outlined,
      route: UnsubscribeScreen.routeName,
    ),
    NavItem(
      title: 'Categories',
      icon: Icons.layers_outlined,
      route: CategoriesScreen.routeName,
    ),
    NavItem(
      title: 'Activity',
      icon: Icons.insights_outlined,
      route: ActivityInsightsScreen.routeName,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final surface = AppColors.isDark(context)
        ? AppColors.darkElevatedCard
        : AppColors.elevatedCard;
    return Drawer(
      width: (MediaQuery.sizeOf(context).width * .82).clamp(0, 312).toDouble(),
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Accounts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const _DrawerAccountSection(),
                  const Divider(height: 1),
                  for (final item in _mail)
                    _DrawerTile(
                      item: item,
                      selected:
                          currentRoute == item.route &&
                          item.arguments == null &&
                          ModalRoute.of(context)?.settings.arguments == null,
                    ),
                  const Divider(height: 16),
                  for (final item in _account)
                    _DrawerTile(
                      item: item,
                      selected:
                          currentRoute == item.route &&
                          item.arguments == null &&
                          ModalRoute.of(context)?.settings.arguments == null,
                    ),
                  const ListTile(
                    leading: Icon(Icons.dark_mode_outlined),
                    title: Text('Dark mode'),
                    trailing: _DrawerThemeToggle(),
                  ),
                  const Divider(height: 16),
                  ExpansionTile(
                    key: const ValueKey('drawer-more-tools'),
                    leading: const Icon(Icons.more_horiz_rounded),
                    title: const Text('More tools'),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final item in _tools)
                        _DrawerTile(
                          item: item,
                          selected:
                              currentRoute == item.route &&
                              item.arguments == null &&
                              ModalRoute.of(context)?.settings.arguments ==
                                  null,
                        ),
                    ],
                  ),
                  _SignOutTile(
                    onSignOut:
                        onSignOut ?? RepositoryScope.read(context).logout,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerAccountSection extends StatefulWidget {
  const _DrawerAccountSection();
  @override
  State<_DrawerAccountSection> createState() => _DrawerAccountSectionState();
}

class _DrawerAccountSectionState extends State<_DrawerAccountSection> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final repository = RepositoryScope.read(context);
    if (repository.isAuthenticated) {
      _loadAccounts();
      () async {
        try {
          await repository.getUserProfile();
        } on Object {
          /* Initials remain available offline. */
        }
      }();
    }
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RepositoryScope.read(context).getConnectedAccounts();
    } on Object {
      if (mounted) _error = 'Could not load mailboxes.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _activate(ConnectedEmailAccount account) async {
    final repository = RepositoryScope.read(context);
    if (account.isActive || repository.switchingMailbox.value != null) return;
    final switched = await repository.activateEmailAccount(account.id);
    if (!mounted) return;
    if (switched) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            repository.lastError ?? 'Could not switch mailboxes. Try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = RepositoryScope.read(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        repository.userProfile,
        repository.activeMailbox,
      ]),
      builder: (context, _) {
        final identity = MailboxIdentity.resolve(
          mailbox: repository.activeMailbox.value,
          profile: repository.userProfile.value,
          userEmail: repository.userEmail,
        );
        final email = identity.email;
        return Column(
          children: [
            ListTile(
              key: const ValueKey('drawer-profile-button'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              leading: MailAvatar(
                key: ValueKey('drawer-avatar-$email'),
                name: identity.name,
                imageUrl: identity.avatarUrl,
              ),
              title: Text(
                email == null ? 'Profile' : identity.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                email ?? 'Account details',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => _openRootDestination(
                context,
                ProfileScreen.routeName,
                selected:
                    ModalRoute.of(context)?.settings.name ==
                    ProfileScreen.routeName,
              ),
            ),
            ValueListenableBuilder<List<ConnectedEmailAccount>>(
              valueListenable: repository.connectedAccounts,
              builder: (context, accounts, _) {
                final showAccounts =
                    accounts.length > 1 ||
                    (accounts.isNotEmpty &&
                        accounts.first.emailAddress != email);
                return ValueListenableBuilder<String?>(
                  valueListenable: repository.switchingMailbox,
                  builder: (context, switching, _) => Column(
                    children: [
                      if (showAccounts) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Mailboxes',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                        for (final account in accounts)
                          ListTile(
                            key: ValueKey('drawer-mailbox-${account.id}'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            leading: MailAvatar(
                              name: MailboxIdentity.resolve(
                                mailbox: account,
                                profile: repository.userProfile.value,
                              ).name,
                              imageUrl: MailboxIdentity.resolve(
                                mailbox: account,
                                profile: repository.userProfile.value,
                              ).avatarUrl,
                              size: 32,
                            ),
                            title: Text(
                              account.emailAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textFor(context)),
                            ),
                            subtitle: account.isActive
                                ? const Text('Current mailbox')
                                : account.syncStatus == 'DISCONNECTED'
                                ? const Text('Reconnect in Manage accounts')
                                : null,
                            trailing: switching == account.id
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : account.isActive
                                ? const Icon(Icons.check_rounded, size: 20)
                                : null,
                            onTap:
                                switching != null ||
                                    account.isActive ||
                                    account.syncStatus == 'DISCONNECTED'
                                ? null
                                : () => _activate(account),
                          ),
                      ],
                      if (_loading && accounts.isEmpty)
                        const LinearProgressIndicator(minHeight: 2),
                      if (_error != null)
                        TextButton.icon(
                          onPressed: _loadAccounts,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(_error!),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
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
        title: Text(
          'Sign out?',
          style: Theme.of(dialogContext).textTheme.titleLarge,
        ),
        content: const Text('Your mailboxes stay connected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t sign out. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('drawer-sign-out'),
    enabled: !_signingOut,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    leading: _signingOut
        ? const SizedBox.square(
            key: ValueKey('sign-out-loader'),
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.logout_rounded),
    title: Text(_signingOut ? 'Signing out…' : 'Sign out'),
    onTap: _signingOut ? null : _signOut,
  );
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
    final repository = RepositoryScope.read(context);
    setState(() => _saving = true);
    final saved = await controller.changeThemeMode(
      enabled ? ThemeMode.dark : ThemeMode.light,
      save: () async =>
          !repository.isAuthenticated ||
          await repository.updatePreferences(
                theme: enabled ? 'Dark' : 'Light',
              ) !=
              null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the theme preference.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: isDark ? 'Use light mode' : 'Use dark mode',
          child: Switch(
            key: const ValueKey('drawer-dark-mode-switch'),
            value: isDark,
            onChanged: _saving ? null : _setDarkMode,
            activeThumbColor: scheme.onPrimary,
            activeTrackColor: scheme.primary,
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
  Widget build(BuildContext context) => ListTile(
    selected: selected,
    shape: const RoundedRectangleBorder(),
    selectedTileColor: Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: .12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    leading: Icon(item.icon, size: 24),
    title: Text(item.title, style: Theme.of(context).textTheme.bodyLarge),
    onTap: () => _openRootDestination(
      context,
      item.route,
      selected: selected,
      arguments: item.arguments,
    ),
  );
}

void _openRootDestination(
  BuildContext context,
  String route, {
  required bool selected,
  Object? arguments,
}) {
  final navigator = Navigator.of(context);
  navigator.pop();
  if (selected) return;
  if (arguments != null) {
    navigator.pushNamed(route, arguments: arguments);
  } else {
    AppNavigation.open(context, route);
  }
}
