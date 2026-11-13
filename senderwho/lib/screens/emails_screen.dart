import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../utils/email_selection.dart';
import '../widgets/app_card.dart';
import '../widgets/mail_list_surface.dart';
import '../widgets/mail_message_row.dart';
import '../widgets/sender_filters_sheet.dart';
import '../widgets/app_header.dart';
import '../widgets/mailbox_sync_notice.dart';
import '../widgets/app_page.dart';
import '../widgets/search_box.dart';
import 'email_details_screen.dart';

class EmailListArguments {
  const EmailListArguments({
    this.mailbox = 'INBOX',
    this.category,
    this.cleanupCategory,
    this.senderId,
    this.query,
    this.title,
  });

  final String mailbox;
  final String? category;
  final String? cleanupCategory;
  final String? senderId;
  final String? query;
  final String? title;
}

class EmailsScreen extends StatefulWidget {
  const EmailsScreen({super.key, this.repository, this.initialArguments});

  static const routeName = '/emails';

  final SenderWhoRepository? repository;
  final EmailListArguments? initialArguments;

  @override
  State<EmailsScreen> createState() => _EmailsScreenState();
}

class _EmailsScreenState extends State<EmailsScreen> {
  static const _mailboxes = <String, String>{
    'INBOX': 'Inbox',
    'UNREAD': 'Unread',
    'READ': 'Read',
    'ARCHIVED': 'Archived',
    'TRASH': 'Trash',
    'ALL': 'All mail',
  };
  final _queryController = TextEditingController();
  final _selection = EmailSelection();
  final _items = <EmailItem>[];
  bool _initialized = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _reloadPending = false;
  Timer? _syncRefresh;
  DashboardSummary? _syncSummary;
  bool _loadingSyncStatus = false;
  int _dataGeneration = 0;
  bool _selectionMode = false;
  bool _acting = false;
  bool _showBack = false;
  bool _showSearch = false;
  String? _error;
  String? _inlineLoadError;
  String _appliedQuery = '';
  bool _inlineRetryResets = false;
  String _mailbox = 'INBOX';
  String? _category;
  String? _cleanupCategory;
  String? _senderId;
  String? _title;
  int _page = 1;
  int _total = 0;
  bool _hasMore = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final arguments =
        widget.initialArguments ?? ModalRoute.of(context)?.settings.arguments;
    if (arguments is EmailListArguments) {
      _showBack = true;
      _mailbox = arguments.mailbox;
      _category = arguments.category;
      _cleanupCategory = arguments.cleanupCategory;
      _senderId = arguments.senderId;
      _title = arguments.title;
      _queryController.text = arguments.query ?? '';
      _showSearch = _queryController.text.isNotEmpty;
    }
    _load(reset: true);
  }

  @override
  void dispose() {
    _syncRefresh?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    reset = reset || _queryController.text.trim() != _appliedQuery;
    if (_loading || _loadingMore) {
      if (reset) _reloadPending = true;
      return;
    }
    _syncRefresh?.cancel();
    if (reset) _appliedQuery = _queryController.text.trim();
    unawaited(_loadSyncStatus());
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _inlineLoadError = null;
      } else {
        _loadingMore = true;
        _inlineLoadError = null;
      }
    });
    if (reset) _dataGeneration++;
    final targetPage = reset ? 1 : _page + 1;
    final result = await _repository.getEmails(
      page: targetPage,
      mailbox: _mailbox,
      query: _appliedQuery,
      category: _category,
      cleanupCategory: _cleanupCategory,
      senderId: _senderId,
    );
    if (!mounted) return;
    if (_reloadPending) {
      _reloadPending = false;
      _loading = false;
      _loadingMore = false;
      unawaited(_load(reset: true));
      return;
    }
    setState(() {
      _loading = false;
      _loadingMore = false;
      if (result == null) {
        final message =
            _repository.lastError ??
            'Could not load your messages. Please try again.';
        if (_items.isEmpty) {
          _error = message;
        } else {
          _error = null;
          _inlineLoadError = message;
          _inlineRetryResets = reset;
        }
        return;
      }
      if (reset) _items.clear();
      _items.addAll(result.items);
      _page = result.page;
      _total = result.total;
      _hasMore = result.hasMore;
      _error = null;
      _inlineLoadError = null;
      _selection.retain(_items.map((message) => message.id));
    });
    _scheduleSyncRefresh();
  }

  bool get _syncing => const {'PENDING', 'SYNCING', 'PARTIAL'}.contains(
    _syncSummary?.syncStatus ?? _repository.activeMailbox.value?.syncStatus,
  );

  Future<void> _loadSyncStatus() async {
    if (_loadingSyncStatus || !_repository.isAuthenticated) return;
    _loadingSyncStatus = true;
    try {
      final summary = await _repository.getDashboard();
      if (mounted && summary.available) setState(() => _syncSummary = summary);
    } on Object {
      // A status failure must not block the message list.
    } finally {
      _loadingSyncStatus = false;
      if (mounted && !_loading && !_loadingMore) _scheduleSyncRefresh();
    }
  }

  void _scheduleSyncRefresh() {
    _syncRefresh?.cancel();
    if (_syncing ||
        (_syncSummary?.syncRetryAt ??
                _repository.activeMailbox.value?.syncRetryAt) !=
            null) {
      _syncRefresh = Timer(
        const Duration(seconds: 3),
        () => _load(reset: true),
      );
    }
  }

  Future<void> _refreshLoadedPages() async {
    final generation = _dataGeneration;
    final pages = await Future.wait([
      for (var page = 1; page <= _page; page++)
        _repository.getEmails(
          page: page,
          mailbox: _mailbox,
          query: _appliedQuery,
          category: _category,
          cleanupCategory: _cleanupCategory,
          senderId: _senderId,
        ),
    ]);
    if (!mounted || generation != _dataGeneration || _loading || _loadingMore) {
      return;
    }
    if (pages.any((page) => page == null)) {
      setState(() {
        _inlineLoadError =
            'Could not refresh messages. Your loaded emails are still available.';
        _inlineRetryResets = true;
      });
      return;
    }
    if (pages.isEmpty) return;
    setState(() {
      _items
        ..clear()
        ..addAll(pages.expand((page) => page!.items));
      _total = pages.last!.total;
      _hasMore = pages.last!.hasMore;
      _selection.retain(_items.map((message) => message.id));
    });
  }

  Future<void> _openEmail(EmailItem email) async {
    if (email.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This message is unavailable. Refresh your inbox and try again.',
          ),
        ),
      );
      return;
    }
    await Navigator.pushNamed<dynamic>(
      context,
      EmailDetailsScreen.routeName,
      arguments: email,
    );
    if (mounted) await _refreshLoadedPages();
  }

  Future<void> _applyBulk(String action, {bool? isRead}) async {
    if (_selection.isEmpty || _acting) return;
    if (action == 'trash') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Move selected emails to Trash?'),
          content: Text(
            '${_selection.count} email messages will be moved to Trash.',
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
              child: const Text('Move to Trash'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final requestedIds = Set<String>.of(_selection.ids);
    setState(() => _acting = true);
    final result = await _repository.applyEmailAction(
      action,
      requestedIds.toList(),
      isRead: isRead,
    );
    if (!mounted) return;

    final failedIds = _failedSelection(result, requestedIds);
    if (result != null && result.processed > 0) {
      await _load(reset: true);
    }
    if (!mounted) return;
    setState(() {
      _acting = false;
      _selection.replaceWith(failedIds);
      _selectionMode = !_selection.isEmpty;
    });
    _showActionResult(result);
  }

  String _activeScopeLabel() {
    final hasQuery = _appliedQuery.isNotEmpty;
    if (_senderId?.isNotEmpty == true) {
      return hasQuery
          ? 'all matching search results from ${_title ?? 'this sender'}'
          : 'all emails from ${_title ?? 'this sender'}';
    }
    if (_category?.isNotEmpty == true) {
      final category = _friendly(_category!).toLowerCase();
      return hasQuery
          ? 'all matching $category search results'
          : 'all $category emails';
    }
    if (_cleanupCategory?.isNotEmpty == true) {
      final category = _friendly(_cleanupCategory!).toLowerCase();
      return hasQuery
          ? 'all matching $category search results'
          : 'all $category emails';
    }
    if (hasQuery) return 'all matching search results';
    final mailbox = _mailboxes[_mailbox] ?? _friendly(_mailbox);
    return 'all ${mailbox.toLowerCase()} emails';
  }

  Future<void> _moveAllMatchingToTrash() async {
    if (_acting || _total == 0 || _mailbox == 'TRASH') return;
    final scope = _activeScopeLabel();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Move all matching emails to Trash?'),
        content: Text(
          'This will move $_total email message${_total == 1 ? '' : 's'} '
          '($scope) to Trash. It does not permanently delete them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Move all to Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    final result = await _repository.applyEmailActionToAllMatching(
      'trash',
      mailbox: _mailbox,
      query: _appliedQuery,
      category: _category,
      cleanupCategory: _cleanupCategory,
      senderId: _senderId,
    );
    if (!mounted) return;
    await _load(reset: true);
    if (!mounted) return;
    setState(() {
      _acting = false;
      _selection.clear();
      _selectionMode = false;
    });
    _showActionResult(result, failuresRemainSelected: false);
  }

  Future<void> _showMailboxActions() async {
    if (_acting || _total == 0 || _mailbox == 'TRASH') return;
    final scope = _activeScopeLabel();
    final moveToTrash = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email actions',
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$_total matching email${_total == 1 ? '' : 's'}',
                          style: Theme.of(sheetContext).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close email actions',
                    onPressed: () => Navigator.pop(sheetContext, false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Material(
                color: AppColors.softFill(sheetContext, AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.danger.withValues(
                      alpha: AppColors.isDark(sheetContext) ? 0.3 : 0.18,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('move-all-matching-to-trash'),
                  onTap: () => Navigator.pop(sheetContext, true),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 72),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(
                                alpha: AppColors.isDark(sheetContext)
                                    ? 0.2
                                    : 0.11,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Move all to Trash',
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$scope. Messages are not permanently deleted.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    sheetContext,
                                  ).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || moveToTrash != true) return;
    await _moveAllMatchingToTrash();
  }

  Future<void> _unsubscribeSelectedSenders() async {
    if (_acting || _selection.isEmpty) return;
    final senderIds = _items
        .where((message) => _selection.contains(message.id))
        .map((message) => message.senderId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (senderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sender details are unavailable for these messages. Refresh and try again.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          'Unsubscribe from ${senderIds.length} sender${senderIds.length == 1 ? '' : 's'}?',
        ),
        content: Text(
          'SenderWho will request that these senders stop future recurring '
          'email. Your ${_selection.count} selected message'
          '${_selection.count == 1 ? '' : 's'} will remain in the mailbox.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.unsubscribe_rounded),
            label: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _acting = true);
    final result = await _repository.createUnsubscribeJobs(senderIds.toList());
    if (!mounted) return;
    setState(() => _acting = false);
    final message = result == null
        ? _repository.lastError ?? 'Unsubscribe requests could not be started.'
        : result.failures.isEmpty
        ? '${result.jobs.length} unsubscribe request${result.jobs.length == 1 ? '' : 's'} queued.'
        : '${result.jobs.length} queued; ${result.failures.length} failed. Selected emails were not deleted.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Set<String> _failedSelection(
    MessageActionResult? result,
    Set<String> requestedIds,
  ) {
    if (result == null) return requestedIds;
    if (result.failed == 0) return const <String>{};

    final remaining = requestedIds.difference(result.processedIds.toSet());
    remaining.addAll(
      result.failures
          .map((failure) => failure.messageId)
          .where(requestedIds.contains),
    );
    return remaining.isEmpty ? requestedIds : remaining;
  }

  void _showActionResult(
    MessageActionResult? result, {
    bool failuresRemainSelected = true,
  }) {
    String? firstFailureReason;
    for (final failure in result?.failures ?? const <MessageActionFailure>[]) {
      final reason = failure.reason.trim();
      if (reason.isNotEmpty) {
        firstFailureReason = reason;
        break;
      }
    }
    final text = result == null
        ? _repository.lastError ?? 'The email action could not be completed.'
        : result.failed == 0
        ? '${result.processed} email message${result.processed == 1 ? '' : 's'} updated.'
        : '${result.processed} updated, ${result.failed} failed'
              '${failuresRemainSelected ? ' and remain selected' : ' and remain in this view'}.'
              '${firstFailureReason == null ? '' : ' $firstFailureReason'}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showMailboxPicker() async {
    FocusScope.of(context).unfocus();
    final mailbox = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            for (final entry in _mailboxes.entries)
              ListTile(
                title: Text(entry.value),
                selected: entry.key == _mailbox,
                trailing: entry.key == _mailbox
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || mailbox == null || mailbox == _mailbox) return;
    setState(() {
      _mailbox = mailbox;
      _title = null;
      _selection.clear();
      _selectionMode = false;
    });
    await _load(reset: true);
  }

  Future<void> _applyFilters({String? category, String? query}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _category = category;
      if (query != null) {
        _queryController.text = query;
        _showSearch = query.isNotEmpty;
      }
      _selection.clear();
      _selectionMode = false;
    });
    await _load(reset: true);
  }

  Future<void> _showCategoryFilter() async {
    FocusScope.of(context).unfocus();
    final selected = await showModalBottomSheet<SenderFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SenderFiltersSheet(
        messages: true,
        initial: SenderFilters(
          category: _category,
          query: _queryController.text,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await _applyFilters(category: selected.category, query: selected.query);
  }

  @override
  Widget build(BuildContext context) {
    final mailboxTitle = _mailboxes[_mailbox] ?? _friendly(_mailbox);
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode && !_acting) {
          setState(() {
            _selectionMode = false;
            _selection.clear();
          });
        }
      },
      child: AppPage(
        header: AppHeader(
          title: _title ?? mailboxTitle,
          onTitleTap: _showMailboxPicker,
          showBack: _showBack,
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _showSearch
                    ? 'Close message search'
                    : 'Search messages',
                icon: Icon(
                  _showSearch ? Icons.close_rounded : Icons.search_rounded,
                ),
                onPressed: () {
                  setState(() => _showSearch = !_showSearch);
                  if (!_showSearch && _queryController.text.isNotEmpty) {
                    _queryController.clear();
                    _load(reset: true);
                  }
                },
              ),
              IconButton(
                tooltip: _selectionMode ? 'Cancel selection' : 'Select',
                onPressed: _items.isEmpty
                    ? null
                    : () => setState(() {
                        _selectionMode = !_selectionMode;
                        if (!_selectionMode) _selection.clear();
                      }),
                icon: Icon(
                  _selectionMode
                      ? Icons.close_rounded
                      : Icons.checklist_rounded,
                ),
              ),
            ],
          ),
        ),
        onRefresh: () => _load(reset: true),
        plainBackground: true,
        maxContentWidth: 1100,
        bottomNavigationBar: _selectionMode
            ? _BulkEmailActions(
                count: _selection.count,
                busy: _acting,
                trashView: _mailbox == 'TRASH',
                archivedView: _mailbox == 'ARCHIVED',
                onRead: () => _applyBulk('read-state', isRead: true),
                onUnread: () => _applyBulk('read-state', isRead: false),
                onArchiveOrUnarchive: () => _applyBulk(
                  _mailbox == 'ARCHIVED' ? 'unarchive' : 'archive',
                ),
                onUnsubscribe: _unsubscribeSelectedSenders,
                onTrashOrRestore: () =>
                    _applyBulk(_mailbox == 'TRASH' ? 'restore' : 'trash'),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            if (_showSearch) ...[
              SearchBox(
                hint: 'Search messages',
                controller: _queryController,
                onSubmitted: (_) => _load(reset: true),
                trailing: IconButton(
                  tooltip: 'Filter categories',
                  onPressed: _showCategoryFilter,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (final entry in <String?, String>{
                    null: 'All',
                    'PEOPLE': 'People',
                    'PROMOTIONS': 'Offers',
                    'NEWSLETTERS': 'Newsletters',
                  }.entries) ...[
                    MailFilterTab(
                      label: entry.value,
                      selected: _category == entry.key,
                      onTap: () => _applyFilters(category: entry.key),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _category == null
                        ? '$_total ${_total == 1 ? 'message' : 'messages'}'
                        : _friendly(_category!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_category != null)
                  IconButton(
                    tooltip: 'Clear category filter',
                    onPressed: () => _applyFilters(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                IconButton(
                  tooltip: 'Filter categories',
                  onPressed: _showCategoryFilter,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                ),
                IconButton(
                  tooltip: 'Refresh messages',
                  onPressed: _loading ? null : () => _load(reset: true),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
                if (!_selectionMode && _mailbox != 'TRASH' && _total > 0)
                  IconButton(
                    key: const ValueKey('email-mailbox-actions'),
                    tooltip: 'More email actions',
                    onPressed: _acting ? null : _showMailboxActions,
                    icon: const Icon(Icons.more_horiz_rounded, size: 21),
                  ),
              ],
            ),
            MailboxSyncNotice(
              summary: _syncSummary,
              account:
                  _repository.activeMailbox.value ??
                  _repository.connectedAccounts.value.firstOrNull,
            ),
            if (_selectionMode) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('select-all-visible'),
                    onPressed: _acting
                        ? null
                        : () => setState(
                            () => _selection.selectAll(
                              _items
                                  .map((message) => message.id)
                                  .where((id) => id.isNotEmpty),
                            ),
                          ),
                    icon: const Icon(Icons.select_all_rounded, size: 18),
                    label: Text('Select all visible (${_items.length})'),
                  ),
                  TextButton.icon(
                    key: const ValueKey('clear-email-selection'),
                    onPressed: _acting || _selection.isEmpty
                        ? null
                        : () => setState(_selection.clear),
                    icon: const Icon(Icons.deselect_rounded, size: 18),
                    label: const Text('Clear selection'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const _EmailListSkeleton()
            else if (_error != null)
              AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const _StateIcon(
                      icon: Icons.cloud_off_rounded,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Could not load your mail',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => _load(reset: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_items.isEmpty)
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 36,
                ),
                child: Column(
                  children: [
                    const _StateIcon(
                      icon: Icons.mark_email_read_outlined,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _syncing ? 'Your inbox is syncing' : 'Nothing to review',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _syncing
                          ? 'Messages appear here as your mailbox is scanned.'
                          : 'No messages match the selected mailbox and filters.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              MailListSurface(
                child: Column(
                  children: [
                    for (var index = 0; index < _items.length; index++) ...[
                      _EmailRow(
                        email: _items[index],
                        selectionMode: _selectionMode,
                        selected: _selection.contains(_items[index].id),
                        onTap: () {
                          if (_acting) return;
                          if (_selectionMode) {
                            setState(() {
                              _selection.toggle(_items[index].id);
                            });
                          } else {
                            _openEmail(_items[index]);
                          }
                        },
                        onLongPress: () {
                          if (_acting) return;
                          setState(() {
                            _selectionMode = true;
                            _selection.selectAll([_items[index].id]);
                          });
                        },
                      ),
                      if (index != _items.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            if (_inlineLoadError != null) ...[
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _inlineLoadError!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: (_loading || _loadingMore)
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
                  onPressed: _loadingMore ? null : () => _load(reset: false),
                  icon: _loadingMore
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more_rounded),
                  label: Text(_loadingMore ? 'Loading…' : 'Load more'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmailRow extends StatelessWidget {
  const _EmailRow({
    required this.email,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final EmailItem email;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) => MailMessageRow(
    key: ValueKey('email-row-${email.id}'),
    email: email,
    selectionMode: selectionMode,
    selected: selected,
    onTap: onTap,
    onLongPress: onLongPress,
  );
}

class _BulkEmailActions extends StatelessWidget {
  const _BulkEmailActions({
    required this.count,
    required this.busy,
    required this.trashView,
    required this.archivedView,
    required this.onRead,
    required this.onUnread,
    required this.onArchiveOrUnarchive,
    required this.onUnsubscribe,
    required this.onTrashOrRestore,
  });

  final int count;
  final bool busy;
  final bool trashView;
  final bool archivedView;
  final VoidCallback onRead;
  final VoidCallback onUnread;
  final VoidCallback onArchiveOrUnarchive;
  final VoidCallback onUnsubscribe;
  final VoidCallback onTrashOrRestore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        elevation: 18,
        color: AppColors.surface(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softFill(context, AppColors.primary),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy) ...[
                      const SizedBox.square(
                        dimension: 13,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      busy ? 'Updating $count' : '$count selected',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Mark read',
                        onPressed: busy || count == 0 ? null : onRead,
                        icon: const Icon(Icons.mark_email_read_outlined),
                      ),
                      IconButton(
                        tooltip: 'Mark unread',
                        onPressed: busy || count == 0 ? null : onUnread,
                        icon: const Icon(Icons.mark_email_unread_outlined),
                      ),
                      if (!trashView) ...[
                        IconButton(
                          tooltip: 'Unsubscribe selected senders',
                          onPressed: busy || count == 0 ? null : onUnsubscribe,
                          icon: const Icon(Icons.unsubscribe_rounded),
                        ),
                        IconButton(
                          tooltip: archivedView ? 'Unarchive' : 'Archive',
                          onPressed: busy || count == 0
                              ? null
                              : onArchiveOrUnarchive,
                          icon: Icon(
                            archivedView
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                          ),
                        ),
                      ],
                      IconButton(
                        tooltip: trashView ? 'Restore' : 'Trash',
                        onPressed: busy || count == 0 ? null : onTrashOrRestore,
                        color: trashView ? AppColors.primary : AppColors.danger,
                        icon: Icon(
                          trashView
                              ? Icons.restore_from_trash_outlined
                              : Icons.delete_outline_rounded,
                        ),
                      ),
                    ],
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

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = AppColors.foregroundFor(context, color);
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.softFill(context, color),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: resolvedColor, size: 27),
    );
  }
}

class _EmailListSkeleton extends StatelessWidget {
  const _EmailListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.trackFor(context),
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonLine(width: index.isEven ? 116 : 145),
                      const SizedBox(height: 9),
                      const _SkeletonLine(),
                      const SizedBox(height: 7),
                      const _SkeletonLine(width: 180),
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

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: 9,
      decoration: BoxDecoration(
        color: AppColors.trackFor(context),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

String _friendly(String value) {
  final lower = value.toLowerCase().replaceAll('_', ' ');
  return lower.isEmpty
      ? value
      : '${lower[0].toUpperCase()}${lower.substring(1)}';
}
