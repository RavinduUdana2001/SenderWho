import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/repository_scope.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_motion.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';

class ActivityInsightsScreen extends StatefulWidget {
  const ActivityInsightsScreen({super.key, this.repository});
  final SenderWhoRepository? repository;
  static const routeName = '/activity';

  @override
  State<ActivityInsightsScreen> createState() => _ActivityInsightsScreenState();
}

class _ActivityInsightsScreenState extends State<ActivityInsightsScreen> {
  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);
  late Future<ActivityInsights> _activityFuture = _load();
  ActivityInsights? _cached;
  bool _loading = false;

  Future<ActivityInsights> _load() async {
    _loading = true;
    try {
      final activity = await _repository.getActivityInsights();
      if (mounted) _cached = activity;
      return activity;
    } finally {
      _loading = false;
    }
  }

  Future<void> _reload() async {
    if (_loading) return;
    setState(() {
      _activityFuture = _load();
    });
    try {
      await _activityFuture;
    } on Object {
      // Keep the last successful view, or show the initial retry state.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ActivityInsights>(
    future: _activityFuture,
    builder: (context, snapshot) {
      final activity = snapshot.data ?? _cached;
      return AppPage(
        maxContentWidth: 760,
        onRefresh: _reload,
        header: AppHeader(
          title: 'Activity',
          action: IconButton(
            tooltip: 'Refresh activity',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AppAsyncError(
                  title: activity == null
                      ? 'Activity unavailable'
                      : 'Showing the last update',
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: _reload,
                ),
              ),
            if (activity == null && !snapshot.hasError)
              const AppAsyncLoading(message: 'Loading activity…'),
            if (activity != null)
              if (activity.stats.isEmpty && activity.weeklyActivity.isEmpty)
                const AppEmptyState(
                  icon: Icons.insights_outlined,
                  title: 'No activity yet',
                  message: 'Your email trends appear after a mailbox scan.',
                )
              else ...[
                Text(
                  'Your week in email',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  activity.period,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (activity.stats.isNotEmpty) ...[
                  _ActivitySummary(stats: activity.stats),
                  const SizedBox(height: 20),
                ],
                if (activity.weeklyActivity.isNotEmpty)
                  _WeeklyChart(
                    key: ValueKey(activity),
                    points: activity.weeklyActivity,
                  ),
              ],
          ],
        ),
      );
    },
  );
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.stats});
  final List<ActivityStat> stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final main =
        stats
            .where((s) => ['received', 'emailsReceived'].contains(s.key))
            .firstOrNull ??
        stats.first;
    final remaining = stats.where((s) => !identical(s, main)).toList();
    return Column(
      children: [
        Container(
          key: const ValueKey('activity-summary'),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withValues(alpha: .14),
                scheme.surfaceContainer,
              ],
            ),
            border: Border.all(color: scheme.primary.withValues(alpha: .16)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.mark_email_unread_outlined,
                color: scheme.primary,
                size: 24,
              ),
              const SizedBox(height: 10),
              Text(
                main.value,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 4),
              Text(
                main.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (remaining.isNotEmpty) ...[
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth >= 300 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 21
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final stat in remaining)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              stat.key.toLowerCase().contains('read')
                                  ? Icons.drafts_outlined
                                  : stat.key == 'spaceSaved'
                                  ? Icons.storage_rounded
                                  : Icons.cleaning_services_outlined,
                              size: 19,
                              color: scheme.primary,
                            ),
                            const SizedBox(height: 7),
                            Text(
                              stat.value,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stat.label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _WeeklyChart extends StatefulWidget {
  const _WeeklyChart({super.key, required this.points});
  final List<WeeklyActivityPoint> points;
  @override
  State<_WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<_WeeklyChart> {
  late int _selected = widget.points.length - 1;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final point = widget.points[_selected];
    final hasActivity = widget.points.any((p) => p.value > 0);
    final peak = widget.points.fold<double>(
      0,
      (max, p) => p.value > max ? p.value : max,
    );
    final description = point.value == 0
        ? 'No emails received'
        : point.value == peak
        ? 'Busiest day'
        : 'Lighter email volume';
    return Container(
      key: const ValueKey('activity-weekly-chart'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly activity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Daily email volume',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          if (!hasActivity)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'No incoming mail this week.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  height: 144,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Peak',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text('0', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          SizedBox(
                            height: 144,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (var i = 0; i < 3; i++)
                                  Divider(
                                    height: 1,
                                    color: scheme.outlineVariant.withValues(
                                      alpha: .45,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < widget.points.length; i++)
                                Expanded(
                                  child: Semantics(
                                    button: true,
                                    selected: _selected == i,
                                    label:
                                        '${widget.points[i].day}, ${widget.points[i].value == 0
                                            ? 'no emails'
                                            : widget.points[i].value == peak
                                            ? 'peak email volume'
                                            : 'relative email volume'}',
                                    child: InkWell(
                                      key: ValueKey('activity-day-$i'),
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () =>
                                          setState(() => _selected = i),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        child: Column(
                                          children: [
                                            SizedBox(
                                              height: 144,
                                              child: Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: TweenAnimationBuilder<double>(
                                                  tween: Tween(
                                                    begin: 0,
                                                    end: peak > 0
                                                        ? widget
                                                                  .points[i]
                                                                  .value /
                                                              peak
                                                        : 0,
                                                  ),
                                                  duration:
                                                      AppMotion.responsive(
                                                        context,
                                                        AppMotion.deliberate,
                                                      ),
                                                  curve: AppMotion.enter,
                                                  builder: (context, value, _) => Container(
                                                    key: ValueKey(
                                                      'activity-bar-$i',
                                                    ),
                                                    width: 20,
                                                    height: 144 * value,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          const BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  6,
                                                                ),
                                                          ),
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          scheme.primary
                                                              .withValues(
                                                                alpha:
                                                                    _selected ==
                                                                        i
                                                                    ? 1
                                                                    : .7,
                                                              ),
                                                          scheme.primary
                                                              .withValues(
                                                                alpha:
                                                                    _selected ==
                                                                        i
                                                                    ? .7
                                                                    : .3,
                                                              ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              widget.points[i].day,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: _selected == i
                                                        ? scheme.primary
                                                        : scheme
                                                              .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${point.day} · $description',
              key: const ValueKey('activity-selected-day'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a day to explore. Bars compare daily volume.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
