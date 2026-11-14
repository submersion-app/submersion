import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// A dive computer download applies the weights and cylinders of the sets
/// that land on the dive (issue #4525), after the computer's own tanks are
/// written, so the merge sees them.
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;
  const t = 1700000000000;
  const points = [
    ProfilePointData(timestamp: 0, depth: 1.0),
    ProfilePointData(timestamp: 600, depth: 18.0),
    ProfilePointData(timestamp: 1800, depth: 5.0),
  ];

  Future<void> gear(String id, String type) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: type,
          diverId: const Value('d1'),
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> set(
    String id, {
    required List<String> gear,
    required String presetId,
    double presetKg = 3.63,
    String? configId,
    bool isDefault = false,
    bool autoApply = false,
  }) async {
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: id,
            diverId: const Value('d1'),
            name: id,
            isDefault: Value(isDefault),
            autoApplyOnComputerImport: Value(autoApply),
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final g in gear) {
      await db
          .into(db.equipmentSetItems)
          .insert(EquipmentSetItemsCompanion.insert(setId: id, equipmentId: g));
    }
    await db
        .into(db.weightPresets)
        .insert(
          WeightPresetsCompanion.insert(
            id: presetId,
            displayName: presetId,
            diverId: const Value('d1'),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await db
        .into(db.weightPresetEntries)
        .insert(
          WeightPresetEntriesCompanion.insert(
            id: '$presetId-e',
            presetId: presetId,
            weightType: 'belt',
            amountKg: presetKg,
            createdAt: t,
          ),
        );
    await db
        .into(db.equipmentSetWeightPresets)
        .insert(
          EquipmentSetWeightPresetsCompanion.insert(
            id: '$id-p',
            setId: id,
            presetId: presetId,
            createdAt: t,
          ),
        );
    if (configId != null) {
      await db
          .into(db.cylinderConfigs)
          .insert(
            CylinderConfigsCompanion.insert(
              id: configId,
              name: configId,
              diverId: const Value('d1'),
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.cylinderConfigItems)
          .insert(
            CylinderConfigItemsCompanion.insert(
              id: '$configId-0',
              configId: configId,
              tankRole: 'backGas',
              volumeL: const Value(11.1),
              o2Percent: const Value(32),
              createdAt: t,
              updatedAt: t,
            ),
          );
      await db
          .into(db.equipmentSetCylinderConfigs)
          .insert(
            EquipmentSetCylinderConfigsCompanion.insert(
              id: '$id-c',
              setId: id,
              configId: configId,
              createdAt: t,
            ),
          );
    }
  }

  Future<String> download({List<TankData>? tanks}) => repository.importProfile(
    computerId: 'perdix',
    profileStartTime: DateTime(2026, 7, 4, 10, 0),
    points: points,
    durationSeconds: 2400,
    maxDepth: 18.0,
    diverId: 'd1',
    tanks: tanks,
  );

  Future<List<DiveTank>> tanksOf(String diveId) =>
      (db.select(db.diveTanks)
            ..where((x) => x.diveId.equals(diveId))
            ..orderBy([(x) => OrderingTerm.asc(x.tankOrder)]))
          .get();

  Future<List<double>> weightsOf(String diveId) async {
    final rows = await (db.select(
      db.diveWeights,
    )..where((w) => w.diveId.equals(diveId))).get();
    return [for (final r in rows) r.amountKg]..sort();
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await gear('bcd', 'bcd');
    await gear('pc', 'computer');
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'perdix',
            name: 'Perdix',
            equipmentId: const Value('pc'),
            createdAt: t,
            updatedAt: t,
          ),
        );
    await set(
      'def',
      gear: ['bcd'],
      presetId: 'belt8',
      configId: 'al80',
      isDefault: true,
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a downloaded dive keeps the computer\'s tank and gas, gets the '
      'set\'s size filled in, and gains no extra cylinder', () async {
    final diveId = await download(
      tanks: const [
        TankData(index: 0, o2Percent: 28, startPressure: 200, endPressure: 60),
      ],
    );
    final tanks = await tanksOf(diveId);
    expect(tanks, hasLength(1));
    expect(tanks.single.o2Percent, 28);
    expect(tanks.single.startPressure, 200);
    expect(tanks.single.volume, closeTo(11.1, 1e-9));
    expect(await weightsOf(diveId), [closeTo(3.63, 1e-9)]);
  });

  test('a download with no tanks gets the set\'s cylinder', () async {
    final diveId = await download();
    final tanks = await tanksOf(diveId);
    expect(tanks, hasLength(1));
    expect(tanks.single.o2Percent, 32);
    expect(tanks.single.volume, closeTo(11.1, 1e-9));
  });

  test('the default set and a computer-linked set combine their '
      'weights', () async {
    await set(
      'comp',
      gear: ['pc'],
      presetId: 'pockets6',
      presetKg: 2.72,
      autoApply: true,
    );
    final diveId = await download();
    expect(await weightsOf(diveId), [closeTo(2.72, 1e-9), closeTo(3.63, 1e-9)]);
  });

  test('downloading the same dive again adds nothing', () async {
    const tank = TankData(
      index: 0,
      o2Percent: 28,
      startPressure: 200,
      endPressure: 60,
    );
    final diveId = await download(tanks: const [tank]);
    final again = await download(tanks: const [tank]);
    expect(again, diveId);
    expect(await tanksOf(diveId), hasLength(1));
    expect(await weightsOf(diveId), hasLength(1));
  });
}
