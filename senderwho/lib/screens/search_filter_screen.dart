import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../screens/sender_details_screen.dart';
import '../screens/email_details_screen.dart';
import '../services/senderwho_repository.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';
import '../widgets/app_button.dart';
import '../widgets/app_async_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_chips.dart';
import '../widgets/app_header.dart';
import '../widgets/app_page.dart';
import '../widgets/search_box.dart';
import '../widgets/section_title.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key, this.repository});

  static const routeName = '/search-filter';
  final SenderWhoRepository? repository;

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final selected = <String>{'All', 'Any time'};
  final _queryController = TextEditingController();
  late Future<SearchFilterOptions> _optionsFuture;
  SearchResults? _results;
  bool _searching = false;
  bool _loadingMore = false;
  bool _filtersExpanded = true;
  String? _searchError;
  bool attachments = false;
  bool unread = false;

  SenderWhoRepository get _repository =>
      widget.repository ?? senderWhoRepository;

  @override
  void initState() {
    super.initState();
    _optionsFuture = _repository.getSearchFilterOptions();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SearchFilterOptions>(
      future: _optionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppHeader(
                  title: 'Search & Filter',
                  subtitle: 'Find senders and messages in email metadata',
                ),
                SizedBox(height: 18),
                AppCard(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          );
        }
        final options =
            snapshot.data ??
            SearchFilterOptions.fromJson({
              'categories': const <String>[],
              'trustScores': const <String>[],
              'dateRanges': const <String>[],
            });

        if (snapshot.hasError) {
          return AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppHeader(
                  title: 'Search & Filter',
                  subtitle: 'Find senders and messages in email metadata',
                ),
                SizedBox(height: context.gap(18)),
                AppAsyncError(
                  message: appAsyncErrorMessage(snapshot.error),
                  onRetry: () => setState(() {
                    _optionsFuture = _repository.getSearchFilterOptions();
                  }),
                ),
              ],
            ),
          );
        }

        return AppPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(
                title: 'Search & Filter',
                subtitle: 'Find senders and messages in email metadata',
              ),
              SizedBox(height: context.gap(18)),
              SearchBox(
                hint: 'Search senders or email',
                controller: _queryController,
                onSubmitted: (_) => _applyFilters(),
              ),
              SizedBox(height: context.gap(18)),
              AppCard(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SectionTitle(title: 'Filters')),
                        if (_activeFilterCount > 0)
                          StatusChip(
                            label: '$_activeFilterCount active',
                            color: AppColors.primary,
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          key: const ValueKey('search-filter-toggle'),
                          tooltip: _filtersExpanded
                              ? 'Collapse filters'
                              : 'Edit filters',
                          onPressed: () => setState(
                            () => _filtersExpanded = !_filtersExpanded,
                          ),
                          icon: Icon(
                            _filtersExpanded
                                ? Icons.expand_less_rounded
                                : Icons.tune_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (!_filtersExpanded) ...[
                      const SizedBox(height: 4),
                      Text(
                        _filterSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      const SectionTitle(title: 'Categories'),
                      const SizedBox(height: 12),
                      _PillWrap(
                        labels: options.categories,
                        selected: selected,
                        onTap: _toggle,
                      ),
                      const SizedBox(height: 18),
                      Divider(color: AppColors.borderFor(context)),
                      const SizedBox(height: 17),
                      const SectionTitle(title: 'Trust Score'),
                      const SizedBox(height: 12),
                      _PillWrap(
                        labels: options.trustScores,
                        selected: selected,
                        onTap: _toggle,
                      ),
                      const SizedBox(height: 18),
                      Divider(color: AppColors.borderFor(context)),
                      const SizedBox(height: 17),
                      const SectionTitle(title: 'Date Range'),
                      const SizedBox(height: 12),
                      _PillWrap(
                        labels: options.dateRanges,
                        selected: selected,
                        onTap: _toggle,
                      ),
                      if (_activeFilterCount > 0) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.restart_alt_rounded),
                            label: const Text('Reset filters'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (_filtersExpanded) ...[
                SizedBox(height: context.gap(14)),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        value: attachments,
                        onChanged: (value) =>
                            setState(() => attachments = value),
                        secondary: const Icon(
                          Icons.attach_file_rounded,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          'Has attachments',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Divider(color: AppColors.borderFor(context)),
                      SwitchListTile.adaptive(
                        value: unread,
                        onChanged: (value) => setState(() => unread = value),
                        secondary: const Icon(
                          Icons.mark_email_unread_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(
                          'Unread only',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: context.gap(18)),
              AppButton(
                label: _searching ? 'Searching…' : 'Search email metadata',
                onPressed: _searching ? null : () => _applyFilters(),
              ),
              if (_searching) ...[
                const SizedBox(height: 18),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_searchError case final error?) ...[
                const SizedBox(height: 18),
                AppAsyncError(
                  title: 'Search could not be completed',
                  message: error,
                  onRetry: () => _applyFilters(),
                ),
              ],
              if (_results case final results?) ...[
                SizedBox(height: context.gap(25)),
                SectionTitle(title: '${results.total} matching results'),
                const SizedBox(height: 14),
                if (results.returned < results.total) ...[
                  Text(
                    'Showing the first ${results.returned} results.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                ],
                if (results.total == 0)
                  Text(
                    'No stored email metadata matches these filters.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                for (final sender in results.senders) ...[
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () => Navigator.pushNamed(
                      context,
                      SenderDetailsScreen.routeName,
                      arguments: sender.id,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sender.name),
                              const SizedBox(height: 4),
                              Text(
                                sender.email,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Text('${sender.score}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                for (final email in results.emails) ...[
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    onTap: email.id.isEmpty
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            EmailDetailsScreen.routeName,
                            arguments: email,
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${email.sender} • ${email.date}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (results.hasMore) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _loadingMore
                          ? null
                          : () => _applyFilters(reset: false),
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
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyFilters({bool reset = true}) async {
    if (_searching || _loadingMore) return;
    setState(() {
      if (reset) {
        _searching = true;
        _results = null;
      } else {
        _loadingMore = true;
      }
      _searchError = null;
    });
    final results = await _repository.search(
      query: _queryController.text,
      selected: selected,
      attachments: attachments,
      unread: unread,
      page: reset ? 1 : (_results?.page ?? 0) + 1,
    );
    if (!mounted) return;
    setState(() {
      _searching = false;
      _loadingMore = false;
      if (results == null) {
        _searchError =
            _repository.lastError ?? 'Search failed. Check your connection.';
      } else {
        _results = reset ? results : _results?.append(results) ?? results;
        if (reset) _filtersExpanded = false;
      }
    });
  }

  int get _activeFilterCount =>
      selected.where((item) => item != 'All' && item != 'Any time').length +
      (attachments ? 1 : 0) +
      (unread ? 1 : 0);

  String get _filterSummary {
    final active = selected
        .where((item) => item != 'All' && item != 'Any time')
        .toList();
    if (attachments) active.add('Has attachments');
    if (unread) active.add('Unread only');
    return active.isEmpty ? 'All messages · Any time' : active.join(' · ');
  }

  void _clearFilters() {
    setState(() {
      selected
        ..clear()
        ..addAll(const {'All', 'Any time'});
      attachments = false;
      unread = false;
    });
  }

  void _toggle(String label) {
    setState(() {
      const trustOptions = {'All', 'High (75+)', 'Medium (50-74)', 'Low (<50)'};
      const dateOptions = {'Any time', 'Today', 'This Week', 'This Month'};
      if (trustOptions.contains(label)) {
        selected.removeAll(trustOptions);
        selected.add(label);
      } else if (dateOptions.contains(label)) {
        selected.removeAll(dateOptions);
        selected.add(label);
      } else {
        selected.contains(label) ? selected.remove(label) : selected.add(label);
      }
    });
  }
}

class _PillWrap extends StatelessWidget {
  const _PillWrap({
    required this.labels,
    required this.selected,
    required this.onTap,
  });

  final List<String> labels;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final label in labels)
          SelectablePill(
            label: label,
            selected: selected.contains(label),
            onTap: () => onTap(label),
          ),
      ],
    );
  }
}
