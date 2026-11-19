/// Writes the difference between [loaded], a held list's rows as its
/// sitting read them, and [current], the rows it holds now (issue #4527,
/// phase 3, plan 6): a row of [current] new to the list is created
/// ([create]; a list that never gains rows of its own passes none, and the
/// row is updated), a changed one updated, and one of [loaded] missing from
/// [current] deleted, in that order. Untouched rows are left alone. Whether
/// anything was written.
Future<bool> writeRowChanges<E>({
  required List<E> loaded,
  required List<E> current,
  required String Function(E row) idOf,
  Future<void> Function(E row)? create,
  required Future<void> Function(E row) update,
  required Future<void> Function(String id) delete,
}) async {
  final byId = {for (final row in loaded) idOf(row): row};
  final kept = {for (final row in current) idOf(row)};
  var changed = false;
  for (final row in current) {
    final before = byId[idOf(row)];
    if (before == row) continue;
    await (before == null && create != null ? create(row) : update(row));
    changed = true;
  }
  for (final row in loaded) {
    final id = idOf(row);
    if (kept.contains(id)) continue;
    await delete(id);
    changed = true;
  }
  return changed;
}
