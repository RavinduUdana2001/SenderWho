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
import '../widgets/section_title.dart';

class InboxHealthScreen extends StatefulWidget {
  const InboxHealthScreen({super.key});

  static const routeName = '/inbox-health';

  @override
  State<InboxHealthScreen> createState() => _InboxHealthScreenState();
}

class _InboxHealthScreenState extends State<InboxHealthScreen> {
  late Future<InboxHealthSummary> _healthFuture = senderWhoRepository
      .getInboxHealth();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InboxHealthSummary>(
      future: _healthFuture,
      builder: (context, snapshot) {
        final health =
            snapshot.data ??
            const InboxHealthSummary(
              score: 0,
              status: 'Unavailable',
              breakdown: [],
            );

        if (snapshot.hasError) {
          return AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppHeader(
                  title: 'Inbox Health',
                  subtitle: 'A live score based on stored Gmail metadata',
                  showBack: true,
                ),
                SizedBox(height: context.gap(18)),
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: () => setState(() {
                    _healthFuture = senderWhoRepository.getInboxHealth();
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
                title: 'Inbox Health',
                subtitle: 'A live score based on stored Gmail metadata',
                showBack: true,
              ),
              SizedBox(height: context.gap(18)),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: health.score / 100,
                            strokeWidth: 8,
                            backgroundColor: AppColors.trackFor(context),
                            color: AppColors.success,
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: Text(
                              '${health.score}%',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  health.status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            health.score == 0
                                ? 'Inbox health will appear after Gmail metadata is scanned.'
                                : 'Calculated from the sender and message metadata in your latest Gmail scan.',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.gap(25)),
              const SectionTitle(title: 'Health Breakdown'),
              SizedBox(height: context.gap(25)),
              for (final item in health.breakdown) ...[
                _BreakdownTile(
                  icon: item.icon,
                  title: item.label,
                  body: item.body,
                  score: item.score,
                  label: !item.available
                      ? 'Not enough data'
                      : item.score >= 80
                      ? 'Excellent'
                      : item.score >= 70
                      ? 'Good'
                      : 'Needs Attention',
                  color: item.available
                      ? item.color
                      : AppColors.mutedFor(context),
                ),
                const SizedBox(height: 25),
              ],
              if (health.breakdown.isEmpty)
                Text(
                  'No health breakdown is available yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.score,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final int score;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$score',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: StatusChip(label: label, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: score / 100,
              backgroundColor: AppColors.trackFor(context),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
