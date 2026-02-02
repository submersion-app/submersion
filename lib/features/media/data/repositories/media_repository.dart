import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;

class MediaRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(MediaRepository);

  /// Get all media for a dive, ordered by takenAt
  /// Includes enrichment data (depth, temperature) if available
  Future<List<domain.MediaItem>> getMediaForDive(String diveId) async {
    try {
      // Use LEFT JOIN to fetch media with optional enrichment data in one query
      final query =
          _db.select(_db.media).join([
              leftOuterJoin(
                _db.mediaEnrichment,
                _db.mediaEnrichment.mediaId.equalsExp(_db.media.id),
              ),
            ])
            ..where(_db.media.diveId.equals(diveId))
            ..orderBy([OrderingTerm.asc(_db.media.takenAt)]);

      final rows = await query.get();
      return rows.map((row) {
        final mediaRow = row.readTable(_db.media);
        final enrichmentRow = row.readTableOrNull(_db.mediaEnrichment);
        return _mapRowToMediaItem(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get media for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get single media item by ID
  /// Includes enrichment data (depth, temperature) if available
  Future<domain.MediaItem?> getMediaById(String id) async {
    try {
      final query = _db.select(_db.media).join([
        leftOuterJoin(
          _db.mediaEnrichment,
          _db.mediaEnrichment.mediaId.equalsExp(_db.media.id),
        ),
      ])..where(_db.media.id.equals(id));

      final row = await query.getSingleOrNull();
      if (row == null) return null;

      final mediaRow = row.readTable(_db.media);
      final enrichmentRow = row.readTableOrNull(_db.mediaEnrichment);
      return _mapRowToMediaItem(mediaRow, enrichmentRow);
    } catch (e, stackTrace) {
      _log.error('Failed to get media by id: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Create new media, generate UUID if id is empty
  Future<domain.MediaItem> createMedia(domain.MediaItem item) async {
    try {
      _log.info('Creating media: ${item.filePath}');
      final id = item.id.isEmpty ? _uuid.v4() : item.id;
      final now = DateTime.now();

      await _db
          .into(_db.media)
          .insert(
            MediaCompanion(
              id: Value(id),
              diveId: Value(item.diveId),
              siteId: Value(item.siteId),
              filePath: Value(item.filePath ?? ''),
              fileType: Value(_mediaTypeToString(item.mediaType)),
              platformAssetId: Value(item.platformAssetId),
              originalFilename: Value(item.originalFilename),
              latitude: Value(item.latitude),
              longitude: Value(item.longitude),
              takenAt: Value(item.takenAt.millisecondsSinceEpoch),
              width: Value(item.width),
              height: Value(item.height),
              durationSeconds: Value(item.durationSeconds),
              caption: Value(item.caption),
              isFavorite: Value(item.isFavorite),
              thumbnailGeneratedAt: Value(
                item.thumbnailGeneratedAt?.millisecondsSinceEpoch,
              ),
              lastVerifiedAt: Value(
                item.lastVerifiedAt?.millisecondsSinceEpoch,
              ),
              isOrphaned: Value(item.isOrphaned),
              signerId: Value(item.signerId),
              signerName: Value(item.signerName),
              createdAt: Value(now.millisecondsSinceEpoch),
              updatedAt: Value(now.millisecondsSinceEpoch),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created media with id: $id');
      return item.copyWith(id: id, createdAt: now, updatedAt: now);
    } catch (e, stackTrace) {
      _log.error('Failed to create media: ${item.filePath}', e, stackTrace);
      rethrow;
    }
  }

  /// Update existing media
  Future<void> updateMedia(domain.MediaItem item) async {
    try {
      _log.info('Updating media: ${item.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.media)..where((t) => t.id.equals(item.id))).write(
        MediaCompanion(
          diveId: Value(item.diveId),
          siteId: Value(item.siteId),
          filePath: Value(item.filePath ?? ''),
          fileType: Value(_mediaTypeToString(item.mediaType)),
          platformAssetId: Value(item.platformAssetId),
          originalFilename: Value(item.originalFilename),
          latitude: Value(item.latitude),
          longitude: Value(item.longitude),
          takenAt: Value(item.takenAt.millisecondsSinceEpoch),
          width: Value(item.width),
          height: Value(item.height),
          durationSeconds: Value(item.durationSeconds),
          caption: Value(item.caption),
          isFavorite: Value(item.isFavorite),
          thumbnailGeneratedAt: Value(
            item.thumbnailGeneratedAt?.millisecondsSinceEpoch,
          ),
          lastVerifiedAt: Value(item.lastVerifiedAt?.millisecondsSinceEpoch),
          isOrphaned: Value(item.isOrphaned),
          signerId: Value(item.signerId),
          signerName: Value(item.signerName),
          updatedAt: Value(now),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: item.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated media: ${item.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update media: ${item.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete media and log deletion for sync
  Future<void> deleteMedia(String id) async {
    try {
      _log.info('Deleting media: $id');
      await (_db.delete(_db.media)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'media', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted media: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete media: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Mark media as orphaned (photo deleted from gallery)
  Future<void> markAsOrphaned(String id) async {
    try {
      _log.info('Marking media as orphaned: $id');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
        MediaCompanion(isOrphaned: const Value(true), updatedAt: Value(now)),
      );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Marked media as orphaned: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to mark media as orphaned: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Mark media as verified (photo still exists)
  Future<void> markAsVerified(String id) async {
    try {
      _log.info('Marking media as verified: $id');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
        MediaCompanion(
          isOrphaned: const Value(false),
          lastVerifiedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Marked media as verified: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to mark media as verified: $id', e, stackTrace);
      rethrow;
    }
  }

  /// Get all orphaned media
  /// Includes enrichment data (depth, temperature) if available
  Future<List<domain.MediaItem>> getOrphanedMedia() async {
    try {
      final query = _db.select(_db.media).join([
        leftOuterJoin(
          _db.mediaEnrichment,
          _db.mediaEnrichment.mediaId.equalsExp(_db.media.id),
        ),
      ])..where(_db.media.isOrphaned.equals(true));

      final rows = await query.get();
      return rows.map((row) {
        final mediaRow = row.readTable(_db.media);
        final enrichmentRow = row.readTableOrNull(_db.mediaEnrichment);
        return _mapRowToMediaItem(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get orphaned media', e, stackTrace);
      rethrow;
    }
  }

  /// Delete all orphaned media, return count
  Future<int> deleteOrphanedMedia() async {
    try {
      _log.info('Deleting all orphaned media');

      // Use transaction to ensure atomicity between query, sync logging, and delete
      return await _db.transaction(() async {
        // Get orphaned media IDs first for sync tracking
        final orphanedQuery = _db.select(_db.media)
          ..where((t) => t.isOrphaned.equals(true));
        final orphaned = await orphanedQuery.get();

        // Delete and log each deletion
        for (final item in orphaned) {
          await _syncRepository.logDeletion(
            entityType: 'media',
            recordId: item.id,
          );
        }

        final deletedCount = await (_db.delete(
          _db.media,
        )..where((t) => t.isOrphaned.equals(true))).go();

        if (deletedCount > 0) {
          SyncEventBus.notifyLocalChange();
        }

        _log.info('Deleted $deletedCount orphaned media items');
        return deletedCount;
      });
    } catch (e, stackTrace) {
      _log.error('Failed to delete orphaned media', e, stackTrace);
      rethrow;
    }
  }

  /// Get enrichment data for media
  Future<domain.MediaEnrichment?> getEnrichmentForMedia(String mediaId) async {
    try {
      final query = _db.select(_db.mediaEnrichment)
        ..where((t) => t.mediaId.equals(mediaId));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToEnrichment(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get enrichment for media: $mediaId', e, stackTrace);
      rethrow;
    }
  }

  /// Save enrichment data (insert or update)
  Future<void> saveEnrichment(domain.MediaEnrichment enrichment) async {
    try {
      _log.info('Saving enrichment for media: ${enrichment.mediaId}');
      final now = DateTime.now();
      final id = enrichment.id.isEmpty ? _uuid.v4() : enrichment.id;

      // Check if enrichment already exists for this media
      final existing = await (_db.select(
        _db.mediaEnrichment,
      )..where((t) => t.mediaId.equals(enrichment.mediaId))).getSingleOrNull();

      if (existing != null) {
        // Update existing enrichment
        await (_db.update(
          _db.mediaEnrichment,
        )..where((t) => t.mediaId.equals(enrichment.mediaId))).write(
          MediaEnrichmentCompanion(
            depthMeters: Value(enrichment.depthMeters),
            temperatureCelsius: Value(enrichment.temperatureCelsius),
            elapsedSeconds: Value(enrichment.elapsedSeconds),
            matchConfidence: Value(enrichment.matchConfidence.name),
            timestampOffsetSeconds: Value(enrichment.timestampOffsetSeconds),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'mediaEnrichment',
          recordId: existing.id,
          localUpdatedAt: now.millisecondsSinceEpoch,
        );
      } else {
        // Insert new enrichment
        await _db
            .into(_db.mediaEnrichment)
            .insert(
              MediaEnrichmentCompanion(
                id: Value(id),
                mediaId: Value(enrichment.mediaId),
                diveId: Value(enrichment.diveId),
                depthMeters: Value(enrichment.depthMeters),
                temperatureCelsius: Value(enrichment.temperatureCelsius),
                elapsedSeconds: Value(enrichment.elapsedSeconds),
                matchConfidence: Value(enrichment.matchConfidence.name),
                timestampOffsetSeconds: Value(
                  enrichment.timestampOffsetSeconds,
                ),
                createdAt: Value(now.millisecondsSinceEpoch),
              ),
            );
        await _syncRepository.markRecordPending(
          entityType: 'mediaEnrichment',
          recordId: id,
          localUpdatedAt: now.millisecondsSinceEpoch,
        );
      }

      SyncEventBus.notifyLocalChange();
      _log.info('Saved enrichment for media: ${enrichment.mediaId}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save enrichment for media: ${enrichment.mediaId}',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get count of media for dive
  Future<int> getMediaCountForDive(String diveId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT COUNT(*) as count
        FROM media
        WHERE dive_id = ?
        ''',
            variables: [Variable.withString(diveId)],
          )
          .getSingle();

      return result.data['count'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error('Failed to get media count for dive: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get GPS coordinates from media attached to a dive.
  ///
  /// Returns a list of (latitude, longitude, takenAt) tuples from photos
  /// that have valid GPS coordinates. Useful for suggesting dive site location
  /// when photos have GPS but the dive doesn't have a site.
  Future<List<({double latitude, double longitude, DateTime takenAt})>>
  getGpsFromDiveMedia(String diveId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT latitude, longitude, taken_at
        FROM media
        WHERE dive_id = ?
        AND latitude IS NOT NULL
        AND longitude IS NOT NULL
        AND latitude != 0
        AND longitude != 0
        ORDER BY taken_at ASC
        ''',
            variables: [Variable.withString(diveId)],
          )
          .get();

      return result
          .map(
            (row) => (
              latitude: row.data['latitude'] as double,
              longitude: row.data['longitude'] as double,
              takenAt: DateTime.fromMillisecondsSinceEpoch(
                row.data['taken_at'] as int,
              ),
            ),
          )
          .toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get GPS from dive media: $diveId', e, stackTrace);
      rethrow;
    }
  }

  /// Get the best GPS coordinates from a dive's media.
  ///
  /// Returns the GPS from the earliest photo with coordinates, or null if
  /// no photos have GPS data. The earliest photo is typically taken at the
  /// dive site before entering the water.
  Future<({double latitude, double longitude})?> getBestGpsFromDiveMedia(
    String diveId,
  ) async {
    final gpsPoints = await getGpsFromDiveMedia(diveId);
    if (gpsPoints.isEmpty) return null;

    // Return the first (earliest) GPS point
    return (
      latitude: gpsPoints.first.latitude,
      longitude: gpsPoints.first.longitude,
    );
  }

  /// Get pending suggestion count for dive
  Future<int> getPendingSuggestionCount(String diveId) async {
    try {
      final result = await _db
          .customSelect(
            '''
        SELECT COUNT(*) as count
        FROM pending_photo_suggestions
        WHERE dive_id = ?
        AND dismissed = 0
        ''',
            variables: [Variable.withString(diveId)],
          )
          .getSingle();

      return result.data['count'] as int? ?? 0;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get pending suggestion count for dive: $diveId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  domain.MediaItem _mapRowToMediaItem(
    MediaData row, [
    MediaEnrichmentData? enrichmentRow,
  ]) {
    return domain.MediaItem(
      id: row.id,
      diveId: row.diveId,
      siteId: row.siteId,
      platformAssetId: row.platformAssetId,
      filePath: row.filePath,
      originalFilename: row.originalFilename,
      mediaType: _parseMediaType(row.fileType),
      latitude: row.latitude,
      longitude: row.longitude,
      takenAt: row.takenAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.takenAt!)
          : _defaultTakenAt(row.id),
      width: row.width,
      height: row.height,
      durationSeconds: row.durationSeconds,
      caption: row.caption,
      isFavorite: row.isFavorite,
      thumbnailPath: null, // Not stored in database
      thumbnailGeneratedAt: row.thumbnailGeneratedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.thumbnailGeneratedAt!)
          : null,
      lastVerifiedAt: row.lastVerifiedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.lastVerifiedAt!)
          : null,
      isOrphaned: row.isOrphaned,
      signerId: row.signerId,
      signerName: row.signerName,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      enrichment: enrichmentRow != null
          ? _mapRowToEnrichment(enrichmentRow)
          : null,
    );
  }

  domain.MediaEnrichment _mapRowToEnrichment(MediaEnrichmentData row) {
    return domain.MediaEnrichment(
      id: row.id,
      mediaId: row.mediaId,
      diveId: row.diveId,
      depthMeters: row.depthMeters,
      temperatureCelsius: row.temperatureCelsius,
      elapsedSeconds: row.elapsedSeconds,
      matchConfidence:
          domain.MatchConfidence.fromString(row.matchConfidence) ??
          domain.MatchConfidence.noProfile,
      timestampOffsetSeconds: row.timestampOffsetSeconds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    );
  }

  /// Parses database file_type string to MediaType enum.
  /// Handles both snake_case (database format) and camelCase (legacy) for compatibility.
  domain.MediaType _parseMediaType(String value) {
    switch (value) {
      case 'video':
        return domain.MediaType.video;
      case 'instructor_signature':
      case 'instructorSignature':
        return domain.MediaType.instructorSignature;
      default:
        return domain.MediaType.photo;
    }
  }

  String _mediaTypeToString(domain.MediaType type) {
    switch (type) {
      case domain.MediaType.video:
        return 'video';
      case domain.MediaType.instructorSignature:
        return 'instructor_signature';
      case domain.MediaType.photo:
        return 'photo';
    }
  }

  /// Returns a default DateTime when takenAt is null in database.
  /// Logs a warning since this indicates data integrity issues.
  DateTime _defaultTakenAt(String mediaId) {
    _log.warning('Media $mediaId has null takenAt, defaulting to now');
    return DateTime.now();
  }
}
