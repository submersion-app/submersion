import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/species_id/data/repositories/identification_sync_marks.dart';

/// The crops of named identifications, kept in the logbook so they sync
/// (issue #4876): a device that did not analyse a photo shows the same
/// picture of each animal the app named. Crops of unnamed ones stay files
/// on the device that analysed them ([IdentificationCropStore] fronts both).
class IdentificationCropRepository {
  /// [database] fixes the logbook; otherwise the open one is used on every
  /// call. Only the app's own logbook publishes by default, as for
  /// [MediaIdentificationRepository].
  IdentificationCropRepository({
    AppDatabase? database,
    IdentificationSyncMarks? marks,
  }) : _database = database,
       _marks = marks ?? (database == null ? IdentificationSyncMarks() : null);

  final AppDatabase? _database;
  final IdentificationSyncMarks? _marks;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  static const _slice = 500;

  /// Ticks on any write to the crops, a sync's included.
  Stream<void> watchChanges() {
    final db = _db;
    return db.tableUpdates(
      TableUpdateQuery.onAllTables([db.mediaIdentificationCrops]),
    );
  }

  Future<Uint8List?> bytesFor(String identificationId) async {
    final db = _db;
    final table = db.mediaIdentificationCrops;
    final row =
        await (db.selectOnly(table)
              ..addColumns([table.jpeg])
              ..where(table.id.equals(identificationId)))
            .getSingleOrNull();
    return row?.read(table.jpeg);
  }

  /// Which of [identificationIds] have a crop here.
  Future<Set<String>> presentAmong(List<String> identificationIds) async {
    if (identificationIds.isEmpty) return const {};
    final db = _db;
    final table = db.mediaIdentificationCrops;
    final present = <String>{};
    for (final slice in identificationIds.slices(_slice)) {
      present.addAll(
        await (db.selectOnly(table)
              ..addColumns([table.id])
              ..where(table.id.isIn(slice)))
            .map((r) => r.read(table.id)!)
            .get(),
      );
    }
    return present;
  }

  /// Stores [jpeg] as the crop of [identificationId] on [mediaId], and
  /// publishes it.
  Future<void> put(
    String identificationId,
    String mediaId,
    Uint8List jpeg,
  ) async {
    final db = _db;
    await db
        .into(db.mediaIdentificationCrops)
        .insertOnConflictUpdate(
          MediaIdentificationCropsCompanion.insert(
            id: identificationId,
            mediaId: mediaId,
            jpeg: jpeg,
          ),
        );
    await _marks?.cropsWritten([identificationId]);
  }

  /// [put], only while [identificationId] is still stored on [mediaId]
  /// (issue #4876): a promotion worked out from rows a sync has deleted
  /// since must not bring back, and publish, a crop for a row that is gone
  /// on every device. Checked and written in one transaction. Returns
  /// whether it wrote.
  Future<bool> putIfIdentified(
    String identificationId,
    String mediaId,
    Uint8List jpeg,
  ) async {
    final db = _db;
    final wrote = await db.transaction(() async {
      final rows = db.mediaIdentifications;
      final stored =
          await (db.selectOnly(rows)
                ..addColumns([rows.id])
                ..where(
                  rows.id.equals(identificationId) &
                      rows.mediaId.equals(mediaId),
                ))
              .getSingleOrNull();
      if (stored == null) return false;
      await db
          .into(db.mediaIdentificationCrops)
          .insertOnConflictUpdate(
            MediaIdentificationCropsCompanion.insert(
              id: identificationId,
              mediaId: mediaId,
              jpeg: jpeg,
            ),
          );
      return true;
    });
    if (wrote) await _marks?.cropsWritten([identificationId]);
    return wrote;
  }

  /// Publishes the crops here that never got a clock: one whose mark failed
  /// after its write. No sync backfill covers crops, which have no time to
  /// order them by, so this runs at launch instead. Returns how many.
  Future<int> republishUnstamped() async {
    final db = _db;
    final table = db.mediaIdentificationCrops;
    final ids =
        await (db.selectOnly(table)
              ..addColumns([table.id])
              ..where(table.hlc.isNull()))
            .map((r) => r.read(table.id)!)
            .get();
    await _marks?.cropsWritten(ids);
    return ids.length;
  }

  /// Removes the crops of [identificationIds] that are here, tombstoned so
  /// peers drop them too unless not [publish].
  Future<void> deleteIds(
    List<String> identificationIds, {
    bool publish = true,
  }) async {
    final present = (await presentAmong(identificationIds)).toList();
    if (present.isEmpty) return;
    final db = _db;
    for (final slice in present.slices(_slice)) {
      await (db.delete(
        db.mediaIdentificationCrops,
      )..where((c) => c.id.isIn(slice))).go();
    }
    if (publish) await _marks?.deleted(cropIds: present);
  }

  /// Removes every crop of [mediaIds], tombstoned unless not [publish].
  Future<void> deleteForMedia(
    List<String> mediaIds, {
    bool publish = true,
  }) async {
    if (mediaIds.isEmpty) return;
    final db = _db;
    final table = db.mediaIdentificationCrops;
    final ids = <String>[];
    for (final slice in mediaIds.slices(_slice)) {
      ids.addAll(
        await (db.selectOnly(table)
              ..addColumns([table.id])
              ..where(table.mediaId.isIn(slice)))
            .map((r) => r.read(table.id)!)
            .get(),
      );
    }
    await deleteIds(ids, publish: publish);
  }
}
