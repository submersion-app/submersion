import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/scanned_ranges.dart';
import 'package:submersion/features/species_id/domain/entities/track_sample.dart';
import 'package:submersion/features/species_id/domain/services/scanned_ranges_codec.dart';
import 'package:submersion/features/species_id/domain/services/track_path_codec.dart';

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
/// decisions on it (issue #4668). Never synced: the rows are this device's,
/// and the app derives them; the diver's own record is the species tags.
class MediaIdentificationRepository {
  /// [database] fixes the logbook; otherwise [currentDatabase] (by default
  /// [DatabaseService]'s) is asked on every call. Both together are
  /// refused in every build, since one would silently win.
  MediaIdentificationRepository({
    AppDatabase? database,
    AppDatabase Function()? currentDatabase,
  }) : _currentDatabase = database != null
           ? (() => database)
           : (currentDatabase ?? _openLogbook) {
    if (database != null && currentDatabase != null) {
      throw ArgumentError(
        'Give a fixed database or a way to find one, not both',
      );
    }
  }

  final AppDatabase Function() _currentDatabase;

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
  }) => _transaction(
    (db) => _write(db, run, insert: insert, deleteIds: deleteIds),
  );

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
  }) => _transaction((db) async {
    final current = read ? await forMedia(mediaId) : null;
    final write = await build(current);
    if (write == null) return false;
    await _write(
      db,
      write.run,
      insert: write.insert,
      deleteIds: write.deleteIds,
    );
    return true;
  });

  Future<void> _write(
    AppDatabase db,
    MediaIdentificationRun run, {
    required List<MediaIdentification> insert,
    required List<String> deleteIds,
  }) async {
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
          .insertOnConflictUpdate(_toCompanion(identification));
    }
  }

  /// Writes the decisions on [changed] (the decision, its species and
  /// when) and nothing else, in one transaction. [changed] comes from an
  /// earlier read: a video's scan may have moved, renamed or claimed the
  /// same rows since (issue #4675), and those columns stay as stored. Only
  /// rows still stored are written: a decision that lands after the rows
  /// were cleared or replaced must not bring them back.
  Future<void> updateDecisions(List<MediaIdentification> changed) =>
      _transaction((db) async {
        for (final identification in changed) {
          final row = _toCompanion(identification);
          await _writeOver(
            db,
            identification.id,
            MediaIdentificationsCompanion(
              decision: row.decision,
              decidedSpeciesId: row.decidedSpeciesId,
              decidedAt: row.decidedAt,
            ),
          );
        }
      });

  /// Writes what naming found for [changed] (scores, candidates and label
  /// flags) and [run], moved on to the pack and place they were named for,
  /// in one transaction. Decisions, claims, boxes and paths stay as stored:
  /// the diver may have decided since [changed] was read. Only rows still
  /// stored are written, and [run] only while it is.
  Future<void> updateNames(
    List<MediaIdentification> changed, {
    required MediaIdentificationRun run,
  }) => _transaction((db) async {
    for (final identification in changed) {
      final row = _toCompanion(identification);
      await _writeOver(
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
    }
    await db.update(db.mediaIdentificationRuns).replace(_runToCompanion(run));
  });

  Future<void> _writeOver(
    AppDatabase db,
    String id,
    MediaIdentificationsCompanion columns,
  ) => (db.update(
    db.mediaIdentifications,
  )..where((r) => r.id.equals(id))).write(columns);

  /// Records that the diver gave [identificationId] the species
  /// [speciesId] from the frame (issue #4675). Writes nothing when the row
  /// is gone: a claim must not bring back a cleared identification.
  Future<void> claim(String identificationId, String speciesId) {
    final db = _db;
    return (db.update(
      db.mediaIdentifications,
    )..where((r) => r.id.equals(identificationId))).write(
      MediaIdentificationsCompanion(claimedSpeciesId: Value(speciesId)),
    );
  }

  /// Removes the runs and identifications of [mediaIds]; returns the ids of
  /// the identifications removed, for their crops and embeddings.
  Future<List<String>> deleteForMedia(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return const [];
    return _transaction((db) async {
      final ids = <String>[];
      // In slices: a sweep after a large sync deletion can name more media
      // than SQLite takes in one statement.
      for (final slice in mediaIds.slices(_slice)) {
        ids.addAll(await _idsWhere(db, (r) => r.mediaId.isIn(slice)));
        await (db.delete(
          db.mediaIdentifications,
        )..where((r) => r.mediaId.isIn(slice))).go();
        await (db.delete(
          db.mediaIdentificationRuns,
        )..where((r) => r.mediaId.isIn(slice))).go();
      }
      return ids;
    });
  }

  static const _slice = 500;

  /// Media ids with rows here but no media row: deleted by sync, or by a
  /// delete that was held for undo and never undone.
  Future<List<String>> orphanMediaIds() async {
    final db = _db;
    final rows = await db
        .customSelect(
          'SELECT media_id FROM media_identification_runs '
          'WHERE media_id NOT IN (SELECT id FROM media) '
          'UNION '
          'SELECT media_id FROM media_identifications '
          'WHERE media_id NOT IN (SELECT id FROM media)',
          readsFrom: {
            db.mediaIdentificationRuns,
            db.mediaIdentifications,
            db.media,
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

  static MediaIdentificationRun _runFromRow(MediaIdentificationRunRow row) =>
      MediaIdentificationRun(
        mediaId: row.mediaId,
        packVersion: row.packVersion,
        detectorId: row.detectorId,
        classifierId: row.classifierId,
        locationCell: row.locationCell,
        analysedAt: _time(row.analysedAt),
        imageWidth: row.imageWidth,
        imageHeight: row.imageHeight,
        detectionCount: row.detectionCount,
        scannedMs: row.scannedMs,
        videoDurationMs: row.videoDurationMs,
        scannedRanges: _ranges(row.scannedRanges),
      );

  /// The stored stretches, or null when there are none or they cannot be
  /// read: the run's scanned_ms mark then applies.
  static ScannedRanges? _ranges(Uint8List? bytes) {
    if (bytes == null) return null;
    try {
      return decodeScannedRanges(bytes);
    } on FormatException catch (e) {
      _log.warning('Unreadable scanned stretches, using the mark', error: e);
      return null;
    }
  }

  static MediaIdentificationRunsCompanion _runToCompanion(
    MediaIdentificationRun run,
  ) => MediaIdentificationRunsCompanion.insert(
    mediaId: run.mediaId,
    packVersion: run.packVersion,
    detectorId: run.detectorId,
    classifierId: run.classifierId,
    locationCell: Value(run.locationCell),
    analysedAt: run.analysedAt.millisecondsSinceEpoch,
    imageWidth: run.imageWidth,
    imageHeight: run.imageHeight,
    detectionCount: run.detectionCount,
    scannedMs: Value(run.scannedMs),
    videoDurationMs: Value(run.videoDurationMs),
    scannedRanges: Value(
      run.scannedRanges == null
          ? null
          : encodeScannedRanges(run.scannedRanges!),
    ),
  );

  static MediaIdentification _fromRow(
    MediaIdentificationRow row, {
    bool withPath = true,
  }) => MediaIdentification(
    id: row.id,
    mediaId: row.mediaId,
    box: IdentificationBox(
      x: row.boxX,
      y: row.boxY,
      width: row.boxWidth,
      height: row.boxHeight,
    ),
    boxPixelWidth: row.boxPixelWidth,
    boxPixelHeight: row.boxPixelHeight,
    detectorScore: row.detectorScore,
    openScore: row.openScore,
    candidates: _decodeCandidates(row.candidatesJson),
    locationLimited: row.locationLimited,
    suggestable: row.suggestable,
    decision: IdentificationDecision.values.firstWhere(
      (d) => d.name == row.decision,
      orElse: () => IdentificationDecision.undecided,
    ),
    decidedSpeciesId: row.decidedSpeciesId,
    decidedAt: row.decidedAt == null ? null : _time(row.decidedAt!),
    createdAt: _time(row.createdAt),
    startMs: row.startMs,
    endMs: row.endMs,
    bestMs: row.bestMs,
    path: withPath ? _decodePath(row) : const [],
    claimedSpeciesId: row.claimedSpeciesId,
    confident: row.confident,
    specific: row.specific,
  );

  static MediaIdentificationsCompanion _toCompanion(MediaIdentification i) =>
      MediaIdentificationsCompanion.insert(
        id: i.id,
        mediaId: i.mediaId,
        boxX: i.box.x,
        boxY: i.box.y,
        boxWidth: i.box.width,
        boxHeight: i.box.height,
        boxPixelWidth: i.boxPixelWidth,
        boxPixelHeight: i.boxPixelHeight,
        detectorScore: i.detectorScore,
        openScore: i.openScore,
        candidatesJson: jsonEncode([for (final c in i.candidates) c.toJson()]),
        locationLimited: i.locationLimited,
        suggestable: i.suggestable,
        decision: i.decision.name,
        decidedSpeciesId: Value(i.decidedSpeciesId),
        decidedAt: Value(i.decidedAt?.millisecondsSinceEpoch),
        createdAt: i.createdAt.millisecondsSinceEpoch,
        startMs: Value(i.startMs),
        endMs: Value(i.endMs),
        bestMs: Value(i.bestMs),
        trackPath: Value(
          i.isTrack ? encodeTrackPath(i.startMs!, i.path) : null,
        ),
        claimedSpeciesId: Value(i.claimedSpeciesId),
        confident: Value(i.confident),
        specific: Value(i.specific),
      );

  /// A path that cannot be read keeps its row with no path, which draws no
  /// label: the rest of what was found stays usable.
  static List<TrackSample> _decodePath(MediaIdentificationRow row) {
    final bytes = row.trackPath;
    final start = row.startMs;
    if (bytes == null || start == null) return const [];
    try {
      return decodeTrackPath(start, bytes);
    } on FormatException catch (e) {
      _log.debug('Unreadable track path on ${row.id}', error: e);
      return const [];
    }
  }

  static final _log = LoggerService.forClass(MediaIdentificationRepository);

  /// A row whose JSON cannot be read keeps its place with no candidates,
  /// which the rules never suggest.
  static List<NamedCandidate> _decodeCandidates(String json) {
    try {
      final list = jsonDecode(json);
      if (list is! List) return const [];
      return [
        for (final entry in list)
          if (entry is Map)
            NamedCandidate.fromJson(entry.cast<String, Object?>()),
      ];
    } on Object {
      return const [];
    }
  }

  static DateTime _time(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
