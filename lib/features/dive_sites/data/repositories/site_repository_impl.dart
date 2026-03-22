import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;

class SiteRepository {
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

        if (diverId != null) {
          query.where((t) => t.diverId.equals(diverId));
        }

        final rows = await query.get();
        return rows.map(_mapRowToSite).toList();
      });
    } catch (e, stackTrace) {
      _log.error('Failed to get all sites', e, stackTrace);
      rethrow;
    }
  }

  /// Get a single site by ID
  Future<domain.DiveSite?> getSiteById(String id) async {
    try {
      final query = _db.select(_db.diveSites)..where((t) => t.id.equals(id));

      final row = await query.getSingleOrNull();
      return row != null ? _mapRowToSite(row) : null;
    } catch (e, stackTrace) {
      _log.error('Failed to get site by id: $id', e, stackTrace);
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
              country: Value(site.country),
              region: Value(site.region),
              rating: Value(site.rating),
              notes: Value(site.notes),
              hazards: Value(site.hazards),
              accessNotes: Value(site.accessNotes),
              mooringNumber: Value(site.mooringNumber),
              parkingInfo: Value(site.parkingInfo),
              altitude: Value(site.altitude),
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
      _log.error('Failed to create site: ${site.name}', e, stackTrace);
      rethrow;
    }
  }

  /// Update an existing site
  Future<void> updateSite(domain.DiveSite site) async {
    try {
      _log.info('Updating site: ${site.id}');
      final now = DateTime.now().millisecondsSinceEpoch;

      await (_db.update(
        _db.diveSites,
      )..where((t) => t.id.equals(site.id))).write(
        DiveSitesCompanion(
          name: Value(site.name),
          description: Value(site.description),
          latitude: Value(site.location?.latitude),
          longitude: Value(site.location?.longitude),
          minDepth: Value(site.minDepth),
          maxDepth: Value(site.maxDepth),
          difficulty: Value(site.difficulty?.name),
          country: Value(site.country),
          region: Value(site.region),
          rating: Value(site.rating),
          notes: Value(site.notes),
          hazards: Value(site.hazards),
          accessNotes: Value(site.accessNotes),
          mooringNumber: Value(site.mooringNumber),
          parkingInfo: Value(site.parkingInfo),
          altitude: Value(site.altitude),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'diveSites',
        recordId: site.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Updated site: ${site.id}');
    } catch (e, stackTrace) {
      _log.error('Failed to update site: ${site.id}', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a site
  Future<void> deleteSite(String id) async {
    try {
      _log.info('Deleting site: $id');
      await (_db.delete(_db.diveSites)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: 'diveSites', recordId: id);
      SyncEventBus.notifyLocalChange();
      _log.info('Deleted site: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete site: $id', e, stackTrace);
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
      _log.error('Failed to get sites by ids', e, stackTrace);
      rethrow;
    }
  }

  /// Bulk delete multiple sites
  Future<void> bulkDeleteSites(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      _log.info('Bulk deleting ${ids.length} sites');
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
      _log.error('Failed to bulk delete sites', e, stackTrace);
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
        deletedSpeciesEntries: deletedSpecies,
        modifiedSpeciesEntries: modifiedSpecies,
      );
    } catch (e, stackTrace) {
      _log.error('Failed to merge sites: $siteIds', e, stackTrace);
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
                  country: Value(site.country),
                  region: Value(site.region),
                  rating: Value(site.rating),
                  notes: Value(site.notes),
                  hazards: Value(site.hazards),
                  accessNotes: Value(site.accessNotes),
                  mooringNumber: Value(site.mooringNumber),
                  parkingInfo: Value(site.parkingInfo),
                  altitude: Value(site.altitude),
                  createdAt: Value(now),
                  updatedAt: Value(now),
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
                  createdAt: Value(now),
                ),
              );
          await _syncRepository.markRecordPending(
            entityType: 'site_species',
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
            entityType: 'site_species',
            recordId: entry.id,
            localUpdatedAt: now,
          );
        }
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Undo merge complete');
    } catch (e, stackTrace) {
      _log.error('Failed to undo merge', e, stackTrace);
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
                t.region.contains(query),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]);

        if (diverId != null) {
          searchQuery.where((t) => t.diverId.equals(diverId));
        }

        final rows = await searchQuery.get();
        return rows.map(_mapRowToSite).toList();
      });
    } catch (e, stackTrace) {
      _log.error('Failed to search sites: $query', e, stackTrace);
      rethrow;
    }
  }

  /// Get dive count per site
  Future<Map<String, int>> getDiveCountsBySite() async {
    try {
      final result = await _db.customSelect('''
        SELECT site_id, COUNT(*) as dive_count
        FROM dives
        WHERE site_id IS NOT NULL
        GROUP BY site_id
      ''').get();

      return {
        for (final row in result)
          row.data['site_id'] as String: row.data['dive_count'] as int,
      };
    } catch (e, stackTrace) {
      _log.error('Failed to get dive counts by site', e, stackTrace);
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
        final counts = await getDiveCountsBySite();

        return sites
            .map(
              (site) => SiteWithDiveCount(
                site: site,
                diveCount: counts[site.id] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.diveCount.compareTo(a.diveCount));
      });
    } catch (e, stackTrace) {
      _log.error('Failed to get sites with dive counts', e, stackTrace);
      rethrow;
    }
  }

  domain.DiveSite _mapRowToSite(DiveSite row) {
    return domain.DiveSite(
      id: row.id,
      diverId: row.diverId,
      name: row.name,
      description: row.description,
      location: row.latitude != null && row.longitude != null
          ? domain.GeoPoint(row.latitude!, row.longitude!)
          : null,
      minDepth: row.minDepth,
      maxDepth: row.maxDepth,
      difficulty: domain.SiteDifficulty.fromString(row.difficulty),
      country: row.country,
      region: row.region,
      rating: row.rating,
      notes: row.notes,
      hazards: row.hazards,
      accessNotes: row.accessNotes,
      mooringNumber: row.mooringNumber,
      parkingInfo: row.parkingInfo,
      altitude: row.altitude,
    );
  }

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
        country: Value(site.country),
        region: Value(site.region),
        rating: Value(site.rating),
        notes: Value(site.notes),
        hazards: Value(site.hazards),
        accessNotes: Value(site.accessNotes),
        mooringNumber: Value(site.mooringNumber),
        parkingInfo: Value(site.parkingInfo),
        altitude: Value(site.altitude),
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
          entityType: 'site_species',
          recordId: primary.id,
          localUpdatedAt: now,
        );
      }

      for (final duplicate in rows.skip(1)) {
        await (_db.delete(
          _db.siteSpecies,
        )..where((t) => t.id.equals(duplicate.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'site_species',
          recordId: duplicate.id,
        );
      }
    }
  }
}

class SiteWithDiveCount {
  final domain.DiveSite site;
  final int diveCount;

  SiteWithDiveCount({required this.site, required this.diveCount});
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
  final List<SiteSpeciesSnapshot> deletedSpeciesEntries;
  final List<SiteSpeciesSnapshot> modifiedSpeciesEntries;

  const MergeSnapshot({
    required this.originalSurvivor,
    required this.deletedSites,
    required this.diveOriginalSiteIds,
    required this.mediaOriginalSiteIds,
    required this.deletedSpeciesEntries,
    required this.modifiedSpeciesEntries,
  });
}

/// Lightweight snapshot of a site_species row for undo.
class SiteSpeciesSnapshot {
  final String id;
  final String siteId;
  final String speciesId;
  final String notes;

  const SiteSpeciesSnapshot({
    required this.id,
    required this.siteId,
    required this.speciesId,
    required this.notes,
  });
}
