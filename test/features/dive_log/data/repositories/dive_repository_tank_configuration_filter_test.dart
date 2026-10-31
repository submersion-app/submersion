import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3804: a dive's configuration is worked out from rows that can change
/// without the dive itself changing, so a filtered list must follow them.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  const now = 1700000000000;
  const singles = DiveFilterState(
    tankConfigurations: [TankBaseConfiguration.singleBackmount],
  );

  Future<void> insertTank(String id, int order, String role) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value(id),
          diveId: const Value('a'),
          tankRole: Value(role),
          volume: const Value(12),
          tankOrder: Value(order),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('a'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  /// [write], with the change tick a list filtered by [filter] would see.
  Future<List<void>> ticksDuring(
    DiveFilterState filter,
    Future<void> Function() write,
  ) async {
    final ticks = <void>[];
    final sub = repo
        .watchTables(diveFilterTablesTouched(filter))
        .listen(ticks.add);
    addTearDown(sub.cancel);
    await write();
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    return ticks;
  }

  test('a filtered list follows a tank added to a dive', () async {
    await insertTank('a-0', 0, 'backGas');
    expect(await repo.getDiveCount(filter: singles), 1);

    final ticks = await ticksDuring(
      singles,
      () => insertTank('a-1', 1, 'sidemountLeft'),
    );

    expect(ticks, isNotEmpty);
    expect(await repo.getDiveCount(filter: singles), 0);
  });

  test('a filtered list follows a tank\'s role changing', () async {
    await insertTank('a-0', 0, 'backGas');

    final ticks = await ticksDuring(
      singles,
      () => (db.update(db.diveTanks)..where((t) => t.id.equals('a-0'))).write(
        const DiveTanksCompanion(tankRole: Value('sidemountLeft')),
      ),
    );

    expect(ticks, isNotEmpty);
    expect(await repo.getDiveCount(filter: singles), 0);
  });

  test('an extra follows a gas switch, its only change', () async {
    const multiGas = DiveFilterState(
      tankExtras: [TankConfigurationExtra.multiGas],
    );
    await insertTank('a-0', 0, 'backGas');
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(
            id: Value('a-1'),
            diveId: Value('a'),
            tankRole: Value('backGas'),
            o2Percent: Value(32),
            volume: Value(12),
            tankOrder: Value(1),
          ),
        );
    // Recorded, so the second gas does not count until a switch names it.
    await ProfileSeriesRepository().insertSeries(
      diveId: 'a',
      samples: [
        const ProfileSample(timestamp: 0, depth: 0),
        const ProfileSample(timestamp: 2400, depth: 20),
      ],
      now: 0,
    );
    expect(await repo.getDiveCount(filter: multiGas), 0);

    final ticks = await ticksDuring(
      multiGas,
      () => db
          .into(db.gasSwitches)
          .insert(
            const GasSwitchesCompanion(
              id: Value('sw'),
              diveId: Value('a'),
              tankId: Value('a-1'),
              timestamp: Value(600),
              createdAt: Value(now),
            ),
          ),
    );

    expect(ticks, isNotEmpty);
    expect(await repo.getDiveCount(filter: multiGas), 1);
  });
}
