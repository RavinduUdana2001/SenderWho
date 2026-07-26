import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_button.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import 'all_senders_screen.dart';
import 'sender_details_screen.dart';

class TopSendersScreen extends StatefulWidget {
  const TopSendersScreen({super.key});

  static const routeName = '/top-senders';

  @override
  State<TopSendersScreen> createState() => _TopSendersScreenState();
}

class _TopSendersScreenState extends State<TopSendersScreen> {
  late Future<List<TopSenderItem>> _topSendersFuture = senderWhoRepository
      .getTopSenders();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TopSenderItem>>(
      future: _topSendersFuture,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <TopSenderItem>[];
        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(
                title: 'Top Senders',
                subtitle: 'Highest-volume senders in scanned email metadata',
              ),
              SizedBox(height: context.gap(18)),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: () => setState(() {
                    _topSendersFuture = senderWhoRepository.getTopSenders();
                  }),
                )
              else if (rows.isEmpty)
                const AppCard(
                  child: Center(child: Text('No sender activity available.')),
                )
              else
                for (var i = 0; i < rows.length; i++) ...[
                  _RankedSenderCard(sender: rows[i], maximum: rows.first.count),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 10),
              AppButton(
                label: 'View All Senders',
                backgroundColor: AppColors.subtle,
                foregroundColor: AppColors.muted,
                onPressed: () => Navigator.pushNamed(
                  context,
                  AllSendersScreen.routeName,
                  arguments: const SenderListArguments(title: 'All Senders'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RankedSenderCard extends StatelessWidget {
  const _RankedSenderCard({required this.sender, required this.maximum});

  final TopSenderItem sender;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final medalColor = switch (sender.rank) {
      1 => const Color(0xFFF5B942),
      2 => const Color(0xFF9AA7BA),
      3 => const Color(0xFFC98755),
      _ => AppColors.muted,
    };
    final progress = maximum == 0 ? 0.0 : sender.count / maximum;
    return AppCard(
      onTap: sender.id.isEmpty
          ? null
          : () => Navigator.pushNamed(
              context,
              SenderDetailsScreen.routeName,
              arguments: sender.id,
            ),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.softFill(context, medalColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#${sender.rank}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: medalColor,
                fontWeight: FontWeight.w900,
              ),
            ),
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
                        sender.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      '${sender.count}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: AppColors.trackFor(context),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
