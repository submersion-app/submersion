import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// Nulls the slot link on every tank pointing at [cylinderIds] and stages
/// those tanks, the way clearCylinderGearLinks does for gear. The schema's
/// ON DELETE SET NULL would clear them too, but a cascade reaches no peer;
/// staging the tank sends the cleared row. A trip holds a handful of slots,
/// so no chunking is needed here.
Future<void> clearTripCylinderLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Iterable<String> cylinderIds, {
  required int now,
}) async {
  final ids = cylinderIds.toSet().toList();
  if (ids.isEmpty) return;
  final tanks = await (db.select(
    db.diveTanks,
  )..where((t) => t.tripCylinderId.isIn(ids))).get();
  if (tanks.isEmpty) return;
  await (db.update(db.diveTanks)..where((t) => t.tripCylinderId.isIn(ids)))
      .write(const DiveTanksCompanion(tripCylinderId: Value(null)));
  for (final tank in tanks) {
    await syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: tank.id,
      localUpdatedAt: now,
    );
  }
}

/// Drops the links on [diveId]'s tanks that point at a slot of any trip
/// other than [tripId] (every link when [tripId] is null) and stages those
/// tanks. A link means nothing outside its trip, so a dive that moves, or
/// leaves its trip, cannot keep one.
Future<void> clearForeignTripCylinderLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  String diveId, {
  required String? tripId,
  required int now,
}) async {
  final rows = await db
      .customSelect(
        '''
        SELECT t.id FROM dive_tanks t
        WHERE t.dive_id = ?1
          AND t.trip_cylinder_id IS NOT NULL
          AND (?2 IS NULL OR t.trip_cylinder_id NOT IN
               (SELECT id FROM trip_cylinders WHERE trip_id = ?2))
        ''',
        variables: [Variable<String>(diveId), Variable<String>(tripId)],
        readsFrom: {db.diveTanks, db.tripCylinders},
      )
      .get();
  if (rows.isEmpty) return;
  final ids = rows.map((r) => r.read<String>('id')).toList();
  await (db.update(db.diveTanks)..where((t) => t.id.isIn(ids))).write(
    const DiveTanksCompanion(tripCylinderId: Value(null)),
  );
  for (final id in ids) {
    await syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: id,
      localUpdatedAt: now,
    );
  }
}
