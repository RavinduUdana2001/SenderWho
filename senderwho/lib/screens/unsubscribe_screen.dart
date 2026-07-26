import 'dart:async';

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
import '../widgets/icon_bubble.dart';
import 'sender_details_screen.dart';

class UnsubscribeScreen extends StatefulWidget {
  const UnsubscribeScreen({super.key, this.repository});

  static const routeName = '/unsubscribe';
  final SenderWhoRepository? repository;

  @override
  State<UnsubscribeScreen> createState() => _UnsubscribeScreenState();
}

class _UnsubscribeScreenState extends State<UnsubscribeScreen> {
  static const _pollInterval = Duration(seconds: 3);
  static const _pollFailureDelays = <Duration>[
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];
  static const _maxConsecutivePollFailures = 5;

  late Future<List<UnsubscribeCandidate>> _candidatesFuture;
  final Map<String, UnsubscribeJobInfo> _jobs = {};
  final Map<String, UnsubscribeCandidate> _candidateCache = {};
  final Set<String> _busySenders = {};
  final Set<String> _trustingSenders = {};
  final Set<String> _hiddenSenderIds = {};
  String? _jobError;
  Timer? _pollTimer;
  int _consecutivePollFailures = 0;
  bool _polling = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

  @override
  void initState() {
    super.initState();
    _candidatesFuture = _loadCandidates();
    unawaited(_restoreActiveJobs());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _hasActiveJobs => _jobs.values.any((job) => job.isActive);

  Future<List<UnsubscribeCandidate>> _loadCandidates() async {
    final candidates = await _repository.getUnsubscribeCandidates();
    for (final candidate in candidates) {
      _candidateCache[candidate.id] = candidate;
    }
    return candidates;
  }

  Future<void> _restoreActiveJobs() async {
    try {
      final jobs = await _repository.getActiveUnsubscribeJobs();
      if (!mounted) return;
      setState(() {
        _jobError = null;
        _consecutivePollFailures = 0;
        for (final job in jobs) {
          if (job.senderId.isNotEmpty) _jobs[job.senderId] = job;
        }
      });
      if (_hasActiveJobs) _schedulePoll();
    } on SenderWhoRequestException catch (error) {
      if (!mounted) return;
      setState(() => _jobError = error.message);
    }
  }

  Future<void> _start(
    UnsubscribeCandidate candidate, {
    bool confirm = true,
  }) async {
    if (_busySenders.contains(candidate.id)) return;
    final currentJob = _jobs[candidate.id];
    if (currentJob?.isActive == true || currentJob?.status == 'COMPLETED') {
      return;
    }
    if (confirm) {
      final approved = await _confirmUnsubscribe(candidate);
      if (approved != true || !mounted) return;
    }
    _candidateCache[candidate.id] = candidate;
    setState(() {
      _busySenders.add(candidate.id);
      _jobError = null;
    });
    final job = await _repository.createUnsubscribeJob(candidate.id);
    if (!mounted) return;
    setState(() {
      _busySenders.remove(candidate.id);
      if (job != null) {
        _jobs[candidate.id] = job;
        _consecutivePollFailures = 0;
      }
    });
    if (job == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _repository.lastError ??
                'Unsubscribe could not be started. Please try again.',
          ),
        ),
      );
      return;
    }
    if (job.isActive) {
      _schedulePoll();
    } else if (job.status == 'COMPLETED') {
      setState(() {
        _candidatesFuture = _loadCandidates();
      });
    }
  }

  Future<void> _startAll(List<UnsubscribeCandidate> items) async {
    if (items.isEmpty || items.any((item) => _busySenders.contains(item.id))) {
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unsubscribe from ${items.length} senders?'),
        content: const Text(
          'SenderWho will ask each provider to stop future recurring email. Existing messages stay in your inbox and are never moved to Trash. Providers may take time to apply the request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    for (final item in items) {
      _candidateCache[item.id] = item;
    }
    setState(() {
      _busySenders.addAll(items.map((item) => item.id));
      _jobError = null;
    });
    final result = await _repository.createUnsubscribeJobs(
      items.map((item) => item.id).toList(),
    );
    if (!mounted) return;
    setState(() {
      _busySenders.removeAll(items.map((item) => item.id));
      for (final job in result?.jobs ?? const <UnsubscribeJobInfo>[]) {
        if (job.senderId.isNotEmpty) _jobs[job.senderId] = job;
      }
      if (result != null) _consecutivePollFailures = 0;
    });
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _repository.lastError ??
                'The unsubscribe requests could not be queued.',
          ),
        ),
      );
      return;
    }
    if (_hasActiveJobs) _schedulePoll();
    if (result.jobs.any((job) => job.status == 'COMPLETED')) {
      setState(() {
        _candidatesFuture = _loadCandidates();
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.failures.isEmpty
              ? '${result.jobs.length} unsubscribe requests queued.'
              : '${result.jobs.length} queued and ${result.failures.length} could not be started.',
        ),
      ),
    );
  }

  Future<bool?> _confirmUnsubscribe(UnsubscribeCandidate candidate) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unsubscribe from ${candidate.name}?'),
        content: Text(
          'SenderWho will ask this provider to stop future recurring email to your account. Existing messages stay in your inbox and are never moved to Trash. The provider may take time to apply it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
  }

  Future<void> _retry(UnsubscribeCandidate candidate) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Retry unsubscribe from ${candidate.name}?'),
        content: Text(
          'SenderWho will retry the verified one-click request for ${candidate.email}. Existing messages stay in your inbox. Retry only if the previous request failed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      await _start(candidate, confirm: false);
    }
  }

  Future<void> _trust(UnsubscribeCandidate candidate) async {
    if (_trustingSenders.contains(candidate.id)) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Trust ${candidate.name}?'),
        content: Text(
          '${candidate.email} will be protected as a trusted sender and removed from unsubscribe suggestions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trust sender'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _trustingSenders.add(candidate.id));
    final trusted = await _repository.setSenderTrusted(candidate.id, true);
    if (!mounted) return;
    setState(() {
      _trustingSenders.remove(candidate.id);
      if (trusted) {
        _hiddenSenderIds.add(candidate.id);
        _jobs.remove(candidate.id);
        _candidateCache.remove(candidate.id);
        _candidatesFuture = _loadCandidates();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          trusted
              ? '${candidate.name} is now trusted and was removed from unsubscribe suggestions.'
              : _repository.lastError ??
                    'This sender could not be trusted. Please try again.',
        ),
      ),
    );
  }

  void _schedulePoll([Duration delay = _pollInterval]) {
    _pollTimer?.cancel();
    if (!mounted || !_hasActiveJobs) return;
    _pollTimer = Timer(delay, () => unawaited(_pollJobs()));
  }

  Future<void> _pollJobs() async {
    if (_polling || !_hasActiveJobs) return;
    _polling = true;
    _pollTimer?.cancel();
    final entries = _jobs.entries
        .where((entry) => entry.value.isActive)
        .toList();
    List<UnsubscribeJobInfo?> refreshed;
    try {
      final jobs = await _repository.getUnsubscribeJobs(
        entries.map((entry) => entry.value.id).toList(),
      );
      final byId = {for (final job in jobs) job.id: job};
      refreshed = entries.map((entry) => byId[entry.value.id]).toList();
    } on Object {
      refreshed = List<UnsubscribeJobInfo?>.filled(entries.length, null);
    }
    if (!mounted) return;

    final refreshFailed = refreshed.any((job) => job == null);
    var completed = 0;
    var failed = 0;
    setState(() {
      if (refreshFailed) {
        _consecutivePollFailures += 1;
        final paused = _consecutivePollFailures >= _maxConsecutivePollFailures;
        _jobError = paused
            ? 'Automatic progress updates paused after repeated connection failures. Your unsubscribe jobs continue safely in the background.'
            : _repository.lastError ??
                  'Job progress could not be refreshed. SenderWho will retry automatically.';
      } else {
        _consecutivePollFailures = 0;
        _jobError = null;
      }
      for (var index = 0; index < entries.length; index++) {
        final job = refreshed[index];
        if (job == null) continue;
        _jobs[entries[index].key] = job;
        if (job.status == 'COMPLETED') {
          completed += 1;
        } else if (job.status == 'FAILED') {
          failed += 1;
        }
      }
      if (completed > 0) {
        _candidatesFuture = _loadCandidates();
      }
    });
    _polling = false;
    if (completed > 0 || failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$completed provider${completed == 1 ? '' : 's'} accepted the request${failed > 0 ? ', $failed failed' : ''}.',
          ),
        ),
      );
    }
    if (!_hasActiveJobs) return;
    if (_consecutivePollFailures >= _maxConsecutivePollFailures) return;
    if (refreshFailed) {
      final delayIndex = (_consecutivePollFailures - 1).clamp(
        0,
        _pollFailureDelays.length - 1,
      );
      _schedulePoll(_pollFailureDelays[delayIndex]);
    } else {
      _schedulePoll();
    }
  }

  void _retryProgress() {
    _pollTimer?.cancel();
    setState(() {
      _jobError = null;
      _consecutivePollFailures = 0;
    });
    if (_hasActiveJobs) {
      unawaited(_pollJobs());
    } else {
      unawaited(_restoreActiveJobs());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UnsubscribeCandidate>>(
      future: _candidatesFuture,
      builder: (context, snapshot) {
        final liveItems = (snapshot.data ?? const <UnsubscribeCandidate>[])
            .where((item) => !_hiddenSenderIds.contains(item.id))
            .toList();
        final liveIds = liveItems.map((item) => item.id).toSet();
        final retainedItems = _jobs.entries
            .where(
              (entry) =>
                  (entry.value.status == 'FAILED' ||
                      entry.value.status == 'CANCELED') &&
                  !liveIds.contains(entry.key),
            )
            .map((entry) => _candidateCache[entry.key])
            .whereType<UnsubscribeCandidate>();
        final items = [...liveItems, ...retainedItems];
        final actionableItems = liveItems
            .where(
              (item) =>
                  !_busySenders.contains(item.id) &&
                  (_jobs[item.id] == null ||
                      _jobs[item.id]?.status == 'FAILED' ||
                      _jobs[item.id]?.status == 'CANCELED'),
            )
            .toList();
        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppHeader(
                title: 'Unsubscribe',
                subtitle: 'Stop future recurring email',
                action: IconButton.filledTonal(
                  tooltip: 'Refresh candidates',
                  onPressed: () {
                    setState(() {
                      _candidatesFuture = _loadCandidates();
                    });
                    _retryProgress();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ),
              SizedBox(height: context.gap(18)),
              if (_jobError case final error?) ...[
                AppAsyncError(
                  title: 'Could not refresh unsubscribe progress',
                  message: error,
                  onRetry: _retryProgress,
                ),
                SizedBox(height: context.gap(14)),
              ],
              _UnsubscribeHero(count: actionableItems.length),
              SizedBox(height: context.gap(18)),
              if (snapshot.connectionState == ConnectionState.waiting)
                const _UnsubscribeSkeleton()
              else if (snapshot.hasError)
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: () => setState(() {
                    _candidatesFuture = _loadCandidates();
                  }),
                )
              else if (items.isEmpty)
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 34,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.softFill(context, AppColors.success),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'You are all caught up',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'No supported one-click unsubscribe senders were found.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _UnsubscribeRow(
                        candidate: items[i],
                        starting: _busySenders.contains(items[i].id),
                        trusting: _trustingSenders.contains(items[i].id),
                        job: _jobs[items[i].id],
                        onUnsubscribe: () => _start(items[i]),
                        onRetry: () => _retry(items[i]),
                        onTrust: () => _trust(items[i]),
                      ),
                      if (i != items.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
              if (actionableItems.isNotEmpty) ...[
                SizedBox(height: context.gap(22)),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.mutedFor(context),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'This asks providers to stop future recurring mail. It never archives, deletes, or moves existing email messages to Trash.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.gap(18)),
                AppButton(
                  label: 'Unsubscribe from All (${actionableItems.length})',
                  backgroundColor: AppColors.danger,
                  onPressed: () => _startAll(actionableItems),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _UnsubscribeRow extends StatelessWidget {
  const _UnsubscribeRow({
    required this.candidate,
    required this.starting,
    required this.trusting,
    required this.job,
    required this.onUnsubscribe,
    required this.onRetry,
    required this.onTrust,
  });

  final UnsubscribeCandidate candidate;
  final bool starting;
  final bool trusting;
  final UnsubscribeJobInfo? job;
  final VoidCallback onUnsubscribe;
  final VoidCallback onRetry;
  final VoidCallback onTrust;

  @override
  Widget build(BuildContext context) {
    final jobStatus = _jobStatusPresentation(job, starting: starting);
    return AppCard(
      onTap: candidate.id.isEmpty
          ? null
          : () => Navigator.pushNamed(
              context,
              SenderDetailsScreen.routeName,
              arguments: candidate.id,
            ),
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          IconBubble(
            icon: Icons.mail_outline_rounded,
            size: 46,
            iconSize: 20,
            color: candidate.color,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  candidate.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (candidate.reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    candidate.reason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
                if (jobStatus != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (jobStatus.spinning)
                        SizedBox.square(
                          dimension: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: jobStatus.color,
                          ),
                        )
                      else
                        Icon(jobStatus.icon, size: 15, color: jobStatus.color),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          jobStatus.label,
                          key: ValueKey('unsubscribe-status-${candidate.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: jobStatus.color,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (jobStatus.reason case final reason?) ...[
                    const SizedBox(height: 5),
                    Text(
                      reason,
                      key: ValueKey('unsubscribe-failure-${candidate.id}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: jobStatus.color),
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (starting || trusting || job?.isActive == true)
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (job?.status == 'FAILED' || job?.status == 'CANCELED')
            TextButton.icon(
              key: ValueKey('unsubscribe-retry-${candidate.id}'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            )
          else if (job?.status == 'COMPLETED')
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.softFill(context, AppColors.success),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 20,
                color: AppColors.success,
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Unsubscribe',
                  onPressed: onUnsubscribe,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    backgroundColor: AppColors.softFill(
                      context,
                      AppColors.danger,
                    ),
                  ),
                  icon: const Icon(Icons.unsubscribe_rounded, size: 19),
                ),
                TextButton(
                  key: ValueKey('trust-unsubscribe-${candidate.id}'),
                  onPressed: onTrust,
                  child: const Text('Trust'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _JobStatusPresentation {
  const _JobStatusPresentation({
    required this.label,
    required this.color,
    required this.icon,
    this.spinning = false,
    this.reason,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool spinning;
  final String? reason;
}

_JobStatusPresentation? _jobStatusPresentation(
  UnsubscribeJobInfo? job, {
  required bool starting,
}) {
  if (starting) {
    return const _JobStatusPresentation(
      label: 'Starting',
      color: AppColors.primary,
      icon: Icons.hourglass_top_rounded,
      spinning: true,
    );
  }
  switch (job?.status) {
    case 'QUEUED':
      return const _JobStatusPresentation(
        label: 'Queued',
        color: AppColors.warning,
        icon: Icons.schedule_rounded,
        spinning: true,
      );
    case 'RUNNING':
      return const _JobStatusPresentation(
        label: 'Running',
        color: AppColors.primary,
        icon: Icons.sync_rounded,
        spinning: true,
      );
    case 'COMPLETED':
      return const _JobStatusPresentation(
        label: 'Request accepted',
        color: AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      );
    case 'FAILED':
      return _JobStatusPresentation(
        label: 'Needs retry',
        color: AppColors.warning,
        icon: Icons.refresh_rounded,
        reason: job!.failureReason.isNotEmpty
            ? job.failureReason
            : 'The provider could not complete this request. Please retry.',
      );
    case 'CANCELED':
      return const _JobStatusPresentation(
        label: 'Canceled',
        color: AppColors.warning,
        icon: Icons.cancel_outlined,
        reason: 'The request was canceled before it reached the provider.',
      );
    default:
      return null;
  }
}

class _UnsubscribeHero extends StatelessWidget {
  const _UnsubscribeHero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  key: const ValueKey('unsubscribe-actionable-count'),
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  count == 1 ? 'sender available' : 'senders available',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Send verified requests to stop future recurring email.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.softFill(context, AppColors.danger),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.unsubscribe_rounded,
              color: AppColors.danger,
              size: 29,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsubscribeSkeleton extends StatelessWidget {
  const _UnsubscribeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: LinearProgressIndicator(
              color: AppColors.trackFor(context),
              backgroundColor: AppColors.trackFor(context),
            ),
          ),
        ),
      ),
    );
  }
}
