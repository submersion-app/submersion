import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late StatisticsRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = StatisticsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> insertSite({String? id, String? name}) async {
    final siteId = id ?? 'site-${DateTime.now().microsecondsSinceEpoch}';
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: siteId,
            name: name ?? 'Test Site',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    return siteId;
  }

  Future<String> insertDiver({String? id, String name = 'Test Diver'}) async {
    final diverId = id ?? 'diver-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(diverId),
            name: Value(name),
            medicalNotes: const Value(''),
            notes: const Value(''),
            isDefault: const Value(false),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diverId;
  }

  Future<String> insertDive({
    String? id,
    required String siteId,
    String? diverId,
    required DateTime diveDateTime,
    double? maxDepth,
    int? runtime,
    int? bottomTime,
    bool excludedFromStats = false,
    bool isPlanned = false,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diverId: Value(diverId),
            siteId: Value(siteId),
            diveDateTime: Value(diveDateTime.millisecondsSinceEpoch),
            maxDepth: Value(maxDepth),
            runtime: Value(runtime),
            bottomTime: Value(bottomTime),
            excludedFromStats: Value(excludedFromStats),
            isPlanned: Value(isPlanned),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  group('getSiteDiveStatistics', () {
    test(
      'returns diveCount 0 and null fields when site has no dives',
      () async {
        final siteId = await insertSite();

        final stats = await repository.getSiteDiveStatistics(siteId: siteId);

        expect(stats.diveCount, equals(0));
        expect(stats.hasData, isFalse);
        expect(stats.maxDepthReached, isNull);
        expect(stats.minDepthReached, isNull);
        expect(stats.longestDiveSeconds, isNull);
        expect(stats.averageDurationSeconds, isNull);
        expect(stats.firstDiveAt, isNull);
        expect(stats.lastDiveAt, isNull);
      },
    );

    test('aggregates a single dive', () async {
      final siteId = await insertSite();
      final diveDate = DateTime.utc(2026, 3, 10);
      await insertDive(
        siteId: siteId,
        diveDateTime: diveDate,
        maxDepth: 18.5,
        runtime: 2400,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.diveCount, equals(1));
      expect(stats.hasData, isTrue);
      expect(stats.maxDepthReached, equals(18.5));
      expect(stats.minDepthReached, equals(18.5));
      expect(stats.longestDiveSeconds, equals(2400));
      expect(stats.averageDurationSeconds, equals(2400.0));
      expect(stats.firstDiveAt, equals(diveDate));
      expect(stats.lastDiveAt, equals(diveDate));
    });

    test(
      'aggregates depth range, duration, and date range across multiple dives',
      () async {
        final siteId = await insertSite();
        final earliest = DateTime.utc(2025, 1, 5);
        final middle = DateTime.utc(2025, 6, 15);
        final latest = DateTime.utc(2026, 2, 20);

        await insertDive(
          id: 'dive-1',
          siteId: siteId,
          diveDateTime: middle,
          maxDepth: 20,
          runtime: 3000,
        );
        await insertDive(
          id: 'dive-2',
          siteId: siteId,
          diveDateTime: earliest,
          maxDepth: 12,
          runtime: 1800,
        );
        await insertDive(
          id: 'dive-3',
          siteId: siteId,
          diveDateTime: latest,
          maxDepth: 30,
          runtime: 2400,
        );

        final stats = await repository.getSiteDiveStatistics(siteId: siteId);

        expect(stats.diveCount, equals(3));
        expect(stats.maxDepthReached, equals(30));
        expect(stats.minDepthReached, equals(12));
        expect(stats.longestDiveSeconds, equals(3000));
        expect(stats.averageDurationSeconds, equals((3000 + 1800 + 2400) / 3));
        expect(stats.firstDiveAt, equals(earliest));
        expect(stats.lastDiveAt, equals(latest));
      },
    );

    test(
      'excludes dives without a depth from the depth range but still counts them',
      () async {
        final siteId = await insertSite();
        await insertDive(
          id: 'dive-with-depth',
          siteId: siteId,
          diveDateTime: DateTime.utc(2026, 1, 1),
          maxDepth: 15,
          runtime: 1800,
        );
        await insertDive(
          id: 'dive-no-depth',
          siteId: siteId,
          diveDateTime: DateTime.utc(2026, 1, 2),
          runtime: 1800,
        );

        final stats = await repository.getSiteDiveStatistics(siteId: siteId);

        expect(stats.diveCount, equals(2));
        expect(stats.maxDepthReached, equals(15));
        expect(stats.minDepthReached, equals(15));
      },
    );

    test(
      'excludes dives with neither runtime nor bottom time from the duration '
      'stats but still counts them',
      () async {
        final siteId = await insertSite();
        await insertDive(
          id: 'dive-with-duration',
          siteId: siteId,
          diveDateTime: DateTime.utc(2026, 1, 1),
          maxDepth: 15,
          runtime: 1800,
        );
        await insertDive(
          id: 'dive-no-duration',
          siteId: siteId,
          diveDateTime: DateTime.utc(2026, 1, 2),
          maxDepth: 16,
        );

        final stats = await repository.getSiteDiveStatistics(siteId: siteId);

        expect(stats.diveCount, equals(2));
        expect(stats.longestDiveSeconds, equals(1800));
        expect(stats.averageDurationSeconds, equals(1800.0));
      },
    );

    test('falls back to bottom time when runtime is null', () async {
      final siteId = await insertSite();
      await insertDive(
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        bottomTime: 2100,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.longestDiveSeconds, equals(2100));
      expect(stats.averageDurationSeconds, equals(2100.0));
    });

    test(
      'filters dives by diverId, excluding another diver\'s dives',
      () async {
        final siteId = await insertSite();
        final diverA = await insertDiver(id: 'diver-a');
        final diverB = await insertDiver(id: 'diver-b');
        await insertDive(
          id: 'dive-diver-a',
          siteId: siteId,
          diverId: diverA,
          diveDateTime: DateTime.utc(2026, 1, 1),
          maxDepth: 10,
          runtime: 1200,
        );
        await insertDive(
          id: 'dive-diver-b',
          siteId: siteId,
          diverId: diverB,
          diveDateTime: DateTime.utc(2026, 1, 2),
          maxDepth: 40,
          runtime: 3600,
        );

        final stats = await repository.getSiteDiveStatistics(
          siteId: siteId,
          diverId: diverA,
        );

        expect(stats.diveCount, equals(1));
        expect(stats.maxDepthReached, equals(10));
        expect(stats.longestDiveSeconds, equals(1200));
      },
    );

    // The card is descriptive: the numbers a diver reads as "what this site is
    // like". DiveStatsScope is what keeps a dive they ticked "exclude from
    // statistics" (issue #526) and a planner entry for a dive never made out of
    // every one of them, the count included.
    test('omits a dive excluded from statistics, the count included', () async {
      final siteId = await insertSite();
      await insertDive(
        id: 'dive-counted',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        maxDepth: 18,
        runtime: 2400,
      );
      await insertDive(
        id: 'dive-excluded',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 2),
        maxDepth: 40,
        runtime: 3600,
        excludedFromStats: true,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.diveCount, equals(1));
      expect(stats.maxDepthReached, equals(18));
      expect(stats.minDepthReached, equals(18));
      expect(stats.longestDiveSeconds, equals(2400));
      expect(stats.averageDurationSeconds, equals(2400.0));
      expect(stats.lastDiveAt, equals(DateTime.utc(2026, 1, 1)));
    });

    test('omits a planned dive that was never made', () async {
      final siteId = await insertSite();
      await insertDive(
        id: 'dive-logged',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        maxDepth: 18,
        runtime: 2400,
      );
      await insertDive(
        id: 'dive-planned',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 5, 1),
        maxDepth: 60,
        runtime: 4800,
        isPlanned: true,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.diveCount, equals(1));
      expect(stats.maxDepthReached, equals(18));
      expect(stats.longestDiveSeconds, equals(2400));
      expect(stats.lastDiveAt, equals(DateTime.utc(2026, 1, 1)));
    });

    test(
      'reports no data when every dive at the site is out of scope',
      () async {
        final siteId = await insertSite();
        await insertDive(
          id: 'dive-excluded-only',
          siteId: siteId,
          diveDateTime: DateTime.utc(2026, 1, 1),
          maxDepth: 18,
          runtime: 2400,
          excludedFromStats: true,
        );

        final stats = await repository.getSiteDiveStatistics(siteId: siteId);

        expect(stats.diveCount, equals(0));
        expect(stats.hasData, isFalse);
        expect(stats.maxDepthReached, isNull);
        expect(stats.firstDiveAt, isNull);
      },
    );

    test('does not include dives logged at a different site', () async {
      final siteId = await insertSite(id: 'site-a');
      final otherSiteId = await insertSite(id: 'site-b');
      await insertDive(
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        maxDepth: 10,
        runtime: 1200,
      );
      await insertDive(
        siteId: otherSiteId,
        diveDateTime: DateTime.utc(2026, 1, 2),
        maxDepth: 40,
        runtime: 3600,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.diveCount, equals(1));
      expect(stats.maxDepthReached, equals(10));
    });
  });

  group('getSiteDiveStatistics anchor dive ids', () {
    test('leaves every anchor id null when the site has no dives', () async {
      final siteId = await insertSite();

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.deepestDiveId, isNull);
      expect(stats.shallowestDiveId, isNull);
      expect(stats.longestDiveId, isNull);
      expect(stats.firstDiveId, isNull);
      expect(stats.lastDiveId, isNull);
    });

    test('points each statistic at the dive it was taken from', () async {
      final siteId = await insertSite();
      // Deliberately distinct dives so a query that anchored every statistic
      // to the same row would fail rather than coincidentally pass.
      await insertDive(
        id: 'dive-first-and-shallowest',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        maxDepth: 8,
        runtime: 1200,
      );
      await insertDive(
        id: 'dive-deepest',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 2, 1),
        maxDepth: 42,
        runtime: 1800,
      );
      await insertDive(
        id: 'dive-longest',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 3, 1),
        maxDepth: 20,
        runtime: 4500,
      );
      await insertDive(
        id: 'dive-last',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 4, 1),
        maxDepth: 15,
        runtime: 1500,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.deepestDiveId, equals('dive-deepest'));
      expect(stats.shallowestDiveId, equals('dive-first-and-shallowest'));
      expect(stats.longestDiveId, equals('dive-longest'));
      expect(stats.firstDiveId, equals('dive-first-and-shallowest'));
      expect(stats.lastDiveId, equals('dive-last'));
    });

    test('never anchors a depth statistic to a dive with no depth', () async {
      final siteId = await insertSite();
      // MAX/MIN(max_depth) skip NULLs, so a depthless dive contributes nothing
      // to either depth number and must not be what the row links to.
      await insertDive(
        id: 'dive-no-depth',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        runtime: 1200,
      );
      await insertDive(
        id: 'dive-with-depth',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 2, 1),
        maxDepth: 25,
        runtime: 1800,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.deepestDiveId, equals('dive-with-depth'));
      expect(stats.shallowestDiveId, equals('dive-with-depth'));
    });

    test(
      'never anchors a duration statistic to a dive with no duration',
      () async {
        final siteId = await insertSite();
        await insertDive(
          id: 'dive-no-duration',
          siteId: siteId,
          diveDateTime: DateTime.utc(2026, 1, 1),
          maxDepth: 30,
        );
        await insertDive(
          id: 'dive-with-duration',
          siteId: siteId,
          diveDateTime: DateTime.utc(2026, 2, 1),
          maxDepth: 12,
          runtime: 900,
        );

        final stats = await repository.getSiteDiveStatistics(siteId: siteId);

        expect(stats.longestDiveId, equals('dive-with-duration'));
      },
    );

    test('never anchors to a dive excluded from statistics', () async {
      final siteId = await insertSite();
      // The excluded dive is the deepest, longest and most recent, so an
      // anchor query missing the scope filter would name it for all three.
      await insertDive(
        id: 'dive-excluded',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 6, 1),
        maxDepth: 60,
        runtime: 5400,
        excludedFromStats: true,
      );
      await insertDive(
        id: 'dive-counted',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        maxDepth: 18,
        runtime: 1800,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.deepestDiveId, equals('dive-counted'));
      expect(stats.shallowestDiveId, equals('dive-counted'));
      expect(stats.longestDiveId, equals('dive-counted'));
      expect(stats.firstDiveId, equals('dive-counted'));
      expect(stats.lastDiveId, equals('dive-counted'));
    });

    test('never anchors to a planned dive that was never made', () async {
      final siteId = await insertSite();
      await insertDive(
        id: 'dive-planned',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 9, 1),
        maxDepth: 55,
        runtime: 4800,
        isPlanned: true,
      );
      await insertDive(
        id: 'dive-logged',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        maxDepth: 22,
        runtime: 2100,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.deepestDiveId, equals('dive-logged'));
      expect(stats.longestDiveId, equals('dive-logged'));
      expect(stats.lastDiveId, equals('dive-logged'));
    });

    test('never anchors to a dive logged at a different site', () async {
      final siteId = await insertSite(id: 'site-a');
      final otherSiteId = await insertSite(id: 'site-b');
      await insertDive(
        id: 'dive-here',
        siteId: siteId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        maxDepth: 10,
        runtime: 1200,
      );
      await insertDive(
        id: 'dive-elsewhere',
        siteId: otherSiteId,
        diveDateTime: DateTime.utc(2026, 2, 1),
        maxDepth: 40,
        runtime: 3600,
      );

      final stats = await repository.getSiteDiveStatistics(siteId: siteId);

      expect(stats.deepestDiveId, equals('dive-here'));
      expect(stats.lastDiveId, equals('dive-here'));
    });

    test('never anchors to another diver\'s dive at the same site', () async {
      final siteId = await insertSite();
      final diverId = await insertDiver(id: 'diver-mine');
      final otherDiverId = await insertDiver(id: 'diver-theirs');
      await insertDive(
        id: 'dive-mine',
        siteId: siteId,
        diverId: diverId,
        diveDateTime: DateTime.utc(2026, 1, 1),
        maxDepth: 14,
        runtime: 1500,
      );
      await insertDive(
        id: 'dive-theirs',
        siteId: siteId,
        diverId: otherDiverId,
        diveDateTime: DateTime.utc(2026, 2, 1),
        maxDepth: 44,
        runtime: 3900,
      );

      final stats = await repository.getSiteDiveStatistics(
        siteId: siteId,
        diverId: diverId,
      );

      expect(stats.deepestDiveId, equals('dive-mine'));
      expect(stats.longestDiveId, equals('dive-mine'));
      expect(stats.lastDiveId, equals('dive-mine'));
    });
  });
}
