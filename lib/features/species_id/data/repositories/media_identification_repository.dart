import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/repositories/identification_sync_marks.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_bars.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/services/scanned_ranges_codec.dart';
import 'package:submersion/features/species_id/domain/services/track_path_codec.dart';

part 'media_identification_rows.dart';
part 'media_identification_tombstones.dart';

/// The logbook a transaction of [MediaIdentificationRepository] runs on,
/// and whether that transaction has ended.
typedef _Pin = ({AppDatabase db, Completer<void> ended});

/// What [MediaIdentificationRepository.storeRunAfterReading] writes.
typedef StoreRunWrite = ({
  MediaIdentificationRun run,
  List<MediaIdentification> insert,
  List<String> deleteIds,
});

/// What the marine life model found on each piece of media, and the diver's
/// decisions on it (issue #4668). Synced since v381 (issue #4876): every
/// write is published through [IdentificationSyncMarks].
class MediaIdentificationRepository {
  /// [database] fixes the logbook; otherwise [currentDatabase] (by default
  /// [DatabaseService]'s) is asked on every call. Both together are
  /// refused in every build, since one would silently win.
  ///
  /// [marks] publishes writes to sync. By default only the app's own
  /// logbook publishes: a repository given a database of its own (a test)
  /// marks nothing unless it is handed marks.
  MediaIdentificationRepository({
    AppDatabase? database,
    AppDatabase Function()? currentDatabase,
    IdentificationSyncMarks? marks,
  }) : _currentDatabase = database != null
           ? (() => database)
           : (currentDatabase ?? _openLogbook),
       _marks =
           marks ??
           (database == null && currentDatabase == null
               ? IdentificationSyncMarks()
               : null) {
    if (database != null && currentDatabase != null) {
      throw ArgumentError(
        'Give a fixed database or a way to find one, not both',
      );
    }
  }

  final AppDatabase Function() _currentDatabase;
  final IdentificationSyncMarks? _marks;

  static AppDatabase _openLogbook() => DatabaseService.instance.database;

  /// Holds, in the zone of a transaction this repository opened, the
  /// logbook that transaction runs on.
  final _pinned = Object();

  /// The open logbook, read on every call so a switch of logbook (demo
  /// mode, a restore) is followed; inside one of this repository's
  /// transactions, the logbook it began on. A callback the transaction
  /// left behind keeps its zone, so the pin holds only until it ends.
  AppDatabase get _db {
    final pin = Zone.current[_pinned] as _Pin?;
    if (pin != null && !pin.ended.isCompleted) return pin.db;
    return _currentDatabase();
  }

  /// Runs [body] in one transaction on the logbook open now. Every read
  /// and write this repository makes inside it uses that logbook, so a
  /// logbook opened meanwhile is neither read nor written (issue #4721).
  Future<T> _transaction<T>(Future<T> Function(AppDatabase db) body) async {
    final db = _db;
    final _Pin pin = (db: db, ended: Completer<void>());
    try {
      return await db.transaction(
        () => runZoned(() => body(db), zoneValues: {_pinned: pin}),
      );
    } finally {
      pin.ended.complete();
    }
  }

  /// Ticks on any write to either table.
  Stream<void> watchChanges() {
    final db = _db;
    return db.tableUpdates(
      TableUpdateQuery.onAllTables([
        db.mediaIdentificationRuns,
        db.mediaIdentifications,
      ]),
    );
  }

  /// Ticks when a photo's species tags change, or a species is edited.
  Stream<void> watchTagChanges() {
    final db = _db;
    return db.tableUpdates(
      TableUpdateQuery.onAllTables([db.mediaSpecies, db.species]),
    );
  }

  /// The species tagged on [mediaId], with their scientific names, as the
  /// rules compare them with candidates.
  Future<List<TaggedSpecies>> taggedSpecies(String mediaId) async {
    final db = _db;
    final rows = await db
        .customSelect(
          'SELECT ms.species_id AS species_id, s.scientific_name AS sci '
          'FROM media_species ms LEFT JOIN species s ON s.id = ms.species_id '
          'WHERE ms.media_id = ?',
          variables: [Variable.withString(mediaId)],
          readsFrom: {db.mediaSpecies, db.species},
        )
        .get();
    return [
      for (final row in rows)
        TaggedSpecies(
          speciesId: row.read<String>('species_id'),
          scientificName: row.readNullable<String>('sci'),
        ),
    ];
  }

  Future<MediaIdentificationRun?> runFor(String mediaId) async {
    final db = _db;
    final row = await (db.select(
      db.mediaIdentificationRuns,
    )..where((r) => r.mediaId.equals(mediaId))).getSingleOrNull();
    return row == null ? null : _runFromRow(row);
  }

  /// Oldest first, so a photo's identifications keep a stable order.
  Future<List<MediaIdentification>> forMedia(String mediaId) async {
    final db = _db;
    final rows =
        await (db.select(db.mediaIdentifications)
              ..where((r) => r.mediaId.equals(mediaId))
              ..orderBy([
                (r) => OrderingTerm.asc(r.createdAt),
                (r) => OrderingTerm.asc(r.id),
              ]))
            .get();
    return [for (final row in rows) _fromRow(row)];
  }

  /// [mediaId]'s run and its identifications, read in one transaction on
  /// one logbook so both come from the same moment: a rename that moves
  /// them on together is seen whole or not at all, and a logbook opened
  /// during the read is not mixed in (issue #4721).
  Future<(MediaIdentificationRun?, List<MediaIdentification>)> forMediaWithRun(
    String mediaId,
  ) => _transaction(
    (_) async => (await runFor(mediaId), await forMedia(mediaId)),
  );

  /// In one transaction: upserts [run], deletes [deleteIds], inserts
  /// [insert].
  Future<void> storeRun(
    MediaIdentificationRun run, {
    required List<MediaIdentification> insert,
    required List<String> deleteIds,
  }) async {
    final decided = await _transaction(
      (db) => _write(db, run, insert: insert, deleteIds: deleteIds),
    );
    await _publishStored(
      run.mediaId,
      insert: insert,
      deleteIds: deleteIds,
      decided: decided,
    );
  }

  /// [storeRun], with what to write worked out by [build] from the rows of
  /// [mediaId] as they are stored, read in the same transaction when
  /// [read] (issue #4709). A decision or claim written meanwhile waits for
  /// the transaction, so a write built from an earlier read never lands
  /// over it. Nothing is written when [build] returns null. Returns whether
  /// it wrote.
  Future<bool> storeRunAfterReading(
    String mediaId, {
    required bool read,
    required Future<StoreRunWrite?> Function(List<MediaIdentification>? current)
    build,
  }) async {
    final stored = await _transaction((db) async {
      final current = read ? await forMedia(mediaId) : null;
      final write = await build(current);
      if (write == null) return null;
      final decided = await _write(
        db,
        write.run,
        insert: write.insert,
        deleteIds: write.deleteIds,
      );
      return (write: write, decided: decided);
    });
    if (stored == null) return false;
    final (:write, :decided) = stored;
    await _publishStored(
      write.run.mediaId,
      insert: write.insert,
      deleteIds: write.deleteIds,
      decided: decided,
    );
    return true;
  }

  /// Publishes a stored run: the run, the rows written, the rows whose
  /// decisions it changed ([decided]) under the decision clock, and
  /// tombstones for the rows deleted.
  Future<void> _publishStored(
    String mediaId, {
    required List<MediaIdentification> insert,
    required List<String> deleteIds,
    required List<String> decided,
  }) async {
    final marks = _marks;
    if (marks == null) return;
    await marks.runsWritten([mediaId]);
    await marks.rowsWritten([for (final i in insert) i.id]);
    await marks.decisionsWritten(decided);
    await marks.deleted(rowIds: deleteIds);
  }

  /// Returns the ids of the rows whose decision fields it changed
  /// ([_decisionsChanged]).
  Future<List<String>> _write(
    AppDatabase db,
    MediaIdentificationRun run, {
    required List<MediaIdentification> insert,
    required List<String> deleteIds,
  }) async {
    final decided = await _decisionsChanged(db, insert);
    // A write that does not name its run id (a later chunk of a video scan)
    // continues the stored run's, and its rows join it (issue #4876).
    final runId =
        run.runId ??
        (await (db.select(
              db.mediaIdentificationRuns,
            )..where((r) => r.mediaId.equals(run.mediaId))).getSingleOrNull())
            ?.runId;
    await db
        .into(db.mediaIdentificationRuns)
        .insertOnConflictUpdate(_runToCompanion(run));
    if (deleteIds.isNotEmpty) {
      await (db.delete(
        db.mediaIdentifications,
      )..where((r) => r.id.isIn(deleteIds))).go();
    }
    for (final identification in insert) {
      await db
          .into(db.mediaIdentifications)
          .insertOnConflictUpdate(
            _toCompanion(
              identification.runId != null || runId == null
                  ? identification
                  : identification.copyWith(runId: () => runId),
            ),
          );
    }
    return decided;
  }

  /// Writes the decisions on [changed] (the decision, its species and
  /// when) and nothing else, in one transaction. [changed] comes from an
  /// earlier read: a video's scan may have moved, renamed or claimed the
  /// same rows since (issue #4675), and those columns stay as stored. Only
  /// rows still stored are written: a decision that lands after the rows
  /// were cleared or replaced must not bring them back.
  Future<void> updateDecisions(List<MediaIdentification> changed) async {
    final written = await _transaction((db) async {
      final written = <String>[];
      for (final identification in changed) {
        final row = _toCompanion(identification);
        final count = await _writeOver(
          db,
          identification.id,
          MediaIdentificationsCompanion(
            decision: row.decision,
            decidedSpeciesId: row.decidedSpeciesId,
            decidedAt: row.decidedAt,
          ),
        );
        if (count > 0) written.add(identification.id);
      }
      return written;
    });
    await _marks?.decisionsWritten(written);
  }

  /// Writes what naming found for [changed] (scores, candidates and label
  /// flags) and [run], moved on to the pack and place they were named for,
  /// in one transaction. Decisions, claims, boxes and paths stay as stored:
  /// the diver may have decided since [changed] was read. Only rows still
  /// stored are written, and [run] only while it is.
  ///
  /// Nothing is written once another run is stored than the one [run] was
  /// read as (issue #4876): a run synced in from another device since is
  /// newer than this naming. Of the run, only what naming moves is
  /// written (its pack, place and bars), so a scan stored since stays.
  /// Returns the ids of the rows written, none when it wrote nothing.
  Future<List<String>> updateNames(
    List<MediaIdentification> changed, {
    required MediaIdentificationRun run,
  }) async {
    final written = await _transaction((db) async {
      final runs = db.mediaIdentificationRuns;
      if (run.runId != null) {
        final stored =
            await (db.selectOnly(runs)
                  ..addColumns([runs.runId])
                  ..where(runs.mediaId.equals(run.mediaId)))
                .map((r) => r.read(runs.runId))
                .getSingleOrNull();
        if (stored != run.runId) {
          return (rows: const <String>[], run: false);
        }
      }
      final written = <String>[];
      for (final identification in changed) {
        final row = _toCompanion(identification);
        final count = await _writeOver(
          db,
          identification.id,
          MediaIdentificationsCompanion(
            openScore: row.openScore,
            candidatesJson: row.candidatesJson,
            locationLimited: row.locationLimited,
            suggestable: row.suggestable,
            confident: row.confident,
            specific: row.specific,
          ),
        );
        if (count > 0) written.add(identification.id);
      }
      // Only what naming moves; bars it does not know stay as stored.
      final moved =
          await (db.update(
            runs,
          )..where((r) => r.mediaId.equals(run.mediaId))).write(
            MediaIdentificationRunsCompanion(
              packVersion: Value(run.packVersion),
              locationCell: Value(run.locationCell),
              namingBars: Value.absentIfNull(run.namingBars?.toJson()),
            ),
          );
      return (rows: written, run: moved > 0);
    });
    await _marks?.rowsWritten(written.rows);
    if (written.run) await _marks?.runsWritten([run.mediaId]);
    return written.rows;
  }

  /// Returns how many rows it wrote: none when the row is gone.
  Future<int> _writeOver(
    AppDatabase db,
    String id,
    MediaIdentificationsCompanion columns,
  ) => (db.update(
    db.mediaIdentifications,
  )..where((r) => r.id.equals(id))).write(columns);

  /// Records that the diver gave [identificationId] the species
  /// [speciesId] from the frame (issue #4675). Writes nothing when the row
  /// is gone: a claim must not bring back a cleared identification.
  Future<void> claim(String identificationId, String speciesId) async {
    final db = _db;
    final count =
        await (db.update(
          db.mediaIdentifications,
        )..where((r) => r.id.equals(identificationId))).write(
          MediaIdentificationsCompanion(claimedSpeciesId: Value(speciesId)),
        );
    if (count > 0) await _marks?.decisionsWritten([identificationId]);
  }

  /// Writes [bars] onto the runs [packVersion] named on this device that
  /// kept none (made before runs kept them, issue #4876), and publishes
  /// them, so a device with no pack names their rows at the diver's level.
  /// A run is this device's when [deviceId] made it, or when it records no
  /// maker yet. Returns how many runs it wrote.
  Future<int> fillNamingBars(
    String packVersion,
    NamingBars bars, {
    required String? deviceId,
  }) async {
    final written = await _transaction((db) async {
      final runs = db.mediaIdentificationRuns;
      final mine = deviceId == null
          ? runs.analysedBy.isNull()
          : runs.analysedBy.isNull() | runs.analysedBy.equals(deviceId);
      final ids =
          await (db.selectOnly(runs)
                ..addColumns([runs.mediaId])
                ..where(
                  runs.packVersion.equals(packVersion) &
                      runs.namingBars.isNull() &
                      mine,
                ))
              .map((r) => r.read(runs.mediaId)!)
              .get();
      for (final slice in ids.slices(_slice)) {
        await (db.update(runs)..where((r) => r.mediaId.isIn(slice))).write(
          MediaIdentificationRunsCompanion(namingBars: Value(bars.toJson())),
        );
      }
      return ids;
    });
    await _marks?.runsWritten(written);
    return written.length;
  }

  /// Deletes [ids], leftovers of a run that lost a sync race on [mediaId]
  /// (issue #4876), with tombstones. They were judged against the run
  /// [runId], so nothing goes once another run is stored (a sync landed
  /// since), and no row of [runId] itself ever does. Only rows nobody has
  /// said anything on go: one a decision or claim synced into since is
  /// shown again, so it stays. Returns the ids deleted, for their crops and
  /// embeddings.
  Future<List<String>> deleteLeftovers(
    String mediaId,
    String runId,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final deleted = await _transaction((db) async {
      final stored =
          await (db.selectOnly(db.mediaIdentificationRuns)
                ..addColumns([db.mediaIdentificationRuns.runId])
                ..where(db.mediaIdentificationRuns.mediaId.equals(mediaId)))
              .map((r) => r.read(db.mediaIdentificationRuns.runId))
              .getSingleOrNull();
      if (stored != runId) return const <String>[];
      final table = db.mediaIdentifications;
      final gone = <String>[];
      for (final slice in ids.slices(_slice)) {
        final unsaid =
            await (db.selectOnly(table)
                  ..addColumns([table.id])
                  ..where(
                    table.mediaId.equals(mediaId) &
                        table.id.isIn(slice) &
                        table.runId.isNotNull() &
                        table.runId.equals(runId).not() &
                        table.decision.equals(
                          IdentificationDecision.undecided.name,
                        ) &
                        table.claimedSpeciesId.isNull() &
                        table.decidedAt.isNull(),
                  ))
                .map((r) => r.read(table.id)!)
                .get();
        if (unsaid.isEmpty) continue;
        await (db.delete(table)..where((r) => r.id.isIn(unsaid))).go();
        gone.addAll(unsaid);
      }
      return gone;
    });
    await _marks?.deleted(rowIds: deleted);
    return deleted;
  }

  /// Removes the runs and identifications of [mediaIds]; returns the ids of
  /// the identifications removed, for their crops and embeddings. They are
  /// tombstoned unless not [publish] (issue #4876): a sweep acting on a
  /// media tombstone removes this device's copies only.
  Future<List<String>> deleteForMedia(
    List<String> mediaIds, {
    bool publish = true,
  }) async {
    if (mediaIds.isEmpty) return const [];
    final (:ids, :runs) = await _transaction((db) async {
      final ids = <String>[];
      final runs = <String>[];
      // In slices: a sweep after a large sync deletion can name more media
      // than SQLite takes in one statement.
      for (final slice in mediaIds.slices(_slice)) {
        ids.addAll(await _idsWhere(db, (r) => r.mediaId.isIn(slice)));
        final table = db.mediaIdentificationRuns;
        runs.addAll(
          await (db.selectOnly(table)
                ..addColumns([table.mediaId])
                ..where(table.mediaId.isIn(slice)))
              .map((r) => r.read(table.mediaId)!)
              .get(),
        );
        await (db.delete(
          db.mediaIdentifications,
        )..where((r) => r.mediaId.isIn(slice))).go();
        await (db.delete(
          db.mediaIdentificationRuns,
        )..where((r) => r.mediaId.isIn(slice))).go();
      }
      return (ids: ids, runs: runs);
    });
    if (publish) await _marks?.deleted(runMediaIds: runs, rowIds: ids);
    return ids;
  }

  static const _slice = 500;

  /// Media ids with rows here whose media row is gone because the media
  /// was deleted (a tombstone says so): by sync, or by a delete that was
  /// held for undo and never undone. Rows whose media has simply not
  /// arrived yet are not orphans: results sync on their own, and may land
  /// before the media they describe (issue #4876).
  ///
  /// Results this device made ([deviceId], or a run with no maker yet) are
  /// orphans with no tombstone too: this device analysed the media, so it
  /// had it, and a tombstone retired since must not keep them forever.
  Future<List<String>> orphanMediaIds({String? deviceId}) async {
    final db = _db;
    // ?1 is this device's id: a run it made, or one with no maker yet.
    const gone =
        'NOT IN (SELECT id FROM media) AND (media_id IN '
        "(SELECT record_id FROM deletion_log WHERE entity_type = 'media') "
        'OR media_id IN (SELECT media_id FROM media_identification_runs '
        'WHERE analysed_by IS NULL OR analysed_by = ?1))';
    final rows = await db
        .customSelect(
          'SELECT media_id FROM media_identification_runs '
          'WHERE media_id $gone '
          'UNION '
          'SELECT media_id FROM media_identifications '
          'WHERE media_id $gone '
          // A synced crop has no reference either, and may be all that is
          // left of a media's results here.
          'UNION '
          'SELECT media_id FROM media_identification_crops '
          'WHERE media_id $gone',
          variables: [Variable<String>(deviceId)],
          readsFrom: {
            db.mediaIdentificationRuns,
            db.mediaIdentifications,
            db.mediaIdentificationCrops,
            db.media,
            db.deletionLog,
          },
        )
        .get();
    return [for (final row in rows) row.read<String>('media_id')];
  }

  Future<int> count() async {
    final db = _db;
    final countExp = db.mediaIdentifications.id.count();
    final row = await (db.selectOnly(
      db.mediaIdentifications,
    )..addColumns([countExp])).getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Every media id with a suggestion still open: an undecided
  /// identification that passed the bars (issue #4727). With [anyUndecided]
  /// every undecided one counts, for a naming level that may suggest what
  /// the pack's bars did not. [among] limits it to those media; [diverId]
  /// to that diver's dives and the media on no dive.
  Future<List<String>> mediaIdsWithSuggestions({
    bool anyUndecided = false,
    List<String>? among,
    String? diverId,
  }) async {
    // One logbook for every chunk (issue #4721).
    final db = _db;
    if (among != null && among.isEmpty) return const [];
    final where = <String>["i.decision = 'undecided'"];
    final variables = <Variable<Object>>[];
    if (!anyUndecided) where.add('i.suggestable = 1');
    if (diverId != null) {
      where.add('(m.dive_id IS NULL OR d.diver_id = ?)');
      variables.add(Variable.withString(diverId));
    }
    final found = <String>{};
    Future<void> read(List<String>? chunk) async {
      final clauses = [
        ...where,
        if (chunk != null)
          'i.media_id IN (${List.filled(chunk.length, '?').join(', ')})',
      ];
      final rows = await db
          .customSelect(
            'SELECT DISTINCT i.media_id AS media_id '
            'FROM media_identifications i '
            'JOIN media m ON m.id = i.media_id '
            'LEFT JOIN dives d ON d.id = m.dive_id '
            'WHERE ${clauses.join(' AND ')}',
            variables: [
              ...variables,
              if (chunk != null)
                for (final id in chunk) Variable.withString(id),
            ],
            readsFrom: {db.mediaIdentifications, db.media, db.dives},
          )
          .get();
      found.addAll([for (final row in rows) row.read<String>('media_id')]);
    }

    if (among == null) {
      await read(null);
    } else {
      for (final chunk in seriesIdChunks(among, size: _slice)) {
        await read(chunk);
      }
    }
    return found.toList();
  }

  /// [forMedia] for many media in one pass per chunk, by media id. Without
  /// [withPaths] a video track's path is left empty, not decoded: what reads
  /// only names, scores and decisions (Species to review, the readiness
  /// check) has no use for it.
  Future<Map<String, List<MediaIdentification>>> forMediaIds(
    List<String> mediaIds, {
    bool withPaths = true,
  }) async {
    // One logbook for every chunk (issue #4721).
    final db = _db;
    final result = <String, List<MediaIdentification>>{};
    for (final chunk in seriesIdChunks(mediaIds, size: _slice)) {
      final rows =
          await (db.select(db.mediaIdentifications)
                ..where((r) => r.mediaId.isIn(chunk))
                ..orderBy([
                  (r) => OrderingTerm.asc(r.createdAt),
                  (r) => OrderingTerm.asc(r.id),
                ]))
              .get();
      for (final row in rows) {
        result
            .putIfAbsent(row.mediaId, () => [])
            .add(_fromRow(row, withPath: withPaths));
      }
    }
    return result;
  }

  /// [runsFor] and [forMediaIds] in one transaction on one logbook, so
  /// each media's run and rows come from the same moment and a logbook
  /// opened during the read is not mixed in (issue #4721), as
  /// [forMediaWithRun] reads one media.
  Future<
    (
      Map<String, MediaIdentificationRun>,
      Map<String, List<MediaIdentification>>,
    )
  >
  forMediaIdsWithRuns(List<String> mediaIds, {bool withPaths = true}) =>
      _transaction(
        (_) async => (
          await runsFor(mediaIds),
          await forMediaIds(mediaIds, withPaths: withPaths),
        ),
      );

  /// [runFor] for many media, by media id; media with no run are absent.
  Future<Map<String, MediaIdentificationRun>> runsFor(
    List<String> mediaIds,
  ) async {
    // One logbook for every chunk (issue #4721).
    final db = _db;
    final result = <String, MediaIdentificationRun>{};
    for (final chunk in seriesIdChunks(mediaIds, size: _slice)) {
      final rows = await (db.select(
        db.mediaIdentificationRuns,
      )..where((r) => r.mediaId.isIn(chunk))).get();
      for (final row in rows) {
        result[row.mediaId] = _runFromRow(row);
      }
    }
    return result;
  }

  /// [taggedSpecies] for many media, by media id; untagged media are
  /// absent.
  Future<Map<String, List<TaggedSpecies>>> taggedSpeciesFor(
    List<String> mediaIds,
  ) async {
    // One logbook for every chunk (issue #4721).
    final db = _db;
    final result = <String, List<TaggedSpecies>>{};
    for (final chunk in seriesIdChunks(mediaIds, size: _slice)) {
      final rows = await db
          .customSelect(
            'SELECT ms.media_id AS media_id, ms.species_id AS species_id, '
            's.scientific_name AS sci '
            'FROM media_species ms LEFT JOIN species s ON s.id = ms.species_id '
            'WHERE ms.media_id IN (${List.filled(chunk.length, '?').join(', ')})',
            variables: [for (final id in chunk) Variable.withString(id)],
            readsFrom: {db.mediaSpecies, db.species},
          )
          .get();
      for (final row in rows) {
        result
            .putIfAbsent(row.read<String>('media_id'), () => [])
            .add(
              TaggedSpecies(
                speciesId: row.read<String>('species_id'),
                scientificName: row.readNullable<String>('sci'),
              ),
            );
      }
    }
    return result;
  }

  /// Every media id with a run or an identification in this logbook.
  Future<List<String>> mediaIds() async {
    final db = _db;
    final rows = await db
        .customSelect(
          'SELECT media_id FROM media_identification_runs '
          'UNION '
          'SELECT media_id FROM media_identifications',
          readsFrom: {db.mediaIdentificationRuns, db.mediaIdentifications},
        )
        .get();
    return [for (final row in rows) row.read<String>('media_id')];
  }

  Future<List<String>> _idsWhere(
    AppDatabase db,
    Expression<bool> Function($MediaIdentificationsTable r)? filter,
  ) async {
    final table = db.mediaIdentifications;
    final query = db.selectOnly(table)..addColumns([table.id]);
    if (filter != null) query.where(filter(table));
    return query.map((r) => r.read(table.id)!).get();
  }

  static final _log = LoggerService.forClass(MediaIdentificationRepository);
}
