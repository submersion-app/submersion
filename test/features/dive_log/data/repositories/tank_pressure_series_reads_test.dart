import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TankPressureRepository tanks;
  late TankPressureSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    tanks = TankPressureRepository();
    series = TankPressureSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final tank in ['tank-a', 'tank-b']) {
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: tank, diveId: 'dive-1'));
    }
  });

  tearDown(tearDownTestDatabase);

  test('getTankPressuresForDive groups series by tank', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200.0),
        TankPressureSample(timestamp: 60, pressure: 190.0),
      ],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: const [TankPressureSample(timestamp: 0, pressure: 210.0)],
      now: now,
    );
    final byTank = await tanks.getTankPressuresForDive('dive-1');
    expect(byTank.keys.toSet(), {'tank-a', 'tank-b'});
    expect(byTank['tank-a']!.map((p) => p.pressure), [200.0, 190.0]);
    expect(byTank['tank-a']!.first.tankId, 'tank-a');
    expect(
      (await tanks.getPressuresForTank('dive-1', 'tank-b')).single.pressure,
      210.0,
    );
    expect(await tanks.hasTankPressures('dive-1'), isTrue);
  });

  test('getDiveById derives start and end pressure from the series', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200.0),
        TankPressureSample(timestamp: 60, pressure: 190.0),
        TankPressureSample(timestamp: 120, pressure: 150.0),
      ],
      now: now,
    );
    final dive = await DiveRepository().getDiveById('dive-1');
    final tankA = dive!.tanks.singleWhere((t) => t.id == 'tank-a');
    expect(tankA.startPressure, 200.0);
    expect(tankA.endPressure, 150.0);
  });

  test('multiple series for one tank interleave by timestamp', () async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'comp-1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await series.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      computerId: 'comp-1',
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200.0),
        TankPressureSample(timestamp: 1800, pressure: 150.0),
        TankPressureSample(timestamp: 3600, pressure: 100.0),
      ],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [
        TankPressureSample(timestamp: 900, pressure: 180.0),
        TankPressureSample(timestamp: 2700, pressure: 120.0),
      ],
      now: now,
    );
    final byTank = await tanks.getTankPressuresForDive('dive-1');
    expect(byTank['tank-a']!.map((p) => p.timestamp), [
      0,
      900,
      1800,
      2700,
      3600,
    ]);
    expect(byTank['tank-a']!.map((p) => p.pressure), [
      200.0,
      180.0,
      150.0,
      120.0,
      100.0,
    ]);
    final forTank = await tanks.getPressuresForTank('dive-1', 'tank-a');
    expect(forTank.map((p) => p.timestamp), [0, 900, 1800, 2700, 3600]);
    expect(forTank.map((p) => p.pressure), [200.0, 180.0, 150.0, 120.0, 100.0]);
    final dive = await DiveRepository().getDiveById('dive-1');
    final tankA = dive!.tanks.singleWhere((t) => t.id == 'tank-a');
    expect(tankA.startPressure, 200.0);
    expect(tankA.endPressure, 100.0);
  });

  test('a dive with no tank series has no pressures', () async {
    expect(await tanks.getTankPressuresForDive('dive-1'), isEmpty);
    expect(await tanks.hasTankPressures('dive-1'), isFalse);
  });
}
