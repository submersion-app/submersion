import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart'
    as domain;
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';

/// CRUD for diver-placed site annotations. Every mutation follows the
/// house write ritual: write the row, mark it pending (which stamps its
/// HLC), bump and mark the parent site, then notify the sync bus.
class SiteFeatureRepository {
  SiteFeatureRepository({LibraryEditStamper? stamper})
    : _libraryStamper = stamper ?? LibraryEditStamper();

  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final LibraryEditStamper _libraryStamper;
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
    String? actingDiverId,
    bool stampLibrary = true,
    int? createdAt,
  }) async {
    // A library site [actingDiverId] may not edit (issue #2567). An editing
    // sitting ([stampLibrary] false) was offered only to a profile that may,
    // and names none here: asked with no profile, every local one would
    // have to be able to.
    if (stampLibrary &&
        !await _libraryStamper.mayEdit(siteId, actingDiverId: actingDiverId)) {
      throw StateError('site $siteId is not this profile to edit');
    }
    // Given by a caller adding several at once, so they list in its order.
    final now = createdAt ?? DateTime.now().millisecondsSinceEpoch;
    final feature = domain.SiteFeature(
      id: _uuid.v4(),
      siteId: siteId,
      typeName: typeName,
      name: name,
      latitude: latitude,
      longitude: longitude,
      bearingDeg: bearingDeg,
      depthMeters: depthMeters,
      notes: notes,
    );
    await _insertFeature(feature, now);
    await _markPendingAndBumpSite(
      feature.id,
      siteId,
      now,
      actingDiverId,
      stampLibrary: stampLibrary,
    );
    return feature;
  }

  /// Copies every feature on [fromSiteId] onto [toSiteId] as new rows, in
  /// their creation order, for a duplicated site (issue #3575). All or
  /// nothing: one transaction, with the parent bumped and stamped once.
  Future<void> copyFeatures({
    required String fromSiteId,
    required String toSiteId,
    String? actingDiverId,
  }) async {
    if (!await _libraryStamper.mayEdit(
      toSiteId,
      actingDiverId: actingDiverId,
    )) {
      throw StateError('site $toSiteId is not this profile to edit');
    }
    final features = await getFeaturesForSite(fromSiteId);
    if (features.isEmpty) return;
    final start = DateTime.now().millisecondsSinceEpoch;
    // One millisecond apart: features list by creation time, so tied stamps
    // could come back in any order.
    final last = start + features.length - 1;
    await _db.transaction(() async {
      for (final (i, feature) in features.indexed) {
        final copyId = _uuid.v4();
        await _insertFeature(
          feature.copyWith(id: copyId, siteId: toSiteId),
          start + i,
        );
        await _syncRepository.markRecordPending(
          entityType: 'siteFeatures',
          recordId: copyId,
          localUpdatedAt: start + i,
        );
      }
      await _bumpSite(toSiteId, last);
      await _libraryStamper.stamp(toSiteId, {
        'features',
      }, actingDiverId: actingDiverId);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Writes [feature] as a new row stamped [now].
  Future<void> _insertFeature(domain.SiteFeature feature, int now) async {
    await _db
        .into(_db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: feature.id,
            siteId: feature.siteId,
            type: feature.typeName,
            latitude: feature.latitude,
            longitude: feature.longitude,
            name: Value(feature.name),
            bearingDeg: Value(feature.bearingDeg),
            depthMeters: Value(feature.depthMeters),
            notes: Value(feature.notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<List<domain.SiteFeature>> getFeaturesForSite(String siteId) async {
    final rows =
        await (_db.select(_db.siteFeatures)
              ..where((t) => t.siteId.equals(siteId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                // Features stamped in the same millisecond still list in one
                // order, which a duplicate's copies then follow.
                (t) => OrderingTerm.asc(t.id),
              ]))
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
                ..orderBy([
                  (t) => OrderingTerm.asc(t.createdAt),
                  // Features stamped in the same millisecond still list in one
                  // order, which a duplicate's copies then follow.
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      for (final row in rows) {
        (bySite[row.siteId] ??= []).add(_toDomain(row));
      }
    }
    return bySite;
  }

  /// [actingDiverId] as for [addFeature]; a feature of a library site that
  /// profile may not edit is left as it is.
  ///
  /// [stampLibrary] false, here and on [addFeature] and [deleteFeature],
  /// leaves the library stamp, and the permission, to the caller: an editing sitting writes
  /// inside its own transaction and stamps once that has committed, since
  /// the stamp goes to the shared library store, which a rollback would not
  /// undo (issue #4527).
  Future<void> updateFeature(
    domain.SiteFeature feature, {
    String? actingDiverId,
    bool stampLibrary = true,
  }) async {
    if (stampLibrary &&
        !await _libraryStamper.mayEdit(
          feature.siteId,
          actingDiverId: actingDiverId,
        )) {
      return;
    }
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
    await _markPendingAndBumpSite(
      feature.id,
      feature.siteId,
      now,
      actingDiverId,
      stampLibrary: stampLibrary,
    );
  }

  /// [actingDiverId] and [stampLibrary] as for [updateFeature].
  Future<void> deleteFeature(
    String id, {
    String? actingDiverId,
    bool stampLibrary = true,
  }) async {
    final row = await (_db.select(
      _db.siteFeatures,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null ||
        (stampLibrary &&
            !await _libraryStamper.mayEdit(
              row.siteId,
              actingDiverId: actingDiverId,
            ))) {
      return;
    }
    await (_db.delete(_db.siteFeatures)..where((t) => t.id.equals(id))).go();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _syncRepository.logDeletion(entityType: 'siteFeatures', recordId: id);
    await _bumpSite(row.siteId, now);
    if (stampLibrary) {
      await _libraryStamper.stamp(row.siteId, {
        'features',
      }, actingDiverId: actingDiverId);
    }
    SyncEventBus.notifyLocalChange();
  }

  Future<void> _markPendingAndBumpSite(
    String id,
    String siteId,
    int now,
    String? actingDiverId, {
    bool stampLibrary = true,
  }) async {
    await _syncRepository.markRecordPending(
      entityType: 'siteFeatures',
      recordId: id,
      localUpdatedAt: now,
    );
    await _bumpSite(siteId, now);
    if (stampLibrary) {
      await _libraryStamper.stamp(siteId, {
        'features',
      }, actingDiverId: actingDiverId);
    }
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
