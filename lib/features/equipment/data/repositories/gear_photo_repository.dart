import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// One gear item's photos in the Gear gallery, newest first.
class GearPhotoGroup {
  const GearPhotoGroup({
    required this.equipmentId,
    required this.name,
    required this.items,
  });

  final String equipmentId;
  final String name;
  final List<MediaItem> items;
}

/// Photos of gear (issue #3355): identification photos on the item, photos
/// that back up a check-in, the Gear gallery across items, and the photo
/// chosen to stand for an item.
///
/// Every gear photo is an ordinary `media` row linked by `equipment_id`;
/// [MediaItem.isGearPhoto] tells a photo or video from leftover paperwork.
/// An item rarely holds more than a handful of rows, so the type filter
/// runs on the mapped rows rather than in SQL.
class GearPhotoRepository {
  GearPhotoRepository({AppDatabase? db, SyncRepository? syncRepository})
    : _dbOverride = db,
      _syncRepository = syncRepository ?? SyncRepository();

  final AppDatabase? _dbOverride;
  final SyncRepository _syncRepository;

  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  /// Ticks when the gear photo lists can have changed: the media rows
  /// themselves, and the check-ins that sort a photo onto a check-in or
  /// back to the item when its check-in is gone (deleted here or by a
  /// sync, which touches no media row).
  Stream<void> watchGearPhotoChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([_db.media, _db.equipmentObservations]),
      )
      .debounce(MediaRepository.changeTickDebounce);

  /// [watchGearPhotoChanges] plus the equipment rows and their shares, for
  /// the readers that also read an item: the gallery's names, which items
  /// the diver may see, and the cover. The photo lists do not, so an
  /// unrelated gear edit does not re-read them.
  Stream<void> watchGearItemPhotoChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          _db.media,
          _db.equipmentObservations,
          _db.equipment,
          _db.equipmentShares,
        ]),
      )
      .debounce(MediaRepository.changeTickDebounce);

  /// The gear photos among the rows [w] selects, newest first.
  Future<List<MediaItem>> _photosOf(
    Expression<bool> Function($MediaTable) w,
  ) async {
    final rows =
        await (_db.select(_db.media)
              ..where(w)
              ..orderBy([
                (t) => OrderingTerm.desc(t.takenAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [
      for (final row in rows)
        if (mediaItemFromRow(row) case final item when item.isGearPhoto) item,
    ];
  }

  /// The item's identification photos: gear photos backing no check-in.
  Future<List<MediaItem>> identificationPhotos(String equipmentId) async {
    final photos = await _photosOf((t) => t.equipmentId.equals(equipmentId));
    final living = await _existingCheckIns(photos);
    return [
      for (final item in photos)
        if (!living.contains(item.observationId)) item,
    ];
  }

  /// The check-in ids among [photos] that name a check-in this device has.
  ///
  /// An id with no check-in counts as none, so the photo shows as an
  /// identification photo instead of vanishing from the gear page: a draft
  /// whose app was killed before Save, a check-in deleted on a peer, or one
  /// that has not arrived yet (sync applies media before check-ins).
  Future<Set<String>> _existingCheckIns(Iterable<MediaItem> photos) async {
    final ids = {for (final m in photos) ?m.observationId};
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.selectOnly(_db.equipmentObservations)
              ..addColumns([_db.equipmentObservations.id])
              ..where(_db.equipmentObservations.id.isIn(ids)))
            .get();
    return {for (final r in rows) r.read(_db.equipmentObservations.id)!};
  }

  /// The photos that back up one check-in.
  Future<List<MediaItem>> photosForObservation(String observationId) =>
      _photosOf(
        (t) =>
            t.observationId.equals(observationId) & t.equipmentId.isNotNull(),
      );

  /// Every check-in photo of [equipmentId], keyed by check-in, in one read
  /// for the Check-ins card.
  Future<Map<String, List<MediaItem>>> photosByObservation(
    String equipmentId,
  ) async {
    final photos = await _photosOf(
      (t) => t.equipmentId.equals(equipmentId) & t.observationId.isNotNull(),
    );
    final living = await _existingCheckIns(photos);
    final byObservation = <String, List<MediaItem>>{};
    for (final item in photos) {
      if (!living.contains(item.observationId)) continue;
      (byObservation[item.observationId!] ??= []).add(item);
    }
    return byObservation;
  }

  /// Every item holding at least one gear photo, for the gallery's
  /// visibility check.
  Future<Set<String>> equipmentIdsWithPhotos() async {
    final m = _db.media;
    // The SQL form of [MediaItem.isGearPhoto]: ids only, no row to hydrate.
    final rows =
        await (_db.selectOnly(m, distinct: true)
              ..addColumns([m.equipmentId])
              ..where(
                m.equipmentId.isNotNull() &
                    m.fileType.isNotIn([
                      ...kSignatureFileTypes,
                      mediaTypeToDbString(MediaType.document),
                    ]) &
                    m.sourceType.equals(MediaSourceType.signature.name).not(),
              ))
            .get();
    return {for (final r in rows) r.read(m.equipmentId)!};
  }

  /// The Gear gallery: photos of every item in [equipmentIds], grouped by
  /// item, the item with the newest photo first. The caller passes the ids
  /// the viewing diver may see.
  Future<List<GearPhotoGroup>> gearGallery(Set<String> equipmentIds) async {
    if (equipmentIds.isEmpty) return const [];
    final rows = await _photosOf((t) => t.equipmentId.isIn(equipmentIds));
    if (rows.isEmpty) return const [];
    // A check-in id with no check-in counts as none here too, so the badge
    // agrees with the gear page.
    final living = await _existingCheckIns(rows);
    final photos = [
      for (final m in rows)
        m.observationId == null || living.contains(m.observationId)
            ? m
            : m.copyWith(observationId: null),
    ];
    final byItem = <String, List<MediaItem>>{};
    for (final item in photos) {
      (byItem[item.equipmentId!] ??= []).add(item);
    }
    final names = {
      for (final row in await (_db.select(
        _db.equipment,
      )..where((t) => t.id.isIn(byItem.keys))).get())
        row.id: row.name,
    };
    // Insertion order follows the photos' newest-first order. A row naming
    // an item this device lacks (a peer's delete not yet reconciled) has no
    // page to open, so its group is left out.
    return [
      for (final MapEntry(:key, :value) in byItem.entries)
        if (names[key] case final name?)
          GearPhotoGroup(equipmentId: key, name: name, items: value),
    ];
  }

  /// Gallery rows already linked to [equipmentId], for the import dedupe.
  Future<List<MediaItem>> galleryLinksFor(String equipmentId) async => [
    for (final item in await _photosOf(
      (t) => t.equipmentId.equals(equipmentId),
    ))
      if (item.platformAssetId?.isNotEmpty ?? false) item,
  ];

  /// Local files already linked to [equipmentId], for the import dedupe.
  Future<Set<String>> linkedLocalPathsFor(String equipmentId) async => {
    for (final item in await _photosOf(
      (t) => t.equipmentId.equals(equipmentId),
    ))
      if (item.localPath case final path? when path.isNotEmpty) path,
  };

  /// The item's cover photo, or null when none is chosen, the chosen row is
  /// not on this device, or it is no longer one of this item's
  /// identification photos.
  Future<MediaItem?> coverFor(String equipmentId) async {
    final item = await (_db.select(
      _db.equipment,
    )..where((t) => t.id.equals(equipmentId))).getSingleOrNull();
    final coverId = item?.coverMediaId;
    if (coverId == null) return null;
    final row = await (_db.select(
      _db.media,
    )..where((t) => t.id.equals(coverId))).getSingleOrNull();
    if (row == null) return null;
    final media = mediaItemFromRow(row);
    final belongs =
        media.isGearPhoto &&
        media.equipmentId == equipmentId &&
        (await _existingCheckIns([media])).isEmpty;
    return belongs ? media : null;
  }

  /// Chooses [mediaId] as the photo that stands for [equipmentId], or clears
  /// the choice when null. A targeted write: the edit form's save never
  /// touches this column.
  Future<void> setCover(String equipmentId, String? mediaId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(
        _db.equipment,
      )..where((t) => t.id.equals(equipmentId))).write(
        EquipmentCompanion(coverMediaId: Value(mediaId), updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: equipmentId,
        localUpdatedAt: now,
      );
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Clears the cover of every item whose cover is one of [mediaIds], after
  /// those rows leave their item.
  Future<void> clearCoversNaming(Iterable<String> mediaIds) async {
    final ids = mediaIds.toSet();
    if (ids.isEmpty) return;
    final items = await (_db.select(
      _db.equipment,
    )..where((t) => t.coverMediaId.isIn(ids))).get();
    for (final item in items) {
      await setCover(item.id, null);
    }
  }
}
