import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/unique_ids.dart';

void main() {
  late InsightsRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
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
    final diveId = id ?? uniqueTestId('dive');
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
            startPressure: Value(startPressure.toDouble()),
            endPressure: Value(endPressure.toDouble()),
            volume: Value(volume),
            tankRole: Value(tankRole),
            o2Percent: const Value(21.0),
            hePercent: const Value(0.0),
            tankOrder: const Value(0),
          ),
        );

    return diveId;
  }

  Future<void> insertTank({
    required String diveId,
    required int startPressure,
    required int endPressure,
    double? volume,
    String tankRole = 'stage',
    int tankOrder = 1,
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value('tank-$diveId-$tankOrder'),
            diveId: Value(diveId),
            startPressure: Value(startPressure.toDouble()),
            endPressure: Value(endPressure.toDouble()),
            volume: Value(volume),
            tankRole: Value(tankRole),
            o2Percent: const Value(21.0),
            hePercent: const Value(0.0),
            tankOrder: Value(tankOrder),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // SAC Volume Trend (uses COALESCE(d.runtime, d.bottom_time))
  // ---------------------------------------------------------------------------

  group('getSacVolumePerDive', () {
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

      final results = await repository.getSacVolumePerDive();

      expect(results, hasLength(1));
      // SAC with Z-factor: gasVol(200)-gasVol(50) at 11.1L / 42 / 3.0 ≈ 12.40 L/min
      expect(results.first.value, closeTo(12.40, 0.5));
    });

    test('leaves out a dive with only a bottom time', () async {
      await insertDiveWithTank(
        id: 'dive-bt-only',
        bottomTimeSeconds: 35 * 60, // 35 min
        runtimeSeconds: null,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        volume: 11.1,
      );

      expect(await repository.getSacVolumePerDive(), isEmpty);
    });

    test('returns empty when no valid data', () async {
      final results = await repository.getSacVolumePerDive();
      expect(results, isEmpty);
    });

    test('sums gas across all tanks for a multi-tank dive', () async {
      // Insert a dive with two tanks
      // Back gas: 12L, 200->100 bar (1200L gas used)
      // Stage: 7L, 200->150 bar (350L gas used)
      // Total: 1550L
      // runtime: 42 min, avgDepth: 20m, ambientPressure: 3.0 atm
      // Expected SAC: 1550 / 42 / 3.0 ≈ 12.30 L/min
      //
      // OLD (broken) behavior: treats each tank row as independent ->
      //   tank1 SAC: 1200/42/3 = 9.52, tank2 SAC: 350/42/3 = 2.78, avg: 6.15
      //   The new query must return ~12.30, not ~6.15.
      final diveId = await insertDiveWithTank(
        id: 'dive-multi-vol-trend',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 42 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 100,
        volume: 12.0,
        tankRole: 'backGas',
      );
      await insertTank(
        diveId: diveId,
        startPressure: 200,
        endPressure: 150,
        volume: 7.0,
        tankRole: 'stage',
        tankOrder: 2,
      );

      final results = await repository.getSacVolumePerDive();

      expect(results, hasLength(1));
      // With Z-factor: ≈ 11.15 L/min
      expect(results.first.value, closeTo(11.15, 0.5));
    });
  });

  // ---------------------------------------------------------------------------
  // SAC Pressure Trend (uses COALESCE(d.runtime, d.bottom_time))
  // ---------------------------------------------------------------------------

  group('getSacPressurePerDive', () {
    test('computes pressure SAC using runtime', () async {
      await insertDiveWithTank(
        id: 'dive-pressure-rt',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 42 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
      );

      final results = await repository.getSacPressurePerDive();

      expect(results, hasLength(1));
      // pressure SAC = (200-50) / (42) / ((20/10)+1)
      // = 150 / 42 / 3 = 1.19 bar/min
      expect(results.first.value, closeTo(1.19, 0.1));
    });

    test('leaves out a dive with only a bottom time', () async {
      await insertDiveWithTank(
        id: 'dive-pressure-bt',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: null,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
      );

      expect(await repository.getSacPressurePerDive(), isEmpty);
    });

    test('uses back gas tank only for multi-tank dive', () async {
      // Back gas: 200->100 bar (100 bar used), role 'backGas'
      // Stage: 200->150 bar (50 bar used), role 'stage'
      // runtime: 42 min, avgDepth: 20m, ambientPressure: 3.0 atm
      // Expected: 100 / 42 / 3.0 ≈ 0.794 bar/min (back gas only)
      // NOT: averaged or combined with stage
      final diveId = await insertDiveWithTank(
        id: 'dive-multi-pres-trend',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 42 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 100,
        tankRole: 'backGas',
      );
      await insertTank(
        diveId: diveId,
        startPressure: 200,
        endPressure: 150,
        tankRole: 'stage',
        tankOrder: 2,
      );

      final results = await repository.getSacPressurePerDive();

      expect(results, hasLength(1));
      // 100 / 42 / 3.0 = 0.794 bar/min
      expect(results.first.value, closeTo(0.794, 0.05));
    });

    test(
      'excludes dive when back gas tank has no valid pressure drop',
      () async {
        // backGas: start=100, end=200 (invalid — no drop)
        // stage: start=200, end=100 (valid — 100 bar drop)
        // Must NOT fall back to stage; must exclude dive entirely,
        // matching Dive.sac which returns null in this case.
        final diveId = await insertDiveWithTank(
          id: 'dive-pres-trend-invalid-bg',
          bottomTimeSeconds: 35 * 60,
          runtimeSeconds: 42 * 60,
          avgDepth: 20.0,
          startPressure: 100,
          endPressure: 200,
          tankRole: 'backGas',
        );
        await insertTank(
          diveId: diveId,
          startPressure: 200,
          endPressure: 100,
          tankRole: 'stage',
          tankOrder: 2,
        );

        final results = await repository.getSacPressurePerDive();

        expect(results, isEmpty);
      },
    );
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

    test(
      'produces one record per dive not per tank for multi-tank dives',
      () async {
        // Insert ONE dive with TWO tanks -- both valid, both with volume
        // If the query is broken, it returns two rows (one per tank) and
        // best.id != worst.id even though there's only one dive.
        // After fix: best and worst both point to the same dive id.
        final diveId = await insertDiveWithTank(
          id: 'dive-multi-vol-rec',
          bottomTimeSeconds: 35 * 60,
          runtimeSeconds: 42 * 60,
          avgDepth: 20.0,
          startPressure: 200,
          endPressure: 100,
          volume: 12.0,
          tankRole: 'backGas',
        );
        await insertTank(
          diveId: diveId,
          startPressure: 200,
          endPressure: 150,
          volume: 7.0,
          tankRole: 'stage',
          tankOrder: 2,
        );

        final records = await repository.getSacVolumeRecords();

        expect(records.best, isNotNull);
        expect(records.worst, isNotNull);
        // Both best and worst must point to the same single dive
        expect(records.best!.id, equals(records.worst!.id));
        expect(records.best!.id, equals(diveId));
      },
    );
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

    test('leaves out a dive with only a bottom time', () async {
      await insertDiveWithTank(
        id: 'dive-bt-rec',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: null,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 80,
      );

      final records = await repository.getSacPressureRecords();
      expect(records.best, isNull);
    });

    test('uses back gas tank only for multi-tank dive records', () async {
      // ONE dive with back gas (100 bar used) and stage (50 bar used)
      // Records SAC must equal back-gas-only SAC, not averaged
      // runtime: 42 min, avgDepth: 20m -> back gas SAC: 100/42/3 ≈ 0.794
      final diveId = await insertDiveWithTank(
        id: 'dive-multi-pres-rec',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 42 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 100,
        tankRole: 'backGas',
      );
      await insertTank(
        diveId: diveId,
        startPressure: 200,
        endPressure: 150,
        tankRole: 'stage',
        tankOrder: 2,
      );

      final records = await repository.getSacPressureRecords();

      expect(records.best, isNotNull);
      expect(records.worst, isNotNull);
      // Both best and worst must point to the same single dive
      expect(records.best!.id, equals(records.worst!.id));
      expect(records.best!.id, equals(diveId));
      // SAC must be back-gas-only: 100/42/3 ≈ 0.794 bar/min
      expect(records.best!.value!, closeTo(0.794, 0.05));
    });

    test(
      'excludes dive when back gas tank has no valid pressure drop',
      () async {
        // backGas: start=100, end=200 (invalid — no drop)
        // stage: start=200, end=100 (valid — 100 bar drop)
        // Must NOT fall back to stage; must exclude dive entirely,
        // matching Dive.sac which returns null in this case.
        final diveId = await insertDiveWithTank(
          id: 'dive-pres-rec-invalid-bg',
          bottomTimeSeconds: 35 * 60,
          runtimeSeconds: 42 * 60,
          avgDepth: 20.0,
          startPressure: 100,
          endPressure: 200,
          tankRole: 'backGas',
        );
        await insertTank(
          diveId: diveId,
          startPressure: 200,
          endPressure: 100,
          tankRole: 'stage',
          tankOrder: 2,
        );

        final records = await repository.getSacPressureRecords();

        expect(records.best, isNull);
        expect(records.worst, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Consumption by cylinder role (issue #771)
  // ---------------------------------------------------------------------------

  group('getRoleConsumptionPerDive', () {
    test('divides by runtime, not bottom time', () async {
      await insertDiveWithTank(
        id: 'dive-back',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 42 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        tankRole: 'backGas',
        volume: 12.0,
      );

      final trend = await repository.getRoleConsumptionPerDive();
      final sac = trend.sac[ConsumptionRoleGroup.bottomGas]!.single.value;

      // About 150 bar over 42 min at 3 ata; the real gas model trims a few
      // percent off the raw drop, and 35 minutes would read 20% higher.
      expect(sac, closeTo(150 / 42 / 3, 150 / 42 / 3 * 0.06));
    });

    test('leaves out a dive with only a bottom time', () async {
      await insertDiveWithTank(
        id: 'dive-norunt',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: null,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        tankRole: 'backGas',
        volume: 12.0,
      );

      final trend = await repository.getRoleConsumptionPerDive();
      expect(trend.rmv, isEmpty);
      expect(trend.sac, isEmpty);
    });

    test('a tank with zero volume has no RMV', () async {
      await insertDiveWithTank(
        id: 'dive-zerovol',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: 42 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        tankRole: 'backGas',
        volume: 0,
      );

      expect((await repository.getRoleConsumptionPerDive()).rmv, isEmpty);
    });

    // Issues #160 and #219: the card once read one query for both settings,
    // so switching bar/min to L/min swapped the unit label while leaving the
    // number untouched (1.6 bar/min became 1.6 L/min).
    test('the two lanes report different magnitudes', () async {
      await insertDiveWithTank(
        id: 'dive-units',
        bottomTimeSeconds: 35 * 60,
        runtimeSeconds: 42 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        tankRole: 'backGas',
        volume: 12.0,
      );

      final trend = await repository.getRoleConsumptionPerDive();
      final sac = trend.sac[ConsumptionRoleGroup.bottomGas]!.single.value;
      final rmv = trend.rmv[ConsumptionRoleGroup.bottomGas]!.single.value;
      expect(rmv, greaterThan(sac * 5));
    });
  });

  // ---------------------------------------------------------------------------
  // Bottom Time Trend (uses bottom_time column directly)
  // ---------------------------------------------------------------------------

  group('getBottomTimePerDive', () {
    test('reports bottom time in minutes, ignoring runtime', () async {
      await insertDiveWithTank(
        id: 'dive-bt-trend',
        bottomTimeSeconds: 45 * 60, // 45 min
        runtimeSeconds: 50 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
      );

      final results = await repository.getBottomTimePerDive();

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

      final results = await repository.getBottomTimePerDive();
      expect(results, isEmpty);
    });
  });

  group('getSacVolumePerDive', () {
    test('returns one point per dive rather than one per month', () async {
      await insertDiveWithTank(
        id: 'dive-1',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        volume: 11.1,
        diveDateTimeMs: DateTime.utc(2024, 5, 10).millisecondsSinceEpoch,
      );
      await insertDiveWithTank(
        id: 'dive-2',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 100,
        volume: 11.1,
        diveDateTimeMs: DateTime.utc(2024, 5, 11).millisecondsSinceEpoch,
      );

      final points = await repository.getSacVolumePerDive();

      expect(points, hasLength(2));
      // Ordered by date, and the second dive used less gas.
      expect(points[0].date.isBefore(points[1].date), isTrue);
      expect(points[1].value, lessThan(points[0].value));
    });

    test('sums every tank on a dive into that dive single SAC', () async {
      final diveId = await insertDiveWithTank(
        id: 'dive-twin',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 100,
        volume: 11.1,
      );
      await insertTank(
        diveId: diveId,
        startPressure: 200,
        endPressure: 100,
        volume: 11.1,
      );

      final points = await repository.getSacVolumePerDive();

      expect(points, hasLength(1));
    });

    test('includes a dive far older than five years', () async {
      final longAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 365 * 8),
      );
      await insertDiveWithTank(
        id: 'ancient',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        volume: 11.1,
        diveDateTimeMs: longAgo.millisecondsSinceEpoch,
      );

      expect(await repository.getSacVolumePerDive(), hasLength(1));
    });
  });

  group('getSacPressurePerDive', () {
    test('returns one point per dive rather than one per month', () async {
      await insertDiveWithTank(
        id: 'dive-1',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        diveDateTimeMs: DateTime.utc(2024, 5, 10).millisecondsSinceEpoch,
      );
      await insertDiveWithTank(
        id: 'dive-2',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 100,
        diveDateTimeMs: DateTime.utc(2024, 5, 11).millisecondsSinceEpoch,
      );

      final points = await repository.getSacPressurePerDive();

      expect(points, hasLength(2));
      // (200-50) / 40 / 3.0 = 1.25 bar/min
      expect(points[0].value, closeTo(1.25, 1e-6));
      // (200-100) / 40 / 3.0 = 0.8333 bar/min
      expect(points[1].value, closeTo(0.8333, 1e-3));
    });

    test('includes a dive far older than five years', () async {
      final longAgo = DateTime.now().toUtc().subtract(
        const Duration(days: 365 * 8),
      );
      await insertDiveWithTank(
        id: 'ancient',
        bottomTimeSeconds: 40 * 60,
        runtimeSeconds: 40 * 60,
        avgDepth: 20.0,
        startPressure: 200,
        endPressure: 50,
        diveDateTimeMs: longAgo.millisecondsSinceEpoch,
      );

      expect(await repository.getSacPressurePerDive(), hasLength(1));
    });
  });
}
