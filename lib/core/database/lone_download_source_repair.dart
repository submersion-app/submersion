import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/table_columns.dart';

/// How far a dive's runtime may differ from its one source's own recording
/// and still be that recording alone: a dive log rounds, a download does not.
const loneDownloadRuntimeSlackSeconds = 60;

/// Whether a dive whose only source row is [source] is that recording alone,
/// not a Combine that carried it (issue #4847).
///
/// A Combine of a download with a hand-logged dive carries one row, written
/// non-primary with a merge slot, so the row count cannot tell it from a lone
/// download that lost its primary flag. The runtime can: a Combine is
/// sequential, its segments spans apart, and the merged dive runs from the
/// first segment's entry to the last one's exit, so it always outlasts any
/// one segment by at least the gap and the other segment.
///
/// The recording's span is the row's `duration` (its runtime), else its exit
/// minus its entry. Either side unknown answers false, which keeps the dive
/// treated as combined: a re-parse stays refused, the safe direction. So does
/// a runtime far shorter than the recording: no Combine writes that, but the
/// row then evidently does not describe this dive as it stands.
///
/// The row's samples must also sit on its own clock: [earliestOwnSample],
/// the first timestamp of a series the row owns, within the slack of zero,
/// or null when it owns none. A row that is not the dive's first stretch was
/// shifted by the Combine, and an Uncombine leaves it shifted on the dive it
/// keeps when a hand-logged stretch (which has no row) came first, while it
/// resets that dive's runtime to the row's own span. A re-parse there would
/// move the samples back to zero.
bool loneDownloadSpansDive({
  required int? diveRuntime,
  required DiveDataSourcesData source,
  int? earliestOwnSample,
}) {
  final entry = source.entryTime;
  final exit = source.exitTime;
  final span =
      source.duration ??
      (entry != null && exit != null ? exit.difference(entry).inSeconds : null);
  if (diveRuntime == null || span == null || span <= 0) return false;
  if (earliestOwnSample != null &&
      earliestOwnSample.abs() > loneDownloadRuntimeSlackSeconds) {
    return false;
  }
  return (diveRuntime - span).abs() <= loneDownloadRuntimeSlackSeconds;
}

/// [loneDownloadSpansDive] for the dive's one row [source], reading the
/// dive's runtime and the start of the samples the row owns.
Future<bool> isLoneDownload(AppDatabase db, DiveDataSourcesData source) async =>
    loneDownloadSpansDive(
      diveRuntime: await diveRuntimeOf(db, source.diveId),
      source: source,
      earliestOwnSample: await _earliestOwnSampleOf(db, source.id),
    );

/// The first timestamp of any series [sourceId] owns, or null when it owns
/// none or a partial migration fixture lacks the columns.
Future<int?> _earliestOwnSampleOf(AppDatabase db, String sourceId) async {
  final columns = await tableColumnNames(db, 'dive_profile_series');
  if (!columns.containsAll(const {'source_id', 'start_timestamp'})) {
    return null;
  }
  final row = await db
      .customSelect(
        'SELECT MIN(start_timestamp) AS start FROM dive_profile_series '
        'WHERE source_id = ?',
        variables: [Variable<String>(sourceId)],
      )
      .getSingle();
  return row.read<int?>('start');
}

/// The dive's `runtime`, or null when it has none or the column is missing
/// from a partial migration fixture.
Future<int?> diveRuntimeOf(AppDatabase db, String diveId) async {
  final row = await db
      .customSelect(
        'SELECT runtime FROM dives WHERE id = ?',
        variables: [Variable<String>(diveId)],
      )
      .getSingleOrNull();
  return row?.read<int?>('runtime');
}

/// Makes the one source row of a lone download primary again and clears its
/// merge slot (v380, issue #4847), and returns how many dives it repaired.
///
/// The v356 stamp took every dive with no primary row for a combined one,
/// however many rows it had, so a lone download that was not primary (how
/// one came to be so can no longer be told) got a slot, and the slot refused
/// its re-parse for good ([sourceOwnsProfileStrand]), even once the diver
/// made it primary again. The dive kept the coarser profile the v182 pack
/// had written while the source's raw data could not replace it.
///
/// A dive qualifies when it has exactly one source row, not primary, its
/// runtime fits that row's own recording and the row's samples sit on its own
/// clock ([loneDownloadSpansDive]). Besides a lone download, that takes in
/// the dive an Uncombine keeps when its first stretch was that row: an
/// Uncombine leaves the kept row's flag and slot as the Combine wrote them,
/// but the first stretch sat at zero on the combined timeline, so a re-parse
/// puts its samples where they already are. The repair makes the row
/// primary, as a fresh import does, so the next re-parse rewrites the dive
/// and its profile from the raw data.
///
/// Runs again after an inbound sync apply, as the v356 stamp does: a peer
/// below v380, or a sync store written before it, still holds the old shape.
/// The sync stamp (`hlc`) does not move, since every device runs this same
/// repair. The rewritten columns are deliberately not declared in
/// `changeLogRewrittenColumns`: `is_primary` is never null, so declaring it
/// would refuse restoring every source row deleted before v380. [diveIds]
/// limits it to the dives a payload touched; null sweeps the library. Guarded
/// on the columns it reads, for migration fixtures that build only part of
/// the schema.
Future<int> repairLoneDownloadSources(
  AppDatabase db, {
  Iterable<String>? diveIds,
}) async {
  final sourceColumns = await tableColumnNames(db, 'dive_data_sources');
  final diveColumns = await tableColumnNames(db, 'dives');
  if (!sourceColumns.containsAll(const {
        'id',
        'dive_id',
        'is_primary',
        'merge_source_slot',
        'duration',
        'entry_time',
        'exit_time',
      }) ||
      !diveColumns.contains('runtime')) {
    return 0;
  }

  if (diveIds == null) return _repairDives(db, null);
  final ids = diveIds.toSet().toList();
  var repaired = 0;
  // Chunked well below SQLite's bound-variable limit: one payload can carry
  // a whole library.
  for (var i = 0; i < ids.length; i += _idChunk) {
    final end = i + _idChunk < ids.length ? i + _idChunk : ids.length;
    repaired += await _repairDives(db, ids.sublist(i, end));
  }
  return repaired;
}

const _idChunk = 500;

Future<int> _repairDives(AppDatabase db, List<String>? ids) async {
  final scoped = ids == null
      ? ''
      : 'WHERE dive_id IN (${List.filled(ids.length, '?').join(', ')})';
  final candidates = await db
      .customSelect(
        'SELECT dive_id FROM dive_data_sources $scoped '
        'GROUP BY dive_id '
        'HAVING COUNT(*) = 1 '
        '   AND SUM(CASE WHEN is_primary THEN 1 ELSE 0 END) = 0',
        variables: [
          if (ids != null)
            for (final id in ids) Variable<String>(id),
        ],
      )
      .get();

  var repaired = 0;
  for (final candidate in candidates) {
    final diveId = candidate.read<String>('dive_id');
    final row = await db
        .customSelect(
          'SELECT * FROM dive_data_sources WHERE dive_id = ?',
          variables: [Variable<String>(diveId)],
        )
        .getSingle();
    final source = db.diveDataSources.map(row.data);
    if (!await isLoneDownload(db, source)) continue;
    await db.customUpdate(
      'UPDATE dive_data_sources SET is_primary = 1, merge_source_slot = NULL '
      'WHERE id = ?',
      variables: [Variable<String>(source.id)],
    );
    repaired++;
  }
  return repaired;
}
