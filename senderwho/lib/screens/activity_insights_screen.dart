import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/section_title.dart';

class ActivityInsightsScreen extends StatefulWidget {
  const ActivityInsightsScreen({super.key});

  static const routeName = '/activity';

  @override
  State<ActivityInsightsScreen> createState() => _ActivityInsightsScreenState();
}

class _ActivityInsightsScreenState extends State<ActivityInsightsScreen> {
  late Future<ActivityInsights> _activityFuture = senderWhoRepository
      .getActivityInsights();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ActivityInsights>(
      future: _activityFuture,
      builder: (context, snapshot) {
        final activity =
            snapshot.data ??
            ActivityInsights.fromJson({
              'period': 'Unavailable',
              'stats': const [],
              'weeklyActivity': const [],
            });

        if (snapshot.hasError) {
          return AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppHeader(
                  title: 'Activity',
                  subtitle: 'Trends from your stored Gmail metadata',
                ),
                SizedBox(height: context.gap(18)),
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: () => setState(() {
                    _activityFuture = senderWhoRepository.getActivityInsights();
                  }),
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
                title: 'Activity',
                subtitle: 'Trends from your stored Gmail metadata',
              ),
              SizedBox(height: context.gap(18)),
              AppCard(
                padding: const EdgeInsets.all(17),
                color: AppColors.softFill(context, AppColors.primary),
                borderColor: AppColors.primary.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.period,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Your latest inbox activity snapshot',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(18)),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 350 ? 2 : 3;
                  const gap = 10.0;
                  final width =
                      (constraints.maxWidth - (gap * (columns - 1))) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final stat in activity.stats)
                        SizedBox(
                          width: width,
                          child: _InsightStat(
                            statKey: stat.key,
                            value: stat.value,
                            label: stat.label,
                            color: stat.color,
                          ),
                        ),
                    ],
                  );
                },
              ),
              SizedBox(height: context.gap(25)),
              const SectionTitle(title: 'Weekly Activity'),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: SizedBox(
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final point in activity.weeklyActivity)
                        _Bar(day: point.day, value: point.value),
                    ],
                  ),
                ),
              ),
              if (activity.stats.isEmpty && activity.weeklyActivity.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'Activity will appear after Gmail metadata is scanned.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InsightStat extends StatelessWidget {
  const _InsightStat({
    required this.statKey,
    required this.value,
    required this.label,
    required this.color,
  });

  final String statKey;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: SizedBox(
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: statKey == 'emailsReceived'
                    ? AppColors.textFor(context)
                    : color,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.day, required this.value});

  final String day;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: value,
                child: Container(
                  width: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(day, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
