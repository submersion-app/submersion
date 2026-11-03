import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';
import 'child_write_harness.dart';

/// Cylinder configs and their cylinders, as the config editor saves them:
/// the cylinders replaced whole, gas written as fractions and stored as
/// percent.
void main() {
  late AppDatabase db;
  late ChildWriteHarness h;
  const t = kSeedTime;

  Future<void> equipment(String id, String owner) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: 'Cylinder $id',
          type: 'tank',
          status: const Value('active'),
          createdAt: t,
          updatedAt: t,
          diverId: Value(owner),
        ),
      );

  Map<String, Object?> cylinder(String role, double o2, {double he = 0}) => {
    'role': role,
    'volume_l': 11.1,
    'working_pressure_bar': 207.0,
    'material': 'aluminum',
    'o2_fraction': o2,
    'he_fraction': he,
  };

  Future<List<CylinderConfigItem>> stored(String configId) =>
      (db.select(db.cylinderConfigItems)
            ..where((i) => i.configId.equals(configId))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .get();

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    h = ChildWriteHarness(db);
    await h.seed();
  });
  tearDown(() => tearDownTestDatabase());

  test('cylinder config items take fractions and store percent', () async {
    final id = (await h.run([
      createOp('cylinder_configs', {
        'name': 'Deco pair',
        'items': [cylinder('backGas', 0.32), cylinder('deco', 0.5)],
      }),
    ])).created.single.id;

    final rows = await stored(id);
    expect([for (final r in rows) r.o2Percent], [32.0, 50.0]);
    expect([for (final r in rows) r.tankRole], ['backGas', 'deco']);
    final firstId = rows.first.id;

    await h.run([
      updateOp('cylinder_configs', id, {
        'items': [cylinder('backGas', 0.21)],
      }),
    ]);
    final after = await stored(id);
    expect(after.single.o2Percent, 21.0);
    // An edit keeps the cylinder at the same place, as the editor does.
    expect(after.single.id, firstId);

    final plan = await h.preview([
      updateOp('cylinder_configs', id, {
        'description': 'Air only',
        'items': [cylinder('backGas', 0.21)],
      }),
    ]);
    expect(plan.items.single.fields.keys, ['description']);
  });

  test('gas fractions that pass 1 are refused', () async {
    final plan = await h.preview([
      createOp('cylinder_configs', {
        'name': 'Impossible',
        'items': [cylinder('backGas', 0.5, he: 0.6)],
      }),
    ]);

    expect(plan.items.single.block!.reason, BlockReason.invalidValue);
  });

  test('a config can point at the diver\'s own equipment only', () async {
    await equipment('mine', kDiverA);
    await equipment('theirs', kDiverB);

    final plan = await h.preview([
      createOp('cylinder_configs', {'name': 'Mine', 'equipment_id': 'mine'}),
      createOp('cylinder_configs', {
        'name': 'Theirs',
        'equipment_id': 'theirs',
      }),
    ]);

    expect(plan.items[0].block, isNull);
    expect(plan.items[1].block, isNotNull);
  });
}
