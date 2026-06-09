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
    String? diverId,
    int? entryTimeMs,
    int? exitTimeMs,
    int? surfaceIntervalSeconds,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    final diveDateTime = entryTimeMs ?? now;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diverId: Value(diverId),
            diveDateTime: Value(diveDateTime),
            entryTime: Value(entryTimeMs),
            exitTime: Value(exitTimeMs),
            surfaceIntervalSeconds: Value(surfaceIntervalSeconds),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  // ---------------------------------------------------------------------------
  // getSurfaceIntervalStats — regression for issue #235
  // ---------------------------------------------------------------------------

  group('getSurfaceIntervalStats', () {
    test(
      'computes stats from explicit surface_interval_seconds when present',
      () async {
        await insertDive(id: 'dive-si-1', surfaceIntervalSeconds: 3600);
        await insertDive(id: 'dive-si-2', surfaceIntervalSeconds: 7200);

        final stats = await repository.getSurfaceIntervalStats();

        expect(stats.avgMinutes, isNotNull);
        expect(stats.avgMinutes, closeTo(90.0, 0.1)); // avg of 60 and 120 min
        expect(stats.minMinutes, closeTo(60.0, 0.1));
        expect(stats.maxMinutes, closeTo(120.0, 0.1));
      },
    );

    test(
      'computes stats from entry/exit timestamps when surface_interval_seconds is null',
      () async {
        final diverId = await insertDiver(id: 'diver-si-test');

        // Dive 1: entry at T=0, exit at T=30min
        final base = DateTime(2024, 6, 1).millisecondsSinceEpoch;
        await insertDive(
          id: 'dive-ts-1',
          diverId: diverId,
          entryTimeMs: base,
          exitTimeMs: base + 30 * 60 * 1000,
          surfaceIntervalSeconds: null,
        );

        // Dive 2: entry at T=2h — surface interval = 2h - 30min = 90min = 5400s
        await insertDive(
          id: 'dive-ts-2',
          diverId: diverId,
          entryTimeMs: base + 2 * 60 * 60 * 1000,
          exitTimeMs: base + 2 * 60 * 60 * 1000 + 45 * 60 * 1000,
          surfaceIntervalSeconds: null,
        );

        final stats = await repository.getSurfaceIntervalStats();

        expect(stats.avgMinutes, isNotNull);
        expect(stats.avgMinutes, closeTo(90.0, 1.0));
        expect(stats.minMinutes, closeTo(90.0, 1.0));
        expect(stats.maxMinutes, closeTo(90.0, 1.0));
      },
    );

    test('mixes explicit and computed surface intervals', () async {
      final diverId = await insertDiver(id: 'diver-mixed');
      final base = DateTime(2024, 7, 1).millisecondsSinceEpoch;

      // Dive 1: exit at T+1h, no surface interval stored
      await insertDive(
        id: 'dive-mix-1',
        diverId: diverId,
        entryTimeMs: base,
        exitTimeMs: base + 60 * 60 * 1000,
        surfaceIntervalSeconds: null,
      );

      // Dive 2: entry at T+3h; computed SI = 2h = 120 min
      await insertDive(
        id: 'dive-mix-2',
        diverId: diverId,
        entryTimeMs: base + 3 * 60 * 60 * 1000,
        exitTimeMs: base + 4 * 60 * 60 * 1000,
        surfaceIntervalSeconds: null,
      );

      // Dive 3: explicit SI of 60 min (3600 s)
      await insertDive(
        id: 'dive-mix-3',
        diverId: diverId,
        entryTimeMs: base + 6 * 60 * 60 * 1000,
        surfaceIntervalSeconds: 3600,
      );

      final stats = await repository.getSurfaceIntervalStats();

      // Intervals: 120 min (computed), 60 min (explicit) => avg=90, min=60, max=120
      expect(stats.avgMinutes, isNotNull);
      expect(stats.avgMinutes, closeTo(90.0, 1.0));
      expect(stats.minMinutes, closeTo(60.0, 1.0));
      expect(stats.maxMinutes, closeTo(120.0, 1.0));
    });

    test(
      'returns null stats when no computable surface intervals exist',
      () async {
        // Single dive — no previous dive to compute interval from
        final singleDiverId = await insertDiver(id: 'diver-single');
        await insertDive(
          id: 'dive-alone',
          diverId: singleDiverId,
          entryTimeMs: DateTime(2024, 8, 1).millisecondsSinceEpoch,
          exitTimeMs: DateTime(2024, 8, 1).millisecondsSinceEpoch + 3600000,
          surfaceIntervalSeconds: null,
        );

        final stats = await repository.getSurfaceIntervalStats();

        // Single dive has no prior exit_time to reference, so no interval
        expect(stats.avgMinutes, isNull);
        expect(stats.minMinutes, isNull);
        expect(stats.maxMinutes, isNull);
      },
    );

    test('returns null stats when no dives exist', () async {
      final stats = await repository.getSurfaceIntervalStats();

      expect(stats.avgMinutes, isNull);
      expect(stats.minMinutes, isNull);
      expect(stats.maxMinutes, isNull);
    });
  });
}
