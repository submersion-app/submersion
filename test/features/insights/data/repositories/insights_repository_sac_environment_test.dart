import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3958: the statistics divide a dive's consumption by the ambient
/// pressure of its own water, so they agree with what `Dive.sac` shows it.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;

  // 100 bar of a 12 L cylinder over 50 min at an average of 20 m.
  const dropBar = 100.0;
  const minutes = 50.0;
  const avgDepth = 20.0;
  const volume = 12.0;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository(gasModel: GasModel.ideal);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive({
    String id = 'd1',
    double? altitude,
    double? surfacePressure,
    String? waterType,
    String? siteId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            bottomTime: Value((minutes * 60).toInt()),
            runtime: Value((minutes * 60).toInt()),
            avgDepth: const Value(avgDepth),
            maxDepth: const Value(avgDepth + 5),
            altitude: Value(altitude),
            surfacePressure: Value(surfacePressure),
            waterType: Value(waterType),
            siteId: Value(siteId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('tank-$id'),
            diveId: Value(id),
            startPressure: const Value(200),
            endPressure: const Value(200 - dropBar),
            volume: const Value(volume),
            tankRole: const Value('backGas'),
            o2Percent: const Value(21.0),
            hePercent: const Value(0.0),
            tankOrder: const Value(0),
          ),
        );
  }

  final environment = DiveEnvironment.forConditions(
    altitudeMeters: 3000,
    waterType: WaterType.fresh,
  );
  final ambient = environment.pressureAtDepth(avgDepth);
  final sac = dropBar / minutes / ambient;

  // The same gas volume at an ambient below the flat model's 3 bar. Ideal gas
  // keeps the expected litres free of the compressibility correction.
  final rmv = dropBar * volume / minutes / ambient;

  test('the pressure trend reads the dive environment', () async {
    await insertDive(altitude: 3000, waterType: 'fresh');

    final points = await repository.getSacPressurePerDive();

    expect(points.single.value, closeTo(sac, 1e-9));
  });

  test('the volume trend reads the dive environment', () async {
    await insertDive(altitude: 3000, waterType: 'fresh');

    final points = await repository.getSacVolumePerDive();

    expect(points.single.value, closeTo(rmv, 1e-9));
  });

  test('the pressure records read the dive environment', () async {
    await insertDive(altitude: 3000, waterType: 'fresh');

    final records = await repository.getSacPressureRecords();

    expect(records.best!.value, closeTo(sac, 1e-9));
  });

  test('the volume records read the dive environment', () async {
    await insertDive(altitude: 3000, waterType: 'fresh');

    final records = await repository.getSacVolumeRecords();

    expect(records.best!.value, closeTo(rmv, 1e-9));
  });

  test('the pressure by tank role reads the dive environment', () async {
    await insertDive(altitude: 3000, waterType: 'fresh');

    final byRole = await repository.getSacPressureByTankRole();

    expect(byRole['backGas'], closeTo(sac, 1e-9));
  });

  test('the volume by tank role reads the dive environment', () async {
    await insertDive(altitude: 3000, waterType: 'fresh');

    final byRole = await repository.getSacVolumeByTankRole();

    expect(byRole['backGas'], closeTo(rmv, 1e-9));
  });

  test('a recorded surface pressure wins over the altitude', () async {
    await insertDive(altitude: 3000, surfacePressure: 0.95, waterType: 'salt');
    final environment = DiveEnvironment.forConditions(
      altitudeMeters: 3000,
      surfacePressureBar: 0.95,
      waterType: WaterType.salt,
    );

    final points = await repository.getSacPressurePerDive();

    expect(
      points.single.value,
      closeTo(dropBar / minutes / environment.pressureAtDepth(avgDepth), 1e-9),
    );
  });

  test('a dive with no water type takes its site\'s', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: const Value('s1'),
            name: const Value('Lake'),
            waterType: const Value('fresh'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await insertDive(siteId: 's1');
    const fresh = DiveEnvironment(
      waterDensityKgM3: DiveEnvironment.freshWaterDensity,
    );

    final points = await repository.getSacPressurePerDive();

    expect(
      points.single.value,
      closeTo(dropBar / minutes / fresh.pressureAtDepth(avgDepth), 1e-9),
    );
  });

  test('the SQL and the dive entity agree on one dive', () async {
    await insertDive(altitude: 3000, waterType: 'fresh');
    final dive = domain.Dive(
      id: 'd1',
      dateTime: DateTime.utc(2026),
      runtime: const Duration(minutes: 50),
      avgDepth: avgDepth,
      altitude: 3000,
      waterType: WaterType.fresh,
      tanks: const [
        domain.DiveTank(
          id: 't1',
          volume: volume,
          startPressure: 200,
          endPressure: 200 - dropBar,
          role: TankRole.backGas,
        ),
      ],
    );

    final points = await repository.getSacPressurePerDive();

    expect(points.single.value, closeTo(dive.sac!, 1e-9));
  });

  test('a dive with no conditions keeps the flat model', () async {
    await insertDive();

    final points = await repository.getSacPressurePerDive();

    expect(points.single.value, closeTo(dropBar / minutes / 3, 1e-6));
  });
}
