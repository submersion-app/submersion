import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;

/// Writes the diver's hand colour adjustments (issue #3520).
///
/// Narrow writers, like `SiteAttachmentRepository`: each writes only the
/// colour column plus updatedAt and takes the row clock, so a stale
/// snapshot cannot roll back anything else on the row. The adjustment is
/// display-only and never touches the file. Kept out of MediaRepository,
/// which is past the file-size ceiling.
class MediaColorAdjustmentRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(MediaColorAdjustmentRepository);

  /// A cleared adjustment is stored as the neutral value, never NULL: media
  /// rows merge through an upsert that leaves a null column unwritten (so a
  /// peer on an older build cannot erase a column it does not know), which
  /// would keep a Reset from ever reaching the diver's other devices. The
  /// neutral value reads back as no adjustment.
  static String _encode(ColorAdjustment? a) =>
      (a ?? const ColorAdjustment()).toJsonString();

  /// Saves [adjustment] on media row [mediaId]; null or neutral clears it.
  ///
  /// Throws [StateError] when the row no longer exists, so the caller can
  /// report a failure rather than queue a sync record for a missing row.
  Future<void> setColorAdjustment(
    String mediaId,
    ColorAdjustment? adjustment,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        final written = await _write(mediaId, adjustment, now);
        if (written == 0) {
          throw StateError('Media $mediaId no longer exists');
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set color adjustment for media: $mediaId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Gives every other photo and video on [diveId] the Auto switch and
  /// sliders of [source], keeping each one's own white point (a white
  /// point only holds for the photo it was picked on). Documents and
  /// signatures are left alone. One transaction.
  ///
  /// Returns each changed row's previous adjustment, keyed by media id, for
  /// [restoreColorAdjustments] (Undo).
  Future<Map<String, ColorAdjustment?>> applySlidersToDive({
    required String diveId,
    required String sourceMediaId,
    required ColorAdjustment source,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final prior = await _db.transaction(() async {
        final rows = await _siblings(diveId, sourceMediaId).get();
        final previous = <String, ColorAdjustment?>{};
        for (final row in rows) {
          final before = ColorAdjustment.fromJsonString(row.colorAdjustment);
          final after = (before ?? const ColorAdjustment()).withSlidersFrom(
            source,
          );
          // A row that already matches is left alone: no write, no sync
          // record, and not counted as changed.
          if ((after.isNeutral ? null : after) == before) continue;
          previous[row.id] = before;
          await _write(row.id, after, now);
        }
        return previous;
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Applied color adjustment to ${prior.length} on $diveId');
      return prior;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to apply color adjustment across dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Puts back the adjustments [prior] recorded. Rows deleted since are
  /// skipped.
  Future<void> restoreColorAdjustments(
    Map<String, ColorAdjustment?> prior,
  ) async {
    if (prior.isEmpty) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        for (final MapEntry(key: id, value: adjustment) in prior.entries) {
          await _write(id, adjustment, now);
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to restore ${prior.length} color adjustments',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The profile match stored for [mediaId], for a tile drawn from a row
  /// that was read without it (the library's lean rows), so the automatic
  /// fix gets the same depth and surface check there as in the dive.
  Future<domain.MediaEnrichment?> enrichmentFor(String mediaId) =>
      MediaRepository().getEnrichmentForMedia(mediaId);

  /// Ticks when a profile match is written (a re-match, a backfill, a sync
  /// pull), the only writes that change [enrichmentFor]'s answer. Narrower
  /// than MediaRepository.watchMediaChanges, which also ticks on every
  /// caption, upload stamp and colour save, each of which would re-query
  /// the match of every library tile on screen.
  Stream<void> watchEnrichmentChanges() => _db
      .tableUpdates(TableUpdateQuery.onTable(_db.mediaEnrichment))
      .debounce(MediaRepository.changeTickDebounce);

  /// How many photos and videos "Apply to this dive" would change.
  Future<int> countOtherMediaOnDive(
    String diveId,
    String excludeMediaId,
  ) async => (await _siblings(diveId, excludeMediaId).get()).length;

  SimpleSelectStatement<$MediaTable, MediaData> _siblings(
    String diveId,
    String excludeMediaId,
  ) => _db.select(_db.media)
    ..where(
      (t) =>
          t.diveId.equals(diveId) &
          t.id.equals(excludeMediaId).not() &
          t.fileType.isIn([
            mediaTypeToDbString(domain.MediaType.photo),
            mediaTypeToDbString(domain.MediaType.video),
          ]),
    );

  /// Writes one row's column and queues it for sync; returns rows written.
  Future<int> _write(String id, ColorAdjustment? adjustment, int now) async {
    final written = await (_db.update(_db.media)..where((t) => t.id.equals(id)))
        .write(
          MediaCompanion(
            colorAdjustment: Value(_encode(adjustment)),
            updatedAt: Value(now),
          ),
        );
    if (written > 0) {
      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    return written;
  }
}
