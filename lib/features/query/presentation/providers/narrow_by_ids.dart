import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';

/// A hydrated list narrowed to the ids a compiled query keeps (#2365), for
/// every list that filters through an id set.
///
/// [ids] is the id set's own AsyncValue. Its rules, in order:
/// - an error is an error, even when a previous set exists: a failed
///   refresh must never leave stale ids on screen as if they were current;
/// - a refresh in flight keeps the previous set, so a write to a watched
///   table does not blank the list;
/// - a first load is loading;
/// - a null set means no filter, and the list passes through untouched.
AsyncValue<List<T>> narrowByIds<T>(
  AsyncValue<List<T>> items,
  AsyncValue<Set<String>?> ids,
  String Function(T item) idOf,
) {
  if (ids.hasError) {
    return AsyncValue.error(ids.error!, ids.stackTrace ?? StackTrace.empty);
  }
  if (!ids.hasValue) return const AsyncValue.loading();
  final keep = ids.value;
  return items.whenData(
    (all) =>
        keep == null ? all : all.where((e) => keep.contains(idOf(e))).toList(),
  );
}

/// [items] narrowed by [query] rooted at [root] (#2365), by [narrowByIds]'s
/// rules. No query passes the list through without touching the database,
/// so a list with no filter never waits on an id set.
AsyncValue<List<T>> narrowByQuery<T>(
  Ref ref,
  AsyncValue<List<T>> items,
  QueryEntity root,
  QueryNode? query,
  String Function(T item) idOf,
) => query == null
    ? items
    : narrowByIds(
        items,
        ref.watch(entityQueryIdsProvider((root: root, query: query))),
        idOf,
      );
