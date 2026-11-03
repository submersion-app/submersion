import 'package:drift/drift.dart';

import 'package:submersion/core/database/table_columns.dart';

/// Recomputes the whole-dive summaries of a combined dive from its segments'
/// data sources (v340, issue #4136), and returns how many dives it rewrote.
///
/// A Combine copied the water temperature, the CNS at the end and the OTU from
/// the first segment that had one, so the combined dive reported its first
/// segment alone. The segments' own values survive on the source rows a
/// Combine carries, so each can be put right: the water temperature is the
/// coldest segment's (every importer stores the minimum), the CNS is the last
/// segment's, and the OTU is the sum of the segments' doses. The loop O2
/// summaries have no copy on the source rows and are left as they are.
///
/// A dive qualifies by the shape a Combine leaves, the one the v184 rung read
/// (#1451): two or more source rows, none primary, every one carrying its
/// merge slot, no clock offset, and spans that do not overlap. Overlapping
/// spans mean two computers recorded the same minutes, where a sum would
/// count the dose twice.
///
/// Only segments with a source row count. A segment logged by hand carries
/// none, so a dive combined with one is repaired from its downloaded
/// segments: closer than the first segment alone, though a fresh Combine
/// would also weigh the hand-logged one.
///
/// A column is rewritten only while it still holds the first segment's value,
/// which is what a Combine wrote. A diver's own edit, or a value a fixed
/// Combine already wrote, no longer matches it, so the repair never touches
/// either and a second run finds nothing to do.
///
/// Cheap enough to run again after every inbound sync apply, which is how a
/// dive combined on a peer below v340, or held in a sync store written before
/// it, gets the same repair. The sync stamp (`updated_at`, `hlc`) does not
/// move: every device runs this same rewrite, so they agree without a sync
/// round.
///
/// Raw SQL, as the other ladder helpers, so it keeps compiling against any
/// later shape of the generated classes. Guarded on the columns it reads, for
/// migration fixtures that build only part of the schema.
Future<int> repairCombinedDiveSummaries(DatabaseConnectionUser db) async {
  final sourceColumns = await tableColumnNames(db, 'dive_data_sources');
  final diveColumns = await tableColumnNames(db, 'dives');
  if (!sourceColumns.containsAll(const {
        'dive_id',
        'is_primary',
        'merge_source_slot',
        'time_offset_seconds',
        'entry_time',
        'exit_time',
        'water_temp',
        'cns',
        'otu',
      }) ||
      !diveColumns.containsAll(const {'water_temp', 'cns_end', 'otu'})) {
    return 0;
  }

  final rows = await db.customSelect('''
    SELECT s.dive_id, s.water_temp, s.cns, s.otu,
           d.water_temp AS dive_water_temp, d.cns_end AS dive_cns_end,
           d.otu AS dive_otu
    FROM dive_data_sources s
    JOIN dives d ON d.id = s.dive_id
    WHERE s.dive_id IN (
      SELECT dive_id FROM dive_data_sources
      GROUP BY dive_id
      HAVING COUNT(*) >= 2
         AND SUM(CASE WHEN is_primary THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN merge_source_slot IS NULL THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN entry_time IS NULL OR exit_time IS NULL
                      THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN COALESCE(time_offset_seconds, 0) <> 0
                      THEN 1 ELSE 0 END) = 0
    )
    AND s.dive_id NOT IN (
      SELECT a.dive_id FROM dive_data_sources a
      JOIN dive_data_sources b ON b.dive_id = a.dive_id AND b.id <> a.id
      WHERE a.entry_time < b.exit_time AND b.entry_time < a.exit_time
    )
    ORDER BY s.dive_id, s.entry_time, s.id
  ''').get();

  final byDive = <String, List<QueryRow>>{};
  for (final row in rows) {
    (byDive[row.read<String>('dive_id')] ??= <QueryRow>[]).add(row);
  }

  var rewritten = 0;
  for (final entry in byDive.entries) {
    final segments = entry.value;
    final dive = segments.first;
    final repair = _CombinedSummaryRepair(segments);
    final waterTemp = repair.waterTemp(
      dive.readNullable<double>('dive_water_temp'),
    );
    final cnsEnd = repair.cnsEnd(dive.readNullable<double>('dive_cns_end'));
    final otu = repair.otu(dive.readNullable<double>('dive_otu'));
    if (waterTemp == null && cnsEnd == null && otu == null) continue;
    await db.customUpdate(
      'UPDATE dives SET '
      'water_temp = COALESCE(?, water_temp), '
      'cns_end = COALESCE(?, cns_end), '
      'otu = COALESCE(?, otu) '
      'WHERE id = ?',
      variables: [
        Variable<double>(waterTemp),
        Variable<double>(cnsEnd),
        Variable<double>(otu),
        Variable<String>(entry.key),
      ],
    );
    rewritten++;
  }
  return rewritten;
}

/// One combined dive's segments in chronological order, and the corrected
/// value of each summary column, or null where the column keeps its value.
class _CombinedSummaryRepair {
  _CombinedSummaryRepair(List<QueryRow> segments)
    : _waterTemps = _values(segments, 'water_temp'),
      _cns = _values(segments, 'cns'),
      _otu = _values(segments, 'otu');

  final List<double> _waterTemps;
  final List<double> _cns;
  final List<double> _otu;

  static List<double> _values(List<QueryRow> segments, String column) => [
    for (final s in segments) ?s.readNullable<double>(column),
  ];

  /// The coldest segment's, where the dive still holds the first segment's.
  double? waterTemp(double? stored) {
    if (!_heldFirst(stored, _waterTemps)) return null;
    final coldest = _waterTemps.reduce((a, b) => a < b ? a : b);
    return coldest < stored! ? coldest : null;
  }

  /// The last segment's, where the dive still holds the first segment's.
  double? cnsEnd(double? stored) {
    if (!_heldFirst(stored, _cns)) return null;
    return _same(_cns.last, stored!) ? null : _cns.last;
  }

  /// The segments' sum, where the dive still holds the first segment's.
  double? otu(double? stored) {
    if (_otu.length < 2 || !_heldFirst(stored, _otu)) return null;
    final total = _otu.reduce((a, b) => a + b);
    return _same(total, stored!) ? null : total;
  }

  static bool _heldFirst(double? stored, List<double> values) =>
      stored != null && values.isNotEmpty && _same(stored, values.first);

  static bool _same(double a, double b) => (a - b).abs() < 1e-9;
}
