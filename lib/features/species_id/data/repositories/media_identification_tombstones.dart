part of 'media_identification_repository.dart';

/// Which identifications this logbook has deleted, here or by applying a
/// peer's tombstone (issue #4890), so what this device keeps for them
/// outside the logbook can go too.
extension MediaIdentificationTombstones on MediaIdentificationRepository {
  /// Those of [ids] this logbook holds a tombstone for and no row. Read
  /// from what is committed: an apply that rolled back left its rows, so
  /// their ids are not among them. A tombstone alone does not show the
  /// row was ever here: sync logs a peer's tombstone whether or not it
  /// found the row, so callers sweeping files shared by every logbook
  /// also check the media is this logbook's ([mediaHereAmong]).
  Future<Set<String>> deletedAmong(Iterable<String> ids) async {
    final wanted = ids.toSet().toList();
    if (wanted.isEmpty) return const {};
    final db = _db;
    final log = db.deletionLog;
    final rows = db.mediaIdentifications;
    final deleted = <String>{};
    for (final slice in wanted.slices(MediaIdentificationRepository._slice)) {
      final tombstoned =
          await (db.selectOnly(log, distinct: true)
                ..addColumns([log.recordId])
                ..where(
                  log.entityType.equals(IdentificationSyncMarks.rows) &
                      log.recordId.isIn(slice),
                ))
              .map((r) => r.read(log.recordId)!)
              .get();
      if (tombstoned.isEmpty) continue;
      final live =
          await (db.selectOnly(rows)
                ..addColumns([rows.id])
                ..where(rows.id.isIn(tombstoned)))
              .map((r) => r.read(rows.id)!)
              .get();
      deleted.addAll(tombstoned.toSet().difference(live.toSet()));
    }
    return deleted;
  }

  /// Those of [mediaIds] this logbook holds: a media row, or a run of the
  /// marine life model on it. Another logbook's photo has its own media
  /// id, so its crops folder is never among them.
  Future<Set<String>> mediaHereAmong(Iterable<String> mediaIds) async {
    final wanted = mediaIds.toSet();
    if (wanted.isEmpty) return const {};
    final db = _db;
    final media = db.media;
    final runs = db.mediaIdentificationRuns;
    final here = <String>{};
    for (final slice in wanted.slices(MediaIdentificationRepository._slice)) {
      here.addAll(
        await (db.selectOnly(media)
              ..addColumns([media.id])
              ..where(media.id.isIn(slice)))
            .map((r) => r.read(media.id)!)
            .get(),
      );
      here.addAll(
        await (db.selectOnly(runs)
              ..addColumns([runs.mediaId])
              ..where(runs.mediaId.isIn(slice)))
            .map((r) => r.read(runs.mediaId)!)
            .get(),
      );
    }
    return here;
  }

  /// Those of [ids] with no row in this logbook, as committed: for ids
  /// known to have been here, whose delete may have committed with no
  /// tombstone logged.
  Future<Set<String>> goneAmong(Iterable<String> ids) async {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return const {};
    final db = _db;
    final rows = db.mediaIdentifications;
    final live = <String>{};
    for (final slice in wanted.slices(MediaIdentificationRepository._slice)) {
      live.addAll(
        await (db.selectOnly(rows)
              ..addColumns([rows.id])
              ..where(rows.id.isIn(slice)))
            .map((r) => r.read(rows.id)!)
            .get(),
      );
    }
    return wanted.difference(live);
  }
}
