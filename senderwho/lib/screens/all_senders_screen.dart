import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/sender_details_screen.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/mail_list_surface.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/mail_avatar.dart';
import '../widgets/mailbox_sync_notice.dart';
import '../widgets/search_box.dart';
import '../widgets/sender_filters_sheet.dart';

class SenderListArguments {
  const SenderListArguments({this.control = 'ALL', this.title});

  final String control;
  final String? title;
}

class AllSendersScreen extends StatefulWidget {
  const AllSendersScreen({super.key, this.repository});

  static const routeName = '/all-senders';
  final SenderWhoRepository? repository;

  @override
  State<AllSendersScreen> createState() => _AllSendersScreenState();
}

class _AllSendersScreenState extends State<AllSendersScreen>
    with WidgetsBindingObserver {
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
  String? _category;
  String? _title;
  bool _initialized = false;
  int _page = 0;
  int _total = 0;
  bool _showSearch = false;
  bool _loading = false;
  bool _reloadPending = false;
  bool _loadingSyncStatus = false;
  Timer? _syncRefresh;
  DashboardSummary? _summary;
  bool _hasMore = false;
  bool _showBack = false;
  String? _error;
  String? _inlineLoadError;
  String _appliedQuery = '';
  bool _inlineRetryResets = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(reset: true);
  }

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
    _syncRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    reset = reset || _queryController.text.trim() != _appliedQuery;
    if (_loading) {
      if (reset) _reloadPending = true;
      return;
    }
    _syncRefresh?.cancel();
    if (reset) _appliedQuery = _queryController.text.trim();
    setState(() {
      _loading = true;
      if (reset) _error = null;
      _inlineLoadError = null;
    });
    unawaited(_loadSyncStatus());
    final result = await _repository.getSenders(
      page: reset ? 1 : _page + 1,
      kind: _kind,
      control: _control,
      query: _appliedQuery,
      category: _category,
    );
    if (!mounted) return;
    if (_reloadPending) {
      _reloadPending = false;
      _loading = false;
      unawaited(_load(reset: true));
      return;
    }
    setState(() {
      _loading = false;
      if (result == null) {
        final message = _repository.lastError ?? 'Could not load senders.';
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
    _scheduleSyncRefresh();
  }

  Future<void> _loadSyncStatus() async {
    if (_loadingSyncStatus || !_repository.isAuthenticated) return;
    _loadingSyncStatus = true;
    try {
      final summary = await _repository.getDashboard();
      if (!mounted) return;
      if (summary.available) setState(() => _summary = summary);
    } on Object {
      // A statistics outage must not delay the sender list.
    } finally {
      _loadingSyncStatus = false;
      if (mounted && !_loading) _scheduleSyncRefresh();
    }
  }

  void _scheduleSyncRefresh() {
    _syncRefresh?.cancel();
    if (_syncing ||
        (_summary?.syncRetryAt ??
                _repository.activeMailbox.value?.syncRetryAt) !=
            null) {
      _syncRefresh = Timer(
        const Duration(seconds: 5),
        () => _load(reset: true),
      );
    }
  }

  bool get _syncing => const {'PENDING', 'SYNCING', 'PARTIAL'}.contains(
    _summary?.syncStatus ?? _repository.activeMailbox.value?.syncStatus,
  );

  Future<void> _showFilters() async {
    FocusScope.of(context).unfocus();
    final initialCategory =
        _category ??
        (const {'PEOPLE', 'NEWSLETTERS'}.contains(_kind) ? _kind : null);
    final result = await showModalBottomSheet<SenderFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SenderFiltersSheet(
        initial: SenderFilters(
          category: initialCategory,
          query: _queryController.text,
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _applyFilters(
      kind: switch (result.category) {
        'PEOPLE' => 'PEOPLE',
        'NEWSLETTERS' => 'NEWSLETTERS',
        _ => 'ALL',
      },
      category: result.category,
      query: result.query,
    );
  }

  Future<void> _applyFilters({
    required String kind,
    String? category,
    String? query,
  }) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _kind = kind;
      _category = category;
      if (query != null) {
        _queryController.text = query;
        _showSearch = query.isNotEmpty;
      }
    });
    await _load(reset: true);
  }

  void _clearFilters() {
    setState(() {
      _kind = 'ALL';
      _category = null;
      _queryController.clear();
      _showSearch = false;
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: AppHeader(
        title: _title ?? 'All Senders',
        showBack: _showBack,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: _showSearch ? 'Close sender search' : 'Search senders',
              onPressed: () {
                setState(() => _showSearch = !_showSearch);
                if (!_showSearch && _queryController.text.isNotEmpty) {
                  _queryController.clear();
                  _load(reset: true);
                }
              },
              icon: Icon(
                _showSearch ? Icons.close_rounded : Icons.search_rounded,
              ),
            ),
            IconButton(
              key: const ValueKey('sender-filter-button'),
              tooltip: 'Filter senders',
              onPressed: _showFilters,
              icon: Badge(
                backgroundColor: Theme.of(context).colorScheme.primary,
                isLabelVisible: _category != null,
                child: const Icon(Icons.tune_rounded, size: 22),
              ),
            ),
          ],
        ),
      ),
      onRefresh: () => _load(reset: true),
      plainBackground: true,
      maxContentWidth: 1100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (_showSearch) ...[
            SearchBox(
              controller: _queryController,
              hint: 'Search senders',
              onSubmitted: (_) => _load(reset: true),
              trailing: IconButton(
                tooltip: 'Apply sender search',
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final tab in _tabs.entries) ...[
                  MailFilterTab(
                    label: tab.value,
                    selected: _kind == tab.key,
                    onTap: () => _applyFilters(
                      kind: tab.key,
                      category:
                          const {'PEOPLE', 'NEWSLETTERS'}.contains(tab.key)
                          ? tab.key
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _category == null
                    ? (_page == 0
                          ? const SizedBox.shrink()
                          : Text(
                              '$_total ${_total == 1 ? 'sender' : 'senders'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ))
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: InputChip(
                          key: const ValueKey('sender-active-category'),
                          label: Text(
                            senderCategories[_category] ?? _category!,
                          ),
                          deleteButtonTooltipMessage: 'Clear category filter',
                          onDeleted: () {
                            setState(() {
                              _category = null;
                              _kind = 'ALL';
                            });
                            _load(reset: true);
                          },
                        ),
                      ),
              ),
              IconButton(
                tooltip: 'Refresh senders',
                onPressed: _loading ? null : () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded, size: 22),
              ),
            ],
          ),
          if (_loading && _senders.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          SizedBox(height: context.gap(8)),
          if (_syncing)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _senders.isEmpty
                          ? 'Scanning your mailbox. New results appear automatically.'
                          : 'Syncing older mail in the background.',
                    ),
                  ),
                ],
              ),
            ),
          MailboxSyncNotice(
            summary: _summary,
            account:
                _repository.activeMailbox.value ??
                _repository.connectedAccounts.value.firstOrNull,
          ),
          if (_loading && _senders.isEmpty)
            const _SenderListSkeleton()
          else if (_error != null)
            SizedBox(
              key: const ValueKey('all-senders-error-state'),
              width: double.infinity,
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
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
              ),
            )
          else if (_senders.isEmpty)
            SizedBox(
              key: const ValueKey('all-senders-empty-state'),
              width: double.infinity,
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 36,
                ),
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
                      _queryController.text.trim().isEmpty &&
                              _kind == 'ALL' &&
                              _category == null &&
                              _control == 'ALL'
                          ? 'Senders appear after your mailbox is scanned. Refresh to check again.'
                          : 'Try another category, sender type, or search term.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_category != null ||
                        _kind != 'ALL' ||
                        _queryController.text.isNotEmpty)
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
              ),
            )
          else
            MailListSurface(
              child: AnimatedSwitcher(
                duration: AppMotion.responsive(context, AppMotion.standard),
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                child: Column(
                  key: ValueKey('sender-list-$_kind-${_senders.length}'),
                  children: [
                    for (var i = 0; i < _senders.length; i++) ...[
                      SenderRow(
                        sender: _senders[i],
                        onChanged: () => _load(reset: true),
                      ),
                      if (i != _senders.length - 1)
                        Divider(
                          height: 1,
                          indent: 0,
                          color: AppColors.borderFor(
                            context,
                          ).withValues(alpha: 0.62),
                        ),
                    ],
                  ],
                ),
              ),
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
    final unread = sender.unreadMessages > 0;
    return InkWell(
      key: ValueKey('sender-row-${sender.id}'),
      onTap: () async {
        await Navigator.pushNamed(
          context,
          SenderDetailsScreen.routeName,
          arguments: sender.id,
        );
        if (context.mounted) onChanged();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              _IdentityAvatar(sender: sender),
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.textFor(context),
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                        if (sender.isTrusted) ...[
                          const SizedBox(width: 4),
                          Tooltip(
                            message: 'Trusted by you',
                            child: Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: AppColors.primaryFor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sender.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (constraints.maxWidth >= 600) ...[
                const SizedBox(width: 16),
                SizedBox(
                  width: 110,
                  child: Text(
                    sender.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Tooltip(
                message:
                    '${sender.totalMessages} messages, ${sender.unreadMessages} unread',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${sender.totalMessages}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    if (unread)
                      Text(
                        '${sender.unreadMessages} unread',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryFor(context),
                          fontWeight: FontWeight.w700,
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

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({required this.sender});
  final SenderInfo sender;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = sender.isBlocked
        ? ('Blocked sender', Icons.block_rounded)
        : sender.identityStatus == 'SUSPICIOUS'
        ? (
            sender.identityRiskLevel == 'HIGH'
                ? 'High-risk sender identity'
                : 'Possible sender impersonation',
            Icons.warning_amber_rounded,
          )
        : sender.identityStatus == 'VERIFIED'
        ? ('Verified sender identity', null)
        : ('Sender identity is unverified', null);
    return Tooltip(
      message: label,
      child: MailAvatar(
        name: sender.name,
        label: '$label. ${sender.name}',
        badge: icon == null
            ? null
            : Icon(icon, size: 14, color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _SenderListSkeleton extends StatelessWidget {
  const _SenderListSkeleton();

  @override
  Widget build(BuildContext context) {
    return MailListSurface(
      child: Column(
        children: [
          for (var i = 0; i < 7; i++) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.trackFor(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: i.isEven ? 120 : 155,
                          height: 10,
                          color: AppColors.trackFor(context),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 8,
                          width: 180,
                          color: AppColors.trackFor(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < 6) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
