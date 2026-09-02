@Tags(['performance'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:submersion/core/database/database.dart' hide Tags;
import 'package:submersion/core/database/database_connection_setup.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

/// Spec section 10 gates on the synthesized 1,000-dive fixture. Legacy
/// numbers come from the legacy SQL shapes run raw against the
/// pre-migration copy; series numbers from the app's own methods on the
/// migrated copy, opened with the app's own connection setup
/// ([applyMainDatabaseSetup]: busy timeout and WAL) rather than a bare
/// connection. Set SUBMERSION_BENCH_FIXTURE to the fixture path (see
/// test/performance/README.md); the test skips without it.
void main() {
  final fixture = Platform.environment['SUBMERSION_BENCH_FIXTURE'];

  test(
    'profile series benchmarks: nothing slower than the legacy shapes',
    () async {
      if (fixture == null) {
        markTestSkipped('SUBMERSION_BENCH_FIXTURE not set');
        return;
      }
      final work = Directory.systemTemp.createTempSync('series-bench');
      addTearDown(() {
        if (work.existsSync()) work.deleteSync(recursive: true);
      });
      // copySync streams, so a multi-hundred-megabyte fixture never has to
      // fit in the test isolate's heap twice over.
      final legacyCopy = File(fixture).copySync('${work.path}/legacy.db');
      final migratedCopy = File(fixture).copySync('${work.path}/migrated.db');
      final results = <String, ({Duration legacy, Duration series})>{};

      // Legacy shapes, raw SQL, pre-migration copy. The per-dive metric
      // materializes rows into the same domain objects the old read
      // returned, so the timing includes object construction and is not
      // just the raw SELECT. Wrapped in try/finally so a failure partway
      // through still closes the handle before the tear-down above tries
      // to delete the directory it lives in.
      late final List<String> diveIds;
      late final Duration legacyHydrate;
      late final Duration legacySummaries;
      late final Duration legacyAscent;
      late final Duration legacyBuckets;
      late final int sizeBefore;
      final raw = sqlite.sqlite3.open(legacyCopy.path);
      try {
        diveIds = raw
            .select(
              'SELECT id FROM dives ORDER BY dive_date_time DESC LIMIT 50',
            )
            .map((r) => r['id'] as String)
            .toList();
        legacyHydrate = _time(() {
          for (final id in diveIds) {
            final profileRows = raw.select(
              'SELECT * FROM dive_profiles WHERE dive_id = ? AND is_primary = 1 '
              'ORDER BY timestamp',
              [id],
            );
            profileRows
                .map(
                  (row) => domain.DiveProfilePoint(
                    timestamp: row['timestamp'] as int,
                    depth: row['depth'] as double,
                    temperature: row['temperature'] as double?,
                  ),
                )
                .toList();
            final pressureRows = raw.select(
              'SELECT * FROM tank_pressure_profiles WHERE dive_id = ? '
              'ORDER BY timestamp',
              [id],
            );
            pressureRows
                .map(
                  (row) => domain.TankPressurePoint(
                    tankId: row['tank_id'] as String,
                    timestamp: row['timestamp'] as int,
                    pressure: row['pressure'] as double,
                  ),
                )
                .toList();
          }
        });
        legacySummaries = _time(() {
          raw.select(_legacyBatchSummarySql(diveIds.length), diveIds);
        });
        legacyAscent = _time(() => raw.select(_legacyAscentDescentSql));
        legacyBuckets = _time(() => raw.select(_legacyTimeAtDepthSql));
        sizeBefore = legacyCopy.lengthSync();
      } finally {
        raw.close();
      }

      // Migration (the ladder from the fixture's version to 183) plus
      // VACUUM. Opened with the app's own connection setup, matching how
      // the real database connects. Wrapped in try/finally so a failure
      // during migration or VACUUM still closes the connection.
      final storedBefore = DatabaseService.getStoredSchemaVersion(
        migratedCopy.path,
      )!;
      late final Duration migrationElapsed;
      late final Duration vacuumElapsed;
      final migrator = AppDatabase(
        NativeDatabase(migratedCopy, setup: applyMainDatabaseSetup),
      );
      try {
        final migration = Stopwatch()..start();
        await migrator.customSelect('SELECT 1').get();
        migration.stop();
        migrationElapsed = migration.elapsed;
        final vacuum = Stopwatch()..start();
        await migrator.customStatement('VACUUM');
        vacuum.stop();
        vacuumElapsed = vacuum.elapsed;
      } finally {
        await migrator.close();
      }
      final sizeAfter = migratedCopy.lengthSync();

      // Series path through the app, migrated copy, also opened with the
      // app's connection setup. Wrapped in try/finally so a failing
      // assertion further down still closes the connection and resets the
      // test seam before the tear-down deletes the directory.
      late final Duration seriesHydrate;
      late final Duration seriesSummaries;
      late final Duration seriesAscent;
      late final Duration seriesBuckets;
      final db = AppDatabase(
        NativeDatabase(migratedCopy, setup: applyMainDatabaseSetup),
      );
      try {
        DatabaseService.instance.setTestDatabase(db);
        final dives = DiveRepository();
        final tankPressures = TankPressureRepository();
        final stats = StatisticsRepository();
        seriesHydrate = await _timeAsync(() async {
          // getDiveById hydrates the whole entity (tanks, buddies,
          // equipment, site, computer, source, safety data...) and is not
          // the metric here: this compares the same two profile reads the
          // legacy side times above, not a full dive hydrate.
          for (final id in diveIds) {
            await dives.getDiveProfile(id);
            await tankPressures.getTankPressuresForDive(id);
          }
        });
        seriesSummaries = await _timeAsync(
          () => dives.getBatchProfileSummaries(diveIds, maxSamples: 200),
        );
        seriesAscent = await _timeAsync(() => stats.getAscentDescentRates());
        seriesBuckets = await _timeAsync(() => stats.getTimeAtDepthRanges());
      } finally {
        await db.close();
        DatabaseService.instance.resetForTesting();
      }

      results['per-dive profile and tank reads (50 dives)'] = (
        legacy: legacyHydrate,
        series: seriesHydrate,
      );
      results['batch summaries (50 dives)'] = (
        legacy: legacySummaries,
        series: seriesSummaries,
      );
      results['ascent/descent rates'] = (
        legacy: legacyAscent,
        series: seriesAscent,
      );
      results['time at depth'] = (legacy: legacyBuckets, series: seriesBuckets);

      final table = StringBuffer()
        ..writeln('| metric | legacy | series |')
        ..writeln('|---|---|---|');
      for (final e in results.entries) {
        table.writeln(
          '| ${e.key} | ${e.value.legacy.inMilliseconds} ms | '
          '${e.value.series.inMilliseconds} ms |',
        );
      }
      table
        ..writeln(
          '| migration $storedBefore -> ${AppDatabase.currentSchemaVersion} '
          '| | ${migrationElapsed.inMilliseconds} ms |',
        )
        ..writeln('| VACUUM | | ${vacuumElapsed.inMilliseconds} ms |')
        ..writeln(
          '| file size | ${sizeBefore ~/ 1024} KB | ${sizeAfter ~/ 1024} KB |',
        );
      // ignore: avoid_print
      print(table);

      // The two migration assertions come first, so a timing miss below can
      // never hide a migration/drop regression.
      expect(
        sizeAfter,
        lessThan(sizeBefore ~/ 2),
        reason: 'the drop plus VACUUM must return most of the file',
      );
      expect(
        DatabaseService.getStoredSchemaVersion(migratedCopy.path),
        AppDatabase.currentSchemaVersion,
      );

      for (final e in results.entries) {
        expect(
          e.value.series.inMicroseconds,
          lessThanOrEqualTo((e.value.legacy.inMicroseconds * 1.25).round()),
          reason:
              '${e.key}: series ${e.value.series} vs legacy '
              '${e.value.legacy}. The 25% tolerance covers timer noise, the '
              'page-cache state each copy happens to be read under, and the '
              'sync sqlite3 legacy path measured against the async drift '
              'stack the series path goes through',
        );
      }
    },
  );
}

Duration _time(void Function() body) {
  final sw = Stopwatch()..start();
  body();
  return sw.elapsed;
}

Future<Duration> _timeAsync(Future<void> Function() body) async {
  final sw = Stopwatch()..start();
  await body();
  return sw.elapsed;
}

String _legacyBatchSummarySql(int n) =>
    'SELECT dive_id, timestamp, depth FROM dive_profiles '
    'WHERE is_primary = 1 AND dive_id IN '
    '(${List.filled(n, '?').join(',')}) ORDER BY dive_id, timestamp';

// The two aggregation queries as they stood before plan 2d, unfiltered scope
// (diver filter and dive filter clauses empty, leaving `WHERE p.is_primary =
// 1` as the only predicate). Copied verbatim from
// `git show 30234a3973e:lib/features/statistics/data/repositories/statistics_repository.dart`
// (getAscentDescentRates at about line 2200, getTimeAtDepthRanges at about
// line 2297), substituting 15 for `_rateWindowSeconds`, 3.0 for
// `_sustainedTransitThreshold` and 4 for `_maxSampleGapFactor`.
const _legacyAscentDescentSql = '''
WITH windows AS (
  SELECT
    p.dive_id AS dive_id,
    p.computer_id AS computer_id,
    p.timestamp / 15 AS window_index,
    AVG(p.depth) AS depth,
    AVG(p.timestamp) AS at
  FROM dive_profiles p
  JOIN dives d ON d.id = p.dive_id
  WHERE p.is_primary = 1
  GROUP BY p.dive_id, p.computer_id, p.timestamp / 15
),
paired AS (
  SELECT
    depth,
    at,
    LAG(depth) OVER w AS prev_depth,
    LAG(at) OVER w AS prev_at
  FROM windows
  WINDOW w AS (PARTITION BY dive_id, computer_id ORDER BY window_index)
),
rates AS (
  SELECT (prev_depth - depth) * 60.0 / (at - prev_at) AS rate
  FROM paired
  WHERE prev_at IS NOT NULL AND at > prev_at
)
SELECT
  AVG(CASE WHEN rate >= 3.0 THEN rate END) AS avg_ascent,
  AVG(CASE WHEN rate <= -3.0 THEN -rate END) AS avg_descent
FROM rates
''';
const _legacyTimeAtDepthSql = '''
WITH samples AS (
  SELECT
    p.dive_id AS dive_id,
    p.computer_id AS computer_id,
    p.id AS sample_id,
    p.timestamp AS at,
    p.depth AS depth
  FROM dive_profiles p
  JOIN dives d ON d.id = p.dive_id
  WHERE p.is_primary = 1
),
cadence AS (
  SELECT
    dive_id,
    computer_id,
    (MAX(at) - MIN(at)) * 4 / (COUNT(*) - 1.0)
      AS max_interval
  FROM samples
  GROUP BY dive_id, computer_id
  HAVING COUNT(*) > 1
),
intervals AS (
  SELECT
    dive_id,
    computer_id,
    depth,
    LEAD(at) OVER w - at AS seconds
  FROM samples
  WINDOW w AS (
    PARTITION BY dive_id, computer_id ORDER BY at, sample_id
  )
)
SELECT
  CASE
    WHEN i.depth < 10 THEN 0
    WHEN i.depth < 20 THEN 10
    WHEN i.depth < 30 THEN 20
    WHEN i.depth < 40 THEN 30
    ELSE 40
  END AS bucket_lo,
  SUM(MIN(i.seconds * 1.0, c.max_interval)) AS seconds
FROM intervals i
JOIN cadence c
  ON c.dive_id = i.dive_id AND c.computer_id IS i.computer_id
WHERE i.seconds > 0
GROUP BY bucket_lo
ORDER BY bucket_lo
''';
