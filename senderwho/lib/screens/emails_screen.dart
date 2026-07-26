import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
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
  static const _categories = [
    'IMPORTANT',
    'PEOPLE',
    'ORDERS',
    'FINANCE',
    'NEWSLETTERS',
    'PROMOTIONS',
    'TRAVEL',
    'SOCIAL',
    'SPAM',
    'UNKNOWN',
  ];

  final _queryController = TextEditingController();
  final _selectedIds = <String>{};
  final _items = <EmailItem>[];
  bool _initialized = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _selectionMode = false;
  bool _acting = false;
  bool _showBack = false;
  String? _error;
  String? _inlineLoadError;
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
      widget.repository ?? senderWhoRepository;

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
    }
    _load(reset: true);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_loading || _loadingMore) return;
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
    final targetPage = reset ? 1 : _page + 1;
    final result = await _repository.getEmails(
      page: targetPage,
      mailbox: _mailbox,
      query: _queryController.text,
      category: _category,
      cleanupCategory: _cleanupCategory,
      senderId: _senderId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadingMore = false;
      if (result == null) {
        final message =
            _repository.lastError ??
            'Could not load email metadata. Check the API and retry.';
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
      _selectedIds.removeWhere(
        (id) => !_items.any((message) => message.id == id),
      );
    });
  }

  Future<void> _openEmail(EmailItem email) async {
    if (email.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This email message is missing its local identifier.'),
        ),
      );
      return;
    }
    final changed = await Navigator.pushNamed<dynamic>(
      context,
      EmailDetailsScreen.routeName,
      arguments: email,
    );
    if (changed == true) await _load(reset: true);
  }

  Future<void> _applyBulk(String action, {bool? isRead}) async {
    if (_selectedIds.isEmpty || _acting) return;
    if (action == 'trash') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Move selected emails to Trash?'),
          content: Text(
            '${_selectedIds.length} email messages will be moved to Trash.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Move to Trash'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final requestedIds = Set<String>.of(_selectedIds);
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
      _selectedIds
        ..clear()
        ..addAll(failedIds);
      _selectionMode = _selectedIds.isNotEmpty;
    });
    _showActionResult(result);
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

  void _showActionResult(MessageActionResult? result) {
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
        : '${result.processed} updated, ${result.failed} failed and remain selected.'
              '${firstFailureReason == null ? '' : ' $firstFailureReason'}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _showCategoryFilter() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 5),
              Text(
                'Show only the messages you want to review.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 9,
                    runSpacing: 10,
                    children: [
                      SelectablePill(
                        label: 'All categories',
                        selected: _category == null,
                        onTap: () => Navigator.pop(context, 'ALL'),
                      ),
                      for (final category in _categories)
                        SelectablePill(
                          label: _friendly(category),
                          selected: _category == category,
                          onTap: () => Navigator.pop(context, category),
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
    if (!mounted || selected == null) return;
    setState(() => _category = selected == 'ALL' ? null : selected);
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final mailboxTitle = _mailboxes[_mailbox] ?? _friendly(_mailbox);
    return AppPage(
      bottomNavigationBar: _selectionMode
          ? _BulkEmailActions(
              count: _selectedIds.length,
              busy: _acting,
              trashView: _mailbox == 'TRASH',
              archivedView: _mailbox == 'ARCHIVED',
              onRead: () => _applyBulk('read-state', isRead: true),
              onUnread: () => _applyBulk('read-state', isRead: false),
              onArchiveOrUnarchive: () =>
                  _applyBulk(_mailbox == 'ARCHIVED' ? 'unarchive' : 'archive'),
              onTrashOrRestore: () =>
                  _applyBulk(_mailbox == 'TRASH' ? 'restore' : 'trash'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader(
            title: _title ?? mailboxTitle,
            subtitle: '$_total email message${_total == 1 ? '' : 's'}',
            showBack: _showBack,
            action: TextButton(
              onPressed: _items.isEmpty
                  ? null
                  : () => setState(() {
                      _selectionMode = !_selectionMode;
                      if (!_selectionMode) _selectedIds.clear();
                    }),
              child: Text(_selectionMode ? 'Cancel' : 'Select'),
            ),
          ),
          SizedBox(height: context.gap(18)),
          SearchBox(
            hint: 'Search subject, sender or preview',
            controller: _queryController,
            onSubmitted: (_) => _load(reset: true),
            trailing: IconButton(
              tooltip: 'Filter categories',
              onPressed: _showCategoryFilter,
              icon: const Icon(Icons.tune_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final entry in _mailboxes.entries) ...[
                  SelectablePill(
                    label: entry.value,
                    selected: _mailbox == entry.key,
                    onTap: () {
                      setState(() {
                        _mailbox = entry.key;
                        _title = null;
                        _selectedIds.clear();
                        _selectionMode = false;
                      });
                      _load(reset: true);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderFor(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.softFill(context, AppColors.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _mailboxIcon(_mailbox),
                    size: 19,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mailboxTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _category == null
                            ? 'All categories'
                            : _friendly(_category!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (_category != null)
                  IconButton(
                    tooltip: 'Clear category filter',
                    onPressed: () {
                      setState(() => _category = null);
                      _load(reset: true);
                    },
                    icon: const Icon(Icons.close_rounded, size: 19),
                  ),
                IconButton.filledTonal(
                  tooltip: 'Refresh messages',
                  onPressed: _loading ? null : () => _load(reset: true),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
          ),
          SizedBox(height: context.gap(16)),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                children: [
                  const _StateIcon(
                    icon: Icons.mark_email_read_outlined,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Nothing to review',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'No messages match the selected mailbox and filters.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < _items.length; index++) ...[
                  _EmailRow(
                    email: _items[index],
                    selectionMode: _selectionMode,
                    selected: _selectedIds.contains(_items[index].id),
                    onTap: () {
                      if (_acting) return;
                      if (_selectionMode) {
                        setState(() {
                          final id = _items[index].id;
                          _selectedIds.contains(id)
                              ? _selectedIds.remove(id)
                              : _selectedIds.add(id);
                        });
                      } else {
                        _openEmail(_items[index]);
                      }
                    },
                  ),
                  if (index != _items.length - 1) const SizedBox(height: 10),
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
    );
  }
}

class _EmailRow extends StatelessWidget {
  const _EmailRow({
    required this.email,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
  });

  final EmailItem email;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _categoryColor(email.category);
    return AppCard(
      key: ValueKey('email-row-${email.id}'),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: selected ? AppColors.primary : null,
      color: selected
          ? AppColors.primary.withValues(
              alpha: AppColors.isDark(context) ? 0.16 : 0.045,
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectionMode) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 5),
          ] else ...[
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.softFill(context, accent),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    email.sender.isEmpty ? '?' : email.sender[0].toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!email.isRead)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface(context),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email.sender,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: email.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _compactDate(email.date),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: email.isRead
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: AppColors.textFor(context),
                  ),
                ),
                if (email.snippet.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email.snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: StatusChip(
                        label: _friendly(email.category),
                        color: accent,
                      ),
                    ),
                    if (!email.isRead) ...[
                      const SizedBox(width: 6),
                      const StatusChip(label: 'New', color: AppColors.primary),
                    ],
                    const Spacer(),
                    if (email.hasAttachments)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: Icon(
                          Icons.attach_file_rounded,
                          size: 16,
                          color: AppColors.mutedFor(context),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Open message',
                      onPressed: onTap,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        size: 19,
                        color: AppColors.mutedFor(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    required this.onTrashOrRestore,
  });

  final int count;
  final bool busy;
  final bool trashView;
  final bool archivedView;
  final VoidCallback onRead;
  final VoidCallback onUnread;
  final VoidCallback onArchiveOrUnarchive;
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
                child: Text(
                  '$count selected',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.primary),
                ),
              ),
              const Spacer(),
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
              if (!trashView)
                IconButton(
                  tooltip: archivedView ? 'Unarchive' : 'Archive',
                  onPressed: busy || count == 0 ? null : onArchiveOrUnarchive,
                  icon: Icon(
                    archivedView
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                ),
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
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.softFill(context, color),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: color, size: 27),
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

IconData _mailboxIcon(String mailbox) {
  return switch (mailbox) {
    'UNREAD' => Icons.mark_email_unread_outlined,
    'READ' => Icons.mark_email_read_outlined,
    'ARCHIVED' => Icons.archive_outlined,
    'TRASH' => Icons.delete_outline_rounded,
    'ALL' => Icons.all_inbox_rounded,
    _ => Icons.inbox_outlined,
  };
}

Color _categoryColor(String category) {
  return switch (category.toUpperCase()) {
    'PEOPLE' => AppColors.primary,
    'ORDERS' => AppColors.orange,
    'FINANCE' => AppColors.success,
    'NEWSLETTERS' => AppColors.cyan,
    'PROMOTIONS' => AppColors.indigo,
    'TRAVEL' => AppColors.warning,
    'SOCIAL' => const Color(0xFFEC4899),
    'SPAM' => AppColors.danger,
    _ => AppColors.muted,
  };
}

String _compactDate(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  final now = DateTime.now();
  final sameDay =
      parsed.year == now.year &&
      parsed.month == now.month &&
      parsed.day == now.day;
  if (sameDay) {
    final hour = parsed.hour == 0
        ? 12
        : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${parsed.hour >= 12 ? 'PM' : 'AM'}';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.day}';
}

String _friendly(String value) {
  final lower = value.toLowerCase().replaceAll('_', ' ');
  return lower.isEmpty
      ? value
      : '${lower[0].toUpperCase()}${lower.substring(1)}';
}
