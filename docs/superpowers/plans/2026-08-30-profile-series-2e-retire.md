# Profile Series Plan 2e: Retire the Legacy Tables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The row-per-sample tables are gone: a v183 rung drops `dive_profiles` / `tank_pressure_profiles` and purges their sync bookkeeping, the upgrade path VACUUMs once, every legacy fallback, delete, re-insert, snapshot list, watcher entry, index heal and `TankPressurePoint.id` is deleted, the receive-side shim for older peers stages inbound legacy rows in temp tables instead, the forty-five legacy-touching test files are ported, and a synthesized 1,000-dive fixture backs the benchmark gates the spec requires, so that PR 2 can open.

**Architecture:** Plans 2a to 2d (done) built the series tables, the series-first reads with a legacy fallback, the series writers, the SQL consumers and the sync registration, and left the legacy tables in place as a safety net. This plan removes the net in a fixed order: capture the legacy benchmark baseline while the legacy read path still exists (Task 1), add the rung that drops the tables and the VACUUM that reclaims the pages (Task 2), move the inbound shim off the legacy tables and onto temp staging tables so older peers' payloads still pack (Task 3), then delete the fallbacks and legacy statements in three slices (Tasks 4 to 6), port the tests (Task 7), verify with the benchmark gates (Task 8), and stop at the PR gate (Task 9). One deviation from spec section 8: the drop is its own rung (183) rather than part of the pack rung, because v182 already exists on this branch and every developer database that ran it must still get the drop.

**Tech Stack:** Flutter, Drift 2.34.3 (with `build_runner` for the regenerated `database.g.dart`), SQLite via `package:sqlite3`; `flutter test` (`performance` tag for the gates); `dart format`; `flutter analyze`.

**Spec:** `docs/superpowers/specs/2026-08-28-profile-sample-storage-design.md` (sections 4 "Schema", 7 "Sync", 8 "Migration and one-time compaction", 10 "Testing and benchmark gates", 11 "Delivery", 12 "Risks"). The 2b/2c/2d hand-off notes (session scratchpad `2b-handoff-checklist.md`) are folded into the constraints and the task file lists.

## Global Constraints

- Schema version rises from 182 to 183 (`currentSchemaVersion`, `migrationVersions`); origin/main is at 180 and PR #1390 holds 181, so 182 and 183 are this branch's; re-check against `origin/main` and every open PR head immediately before the PR opens (sweep with `git fetch origin` and `git show "origin/${h}:lib/core/database/database.dart"` per branch; the zsh `$h:...` modifier trap is documented in memory). `minimumCompatibleSchemaVersion` becomes 183 (the final review wave raised it from 182): no released build was ever stamped 182, since main is at 180, the 181 rung is an open PR, and 182 and 183 ship together, so 183 holds nothing in the fleet that 182 did not already hold. What it records is that v183, not v182, is the rung that purges the `diveProfiles` / `tankPressureProfiles` `deletion_log` rows, which were also the inbound resurrection guard for those entity types, so a reader below 183 must not be one this build expects to apply its payloads.
- Order matters: Task 1 (baseline) runs before any deletion; Task 2 (drop) before Task 3 (staging shim) leaves a window where the shim writes into dropped tables, so Tasks 2 and 3 are one commit each but Task 3's tests are the gate for both (the inbound tests must pass with the tables gone).
- `packLegacyProfileRows` and its migration-ladder call (the v182 rung) SURVIVE: an upgrade from a pre-182 database runs the v182 rung (pack) before the v183 rung (drop). The `beforeOpen` backstop's pack call also survives (it no-ops when the tables are gone: `_columnNames` of a missing table is empty). The packer gains table-name parameters so the same code packs the staging tables.
- The receive-side tolerance (spec section 7) stays until every peer that can publish is at 182 or above: `SyncData.diveProfiles` / `tankPressureProfiles` (inbound-only fields), the `mergeOrder` legacy entries, `SyncService.inboundOnlyLegacyEntities`, `_baseApplyEntityFlags` and the pack hooks all stay. What changes is where the rows land: temp staging tables, packed and emptied immediately.
- After this plan, `grep -rn "dive_profiles\|tank_pressure_profiles" lib` matches only: the migration rungs below 183 in `database.dart` (history), the packer's parameter defaults, the staging DDL, and doc comments that describe history. `DiveProfile`, `DiveProfilesCompanion`, `TankPressureProfile`, `TankPressureProfilesCompanion` no longer exist.
- Benchmarks (spec section 10): on the synthesized 1,000-dive fixture, per-dive detail hydrate, `getBatchProfileSummaries` for 50 dives, both statistics aggregations, migration wall time, post-VACUUM file size and VACUUM time; gate "nothing slower than today", numbers reported in the PR description. "Today" is the legacy SQL shape measured on the pre-migration fixture by the same test run.
- No em-dashes (U+2014) or en-dashes used as punctuation anywhere (code, comments, tests, commit messages, the PR body). No emojis. Immutability: never mutate a list handed in.
- TDD per task; `dart format .` from the worktree root; `flutter analyze` zero issues (infos included); tests run per file with `flutter test <path>`, never piped; stage explicit paths; one local commit per task with the message given; no push and no PR until Task 9's gate is explicitly authorized by the user; no `Co-Authored-By` trailer; never `git stash`.
- Worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-sample-storage-2`, branch `worktree-profile-sample-storage-2`, absolute paths only. `build_runner` output (`database.g.dart`) is committed in this repository (check `git ls-files lib/core/database/database.g.dart`; if tracked, commit the regenerated file with Task 2; if ignored, do not).
- Known machine flakes: `local_file_resolver_test.dart` (mounted `$TMPDIR`, passes with `TMPDIR=/private/tmp/claude-501/sysvol-tmp`), `changeset_writer_test.dart`, `backup_encryption_service_test.dart`, `database_security_service_test.dart`.

## File structure

| File | Responsibility after this plan |
|---|---|
| `tools/synth_fixture.dart` (new) | copies a plaintext Submersion database and replicates every dive (with its child rows) N times under fresh ids; prints row counts |
| `test/performance/profile_series_benchmark_test.dart` (new, `performance` tag) | the spec's six numbers on the synthesized fixture: legacy SQL shapes on the pre-migration copy, series path on the migrated copy, migration and VACUUM timings, file sizes; asserts the gate and prints the table for the PR |
| `lib/core/database/database.dart` | `currentSchemaVersion = 183`; the v183 rung (`_dropLegacySampleTables`, bookkeeping purge); `DiveProfiles` / `TankPressureProfiles` table classes removed from the schema; the backstop comment updated |
| `lib/core/database/database.g.dart` | regenerated |
| `lib/core/services/database_service.dart` | `_runUpgradeLadder` reads the stored version before the ladder and VACUUMs once when it was below 183 |
| `lib/core/database/performance_indexes.dart` | the two legacy index heals removed |
| `lib/core/database/profile_series_pack.dart` | `packLegacyProfileRows(db, {nowMs, profileTable, tankTable})` |
| `lib/core/database/legacy_sample_staging.dart` (new) | temp staging DDL from the codec field table, JSON-row staging, `packStagedLegacyRows` |
| `lib/core/services/sync/sync_data_serializer.dart` | legacy `upsertRecord` / `upsertRecords` cases stage rows; legacy `fetchRecord`, `fetchRecords`, `recordIdsFor`, `_syncTableFor`, `deleteRecord` cases removed; `packLegacySamples` packs the staging tables |
| `lib/core/services/sync/sync_service.dart` | `parentRefs` legacy entries removed; the adopt clear loop skips inbound-only entities |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, `tank_pressure_repository.dart`, `dive_computer_repository_impl.dart`, `lib/features/divers/data/repositories/diver_repository.dart` | fallbacks, legacy deletes, legacy UPDATEs and legacy watcher entries gone; `_minProfileTemp` over series points |
| `lib/features/dive_log/data/services/dive_split_service.dart`, `dive_merge_service.dart`, `dive_consolidation_service.dart`, `dive_merge_snapshot.dart`, `lib/features/dive_computer/data/services/reparse_service.dart` | legacy deletes, undo `deleteWhere`s and verbatim re-inserts, snapshot legacy lists gone |
| `lib/features/dive_log/domain/entities/dive.dart`, `lib/features/dive_log/domain/services/profile_series_merge.dart`, `lib/features/dive_log/domain/services/estimated_tank_pressure_synthesizer.dart` | `TankPressurePoint.id` removed |
| `lib/features/statistics/data/repositories/statistics_repository.dart` | legacy watcher entries gone |
| 45 test files | ported (see Task 7's table) |

---

### Task 1: Synthesized fixture and the legacy benchmark baseline

**Files:**
- Create: `tools/synth_fixture.dart`
- Create: `test/performance/profile_series_benchmark_test.dart`
- Create: `test/performance/README.md` (how to build the fixture and run the gate; five lines)

**Interfaces:**
- Consumes: `package:sqlite3` (raw), `AppDatabase(NativeDatabase(file))` (runs the ladder on first `SELECT 1`), `DiveRepository().getDiveById`, `getBatchProfileSummaries(ids, 200)`, `StatisticsRepository().getAscentDescentRates()`, `getTimeAtDepthRanges()`, `DatabaseService.getStoredSchemaVersion(path)`, the legacy SQL shapes reproduced verbatim from git history (`git show 30234a3973e:lib/features/statistics/data/repositories/statistics_repository.dart` for the two aggregation CTEs; `git show 879a9cf1624:lib/features/dive_log/data/repositories/dive_repository_impl.dart` for the per-dive profile select and the batch summary query).
- Produces: `dart run tools/synth_fixture.dart <source.db> <out.db> --replicas 25` (40 dives x 25 = 1,000); the benchmark test reads `SUBMERSION_BENCH_FIXTURE` (a path to a pre-migration fixture at schema 180 or later, never a live database) and skips with a message when unset.

- [ ] **Step 1: The fixture tool**

`tools/synth_fixture.dart` (top-level script, `package:sqlite3` only; no Flutter):

```dart
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// Replicates every dive of a plaintext Submersion database N times under
/// fresh ids so a small development library becomes a large benchmark
/// fixture. Usage:
///
///     dart run tools/synth_fixture.dart <source.db> <out.db> --replicas 25
///
/// Never points at a live database: it copies the source file first. Child
/// rows are found by column name: every table with a `dive_id` column is
/// replicated; `id` (when text) gets a `-r<k>` suffix, `dive_id`, `tank_id`
/// and `source_id` are remapped to the replica's ids, `computer_id`,
/// `site_id` and every other column are copied as they are. Media rows are
/// skipped (blob stores are not part of the profile benchmark).
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tools/synth_fixture.dart <source.db> <out.db> [--replicas N]');
    exit(64);
  }
  final source = args[0];
  final out = args[1];
  final replicas = args.contains('--replicas') ? int.parse(args[args.indexOf('--replicas') + 1]) : 25;
  if (!File(source).existsSync()) {
    stderr.writeln('No such file: $source');
    exit(66);
  }
  File(source).copySync(out);
  final db = sqlite3.open(out);
  try {
    db.execute('PRAGMA foreign_keys = OFF');
    final tables = _tablesWithDiveId(db)..remove('media');
    final diveIds = db.select('SELECT id FROM dives').map((r) => r['id'] as String).toList();
    db.execute('BEGIN');
    for (var k = 1; k <= replicas; k++) {
      final suffix = '-r$k';
      for (final table in ['dives', ...tables.where((t) => t != 'dives')]) {
        _replicate(db, table, suffix, diveIds);
      }
    }
    db.execute('COMMIT');
    for (final table in ['dives', ...tables]) {
      final n = db.select('SELECT COUNT(*) AS n FROM $table').first['n'];
      stdout.writeln('$table: $n');
    }
  } finally {
    db.close();
  }
}

Set<String> _tablesWithDiveId(Database db) {
  final out = <String>{};
  for (final row in db.select("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'")) {
    final name = row['name'] as String;
    final cols = db.select('SELECT name FROM pragma_table_info(?)', [name]).map((c) => c['name'] as String);
    if (cols.contains('dive_id')) out.add(name);
  }
  return out;
}

void _replicate(Database db, String table, String suffix, List<String> diveIds) {
  final cols = db.select('SELECT name, pk FROM pragma_table_info(?)', [table]).map((c) => (name: c['name'] as String, pk: (c['pk'] as int) > 0)).toList();
  final names = cols.map((c) => c.name).toList();
  final where = table == 'dives' ? 'WHERE id IN (${List.filled(diveIds.length, '?').join(',')})' : 'WHERE dive_id IN (${List.filled(diveIds.length, '?').join(',')})';
  final rows = db.select('SELECT ${names.join(', ')} FROM $table $where', diveIds);
  final insert = db.prepare('INSERT OR IGNORE INTO $table (${names.join(', ')}) VALUES (${List.filled(names.length, '?').join(', ')})');
  try {
    for (final row in rows) {
      final values = <Object?>[];
      for (final c in cols) {
        final v = row[c.name];
        if (v is String && (c.name == 'id' || c.name == 'dive_id' || c.name == 'tank_id' || c.name == 'source_id')) {
          values.add('$v$suffix');
        } else {
          values.add(v);
        }
      }
      insert.execute(values);
    }
  } finally {
    insert.dispose();
  }
}
```

`_replicate` remaps `id`, `dive_id`, `tank_id`, `source_id` by suffix; because every replicated table's referenced ids (tanks, sources) are themselves replicated with the same suffix, the remap is consistent. Composite-key junction tables without an `id` column get their `dive_id` remapped and their other key copied, which is correct (the other key is a shared parent: equipment, tag, buddy, species). Run it once on a copy of the development database (`/Users/ericgriffin/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db`, plaintext, 40 dives, schema 180) into the session scratchpad (`/private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/5b0068b6-136c-4277-89c4-30a25ed89d1c/scratchpad/bench-1000.db`) and record the printed counts in the report: `dives: 1040` (40 originals plus 1,000 replicas), `dive_profiles` about 26x the original count.

- [ ] **Step 2: The benchmark test (fails until the fixture path is set; skips without it)**

`test/performance/profile_series_benchmark_test.dart`:

```dart
@Tags(['performance'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

/// Spec section 10 gates on the synthesized 1,000-dive fixture. Legacy
/// numbers come from the legacy SQL shapes run raw against the
/// pre-migration copy; series numbers from the app's own methods on the
/// migrated copy. Set SUBMERSION_BENCH_FIXTURE to the fixture path
/// (see test/performance/README.md); the test skips without it.
void main() {
  final fixture = Platform.environment['SUBMERSION_BENCH_FIXTURE'];

  test('profile series benchmarks: nothing slower than the legacy shapes', () async {
    if (fixture == null) {
      markTestSkipped('SUBMERSION_BENCH_FIXTURE not set');
      return;
    }
    final work = Directory.systemTemp.createTempSync('series-bench');
    final legacyCopy = File('${work.path}/legacy.db')..writeAsBytesSync(File(fixture).readAsBytesSync());
    final migratedCopy = File('${work.path}/migrated.db')..writeAsBytesSync(File(fixture).readAsBytesSync());
    final results = <String, ({Duration legacy, Duration series})>{};

    // Legacy shapes, raw SQL, pre-migration copy.
    final raw = sqlite.sqlite3.open(legacyCopy.path);
    final diveIds = raw.select('SELECT id FROM dives ORDER BY dive_date_time DESC LIMIT 50').map((r) => r['id'] as String).toList();
    final legacyHydrate = _time(() {
      for (final id in diveIds) {
        raw.select('SELECT * FROM dive_profiles WHERE dive_id = ? AND is_primary = 1 ORDER BY timestamp', [id]);
        raw.select('SELECT * FROM tank_pressure_profiles WHERE dive_id = ? ORDER BY timestamp', [id]);
      }
    });
    final legacySummaries = _time(() {
      raw.select(_legacyBatchSummarySql(diveIds.length), diveIds);
    });
    final legacyAscent = _time(() => raw.select(_legacyAscentDescentSql));
    final legacyBuckets = _time(() => raw.select(_legacyTimeAtDepthSql));
    final sizeBefore = legacyCopy.lengthSync();
    raw.close();

    // Migration (the ladder from the fixture's version to 183) plus VACUUM.
    final storedBefore = DatabaseService.getStoredSchemaVersion(migratedCopy.path)!;
    final migration = Stopwatch()..start();
    final migrator = AppDatabase(NativeDatabase(migratedCopy.file));
    await migrator.customSelect('SELECT 1').get();
    migration.stop();
    final vacuum = Stopwatch()..start();
    await migrator.customStatement('VACUUM');
    vacuum.stop();
    await migrator.close();
    final sizeAfter = migratedCopy.lengthSync();

    // Series path through the app, migrated copy.
    final db = AppDatabase(NativeDatabase(migratedCopy.file));
    DatabaseService.instance.setTestDatabase(db);
    final dives = DiveRepository();
    final stats = StatisticsRepository();
    final seriesHydrate = await _timeAsync(() async {
      for (final id in diveIds) {
        await dives.getDiveById(id);
      }
    });
    final seriesSummaries = await _timeAsync(() => dives.getBatchProfileSummaries(diveIds, 200));
    final seriesAscent = await _timeAsync(() => stats.getAscentDescentRates());
    final seriesBuckets = await _timeAsync(() => stats.getTimeAtDepthRanges());
    await db.close();
    DatabaseService.instance.resetForTesting();

    results['per-dive hydrate (50 dives)'] = (legacy: legacyHydrate, series: seriesHydrate);
    results['batch summaries (50 dives)'] = (legacy: legacySummaries, series: seriesSummaries);
    results['ascent/descent rates'] = (legacy: legacyAscent, series: seriesAscent);
    results['time at depth'] = (legacy: legacyBuckets, series: seriesBuckets);

    final table = StringBuffer()
      ..writeln('| metric | legacy | series |')
      ..writeln('|---|---|---|');
    for (final e in results.entries) {
      table.writeln('| ${e.key} | ${e.value.legacy.inMilliseconds} ms | ${e.value.series.inMilliseconds} ms |');
    }
    table
      ..writeln('| migration $storedBefore -> ${AppDatabase.currentSchemaVersion} | | ${migration.elapsed.inMilliseconds} ms |')
      ..writeln('| VACUUM | | ${vacuum.elapsed.inMilliseconds} ms |')
      ..writeln('| file size | ${sizeBefore ~/ 1024} KB | ${sizeAfter ~/ 1024} KB |');
    // ignore: avoid_print
    print(table);

    for (final e in results.entries) {
      expect(
        e.value.series.inMicroseconds,
        lessThanOrEqualTo((e.value.legacy.inMicroseconds * 1.25).round()),
        reason: '${e.key}: series ${e.value.series} vs legacy ${e.value.legacy} (25% tolerance for timer noise)',
      );
    }
    expect(sizeAfter, lessThan(sizeBefore ~/ 2), reason: 'the drop plus VACUUM must return most of the file');
    expect(storedBefore, lessThan(183));
    expect(DatabaseService.getStoredSchemaVersion(migratedCopy.path), AppDatabase.currentSchemaVersion);
  });
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
    'SELECT dive_id, timestamp, depth FROM dive_profiles WHERE is_primary = 1 AND dive_id IN (${List.filled(n, '?').join(',')}) ORDER BY dive_id, timestamp';

// The two aggregation queries as they stood before plan 2d, unfiltered scope
// (diver filter and dive filter clauses empty). Copy them verbatim from
// `git show 30234a3973e:lib/features/statistics/data/repositories/statistics_repository.dart`
// (getAscentDescentRates at about line 2200, getTimeAtDepthRanges at about
// line 2297), substituting 15, 3.0 and 4 for the constants.
const _legacyAscentDescentSql = '''
...
''';
const _legacyTimeAtDepthSql = '''
...
''';
```

Fill the two `const` strings with the verbatim legacy SQL (the plan does not repeat 60 lines of SQL; the commit named above is the source, and the implementer pastes them). `getBatchProfileSummaries` signature: check the second parameter's name and meaning in `dive_repository_impl.dart` (it is `maxSamples`). `NativeDatabase(File)` takes a `File`; `migratedCopy` is one. If `AppDatabase` needs the `NativeDatabase` opened with the app's `setup:` callback for pragmas, use `DatabaseService`'s public helpers instead of constructing the connection by hand; read `database_service.dart` lines 30-60 for `_connectionSetup` and whether a public equivalent exists (if not, `NativeDatabase(file)` is acceptable for a benchmark).

The gate deliberately runs BEFORE any deletion: on this commit the migrated copy's ladder stops at 182 (Task 2 adds 183), so the size assertion and the `storedBefore < 183` expectation are written now and go green in Task 8. Mark the two of them with a comment "green after Task 2" and run the test once to record the legacy versus series timings in the report (they are the baseline the PR cites).

- [ ] **Step 3: Run**

```bash
dart run tools/synth_fixture.dart <copy of the dev db> /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/5b0068b6-136c-4277-89c4-30a25ed89d1c/scratchpad/bench-1000.db --replicas 25
SUBMERSION_BENCH_FIXTURE=<that path> flutter test --run-skipped --tags performance test/performance/profile_series_benchmark_test.dart
```

Expected: the tool prints counts; the test prints the table; the timing assertions pass (or, if a series metric is slower than legacy by more than 25%, STOP and report the numbers: that is the gate the spec set, and the fix belongs to whoever owns the slow read, not to this plan's deletions); the two "green after Task 2" assertions fail for now.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add tools/synth_fixture.dart test/performance/profile_series_benchmark_test.dart test/performance/README.md
git commit -m "test(perf): synthesized 1,000-dive fixture tool and the profile series benchmark gate"
```

---

### Task 2: The v183 rung (drop and purge) and the one-time VACUUM

**Files:**
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion`, `migrationVersions`, the rung after v182, the `@DriftDatabase(tables: [...])` list, delete the `DiveProfiles` and `TankPressureProfiles` table classes near lines 849 and 2802, the v182 backstop comment)
- Regenerate: `lib/core/database/database.g.dart` (`dart run build_runner build --delete-conflicting-outputs`)
- Modify: `lib/core/database/performance_indexes.dart` (delete the `idx_dive_profiles_dive_id` and `idx_tank_pressure_dive_tank` entries near lines 85-95)
- Modify: `lib/core/services/database_service.dart` (`_runUpgradeLadder` near line 309)
- Modify: `test/core/database/query_plan_test.dart` (delete the two legacy-table plan tests near lines 30-45), `test/core/database/performance_indexes_test.dart` (the dropped-index heal test near line 40 uses `idx_dive_profile_series_dive_primary` instead)
- Test: `test/core/database/migration_v183_drop_legacy_tables_test.dart` (new)
- Test: `test/core/services/database_service_vacuum_test.dart` (new)

**Interfaces:**
- Consumes: `legacyDdlAt180(raw, {userVersion})` and `seedParents` / `seedProfiles` / `seedPressures` from `test/helpers/legacy_profile_fixtures.dart` (plan 2a) to build a pre-183 fixture; `DatabaseService.getStoredSchemaVersion(path, {keyHex})`; the packer (v182 rung) unchanged.
- Produces: `AppDatabase.currentSchemaVersion == 183`; a private `Future<void> _dropLegacySampleTables()` on `AppDatabase`; `_runUpgradeLadder` VACUUMs when the pre-ladder `user_version` was below 183. After this task nothing in `lib/` can name `_db.diveProfiles` or `_db.tankPressureProfiles` and compile; Tasks 3 to 6 remove every such reference and this task's `flutter analyze` step is where they are enumerated, so Task 2's commit includes the MECHANICAL removals needed to compile (each listed in Step 3) and leaves the behavioral deletions to their tasks.

- [ ] **Step 1: Write the failing tests**

`test/core/database/migration_v183_drop_legacy_tables_test.dart` (model: `test/core/database/migration_v182_profile_series_test.dart`, which opens `AppDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false))` over a `sqlite3.openInMemory()` handle stamped with `PRAGMA user_version`):

```dart
  test('the v183 rung drops the legacy tables and purges their bookkeeping', () async {
    final raw = sqlite3.openInMemory();
    legacyDdlAt180(raw, userVersion: 182);
    seedParents(raw);
    seedProfiles(raw); // legacy rows the v182 rung would have packed already
    raw.execute("CREATE TABLE IF NOT EXISTS sync_records (id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, record_id TEXT NOT NULL, local_updated_at INTEGER, synced_at INTEGER, sync_status TEXT, conflict_data TEXT, created_at INTEGER, updated_at INTEGER)");
    raw.execute("CREATE TABLE IF NOT EXISTS deletion_log (id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, record_id TEXT NOT NULL, deleted_at INTEGER NOT NULL, hlc TEXT, peer_device_id TEXT, provider TEXT, base_seq_applied INTEGER, last_seq_applied INTEGER)");
    raw.execute("INSERT INTO sync_records (id, entity_type, record_id) VALUES ('s1', 'diveProfiles', 'p1'), ('s2', 'tankPressureProfiles', 't1'), ('s3', 'dives', 'd1')");
    raw.execute("INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) VALUES ('l1', 'diveProfiles', 'p9', 1), ('l2', 'dives', 'd9', 1)");
    // A series row must survive the drop: pack first the way v182 did.
    final db = AppDatabase(NativeDatabase.opened(raw, closeUnderlyingOnClose: false));
    await db.customSelect('SELECT 1').get();
    expect(raw.select("SELECT name FROM sqlite_master WHERE name IN ('dive_profiles', 'tank_pressure_profiles')"), isEmpty);
    expect(raw.select("SELECT name FROM sqlite_master WHERE type = 'index' AND name IN ('idx_dive_profiles_dive_id', 'idx_tank_pressure_dive_tank')"), isEmpty);
    expect(raw.select("SELECT entity_type FROM sync_records").map((r) => r['entity_type']), ['dives']);
    expect(raw.select("SELECT entity_type FROM deletion_log").map((r) => r['entity_type']), ['dives']);
    expect(raw.select('SELECT COUNT(*) AS n FROM dive_profile_series').first['n'], greaterThan(0));
    expect(raw.select('PRAGMA user_version').first.values.first, 183);
    await db.close();
  });

  test('re-running the ladder at 183 is a no-op', () async {
    // open a 183 database (the previous test's end state rebuilt), open again, no throw, counts unchanged
  });

  test('a database that skipped the v182 rung still packs before the drop', () async {
    // legacyDdlAt180(raw, userVersion: 181) with seedProfiles: after the
    // ladder the series exist, the legacy tables are gone, and the packed
    // sample counts equal the seeded rows minus exact duplicates.
  });
```

(If the fixture helper's `sync_records` / `deletion_log` DDL differs from the real schema, copy the real CREATE TABLE text from `database.g.dart` for those two tables; the rung's `DELETE` needs only `entity_type`.) Write the three bodies in full.

`test/core/services/database_service_vacuum_test.dart`: find the existing test that opens a file through `DatabaseService` with a pending migration (`grep -rln "migrationThenBackground\|_runUpgradeLadder\|openDatabaseFile\|lastOpenMode" test/core/services`) and copy its fixture: write a plaintext database file at `user_version` 182 containing a big `dive_profiles` table (insert 20,000 rows through the raw handle) plus the series tables; open it through the service; assert `lastOpenMode == DatabaseOpenMode.migrationThenBackground`, the stored version is 183, and `PRAGMA freelist_count` on the file (raw, after the service closes it or on a fresh raw handle) is 0, which only VACUUM achieves after a drop. A second test opens a file already at 183 and asserts no VACUUM happened (seed a freelist by deleting rows from a scratch table before opening; `freelist_count` stays greater than 0).

- [ ] **Step 2: Run the tests to verify they fail**

Expected: the rung does not exist (tables still present, version 182); the VACUUM test finds `freelist_count > 0`.

- [ ] **Step 3: Implement**

`database.dart`:
- `static const int currentSchemaVersion = 183;` and `183,` appended to `migrationVersions`.
- After the v182 block in `onUpgrade`:

```dart
        // v183: the legacy row-per-sample tables are gone. The v182 rung
        // above packed every row into series (and the beforeOpen backstop
        // re-packs any dive that missed it), so nothing reads these tables
        // any more. Their sync bookkeeping goes with them: pending records
        // and tombstones for entity types no peer exports. Idempotent
        // (IF EXISTS / DELETE), so a retried ladder is safe. The pages come
        // back at the one VACUUM in DatabaseService._runUpgradeLadder.
        if (from < 183) {
          await _dropLegacySampleTables();
        }
        if (from < 183) await reportProgress();
```

with

```dart
  Future<void> _dropLegacySampleTables() async {
    await customStatement('DROP INDEX IF EXISTS idx_dive_profiles_dive_id');
    await customStatement('DROP INDEX IF EXISTS idx_tank_pressure_dive_tank');
    await customStatement('DROP TABLE IF EXISTS dive_profiles');
    await customStatement('DROP TABLE IF EXISTS tank_pressure_profiles');
    await customStatement(
      "DELETE FROM sync_records WHERE entity_type IN ('diveProfiles', 'tankPressureProfiles')",
    );
    await customStatement(
      "DELETE FROM deletion_log WHERE entity_type IN ('diveProfiles', 'tankPressureProfiles')",
    );
  }
```

- Remove `DiveProfiles` and `TankPressureProfiles` from the `@DriftDatabase(tables: [...])` list and delete the two table classes. Update the v182 backstop comment's last sentence ("The legacy tables stay until plan 2e retires them" becomes "v183 drops the legacy tables; the packer no-ops once they are gone").
- Regenerate `database.g.dart`.

`database_service.dart` `_runUpgradeLadder`:

```dart
  Future<void> _runUpgradeLadder(
    File file,
    String? keyHex,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  ) async {
    // Read before the ladder: the one-time VACUUM below keys off the version
    // the file had on disk, not the version the ladder leaves behind.
    final storedBefore = getStoredSchemaVersion(file.path, keyHex: keyHex);
    final migrator = AppDatabase(
      NativeDatabase(file, setup: _connectionSetup(keyHex)),
      onMigrationProgress: onMigrationProgress,
    );
    try {
      await migrator.customSelect('SELECT 1').get();
      if (storedBefore != null && storedBefore < 183) {
        // v183 dropped the row-per-sample tables (about 90% of the pages of
        // an older file). VACUUM here: outside any migration transaction,
        // on the one exclusive main-isolate connection, before the
        // background executor opens the file. Non-fatal: a busy lock leaves
        // a correct but large file.
        try {
          await migrator.customStatement('VACUUM');
        } catch (e, stackTrace) {
          _log.warning('Post-migration VACUUM skipped', error: e, stackTrace: stackTrace);
        }
      }
    } catch (_) {
      await migrator.close().timeout(const Duration(seconds: 5), onTimeout: () {}).catchError((_) {});
      rethrow;
    }
    await migrator.close().timeout(const Duration(seconds: 5));
  }
```

(use the file's real logger; if `_log` does not exist, `developer.log` as `database.dart` does.)

`performance_indexes.dart`: delete the two legacy entries. `query_plan_test.dart`: delete the two legacy-table tests. `performance_indexes_test.dart`: the heal test drops and re-heals `idx_dive_profile_series_dive_primary`.

Mechanical compile fixes this task MUST include (everything that names the deleted Drift classes; the behavioral cleanup of each site is Tasks 4 to 6, so here only remove the reference in the smallest way that keeps the file's current behavior for series and stops it for legacy): run `flutter analyze` after the regeneration and fix every error it lists. Expected error sites (from `grep -rn "_db.diveProfiles\|_db.tankPressureProfiles\|db.diveProfiles\|db.tankPressureProfiles\|DiveProfile\b\|TankPressureProfile\b\|DiveProfilesCompanion\|TankPressureProfilesCompanion" lib`): `dive_repository_impl.dart` (the fallback bodies, `_mapRowToDive`'s legacy branches, `_dropSupersededOriginals`, `_dropDuplicateSamples`, `_profilePointFromRow`, `_minProfileTemp`, `restoreOriginalProfile`'s legacy delete, the watchers), `tank_pressure_repository.dart` (three fallbacks, one legacy delete), `dive_computer_repository_impl.dart` (two fallbacks, two legacy deletes in `clearSourceAndProfiles`, the two `UPDATE dive_profiles` raw statements do not name the class but the table is gone, so they go too), `diver_repository.dart` (raw UPDATE), `dive_split_service.dart` (the two restored legacy deletes), `dive_merge_snapshot.dart` (the two legacy lists), `dive_merge_service.dart` and `dive_consolidation_service.dart` (undo `deleteWhere`s and re-inserts, snapshot id sets), `reparse_service.dart` (two legacy deletes), `sync_data_serializer.dart` (every legacy case), `statistics_repository.dart` (watcher entries). For THIS task delete exactly those references (Tasks 4 to 6 then do the semantic cleanup: removing the `if (series.isEmpty)` gates, the `_...Legacy` method shells, `TankPressurePoint.id`, comments) and delete the tests that only exercised the deleted references if they cannot compile (list each in the report; Task 7 owns the ports).

The compile-fix scope is deliberately mechanical because `database.g.dart` regeneration makes the branch uncompilable until every reference is gone; a reviewer checks that no series behavior changed in this commit.

- [ ] **Step 4: Run the tests**

Run the two new files, `migration_v182_profile_series_test.dart`, `profile_series_pack_test.dart`, `backstop_resilience_test.dart`, `query_plan_test.dart`, `performance_indexes_test.dart`, `database_import_graph_test.dart`, then `flutter analyze` (zero issues) and, because the compile fixes touch many files, the whole `test/features/dive_log/data/repositories/` and `test/core/services/sync/` directories (per file, or one `flutter test <dir>` run per directory, unpiped). Files that fail ONLY because their fixture seeds the dropped tables are listed for Task 7 in the report; anything else is a regression to fix here.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart lib/core/database/performance_indexes.dart lib/core/services/database_service.dart test/core/database/migration_v183_drop_legacy_tables_test.dart test/core/services/database_service_vacuum_test.dart test/core/database/query_plan_test.dart test/core/database/performance_indexes_test.dart <every compile-fix file by path> <database.g.dart if tracked>
git commit -m "feat(db): v183 drops the legacy sample tables, purges their bookkeeping, VACUUMs once on upgrade"
```

---

### Task 3: The inbound shim stages legacy rows in temp tables

**Files:**
- Create: `lib/core/database/legacy_sample_staging.dart`
- Modify: `lib/core/database/profile_series_pack.dart` (`profileTable` / `tankTable` parameters; five hardcoded table names near lines 67, 73, 83, 90, 126, 210)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (legacy `upsertRecord` / `upsertRecords` cases; `packLegacySamples`; the legacy `fetchRecord`, `fetchRecords`, `recordIdsFor`, `_syncTableFor`, `deleteRecord` cases are gone since Task 2)
- Modify: `lib/core/services/sync/sync_service.dart` (`parentRefs` legacy entries removed; the adopt clear loop skips `inboundOnlyLegacyEntities`)
- Test: `test/core/database/legacy_sample_staging_test.dart` (new)
- Verify (all six scenarios must pass with the tables gone): `test/core/services/sync/legacy_sample_entities_inbound_test.dart`, `cross_version_roundtrip_test.dart`, `profile_series_sync_test.dart`, `base_publish_streaming_parity_test.dart`, `sync_base_streaming_parity_test.dart`, the adopt tests.

**Interfaces:**
- Consumes: `kProfileFieldTableV1` (`lib/features/dive_log/domain/codecs/profile_field_table.dart`: `ProfileField(name, kind)`, kinds `deltaInt` / `float64` / `runLengthString`), `packLegacyProfileRows`, `_columnNames`, `_unpackedDiveIds(db, legacyTable: ...)` (existing packer internals).
- Produces:
  - `const String kLegacyProfileStagingTable = 'dive_profiles_inbound'; const String kLegacyTankStagingTable = 'tank_pressure_profiles_inbound';`
  - `Future<void> ensureLegacyStagingTables(DatabaseConnectionUser db)` (CREATE TEMP TABLE IF NOT EXISTS for both)
  - `Future<int> stageLegacyProfileRows(DatabaseConnectionUser db, List<Map<String, dynamic>> jsonRows)` and `stageLegacyTankRows(...)` (camelCase wire keys to snake_case columns, unknown keys ignored, `INSERT OR REPLACE`, returns the count)
  - `Future<ProfilePackReport> packStagedLegacyRows(DatabaseConnectionUser db)` (packs the staging tables, then empties them)
  - `packLegacyProfileRows(db, {int? nowMs, String profileTable = 'dive_profiles', String tankTable = 'tank_pressure_profiles'})`

- [ ] **Step 1: Write the failing test**

`test/core/database/legacy_sample_staging_test.dart` (an in-memory `AppDatabase` from `setUpTestDatabase()`, FK parents seeded as in `profile_series_repository_writers_test.dart`):

```dart
  test('wire rows land in the staging table with snake_case columns', () async {
    await ensureLegacyStagingTables(db);
    final n = await stageLegacyProfileRows(db, [
      {'id': 'p1', 'diveId': 'dive-1', 'computerId': null, 'sourceId': null, 'isPrimary': true, 'timestamp': 0, 'depth': 0.0, 'ppO2': 1.2, 'o2SensorMv1': 55, 'heartRateSource': 'chest', 'unknownKey': 42},
      {'id': 'p2', 'diveId': 'dive-1', 'isPrimary': true, 'timestamp': 30, 'depth': 12.0},
    ]);
    expect(n, 2);
    final rows = await db.customSelect('SELECT id, dive_id, is_primary, pp_o2, o2_sensor_mv1, heart_rate_source FROM dive_profiles_inbound ORDER BY timestamp').get();
    expect(rows.first.data['pp_o2'], 1.2);
    expect(rows.first.data['o2_sensor_mv1'], 55);
    expect(rows.first.data['heart_rate_source'], 'chest');
    expect(rows.first.data['is_primary'], 1);
  });

  test('packStagedLegacyRows packs into series and empties the staging tables', () async {
    await ensureLegacyStagingTables(db);
    await stageLegacyProfileRows(db, [/* two rows for dive-1 as above */]);
    await stageLegacyTankRows(db, [{'id': 't1', 'diveId': 'dive-1', 'tankId': 'tank-a', 'timestamp': 0, 'pressure': 200.0}]);
    final report = await packStagedLegacyRows(db);
    expect(report.profileSeries, 1);
    expect(report.tankSeries, 1);
    final series = await ProfileSeriesRepository().getSeriesForDive('dive-1');
    expect(series.single.samples.map((s) => s.depth), [0.0, 12.0]);
    expect(series.single.id, profileSeriesMigratedId(/* the identity of the rows */));
    expect((await db.customSelect('SELECT COUNT(*) AS n FROM dive_profiles_inbound').getSingle()).data['n'], 0);
    expect((await db.customSelect('SELECT COUNT(*) AS n FROM tank_pressure_profiles_inbound').getSingle()).data['n'], 0);
  });

  test('a dive that already has a series ignores staged rows, and the staging is still emptied', () async {
    // insert a series for dive-1 first; stage rows for dive-1; pack; the
    // series is unchanged and the staging table is empty.
  });

  test('ensureLegacyStagingTables is idempotent and survives a missing legacy table', () async {
    await ensureLegacyStagingTables(db);
    await ensureLegacyStagingTables(db);
    expect(await packStagedLegacyRows(db), isA<ProfilePackReport>());
  });
```

Write every body in full (`profileSeriesMigratedId`'s named parameters are in `lib/features/dive_log/domain/entities/profile_series_identity.dart`).

- [ ] **Step 2: Run the test to verify it fails**

Expected: compile error, the file does not exist.

- [ ] **Step 3: Implement**

`lib/core/database/legacy_sample_staging.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_field_table.dart';

/// Where an older peer's row-per-sample arrays land now that the legacy
/// tables are gone (v183). TEMP tables live for the connection; the packer
/// reads them like it read `dive_profiles`, and they are emptied after each
/// pack. Retire with the receive-side shim (plan 2d's
/// SyncService.inboundOnlyLegacyEntities) once no peer below 182 can publish.
const String kLegacyProfileStagingTable = 'dive_profiles_inbound';
const String kLegacyTankStagingTable = 'tank_pressure_profiles_inbound';

String _sqlType(ProfileFieldKind kind) => switch (kind) {
  ProfileFieldKind.deltaInt => 'INTEGER',
  ProfileFieldKind.float64 => 'REAL',
  ProfileFieldKind.runLengthString => 'TEXT',
};

/// The legacy `dive_profiles` columns: identity plus every codec field.
final List<String> kLegacyProfileColumns = [
  'id', 'dive_id', 'computer_id', 'source_id', 'is_primary',
  for (final f in kProfileFieldTableV1) f.name,
];

const List<String> kLegacyTankColumns = ['id', 'dive_id', 'tank_id', 'computer_id', 'timestamp', 'pressure'];

String _profileDdl() => 'CREATE TEMP TABLE IF NOT EXISTS $kLegacyProfileStagingTable ('
    'id TEXT NOT NULL PRIMARY KEY, dive_id TEXT NOT NULL, computer_id TEXT, source_id TEXT, '
    'is_primary INTEGER NOT NULL DEFAULT 1, '
    '${[for (final f in kProfileFieldTableV1) '${f.name} ${_sqlType(f.kind)}'].join(', ')})';

const String _tankDdl = 'CREATE TEMP TABLE IF NOT EXISTS $kLegacyTankStagingTable ('
    'id TEXT NOT NULL PRIMARY KEY, dive_id TEXT NOT NULL, tank_id TEXT NOT NULL, '
    'computer_id TEXT, timestamp INTEGER NOT NULL, pressure REAL NOT NULL)';

Future<void> ensureLegacyStagingTables(DatabaseConnectionUser db) async {
  await db.customStatement(_profileDdl());
  await db.customStatement(_tankDdl);
}

/// `diveId` -> `dive_id`, `ppO2` -> `pp_o2`, `o2SensorMv1` -> `o2_sensor_mv1`:
/// Drift's default column naming, which is what the wire keys were made from.
String legacyColumnFor(String wireKey) =>
    wireKey.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

Future<int> stageLegacyProfileRows(DatabaseConnectionUser db, List<Map<String, dynamic>> jsonRows) =>
    _stage(db, kLegacyProfileStagingTable, kLegacyProfileColumns, jsonRows);

Future<int> stageLegacyTankRows(DatabaseConnectionUser db, List<Map<String, dynamic>> jsonRows) =>
    _stage(db, kLegacyTankStagingTable, kLegacyTankColumns, jsonRows);

Future<int> _stage(DatabaseConnectionUser db, String table, List<String> columns, List<Map<String, dynamic>> jsonRows) async {
  var staged = 0;
  for (final row in jsonRows) {
    final values = <String, Object?>{};
    for (final entry in row.entries) {
      final column = legacyColumnFor(entry.key);
      if (!columns.contains(column)) continue;
      final v = entry.value;
      values[column] = v is bool ? (v ? 1 : 0) : v;
    }
    if (values['id'] == null || values['dive_id'] == null) continue;
    final names = values.keys.toList();
    await db.customStatement(
      'INSERT OR REPLACE INTO $table (${names.join(', ')}) VALUES (${List.filled(names.length, '?').join(', ')})',
      [for (final n in names) values[n]],
    );
    staged++;
  }
  return staged;
}

/// Packs whatever is staged into series (dives that already have a series
/// are left alone, exactly as the migration packer does) and empties both
/// staging tables.
Future<ProfilePackReport> packStagedLegacyRows(DatabaseConnectionUser db) async {
  await ensureLegacyStagingTables(db);
  try {
    return await packLegacyProfileRows(
      db,
      profileTable: kLegacyProfileStagingTable,
      tankTable: kLegacyTankStagingTable,
    );
  } finally {
    await db.customStatement('DELETE FROM $kLegacyProfileStagingTable');
    await db.customStatement('DELETE FROM $kLegacyTankStagingTable');
  }
}
```

Check `customStatement`'s argument form on `DatabaseConnectionUser` (positional `List<Object?>` args) and adjust; keep `database.dart`'s import graph Flutter-free (this file imports only drift, the packer and the codec field table; `database_import_graph_test` covers it if `database.dart` imports it, which it does not need to).

`profile_series_pack.dart`: add the two named parameters and use them at every hardcoded site (the `_columnNames` calls, the two `_unpackedDiveIds(... legacyTable: ...)` calls, the two `SELECT * FROM ... WHERE dive_id = ?` reads). The doc comment names the defaults and the staging use.

`sync_data_serializer.dart`:
- `upsertRecord` cases: `case 'diveProfiles': await ensureLegacyStagingTables(_db); await stageLegacyProfileRows(_db, [data]); return;` and the tank twin; `upsertRecords` cases: `ensureLegacyStagingTables(_db)` then `stageLegacy...Rows(_db, records)`.
- `packLegacySamples()` returns `packStagedLegacyRows(_db)`.
- Confirm the legacy `fetchRecord`, `fetchRecords`, `recordIdsFor`, `_syncTableFor`, `deleteRecord` cases are gone (Task 2); a legacy tombstone from an older peer now falls through `deleteRecord`'s switch, which has no default, so it is a no-op: add a comment above the switch saying so. `recordIdsFor`'s default throws, which is right: nothing passes a legacy type any more (its callers iterate `entityHasUpdatedAt` keys).

`sync_service.dart`:
- Remove `parentRefs['diveProfiles']` and `['tankPressureProfiles']` (`_mergeEntity` reads `parentRefs[type] ?? const []`).
- In `_adoptApplyStreaming`, the clear loop over the union: skip keys in `inboundOnlyLegacyEntities` (nothing local to clear; the temp tables are per-connection scratch). Keep the fold-back of `changeset.data.diveProfiles` / `tankPressureProfiles` and the `wantRows` predicates (they feed the staging cases).

- [ ] **Step 4: Run the tests**

Run the new file, then every file in the Verify list plus `test/core/services/sync/` as a directory. The six inbound scenarios must pass with the legacy tables gone.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/legacy_sample_staging.dart lib/core/database/profile_series_pack.dart lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/database/legacy_sample_staging_test.dart <adjusted sync tests by path>
git commit -m "feat(sync): older peers' sample rows stage in temp tables and pack into series"
```

---

### Task 4: Repositories without fallbacks

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`getDiveProfile`, `getMergedProfile`, `getProfilesByDataSource`, `getBatchProfileSummaries`, `_mapRowToDive`, `_mergedSeriesPoints`, `_minProfileTemp`, `restoreOriginalProfile`, the two watchers, `_dropSupersededOriginals`, `_dropDuplicateSamples`, `_profilePointFromRow`)
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_repository.dart` (`getTankPressuresForDive`, `getPressuresForTank`, `hasTankPressures`, `deleteTankPressuresForDive`)
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`getComputerIdsForDive`, `getPrimaryComputerId`, `clearSourceAndProfiles`, `deleteComputer`, the relink block, `importProfile`'s remaining doc lines)
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (the legacy UPDATE near line 375 is gone since Task 2; the series twins stay)
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (`watchStatisticsChanges` legacy entries)
- Test: extend `test/features/dive_log/data/repositories/dive_repository_series_reads_test.dart` (a dive with NO series reads as an empty profile, null merged profile behavior as the method documents, empty tank map) and `tank_pressure_series_reads_test.dart` (no fallback: a dive with no tank series has no pressures).

**Interfaces:**
- Consumes: Task 2 left these files compiling with the legacy references cut out; the `if (series.isEmpty) return _xLegacy(...)` gates may still call now-empty or deleted shells.
- Produces: each read is series-only: `getDiveProfile` returns `mergeSeriesPoints(primary series)` (empty list when none); `_mergedSeriesPoints` returns a non-nullable `List<domain.DiveProfilePoint>`; `getMergedProfile` / `_mapRowToDive` use it directly; `getProfilesByDataSource` is the former `_profilesBySourceFromSeries` body (the empty-series case yields `{}` for a dive with no sources, or one empty entry per source, whichever the former series path did); `getBatchProfileSummaries` is the former series branch with no legacy leg; `_mapRowToDive`'s tank start/end come from tank series only; `_minProfileTemp(List<domain.DiveProfilePoint> points)` is the minimum finite `temperature` over the merged points (the legacy helper's rule over rows); `TankPressureRepository`'s three reads are series-only; `DiveComputerRepository`'s two reads are series-only; every `_...Legacy` method, `_dropSupersededOriginals`, `_dropDuplicateSamples`, `_profilePointFromRow` deleted; the watchers list only the series tables (with `dives`, `diveTanks`, events, etc. as before).

- [ ] **Step 1: Write the failing tests** (the "no series" cases: `getDiveProfile` returns `[]`, `getMergedProfile` returns `[]`, `getDiveById` has an empty profile and tanks with null start/end pressures, `getProfilesByDataSource` returns what the series path returns for a dive with sources but no series, `getTankPressuresForDive` returns `{}`, `hasTankPressures` false, `getComputerIdsForDive` `[]`, `getPrimaryComputerId` null). Most already exist as fallback tests seeded with legacy rows; rewrite those to seed nothing and assert the empty results.
- [ ] **Step 2: Run them** (they fail on the Task 2 shells or on now-unreachable legacy seeds).
- [ ] **Step 3: Delete the gates and shells** as the Interfaces block describes. In `_mapRowToDive`, `_minProfileTemp` takes the merged points. Doc comments: remove every "falls back to the legacy table" sentence; the watcher docs name only the series tables.
- [ ] **Step 4: Run** the two extended files, `dive_repository_test.dart`, `dive_repository_series_writes_test.dart`, `profiles_by_data_source_series_test.dart`, `batch_summaries_series_test.dart`, `dive_computer_series_reads_test.dart`, `dive_computer_repository_impl_test.dart`, `dive_computer_repository_series_writes_test.dart`, `diver_repository_test.dart`, `series_computer_link_test.dart`, `tank_pressure_repository_series_writes_test.dart`, `test/features/statistics/data/repositories/statistics_repository_deco_test.dart`. Legacy-seeded fallback tests that now fail are listed for Task 7 (they are deleted or re-seeded there).
- [ ] **Step 5: Format, analyze, commit**

```bash
git commit -m "refactor(series): repositories read series only; the 2b fallbacks and legacy statements are gone"
```

(stage the five lib files and the two test files by path).

---

### Task 5: Services without legacy rows

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_merge_snapshot.dart` (delete `profileRows`, `tankPressureRows` and their capture; keep `profileSeriesRows`, `tankSeriesRows`)
- Modify: `lib/features/dive_log/data/services/dive_merge_service.dart` (undo: the legacy `deleteWhere`s and verbatim re-inserts; comments)
- Modify: `lib/features/dive_log/data/services/dive_consolidation_service.dart` (undo: `snapshotIds` / `currentChildIds` legacy entries, legacy `deleteWhere`s, verbatim re-inserts; comments)
- Modify: `lib/features/dive_log/data/services/dive_split_service.dart` (the two legacy deletes restored by the 2c fix wave; the comment that explains them)
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (two legacy deletes)
- Modify tests: the six hand-built `DiveMergeSnapshot(...)` constructions drop the two fields (`test/features/dive_log/presentation/widgets/combine_dives_dialog_test.dart`, `dive_list_selection_test.dart`, `merge_dive_dialog_test.dart`, `test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart` (two), `universal_adapter_test.dart`, `test/features/universal_import/presentation/providers/import_consolidation_service_test.dart`); `dive_split_service_test.dart`'s "legacy rows of the moved identities" test (from the 2c fix wave) is deleted (its subject no longer exists).

- [ ] **Step 1: Failing test**: in `dive_merge_service_series_test.dart` and `dive_consolidation_service_series_test.dart` assert the snapshot has no legacy fields (a compile-level change: constructing `DiveMergeSnapshot` without them); run the six snapshot tests to see the compile failures.
- [ ] **Step 2: Delete** the fields, the capture queries, the undo legacy statements and re-inserts, the split and reparse legacy deletes; rewrite the comments that explained the legacy deletes ("a migrated database still holds dive_profiles rows" is no longer true).
- [ ] **Step 3: Run** the six snapshot tests, `dive_merge_service_test.dart`, `dive_merge_service_series_test.dart`, `dive_consolidation_service_test.dart`, `dive_consolidation_service_series_test.dart`, `dive_split_service_test.dart`, `dive_split_service_series_test.dart`, `dive_consolidation_test.dart`, `reparse_service_test.dart`, `reparse_service_series_test.dart`, `raw_data_persistence_test.dart`, `multi_computer_integration_test.dart`.
- [ ] **Step 4: Format, analyze, commit**

```bash
git commit -m "refactor(series): services carry series only; snapshot legacy lists and legacy deletes are gone"
```

---

### Task 6: TankPressurePoint.id and the last legacy names

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`TankPressurePoint`: delete `id`, its constructor parameter and its `props` entry)
- Modify: `lib/features/dive_log/domain/services/profile_series_merge.dart` (`mergeTankSeriesPoints` no longer synthesizes ids; doc comment)
- Modify: `lib/features/dive_log/domain/services/estimated_tank_pressure_synthesizer.dart` (drops the fabricated ids)
- Modify: every `TankPressurePoint(` construction in `lib/` and `test/` (104 carry `id:`; `grep -rn "TankPressurePoint(" lib test --include='*.dart' -A 1 | grep "id:"` lists them; the `TankPressurePoint` record typedef in `lib/features/dive_log/domain/services/tank_pressure_series.dart` is a different type and is untouched)
- Modify: `lib/core/database/database.dart` doc comments that still say "until plan 2e" on the v182 rung and backstop; `lib/features/dive_log/domain/codecs/profile_sample.dart` / `profile_field_table.dart` / `tank_pressure_series_codec.dart` doc comments that say "as the dive_profiles table stores it" become "as the v181 dive_profiles table stored it (the codec's column order)".
- Test: `test/features/dive_log/domain/entities/tank_pressure_point_test.dart` (new, small): equality ignores nothing that no longer exists; two points with the same tank, timestamp and pressure are equal.

- [ ] **Step 1: Failing test** (the equality test compiles only once `id` is gone; run to see the compile error).
- [ ] **Step 2: Remove the field**; `dart fix` will not do the constructor sweep, so run the grep and edit each site (a `sed` over the exact `id: '...',` / `id: ...,` argument lines is acceptable when followed by `dart format .` and `flutter analyze`; review the diff for any `id:` that belonged to another type).
- [ ] **Step 3: Run** `flutter analyze` (zero), then every test file the sweep touched (list them from `git diff --name-only`), per file.
- [ ] **Step 4: Format, analyze, commit**

```bash
git commit -m "refactor(series): TankPressurePoint has no row id; last legacy-table names in docs"
```

---

### Task 7: Port the legacy-touching tests

**Files:** the test files below (one commit; group edits by directory in the report).

**Interfaces:**
- Consumes: `ProfileSeriesRepository` / `TankPressureSeriesRepository` (`insertSeries`, `getSeriesForDive`, `getRowsForDives`), bound with `database: db, syncRepository: SyncRepository(database: db)` in tests that build their own `AppDatabase`; `ProfileSeriesCodec().decode(row.samples)` for raw-row assertions in migration tests; `legacyDdlAt180` / `seedProfiles` / `seedPressures` (`test/helpers/legacy_profile_fixtures.dart`) which STAY (they build pre-183 fixtures).
- Produces: no test seeds, reads or asserts on `dive_profiles` / `tank_pressure_profiles` except (a) migration fixtures at a version below 183 (they seed legacy rows for the ladder to pack and drop) and (b) the packer tests that build the legacy tables by hand. `DiveProfilesCompanion` / `TankPressureProfilesCompanion` / `DiveProfile` / `TankPressureProfile` appear nowhere under `test/`.

Port rules (from plan 2c, extended for the drop):
- P1 seeds: a helper that inserted a legacy row inserts one single-sample series through the repository instead (the legacy helper is deleted, not kept beside the twin).
- P2 raw-row assertions after the ladder (old migration tests): read `dive_profile_series` / `tank_pressure_series` rows for the dive (raw `SELECT` on the `sqlite3` handle, or the repository bound to the test's `AppDatabase`), decode with the codec, and assert the same values on the decoded samples (a v89 test that asserted `setpoint` on a row asserts it on the decoded sample at the same timestamp).
- P3 "legacy table is empty" assertions (R5 from plan 2c): delete; the table does not exist.
- P4 `performance_data_generator.dart`: `_buildProfilePoints` builds a `List<ProfileSample>` per dive and the generator inserts one primary series per dive through `ProfileSeriesRepository.insertSeries` (batching is not available for series; the generator's perf test budget may need its dive count halved; say so in the report if it does).
- P5 tests whose subject was the fallback itself (`dive_profile_duplicate_rows_test.dart`'s legacy cases, `profiles_by_data_source_test.dart`'s legacy-seeded cases, the `_...Legacy` twins in the 2b series tests): the assertion survives only if it is about the series path; otherwise delete the test and say which in the report.

| file | rule |
|---|---|
| `test/core/database/migration_v59_test.dart`, `migration_v89_o2_cells_test.dart`, `migration_v102_tank_pressure_relink_test.dart`, `migration_v105_profile_heading_test.dart`, `migration_v132_bottom_time_backfill_test.dart`, `migration_v153_o2_cell_mv_test.dart` | fixtures stay; P2 for every post-ladder read |
| `test/core/database/backfill_missing_data_sources_test.dart` (fixture at `currentSchemaVersion`: it must create the SERIES tables, not `dive_profiles`; seed series rows with the identity the backfill reads) | P1 + P2 |
| `test/core/services/sync/sync_dive_profile_mv_test.dart` | P1 (series with `o2SensorMv` samples), P2 |
| `test/features/media/data/lightroom_scan_service_test.dart` | P1 |
| `test/features/dive_log/profile_analysis_tick_reactivity_test.dart` | P1 |
| `test/helpers/performance_data_generator.dart` | P4 |
| `test/features/dive_computer/data/services/reparse_service_test.dart`, `raw_data_persistence_test.dart` | delete the legacy helpers and the R5 assertions (P1, P3) |
| `test/features/dive_log/data/services/dive_split_service_test.dart`, `dive_merge_service_test.dart`, `dive_consolidation_service_test.dart` | P1, P3 |
| `test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart`, `dive_consolidation_test.dart`, `dive_repository_test.dart`, `edited_profile_supersedes_originals_test.dart`, `profiles_by_data_source_test.dart`, `dive_profile_duplicate_rows_test.dart`, `diver_repository_test.dart` (`test/features/divers/...`) | P1, P3, P5 |
| the 2b/2c/2d series test files that carry `expect(await db.select(db.diveProfiles).get(), isEmpty)` style assertions (`dive_repository_series_reads_test.dart`, `dive_computer_repository_series_writes_test.dart`, `batch_summaries_series_test.dart`, `tank_pressure_series_reads_test.dart`, `dive_repository_series_writes_test.dart`, `dive_computer_series_reads_test.dart`, `tank_pressure_repository_series_writes_test.dart`, `dive_split_service_series_test.dart`, `dive_merge_service_series_test.dart`, `dive_consolidation_service_series_test.dart`, `reparse_service_series_test.dart`, `profile_analysis_loading_race_test.dart`, `profile_analysis_deco_stop_wiring_test.dart`, `dive_providers_test.dart`) | P3 |
| `test/core/database/profile_series_pack_test.dart`, `profile_series_pack_orphans_test.dart`, `migration_v182_profile_series_test.dart`, `backstop_resilience_test.dart` | fixtures build the legacy tables by hand at a version below 183: unchanged, but each opens the ladder to `currentSchemaVersion`, so any post-ladder assertion that the legacy tables still exist becomes an assertion that they are gone |

- [ ] **Step 1: Enumerate**: `grep -rln "DiveProfilesCompanion\|TankPressureProfilesCompanion\|DiveProfile\b\|TankPressureProfile\b\|db.diveProfiles\b\|db.tankPressureProfiles\b\|INSERT INTO dive_profiles\|INSERT INTO tank_pressure_profiles\|FROM dive_profiles\|FROM tank_pressure_profiles" test` and reconcile against the table above (any file not in the table is reported and ported by the same rules).
- [ ] **Step 2: Port**, file by file, running each file after its edit.
- [ ] **Step 3: Run** every file in the table, then the directories `test/core/database/`, `test/core/services/sync/`, `test/features/dive_log/`, `test/features/dive_computer/`, `test/features/statistics/`, `test/features/data_quality/`.
- [ ] **Step 4: Format, analyze, commit**

```bash
git commit -m "test(series): port the legacy-table fixtures and assertions to series"
```

---

### Task 8: Verification and the benchmark gate

- [ ] **Step 1: Greps**

```bash
grep -rn "dive_profiles\|tank_pressure_profiles" lib --include='*.dart' | grep -v "database.dart\|profile_series_pack.dart\|legacy_sample_staging.dart" | grep -v "^\S*:\s*//\|///"
grep -rn "DiveProfile\b\|TankPressureProfile\b\|DiveProfilesCompanion\|TankPressureProfilesCompanion\|_db.diveProfiles\|_db.tankPressureProfiles" lib test --include='*.dart'
grep -rn "Legacy(" lib/features/dive_log lib/features/dive_computer --include='*.dart'
grep -rn "TankPressurePoint(" lib test --include='*.dart' -A 1 | grep "id:"
```

Expected: nothing from the last three; the first shows only history comments (older rungs' text in `database.dart` is excluded by the filter; anything left is a comment describing history).

- [ ] **Step 2: Every test file this plan created or touched, individually**, then the six directories from Task 7 Step 3, then `database_import_graph_test.dart`.
- [ ] **Step 3: Format, analyze**: `dart format --output=none --set-exit-if-changed .` exit 0; `flutter analyze` "No issues found!".
- [ ] **Step 4: Full suite once** (background, `full-suite-2e.log`, known flakes as listed in the constraints; any other failure reruns alone once; a repeat is real).
- [ ] **Step 5: The benchmark gate**: rebuild the fixture from a fresh copy of the development database with the tool (Task 1), then `SUBMERSION_BENCH_FIXTURE=<path> flutter test --run-skipped --tags performance test/performance/profile_series_benchmark_test.dart`. Expected: every assertion green, including the two marked "green after Task 2"; paste the printed table into the report. If a series metric exceeds its legacy number by more than 25%, STOP: the gate failed; report the numbers and the method; do not weaken the assertion.
- [ ] **Step 6: Report**: commit list from `git log --oneline efdd779365b..HEAD`, the greps, per-file results, the full-suite summary and flake reruns, the benchmark table, and the schema-ladder sweep result (`git fetch origin` then, for every `origin/*` branch, `git show "origin/${h}:lib/core/database/database.dart" | grep -oE 'currentSchemaVersion = [0-9]+'`; any branch at 182 or 183 other than this one is a collision to report).

---

### Task 9: PR gate (STOP for authorization)

This task performs NO push and opens NO pull request. It prepares and stops.

- [ ] **Step 1: Merge `origin/main`** into the branch (`git fetch origin && git merge origin/main`), resolve conflicts if any (a conflicting `database.dart` rung number is the one to watch: if `origin/main` moved past 180, re-check that 182 and 183 are still free; if not, renumber this branch's two rungs and their tests to the next free numbers, update the floor to match the pack rung, and rerun Task 8), run `git submodule update --init --recursive`, `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, then `flutter analyze` and the Task 8 directory runs again.
- [ ] **Step 2: Write the PR body** to the session scratchpad as `pr2-body.md`: title "Packed profile series: 90% smaller dive logs, one series row per source"; sections: Why (the spike numbers: 25.4 of 28.07 MB were sample rows, 719 KB per dive; 74x / 129x lossless), What (the five plans in one paragraph each: tables and packer; series-first reads; writers; consumers and sync with the floor at 182; retirement at 183 with VACUUM), Migration and sync notes (deterministic migrated ids, the floor, the inbound shim and when it may retire, the one VACUUM), Behavior notes (the whole-series primary swap from plan 2c's review; the deterministic neighbour tie-break; dedupe at encode time), Benchmarks (the table from Task 8), Testing (the suite totals; the benchmark command), Follow-ups (retire the shim; `_applyAdoptInMemory`; the two files over 800 lines). No attribution line, no session link (repository rule).
- [ ] **Step 3: Release notes**: add the user-facing entry where this repository keeps them (memory: `feedback_release_notes_location.md` and `project_release_notes_source_of_truth.md` name the file and the rule; read them before writing) in one commit `docs: release notes for packed profile series`.
- [ ] **Step 4: STOP.** Report to the user: the branch state, the PR body path, the ladder sweep, and the exact push command (`git push --no-verify origin HEAD:worktree-profile-sample-storage-2`, the pre-push hook dies silently on new test files from a worktree) with the PR base (`main`; PR #1387 is the codec PR this branch stacks on, so note that PR 2 should target `main` after PR 1 merges or be opened as a stacked PR against PR 1's branch, the user's call). Do not push; do not open the PR; wait for explicit authorization.

---

## Self-review

**Spec coverage.** Section 8: step 4 (drop) and step 5 (purge) in the v183 rung (Task 2; the deviation from "one rung" is stated in the header and the constraints); the VACUUM at the `_runUpgradeLadder` seam keyed off the pre-ladder `user_version`, non-fatal (Task 2); the pre-migration backup is untouched. Section 7: the legacy entities' switch cases leave the serializer (Task 2 removes the read/delete cases, Task 3 turns the apply cases into staging); the receive-side tolerance survives on temp tables (Task 3) with its retirement condition named in the constraints. Section 4 "the legacy index heals go with the table" (Task 2). Section 6 "`TankPressurePoint.id` is removed" (Task 6). Section 10: migration test asserts "the old tables are gone; the retired tombstones and pending records are purged; two independently migrated copies produce identical series ids" (Task 2's new test plus the v182 determinism test that stays); `query_plan_test` and `performance_indexes_test` updated (Task 2); the benchmark fixture tool and the six numbers with the "nothing slower than today" gate (Tasks 1 and 8); "of the 53 test files that reference the old tables, those asserting on raw rows are ported" (Task 7; the count is 45 today after plans 2c and 2d ported the rest). Section 11: the PR body and release notes (Task 9), the push withheld for authorization.

**Placeholder scan.** Task 1's two legacy SQL constants are marked as verbatim copies from a named commit (60 lines the plan does not repeat; the commit and line numbers are given). Task 2's compile-fix list names every file and construct. Task 7 is a table of files and rules with the rule semantics spelled out; each rule names the replacement construct. No "add error handling", no "similar to Task N".

**Type consistency.** `packLegacyProfileRows(db, {nowMs, profileTable, tankTable})` (Task 3) matches `packStagedLegacyRows` and the v182 rung's unchanged call; `ensureLegacyStagingTables` / `stageLegacyProfileRows` / `stageLegacyTankRows` / `packStagedLegacyRows` (Task 3) match the serializer edits; `_dropLegacySampleTables()` (Task 2) is called from the rung only; `DatabaseService.getStoredSchemaVersion(path, {keyHex})` (existing) is used by Task 2's ladder and Task 1's benchmark; `_minProfileTemp(List<domain.DiveProfilePoint>)` (Task 4) is called from `_mapRowToDive` only; `TankPressurePoint(tankId, timestamp, pressure)` (Task 6) matches `mergeTankSeriesPoints` and the synthesizer after the sweep.
