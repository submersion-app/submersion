import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
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
      final query = _db.select(_db.diveSites)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]);

      if (diverId != null) {
        query.where((t) => t.diverId.equals(diverId));
      }

      final rows = await query.get();
      return rows.map(_mapRowToSite).toList();
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

  /// Search sites by name or location
  Future<List<domain.DiveSite>> searchSites(
    String query, {
    String? diverId,
  }) async {
    try {
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
      final sites = await getAllSites(diverId: diverId);
      final counts = await getDiveCountsBySite();

      return sites
          .map(
            (site) =>
                SiteWithDiveCount(site: site, diveCount: counts[site.id] ?? 0),
          )
          .toList()
        ..sort((a, b) => b.diveCount.compareTo(a.diveCount));
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
    );
  }
}

class SiteWithDiveCount {
  final domain.DiveSite site;
  final int diveCount;

  SiteWithDiveCount({required this.site, required this.diveCount});
}
