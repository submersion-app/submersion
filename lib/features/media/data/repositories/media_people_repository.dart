import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';

/// People tagged on photos and videos: the `media_people` table (v326,
/// issue #1745).
///
/// A row is a buddy or the diver themself ("Me"), with an optional face box
/// and, on a video, the paused frame it was drawn on. Rows are edited after
/// they are written, so every write stamps `updated_at` and marks the row
/// pending; removing a tag tombstones it by id.
///
/// Every read is scoped to the viewing diver: a profile sees its own Me tags
/// and the tags of its own buddies, never another profile's, even on media
/// every profile can see. A null diver id means no scoping.
class MediaPeopleRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const Uuid _uuid = Uuid();

  /// Bound-variable budget per `isIn` chunk, well under SQLite's 999 limit.
  static const int _chunkSize = 500;

  static const String _entityType = 'mediaPeople';

  /// Ticks whenever `media_people` changes, from any writer.
  Stream<void> watchTagChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.mediaPeople));

  /// The tags on [mediaId] that [diverId] owns, Me first, then buddies by
  /// name, then by moment.
  Future<List<MediaPersonTag>> getTagsForMedia(
    String mediaId, {
    required String? diverId,
  }) async => [
    for (final chip in await getChipsForMedia(mediaId, diverId: diverId))
      chip.tag,
  ];

  /// The tags on [mediaId] that [diverId] owns, with each buddy's name, in
  /// the order [getTagsForMedia] documents.
  Future<List<MediaPersonChip>> getChipsForMedia(
    String mediaId, {
    required String? diverId,
  }) async {
    final p = _db.mediaPeople;
    final b = _db.buddies;
    final query =
        _db.select(p).join([
            leftOuterJoin(b, b.id.equalsExp(p.buddyId), useColumns: false),
          ])
          ..addColumns([b.name])
          ..where(
            p.mediaId.equals(mediaId) & _namesSomeone & _ownedBy(diverId),
          );
    final chips = [
      for (final row in await query.get())
        MediaPersonChip(
          tag: _tagFromRow(row.readTable(p)),
          buddyName: row.read(b.name),
        ),
    ];
    chips.sort(_compareChips);
    return chips;
  }

  /// Tags [mediaId] with a buddy ([buddyId]) or the diver ([diverId]):
  /// exactly one of them.
  ///
  /// On a photo a person appears once, so tagging someone already tagged
  /// moves their existing box rather than adding a second row, and a tag
  /// without a spot leaves an existing box alone. On a video every boxed
  /// call adds a row, one per moment, but a person has at most one tag
  /// without a spot, and tagging someone again within
  /// [faceTagMomentWindow] of one of their moments moves that tag.
  Future<MediaPersonTag> addTag({
    required String mediaId,
    String? buddyId,
    String? diverId,
    FaceBox? box,
    Duration? videoPosition,
  }) async {
    if ((buddyId == null) == (diverId == null)) {
      throw ArgumentError('A tag names exactly one of buddyId and diverId');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final isVideo = await _isVideo(mediaId);
    final existing = await _findDuplicate(
      mediaId,
      buddyId: buddyId,
      diverId: diverId,
      isVideo: isVideo,
      positionMs: videoPosition?.inMilliseconds,
      hasBox: box != null,
    );
    if (existing != null) {
      // A tag without a spot adds nothing to the person's tag there.
      if (box == null) return _tagFromRow(existing);
      final moved = _tagFromRow(existing).copyWith(
        box: box,
        videoPosition: isVideo ? videoPosition : null,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
      await updateTag(moved);
      return moved;
    }

    final id = _uuid.v4();
    await _db
        .into(_db.mediaPeople)
        .insert(
          MediaPeopleCompanion(
            id: Value(id),
            mediaId: Value(mediaId),
            buddyId: Value(buddyId),
            diverId: Value(diverId),
            bboxX: Value(box?.x),
            bboxY: Value(box?.y),
            bboxWidth: Value(box?.width),
            bboxHeight: Value(box?.height),
            videoPositionMs: Value(videoPosition?.inMilliseconds),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: _entityType,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    final at = DateTime.fromMillisecondsSinceEpoch(now);
    return MediaPersonTag(
      id: id,
      mediaId: mediaId,
      buddyId: buddyId,
      diverId: diverId,
      box: box,
      videoPosition: videoPosition,
      createdAt: at,
      updatedAt: at,
    );
  }

  /// Writes [tag]'s person, box and moment over the stored row, stamped with
  /// the later of [MediaPersonTag.updatedAt] and now.
  ///
  /// The person rules [addTag] keeps hold here too ([isDuplicatePersonTag]):
  /// re-assigning or moving a tag onto another of the same person's tags
  /// removes that other tag, so the edited one is theirs. On a photo, an
  /// edited tag without a box takes the removed tag's box rather than
  /// losing it.
  Future<void> updateTag(MediaPersonTag tag) async {
    if ((tag.buddyId == null) == (tag.diverId == null)) {
      throw ArgumentError('A tag names exactly one of buddyId and diverId');
    }
    final now = max(
      DateTime.now().millisecondsSinceEpoch,
      tag.updatedAt.millisecondsSinceEpoch,
    );
    final box = tag.box;
    await (_db.update(
      _db.mediaPeople,
    )..where((t) => t.id.equals(tag.id))).write(
      MediaPeopleCompanion(
        buddyId: Value(tag.buddyId),
        diverId: Value(tag.diverId),
        bboxX: Value(box?.x),
        bboxY: Value(box?.y),
        bboxWidth: Value(box?.width),
        bboxHeight: Value(box?.height),
        videoPositionMs: Value(tag.videoPosition?.inMilliseconds),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: _entityType,
      recordId: tag.id,
      localUpdatedAt: now,
    );
    await _collapseDuplicates(tag, now);
    SyncEventBus.notifyLocalChange();
  }

  /// Removes the tag [tagId], tombstoning it so other devices drop it too.
  /// No-op when absent.
  Future<void> removeTag(String tagId) async {
    final deleted = await (_db.delete(
      _db.mediaPeople,
    )..where((t) => t.id.equals(tagId))).go();
    if (deleted == 0) return;
    await _syncRepository.logDeletion(entityType: _entityType, recordId: tagId);
    SyncEventBus.notifyLocalChange();
  }

  /// The ids of the buddies tagged on at least one photo or video, scoped to
  /// [diverId]'s own buddies like every read here.
  Future<Set<String>> getTaggedBuddyIds({required String? diverId}) async {
    final p = _db.mediaPeople;
    final rows =
        await (_db.selectOnly(p, distinct: true)
              ..addColumns([p.buddyId])
              ..where(p.buddyId.isNotNull() & _ownedBy(diverId)))
            .get();
    return {for (final row in rows) row.read(p.buddyId)!};
  }

  /// Every photo and video [buddyId] is tagged in, newest first, once each.
  ///
  /// Scoped to [diverId] through the media's dive while keeping media with
  /// no dive, the library's own rule.
  Future<List<MediaItem>> getMediaForBuddy(
    String buddyId, {
    required String? diverId,
  }) async {
    final m = _db.media;
    final query =
        _db.select(m, distinct: true).join([
            innerJoin(
              _db.mediaPeople,
              _db.mediaPeople.mediaId.equalsExp(m.id),
              useColumns: false,
            ),
            leftOuterJoin(
              _db.mediaEnrichment,
              _db.mediaEnrichment.mediaId.equalsExp(m.id),
            ),
            leftOuterJoin(
              _db.dives,
              _db.dives.id.equalsExp(m.diveId),
              useColumns: false,
            ),
          ])
          ..where(
            _db.mediaPeople.buddyId.equals(buddyId) & _diverScope(diverId),
          )
          ..orderBy([
            OrderingTerm.desc(coalesce([m.takenAt, m.createdAt])),
            OrderingTerm.asc(m.id),
          ]);
    final rows = await query.get();
    return rows
        .map(
          (row) => mediaItemFromRow(
            row.readTable(m),
            row.readTableOrNull(_db.mediaEnrichment),
          ),
        )
        .toList();
  }

  /// Deletes and tombstones every tag on [mediaIds]. Runs inside the
  /// caller's transaction and does not notify.
  Future<void> deleteForMedia(List<String> mediaIds) =>
      _deleteWhere(mediaIds, (t, chunk) => t.mediaId.isIn(chunk));

  /// Deletes and tombstones every tag of [buddyIds]. Runs inside the
  /// caller's transaction and does not notify.
  Future<void> deleteForBuddies(List<String> buddyIds) =>
      _deleteWhere(buddyIds, (t, chunk) => t.buddyId.isIn(chunk));

  Future<void> _deleteWhere(
    List<String> keys,
    Expression<bool> Function($MediaPeopleTable t, List<String> chunk) where,
  ) async {
    for (var i = 0; i < keys.length; i += _chunkSize) {
      final chunk = keys.sublist(i, min(i + _chunkSize, keys.length));
      final ids =
          await (_db.selectOnly(_db.mediaPeople)
                ..addColumns([_db.mediaPeople.id])
                ..where(where(_db.mediaPeople, chunk)))
              .map((row) => row.read(_db.mediaPeople.id)!)
              .get();
      if (ids.isEmpty) continue;
      // By the same chunked predicate, not by the ids: one buddy can have
      // more tags than a single IN (...) may bind.
      await (_db.delete(_db.mediaPeople)..where((t) => where(t, chunk))).go();
      await _syncRepository.logDeletions(
        entityType: _entityType,
        recordIds: ids,
      );
    }
  }

  /// A row naming nobody (a peer cleared a dangling person reference)
  /// is not a tag: hidden rather than drawn as an empty chip.
  Expression<bool> get _namesSomeone =>
      _db.mediaPeople.buddyId.isNotNull() | _db.mediaPeople.diverId.isNotNull();

  /// Rows [diverId] owns: its own Me tags and its own buddies' tags.
  Expression<bool> _ownedBy(String? diverId) {
    if (diverId == null) return const Constant(true);
    final p = _db.mediaPeople;
    return p.diverId.equals(diverId) |
        p.buddyId.isInQuery(
          _db.selectOnly(_db.buddies)
            ..addColumns([_db.buddies.id])
            ..where(_db.buddies.diverId.equals(diverId)),
        );
  }

  Expression<bool> _diverScope(String? diverId) {
    if (diverId == null) return const Constant(true);
    return _db.media.diveId.isNull() | _db.dives.diverId.equals(diverId);
  }

  Future<bool> _isVideo(String mediaId) async {
    final row =
        await (_db.selectOnly(_db.media)
              ..addColumns([_db.media.fileType])
              ..where(_db.media.id.equals(mediaId)))
            .getSingleOrNull();
    return row?.read(_db.media.fileType) ==
        mediaTypeToDbString(MediaType.video);
  }

  /// Every other tag of [tag]'s person on its media item that duplicates
  /// it, per [isDuplicatePersonTag], deleted and tombstoned. On a photo the
  /// edited tag first takes a duplicate's box when it has none.
  Future<void> _collapseDuplicates(MediaPersonTag tag, int now) async {
    final isVideo = await _isVideo(tag.mediaId);
    final p = _db.mediaPeople;
    final duplicates = [
      for (final row
          in await (_db.select(p)..where(
                (r) =>
                    r.mediaId.equals(tag.mediaId) &
                    r.id.equals(tag.id).not() &
                    _samePerson(r, tag.buddyId, tag.diverId),
              ))
              .get())
        if (_duplicates(
          row,
          isVideo: isVideo,
          positionMs: tag.videoPosition?.inMilliseconds,
          hasBox: tag.box != null,
        ))
          row,
    ];
    if (duplicates.isEmpty) return;
    final boxed = duplicates.where((r) => r.bboxX != null).firstOrNull;
    if (!isVideo && tag.box == null && boxed != null) {
      await (_db.update(p)..where((r) => r.id.equals(tag.id))).write(
        MediaPeopleCompanion(
          bboxX: Value(boxed.bboxX),
          bboxY: Value(boxed.bboxY),
          bboxWidth: Value(boxed.bboxWidth),
          bboxHeight: Value(boxed.bboxHeight),
          updatedAt: Value(now),
        ),
      );
    }
    for (final other in duplicates) {
      await (_db.delete(p)..where((r) => r.id.equals(other.id))).go();
      await _syncRepository.logDeletion(
        entityType: _entityType,
        recordId: other.id,
      );
    }
  }

  /// A tag of the person on [mediaId] that a new tag with [hasBox] and
  /// [positionMs] would duplicate, per [isDuplicatePersonTag].
  Future<MediaPeopleData?> _findDuplicate(
    String mediaId, {
    required String? buddyId,
    required String? diverId,
    required bool isVideo,
    required int? positionMs,
    required bool hasBox,
  }) async {
    final rows =
        await (_db.select(_db.mediaPeople)..where(
              (t) =>
                  t.mediaId.equals(mediaId) & _samePerson(t, buddyId, diverId),
            ))
            .get();
    for (final row in rows) {
      if (_duplicates(
        row,
        isVideo: isVideo,
        positionMs: positionMs,
        hasBox: hasBox,
      )) {
        return row;
      }
    }
    return null;
  }

  static bool _duplicates(
    MediaPeopleData row, {
    required bool isVideo,
    required int? positionMs,
    required bool hasBox,
  }) => isDuplicatePersonTag(
    isVideo: isVideo,
    aPositionMs: row.videoPositionMs,
    aHasBox: row.bboxX != null,
    bPositionMs: positionMs,
    bHasBox: hasBox,
  );

  Expression<bool> _samePerson(
    $MediaPeopleTable t,
    String? buddyId,
    String? diverId,
  ) => buddyId != null ? t.buddyId.equals(buddyId) : t.diverId.equals(diverId!);

  static int _compareChips(MediaPersonChip a, MediaPersonChip b) {
    if (a.tag.isMe != b.tag.isMe) return a.tag.isMe ? -1 : 1;
    final byName = (a.buddyName ?? '').toLowerCase().compareTo(
      (b.buddyName ?? '').toLowerCase(),
    );
    if (byName != 0) return byName;
    final byPerson = (a.tag.buddyId ?? a.tag.diverId ?? '').compareTo(
      b.tag.buddyId ?? b.tag.diverId ?? '',
    );
    if (byPerson != 0) return byPerson;
    final at = a.tag.videoPosition?.inMilliseconds ?? -1;
    final bt = b.tag.videoPosition?.inMilliseconds ?? -1;
    if (at != bt) return at.compareTo(bt);
    return a.tag.createdAt.compareTo(b.tag.createdAt);
  }

  MediaPersonTag _tagFromRow(MediaPeopleData row) {
    final x = row.bboxX;
    final y = row.bboxY;
    final w = row.bboxWidth;
    final h = row.bboxHeight;
    final ms = row.videoPositionMs;
    return MediaPersonTag(
      id: row.id,
      mediaId: row.mediaId,
      buddyId: row.buddyId,
      diverId: row.diverId,
      box: x == null || y == null || w == null || h == null
          ? null
          : FaceBox(x: x, y: y, width: w, height: h),
      videoPosition: ms == null ? null : Duration(milliseconds: ms),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}
