import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> insertDive({
    String? id,
    int? diveNumber,
    int? bottomTimeSeconds,
    int? runtimeSeconds,
    double? maxDepth,
    double? avgDepth,
    double? waterTemp,
    int? diveDateTimeMs,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(diveDateTimeMs ?? now),
            diveNumber: Value(diveNumber),
            bottomTime: Value(bottomTimeSeconds),
            runtime: Value(runtimeSeconds),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            waterTemp: Value(waterTemp),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  // ---------------------------------------------------------------------------
  // getDiveSummaries - tests bottom_time column mapping
  // ---------------------------------------------------------------------------

  group('getDiveSummaries', () {
    test('maps bottom_time column to DiveSummary.bottomTime', () async {
      await insertDive(
        id: 'dive-bt',
        diveNumber: 1,
        bottomTimeSeconds: 45 * 60,
        runtimeSeconds: 50 * 60,
        maxDepth: 25.0,
      );

      final summaries = await repository.getDiveSummaries(limit: 10);

      expect(summaries, hasLength(1));
      expect(summaries.first.bottomTime, const Duration(minutes: 45));
      expect(summaries.first.runtime, const Duration(minutes: 50));
    });

    test('handles null bottom_time', () async {
      await insertDive(
        id: 'dive-null-bt',
        diveNumber: 1,
        bottomTimeSeconds: null,
        maxDepth: 20.0,
      );

      final summaries = await repository.getDiveSummaries(limit: 10);

      expect(summaries, hasLength(1));
      expect(summaries.first.bottomTime, isNull);
    });

    test('returns DiveSummary type', () async {
      await insertDive(id: 'dive-type', diveNumber: 1);

      final summaries = await repository.getDiveSummaries(limit: 10);

      expect(summaries, hasLength(1));
      expect(summaries.first, isA<DiveSummary>());
    });
  });

  // ---------------------------------------------------------------------------
  // Sort by bottomTime
  // ---------------------------------------------------------------------------

  group('sort by bottomTime', () {
    test('sorts by bottom_time ascending', () async {
      await insertDive(
        id: 'dive-short',
        diveNumber: 1,
        bottomTimeSeconds: 20 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );
      await insertDive(
        id: 'dive-long',
        diveNumber: 2,
        bottomTimeSeconds: 60 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 11, 0).millisecondsSinceEpoch,
      );

      final summaries = await repository.getDiveSummaries(
        limit: 10,
        sort: const SortState(
          field: DiveSortField.bottomTime,
          direction: SortDirection.ascending,
        ),
      );

      expect(summaries, hasLength(2));
      expect(summaries.first.id, 'dive-short');
      expect(summaries.last.id, 'dive-long');
    });

    test('sorts by bottom_time descending', () async {
      await insertDive(
        id: 'dive-short2',
        diveNumber: 1,
        bottomTimeSeconds: 20 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );
      await insertDive(
        id: 'dive-long2',
        diveNumber: 2,
        bottomTimeSeconds: 60 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 11, 0).millisecondsSinceEpoch,
      );

      final summaries = await repository.getDiveSummaries(
        limit: 10,
        sort: const SortState(
          field: DiveSortField.bottomTime,
          direction: SortDirection.descending,
        ),
      );

      expect(summaries, hasLength(2));
      expect(summaries.first.id, 'dive-long2');
      expect(summaries.last.id, 'dive-short2');
    });
  });

  // ---------------------------------------------------------------------------
  // Filter by bottomTime (minBottomTimeMinutes / maxBottomTimeMinutes)
  // ---------------------------------------------------------------------------

  group('filter by bottomTime', () {
    test('filters by minBottomTimeMinutes', () async {
      await insertDive(
        id: 'dive-10min',
        diveNumber: 1,
        bottomTimeSeconds: 10 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );
      await insertDive(
        id: 'dive-45min',
        diveNumber: 2,
        bottomTimeSeconds: 45 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 11, 0).millisecondsSinceEpoch,
      );

      final summaries = await repository.getDiveSummaries(
        limit: 10,
        filter: const DiveFilterState(minBottomTimeMinutes: 30),
      );

      expect(summaries, hasLength(1));
      expect(summaries.first.id, 'dive-45min');
    });

    test('filters by maxBottomTimeMinutes', () async {
      await insertDive(
        id: 'dive-20min',
        diveNumber: 1,
        bottomTimeSeconds: 20 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );
      await insertDive(
        id: 'dive-60min',
        diveNumber: 2,
        bottomTimeSeconds: 60 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 11, 0).millisecondsSinceEpoch,
      );

      final summaries = await repository.getDiveSummaries(
        limit: 10,
        filter: const DiveFilterState(maxBottomTimeMinutes: 30),
      );

      expect(summaries, hasLength(1));
      expect(summaries.first.id, 'dive-20min');
    });

    test('filters by both min and max bottomTimeMinutes', () async {
      await insertDive(
        id: 'dive-5min',
        diveNumber: 1,
        bottomTimeSeconds: 5 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 9, 0).millisecondsSinceEpoch,
      );
      await insertDive(
        id: 'dive-35min',
        diveNumber: 2,
        bottomTimeSeconds: 35 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );
      await insertDive(
        id: 'dive-75min',
        diveNumber: 3,
        bottomTimeSeconds: 75 * 60,
        diveDateTimeMs: DateTime(2026, 3, 28, 11, 0).millisecondsSinceEpoch,
      );

      final summaries = await repository.getDiveSummaries(
        limit: 10,
        filter: const DiveFilterState(
          minBottomTimeMinutes: 20,
          maxBottomTimeMinutes: 60,
        ),
      );

      expect(summaries, hasLength(1));
      expect(summaries.first.id, 'dive-35min');
    });
  });

  // ---------------------------------------------------------------------------
  // getStatistics - SUM(COALESCE(runtime, bottom_time))
  // ---------------------------------------------------------------------------

  group('getStatistics', () {
    test('falls back to bottom_time when runtime is null', () async {
      await insertDive(
        id: 'dive-stat1',
        diveNumber: 1,
        bottomTimeSeconds: 30 * 60,
        maxDepth: 20.0,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );
      await insertDive(
        id: 'dive-stat2',
        diveNumber: 2,
        bottomTimeSeconds: 45 * 60,
        maxDepth: 25.0,
        diveDateTimeMs: DateTime(2026, 3, 28, 11, 0).millisecondsSinceEpoch,
      );

      final stats = await repository.getStatistics();

      expect(stats.totalDives, 2);
      // No runtime set → falls back to bottom times: 30 + 45 = 75 minutes
      expect(stats.totalTimeSeconds, (30 + 45) * 60);
    });

    test('prefers runtime over bottom_time when both are set', () async {
      // Regression for issue #195: total time was summing bottom_time only,
      // ignoring the runtime field that captures full descent/ascent/bottom.
      await insertDive(
        id: 'dive-with-runtime',
        diveNumber: 1,
        bottomTimeSeconds: 30 * 60,
        runtimeSeconds: 40 * 60,
        maxDepth: 20.0,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );
      await insertDive(
        id: 'dive-no-runtime',
        diveNumber: 2,
        bottomTimeSeconds: 45 * 60,
        maxDepth: 25.0,
        diveDateTimeMs: DateTime(2026, 3, 28, 11, 0).millisecondsSinceEpoch,
      );

      final stats = await repository.getStatistics();

      expect(stats.totalDives, 2);
      // Dive 1 contributes runtime (40), dive 2 falls back to bottom_time (45)
      expect(stats.totalTimeSeconds, (40 + 45) * 60);
    });
  });

  // ---------------------------------------------------------------------------
  // getStatistics - depth distribution buckets (issue #641)
  // ---------------------------------------------------------------------------

  group('getStatistics depth distribution', () {
    test(
      'buckets max depth into 10m ranges up to 130m, with an open-ended tail',
      () async {
        await insertDive(id: 'dive-5m', maxDepth: 5.0);
        await insertDive(id: 'dive-35m', maxDepth: 35.0);
        await insertDive(id: 'dive-40m', maxDepth: 40.0);
        await insertDive(id: 'dive-125m', maxDepth: 125.0);
        await insertDive(id: 'dive-150m', maxDepth: 150.0);

        final stats = await repository.getStatistics();
        final byLabel = {for (final d in stats.depthDistribution) d.label: d};

        expect(stats.depthDistribution.length, 14);
        expect(byLabel['0-10m']!.count, 1);
        expect(byLabel['30-40m']!.count, 1);
        // A dive at exactly 40m now falls in its own 40-50m bucket instead of
        // the old open-ended "40m+" catch-all.
        expect(byLabel['40-50m']!.count, 1);
        expect(byLabel['40-50m']!.openEnded, isFalse);
        expect(byLabel['120-130m']!.count, 1);
        expect(byLabel['130m+']!.count, 1);
        expect(byLabel['130m+']!.openEnded, isTrue);
      },
    );

    test(
      'dives under 40m are still counted correctly (no regression)',
      () async {
        await insertDive(id: 'dive-a', maxDepth: 12.0);
        await insertDive(id: 'dive-b', maxDepth: 12.0);
        await insertDive(id: 'dive-c', maxDepth: 38.0);

        final stats = await repository.getStatistics();
        final byLabel = {for (final d in stats.depthDistribution) d.label: d};

        expect(byLabel['10-20m']!.count, 2);
        expect(byLabel['30-40m']!.count, 1);
      },
    );

    test('sums dive time per bucket, preferring runtime over bottom_time '
        '(issue #641 follow-up)', () async {
      await insertDive(
        id: 'dive-a',
        maxDepth: 12.0,
        bottomTimeSeconds: 20 * 60,
        runtimeSeconds: 25 * 60,
      );
      await insertDive(
        id: 'dive-b',
        maxDepth: 15.0,
        bottomTimeSeconds: 30 * 60,
      );
      await insertDive(
        id: 'dive-c',
        maxDepth: 38.0,
        bottomTimeSeconds: 45 * 60,
      );

      final stats = await repository.getStatistics();
      final byLabel = {for (final d in stats.depthDistribution) d.label: d};

      // dive-a prefers runtime (25m) over bottom_time (20m); dive-b has no
      // runtime and falls back to bottom_time (30m). Same bucket: 55m total.
      expect(byLabel['10-20m']!.totalDurationSeconds, 55 * 60);
      expect(byLabel['30-40m']!.totalDurationSeconds, 45 * 60);
      expect(byLabel['0-10m']!.totalDurationSeconds, 0);
    });

    test('falls back to the profile span when runtime, entry/exit time, and '
        'bottom_time are all missing (issue #641 follow-up)', () async {
      // No runtime/entryTime/exitTime/bottomTime: effectiveRuntime can only
      // resolve via the profile-derived fallback (30 min span).
      await repository.createDive(
        domain.Dive(
          id: 'dive-profile-only',
          dateTime: DateTime.utc(2026, 3, 28, 10),
          maxDepth: 22.0,
          profile: [
            for (var t = 0; t <= 1800; t += 10)
              domain.DiveProfilePoint(
                timestamp: t,
                depth: t == 0 || t == 1800 ? 0 : 22,
              ),
          ],
        ),
      );
      await insertDive(
        id: 'dive-with-bottom-time',
        maxDepth: 22.0,
        bottomTimeSeconds: 10 * 60,
      );

      final stats = await repository.getStatistics();
      final byLabel = {for (final d in stats.depthDistribution) d.label: d};

      // dive-profile-only contributes its 30 min profile span; dive-with-
      // bottom-time contributes its 10 min bottom_time. Same bucket: 40m.
      expect(byLabel['20-30m']!.totalDurationSeconds, (30 + 10) * 60);
      expect(byLabel['20-30m']!.count, 2);
    });

    test('falls back to exit - entry when there is no runtime, ahead of the '
        'profile span and bottom_time (issue #641 follow-up)', () async {
      await repository.createDive(
        domain.Dive(
          id: 'dive-entry-exit',
          dateTime: DateTime.utc(2026, 3, 29, 10),
          maxDepth: 45.0,
          entryTime: DateTime.utc(2026, 3, 29, 10),
          exitTime: DateTime.utc(2026, 3, 29, 10, 50),
          bottomTime: const Duration(minutes: 20),
          profile: [
            for (var t = 0; t <= 600; t += 10)
              domain.DiveProfilePoint(
                timestamp: t,
                depth: t == 0 || t == 600 ? 0 : 45,
              ),
          ],
        ),
      );

      final stats = await repository.getStatistics();
      final byLabel = {for (final d in stats.depthDistribution) d.label: d};

      // 50 min from the timestamps, not the 10 min profile span and not the
      // 20 min bottom_time: both sit later in the chain.
      expect(byLabel['40-50m']!.totalDurationSeconds, 50 * 60);
    });

    test(
      'reports zero time for a bucket whose dives carry no duration at all',
      () async {
        await insertDive(id: 'dive-untimed', maxDepth: 18.0);

        final stats = await repository.getStatistics();
        final byLabel = {for (final d in stats.depthDistribution) d.label: d};

        // SUM over an all-NULL column is NULL; the bucket still reports its
        // dive, with no time behind it.
        expect(byLabel['10-20m']!.count, 1);
        expect(byLabel['10-20m']!.totalDurationSeconds, 0);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // getDiveRecords - bottom_time mapping in DiveRecord
  // ---------------------------------------------------------------------------

  group('getDiveRecords', () {
    test('maps bottom_time to DiveRecord.bottomTime', () async {
      await insertDive(
        id: 'dive-record',
        diveNumber: 1,
        bottomTimeSeconds: 45 * 60,
        maxDepth: 30.0,
        waterTemp: 22.0,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );

      final records = await repository.getRecords();

      expect(records.longestDive, isNotNull);
      expect(records.longestDive!.bottomTime, const Duration(minutes: 45));
    });

    test('longestDive query orders by bottom_time DESC', () async {
      await insertDive(
        id: 'dive-short-rec',
        diveNumber: 1,
        bottomTimeSeconds: 20 * 60,
        maxDepth: 20.0,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );
      await insertDive(
        id: 'dive-long-rec',
        diveNumber: 2,
        bottomTimeSeconds: 60 * 60,
        maxDepth: 25.0,
        diveDateTimeMs: DateTime(2026, 3, 28, 11, 0).millisecondsSinceEpoch,
      );

      final records = await repository.getRecords();

      expect(records.longestDive, isNotNull);
      expect(records.longestDive!.diveId, 'dive-long-rec');
      expect(records.longestDive!.bottomTime, const Duration(minutes: 60));
    });

    test('handles null bottom_time in records', () async {
      await insertDive(
        id: 'dive-no-bt',
        diveNumber: 1,
        bottomTimeSeconds: null,
        maxDepth: 20.0,
        diveDateTimeMs: DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch,
      );

      final records = await repository.getRecords();

      // Longest dive should be null since no dives have bottom_time
      expect(records.longestDive, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // getSurfaceInterval - effectiveRuntime fallback (line 2977)
  // ---------------------------------------------------------------------------

  group('getSurfaceInterval', () {
    test('uses effectiveRuntime when previous dive has no exitTime', () async {
      // First dive: has entryTime + bottomTime but NO exitTime
      // effectiveRuntime will use bottomTime as fallback
      final dt1 = DateTime(2026, 3, 28, 10, 0).millisecondsSinceEpoch;
      final entry1 = DateTime(2026, 3, 28, 10, 5).millisecondsSinceEpoch;
      await insertDive(
        id: 'dive-prev',
        diveNumber: 1,
        bottomTimeSeconds: 45 * 60,
        diveDateTimeMs: dt1,
      );
      // Manually set entryTime without exitTime
      await db.customStatement(
        "UPDATE dives SET entry_time = ? WHERE id = 'dive-prev'",
        [entry1],
      );

      // Second dive: 2 hours after first dive's estimated exit
      final dt2 = DateTime(2026, 3, 28, 12, 0).millisecondsSinceEpoch;
      await insertDive(
        id: 'dive-curr',
        diveNumber: 2,
        bottomTimeSeconds: 30 * 60,
        diveDateTimeMs: dt2,
      );

      final interval = await repository.getSurfaceInterval('dive-curr');

      expect(interval, isNotNull);
      expect(interval!.inMinutes, greaterThan(0));
    });
  });
}
