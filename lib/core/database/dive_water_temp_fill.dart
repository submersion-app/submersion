import 'package:drift/drift.dart';

import 'package:submersion/core/database/table_columns.dart';

/// Fills an empty `dives.water_temp` from the dive's source rows (v349, issue
/// #4333), and returns how many dives it filled.
///
/// A download stored the water temperature it measured on its
/// `dive_data_sources` row only, so the dive's own column stayed empty. The
/// detail page fills it from the profile when it reads the dive, but the query
/// field, the dive table, the summaries and the agent's documents read the
/// column, so a downloaded dive had no water temperature there.
///
/// The value is the primary source's, as the dive's profile is the primary
/// reading's. A dive whose primary reading has none (a computer with no
/// temperature sensor, or a Combine, whose segments are none of them primary)
/// takes the coldest of its other sources, since every importer stores the
/// minimum it saw. A value outside [-3, 45] °C is a sensor glitch and is left
/// on the source row, the window an agent's write of the column accepts.
///
/// Only an empty column is filled: a temperature the diver entered, or one a
/// re-parse wrote, is never touched, so a second run finds nothing to do and
/// a logged value from before the fill still means what it did. That is why
/// the column needs no entry in `changeLogRewrittenColumns`.
///
/// Runs after a download writes its source row, scoped to that dive, and
/// again after an inbound sync apply, which is how a dive from a peer below
/// v349, or held in a sync store written before it, gets the same fill.
/// [diveIds] limits it to the dives named; null sweeps the whole library, as
/// the rung and a base file adoption do. The sync stamp (`updated_at`, `hlc`)
/// does not move: every device runs this same fill, so they agree without a
/// sync round.
///
/// Raw SQL, as the other ladder helpers, so it keeps compiling against any
/// later shape of the generated classes. Guarded on the columns it reads, for
/// migration fixtures that build only part of the schema.
Future<int> fillDiveWaterTempsFromSources(
  DatabaseConnectionUser db, {
  Iterable<String>? diveIds,
}) async {
  final sourceColumns = await tableColumnNames(db, 'dive_data_sources');
  final diveColumns = await tableColumnNames(db, 'dives');
  if (!sourceColumns.containsAll(const {
        'dive_id',
        'is_primary',
        'water_temp',
      }) ||
      !diveColumns.contains('water_temp')) {
    return 0;
  }

  if (diveIds == null) return _fill(db, null);
  final ids = diveIds.toSet().toList();
  var filled = 0;
  // Chunked well below SQLite's bound-variable limit: one payload can carry
  // a whole library.
  for (var i = 0; i < ids.length; i += _idChunk) {
    final end = i + _idChunk < ids.length ? i + _idChunk : ids.length;
    filled += await _fill(db, ids.sublist(i, end));
  }
  return filled;
}

const _idChunk = 500;

/// A source temperature worth copying onto its dive.
const _plausible = 's.water_temp BETWEEN -3 AND 45';

/// Fills the empty dives among [ids], or every one when null.
Future<int> _fill(DatabaseConnectionUser db, List<String>? ids) {
  const sources =
      'FROM dive_data_sources s WHERE s.dive_id = dives.id AND $_plausible';
  final scoped = ids == null
      ? ''
      : ' AND id IN (${List.filled(ids.length, '?').join(', ')})';
  return db.customUpdate(
    'UPDATE dives SET water_temp = COALESCE('
    '(SELECT MIN(s.water_temp) $sources AND s.is_primary = 1), '
    '(SELECT MIN(s.water_temp) $sources)) '
    'WHERE water_temp IS NULL AND EXISTS (SELECT 1 $sources)$scoped',
    variables: [
      if (ids != null)
        for (final id in ids) Variable<String>(id),
    ],
  );
}
