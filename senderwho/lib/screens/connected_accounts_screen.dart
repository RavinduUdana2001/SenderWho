import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/section_title.dart';

class ConnectedAccountsScreen extends StatefulWidget {
  const ConnectedAccountsScreen({super.key});

  static const routeName = '/connected-accounts';

  @override
  State<ConnectedAccountsScreen> createState() =>
      _ConnectedAccountsScreenState();
}

class _ConnectedAccountsScreenState extends State<ConnectedAccountsScreen> {
  late Future<List<ConnectedEmailAccount>> _accountsFuture;
  final Set<String> _busyAccountIds = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _loadAccounts();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<List<ConnectedEmailAccount>> _loadAccounts() async {
    final accounts = await senderWhoRepository.getConnectedAccounts();
    _refreshTimer?.cancel();
    if (mounted &&
        senderWhoRepository.isAuthenticated &&
        accounts.any(
          (account) =>
              account.syncStatus == 'PENDING' ||
              account.syncStatus == 'SYNCING' ||
              account.syncStatus == 'PARTIAL',
        )) {
      _refreshTimer = Timer(const Duration(seconds: 2), _refresh);
    }
    return accounts;
  }

  void _refresh() {
    if (!mounted) return;
    _refreshTimer?.cancel();
    setState(() {
      _accountsFuture = _loadAccounts();
    });
  }

  Future<void> _queueSync(ConnectedEmailAccount account) async {
    if (_busyAccountIds.contains(account.id)) return;
    setState(() => _busyAccountIds.add(account.id));
    final queued = await senderWhoRepository.queueAccountSync(account.id);
    if (!mounted) return;
    setState(() => _busyAccountIds.remove(account.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          queued
              ? '${_providerLabel(account)} scan queued for ${account.emailAddress}.'
              : 'Could not queue the ${_providerLabel(account)} scan. Please retry.',
        ),
      ),
    );
    if (queued) _refresh();
  }

  Future<void> _disconnect(ConnectedEmailAccount account) async {
    if (_busyAccountIds.contains(account.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect ${_providerLabel(account)}?'),
        content: Text(
          'SenderWho will revoke access for ${account.emailAddress} and stop future scans. Stored metadata remains until you delete your SenderWho data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyAccountIds.add(account.id));
    final result = await senderWhoRepository.disconnectAccount(account.id);
    if (!mounted) return;
    setState(() => _busyAccountIds.remove(account.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Could not disconnect this account.'
              : result.providerRevoked
              ? '${account.emailAddress} was disconnected and provider access was revoked.'
              : '${account.emailAddress} was disconnected locally. You can also remove SenderWho in your ${_providerLabel(account)} account security settings.',
        ),
      ),
    );
    if (result?.disconnected == true) _refresh();
  }

  Future<void> _reconnect(ConnectedEmailAccount account) async {
    if (_busyAccountIds.contains(account.id)) return;
    setState(() => _busyAccountIds.add(account.id));
    final connected = await senderWhoRepository.startOAuth(
      account.provider.toLowerCase(),
    );
    if (!mounted) return;
    setState(() => _busyAccountIds.remove(account.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? '${account.emailAddress} was reconnected. A fresh scan will start automatically.'
              : senderWhoRepository.lastError ??
                    'The account could not be reconnected.',
        ),
      ),
    );
    if (connected) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ConnectedEmailAccount>>(
      future: _accountsFuture,
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <ConnectedEmailAccount>[];
        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                title: 'Connected Accounts',
                subtitle: 'Manage Gmail and Yahoo connections and scan status',
                showBack: true,
                action: IconButton.filledTonal(
                  tooltip: 'Refresh accounts',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
              SizedBox(height: context.gap(22)),
              const SectionTitle(title: 'Connected Accounts'),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting)
                const AppCard(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (snapshot.hasError)
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: _refresh,
                ),
              for (final account in accounts) ...[
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconBubble(
                            icon: account.provider == 'GOOGLE'
                                ? Icons.g_mobiledata_rounded
                                : Icons.mail_outline_rounded,
                            size: 35,
                            iconSize: 28,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.displayName,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  account.emailAddress,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (account.syncStatus == 'PARTIAL') ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    'Ready to use · older mail syncing in background · ${account.backfillProcessed} processed',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          StatusChip(
                            label: _statusLabel(account.syncStatus),
                            color: _statusColor(account.syncStatus),
                          ),
                        ],
                      ),
                      if (account.lastSyncError != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.softFill(
                              context,
                              AppColors.danger,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: AppColors.danger,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  account.lastSyncError!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.danger),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (account.lastSyncedAt != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Last synced ${_formatDate(account.lastSyncedAt!)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          TextButton.icon(
                            onPressed:
                                account.syncStatus == 'DISCONNECTED' ||
                                    _busyAccountIds.contains(account.id)
                                ? null
                                : () => _disconnect(account),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                            icon: const Icon(Icons.link_off_rounded, size: 18),
                            label: const Text('Disconnect'),
                          ),
                          if (account.recoveryAction == 'RECONNECT' ||
                              account.recoveryAction == 'CONFIGURE_GOOGLE')
                            TextButton.icon(
                              onPressed: _busyAccountIds.contains(account.id)
                                  ? null
                                  : () => _reconnect(account),
                              icon: const Icon(Icons.link_rounded, size: 18),
                              label: const Text('Reconnect'),
                            )
                          else
                            TextButton.icon(
                              onPressed:
                                  _busyAccountIds.contains(account.id) ||
                                      account.syncStatus == 'PENDING' ||
                                      account.syncStatus == 'SYNCING' ||
                                      account.syncStatus == 'PARTIAL'
                                  ? null
                                  : () => _queueSync(account),
                              icon: const Icon(Icons.sync_rounded, size: 18),
                              label: const Text('Scan now'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (accounts.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting &&
                  !snapshot.hasError)
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      IconBubble(
                        icon: Icons.link_off_rounded,
                        size: 54,
                        iconSize: 25,
                        color: AppColors.mutedFor(context),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        'No email account connected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              SizedBox(height: context.gap(12)),
              AppCard(
                padding: const EdgeInsets.all(16),
                color: AppColors.softFill(context, AppColors.primary),
                borderColor: AppColors.primary.withValues(alpha: 0.22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconBubble(
                      icon: Icons.shield_outlined,
                      size: 38,
                      iconSize: 19,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your privacy matters',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Only the email access needed for analysis, organization, and cleanup is requested.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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

  String _providerLabel(ConnectedEmailAccount account) =>
      account.provider == 'YAHOO' ? 'Yahoo Mail' : 'Gmail';
}

String _formatDate(DateTime value) {
  final local = value.toLocal().toIso8601String().replaceFirst('T', ' ');
  return local.length >= 16 ? local.substring(0, 16) : local;
}

String _statusLabel(String status) {
  return switch (status) {
    'READY' => 'Ready',
    'FAILED' => 'Action needed',
    'DISCONNECTED' => 'Reconnect',
    'SYNCING' => 'Scanning',
    'PARTIAL' => 'Ready',
    'PENDING' => 'Queued',
    _ => status,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'READY' || 'PARTIAL' => AppColors.success,
    'FAILED' || 'DISCONNECTED' => AppColors.danger,
    _ => AppColors.warning,
  };
}
