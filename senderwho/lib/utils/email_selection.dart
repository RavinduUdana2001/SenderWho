/// Predictable selection state shared by email list interactions and tests.
class EmailSelection {
  final Set<String> _ids = <String>{};

  Set<String> get ids => Set<String>.unmodifiable(_ids);
  int get count => _ids.length;
  bool get isEmpty => _ids.isEmpty;
  bool contains(String id) => _ids.contains(id);

  void toggle(String id) {
    if (id.isEmpty) return;
    if (!_ids.remove(id)) _ids.add(id);
  }

  void selectOnly(String id) {
    _ids.clear();
    if (id.isNotEmpty) _ids.add(id);
  }

  void selectAll(Iterable<String> ids) {
    _ids.addAll(ids.where((id) => id.isNotEmpty));
  }

  void retain(Iterable<String> availableIds) {
    _ids.retainAll(availableIds.toSet());
  }

  void replaceWith(Iterable<String> ids) {
    _ids
      ..clear()
      ..addAll(ids.where((id) => id.isNotEmpty));
  }

  void clear() => _ids.clear();
}
