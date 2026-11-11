import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
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
  /// the gallery, which also reads items: their names and which of them the
  /// diver may see. The photo lists and covers do not, so an unrelated gear
  /// edit does not re-read them.
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
    final t = _db.equipmentObservations;
    final living = <String>{};
    // Chunked for SQLite's bound-variable limit: a gallery can hold a
    // great many check-in photos.
    for (final chunk in seriesIdChunks([
      ...{for (final m in photos) ?m.observationId},
    ])) {
      final rows =
          await (_db.selectOnly(t)
                ..addColumns([t.id])
                ..where(t.id.isIn(chunk)))
              .get();
      living.addAll(rows.map((r) => r.read(t.id)!));
    }
    return living;
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

  /// The Equipment gallery: photos of every item [diverId] may see (every
  /// item for a null [diverId]), grouped by item, the item with the newest
  /// photo first. Scoped by the same rule as the Library's Equipment pick
  /// ([VisibilityFilter.visibleEquipmentIds]), which also leaves out a row
  /// naming an item this device lacks (a peer's delete not yet reconciled),
  /// since it has no page to open.
  Future<List<GearPhotoGroup>> gearGallery({String? diverId}) async {
    final rows = await _photosOf(
      (t) => VisibilityFilter.visibleEquipmentIds(_db, t.equipmentId, diverId),
    );
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
    final names = <String, String>{};
    for (final chunk in seriesIdChunks(byItem.keys.toList())) {
      for (final row in await (_db.select(
        _db.equipment,
      )..where((t) => t.id.isIn(chunk))).get()) {
        names[row.id] = row.name;
      }
    }
    // Insertion order follows the photos' newest-first order.
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

  /// The photo [coverId] that [equipmentId] names as its cover, or null when
  /// the row is not on this device, is not a photo (a cover is a still,
  /// never a video), or is no longer one of this item's identification
  /// photos. The caller holds the item, so its cover id is
  /// passed in rather than read again.
  Future<MediaItem?> coverFor(String equipmentId, String coverId) =>
      _coverCandidate(equipmentId, coverId);

  /// [mediaId] when it may stand for [equipmentId]: a photo on this device,
  /// linked to this item, backing none of its check-ins. The one rule both
  /// [setCover] and [coverFor] apply, so what is saved is what is shown.
  Future<MediaItem?> _coverCandidate(String equipmentId, String mediaId) async {
    final row = await (_db.select(
      _db.media,
    )..where((t) => t.id.equals(mediaId))).getSingleOrNull();
    if (row == null) return null;
    final media = mediaItemFromRow(row);
    final belongs =
        media.isGearPhoto &&
        media.mediaType == MediaType.photo &&
        media.equipmentId == equipmentId &&
        (await _existingCheckIns([media])).isEmpty;
    return belongs ? media : null;
  }

  /// Chooses [mediaId] as the photo that stands for [equipmentId], or clears
  /// the choice when null. A targeted write: the edit form's save never
  /// touches this column. Throws a [StateError] when the item is gone (a
  /// peer's delete arriving mid-tap), so nothing is marked for sync and the
  /// caller can say the cover did not change, and an [ArgumentError] for a
  /// row that cannot stand for the item: a video, a check-in's photo,
  /// another item's photo or one not on this device. Readers would ignore
  /// such a cover anyway; refusing it keeps it from being synced.
  Future<void> setCover(String equipmentId, String? mediaId) async {
    if (mediaId != null &&
        await _coverCandidate(equipmentId, mediaId) == null) {
      throw ArgumentError.value(
        mediaId,
        'mediaId',
        'not an identification photo of $equipmentId',
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      final written =
          await (_db.update(
            _db.equipment,
          )..where((t) => t.id.equals(equipmentId))).write(
            EquipmentCompanion(
              coverMediaId: Value(mediaId),
              updatedAt: Value(now),
            ),
          );
      if (written == 0) {
        throw StateError('No equipment $equipmentId to set a cover on');
      }
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
    for (final chunk in seriesIdChunks(mediaIds.toSet().toList())) {
      final items = await (_db.select(
        _db.equipment,
      )..where((t) => t.coverMediaId.isIn(chunk))).get();
      for (final item in items) {
        await setCover(item.id, null);
      }
    }
  }
}
