import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// `dive_tanks.equipment_id` is written by the transmitter registry, never
/// by an edit flow. The domain tank exposes it read-only so a cylinder row
/// can find its gear item (condition phase 3a).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'al80',
            name: 'AL80',
            type: 'tank',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't1',
            diveId: 'd1',
          ).copyWith(equipmentId: const Value('al80')),
        );
  });

  tearDown(tearDownTestDatabase);

  test('the gear link is read onto the domain tank', () async {
    final dive = await DiveRepository().getDiveById('d1');
    expect(dive!.tanks.single.equipmentId, 'al80');
  });

  test('an edit that rebuilds the tank keeps the gear link', () async {
    final repo = DiveRepository();
    final dive = await repo.getDiveById('d1');
    await repo.updateDive(
      dive!.copyWith(tanks: [dive.tanks.single.copyWith(startPressure: 200)]),
    );
    final row = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('t1'))).getSingle();
    expect(row.equipmentId, 'al80');
    expect(row.startPressure, 200);
  });
}
