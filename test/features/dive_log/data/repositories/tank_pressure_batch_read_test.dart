import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

/// The batched tank pressure read the dives-only UDDF export uses (issue
/// #1874): the same per-tank points as the single-dive read, for many dives.
void main() {
  late AppDatabase db;
  const now = 1750000000000;

  Future<void> diveWithTanks(String diveId, List<String> tankIds) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: const Value(now),
            createdAt: const Value(now),
            updatedAt: const Value(now),
          ),
        );
    for (final tank in tankIds) {
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: tank, diveId: diveId));
    }
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await diveWithTanks('dive-1', ['tank-a', 'tank-b']);
    await diveWithTanks('dive-2', ['tank-c']);
    await diveWithTanks('dive-3', ['tank-d']);
    final series = TankPressureSeriesRepository();
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
    await series.insertSeries(
      diveId: 'dive-2',
      tankId: 'tank-c',
      samples: const [TankPressureSample(timestamp: 30, pressure: 150.0)],
      now: now,
    );
  });

  tearDown(tearDownTestDatabase);

  test('reads each dive\'s pressures by tank, leaving out dives with '
      'none', () async {
    final byDive = await TankPressureRepository().getTankPressuresForDives([
      'dive-1',
      'dive-2',
      'dive-3',
    ]);

    expect(byDive.keys.toSet(), {'dive-1', 'dive-2'});
    expect(byDive['dive-1']!.keys.toSet(), {'tank-a', 'tank-b'});
    expect(byDive['dive-1']!['tank-a']!.map((p) => (p.timestamp, p.pressure)), [
      (0, 200.0),
      (60, 190.0),
    ]);
    expect(byDive['dive-1']!['tank-b']!.map((p) => (p.timestamp, p.pressure)), [
      (0, 210.0),
    ]);
    expect(byDive['dive-2']!['tank-c']!.map((p) => (p.timestamp, p.pressure)), [
      (30, 150.0),
    ]);
  });

  test('an empty id list reads nothing', () async {
    expect(await TankPressureRepository().getTankPressuresForDives([]), {});
  });
}
