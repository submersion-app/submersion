import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// What a buddy merge did to people tags (issue #1745), so its undo can put
/// them back: each repointed tag's original buddy, and the duplicates the
/// merge removed because the survivor was already tagged on that photo.
class MediaPeopleMergeSnapshot {
  final Map<String, String> originalBuddyIds;
  final List<MediaPeopleData> removedDuplicates;

  /// Smart album id -> its filter JSON before [repointSmartAlbumBuddies].
  final Map<String, String> albumFilters;

  const MediaPeopleMergeSnapshot({
    this.originalBuddyIds = const {},
    this.removedDuplicates = const [],
    this.albumFilters = const {},
  });

  MediaPeopleMergeSnapshot withAlbumFilters(Map<String, String> filters) =>
      MediaPeopleMergeSnapshot(
        originalBuddyIds: originalBuddyIds,
        removedDuplicates: removedDuplicates,
        albumFilters: filters,
      );
}

/// Moves the people tags of [fromBuddyIds] to [toBuddyId] for a buddy merge
/// that is about to delete [fromBuddyIds]. Without it their tags would go
/// with them on the foreign-key cascade, silently and without tombstones.
///
/// A photo shows a person once, so where the survivor (or another merged
/// buddy) is already tagged on a photo, the extra tag is deleted and
/// tombstoned instead. Every moment on a video is kept. Runs inside the
/// caller's transaction and does not notify.
Future<MediaPeopleMergeSnapshot> repointMediaPeopleForMerge(
  AppDatabase db,
  SyncRepository syncRepository, {
  required List<String> fromBuddyIds,
  required String toBuddyId,
  required int now,
}) async {
  if (fromBuddyIds.isEmpty) return const MediaPeopleMergeSnapshot();
  final p = db.mediaPeople;
  final moving = await (db.select(
    p,
  )..where((t) => t.buddyId.isIn(fromBuddyIds))).get();
  if (moving.isEmpty) return const MediaPeopleMergeSnapshot();

  final mediaIds = {for (final r in moving) r.mediaId};
  final videos = {
    for (final row
        in await (db.selectOnly(db.media)
              ..addColumns([db.media.id])
              ..where(
                db.media.id.isIn(mediaIds) &
                    db.media.fileType.equals(
                      mediaTypeToDbString(MediaType.video),
                    ),
              ))
            .get())
      row.read(db.media.id)!,
  };
  // Photos the survivor is already on, filled as tags move onto it.
  final survivorPhotos = {
    for (final r in await (db.select(
      p,
    )..where((t) => t.buddyId.equals(toBuddyId))).get())
      if (!videos.contains(r.mediaId)) r.mediaId,
  };

  final original = <String, String>{};
  final removed = <MediaPeopleData>[];
  for (final row in moving) {
    final isPhoto = !videos.contains(row.mediaId);
    if (isPhoto && survivorPhotos.contains(row.mediaId)) {
      await (db.delete(p)..where((t) => t.id.equals(row.id))).go();
      await syncRepository.logDeletion(
        entityType: 'mediaPeople',
        recordId: row.id,
      );
      removed.add(row);
      continue;
    }
    await (db.update(p)..where((t) => t.id.equals(row.id))).write(
      MediaPeopleCompanion(buddyId: Value(toBuddyId), updatedAt: Value(now)),
    );
    await syncRepository.markRecordPending(
      entityType: 'mediaPeople',
      recordId: row.id,
      localUpdatedAt: now,
    );
    original[row.id] = row.buddyId!;
    if (isPhoto) survivorPhotos.add(row.mediaId);
  }
  return MediaPeopleMergeSnapshot(
    originalBuddyIds: original,
    removedDuplicates: removed,
  );
}

/// Reverses [repointMediaPeopleForMerge] once the merged buddies exist
/// again: repointed tags go back to their buddy and removed duplicates are
/// re-inserted under their own ids, their tombstones dropped, and repointed
/// smart albums get their filters back. Runs inside the caller's
/// transaction and does not notify.
Future<void> undoMediaPeopleMerge(
  AppDatabase db,
  SyncRepository syncRepository,
  MediaPeopleMergeSnapshot snapshot, {
  required int now,
}) async {
  final p = db.mediaPeople;
  for (final MapEntry(key: id, value: buddyId)
      in snapshot.originalBuddyIds.entries) {
    await (db.update(p)..where((t) => t.id.equals(id))).write(
      MediaPeopleCompanion(buddyId: Value(buddyId), updatedAt: Value(now)),
    );
    await syncRepository.markRecordPending(
      entityType: 'mediaPeople',
      recordId: id,
      localUpdatedAt: now,
    );
  }
  for (final MapEntry(key: id, value: filterJson)
      in snapshot.albumFilters.entries) {
    await (db.update(db.mediaSmartAlbums)..where((t) => t.id.equals(id))).write(
      MediaSmartAlbumsCompanion(
        filterJson: Value(filterJson),
        updatedAt: Value(now),
      ),
    );
    await syncRepository.markRecordPending(
      entityType: 'mediaSmartAlbums',
      recordId: id,
      localUpdatedAt: now,
    );
  }
  for (final row in snapshot.removedDuplicates) {
    final inserted = await db
        .into(p)
        .insertReturningOrNull(
          row.copyWith(updatedAt: now),
          onConflict: DoNothing<$MediaPeopleTable, MediaPeopleData>(
            target: const [],
          ),
        );
    if (inserted == null) continue;
    await syncRepository.removeDeletion(
      entityType: 'mediaPeople',
      recordId: row.id,
    );
    await syncRepository.markRecordPending(
      entityType: 'mediaPeople',
      recordId: row.id,
      localUpdatedAt: now,
    );
  }
}

/// Rewrites every saved smart album whose filter names one of
/// [fromBuddyIds] to name [toBuddyId] instead (issue #1745), the people
/// twin of `repointSmartAlbumTags`. Keys this build does not know are kept.
/// Each rewritten album is stamped and marked pending. Returns each
/// rewritten album's previous filter JSON, for an undo. Runs inside the
/// caller's transaction and does not notify.
Future<Map<String, String>> repointSmartAlbumBuddies(
  AppDatabase db,
  SyncRepository syncRepository, {
  required List<String> fromBuddyIds,
  required String toBuddyId,
  required int now,
}) async {
  final from = fromBuddyIds.toSet();
  final previous = <String, String>{};
  for (final row in await db.select(db.mediaSmartAlbums).get()) {
    final Object? decoded;
    try {
      decoded = jsonDecode(row.filterJson);
    } on FormatException {
      continue;
    }
    if (decoded is! Map<String, dynamic>) continue;
    final filter = MediaLibraryFilter.fromJson(decoded);
    if (!filter.buddyIds.any(from.contains)) continue;
    previous[row.id] = row.filterJson;
    final repointed = filter.copyWith(
      buddyIds: {
        for (final id in filter.buddyIds) from.contains(id) ? toBuddyId : id,
      },
    );
    await (db.update(
      db.mediaSmartAlbums,
    )..where((t) => t.id.equals(row.id))).write(
      MediaSmartAlbumsCompanion(
        filterJson: Value(jsonEncode({...decoded, ...repointed.toJson()})),
        updatedAt: Value(now),
      ),
    );
    await syncRepository.markRecordPending(
      entityType: 'mediaSmartAlbums',
      recordId: row.id,
      localUpdatedAt: now,
    );
  }
  return previous;
}
