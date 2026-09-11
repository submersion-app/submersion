import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// Chunk size for the `IN (...)` lists, well under SQLite's variable limit.
const _chunkSize = 500;

/// Clears every dive tank link to the gear items in [equipmentIds], both the
/// cylinder's own item (`equipment_id`, written by the transmitter registry)
/// and the regulator it was breathed from (`regulator_equipment_id`), and
/// stages each cleared tank and its parent dive for sync.
///
/// Call it inside the deleting transaction, before the items go. The schema
/// sets both links null on delete (v202, v210), but that write reaches no
/// peer: `dive_tanks` carries no clock of its own and exports only through
/// its parent dive's HLC, so the parent dive has to be staged or peers keep
/// the stale link. Shared by every path that deletes gear, so a bulk delete
/// cannot skip the staging a single delete does.
Future<void> clearCylinderGearLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Iterable<String> equipmentIds, {
  required int now,
}) async {
  final ids = equipmentIds.toSet().toList();
  final tankIds = <String>{};
  final diveIds = <String>{};
  for (var i = 0; i < ids.length; i += _chunkSize) {
    final chunk = ids.sublist(i, math.min(i + _chunkSize, ids.length));
    final tanks =
        await (db.select(db.diveTanks)..where(
              (t) =>
                  t.equipmentId.isIn(chunk) |
                  t.regulatorEquipmentId.isIn(chunk),
            ))
            .get();
    if (tanks.isEmpty) continue;
    await (db.update(db.diveTanks)..where((t) => t.equipmentId.isIn(chunk)))
        .write(const DiveTanksCompanion(equipmentId: Value(null)));
    await (db.update(db.diveTanks)
          ..where((t) => t.regulatorEquipmentId.isIn(chunk)))
        .write(const DiveTanksCompanion(regulatorEquipmentId: Value(null)));
    for (final tank in tanks) {
      tankIds.add(tank.id);
      diveIds.add(tank.diveId);
    }
  }
  for (final id in tankIds) {
    await syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: id,
      localUpdatedAt: now,
    );
  }
  for (final id in diveIds) {
    await syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: id,
      localUpdatedAt: now,
    );
  }
}
