import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TankPressureSeriesRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Comp 1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final tank in ['tank-a', 'tank-b']) {
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: tank, diveId: 'dive-1'));
    }
    repo = TankPressureSeriesRepository();
  });

  tearDown(tearDownTestDatabase);

  test(
    'insertSeries sorts by timestamp and keeps input order for ties',
    () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        samples: const [
          TankPressureSample(timestamp: 60, pressure: 180.0),
          TankPressureSample(timestamp: 0, pressure: 200.0),
          TankPressureSample(timestamp: 60, pressure: 181.0),
        ],
        now: 1000,
      );
      final series = (await repo.getSeriesForDive('dive-1')).single;
      expect(series.id, id);
      expect(series.samples.map((s) => (s.timestamp, s.pressure)).toList(), [
        (0, 200.0),
        (60, 180.0),
        (60, 181.0),
      ]);
    },
  );

  test(
    'reassignTank moves every series of the tank and restamps hlc',
    () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
        now: 1000,
      );
      final before = (await db.select(db.tankPressureSeries).get()).single.hlc;
      expect(
        await repo.reassignTank('dive-1', 'tank-a', 'tank-b', now: 2000),
        1,
      );
      final row = (await db.select(db.tankPressureSeries).get()).single;
      expect(row.id, id);
      expect(row.tankId, 'tank-b');
      expect(row.updatedAt, 2000);
      expect(row.hlc, isNot(before));
      expect(await repo.reassignTank('dive-1', 'tank-a', 'tank-b'), 0);
    },
  );

  test('swapTanks exchanges the tank ids of both sets', () async {
    final a = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final b = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
      now: 1000,
    );
    await repo.swapTanks('dive-1', 'tank-a', 'tank-b', now: 2000);
    final rows = await db.select(db.tankPressureSeries).get();
    expect(rows.firstWhere((r) => r.id == a).tankId, 'tank-b');
    expect(rows.firstWhere((r) => r.id == b).tankId, 'tank-a');
  });

  test('swapTanks without now stamps the current wall-clock time', () async {
    final a = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final b = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
      now: 1000,
    );
    await repo.swapTanks('dive-1', 'tank-a', 'tank-b');
    final rows = await db.select(db.tankPressureSeries).get();
    expect(rows.firstWhere((r) => r.id == a).tankId, 'tank-b');
    expect(rows.firstWhere((r) => r.id == b).tankId, 'tank-a');
    expect(rows.firstWhere((r) => r.id == a).updatedAt, greaterThan(0));
    expect(rows.firstWhere((r) => r.id == b).updatedAt, greaterThan(0));
  });

  test('stampComputerWhereNull touches only null-computer series', () async {
    final manual = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final owned = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      computerId: 'comp-1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
      now: 1000,
    );
    expect(await repo.stampComputerWhereNull('dive-1', 'comp-1', now: 2000), 1);
    final rows = await db.select(db.tankPressureSeries).get();
    expect(rows.firstWhere((r) => r.id == manual).computerId, 'comp-1');
    expect(rows.firstWhere((r) => r.id == manual).updatedAt, 2000);
    expect(rows.firstWhere((r) => r.id == owned).updatedAt, 1000);
  });

  test(
    'stampComputerWhereNull without now stamps the current wall-clock time',
    () async {
      final manual = await repo.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
        now: 1000,
      );
      expect(await repo.stampComputerWhereNull('dive-1', 'comp-1'), 1);
      final row = await (db.select(
        db.tankPressureSeries,
      )..where((t) => t.id.equals(manual))).getSingle();
      expect(row.computerId, 'comp-1');
      expect(row.updatedAt, greaterThan(0));
    },
  );

  test('getRowsForDives chunks past the SQL variable ceiling', () async {
    const count = 2000;
    final diveIds = [for (var i = 0; i < count; i++) 'chunk-dive-$i'];
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.batch(
      (b) => b.insertAll(db.dives, [
        for (final id in diveIds)
          DivesCompanion.insert(
            id: id,
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
      ]),
    );
    await db.batch(
      (b) => b.insertAll(db.diveTanks, [
        DiveTanksCompanion.insert(
          id: 'chunk-tank-first',
          diveId: diveIds.first,
        ),
        DiveTanksCompanion.insert(id: 'chunk-tank-last', diveId: diveIds.last),
      ]),
    );
    final first = await repo.insertSeries(
      diveId: diveIds.first,
      tankId: 'chunk-tank-first',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final last = await repo.insertSeries(
      diveId: diveIds.last,
      tankId: 'chunk-tank-last',
      samples: const [TankPressureSample(timestamp: 0, pressure: 190.0)],
      now: 1000,
    );

    final rows = await repo.getRowsForDives(diveIds);
    expect(rows.map((r) => r.id), [first, last]);
  });

  test('deleteByIds and getRowsForDives', () async {
    final a = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final b = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
      now: 1000,
    );
    expect((await repo.getRowsForDives(['dive-1'])).map((r) => r.id), [a, b]);
    expect(await repo.getRowsForDives(const []), isEmpty);
    expect(await repo.deleteByIds(const []), isEmpty);
    expect(await repo.deleteByIds([a]), [a]);
    expect((await repo.getRowsForDives(['dive-1'])).map((r) => r.id), [b]);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.single.entityType, 'tankPressureSeries');
    expect(tombstones.single.recordId, a);
  });
}
