/// [all] without the built-in entries whose id is in [hidden] (issue #401).
///
/// Custom entries are never dropped, even one sharing a built-in's id. An
/// entry whose id is in [keep] stays even when hidden, so a picker still
/// shows the value a record already uses. Order is preserved, and [all]
/// itself is returned when nothing is dropped.
List<T> visibleBuiltIns<T>(
  List<T> all,
  Set<String> hidden, {
  required bool Function(T) isBuiltIn,
  required String Function(T) idOf,
  Iterable<String?> keep = const [],
}) {
  if (hidden.isEmpty) return all;
  final kept = {for (final id in keep) ?id};
  final visible = [
    for (final entry in all)
      if (!isBuiltIn(entry) ||
          !hidden.contains(idOf(entry)) ||
          kept.contains(idOf(entry)))
        entry,
  ];
  return visible.length == all.length ? all : visible;
}
