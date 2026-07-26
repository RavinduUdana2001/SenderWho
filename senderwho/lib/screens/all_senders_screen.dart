import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/sender_details_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/icon_bubble.dart';
import '../widgets/search_box.dart';

class SenderListArguments {
  const SenderListArguments({this.control = 'ALL', this.title});

  final String control;
  final String? title;
}

Color _senderCategoryColor(BuildContext context, String category) {
  return switch (category.trim().toLowerCase()) {
    'social' || 'newsletters' || 'travel' =>
      AppColors.isDark(context) ? AppColors.brandCyan : const Color(0xFF087C98),
    'promotions' || 'orders' || 'important' =>
      AppColors.isDark(context) ? AppColors.warning : const Color(0xFFB86B00),
    'spam' => AppColors.danger,
    'unknown' => AppColors.mutedFor(context),
    _ => AppColors.primary,
  };
}

class AllSendersScreen extends StatefulWidget {
  const AllSendersScreen({super.key, this.repository});

  static const routeName = '/all-senders';
  final SenderWhoRepository? repository;

  @override
  State<AllSendersScreen> createState() => _AllSendersScreenState();
}

class _AllSendersScreenState extends State<AllSendersScreen> {
  static const _tabs = <String, String>{
    'ALL': 'All',
    'PEOPLE': 'People',
    'COMPANIES': 'Companies',
    'NEWSLETTERS': 'Newsletters',
  };
  final _queryController = TextEditingController();
  final _senders = <SenderInfo>[];
  String _kind = 'ALL';
  String _control = 'ALL';
  String? _title;
  bool _initialized = false;
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _hasMore = false;
  bool _showBack = false;
  String? _error;
  String? _inlineLoadError;
  bool _inlineRetryResets = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is SenderListArguments) {
      _showBack = true;
      _control = arguments.control;
      _title = arguments.title;
    }
    _load(reset: true);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) _error = null;
      _inlineLoadError = null;
    });
    final result = await _repository.getSenders(
      page: reset ? 1 : _page + 1,
      kind: _kind,
      control: _control,
      query: _queryController.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result == null) {
        const message = 'Could not load senders.';
        if (_senders.isEmpty) {
          _error = message;
        } else {
          _error = null;
          _inlineLoadError = message;
          _inlineRetryResets = reset;
        }
        return;
      }
      if (reset) _senders.clear();
      _senders.addAll(result.items);
      _page = result.page;
      _total = result.total;
      _hasMore = result.hasMore;
      _error = null;
      _inlineLoadError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader(
            title: _title ?? 'All Senders',
            subtitle: '$_total senders found in your inbox',
            showBack: _showBack,
            action: IconButton.filledTonal(
              tooltip: 'Refresh senders',
              onPressed: _loading ? null : () => _load(reset: true),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
          SizedBox(height: context.gap(18)),
          SearchBox(
            controller: _queryController,
            hint: 'Search name, email or domain',
            onSubmitted: (_) => _load(reset: true),
          ),
          SizedBox(height: context.gap(16)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final tab in _tabs.entries) ...[
                  SelectablePill(
                    label: tab.value,
                    selected: _kind == tab.key,
                    onTap: () {
                      setState(() => _kind = tab.key);
                      _load(reset: true);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          SizedBox(height: context.gap(18)),
          if (_loading && _senders.isEmpty)
            const _SenderListSkeleton()
          else if (_error != null)
            AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 34,
                    color: AppColors.mutedFor(context),
                  ),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  FilledButton.tonal(
                    onPressed: () => _load(reset: true),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          else if (_senders.isEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.softFill(context, AppColors.primary),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.person_search_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No matching senders',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Try another sender type or search term.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < _senders.length; i++) ...[
                  SenderRow(
                    sender: _senders[i],
                    onChanged: () => _load(reset: true),
                  ),
                  if (i != _senders.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          if (_inlineLoadError != null) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_rounded, color: AppColors.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _inlineLoadError!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => _load(reset: _inlineRetryResets),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
          if (_hasMore) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : () => _load(reset: false),
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: const Text('Load more'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SenderRow extends StatelessWidget {
  const SenderRow({super.key, required this.sender, required this.onChanged});

  final SenderInfo sender;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () async {
        await Navigator.pushNamed(
          context,
          SenderDetailsScreen.routeName,
          arguments: sender.id,
        );
        onChanged();
      },
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          _IdentityAvatar(sender: sender),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sender.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  sender.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    if (sender.identityStatus == 'SUSPICIOUS')
                      StatusChip(
                        label: sender.identityRiskLevel == 'HIGH'
                            ? 'High identity risk'
                            : 'Possible impersonation',
                        color: sender.identityRiskLevel == 'HIGH'
                            ? AppColors.danger
                            : AppColors.warning,
                      )
                    else if (sender.isTrusted)
                      const StatusChip(
                        label: 'Trusted by you',
                        color: AppColors.success,
                      )
                    else
                      StatusChip(
                        label: sender.category,
                        color: _senderCategoryColor(context, sender.category),
                      ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '${sender.totalMessages} messages · ${sender.unreadMessages} unread',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TrustScore(score: sender.score),
          const SizedBox(width: 3),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.mutedFor(context),
          ),
        ],
      ),
    );
  }
}

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({required this.sender});

  final SenderInfo sender;

  @override
  Widget build(BuildContext context) {
    if (!sender.isBlocked && sender.identityStatus == 'UNVERIFIED') {
      const label = 'Sender identity is unverified';
      return Tooltip(
        message: label,
        child: Semantics(
          label: '$label. ${sender.name}',
          image: true,
          child: SizedBox.square(
            dimension: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconBubble(
                  icon: Icons.person_outline_rounded,
                  label: sender.initial,
                  size: 48,
                  iconSize: 24,
                  backgroundColor: sender.color,
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    width: 19,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.borderFor(context),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.question_mark_rounded,
                      size: 12,
                      color: AppColors.mutedFor(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final (icon, color, label) = switch ((
      sender.isBlocked,
      sender.identityStatus,
      sender.identityRiskLevel,
    )) {
      (true, _, _) => (Icons.block_rounded, AppColors.danger, 'Blocked sender'),
      (false, 'VERIFIED', _) => (
        Icons.gpp_good_rounded,
        AppColors.success,
        'Verified sender identity',
      ),
      (false, 'SUSPICIOUS', 'HIGH') => (
        Icons.warning_rounded,
        AppColors.danger,
        'High-risk sender identity',
      ),
      (false, 'SUSPICIOUS', _) => (
        Icons.warning_amber_rounded,
        AppColors.warning,
        'Possible sender impersonation',
      ),
      _ => (Icons.help_outline_rounded, AppColors.mutedFor(context), 'Unknown'),
    };
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        image: true,
        child: IconBubble(
          icon: icon,
          size: 48,
          iconSize: 24,
          color: color,
          backgroundColor: AppColors.softFill(context, color),
        ),
      ),
    );
  }
}

class _TrustScore extends StatelessWidget {
  const _TrustScore({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final indicatorColor = score >= 75
        ? AppColors.primary
        : score >= 50
        ? AppColors.mutedFor(context)
        : AppColors.warning;
    return Tooltip(
      message: 'Sender confidence: $score out of 100',
      child: Semantics(
        label: 'Sender confidence $score out of 100',
        child: SizedBox.square(
          dimension: 42,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: score.clamp(0, 100) / 100,
                strokeWidth: 3.5,
                color: indicatorColor,
                backgroundColor: AppColors.trackFor(context),
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text(
                  '$score',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textFor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SenderListSkeleton extends StatelessWidget {
  const _SenderListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.trackFor(context),
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: index.isEven ? 120 : 155,
                        decoration: BoxDecoration(
                          color: AppColors.trackFor(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.trackFor(context),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
