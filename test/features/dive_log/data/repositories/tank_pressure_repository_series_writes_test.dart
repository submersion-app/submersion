import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TankPressureRepository repo;
  late TankPressureSeriesRepository series;

  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = TankPressureRepository();
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

  test(
    'insertTankPressures writes one null-computer series per tank and skips empty tanks',
    () async {
      await repo.insertTankPressures('dive-1', {
        'tank-a': [
          (timestamp: 60, pressure: 180.0),
          (timestamp: 0, pressure: 200.0),
        ],
        'tank-b': const [],
      });
      final rows = await series.getSeriesForDive('dive-1');
      expect(rows, hasLength(1));
      expect(rows.single.tankId, 'tank-a');
      expect(rows.single.computerId, isNull);
      expect(rows.single.samples.map((s) => s.pressure), [200.0, 180.0]);
      final dive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('dive-1'))).getSingle();
      expect(dive.updatedAt, greaterThan(0));
    },
  );

  test(
    'deleteTankPressuresForDive removes every series with one tombstone each and no legacy tombstones',
    () async {
      final a = await series.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
        now: 1000,
      );
      final b = await series.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-b',
        samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
        now: 1000,
      );
      await repo.deleteTankPressuresForDive('dive-1');
      expect(await series.getSeriesForDive('dive-1'), isEmpty);
      final tombstones = await db.select(db.deletionLog).get();
      expect(tombstones.map((t) => t.recordId).toSet(), {a, b});
      expect(tombstones.map((t) => t.entityType).toSet(), {
        'tankPressureSeries',
      });
    },
  );

  test('replaceTankPressures deletes then inserts', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    await repo.replaceTankPressures('dive-1', {
      'tank-b': [(timestamp: 0, pressure: 150.0)],
    });
    final rows = await series.getSeriesForDive('dive-1');
    expect(rows.single.tankId, 'tank-b');
    expect(rows.single.samples.single.pressure, 150.0);
  });

  test(
    'reassignTankPressureSeries and swapTankPressureSeries move series between tanks',
    () async {
      final a = await series.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
        now: 1000,
      );
      await repo.reassignTankPressureSeries(
        diveId: 'dive-1',
        fromTankId: 'tank-a',
        toTankId: 'tank-b',
      );
      expect((await series.getSeriesForTank('dive-1', 'tank-b')).single.id, a);
      final b = await series.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
        now: 1000,
      );
      await repo.swapTankPressureSeries(
        diveId: 'dive-1',
        tankIdA: 'tank-a',
        tankIdB: 'tank-b',
      );
      expect((await series.getSeriesForTank('dive-1', 'tank-a')).single.id, a);
      expect((await series.getSeriesForTank('dive-1', 'tank-b')).single.id, b);
    },
  );
}
