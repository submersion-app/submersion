import 'dart:math';

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/data/repositories/smart_album_tag_repoint.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';

/// What a buddy merge did to people tags (issue #1745), so its undo can put
/// them back: each repointed tag's original buddy, the duplicates the merge
/// removed because the survivor was already tagged there, and the
/// survivor's tags as they were before a duplicate's box moved onto them.
class MediaPeopleMergeSnapshot {
  final Map<String, String> originalBuddyIds;
  final List<MediaPeopleData> removedDuplicates;
  final List<MediaPeopleData> boxedSurvivors;

  /// Smart album id -> its filter JSON before [repointSmartAlbumBuddies].
  final Map<String, String> albumFilters;

  const MediaPeopleMergeSnapshot({
    this.originalBuddyIds = const {},
    this.removedDuplicates = const [],
    this.boxedSurvivors = const [],
    this.albumFilters = const {},
  });

  MediaPeopleMergeSnapshot withAlbumFilters(Map<String, String> filters) =>
      MediaPeopleMergeSnapshot(
        originalBuddyIds: originalBuddyIds,
        removedDuplicates: removedDuplicates,
        boxedSurvivors: boxedSurvivors,
        albumFilters: filters,
      );
}

/// Bound-variable budget per `isIn` chunk, well under SQLite's 999 limit.
const int _chunkSize = 500;

/// Moves the people tags of [fromBuddyIds] to [toBuddyId] for a buddy merge
/// that is about to delete [fromBuddyIds]. Without it their tags would go
/// with them on the foreign-key cascade, silently and without tombstones.
///
/// The person rules `MediaPeopleRepository.addTag` keeps hold here too.
/// A photo shows a person once: where the survivor is already tagged there,
/// the duplicate is deleted and tombstoned, and if only the duplicate had a
/// box, the box moves onto the survivor's tag first. On a video every
/// moment is kept, but a duplicate without a spot, or within
/// [faceTagMomentWindow] of a survivor's moment, collapses into the
/// survivor's tag. Runs inside the caller's transaction and does not notify.
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

  // Chunked: a buddy can be on more media than one IN (...) may bind.
  final mediaIds = [
    ...{for (final r in moving) r.mediaId},
  ];
  final videos = <String>{};
  final survivor = <String, List<MediaPeopleData>>{};
  for (var i = 0; i < mediaIds.length; i += _chunkSize) {
    final chunk = mediaIds.sublist(i, min(i + _chunkSize, mediaIds.length));
    videos.addAll(
      await (db.selectOnly(db.media)
            ..addColumns([db.media.id])
            ..where(
              db.media.id.isIn(chunk) &
                  db.media.fileType.equals(
                    mediaTypeToDbString(MediaType.video),
                  ),
            ))
          .map((row) => row.read(db.media.id)!)
          .get(),
    );
    // The survivor's tags per media item, kept current as tags move onto it.
    for (final r
        in await (db.select(p)..where(
              (t) => t.buddyId.equals(toBuddyId) & t.mediaId.isIn(chunk),
            ))
            .get()) {
      survivor.putIfAbsent(r.mediaId, () => []).add(r);
    }
  }

  final original = <String, String>{};
  final removed = <MediaPeopleData>[];
  final boxed = <MediaPeopleData>[];
  for (final row in moving) {
    final isVideo = videos.contains(row.mediaId);
    final mine = survivor.putIfAbsent(row.mediaId, () => []);
    final keeper = mine.where((s) => _sameTag(s, row, isVideo)).firstOrNull;
    if (keeper == null) {
      await (db.update(p)..where((t) => t.id.equals(row.id))).write(
        MediaPeopleCompanion(buddyId: Value(toBuddyId), updatedAt: Value(now)),
      );
      await syncRepository.markRecordPending(
        entityType: 'mediaPeople',
        recordId: row.id,
        localUpdatedAt: now,
      );
      original[row.id] = row.buddyId!;
      mine.add(row.copyWith(buddyId: Value(toBuddyId)));
      continue;
    }
    if (!isVideo && keeper.bboxX == null && row.bboxX != null) {
      // Only the duplicate marked the face: keep its box.
      boxed.add(keeper);
      final withBox = keeper.copyWith(
        bboxX: Value(row.bboxX),
        bboxY: Value(row.bboxY),
        bboxWidth: Value(row.bboxWidth),
        bboxHeight: Value(row.bboxHeight),
        updatedAt: now,
      );
      await (db.update(p)..where((t) => t.id.equals(keeper.id))).write(
        withBox.toCompanion(false),
      );
      await syncRepository.markRecordPending(
        entityType: 'mediaPeople',
        recordId: keeper.id,
        localUpdatedAt: now,
      );
      mine[mine.indexOf(keeper)] = withBox;
    }
    await (db.delete(p)..where((t) => t.id.equals(row.id))).go();
    await syncRepository.logDeletion(
      entityType: 'mediaPeople',
      recordId: row.id,
    );
    removed.add(row);
  }
  return MediaPeopleMergeSnapshot(
    originalBuddyIds: original,
    removedDuplicates: removed,
    boxedSurvivors: boxed,
  );
}

/// Whether [moving] duplicates the survivor's tag [kept]: on a photo any
/// tag of the person; on a video both without a spot, or both moments
/// within [faceTagMomentWindow].
bool _sameTag(MediaPeopleData kept, MediaPeopleData moving, bool isVideo) =>
    isDuplicatePersonTag(
      isVideo: isVideo,
      aPositionMs: kept.videoPositionMs,
      aHasBox: kept.bboxX != null,
      bPositionMs: moving.videoPositionMs,
      bHasBox: moving.bboxX != null,
    );

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
  // Only the box goes back: a survivor tag may itself be a tag the merge
  // moved, whose buddy the loop above has just restored.
  for (final row in snapshot.boxedSurvivors) {
    await (db.update(p)..where((t) => t.id.equals(row.id))).write(
      MediaPeopleCompanion(
        bboxX: Value(row.bboxX),
        bboxY: Value(row.bboxY),
        bboxWidth: Value(row.bboxWidth),
        bboxHeight: Value(row.bboxHeight),
        updatedAt: Value(now),
      ),
    );
    await syncRepository.markRecordPending(
      entityType: 'mediaPeople',
      recordId: row.id,
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
/// twin of `repointSmartAlbumTags`. Returns each rewritten album's previous
/// filter JSON, for an undo. Runs inside the caller's transaction and does
/// not notify.
Future<Map<String, String>> repointSmartAlbumBuddies(
  AppDatabase db,
  SyncRepository syncRepository, {
  required List<String> fromBuddyIds,
  required String toBuddyId,
  required int now,
}) {
  final from = fromBuddyIds.toSet();
  return repointSmartAlbums(
    db,
    syncRepository,
    names: (filter) => filter.buddyIds.any(from.contains),
    repoint: (filter) => filter.copyWith(
      buddyIds: {
        for (final id in filter.buddyIds) from.contains(id) ? toBuddyId : id,
      },
    ),
    now: now,
  );
}
