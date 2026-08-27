import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/data/visibility/visibility_filter.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/data/mappers/dive_site_row_mapper.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/domain/services/site_location_merge.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

// Re-exported so the many existing `site_repository_impl.dart` importers of
// SiteWithDiveCount keep compiling after the class moved to the domain layer.
export 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';

class SiteRepository {
  /// Injectable seams mirror [DiveRepository]: tests hand in a coordinator
  /// over an in-memory queue, production builds the default. A redirecting
  /// GENERATIVE constructor (not a factory) so existing test fakes that
  /// `extends SiteRepository` keep their implicit super() call.
  SiteRepository({
    MediaRepository? mediaRepository,
    MediaDeletionCoordinator? mediaDeletionCoordinator,
  }) : this._(mediaRepository ?? MediaRepository(), mediaDeletionCoordinator);

  SiteRepository._(this._mediaRepository, MediaDeletionCoordinator? coordinator)
    : _mediaDeletionCoordinator =
          coordinator ??
          MediaDeletionCoordinator(
            mediaRepository: _mediaRepository,
            queue: () => MediaTransferQueueRepository(),
            // No worker kick from the data layer (provider cycles): queued
            // intents drain on the next connectivity event, app start, or
            // any other kick; the Verify Library sweep is the backstop.
          );

  final MediaRepository _mediaRepository;
  final MediaDeletionCoordinator _mediaDeletionCoordinator;
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(SiteRepository);

  /// Get all sites ordered by name
  Future<List<domain.DiveSite>> getAllSites({String? diverId}) async {
    try {
      return await PerfTimer.measure('getAllSites', () async {
        final query = _db.select(_db.diveSites)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]);

        VisibilityFilter.applyToDiveSites(query, diverId);

        final rows = await query.get();
        return rows.map(_mapRowToSite).toList();
      });
    } catch (e, stackTrace) {
      _log.error('Failed to get all sites', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Emits whenever the `dive_sites` table changes so list providers can
  /// refresh after a sync or any other write.
  Stream<void> watchSitesChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.diveSites));

  /// Get a single site by ID
  Future<domain.DiveSite?> getSiteById(String id) async {
    try {
      final query = _db.select(_db.diveSites)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToSite(row) : null;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get site by id: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Create a new site
  Future<domain.DiveSite> createSite(domain.DiveSite site) async {
    try {
      _log.info('Creating site: ${site.name}');
      final id = site.id.isEmpty ? _uuid.v4() : site.id;
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db
          .into(_db.diveSites)
          .insert(
            DiveSitesCompanion(
              id: Value(id),
              diverId: Value(site.diverId),
              name: Value(site.name),
              description: Value(site.description),
              latitude: Value(site.location?.latitude),
              longitude: Value(site.location?.longitude),
              minDepth: Value(site.minDepth),
              maxDepth: Value(site.maxDepth),
              difficulty: Value(site.difficulty?.name),
              waterType: Value(site.waterType?.name),
              country: Value(site.country),
              region: Value(site.region),
              city: Value(site.city),
              island: Value(site.island),
              bodyOfWater: Value(site.bodyOfWater),
              rating: Value(site.rating),
              notes: Value(site.notes),
              hazards: Value(site.hazards),
              accessNotes: Value(site.accessNotes),
              mooringNumber: Value(site.mooringNumber),
              parkingInfo: Value(site.parkingInfo),
              altitude: Value(site.altitude),
              entryMethod: Value(site.entryMethod?.name),
              exitMethod: Value(site.exitMethod?.name),
              isShared: Value(site.isShared),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await _syncRepository.markRecordPending(
        entityType: 'diveSites',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();

      _log.info('Created site with id: $id');
      return site.copyWith(id: id);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create site: ${site.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update an existing site
  Future<void> updateSite(domain.DiveSite site) => _writeSiteUpdate(site);

  /// Update an existing site and, in the same statement, apply importer-only
  /// columns that do not flow through the [domain.DiveSite] entity.
  ///
  /// The UDDF importer's overwrite path needs both halves to land together:
  /// writing the core fields and then patching `waterType`/`bodyOfWater` in a
  /// second statement would leave the row with new core data and stale
  /// metadata if the second write threw. Merging them into one UPDATE makes
  /// the pair atomic without a transaction, and marks the row pending for
  /// sync exactly once.
  ///
  /// Columns set on [metadataPatch] win over the values derived from [site].
  Future<void> updateSiteWithImportedMetadata(
    domain.DiveSite site,
    DiveSitesCompanion metadataPatch,
  ) => _writeSiteUpdate(site, metadataPatch: metadataPatch);

  Future<void> _writeSiteUpdate(
    domain.DiveSite site, {
    DiveSitesCompanion? metadataPatch,
  }) async {
    try {
      _log.info('Updating site: ${site.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      var companion = DiveSitesCompanion(
        name: Value(site.name),
        description: Value(site.description),
        latitude: Value(site.location?.latitude),
        longitude: Value(site.location?.longitude),
        minDepth: Value(site.minDepth),
        maxDepth: Value(site.maxDepth),
        difficulty: Value(site.difficulty?.name),
        waterType: Value(site.waterType?.name),
        country: Value(site.country),
        region: Value(site.region),
        city: Value(site.city),
        island: Value(site.island),
        bodyOfWater: Value(site.bodyOfWater),
        rating: Value(site.rating),
        notes: Value(site.notes),
        hazards: Value(site.hazards),
        accessNotes: Value(site.accessNotes),
        mooringNumber: Value(site.mooringNumber),
        parkingInfo: Value(site.parkingInfo),
        altitude: Value(site.altitude),
        entryMethod: Value(site.entryMethod?.name),
        exitMethod: Value(site.exitMethod?.name),
        isShared: Value(site.isShared),
        updatedAt: Value(now),
      );
      if (metadataPatch != null) {
        // Only the columns actually present on the patch override the
        // entity-derived values; `Value.absent()` leaves them alone.
        if (metadataPatch.waterType.present) {
          companion = companion.copyWith(waterType: metadataPatch.waterType);
        }
        if (metadataPatch.bodyOfWater.present) {
          companion = companion.copyWith(
            bodyOfWater: metadataPatch.bodyOfWater,
          );
        }
      }

      await (_db.update(
        _db.diveSites,
      )..where((t) => t.id.equals(site.id))).write(companion);
      await _syncRepository.markRecordPending(
        entityType: 'diveSites',
        recordId: site.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated site: ${site.id}');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update site: ${site.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Apply a partial [DiveSitesCompanion] update to a site row.
  ///
  /// Used by the UDDF importer to persist columns that do not flow through
  /// the [domain.DiveSite] entity (e.g. MacDive waterType).
  /// Stores a looked-up altitude for [siteId] without touching any other
  /// column. Use this, never `updateSite` with a copied entity, for the
  /// altitude write-back (issue #1187).
  Future<void> updateSiteAltitude(String siteId, double altitudeMeters) =>
      applyImportedMetadata(
        siteId,
        DiveSitesCompanion(altitude: Value(altitudeMeters)),
      );

  /// Stores coordinates (and optionally an altitude) for [siteId] without
  /// touching any other column.
  Future<void> updateSiteCoordinates(
    String siteId,
    domain.GeoPoint location, {
    double? altitude,
  }) => applyImportedMetadata(
    siteId,
    DiveSitesCompanion(
      latitude: Value(location.latitude),
      longitude: Value(location.longitude),
      altitude: altitude == null ? const Value.absent() : Value(altitude),
    ),
  );

  /// Fills whichever of country, region, city and body of water are still
  /// empty on [siteId] from [found], leaving every other column untouched
  /// (issue #1187). Returns true when a column was written. The row is
  /// marked pending for sync only when something changed.
  Future<bool> fillMissingLocationDetails(
    String siteId,
    PlaceLookup found,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final changed = await _db.transaction(() async {
        final row = await (_db.select(
          _db.diveSites,
        )..where((t) => t.id.equals(siteId))).getSingleOrNull();
        if (row == null) return false;

        final merged = mergeMissingLocationDetails(
          current: SiteLocationDetails.ofSite(_mapRowToSite(row)),
          found: found,
        );
        if (merged == null) return false;

        Value<String?> column(String? value) =>
            value == null ? const Value.absent() : Value(value);
        await (_db.update(
          _db.diveSites,
        )..where((t) => t.id.equals(siteId))).write(
          DiveSitesCompanion(
            country: column(merged.country),
            region: column(merged.region),
            city: column(merged.city),
            bodyOfWater: column(merged.bodyOfWater),
            updatedAt: Value(now),
          ),
        );
        return true;
      });
      if (!changed) return false;

      await _syncRepository.markRecordPending(
        entityType: 'diveSites',
        recordId: siteId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return true;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to fill location details for site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Only columns set on [patch] are written; others are left untouched.
  /// Marks the row pending for sync.
  Future<void> applyImportedMetadata(
    String siteId,
    DiveSitesCompanion patch,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.diveSites)..where((t) => t.id.equals(siteId)))
          .write(patch.copyWith(updatedAt: Value(now)));
      await _syncRepository.markRecordPending(
        entityType: 'diveSites',
        recordId: siteId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to apply imported metadata to site: $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Flip the shared state of a single site. Marks it pending for sync.
  Future<void> setShared(String id, bool isShared) async {
    try {
      _log.info('Setting site $id isShared=$isShared');
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.diveSites)..where((t) => t.id.equals(id))).write(
        DiveSitesCompanion(isShared: Value(isShared), updatedAt: Value(now)),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveSites',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set shared flag on site $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Mark every private site owned by [diverId] as shared. Returns the
  /// count of rows updated. All updated rows are marked pending for sync.
  Future<int> shareAllForDiver(String diverId) async {
    try {
      _log.info('Bulk sharing all private sites for diver $diverId');
      final now = DateTime.now().millisecondsSinceEpoch;

      return await _db.transaction(() async {
        final toShare =
            await (_db.select(_db.diveSites)..where(
                  (t) => t.diverId.equals(diverId) & t.isShared.equals(false),
                ))
                .get();

        if (toShare.isEmpty) return 0;

        await _db.customUpdate(
          'UPDATE dive_sites SET is_shared = 1, updated_at = ? '
          'WHERE diver_id = ? AND is_shared = 0',
          variables: [Variable.withInt(now), Variable.withString(diverId)],
          updates: {_db.diveSites},
        );

        for (final row in toShare) {
          await _syncRepository.markRecordPending(
            entityType: 'diveSites',
            recordId: row.id,
            localUpdatedAt: now,
          );
        }
        SyncEventBus.notifyLocalChange();
        return toShare.length;
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk-share sites for diver $diverId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Cascade a dying site's media: site-only rows die with the site
  /// (rows + tombstones + blob-delete intents via the coordinator's
  /// enqueue-before-delete path); dive-linked and library-level rows
  /// survive with siteId nulled and HLC-stamped. Mirrors
  /// DiveRepository._cascadeMediaForDiveDeletion; without it the silent
  /// FK SET NULL on media.site_id writes no HLC stamp and peers diverge.
  ///
  /// Deliberately NOT wrapped in a transaction with the site delete: the
  /// coordinator's queue writes live in another database, and every step
  /// is individually idempotent/tombstoned. Site merge relinks media to
  /// the survivor inside its own transaction BEFORE deleting duplicates,
  /// so this sees no doomed media for merged-away sites.
  Future<void> _cascadeMediaForSiteDeletion(List<String> ids) async {
    final split = await _mediaRepository.partitionMediaForSiteDeletion(ids);
    if (split.doomed.isNotEmpty) {
      await _mediaDeletionCoordinator.deleteMediaItems(split.doomed);
    }
    if (split.unlinkIds.isNotEmpty) {
      await _mediaRepository.unlinkMediaFromDeletedSites(split.unlinkIds);
    }
  }

  /// Delete a site.
  ///
  /// [cascadeMedia] is true for user-intent deletions (the site's direct
  /// attachments go with the site). Restore/undo flows that re-point media
  /// afterwards pass false so the cascade cannot eat rows they are about
  /// to restore.
  Future<void> deleteSite(String id, {bool cascadeMedia = true}) async {
    try {
      _log.info('Deleting site: $id');
      if (cascadeMedia) await _cascadeMediaForSiteDeletion([id]);
      await (_db.delete(_db.diveSites)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'diveSites', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted site: $id');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete site: $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get multiple sites by IDs
  Future<List<domain.DiveSite>> getSitesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final query = _db.select(_db.diveSites)..where((t) => t.id.isIn(ids));
      final rows = await query.get();
      return rows.map(_mapRowToSite).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get sites by ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Bulk delete multiple sites
  Future<void> bulkDeleteSites(
    List<String> ids, {
    bool cascadeMedia = true,
  }) async {
    if (ids.isEmpty) return;
    try {
      _log.info('Bulk deleting ${ids.length} sites');
      if (cascadeMedia) await _cascadeMediaForSiteDeletion(ids);
      await (_db.delete(_db.diveSites)..where((t) => t.id.isIn(ids))).go();
      for (final id in ids) {
        await _syncRepository.logDeletion(
          entityType: 'diveSites',
          recordId: id,
        );
      }
      SyncEventBus.notifyLocalChange();
      _log.info('Bulk deleted ${ids.length} sites');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to bulk delete sites',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Merge multiple sites into the first site in [siteIds].
  ///
  /// The first ID is treated as the survivor. The survivor is updated with
  /// [mergedSite], dependent records are re-linked to it, expected species are
  /// unioned by species ID, and the remaining sites are deleted.
  ///
  /// Returns a [MergeSnapshot] that can be passed to [undoMerge] to reverse
  /// the operation, or `null` if the merge was a no-op.
  Future<MergeSnapshot?> mergeSites({
    required domain.DiveSite mergedSite,
    required List<String> siteIds,
  }) async {
    final orderedIds = siteIds.toSet().toList(growable: false);
    if (orderedIds.length < 2) return null;

    final survivorId = orderedIds.first;
    final duplicateIds = orderedIds.skip(1).toList(growable: false);
    final now = DateTime.now().millisecondsSinceEpoch;
    final survivorSite = mergedSite.copyWith(id: survivorId);

    try {
      _log.info(
        'Merging ${orderedIds.length} sites into survivor: $survivorId',
      );

      // Validate all sites exist before mutating
      final originalSurvivor = await getSiteById(survivorId);
      if (originalSurvivor == null) {
        throw StateError('Survivor site $survivorId does not exist');
      }
      final deletedSites = await getSitesByIds(duplicateIds);
      if (deletedSites.length != duplicateIds.length) {
        final found = deletedSites.map((s) => s.id).toSet();
        final missing = duplicateIds.where((id) => !found.contains(id));
        throw StateError('Sites not found: ${missing.join(', ')}');
      }

      final affectedDives = await (_db.select(
        _db.dives,
      )..where((t) => t.siteId.isIn(duplicateIds))).get();
      final diveOriginalSiteIds = {
        for (final dive in affectedDives)
          if (dive.siteId != null) dive.id: dive.siteId!,
      };

      final affectedMedia = await (_db.select(
        _db.media,
      )..where((t) => t.siteId.isIn(duplicateIds))).get();
      final mediaOriginalSiteIds = {
        for (final media in affectedMedia)
          if (media.siteId != null) media.id: media.siteId!,
      };

      final affectedFeatures = await (_db.select(
        _db.siteFeatures,
      )..where((t) => t.siteId.isIn(duplicateIds))).get();
      final featureOriginalSiteIds = {
        for (final f in affectedFeatures) f.id: f.siteId,
      };

      // Capture raw timestamps for deleted sites (domain entity lacks these)
      final rawSiteRows = await (_db.select(
        _db.diveSites,
      )..where((t) => t.id.isIn(orderedIds))).get();
      final siteTimestamps = {
        for (final row in rawSiteRows)
          row.id: (createdAt: row.createdAt, updatedAt: row.updatedAt),
      };

      final allSpeciesRows = await (_db.select(
        _db.siteSpecies,
      )..where((t) => t.siteId.isIn(orderedIds))).get();
      final speciesSnapshots = allSpeciesRows
          .map(
            (row) => SiteSpeciesSnapshot(
              id: row.id,
              siteId: row.siteId,
              speciesId: row.speciesId,
              notes: row.notes,
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false);

      await _db.transaction(() async {
        await _updateSiteRow(survivorSite, now);
        await _syncRepository.markRecordPending(
          entityType: 'diveSites',
          recordId: survivorId,
          localUpdatedAt: now,
        );

        await _relinkDives(duplicateIds, survivorId, now);
        await _relinkMedia(duplicateIds, survivorId, now);
        await _relinkSiteFeatures(duplicateIds, survivorId, now);
        await _mergeExpectedSpecies(
          orderedSiteIds: orderedIds,
          survivorId: survivorId,
          now: now,
        );

        for (final duplicateId in duplicateIds) {
          await (_db.delete(
            _db.diveSites,
          )..where((t) => t.id.equals(duplicateId))).go();
          await _syncRepository.logDeletion(
            entityType: 'diveSites',
            recordId: duplicateId,
          );
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Merged ${orderedIds.length} sites into survivor: $survivorId');

      // Separate snapshots into deleted vs modified for undo
      final postMergeSpecies = await (_db.select(
        _db.siteSpecies,
      )..where((t) => t.siteId.equals(survivorId))).get();
      final survivingIds = postMergeSpecies.map((row) => row.id).toSet();

      final deletedSpecies = speciesSnapshots
          .where((s) => !survivingIds.contains(s.id))
          .toList(growable: false);
      final modifiedSpecies = speciesSnapshots
          .where(
            (s) =>
                survivingIds.contains(s.id) &&
                (s.siteId != survivorId ||
                    s.notes != _findPostMergeNotes(postMergeSpecies, s.id)),
          )
          .toList(growable: false);

      return MergeSnapshot(
        originalSurvivor: originalSurvivor,
        deletedSites: deletedSites,
        diveOriginalSiteIds: diveOriginalSiteIds,
        mediaOriginalSiteIds: mediaOriginalSiteIds,
        featureOriginalSiteIds: featureOriginalSiteIds,
        deletedSpeciesEntries: deletedSpecies,
        modifiedSpeciesEntries: modifiedSpecies,
        deletedSiteTimestamps: {
          for (final id in duplicateIds)
            if (siteTimestamps.containsKey(id)) id: siteTimestamps[id]!,
        },
        survivorTimestamps: siteTimestamps[survivorId],
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to merge sites: $siteIds',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  String _findPostMergeNotes(List<SiteSpecy> rows, String id) {
    return rows.where((r) => r.id == id).firstOrNull?.notes ?? '';
  }

  /// Reverse a merge operation using a previously captured [MergeSnapshot].
  Future<void> undoMerge(MergeSnapshot snapshot) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      _log.info(
        'Undoing merge: restoring ${snapshot.deletedSites.length} sites',
      );

      await _db.transaction(() async {
        // 1. Restore the survivor to its original state
        await _updateSiteRow(snapshot.originalSurvivor, now);
        await _syncRepository.markRecordPending(
          entityType: 'diveSites',
          recordId: snapshot.originalSurvivor.id,
          localUpdatedAt: now,
        );

        // 2. Re-create deleted sites
        for (final site in snapshot.deletedSites) {
          final ts = snapshot.deletedSiteTimestamps[site.id];
          await _db
              .into(_db.diveSites)
              .insert(
                DiveSitesCompanion(
                  id: Value(site.id),
                  diverId: Value(site.diverId),
                  name: Value(site.name),
                  description: Value(site.description),
                  latitude: Value(site.location?.latitude),
                  longitude: Value(site.location?.longitude),
                  minDepth: Value(site.minDepth),
                  maxDepth: Value(site.maxDepth),
                  difficulty: Value(site.difficulty?.name),
                  waterType: Value(site.waterType?.name),
                  country: Value(site.country),
                  region: Value(site.region),
                  city: Value(site.city),
                  island: Value(site.island),
                  bodyOfWater: Value(site.bodyOfWater),
                  rating: Value(site.rating),
                  notes: Value(site.notes),
                  hazards: Value(site.hazards),
                  accessNotes: Value(site.accessNotes),
                  mooringNumber: Value(site.mooringNumber),
                  parkingInfo: Value(site.parkingInfo),
                  altitude: Value(site.altitude),
                  entryMethod: Value(site.entryMethod?.name),
                  exitMethod: Value(site.exitMethod?.name),
                  isShared: Value(site.isShared),
                  createdAt: Value(ts?.createdAt ?? now),
                  updatedAt: Value(ts?.updatedAt ?? now),
                ),
              );
          await _syncRepository.markRecordPending(
            entityType: 'diveSites',
            recordId: site.id,
            localUpdatedAt: now,
          );
        }

        // 3. Re-point dives back to their original sites
        for (final entry in snapshot.diveOriginalSiteIds.entries) {
          await (_db.update(
            _db.dives,
          )..where((t) => t.id.equals(entry.key))).write(
            DivesCompanion(siteId: Value(entry.value), updatedAt: Value(now)),
          );
          await _syncRepository.markRecordPending(
            entityType: 'dives',
            recordId: entry.key,
            localUpdatedAt: now,
          );
        }

        // 4. Re-point media back to their original sites
        for (final entry in snapshot.mediaOriginalSiteIds.entries) {
          await (_db.update(
            _db.media,
          )..where((t) => t.id.equals(entry.key))).write(
            MediaCompanion(siteId: Value(entry.value), updatedAt: Value(now)),
          );
          await _syncRepository.markRecordPending(
            entityType: 'media',
            recordId: entry.key,
            localUpdatedAt: now,
          );
        }

        // 4b. Re-point site features back to their original sites
        for (final entry in snapshot.featureOriginalSiteIds.entries) {
          await (_db.update(
            _db.siteFeatures,
          )..where((t) => t.id.equals(entry.key))).write(
            SiteFeaturesCompanion(
              siteId: Value(entry.value),
              updatedAt: Value(now),
            ),
          );
          await _syncRepository.markRecordPending(
            entityType: 'siteFeatures',
            recordId: entry.key,
            localUpdatedAt: now,
          );
        }

        // 5. Restore deleted species entries
        for (final entry in snapshot.deletedSpeciesEntries) {
          await _db
              .into(_db.siteSpecies)
              .insert(
                SiteSpeciesCompanion(
                  id: Value(entry.id),
                  siteId: Value(entry.siteId),
                  speciesId: Value(entry.speciesId),
                  notes: Value(entry.notes),
                  createdAt: Value(entry.createdAt),
                ),
              );
          await _syncRepository.markRecordPending(
            entityType: 'siteSpecies',
            recordId: entry.id,
            localUpdatedAt: now,
          );
        }

        // 6. Restore modified species entries to original state
        for (final entry in snapshot.modifiedSpeciesEntries) {
          await (_db.update(
            _db.siteSpecies,
          )..where((t) => t.id.equals(entry.id))).write(
            SiteSpeciesCompanion(
              siteId: Value(entry.siteId),
              notes: Value(entry.notes),
            ),
          );
          await _syncRepository.markRecordPending(
            entityType: 'siteSpecies',
            recordId: entry.id,
            localUpdatedAt: now,
          );
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Undo merge complete');
    } catch (e, stackTrace) {
      _log.error('Failed to undo merge', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Search sites by name or location
  Future<List<domain.DiveSite>> searchSites(
    String query, {
    String? diverId,
  }) async {
    try {
      return await PerfTimer.measure('searchSites', () async {
        final searchQuery = _db.select(_db.diveSites)
          ..where(
            (t) =>
                t.name.contains(query) |
                t.country.contains(query) |
                t.region.contains(query) |
                t.city.contains(query) |
                t.island.contains(query) |
                t.bodyOfWater.contains(query),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]);

        VisibilityFilter.applyToDiveSites(searchQuery, diverId);

        final rows = await searchQuery.get();
        return rows.map(_mapRowToSite).toList();
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to search sites: $query',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Dive count per site. Kept for callers that only need the count; the
  /// list path uses [getDiveAggregatesBySite].
  Future<Map<String, int>> getDiveCountsBySite() async {
    final aggregates = await getDiveAggregatesBySite();
    return aggregates.map((siteId, a) => MapEntry(siteId, a.diveCount));
  }

  /// One GROUP BY over the dives table: count, most recent dive, and the
  /// deepest max_depth logged, per site. Sites with no dives are absent.
  Future<Map<String, SiteDiveAggregate>> getDiveAggregatesBySite() async {
    try {
      final result = await _db.customSelect('''
        SELECT site_id,
               COUNT(*) AS dive_count,
               MAX(dive_date_time) AS last_dived,
               MAX(max_depth) AS max_depth_reached
        FROM dives
        WHERE site_id IS NOT NULL
        GROUP BY site_id
      ''').get();

      return {
        for (final row in result)
          row.data['site_id'] as String: SiteDiveAggregate(
            diveCount: row.data['dive_count'] as int,
            lastDivedAt: row.data['last_dived'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    row.data['last_dived'] as int,
                  ),
            maxDepthReached: (row.data['max_depth_reached'] as num?)
                ?.toDouble(),
          ),
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive aggregates by site',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Distinct `site_features.type` names per site, ordered by the first
  /// feature of each type. One query for the whole list, so a card can show
  /// feature chips without a per-row lookup.
  Future<Map<String, List<String>>> getFeatureTypesBySite() async {
    try {
      final result = await _db.customSelect('''
        SELECT site_id, type, MIN(created_at) AS first_seen
        FROM site_features
        GROUP BY site_id, type
        ORDER BY site_id, first_seen
      ''').get();

      final types = <String, List<String>>{};
      for (final row in result) {
        types
            .putIfAbsent(row.data['site_id'] as String, () => [])
            .add(row.data['type'] as String);
      }
      return types;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get feature types by site',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get sites with dive counts
  Future<List<SiteWithDiveCount>> getSitesWithDiveCounts({
    String? diverId,
  }) async {
    try {
      return await PerfTimer.measure('getSitesWithDiveCounts', () async {
        final sites = await getAllSites(diverId: diverId);
        final aggregates = await getDiveAggregatesBySite();
        final featureTypes = await getFeatureTypesBySite();

        return sites.map((site) {
          final a = aggregates[site.id];
          return SiteWithDiveCount(
            site: site,
            diveCount: a?.diveCount ?? 0,
            lastDivedAt: a?.lastDivedAt,
            maxDepthReached: a?.maxDepthReached,
            featureTypes: featureTypes[site.id] ?? const [],
          );
        }).toList()..sort((a, b) => b.diveCount.compareTo(a.diveCount));
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get sites with dive counts',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  domain.DiveSite _mapRowToSite(DiveSite row) => mapDiveSiteRow(row);

  Future<void> _updateSiteRow(domain.DiveSite site, int now) async {
    await (_db.update(_db.diveSites)..where((t) => t.id.equals(site.id))).write(
      DiveSitesCompanion(
        name: Value(site.name),
        description: Value(site.description),
        latitude: Value(site.location?.latitude),
        longitude: Value(site.location?.longitude),
        minDepth: Value(site.minDepth),
        maxDepth: Value(site.maxDepth),
        difficulty: Value(site.difficulty?.name),
        waterType: Value(site.waterType?.name),
        country: Value(site.country),
        region: Value(site.region),
        city: Value(site.city),
        island: Value(site.island),
        bodyOfWater: Value(site.bodyOfWater),
        rating: Value(site.rating),
        notes: Value(site.notes),
        hazards: Value(site.hazards),
        accessNotes: Value(site.accessNotes),
        mooringNumber: Value(site.mooringNumber),
        parkingInfo: Value(site.parkingInfo),
        altitude: Value(site.altitude),
        entryMethod: Value(site.entryMethod?.name),
        exitMethod: Value(site.exitMethod?.name),
        isShared: Value(site.isShared),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> _relinkDives(
    List<String> duplicateIds,
    String survivorId,
    int now,
  ) async {
    if (duplicateIds.isEmpty) return;

    final affectedDives = await (_db.select(
      _db.dives,
    )..where((t) => t.siteId.isIn(duplicateIds))).get();

    if (affectedDives.isEmpty) return;

    await (_db.update(
      _db.dives,
    )..where((t) => t.siteId.isIn(duplicateIds))).write(
      DivesCompanion(siteId: Value(survivorId), updatedAt: Value(now)),
    );

    for (final dive in affectedDives) {
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: dive.id,
        localUpdatedAt: now,
      );
    }
  }

  /// Diver-placed annotations follow their site: a simple re-point with
  /// no dedupe key (two moorings at one site are legitimate, and any
  /// genuine duplicates are visible on the map and hand-fixable).
  Future<void> _relinkSiteFeatures(
    List<String> duplicateIds,
    String survivorId,
    int now,
  ) async {
    if (duplicateIds.isEmpty) return;

    final affected = await (_db.select(
      _db.siteFeatures,
    )..where((t) => t.siteId.isIn(duplicateIds))).get();

    if (affected.isEmpty) return;

    await (_db.update(
      _db.siteFeatures,
    )..where((t) => t.siteId.isIn(duplicateIds))).write(
      SiteFeaturesCompanion(siteId: Value(survivorId), updatedAt: Value(now)),
    );

    for (final feature in affected) {
      await _syncRepository.markRecordPending(
        entityType: 'siteFeatures',
        recordId: feature.id,
        localUpdatedAt: now,
      );
    }
  }

  Future<void> _relinkMedia(
    List<String> duplicateIds,
    String survivorId,
    int now,
  ) async {
    if (duplicateIds.isEmpty) return;

    final affectedMedia = await (_db.select(
      _db.media,
    )..where((t) => t.siteId.isIn(duplicateIds))).get();

    if (affectedMedia.isEmpty) return;

    await (_db.update(
      _db.media,
    )..where((t) => t.siteId.isIn(duplicateIds))).write(
      MediaCompanion(siteId: Value(survivorId), updatedAt: Value(now)),
    );

    for (final media in affectedMedia) {
      await _syncRepository.markRecordPending(
        entityType: 'media',
        recordId: media.id,
        localUpdatedAt: now,
      );
    }
  }

  Future<void> _mergeExpectedSpecies({
    required List<String> orderedSiteIds,
    required String survivorId,
    required int now,
  }) async {
    final speciesRows = await (_db.select(
      _db.siteSpecies,
    )..where((t) => t.siteId.isIn(orderedSiteIds))).get();

    if (speciesRows.isEmpty) return;

    final siteOrder = <String, int>{
      for (var i = 0; i < orderedSiteIds.length; i++) orderedSiteIds[i]: i,
    };

    final bySpecies = <String, List<SiteSpecy>>{};
    for (final row in speciesRows) {
      bySpecies.putIfAbsent(row.speciesId, () => []).add(row);
    }

    for (final rows in bySpecies.values) {
      rows.sort(
        (a, b) => (siteOrder[a.siteId] ?? orderedSiteIds.length).compareTo(
          siteOrder[b.siteId] ?? orderedSiteIds.length,
        ),
      );

      final primary = rows.first;
      final mergedNotes = rows
          .map((row) => row.notes.trim())
          .firstWhere((notes) => notes.isNotEmpty, orElse: () => '');

      final primaryNeedsSiteMove = primary.siteId != survivorId;
      final primaryNeedsNoteUpdate = primary.notes != mergedNotes;

      if (primaryNeedsSiteMove || primaryNeedsNoteUpdate) {
        await (_db.update(
          _db.siteSpecies,
        )..where((t) => t.id.equals(primary.id))).write(
          SiteSpeciesCompanion(
            siteId: Value(survivorId),
            notes: Value(mergedNotes),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'siteSpecies',
          recordId: primary.id,
          localUpdatedAt: now,
        );
      }

      for (final duplicate in rows.skip(1)) {
        await (_db.delete(
          _db.siteSpecies,
        )..where((t) => t.id.equals(duplicate.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'siteSpecies',
          recordId: duplicate.id,
        );
      }
    }
  }
}

/// Result returned from a merge operation, containing the survivor ID
/// and an optional snapshot for undo.
class SiteMergeResult {
  final String survivorId;
  final MergeSnapshot? snapshot;

  const SiteMergeResult({required this.survivorId, this.snapshot});
}

/// Snapshot captured before a merge so the operation can be reversed.
class MergeSnapshot {
  final domain.DiveSite originalSurvivor;
  final List<domain.DiveSite> deletedSites;
  final Map<String, String> diveOriginalSiteIds;
  final Map<String, String> mediaOriginalSiteIds;

  /// Site feature id -> the site it belonged to before the merge.
  final Map<String, String> featureOriginalSiteIds;
  final List<SiteSpeciesSnapshot> deletedSpeciesEntries;
  final List<SiteSpeciesSnapshot> modifiedSpeciesEntries;

  /// Original createdAt/updatedAt for each deleted site, keyed by site ID.
  /// DiveSite domain entity does not carry timestamps, so they are captured
  /// separately from the database row before deletion.
  final Map<String, ({int createdAt, int updatedAt})> deletedSiteTimestamps;

  /// Original createdAt/updatedAt for the survivor site before merge.
  final ({int createdAt, int updatedAt})? survivorTimestamps;

  const MergeSnapshot({
    required this.originalSurvivor,
    required this.deletedSites,
    required this.diveOriginalSiteIds,
    required this.mediaOriginalSiteIds,
    this.featureOriginalSiteIds = const {},
    required this.deletedSpeciesEntries,
    required this.modifiedSpeciesEntries,
    this.deletedSiteTimestamps = const {},
    this.survivorTimestamps,
  });
}

/// Lightweight snapshot of a site_species row for undo.
class SiteSpeciesSnapshot {
  final String id;
  final String siteId;
  final String speciesId;
  final String notes;
  final int createdAt;

  const SiteSpeciesSnapshot({
    required this.id,
    required this.siteId,
    required this.speciesId,
    required this.notes,
    required this.createdAt,
  });
}
