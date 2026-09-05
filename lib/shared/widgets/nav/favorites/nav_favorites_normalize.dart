/// Normalizes a stored list of favorite nav destination ids.
///
/// Guarantees on the returned list:
/// - Every id is in [validIds] (unknown and pinned ids are dropped, so a
///   destination removed in a later release simply disappears from the
///   favorites instead of crashing the sidebar).
/// - No duplicates (first occurrence wins).
/// - Stored order is preserved.
List<String> normalizeNavFavoriteIds({
  required List<String> stored,
  required List<String> validIds,
}) {
  final result = <String>[];
  for (final id in stored) {
    if (!validIds.contains(id)) continue;
    if (result.contains(id)) continue;
    result.add(id);
  }
  return List.unmodifiable(result);
}
