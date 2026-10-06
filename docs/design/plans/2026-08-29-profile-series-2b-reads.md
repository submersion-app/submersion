# Profile Series 2b: Reads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every profile and tank-pressure read series-first (decode from `dive_profile_series` / `tank_pressure_series` when a dive has series rows, fall back to the legacy row tables when it does not), after first hardening the foundation plan 2a left, so that plan 2c can move writers one at a time with every existing test staying green.

**Architecture:** Each read method in `DiveRepository`, `TankPressureRepository`, and `DiveComputerRepositoryImpl` asks the series repositories first; an empty result means "not yet migrated to series" and the method runs its existing legacy body, moved verbatim into a `_...Legacy` private method that plan 2e deletes together with the tables. The merge of several series into one timestamp-ordered point list, and the series-level twin of the edited-profile "superseded originals" rule, live in one pure-Dart helper so `getDiveById`, `getMergedProfile`, and `getDiveForAnalysis` stay in step by construction. Task 1 is the carry-over from plan 2a's final re-review: guard the backstop's packer call, skip malformed legacy rows, check for work before loading parent sets, drop tombstones on restore, and pin the import-graph test's seed.

**Tech Stack:** Drift 2.34, the plan 2a repositories (`ProfileSeriesRepository`, `TankPressureSeriesRepository`), the PR 1 codecs, `flutter_test` with `setUpTestDatabase()`.

**Spec:** `docs/superpowers/specs/2026-08-28-profile-sample-storage-design.md`, section 6 (read paths: "every existing read method selects series rows for the dive and decodes; merge order across sources and the promote tiebreaker are reproduced in Dart"; `getBatchProfileSummaries` decodes one series per dive). Section 6's removal of `TankPressurePoint.id` is deferred to plan 2e: it touches about a hundred test constructions and belongs with the other mechanical cleanups, section 3 (decode only inside the repositories), section 9 (the nine SQL consumers are plan 2d, not this plan).

## Global Constraints

- Work only in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-sample-storage-2` on branch `worktree-profile-sample-storage-2` (HEAD 9be092d38b5 at planning time). The shell's working directory does not persist between commands; prefix every command with `cd` into that directory.
- Never use an em-dash (U+2014) or an en-dash as punctuation anywhere. No emojis.
- Lints: `package:flutter_lints/flutter.yaml` plus `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_fields`, `prefer_final_locals`, `avoid_print`, `require_trailing_commas`, `always_use_package_imports`. Project imports use `package:submersion/...`; test helpers use the relative `../../../../helpers/test_database.dart` form.
- The legacy tables, their Drift classes, the packer's writes, and every writer stay as they are. This plan changes reads only. Legacy read bodies move into `_...Legacy` methods unchanged; they are deleted in plan 2e, never here.
- Series-first rule, applied identically everywhere: fetch the dive's series once; an empty list means legacy fallback; a non-empty list is authoritative (no union with legacy rows).
- Decoding happens only inside `ProfileSeriesRepository` / `TankPressureSeriesRepository` (spec section 3). Consumers receive `ProfileSeries` / `TankPressureSeries` entities.
- `getDiveById`, `getMergedProfile`, and `getDiveForAnalysis` must return the same point list for the same dive (the existing parity test); they share one private helper.
- `database.dart`'s import graph stays Flutter-free (`test/core/database/database_import_graph_test.dart`).
- The `TankPressureSeries` name is shared by the Drift table class and the domain entity by decision; consumers import the entity `as domain`.
- Run tests per file, never a directory, never piped through grep, tail, or head. `dart format .` and `flutter analyze` ("No issues found!") before every commit. `git add` explicit paths only. No push. No `Co-Authored-By`.
- No new file over 400 lines; `dive_repository_impl.dart` is already large (7,000 lines), add only what the tasks list there and put every new helper in its own file.

---

## File structure

Create:

| file | responsibility |
|---|---|
| `lib/features/dive_log/domain/services/profile_series_merge.dart` | `mergeSeriesPoints` (interleave several series by timestamp, stable) and `dropSupersededSeries` (series-level twin of the edited-profile rule) |
| `test/core/database/backstop_resilience_test.dart` | the backstop survives a packer failure; malformed legacy rows are skipped |
| `test/features/dive_log/domain/services/profile_series_merge_test.dart` | |
| `test/features/dive_log/data/repositories/dive_repository_series_reads_test.dart` | `getDiveProfile`, `getMergedProfile`, `getDiveById` parity, supersede rule, fallback |
| `test/features/dive_log/data/repositories/profiles_by_data_source_series_test.dart` | series path of `getProfilesByDataSource` |
| `test/features/dive_log/data/repositories/batch_summaries_series_test.dart` | series path of `getBatchProfileSummaries` |
| `test/features/dive_log/data/repositories/tank_pressure_series_reads_test.dart` | tank reads, `getDiveById` start/end pressure |
| `test/features/dive_log/data/repositories/dive_computer_series_reads_test.dart` | computer id reads |

Modify:

| file | change |
|---|---|
| `lib/core/database/database.dart` | backstop packer call guarded |
| `lib/core/database/profile_series_pack.dart` | work check before parent loads; malformed rows skipped and counted; node id from `device_id` |
| `lib/features/dive_log/data/repositories/profile_series_repository.dart` | `getSeriesForDives`; `restoreSeriesRow` drops the tombstone |
| `lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart` | `hasSeriesForDive`; `restoreSeriesRow` drops the tombstone |
| `test/core/database/database_import_graph_test.dart` | seed path asserted |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | series-first `getDiveProfile`, `getMergedProfile`, `_mapRowToDive` (profile and tank pressures), `getProfilesByDataSource`, `getBatchProfileSummaries`; watchers |
| `lib/features/dive_log/data/repositories/tank_pressure_repository.dart` | series-first reads |
| `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | series-first `getComputerIdsForDive`, `getPrimaryComputerId`; `getProfilesForDive` removed |
| `test/features/dive_log/data/repositories/dive_computer_repository_error_test.dart` | `getProfilesForDive` expectation removed |

---

### Task 1: Foundation hardening (carry-over from plan 2a's review)

**Files:**
- Modify: `lib/core/database/database.dart` (the v182 backstop lines: `await _assertProfileSeriesSchema(); await packLegacyProfileRows(this);`)
- Modify: `lib/core/database/profile_series_pack.dart`
- Modify: `lib/features/dive_log/data/repositories/profile_series_repository.dart` (`restoreSeriesRow`)
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart` (`restoreSeriesRow`)
- Modify: `test/core/database/database_import_graph_test.dart`
- Test: `test/core/database/backstop_resilience_test.dart`
- Test: `test/core/database/profile_series_pack_test.dart` (two added tests)
- Test: `test/features/dive_log/data/repositories/profile_series_repository_restore_test.dart` (one added test)
- Test: `test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart` (one added test)

**Interfaces:**
- Consumes: `packLegacyProfileRows(DatabaseConnectionUser, {int? nowMs})`, `ProfilePackReport` record with `profileSeries`, `tankSeries`, `droppedSamples`, `skippedOrphans`; `SyncRepository.removeDeletion({required String entityType, required String recordId})`; `Hlc(physicalTime, counter, nodeId)`.
- Produces: `ProfilePackReport` gains `int skippedRows`; the backstop never fails an open because of the packer; `restoreSeriesRow` leaves no tombstone.

- [ ] **Step 1: Write the failing tests**

Create `test/core/database/backstop_resilience_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/profile_series_pack.dart';

import '../../helpers/legacy_profile_fixtures.dart';

/// The v182 backstop packs on every open. A legacy row it cannot pack, or a
/// series table it cannot insert into, must never turn into a database that
/// cannot open: the ladder is where a packing failure is visible and retried,
/// the backstop is a self-heal that has to stay best-effort.
void main() {
  test('a series table missing a column does not fail the open', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    seedParents(raw);
    seedProfiles(raw);
    // A pre-existing dive_profile_series without its samples column: the
    // IF NOT EXISTS DDL leaves it alone and every packer INSERT fails.
    raw.execute('''
      CREATE TABLE dive_profile_series (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        computer_id TEXT,
        source_id TEXT,
        is_primary INTEGER NOT NULL DEFAULT 1
      )
    ''');

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('a legacy row with a null timestamp is skipped, counted, and does not fail the open', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    raw.execute('PRAGMA user_version = 182');
    raw.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute('CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute('''
      CREATE TABLE dive_data_sources (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        computer_id TEXT,
        is_primary INTEGER NOT NULL DEFAULT 0,
        imported_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    raw.execute(
      'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, dive_id TEXT NOT NULL)',
    );
    // timestamp and depth nullable on purpose: a restored or hand-repaired
    // legacy table can hold such rows and the packer must step over them.
    raw.execute('''
      CREATE TABLE dive_profiles (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        computer_id TEXT,
        source_id TEXT,
        is_primary INTEGER NOT NULL DEFAULT 1,
        timestamp INTEGER,
        depth REAL
      )
    ''');
    raw.execute("INSERT INTO dives (id) VALUES ('d1')");
    raw.execute(
      "INSERT INTO dive_profiles (id, dive_id, timestamp, depth) VALUES "
      "('p1', 'd1', 0, 1.0), ('p2', 'd1', NULL, 2.0), ('p3', 'd1', 10, NULL), "
      "('p4', 'd1', 20, 3.0)",
    );

    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final row = await db
        .customSelect('SELECT sample_count FROM dive_profile_series')
        .getSingle();
    expect(row.read<int>('sample_count'), 2, reason: 'p2 and p3 are skipped');
    // A second explicit pack reports nothing new and no skipped rows, because
    // the dive already has a series row and is not revisited.
    final again = await packLegacyProfileRows(db, nowMs: 1);
    expect(again.profileSeries, 0);
    expect(again.skippedRows, 0);
  });
}
```

Add to `test/core/database/profile_series_pack_test.dart` (inside `main`, using the existing fixture helpers):

```dart
  test('skippedRows counts legacy rows without a timestamp or depth', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    seedParents(raw);
    // Loosen the columns the fixture declares NOT NULL by rebuilding the
    // table without those constraints.
    raw.execute('DROP TABLE dive_profiles');
    raw.execute('''
      CREATE TABLE dive_profiles (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL,
        computer_id TEXT,
        source_id TEXT,
        is_primary INTEGER NOT NULL DEFAULT 1,
        timestamp INTEGER,
        depth REAL
      )
    ''');
    raw.execute(
      "INSERT INTO dive_profiles (id, dive_id, timestamp, depth) VALUES "
      "('p1', 'd1', 0, 1.0), ('p2', 'd1', NULL, 2.0), ('p3', 'd1', 10, 3.0)",
    );
    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    // The backstop already packed on open; measure a fresh pack instead.
    await db.customSelect('SELECT 1').get();
    await db.customStatement('DELETE FROM dive_profile_series');
    final report = await packLegacyProfileRows(db, nowMs: 1);
    expect(report.profileSeries, 1);
    expect(report.skippedRows, 1);
  });

  test('the migration hlc carries the device id, not the persisted node id', () async {
    final db = AppDatabase(
      legacyFixture(
        seed: (raw) {
          seedParents(raw);
          seedProfiles(raw);
          raw.execute(
            'CREATE TABLE sync_metadata (id TEXT NOT NULL PRIMARY KEY, '
            'device_id TEXT NOT NULL, hlc TEXT, created_at INTEGER NOT NULL, '
            'updated_at INTEGER NOT NULL)',
          );
          raw.execute(
            "INSERT INTO sync_metadata (id, device_id, hlc, created_at, updated_at) "
            "VALUES ('global', 'dev-1', '000001800000000000:000005:other', 0, 0)",
          );
        },
      ),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    await db.customStatement('DELETE FROM dive_profile_series');
    await packLegacyProfileRows(db, nowMs: 1700000000000);
    final row = await db
        .customSelect('SELECT hlc FROM dive_profile_series LIMIT 1')
        .getSingle();
    expect(row.read<String>('hlc'), const Hlc(1800000000000, 6, 'dev-1').toString());
  });
```

If `legacyFixture` in that test file does not accept a `seed` callback in this form any more (the plan 2a fix wave moved fixtures into `test/helpers/legacy_profile_fixtures.dart`), build the database the way the neighbouring `stamps the migration hlc` test does and keep the assertions.

Add to `test/features/dive_log/data/repositories/profile_series_repository_restore_test.dart` (a new test in its existing `main`, reusing its `setUp` fixture; read the file first and follow its naming):

```dart
  test('restoreSeriesRow removes the tombstone the delete logged', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    final row = await (db.select(db.diveProfileSeries)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    await repo.deleteForDive('dive-1');
    var tombstones = await (db.select(db.deletionLog)
          ..where((t) => t.recordId.equals(id)))
        .get();
    expect(tombstones, hasLength(1));

    await repo.restoreSeriesRow(row, now: now + 1);

    tombstones = await (db.select(db.deletionLog)
          ..where((t) => t.recordId.equals(id)))
        .get();
    expect(tombstones, isEmpty);
    expect(await repo.getSeriesById(id), isNotNull);
  });
```

Add the mirror to `test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart` (`insertSeries` with `tankId: 'tank-a'`, `deleteForDive`, `restoreSeriesRow`, tombstone gone).

In `test/core/database/database_import_graph_test.dart`, before the `while` loop add:

```dart
    expect(
      File(queue.single).existsSync(),
      isTrue,
      reason: 'the walk must start at the real database.dart; a wrong '
          'working directory would make this test pass vacuously',
    );
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
flutter test test/core/database/backstop_resilience_test.dart
flutter test test/core/database/profile_series_pack_test.dart
flutter test test/features/dive_log/data/repositories/profile_series_repository_restore_test.dart
flutter test test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart
```

Expected: the resilience tests fail (the first with a failed open, the second with a `TypeError` or a `skippedRows` compile error); the `skippedRows` and node-id tests fail; the two tombstone tests fail on `expect(tombstones, isEmpty)`.

- [ ] **Step 3: Guard the backstop and harden the packer**

In `lib/core/database/database.dart`, replace the backstop's `await packLegacyProfileRows(this);` with:

```dart
        // Best effort: the ladder's own call is where a packing failure is
        // visible and retried. Here a malformed legacy table, a series table
        // a parallel branch shaped differently, or a busy lock from the
        // second isolate must not turn into a database that cannot open.
        try {
          await packLegacyProfileRows(this);
        } catch (e, stackTrace) {
          developer.log(
            'Backstop pack of legacy profile rows failed; continuing',
            name: 'AppDatabase',
            error: e,
            stackTrace: stackTrace,
          );
        }
```

In `lib/core/database/profile_series_pack.dart`:

1. Add `int skippedRows,` to the `ProfilePackReport` typedef and document it: `/// Legacy rows without a timestamp or depth (pressure, tank id for tanks), stepped over.`
2. Restructure the top of `packLegacyProfileRows` so the work check comes first:

```dart
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final profileColumns = await _columnNames(db, 'dive_profiles');
  final canPackProfiles =
      profileColumns.containsAll(const {'dive_id', 'timestamp', 'depth'});
  final tankColumns = await _columnNames(db, 'tank_pressure_profiles');
  final canPackTanks = tankColumns.containsAll(
    const {'dive_id', 'tank_id', 'timestamp', 'pressure'},
  );
  final unpackedProfileDives = canPackProfiles
      ? await _unpackedDiveIds(
          db,
          legacyTable: 'dive_profiles',
          seriesTable: 'dive_profile_series',
        )
      : const <String>[];
  final unpackedTankDives = canPackTanks
      ? await _unpackedDiveIds(
          db,
          legacyTable: 'tank_pressure_profiles',
          seriesTable: 'tank_pressure_series',
        )
      : const <String>[];
  if (unpackedProfileDives.isEmpty && unpackedTankDives.isEmpty) {
    // The common case on every open once a database is packed: nothing to
    // do, so nothing else is loaded.
    return (
      profileSeries: 0,
      tankSeries: 0,
      droppedSamples: 0,
      skippedOrphans: 0,
      skippedRows: 0,
    );
  }
  final hlc = await _migrationHlc(db, now);
  final diveIds = await _parentIds(db, 'dives');
  final computerIds = await _parentIds(db, 'dive_computers');
  final sourceIds = await _parentIds(db, 'dive_data_sources');
  final tankIds = await _parentIds(db, 'dive_tanks');
```

   and make the two table passes iterate `unpackedProfileDives` / `unpackedTankDives` instead of calling `_unpackedDiveIds` themselves. Return `skippedRows: skippedRows` in the final record.

3. Malformed rows: change `_profileSampleOf` to return `ProfileSample?`, returning null when `data['timestamp']` or `data['depth']` is null (before any cast); in the profile loop, `final sample = _profileSampleOf(row.data); if (sample == null) { skippedRows++; continue; }`. In the tank loop, skip and count when `tank_id`, `timestamp`, or `pressure` is null.

4. Node id: in `_migrationHlc`, replace `return Hlc.parse(persisted).increment(nowMs).toString();` with

```dart
      final advanced = Hlc.parse(persisted).increment(nowMs);
      // The device id column is the authority on this device's node id.
      return Hlc(advanced.physicalTime, advanced.counter, deviceId).toString();
```

In both repositories' `restoreSeriesRow`, wrap the insert in a transaction that also removes the tombstone:

```dart
    await _db.transaction(() async {
      await _db
          .into(_db.diveProfileSeries)
          .insertOnConflictUpdate(row.toCompanion(false));
      // The delete that preceded a restore logged a tombstone; left in place
      // it would ride the next changeset beside the upsert and delete the
      // restored row on every peer.
      await _syncRepository.removeDeletion(
        entityType: entityType,
        recordId: row.id,
      );
      if (markPending) {
        await _markPending(
          row.id,
          now ?? DateTime.now().millisecondsSinceEpoch,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
```

(the tank repository has no `_markPending` helper; call `_syncRepository.markRecordPending(entityType: entityType, recordId: row.id, localUpdatedAt: ...)` directly as its `insertSeries` does).

- [ ] **Step 4: Run the tests to verify they pass**

Run the four files from Step 2 plus `flutter test test/core/database/database_import_graph_test.dart`, `flutter test test/core/database/migration_v182_profile_series_test.dart`, and `flutter test test/core/database/profile_series_pack_orphans_test.dart`. Expected: all pass. Fix any test in `profile_series_pack_orphans_test.dart` that constructs a `ProfilePackReport` literal without `skippedRows` by adding `skippedRows: 0`.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart lib/core/database/profile_series_pack.dart lib/features/dive_log/data/repositories/profile_series_repository.dart lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart test/core/database/database_import_graph_test.dart test/core/database/backstop_resilience_test.dart test/core/database/profile_series_pack_test.dart test/core/database/profile_series_pack_orphans_test.dart test/features/dive_log/data/repositories/profile_series_repository_restore_test.dart test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart
git commit -m "fix(db): best-effort backstop pack, skip malformed legacy rows, drop tombstones on restore"
```

---

### Task 2: Merge helper and batch read on the repositories

**Files:**
- Create: `lib/features/dive_log/domain/services/profile_series_merge.dart`
- Modify: `lib/features/dive_log/data/repositories/profile_series_repository.dart` (add `getSeriesForDives`)
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart` (add `hasSeriesForDive`)
- Test: `test/features/dive_log/domain/services/profile_series_merge_test.dart`
- Test: `test/features/dive_log/data/repositories/profile_series_repository_test.dart` (one added test)
- Test: `test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart` (one added test)

**Interfaces:**
- Consumes: `ProfileSeries` (`samples`, `isPrimary`, `computerId`, `sourceId`, `points`), `ProfileSample.toPoint()` from `codecs/profile_sample_point.dart`.
- Produces:
  - `List<DiveProfilePoint> mergeSeriesPoints(List<ProfileSeries> series)`: every sample of every series, ordered by timestamp, ties keeping the order of `series` and then within-series order.
  - `List<ProfileSeries> dropSupersededSeries(List<ProfileSeries> series, {required bool hasSources, required String? primaryComputerId})`: the series-level twin of `DiveRepository._dropSupersededOriginals`.
  - `Future<Map<String, List<ProfileSeries>>> ProfileSeriesRepository.getSeriesForDives(List<String> diveIds)`: series grouped by dive id, each list in `(start_timestamp, id)` order; dives with no series are absent from the map.
  - `Future<bool> TankPressureSeriesRepository.hasSeriesForDive(String diveId)`: a count, no decode.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/services/profile_series_merge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';

ProfileSeries series(
  String id, {
  String? computerId,
  String? sourceId,
  bool isPrimary = true,
  required List<ProfileSample> samples,
}) => ProfileSeries(
  id: id,
  diveId: 'd1',
  computerId: computerId,
  sourceId: sourceId,
  isPrimary: isPrimary,
  summary: ProfileSeriesSummary.of(samples),
  samples: samples,
  codecVersion: 1,
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  group('mergeSeriesPoints', () {
    test('a single series maps straight to points', () {
      final s = series(
        'a',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 10, depth: 5.0),
        ],
      );
      expect(mergeSeriesPoints([s]).map((p) => p.timestamp), [0, 10]);
    });

    test('two series interleave by timestamp', () {
      final a = series(
        'a',
        computerId: 'c1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 0.0),
          ProfileSample(timestamp: 20, depth: 10.0),
        ],
      );
      final b = series(
        'b',
        computerId: 'c2',
        samples: const [
          ProfileSample(timestamp: 10, depth: 4.0),
          ProfileSample(timestamp: 30, depth: 2.0),
        ],
      );
      expect(
        mergeSeriesPoints([a, b]).map((p) => p.timestamp),
        [0, 10, 20, 30],
      );
    });

    test('ties keep series order, then within-series order', () {
      final a = series(
        'a',
        samples: const [
          ProfileSample(timestamp: 10, depth: 1.0),
          ProfileSample(timestamp: 10, depth: 1.5),
        ],
      );
      final b = series(
        'b',
        samples: const [ProfileSample(timestamp: 10, depth: 2.0)],
      );
      expect(mergeSeriesPoints([a, b]).map((p) => p.depth), [1.0, 1.5, 2.0]);
      expect(mergeSeriesPoints([b, a]).map((p) => p.depth), [2.0, 1.0, 1.5]);
    });

    test('an empty list merges to an empty list', () {
      expect(mergeSeriesPoints(const []), isEmpty);
    });
  });

  group('dropSupersededSeries', () {
    final original = series(
      'orig',
      computerId: 'c1',
      sourceId: 's1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
    );
    final edit = series(
      'edit',
      sourceId: 's1',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
    );
    final other = series(
      'other',
      computerId: 'c2',
      sourceId: 's2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
    );

    test('an edit drops the demoted original of the primary family', () {
      final kept = dropSupersededSeries(
        [original, edit, other],
        hasSources: true,
        primaryComputerId: 'c1',
      );
      expect(kept.map((s) => s.id), ['edit', 'other']);
    });

    test('without an edit nothing is dropped', () {
      final kept = dropSupersededSeries(
        [original, other],
        hasSources: true,
        primaryComputerId: 'c1',
      );
      expect(kept.map((s) => s.id), ['orig', 'other']);
    });

    test('a dive with no primary series keeps everything', () {
      final kept = dropSupersededSeries(
        [original, other],
        hasSources: true,
        primaryComputerId: null,
      );
      expect(kept, hasLength(2));
    });

    test('with no data sources every series is family', () {
      final demotedManual = series(
        'old',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      );
      final kept = dropSupersededSeries(
        [demotedManual, edit, other],
        hasSources: false,
        primaryComputerId: null,
      );
      expect(kept.map((s) => s.id), ['edit']);
    });
  });
}
```

Add to `profile_series_repository_test.dart` (in the `insert and read` group):

```dart
    test('getSeriesForDives groups by dive and omits dives without series', () async {
      await db
          .into(db.dives)
          .insert(
            const DivesCompanion(
              id: Value('dive-2'),
              diveDateTime: Value(now),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await repo.insertSeries(diveId: 'dive-1', samples: samples, id: 'a', now: now);
      await repo.insertSeries(
        diveId: 'dive-2',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        id: 'b',
        now: now,
      );
      final byDive = await repo.getSeriesForDives(['dive-1', 'dive-2', 'dive-9']);
      expect(byDive.keys.toSet(), {'dive-1', 'dive-2'});
      expect(byDive['dive-1']!.single.id, 'a');
      expect(byDive['dive-2']!.single.id, 'b');
      expect(await repo.getSeriesForDives(const []), isEmpty);
    });
```

Add to `tank_pressure_series_repository_test.dart`:

```dart
  test('hasSeriesForDive answers without decoding', () async {
    expect(await repo.hasSeriesForDive('dive-1'), isFalse);
    await repo.insertSeries(diveId: 'dive-1', tankId: 'tank-a', samples: samples);
    expect(await repo.hasSeriesForDive('dive-1'), isTrue);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the three test files. Expected: the merge file fails to compile (library missing); the two repository tests fail on the missing methods.

- [ ] **Step 3: Create the helper and the repository methods**

Create `lib/features/dive_log/domain/services/profile_series_merge.dart`:

```dart
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample_point.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';

/// Every sample of every series in [series], interleaved by timestamp.
///
/// This is what `ORDER BY timestamp` over the legacy row table produced for
/// a multi-source dive. Stable: samples that share a timestamp keep the
/// order of [series] and then their order within the series, so callers
/// that pass series in `(start_timestamp, id)` order get a deterministic
/// list on every device.
List<DiveProfilePoint> mergeSeriesPoints(List<ProfileSeries> series) {
  if (series.isEmpty) return const [];
  if (series.length == 1) return series.single.points;
  final entries = <(int timestamp, int order, ProfileSample sample)>[];
  var order = 0;
  for (final s in series) {
    for (final sample in s.samples) {
      entries.add((sample.timestamp, order++, sample));
    }
  }
  entries.sort((a, b) {
    final byTime = a.$1.compareTo(b.$1);
    return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
  });
  return [for (final entry in entries) entry.$3.toPoint()];
}

/// Series-level twin of `DiveRepository._dropSupersededOriginals`.
///
/// A saved profile edit demotes the originals and inserts a null-computer
/// series under the same source; the demoted originals of the primary
/// family are superseded and must not render next to the edit. Family
/// membership follows the legacy rule exactly: with no data sources every
/// series is family; otherwise a null-computer series or one on the primary
/// computer is. Nothing is dropped unless the family holds both a primary
/// and a demoted member.
List<ProfileSeries> dropSupersededSeries(
  List<ProfileSeries> series, {
  required bool hasSources,
  required String? primaryComputerId,
}) {
  if (!series.any((s) => !s.isPrimary) || !series.any((s) => s.isPrimary)) {
    return series;
  }
  bool isFamily(ProfileSeries s) =>
      !hasSources || s.computerId == null || s.computerId == primaryComputerId;
  final family = series.where(isFamily);
  final edited =
      family.any((s) => s.isPrimary) && family.any((s) => !s.isPrimary);
  if (!edited) return series;
  return [
    for (final s in series)
      if (s.isPrimary || !isFamily(s)) s,
  ];
}
```

Note one deliberate simplification versus the legacy code: the legacy version only looked up the primary source when a demoted row had a computer id; the series version takes `hasSources` and `primaryComputerId` from the caller, which looks them up once. `DiveRepository` supplies them from `_primarySourceComputer` (Task 3).

In `profile_series_repository.dart`, after `getSeriesForDive`, add:

```dart
  /// Every series of every dive in [diveIds], grouped by dive, each list in
  /// the same order [getSeriesForDive] uses. Dives without series are absent
  /// from the map, which is how a caller tells "not yet migrated" apart
  /// from "no samples". One statement for the whole batch.
  Future<Map<String, List<ProfileSeries>>> getSeriesForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const {};
    final rows =
        await (_db.select(_db.diveProfileSeries)
              ..where((t) => t.diveId.isIn(diveIds))
              ..orderBy([
                (t) => OrderingTerm.asc(t.diveId),
                (t) => OrderingTerm.asc(t.startTimestamp),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final byDive = <String, List<ProfileSeries>>{};
    for (final row in rows) {
      byDive.putIfAbsent(row.diveId, () => []).add(_decode(row));
    }
    return byDive;
  }
```

In `tank_pressure_series_repository.dart`, after `getSeriesForTank`, add:

```dart
  /// Whether [diveId] has any tank pressure series. A count, no decode.
  Future<bool> hasSeriesForDive(String diveId) async {
    final query = _db.selectOnly(_db.tankPressureSeries)
      ..addColumns([_db.tankPressureSeries.id.count()])
      ..where(_db.tankPressureSeries.diveId.equals(diveId));
    final row = await query.getSingle();
    return (row.read(_db.tankPressureSeries.id.count()) ?? 0) > 0;
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run the three files. Expected: 8 merge tests, the new repository tests, and every pre-existing test pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/domain/services/profile_series_merge.dart lib/features/dive_log/data/repositories/profile_series_repository.dart lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart test/features/dive_log/domain/services/profile_series_merge_test.dart test/features/dive_log/data/repositories/profile_series_repository_test.dart test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart
git commit -m "feat: series merge helper, batch series read, tank series existence check"
```

---

### Task 3: Series-first `getDiveProfile`, `getMergedProfile`, and `getDiveById`

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`: fields; `getDiveProfile`; `getMergedProfile`; the profile part of `_mapRowToDive`; the three watchers
- Test: `test/features/dive_log/data/repositories/dive_repository_series_reads_test.dart`

**Interfaces:**
- Consumes: `ProfileSeriesRepository.getSeriesForDive(diveId)`, `mergeSeriesPoints`, `dropSupersededSeries`, `_primarySourceComputer(diveId)` (existing, returns `({bool hasSources, String? computerId})`).
- Produces: `Future<List<domain.DiveProfilePoint>?> _mergedSeriesPoints(String diveId)` (null when the dive has no series) used by `getMergedProfile` and `_mapRowToDive`; `_getDiveProfileLegacy`, `_getMergedProfileLegacy` holding the moved bodies; watchers registering `diveProfileSeries` and `tankPressureSeries`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/dive_repository_series_reads_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// The series-first read paths. Fixtures are written through the series
/// repository; the legacy-row fixtures in the neighbouring test files keep
/// covering the fallback branch until plan 2e removes it.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late ProfileSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    series = ProfileSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final computer in ['comp-1', 'comp-2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: computer,
              name: computer,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<void> source(String id, String? computerId, {bool primary = false}) =>
      db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: id,
              diveId: 'dive-1',
              computerId: Value(computerId),
              isPrimary: Value(primary),
              importedAt: DateTime.fromMillisecondsSinceEpoch(now),
              createdAt: DateTime.fromMillisecondsSinceEpoch(now),
            ),
          );

  test('getDiveProfile returns only primary series, merged by timestamp', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 0.0),
        ProfileSample(timestamp: 20, depth: 10.0),
      ],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 10, depth: 99.0)],
      now: now,
    );
    final profile = await dives.getDiveProfile('dive-1');
    expect(profile.map((p) => p.timestamp), [0, 20]);
    expect(profile.map((p) => p.depth), [0.0, 10.0]);
  });

  test('getMergedProfile keeps every source and getDiveById stays in step', () async {
    await source('src-1', 'comp-1', primary: true);
    await source('src-2', 'comp-2');
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 0.0),
        ProfileSample(timestamp: 20, depth: 10.0),
      ],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      sourceId: 'src-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 10, depth: 4.0)],
      now: now,
    );
    final merged = await dives.getMergedProfile('dive-1');
    expect(merged.map((p) => p.timestamp), [0, 10, 20]);
    final byId = await dives.getDiveById('dive-1');
    expect(byId!.profile, merged);
    final analysis = await dives.getDiveForAnalysis('dive-1');
    expect(analysis!.profile, merged);
  });

  test('an edit supersedes the demoted original of the primary family', () async {
    await source('src-1', 'comp-1', primary: true);
    await source('src-2', 'comp-2');
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      isPrimary: false,
      samples: const [
        ProfileSample(timestamp: 0, depth: 0.0),
        ProfileSample(timestamp: 10, depth: 30.0),
      ],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 0.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      sourceId: 'src-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 5, depth: 7.0)],
      now: now,
    );
    final merged = await dives.getMergedProfile('dive-1');
    // The trimmed original (30 m at t=10) is gone; the other computer stays.
    expect(merged.map((p) => p.depth), [0.0, 7.0]);
    expect((await dives.getDiveById('dive-1'))!.profile, merged);
  });

  test('a dive with no series falls back to the legacy rows', () async {
    await db
        .into(db.diveProfiles)
        .insert(
          const DiveProfilesCompanion(
            id: Value('legacy-1'),
            diveId: Value('dive-1'),
            timestamp: Value(5),
            depth: Value(3.0),
          ),
        );
    expect((await dives.getDiveProfile('dive-1')).single.depth, 3.0);
    expect((await dives.getMergedProfile('dive-1')).single.depth, 3.0);
    expect((await dives.getDiveById('dive-1'))!.profile.single.depth, 3.0);
  });

  test('series rows win over legacy rows when both exist', () async {
    await db
        .into(db.diveProfiles)
        .insert(
          const DiveProfilesCompanion(
            id: Value('legacy-1'),
            diveId: Value('dive-1'),
            timestamp: Value(5),
            depth: Value(3.0),
          ),
        );
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
      now: now,
    );
    expect((await dives.getDiveProfile('dive-1')).single.depth, 9.0);
  });

  test('a series write ticks the detail and analysis watchers', () async {
    final detail = dives.watchDiveDetailChanges().first;
    final analysis = dives.watchAnalysisInputChanges().first;
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await expectLater(detail, completes);
    await expectLater(analysis, completes);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_series_reads_test.dart`
Expected: the series-path tests fail (empty profiles); the fallback test passes; the watcher test may time out (no tick from the series table yet).

- [ ] **Step 3: Port the reads**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`:

1. Imports: add
```dart
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_series_merge.dart';
```
   (`profile_series.dart` may already be imported `as domain` elsewhere in the file; if a name clash arises with `TankPressureSeries`, import the entity file with the alias the file already uses for `dive.dart`, which is `domain`, and refer to `domain.ProfileSeries`.)

2. Fields, next to `final SyncRepository _syncRepository = SyncRepository();`:
```dart
  final ProfileSeriesRepository _profileSeries = ProfileSeriesRepository();
  final TankPressureSeriesRepository _tankSeries = TankPressureSeriesRepository();
```

3. Rename the existing `getDiveProfile` body: move everything inside its `try` (the `PerfTimer.measure('getDiveProfile', ...)` call and the row mapping) into a new private method `Future<List<domain.DiveProfilePoint>> _getDiveProfileLegacy(String diveId)` with no try/catch of its own, and make `getDiveProfile`:

```dart
  /// Get profile data for a single dive (for lazy loading in list views).
  ///
  /// Series-first: a dive with series rows is read from them (primary series
  /// only, interleaved by timestamp); a dive with none is read from the
  /// legacy row table until plan 2e removes it.
  Future<List<domain.DiveProfilePoint>> getDiveProfile(String diveId) async {
    try {
      final series = await _profileSeries.getSeriesForDive(diveId);
      if (series.isNotEmpty) {
        return mergeSeriesPoints([
          for (final s in series)
            if (s.isPrimary) s,
        ]);
      }
      return await _getDiveProfileLegacy(diveId);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get profile for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
```

4. Add the shared merged read:

```dart
  /// The merged profile from series rows, or null when [diveId] has none.
  ///
  /// Shared by [getMergedProfile] and [_mapRowToDive] so `getDiveById`,
  /// `getMergedProfile`, and `getDiveForAnalysis` return the same list by
  /// construction (the parity test locks this in). Every source is kept,
  /// except the demoted originals a saved edit superseded
  /// ([dropSupersededSeries], the series twin of
  /// [_dropSupersededOriginals]).
  Future<List<domain.DiveProfilePoint>?> _mergedSeriesPoints(
    String diveId,
  ) async {
    final series = await _profileSeries.getSeriesForDive(diveId);
    if (series.isEmpty) return null;
    final needsPrimary =
        series.any((s) => !s.isPrimary) && series.any((s) => s.isPrimary);
    var hasSources = true;
    String? primaryComputerId;
    if (needsPrimary) {
      final primary = await _primarySourceComputer(diveId);
      hasSources = primary.hasSources;
      primaryComputerId = primary.computerId;
    }
    return mergeSeriesPoints(
      dropSupersededSeries(
        series,
        hasSources: hasSources,
        primaryComputerId: primaryComputerId,
      ),
    );
  }
```

5. Move `getMergedProfile`'s body into `Future<List<domain.DiveProfilePoint>> _getMergedProfileLegacy(String diveId)` unchanged and make:

```dart
  Future<List<domain.DiveProfilePoint>> getMergedProfile(String diveId) async {
    return await _mergedSeriesPoints(diveId) ??
        await _getMergedProfileLegacy(diveId);
  }
```

   Keep the existing doc comment on `getMergedProfile`.

6. In `_mapRowToDive`, replace the profile query and `_dropSupersededOriginals` call with:

```dart
    final seriesProfile = await _mergedSeriesPoints(row.id);
    final profileQuery = _db.select(_db.diveProfiles)
      ..where((t) => t.diveId.equals(row.id))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    final profileRows = seriesProfile != null
        ? const <DiveProfile>[]
        : await _dropSupersededOriginals(row.id, await profileQuery.get());
```

   and where the `Dive` is built, replace `profile: _dropDuplicateSamples(profileRows).map(_profilePointFromRow).toList(),` with:

```dart
      profile:
          seriesProfile ??
          _dropDuplicateSamples(profileRows).map(_profilePointFromRow).toList(),
```

   (Tank pressures in `_mapRowToDive` are Task 5.)

7. Watchers: in `watchDiveDetailChanges` add `TableUpdateQuery.onTable(_db.diveProfileSeries),` after the `diveProfiles` line and `TableUpdateQuery.onTable(_db.tankPressureSeries),` after the `tankPressureProfiles` line; the same two lines in `watchAnalysisInputChanges`. `watchDivesChanges` watches only `dives` and stays as it is.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/features/dive_log/data/repositories/dive_repository_series_reads_test.dart
flutter test test/features/dive_log/data/repositories/dive_profile_duplicate_rows_test.dart
flutter test test/features/dive_log/data/repositories/edited_profile_supersedes_originals_test.dart
flutter test test/features/dive_log/data/repositories/dive_repository_test.dart
flutter test test/features/dive_log/data/repositories/dive_repository_error_test.dart
flutter test test/features/dive_log/profile_analysis_tick_reactivity_test.dart
```

Expected: all pass. The legacy-fixture files exercise the fallback branch and must not change.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_series_reads_test.dart
git commit -m "feat: series-first getDiveProfile, getMergedProfile, and getDiveById"
```

---

### Task 4: Series-first `getProfilesByDataSource`

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`getProfilesByDataSource`)
- Test: `test/features/dive_log/data/repositories/profiles_by_data_source_series_test.dart`

**Interfaces:**
- Consumes: `_profileSeries.getSeriesForDive`, `_canonicalDataSourceRows`, `mergeSeriesPoints`, `legacyDataSourceId(diveId)`, `domain.SourceProfile`.
- Produces: `_getProfilesByDataSourceLegacy` holding the moved body; the series path.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/profiles_by_data_source_series_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// Series path of getProfilesByDataSource; mirrors the cases the legacy
/// profiles_by_data_source_test pins.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late ProfileSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    series = ProfileSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final computer in ['comp-1', 'comp-2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: computer,
              name: computer,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<void> source(String id, String? computerId, {bool primary = false}) =>
      db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: id,
              diveId: 'dive-1',
              computerId: Value(computerId),
              isPrimary: Value(primary),
              importedAt: DateTime.fromMillisecondsSinceEpoch(now),
              createdAt: DateTime.fromMillisecondsSinceEpoch(now),
            ),
          );

  test('series attribute to their source, null-computer series to the primary', () async {
    await source('src-1', 'comp-1', primary: true);
    await source('src-2', 'comp-2');
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      sourceId: 'src-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: now,
    );
    // A pre-v154 series: no source, no computer.
    await series.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 5, depth: 3.0)],
      now: now,
    );
    final bySource = await dives.getProfilesByDataSource('dive-1');
    expect(bySource.keys.toSet(), {'src-1', 'src-2'});
    expect(bySource['src-1']!.points.map((p) => p.depth), [1.0, 3.0]);
    expect(bySource['src-2']!.points.map((p) => p.depth), [2.0]);
    expect(bySource['src-1']!.isEdited, isFalse);
  });

  test('an edited primary replaces the original and sets isEdited', () async {
    await source('src-1', 'comp-1', primary: true);
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
      now: now,
    );
    final bySource = await dives.getProfilesByDataSource('dive-1');
    expect(bySource['src-1']!.isEdited, isTrue);
    expect(bySource['src-1']!.points.single.depth, 9.0);
  });

  test('a metadata-only source keeps an entry with no points', () async {
    await source('src-1', 'comp-1', primary: true);
    await source('src-2', 'comp-2');
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    final bySource = await dives.getProfilesByDataSource('dive-1');
    expect(bySource['src-2']!.points, isEmpty);
  });

  test('with no data sources a synthetic primary source is produced', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: now,
    );
    final bySource = await dives.getProfilesByDataSource('dive-1');
    final only = bySource.values.single;
    expect(only.sourceId, legacyDataSourceId('dive-1'));
    expect(only.computerId, 'comp-1');
    expect(only.isEdited, isTrue);
    expect(only.points.single.depth, 1.0);
  });

  test('no series and no legacy rows gives an empty map', () async {
    expect(await dives.getProfilesByDataSource('dive-1'), isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/profiles_by_data_source_series_test.dart`
Expected: the four series tests fail (empty or missing entries); the last passes.

- [ ] **Step 3: Port the read**

Move the existing body of `getProfilesByDataSource` (everything inside its `try`) into `Future<Map<String, domain.SourceProfile>> _getProfilesByDataSourceLegacy(String diveId)` unchanged, and make the public method:

```dart
  Future<Map<String, domain.SourceProfile>> getProfilesByDataSource(
    String diveId,
  ) async {
    try {
      final series = await _profileSeries.getSeriesForDive(diveId);
      if (series.isEmpty) return await _getProfilesByDataSourceLegacy(diveId);
      return _profilesBySourceFromSeries(diveId, series);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get profiles by data source for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  /// Series path of [getProfilesByDataSource]; the same rules as the legacy
  /// body, applied to whole series instead of rows.
  Future<Map<String, domain.SourceProfile>> _profilesBySourceFromSeries(
    String diveId,
    List<ProfileSeries> series,
  ) async {
    final sourceRows = _canonicalDataSourceRows(
      await (_db.select(_db.diveDataSources)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.isPrimary),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get(),
    );
    if (sourceRows.isEmpty) {
      // Dives with series but no dive_data_sources row: synthesize the
      // primary source the way the legacy read does.
      final primary = [
        for (final s in series)
          if (s.isPrimary) s,
      ];
      if (primary.isEmpty) return {};
      final syntheticSourceId = legacyDataSourceId(diveId);
      return {
        syntheticSourceId: domain.SourceProfile(
          sourceId: syntheticSourceId,
          computerId: primary.first.computerId,
          isEdited: series.any((s) => !s.isPrimary),
          points: mergeSeriesPoints(primary),
        ),
      };
    }

    final primary = sourceRows.first;
    final sourceIdByComputer = <String, String>{
      for (final s in sourceRows)
        if (s.computerId != null) s.computerId!: s.id,
    };
    final sourceIds = {for (final s in sourceRows) s.id};
    // The FK is authoritative; a series without one follows the pre-v154
    // computer convention (issue #1149).
    bool isPrimaryFamily(ProfileSeries s) => sourceIds.contains(s.sourceId)
        ? s.sourceId == primary.id
        : s.computerId == null || s.computerId == primary.computerId;
    final family = series.where(isPrimaryFamily);
    final hasEditedProfile =
        family.any((s) => s.isPrimary) && family.any((s) => !s.isPrimary);

    final grouped = <String, List<ProfileSeries>>{
      for (final s in sourceRows) s.id: [],
    };
    var primaryIsEdited = false;
    for (final s in series) {
      final owner = sourceIds.contains(s.sourceId)
          ? s.sourceId!
          : s.computerId == null
          ? primary.id
          : (sourceIdByComputer[s.computerId!] ?? primary.id);
      if (hasEditedProfile && isPrimaryFamily(s)) {
        if (!s.isPrimary) continue;
        primaryIsEdited = true;
      }
      grouped[owner]!.add(s);
    }
    return {
      for (final s in sourceRows)
        s.id: domain.SourceProfile(
          sourceId: s.id,
          computerId: s.computerId,
          isEdited: s.id == primary.id && primaryIsEdited,
          points: mergeSeriesPoints(grouped[s.id]!),
        ),
    };
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/features/dive_log/data/repositories/profiles_by_data_source_series_test.dart
flutter test test/features/dive_log/data/repositories/profiles_by_data_source_test.dart
flutter test test/features/dive_log/data/repositories/canonical_data_sources_test.dart
flutter test test/features/dive_log/presentation/providers/profile_analysis_deco_stop_wiring_test.dart
```

Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/profiles_by_data_source_series_test.dart
git commit -m "feat: series-first getProfilesByDataSource"
```

---

### Task 5: Batch summaries and tank pressure reads

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`getBatchProfileSummaries`; tank pressures in `_mapRowToDive`)
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_repository.dart` (`getTankPressuresForDive`, `getPressuresForTank`, `hasTankPressures`)
- Test: `test/features/dive_log/data/repositories/batch_summaries_series_test.dart`
- Test: `test/features/dive_log/data/repositories/tank_pressure_series_reads_test.dart`

**Interfaces:**
- Consumes: `_profileSeries.getSeriesForDives`, `_tankSeries.getSeriesForDive`, `_tankSeries.getSeriesForTank`, `_tankSeries.hasSeriesForDive`, `mergeSeriesPoints`, `domain.TankPressureSeries`.
- Produces: series-path `TankPressurePoint`s carry `id: '<seriesId>:<index>'` (the field stays until plan 2e removes it); `_getBatchProfileSummariesLegacy(List<String> diveIds, int maxSamples)`; `_downsample(List<domain.DiveProfilePoint>, int maxSamples)`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/data/repositories/batch_summaries_series_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late ProfileSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    series = ProfileSeriesRepository();
    for (final id in ['dive-1', 'dive-2', 'dive-3']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diveDateTime: const Value(now),
              createdAt: const Value(now),
              updatedAt: const Value(now),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('series-backed and legacy-backed dives are both summarised', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      samples: [
        for (var i = 0; i < 300; i++)
          ProfileSample(timestamp: i, depth: i.toDouble()),
      ],
      now: now,
    );
    await db
        .into(db.diveProfiles)
        .insert(
          const DiveProfilesCompanion(
            id: Value('legacy-1'),
            diveId: Value('dive-2'),
            timestamp: Value(7),
            depth: Value(3.0),
          ),
        );
    final summaries = await dives.getBatchProfileSummaries(
      ['dive-1', 'dive-2', 'dive-3'],
      maxSamples: 120,
    );
    expect(summaries.keys.toSet(), {'dive-1', 'dive-2'});
    expect(summaries['dive-1'], hasLength(120));
    expect(summaries['dive-1']!.first.timestamp, 0);
    expect(summaries['dive-1']!.last.timestamp, 299);
    expect(summaries['dive-2']!.single.depth, 3.0);
  });

  test('every series of a dive contributes, primary or not', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      computerId: null,
      samples: const [ProfileSample(timestamp: 10, depth: 2.0)],
      now: now,
    );
    final summaries = await dives.getBatchProfileSummaries(['dive-1']);
    expect(summaries['dive-1']!.map((p) => p.timestamp), [0, 10]);
  });

  test('an empty id list returns an empty map', () async {
    expect(await dives.getBatchProfileSummaries(const []), isEmpty);
  });
}
```

Create `test/features/dive_log/data/repositories/tank_pressure_series_reads_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TankPressureRepository tanks;
  late TankPressureSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    tanks = TankPressureRepository();
    series = TankPressureSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final tank in ['tank-a', 'tank-b']) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(id: tank, diveId: 'dive-1'),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('getTankPressuresForDive groups series by tank', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200.0),
        TankPressureSample(timestamp: 60, pressure: 190.0),
      ],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: const [TankPressureSample(timestamp: 0, pressure: 210.0)],
      now: now,
    );
    final byTank = await tanks.getTankPressuresForDive('dive-1');
    expect(byTank.keys.toSet(), {'tank-a', 'tank-b'});
    expect(byTank['tank-a']!.map((p) => p.pressure), [200.0, 190.0]);
    expect(byTank['tank-a']!.first.tankId, 'tank-a');
    expect((await tanks.getPressuresForTank('dive-1', 'tank-b')).single.pressure, 210.0);
    expect(await tanks.hasTankPressures('dive-1'), isTrue);
  });

  test('getDiveById derives start and end pressure from the series', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [
        TankPressureSample(timestamp: 0, pressure: 200.0),
        TankPressureSample(timestamp: 60, pressure: 190.0),
        TankPressureSample(timestamp: 120, pressure: 150.0),
      ],
      now: now,
    );
    final dive = await DiveRepository().getDiveById('dive-1');
    final tankA = dive!.tanks.singleWhere((t) => t.id == 'tank-a');
    expect(tankA.startPressure, 200.0);
    expect(tankA.endPressure, 150.0);
  });

  test('a dive with no tank series falls back to the legacy rows', () async {
    await db
        .into(db.tankPressureProfiles)
        .insert(
          TankPressureProfilesCompanion.insert(
            id: 'legacy-1',
            diveId: 'dive-1',
            tankId: 'tank-a',
            timestamp: 0,
            pressure: 180.0,
          ),
        );
    expect((await tanks.getTankPressuresForDive('dive-1'))['tank-a']!.single.pressure, 180.0);
    expect(await tanks.hasTankPressures('dive-1'), isTrue);
    final dive = await DiveRepository().getDiveById('dive-1');
    expect(dive!.tanks.singleWhere((t) => t.id == 'tank-a').startPressure, 180.0);
  });

  test('no series and no legacy rows', () async {
    expect(await tanks.getTankPressuresForDive('dive-1'), isEmpty);
    expect(await tanks.hasTankPressures('dive-1'), isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run both files. Expected: series-path tests fail; fallback and empty tests pass.

- [ ] **Step 3: Port the reads**

1. `TankPressurePoint` keeps its `id` field in this plan (plan 2e removes it together with the legacy tables); series-path points get `id: '${s.id}:$index'`, unique within one read and never persisted.
2. Nothing changes in `dive.dart` or the synthesizer.
3. In `tank_pressure_repository.dart`, add `final TankPressureSeriesRepository _tankSeries = TankPressureSeriesRepository();` (import `tank_pressure_series_repository.dart` and the entity file `as domain` if the file needs `TankPressureSeries`), move the three read bodies into `_getTankPressuresForDiveLegacy`, `_getPressuresForTankLegacy`, `_hasTankPressuresLegacy`, and write:

```dart
  Future<Map<String, List<TankPressurePoint>>> getTankPressuresForDive(
    String diveId,
  ) async {
    final series = await _tankSeries.getSeriesForDive(diveId);
    if (series.isEmpty) return _getTankPressuresForDiveLegacy(diveId);
    final result = <String, List<TankPressurePoint>>{};
    for (final s in series) {
      final points = result.putIfAbsent(s.tankId, () => []);
      for (var i = 0; i < s.samples.length; i++) {
        final sample = s.samples[i];
        points.add(
          TankPressurePoint(
            id: '${s.id}:$i',
            tankId: s.tankId,
            timestamp: sample.timestamp,
            pressure: sample.pressure,
          ),
        );
      }
    }
    return result;
  }

  Future<List<TankPressurePoint>> getPressuresForTank(
    String diveId,
    String tankId,
  ) async {
    final series = await _tankSeries.getSeriesForTank(diveId, tankId);
    if (series.isEmpty) return _getPressuresForTankLegacy(diveId, tankId);
    return [
      for (final s in series)
        for (var i = 0; i < s.samples.length; i++)
          TankPressurePoint(
            id: '${s.id}:$i',
            tankId: s.tankId,
            timestamp: s.samples[i].timestamp,
            pressure: s.samples[i].pressure,
          ),
    ];
  }

  Future<bool> hasTankPressures(String diveId) async =>
      await _tankSeries.hasSeriesForDive(diveId) ||
      await _hasTankPressuresLegacy(diveId);
```

   `getSeriesForDive` orders by tank, start, id and `getSeriesForTank` by start, id, so points come out timestamp-ordered within a tank as long as a tank's series do not overlap in time (a tank has one series per computer; two computers on one tank is the multi-transmitter case, whose series are concatenated in start order, the same order the legacy `ORDER BY timestamp` produced when their ranges did not overlap).

4. In `dive_repository_impl.dart`, `_mapRowToDive`: replace the tank pressure query and grouping with:

```dart
    final tankSeries = await _tankSeries.getSeriesForDive(row.id);
    final startPressureByTank = <String, double>{};
    final endPressureByTank = <String, double>{};
    if (tankSeries.isNotEmpty) {
      for (final s in tankSeries) {
        if (s.samples.isEmpty) continue;
        startPressureByTank.putIfAbsent(s.tankId, () => s.samples.first.pressure);
        endPressureByTank[s.tankId] = s.samples.last.pressure;
      }
    } else {
      final tankPressureRows =
          await (_db.select(_db.tankPressureProfiles)
                ..where((t) => t.diveId.equals(row.id))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();
      for (final p in tankPressureRows) {
        startPressureByTank.putIfAbsent(p.tankId, () => p.pressure);
        endPressureByTank[p.tankId] = p.pressure;
      }
    }
```

   and in the tank mapping replace the `profilePoints`/`profileStartPressure`/`profileEndPressure` block with `startPressure: t.startPressure ?? startPressureByTank[t.id], endPressure: t.endPressure ?? endPressureByTank[t.id],`. Delete the now-unused `tankPressuresByTankId` map.

5. `getBatchProfileSummaries`: move the existing body into `_getBatchProfileSummariesLegacy(List<String> diveIds, int maxSamples)` (returning the map for exactly those ids), extract its downsampling loop into `static List<domain.DiveProfilePoint> _downsample(List<domain.DiveProfilePoint> points, int maxSamples)`, and write:

```dart
  Future<Map<String, List<domain.DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) async {
    if (diveIds.isEmpty) return {};
    try {
      return await PerfTimer.measure('batchProfileSummaries', () async {
        final byDive = await _profileSeries.getSeriesForDives(diveIds);
        final result = <String, List<domain.DiveProfilePoint>>{
          for (final entry in byDive.entries)
            entry.key: _downsample(
              [
                for (final p in mergeSeriesPoints(entry.value))
                  domain.DiveProfilePoint(timestamp: p.timestamp, depth: p.depth),
              ],
              maxSamples,
            ),
        };
        final legacyIds = [
          for (final id in diveIds)
            if (!byDive.containsKey(id)) id,
        ];
        if (legacyIds.isNotEmpty) {
          result.addAll(
            await _getBatchProfileSummariesLegacy(legacyIds, maxSamples),
          );
        }
        return result;
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get batch profiles',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/features/dive_log/data/repositories/batch_summaries_series_test.dart
flutter test test/features/dive_log/data/repositories/tank_pressure_series_reads_test.dart
flutter test test/features/dive_log/data/repositories/dive_repository_test.dart
flutter test test/features/dive_log/data/repositories/dive_computer_multi_transmitter_pressure_test.dart
flutter test test/features/data_quality/repairs/tank_pressure_repairs_test.dart
flutter test test/features/settings/presentation/providers/load_tank_pressures_test.dart
flutter test test/features/dive_log/presentation/pages/dive_edit_preserves_sac_widget_test.dart
```

Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/data/repositories/tank_pressure_repository.dart test/features/dive_log/data/repositories/batch_summaries_series_test.dart test/features/dive_log/data/repositories/tank_pressure_series_reads_test.dart
git commit -m "feat: series-first batch summaries and tank pressure reads"
```

---

### Task 6: Dive computer repository reads

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`getComputerIdsForDive`, `getPrimaryComputerId`; `getProfilesForDive` removed)
- Modify: `test/features/dive_log/data/repositories/dive_computer_repository_error_test.dart` (the `getProfilesForDive` expectation removed)
- Test: `test/features/dive_log/data/repositories/dive_computer_series_reads_test.dart`

**Interfaces:**
- Consumes: `ProfileSeriesRepository.getSeriesForDive`.
- Produces: series-first `getComputerIdsForDive`, `getPrimaryComputerId`; `getProfilesForDive` gone (no production caller; it returned legacy Drift rows).

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/dive_computer_series_reads_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveComputerRepository computers;
  late ProfileSeriesRepository series;
  const now = 1750000000000;

  setUp(() async {
    db = await setUpTestDatabase();
    computers = DiveComputerRepository();
    series = ProfileSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final computer in ['comp-1', 'comp-2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: computer,
              name: computer,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('computer ids and the primary computer come from the series', () async {
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: now,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
      now: now,
    );
    expect(
      (await computers.getComputerIdsForDive('dive-1')).toSet(),
      {'comp-1', 'comp-2'},
    );
    expect(await computers.getPrimaryComputerId('dive-1'), 'comp-1');
  });

  test('falls back to legacy rows when the dive has no series', () async {
    await db
        .into(db.diveProfiles)
        .insert(
          const DiveProfilesCompanion(
            id: Value('legacy-1'),
            diveId: Value('dive-1'),
            computerId: Value('comp-2'),
            timestamp: Value(0),
            depth: Value(1.0),
          ),
        );
    expect(await computers.getComputerIdsForDive('dive-1'), ['comp-2']);
    expect(await computers.getPrimaryComputerId('dive-1'), 'comp-2');
  });

  test('no series and no legacy rows', () async {
    expect(await computers.getComputerIdsForDive('dive-1'), isEmpty);
    expect(await computers.getPrimaryComputerId('dive-1'), isNull);
  });
}
```

If the repository class is not named `DiveComputerRepository`, use the name declared in `dive_computer_repository_impl.dart`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_series_reads_test.dart`
Expected: the series test fails; the other two pass.

- [ ] **Step 3: Port the reads**

In `dive_computer_repository_impl.dart`: add `final ProfileSeriesRepository _profileSeries = ProfileSeriesRepository();` with its import; delete `getProfilesForDive` entirely; move the bodies of `getComputerIdsForDive` and `getPrimaryComputerId` (the `customSelect` and mapping inside their `try`) into `_getComputerIdsForDiveLegacy` and `_getPrimaryComputerIdLegacy`, and write:

```dart
  Future<List<String>> getComputerIdsForDive(String diveId) async {
    try {
      final series = await _profileSeries.getSeriesForDive(diveId);
      if (series.isNotEmpty) {
        return {
          for (final s in series)
            if (s.computerId != null) s.computerId!,
        }.toList();
      }
      return await _getComputerIdsForDiveLegacy(diveId);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get computer ids for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<String?> getPrimaryComputerId(String diveId) async {
    try {
      final series = await _profileSeries.getSeriesForDive(diveId);
      if (series.isNotEmpty) {
        for (final s in series) {
          if (s.isPrimary && s.computerId != null) return s.computerId;
        }
        return null;
      }
      return await _getPrimaryComputerIdLegacy(diveId);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get primary computer for dive: $diveId',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
```

In `dive_computer_repository_error_test.dart`, delete the `expect(repository.getProfilesForDive('test-id'), throwsA(...))` block (the method no longer exists).

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/features/dive_log/data/repositories/dive_computer_series_reads_test.dart
flutter test test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart
flutter test test/features/dive_log/data/repositories/dive_computer_repository_error_test.dart
```

Expected: all pass. If `dive_computer_repository_impl_test.dart` asserts on `getProfilesForDive`, delete that assertion too and note it in the report.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart test/features/dive_log/data/repositories/dive_computer_repository_error_test.dart test/features/dive_log/data/repositories/dive_computer_series_reads_test.dart
git add test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart
git commit -m "feat: series-first computer id reads; drop the unused getProfilesForDive"
```

---

### Task 7: Verification

**Files:** none new.

- [ ] **Step 1: Run every test file this plan created or touched, individually**

The eight new test files, plus: `profile_series_pack_test.dart`, `profile_series_pack_orphans_test.dart`, `migration_v182_profile_series_test.dart`, `database_import_graph_test.dart`, `profile_series_repository_test.dart`, `profile_series_repository_restore_test.dart`, `tank_pressure_series_repository_test.dart`, `dive_repository_test.dart`, `dive_repository_error_test.dart`, `dive_profile_duplicate_rows_test.dart`, `edited_profile_supersedes_originals_test.dart`, `profiles_by_data_source_test.dart`, `canonical_data_sources_test.dart`, `dive_computer_repository_impl_test.dart`, `dive_computer_repository_error_test.dart`, `dive_computer_multi_transmitter_pressure_test.dart`, `tank_pressure_repairs_test.dart`, `load_tank_pressures_test.dart`, `profile_analysis_tick_reactivity_test.dart`, `profile_analysis_deco_stop_wiring_test.dart`, `profile_analysis_loading_race_test.dart`, `dive_providers_test.dart`, `multi_computer_integration_test.dart`, `consolidation_sync_roundtrip_test.dart`, `uddf_round_trip_test.dart`.

Expected: every file passes.

- [ ] **Step 2: Format, analyze, layering**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test test/core/database/database_import_graph_test.dart
```

Expected: exit 0, "No issues found!", pass.

- [ ] **Step 3: Full suite once**

Background, 600000 ms timeout, output to `/private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/5b0068b6-136c-4277-89c4-30a25ed89d1c/scratchpad/full-suite-2b.log` with `echo "exit=$?"` appended. Known machine flakes: `local_file_resolver_test.dart` (mounted `$TMPDIR`; passes with `TMPDIR=/private/tmp/claude-501/sysvol-tmp`), `changeset_writer_test.dart` (shared `sync_base_publish` temp path; passes alone), `backup_encryption_service_test.dart`, `database_security_service_test.dart`. Any other failure: rerun alone once; a repeat is real. Any failure in a file this plan touched, or under `test/core/database/`, `test/features/dive_log/`, `test/core/services/sync/`, is real.

- [ ] **Step 4: Report**

The commit list from `git log --oneline 9be092d38b5..HEAD`, the per-file results, the full-suite summary and exit, flake reruns.

---

## Self-review

**Spec coverage.** Section 6 reads: `getDiveProfile`, `getMergedProfile`, `getProfilesByDataSource`, `getDiveForAnalysis` (via `getMergedProfile`), `getBatchProfileSummaries` ("decodes one series per dive and downsamples"), `getTankPressures`, `getPressuresForTank`: Tasks 3, 4, 5. "Merge order across sources and the promote tiebreaker reproduced in Dart": `mergeSeriesPoints` and `dropSupersededSeries` (Task 2), the winner promote already exists on the repository. Parity of `getDiveById` / `getMergedProfile` / `getDiveForAnalysis`: one shared `_mergedSeriesPoints` (Task 3) and a test. `TankPressurePoint.id` removal: deferred to plan 2e (about a hundred test constructions; a mechanical cleanup, not a read change). Section 3 "decode only in the repositories": every consumer takes entities; `getSeriesForDives` added for the batch read. Section 9 SQL consumers: deliberately plan 2d. The plan 2a re-review carry-over (backstop guard, malformed rows, work check, tombstone on restore, seed assert, node id): Task 1.

Not in this plan by design: any writer (2c), any SQL predicate (2d), fallback removal (2e).

**Placeholder scan.** Legacy bodies are moved, not rewritten; each move names the source method and the target name. No grep-driven edits remain. No "add handling", no "similar to".

**Type consistency.** `mergeSeriesPoints(List<ProfileSeries>)` and `dropSupersededSeries(List<ProfileSeries>, {required bool hasSources, required String? primaryComputerId})` are defined in Task 2 and called with those shapes in Tasks 3, 4, 5. `getSeriesForDives` returns `Map<String, List<ProfileSeries>>` (Task 2) and is consumed as such in Task 5. `hasSeriesForDive` (Task 2) is used in Task 5. `_primarySourceComputer` returns `({bool hasSources, String? computerId})`, matched in Task 3. `TankPressurePoint({id, tankId, timestamp, pressure})` is unchanged and every series-path construction supplies all four. `ProfilePackReport.skippedRows` (Task 1) matches its tests.
