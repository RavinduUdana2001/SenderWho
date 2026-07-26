import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../screens/all_senders_screen.dart';
import '../screens/bulk_clean_screen.dart';
import '../screens/connect_email_screen.dart';
import '../screens/connected_accounts_screen.dart';
import '../screens/emails_screen.dart';
import '../screens/inbox_health_screen.dart';
import '../screens/search_filter_screen.dart';
import '../screens/security_alerts_screen.dart';
import '../screens/sender_details_screen.dart';
import '../screens/unsubscribe_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const routeName = '/dashboard';

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  late Future<DashboardSummary> _dashboardFuture;
  DashboardSummary? _cachedDashboard;
  Timer? _refreshTimer;
  bool _queueingScan = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dashboardFuture = _loadDashboard();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    _refreshTimer?.cancel();
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  Future<DashboardSummary> _loadDashboard() async {
    final dashboard = await senderWhoRepository.getDashboard();
    if (dashboard.available) _cachedDashboard = dashboard;
    _scheduleRefresh(dashboard.syncStatus);
    return dashboard;
  }

  void _scheduleRefresh(String? syncStatus) {
    _refreshTimer?.cancel();
    if (!mounted || !senderWhoRepository.isAuthenticated) return;
    final delay = syncStatus == 'PENDING' || syncStatus == 'SYNCING'
        ? const Duration(seconds: 2)
        : syncStatus == 'PARTIAL'
        ? const Duration(seconds: 15)
        : const Duration(seconds: 30);
    _refreshTimer = Timer(delay, _refresh);
  }

  Future<void> _scanNow(DashboardSummary dashboard) async {
    if (AppConfig.uiPreviewMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email actions are disabled in UI preview mode.'),
        ),
      );
      return;
    }
    final accountId = dashboard.connectedAccountId;
    if (accountId == null || accountId.isEmpty || _queueingScan) return;
    setState(() => _queueingScan = true);
    final queued = await senderWhoRepository.queueAccountSync(accountId);
    if (!mounted) return;
    setState(() => _queueingScan = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          queued
              ? 'A fresh email metadata scan has been queued.'
              : 'The inbox scan could not be queued. Please try again.',
        ),
      ),
    );
    if (queued) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSummary>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        final dashboard = snapshot.data?.available == true
            ? snapshot.data
            : _cachedDashboard;
        final isRefreshing =
            snapshot.connectionState == ConnectionState.waiting &&
            dashboard != null;
        final showingStale =
            snapshot.data?.available == false && _cachedDashboard != null;

        return AppPage(
          maxContentWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DashboardHeader(isRefreshing: isRefreshing, onRefresh: _refresh),
              SizedBox(height: context.gap(26)),
              if (isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                ),
              if (showingStale) ...[
                _DashboardStaleNotice(onRetry: _refresh),
                const SizedBox(height: 14),
              ],
              if (dashboard == null &&
                  snapshot.connectionState == ConnectionState.waiting)
                const _DashboardLoading()
              else if (dashboard == null)
                _DashboardUnavailable(onRetry: _refresh)
              else
                _DashboardContent(
                  dashboard: dashboard,
                  queueingScan: _queueingScan,
                  onScan: () => _scanNow(dashboard),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.isRefreshing, required this.onRefresh});

  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 58),
          child: Text(
            'Dashboard',
            key: const ValueKey('dashboard-header-title'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: _RoundIconButton(
            tooltip: 'Open menu',
            icon: Icons.menu_rounded,
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        Align(
          alignment: Alignment.topRight,
          child: _RoundIconButton(
            tooltip: 'Refresh live results',
            icon: isRefreshing ? Icons.sync_rounded : Icons.refresh_rounded,
            onPressed: onRefresh,
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.dashboard,
    required this.queueingScan,
    required this.onScan,
  });

  final DashboardSummary dashboard;
  final bool queueingScan;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (AppConfig.uiPreviewMode) ...[
          const _PreviewModeNotice(),
          SizedBox(height: context.gap(14)),
        ],
        _DashboardSearch(
          onTap: () =>
              Navigator.pushNamed(context, SearchFilterScreen.routeName),
        ),
        if (dashboard.syncStatus == 'PENDING' ||
            dashboard.syncStatus == 'SYNCING' ||
            dashboard.syncStatus == 'PARTIAL' ||
            dashboard.syncStatus == 'FAILED' ||
            dashboard.syncStatus == 'DISCONNECTED') ...[
          SizedBox(height: context.gap(16)),
          _SyncNotice(dashboard: dashboard, onRetry: onScan),
        ],
        SizedBox(height: context.gap(20)),
        _HealthOverviewCard(summary: dashboard),
        SizedBox(height: context.gap(28)),
        const _SectionHeader(
          title: 'Inbox overview',
          caption: 'Live results from stored email metadata',
        ),
        const SizedBox(height: 14),
        _MetricGrid(summary: dashboard),
        SizedBox(height: context.gap(28)),
        _CleanupOpportunityCard(summary: dashboard),
        SizedBox(height: context.gap(28)),
        const _SectionHeader(
          title: 'Quick actions',
          caption: 'Manage your inbox without leaving SenderWho',
        ),
        const SizedBox(height: 14),
        _QuickActionGrid(
          summary: dashboard,
          queueingScan: queueingScan,
          onScan: onScan,
        ),
        SizedBox(height: context.gap(28)),
        _SectionHeader(
          title: 'Top senders',
          caption: 'Ranked by scanned message volume',
          actionLabel: 'View all',
          onAction: () =>
              Navigator.pushNamed(context, AllSendersScreen.routeName),
        ),
        const SizedBox(height: 14),
        _TopSendersCard(items: dashboard.topSenders),
        SizedBox(height: context.gap(28)),
        _SectionHeader(
          title: 'Security alerts',
          caption: dashboard.recentAlerts.isEmpty
              ? 'Nothing currently needs your attention'
              : '${dashboard.openAlertCount} alerts need review',
          actionLabel: 'View all',
          onAction: () =>
              Navigator.pushNamed(context, SecurityAlertsScreen.routeName),
        ),
        const SizedBox(height: 14),
        if (dashboard.recentAlerts.isEmpty)
          const _SafeInboxCard()
        else
          for (final alert in dashboard.recentAlerts.take(3)) ...[
            _AlertCard(alert: alert),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _PreviewModeNotice extends StatelessWidget {
  const _PreviewModeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.softFill(context, AppColors.indigo),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.indigo.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const _SoftIcon(
            icon: Icons.visibility_outlined,
            color: AppColors.indigo,
            size: 30,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'UI preview · Sample data · email actions are disabled',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.mutedFor(context),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSearch extends StatelessWidget {
  const _DashboardSearch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.borderFor(context).withValues(alpha: 0.58),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 21,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search senders and email metadata',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
              ),
              Icon(
                Icons.tune_rounded,
                size: 18,
                color: AppColors.mutedFor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthOverviewCard extends StatelessWidget {
  const _HealthOverviewCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final healthColor = _healthColor(summary);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          healthColor.withValues(
            alpha: AppColors.isDark(context) ? 0.07 : 0.045,
          ),
          AppColors.surface(context),
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: healthColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFor(context),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INBOX HEALTH',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${summary.inboxHealthScore}%',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: 32, letterSpacing: -0.8),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Dot(color: healthColor),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            summary.inboxHealthStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: healthColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      summary.totalMessages == 0
                          ? 'Results appear after the first scan.'
                          : '${_formatCount(summary.totalMessages)} scanned messages',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _HealthRing(percent: summary.inboxHealthScore),
            ],
          ),
          const SizedBox(height: 15),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  Navigator.pushNamed(context, InboxHealthScreen.routeName),
              borderRadius: BorderRadius.circular(13),
              child: Ink(
                height: 42,
                decoration: BoxDecoration(
                  color: healthColor.withValues(
                    alpha: AppColors.isDark(context) ? 0.14 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: healthColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View details',
                      style: TextStyle(
                        color: healthColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 7),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: healthColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        icon: Icons.people_alt_rounded,
        value: summary.totalSenders,
        label: 'Senders',
        detail: 'Identified contacts',
        color: AppColors.primary,
        route: AllSendersScreen.routeName,
      ),
      _MetricData(
        icon: Icons.mark_email_unread_rounded,
        value: summary.unreadEmails,
        label: 'Unread',
        detail: 'Need your attention',
        color: AppColors.indigo,
        route: EmailsScreen.routeName,
        arguments: const EmailListArguments(
          mailbox: 'UNREAD',
          title: 'Unread Emails',
        ),
      ),
      _MetricData(
        icon: Icons.local_offer_rounded,
        value: summary.promotions,
        label: 'Promotions',
        detail: 'Marketing messages',
        color: AppColors.cyan,
        route: EmailsScreen.routeName,
        arguments: const EmailListArguments(
          mailbox: 'ALL',
          category: 'PROMOTIONS',
          title: 'Promotions',
        ),
      ),
      _MetricData(
        icon: Icons.gpp_maybe_rounded,
        value: summary.spam,
        label: 'Spam',
        detail: 'Flagged as junk',
        color: AppColors.danger,
        route: EmailsScreen.routeName,
        arguments: const EmailListArguments(
          mailbox: 'ALL',
          category: 'SPAM',
          title: 'Spam / Junk',
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        final gap = constraints.maxWidth < 340 ? 10.0 : 12.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _MetricCard(data: item),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, data.route, arguments: data.arguments),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.borderFor(
                context,
              ).withValues(alpha: AppColors.isDark(context) ? 0.64 : 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowFor(context),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SoftIcon(icon: data.icon, color: data.color),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 16,
                    color: AppColors.mutedFor(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _formatCount(data.value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CleanupOpportunityCard extends StatelessWidget {
  const _CleanupOpportunityCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final hasOpportunity = summary.cleanupMessages > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.surface(context),
        border: Border.all(color: AppColors.borderFor(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFor(context),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SoftIcon(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart cleanup',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasOpportunity
                          ? '${_formatCount(summary.cleanupMessages)} emails are ready for review.'
                          : 'No cleanup suggestions are available right now.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasOpportunity) ...[
            const SizedBox(height: 17),
            Row(
              children: [
                _OpportunityStat(
                  label: 'Potential space',
                  value: _formatBytes(summary.estimatedSpaceBytes),
                ),
                const SizedBox(width: 10),
                _OpportunityStat(
                  label: 'Can unsubscribe',
                  value: _formatCount(summary.unsubscribeSenders),
                ),
              ],
            ),
          ],
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, BulkCleanScreen.routeName),
              icon: const Icon(Icons.cleaning_services_rounded, size: 17),
              label: Text(hasOpportunity ? 'Review cleanup' : 'Open cleanup'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({
    required this.summary,
    required this.queueingScan,
    required this.onScan,
  });

  final DashboardSummary summary;
  final bool queueingScan;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(
        icon: Icons.people_alt_outlined,
        title: 'All senders',
        detail: '${_formatCount(summary.totalSenders)} identified',
        color: AppColors.primary,
        onTap: () => Navigator.pushNamed(context, AllSendersScreen.routeName),
      ),
      _ActionData(
        icon: Icons.cleaning_services_outlined,
        title: 'Bulk clean',
        detail: '${_formatCount(summary.cleanupMessages)} suggested',
        color: AppColors.success,
        onTap: () => Navigator.pushNamed(context, BulkCleanScreen.routeName),
      ),
      _ActionData(
        icon: Icons.unsubscribe_rounded,
        title: 'Unsubscribe',
        detail: '${_formatCount(summary.unsubscribeSenders)} available',
        color: AppColors.indigo,
        onTap: () => Navigator.pushNamed(context, UnsubscribeScreen.routeName),
      ),
      _ActionData(
        icon: queueingScan ? Icons.sync_rounded : Icons.cloud_sync_outlined,
        title: queueingScan ? 'Queueing…' : 'Scan inbox',
        detail: _scanActionDetail(summary),
        color: AppColors.orange,
        onTap:
            summary.connectedAccountId == null ||
                queueingScan ||
                summary.syncRecoveryAction == 'RECONNECT' ||
                summary.syncRecoveryAction == 'CONFIGURE_GOOGLE'
            ? null
            : onScan,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 340 ? 10.0 : 12.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: _QuickActionCard(action: action),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _ActionData action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: AppColors.borderFor(context).withValues(alpha: 0.56),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowFor(context),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              _SoftIcon(icon: action.icon, color: action.color),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: AppColors.mutedFor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopSendersCard extends StatelessWidget {
  const _TopSendersCard({required this.items});

  final List<TopSenderItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyDashboardCard(
        icon: Icons.people_outline_rounded,
        title: 'No sender rankings yet',
        body: 'Top senders appear after email metadata is scanned.',
      );
    }

    return Container(
      decoration: _surfaceDecoration(context, radius: 20),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _TopSenderRow(item: items[index]),
            if (index != items.length - 1)
              Divider(
                height: 1,
                indent: 62,
                color: AppColors.borderFor(context).withValues(alpha: 0.7),
              ),
          ],
        ],
      ),
    );
  }
}

class _TopSenderRow extends StatelessWidget {
  const _TopSenderRow({required this.item});

  final TopSenderItem item;

  @override
  Widget build(BuildContext context) {
    final initial = item.name.trim().isEmpty
        ? '?'
        : item.name.trim()[0].toUpperCase();
    return InkWell(
      onTap: item.id.isEmpty
          ? null
          : () => Navigator.pushNamed(
              context,
              SenderDetailsScreen.routeName,
              arguments: item.id,
            ),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.softFill(context, AppColors.primary),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCount(item.count),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'messages',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final AlertItem alert;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, '/alert-details', arguments: alert),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: _surfaceDecoration(context, radius: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SoftIcon(
                icon: Icons.shield_outlined,
                color: alert.color,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RiskPill(label: alert.risk, color: alert.color),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${alert.email} • ${_relativeFromValue(alert.time)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice({required this.dashboard, required this.onRetry});

  final DashboardSummary dashboard;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final recovery = dashboard.syncRecoveryAction;
    final needsConnection =
        recovery == 'RECONNECT' || recovery == 'CONFIGURE_GOOGLE';
    final failed =
        dashboard.syncStatus == 'FAILED' ||
        dashboard.syncStatus == 'DISCONNECTED';
    final backfilling = dashboard.syncStatus == 'PARTIAL';
    final color = failed
        ? AppColors.danger
        : backfilling
        ? AppColors.success
        : AppColors.primary;
    final actionLabel = switch (recovery) {
      'RECONNECT' => 'Reconnect',
      'CONFIGURE_GOOGLE' => 'Details',
      _ => 'Retry',
    };
    void handleAction() {
      if (recovery == 'RECONNECT') {
        Navigator.pushNamed(context, ConnectEmailScreen.routeName);
      } else if (recovery == 'CONFIGURE_GOOGLE') {
        Navigator.pushNamed(context, ConnectedAccountsScreen.routeName);
      } else {
        onRetry();
      }
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.softFill(context, color),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _SoftIcon(
            icon: failed
                ? Icons.error_outline_rounded
                : backfilling
                ? Icons.check_circle_outline_rounded
                : Icons.sync_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failed
                      ? needsConnection
                            ? 'Email connection needs attention'
                            : 'Inbox scan needs attention'
                      : backfilling
                      ? 'Recent email is ready'
                      : 'Inbox scan in progress',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  failed
                      ? dashboard.syncError ?? 'Retry the metadata scan.'
                      : backfilling
                      ? 'You can use SenderWho now. Older mail continues importing safely in the background.'
                      : 'Recent mail is being prepared. This should only take a short moment.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
          if (failed)
            TextButton(onPressed: handleAction, child: Text(actionLabel))
          else if (!backfilling)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
        ],
      ),
    );
  }
}

class _SafeInboxCard extends StatelessWidget {
  const _SafeInboxCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(context, radius: 18),
      child: Row(
        children: [
          const _SoftIcon(
            icon: Icons.verified_user_rounded,
            color: AppColors.success,
            size: 44,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No open security alerts',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'SenderWho has not found anything that currently needs review.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 10, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SkeletonBox(height: 52, radius: 16),
        SizedBox(height: context.gap(20)),
        Container(
          height: 238,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderFor(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'INBOX HEALTH',
                style: TextStyle(
                  color: AppColors.mutedFor(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Loading live email insights…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        SizedBox(height: context.gap(28)),
        const _SkeletonBox(height: 18, width: 132),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: _SkeletonBox(height: 128, radius: 18)),
            SizedBox(width: 12),
            Expanded(child: _SkeletonBox(height: 128, radius: 18)),
          ],
        ),
      ],
    );
  }
}

class _DashboardUnavailable extends StatelessWidget {
  const _DashboardUnavailable({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: _surfaceDecoration(context, radius: 22),
          child: Column(
            children: [
              const _SoftIcon(
                icon: Icons.cloud_off_rounded,
                color: AppColors.danger,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                'INBOX HEALTH',
                style: TextStyle(
                  color: AppColors.mutedFor(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Live dashboard unavailable',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SenderWho could not load authenticated email results. Check the API connection or sign in again.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 43,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardStaleNotice extends StatelessWidget {
  const _DashboardStaleNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.softFill(context, AppColors.warning),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 19,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Showing saved results. Live refresh is unavailable.'),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyDashboardCard extends StatelessWidget {
  const _EmptyDashboardCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _surfaceDecoration(context, radius: 18),
      child: Row(
        children: [
          _SoftIcon(icon: icon, color: AppColors.primary, size: 44),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 10, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.caption,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String caption;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _HealthRing extends StatelessWidget {
  const _HealthRing({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: percent.clamp(0, 100).toDouble() / 100,
              strokeWidth: 7,
              backgroundColor: AppColors.trackFor(context),
              color: _healthColorFromScore(percent),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'SCORE',
                style: TextStyle(
                  color: AppColors.mutedFor(context),
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.borderFor(context).withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowFor(context),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, size: 20),
          ),
        ),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon({required this.icon, required this.color, this.size = 38});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.softFill(context, color),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class _OpportunityStat extends StatelessWidget {
  const _OpportunityStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: AppColors.borderFor(context).withValues(alpha: 0.58),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskPill extends StatelessWidget {
  const _RiskPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.softFill(context, color),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, this.width, this.radius = 10});

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.trackFor(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    required this.color,
    required this.route,
    this.arguments,
  });

  final IconData icon;
  final int value;
  final String label;
  final String detail;
  final Color color;
  final String route;
  final Object? arguments;
}

class _ActionData {
  const _ActionData({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback? onTap;
}

BoxDecoration _surfaceDecoration(BuildContext context, {double radius = 18}) {
  return BoxDecoration(
    color: AppColors.surface(context),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: AppColors.borderFor(context).withValues(alpha: 0.56),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowFor(context),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

Color _healthColor(DashboardSummary summary) {
  if (summary.totalMessages == 0) return AppColors.muted;
  return _healthColorFromScore(summary.inboxHealthScore);
}

Color _healthColorFromScore(int score) {
  if (score >= 80) return AppColors.primary;
  if (score >= 60) return AppColors.warning;
  return AppColors.danger;
}

String _relativeFromValue(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed == null ? value : _relativeTime(parsed);
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return '${value.toLocal().year}-${value.toLocal().month.toString().padLeft(2, '0')}-${value.toLocal().day.toString().padLeft(2, '0')}';
}

String _formatCount(int value) {
  final source = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < source.length; index++) {
    if (index > 0 && (source.length - index) % 3 == 0) buffer.write(',');
    buffer.write(source[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _scanActionDetail(DashboardSummary summary) {
  return switch (summary.syncStatus) {
    'PENDING' => 'Queued',
    'SYNCING' => 'In progress',
    'PARTIAL' => 'Importing older mail',
    'FAILED' => 'Retry available',
    'DISCONNECTED' => 'Reconnect required',
    'READY' =>
      summary.lastSyncedAt == null
          ? 'Refresh metadata'
          : _relativeSync(summary.lastSyncedAt),
    _ => 'Account unavailable',
  };
}

String _relativeSync(DateTime? value) {
  if (value == null) return 'Ready';
  return 'Synced ${_relativeTime(value)}';
}
