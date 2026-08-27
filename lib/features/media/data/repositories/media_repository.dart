import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

class MediaRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(MediaRepository);

  /// Trailing-debounce window applied to [watchMediaChanges].
  ///
  /// A sync applies remote changes as many per-changeset transactions, and a
  /// bulk photo import inserts one row per file; un-coalesced, every commit
  /// would re-invalidate every listening provider. Debouncing collapses a
  /// write burst into a single tick that fires once writes go quiet.
  static const changeTickDebounce = Duration(milliseconds: 300);

  /// Emits whenever the `media` table changes so cross-feature providers can
  /// refresh after a delete, an import, or a sync -- including writes that go
  /// straight to the database and so bypass the notifier paths that invalidate
  /// per-dive media providers.
  ///
  /// Covers `media_enrichment` as well as `media`.
  ///
  /// This tick was scoped to `media` alone on the reasoning that consumers
  /// render the media rows themselves and not the joined enrichment values.
  /// That is not true of the fullscreen viewer, and the reads behind the tick
  /// left-outer-join the enrichment table regardless, so a row written there
  /// changes what they return just as much as a write to `media` does.
  ///
  /// The narrower scope made the enrichment backfill invisible: it computed
  /// and saved the depth and elapsed values, no provider re-read them, and
  /// the depth chips, mini profile and dive computer stayed absent until the
  /// viewer was closed and reopened. Newly linked media hit that every time,
  /// since linking is precisely when the enrichment does not exist yet.
  Stream<void> watchMediaChanges() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([_db.media, _db.mediaEnrichment]),
      )
      .debounce(changeTickDebounce);

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
        return mediaItemFromRow(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all media directly attached to a site, ordered by takenAt.
  /// Enrichment rides along for rows that are also dive-linked.
  Future<List<domain.MediaItem>> getMediaForSite(String siteId) async {
    try {
      final query =
          _db.select(_db.media).join([
              leftOuterJoin(
                _db.mediaEnrichment,
                _db.mediaEnrichment.mediaId.equalsExp(_db.media.id),
              ),
            ])
            ..where(_db.media.siteId.equals(siteId))
            ..orderBy([OrderingTerm.asc(_db.media.takenAt)]);

      final rows = await query.get();
      return rows.map((row) {
        final mediaRow = row.readTable(_db.media);
        final enrichmentRow = row.readTableOrNull(_db.mediaEnrichment);
        return mediaItemFromRow(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media for site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Count of media directly attached to a site (badges/headers).
  Future<int> getMediaCountForSite(String siteId) async {
    final count = _db.media.id.count();
    final query = _db.selectOnly(_db.media)
      ..addColumns([count])
      ..where(_db.media.siteId.equals(siteId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
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
      return mediaItemFromRow(mediaRow, enrichmentRow);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Newest photos and videos across all dives, ordered by takenAt
  /// descending. Signatures and documents are excluded: they are attachments
  /// rather than things a diver browses by recency. Media not attached to a
  /// dive is excluded too, because the dashboard ribbon links each tile to
  /// its dive and an unattached item would render as a dead tile. Backs the
  /// dashboard media ribbon.
  Future<List<domain.MediaItem>> getRecentMedia({int limit = 12}) async {
    try {
      final browsableTypes = [
        mediaTypeToDbString(domain.MediaType.photo),
        mediaTypeToDbString(domain.MediaType.video),
      ];
      final query =
          _db.select(_db.media).join([
              leftOuterJoin(
                _db.mediaEnrichment,
                _db.mediaEnrichment.mediaId.equalsExp(_db.media.id),
              ),
            ])
            ..where(
              _db.media.fileType.isIn(browsableTypes) &
                  _db.media.diveId.isNotNull(),
            )
            ..orderBy([OrderingTerm.desc(_db.media.takenAt)])
            ..limit(limit);

      final rows = await query.get();
      return rows.map((row) {
        final mediaRow = row.readTable(_db.media);
        final enrichmentRow = row.readTableOrNull(_db.mediaEnrichment);
        return mediaItemFromRow(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get recent media',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Returns the device ID to record on a new MediaItem, or null if the
  /// source type is device-portable (gallery, URL, manifest, signature).
  ///
  /// Caller-provided originDeviceId is always preserved.
  Future<String?> _effectiveOriginDeviceId(domain.MediaItem item) async {
    if (item.originDeviceId != null) return item.originDeviceId;
    switch (item.sourceType) {
      case MediaSourceType.localFile:
      case MediaSourceType.serviceConnector:
        return _syncRepository.getDeviceId();
      case MediaSourceType.platformGallery:
      case MediaSourceType.networkUrl:
      case MediaSourceType.manifestEntry:
      case MediaSourceType.signature:
      // Cloud-backed rows resolve through the store on every device.
      case MediaSourceType.mediaStore:
        return null;
    }
  }

  /// Create new media, generate UUID if id is empty
  Future<domain.MediaItem> createMedia(domain.MediaItem item) async {
    try {
      _log.info('Creating media: ${item.filePath}');
      final id = item.id.isEmpty ? _uuid.v4() : item.id;
      final now = DateTime.now();
      final effectiveDeviceId = await _effectiveOriginDeviceId(item);

      await _db
          .into(_db.media)
          .insert(
            MediaCompanion(
              id: Value(id),
              diveId: Value(item.diveId),
              siteId: Value(item.siteId),
              filePath: Value(item.filePath ?? ''),
              fileType: Value(mediaTypeToDbString(item.mediaType)),
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
              imageData: Value(item.imageData),
              sourceType: Value(item.sourceType.name),
              localPath: Value(item.localPath),
              bookmarkRef: Value(item.bookmarkRef),
              url: Value(item.url),
              subscriptionId: Value(item.subscriptionId),
              entryKey: Value(item.entryKey),
              connectorAccountId: Value(item.connectorAccountId),
              remoteAssetId: Value(item.remoteAssetId),
              originDeviceId: Value(effectiveDeviceId),
              contentHash: Value(item.contentHash),
              contentSizeBytes: Value(item.contentSizeBytes),
              remoteUploadedAt: Value(
                item.remoteUploadedAt?.millisecondsSinceEpoch,
              ),
              remoteThumbUploadedAt: Value(
                item.remoteThumbUploadedAt?.millisecondsSinceEpoch,
              ),
              compressedLevel: Value(item.compressedLevel),
              compressedSizeBytes: Value(item.compressedSizeBytes),
              remoteCompressedUploadedAt: Value(
                item.remoteCompressedUploadedAt?.millisecondsSinceEpoch,
              ),
              retainInLibrary: Value(item.retainInLibrary),
              manualElapsedSeconds: Value(item.manualElapsedSeconds),
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
      return item.copyWith(
        id: id,
        createdAt: now,
        updatedAt: now,
        originDeviceId: effectiveDeviceId,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create media: ${item.filePath}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Pins [id] to [elapsedSeconds] from its dive's start, or clears the pin
  /// with null so the position derives from the capture time again
  /// (issue #1090).
  ///
  /// Writes only the pin and updatedAt, so a stale caller snapshot cannot
  /// clobber any other column. The enrichment row is NOT rewritten here:
  /// [DiveMediaEnricher] is the one writer of enrichment and reads the pin
  /// on its next pass, which callers trigger right after this returns.
  Future<void> setManualElapsedSeconds(String id, int? elapsedSeconds) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
        MediaCompanion(
          manualElapsedSeconds: Value(elapsedSeconds),
          updatedAt: Value(now),
        ),
      );
      _log.info('Set manual elapsed for media $id: $elapsedSeconds');

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set manual elapsed for media: $id',
        error: e,
        stackTrace: stackTrace,
      );
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
          fileType: Value(mediaTypeToDbString(item.mediaType)),
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
          imageData: Value(item.imageData),
          sourceType: Value(item.sourceType.name),
          localPath: Value(item.localPath),
          bookmarkRef: Value(item.bookmarkRef),
          url: Value(item.url),
          subscriptionId: Value(item.subscriptionId),
          entryKey: Value(item.entryKey),
          connectorAccountId: Value(item.connectorAccountId),
          remoteAssetId: Value(item.remoteAssetId),
          originDeviceId: Value(item.originDeviceId),
          contentHash: Value(item.contentHash),
          contentSizeBytes: Value(item.contentSizeBytes),
          remoteUploadedAt: Value(
            item.remoteUploadedAt?.millisecondsSinceEpoch,
          ),
          remoteThumbUploadedAt: Value(
            item.remoteThumbUploadedAt?.millisecondsSinceEpoch,
          ),
          compressedLevel: Value(item.compressedLevel),
          compressedSizeBytes: Value(item.compressedSizeBytes),
          remoteCompressedUploadedAt: Value(
            item.remoteCompressedUploadedAt?.millisecondsSinceEpoch,
          ),
          retainInLibrary: Value(item.retainInLibrary),
          manualElapsedSeconds: Value(item.manualElapsedSeconds),
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
      _log.error(
        'Failed to update media: ${item.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete media and log deletion for sync
  Future<void> deleteMedia(String id) async {
    try {
      _log.info('Deleting media: $id');
      await _db.transaction(() async {
        await _dropEnrichmentRows([id]);
        await (_db.delete(_db.media)..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(entityType: 'media', recordId: id);
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted media: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete media: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete multiple media items in a single transaction.
  /// Logs each deletion for sync tracking.
  Future<void> deleteMultipleMedia(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      _log.info('Deleting ${ids.length} media items');
      await _db.transaction(() async {
        // Before the parents: the enrichment rows would otherwise vanish on
        // the FK cascade, which removes them without logging anything. See
        // [_dropEnrichmentRows] for why the tombstone matters.
        await _dropEnrichmentRows(ids);
        for (final id in ids) {
          await (_db.delete(_db.media)..where((t) => t.id.equals(id))).go();
          await _syncRepository.logDeletion(entityType: 'media', recordId: id);
        }
      });
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted ${ids.length} media items');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete multiple media',
        error: e,
        stackTrace: stackTrace,
      );
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
      _log.error(
        'Failed to mark media as orphaned: $id',
        error: e,
        stackTrace: stackTrace,
      );
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
      _log.error(
        'Failed to mark media as verified: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Whether any attachable media exists (signatures excluded). Cheap
  /// EXISTS probe for setup/status surfaces.
  Future<bool> hasAnyMedia() async {
    final row = await _db
        .customSelect(
          "SELECT EXISTS(SELECT 1 FROM media "
          "WHERE file_type != 'instructor_signature') AS present",
        )
        .getSingle();
    return row.read<int>('present') == 1;
  }

  /// Get all media items with the given [sourceType].
  /// Includes enrichment data (depth, temperature) if available.
  ///
  /// Used by Settings → Media Sources subsections to enumerate items per
  /// source type (e.g., the Local files diagnostics view counts orphaned
  /// vs. available items here).
  Future<List<domain.MediaItem>> getAllBySourceType(
    MediaSourceType sourceType,
  ) => getAllBySourceTypes({sourceType});

  /// Every row of the given source types, or every row when [sourceTypes] is
  /// null.
  ///
  /// Null rather than defaulting to "all types" so a caller cannot sweep the
  /// whole library by forgetting an argument: asking for everything has to be
  /// written down.
  Future<List<domain.MediaItem>> getAllBySourceTypes(
    Set<MediaSourceType>? sourceTypes,
  ) async {
    // Null means every row; an EMPTY set means none, and asking the database
    // to prove that is pointless. Not a correctness guard (SQLite accepts the
    // `IN ()` an empty list compiles to and matches nothing), but it matches
    // partitionMediaForDiveDeletion's convention and keeps the null-versus-
    // empty distinction obvious at the top of the method, where getting it
    // backwards would sweep the whole library instead of none of it.
    if (sourceTypes != null && sourceTypes.isEmpty) {
      return const <domain.MediaItem>[];
    }
    try {
      final query = _db.select(_db.media).join([
        leftOuterJoin(
          _db.mediaEnrichment,
          _db.mediaEnrichment.mediaId.equalsExp(_db.media.id),
        ),
      ]);
      if (sourceTypes != null) {
        query.where(
          _db.media.sourceType.isIn(sourceTypes.map((t) => t.name).toList()),
        );
      }

      final rows = await query.get();
      return rows.map((row) {
        final mediaRow = row.readTable(_db.media);
        final enrichmentRow = row.readTableOrNull(_db.mediaEnrichment);
        return mediaItemFromRow(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media by source types: '
        '${sourceTypes?.map((t) => t.name).join(',') ?? 'all'}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get all media items belonging to a specific manifest subscription.
  ///
  /// Used by [SubscriptionPoller] to diff existing rows against a freshly
  /// fetched manifest. Filtered on `subscription_id` to avoid scanning the
  /// full `manifestEntry` source-type set when many subscriptions share the
  /// device.
  Future<List<domain.MediaItem>> getAllBySubscription(
    String subscriptionId,
  ) async {
    try {
      final query = _db.select(_db.media).join([
        leftOuterJoin(
          _db.mediaEnrichment,
          _db.mediaEnrichment.mediaId.equalsExp(_db.media.id),
        ),
      ])..where(_db.media.subscriptionId.equals(subscriptionId));

      final rows = await query.get();
      return rows.map((row) {
        final mediaRow = row.readTable(_db.media);
        final enrichmentRow = row.readTableOrNull(_db.mediaEnrichment);
        return mediaItemFromRow(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get media by subscription: $subscriptionId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Set the `is_orphaned` flag on a media row.
  ///
  /// Unlike [markAsOrphaned] (which always sets to true and is the v1
  /// gallery-deletion handler), this accepts an explicit boolean so the
  /// [SubscriptionPoller] can flip rows back to non-orphaned when a
  /// previously-removed manifest entry reappears.
  Future<void> markOrphaned(String id, bool isOrphaned) async {
    try {
      _log.info('Setting isOrphaned=$isOrphaned for media: $id');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(_db.media)..where((t) => t.id.equals(id))).write(
        MediaCompanion(isOrphaned: Value(isOrphaned), updatedAt: Value(now)),
      );

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set isOrphaned for media: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Writes the orphan flag and the verification stamp together, and nothing
  /// else.
  ///
  /// Deliberately NOT [updateMedia], which writes every column from the
  /// caller's snapshot. The passive reconciliation path is driven by grid
  /// tiles, and a tile's snapshot comes from a FutureProvider that an
  /// upload's stamp write does not invalidate, so it goes stale the moment an
  /// upload completes. A full-row write from there would silently roll back
  /// `remoteUploadedAt` and anything else that changed since the tile built.
  ///
  /// Differs from [markOrphaned] only by also stamping `lastVerifiedAt`,
  /// which the callers of this one have actually earned: they checked.
  ///
  /// Idempotent: the UPDATE is guarded on the flag actually differing, and
  /// the sync record is only marked pending when a row was written.
  ///
  /// Deliberately enforced HERE rather than left to the caller.
  /// `reconciledOrphanFlag` compares against the caller's snapshot, and a grid
  /// tile's snapshot can lag the row it describes, so a stale caller can ask
  /// for a state the row already holds. Since every write here is sync-visible
  /// through [markRecordPending], letting that through would queue redundant
  /// sync work for an item nothing changed about. The consumers that feed
  /// tiles do refresh on media-table ticks today, but that makes this a race
  /// window rather than a guarantee, and the guarantee belongs at the layer
  /// that owns the row.
  Future<void> markVerified(
    String id, {
    required bool isOrphaned,
    required DateTime verifiedAt,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      final rowsWritten =
          await (_db.update(_db.media)..where(
                // Matching on the OPPOSITE flag is what makes this a no-op
                // when the row already agrees.
                (t) => t.id.equals(id) & t.isOrphaned.equals(!isOrphaned),
              ))
              .write(
                MediaCompanion(
                  isOrphaned: Value(isOrphaned),
                  lastVerifiedAt: Value(verifiedAt.millisecondsSinceEpoch),
                  updatedAt: Value(now),
                ),
              );
      if (rowsWritten == 0) return;
      _log.info('Marked media verified: $id (isOrphaned=$isOrphaned)');

      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to mark media verified: $id',
        error: e,
        stackTrace: stackTrace,
      );
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
        return mediaItemFromRow(mediaRow, enrichmentRow);
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get orphaned media',
        error: e,
        stackTrace: stackTrace,
      );
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
      _log.error(
        'Failed to delete orphaned media',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get enrichment data for media
  Future<domain.MediaEnrichment?> getEnrichmentForMedia(String mediaId) async {
    try {
      final query = _db.select(_db.mediaEnrichment)
        ..where((t) => t.mediaId.equals(mediaId));

      final row = await query.getSingleOrNull();
      return row != null ? mediaEnrichmentFromRow(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get enrichment for media: $mediaId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Save enrichment data (insert or update)
  Future<void> saveEnrichment(domain.MediaEnrichment enrichment) async {
    try {
      _log.info('Saving enrichment for media: ${enrichment.mediaId}');
      await _writeEnrichmentRow(enrichment);
      SyncEventBus.notifyLocalChange();
      _log.info('Saved enrichment for media: ${enrichment.mediaId}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save enrichment for media: ${enrichment.mediaId}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Saves a batch of enrichments in one transaction.
  ///
  /// One transaction means one commit, all-or-nothing persistence, and ONE
  /// mediaEnrichment table tick, where per-row [saveEnrichment] calls each
  /// tick separately. `watchMediaChanges` trailing-debounces at 300ms, so a
  /// fast per-row burst already coalesced -- but a burst SLOWER than the
  /// window (the dive-media backfill runs from the open media viewer and
  /// can write a row per photo of a dive) re-ran every subscribed provider
  /// (the library re-query included) once per quiet gap. An empty batch
  /// returns without touching the database, so the common "everything
  /// already enriched" pass costs no tick at all.
  Future<void> saveEnrichments(List<domain.MediaEnrichment> enrichments) async {
    if (enrichments.isEmpty) return;
    try {
      _log.info('Saving ${enrichments.length} enrichments');
      // markRecordPending opens its own transaction; Drift nests it as a
      // savepoint because both repositories share the one database instance.
      await _db.transaction(() async {
        for (final enrichment in enrichments) {
          await _writeEnrichmentRow(enrichment);
        }
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save enrichment batch of ${enrichments.length}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Upserts one enrichment row and marks it pending for sync.
  ///
  /// Shared by [saveEnrichment] (single write, then notify) and
  /// [saveEnrichments] (many writes in one transaction, then one notify);
  /// deliberately does NOT call [SyncEventBus.notifyLocalChange] so the
  /// batch path can notify once.
  Future<void> _writeEnrichmentRow(domain.MediaEnrichment enrichment) async {
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
          // The dive is part of the value, not just a back-pointer: an
          // enrichment is the join product of this media and ONE dive's
          // profile. Leaving it behind would let a row repaired against a
          // different dive keep claiming the old one.
          diveId: Value(enrichment.diveId),
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
              timestampOffsetSeconds: Value(enrichment.timestampOffsetSeconds),
              createdAt: Value(now.millisecondsSinceEpoch),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'mediaEnrichment',
        recordId: id,
        localUpdatedAt: now.millisecondsSinceEpoch,
      );
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
      _log.error(
        'Failed to get media count for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the set of platformAssetIds already linked to a specific dive.
  ///
  /// Returns only non-null platformAssetIds for gallery photos.
  /// Used to prevent duplicate linking.
  Future<Set<String>> getLinkedAssetIdsForDive(String diveId) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT platform_asset_id FROM media WHERE dive_id = ? AND platform_asset_id IS NOT NULL',
            variables: [Variable.withString(diveId)],
          )
          .get();
      return result
          .map((row) => row.data['platform_asset_id'] as String)
          .toSet();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get linked asset IDs for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the set of local file paths already linked to a specific dive.
  ///
  /// The desktop counterpart to [getLinkedAssetIdsForDive]: Windows / Linux
  /// imports are `localFile` rows with a null `platform_asset_id`, so the
  /// asset-id query cannot see them and duplicate detection has to key on the
  /// path instead. The path is also the more stable key -- the desktop
  /// picker's synthetic asset id embeds the file's mtime, so it changes
  /// whenever the file is touched.
  Future<Set<String>> getLinkedLocalPathsForDive(String diveId) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT local_path FROM media '
            'WHERE dive_id = ? AND local_path IS NOT NULL',
            variables: [Variable.withString(diveId)],
          )
          .get();
      return result.map((row) => row.data['local_path'] as String).toSet();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get linked local paths for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Site counterpart of [getLinkedAssetIdsForDive]: gallery-import dedupe
  /// for direct site attachments.
  Future<Set<String>> getLinkedAssetIdsForSite(String siteId) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT platform_asset_id FROM media '
            'WHERE site_id = ? AND platform_asset_id IS NOT NULL',
            variables: [Variable.withString(siteId)],
          )
          .get();
      return result
          .map((row) => row.data['platform_asset_id'] as String)
          .toSet();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get linked asset IDs for site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Site counterpart of [getLinkedLocalPathsForDive]: file-import dedupe
  /// for direct site attachments.
  Future<Set<String>> getLinkedLocalPathsForSite(String siteId) async {
    try {
      final result = await _db
          .customSelect(
            'SELECT local_path FROM media '
            'WHERE site_id = ? AND local_path IS NOT NULL',
            variables: [Variable.withString(siteId)],
          )
          .get();
      return result.map((row) => row.data['local_path'] as String).toSet();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get linked local paths for site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
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
      _log.error(
        'Failed to get GPS from dive media: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
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
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Remote asset ids of every connector-sourced media row. Media rows sync
  /// via HLC, so this covers rows created on other devices too: it is the
  /// scan-time dedup set that keeps a second connected device from
  /// re-creating the same Lightroom links.
  Future<Set<String>> getConnectorRemoteAssetIds() async {
    final remoteAssetId = _db.media.remoteAssetId;
    final query = _db.selectOnly(_db.media)
      ..addColumns([remoteAssetId])
      ..where(
        _db.media.sourceType.equals(MediaSourceType.serviceConnector.name) &
            remoteAssetId.isNotNull(),
      );
    final rows = await query.get();
    return rows.map((r) => r.read(remoteAssetId)!).toSet();
  }

  /// Remote asset ids held by live (non-dismissed) pending suggestions.
  Future<Set<String>> getPendingSuggestionRemoteAssetIds() async {
    final remoteAssetId = _db.pendingPhotoSuggestions.remoteAssetId;
    final query = _db.selectOnly(_db.pendingPhotoSuggestions)
      ..addColumns([remoteAssetId])
      ..where(
        _db.pendingPhotoSuggestions.dismissed.equals(false) &
            remoteAssetId.isNotNull(),
      );
    final rows = await query.get();
    return rows.map((r) => r.read(remoteAssetId)!).toSet();
  }

  /// Inserts a pending suggestion; fills the id with a uuid when empty.
  /// Per-device table: no sync record, no HLC.
  Future<domain.PendingPhotoSuggestion> createPendingSuggestion(
    domain.PendingPhotoSuggestion suggestion,
  ) async {
    final id = suggestion.id.isEmpty ? _uuid.v4() : suggestion.id;
    await _db
        .into(_db.pendingPhotoSuggestions)
        .insert(
          PendingPhotoSuggestionsCompanion.insert(
            id: id,
            diveId: suggestion.diveId,
            platformAssetId: suggestion.platformAssetId,
            takenAt: suggestion.takenAt.millisecondsSinceEpoch,
            thumbnailPath: Value(suggestion.thumbnailPath),
            dismissed: Value(suggestion.dismissed),
            createdAt: suggestion.createdAt.millisecondsSinceEpoch,
            connectorAccountId: Value(suggestion.connectorAccountId),
            remoteAssetId: Value(suggestion.remoteAssetId),
          ),
        );
    return domain.PendingPhotoSuggestion(
      id: id,
      diveId: suggestion.diveId,
      platformAssetId: suggestion.platformAssetId,
      takenAt: suggestion.takenAt,
      thumbnailPath: suggestion.thumbnailPath,
      dismissed: suggestion.dismissed,
      createdAt: suggestion.createdAt,
      connectorAccountId: suggestion.connectorAccountId,
      remoteAssetId: suggestion.remoteAssetId,
    );
  }

  /// Live (non-dismissed) suggestions for a dive, oldest capture first.
  Future<List<domain.PendingPhotoSuggestion>> getPendingSuggestionsForDive(
    String diveId,
  ) async {
    final query = _db.select(_db.pendingPhotoSuggestions)
      ..where((t) => t.diveId.equals(diveId) & t.dismissed.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.takenAt)]);
    final rows = await query.get();
    return rows.map(_mapRowToSuggestion).toList();
  }

  Future<void> dismissPendingSuggestion(String id) async {
    await (_db.update(_db.pendingPhotoSuggestions)
          ..where((t) => t.id.equals(id)))
        .write(const PendingPhotoSuggestionsCompanion(dismissed: Value(true)));
  }

  /// Removes every candidate row for a confirmed connector asset (an
  /// ambiguous match creates one suggestion per candidate dive).
  Future<void> deleteSuggestionsForRemoteAsset(String remoteAssetId) async {
    await (_db.delete(
      _db.pendingPhotoSuggestions,
    )..where((t) => t.remoteAssetId.equals(remoteAssetId))).go();
  }

  domain.PendingPhotoSuggestion _mapRowToSuggestion(
    PendingPhotoSuggestion row,
  ) {
    return domain.PendingPhotoSuggestion(
      id: row.id,
      diveId: row.diveId,
      platformAssetId: row.platformAssetId,
      takenAt: DateTime.fromMillisecondsSinceEpoch(row.takenAt, isUtc: true),
      thumbnailPath: row.thumbnailPath,
      dismissed: row.dismissed,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
      connectorAccountId: row.connectorAccountId,
      remoteAssetId: row.remoteAssetId,
    );
  }

  /// Stamps the content identity computed by the upload pipeline. A synced
  /// row update: peers learn the hash even before upload confirmation.
  Future<void> stampContentIdentity(
    String mediaId, {
    required String contentHash,
    required int sizeBytes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        contentHash: Value(contentHash),
        contentSizeBytes: Value(sizeBytes),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Confirms the original object exists in the media store. Once this
  /// syncs, every device knows the bytes are fetchable.
  Future<void> stampRemoteUploaded(
    String mediaId, {
    required DateTime uploadedAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteUploadedAt: Value(uploadedAt.millisecondsSinceEpoch),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// A media row is linked to the logbook when it references a dive or a
  /// site (orphan-prevention spec section 3). Single definition shared by
  /// the deletion cascades, the unlink partitions, and the orphan backlog
  /// sweep so the predicates cannot drift apart.
  static Expression<bool> isLinkedToDiveOrSite($MediaTable m) =>
      m.diveId.isNotNull() | m.siteId.isNotNull();

  /// Splits a dying dive's media (orphan-prevention spec 4.2): `doomed`
  /// rows die with the dive (dive-only; full items because the blob-delete
  /// intent needs contentHash/filename/type), `unlinkIds` survive as
  /// site-linked rows with diveId nulled.
  Future<({List<domain.MediaItem> doomed, List<String> unlinkIds})>
  partitionMediaForDiveDeletion(List<String> diveIds) async {
    // Not a correctness guard - SQLite accepts the `IN ()` an empty list
    // compiles to and matches nothing - but bulk callers legitimately hand
    // over empty collections (e.g. consolidation's secondary-dive set), and
    // there is no reason to make the database prove that nothing matches.
    // Matches [unlinkMediaFromDeletedDives]'s guard below.
    if (diveIds.isEmpty) {
      return (doomed: const <domain.MediaItem>[], unlinkIds: const <String>[]);
    }
    final rows = await (_db.select(
      _db.media,
    )..where((t) => t.diveId.isIn(diveIds))).get();
    final doomed = <domain.MediaItem>[];
    final unlinkIds = <String>[];
    for (final row in rows) {
      final keep = row.siteId != null;
      if (keep) {
        unlinkIds.add(row.id);
      } else {
        doomed.add(mediaItemFromRow(row));
      }
    }
    return (doomed: doomed, unlinkIds: unlinkIds);
  }

  /// Explicitly unlinks surviving media from deleted dives, with the HLC
  /// stamp the old silent FK SET NULL never produced - so the unlink
  /// propagates to other devices instead of diverging.
  Future<void> unlinkMediaFromDeletedDives(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(_db.media)..where((t) => t.id.isIn(mediaIds))).write(
        MediaCompanion(diveId: const Value(null), updatedAt: Value(now)),
      );
      for (final id in mediaIds) {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Splits a dying site's media: `doomed` rows die with the site
  /// (site-only; full items because the blob-delete intent needs
  /// contentHash/filename/type), `unlinkIds` survive as dive-linked rows
  /// with siteId nulled. Site counterpart of [partitionMediaForDiveDeletion].
  Future<({List<domain.MediaItem> doomed, List<String> unlinkIds})>
  partitionMediaForSiteDeletion(List<String> siteIds) async {
    // Empty-guard mirrors [partitionMediaForDiveDeletion]: bulk callers
    // legitimately hand over empty collections.
    if (siteIds.isEmpty) {
      return (doomed: const <domain.MediaItem>[], unlinkIds: const <String>[]);
    }
    final rows = await (_db.select(
      _db.media,
    )..where((t) => t.siteId.isIn(siteIds))).get();
    final doomed = <domain.MediaItem>[];
    final unlinkIds = <String>[];
    for (final row in rows) {
      final keep = row.diveId != null;
      if (keep) {
        unlinkIds.add(row.id);
      } else {
        doomed.add(mediaItemFromRow(row));
      }
    }
    return (doomed: doomed, unlinkIds: unlinkIds);
  }

  /// Explicitly unlinks surviving media from deleted sites, with the HLC
  /// stamp the silent FK SET NULL never produced - so the unlink propagates
  /// to other devices instead of diverging. Site counterpart of
  /// [unlinkMediaFromDeletedDives].
  ///
  /// Deliberately NOT routed through [_unlinkColumns]: that path also sets
  /// retain_in_library, which is a one-way latch that permanently excludes a
  /// row from the orphan sweep. Site-deletion leftovers must stay sweepable,
  /// the same distinction [unlinkMediaFromDeletedDives] draws.
  Future<void> unlinkMediaFromDeletedSites(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(_db.media)..where((t) => t.id.isIn(mediaIds))).write(
        MediaCompanion(siteId: const Value(null), updatedAt: Value(now)),
      );
      for (final id in mediaIds) {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Stage B of the repair apply (Media section Phase 3): commits every
  /// prepared write in one transaction with per-row HLC marking. Stage A
  /// (hashing, bookmarks) happened per row before this; Stage C (queue
  /// enqueues, cloud-backed conversion) follows after.
  Future<void> applyRepairWrites(List<RepairWrite> writes) async {
    if (writes.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final write in writes) {
        // sourceType is the resolver dispatch key, so a repair must always
        // restate it: relinking a dead gallery row to a file on disk while
        // leaving sourceType alone would keep routing the row through
        // PlatformGalleryResolver, turning a visibly-missing item into a
        // silently-missing one the moment the orphan flag lifts.
        final toGallery =
            write.newSourceType == MediaSourceType.platformGallery;
        await (_db.update(
          _db.media,
        )..where((t) => t.id.equals(write.mediaId))).write(
          MediaCompanion(
            localPath: toGallery
                ? const Value(null)
                : Value(write.newLocalPath),
            bookmarkRef: write.newBookmarkRef == null && !toGallery
                ? const Value.absent()
                : Value(write.newBookmarkRef),
            // Null for a file repair: the old asset id addresses an asset
            // that no longer exists on this device.
            platformAssetId: Value(write.newPlatformAssetId),
            sourceType: Value(write.newSourceType.name),
            isOrphaned: const Value(false),
            lastVerifiedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: write.mediaId,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Converts rows to cloud-backed [MediaSourceType.mediaStore] (Media
  /// section Phase 3): the store becomes the source of truth, the local
  /// pointers clear, and the orphan flag lifts. Refused per row without the
  /// contentHash + remoteUploadedAt stamp pair -- converting an unconfirmed
  /// row would render nothing anywhere. Sync-safe like [_unlinkColumns].
  Future<void> convertToCloudBacked(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return;
    final rows = await (_db.select(
      _db.media,
    )..where((t) => t.id.isIn(mediaIds))).get();
    final qualified = [
      for (final row in rows)
        if (row.contentHash != null && row.remoteUploadedAt != null) row.id,
    ];
    if (qualified.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(_db.media)..where((t) => t.id.isIn(qualified))).write(
        MediaCompanion(
          sourceType: Value(MediaSourceType.mediaStore.name),
          localPath: const Value(null),
          bookmarkRef: const Value(null),
          platformAssetId: const Value(null),
          isOrphaned: const Value(false),
          lastVerifiedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      for (final id in qualified) {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes the enrichment rows of [mediaIds], each with a tombstone.
  ///
  /// An enrichment is the join product of a media item and ONE dive's
  /// profile, so it is stale the moment that dive link changes: both the
  /// move path and the unlink path have to drop it rather than leave the
  /// photo reporting a depth and elapsed time from a dive it has left.
  /// mediaEnrichment is an HLC-synced entity, so the drop needs a logged
  /// deletion rather than a silent disappearance.
  ///
  /// Deletion needs this as much as the link-changing paths do, even though
  /// the FK cascade would remove the child rows on its own: the cascade logs
  /// nothing, so the one operation that destroys the most data would be the
  /// one telling peers the least. A peer's live child of a media row we have
  /// deleted is already skipped on merge (mediaEnrichment's parentRefs are
  /// `nullable: false`), so this is not the only thing standing between us
  /// and a resurrected row; it removes the dependence on that interplay, and
  /// on foreign keys being enabled at all.
  ///
  /// Caller supplies the transaction; this does no committing of its own.
  Future<void> _dropEnrichmentRows(List<String> mediaIds) async {
    final stale = await (_db.select(
      _db.mediaEnrichment,
    )..where((t) => t.mediaId.isIn(mediaIds))).get();
    for (final row in stale) {
      await (_db.delete(
        _db.mediaEnrichment,
      )..where((t) => t.id.equals(row.id))).go();
      await _syncRepository.logDeletion(
        entityType: 'mediaEnrichment',
        recordId: row.id,
      );
    }
  }

  /// Splits [mediaIds] by whether anything other than the dive still needs
  /// the row, for the dive-unlink path.
  ///
  /// `siteLinked` rows survive a dive unlink with the link merely cleared,
  /// the same carve-out the dive-deletion cascade makes: a dive-scoped
  /// action must never destroy a site's only photo as a side effect.
  Future<({List<String> deletable, List<String> siteLinked})>
  partitionForDiveUnlink(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return (deletable: const <String>[], siteLinked: const <String>[]);
    }
    final rows = await (_db.select(
      _db.media,
    )..where((t) => t.id.isIn(mediaIds))).get();
    final deletable = <String>[];
    final siteLinked = <String>[];
    for (final row in rows) {
      if (row.siteId != null) {
        siteLinked.add(row.id);
      } else {
        deletable.add(row.id);
      }
    }
    return (deletable: deletable, siteLinked: siteLinked);
  }

  /// Mirror of [partitionForDiveUnlink] for the site-unlink path: rows a
  /// dive still references survive with only the site link cleared, the
  /// rest leave the library.
  Future<({List<String> deletable, List<String> diveLinked})>
  partitionForSiteUnlink(List<String> mediaIds) async {
    if (mediaIds.isEmpty) {
      return (deletable: const <String>[], diveLinked: const <String>[]);
    }
    final rows = await (_db.select(
      _db.media,
    )..where((t) => t.id.isIn(mediaIds))).get();
    final deletable = <String>[];
    final diveLinked = <String>[];
    for (final row in rows) {
      if (row.diveId != null) {
        diveLinked.add(row.id);
      } else {
        deletable.add(row.id);
      }
    }
    return (deletable: deletable, diveLinked: diveLinked);
  }

  /// Of [mediaIds], those carrying metadata a user typed or set that no
  /// source file holds: a caption, or the favorite flag.
  ///
  /// Used to decide whether an unlink needs to warn before it removes the
  /// rows. Deliberately no join against `media_species`: that table is
  /// declared but nothing in the app reads or writes it, so joining it
  /// would cost a scan to always return nothing.
  Future<Set<String>> idsWithUserMetadata(List<String> mediaIds) async {
    if (mediaIds.isEmpty) return {};
    final rows =
        await (_db.select(_db.media)..where(
              (t) =>
                  t.id.isIn(mediaIds) &
                  (t.isFavorite.equals(true) |
                      (t.caption.isNotNull() & t.caption.equals('').not())),
            ))
            .get();
    return {for (final row in rows) row.id};
  }

  /// Moves media to [newDiveId] (also the link path for unlinked rows).
  /// Enrichment rows are join products of media x the OLD dive's profile:
  /// stale after the move, so they are deleted with tombstones (enrichment
  /// is an HLC-synced entity) and recomputed lazily by DiveMediaEnricher
  /// the next time the new dive's media renders.
  Future<void> reassignMediaToDive(
    List<String> mediaIds,
    String newDiveId,
  ) async {
    if (mediaIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _dropEnrichmentRows(mediaIds);
      await (_db.update(_db.media)..where((t) => t.id.isIn(mediaIds))).write(
        MediaCompanion(diveId: Value(newDiveId), updatedAt: Value(now)),
      );
      for (final id in mediaIds) {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Clears the dive link and keeps the row. Reached from
  /// [MediaUnlinkService] for media a dive site still needs; media with no
  /// other attachment is deleted outright instead.
  ///
  /// Drops the enrichment as part of the same transaction: it was computed
  /// against the dive being left, so keeping it would leave the photo
  /// reporting that dive's depth and elapsed time from the site gallery.
  Future<void> unlinkFromDive(List<String> mediaIds) => _unlinkColumns(
    mediaIds,
    const MediaCompanion(diveId: Value(null)),
    dropEnrichment: true,
  );

  /// Same mechanic for the site link, for media a dive still needs.
  Future<void> unlinkFromSite(List<String> mediaIds) =>
      _unlinkColumns(mediaIds, const MediaCompanion(siteId: Value(null)));

  /// Attaches the site link, same sync-safe shape.
  Future<void> linkMediaToSite(List<String> mediaIds, String siteId) =>
      _unlinkColumns(mediaIds, MediaCompanion(siteId: Value(siteId)));

  Future<void> _unlinkColumns(
    List<String> mediaIds,
    MediaCompanion changes, {
    bool dropEnrichment = false,
  }) async {
    if (mediaIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      if (dropEnrichment) await _dropEnrichmentRows(mediaIds);
      await (_db.update(_db.media)..where((t) => t.id.isIn(mediaIds))).write(
        changes.copyWith(updatedAt: Value(now)),
      );
      for (final id in mediaIds) {
        await _syncRepository.markRecordPending(
          entityType: 'media',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Unlinked rows older than [olderThan]. Every source type qualifies: a
  /// row with no dive and no site has no business in the library, and the
  /// age guard only exists so an insert racing this query is never caught
  /// mid-flight.
  Future<List<String>> getSweepableOrphanIds({
    required DateTime olderThan,
  }) async {
    final id = _db.media.id;
    final query = _db.selectOnly(_db.media)
      ..addColumns([id])
      ..where(
        isLinkedToDiveOrSite(_db.media).not() &
            _db.media.createdAt.isSmallerThanValue(
              olderThan.millisecondsSinceEpoch,
            ),
      );
    final rows = await query.get();
    return rows.map((r) => r.read(id)!).toList();
  }

  /// Every distinct non-null content hash - the verify sweep's referenced
  /// set (orphan-prevention spec 6.1). Same conservative rule as
  /// [countRowsWithHash]: a hash counts whether or not its rows uploaded.
  Future<Set<String>> getAllContentHashes() async {
    final hash = _db.media.contentHash;
    final query = _db.selectOnly(_db.media, distinct: true)
      ..addColumns([hash])
      ..where(hash.isNotNull());
    final rows = await query.get();
    return rows.map((r) => r.read(hash)!).toSet();
  }

  /// Rows with a content hash and at least one remote stamp, for the
  /// verify sweep's reverse repair (orphan-prevention spec 6.2).
  Future<
    List<
      ({
        String id,
        String contentHash,
        bool hasOriginal,
        bool hasThumb,
        bool hasRendition,
      })
    >
  >
  getRemoteStampedSummaries() async {
    // selectOnly projection: full rows would drag the imageData BLOB
    // (signature bytes) into memory for every stamped row, and the verify
    // sweep only needs five scalars.
    final id = _db.media.id;
    final hash = _db.media.contentHash;
    final original = _db.media.remoteUploadedAt;
    final thumb = _db.media.remoteThumbUploadedAt;
    final rendition = _db.media.remoteCompressedUploadedAt;
    final query = _db.selectOnly(_db.media)
      ..addColumns([id, hash, original, thumb, rendition])
      ..where(
        hash.isNotNull() &
            (original.isNotNull() | thumb.isNotNull() | rendition.isNotNull()),
      );
    final rows = await query.get();
    return [
      for (final row in rows)
        (
          id: row.read(id)!,
          contentHash: row.read(hash)!,
          hasOriginal: row.read(original) != null,
          hasThumb: row.read(thumb) != null,
          hasRendition: row.read(rendition) != null,
        ),
    ];
  }

  /// Clears a stale thumb stamp (verify sweep reverse repair). Mirrors
  /// [clearRemoteUploaded].
  Future<void> clearRemoteThumbUploaded(String mediaId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteThumbUploadedAt: const Value<int?>(null),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Backfill candidates (design spec section 9): device-resident photos
  /// not yet confirmed in the media store, newest first so recent dives
  /// gain protection soonest. Scoped to rows linked to a dive or site so
  /// orphaned rows are never uploaded (orphan-prevention spec section 4.1).
  Future<List<String>> getBackfillCandidateIds() async {
    final id = _db.media.id;
    final query = _db.selectOnly(_db.media)
      ..addColumns([id])
      ..where(
        isLinkedToDiveOrSite(_db.media) &
            // Photos from any uploadable source.
            ((_db.media.remoteUploadedAt.isNull() &
                    _db.media.remoteCompressedUploadedAt.isNull() &
                    _db.media.fileType.equals('photo') &
                    _db.media.sourceType.isIn([
                      'platformGallery',
                      'localFile',
                      'serviceConnector',
                    ])) |
                // Gallery and local videos upload their original, so a
                // missing original stamp is their backfill signal. Without
                // this branch a local video could never be uploaded after
                // the fact and would show a permanent not-backed-up badge.
                //
                // serviceConnector is deliberately absent: connector videos
                // are thumb-only and never get remoteUploadedAt, so
                // including them here would re-enqueue them on every
                // backfill run forever. They are covered by the thumb
                // branch below.
                (_db.media.remoteUploadedAt.isNull() &
                    _db.media.remoteCompressedUploadedAt.isNull() &
                    _db.media.fileType.equals('video') &
                    _db.media.sourceType.isIn([
                      'platformGallery',
                      'localFile',
                    ])) |
                // Connector videos are thumb-only (no original in the store
                // by design), so their backfill signal is the missing thumb
                // stamp.
                (_db.media.remoteThumbUploadedAt.isNull() &
                    _db.media.fileType.equals('video') &
                    _db.media.sourceType.equals('serviceConnector'))),
      )
      ..orderBy([OrderingTerm.desc(_db.media.takenAt)]);
    final rows = await query.get();
    return rows.map((r) => r.read(id)!).toList();
  }

  /// Confirms the thumbnail object exists in the media store.
  Future<void> stampRemoteThumbUploaded(
    String mediaId, {
    required DateTime uploadedAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteThumbUploadedAt: Value(uploadedAt.millisecondsSinceEpoch),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Confirms a compressed rendition exists in the store, recording which
  /// level produced it (first-writer-wins) and its byte size.
  Future<void> stampRemoteCompressedUploaded(
    String mediaId, {
    required DateTime uploadedAt,
    required String level,
    required int sizeBytes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteCompressedUploadedAt: Value(uploadedAt.millisecondsSinceEpoch),
        compressedLevel: Value(level),
        compressedSizeBytes: Value(sizeBytes),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Clears the original-upload stamp (used when a re-upload override
  /// switches an item from original to compressed).
  Future<void> clearRemoteUploaded(String mediaId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteUploadedAt: const Value<int?>(null),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Clears the compressed-rendition stamps (override switching to original).
  Future<void> clearRemoteCompressed(String mediaId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.media)..where((t) => t.id.equals(mediaId))).write(
      MediaCompanion(
        remoteCompressedUploadedAt: const Value<int?>(null),
        compressedLevel: const Value<String?>(null),
        compressedSizeBytes: const Value<int?>(null),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: 'media',
      recordId: mediaId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Number of media rows sharing [contentHash] that still want the original
  /// object (remote_uploaded_at set). Guards a targeted delete.
  Future<int> countRowsWithOriginal(String contentHash) async {
    final count = _db.media.id.count();
    final query = _db.selectOnly(_db.media)
      ..addColumns([count])
      ..where(
        _db.media.contentHash.equals(contentHash) &
            _db.media.remoteUploadedAt.isNotNull(),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Number of media rows sharing [contentHash] that still want the rendition.
  Future<int> countRowsWithRendition(String contentHash) async {
    final count = _db.media.id.count();
    final query = _db.selectOnly(_db.media)
      ..addColumns([count])
      ..where(
        _db.media.contentHash.equals(contentHash) &
            _db.media.remoteCompressedUploadedAt.isNotNull(),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Number of media rows referencing [contentHash] at all - uploaded or
  /// not. The delete fast path's drain-time refcount (orphan-prevention
  /// spec 5.3): deliberately broader than [countRowsWithOriginal] because
  /// skipping a blob delete is free while a wrong delete costs a re-upload.
  Future<int> countRowsWithHash(String contentHash) async {
    final count = _db.media.id.count();
    final query = _db.selectOnly(_db.media)
      ..addColumns([count])
      ..where(_db.media.contentHash.equals(contentHash));
    return (await query.getSingle()).read(count) ?? 0;
  }
}
