import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

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

  /// Ticks when gear photos or an item's name or cover can have changed:
  /// the media rows themselves and the equipment rows the gallery names and
  /// the cover lives on.
  Stream<void> watchGearPhotoChanges() => _db
      .tableUpdates(TableUpdateQuery.onAllTables([_db.media, _db.equipment]))
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
  Future<List<MediaItem>> identificationPhotos(String equipmentId) async => [
    for (final item in await _photosOf(
      (t) => t.equipmentId.equals(equipmentId),
    ))
      if (item.observationId == null) item,
  ];

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
    final byObservation = <String, List<MediaItem>>{};
    for (final item in await _photosOf(
      (t) => t.equipmentId.equals(equipmentId) & t.observationId.isNotNull(),
    )) {
      (byObservation[item.observationId!] ??= []).add(item);
    }
    return byObservation;
  }

  /// Every item holding at least one gear photo, for the gallery's
  /// visibility check.
  Future<Set<String>> equipmentIdsWithPhotos() async => {
    for (final item in await _photosOf((t) => t.equipmentId.isNotNull()))
      item.equipmentId!,
  };

  /// The Gear gallery: photos of every item in [equipmentIds], grouped by
  /// item, the item with the newest photo first. The caller passes the ids
  /// the viewing diver may see.
  Future<List<GearPhotoGroup>> gearGallery(Set<String> equipmentIds) async {
    if (equipmentIds.isEmpty) return const [];
    final photos = await _photosOf((t) => t.equipmentId.isIn(equipmentIds));
    if (photos.isEmpty) return const [];
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
    // Insertion order follows the photos' newest-first order.
    return [
      for (final MapEntry(:key, :value) in byItem.entries)
        GearPhotoGroup(equipmentId: key, name: names[key] ?? '', items: value),
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
      if (item.filePath case final path? when path.isNotEmpty) path,
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
        media.observationId == null;
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
