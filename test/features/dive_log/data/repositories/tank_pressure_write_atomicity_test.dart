import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';

import '../../../../helpers/test_database.dart';

/// A dive's pressure set is written one series per tank. Before series, all
/// of a dive's pressures were one batch, so a failure part way through wrote
/// nothing; now each insertSeries commits and marks itself pending on its
/// own. A multi-transmitter download whose second tank cannot be written
/// would leave the first committed and pending, and that half of the
/// pressure set then publishes to peers as if it were the whole.
void main() {
  late AppDatabase db;
  const now = 1750000000000;

  /// Refuses the series carrying [sampleCount] samples, standing in for
  /// anything that can fail the second write: an encode the codec refuses,
  /// a constraint, a disk error.
  void refuseSeriesOfSize(int sampleCount) {
    db.customStatement('''
      CREATE TRIGGER refuse_second_tank
      BEFORE INSERT ON tank_pressure_series
      WHEN NEW.sample_count = $sampleCount
      BEGIN SELECT RAISE(ABORT, 'no second tank'); END
    ''');
  }

  Future<int> seriesCount() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM tank_pressure_series')
        .getSingle();
    return row.read<int>('n');
  }

  setUp(() async {
    db = await setUpTestDatabase();
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
    await db
        .into(db.diveComputers)
        .insert(
          const DiveComputersCompanion(
            id: Value('comp-1'),
            name: Value('Perdix'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('insertTankPressures writes every tank or none', () async {
    refuseSeriesOfSize(1);

    await expectLater(
      TankPressureRepository().insertTankPressures('dive-1', {
        'tank-a': [
          (timestamp: 0, pressure: 200.0),
          (timestamp: 60, pressure: 190.0),
        ],
        'tank-b': [(timestamp: 0, pressure: 210.0)],
      }),
      throwsA(anything),
    );

    expect(
      await seriesCount(),
      0,
      reason: "tank-a's series must not survive tank-b failing",
    );
  });

  test(
    'a download whose second tank cannot be written writes neither',
    () async {
      refuseSeriesOfSize(1);

      await expectLater(
        DiveComputerRepository().importProfile(
          computerId: 'comp-1',
          profileStartTime: DateTime(2026, 1, 1, 10),
          points: const [
            // Tank 0 gets two readings, tank 1 exactly one, so the trigger
            // fires on the second series and not the first.
            ProfilePointData(
              timestamp: 0,
              depth: 0.0,
              pressure: 200.0,
              tankIndex: 0,
            ),
            ProfilePointData(
              timestamp: 30,
              depth: 10.0,
              pressure: 190.0,
              tankIndex: 0,
            ),
            ProfilePointData(
              timestamp: 60,
              depth: 12.0,
              pressure: 180.0,
              tankIndex: 1,
            ),
          ],
          durationSeconds: 90,
          maxDepth: 12.0,
          tanks: const [
            TankData(index: 0, o2Percent: 21.0),
            TankData(index: 1, o2Percent: 32.0),
          ],
        ),
        throwsA(anything),
      );

      expect(await seriesCount(), 0);
    },
  );

  test('a clean write still lands every tank', () async {
    await TankPressureRepository().insertTankPressures('dive-1', {
      'tank-a': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 60, pressure: 190.0),
      ],
      'tank-b': [(timestamp: 0, pressure: 210.0)],
    });

    expect(await seriesCount(), 2);
  });
}
