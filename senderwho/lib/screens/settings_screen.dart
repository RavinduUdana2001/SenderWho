import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../screens/connected_accounts_screen.dart';
import '../screens/categories_screen.dart';
import '../screens/emails_screen.dart';
import '../screens/privacy_security_screen.dart';
import '../screens/all_senders_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../theme/theme_mode_controller.dart';
import '../utils/responsive.dart';
import '../utils/public_links.dart';
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/section_title.dart';

typedef SettingsPublicPageOpener =
    Future<void> Function(
      BuildContext context, {
      required String url,
      required String pageName,
    });

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.repository, this.publicPageOpener});

  static const routeName = '/settings';
  final SenderWhoRepository? repository;
  final SettingsPublicPageOpener? publicPageOpener;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<AppSettings> _settingsFuture;
  late Future<List<ConnectedEmailAccount>> _accountsFuture;
  bool _savingPreferences = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _repository.getSettings();
    _accountsFuture = _loadAccountPreviews();
  }

  Future<List<ConnectedEmailAccount>> _loadAccountPreviews() async {
    try {
      return await _repository.getConnectedAccounts();
    } on Object {
      // The account preview is supplementary. The dedicated management page
      // still presents a retryable error if this request is unavailable.
      return const <ConnectedEmailAccount>[];
    }
  }

  void _reloadSettings() {
    if (!mounted) return;
    setState(() {
      _settingsFuture = _repository.getSettings();
      _accountsFuture = _loadAccountPreviews();
    });
  }

  Future<void> _openRoute(String routeName, {Object? arguments}) async {
    await Navigator.pushNamed(context, routeName, arguments: arguments);
    _reloadSettings();
  }

  Future<void> _openPublicPage({
    required String url,
    required String pageName,
  }) {
    final opener = widget.publicPageOpener ?? openSenderWhoPublicPage;
    return opener(context, url: url, pageName: pageName);
  }

  Future<void> _updatePreferences({
    bool? notificationsEnabled,
    String? inboxScanFrequency,
    String? theme,
  }) async {
    if (_savingPreferences) return;
    setState(() => _savingPreferences = true);
    AppSettings? updated;
    Object? failure;
    try {
      updated = await _repository.updatePreferences(
        notificationsEnabled: notificationsEnabled,
        inboxScanFrequency: inboxScanFrequency,
        theme: theme,
      );
    } on Object catch (error) {
      failure = error;
    }
    if (!mounted) return;
    setState(() => _savingPreferences = false);
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failure is SenderWhoRequestException
                ? failure.message
                : _repository.lastError ??
                      'Could not save this preference. Please try again.',
          ),
        ),
      );
      return;
    }
    if (theme != null) {
      ThemeModeController.of(context).setThemeMode(switch (theme) {
        'Light' => ThemeMode.light,
        'Dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      });
    }
    setState(() {
      _settingsFuture = Future.value(updated);
    });
  }

  Future<void> _choosePreference({
    required String title,
    required List<String> values,
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            for (final value in values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  tileColor: value == currentValue
                      ? AppColors.softFill(context, AppColors.primary)
                      : Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  leading: Icon(
                    value == 'Dark'
                        ? Icons.dark_mode_outlined
                        : value == 'Light'
                        ? Icons.light_mode_outlined
                        : value == 'System'
                        ? Icons.devices_rounded
                        : Icons.schedule_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(value),
                  trailing: value == currentValue
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.pop(context, value),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return AppPage(
            child: Column(
              children: [
                const AppHeader(
                  title: 'Settings',
                  subtitle: 'Personalize your SenderWho experience',
                ),
                SizedBox(height: context.gap(22)),
                if (snapshot.hasError)
                  AppAsyncError(
                    message: appAsyncErrorMessage(snapshot.error),
                    onRetry: _reloadSettings,
                  )
                else
                  const AppAsyncLoading(message: 'Loading your settings…'),
              ],
            ),
          );
        }
        final settings = snapshot.requireData;

        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(
                title: 'Settings',
                subtitle: 'Personalize your SenderWho experience',
              ),
              SizedBox(height: context.gap(22)),
              if (snapshot.hasError) ...[
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: _reloadSettings,
                ),
                SizedBox(height: context.gap(18)),
              ],
              if (_savingPreferences) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
              ],
              const SectionTitle(title: 'Account'),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SettingsTile(
                      key: const ValueKey('settings-connected-accounts'),
                      icon: Icons.alternate_email_rounded,
                      title: 'Connected Accounts',
                      subtitle: 'View every connected mailbox',
                      value:
                          '${settings.connectedAccountsCount} ${settings.connectedAccountsCount == 1 ? 'Account' : 'Accounts'}',
                      onTap: () =>
                          _openRoute(ConnectedAccountsScreen.routeName),
                    ),
                    FutureBuilder<List<ConnectedEmailAccount>>(
                      future: _accountsFuture,
                      builder: (context, accountSnapshot) {
                        final accounts = accountSnapshot.data;
                        if (accounts == null || accounts.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            for (final account in accounts) ...[
                              const Divider(
                                height: 1,
                                indent: 64,
                                endIndent: 20,
                              ),
                              _ConnectedAccountPreview(
                                account: account,
                                onTap: () => _openRoute(
                                  ConnectedAccountsScreen.routeName,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-manage-accounts'),
                      icon: Icons.manage_accounts_outlined,
                      title: 'Manage Accounts',
                      subtitle:
                          'Add Gmail, Outlook, or Yahoo; switch, scan, or disconnect',
                      onTap: () =>
                          _openRoute(ConnectedAccountsScreen.routeName),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-privacy-security'),
                      icon: Icons.verified_user_outlined,
                      title: 'Privacy & Security',
                      onTap: () => _openRoute(PrivacySecurityScreen.routeName),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(25)),
              const SectionTitle(title: 'Preferences'),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SettingsTile(
                      key: const ValueKey('settings-security-notifications'),
                      icon: Icons.notifications_active_outlined,
                      title: 'Security notifications',
                      subtitle: 'Account, sync, and suspicious-activity alerts',
                      trailingSwitch: true,
                      switchValue: settings.notificationsEnabled,
                      onSwitchChanged: _savingPreferences
                          ? null
                          : (enabled) => _updatePreferences(
                              notificationsEnabled: enabled,
                            ),
                      onTap: _savingPreferences
                          ? null
                          : () => _updatePreferences(
                              notificationsEnabled:
                                  !settings.notificationsEnabled,
                            ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-email-categories'),
                      icon: Icons.category_outlined,
                      title: 'E-mail Categories',
                      onTap: () => _openRoute(CategoriesScreen.routeName),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-scan-frequency'),
                      icon: Icons.schedule_rounded,
                      title: 'Inbox Scan Frequency',
                      value: settings.inboxScanFrequency,
                      onTap: _savingPreferences
                          ? null
                          : () => _choosePreference(
                              title: 'Inbox scan frequency',
                              values: const [
                                'Auto',
                                'Hourly',
                                'Daily',
                                'Manual',
                              ],
                              currentValue: settings.inboxScanFrequency,
                              onSelected: (value) =>
                                  _updatePreferences(inboxScanFrequency: value),
                            ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-theme'),
                      icon: switch (settings.theme) {
                        'Dark' => Icons.dark_mode_outlined,
                        'Light' => Icons.light_mode_outlined,
                        _ => Icons.devices_rounded,
                      },
                      title: 'Theme',
                      value: settings.theme,
                      onTap: _savingPreferences
                          ? null
                          : () => _choosePreference(
                              title: 'Theme',
                              values: const ['System', 'Light', 'Dark'],
                              currentValue: settings.theme,
                              onSelected: (value) =>
                                  _updatePreferences(theme: value),
                            ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(25)),
              const SectionTitle(title: 'E-mail Management'),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SettingsTile(
                      key: const ValueKey('settings-archived-emails'),
                      icon: Icons.archive_outlined,
                      title: 'Archived E-mails',
                      value: '${settings.archivedEmails}',
                      onTap: () => _openRoute(
                        EmailsScreen.routeName,
                        arguments: const EmailListArguments(
                          mailbox: 'ARCHIVED',
                          title: 'Archived Emails',
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-trash'),
                      icon: Icons.delete_outline_rounded,
                      title: 'Trash',
                      value: '${settings.trashEmails}',
                      onTap: () => _openRoute(
                        EmailsScreen.routeName,
                        arguments: const EmailListArguments(
                          mailbox: 'TRASH',
                          title: 'Trash',
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-blocked-senders'),
                      icon: Icons.block_outlined,
                      title: 'Blocked Senders',
                      value: '${settings.blockedSenders}',
                      onTap: () => _openRoute(
                        AllSendersScreen.routeName,
                        arguments: const SenderListArguments(
                          control: 'BLOCKED',
                          title: 'Blocked Senders',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(25)),
              const SectionTitle(title: 'Legal & Support'),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SettingsTile(
                      key: const ValueKey('settings-privacy-policy'),
                      icon: Icons.policy_outlined,
                      title: 'Privacy Policy',
                      onTap: () => _openPublicPage(
                        url: AppConfig.privacyPolicyUrl,
                        pageName: 'the Privacy Policy',
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-terms'),
                      icon: Icons.description_outlined,
                      title: 'Terms of Service',
                      onTap: () => _openPublicPage(
                        url: AppConfig.termsOfServiceUrl,
                        pageName: 'the Terms of Service',
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-support'),
                      icon: Icons.support_agent_rounded,
                      title: 'Support',
                      subtitle: AppConfig.supportEmail,
                      onTap: () => _openPublicPage(
                        url: AppConfig.supportUrl,
                        pageName: 'SenderWho Support',
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      key: const ValueKey('settings-account-deletion-info'),
                      icon: Icons.delete_forever_outlined,
                      title: 'Account deletion information',
                      onTap: () => _openPublicPage(
                        url: AppConfig.accountDeletionUrl,
                        pageName: 'account deletion information',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailingSwitch = false,
    this.switchValue = true,
    this.onSwitchChanged,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final bool trailingSwitch;
  final bool switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            IconBubble(icon: icon, size: 40, iconSize: 19, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: destructive
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            if (trailingSwitch)
              Switch.adaptive(value: switchValue, onChanged: onSwitchChanged)
            else ...[
              if (value != null)
                Text(value!, style: Theme.of(context).textTheme.bodyMedium),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.mutedFor(context),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectedAccountPreview extends StatelessWidget {
  const _ConnectedAccountPreview({required this.account, required this.onTap});

  final ConnectedEmailAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disconnected = account.syncStatus == 'DISCONNECTED';
    return InkWell(
      key: ValueKey('settings-account-${account.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(64, 11, 14, 11),
        child: Row(
          children: [
            Icon(
              account.provider == 'MICROSOFT'
                  ? Icons.window_rounded
                  : account.provider == 'YAHOO'
                  ? Icons.alternate_email_rounded
                  : Icons.g_mobiledata_rounded,
              size: account.provider == 'GOOGLE' ? 23 : 19,
              color: disconnected
                  ? AppColors.mutedFor(context)
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.emailAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    disconnected
                        ? 'Disconnected · reconnect to use'
                        : account.isActive
                        ? 'Current mailbox'
                        : '${account.provider == 'MICROSOFT'
                              ? 'Microsoft Outlook'
                              : account.provider == 'YAHOO'
                              ? 'Yahoo Mail'
                              : 'Gmail'} connected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: account.isActive && !disconnected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (account.isActive && !disconnected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.mutedFor(context),
              ),
          ],
        ),
      ),
    );
  }
}
