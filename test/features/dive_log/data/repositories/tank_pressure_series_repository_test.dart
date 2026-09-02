import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TankPressureSeriesRepository repo;
  const now = 1750000000000;

  const samples = [
    TankPressureSample(timestamp: 0, pressure: 200.0),
    TankPressureSample(timestamp: 60, pressure: 190.5),
    TankPressureSample(timestamp: 120, pressure: 181.0),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    repo = TankPressureSeriesRepository();
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
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Perdix',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final tank in ['tank-a', 'tank-b']) {
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: tank, diveId: 'dive-1'));
    }
  });

  tearDown(tearDownTestDatabase);

  test('insertSeries stores the encoded readings and summary', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      computerId: 'comp-1',
      samples: samples,
      now: now,
    );
    final row = await (db.select(
      db.tankPressureSeries,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.tankId, 'tank-a');
    expect(row.computerId, 'comp-1');
    expect(row.sampleCount, 3);
    expect(row.startTimestamp, 0);
    expect(row.endTimestamp, 120);
    expect(row.hlc, isNotNull);

    final read = await repo.getSeriesForTank('dive-1', 'tank-a');
    expect(read.single.samples, samples);
    expect(read.single.summary.sampleCount, 3);
  });

  test('exact duplicates are dropped and an empty list is refused', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: [samples[0], samples[0], samples[1]],
      now: now,
    );
    final read = await repo.getSeriesForTank('dive-1', 'tank-a');
    expect(read.single.id, id);
    expect(read.single.samples, [samples[0], samples[1]]);
    expect(
      () => repo.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        samples: const [],
      ),
      throwsArgumentError,
    );
  });

  test('getSeriesForDive orders by tank then start', () async {
    await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: samples,
      id: 'b',
      now: now,
    );
    // Two series on tank-a whose id order disagrees with their start order,
    // so the assertion below can only pass on the start key.
    await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 5, pressure: 150.0)],
      id: 'a',
      now: now,
    );
    await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      computerId: 'comp-1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      id: 'c',
      now: now,
    );
    final all = await repo.getSeriesForDive('dive-1');
    expect(all.map((s) => s.id), ['c', 'a', 'b']);
  });

  test(
    'deleteForTank and deleteOwnedByComputer tombstone what they remove',
    () async {
      final a = await repo.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        computerId: 'comp-1',
        samples: samples,
        now: now,
      );
      final b = await repo.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-b',
        samples: samples,
        now: now,
      );

      expect(await repo.deleteForTank('dive-1', 'tank-a'), [a]);
      expect((await repo.getSeriesForDive('dive-1')).map((s) => s.id), [b]);

      expect(await repo.deleteOwnedByComputer('dive-1', null), [b]);
      expect(await repo.getSeriesForDive('dive-1'), isEmpty);

      final tombstones =
          await (db.select(db.deletionLog)..where(
                (t) => t.entityType.equals(
                  TankPressureSeriesRepository.entityType,
                ),
              ))
              .get();
      expect(tombstones, hasLength(2));
      expect(tombstones.map((t) => t.recordId).toSet(), {a, b});
    },
  );

  test('deleteOwnedByComputer with a non-null computerId removes only that '
      "computer's series", () async {
    final owned = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      computerId: 'comp-1',
      samples: samples,
      now: now,
    );
    final manual = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: samples,
      now: now,
    );

    expect(await repo.deleteOwnedByComputer('dive-1', 'comp-1'), [owned]);
    final remaining = await repo.getSeriesForDive('dive-1');
    expect(remaining.map((s) => s.id), [manual]);
  });

  test('restoreSeriesRow puts the captured row back and queues it', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      computerId: 'comp-1',
      samples: samples,
      now: now,
    );
    final captured = await (db.select(
      db.tankPressureSeries,
    )..where((t) => t.id.equals(id))).getSingle();
    await repo.deleteForDive('dive-1');
    await (db.delete(db.syncRecords)..where((t) => t.recordId.equals(id))).go();

    await repo.restoreSeriesRow(captured, now: now + 5);

    final back = await (db.select(
      db.tankPressureSeries,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(back.createdAt, captured.createdAt);
    expect(back.samples, captured.samples);
    expect(back.hlc, isNotNull);
    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.recordId.equals(id))).getSingle();
    expect(pending.entityType, TankPressureSeriesRepository.entityType);

    await repo.deleteForDive('dive-1');
    await repo.restoreSeriesRow(captured, markPending: false);
    final verbatim = await (db.select(
      db.tankPressureSeries,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(verbatim.hlc, captured.hlc);
  });

  test('restoreSeriesRow without now stamps the pending record with '
      'wall-clock time', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: samples,
      now: now,
    );
    final captured = await (db.select(
      db.tankPressureSeries,
    )..where((t) => t.id.equals(id))).getSingle();
    await repo.deleteForDive('dive-1');
    await (db.delete(db.syncRecords)..where((t) => t.recordId.equals(id))).go();

    await repo.restoreSeriesRow(captured);

    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.recordId.equals(id))).getSingle();
    expect(pending.entityType, TankPressureSeriesRepository.entityType);
    expect(pending.localUpdatedAt, greaterThan(0));
  });

  test('restoreSeriesRow removes the tombstone the delete logged', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: samples,
      now: now,
    );
    final row = await (db.select(
      db.tankPressureSeries,
    )..where((t) => t.id.equals(id))).getSingle();
    await repo.deleteForDive('dive-1');
    var tombstones = await (db.select(
      db.deletionLog,
    )..where((t) => t.recordId.equals(id))).get();
    expect(tombstones, hasLength(1));

    await repo.restoreSeriesRow(row, now: now + 1);

    tombstones = await (db.select(
      db.deletionLog,
    )..where((t) => t.recordId.equals(id))).get();
    expect(tombstones, isEmpty);
    final read = await repo.getSeriesForTank('dive-1', 'tank-a');
    expect(read, isNotEmpty);
  });

  test('deleteForDive removes every series of the dive', () async {
    await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: samples,
    );
    await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: samples,
    );
    expect(await repo.deleteForDive('dive-1'), hasLength(2));
    expect(await repo.getSeriesForDive('dive-1'), isEmpty);
  });

  test('hasSeriesForDive answers without decoding', () async {
    expect(await repo.hasSeriesForDive('dive-1'), isFalse);
    await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: samples,
    );
    expect(await repo.hasSeriesForDive('dive-1'), isTrue);
  });

  group('an unreadable blob', () {
    test('getSeriesForDive skips it and keeps the rest', () async {
      final badId = await repo.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        samples: samples,
        now: now,
      );
      final goodId = await repo.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-b',
        samples: samples,
        now: now,
      );
      await (db.update(
        db.tankPressureSeries,
      )..where((t) => t.id.equals(badId))).write(
        TankPressureSeriesCompanion(
          samples: Value(Uint8List.fromList(const [1, 2, 3, 4])),
        ),
      );

      final read = await repo.getSeriesForDive('dive-1');
      expect(read.map((s) => s.id), [goodId]);
    });
  });
}
