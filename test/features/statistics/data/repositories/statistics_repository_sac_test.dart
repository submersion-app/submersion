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

  Future<String> insertDiveWithTank({
    String? id,
    required int bottomTimeSeconds,
    int? runtimeSeconds,
    required double avgDepth,
    required int startPressure,
    required int endPressure,
    double? volume,
    String tankRole = 'backGas',
    int? diveDateTimeMs,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final diveDateTime = diveDateTimeMs ?? now;

    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(diveDateTime),
            bottomTime: Value(bottomTimeSeconds),
            runtime: Value(runtimeSeconds),
            avgDepth: Value(avgDepth),
            maxDepth: Value(avgDepth + 5),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('tank-$diveId'),
            diveId: Value(diveId),
            startPressure: Value(startPressure),
            endPressure: Value(endPressure),
            volume: Value(volume),
            tankRole: Value(tankRole),
            o2Percent: const Value(21.0),
            hePercent: const Value(0.0),
            tankOrder: const Value(0),
          ),
        );

    return diveId;
  }

  // ---------------------------------------------------------------------------
  // SAC Volume Trend (uses COALESCE(d.runtime, d.bottom_time))
  // ---------------------------------------------------------------------------

  group('getSacVolumeTrend', () {
    test('computes SAC using runtime when available', () async {
      await insertDiveWithTank(
        id: 'dive-runtime',
        bottomTimeSeconds: 35 * 60, // 35 min bottom time
        runtimeSeconds: 42 * 60, // 42 min runtime
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        volume: 11.1,
      );

      final results = await repository.getSacVolumeTrend();

      expect(results, hasLength(1));
      // SAC = (200-50) * 11.1 / (42) / ((20/10)+1)
      // SAC = 150 * 11.1 / 42 / 3 = 13.21 L/min
      expect(results.first.value, closeTo(13.21, 0.5));
    });

    test('falls back to bottom_time when runtime is null', () async {
      await insertDiveWithTank(
        id: 'dive-bt-only',
        bottomTimeSeconds: 35 * 60, // 35 min
        runtimeSeconds: null,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        volume: 11.1,
      );

      final results = await repository.getSacVolumeTrend();

      expect(results, hasLength(1));
      // SAC = (200-50) * 11.1 / (35) / ((20/10)+1)
      // SAC = 150 * 11.1 / 35 / 3 = 15.86 L/min
      expect(results.first.value, closeTo(15.86, 0.5));
    });

    test('returns empty when no valid data', () async {
      final results = await repository.getSacVolumeTrend();
      expect(results, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // SAC Pressure Trend (uses COALESCE(d.runtime, d.bottom_time))
  // ---------------------------------------------------------------------------

  group('getSacPressureTrend', () {
    test('computes pressure SAC using runtime', () async {
      await insertDiveWithTank(
        id: 'dive-pressure-rt',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 42 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
      );

      final results = await repository.getSacPressureTrend();

      expect(results, hasLength(1));
      // pressure SAC = (200-50) / (42) / ((20/10)+1)
      // = 150 / 42 / 3 = 1.19 bar/min
      expect(results.first.value, closeTo(1.19, 0.1));
    });

    test('falls back to bottom_time when runtime null', () async {
      await insertDiveWithTank(
        id: 'dive-pressure-bt',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: null,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
      );

      final results = await repository.getSacPressureTrend();

      expect(results, hasLength(1));
      // pressure SAC = 150 / 35 / 3 = 1.43 bar/min
      expect(results.first.value, closeTo(1.43, 0.1));
    });
  });

  // ---------------------------------------------------------------------------
  // SAC Volume Records (uses COALESCE(d.runtime, d.bottom_time))
  // ---------------------------------------------------------------------------

  group('getSacVolumeRecords', () {
    test('returns best and worst SAC using runtime', () async {
      // Good SAC dive (low SAC = efficient)
      await insertDiveWithTank(
        id: 'dive-good',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 50 * 60,
        avgDepth: 15.0,
        startPressure: 200,
        endPressure: 100,
        volume: 11.1,
      );

      // Bad SAC dive (high SAC = inefficient)
      await insertDiveWithTank(
        id: 'dive-bad',
        bottomTimeSeconds: 25 * 60,
        runtimeSeconds: 30 * 60,
        avgDepth: 30.0,
        startPressure: 200,
        endPressure: 30,
        volume: 11.1,
      );

      final records = await repository.getSacVolumeRecords();

      expect(records.best, isNotNull);
      expect(records.worst, isNotNull);
      expect(records.best!.value!, lessThan(records.worst!.value!));
    });

    test('returns null when no data', () async {
      final records = await repository.getSacVolumeRecords();
      expect(records.best, isNull);
      expect(records.worst, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // SAC Pressure Records
  // ---------------------------------------------------------------------------

  group('getSacPressureRecords', () {
    test('returns best/worst using runtime', () async {
      await insertDiveWithTank(
        id: 'dive-good-p',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 50 * 60,
        avgDepth: 15.0,
        startPressure: 200,
        endPressure: 100,
      );

      await insertDiveWithTank(
        id: 'dive-bad-p',
        bottomTimeSeconds: 25 * 60,
        runtimeSeconds: 30 * 60,
        avgDepth: 30.0,
        startPressure: 200,
        endPressure: 30,
      );

      final records = await repository.getSacPressureRecords();

      expect(records.best, isNotNull);
      expect(records.worst, isNotNull);
      expect(records.best!.value!, lessThan(records.worst!.value!));
    });

    test('falls back to bottom_time', () async {
      await insertDiveWithTank(
        id: 'dive-bt-rec',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: null,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 80,
      );

      final records = await repository.getSacPressureRecords();
      expect(records.best, isNotNull);
      expect(records.best!.value!, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // SAC By Tank Role
  // ---------------------------------------------------------------------------

  group('getSacByTankRole', () {
    test('groups SAC by tank role using runtime', () async {
      await insertDiveWithTank(
        id: 'dive-back',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 42 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        tankRole: 'backGas',
      );

      final sacByRole = await repository.getSacByTankRole();

      expect(sacByRole, isNotEmpty);
      expect(sacByRole.containsKey('backGas'), isTrue);
      expect(sacByRole['backGas']!, greaterThan(0));
    });

    test('falls back to bottom_time when runtime null', () async {
      await insertDiveWithTank(
        id: 'dive-norunt',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: null,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        tankRole: 'backGas',
      );

      final sacByRole = await repository.getSacByTankRole();

      expect(sacByRole, isNotEmpty);
      expect(sacByRole['backGas']!, greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Bottom Time Trend (uses bottom_time column directly)
  // ---------------------------------------------------------------------------

  group('getBottomTimeTrend', () {
    test('computes average bottom time per month', () async {
      await insertDiveWithTank(
        id: 'dive-bt-trend',
        bottomTimeSeconds: 45 * 60, // 45 min
        runtimeSeconds: 50 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
      );

      final results = await repository.getBottomTimeTrend();

      expect(results, hasLength(1));
      expect(results.first.value, closeTo(45.0, 0.5));
    });

    test('returns empty when no bottom_time data', () async {
      // Insert dive with null bottom_time
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('dive-no-bt'),
              diveDateTime: Value(now),
              bottomTime: const Value(null),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final results = await repository.getBottomTimeTrend();
      expect(results, isEmpty);
    });
  });
}
