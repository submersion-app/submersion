import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The hydrated dive list narrowed to the ids the compiled filter keeps
/// (#2365), for the table, map and export views.
///
/// [ids] is the id set's own AsyncValue. Its rules, in order:
/// - an error is an error, even when a previous set exists: a failed
///   refresh must never leave stale ids on screen as if they were current;
/// - a refresh in flight keeps the previous set, so a write to a watched
///   table does not blank the list;
/// - a first load is loading;
/// - a null set means no filter, and the list passes through untouched.
AsyncValue<List<Dive>> narrowDivesByIds(
  AsyncValue<List<Dive>> dives,
  AsyncValue<Set<String>?> ids,
) {
  if (ids.hasError) {
    return AsyncValue.error(ids.error!, ids.stackTrace ?? StackTrace.empty);
  }
  if (!ids.hasValue) return const AsyncValue.loading();
  final keep = ids.value;
  return dives.whenData(
    (all) =>
        keep == null ? all : all.where((d) => keep.contains(d.id)).toList(),
  );
}
