/// [all] with the entries whose id is in [favourites] moved to the front
/// (issue #4413).
///
/// A stable partition: starred entries keep their relative order, and so do
/// the rest. An id in [favourites] that matches no entry (a deleted custom
/// type, or one synced from a newer version) is ignored. [all] itself is
/// returned when no entry is starred; otherwise the result is a new list,
/// even when the starred entries already lead. An entry
/// whose [idOf] is null (one that cannot be starred) is never lifted.
List<T> favouritesFirst<T>(
  List<T> all,
  Set<String> favourites, {
  required String? Function(T) idOf,
}) {
  if (favourites.isEmpty) return all;
  final starred = <T>[];
  final rest = <T>[];
  for (final entry in all) {
    (favourites.contains(idOf(entry)) ? starred : rest).add(entry);
  }
  if (starred.isEmpty) return all;
  return [...starred, ...rest];
}

/// [current] with [id] starred or unstarred. Returns [current] itself when
/// nothing changes, so a settings write can be skipped.
Set<String> withDiveTypeFavourite(
  Set<String> current,
  String id,
  bool favourite,
) {
  if (current.contains(id) == favourite) return current;
  return favourite
      ? {...current, id}
      : {
          for (final existing in current)
            if (existing != id) existing,
        };
}
