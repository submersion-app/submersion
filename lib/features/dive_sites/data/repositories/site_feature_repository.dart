import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart'
    as domain;

/// CRUD for diver-placed site annotations. Every mutation follows the
/// house write ritual: write the row, mark it pending (which stamps its
/// HLC), bump and mark the parent site, then notify the sync bus.
class SiteFeatureRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// Emits whenever the `site_features` table changes so providers can
  /// refresh after a local write or a sync merge.
  Stream<void> watchFeatureChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.siteFeatures));

  Future<domain.SiteFeature> addFeature({
    required String siteId,
    required String typeName,
    required double latitude,
    required double longitude,
    double? bearingDeg,
    double? depthMeters,
    String name = '',
    String notes = '',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: id,
            siteId: siteId,
            type: typeName,
            latitude: latitude,
            longitude: longitude,
            name: Value(name),
            bearingDeg: Value(bearingDeg),
            depthMeters: Value(depthMeters),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _markPendingAndBumpSite(id, siteId, now);
    return domain.SiteFeature(
      id: id,
      siteId: siteId,
      typeName: typeName,
      name: name,
      latitude: latitude,
      longitude: longitude,
      bearingDeg: bearingDeg,
      depthMeters: depthMeters,
      notes: notes,
    );
  }

  Future<List<domain.SiteFeature>> getFeaturesForSite(String siteId) async {
    final rows =
        await (_db.select(_db.siteFeatures)
              ..where((t) => t.siteId.equals(siteId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows.map(_toDomain).toList();
  }

  /// How many site ids one `IN` clause carries.
  ///
  /// Each id binds a variable, and SQLite refuses a statement past its
  /// limit, so a big enough library would fail the export outright instead
  /// of loading its features. The cap is the one the sync serializer uses
  /// for the same reason: comfortably under the oldest limit still in the
  /// field (999) rather than under whatever the current build happens to
  /// allow.
  static const _idsPerQuery = 900;

  /// Every feature on [siteIds], grouped by site.
  ///
  /// The export writes a whole library's sites at once, so reading them one
  /// site at a time would be a query per site. Sites with no features are
  /// absent from the result rather than mapped to an empty list.
  Future<Map<String, List<domain.SiteFeature>>> getFeaturesForSites(
    List<String> siteIds,
  ) async {
    if (siteIds.isEmpty) return const {};
    final bySite = <String, List<domain.SiteFeature>>{};
    for (var i = 0; i < siteIds.length; i += _idsPerQuery) {
      final chunk = siteIds.sublist(
        i,
        math.min(i + _idsPerQuery, siteIds.length),
      );
      final rows =
          await (_db.select(_db.siteFeatures)
                ..where((t) => t.siteId.isIn(chunk))
                ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
              .get();
      for (final row in rows) {
        (bySite[row.siteId] ??= []).add(_toDomain(row));
      }
    }
    return bySite;
  }

  Future<void> updateFeature(domain.SiteFeature feature) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.siteFeatures,
    )..where((t) => t.id.equals(feature.id))).write(
      SiteFeaturesCompanion(
        type: Value(feature.typeName),
        name: Value(feature.name),
        latitude: Value(feature.latitude),
        longitude: Value(feature.longitude),
        bearingDeg: Value(feature.bearingDeg),
        depthMeters: Value(feature.depthMeters),
        notes: Value(feature.notes),
        updatedAt: Value(now),
      ),
    );
    await _markPendingAndBumpSite(feature.id, feature.siteId, now);
  }

  Future<void> deleteFeature(String id) async {
    final row = await (_db.select(
      _db.siteFeatures,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.siteFeatures)..where((t) => t.id.equals(id))).go();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _syncRepository.logDeletion(entityType: 'siteFeatures', recordId: id);
    await _bumpSite(row.siteId, now);
    SyncEventBus.notifyLocalChange();
  }

  Future<void> _markPendingAndBumpSite(
    String id,
    String siteId,
    int now,
  ) async {
    await _syncRepository.markRecordPending(
      entityType: 'siteFeatures',
      recordId: id,
      localUpdatedAt: now,
    );
    await _bumpSite(siteId, now);
    SyncEventBus.notifyLocalChange();
  }

  /// The parent bump is not cosmetic: peers order a site's annotation
  /// edits against the site itself, and the site row is what a partial
  /// sync fetches first.
  Future<void> _bumpSite(String siteId, int now) async {
    await (_db.update(_db.diveSites)..where((t) => t.id.equals(siteId))).write(
      DiveSitesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'diveSites',
      recordId: siteId,
      localUpdatedAt: now,
    );
  }

  domain.SiteFeature _toDomain(SiteFeature row) => domain.SiteFeature(
    id: row.id,
    siteId: row.siteId,
    typeName: row.type,
    name: row.name,
    latitude: row.latitude,
    longitude: row.longitude,
    bearingDeg: row.bearingDeg,
    depthMeters: row.depthMeters,
    notes: row.notes,
  );
}
