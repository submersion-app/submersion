import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';

/// Builds a self-contained SQL subquery `SELECT fq.id FROM dives fq WHERE
/// ...` selecting the ids of all dives matching [filter], for Statistics'
/// `id IN (...)` fragments.
///
/// A wrapper over the one compiler every dive path uses (#2365): the tree
/// `DiveFilterState.toQuery()` returns, compiled with the `fq` alias so
/// its correlated subqueries never collide with the caller's `d` or
/// `dives`. Returns an empty no-op (`subquery: ''`, `params: []`) when the
/// filter has no active axes, so callers can skip injecting anything.
({String subquery, List<Object?> params}) buildFilteredDiveIdSubquery(
  DiveFilterState filter,
) {
  final compiled = compileDiveFilter(filter, rootAlias: 'fq');
  if (compiled.isEmpty) return (subquery: '', params: const <Object?>[]);
  return (subquery: compiled.idSubquery(), params: compiled.params);
}

/// Recorded deco-signal SQL condition (no bind params), shared by
/// [buildFilteredDiveIdSubquery], `DiveRepository._buildFilterWhereClauses`
/// and `DiveRepository.getDiveIdsWithDecoSignal` so the three SQL paths
/// (Statistics, the paginated dive list, and the id set the entity-backed
/// surfaces intersect with) can't drift apart. Mirrors
/// `StatisticsRepository.scanRecordedDecoSignals`:
///
/// - A series with a recorded deco stop (`has_deco_stop`) or a
///   `decoStopStart` event means deco.
/// - A series that carries `deco_type` values (`has_deco_type`) but never a
///   stop means no-deco: the computer recorded obligations and reported
///   none.
/// - A positive ceiling (`has_positive_ceiling`) on a series with no
///   `deco_type` at all also means deco (some import sources only ever
///   write a stop depth).
/// - A dive with no qualifying series data matches neither branch; it is
///   only classifiable via the computed fallback, which this SQL-only axis
///   does not have access to.
///
/// The dive query registry's `deco` field reads this at every depth through
/// the `{r}` placeholder (#2365), so every dive path evaluates it the same
/// way.
///
/// [diveIdRef] must be a reference to the enclosing query's `dives.id`
/// resolvable from inside these correlated subqueries (e.g. `d.id` when the
/// caller aliases `dives` as `d`, or `dives.id` when it does not).
String decoSignalCondition({
  required bool wantDeco,
  required String diveIdRef,
}) {
  final hasDecoStop =
      'EXISTS (SELECT 1 FROM dive_profile_series s '
      'WHERE s.dive_id = $diveIdRef AND s.has_deco_stop = 1) '
      "OR EXISTS (SELECT 1 FROM dive_profile_events e "
      "WHERE e.dive_id = $diveIdRef AND e.event_type = 'decoStopStart')";
  final hasDecoType =
      'EXISTS (SELECT 1 FROM dive_profile_series s '
      'WHERE s.dive_id = $diveIdRef AND s.has_deco_type = 1)';
  final hasPositiveCeiling =
      'EXISTS (SELECT 1 FROM dive_profile_series s '
      'WHERE s.dive_id = $diveIdRef AND s.has_positive_ceiling = 1)';

  if (wantDeco) {
    return '($hasDecoStop OR (NOT ($hasDecoType) AND $hasPositiveCeiling))';
  }
  return '($hasDecoType AND NOT ($hasDecoStop))';
}
