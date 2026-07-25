import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_models.dart';
import '../screens/all_senders_screen.dart';
import '../services/senderwho_repository.dart';
import '../services/data_export_delivery.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/section_title.dart';
import 'settings_screen.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({
    super.key,
    this.repository,
    this.exportDelivery,
  });

  static const routeName = '/privacy-security';
  final SenderWhoRepository? repository;
  final Future<ShareResult> Function(
    Map<String, dynamic> export, {
    Rect? sharePositionOrigin,
  })?
  exportDelivery;

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  late Future<PrivacySecuritySummary> _summaryFuture;
  late Future<List<AppSessionInfo>> _sessionsFuture;
  bool _busy = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

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
              ? 'The selected session was signed out.'
              : _repository.lastError ?? 'Could not revoke session.',
        ),
      ),
    );
  }

  Future<void> _revokeAllSessions() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              ? _repository.lastError ?? 'Could not revoke sessions.'
              : '$count active session(s) were signed out.',
        ),
      ),
    );
  }

  Future<void> _prepareExport() async {
    if (_busy) return;
    setState(() => _busy = true);
    String message;
    try {
      final export = await _repository.prepareCompleteExport();
      if (!mounted) return;
      final renderBox = context.findRenderObject();
      final origin = renderBox is RenderBox && renderBox.hasSize
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : null;
      final deliver = widget.exportDelivery ?? deliverSenderWhoExport;
      final result = await deliver(export, sharePositionOrigin: origin);
      message = switch (result.status) {
        ShareResultStatus.success => 'Your complete data export is ready.',
        ShareResultStatus.dismissed => 'Export prepared. Sharing was canceled.',
        ShareResultStatus.unavailable =>
          'Export prepared, but file sharing is unavailable on this device.',
      };
    } on Object catch (error) {
      message = error is SenderWhoRequestException
          ? error.message
          : _repository.lastError ?? 'Could not prepare the data export.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SenderWho account?'),
        content: const Text(
          'This permanently deletes SenderWho data and attempts to revoke provider access. Your email messages themselves are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final success = await _repository.deleteAccount();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _repository.lastError ?? 'Could not delete the account.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PrivacySecuritySummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppHeader(
                  title: 'Privacy & Security',
                  subtitle: 'Account protection, sender controls and data use',
                  showBack: true,
                ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppHeader(
                  title: 'Privacy & Security',
                  subtitle: 'Account protection, sender controls and data use',
                  showBack: true,
                ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(
                title: 'Privacy & Security',
                subtitle: 'Account protection, sender controls and data use',
                showBack: true,
              ),
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
                      title: 'Email account security',
                      subtitle:
                          'Passwords and two-step verification are managed by your email provider.',
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
                              'Pull back and retry if you are offline.',
                            ),
                          ),
                        for (final session in sessions) ...[
                          ListTile(
                            leading: Icon(
                              session.current
                                  ? Icons.phonelink_lock_rounded
                                  : Icons.devices_outlined,
                            ),
                            title: Text(
                              session.current
                                  ? '${session.label} (this device)'
                                  : session.label,
                            ),
                            subtitle: Text(
                              session.ipAddress.isEmpty
                                  ? 'Network address unavailable'
                                  : session.ipAddress,
                            ),
                            trailing: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _revokeSession(session),
                              child: const Text('Sign out'),
                            ),
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
                            'Your data is used only for sender verification, inbox organization, and security features. Retention: ${summary.dataRetention}.',
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
                      icon: Icons.download_outlined,
                      title: 'Download or share data export',
                      subtitle:
                          'All SenderWho sections in one portable JSON file',
                      onTap: _busy ? null : _prepareExport,
                    ),
                    const Divider(height: 1, indent: 20, endIndent: 20),
                    SettingsTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete SenderWho account',
                      subtitle: 'Permanent deletion and provider revocation',
                      onTap: _busy ? null : _deleteAccount,
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
