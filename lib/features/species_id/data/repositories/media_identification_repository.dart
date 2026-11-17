import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';

/// What the marine life model found on each piece of media, and the diver's
/// decisions on it (issue #4668). Never synced: the rows are this device's,
/// and the app derives them; the diver's own record is the species tags.
class MediaIdentificationRepository {
  MediaIdentificationRepository({AppDatabase? database}) : _database = database;

  final AppDatabase? _database;

  /// The open logbook, read on every call so a switch of logbook (demo
  /// mode, a restore) is followed.
  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// Ticks on any write to either table.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.mediaIdentificationRuns,
      _db.mediaIdentifications,
    ]),
  );

  Future<MediaIdentificationRun?> runFor(String mediaId) async {
    final row = await (_db.select(
      _db.mediaIdentificationRuns,
    )..where((r) => r.mediaId.equals(mediaId))).getSingleOrNull();
    return row == null ? null : _runFromRow(row);
  }

  /// Oldest first, so a photo's identifications keep a stable order.
  Future<List<MediaIdentification>> forMedia(String mediaId) async {
    final rows =
        await (_db.select(_db.mediaIdentifications)
              ..where((r) => r.mediaId.equals(mediaId))
              ..orderBy([
                (r) => OrderingTerm.asc(r.createdAt),
                (r) => OrderingTerm.asc(r.id),
              ]))
            .get();
    return [for (final row in rows) _fromRow(row)];
  }

  /// In one transaction: upserts [run], deletes [deleteIds], inserts
  /// [insert].
  Future<void> storeRun(
    MediaIdentificationRun run, {
    required List<MediaIdentification> insert,
    required List<String> deleteIds,
  }) => _db.transaction(() async {
    await _db
        .into(_db.mediaIdentificationRuns)
        .insertOnConflictUpdate(_runToCompanion(run));
    if (deleteIds.isNotEmpty) {
      await (_db.delete(
        _db.mediaIdentifications,
      )..where((r) => r.id.isIn(deleteIds))).go();
    }
    for (final identification in insert) {
      await _db
          .into(_db.mediaIdentifications)
          .insertOnConflictUpdate(_toCompanion(identification));
    }
  });

  /// Writes [changed] over the stored rows with the same ids, and [run]
  /// when given, in one transaction.
  Future<void> updateIdentifications(
    List<MediaIdentification> changed, {
    MediaIdentificationRun? run,
  }) => _db.transaction(() async {
    for (final identification in changed) {
      await _db
          .into(_db.mediaIdentifications)
          .insertOnConflictUpdate(_toCompanion(identification));
    }
    if (run != null) {
      await _db
          .into(_db.mediaIdentificationRuns)
          .insertOnConflictUpdate(_runToCompanion(run));
    }
  });

  /// Removes the runs and identifications of [mediaIds]; returns the ids of
  /// the identifications removed, for their crops and embeddings.
  Future<List<String>> deleteForMedia(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return const [];
    return _db.transaction(() async {
      final ids = await _idsWhere((r) => r.mediaId.isIn(mediaIds));
      await (_db.delete(
        _db.mediaIdentifications,
      )..where((r) => r.mediaId.isIn(mediaIds))).go();
      await (_db.delete(
        _db.mediaIdentificationRuns,
      )..where((r) => r.mediaId.isIn(mediaIds))).go();
      return ids;
    });
  }

  /// Media ids with rows here but no media row: deleted by sync, or by a
  /// delete that was held for undo and never undone.
  Future<List<String>> orphanMediaIds() async {
    final rows = await _db
        .customSelect(
          'SELECT media_id FROM media_identification_runs '
          'WHERE media_id NOT IN (SELECT id FROM media) '
          'UNION '
          'SELECT media_id FROM media_identifications '
          'WHERE media_id NOT IN (SELECT id FROM media)',
          readsFrom: {
            _db.mediaIdentificationRuns,
            _db.mediaIdentifications,
            _db.media,
          },
        )
        .get();
    return [for (final row in rows) row.read<String>('media_id')];
  }

  Future<int> count() async {
    final countExp = _db.mediaIdentifications.id.count();
    final row = await (_db.selectOnly(
      _db.mediaIdentifications,
    )..addColumns([countExp])).getSingle();
    return row.read(countExp) ?? 0;
  }

  /// Removes every run and identification; returns the identification ids.
  Future<List<String>> deleteAll() => _db.transaction(() async {
    final ids = await _idsWhere(null);
    await _db.delete(_db.mediaIdentifications).go();
    await _db.delete(_db.mediaIdentificationRuns).go();
    return ids;
  });

  Future<List<String>> _idsWhere(
    Expression<bool> Function($MediaIdentificationsTable r)? filter,
  ) async {
    final table = _db.mediaIdentifications;
    final query = _db.selectOnly(table)..addColumns([table.id]);
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
      );

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
  );

  static MediaIdentification _fromRow(MediaIdentificationRow row) =>
      MediaIdentification(
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
      );

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
