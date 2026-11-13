import 'package:flutter/material.dart';
import 'app_chips.dart';
import 'search_box.dart';

const senderCategories = <String, String>{
  'IMPORTANT': 'Important',
  'PEOPLE': 'People',
  'ORDERS': 'Orders',
  'FINANCE': 'Finance',
  'NEWSLETTERS': 'Newsletters',
  'PROMOTIONS': 'Offers',
  'TRAVEL': 'Travel',
  'SOCIAL': 'Social',
  'SPAM': 'Spam',
  'UNKNOWN': 'Other',
};

class SenderFilters {
  const SenderFilters({this.category, this.query = ''});
  final String? category;
  final String query;
}

/// Draft filters apply together. Dismissing the sheet leaves the list intact.
class SenderFiltersSheet extends StatefulWidget {
  const SenderFiltersSheet({
    super.key,
    required this.initial,
    this.messages = false,
  });
  final SenderFilters initial;
  final bool messages;
  @override
  State<SenderFiltersSheet> createState() => _SenderFiltersSheetState();
}

class _SenderFiltersSheetState extends State<SenderFiltersSheet> {
  late final _query = TextEditingController(text: widget.initial.query);
  late String? _category = widget.initial.category;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _apply() {
    FocusScope.of(context).unfocus();
    Navigator.pop(
      context,
      SenderFilters(category: _category, query: _query.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter by category',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: widget.messages
                              ? 'Close message filters'
                              : 'Close sender filters',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  SearchBox(
                    key: ValueKey(
                      widget.messages
                          ? 'message-filter-search'
                          : 'sender-filter-search',
                    ),
                    controller: _query,
                    hint: widget.messages
                        ? 'Search messages'
                        : 'Sender name or email',
                    onSubmitted: (_) => _apply(),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      SelectablePill(
                        label: 'All categories',
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      for (final category in senderCategories.entries)
                        SelectablePill(
                          key: ValueKey(
                            '${widget.messages ? 'message' : 'sender'}-category-${category.key}',
                          ),
                          label: category.value,
                          selected: _category == category.key,
                          onTap: () => setState(() => _category = category.key),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _category = null;
                    _query.clear();
                  }),
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Apply filters'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
