import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

import '../../../../helpers/test_database.dart';

/// A plan's gear junction carries the same provenance as a dive's
/// (issue #1487), so an assembly attached to a plan reads back as one.
void main() {
  late db.AppDatabase database;
  late DivePlanRepository repo;

  setUp(() async {
    database = await setUpTestDatabase();
    repo = DivePlanRepository();
    for (final id in ['reg', 'hose']) {
      await database
          .into(database.equipment)
          .insert(
            db.EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('a plan round-trips gear provenance', () async {
    final t = DateTime(2026, 1, 1);
    final plan = DivePlan(
      id: 'p1',
      name: 'Test',
      createdAt: t,
      updatedAt: t,
      gfLow: 30,
      gfHigh: 70,
      equipmentIds: const ['reg', 'hose'],
      gearProvenance: const [
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg'),
      ],
    );
    await repo.savePlan(plan);
    final read = await repo.getPlan('p1');
    expect(
      read!.gearProvenance
          .firstWhere((p) => p.equipmentId == 'hose')
          .viaEquipmentId,
      'reg',
    );

    // Clearing the provenance on an unchanged membership is an update of
    // the existing rows, not a delete and re-insert.
    await repo.savePlan(read.copyWith(gearProvenance: const []));
    final again = await repo.getPlan('p1');
    expect(again!.equipmentIds, unorderedEquals(['reg', 'hose']));
    expect(again.gearProvenance.every((p) => p.viaEquipmentId == null), isTrue);
  });
}
