import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart'
    as domain;

/// CRUD for the diver's wreck catalogue. Every mutation follows the house
/// write ritual: write the row, mark it pending (which stamps its HLC),
/// then notify the sync bus. There is no parent bump, because a wreck is
/// a top-level entity like a dive site rather than a child row.
class WreckRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// Emits whenever the `wrecks` table changes so providers refresh after
  /// a local write or a sync merge.
  Stream<void> watchWreckChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.wrecks));

  /// Inserts [wreck], assigning an id when it carries none.
  Future<domain.Wreck> createWreck(domain.Wreck wreck) async {
    final id = wreck.id.isEmpty ? _uuid.v4() : wreck.id;
    final now = DateTime.now().millisecondsSinceEpoch;
    final stored = wreck.copyWith(id: id);
    await _db.into(_db.wrecks).insert(_companion(stored, now, insert: true));
    await _markPending(id, now);
    return stored;
  }

  Future<List<domain.Wreck>> getAllWrecks() async {
    final rows = await (_db.select(
      _db.wrecks,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
    return rows.map(_toDomain).toList();
  }

  Future<domain.Wreck?> getWreckById(String id) async {
    final row = await (_db.select(
      _db.wrecks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<domain.Wreck>> getWrecksForSite(String siteId) async {
    final rows =
        await (_db.select(_db.wrecks)
              ..where((t) => t.siteId.equals(siteId))
              ..orderBy([(t) => OrderingTerm.asc(t.name)]))
            .get();
    return rows.map(_toDomain).toList();
  }

  Future<void> updateWreck(domain.Wreck wreck) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.wrecks,
    )..where((t) => t.id.equals(wreck.id))).write(_companion(wreck, now));
    await _markPending(wreck.id, now);
  }

  Future<void> deleteWreck(String id) async {
    await (_db.delete(_db.wrecks)..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: 'wrecks', recordId: id);
    SyncEventBus.notifyLocalChange();
  }

  Future<void> _markPending(String id, int now) async {
    await _syncRepository.markRecordPending(
      entityType: 'wrecks',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Every writable column. `createdAt` is set on insert only, so an
  /// update never rewrites when the diver first recorded the wreck.
  WrecksCompanion _companion(domain.Wreck w, int now, {bool insert = false}) {
    return WrecksCompanion(
      id: Value(w.id),
      diverId: Value(w.diverId),
      siteId: Value(w.siteId),
      name: Value(w.name),
      latitude: Value(w.latitude),
      longitude: Value(w.longitude),
      vesselType: Value(w.vesselTypeName),
      causeOfSinking: Value(w.causeName),
      condition: Value(w.conditionName),
      protectedStatus: Value(w.protectionName),
      depthToDeckMeters: Value(w.depthToDeckMeters),
      depthToSeabedMeters: Value(w.depthToSeabedMeters),
      lengthMeters: Value(w.lengthMeters),
      yearBuilt: Value(w.yearBuilt),
      yearSunk: Value(w.yearSunk),
      penetrationPossible: Value(w.penetrationPossible),
      notes: Value(w.notes),
      isShared: Value(w.isShared),
      createdAt: insert ? Value(now) : const Value.absent(),
      updatedAt: Value(now),
    );
  }

  domain.Wreck _toDomain(Wreck row) => domain.Wreck(
    id: row.id,
    diverId: row.diverId,
    siteId: row.siteId,
    name: row.name,
    latitude: row.latitude,
    longitude: row.longitude,
    vesselTypeName: row.vesselType,
    causeName: row.causeOfSinking,
    conditionName: row.condition,
    protectionName: row.protectedStatus,
    depthToDeckMeters: row.depthToDeckMeters,
    depthToSeabedMeters: row.depthToSeabedMeters,
    lengthMeters: row.lengthMeters,
    yearBuilt: row.yearBuilt,
    yearSunk: row.yearSunk,
    penetrationPossible: row.penetrationPossible,
    notes: row.notes,
    isShared: row.isShared,
  );
}
