import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../screens/all_senders_screen.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../utils/public_links.dart';
import '../utils/mail_date.dart';
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/section_title.dart';
import 'settings_screen.dart';
import 'connected_accounts_screen.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key, this.repository});

  static const routeName = '/privacy-security';
  final SenderWhoRepository? repository;

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  late Future<PrivacySecuritySummary> _summaryFuture;
  late Future<List<AppSessionInfo>> _sessionsFuture;
  bool _busy = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  @override
  void initState() {
    super.initState();
    _summaryFuture = _repository.getPrivacySecurity();
    _sessionsFuture = _repository.getSessions();
    // The summary loading view is rendered before the nested session builder.
    // Attach an early listener so a very fast session failure is not reported
    // as an unhandled asynchronous error; the FutureBuilder still shows it.
    _sessionsFuture.ignore();
  }

  void _refresh() {
    setState(() {
      _summaryFuture = _repository.getPrivacySecurity();
      _sessionsFuture = _repository.getSessions();
      _sessionsFuture.ignore();
    });
  }

  Future<void> _revokeSession(AppSessionInfo session) async {
    if (_busy) return;
    setState(() => _busy = true);
    final success = await _repository.revokeSession(session.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!session.current && success) _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'The selected device was signed out.'
              : _repository.lastError ??
                    'Could not sign out this device. Please try again.',
        ),
      ),
    );
  }

  Future<void> _revokeAllSessions() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Sign out every device?'),
        content: const Text(
          'You will need to sign in with your email provider again on this device and every other device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final count = await _repository.revokeAllSessions();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == null
              ? _repository.lastError ??
                    'Could not sign out all devices. Please try again.'
              : '$count active session${count == 1 ? ' was' : 's were'} signed out.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PrivacySecuritySummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            header: AppHeader(title: 'Privacy & Security', showBack: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 18),
                AppCard(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          );
        }
        final summary =
            snapshot.data ??
            PrivacySecuritySummary.fromJson({
              'twoFactorEnabled': false,
              'blockedSenders': 0,
              'trustedSenders': 0,
              'dataRetention': 'Metadata only',
              'privacyMode': 'Standard',
            });

        if (snapshot.hasError) {
          return AppPage(
            header: const AppHeader(
              title: 'Privacy & Security',
              showBack: true,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: context.gap(18)),
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: _refresh,
                ),
              ],
            ),
          );
        }

        return AppPage(
          header: const AppHeader(title: 'Privacy & Security', showBack: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_busy) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(
                  minHeight: 2,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ],
              SizedBox(height: context.gap(22)),
              const SectionTitle(title: 'Security'),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Mailbox access',
                      subtitle:
                          'Manage connections and sign in again if needed',
                      onTap: () => Navigator.pushNamed(
                        context,
                        ConnectedAccountsScreen.routeName,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(25)),
              const SectionTitle(title: 'Active Sessions'),
              const SizedBox(height: 14),
              FutureBuilder<List<AppSessionInfo>>(
                future: _sessionsFuture,
                builder: (context, sessionSnapshot) {
                  if (sessionSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const AppCard(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (sessionSnapshot.hasError) {
                    return AppAsyncError(
                      title: 'Could not load active sessions',
                      message: appAsyncErrorMessage(sessionSnapshot.error),
                      onRetry: _refresh,
                    );
                  }
                  final sessions = sessionSnapshot.data ?? const [];
                  return AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        if (sessions.isEmpty)
                          const ListTile(
                            leading: Icon(Icons.devices_outlined),
                            title: Text('No active sessions found'),
                            subtitle: Text(
                              'No devices are currently signed in.',
                            ),
                          ),
                        for (final session in sessions) ...[
                          _SessionRow(
                            session: session,
                            onSignOut: _busy
                                ? null
                                : () => _revokeSession(session),
                          ),
                          if (session != sessions.last)
                            const Divider(height: 1, indent: 20, endIndent: 20),
                        ],
                        if (sessions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _revokeAllSessions,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Sign out all devices'),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: context.gap(25)),
              const SectionTitle(title: 'Sender Controls'),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.block_outlined,
                      title: 'Blocked Senders',
                      subtitle: '${summary.blockedSenders} blocked senders',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AllSendersScreen.routeName,
                        arguments: const SenderListArguments(
                          control: 'BLOCKED',
                          title: 'Blocked Senders',
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      icon: Icons.person_add_alt_rounded,
                      title: 'Trusted Senders',
                      subtitle: '${summary.trustedSenders} trusted senders',
                      onTap: () => Navigator.pushNamed(
                        context,
                        AllSendersScreen.routeName,
                        arguments: const SenderListArguments(
                          control: 'TRUSTED',
                          title: 'Trusted Senders',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(25)),
              AppCard(
                padding: const EdgeInsets.all(20),
                color: AppColors.softFill(context, AppColors.primary),
                borderColor: AppColors.primary.withValues(alpha: 0.22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconBubble(
                      icon: Icons.verified_user_outlined,
                      size: 30,
                      iconSize: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your privacy matters',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SenderWho saves sender details and short previews. Full messages load when opened. Read our Privacy Policy for data retention details.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(25)),
              const SectionTitle(title: 'Your Data'),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    SettingsTile(
                      icon: Icons.policy_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'How SenderWho accesses and protects your data',
                      onTap: () => openSenderWhoPublicPage(
                        context,
                        url: AppConfig.privacyPolicyUrl,
                        pageName: 'the Privacy Policy',
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

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, this.onSignOut});
  final AppSessionInfo session;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        final details = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              session.current
                  ? Icons.phonelink_lock_rounded
                  : Icons.devices_outlined,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.current
                        ? 'This device'
                        : session.lastUsedAt == null
                        ? 'Signed in'
                        : 'Last active ${formatMailDate(session.lastUsedAt!.toIso8601String(), detailed: true)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
        final action = TextButton(
          onPressed: onSignOut,
          child: const Text('Sign out'),
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              )
            : Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 8),
                  action,
                ],
              );
      },
    ),
  );
}
