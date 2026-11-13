import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_transport.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_card.dart';
import '../widgets/mail_list_surface.dart';
import '../widgets/search_box.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/mail_avatar.dart';
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
  List<UnsubscribeCandidate> _lastCandidates = const [];
  bool _selecting = false;
  bool _showSearch = false;
  String _filter = 'ALL';
  final _query = TextEditingController();
  final _selected = <String>{};
  Timer? _searchDebounce;
  RequestCancellation? _candidateCancellation;
  int _candidateGeneration = 0, _page = 0, _total = 0;
  bool _hasMore = false, _loadingMore = false;
  String? _moreError;
  String _appliedCandidateQuery = '', _appliedCandidateFilter = 'ALL';

  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  @override
  void initState() {
    super.initState();
    _candidatesFuture = _loadCandidates();
    unawaited(_restoreActiveJobs());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _searchDebounce?.cancel();
    _candidateCancellation?.cancel();
    _query.dispose();
    super.dispose();
  }

  bool get _hasActiveJobs => _jobs.values.any((job) => job.isActive);

  Future<List<UnsubscribeCandidate>> _loadCandidates() async {
    final generation = ++_candidateGeneration;
    _candidateCancellation?.cancel();
    final cancellation = _candidateCancellation = RequestCancellation();
    final query = _query.text.trim(), filter = _filter;
    _loadingMore = false;
    _moreError = null;
    final result = await _repository.getUnsubscribePage(
      query: query,
      filter: filter,
      cancellation: cancellation,
    );
    if (!mounted || generation != _candidateGeneration) return _lastCandidates;
    if (result == null) {
      throw SenderWhoRequestException(
        _repository.lastError ??
            'Subscriptions could not be loaded. Try again.',
      );
    }
    _page = result.page;
    _appliedCandidateQuery = query;
    _appliedCandidateFilter = filter;
    _total = result.total;
    _hasMore = result.hasMore;
    _lastCandidates = result.items;
    _remember(result);
    return _lastCandidates;
  }

  void _remember(UnsubscribeCandidatePage result) {
    for (final candidate in result.items) {
      _candidateCache[candidate.id] = candidate;
    }
    for (final job in result.jobs) {
      _jobs[job.senderId] = job;
    }
    if (_hasActiveJobs && !_polling) _schedulePoll();
  }

  void _changeCandidateFilters({bool debounce = false}) {
    _searchDebounce?.cancel();
    // Invalidate the prior request immediately, including while typing.
    _candidateGeneration++;
    _candidateCancellation?.cancel();
    void apply() {
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _selecting = false;
        _page = 0;
        _lastCandidates = const [];
        _hasMore = false;
        _total = 0;
        _candidatesFuture = _loadCandidates();
        _candidatesFuture.ignore();
      });
    }

    if (debounce) {
      _searchDebounce = Timer(const Duration(milliseconds: 300), apply);
      setState(() {});
    } else {
      apply();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    if (_query.text.trim() != _appliedCandidateQuery ||
        _filter != _appliedCandidateFilter) {
      _changeCandidateFilters();
      return;
    }
    final generation = _candidateGeneration;
    final cancellation = _candidateCancellation;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    final result = await _repository.getUnsubscribePage(
      page: _page + 1,
      query: _query.text,
      filter: _filter,
      cancellation: cancellation,
    );
    if (!mounted || generation != _candidateGeneration) return;
    setState(() {
      _loadingMore = false;
      if (result == null) {
        _moreError =
            _repository.lastError ?? 'More subscriptions could not be loaded.';
        return;
      }
      final byId = {
        for (final item in _lastCandidates) item.id: item,
        for (final item in result.items) item.id: item,
      };
      _lastCandidates = byId.values.toList();
      _page = result.page;
      _total = result.total;
      _hasMore = result.hasMore;
      _remember(result);
      _candidatesFuture = Future.value(_lastCandidates);
    });
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
        scrollable: true,
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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
        if (job.senderId.isNotEmpty) {
          _jobs[job.senderId] = job;
          _selected.remove(job.senderId);
        }
      }
      if (_selected.isEmpty) _selecting = false;
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
        scrollable: true,
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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
        scrollable: true,
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
        scrollable: true,
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
        _selected.remove(candidate.id);
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
    final chunks = (_jobs.values.where((job) => job.isActive).length / 25)
        .ceil()
        .clamp(1, 1000);
    final effectiveDelay = delay < _pollInterval * chunks
        ? _pollInterval * chunks
        : delay;
    _pollTimer = Timer(effectiveDelay, () => unawaited(_pollJobs()));
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
            ? 'Automatic progress updates paused. Your unsubscribe requests continue in the background.'
            : _repository.lastError ??
                  'Request progress could not be refreshed. SenderWho will retry automatically.';
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
            '${[if (completed > 0) '$completed unsubscribe request${completed == 1 ? '' : 's'} accepted', if (failed > 0) '$failed request${failed == 1 ? '' : 's'} could not be completed'].join('; ')}.',
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

  Future<void> _refresh() async {
    final future = _loadCandidates();
    setState(() {
      _candidatesFuture = future;
    });
    _retryProgress();
    try {
      await future;
    } on Object {
      /* The page exposes a retry action. */
    }
  }

  Future<void> _openSender(UnsubscribeCandidate candidate) async {
    await Navigator.pushNamed(
      context,
      SenderDetailsScreen.routeName,
      arguments: candidate.id,
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UnsubscribeCandidate>>(
      future: _candidatesFuture,
      builder: (context, snapshot) {
        final liveItems = (snapshot.data ?? _lastCandidates)
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
        final search = _query.text.trim().toLowerCase();
        final visible = items.where((item) {
          final job = _jobs[item.id];
          if (_filter == 'ACTIVE' &&
              job?.isActive != true &&
              !_busySenders.contains(item.id)) {
            return false;
          }
          if (_filter == 'RETRY' &&
              job?.status != 'FAILED' &&
              job?.status != 'CANCELED') {
            return false;
          }
          return search.isEmpty ||
              '${item.name} ${item.email}'.toLowerCase().contains(search);
        }).toList();
        final availableIds = actionableItems
            .where((item) => !_trustingSenders.contains(item.id))
            .map((item) => item.id)
            .toSet();
        final selectedItems = actionableItems
            .where(
              (item) =>
                  _selected.contains(item.id) && availableIds.contains(item.id),
            )
            .toList();
        final shownItems = visible
            .where((item) => availableIds.contains(item.id))
            .toList();
        final initialLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            items.isEmpty &&
            !snapshot.hasData;
        return AppPage(
          maxContentWidth: 1000,
          onRefresh: _refresh,
          header: AppHeader(
            title: 'Unsubscribe',
            action: _selecting
                ? TextButton(
                    onPressed: () => setState(() {
                      _selecting = false;
                      _selected.clear();
                    }),
                    child: const Text('Cancel'),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _showSearch
                            ? 'Close subscription search'
                            : 'Search subscriptions',
                        onPressed: () {
                          setState(() => _showSearch = !_showSearch);
                          if (!_showSearch && _query.text.isNotEmpty) {
                            _query.clear();
                            _changeCandidateFilters();
                          }
                        },
                        icon: Icon(
                          _showSearch
                              ? Icons.close_rounded
                              : Icons.search_rounded,
                        ),
                      ),
                      PopupMenuButton<String>(
                        key: const ValueKey('unsubscribe-page-menu'),
                        tooltip: 'Subscription actions',
                        onSelected: (action) {
                          if (action == 'refresh') _refresh();
                          if (action == 'select') {
                            setState(() => _selecting = true);
                          }
                          if (action == 'all') _startAll(shownItems);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'select',
                            enabled: shownItems.isNotEmpty,
                            child: const Text('Select subscriptions'),
                          ),
                          const PopupMenuItem(
                            value: 'refresh',
                            child: Text('Refresh subscriptions'),
                          ),
                          if (shownItems.isNotEmpty)
                            PopupMenuItem(
                              key: const ValueKey('unsubscribe-all-shown'),
                              value: 'all',
                              child: Text(
                                'Unsubscribe all shown (${shownItems.length})',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
          bottomNavigationBar: _selecting
              ? _SubscriptionSelectionBar(
                  count: selectedItems.length,
                  onSubmit: selectedItems.isEmpty
                      ? null
                      : () => _startAll(selectedItems),
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Stop emails you no longer want. Existing messages stay in your mailbox.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (_showSearch) ...[
                SearchBox(
                  hint: 'Search subscriptions',
                  controller: _query,
                  onChanged: (_) => _changeCandidateFilters(debounce: true),
                  onSubmitted: (_) => _changeCandidateFilters(),
                ),
                const SizedBox(height: 8),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in {
                      'ALL': 'All',
                      'ACTIVE': 'In progress',
                      'RETRY': 'Needs retry',
                    }.entries) ...[
                      MailFilterTab(
                        label: tab.value,
                        selected: _filter == tab.key,
                        onTap: () {
                          _filter = tab.key;
                          _changeCandidateFilters();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (snapshot.hasError && items.isNotEmpty) ...[
                AppAsyncError(
                  title: 'Could not refresh subscriptions',
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: _refresh,
                ),
                const SizedBox(height: 12),
              ],
              if (_jobError case final error?) ...[
                AppAsyncError(
                  title: 'Could not update request progress',
                  message: error,
                  onRetry: _retryProgress,
                ),
                const SizedBox(height: 12),
              ],
              if (!initialLoading && !snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        _hasMore
                            ? '${visible.length} of $_total subscriptions'
                            : '${visible.length} ${visible.length == 1 ? 'subscription' : 'subscriptions'}',
                        key: const ValueKey('unsubscribe-actionable-count'),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      if (_selecting && shownItems.isNotEmpty)
                        TextButton(
                          key: const ValueKey('unsubscribe-select-visible'),
                          onPressed: () => setState(
                            () => _selected.addAll(
                              shownItems.map((item) => item.id),
                            ),
                          ),
                          child: const Text('Select all shown'),
                        ),
                    ],
                  ),
                ),
              if (initialLoading)
                const _UnsubscribeSkeleton()
              else if (snapshot.hasError && items.isEmpty)
                AppAsyncError(
                  title: 'Subscriptions could not be loaded',
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: _refresh,
                )
              else if (visible.isEmpty)
                AppEmptyState(
                  icon: items.isEmpty
                      ? Icons.mark_email_read_outlined
                      : Icons.search_off_rounded,
                  title: items.isEmpty && search.isEmpty && _filter == 'ALL'
                      ? 'No subscriptions to review'
                      : 'No matching subscriptions',
                  message: items.isEmpty && search.isEmpty && _filter == 'ALL'
                      ? 'Senders with a supported unsubscribe option appear here after a mailbox scan.'
                      : 'Try another search or view all subscriptions.',
                  action: items.isEmpty && search.isEmpty && _filter == 'ALL'
                      ? null
                      : TextButton(
                          onPressed: () {
                            _query.clear();
                            _filter = 'ALL';
                            _changeCandidateFilters();
                          },
                          child: const Text('Clear filters'),
                        ),
                )
              else
                for (var i = 0; i < visible.length; i++) ...[
                  _UnsubscribeRow(
                    candidate: visible[i],
                    starting: _busySenders.contains(visible[i].id),
                    trusting: _trustingSenders.contains(visible[i].id),
                    job: _jobs[visible[i].id],
                    selecting: _selecting,
                    selected: _selected.contains(visible[i].id),
                    canSelect: availableIds.contains(visible[i].id),
                    onSelect: () => setState(() {
                      _selecting = true;
                      if (!_selected.add(visible[i].id)) {
                        _selected.remove(visible[i].id);
                      }
                    }),
                    onOpen: () => _openSender(visible[i]),
                    onUnsubscribe: () => _start(visible[i]),
                    onRetry: () => _retry(visible[i]),
                    onTrust: () => _trust(visible[i]),
                  ),
                  if (i != visible.length - 1) const Divider(height: 1),
                ],
              if (_moreError case final error?)
                AppAsyncError(
                  title: 'Could not load more subscriptions',
                  message: error,
                  onRetry: _loadMore,
                ),
              if (_hasMore && !initialLoading) ...[
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : _loadMore,
                    icon: _loadingMore
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_rounded),
                    label: Text(
                      _loadingMore ? 'Loading…' : 'Load more subscriptions',
                    ),
                  ),
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
    required this.selecting,
    required this.selected,
    required this.canSelect,
    required this.onSelect,
    required this.onOpen,
  });

  final UnsubscribeCandidate candidate;
  final bool starting;
  final bool trusting;
  final UnsubscribeJobInfo? job;
  final VoidCallback onUnsubscribe, onRetry, onTrust, onSelect, onOpen;
  final bool selecting, selected, canSelect;

  @override
  Widget build(BuildContext context) {
    final status = _jobStatusPresentation(job, starting: starting);
    final busy = starting || trusting || job?.isActive == true;
    final retry = job?.status == 'FAILED' || job?.status == 'CANCELED';
    final statusColor = AppColors.foregroundFor(
      context,
      status?.color ?? AppColors.primary,
    );
    final stackActions =
        MediaQuery.sizeOf(context).width < 340 ||
        (MediaQuery.sizeOf(context).width < 380 &&
            MediaQuery.textScalerOf(context).scale(14) > 16);
    final actions = <Widget>[
      if (!selecting && !busy && job?.status != 'COMPLETED') ...[
        const SizedBox(width: 6),
        Tooltip(
          message: retry ? 'Retry unsubscribe' : 'Unsubscribe',
          child: TextButton(
            key: ValueKey(
              retry
                  ? 'unsubscribe-retry-${candidate.id}'
                  : 'unsubscribe-start-${candidate.id}',
            ),
            onPressed: retry ? onRetry : onUnsubscribe,
            style: TextButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(retry ? 'Retry' : 'Unsubscribe'),
          ),
        ),
        PopupMenuButton<String>(
          key: ValueKey('unsubscribe-more-${candidate.id}'),
          tooltip: 'More subscription actions',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 180),
          onSelected: (value) {
            if (value == 'trust') onTrust();
            if (value == 'view') onOpen();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Text('View sender')),
            PopupMenuItem(
              key: ValueKey('trust-unsubscribe-${candidate.id}'),
              value: 'trust',
              child: const Text('Trust sender'),
            ),
          ],
        ),
      ],
    ];
    return Material(
      color: selected
          ? AppColors.softFill(context, AppColors.primary)
          : Colors.transparent,
      child: InkWell(
        key: ValueKey('subscription-row-${candidate.id}'),
        onTap: selecting ? (canSelect ? onSelect : null) : onOpen,
        onLongPress: !selecting && canSelect ? onSelect : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selecting)
                    SizedBox(
                      width: 38,
                      child: Checkbox(
                        value: selected,
                        onChanged: canSelect ? (_) => onSelect() : null,
                      ),
                    )
                  else
                    MailAvatar(name: candidate.name, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidate.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textFor(context),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          candidate.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (status != null || trusting) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (status?.spinning == true || trusting)
                                const SizedBox.square(
                                  dimension: 11,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                  ),
                                )
                              else
                                Icon(
                                  status!.icon,
                                  size: 13,
                                  color: statusColor,
                                ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  trusting
                                      ? 'Saving sender preference…'
                                      : status!.label,
                                  key: ValueKey(
                                    'unsubscribe-status-${candidate.id}',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: statusColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!stackActions) ...actions,
                ],
              ),
              if (stackActions && actions.isNotEmpty)
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              if (status?.reason case final reason?)
                Padding(
                  padding: EdgeInsets.only(left: selecting ? 48 : 46, top: 6),
                  child: Text(
                    reason,
                    key: ValueKey('unsubscribe-failure-${candidate.id}'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: statusColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionSelectionBar extends StatelessWidget {
  const _SubscriptionSelectionBar({
    required this.count,
    required this.onSubmit,
  });
  final int count;
  final VoidCallback? onSubmit;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface(context),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              '$count selected',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            FilledButton(
              onPressed: onSubmit,
              child: Text('Unsubscribe ($count)'),
            ),
          ],
        ),
      ),
    ),
  );
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
        label: 'Request sent',
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
