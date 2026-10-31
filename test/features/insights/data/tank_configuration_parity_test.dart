import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/presentation/insights_dive_filters.dart';

import '../../../helpers/test_database.dart';

/// Issue #3804: the reason the feature exists. A diver who distrusts a number
/// taps it, so the list a bar opens must hold exactly the dives it counted,
/// on every path that reads the filter.
void main() {
  late AppDatabase db;
  late InsightsRepository insights;
  late DiveRepository dives;
  const now = 1700000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    insights = InsightsRepository();
    dives = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertDive(
    String id, {
    String mode = 'oc',
    double depth = 30,
    bool planned = false,
    bool excluded = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveMode: Value(mode),
          maxDepth: Value(depth),
          isPlanned: Value(planned),
          excludedFromStats: Value(excluded),
          diveDateTime: const Value(now),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertTank(
    String diveId,
    int order,
    String role, {
    double o2 = 21,
    String? computerId,
  }) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion(
          id: Value('$diveId-$order'),
          diveId: Value(diveId),
          tankRole: Value(role),
          o2Percent: Value(o2),
          volume: const Value(12),
          tankOrder: Value(order),
          computerId: Value(computerId),
        ),
      );

  Future<void> insertComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(now),
          updatedAt: const Value(now),
        ),
      );

  Future<void> insertPrimarySource(String diveId, String computerId) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value('$diveId-source'),
          diveId: Value(diveId),
          computerId: Value(computerId),
          isPrimary: const Value(true),
          importedAt: Value(DateTime.utc(2024)),
          createdAt: Value(DateTime.utc(2024)),
        ),
      );

  /// One dive of every configuration and extra, half of them shallow so a
  /// scope has something to narrow.
  Future<void> seedLogbook() async {
    await insertComputer('primary');
    await insertComputer('other');

    await insertDive('single');
    await insertTank('single', 0, 'backGas');
    await insertDive('single-shallow', depth: 10);
    await insertTank('single-shallow', 0, 'backGas');

    await insertDive('twin');
    await insertTank('twin', 0, 'backGas');
    await insertTank('twin', 1, 'backGas');

    await insertDive('sidemount');
    await insertTank('sidemount', 0, 'sidemountLeft');
    await insertTank('sidemount', 1, 'stage');
    await insertDive('sidemount-shallow', depth: 10);
    await insertTank('sidemount-shallow', 0, 'sidemountRight');

    await insertDive('rebreather', mode: 'ccr');
    await insertDive('other');
    await insertTank('other', 0, 'stage');
    await insertDive('empty');

    await insertDive('deco');
    await insertTank('deco', 0, 'backGas');
    await insertTank('deco', 1, 'deco', o2: 50);

    // Consolidated: read alone the second recording's cylinders would make
    // this a twin set with a stage. Only the primary's count.
    await insertDive('consolidated');
    await insertPrimarySource('consolidated', 'primary');
    await insertTank('consolidated', 0, 'backGas', computerId: 'primary');
    await insertTank('consolidated', 1, 'backGas', computerId: 'other');
    await insertTank('consolidated', 2, 'stage', computerId: 'other');

    // A bottom timer as primary: it logs no cylinders, so every one stays.
    await insertDive('timer');
    await insertPrimarySource('timer', 'primary');
    await insertTank('timer', 0, 'sidemountLeft', computerId: 'other');

    // The chart leaves these out and the dive list does not.
    await insertDive('planned', planned: true);
    await insertTank('planned', 0, 'sidemountLeft');
    await insertDive('excluded', excluded: true);
    await insertTank('excluded', 0, 'sidemountLeft');
    await insertTank('excluded', 1, 'stage');
  }

  Future<Set<String>> filteredIds(DiveFilterState filter) async {
    final f = buildFilteredDiveIdSubquery(filter);
    final rows = await db
        .customSelect(
          f.subquery,
          variables: [for (final p in f.params) Variable(p)],
        )
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  /// Every path that reads [filter] selects dives whose count is [count].
  Future<void> expectEveryPath(
    DiveFilterState filter,
    int count,
    String reason,
  ) async {
    final ids = await filteredIds(filter);
    expect(ids, hasLength(count), reason: '$reason: filtered ids');
    expect(
      await dives.getDiveCount(filter: filter),
      count,
      reason: '$reason: getDiveCount',
    );
    final summaries = await dives.getDiveSummaries(filter: filter, limit: 100);
    expect(
      {for (final s in summaries) s.id},
      ids,
      reason: '$reason: getDiveSummaries',
    );
  }

  Future<void> expectBarsMatchLists(DiveFilterState scope) async {
    final stats = await insights.getTankConfigurationStats(filter: scope);
    for (final c in TankBaseConfiguration.values) {
      await expectEveryPath(
        tankConfigDivesFilter(scope, c),
        stats.baseCounts[c] ?? 0,
        c.name,
      );
    }
    for (final e in TankConfigurationExtra.values) {
      await expectEveryPath(
        tankExtraDivesFilter(scope, e),
        stats.extraCounts[e] ?? 0,
        e.name,
      );
    }
  }

  test('the seeded logbook reaches every bar', () async {
    await seedLogbook();

    final stats = await insights.getTankConfigurationStats();
    expect(stats.totalDives, 11);
    expect(stats.baseCounts, {
      TankBaseConfiguration.singleBackmount: 4,
      TankBaseConfiguration.twinBackmount: 1,
      TankBaseConfiguration.sidemount: 3,
      TankBaseConfiguration.rebreather: 1,
      TankBaseConfiguration.other: 1,
      TankBaseConfiguration.noTanks: 1,
    });
    expect(stats.extraCounts, {
      TankConfigurationExtra.stages: 2,
      TankConfigurationExtra.decoGas: 1,
      TankConfigurationExtra.multiGas: 1,
    });
  });

  test('every bar opens exactly the dives it counted', () async {
    await seedLogbook();
    await expectBarsMatchLists(const DiveFilterState());
  });

  test('and under an Insights scope', () async {
    await seedLogbook();
    await expectBarsMatchLists(const DiveFilterState(minDepth: 20));
  });

  test('and under an extras scope, where a tap must narrow it', () async {
    await seedLogbook();
    await expectBarsMatchLists(
      const DiveFilterState(tankExtras: [TankConfigurationExtra.stages]),
    );
  });

  test('a scope that matches nothing leaves every bar at zero', () async {
    await seedLogbook();
    await expectBarsMatchLists(const DiveFilterState(minDepth: 500));
  });

  test('the Refine axis also finds planned and excluded dives', () async {
    await seedLogbook();

    final bar = await filteredIds(
      tankConfigDivesFilter(
        const DiveFilterState(),
        TankBaseConfiguration.sidemount,
      ),
    );
    final chip = await filteredIds(
      const DiveFilterState(
        tankConfigurations: [TankBaseConfiguration.sidemount],
      ),
    );

    expect(chip, {...bar, 'planned', 'excluded'});
  });

  test('a Refine extra also finds an excluded dive', () async {
    await seedLogbook();

    final bar = await filteredIds(
      tankExtraDivesFilter(
        const DiveFilterState(),
        TankConfigurationExtra.stages,
      ),
    );
    final chip = await filteredIds(
      const DiveFilterState(tankExtras: [TankConfigurationExtra.stages]),
    );

    expect(chip, {...bar, 'excluded'});
  });
}
