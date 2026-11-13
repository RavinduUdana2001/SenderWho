import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/repository_scope.dart';
import '../services/senderwho_repository.dart';
import '../utils/app_navigation.dart';
import '../utils/mail_date.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/mail_avatar.dart';
import '../widgets/mailbox_sync_notice.dart';
import 'all_senders_screen.dart';
import 'bulk_clean_screen.dart';
import 'connected_accounts_screen.dart';
import 'emails_screen.dart';
import 'inbox_health_screen.dart';
import 'search_filter_screen.dart';
import 'security_alerts_screen.dart';
import 'sender_details_screen.dart';
import 'unsubscribe_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.repository});
  static const routeName = '/dashboard';
  final SenderWhoRepository? repository;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);
  late Future<DashboardSummary> _future;
  DashboardSummary? _cached;
  Timer? _timer;
  bool _loading = false;
  bool _queueing = false;
  bool _scanScheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    } else {
      _timer?.cancel();
    }
  }

  Future<DashboardSummary> _load() async {
    _loading = true;
    try {
      final summary = await _repository.getDashboard();
      if (mounted && summary.available) {
        _cached = summary;
        _scanScheduled = false;
      }
      return summary;
    } finally {
      _loading = false;
      _scheduleRefresh();
    }
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    if (!mounted ||
        !_repository.isAuthenticated ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
      return;
    }
    final syncing = const {
      'PENDING',
      'SYNCING',
      'PARTIAL',
    }.contains(_cached?.syncStatus);
    _timer = Timer(Duration(seconds: syncing ? 10 : 30), () {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent == true) {
        _refresh();
      } else {
        _scheduleRefresh();
      }
    });
  }

  void _refresh() {
    if (!mounted || _loading) return;
    _timer?.cancel();
    setState(() {
      _future = _load();
    });
  }

  bool _canScan(DashboardSummary summary) =>
      !_scanScheduled &&
      summary.connectedAccountId?.isNotEmpty == true &&
      summary.syncRetryAt == null &&
      !const {
        'PENDING',
        'SYNCING',
        'PARTIAL',
        'DISCONNECTED',
      }.contains(summary.syncStatus) &&
      !const {
        'RECONNECT',
        'CONFIGURE_GOOGLE',
        'CONTACT_ADMIN',
      }.contains(summary.syncRecoveryAction);
  Future<void> _scan(DashboardSummary summary) async {
    if (_queueing || _loading || !_canScan(summary)) return;
    if (AppConfig.uiPreviewMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email actions are disabled in UI preview mode.'),
        ),
      );
      return;
    }
    setState(() => _queueing = true);
    try {
      final queued = await _repository.queueAccountSync(
        summary.connectedAccountId!,
      );
      if (!mounted) return;
      if (queued) _scanScheduled = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            queued
                ? 'Mailbox sync scheduled.'
                : _repository.lastError ??
                      'Couldn’t start the sync. Please try again later.',
          ),
        ),
      );
      if (queued) {
        _refresh();
        await _future;
      }
    } finally {
      if (mounted) setState(() => _queueing = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DashboardSummary>(
    future: _future,
    builder: (context, snapshot) {
      final summary = snapshot.data?.available == true
          ? snapshot.data
          : _cached;
      final stale = snapshot.hasError || snapshot.data?.available == false;
      return AppPage(
        maxContentWidth: 840,
        onRefresh: () async {
          if (!_loading) _refresh();
          await _future;
        },
        header: AppHeader(
          title: 'Dashboard',
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Search senders and messages',
                onPressed: () =>
                    Navigator.pushNamed(context, SearchFilterScreen.routeName),
                icon: const Icon(Icons.search_rounded),
              ),
              IconButton(
                tooltip: 'Refresh live results',
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            if (summary == null)
              snapshot.connectionState == ConnectionState.waiting
                  ? const AppAsyncLoading(
                      message: 'Loading your mailbox overview…',
                    )
                  : AppAsyncError(
                      title: 'Overview unavailable',
                      message: 'Your mailbox overview could not be refreshed.',
                      onRetry: _refresh,
                    )
            else ...[
              if (AppConfig.uiPreviewMode)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'UI preview · Sample data · email actions are disabled',
                  ),
                ),
              if (stale)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OverviewRow(
                    icon: Icons.cloud_off_outlined,
                    title: 'Showing the last update',
                    subtitle: 'Pull to refresh when you’re connected.',
                    onTap: _refresh,
                  ),
                ),
              MailboxSyncNotice(
                summary: summary,
                account: _repository.activeMailbox.value,
              ),
              _MailboxOverview(summary: summary),
              if (const {
                'PENDING',
                'SYNCING',
                'PARTIAL',
              }.contains(summary.syncStatus))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.sync_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary.totalMessages > 0
                              ? 'Older mail is syncing. You can keep using your inbox.'
                              : 'Preparing your mailbox. Results appear automatically.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              const _SectionHeading(title: 'Manage your inbox'),
              const SizedBox(height: 10),
              _OverviewPanel(
                child: Column(
                  children: [
                    _OverviewRow(
                      key: const ValueKey('dashboard-cleanup'),
                      icon: Icons.cleaning_services_outlined,
                      title: 'Bulk clean',
                      subtitle: summary.cleanupMessages > 0
                          ? '${_number(summary.cleanupMessages)} emails to review · ${_bytes(summary.estimatedSpaceBytes)}'
                          : 'Review emails before moving them to Trash',
                      onTap: () => AppNavigation.open(
                        context,
                        BulkCleanScreen.routeName,
                      ),
                    ),
                    const Divider(height: 1),
                    _OverviewRow(
                      key: const ValueKey('dashboard-unsubscribe'),
                      icon: Icons.unsubscribe_outlined,
                      title: 'Unsubscribe',
                      subtitle:
                          '${_number(summary.unsubscribeSenders)} subscriptions available',
                      onTap: () => AppNavigation.open(
                        context,
                        UnsubscribeScreen.routeName,
                      ),
                    ),
                    const Divider(height: 1),
                    _OverviewRow(
                      key: const ValueKey('dashboard-health'),
                      icon: Icons.health_and_safety_outlined,
                      title: 'Inbox health',
                      subtitle: summary.totalMessages == 0
                          ? 'Available after your first scan'
                          : summary.inboxHealthStatus,
                      value: '${summary.inboxHealthScore}%',
                      onTap: () => Navigator.pushNamed(
                        context,
                        InboxHealthScreen.routeName,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeading(
                title: 'Top senders',
                action: TextButton(
                  onPressed: () =>
                      AppNavigation.open(context, AllSendersScreen.routeName),
                  child: const Text('View all'),
                ),
              ),
              if (summary.topSenders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Your most active senders appear after a scan.'),
                )
              else
                _OverviewPanel(
                  child: Column(
                    children: [
                      for (
                        var i = 0;
                        i < summary.topSenders.take(3).length;
                        i++
                      ) ...[
                        _OverviewRow(
                          key: ValueKey(
                            'dashboard-sender-${summary.topSenders[i].id}',
                          ),
                          leading: MailAvatar(
                            name: summary.topSenders[i].name,
                            size: 34,
                          ),
                          title: summary.topSenders[i].name,
                          subtitle: summary.topSenders[i].email,
                          value: _number(summary.topSenders[i].count),
                          onTap: summary.topSenders[i].id.isEmpty
                              ? null
                              : () => Navigator.pushNamed(
                                  context,
                                  SenderDetailsScreen.routeName,
                                  arguments: summary.topSenders[i].id,
                                ),
                        ),
                        if (i < summary.topSenders.take(3).length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _SectionHeading(
                title: 'Security alerts',
                action: TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    SecurityAlertsScreen.routeName,
                  ),
                  child: const Text('View all'),
                ),
              ),
              if (summary.recentAlerts.isEmpty)
                const _OverviewRow(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No open alerts',
                  subtitle: 'Nothing currently needs review.',
                )
              else
                _OverviewPanel(
                  child: Column(
                    children: [
                      for (
                        var i = 0;
                        i < summary.recentAlerts.take(2).length;
                        i++
                      ) ...[
                        _OverviewRow(
                          key: ValueKey(
                            'dashboard-alert-${summary.recentAlerts[i].id}',
                          ),
                          icon: Icons.shield_outlined,
                          title: summary.recentAlerts[i].title,
                          subtitle: summary.recentAlerts[i].reason,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/alert-details',
                            arguments: summary.recentAlerts[i],
                          ),
                        ),
                        if (i < summary.recentAlerts.take(2).length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _OverviewRow(
                key: const ValueKey('dashboard-sync'),
                icon: Icons.sync_rounded,
                title: 'Mailbox sync',
                subtitle: summary.syncRetryAt != null
                    ? 'Retry scheduled automatically'
                    : const {
                        'PENDING',
                        'SYNCING',
                        'PARTIAL',
                      }.contains(summary.syncStatus)
                    ? 'Syncing in the background'
                    : summary.lastSyncedAt == null
                    ? 'Manage your mailbox connection'
                    : 'Last updated ${formatMailDate(summary.lastSyncedAt!.toIso8601String(), detailed: true)}',
                onTap: () => Navigator.pushNamed(
                  context,
                  ConnectedAccountsScreen.routeName,
                ),
              ),
              if (_canScan(summary))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _queueing || _loading
                        ? null
                        : () => _scan(summary),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(_queueing ? 'Scheduling…' : 'Scan inbox'),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _MailboxOverview extends StatelessWidget {
  const _MailboxOverview({required this.summary});
  final DashboardSummary summary;
  @override
  Widget build(BuildContext context) {
    final metrics =
        <
          ({
            String label,
            int count,
            IconData icon,
            String route,
            Object? arguments,
          })
        >[
          (
            label: 'Senders',
            count: summary.totalSenders,
            icon: Icons.people_outline_rounded,
            route: AllSendersScreen.routeName,
            arguments: null,
          ),
          (
            label: 'Unread',
            count: summary.unreadEmails,
            icon: Icons.mark_email_unread_outlined,
            route: EmailsScreen.routeName,
            arguments: const EmailListArguments(
              mailbox: 'UNREAD',
              title: 'Unread Emails',
            ),
          ),
          (
            label: 'Promotions',
            count: summary.promotions,
            icon: Icons.local_offer_outlined,
            route: EmailsScreen.routeName,
            arguments: const EmailListArguments(
              mailbox: 'ALL',
              category: 'PROMOTIONS',
              title: 'Promotions',
            ),
          ),
          (
            label: 'Spam',
            count: summary.spam,
            icon: Icons.report_gmailerrorred_rounded,
            route: EmailsScreen.routeName,
            arguments: const EmailListArguments(
              mailbox: 'ALL',
              category: 'SPAM',
              title: 'Spam / Junk',
            ),
          ),
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  'Your mailbox',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_number(summary.totalMessages)} messages',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 620
                ? 4
                : MediaQuery.textScalerOf(context).scale(14) > 20
                ? 1
                : 2;
            final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in metrics)
                  SizedBox(
                    width: width,
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('dashboard-metric-${item.label}'),
                        onTap: () {
                          if (item.arguments == null) {
                            AppNavigation.open(context, item.route);
                          } else {
                            Navigator.pushNamed(
                              context,
                              item.route,
                              arguments: item.arguments,
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _number(item.count),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  const _OverviewPanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
  });
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading ??
                Icon(
                  icon,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (value != null) ...[
                    const SizedBox(height: 4),
                    Text(value!, style: Theme.of(context).textTheme.labelLarge),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ],
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      ?action,
    ],
  );
}

String _number(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);
String _bytes(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).round()} KB'
    : bytes < 1024 * 1024 * 1024
    ? '${(bytes / (1024 * 1024)).round()} MB'
    : '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
