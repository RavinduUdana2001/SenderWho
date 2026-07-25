import 'package:flutter/material.dart';

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
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/section_title.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.repository});

  static const routeName = '/settings';
  final SenderWhoRepository? repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<AppSettings> _settingsFuture;
  bool _savingPreferences = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

  @override
  void initState() {
    super.initState();
    _settingsFuture = _repository.getSettings();
  }

  Future<void> _updatePreferences({
    bool? notificationsEnabled,
    String? inboxScanFrequency,
    String? theme,
  }) async {
    if (_savingPreferences) return;
    setState(() => _savingPreferences = true);
    final updated = await _repository.updatePreferences(
      notificationsEnabled: notificationsEnabled,
      inboxScanFrequency: inboxScanFrequency,
      theme: theme,
    );
    if (!mounted) return;
    setState(() => _savingPreferences = false);
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this preference.')),
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
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
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
                    tileColor: AppColors.trackFor(context),
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
                      color: AppColors.primary,
                    ),
                    title: Text(value),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(context, value),
                  ),
                ),
            ],
          ),
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
                    onRetry: () => setState(() {
                      _settingsFuture = _repository.getSettings();
                    }),
                  )
                else
                  const AppCard(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Loading your settings…'),
                      ],
                    ),
                  ),
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
                  onRetry: () => setState(() {
                    _settingsFuture = _repository.getSettings();
                  }),
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
                      icon: Icons.alternate_email_rounded,
                      title: 'Connected Accounts',
                      value:
                          '${settings.connectedAccountsCount} ${settings.connectedAccountsCount == 1 ? 'Account' : 'Accounts'}',
                      onTap: () => Navigator.pushNamed(
                        context,
                        ConnectedAccountsScreen.routeName,
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Manage Accounts',
                      onTap: () => Navigator.pushNamed(
                        context,
                        ConnectedAccountsScreen.routeName,
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Privacy & Security',
                      onTap: () => Navigator.pushNamed(
                        context,
                        PrivacySecurityScreen.routeName,
                      ),
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
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      icon: Icons.category_outlined,
                      title: 'E-mail Categories',
                      onTap: () => Navigator.pushNamed(
                        context,
                        CategoriesScreen.routeName,
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
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
                              onSelected: (value) =>
                                  _updatePreferences(inboxScanFrequency: value),
                            ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      icon: Icons.light_mode_outlined,
                      title: 'Theme',
                      value: settings.theme,
                      onTap: _savingPreferences
                          ? null
                          : () => _choosePreference(
                              title: 'Theme',
                              values: const ['System', 'Light', 'Dark'],
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
                      icon: Icons.archive_outlined,
                      title: 'Archived E-mails',
                      value: '${settings.archivedEmails}',
                      onTap: () => Navigator.pushNamed(
                        context,
                        EmailsScreen.routeName,
                        arguments: const EmailListArguments(
                          mailbox: 'ARCHIVED',
                          title: 'Archived Emails',
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Trash',
                      value: '${settings.trashEmails}',
                      onTap: () => Navigator.pushNamed(
                        context,
                        EmailsScreen.routeName,
                        arguments: const EmailListArguments(
                          mailbox: 'TRASH',
                          title: 'Trash',
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      icon: Icons.block_outlined,
                      title: 'Blocked Senders',
                      value: '${settings.blockedSenders}',
                      onTap: () => Navigator.pushNamed(
                        context,
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
    final color = destructive ? AppColors.danger : AppColors.primary;
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
                      color: destructive ? AppColors.danger : null,
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
