/// Order helpers shared by every detail page whose sections the diver can
/// hide and reorder (Dive Details, Site Details).
///
/// A page stores its sections as a list of configs, one per section id, in
/// the diver's order. These functions see a config only through `idOf`, so
/// they work for any page's config type.
library;

/// [sections] reordered as if [rendered] had its [oldIndex] entry dropped at
/// [newIndex].
///
/// A page renders only the sections that are visible and have content, so a
/// drop index in that subset is not an index into the saved list. The moved
/// section is re-anchored next to the rendered neighbour it was dropped
/// against, which leaves every section outside [rendered] (hidden ones
/// included) where the diver left it.
///
/// Indices follow `ReorderableListView.onReorderItem`: [newIndex] is the
/// final resting index, already adjusted for the removal. Returns
/// [sections] itself when the move is a no-op or out of range.
List<C> moveRenderedSection<C, T>(
  List<C> sections,
  T Function(C) idOf,
  List<T> rendered,
  int oldIndex,
  int newIndex,
) {
  if (oldIndex == newIndex ||
      rendered.length < 2 ||
      oldIndex < 0 ||
      oldIndex >= rendered.length ||
      newIndex < 0 ||
      newIndex >= rendered.length) {
    return sections;
  }

  final movedId = rendered[oldIndex];
  final movedAt = sections.indexWhere((s) => idOf(s) == movedId);
  if (movedAt < 0) return sections;
  final config = sections[movedAt];

  final reordered = List.of(rendered)..removeAt(oldIndex);
  reordered.insert(newIndex, movedId);

  final result = List.of(sections)..removeWhere((s) => idOf(s) == movedId);

  // Anchor on the rendered section that now follows the moved one, so it
  // lands immediately before it; at the end of the list, anchor on the one
  // it now follows instead.
  final followingId = newIndex + 1 < reordered.length
      ? reordered[newIndex + 1]
      : null;
  if (followingId != null) {
    final at = result.indexWhere((s) => idOf(s) == followingId);
    if (at >= 0) {
      result.insert(at, config);
      return result;
    }
  }
  final precedingId = newIndex > 0 ? reordered[newIndex - 1] : null;
  if (precedingId != null) {
    final at = result.indexWhere((s) => idOf(s) == precedingId);
    if (at >= 0) {
      result.insert(at + 1, config);
      return result;
    }
  }
  result.insert(0, config);
  return result;
}

/// [sections] with a config from [create] added for every id in [allIds]
/// that it lacks.
///
/// A section added in a later release must not land at the bottom of an
/// order saved before it existed. Each missing id is instead inserted just
/// after its nearest preceding sibling in [allIds] (the default order), or
/// at the top when none of them is present. Returns [sections] itself when
/// nothing is missing.
List<C> ensureAllSections<C, T>(
  List<C> sections,
  T Function(C) idOf,
  List<T> allIds,
  C Function(T) create,
) {
  final presentIds = sections.map(idOf).toSet();
  if (allIds.every(presentIds.contains)) return sections;

  final result = List.of(sections);
  for (var i = 0; i < allIds.length; i++) {
    final id = allIds[i];
    if (presentIds.contains(id)) continue;
    result.insert(_insertionIndex(result, idOf, allIds, i), create(id));
    presentIds.add(id);
  }
  return result;
}

/// Where the id at [defaultIndex] of [allIds] belongs in [sections], by
/// default-order adjacency.
int _insertionIndex<C, T>(
  List<C> sections,
  T Function(C) idOf,
  List<T> allIds,
  int defaultIndex,
) {
  for (var i = defaultIndex - 1; i >= 0; i--) {
    final position = sections.indexWhere((s) => idOf(s) == allIds[i]);
    if (position >= 0) return position + 1;
  }
  return 0;
}
