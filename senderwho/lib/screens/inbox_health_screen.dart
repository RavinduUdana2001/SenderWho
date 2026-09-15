import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../utils/responsive.dart';
import '../widgets/app_animated_progress.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_card.dart';
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

  void _reload() {
    setState(() {
      _healthFuture = senderWhoRepository.getInboxHealth();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InboxHealthSummary>(
      future: _healthFuture,
      builder: (context, snapshot) {
        final content = switch ((snapshot.connectionState, snapshot.error)) {
          (ConnectionState.waiting, _) => const AppAsyncLoading(
            message: 'Calculating your inbox health…',
          ),
          (_, final Object error) => AppAsyncError(
            message: appAsyncErrorMessage(error),
            onRetry: _reload,
          ),
          _ => _HealthContent(
            health:
                snapshot.data ??
                const InboxHealthSummary(
                  score: 0,
                  status: 'Unavailable',
                  breakdown: [],
                ),
          ),
        };

        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(
                title: 'Inbox Health',
                subtitle: 'A live score from your stored email metadata',
                showBack: true,
              ),
              SizedBox(height: context.gap(16)),
              AnimatedSwitcher(
                duration: AppMotion.responsive(context, AppMotion.standard),
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                child: KeyedSubtree(
                  key: ValueKey(snapshot.connectionState),
                  child: content,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HealthContent extends StatelessWidget {
  const _HealthContent({required this.health});

  final InboxHealthSummary health;

  @override
  Widget build(BuildContext context) {
    final onGradient = AppColors.onGradientFor(context);
    final onGradientMuted = AppColors.onGradientMutedFor(context);
    final success = AppColors.successFor(context);
    final successVisual = AppColors.successVisualFor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppGradientCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              AppAnimatedProgressRing(
                value: health.score / 100,
                color: successVisual,
                backgroundColor: successVisual.withValues(alpha: 0.16),
                size: 80,
                strokeWidth: 7.5,
                child: AppAnimatedCount(
                  value: health.score,
                  formatter: (value) => '$value%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onGradient,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: successVisual,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            health.status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: success,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      health.score == 0
                          ? 'Run an inbox scan to reveal your health score.'
                          : 'Based on sender trust, spam signals, and inbox organization.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: onGradientMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.gap(24)),
        const SectionTitle(title: 'Health breakdown'),
        SizedBox(height: context.gap(14)),
        if (health.breakdown.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  color: AppColors.mutedFor(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No breakdown is available yet. Scan your inbox to create one.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          for (var index = 0; index < health.breakdown.length; index++) ...[
            _BreakdownCard(item: health.breakdown[index], index: index),
            if (index != health.breakdown.length - 1)
              SizedBox(height: context.gap(14)),
          ],
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.item, required this.index});

  final InboxHealthBreakdown item;
  final int index;

  @override
  Widget build(BuildContext context) {
    final baseColor = _breakdownBaseColor(item, index);
    final color = item.available
        ? AppColors.foregroundFor(context, baseColor)
        : AppColors.mutedFor(context);
    final visualColor = item.available
        ? AppColors.visualAccentFor(context, baseColor)
        : AppColors.mutedFor(context);
    final label = !item.available
        ? 'Not enough data'
        : item.score >= 80
        ? 'Excellent'
        : item.score >= 70
        ? 'Good'
        : 'Needs attention';

    return Semantics(
      label: '${item.label}, $label, ${item.score} out of 100',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.responsive(
          context,
          Duration(milliseconds: 230 + (index * 45)),
        ),
        curve: AppMotion.enter,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10),
            child: child,
          ),
        ),
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.softFill(context, color),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(item.icon, size: 21, color: visualColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.softFill(context, color),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: visualColor.withValues(alpha: 0.26),
                      ),
                    ),
                    child: Text(
                      '${item.score}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              AppAnimatedProgressBar(
                value: item.score / 100,
                color: visualColor,
                backgroundColor: AppColors.trackFor(context),
                height: 6,
              ),
              const SizedBox(height: 11),
              Text(
                item.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _breakdownBaseColor(InboxHealthBreakdown item, int index) {
  final key = item.key.toLowerCase();
  return key.contains('sender') || index == 0
      ? AppColors.orange
      : key.contains('spam') || index == 1
      ? AppColors.info
      : key.contains('clutter') || index == 2
      ? AppColors.indigo
      : AppColors.primary;
}
