import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

typedef EquipmentPacking = ({String tripId, String? bagId});

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

  /// The trip's gear in a bag, item to bag. An item whose bag is no longer
  /// packed on the trip, or is no longer a bag, rides loose, and an item
  /// that has itself become a bag is in no bag.
  Future<Map<String, String>> bagAssignmentsForTrip(String tripId) async {
    final rows = await _db
        .customSelect(
          'SELECT item.equipment_id AS item, item.bag_equipment_id AS bag '
          'FROM trip_equipment item '
          'JOIN trip_equipment packed ON packed.trip_id = item.trip_id '
          'AND packed.equipment_id = item.bag_equipment_id '
          'JOIN equipment bag ON bag.id = item.bag_equipment_id '
          'AND bag.type = ? '
          'JOIN equipment gear ON gear.id = item.equipment_id '
          'AND gear.type != ? '
          'WHERE item.trip_id = ?',
          variables: [
            Variable.withString(EquipmentType.bag.name),
            Variable.withString(EquipmentType.bag.name),
            Variable.withString(tripId),
          ],
          readsFrom: {_db.tripEquipment, _db.equipment},
        )
        .get();
    return {
      for (final row in rows) row.read<String>('item'): row.read<String>('bag'),
    };
  }

  Future<List<EquipmentPacking>> packingForEquipment(String equipmentId) async {
    final rows =
        await (_db.select(_db.tripEquipment)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([(t) => OrderingTerm.asc(t.tripId)]))
            .get();
    return [
      for (final row in rows) (tripId: row.tripId, bagId: row.bagEquipmentId),
    ];
  }

  /// Packs gear and assigns it in one transaction. Gear whose bag has left
  /// the trip since it was chosen is packed loose.
  Future<void> packInBag(String tripId, String equipmentId, String bagId) =>
      _db.transaction(() async {
        await pack(tripId, [equipmentId]);
        await assignBag(tripId, equipmentId, bagId, orLoose: true);
      });

  /// Moves packed gear between the bags on this trip. Null means loose gear.
  /// A bag that is not a bag packed on this trip throws, or with [orLoose]
  /// leaves the gear loose: a sitting's held choice can outlive its bag,
  /// unpacked on another device before Save.
  Future<void> assignBag(
    String tripId,
    String equipmentId,
    String? bagId, {
    bool orLoose = false,
  }) async {
    final changed = await _db.transaction(() async {
      final packed = _db.tripEquipment;
      final item =
          await (_db.select(packed)..where(
                (t) =>
                    t.tripId.equals(tripId) & t.equipmentId.equals(equipmentId),
              ))
              .getSingleOrNull();
      if (item == null) return false;
      var target = bagId;
      if (target != null) {
        final inventory = _db.equipment;
        final candidates =
            await (_db.select(packed).join([
                  innerJoin(
                    inventory,
                    inventory.id.equalsExp(packed.equipmentId),
                  ),
                ])..where(
                  packed.tripId.equals(tripId) &
                      packed.equipmentId.isIn([target, equipmentId]) &
                      inventory.type.equals(EquipmentType.bag.name),
                ))
                .get();
        if (target == equipmentId ||
            candidates.length != 1 ||
            candidates.single.readTable(packed).equipmentId != target) {
          if (!orLoose) {
            throw StateError('Choose a packed bag from the same trip');
          }
          target = null;
        }
      }
      if (item.bagEquipmentId == target) return false;
      await _setBagForRows([item], target);
      return true;
    });
    if (changed) SyncEventBus.notifyLocalChange();
  }

  /// Sets the bag of each of [rows] under one clock, which is both the row
  /// clock and the bag's own (see TripEquipment.bagHlc).
  Future<void> _setBagForRows(
    List<TripEquipmentRow> rows,
    String? bagId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in rows) {
      final clock = await _syncRepository.issueRowClock();
      await (_db.update(
        _db.tripEquipment,
      )..where((t) => t.id.equals(row.id))).write(
        TripEquipmentCompanion(
          bagEquipmentId: Value(bagId),
          bagHlc: Value(clock),
          hlc: Value(clock),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: entity,
        recordId: row.id,
        localUpdatedAt: now,
        stampClock: false,
      );
    }
  }

  Future<void> _clearBag(String equipmentId, {String? tripId}) async {
    final rows =
        await (_db.select(_db.tripEquipment)..where(
              (t) =>
                  t.bagEquipmentId.equals(equipmentId) &
                  (tripId == null
                      ? const Constant(true)
                      : t.tripId.equals(tripId)),
            ))
            .get();
    await _setBagForRows(rows, null);
  }

  /// Packs each of [equipmentIds] for [tripId]; a pair already packed is
  /// left alone. Returns how many were added. Gear still naming a newly
  /// packed item as its bag, left by an unpack that did not clear it (an
  /// older app version, or a sync), comes out of it: a bag packed again
  /// starts empty.
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
      final stale =
          await (_db.select(_db.tripEquipment)..where(
                (t) =>
                    t.tripId.equals(tripId) &
                    t.bagEquipmentId.isIn([
                      for (final r in rows) r.equipmentId.value,
                    ]),
              ))
              .get();
      await _setBagForRows(stale, null);
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
      await _clearBag(equipmentId, tripId: tripId);
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
    await _clearBag(equipmentId);
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
