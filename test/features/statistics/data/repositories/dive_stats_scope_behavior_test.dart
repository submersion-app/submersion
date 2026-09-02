import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

/// Behavioral guard for [DiveStatsScope]: proves every descriptive aggregate
/// actually drops the dives it is supposed to, rather than merely that the
/// predicate string is well formed.
///
/// The fixture seeds five dives, all identical apart from the flag under test,
/// so a leak shows up as an inflated count rather than a subtle shift:
///
/// | id           | counted by non-gas aggregates | counted by gas aggregates |
/// |--------------|-------------------------------|---------------------------|
/// | included     | yes                           | yes                       |
/// | excluded     | no (master flag)              | no                        |
/// | gas-excluded | yes                           | no                        |
/// | planned      | no                            | no                        |
/// | gauge        | yes                           | no (gauge has no gas data)|
///
/// So a non-gas aggregate sees 3 dives and a gas aggregate sees 1.
void main() {
  late StatisticsRepository repository;
  late AppDatabase db;

  /// Dives in scope for a descriptive, non-gas aggregate.
  const nonGasInScope = 3;

  /// Dives in scope for a SAC/RMV or gas-mix aggregate.
  const gasInScope = 1;

  Future<void> insertDive(
    String id, {
    bool excludedFromStats = false,
    bool excludedFromGasStats = false,
    bool isPlanned = false,
    String diveMode = 'oc',
  }) async {
    final at = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(at),
            diveMode: Value(diveMode),
            avgDepth: const Value(15.0),
            maxDepth: const Value(30.0),
            bottomTime: const Value(1800),
            isPlanned: Value(isPlanned),
            excludedFromStats: Value(excludedFromStats),
            excludedFromGasStats: Value(excludedFromGasStats),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('tank-$id'),
            diveId: Value(id),
            startPressure: const Value(200.0),
            endPressure: const Value(50.0),
            volume: const Value(11.1),
            o2Percent: const Value(21.0),
            hePercent: const Value(0.0),
            tankOrder: const Value(0),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = StatisticsRepository();

    await insertDive('included');
    await insertDive('excluded', excludedFromStats: true);
    await insertDive('gas-excluded', excludedFromGasStats: true);
    await insertDive('planned', isPlanned: true);
    await insertDive('gauge', diveMode: 'gauge');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('non-gas aggregates drop excluded and planned dives', () {
    test('getDivesPerYear', () async {
      final rows = await repository.getDivesPerYear();
      final total = rows.fold<int>(0, (sum, r) => sum + r.count);
      expect(total, nonGasInScope);
    });

    test('getCumulativeDiveCount', () async {
      final rows = await repository.getCumulativeDiveCount();
      expect(rows.last.value, nonGasInScope.toDouble());
    });

    test('getDepthPerDive', () async {
      final rows = await repository.getDepthPerDive();
      expect(rows, isNotEmpty);
      // One monthly bucket; every seeded dive has the same max depth, so the
      // assertion that bites is the count behind the average, checked above.
      expect(rows.first.value, 30.0);
    });

    test('getDivesByDayOfWeek', () async {
      final rows = await repository.getDivesByDayOfWeek();
      final total = rows.fold<int>(0, (sum, r) => sum + r.count);
      expect(total, nonGasInScope);
    });

    test('getDivesBySeason', () async {
      final rows = await repository.getDivesBySeason();
      final total = rows.fold<int>(0, (sum, r) => sum + r.count);
      expect(total, nonGasInScope);
    });
  });

  group('gas aggregates additionally drop gas-excluded and gauge dives', () {
    test('getGasMixDistribution', () async {
      final dist = await repository.getGasMixDistribution();
      final total = dist.fold<int>(0, (sum, s) => sum + s.count);
      expect(
        total,
        gasInScope,
        reason:
            'the gauge dive and the gas-excluded dive both drop out, on '
            'top of the master-excluded and planned dives',
      );
    });

    test('getSacVolumePerDive', () async {
      final rows = await repository.getSacVolumePerDive();
      expect(rows, isNotEmpty, reason: 'the included dive has tank volume');
      // One month bucket holding exactly the in-scope dives.
      expect(rows.length, 1);
    });

    test('getSacVolumeRecords', () async {
      final records = await repository.getSacVolumeRecords();
      expect(records.best, isNotNull);
      expect(
        records.best!.id,
        'included',
        reason: 'the only dive in scope for a gas aggregate',
      );
      expect(
        records.worst?.id,
        anyOf(isNull, 'included'),
        reason:
            'with a single dive in scope, best and worst are the same '
            'dive or worst is unset; either way no excluded dive appears',
      );
    });
  });

  group('the master flag implies the gas flag', () {
    test('a master-excluded dive is absent from gas aggregates too', () async {
      final records = await repository.getSacVolumeRecords();
      expect(records.best?.id, isNot('excluded'));
      expect(records.worst?.id, isNot('excluded'));
    });
  });

  group('DiveRepository aggregates', () {
    late DiveRepository diveRepo;

    setUp(() {
      diveRepo = DiveRepository();
    });

    test('getStatistics counts only dives in scope', () async {
      final stats = await diveRepo.getStatistics();
      expect(stats.totalDives, nonGasInScope);
    });

    test('getRecords never surfaces an excluded dive', () async {
      // Make the excluded dive the deepest and the planned dive the longest,
      // so a leak is unmissable rather than a tie broken the lucky way.
      await db.customStatement(
        "UPDATE dives SET max_depth = 99.0 WHERE id = 'excluded'",
      );
      await db.customStatement(
        "UPDATE dives SET bottom_time = 99999 WHERE id = 'planned'",
      );

      final records = await diveRepo.getRecords();
      expect(records.deepestDive?.diveId, isNot('excluded'));
      expect(records.longestDive?.diveId, isNot('planned'));
      expect(records.deepestDive?.diveId, isNotNull);
    });

    test('getPersonalRecordIds never surfaces an excluded dive', () async {
      await db.customStatement(
        "UPDATE dives SET max_depth = 99.0 WHERE id = 'excluded'",
      );
      final ids = await diveRepo.getPersonalRecordIds();
      final winners = [
        ids.deepestId,
        ids.longestId,
        ids.coldestId,
        ids.warmestId,
      ];
      expect(winners, isNot(contains('excluded')));
      expect(winners, isNot(contains('planned')));
    });

    test('countDivesSince counts only dives in scope', () async {
      final count = await diveRepo.countDivesSince(DateTime.utc(2020));
      expect(count, nonGasInScope);
    });

    test('getOnThisDayDiveIds skips excluded dives', () async {
      final ids = await diveRepo.getOnThisDayDiveIds(
        month: 1,
        day: 1,
        excludeYear: 2030,
      );
      expect(ids, isNot(contains('excluded')));
      expect(ids, isNot(contains('planned')));
      expect(ids, contains('included'));
    });

    test('getDiveCount deliberately still counts excluded dives', () async {
      final count = await diveRepo.getDiveCount();
      expect(
        count,
        5,
        reason:
            'the logbook list header counts what is in the logbook, and '
            'an excluded dive is still in the logbook. If this ever starts '
            'returning 3, someone applied DiveStatsScope where the design '
            'deliberately does not.',
      );
    });
  });

  group('per-entity descriptive counts', () {
    setUp(() async {
      // Link the included dive AND the out-of-scope dives to the same buddy,
      // site and centre, so a leak shows up as 3 where 1 is correct.
      final at = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion(
              id: const Value('b1'),
              name: const Value('Test Buddy'),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion(
              id: const Value('s1'),
              name: const Value('Test Site'),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      for (final id in ['included', 'excluded', 'planned']) {
        await db
            .into(db.diveBuddies)
            .insert(
              DiveBuddiesCompanion(
                id: Value('db-$id'),
                diveId: Value(id),
                buddyId: const Value('b1'),
                createdAt: Value(at),
              ),
            );
        await db.customStatement(
          "UPDATE dives SET site_id = 's1' WHERE id = '$id'",
        );
      }
    });

    test('getDiveCountForBuddy ignores excluded and planned dives', () async {
      expect(await BuddyRepository().getDiveCountForBuddy('b1'), 1);
    });

    test(
      'getDiveAggregatesBySite ignores excluded and planned dives',
      () async {
        final agg = await SiteRepository().getDiveAggregatesBySite();
        expect(agg['s1']?.diveCount, 1);
      },
    );

    test('getDiveCountForDiver ignores excluded and planned dives', () async {
      final at = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: const Value('diver-1'),
              name: const Value('Test Diver'),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      await db.customStatement("UPDATE dives SET diver_id = 'diver-1'");
      expect(
        await DiverRepository().getDiveCountForDiver('diver-1'),
        nonGasInScope,
      );
    });

    test('getDiveCountForCenter ignores excluded and planned dives', () async {
      final at = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
      await db
          .into(db.diveCenters)
          .insert(
            DiveCentersCompanion(
              id: const Value('c1'),
              name: const Value('Test Centre'),
              createdAt: Value(at),
              updatedAt: Value(at),
            ),
          );
      await db.customStatement(
        "UPDATE dives SET dive_center_id = 'c1' "
        "WHERE id IN ('included', 'excluded')",
      );
      expect(await DiveCenterRepository().getDiveCountForCenter('c1'), 1);
    });
  });
}
