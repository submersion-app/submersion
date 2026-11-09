/// SQL spellings of `Dive.measuredRuntime` and `Dive.effectiveRuntime`, for
/// queries that must read dive durations without hydrating `Dive` object
/// graphs.
///
/// The measured chain has three steps, in order: the explicit `runtime`, then
/// `exit_time - entry_time`, then the span of the dive's profile samples. A
/// dive downloaded from a computer often carries no explicit `runtime` at all
/// and is only measurable through its profile, so a query that reads the
/// column alone misses it.
///
/// Anything reported as a duration (totals, records, charts, SAC) reads
/// [measuredRuntimeSecondsSql]: bottom time is derived from a depth threshold,
/// so it never counts as runtime (issue #3304). [effectiveRuntimeSecondsSql]
/// adds it as a fourth step, as an estimate of when a dive ended for a time
/// window.
///
/// The fragments live here, in one file, so the aggregates cannot drift into
/// two different answers for the same dive. Callers pass the table alias
/// their statement uses for `dives`.
library;

import 'package:submersion/core/database/dive_source_stamp.dart';

/// `entry_time` and `exit_time` are epoch milliseconds; `runtime` and
/// `bottom_time` are already stored in seconds.
const _millisecondsPerSecond = 1000;

/// `exit_time - entry_time` in seconds, or NULL when either endpoint is
/// missing or the pair is not strictly increasing.
///
/// Mirrors the guard `Dive.measuredRuntime` applies before trusting the
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
/// (`start_timestamp` / `end_timestamp`) over the series the merged profile
/// read (`DiveRepository.getMergedProfile`, which hydrates `Dive.profile`)
/// keeps, so Insights and a hydrated dive agree on how long the dive lasted
/// (issue #3537).
///
/// That read keeps primary and demoted series alike, minus two kinds of
/// demoted row: an inactive child revision (a history row with a parent),
/// and, once a saved edit is primary, the superseded originals of the edited
/// family (`dropSupersededSeries`). Family membership follows that rule: a
/// series with no computer, every series of a dive with no data sources, or
/// one on the computer of the dive's first source in shown order (primary
/// first, then oldest).
///
/// One case stays apart: a series whose packed blob fails to decode is
/// skipped by the Dart read but still counted here, because SQL reads only
/// the summary columns and cannot tell a corrupt blob. Every table this
/// reads is one `watchInsightsChanges` already watches, or, for the history
/// table, is only written alongside a `dive_profile_series` row.
///
/// Mirrors `Dive.calculateRuntimeFromProfile`, which returns null unless the
/// span is positive; `NULLIF(..., 0)` is what carries that rule into SQL.
String profileSpanSecondsSql(String alias) =>
    'NULLIF((SELECT MAX(s.end_timestamp) - MIN(s.start_timestamp) '
    'FROM dive_profile_series s WHERE s.dive_id = $alias.id '
    'AND s.sample_count > 0 '
    'AND NOT (s.is_primary = 0 AND ('
    '${_inactiveChildRevisionSql('s')} OR ${_supersededOriginalSql('s')}'
    '))), 0)';

/// Whether demoted series [s] is an earlier revision of an edit: the merged
/// read hides it rather than drawing it beside the active one.
String _inactiveChildRevisionSql(String s) =>
    'EXISTS (SELECT 1 FROM dive_profile_series_history h '
    'WHERE h.series_id = $s.id AND h.dive_id = $s.dive_id '
    'AND h.parent_series_id IS NOT NULL)';

/// Whether demoted series [s] belongs to the family a primary saved edit (a
/// primary series with no computer) supersedes.
String _supersededOriginalSql(String s) {
  const sources = 'dive_data_sources ds WHERE ds.dive_id';
  return '(EXISTS (SELECT 1 FROM dive_profile_series e '
      'WHERE e.dive_id = $s.dive_id AND e.is_primary = 1 '
      'AND e.computer_id IS NULL) '
      'AND ($s.computer_id IS NULL '
      'OR NOT EXISTS (SELECT 1 FROM $sources = $s.dive_id) '
      'OR $s.computer_id = (SELECT ds.computer_id FROM $sources = $s.dive_id '
      'ORDER BY ds.is_primary DESC, ds.created_at ASC, ds.rowid ASC '
      'LIMIT 1)))';
}

/// A duration the dive actually measured, in seconds, or NULL: the form of
/// `Dive.measuredRuntime` that every report of a dive's length reads. Bottom
/// time is left out because it is derived from a depth threshold, so it is
/// never reported as a runtime (issues #3059, #3304).
///
/// `COALESCE` short-circuits in SQLite, so the correlated profile subquery is
/// only executed for the dives that actually reach that step. A dive with an
/// explicit `runtime` never touches `dive_profile_series`, which is what keeps this
/// usable in aggregates that scan the whole dive table.
///
/// NULL for a draft (issue #637): its times are taps at the site and any
/// runtime it holds came from the plan it adopted, so neither is a reading
/// to report; [effectiveRuntimeSecondsSql] still spans its taps.
String measuredRuntimeSecondsSql(String alias) =>
    'CASE WHEN $alias.is_draft = 1 THEN NULL ELSE COALESCE('
    '$alias.runtime, '
    '${timestampRuntimeSecondsSql(alias)}, '
    '${profileSpanSecondsSql(alias)}) END';

/// What [measuredRuntimeSecondsSql] reads beyond the dive row, by SQL name:
/// the tables a query or a tick over a measured runtime has to follow. The
/// series history is left out because it is not a drift table, and it is
/// only written alongside a `dive_profile_series` row.
const Set<String> measuredRuntimeTables = {
  'dive_profile_series',
  'dive_data_sources',
};

/// The whole `Dive.effectiveRuntime` chain as one scalar expression, in
/// seconds, NULL only for a dive that carries no duration in any form: the
/// [measuredRuntimeSecondsSql] steps, then `bottom_time`. An estimate for a
/// time window, never a value to report as a runtime.
///
/// A draft's window is its taps, NULL while it is still open (issue #637).
String effectiveRuntimeSecondsSql(String alias) =>
    'CASE WHEN $alias.is_draft = 1 '
    'THEN ${timestampRuntimeSecondsSql(alias)} '
    'ELSE COALESCE(${measuredRuntimeSecondsSql(alias)}, $alias.bottom_time) '
    'END';

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

/// Whether the dive at [alias] is a plan nobody has dived, as an SQL boolean.
///
/// `is_planned` alone is not the answer. A dive mirrored to a linked buddy
/// (#2002) stays planned until that diver's own download, even though the dive
/// it was mirrored from happened, so a logged dive on the same outing makes it
/// real. Everything that reads exposure uses this, so a saved plan restricts
/// nothing and a mirrored dive restricts its diver (issue #3924).
///
/// Only a planned dive with an outing id reaches the sibling lookup, which
/// `idx_dives_outing` serves.
String diveUndivedSql(String alias) {
  const s = 'undived_sibling';
  return '($alias.is_planned = 1 AND $alias.is_draft = 0 AND '
      'NOT ($alias.outing_id IS NOT NULL AND '
      'EXISTS (SELECT 1 FROM dives $s WHERE $s.outing_id = $alias.outing_id '
      'AND $s.is_planned = 0)))';
}

/// True for a dive that waits for its dive computer readings: a plan or a
/// draft (issue #637). The one place "plan or draft" is spelled in SQL, for
/// numbering and matching, which skip both. Safety reads do NOT use it: a
/// draft happened, so no-fly and surface interval count it
/// ([diveUndivedSql]).
String diveUnfilledSql(String alias) =>
    '($alias.is_planned = 1 OR $alias.is_draft = 1)';

/// How far back a dive's residual load reads: the tissue lookback's window.
const kResidualLookback = Duration(hours: 48);

/// A version token for the dives whose load can reach the dive at [alias]:
/// the sum of [diveSourceStampSql] over the dives that start up to
/// [kResidualLookback] plus a day before it, or 0 when there are none.
///
/// A stored result computed from a dive's residual load goes stale when one of
/// those dives changes, which nothing on the dive itself can see. A token and
/// not a time, for the reasons on [diveSourceStampSql]: it moves on a profile
/// or tank that never re-stamps its dive, on a write stamped older than the
/// last, and on adding or removing a dive. Compare it only for equality.
///
/// The lookback counts surface time from an earlier dive's exit and this reads
/// starts, so the extra day keeps a long dive that ended inside the lookback.
/// Reading too far costs one recompute and never a wrong answer. This is the
/// direct lookback only: a change further back reaches this dive through the
/// dives between.
///
/// Two subqueries for the same reason as [diveSurfaceIntervalSecondsSql]: each
/// is a range seek on `idx_dives_entry_date`.
String earlierDivesRevisionSql(String alias) {
  const h = 'history_dive';
  final start = 'COALESCE($alias.entry_time, $alias.dive_date_time)';
  final window = kResidualLookback + const Duration(days: 1);
  final from = '$start - ${window.inMilliseconds}';
  String stamps(String where) =>
      'COALESCE((SELECT SUM(${diveSourceStampSql(h)}) FROM dives $h '
      'WHERE $where), 0)';
  return '(${stamps('$h.entry_time >= $from AND $h.entry_time < $start')} + '
      '${stamps('$h.entry_time IS NULL '
      'AND $h.dive_date_time >= $from AND $h.dive_date_time < $start')})';
}

/// The logged dives a downloaded dive could be, nearest in time first.
///
/// Binds the download's start, then the window's first and last millisecond,
/// then the diver when [scopedToDiver]. total_seconds is the whole
/// `Dive.effectiveRuntime` chain, because a download's duration is the
/// computer's runtime rather than the bottom time.
///
/// This runs once per downloaded dive, so the filter is a range that seeks
/// idx_dives_start or idx_dives_diver_start, not `ABS(start - ?) <= ?`, which
/// reads every dive (issue #3863).
String diveMatchCandidatesSql({required bool scopedToDiver}) {
  final start = diveStartMillisSql('dives');
  return '''
SELECT id, dive_date_time, entry_time, max_depth,
  ${effectiveRuntimeSecondsSql('dives')} AS total_seconds,
  $start AS effective_time,
  ABS($start - ?1) AS time_diff
FROM dives
WHERE $start BETWEEN ?2 AND ?3
  AND NOT ${diveUnfilledSql('dives')}
  ${scopedToDiver ? 'AND diver_id = ?4' : ''}
ORDER BY time_diff ASC
LIMIT 10
''';
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
/// on `idx_dives_entry_date` rather than a scan of `dives` per row. A plan
/// nobody has dived ([diveUndivedSql]) is skipped unless this dive is one too
/// (issue #3924).
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
  final previousExit = diveEndMillisSql(p);
  String gap(String where, String order) =>
      '(SELECT MAX(0, CAST(($start - $previousExit) '
      '/ $_millisecondsPerSecond AS INTEGER)) '
      'FROM dives $p WHERE $p.id != $alias.id AND $where '
      'AND (NOT ${diveUndivedSql(p)} OR ${diveUndivedSql(alias)})'
      '$previousScope '
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

/// When the dive at [alias] ended, in epoch milliseconds, as the planner's
/// `diveEnd` reads it: the stored `exit_time` whenever there is one, else the
/// start plus [effectiveRuntimeSecondsSql], else the start. Unlike
/// [diveExitMillisSql] it is never NULL and trusts an exit time at or before
/// the start. The previous dive's exit in [diveSurfaceIntervalSecondsSql] and
/// the Follow prompt's lookup ([latestEndedDiveSql]) both read it.
String diveEndMillisSql(String alias) =>
    'COALESCE($alias.exit_time, ${diveStartMillisSql(alias)} '
    '+ COALESCE(${effectiveRuntimeSecondsSql(alias)}, 0) '
    '* $_millisecondsPerSecond)';

/// The logged dive that ended last inside a window, for the planner's Follow
/// prompt (issue #4250): its id, or no row when no logged dive ended in it.
///
/// Binds the earliest start to read, then the window's first millisecond
/// (exclusive) and last (inclusive), then the diver when [scopedToDiver].
/// The window is on [diveEndMillisSql]; a planned dive never counts,
/// and a dive still under way or stamped in the future ends after the window.
///
/// The end has no index, so the start bounds the read: a range on it seeks
/// idx_dives_start or idx_dives_diver_start, and reads the few dives of the
/// last days rather than the whole log. The earliest start is the window's
/// first millisecond less the longest dive the lookup allows for. A dive that
/// starts after the window's last millisecond is stamped in the future and is
/// passed over, even with an exit time before its start.
String latestEndedDiveSql({required bool scopedToDiver}) {
  final start = diveStartMillisSql('dives');
  final end = diveEndMillisSql('dives');
  return '''
SELECT id, $end AS end_ms
FROM dives
WHERE $start BETWEEN ?1 AND ?3
  AND is_planned = 0
  ${scopedToDiver ? 'AND diver_id = ?4' : ''}
  AND $end > ?2 AND $end <= ?3
ORDER BY end_ms DESC, $start DESC, dive_number DESC
LIMIT 1
''';
}
