import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../utils/app_navigation.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_header.dart';
import '../widgets/mail_avatar.dart';
import '../widgets/app_page.dart';
import 'all_senders_screen.dart';
import 'sender_details_screen.dart';

class TopSendersScreen extends StatefulWidget {
  const TopSendersScreen({super.key, this.repository});
  final SenderWhoRepository? repository;

  static const routeName = '/top-senders';

  @override
  State<TopSendersScreen> createState() => _TopSendersScreenState();
}

class _TopSendersScreenState extends State<TopSendersScreen> {
  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  late Future<List<TopSenderItem>> _topSendersFuture = _repository
      .getTopSenders();

  Future<void> _reload() async {
    setState(() {
      _topSendersFuture = _repository.getTopSenders();
    });
    try {
      await _topSendersFuture;
    } on Object {
      // FutureBuilder keeps the retry state visible.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TopSenderItem>>(
      future: _topSendersFuture,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <TopSenderItem>[];
        return AppPage(
          onRefresh: _reload,
          header: const AppHeader(
            title: 'Top Senders',
            subtitle: 'Senders who email you most',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: context.gap(18)),
              if (snapshot.connectionState == ConnectionState.waiting)
                const AppAsyncLoading(message: 'Loading top senders…')
              else if (snapshot.hasError)
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: _reload,
                )
              else if (rows.isEmpty)
                const AppEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No sender activity yet',
                  message:
                      'Your most active senders appear after a mailbox scan.',
                )
              else
                for (var i = 0; i < rows.length; i++) ...[
                  _RankedSenderCard(sender: rows[i]),
                  const Divider(height: 1),
                ],
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  label: const Text('View all senders'),
                  icon: const Icon(Icons.people_outline_rounded, size: 18),
                  onPressed: () =>
                      AppNavigation.open(context, AllSendersScreen.routeName),
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
  const _RankedSenderCard({required this.sender});
  final TopSenderItem sender;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: sender.id.isEmpty
        ? null
        : () => Navigator.pushNamed(
            context,
            SenderDetailsScreen.routeName,
            arguments: sender.id,
          ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          MailAvatar(name: sender.name, size: 36),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textFor(context),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sender.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${sender.count} emails',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  '#${sender.rank}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
