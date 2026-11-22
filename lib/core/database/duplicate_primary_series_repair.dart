import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/table_columns.dart';
import 'package:submersion/features/dive_log/domain/services/profile_live_edits.dart';

/// Demotes a live profile series that duplicates its source's own over the
/// same minutes under another computer's label (v380, issue #4847), and
/// returns how many series it demoted.
///
/// The v182 pack made one series per `(computer_id, source_id, is_primary)`
/// of a dive's legacy rows. Where one profile's rows carried mixed computer
/// ids, it wrote two live series of one source over the same span, one
/// labelled with a computer the source does not name. The chart interleaves
/// every live series by time, so the two near-identical curves were zipped
/// together.
///
/// Within one source's live series, the source's own are those whose
/// computer is the source's (`IS`, so a file source's own series carries
/// none). Another live series of that source whose span lies within one of
/// theirs (give or take a minute) repeats minutes the chart already shows,
/// and is demoted, not deleted: it stays in the profile's history, its label
/// untouched. One that overlaps none is a segment of its own, the shape a
/// merge of one computer's split dive writes, and stays live. So is one that
/// overlaps but reaches past them, as a label that changed partway through a
/// profile leaves it: demoting it would hide the minutes only it holds.
///
/// Only a computer's label marks a duplicate, and only one that no source
/// row of the dive names. A live series with no computer beside the
/// recording is the diver's edit, as a re-parse reads it, even with no
/// demoted generation beneath it. A computer with a row of its own on the
/// dive recorded those minutes itself: a Combine re-points a pre-v154 series
/// with no source at its segment's owner, so a second computer's series can
/// carry the first one's source. A source is left alone when it has no own
/// series, or two of them overlap (nothing tells which is right), or any of
/// its live series is a manual edit, marked or by shape
/// ([profileLiveEditIds]): an edit is the diver's choice
/// of samples.
///
/// Runs again after an inbound sync apply, as the v356 stamp does; the sync
/// stamp (`hlc`) does not move, since every device runs this same repair. A
/// demoted series' `updated_at` goes up by one, which moves the stamp the
/// device-local caches key on (`diveSourceStampSql`) without moving the HLC
/// sync exports by.
///
/// `is_primary` is deliberately not declared in `changeLogRewrittenColumns`:
/// it is never null, so declaring it would refuse restoring every series
/// deleted before v380. [diveIds] limits it to the dives a payload touched;
/// null sweeps the library. Guarded on the columns it reads, for migration
/// fixtures that build only part of the schema.
Future<int> demoteDuplicatePrimarySeries(
  AppDatabase db, {
  Iterable<String>? diveIds,
}) async {
  final seriesColumns = await tableColumnNames(db, 'dive_profile_series');
  final sourceColumns = await tableColumnNames(db, 'dive_data_sources');
  if (!seriesColumns.containsAll(const {
        'id',
        'dive_id',
        'computer_id',
        'source_id',
        'is_primary',
        'is_edit',
        'start_timestamp',
        'end_timestamp',
      }) ||
      !sourceColumns.containsAll(const {'id', 'computer_id'})) {
    return 0;
  }

  if (diveIds == null) return _repairDives(db, null);
  final ids = diveIds.toSet().toList();
  var demoted = 0;
  // Chunked well below SQLite's bound-variable limit: one payload can carry
  // a whole library.
  for (var i = 0; i < ids.length; i += _idChunk) {
    final end = i + _idChunk < ids.length ? i + _idChunk : ids.length;
    demoted += await _repairDives(db, ids.sublist(i, end));
  }
  return demoted;
}

const _idChunk = 500;

/// One series, as much as the repair reads of it.
typedef _Series = ({ProfileSeriesIdentity identity, int start, int end});

Future<int> _repairDives(AppDatabase db, List<String>? ids) async {
  final scoped = ids == null
      ? ''
      : 'AND a.dive_id IN (${List.filled(ids.length, '?').join(', ')})';
  // Dives where one source holds two live series that overlap in time: the
  // only ones the repair can change. Self-join on the summary columns, so no
  // blob is read.
  final dives = await db
      .customSelect(
        'SELECT DISTINCT a.dive_id FROM dive_profile_series a '
        'JOIN dive_profile_series b ON b.dive_id = a.dive_id '
        '  AND b.source_id = a.source_id AND b.id > a.id '
        'WHERE a.is_primary AND b.is_primary '
        '  AND a.start_timestamp <= b.end_timestamp '
        '  AND b.start_timestamp <= a.end_timestamp '
        '  $scoped',
        variables: [
          if (ids != null)
            for (final id in ids) Variable<String>(id),
        ],
      )
      .get();

  var demoted = 0;
  for (final dive in dives) {
    final diveId = dive.read<String>('dive_id');
    final rows = await db
        .customSelect(
          'SELECT s.id, s.computer_id, s.source_id, s.is_primary, s.is_edit, '
          's.start_timestamp, s.end_timestamp, '
          'd.computer_id AS source_computer_id '
          'FROM dive_profile_series s '
          'LEFT JOIN dive_data_sources d ON d.id = s.source_id '
          'WHERE s.dive_id = ?',
          variables: [Variable<String>(diveId)],
        )
        .get();
    final series = <_Series>[
      for (final r in rows)
        (
          identity: (
            id: r.read<String>('id'),
            computerId: r.read<String?>('computer_id'),
            sourceId: r.read<String?>('source_id'),
            isPrimary: r.read<bool>('is_primary'),
            isEdit: r.read<bool?>('is_edit'),
          ),
          start: r.read<int>('start_timestamp'),
          end: r.read<int>('end_timestamp'),
        ),
    ];
    final sourceComputer = <String, String?>{
      for (final r in rows)
        ?r.read<String?>('source_id'): r.read<String?>('source_computer_id'),
    };
    final computersWithSource = <String>{
      for (final r
          in await db
              .customSelect(
                'SELECT computer_id FROM dive_data_sources '
                'WHERE dive_id = ? AND computer_id IS NOT NULL',
                variables: [Variable<String>(diveId)],
              )
              .get())
        r.read<String>('computer_id'),
    };
    final edits = profileLiveEditIds([for (final s in series) s.identity]);

    for (final MapEntry(key: sourceId, value: computerId)
        in sourceComputer.entries) {
      final live = [
        for (final s in series)
          if (s.identity.sourceId == sourceId && s.identity.isPrimary) s,
      ];
      if (live.any((s) => edits.contains(s.identity.id))) continue;
      final own = [
        for (final s in live)
          if (s.identity.computerId == computerId) s,
      ];
      if (own.isEmpty || _anyOverlap(own)) continue;
      for (final s in live) {
        final label = s.identity.computerId;
        // No computer beside the recording is the diver's edit, as a
        // re-parse reads it (`ReparseService._keptEdits`), even with no
        // demoted generation beneath it to give it away by shape.
        if (label == null || label == computerId) continue;
        if (computersWithSource.contains(label)) continue;
        if (!own.any((o) => _contains(o, s))) continue;
        // One more on updated_at moves the stamp the device-local caches
        // key on (diveSourceStampSql), so the dive's metrics are rebuilt
        // from the profile it now shows. Sync exports by the HLC, which
        // stays where it was.
        await db.customUpdate(
          'UPDATE dive_profile_series '
          'SET is_primary = 0, updated_at = updated_at + 1 WHERE id = ?',
          variables: [Variable<String>(s.identity.id)],
        );
        demoted++;
      }
    }
  }
  return demoted;
}

bool _overlaps(_Series a, _Series b) => a.start <= b.end && b.start <= a.end;

/// How far a duplicate may run past the series it repeats: two copies of one
/// recording can differ by a sample at either end.
const _spanSlackSeconds = 60;

/// Whether [inner]'s span lies within [outer]'s, give or take the slack.
bool _contains(_Series outer, _Series inner) =>
    inner.start >= outer.start - _spanSlackSeconds &&
    inner.end <= outer.end + _spanSlackSeconds;

bool _anyOverlap(List<_Series> series) {
  for (var i = 0; i < series.length; i++) {
    for (var j = i + 1; j < series.length; j++) {
      if (_overlaps(series[i], series[j])) return true;
    }
  }
  return false;
}
