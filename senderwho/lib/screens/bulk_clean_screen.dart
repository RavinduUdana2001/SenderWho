import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/emails_screen.dart';
import '../services/senderwho_repository.dart';
import '../services/repository_scope.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_button.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';

class BulkCleanScreen extends StatefulWidget {
  const BulkCleanScreen({super.key, this.repository});

  static const routeName = '/bulk-clean';

  final SenderWhoRepository? repository;

  @override
  State<BulkCleanScreen> createState() => _BulkCleanScreenState();
}

class _BulkCleanScreenState extends State<BulkCleanScreen> {
  late Future<List<CleanupSuggestion>> _suggestionsFuture;
  List<CleanupJobInfo> _activeJobs = const [];
  final Set<String> _selectedSuggestionIds = {};
  bool _queueing = false;
  bool _preparingPreview = false;
  bool _canceling = false;
  String? _pollError;
  Timer? _pollTimer;

  SenderWhoRepository get _repository =>
      widget.repository ?? RepositoryScope.read(context);

  @override
  void initState() {
    super.initState();
    _suggestionsFuture = _repository.getCleanupSuggestions();
    unawaited(_restoreActiveJobs());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreActiveJobs() async {
    try {
      final jobs = await _repository.getActiveCleanupJobs();
      if (!mounted || jobs.isEmpty) return;
      setState(() {
        _activeJobs = jobs;
        _pollError = null;
      });
      unawaited(_pollJobs());
    } on SenderWhoRequestException {
      // Suggestions remain usable when there is no active cleanup to restore.
    }
  }

  Future<void> _pollJobs() async {
    if (_activeJobs.isEmpty || _canceling) return;
    final jobs = await Future.wait(
      _activeJobs.map((job) => _repository.getCleanupJob(job.id)),
    );
    if (!mounted || _canceling) return;
    final previous = _activeJobs;
    final available = <CleanupJobInfo>[
      for (var index = 0; index < previous.length; index++)
        jobs[index] ?? previous[index],
    ];
    final pollFailed = jobs.any((job) => job == null);
    setState(() {
      _activeJobs = available;
      _pollError = pollFailed
          ? _repository.lastError ?? 'Cleanup progress could not be refreshed.'
          : null;
    });
    if (available.isNotEmpty && available.every((job) => job.isFinished)) {
      _pollTimer?.cancel();
      setState(() {
        _suggestionsFuture = _repository.getCleanupSuggestions();
        _selectedSuggestionIds.clear();
        _pollError = null;
      });
      final processed = available.fold<int>(
        0,
        (sum, job) => sum + job.processedMessages,
      );
      final failed = available.fold<int>(
        0,
        (sum, job) => sum + job.failedMessages,
      );
      final canceled = available.any((job) => job.isCanceled);
      final unchanged = available.fold<int>(
        0,
        (sum, job) => sum + job.remainingMessages,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            canceled
                ? 'Cleanup stopped after $processed messages. $unchanged messages were left unchanged${failed > 0 ? ' and $failed could not be processed' : ''}.'
                : failed == 0
                ? '$processed messages cleaned from your inbox.'
                : '$processed messages cleaned; $failed could not be cleaned. Review the remaining suggestions to try again.',
          ),
        ),
      );
      return;
    }
    _pollTimer?.cancel();
    _pollTimer = Timer(const Duration(seconds: 2), _pollJobs);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CleanupSuggestion>>(
      future: _suggestionsFuture,
      builder: (context, snapshot) {
        final suggestions = snapshot.data ?? const <CleanupSuggestion>[];
        if (snapshot.hasError) {
          return AppPage(
            header: const AppHeader(
              title: 'Bulk Clean',
              subtitle: 'Review suggestions before changing your inbox',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: context.gap(18)),
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: () => setState(() {
                    _suggestionsFuture = _repository.getCleanupSuggestions();
                  }),
                ),
              ],
            ),
          );
        }
        final selectedSuggestions = suggestions
            .where((item) => _selectedSuggestionIds.contains(item.id))
            .toList();
        final selectedMatches = selectedSuggestions.fold<int>(
          0,
          (sum, item) => sum + item.messageCount,
        );
        final selectedBytes = selectedSuggestions.fold<int>(
          0,
          (sum, item) => sum + item.estimatedSpaceBytes,
        );
        final allSelected =
            suggestions.isNotEmpty &&
            selectedSuggestions.length == suggestions.length;
        final cleanupRunning = _activeJobs.any((job) => !job.isFinished);
        final selectionLocked =
            cleanupRunning || _queueing || _preparingPreview;

        return AppPage(
          header: const AppHeader(
            title: 'Bulk Clean',
            subtitle: 'Review suggestions before changing your inbox',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: context.gap(18)),
              _CleanupHero(
                suggestionCount: suggestions.length,
                loading: snapshot.connectionState == ConnectionState.waiting,
              ),
              SizedBox(height: context.gap(18)),
              if (selectedSuggestions.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_formatNumber(selectedMatches)} matching emails · ${_formatBytes(selectedBytes)} estimated',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    'Choose what to clean',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (suggestions.isNotEmpty)
                    TextButton(
                      onPressed: selectionLocked
                          ? null
                          : () => setState(() {
                              if (allSelected) {
                                _selectedSuggestionIds.clear();
                              } else {
                                _selectedSuggestionIds.addAll(
                                  suggestions.map((item) => item.id),
                                );
                              }
                            }),
                      child: Text(allSelected ? 'Clear all' : 'Select all'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (suggestions.isEmpty &&
                  snapshot.connectionState != ConnectionState.waiting)
                const AppCard(
                  padding: EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No cleanup suggestions are available. Your latest scan did not find safe cleanup groups.',
                        ),
                      ),
                    ],
                  ),
                ),
              for (final item in suggestions) ...[
                _CleanupSuggestionCard(
                  suggestion: item,
                  selected: _selectedSuggestionIds.contains(item.id),
                  enabled: !selectionLocked,
                  onSelected: (selected) => setState(() {
                    selected
                        ? _selectedSuggestionIds.add(item.id)
                        : _selectedSuggestionIds.remove(item.id);
                  }),
                  onReview: () => Navigator.pushNamed(
                    context,
                    EmailsScreen.routeName,
                    arguments: EmailListArguments(
                      mailbox: 'ALL',
                      cleanupCategory: item.categoryKey,
                      title: item.category,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(height: context.gap(24)),
              if (_activeJobs.isNotEmpty) ...[
                _CleanupProgressCard(
                  jobs: _activeJobs,
                  stopping: _canceling,
                  onStop: cleanupRunning ? _confirmStopCleanup : null,
                ),
                if (_pollError case final error?) ...[
                  const SizedBox(height: 12),
                  AppAsyncError(
                    title: 'Progress temporarily unavailable',
                    message: error,
                    onRetry: _pollJobs,
                  ),
                ],
                SizedBox(height: context.gap(24)),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 15,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Important messages and trusted senders stay protected',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.gap(24)),
              AppButton(
                label: cleanupRunning
                    ? 'Cleanup in progress…'
                    : _preparingPreview
                    ? 'Calculating exact cleanup…'
                    : _queueing
                    ? 'Starting cleanup…'
                    : selectedSuggestions.isEmpty
                    ? 'Select at least one group'
                    : 'Review & clean ${selectedSuggestions.length} group${selectedSuggestions.length == 1 ? '' : 's'}',
                backgroundColor: AppColors.danger,
                loading: _preparingPreview || _queueing,
                onPressed:
                    _preparingPreview ||
                        _queueing ||
                        selectedSuggestions.isEmpty ||
                        cleanupRunning
                    ? null
                    : () => _showCleanDialog(context, selectedSuggestions),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCleanDialog(
    BuildContext context,
    List<CleanupSuggestion> suggestions,
  ) async {
    if (_queueing || _preparingPreview) return;
    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages are ready to clean.')),
      );
      return;
    }

    final categoriesByAccount = <String, Set<String>>{};
    for (final suggestion in suggestions) {
      categoriesByAccount
          .putIfAbsent(suggestion.emailAccountId, () => <String>{})
          .add(suggestion.categoryKey);
    }
    setState(() => _preparingPreview = true);
    final entries = categoriesByAccount.entries.toList();
    final previews = await Future.wait(
      entries.map(
        (entry) => _repository.previewCleanup(
          emailAccountId: entry.key,
          categories: entry.value.toList(),
        ),
      ),
    );
    if (!mounted || !context.mounted) return;
    setState(() => _preparingPreview = false);
    if (previews.any((preview) => preview == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _repository.lastError ??
                'The exact cleanup preview could not be calculated. Nothing was changed.',
          ),
        ),
      );
      return;
    }

    final exactMessages = previews.fold<int>(
      0,
      (sum, preview) => sum + preview!.totalMessages,
    );
    final exactBytes = previews.fold<int>(
      0,
      (sum, preview) => sum + preview!.estimatedSpaceBytes,
    );
    if (exactMessages == 0) {
      setState(() {
        _selectedSuggestionIds.clear();
        _suggestionsFuture = _repository.getCleanupSuggestions();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No matching messages remain. Nothing was changed.'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Clean selected messages?'),
        content: _CleanupConfirmationContent(
          suggestions: suggestions,
          exactMessages: exactMessages,
          exactBytes: exactBytes,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Clean now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !context.mounted) return;
    await _startCleanup(previews.whereType<CleanupPreview>().toList());
  }

  Future<void> _startCleanup(List<CleanupPreview> previews) async {
    if (_queueing) return;
    setState(() => _queueing = true);
    final jobs = <CleanupJobInfo>[];
    for (final preview in previews) {
      final job = await _repository.createCleanupJob(
        emailAccountId: preview.emailAccountId,
        categories: preview.categories,
        previewId: preview.previewId,
      );
      if (job != null) jobs.add(job);
    }
    if (!mounted) return;
    setState(() {
      _queueing = false;
      if (jobs.isNotEmpty) {
        _activeJobs = jobs;
        _pollError = null;
      }
    });
    if (jobs.isNotEmpty) _pollJobs();

    final requestedJobs = previews.length;
    final queuedMessages = jobs.fold<int>(
      0,
      (sum, job) => sum + job.totalMessages,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          jobs.length == requestedJobs
              ? 'Cleanup started for $queuedMessages unique messages.'
              : jobs.isEmpty
              ? _repository.lastError ??
                    'Cleanup could not be queued. Nothing was changed.'
              : '${jobs.length} of $requestedJobs cleanup jobs started. The unstarted account can be retried safely.',
        ),
      ),
    );
  }

  Future<void> _confirmStopCleanup() async {
    final activeJobs = _activeJobs.where((job) => !job.isFinished).toList();
    if (_canceling || activeJobs.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Stop cleanup?'),
        content: const Text(
          'Messages already moved will stay in Trash. A small number of actions already in progress may finish, but all remaining messages will stay in your inbox.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep cleaning'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop cleanup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _pollTimer?.cancel();
    setState(() {
      _canceling = true;
      _pollError = null;
    });
    final results = await Future.wait(
      activeJobs.map((job) => _repository.cancelCleanupJob(job.id)),
    );
    if (!mounted) return;
    final updates = <String, CleanupJobInfo>{
      for (final result in results.whereType<CleanupJobInfo>())
        result.id: result,
    };
    final failedRequests = results.where((result) => result == null).length;
    setState(() {
      _canceling = false;
      _activeJobs = [for (final job in _activeJobs) updates[job.id] ?? job];
      _pollError = failedRequests == 0
          ? null
          : _repository.lastError ??
                'Some cleanup jobs could not be stopped. Please try again.';
    });
    await _pollJobs();
  }
}

class _CleanupConfirmationContent extends StatelessWidget {
  const _CleanupConfirmationContent({
    required this.suggestions,
    required this.exactMessages,
    required this.exactBytes,
  });

  final List<CleanupSuggestion> suggestions;
  final int exactMessages;
  final int exactBytes;

  @override
  Widget build(BuildContext context) {
    final categoryNames = suggestions
        .map((suggestion) => suggestion.category)
        .toSet()
        .join(', ');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_formatNumber(exactMessages)} messages · ${_formatBytes(exactBytes)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            categoryNames,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Removes these messages from your inbox. They remain recoverable for a limited period, and trusted senders stay protected.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanupProgressCard extends StatelessWidget {
  const _CleanupProgressCard({
    required this.jobs,
    required this.stopping,
    this.onStop,
  });

  final List<CleanupJobInfo> jobs;
  final bool stopping;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final total = jobs.fold<int>(0, (sum, job) => sum + job.totalMessages);
    final moved = jobs.fold<int>(0, (sum, job) => sum + job.processedMessages);
    final failed = jobs.fold<int>(0, (sum, job) => sum + job.failedMessages);
    final attempted = moved + failed;
    final remaining = total > attempted ? total - attempted : 0;
    final progress = total == 0 ? 0.0 : (attempted / total).clamp(0.0, 1.0);
    final finished = jobs.every((job) => job.isFinished);
    final canceled = jobs.any((job) => job.isCanceled);
    final hasFailures = !canceled && finished && (failed > 0 || remaining > 0);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                !finished
                    ? Icons.sync_rounded
                    : canceled
                    ? Icons.stop_circle_outlined
                    : hasFailures
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline,
                color: canceled
                    ? AppColors.warning
                    : hasFailures
                    ? AppColors.danger
                    : AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  !finished
                      ? 'Cleaning messages'
                      : canceled
                      ? 'Cleanup stopped'
                      : hasFailures
                      ? 'Cleanup completed with issues'
                      : 'Cleanup finished',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text('$attempted / $total'),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CleanupFact(
                icon: Icons.delete_sweep_outlined,
                label: '$moved cleaned',
                color: AppColors.primary,
              ),
              if (failed > 0)
                _CleanupFact(
                  icon: Icons.error_outline_rounded,
                  label: finished
                      ? '$failed failed'
                      : '$failed issue${failed == 1 ? '' : 's'} so far',
                  color: AppColors.danger,
                ),
              if (remaining > 0)
                _CleanupFact(
                  icon: canceled
                      ? Icons.mark_email_read_outlined
                      : Icons.replay_rounded,
                  label: canceled
                      ? '$remaining left unchanged'
                      : '$remaining remaining',
                  color: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            !finished
                ? 'Cleanup continues safely in the background.'
                : canceled
                ? 'Already cleaned messages remain in Trash. Unprocessed messages were left in your inbox.'
                : hasFailures
                ? 'Refresh the suggestions, review the remaining messages, and retry safely.'
                : 'Messages were removed from your inbox and remain recoverable for a limited period.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!finished && onStop != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('cleanup-stop'),
                onPressed: stopping ? null : onStop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.5),
                  ),
                ),
                icon: stopping
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.stop_circle_outlined),
                label: Text(stopping ? 'Stopping cleanup…' : 'Stop cleanup'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CleanupSuggestionCard extends StatelessWidget {
  const _CleanupSuggestionCard({
    required this.suggestion,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    required this.onReview,
  });

  final CleanupSuggestion suggestion;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onSelected;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: ValueKey('cleanup-suggestion-${suggestion.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 12,
      color: selected
          ? AppColors.softFill(context, AppColors.primary)
          : Theme.of(context).colorScheme.surfaceContainer,
      onTap: enabled ? () => onSelected(!selected) : null,
      child: Column(
        children: [
          Row(
            children: [
              Icon(_cleanupIcon(suggestion.categoryKey), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.category,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _cleanupDescription(suggestion.categoryKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Checkbox(
                key: ValueKey('cleanup-select-${suggestion.id}'),
                value: selected,
                onChanged: enabled
                    ? (value) => onSelected(value ?? false)
                    : null,
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              Text(
                '${_formatNumber(suggestion.messageCount)} emails · ${_formatBytes(suggestion.estimatedSpaceBytes)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Tooltip(
                message: _cleanupCriteria(suggestion.categoryKey),
                child: TextButton(
                  onPressed: onReview,
                  child: const Text('Review messages'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CleanupFact extends StatelessWidget {
  const _CleanupFact({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = AppColors.foregroundFor(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softFill(context, color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: resolvedColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CleanupHero extends StatelessWidget {
  const _CleanupHero({required this.suggestionCount, required this.loading});

  final int suggestionCount;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        loading
            ? 'Finding emails you can clean up…'
            : '$suggestionCount groups to review. Nothing moves to Trash until you confirm.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

IconData _cleanupIcon(String category) {
  return switch (category.toUpperCase()) {
    'MARKETING' || 'PROMOTIONS' => Icons.local_offer_outlined,
    'NEWSLETTERS' => Icons.newspaper_outlined,
    'SPAM' => Icons.report_gmailerrorred_outlined,
    'OLD_UNREAD' => Icons.mark_email_unread_outlined,
    'LARGE_ATTACHMENTS' => Icons.attach_file_rounded,
    _ => Icons.auto_delete_outlined,
  };
}

String _cleanupDescription(String category) {
  return switch (category.toUpperCase()) {
    'MARKETING' || 'PROMOTIONS' =>
      'Promotional offers and marketing campaigns from untrusted senders.',
    'NEWSLETTERS' =>
      'Recurring newsletter messages from senders you have not trusted.',
    'SPAM' => 'Messages already categorized as spam or junk.',
    'OLD_UNREAD' =>
      'Unread messages older than 90 days that may no longer need attention.',
    'LARGE_ATTACHMENTS' =>
      'Messages with attachments or content using at least 5 MB.',
    _ => 'Messages matching this safe cleanup suggestion.',
  };
}

String _cleanupCriteria(String category) {
  return switch (category.toUpperCase()) {
    'MARKETING' || 'PROMOTIONS' => 'Category: Promotions',
    'NEWSLETTERS' => 'Category: Newsletters',
    'SPAM' => 'Category: Spam',
    'OLD_UNREAD' => 'Unread · older than 90 days',
    'LARGE_ATTACHMENTS' => 'Message size · 5 MB or larger',
    _ => 'Matched by the latest inbox scan',
  };
}

String _formatNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
