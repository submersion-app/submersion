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

/// The whole `Dive.effectiveRuntime` chain as one scalar expression, in
/// seconds, NULL only for a dive that carries no duration in any form.
///
/// `COALESCE` short-circuits in SQLite, so the correlated profile subquery is
/// only executed for the dives that actually reach that step. A dive with an
/// explicit `runtime` never touches `dive_profile_series`, which is what keeps this
/// usable in aggregates that scan the whole dive table.
String effectiveRuntimeSecondsSql(String alias) =>
    'COALESCE('
    '$alias.runtime, '
    '${timestampRuntimeSecondsSql(alias)}, '
    '${profileSpanSecondsSql(alias)}, '
    '$alias.bottom_time)';
