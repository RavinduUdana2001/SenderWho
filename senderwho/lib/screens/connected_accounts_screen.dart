import 'dart:async';
import '../utils/user_friendly_error.dart';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/section_title.dart';

class ConnectedAccountsArguments {
  const ConnectedAccountsArguments({this.addMailbox = false});
  final bool addMailbox;
}

class ConnectedAccountsScreen extends StatefulWidget {
  const ConnectedAccountsScreen({super.key, this.repository});

  final SenderWhoRepository? repository;

  static const routeName = '/connected-accounts';

  @override
  State<ConnectedAccountsScreen> createState() =>
      _ConnectedAccountsScreenState();
}

class _ConnectedAccountsScreenState extends State<ConnectedAccountsScreen> {
  late Future<List<ConnectedEmailAccount>> _accountsFuture;
  late Future<Map<String, bool>> _providersFuture;
  final Set<String> _busyAccountIds = {};
  String? _connectingProvider;
  Timer? _refreshTimer;
  bool _openAddMailbox = false;
  bool _readArguments = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  @override
  void initState() {
    super.initState();
    _accountsFuture = _loadAccounts();
    _providersFuture = _repository.availableAuthProviders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readArguments) return;
    _readArguments = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    _openAddMailbox =
        arguments is ConnectedAccountsArguments && arguments.addMailbox;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<List<ConnectedEmailAccount>> _loadAccounts() async {
    final accounts = await _repository.getConnectedAccounts();
    _refreshTimer?.cancel();
    if (mounted &&
        _repository.isAuthenticated &&
        accounts.any(
          (account) =>
              account.syncStatus == 'PENDING' ||
              account.syncStatus == 'SYNCING' ||
              account.syncStatus == 'PARTIAL' ||
              account.hasScheduledRetry,
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
    if (_busyAccountIds.isNotEmpty ||
        _connectingProvider != null ||
        _repository.switchingMailbox.value != null) {
      return;
    }
    setState(() => _busyAccountIds.add(account.id));
    final queued = await _repository.queueAccountSync(account.id);
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
    if (_busyAccountIds.isNotEmpty ||
        _connectingProvider != null ||
        _repository.switchingMailbox.value != null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text('Disconnect ${_providerLabel(account)}?'),
        content: Text(
          'SenderWho will revoke access for ${account.emailAddress} and stop future scans. Saved sender details and message previews remain until you delete your SenderWho account.${account.isActive ? ' Another available mailbox will become current.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyAccountIds.add(account.id));
    final result = await _repository.disconnectAccount(account.id);
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
    if (_busyAccountIds.isNotEmpty ||
        _connectingProvider != null ||
        _repository.switchingMailbox.value != null) {
      return;
    }
    setState(() => _busyAccountIds.add(account.id));
    final connected = await _repository.connectEmailAccount(
      account.provider.toLowerCase(),
      loginHint: account.provider == 'YAHOO' ? null : account.emailAddress,
    );
    if (!mounted) return;
    setState(() => _busyAccountIds.remove(account.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? '${_providerLabel(account)} connection completed. Your mailbox list has been updated.'
              : _repository.lastError ??
                    'The account could not be reconnected.',
        ),
      ),
    );
    if (connected) _refresh();
  }

  Future<void> _activate(ConnectedEmailAccount account) async {
    if (account.isActive ||
        _busyAccountIds.isNotEmpty ||
        _connectingProvider != null) {
      return;
    }
    setState(() => _busyAccountIds.add(account.id));
    final activated = await _repository.activateEmailAccount(account.id);
    if (!mounted) return;
    setState(() => _busyAccountIds.remove(account.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          activated
              ? '${account.emailAddress} is now your current mailbox.'
              : _repository.lastError ?? 'Could not switch mailboxes.',
        ),
      ),
    );
    if (activated) _refresh();
  }

  Future<void> _connect(String provider) async {
    if (_connectingProvider != null ||
        _busyAccountIds.isNotEmpty ||
        _repository.switchingMailbox.value != null) {
      return;
    }
    setState(() => _connectingProvider = provider);
    final connected = await _repository.connectEmailAccount(provider);
    if (!mounted) return;
    setState(() => _connectingProvider = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? '${_providerLabelForValue(provider)} connected and selected.'
              : _repository.lastError ?? 'The mailbox could not be connected.',
        ),
      ),
    );
    if (connected) _refresh();
  }

  void _cancelConnection() {
    _repository.cancelOAuth();
  }

  Widget _addAccountsCard(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      future: _providersFuture,
      builder: (context, snapshot) {
        final providers = snapshot.data ?? const <String, bool>{};
        final googleEnabled = providers['google'] ?? true;
        final microsoftEnabled = providers['microsoft'] ?? false;
        final yahooEnabled = providers['yahoo'] ?? false;
        final connecting = _connectingProvider;
        return AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('add-gmail-account'),
                  onPressed:
                      connecting == null &&
                          _busyAccountIds.isEmpty &&
                          googleEnabled
                      ? () => _connect('google')
                      : null,
                  icon: connecting == 'google'
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.g_mobiledata_rounded, size: 25),
                  label: Text(
                    connecting == 'google'
                        ? 'Connecting Gmail…'
                        : 'Add Gmail account',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('add-microsoft-account'),
                  onPressed:
                      connecting == null &&
                          _busyAccountIds.isEmpty &&
                          microsoftEnabled
                      ? () => _connect('microsoft')
                      : null,
                  icon: connecting == 'microsoft'
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.window_rounded, size: 20),
                  label: Text(
                    connecting == 'microsoft'
                        ? 'Connecting Microsoft Outlook…'
                        : microsoftEnabled
                        ? 'Add Microsoft Outlook account'
                        : 'Microsoft Outlook is not available yet',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('add-yahoo-account'),
                  onPressed:
                      connecting == null &&
                          _busyAccountIds.isEmpty &&
                          yahooEnabled
                      ? () => _connect('yahoo')
                      : null,
                  icon: connecting == 'yahoo'
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.alternate_email_rounded, size: 20),
                  label: Text(
                    connecting == 'yahoo'
                        ? 'Connecting Yahoo Mail…'
                        : yahooEnabled
                        ? 'Add Yahoo account'
                        : 'Yahoo Mail is not available yet',
                  ),
                ),
              ),
              if (connecting != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _cancelConnection,
                    child: const Text('Cancel connection'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    return FutureBuilder<List<ConnectedEmailAccount>>(
      future: _accountsFuture,
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <ConnectedEmailAccount>[];
        final connectedCount = accounts
            .where((account) => account.syncStatus != 'DISCONNECTED')
            .length;
        return AppPage(
          header: AppHeader(
            title: 'Manage Accounts',
            showBack:
                arguments is ConnectedAccountsArguments && arguments.addMailbox,
            action: IconButton(
              tooltip: 'Refresh accounts',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: context.gap(22)),
              ExpansionTile(
                key: const ValueKey('add-mailbox-section'),
                initiallyExpanded: _openAddMailbox,
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_rounded),
                title: const Text('Add another mailbox'),
                children: [_addAccountsCard(context)],
              ),
              SizedBox(height: context.gap(12)),
              SectionTitle(
                title: 'Connected Accounts',
                actionLabel: accounts.isEmpty
                    ? null
                    : '$connectedCount connected',
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a mailbox to see its messages and senders. Switch anytime from your profile menu.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                            icon: _providerIcon(account.provider),
                            size: 35,
                            iconSize: 28,
                            color: _providerColor(account.provider),
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
                                if (account.isActive) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    key: ValueKey(
                                      'current-account-${account.id}',
                                    ),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 15,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          'Current mailbox',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 7),
                                Text(
                                  account.emailAddress,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (account.syncStatus == 'PARTIAL' ||
                                    (account.syncStatus == 'SYNCING' &&
                                        !account.backfillComplete &&
                                        account.backfillProcessed > 0)) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    '${account.backfillProcessed} messages processed · syncing older mail',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      StatusChip(
                        label:
                            account.hasScheduledRetry ||
                                isMailboxRateLimited(account.lastSyncError)
                            ? 'Sync paused'
                            : _statusLabel(account.syncStatus),
                        color:
                            account.hasScheduledRetry ||
                                isMailboxRateLimited(account.lastSyncError)
                            ? Theme.of(context).colorScheme.primary
                            : _statusColor(account.syncStatus),
                      ),
                      if (account.lastSyncError != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.softFill(
                              context,
                              account.needsReconnect
                                  ? AppColors.danger
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                account.needsReconnect
                                    ? Icons.link_off_rounded
                                    : Icons.schedule_rounded,
                                size: 18,
                                color: account.needsReconnect
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  account.hasScheduledRetry
                                      ? 'Sync will retry automatically. Your saved mail is available.'
                                      : account.lastSyncError!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
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
                          if (!account.isActive &&
                              account.syncStatus != 'DISCONNECTED')
                            TextButton.icon(
                              key: ValueKey('activate-account-${account.id}'),
                              onPressed:
                                  (_busyAccountIds.isNotEmpty ||
                                      _connectingProvider != null)
                                  ? null
                                  : () => _activate(account),
                              icon: const Icon(
                                Icons.swap_horiz_rounded,
                                size: 18,
                              ),
                              label: const Text('Use this account'),
                            ),
                          TextButton.icon(
                            onPressed:
                                account.syncStatus == 'DISCONNECTED' ||
                                    (_busyAccountIds.isNotEmpty ||
                                        _connectingProvider != null)
                                ? null
                                : () => _disconnect(account),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            icon: const Icon(Icons.link_off_rounded, size: 18),
                            label: const Text('Disconnect'),
                          ),
                          if (account.recoveryAction != 'CONFIGURE_GOOGLE' &&
                              account.recoveryAction != 'CONTACT_ADMIN' &&
                              account.needsReconnect)
                            TextButton.icon(
                              onPressed:
                                  (_busyAccountIds.isNotEmpty ||
                                      _connectingProvider != null)
                                  ? null
                                  : () => _reconnect(account),
                              icon: const Icon(Icons.link_rounded, size: 18),
                              label: const Text('Reconnect'),
                            ),
                          if (!account.needsReconnect &&
                              account.recoveryAction != 'CONFIGURE_GOOGLE' &&
                              account.recoveryAction != 'CONTACT_ADMIN' &&
                              account.syncStatus != 'DISCONNECTED')
                            TextButton.icon(
                              onPressed:
                                  _busyAccountIds.contains(account.id) ||
                                      account.syncStatus == 'PENDING' ||
                                      account.syncStatus == 'SYNCING' ||
                                      account.syncStatus == 'PARTIAL' ||
                                      account.hasScheduledRetry
                                  ? null
                                  : () => _queueSync(account),
                              icon: const Icon(Icons.sync_rounded, size: 18),
                              label: Text(
                                account.hasScheduledRetry
                                    ? 'Retry scheduled'
                                    : 'Scan now',
                              ),
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
            ],
          ),
        );
      },
    );
  }

  String _providerLabel(ConnectedEmailAccount account) =>
      _providerLabelForValue(account.provider);
}

String _providerLabelForValue(String provider) =>
    switch (provider.toUpperCase()) {
      'MICROSOFT' => 'Microsoft Outlook',
      'YAHOO' => 'Yahoo Mail',
      _ => 'Gmail',
    };

IconData _providerIcon(String provider) => switch (provider.toUpperCase()) {
  'MICROSOFT' => Icons.window_rounded,
  'YAHOO' => Icons.alternate_email_rounded,
  _ => Icons.g_mobiledata_rounded,
};

Color _providerColor(String provider) => switch (provider.toUpperCase()) {
  'MICROSOFT' => AppColors.microsoft,
  'YAHOO' => AppColors.yahoo,
  _ => AppColors.google,
};

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
