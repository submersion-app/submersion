import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

/// A set used in bulk edit applies its weights and cylinders as well as its
/// gear (issue #4525), only where a dive has none, and undo takes back
/// exactly what it wrote.
void main() {
  late AppDatabase db;
  late BulkDiveEditService service;
  late DiveRepository diveRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    service = BulkDiveEditService(
      diveRepo,
      BuddyRepository(),
      SpeciesRepository(),
    );
    // d1 has nothing; d2 has its own lead and a tank with no size.
    for (final id in ['d1', 'd2']) {
      await diveRepo.createDive(
        domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
      );
    }
    await db.customStatement(
      'INSERT INTO dive_weights (id, dive_id, weight_type, amount_kg, '
      "created_at) VALUES ('own', 'd2', 'belt', 5.0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, tank_role, o2_percent, '
      "tank_order) VALUES ('t2', 'd2', 'backGas', 28.0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('bcd', 'BCD', 'bcd', 0, 0), ('reg', 'Reg', 'regulator', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_sets (id, name, created_at, updated_at) '
      "VALUES ('warm', 'Warm', 0, 0), ('lead', 'Lead only', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_set_items (set_id, equipment_id) '
      "VALUES ('warm', 'bcd'), ('warm', 'reg')",
    );
    await db.customStatement(
      'INSERT INTO weight_presets (id, display_name, created_at, updated_at) '
      "VALUES ('belt8', 'Belt', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO weight_preset_entries (id, preset_id, weight_type, '
      "amount_kg, created_at) VALUES ('e1', 'belt8', 'belt', 3.63, 0)",
    );
    await db.customStatement(
      'INSERT INTO cylinder_configs (id, name, created_at, updated_at) '
      "VALUES ('al80', 'AL80', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO cylinder_config_items (id, config_id, tank_role, '
      'volume_l, o2_percent, created_at, updated_at) '
      "VALUES ('ci1', 'al80', 'backGas', 11.1, 32.0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_set_weight_presets (id, set_id, preset_id, '
      "created_at) VALUES ('wp1', 'warm', 'belt8', 0), "
      "('wp2', 'lead', 'belt8', 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_set_cylinder_configs (id, set_id, config_id, '
      "created_at) VALUES ('cc1', 'warm', 'al80', 0)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<List<(String, double)>> weightsOf(String diveId) async => [
    for (final r in await (db.select(
      db.diveWeights,
    )..where((w) => w.diveId.equals(diveId))).get())
      (r.id, r.amountKg),
  ];

  Future<List<DiveTank>> tanksOf(String diveId) =>
      (db.select(db.diveTanks)..where((t) => t.diveId.equals(diveId))).get();

  Future<int> gearCount(String diveId) async => (await (db.select(
    db.diveEquipment,
  )..where((r) => r.diveId.equals(diveId))).get()).length;

  BulkEditRequest useSet(String setId) => BulkEditRequest(
    diveIds: const ['d1', 'd2'],
    scalars: const DivesCompanion(),
    ops: [
      EquipmentSetsOp(mode: BulkCollectionMode.add, setIds: [setId]),
    ],
  );

  Future<void> expectApplied() async {
    // The empty dive takes the set's lead and its cylinder, gas included.
    expect((await weightsOf('d1')).map((w) => w.$2), [closeTo(3.63, 1e-9)]);
    final d1 = await tanksOf('d1');
    expect(d1, hasLength(1));
    expect(d1.single.o2Percent, 32);
    // The other keeps its own lead and its own gas; only the gap is filled.
    expect(await weightsOf('d2'), [('own', 5.0)]);
    final d2 = await tanksOf('d2');
    expect(d2, hasLength(1));
    expect(d2.single.id, 't2');
    expect(d2.single.o2Percent, 28);
    expect(d2.single.volume, closeTo(11.1, 1e-9));
  }

  test('adding a set applies its weights and cylinders where a dive has '
      'none', () async {
    await service.apply(useSet('warm'));
    expect(await gearCount('d1'), 2);
    await expectApplied();
  });

  test('gear added through a set, as the bulk form sends it, does the '
      'same', () async {
    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1', 'd2'],
        scalars: DivesCompanion(),
        ops: [
          EquipmentOp(
            mode: BulkCollectionMode.add,
            equipmentIds: ['bcd', 'reg'],
            viaSetId: 'warm',
          ),
        ],
      ),
    );
    await expectApplied();
  });

  test('gear added by hand applies no weights or tanks', () async {
    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        scalars: DivesCompanion(),
        ops: [
          EquipmentOp(mode: BulkCollectionMode.add, equipmentIds: ['bcd']),
        ],
      ),
    );
    expect(await weightsOf('d1'), isEmpty);
    expect(await tanksOf('d1'), isEmpty);
  });

  test('a set with only weights still fills them', () async {
    await service.apply(useSet('lead'));
    expect(await gearCount('d1'), 0);
    expect((await weightsOf('d1')).map((w) => w.$2), [closeTo(3.63, 1e-9)]);
    expect(await weightsOf('d2'), [('own', 5.0)]);
  });

  test('undo takes back the weights and cylinders it wrote and restores '
      'the filled size', () async {
    final snapshot = await service.apply(useSet('warm'));
    await service.undo(snapshot);

    expect(await gearCount('d1'), 0);
    expect(await weightsOf('d1'), isEmpty);
    expect(await tanksOf('d1'), isEmpty);
    // The dive it did not give weights to keeps its very row.
    expect(await weightsOf('d2'), [('own', 5.0)]);
    final d2 = await tanksOf('d2');
    expect(d2.single.id, 't2');
    expect(d2.single.volume, isNull);
  });

  // Undo takes back what the edit wrote, not what the diver added since.
  test('undo leaves a weight added to the dive after the edit', () async {
    final snapshot = await service.apply(useSet('warm'));
    await db
        .into(db.diveWeights)
        .insert(
          DiveWeightsCompanion.insert(
            id: 'later',
            diveId: 'd1',
            weightType: 'belt',
            amountKg: 1.0,
            createdAt: 1700000000000,
          ),
        );
    await service.undo(snapshot);
    expect(await weightsOf('d1'), [('later', 1.0)]);
  });
}
