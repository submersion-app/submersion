import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// Gear packed for a trip (issue #2338): the `trip_equipment` links. A
/// parent-gated child of `trips`; writes never touch the trip or item rows
/// (#1769: a child change does not re-stamp its parent).
class TripEquipmentRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  static const String entity = 'tripEquipment';

  /// Emits when a link is written or removed.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripEquipment));

  Future<List<String>> equipmentIdsForTrip(String tripId) =>
      (_db.selectOnly(_db.tripEquipment)
            ..addColumns([_db.tripEquipment.equipmentId])
            ..where(_db.tripEquipment.tripId.equals(tripId)))
          .map((r) => r.read(_db.tripEquipment.equipmentId)!)
          .get();

  Future<Set<String>> tripIdsForEquipment(String equipmentId) async =>
      (await (_db.selectOnly(_db.tripEquipment)
                ..addColumns([_db.tripEquipment.tripId])
                ..where(_db.tripEquipment.equipmentId.equals(equipmentId)))
              .map((r) => r.read(_db.tripEquipment.tripId)!)
              .get())
          .toSet();

  /// Packs each of [equipmentIds] for [tripId]; a pair already packed is
  /// left alone. Returns how many were added.
  Future<int> pack(String tripId, Iterable<String> equipmentIds) async {
    final added = await _db.transaction(() async {
      final existing = (await equipmentIdsForTrip(tripId)).toSet();
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = [
        for (final id in equipmentIds.toSet().difference(existing))
          TripEquipmentCompanion.insert(
            id: _uuid.v4(),
            tripId: tripId,
            equipmentId: id,
            createdAt: now,
          ),
      ];
      if (rows.isEmpty) return 0;
      await _db.batch((b) => b.insertAll(_db.tripEquipment, rows));
      for (final r in rows) {
        await _syncRepository.markRecordPending(
          entityType: entity,
          recordId: r.id.value,
          localUpdatedAt: now,
        );
      }
      return rows.length;
    });
    if (added > 0) SyncEventBus.notifyLocalChange();
    return added;
  }

  /// Unpacks [equipmentId] from [tripId] and tombstones the link.
  Future<void> unpack(String tripId, String equipmentId) async {
    await _db.transaction(() async {
      final ids = await _idsWhere(
        _db.tripEquipment.tripId.equals(tripId) &
            _db.tripEquipment.equipmentId.equals(equipmentId),
      );
      await (_db.delete(_db.tripEquipment)..where(
            (t) => t.tripId.equals(tripId) & t.equipmentId.equals(equipmentId),
          ))
          .go();
      await _syncRepository.logDeletions(entityType: entity, recordIds: ids);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes and tombstones every link of [tripId], for a trip delete.
  /// Cascades write no tombstones, so the trip's delete calls this first
  /// and every peer drops them too. Runs inside the caller's transaction.
  Future<void> deleteByTripId(String tripId) async {
    final ids = await _idsWhere(_db.tripEquipment.tripId.equals(tripId));
    await (_db.delete(
      _db.tripEquipment,
    )..where((t) => t.tripId.equals(tripId))).go();
    await _syncRepository.logDeletions(entityType: entity, recordIds: ids);
  }

  /// As [deleteByTripId], for an item delete.
  Future<void> deleteForEquipment(String equipmentId) async {
    final ids = await _idsWhere(
      _db.tripEquipment.equipmentId.equals(equipmentId),
    );
    await (_db.delete(
      _db.tripEquipment,
    )..where((t) => t.equipmentId.equals(equipmentId))).go();
    await _syncRepository.logDeletions(entityType: entity, recordIds: ids);
  }

  Future<List<String>> _idsWhere(Expression<bool> where) =>
      (_db.selectOnly(_db.tripEquipment)
            ..addColumns([_db.tripEquipment.id])
            ..where(where))
          .map((r) => r.read(_db.tripEquipment.id)!)
          .get();
}
