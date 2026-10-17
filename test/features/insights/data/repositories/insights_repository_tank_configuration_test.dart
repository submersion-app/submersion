import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3421: the Gas page's tank configuration card counts each dive in
/// scope once by base configuration and under each extra.
void main() {
  late InsightsRepository repository;
  late AppDatabase db;
  const now = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDive(
    String id, {
    String? diverId,
    bool excludedFromStats = false,
    bool excludedFromGasStats = false,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: const Value(now),
            runtime: const Value(42 * 60),
            maxDepth: const Value(25.0),
            excludedFromStats: Value(excludedFromStats),
            excludedFromGasStats: Value(excludedFromGasStats),
            createdAt: const Value(now),
            updatedAt: const Value(now),
          ),
        );
  }

  Future<void> insertTank(
    String diveId,
    int order,
    String role, {
    double o2 = 21.0,
    String? computerId,
    String? sourceId,
    String? sharedComputerIds,
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('$diveId-$order'),
            diveId: Value(diveId),
            tankRole: Value(role),
            o2Percent: Value(o2),
            tankOrder: Value(order),
            computerId: Value(computerId),
            sourceId: Value(sourceId),
            sharedComputerIds: Value(sharedComputerIds),
          ),
        );
  }

  Future<void> insertComputer(String id) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: const Value(now),
            updatedAt: const Value(now),
          ),
        );
  }

  Future<void> insertSource(
    String diveId,
    String? computerId, {
    required bool primary,
    String? id,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id ?? '$diveId-$computerId'),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(primary),
            importedAt: Value(DateTime.utc(2024)),
            createdAt: Value(DateTime.utc(2024)),
          ),
        );
  }

  Future<void> insertProfile(String diveId) async {
    await ProfileSeriesRepository().insertSeries(
      diveId: diveId,
      samples: [
        const ProfileSample(timestamp: 0, depth: 0),
        const ProfileSample(timestamp: 2400, depth: 20),
      ],
      now: 0,
    );
  }

  Future<void> insertSwitch(String diveId, String tankId, int at) async {
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: Value('$diveId-sw-$at'),
            diveId: Value(diveId),
            tankId: Value(tankId),
            timestamp: Value(at),
            createdAt: const Value(now),
          ),
        );
  }

  test('sorts dives into base configurations', () async {
    await insertDive('sm');
    await insertTank('sm', 0, 'sidemountLeft');
    await insertTank('sm', 1, 'sidemountRight');
    await insertDive('single');
    await insertTank('single', 0, 'backGas');
    await insertDive('bare');

    final stats = await repository.getTankConfigurationStats();

    expect(stats.totalDives, 3);
    expect(stats.baseCounts, {
      TankBaseConfiguration.sidemount: 1,
      TankBaseConfiguration.singleBackmount: 1,
      TankBaseConfiguration.noTanks: 1,
    });
  });

  test(
    'leaves out excluded_from_stats but keeps excluded_from_gas_stats dives',
    () async {
      await insertDive('out', excludedFromStats: true);
      await insertTank('out', 0, 'backGas');
      await insertDive('gasOut', excludedFromGasStats: true);
      await insertTank('gasOut', 0, 'sidemountLeft');

      final stats = await repository.getTankConfigurationStats();

      expect(stats.totalDives, 1);
      expect(stats.baseCounts, {TankBaseConfiguration.sidemount: 1});
    },
  );

  test('respects the insights filter', () async {
    await insertDive('tagged');
    await insertTank('tagged', 0, 'sidemountLeft');
    await insertDive('untagged');
    await insertTank('untagged', 0, 'backGas');
    await db
        .into(db.tags)
        .insert(
          const TagsCompanion(
            id: Value('cave'),
            name: Value('cave'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveTags)
        .insert(
          const DiveTagsCompanion(
            id: Value('tagged-cave'),
            diveId: Value('tagged'),
            tagId: Value('cave'),
            createdAt: Value(now),
          ),
        );

    final stats = await repository.getTankConfigurationStats(
      filter: const DiveFilterState(tagIds: ['cave']),
    );

    expect(stats.totalDives, 1);
    expect(stats.baseCounts, {TankBaseConfiguration.sidemount: 1});
  });

  test(
    "counts only the primary computer's cylinders plus hand-added ones",
    () async {
      await insertComputer('c1');
      await insertComputer('c2');
      await insertDive('merged');
      await insertSource('merged', 'c1', primary: true);
      await insertSource('merged', 'c2', primary: false);
      await insertTank('merged', 0, 'backGas', computerId: 'c1');
      // The second computer's copy of the same cylinder, left unmatched.
      await insertTank('merged', 1, 'backGas', computerId: 'c2');
      await insertTank('merged', 2, 'stage', o2: 50);

      final stats = await repository.getTankConfigurationStats();

      expect(stats.baseCounts, {TankBaseConfiguration.singleBackmount: 1});
      expect(stats.extraCounts[TankConfigurationExtra.stages], 1);
    },
  );

  test(
    'keeps a cylinder shared with the primary after the primary changes',
    () async {
      await insertComputer('c1');
      await insertComputer('c2');
      await insertDive('promoted');
      // Merged into c1's row, shared with c2, then c2 made primary.
      await insertSource('promoted', 'c1', primary: false);
      await insertSource('promoted', 'c2', primary: true);
      await insertTank(
        'promoted',
        0,
        'backGas',
        computerId: 'c1',
        sharedComputerIds: '["c2"]',
      );

      final stats = await repository.getTankConfigurationStats();

      expect(stats.baseCounts, {TankBaseConfiguration.singleBackmount: 1});
    },
  );

  test(
    "with sources that name no computer, counts the primary source's copy",
    () async {
      await insertDive('files');
      await insertSource('files', null, primary: true, id: 's1');
      await insertSource('files', null, primary: false, id: 's2');
      await insertTank('files', 0, 'backGas', sourceId: 's1');
      // The second file's copy of the same cylinder, left unmatched.
      await insertTank('files', 1, 'backGas', sourceId: 's2');
      await insertTank('files', 2, 'stage', o2: 50);

      final stats = await repository.getTankConfigurationStats();

      expect(stats.baseCounts, {TankBaseConfiguration.singleBackmount: 1});
      expect(stats.extraCounts[TankConfigurationExtra.stages], 1);
    },
  );

  test("counts every cylinder when the primary recording owns none", () async {
    await insertComputer('timer');
    await insertComputer('c2');
    await insertDive('timed');
    // A bottom timer as primary logs no cylinders of its own.
    await insertSource('timed', 'timer', primary: true);
    await insertSource('timed', 'c2', primary: false);
    await insertTank('timed', 0, 'sidemountLeft', computerId: 'c2');
    await insertTank('timed', 1, 'sidemountRight', computerId: 'c2');

    final stats = await repository.getTankConfigurationStats();

    expect(stats.baseCounts, {TankBaseConfiguration.sidemount: 1});
  });

  test(
    "leaves out a computerless secondary source's copy under a primary computer",
    () async {
      await insertComputer('c1');
      await insertDive('mixed');
      await insertSource('mixed', 'c1', primary: true);
      // A consolidated file import that names no computer.
      await insertSource('mixed', null, primary: false, id: 'file');
      await insertTank('mixed', 0, 'backGas', computerId: 'c1');
      await insertTank('mixed', 1, 'backGas', sourceId: 'file');

      final stats = await repository.getTankConfigurationStats();

      expect(stats.baseCounts, {TankBaseConfiguration.singleBackmount: 1});
    },
  );

  test('a gas switch row marks a deco tank breathed', () async {
    await insertDive('switched');
    await insertProfile('switched');
    await insertTank('switched', 0, 'backGas');
    await insertTank('switched', 1, 'deco', o2: 50);
    await insertSwitch('switched', 'switched-1', 1500);
    await insertDive('unswitched');
    await insertProfile('unswitched');
    await insertTank('unswitched', 0, 'backGas');
    await insertTank('unswitched', 1, 'deco', o2: 50);

    final stats = await repository.getTankConfigurationStats();

    expect(stats.extraCounts[TankConfigurationExtra.decoGas], 2);
    expect(stats.extraCounts[TankConfigurationExtra.multiGas], 1);
  });

  // The card reads gas switches and data sources, so a write to only those
  // (a sync pull, or setting the primary source) must refresh Insights.
  Future<bool> fires(Future<void> Function() write) async {
    var fired = false;
    final sub = repository.watchInsightsChanges().listen((_) => fired = true);
    addTearDown(sub.cancel);
    await write();
    for (var i = 0; i < 150 && !fired; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return fired;
  }

  test('insights refresh on a gas switch write', () async {
    await insertDive('w');
    await insertTank('w', 0, 'backGas');
    expect(await fires(() => insertSwitch('w', 'w-0', 600)), isTrue);
  });

  test('insights refresh on a data source write', () async {
    await insertComputer('c1');
    await insertDive('w');
    expect(await fires(() => insertSource('w', 'c1', primary: true)), isTrue);
  });

  test('scopes to the diver', () async {
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('a'),
            name: Value('A'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await insertDive('mine', diverId: 'a');
    await insertTank('mine', 0, 'sidemountLeft');
    await insertDive('theirs');
    await insertTank('theirs', 0, 'backGas');

    final stats = await repository.getTankConfigurationStats(diverId: 'a');

    expect(stats.totalDives, 1);
    expect(stats.baseCounts, {TankBaseConfiguration.sidemount: 1});
  });
}
