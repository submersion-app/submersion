import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/table_columns.dart';
import 'package:submersion/features/dive_log/data/services/data_source_strand.dart';

/// Stamps a merge slot on the source rows of a dive that has no primary row
/// and no slot yet (v356, issue #4367), and returns how many dives it
/// stamped.
///
/// A Combine writes every carried row non-primary, and since v184 it stamps
/// each row's slot as well. The v184 rung gave the dives combined before it
/// a slot only where it could tell them by shape: two or more rows, every
/// one with an entry and an exit time, no clock offset, spans apart. The
/// rest, a download combined with a hand-logged dive among them, kept none.
///
/// The slot is what keeps a re-parse off a carried row
/// ([sourceOwnsProfileStrand]): the Combine re-based its samples and kept no
/// record of the shift, so a re-parse would put them back at the download's
/// own timestamps. A dive with no primary row is refused for that alone, but
/// consolidating it with another import gives it a primary row, and an
/// unslotted row then re-parsed. Stamping it here keeps the refusal through
/// that.
///
/// A dive qualifies while it has no primary row and none of its rows has a
/// slot. That is the shape the re-parse already refuses today, so the stamp
/// changes nothing a re-parse does until a primary row arrives. A row a
/// Combine stamped, or the v184 rung, or this one, leaves its dive out, so a
/// second run finds nothing to do.
///
/// Slots are numbered per display strand ([dataSourceStrandKeysById]), the
/// way an Uncombine numbers a segment's rows, so the dive shows the same
/// sources after the stamp as before it. A slot only groups rows with no
/// computer; one shared by every row would fold two computers' recordings
/// of the same minutes into one source (issue #543).
///
/// Runs again after an inbound sync apply, which is how a dive from a peer
/// below v356, or held in a sync store written before it, gets the same
/// stamp. [diveIds] limits it to the dives a payload touched; null sweeps
/// the whole library, as the rung and a base file adoption do. The sync
/// stamp (`hlc`) does not move: every device runs this same stamp, so they
/// agree without a sync round. It fills empty slots and rewrites none, so
/// the column needs no entry in `changeLogRewrittenColumns`.
///
/// The dive's rows are selected in raw SQL, as the other ladder helpers do,
/// and handed to the strand rule through the table's own mapping, so the
/// rung and the display can never disagree on a strand. The mapping leaves a
/// nullable column it does not find empty; a later rung that adds a required
/// column to this table has to keep that true at v356. Guarded on the
/// columns it reads, for migration fixtures that build only part of the
/// schema.
Future<int> stampCombinedDiveSourceSlots(
  AppDatabase db, {
  Iterable<String>? diveIds,
}) async {
  final columns = await tableColumnNames(db, 'dive_data_sources');
  if (!columns.containsAll(const {
    'id',
    'dive_id',
    'is_primary',
    'merge_source_slot',
    'created_at',
  })) {
    return 0;
  }

  if (diveIds == null) return _stampDives(db, null);
  final ids = diveIds.toSet().toList();
  var stamped = 0;
  // Chunked well below SQLite's bound-variable limit: one payload can carry
  // a whole library.
  for (var i = 0; i < ids.length; i += _idChunk) {
    final end = i + _idChunk < ids.length ? i + _idChunk : ids.length;
    stamped += await _stampDives(db, ids.sublist(i, end));
  }
  return stamped;
}

const _idChunk = 500;

/// Stamps the qualifying dives among [ids], or every one when null.
Future<int> _stampDives(AppDatabase db, List<String>? ids) async {
  final scoped = ids == null
      ? ''
      : 'WHERE dive_id IN (${List.filled(ids.length, '?').join(', ')})';
  final dives = await db
      .customSelect(
        'SELECT dive_id FROM dive_data_sources $scoped '
        'GROUP BY dive_id '
        'HAVING SUM(CASE WHEN is_primary THEN 1 ELSE 0 END) = 0 '
        '   AND SUM(CASE WHEN merge_source_slot IS NULL '
        '                THEN 0 ELSE 1 END) = 0',
        variables: [
          if (ids != null)
            for (final id in ids) Variable<String>(id),
        ],
      )
      .get();

  for (final dive in dives) {
    // Shown order, which decides the row that speaks for each strand.
    final rows = await db
        .customSelect(
          'SELECT * FROM dive_data_sources WHERE dive_id = ? '
          'ORDER BY is_primary DESC, created_at ASC, id ASC',
          variables: [Variable<String>(dive.read<String>('dive_id'))],
        )
        .get();
    final sources = [for (final r in rows) db.diveDataSources.map(r.data)];
    final strandOf = dataSourceStrandKeysById(sources);
    final slotByStrand = <String, int>{};
    for (final source in sources) {
      final slot = slotByStrand.putIfAbsent(
        strandOf[source.id]!,
        () => slotByStrand.length,
      );
      await db.customUpdate(
        'UPDATE dive_data_sources SET merge_source_slot = ? '
        'WHERE id = ? AND merge_source_slot IS NULL',
        variables: [Variable<int>(slot), Variable<String>(source.id)],
      );
    }
  }
  return dives.length;
}
