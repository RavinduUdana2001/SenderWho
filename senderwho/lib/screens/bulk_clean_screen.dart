import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/emails_screen.dart';
import '../services/senderwho_repository.dart';
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
  String? _pollError;
  Timer? _pollTimer;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

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
    if (_activeJobs.isEmpty) return;
    final jobs = await Future.wait(
      _activeJobs.map((job) => _repository.getCleanupJob(job.id)),
    );
    if (!mounted) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed == 0
                ? '$processed messages cleaned from your inbox.'
                : '$processed cleaned and $failed failed. You can retry the remaining suggestions.',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppHeader(
                  title: 'Bulk Clean',
                  subtitle: 'Review suggestions before changing your inbox',
                ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppHeader(
                title: 'Bulk Clean',
                subtitle: 'Review suggestions before changing your inbox',
              ),
              SizedBox(height: context.gap(18)),
              _CleanupHero(
                suggestionCount: suggestions.length,
                loading: snapshot.connectionState == ConnectionState.waiting,
              ),
              SizedBox(height: context.gap(18)),
              LayoutBuilder(
                builder: (context, constraints) {
                  final gap = constraints.maxWidth < 340 ? 12.0 : 24.0;
                  return Row(
                    children: [
                      Expanded(
                        child: _CleanStat(
                          icon: Icons.sd_storage_outlined,
                          color: AppColors.indigo,
                          value: _formatBytes(selectedBytes),
                          label: 'Selected matching space',
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _CleanStat(
                          icon: Icons.mark_email_unread_outlined,
                          color: AppColors.primary,
                          value: _formatNumber(selectedMatches),
                          label: 'Selected matches before de-duplication',
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: context.gap(24)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose what to clean',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nothing moves until you review the groups and confirm the exact unique total.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
                _CleanupProgressCard(jobs: _activeJobs),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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
  const _CleanupProgressCard({required this.jobs});

  final List<CleanupJobInfo> jobs;

  @override
  Widget build(BuildContext context) {
    final total = jobs.fold<int>(0, (sum, job) => sum + job.totalMessages);
    final moved = jobs.fold<int>(0, (sum, job) => sum + job.processedMessages);
    final failed = jobs.fold<int>(0, (sum, job) => sum + job.failedMessages);
    final attempted = moved + failed;
    final remaining = total > attempted ? total - attempted : 0;
    final progress = total == 0 ? 0.0 : (attempted / total).clamp(0.0, 1.0);
    final finished = jobs.every((job) => job.isFinished);
    final hasFailures = finished && (failed > 0 || remaining > 0);
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
                    : hasFailures
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline,
                color: hasFailures ? AppColors.danger : AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  !finished
                      ? 'Cleaning messages'
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
                  label: finished ? '$failed failed' : '$failed issue so far',
                  color: AppColors.danger,
                ),
              if (remaining > 0)
                _CleanupFact(
                  icon: Icons.replay_rounded,
                  label: '$remaining remaining',
                  color: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            !finished
                ? 'Cleanup continues safely in the background.'
                : hasFailures
                ? 'Refresh the suggestions, review the remaining messages, and retry safely.'
                : 'Messages were removed from your inbox and remain recoverable for a limited period.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CleanStat extends StatelessWidget {
  const _CleanStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.softFill(context, color),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(height: 11),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(15),
      color: selected
          ? AppColors.softFill(context, AppColors.primary)
          : AppColors.surface(context),
      borderColor: selected ? AppColors.primary : AppColors.borderFor(context),
      onTap: enabled ? () => onSelected(!selected) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.softFill(context, AppColors.primary),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _cleanupIcon(suggestion.categoryKey),
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.category,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cleanupDescription(suggestion.categoryKey),
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
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CleanupFact(
                icon: Icons.mail_outline_rounded,
                label: '${_formatNumber(suggestion.messageCount)} matches',
                color: AppColors.primary,
              ),
              _CleanupFact(
                icon: Icons.sd_storage_outlined,
                label: _formatBytes(suggestion.estimatedSpaceBytes),
                color: AppColors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _cleanupCriteria(suggestion.categoryKey),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              TextButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.visibility_outlined, size: 17),
                label: const Text('Review messages'),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.softFill(context, color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softFill(context, AppColors.primary),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    loading
                        ? 'ANALYZING INBOX'
                        : '$suggestionCount CLEANUP GROUP${suggestionCount == 1 ? '' : 'S'}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'A cleaner inbox,\non your terms.',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Review every group before messages are removed from your inbox.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 12, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.softFill(context, AppColors.primary),
              shape: BoxShape.circle,
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primary,
                    size: 31,
                  ),
          ),
        ],
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
