import 'dart:math' as math;

import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/dive_log/domain/entities/tank_extra_regulators.dart';
import 'package:submersion/features/equipment/data/repositories/tank_regulator_sql.dart';

/// Chunk size for the `IN (...)` lists. The select binds each chunk three
/// times (the cylinder, the first regulator and the extra regulators), so
/// it must stay under a third of SQLite's ~999 limit.
const _chunkSize = 300;

/// Clears every dive tank link to the gear items in [equipmentIds], both the
/// cylinder's own item (`equipment_id`, written by the transmitter registry)
/// and the regulators it was breathed from (`regulator_equipment_id` and
/// `extra_regulator_ids`), and stages each cleared tank for sync. A deleted
/// first regulator hands its place to the next extra (issue #3375).
///
/// Call it inside the deleting transaction, before the items go. The schema
/// sets the two id links null on delete (v202, v210), but that write reaches
/// no peer, and the extras are a JSON list with no foreign key at all.
/// `dive_tanks` has no `updated_at`; staging a tank stamps its `hlc`, and a
/// pending tank is exported on its own
/// (SyncDataSerializer.parentGatedChildEntities). The parent dive is
/// deliberately NOT staged: re-stamping it would make this device's whole
/// dive row win under last-writer-wins and overwrite a newer edit to that
/// dive made on another device, although the dive itself did not change.
/// Trip cylinder slots holding the gear are cleared and staged too. Shared
/// by every path that deletes gear, so a bulk delete cannot skip the staging
/// a single delete does.
Future<void> clearCylinderGearLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Iterable<String> equipmentIds, {
  required int now,
}) async {
  final deleted = equipmentIds.toSet();
  final ids = deleted.toList();
  final tankIds = <String>{};
  for (var i = 0; i < ids.length; i += _chunkSize) {
    final chunk = ids.sublist(i, math.min(i + _chunkSize, ids.length));
    final marks = List.filled(chunk.length, '?').join(', ');
    final vars = [for (final id in chunk) Variable.withString(id)];
    final tanks = await db
        .customSelect(
          'SELECT t.id, t.regulator_equipment_id, t.extra_regulator_ids '
          'FROM dive_tanks t WHERE t.equipment_id IN ($marks) '
          'OR ${tankNamesAnyRegulatorSql('t', marks)}',
          variables: [...vars, ...vars, ...vars],
        )
        .get();
    if (tanks.isEmpty) continue;
    // Stamped in the write as well as marked below, so the clear carries its
    // own clock and a peer's older copy cannot restore the link (#2644).
    final clearedAt = await syncRepository.issueRowClock();
    await (db.update(
      db.diveTanks,
    )..where((t) => t.equipmentId.isIn(chunk))).write(
      DiveTanksCompanion(equipmentId: const Value(null), hlc: Value(clearedAt)),
    );
    // A tank with no extras only loses its first regulator: one statement
    // per chunk, as before extras existed.
    await (db.update(db.diveTanks)..where(
          (t) =>
              t.regulatorEquipmentId.isIn(chunk) & t.extraRegulatorIds.isNull(),
        ))
        .write(
          DiveTanksCompanion(
            regulatorEquipmentId: const Value(null),
            hlc: Value(clearedAt),
          ),
        );
    // A tank with extras is rebuilt from its survivors, so the next extra
    // moves up when the first goes.
    for (final row in tanks) {
      final raw = row.readNullable<String>('extra_regulator_ids');
      if (raw == null) continue;
      final first = row.readNullable<String>('regulator_equipment_id');
      final extras = decodeExtraRegulatorIds(raw);
      if (!deleted.contains(first) && !extras.any(deleted.contains)) {
        continue;
      }
      final kept = normalizeTankRegulators(null, [
        for (final id in [?first, ...extras])
          if (!deleted.contains(id)) id,
      ]);
      await (db.update(
        db.diveTanks,
      )..where((t) => t.id.equals(row.read<String>('id')))).write(
        DiveTanksCompanion(
          regulatorEquipmentId: Value(kept.first),
          extraRegulatorIds: Value(encodeExtraRegulatorIds(kept.extras)),
          hlc: Value(clearedAt),
        ),
      );
    }
    tankIds.addAll(tanks.map((t) => t.read<String>('id')));
  }
  for (final id in tankIds) {
    await syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: id,
      localUpdatedAt: now,
    );
  }
  // Trip cylinder slots holding the gear: cleared and staged the same way.
  await clearTripCylinderEquipmentLinks(db, syncRepository, ids, now: now);
}
