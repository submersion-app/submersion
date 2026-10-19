/// SQL spellings of `Dive.effectiveRuntime`, for queries that must total dive
/// durations without hydrating `Dive` object graphs.
///
/// The chain has four steps, in order: the explicit `runtime`, then
/// `exit_time - entry_time`, then the span of the dive's profile samples,
/// then `bottom_time`. Every aggregate that reports "total dive time" has to
/// resolve all four, because a dive downloaded from a computer often carries
/// no explicit `runtime` at all and is only measurable through its profile.
/// A query that stops at `COALESCE(runtime, bottom_time)` silently reports
/// those dives as zero.
///
/// The fragments live here, in one file, so the depth-distribution and
/// dive-type aggregates cannot drift into two different answers for the same
/// dive. Callers pass the table alias their statement uses for `dives`.
library;

/// `entry_time` and `exit_time` are epoch milliseconds; `runtime` and
/// `bottom_time` are already stored in seconds.
const _millisecondsPerSecond = 1000;

/// `exit_time - entry_time` in seconds, or NULL when either endpoint is
/// missing or the pair is not strictly increasing.
///
/// Mirrors the guard `Dive.effectiveRuntime` applies before trusting the
/// computed value: a zero or negative span means the timestamps are unusable,
/// not that the dive lasted no time. The CAST truncates toward zero to match
/// Dart's `Duration.inSeconds`; both operands are `IntColumn`s, so SQLite's
/// `/` is already integer division and the CAST states that rather than
/// changing it.
String timestampRuntimeSecondsSql(String alias) =>
    'CASE WHEN $alias.entry_time IS NOT NULL '
    'AND $alias.exit_time IS NOT NULL '
    'AND $alias.exit_time > $alias.entry_time '
    'THEN CAST(($alias.exit_time - $alias.entry_time) '
    '/ $_millisecondsPerSecond AS INTEGER) '
    'END';

/// The span of the dive's profile samples in seconds, or NULL when it has no
/// samples or they all share one timestamp. Read from the series summaries
/// (`start_timestamp` / `end_timestamp`) over every series row of the dive,
/// primary and demoted alike, the span the retired row-per-sample read
/// produced (it had no `is_primary` filter either).
///
/// Mirrors `Dive.calculateRuntimeFromProfile`, which returns null unless the
/// span is positive; `NULLIF(..., 0)` is what carries that rule into SQL.
String profileSpanSecondsSql(String alias) =>
    'NULLIF((SELECT MAX(s.end_timestamp) - MIN(s.start_timestamp) '
    'FROM dive_profile_series s WHERE s.dive_id = $alias.id), 0)';

/// The first three steps of the chain: a duration the dive actually
/// measured, in seconds, or NULL. Bottom time is left out because it is
/// derived from a depth threshold, so Insights' runtime (issue #3059) never
/// reports one as a runtime.
///
/// `COALESCE` short-circuits in SQLite, so the correlated profile subquery is
/// only executed for the dives that actually reach that step. A dive with an
/// explicit `runtime` never touches `dive_profile_series`, which is what keeps this
/// usable in aggregates that scan the whole dive table.
String measuredRuntimeSecondsSql(String alias) =>
    'COALESCE('
    '$alias.runtime, '
    '${timestampRuntimeSecondsSql(alias)}, '
    '${profileSpanSecondsSql(alias)})';

/// The whole `Dive.effectiveRuntime` chain as one scalar expression, in
/// seconds, NULL only for a dive that carries no duration in any form: the
/// [measuredRuntimeSecondsSql] steps, then `bottom_time`.
String effectiveRuntimeSecondsSql(String alias) =>
    'COALESCE(${measuredRuntimeSecondsSql(alias)}, $alias.bottom_time)';

/// When the dive started, in epoch milliseconds: `entry_time`, else the dive
/// date.
String diveStartMillisSql(String alias) =>
    'COALESCE($alias.entry_time, $alias.dive_date_time)';

/// When the dive ended, in epoch milliseconds, or NULL when that is unknown.
///
/// The stored `exit_time` when it is after the start; otherwise the start
/// plus [effectiveRuntimeSecondsSql]. NULL only for a dive with neither a
/// usable exit time nor a duration in any form (issue #3340).
String diveExitMillisSql(String alias) {
  final start = diveStartMillisSql(alias);
  return 'CASE WHEN $alias.exit_time > $start THEN $alias.exit_time '
      'ELSE $start + ${effectiveRuntimeSecondsSql(alias)} '
      '* $_millisecondsPerSecond END';
}

/// The alias the previous dive takes inside [diveSurfaceIntervalSecondsSql],
/// exposed so a caller's `previousScope` can name it.
const kSurfaceIntervalPreviousAlias = 'si_prev';

/// A dive's surface interval in whole seconds (#2984): ONE definition for
/// the dive table, the `surfaceInterval` query field and Insights.
///
/// The stored `surface_interval_seconds` wins. Otherwise it is the gap from
/// the previous dive's exit to this dive's start, where "previous" is what
/// `DiveRepository.getPreviousDiveTimes` picks for the detail page: any
/// diver, the dive whose `entry_time` is latest before this dive's start
/// (ties by `dive_date_time`), and only when no such dive exists, the
/// latest dive with no `entry_time` whose `dive_date_time` is before it.
/// That ranking is spelled as two subqueries so each is an index range seek
/// on `idx_dives_entry_date` rather than a scan of `dives` per row.
///
/// The previous dive's exit is its `exit_time`, else its start plus
/// [effectiveRuntimeSecondsSql]. A negative gap (overlapping dives) is
/// zero, matching `getSurfaceInterval`; the first dive is NULL. The CAST
/// truncates, like `Duration.inSeconds`.
///
/// [previousScope] is appended to both subqueries' WHERE clauses and must
/// lead with ` AND `; it names the previous dive as
/// [kSurfaceIntervalPreviousAlias].
String diveSurfaceIntervalSecondsSql(
  String alias, {
  String previousScope = '',
}) {
  const p = kSurfaceIntervalPreviousAlias;
  final start = 'COALESCE($alias.entry_time, $alias.dive_date_time)';
  final previousExit =
      'COALESCE($p.exit_time, COALESCE($p.entry_time, $p.dive_date_time) '
      '+ COALESCE(${effectiveRuntimeSecondsSql(p)}, 0) '
      '* $_millisecondsPerSecond)';
  String gap(String where, String order) =>
      '(SELECT MAX(0, CAST(($start - $previousExit) '
      '/ $_millisecondsPerSecond AS INTEGER)) '
      'FROM dives $p WHERE $p.id != $alias.id AND $where$previousScope '
      'ORDER BY $order LIMIT 1)';
  final withEntry = gap(
    '$p.entry_time < $start',
    '$p.entry_time DESC, $p.dive_date_time DESC',
  );
  final withoutEntry = gap(
    '$p.entry_time IS NULL AND $p.dive_date_time < $start',
    '$p.dive_date_time DESC',
  );
  return 'COALESCE($alias.surface_interval_seconds, $withEntry, '
      '$withoutEntry)';
}
