import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
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

  Future<void> insertDive({
    required String id,
    required DateTime at,
    double? maxDepth,
    int? bottomTimeSeconds,
    double? waterTemp,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(at.millisecondsSinceEpoch),
            maxDepth: Value(maxDepth),
            bottomTime: Value(bottomTimeSeconds),
            waterTemp: Value(waterTemp),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  group('getDepthPerDive', () {
    test('returns one point per dive, ordered by date', () async {
      await insertDive(id: 'b', at: DateTime.utc(2024, 5, 20), maxDepth: 30.0);
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10), maxDepth: 18.0);

      final points = await repository.getDepthPerDive();

      expect(points, hasLength(2));
      expect(points[0].value, 18.0);
      expect(points[1].value, 30.0);
      expect(points[0].date.isBefore(points[1].date), isTrue);
    });

    test('does not collapse two dives in the same month', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10), maxDepth: 18.0);
      await insertDive(id: 'b', at: DateTime.utc(2024, 5, 11), maxDepth: 30.0);

      expect(await repository.getDepthPerDive(), hasLength(2));
    });

    test('includes a dive far older than five years', () async {
      // The regression that matters: the old code hardcoded a five-year
      // cutoff, so "lifetime" was unreachable no matter what filter was set.
      final longAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 365 * 8),
      );
      await insertDive(id: 'ancient', at: longAgo, maxDepth: 12.0);

      final points = await repository.getDepthPerDive();

      expect(points, hasLength(1));
      expect(points.single.value, 12.0);
    });

    test('skips dives with no recorded max depth', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));

      expect(await repository.getDepthPerDive(), isEmpty);
    });

    test('honours a date filter', () async {
      await insertDive(id: 'a', at: DateTime.utc(2020, 5, 10), maxDepth: 18.0);
      await insertDive(id: 'b', at: DateTime.utc(2024, 5, 10), maxDepth: 30.0);

      final points = await repository.getDepthPerDive(
        filter: DiveFilterState(startDate: DateTime.utc(2023, 1, 1)),
      );

      expect(points, hasLength(1));
      expect(points.single.value, 30.0);
    });
  });

  group('getBottomTimePerDive', () {
    test('returns minutes, one point per dive', () async {
      await insertDive(
        id: 'a',
        at: DateTime.utc(2024, 5, 10),
        bottomTimeSeconds: 45 * 60,
      );
      await insertDive(
        id: 'b',
        at: DateTime.utc(2024, 5, 11),
        bottomTimeSeconds: 60 * 60,
      );

      final points = await repository.getBottomTimePerDive();

      expect(points, hasLength(2));
      expect(points[0].value, closeTo(45, 1e-9));
      expect(points[1].value, closeTo(60, 1e-9));
    });

    test('includes a dive far older than five years', () async {
      final longAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 365 * 8),
      );
      await insertDive(id: 'ancient', at: longAgo, bottomTimeSeconds: 30 * 60);

      expect(await repository.getBottomTimePerDive(), hasLength(1));
    });
  });

  Future<void> insertWeight({
    required String diveId,
    required String id,
    required double amountKg,
    String weightType = 'Belt',
  }) async {
    await db
        .into(db.diveWeights)
        .insert(
          DiveWeightsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            weightType: Value(weightType),
            amountKg: Value(amountKg),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  group('getWeightPerDive', () {
    test('sums every weight row on a dive into one point', () async {
      // The old monthly query averaged across weight ROWS, so a diver with a
      // 4 kg belt plus 2 kg of trim weights was recorded as 3 kg rather than
      // the 6 kg actually carried.
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));
      await insertWeight(diveId: 'a', id: 'w1', amountKg: 4.0);
      await insertWeight(
        diveId: 'a',
        id: 'w2',
        amountKg: 2.0,
        weightType: 'Trim',
      );

      final points = await repository.getWeightPerDive();

      expect(points, hasLength(1));
      expect(points.single.value, closeTo(6.0, 1e-9));
    });

    test('returns one point per dive, ordered by date', () async {
      await insertDive(id: 'b', at: DateTime.utc(2024, 5, 20));
      await insertWeight(diveId: 'b', id: 'w2', amountKg: 5.0);
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));
      await insertWeight(diveId: 'a', id: 'w1', amountKg: 7.0);

      final points = await repository.getWeightPerDive();

      expect(points.map((p) => p.value), [7.0, 5.0]);
    });

    test('skips dives with no weight rows', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));

      expect(await repository.getWeightPerDive(), isEmpty);
    });

    test('includes a dive far older than five years', () async {
      final longAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 365 * 8),
      );
      await insertDive(id: 'ancient', at: longAgo);
      await insertWeight(diveId: 'ancient', id: 'w1', amountKg: 6.0);

      expect(await repository.getWeightPerDive(), hasLength(1));
    });
  });

  group('getWaterTempPerDive', () {
    test('returns one point per dive with a recorded temperature', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10), waterTemp: 12.5);
      await insertDive(id: 'b', at: DateTime.utc(2024, 8, 10), waterTemp: 28.0);

      final points = await repository.getWaterTempPerDive();

      expect(points.map((p) => p.value), [12.5, 28.0]);
    });

    test('skips dives with no recorded temperature', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));

      expect(await repository.getWaterTempPerDive(), isEmpty);
    });

    test('does not collapse different years into one calendar month', () async {
      // The seasonal chart deliberately does collapse years; this one must not.
      await insertDive(id: 'a', at: DateTime.utc(2023, 7, 10), waterTemp: 10.0);
      await insertDive(id: 'b', at: DateTime.utc(2024, 7, 10), waterTemp: 29.0);

      final points = await repository.getWaterTempPerDive();

      expect(points, hasLength(2));
      expect(points.map((p) => p.value), [10.0, 29.0]);
    });
  });

  group('getCumulativeDiveCount', () {
    test('steps once per dive rather than once per month', () async {
      // Month bucketing collapsed a whole trip into a single step, so a
      // liveaboard week showed as one point.
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10), maxDepth: 18);
      await insertDive(id: 'b', at: DateTime.utc(2024, 5, 11), maxDepth: 20);
      await insertDive(id: 'c', at: DateTime.utc(2024, 5, 12), maxDepth: 22);

      final points = await repository.getCumulativeDiveCount();

      expect(points, hasLength(3));
      expect(points.map((p) => p.value), [1, 2, 3]);
    });

    test('keeps each dive on its own date', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));
      await insertDive(id: 'b', at: DateTime.utc(2024, 8, 2));

      final points = await repository.getCumulativeDiveCount();

      expect(points[0].date, DateTime.utc(2024, 5, 10));
      expect(points[1].date, DateTime.utc(2024, 8, 2));
    });

    test('counts dives with no recorded depth', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));

      expect(await repository.getCumulativeDiveCount(), hasLength(1));
    });

    test('honours a date filter', () async {
      await insertDive(id: 'a', at: DateTime.utc(2020, 5, 10));
      await insertDive(id: 'b', at: DateTime.utc(2024, 5, 10));

      final points = await repository.getCumulativeDiveCount(
        filter: DiveFilterState(startDate: DateTime.utc(2023, 1, 1)),
      );

      expect(points, hasLength(1));
      expect(points.single.value, 1);
    });
  });

  group('dive identity', () {
    test('a per-dive point carries the dive it came from', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10), maxDepth: 18.0);

      final points = await repository.getDepthPerDive();

      expect(points.single.diveId, 'a');
    });

    test('bottom time, temperature and weight carry it too', () async {
      await insertDive(
        id: 'a',
        at: DateTime.utc(2024, 5, 10),
        bottomTimeSeconds: 40 * 60,
        waterTemp: 21,
      );
      await insertWeight(diveId: 'a', id: 'w1', amountKg: 6);

      expect((await repository.getBottomTimePerDive()).single.diveId, 'a');
      expect((await repository.getWaterTempPerDive()).single.diveId, 'a');
      expect((await repository.getWeightPerDive()).single.diveId, 'a');
    });

    test('the cumulative count carries it', () async {
      await insertDive(id: 'a', at: DateTime.utc(2024, 5, 10));

      expect((await repository.getCumulativeDiveCount()).single.diveId, 'a');
    });
  });
}
