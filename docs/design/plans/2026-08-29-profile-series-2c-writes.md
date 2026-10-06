# Profile Series Plan 2c: Writers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every production write of profile samples and tank pressure samples lands in the packed series tables (`dive_profile_series`, `tank_pressure_series`) through the two series repositories, so that after this plan no code path inserts or updates a `dive_profiles` or `tank_pressure_profiles` row.

**Architecture:** Plan 2a created the tables, the v182 packer and the repositories; plan 2b made every read series-first with a byte-identical legacy fallback. This plan moves the thirteen legacy write sites, one file per task: the repositories gain the handful of operations the writers need (Task 1), then `DiveRepository`, `DiveComputerRepository`, `TankPressureRepository`, `ReparseService`, `DiveSplitService`, `DiveMergeService` with its snapshot, and `DiveConsolidationService` move in turn. Legacy `INSERT` and `UPDATE` statements are deleted; legacy `DELETE` statements stay in place (they keep the 2b fallback from re-exposing stale rows after a series delete) and go with the tables in plan 2e; legacy per-row tombstones (`logDeletion` with entity type `diveProfiles` or `tankPressureProfiles`) are removed because plan 2d drops those sync entities. Tests that seed legacy rows for a moved writer switch to series seeding in the same task.

**Tech Stack:** Flutter, Drift 2.34.3, SQLite; `ProfileSeriesCodec` / `TankPressureSeriesCodec` (PR 1); `flutter test`; `dart format`; `flutter analyze`.

**Spec:** `docs/superpowers/specs/2026-08-28-profile-sample-storage-design.md` (sections 3, 6 and 12 bind this plan; section 7 is plan 2d; section 8 is done; section 9 is plan 2d; section 10's gates run in plan 2e). Plan 2b's hand-off checklist (session scratchpad `2b-handoff-checklist.md`) is folded into the constraints below.

## Global Constraints

- Schema version stays 182. No migration, no new table, no new column in this plan.
- Series are the only write target: after each task, the file it names contains no `into(_db.diveProfiles)`, `update(_db.diveProfiles)`, `into(_db.tankPressureProfiles)`, `update(_db.tankPressureProfiles)`, `INSERT INTO dive_profiles`, `UPDATE dive_profiles`, `INSERT INTO tank_pressure_profiles` or `UPDATE tank_pressure_profiles`. Legacy `delete(...)` / `DELETE FROM` statements on those tables STAY exactly as they are.
- Legacy per-row tombstones go: no `logDeletion(entityType: 'diveProfiles', ...)` or `logDeletion(entityType: 'tankPressureProfiles', ...)` survives in a moved file. Series deletes log one tombstone per series inside the repositories.
- "No samples" means "no series row": never call `insertSeries` with an empty list; skip the insert instead (`insertSeries` throws `ArgumentError` on an empty list).
- Ordering is the repository's job: `insertSeries` sorts samples by timestamp (stable, ties keep input order) and drops exact duplicates before encoding. Writers hand over whatever order they have.
- A demote-then-insert (`saveEditedProfile`) and a delete-then-promote (`restoreOriginalProfile`, reparse replace) run inside ONE `_db.transaction` so a dive is never observable with series but no primary series.
- Decode only inside the two series repositories. Services and the other repositories receive `ProfileSeries` / `TankPressureSeries` entities or `ProfileSample` / `TankPressureSample` lists; nothing outside the codecs directory names a codec class.
- Tank writes key on `(dive_id, tank_id, computer_id)`; a tank may legitimately own several series; nothing upserts by `(dive_id, tank_id)`.
- Drift name clash: the table class `TankPressureSeries` (database.dart) and the entity `TankPressureSeries` (entities/profile_series.dart) share a name. Files that import both must import the entity file `as series` and write `series.TankPressureSeries`; `dive_repository_impl.dart` already imports the entity file unaliased and names only `ProfileSeries`, leave it that way.
- No em-dashes (U+2014) or en-dashes used as punctuation anywhere (code, comments, tests, commit messages). No emojis. Immutability: never mutate a list handed in; build new lists.
- TDD per task; `dart format .` from the worktree root; `flutter analyze` zero issues (infos included); tests run per file with `flutter test <path>`, never piped; stage explicit paths; one local commit per task with the message given; no push; no `Co-Authored-By` trailer.
- Worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-sample-storage-2`, branch `worktree-profile-sample-storage-2`, absolute paths only.

## Test migration rules (apply in every task that names test files)

Each heavy write-site test file has a legacy seed helper near its top (`insertTestProfile`, `insertProfile`, `insertProfileRow`, `insertTankPressure`, ...) that inserts ONE `dive_profiles` or `tank_pressure_profiles` row per call, plus assertions that count or read those rows. Because the 2b reads use the series tables whenever a dive has ANY series row and ignore the legacy rows otherwise, a test that seeds legacy rows and then calls a moved writer sees the writer act on an empty series set. The rules:

- R1 (seed): keep the legacy helper in place for tests whose writer has NOT moved yet, and add a series twin next to it that inserts ONE single-sample series per call through the repository, returning the series id. The twin keeps the same parameters. Tests that call a writer moved in THIS task switch to the twin; nothing else in the file changes for seeding. When a later task moves the remaining writers of that file, it switches the rest and deletes the legacy helper.
- R2 (assert on seeded rows): an assertion that counted or read legacy rows the test SEEDED becomes the same assertion over series rows (`db.select(db.diveProfileSeries)` / `db.select(db.tankPressureSeries)`, or `ProfileSeriesRepository().getSeriesForDive`), one series per seeded row, so counts stay equal.
- R3 (assert on writer output): an assertion that counted legacy rows a WRITER inserted from N points becomes an assertion on the series it inserted (`getSeriesForDive(diveId, primaryOnly: true)` or `getSeriesForDive(diveId)`), checking `samples.length == N` (or `points`), and `isPrimary` / `computerId` / `sourceId` on the series instead of per row.
- R4 (tombstones): an assertion that a `deletion_log` row has entity type `diveProfiles` / `tankPressureProfiles` becomes `diveProfileSeries` / `tankPressureSeries`, one per series rather than one per row.
- R5 (legacy deletes): an assertion that a legacy table is EMPTY after a writer that deletes stays as it is (legacy deletes remain); add the series assertion beside it.
- R6 (reads): assertions that go through `getDiveProfile`, `getMergedProfile`, `getProfilesByDataSource`, `getTankPressuresForDive`, `getPressuresForTank`, `getDiveById` need no change once seeding moved.

Series twin of a profile seed helper (the shape every task reuses; adapt the parameter list to the file's helper):

```dart
  final profileSeries = ProfileSeriesRepository();

  Future<String> insertTestSeries({
    required String diveId,
    String? sourceId,
    String? computerId,
    bool isPrimary = true,
    int timestamp = 0,
    double depth = 5.0,
    String? id,
  }) => profileSeries.insertSeries(
    id: id,
    diveId: diveId,
    computerId: computerId,
    sourceId: sourceId,
    isPrimary: isPrimary,
    samples: [ProfileSample(timestamp: timestamp, depth: depth)],
    now: 1000,
  );
```

Series twin of a tank pressure seed helper:

```dart
  final tankSeries = TankPressureSeriesRepository();

  Future<String> insertTestPressureSeries({
    required String diveId,
    required String tankId,
    String? computerId,
    int timestamp = 0,
    double pressure = 200.0,
    String? id,
  }) => tankSeries.insertSeries(
    id: id,
    diveId: diveId,
    tankId: tankId,
    computerId: computerId,
    samples: [TankPressureSample(timestamp: timestamp, pressure: pressure)],
    now: 1000,
  );
```

Imports the twins need: `package:submersion/features/dive_log/data/repositories/profile_series_repository.dart`, `.../tank_pressure_series_repository.dart`, `package:submersion/features/dive_log/domain/codecs/profile_sample.dart` (`ProfileSample`), `package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart` (`TankPressureSample`). Both repositories reach `DatabaseService.instance.database`, which `setUpTestDatabase()` provides; a test file that builds its own `AppDatabase` (the reparse tests) constructs them with `database: db` (Task 1 adds that parameter).

## File structure

| File | Responsibility after this plan |
|---|---|
| `lib/core/data/repositories/sync_repository.dart` | gains `SyncRepository({AppDatabase? database})` so a repository bound to a private database stamps hlc into that database |
| `lib/features/dive_log/data/repositories/profile_series_repository.dart` | gains `database:` injection, stable sort in `insertSeries`, `hasAnySeries`, `ownsAny`, `adoptUnattributed`, `deleteByComputer`, `deleteByIds`, `getRowsForDives` |
| `lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart` | gains `database:` injection, stable sort, `getRowsForDives`, `reassignTank`, `swapTanks`, `stampComputerWhereNull`, `deleteByIds` |
| `lib/features/dive_log/domain/codecs/profile_sample.dart`, `tank_pressure_series_codec.dart` | gain `shiftedBy(int seconds)` on the sample types (merge and consolidation re-base timestamps) |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | `createDive`, `saveEditedProfile`, `restoreOriginalProfile`, `_adoptUnattributedProfiles`, `setPrimaryDataSource` write series; `_sourceOwnsProfiles`, `_promoteProfilesOwnedBySource`, `_ownedBySourceSql`, `_ownershipVars` deleted |
| `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` | `importProfile`, `setPrimaryProfile`, `clearSourceAndProfiles` write series; the per-sample `markRecordPending` loop goes |
| `lib/features/dive_log/data/repositories/tank_pressure_repository.dart` | `insertTankPressures`, `deleteTankPressuresForDive`, `replaceTankPressures`, `reassignTankPressureSeries`, `swapTankPressureSeries` write series |
| `lib/features/dive_computer/data/services/reparse_service.dart` | `_replaceDiveProfiles`, the tank-pressure clear, `_replaceTankPressureProfiles` write series through repositories bound to `db` |
| `lib/features/dive_log/data/services/dive_split_service.dart` | selects, copies and deletes series instead of rows |
| `lib/features/dive_log/data/services/dive_merge_snapshot.dart` | captures `profileSeriesRows` and `tankSeriesRows` (raw rows, restored verbatim) beside the legacy row lists, which stay until plan 2e |
| `lib/features/dive_log/data/services/dive_merge_service.dart` | re-bases series into the merged dive, fills gaps into the adjacent series, undo restores series rows |
| `lib/features/dive_log/data/services/dive_consolidation_service.dart` | stamps, copies and restores series |

---

### Task 1: Repository operations the writers need

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (constructor and `_db` getter only)
- Modify: `lib/features/dive_log/data/repositories/profile_series_repository.dart`
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart`
- Modify: `lib/features/dive_log/domain/codecs/profile_sample.dart` (`shiftedBy`)
- Modify: `lib/features/dive_log/domain/codecs/tank_pressure_series_codec.dart` (`TankPressureSample.shiftedBy`)
- Test: `test/features/dive_log/data/repositories/profile_series_repository_writers_test.dart` (new)
- Test: `test/features/dive_log/data/repositories/tank_pressure_series_repository_writers_test.dart` (new)
- Test: `test/features/dive_log/domain/codecs/sample_shift_test.dart` (new)

**Interfaces:**
- Consumes: the existing repositories (`insertSeries`, `_ownedBy`, `_ids`, `_delete`, `_markPending`, `_setPrimary` in the profile repository; `insertSeries`, `_delete` in the tank repository), `SyncRepository.markRecordPending`, `dedupeExactSamples`, `dedupeExactPressureSamples`.
- Produces (every later task relies on these exact names):
  - `SyncRepository({AppDatabase? database})`
  - `ProfileSeriesRepository({SyncRepository? syncRepository, AppDatabase? database})`
  - `Future<bool> ProfileSeriesRepository.hasAnySeries(String diveId)`
  - `Future<bool> ProfileSeriesRepository.ownsAny(String diveId, {required String? sourceId, required String? computerId})`
  - `Future<int> ProfileSeriesRepository.adoptUnattributed(String diveId, String sourceId, {int? now})`
  - `Future<List<String>> ProfileSeriesRepository.deleteByComputer(String diveId, String? computerId)`
  - `Future<List<String>> ProfileSeriesRepository.deleteByIds(List<String> ids)`
  - `Future<List<DiveProfileSeriesRow>> ProfileSeriesRepository.getRowsForDives(List<String> diveIds)`
  - `TankPressureSeriesRepository({SyncRepository? syncRepository, AppDatabase? database})`
  - `Future<List<TankPressureSeriesRow>> TankPressureSeriesRepository.getRowsForDives(List<String> diveIds)`
  - `Future<int> TankPressureSeriesRepository.reassignTank(String diveId, String fromTankId, String toTankId, {int? now})`
  - `Future<void> TankPressureSeriesRepository.swapTanks(String diveId, String tankIdA, String tankIdB, {int? now})`
  - `Future<int> TankPressureSeriesRepository.stampComputerWhereNull(String diveId, String computerId, {int? now})`
  - `Future<List<String>> TankPressureSeriesRepository.deleteByIds(List<String> ids)`
  - `ProfileSample ProfileSample.shiftedBy(int seconds)`, `TankPressureSample TankPressureSample.shiftedBy(int seconds)`
  - `insertSeries` on both repositories sorts by timestamp (stable) before dedupe and encode.

- [ ] **Step 1: Write the failing tests**

`test/features/dive_log/domain/codecs/sample_shift_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

void main() {
  test('ProfileSample.shiftedBy moves only the timestamp', () {
    const s = ProfileSample(timestamp: 10, depth: 5.0, temperature: 21.0);
    final t = s.shiftedBy(90);
    expect(t.timestamp, 100);
    expect(t.depth, 5.0);
    expect(t.temperature, 21.0);
    expect(s.timestamp, 10);
  });

  test('TankPressureSample.shiftedBy moves only the timestamp', () {
    const s = TankPressureSample(timestamp: 10, pressure: 200.0);
    final t = s.shiftedBy(-5);
    expect(t.timestamp, 5);
    expect(t.pressure, 200.0);
  });
}
```

`test/features/dive_log/data/repositories/profile_series_repository_writers_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProfileSeriesRepository repo;

  Future<void> seedParents(AppDatabase target) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await target
        .into(target.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await target
        .into(target.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Comp 1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await target
        .into(target.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-1',
            diveId: 'dive-1',
            computerId: const Value('comp-1'),
            isPrimary: const Value(true),
            importedAt: DateTime.fromMillisecondsSinceEpoch(now),
            createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await seedParents(db);
    repo = ProfileSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase(db);
  });

  test('insertSeries sorts by timestamp and keeps input order for ties', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [
        ProfileSample(timestamp: 20, depth: 2.0),
        ProfileSample(timestamp: 0, depth: 0.0),
        ProfileSample(timestamp: 10, depth: 1.0),
        ProfileSample(timestamp: 10, depth: 1.5),
      ],
      now: 1000,
    );
    final series = await repo.getSeriesById(id);
    expect(
      series!.samples.map((s) => (s.timestamp, s.depth)).toList(),
      [(0, 0.0), (10, 1.0), (10, 1.5), (20, 2.0)],
    );
  });

  test('hasAnySeries is false before and true after an insert', () async {
    expect(await repo.hasAnySeries('dive-1'), isFalse);
    await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    expect(await repo.hasAnySeries('dive-1'), isTrue);
  });

  test('ownsAny follows the FK first, then the null-source computer rule', () async {
    await repo.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: null,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    expect(
      await repo.ownsAny('dive-1', sourceId: 'src-1', computerId: 'comp-1'),
      isTrue,
    );
    expect(
      await repo.ownsAny('dive-1', sourceId: 'src-other', computerId: 'comp-x'),
      isFalse,
    );
    expect(
      await repo.ownsAny('dive-1', sourceId: 'src-other', computerId: null),
      isFalse,
    );
  });

  test('adoptUnattributed stamps only null-source series and restamps hlc', () async {
    final orphan = await repo.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final owned = await repo.insertSeries(
      diveId: 'dive-1',
      sourceId: 'src-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    final before = (await db.select(db.diveProfileSeries).get())
        .firstWhere((r) => r.id == orphan)
        .hlc;
    expect(await repo.adoptUnattributed('dive-1', 'src-1', now: 2000), 1);
    final rows = await db.select(db.diveProfileSeries).get();
    final adopted = rows.firstWhere((r) => r.id == orphan);
    expect(adopted.sourceId, 'src-1');
    expect(adopted.updatedAt, 2000);
    expect(adopted.hlc, isNot(before));
    expect(rows.firstWhere((r) => r.id == owned).sourceId, 'src-1');
    expect(await repo.adoptUnattributed('dive-1', 'src-1'), 0);
  });

  test('deleteByComputer matches the computer or the null-computer series', () async {
    final byComp = await repo.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final manual = await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    expect(await repo.deleteByComputer('dive-1', 'comp-1'), [byComp]);
    expect(await repo.deleteByComputer('dive-1', null), [manual]);
    expect(await repo.getSeriesForDive('dive-1'), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => t.recordId).toSet(), {byComp, manual});
    expect(tombstones.map((t) => t.entityType).toSet(), {'diveProfileSeries'});
  });

  test('deleteByIds deletes exactly the ids given and tolerates an empty list', () async {
    final a = await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final b = await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    expect(await repo.deleteByIds(const []), isEmpty);
    expect(await repo.deleteByIds([a]), [a]);
    expect((await repo.getSeriesForDive('dive-1')).map((s) => s.id), [b]);
  });

  test('getRowsForDives returns raw rows for the given dives only', () async {
    final a = await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    expect(await repo.getRowsForDives(const []), isEmpty);
    final rows = await repo.getRowsForDives(['dive-1', 'dive-none']);
    expect(rows.map((r) => r.id), [a]);
    expect(rows.single.samples, isNotEmpty);
  });

  test('a repository bound to a private database never touches the global one', () async {
    final private = AppDatabase(NativeDatabase.memory());
    addTearDown(private.close);
    await seedParents(private);
    final bound = ProfileSeriesRepository(
      database: private,
      syncRepository: SyncRepository(database: private),
    );
    final id = await bound.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
      now: 1000,
    );
    expect((await bound.getSeriesForDive('dive-1')).map((s) => s.id), [id]);
    expect(await repo.getSeriesForDive('dive-1'), isEmpty);
    final privateRow = (await private.select(private.diveProfileSeries).get()).single;
    expect(privateRow.hlc, isNotNull);
  });
}
```

`test/features/dive_log/data/repositories/tank_pressure_series_repository_writers_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TankPressureSeriesRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Comp 1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final tank in ['tank-a', 'tank-b']) {
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: tank, diveId: 'dive-1'));
    }
    repo = TankPressureSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase(db);
  });

  test('insertSeries sorts by timestamp and keeps input order for ties', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [
        TankPressureSample(timestamp: 60, pressure: 180.0),
        TankPressureSample(timestamp: 0, pressure: 200.0),
        TankPressureSample(timestamp: 60, pressure: 181.0),
      ],
      now: 1000,
    );
    final series = (await repo.getSeriesForDive('dive-1')).single;
    expect(series.id, id);
    expect(
      series.samples.map((s) => (s.timestamp, s.pressure)).toList(),
      [(0, 200.0), (60, 180.0), (60, 181.0)],
    );
  });

  test('reassignTank moves every series of the tank and restamps hlc', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final before = (await db.select(db.tankPressureSeries).get()).single.hlc;
    expect(await repo.reassignTank('dive-1', 'tank-a', 'tank-b', now: 2000), 1);
    final row = (await db.select(db.tankPressureSeries).get()).single;
    expect(row.id, id);
    expect(row.tankId, 'tank-b');
    expect(row.updatedAt, 2000);
    expect(row.hlc, isNot(before));
    expect(await repo.reassignTank('dive-1', 'tank-a', 'tank-b'), 0);
  });

  test('swapTanks exchanges the tank ids of both sets', () async {
    final a = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final b = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
      now: 1000,
    );
    await repo.swapTanks('dive-1', 'tank-a', 'tank-b', now: 2000);
    final rows = await db.select(db.tankPressureSeries).get();
    expect(rows.firstWhere((r) => r.id == a).tankId, 'tank-b');
    expect(rows.firstWhere((r) => r.id == b).tankId, 'tank-a');
  });

  test('stampComputerWhereNull touches only null-computer series', () async {
    final manual = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final owned = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      computerId: 'comp-1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
      now: 1000,
    );
    expect(await repo.stampComputerWhereNull('dive-1', 'comp-1', now: 2000), 1);
    final rows = await db.select(db.tankPressureSeries).get();
    expect(rows.firstWhere((r) => r.id == manual).computerId, 'comp-1');
    expect(rows.firstWhere((r) => r.id == manual).updatedAt, 2000);
    expect(rows.firstWhere((r) => r.id == owned).updatedAt, 1000);
  });

  test('deleteByIds and getRowsForDives', () async {
    final a = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final b = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
      now: 1000,
    );
    expect((await repo.getRowsForDives(['dive-1'])).map((r) => r.id), [a, b]);
    expect(await repo.getRowsForDives(const []), isEmpty);
    expect(await repo.deleteByIds(const []), isEmpty);
    expect(await repo.deleteByIds([a]), [a]);
    expect((await repo.getRowsForDives(['dive-1'])).map((r) => r.id), [b]);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.single.entityType, 'tankPressureSeries');
    expect(tombstones.single.recordId, a);
  });
}
```

Check the exact `DivesCompanion.insert` / `DiveComputersCompanion.insert` / `DiveDataSourcesCompanion.insert` / `DiveTanksCompanion.insert` required parameters against `test/features/dive_log/data/repositories/profile_series_repository_test.dart` (2a) and copy its fixture style if the ones above do not compile; the assertions are the contract, the fixture is not.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/codecs/sample_shift_test.dart`, then the two repository files.
Expected: compile errors naming `shiftedBy`, `hasAnySeries`, `ownsAny`, `adoptUnattributed`, `deleteByComputer`, `deleteByIds`, `getRowsForDives`, `reassignTank`, `swapTanks`, `stampComputerWhereNull`, the `database:` parameters.

- [ ] **Step 3: Implement**

`lib/core/data/repositories/sync_repository.dart`: replace the `_db` getter with

```dart
  SyncRepository({AppDatabase? database}) : _database = database;

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
```

(keep every other field; if the class already declares an explicit constructor, extend it with the named parameter instead of adding a second one).

`lib/features/dive_log/domain/codecs/profile_sample.dart`: add to `ProfileSample`

```dart
  /// The same sample [seconds] later (negative moves it earlier). Merge and
  /// consolidation re-base a segment's samples onto the combined timeline.
  ProfileSample shiftedBy(int seconds) => ProfileSample(
    timestamp: timestamp + seconds,
    depth: depth,
    pressure: pressure,
    temperature: temperature,
    heartRate: heartRate,
    ascentRate: ascentRate,
    ceiling: ceiling,
    ndl: ndl,
    setpoint: setpoint,
    ppO2: ppO2,
    o2Sensor1: o2Sensor1,
    o2Sensor2: o2Sensor2,
    o2Sensor3: o2Sensor3,
    o2Sensor4: o2Sensor4,
    o2Sensor5: o2Sensor5,
    o2Sensor6: o2Sensor6,
    cns: cns,
    tts: tts,
    rbt: rbt,
    decoType: decoType,
    heartRateSource: heartRateSource,
    heading: heading,
    o2SensorMv1: o2SensorMv1,
    o2SensorMv2: o2SensorMv2,
    o2SensorMv3: o2SensorMv3,
    o2SensorMv4: o2SensorMv4,
    o2SensorMv5: o2SensorMv5,
    o2SensorMv6: o2SensorMv6,
  );
```

(name every one of the 28 fields; check the constructor's parameter names in the file and match them exactly).

`lib/features/dive_log/domain/codecs/tank_pressure_series_codec.dart`, on `TankPressureSample`:

```dart
  TankPressureSample shiftedBy(int seconds) =>
      TankPressureSample(timestamp: timestamp + seconds, pressure: pressure);
```

`lib/features/dive_log/data/repositories/profile_series_repository.dart`:

```dart
  ProfileSeriesRepository({
    SyncRepository? syncRepository,
    AppDatabase? database,
  }) : _syncRepository = syncRepository ?? SyncRepository(database: database),
       _database = database;

  final AppDatabase? _database;
  AppDatabase get _db => _database ?? DatabaseService.instance.database;
```

In `insertSeries`, replace `_codec.encode(dedupeExactSamples(samples))` with `_codec.encode(dedupeExactSamples(_sortedByTimestamp(samples)))` and add

```dart
  /// Timestamp order, ties in input order. Every writer hands over whatever
  /// order it has; the codec and every reader assume ascending timestamps.
  static List<ProfileSample> _sortedByTimestamp(List<ProfileSample> samples) {
    final indexed = [for (var i = 0; i < samples.length; i++) (samples[i].timestamp, i)];
    indexed.sort((a, b) {
      final byTime = a.$1.compareTo(b.$1);
      return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
    });
    return [for (final e in indexed) samples[e.$2]];
  }
```

New public methods (place them near the related existing ones):

```dart
  /// Whether [diveId] has any series row, primary or not. The writers use it
  /// where the legacy code counted `dive_profiles` rows.
  Future<bool> hasAnySeries(String diveId) async {
    final count = await (_db.selectOnly(_db.diveProfileSeries)
          ..addColumns([_db.diveProfileSeries.id.count()])
          ..where(_db.diveProfileSeries.diveId.equals(diveId)))
        .map((row) => row.read(_db.diveProfileSeries.id.count()))
        .getSingle();
    return (count ?? 0) > 0;
  }

  /// Whether the source identified by [sourceId] / [computerId] owns at least
  /// one series of [diveId]: the FK first, then the legacy null-source
  /// computer rule (the same predicate every ownership write uses).
  Future<bool> ownsAny(
    String diveId, {
    required String? sourceId,
    required String? computerId,
  }) async {
    final count = await (_db.selectOnly(_db.diveProfileSeries)
          ..addColumns([_db.diveProfileSeries.id.count()])
          ..where(
            _db.diveProfileSeries.diveId.equals(diveId) &
                _ownedBy(
                  _db.diveProfileSeries,
                  sourceId: sourceId,
                  computerId: computerId,
                ),
          ))
        .map((row) => row.read(_db.diveProfileSeries.id.count()))
        .getSingle();
    return (count ?? 0) > 0;
  }

  /// Stamps [sourceId] on every series of [diveId] that has no source yet
  /// (the first `dive_data_sources` row of a dive adopts the unattributed
  /// profile, issue #1149). Returns the number of series stamped.
  Future<int> adoptUnattributed(
    String diveId,
    String sourceId, {
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final ids = await _ids(
      (t) => t.diveId.equals(diveId) & t.sourceId.isNull(),
    );
    if (ids.isEmpty) return 0;
    await _db.transaction(() async {
      await (_db.update(_db.diveProfileSeries)..where((t) => t.id.isIn(ids)))
          .write(
            DiveProfileSeriesCompanion(
              sourceId: Value(sourceId),
              updatedAt: Value(nowMs),
            ),
          );
      for (final id in ids) {
        await _markPending(id, nowMs);
      }
    });
    return ids.length;
  }

  /// Deletes the series [computerId] contributed to [diveId]; a null
  /// [computerId] matches the null-computer (manual or file) series only.
  /// One tombstone per series. Returns the deleted ids.
  Future<List<String>> deleteByComputer(String diveId, String? computerId) =>
      _delete(
        (t) =>
            t.diveId.equals(diveId) &
            (computerId == null
                ? t.computerId.isNull()
                : t.computerId.equals(computerId)),
      );

  /// Deletes exactly [ids], one tombstone each. Empty input is a no-op.
  Future<List<String>> deleteByIds(List<String> ids) =>
      ids.isEmpty ? Future.value(const []) : _delete((t) => t.id.isIn(ids));

  /// Raw rows of every series of [diveIds], undecoded, for snapshots that
  /// restore them verbatim through [restoreSeriesRow].
  Future<List<DiveProfileSeriesRow>> getRowsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    return (_db.select(_db.diveProfileSeries)
          ..where((t) => t.diveId.isIn(diveIds))
          ..orderBy([
            (t) => OrderingTerm.asc(t.diveId),
            (t) => OrderingTerm.asc(t.startTimestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }
```

`lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart`: the same constructor shape (`{SyncRepository? syncRepository, AppDatabase? database}`, `_database`, `_db` getter); in `insertSeries` sort before dedupe with a `_sortedByTimestamp` twin over `TankPressureSample`; and

```dart
  Future<List<TankPressureSeriesRow>> getRowsForDives(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return const [];
    return (_db.select(_db.tankPressureSeries)
          ..where((t) => t.diveId.isIn(diveIds))
          ..orderBy([
            (t) => OrderingTerm.asc(t.diveId),
            (t) => OrderingTerm.asc(t.tankId),
            (t) => OrderingTerm.asc(t.startTimestamp),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  /// Points every series of [fromTankId] on [diveId] at [toTankId] (the
  /// wrong-cylinder repair). Returns the number of series moved.
  Future<int> reassignTank(
    String diveId,
    String fromTankId,
    String toTankId, {
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final ids = await _ids(
      (t) => t.diveId.equals(diveId) & t.tankId.equals(fromTankId),
    );
    if (ids.isEmpty) return 0;
    await _retarget(ids, toTankId, nowMs);
    return ids.length;
  }

  /// Exchanges the tank ids of the two series sets (the swapped-cylinders
  /// repair). Both sets are read before either is written.
  Future<void> swapTanks(
    String diveId,
    String tankIdA,
    String tankIdB, {
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final aIds = await _ids(
      (t) => t.diveId.equals(diveId) & t.tankId.equals(tankIdA),
    );
    final bIds = await _ids(
      (t) => t.diveId.equals(diveId) & t.tankId.equals(tankIdB),
    );
    await _db.transaction(() async {
      if (aIds.isNotEmpty) await _retarget(aIds, tankIdB, nowMs);
      if (bIds.isNotEmpty) await _retarget(bIds, tankIdA, nowMs);
    });
  }

  /// Stamps [computerId] on the null-computer series of [diveId]
  /// (consolidation gives the target's unattributed pressures to its primary
  /// computer). Returns the number of series stamped.
  Future<int> stampComputerWhereNull(
    String diveId,
    String computerId, {
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final ids = await _ids(
      (t) => t.diveId.equals(diveId) & t.computerId.isNull(),
    );
    if (ids.isEmpty) return 0;
    await _db.transaction(() async {
      await (_db.update(_db.tankPressureSeries)..where((t) => t.id.isIn(ids)))
          .write(
            TankPressureSeriesCompanion(
              computerId: Value(computerId),
              updatedAt: Value(nowMs),
            ),
          );
      for (final id in ids) {
        await _markPending(id, nowMs);
      }
    });
    return ids.length;
  }

  Future<List<String>> deleteByIds(List<String> ids) =>
      ids.isEmpty ? Future.value(const []) : _delete((t) => t.id.isIn(ids));

  Future<void> _retarget(List<String> ids, String tankId, int nowMs) async {
    await _db.transaction(() async {
      await (_db.update(_db.tankPressureSeries)..where((t) => t.id.isIn(ids)))
          .write(
            TankPressureSeriesCompanion(
              tankId: Value(tankId),
              updatedAt: Value(nowMs),
            ),
          );
      for (final id in ids) {
        await _markPending(id, nowMs);
      }
    });
  }

  Future<List<String>> _ids(
    Expression<bool> Function($TankPressureSeriesTable t) where,
  ) async {
    final rows = await (_db.selectOnly(_db.tankPressureSeries)
          ..addColumns([_db.tankPressureSeries.id])
          ..where(where(_db.tankPressureSeries)))
        .get();
    return [for (final r in rows) r.read(_db.tankPressureSeries.id)!];
  }
```

If the tank repository already has a `_markPending` or `_ids` helper, reuse it rather than adding a second. The profile repository's `_markPending` and `_ids` exist already.

- [ ] **Step 4: Run the tests to verify they pass**

Run the three new files, then the existing `profile_series_repository_test.dart`, `profile_series_repository_restore_test.dart`, `tank_pressure_series_repository_test.dart`, `profile_series_codec_test.dart` (find it under `test/features/dive_log/domain/codecs/`), and `test/core/data/repositories/sync_repository_test.dart` if it exists.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/data/repositories/sync_repository.dart lib/features/dive_log/data/repositories/profile_series_repository.dart lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart lib/features/dive_log/domain/codecs/profile_sample.dart lib/features/dive_log/domain/codecs/tank_pressure_series_codec.dart test/features/dive_log/data/repositories/profile_series_repository_writers_test.dart test/features/dive_log/data/repositories/tank_pressure_series_repository_writers_test.dart test/features/dive_log/domain/codecs/sample_shift_test.dart
git commit -m "feat(series): writer operations on the series repositories, database injection, stable sort on insert"
```

---

### Task 2: DiveRepository writers (createDive, saveEditedProfile, restoreOriginalProfile, saveComputerReading, setPrimaryDataSource)

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`createDive` profile batch; `saveEditedProfile`; `restoreOriginalProfile`; `_adoptUnattributedProfiles`; `setPrimaryDataSource`; delete `_sourceOwnsProfiles`, `_promoteProfilesOwnedBySource`, `_ownedBySourceSql`, `_ownershipVars`)
- Test: `test/features/dive_log/data/repositories/dive_repository_series_writes_test.dart` (new)
- Modify tests (rules R1 to R6): `test/features/dive_log/data/repositories/dive_repository_test.dart`, `dive_repository_new_methods_test.dart` (legacy helper `insertTestProfile` near line 162), `edited_profile_supersedes_originals_test.dart`, `dive_consolidation_test.dart` (helper `insertTestProfile` near line 118; the recursive `INSERT INTO dive_profiles` test near line 1305), `test/features/dive_log/integration/multi_computer_integration_test.dart`, `dive_computer_data_repository_test.dart`, `dive_repository_error_test.dart`.

**Interfaces:**
- Consumes (Task 1 and earlier): `ProfileSeriesRepository.insertSeries({diveId, computerId, sourceId, isPrimary, samples, id, now})`, `demoteAll(diveId, {now})`, `deleteEditedSeries(diveId)`, `promoteByComputer(diveId, computerId, {now})`, `promoteAll(diveId, {now})`, `promoteWinnerOwnedBy(diveId, {sourceId, computerId, now})`, `ownsAny(diveId, {sourceId, computerId})`, `adoptUnattributed(diveId, sourceId, {now})`; `profileSampleFromPoint(DiveProfilePoint point, {double? pressure})` from `codecs/profile_sample_point.dart`; the existing `_profileSeries` field (plan 2b).
- Produces: nothing new for later tasks; `_sourceOwnsProfiles`, `_promoteProfilesOwnedBySource`, `_ownedBySourceSql`, `_ownershipVars` are GONE (grep the file and the tests for other callers first; if `_ownedBySourceSql` is used by a read that plan 2d owns, leave that read alone and delete only what becomes unused).

- [ ] **Step 1: Write the failing test**

`test/features/dive_log/data/repositories/dive_repository_series_writes_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late ProfileSeriesRepository series;

  Future<void> computer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: id,
            name: 'Comp $id',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> source(
    String id,
    String diveId,
    String? computerId, {
    bool primary = false,
  }) async {
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            computerId: Value(computerId),
            isPrimary: Value(primary),
            importedAt: now,
            createdAt: now,
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    series = ProfileSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase(db);
  });

  domain.Dive dive(String id, List<domain.DiveProfilePoint> profile) =>
      domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), profile: profile);

  test('createDive writes one primary null-identity series and no legacy rows', () async {
    await dives.createDive(
      dive('dive-1', const [
        domain.DiveProfilePoint(timestamp: 10, depth: 5.0),
        domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
      ]),
    );
    final rows = await series.getSeriesForDive('dive-1');
    expect(rows, hasLength(1));
    expect(rows.single.isPrimary, isTrue);
    expect(rows.single.computerId, isNull);
    expect(rows.single.sourceId, isNull);
    expect(rows.single.samples.map((s) => s.timestamp), [0, 10]);
    expect(await db.select(db.diveProfiles).get(), isEmpty);
  });

  test('createDive with no profile writes no series row', () async {
    await dives.createDive(dive('dive-1', const []));
    expect(await series.getSeriesForDive('dive-1'), isEmpty);
  });

  test('saveEditedProfile demotes every series and inserts the edit under the primary source', () async {
    await dives.createDive(dive('dive-1', const [domain.DiveProfilePoint(timestamp: 0, depth: 1.0)]));
    await computer('comp-1');
    await source('src-1', 'dive-1', 'comp-1', primary: true);
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    await dives.saveEditedProfile('dive-1', const [
      domain.DiveProfilePoint(timestamp: 0, depth: 9.0),
      domain.DiveProfilePoint(timestamp: 5, depth: 8.0),
    ]);
    final rows = await series.getSeriesForDive('dive-1');
    final primary = rows.where((s) => s.isPrimary).toList();
    expect(primary, hasLength(1));
    expect(primary.single.computerId, isNull);
    expect(primary.single.sourceId, 'src-1');
    expect(primary.single.samples.map((s) => s.depth), [9.0, 8.0]);
    expect(rows.where((s) => !s.isPrimary), hasLength(2));
    expect((await dives.getDiveProfile('dive-1')).map((p) => p.depth), [9.0, 8.0]);
    final row = await (db.select(db.dives)..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(row.maxDepth, 9.0);
    expect(await db.select(db.diveProfiles).get(), isEmpty);
  });

  test('restoreOriginalProfile deletes the edit and re-promotes the primary computer only', () async {
    await computer('comp-1');
    await computer('comp-2');
    await dives.createDive(dive('dive-1', const []));
    await source('src-1', 'dive-1', 'comp-1', primary: true);
    await source('src-2', 'dive-1', 'comp-2');
    final a = await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final b = await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      sourceId: 'src-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    final edit = await series.insertSeries(
      diveId: 'dive-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
      now: 1000,
    );
    await dives.restoreOriginalProfile('dive-1');
    final rows = await series.getSeriesForDive('dive-1');
    expect(rows.map((s) => s.id).toSet(), {a, b});
    expect(rows.firstWhere((s) => s.id == a).isPrimary, isTrue);
    expect(rows.firstWhere((s) => s.id == b).isPrimary, isFalse);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => t.recordId), [edit]);
  });

  test('restoreOriginalProfile on a single-computer dive promotes everything left', () async {
    await dives.createDive(dive('dive-1', const []));
    await series.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    await series.insertSeries(
      diveId: 'dive-1',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 5, depth: 2.0)],
      now: 1000,
    );
    await dives.restoreOriginalProfile('dive-1');
    expect((await series.getSeriesForDive('dive-1')).every((s) => s.isPrimary), isTrue);
  });

  test('saveComputerReading adopts the unattributed series of a single-source dive', () async {
    await computer('comp-1');
    await dives.createDive(dive('dive-1', const [domain.DiveProfilePoint(timestamp: 0, depth: 1.0)]));
    await dives.saveComputerReading(
      DiveDataSourcesCompanion.insert(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: const Value('comp-1'),
        isPrimary: const Value(true),
        importedAt: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    );
    expect((await series.getSeriesForDive('dive-1')).single.sourceId, 'src-1');
  });

  test('setPrimaryDataSource promotes the winner series owned by the new primary', () async {
    await computer('comp-1');
    await computer('comp-2');
    await dives.createDive(dive('dive-1', const []));
    await source('src-1', 'dive-1', 'comp-1', primary: true);
    await source('src-2', 'dive-1', 'comp-2');
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final b = await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      sourceId: 'src-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    await dives.setPrimaryDataSource(diveId: 'dive-1', computerReadingId: 'src-2');
    final rows = await series.getSeriesForDive('dive-1');
    expect(rows.where((s) => s.isPrimary).map((s) => s.id), [b]);
    expect((await dives.getDiveProfile('dive-1')).single.depth, 2.0);
  });

  test('setPrimaryDataSource leaves the flags alone when the new primary owns nothing', () async {
    await computer('comp-1');
    await computer('comp-2');
    await dives.createDive(dive('dive-1', const []));
    await source('src-1', 'dive-1', 'comp-1', primary: true);
    await source('src-2', 'dive-1', 'comp-2');
    final a = await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    await dives.setPrimaryDataSource(diveId: 'dive-1', computerReadingId: 'src-2');
    expect((await series.getSeriesForDive('dive-1')).single.id, a);
    expect((await series.getSeriesForDive('dive-1')).single.isPrimary, isTrue);
  });
}
```

Adapt the `domain.Dive` constructor call to its required parameters (read `lib/features/dive_log/domain/entities/dive.dart`; `dive_repository_series_reads_test.dart` from plan 2b shows a working construction). The assertions are the contract.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_series_writes_test.dart`
Expected: the `createDive` tests fail on `getSeriesForDive` being empty (rows land in `dive_profiles`); the edit/restore/adopt/promote tests fail on flags that never changed.

- [ ] **Step 3: Move the five sites**

Add the import `package:submersion/features/dive_log/domain/codecs/profile_sample_point.dart` (for `profileSampleFromPoint`) next to the existing series imports.

`createDive`: delete the `for (final point in dive.profile) { batch.insert(_db.diveProfiles, ...) }` loop from the child-row batch (the comment above it too). After the batch completes add:

```dart
      // Profile samples: one packed primary series with no computer and no
      // source, the same identity the legacy rows carried for a manual dive.
      if (dive.profile.isNotEmpty) {
        await _profileSeries.insertSeries(
          diveId: id,
          samples: [for (final point in dive.profile) profileSampleFromPoint(point)],
          now: now,
        );
      }
```

`saveEditedProfile`, inside the existing `_db.transaction`: replace the "Demote all existing profiles" `update(_db.diveProfiles)` statement and the whole `_db.batch` insert with

```dart
        // Demote every series, then the edit becomes the one primary series
        // of the dive: no computer (a manual correction), owned by the source
        // that was primary at the time (issue #1149).
        await _profileSeries.demoteAll(diveId, now: now);
        if (editedPoints.isNotEmpty) {
          await _profileSeries.insertSeries(
            diveId: diveId,
            sourceId: primarySource?.id,
            isPrimary: true,
            samples: [for (final point in editedPoints) profileSampleFromPoint(point)],
            now: now,
          );
        }
```

Keep the `primarySource` lookup, the stats recomputation and everything after the transaction unchanged.

`restoreOriginalProfile`, inside the existing transaction: keep the legacy `delete(_db.diveProfiles)` of edited rows exactly as it is (rule: legacy deletes stay) and add directly after it `await _profileSeries.deleteEditedSeries(diveId);`. Replace the two `update(_db.diveProfiles)` promote statements with

```dart
        if (primaryComputerId != null) {
          // Multi-computer dive: only the previously-primary computer's
          // series come back.
          await _profileSeries.promoteByComputer(diveId, primaryComputerId);
        } else {
          // Single-computer dive (or no computer reading): everything left is
          // the live profile.
          await _profileSeries.promoteAll(diveId);
        }
```

`_adoptUnattributedProfiles`: replace the `update(_db.diveProfiles)` statement with `await _profileSeries.adoptUnattributed(diveId, reading.id.value);`.

`setPrimaryDataSource`: replace

```dart
        if (await _sourceOwnsProfiles(diveId, newPrimary)) {
          await (_db.update(_db.diveProfiles)
                ..where((t) => t.diveId.equals(diveId)))
              .write(const DiveProfilesCompanion(isPrimary: Value(false)));
          await _promoteProfilesOwnedBySource(diveId, newPrimary);
        }
```

with

```dart
        // Flip the profile flags only when the new primary owns samples;
        // otherwise the current primary profile stays on display (#1149).
        if (await _profileSeries.ownsAny(
          diveId,
          sourceId: newPrimary.id,
          computerId: newPrimary.computerId,
        )) {
          await _profileSeries.demoteAll(diveId, now: now);
          await _profileSeries.promoteWinnerOwnedBy(
            diveId,
            sourceId: newPrimary.id,
            computerId: newPrimary.computerId,
            now: now,
          );
        }
```

Then delete `_sourceOwnsProfiles` and `_promoteProfilesOwnedBySource`, and `_ownedBySourceSql` / `_ownershipVars` if nothing else in the file uses them (`grep -n "_ownedBySourceSql\|_ownershipVars" lib/features/dive_log/data/repositories/dive_repository_impl.dart`; if a remaining caller is a READ over `dive_profiles`, leave the constant and the read alone, plan 2d owns them).

- [ ] **Step 4: Run the new test, then migrate the existing tests**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_series_writes_test.dart`
Expected: PASS.

Then run each file below and apply the rules:

- `dive_repository_new_methods_test.dart`: add the `insertTestSeries` twin beside `insertTestProfile` (same parameters: `diveId`, `sourceTag`, `isPrimary`, `timestamp`, `depth`, `computerId`; keep returning the deterministic id by passing `id:`). Switch every test that calls `restoreOriginalProfile`, `setPrimaryDataSource`, `saveComputerReading` or `saveEditedProfile` to the twin (R1) and convert their legacy-row assertions (R2, R3). Tests that only READ after seeding stay on the legacy helper (the 2b fallback covers them until plan 2e).
- `dive_consolidation_test.dart`: same twin beside its `insertTestProfile` (parameters `diveId`, `sourceTag`, `sourceId`, `isPrimary`, `timestamp`, `depth`). Tests calling `setPrimaryDataSource` / `saveComputerReading` / `saveEditedProfile` switch (R1, R2, R3). The 32767-row recursive `INSERT INTO dive_profiles` test (near line 1305) becomes one series: `await ProfileSeriesRepository().insertSeries(diveId: diveId, sourceId: 'reading-b', isPrimary: false, samples: [for (var n = 0; n < sampleCount; n++) ProfileSample(timestamp: n, depth: 10.0)], now: 1000);` and the count assertion becomes `expect((await ProfileSeriesRepository().getSeriesForDive(diveId, primaryOnly: true)).single.samples, hasLength(sampleCount));`. Tests that call `DiveSplitService` stay on the legacy helper until Task 6.
- `edited_profile_supersedes_originals_test.dart`, `multi_computer_integration_test.dart`, `dive_repository_test.dart`, `dive_computer_data_repository_test.dart`, `dive_repository_error_test.dart`: run each; apply R1 to R6 to the tests that exercise the five moved writers; leave the rest.

Run: each migrated file with `flutter test <path>`, plus `dive_repository_series_reads_test.dart`, `profiles_by_data_source_test.dart`, `profiles_by_data_source_series_test.dart`, `dive_profile_duplicate_rows_test.dart`, `canonical_data_sources_test.dart`, `test/features/dive_log/presentation/providers/dive_providers_test.dart`.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_series_writes_test.dart <every migrated test file by path>
git commit -m "feat(series): DiveRepository writes profile series (create, edit, restore, adopt, primary swap)"
```

---

### Task 3: DiveComputerRepository writers (importProfile, setPrimaryProfile, clearSourceAndProfiles)

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`importProfile`: the `hasProfiles` count, the profile batch, the tank-pressure batch; `setPrimaryProfile`; `clearSourceAndProfiles`)
- Test: `test/features/dive_log/data/repositories/dive_computer_repository_series_writes_test.dart` (new)
- Modify tests (rules R1 to R6): `test/features/dive_log/data/repositories/dive_computer_repository_impl_test.dart` (legacy helper `insertProfile` near line 89; the test near line 394 about nulling `dive_profiles` FK references on computer delete is plan 2d's and stays on the legacy helper), `dive_computer_repository_import_attribution_test.dart`, `dive_computer_multi_transmitter_pressure_test.dart`, `test/features/dive_computer/data/services/raw_data_persistence_test.dart` (helpers `insertProfile` / `insertTankPressure` near lines 85 and 125; its "tables are empty after clear" assertions stay (R5) and gain series twins), `replace_source_gear_link_test.dart`, `test/features/dive_computer/data/services/dive_import_service_test.dart`, `dive_computer_repository_error_test.dart`, `dive_computer_altitude_enrichment_test.dart`.

**Interfaces:**
- Consumes: `ProfileSeriesRepository.hasAnySeries`, `insertSeries`, `demoteAll`, `promoteByComputer`, `deleteByComputer`; `TankPressureSeriesRepository.insertSeries({diveId, tankId, computerId, samples, id, now})`, `deleteForDive`; `groupPressuresByTank` (existing); `ProfilePointData` (existing, this file).
- Produces: a private `static codec.ProfileSample _sampleFromPointData(ProfilePointData p)` in this file; a `_tankSeries` field. Nothing for later tasks.

- [ ] **Step 1: Write the failing test**

`test/features/dive_log/data/repositories/dive_computer_repository_series_writes_test.dart` (reuse the fixture helpers of `dive_computer_repository_impl_test.dart` for computers and dives; the `importProfile` call shape is in that file too):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveComputerRepository computers;
  late ProfileSeriesRepository series;
  late TankPressureSeriesRepository tankSeries;

  Future<void> insertComputer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Computer $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    computers = DiveComputerRepository();
    series = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
    await insertComputer('comp-1');
    await insertComputer('comp-2');
  });

  tearDown(() async {
    await tearDownTestDatabase(db);
  });

  // isPrimary is passed false on purpose: a dive with no series makes the
  // import primary regardless (the legacy `hasProfiles == 0` rule).
  Future<String> importDive({String computerId = 'comp-1'}) =>
      computers.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 1, 1, 10),
        points: const [
          ProfilePointData(timestamp: 30, depth: 10.0, pressure: 190.0, tankIndex: 0),
          ProfilePointData(timestamp: 0, depth: 0.0, pressure: 200.0, tankIndex: 0),
        ],
        durationSeconds: 60,
        maxDepth: 10.0,
        isPrimary: false,
        tanks: const [TankData(index: 0, o2Percent: 21.0)],
      );

  test('a first import writes one primary series owned by the computer and its source, and one tank series', () async {
    final diveId = await importDive();
    final rows = await series.getSeriesForDive(diveId);
    expect(rows, hasLength(1));
    expect(rows.single.isPrimary, isTrue);
    expect(rows.single.computerId, 'comp-1');
    expect(rows.single.sourceId, isNotNull);
    expect(rows.single.samples.map((s) => s.timestamp), [0, 30]);
    expect(await db.select(db.diveProfiles).get(), isEmpty);
    final tanks = await tankSeries.getSeriesForDive(diveId);
    expect(tanks, hasLength(1));
    expect(tanks.single.computerId, 'comp-1');
    expect(tanks.single.samples.map((s) => s.pressure), [200.0, 190.0]);
    expect(await db.select(db.tankPressureProfiles).get(), isEmpty);
  });

  test('setPrimaryProfile flips the flags by computer and writes no tombstone', () async {
    final diveId = await importDive();
    final second = await series.insertSeries(
      diveId: diveId,
      computerId: 'comp-2',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    await computers.setPrimaryProfile(diveId, 'comp-2');
    final rows = await series.getSeriesForDive(diveId);
    expect(rows.firstWhere((s) => s.id == second).isPrimary, isTrue);
    expect(rows.firstWhere((s) => s.id != second).isPrimary, isFalse);
    expect(await db.select(db.deletionLog).get(), isEmpty);
  });

  test('clearSourceAndProfiles deletes the computer profile series and every tank series of the dive', () async {
    final diveId = await importDive();
    final imported = (await series.getSeriesForDive(diveId)).single.id;
    final tank = (await tankSeries.getSeriesForDive(diveId)).single.id;
    final edit = await series.insertSeries(
      diveId: diveId,
      samples: const [ProfileSample(timestamp: 0, depth: 9.0)],
      now: 1000,
    );
    await computers.clearSourceAndProfiles(diveId: diveId, computerId: 'comp-1');
    expect((await series.getSeriesForDive(diveId)).map((s) => s.id), [edit]);
    expect(await tankSeries.getSeriesForDive(diveId), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => t.recordId).toSet(), {imported, tank});
    expect(await db.select(db.diveProfiles).get(), isEmpty);
    expect(await db.select(db.tankPressureProfiles).get(), isEmpty);
  });
}
```

Imports the file needs: `package:drift/drift.dart` (hide `isNull`), `flutter_test`, `database.dart`, `dive_computer_repository_impl.dart` (`DiveComputerRepository`, `ProfilePointData`, `TankData`), the two series repositories, `codecs/profile_sample.dart`, `codecs/tank_pressure_series_codec.dart`, `../../../../helpers/test_database.dart`. If `TankData` needs more required parameters than `index` and `o2Percent`, copy the construction from `dive_computer_repository_impl_test.dart`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_computer_repository_series_writes_test.dart`
Expected: fails on empty series lists and on `dive_profiles` / `tank_pressure_profiles` not being empty.

- [ ] **Step 3: Move the three sites**

Imports: `import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart' as codec;`, `import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart' show TankPressureSample;`, `import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';`. Field: `final TankPressureSeriesRepository _tankSeries = TankPressureSeriesRepository();` next to `_profileSeries`.

`importProfile`:
- Replace the `hasProfiles` `customSelect` count with `final hadSeries = await _profileSeries.hasAnySeries(diveId); if (!hadSeries) { isPrimary = true; }`.
- Replace the profile `_db.batch` with

```dart
      if (points.isNotEmpty) {
        await _profileSeries.insertSeries(
          diveId: diveId,
          computerId: computerId,
          sourceId: ownerSourceId,
          isPrimary: isPrimary,
          samples: [for (final point in points) _sampleFromPointData(point)],
        );
      }
```

- Replace the tank-pressure `_db.batch` (keep `pressuresByTank`, `insertEntries` and the log loop) with

```dart
        for (final entry in insertEntries) {
          if (entry.value.isEmpty) continue;
          await _tankSeries.insertSeries(
            diveId: diveId,
            tankId: tankIdsByIndex[entry.key]!,
            computerId: computerId,
            samples: [
              for (final point in entry.value)
                TankPressureSample(
                  timestamp: point.timestamp,
                  pressure: point.pressure,
                ),
            ],
          );
        }
```

- Add the mapper (a private static method of the class, or a top-level private function):

```dart
  static codec.ProfileSample _sampleFromPointData(ProfilePointData p) =>
      codec.ProfileSample(
        timestamp: p.timestamp,
        depth: p.depth,
        temperature: p.temperature,
        heartRate: p.heartRate,
        heading: p.heading,
        setpoint: p.setpoint,
        ppO2: p.ppO2,
        cns: p.cns,
        ndl: p.ndl,
        ceiling: p.ceiling,
        ascentRate: p.ascentRate,
        rbt: p.rbt,
        decoType: p.decoType,
        tts: p.tts,
        o2Sensor1: p.o2Sensor1,
        o2Sensor2: p.o2Sensor2,
        o2Sensor3: p.o2Sensor3,
        o2Sensor4: p.o2Sensor4,
        o2Sensor5: p.o2Sensor5,
        o2Sensor6: p.o2Sensor6,
        o2SensorMv1: p.o2SensorMv1,
        o2SensorMv2: p.o2SensorMv2,
        o2SensorMv3: p.o2SensorMv3,
        o2SensorMv4: p.o2SensorMv4,
        o2SensorMv5: p.o2SensorMv5,
        o2SensorMv6: p.o2SensorMv6,
      );
```

(the legacy row left `pressure` null; per-sample pressure lives in the tank series.)

`setPrimaryProfile`: replace the two `customStatement` updates and the `for (final profile in profiles) markRecordPending(entityType: 'diveProfiles', ...)` loop (and its `profiles` select) with

```dart
      await _profileSeries.demoteAll(diveId, now: now);
      await _profileSeries.promoteByComputer(diveId, computerId, now: now);
```

Keep the `dives.updatedAt` write, the `dives` `markRecordPending`, the notify and the logging.

`clearSourceAndProfiles`: keep all five legacy `customStatement` deletes. Directly after the `tank_pressure_profiles` delete add `await _tankSeries.deleteForDive(diveId);`; directly after the `dive_profiles` delete add `await _profileSeries.deleteByComputer(diveId, computerId);`.

- [ ] **Step 4: Run the new test, then migrate the existing tests**

Run the new file: PASS.

Then, per file: add the series twins beside the legacy helpers (R1); switch every test that calls `importProfile`, `setPrimaryProfile` or `clearSourceAndProfiles` and then asserts on `dive_profiles` / `tank_pressure_profiles` rows (R2, R3, R4, R5). In `raw_data_persistence_test.dart` the assertions that the legacy tables are empty after `clearSourceAndProfiles` stay and gain `expect(await tankSeries.getSeriesForDive(diveId), isEmpty)` / profile twins beside them. Leave the computer-delete FK test in `dive_computer_repository_impl_test.dart` on the legacy helper.

Run: every file in the Files list, plus `dive_computer_series_reads_test.dart`, `dive_computer_repository_error_test.dart`, `test/features/dive_log/integration/multi_computer_integration_test.dart`.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart test/features/dive_log/data/repositories/dive_computer_repository_series_writes_test.dart <every migrated test file by path>
git commit -m "feat(series): DiveComputerRepository writes profile and tank series on import, primary swap and clear"
```

---

### Task 4: TankPressureRepository writers

**Files:**
- Modify: `lib/features/dive_log/data/repositories/tank_pressure_repository.dart` (`insertTankPressures`, `deleteTankPressuresForDive`, `reassignTankPressureSeries`, `swapTankPressureSeries`; `replaceTankPressures` composes the two and needs no edit)
- Test: `test/features/dive_log/data/repositories/tank_pressure_repository_series_writes_test.dart` (new)
- Verify (no legacy references, should pass unchanged): `test/features/data_quality/repairs/tank_pressure_repairs_test.dart`, `test/features/data_quality/repairs/quality_repair_executor_test.dart`, `test/features/dive_import/data/services/uddf_entity_importer_test.dart`, `test/features/dive_log/presentation/pages/dive_edit_preserves_sac_widget_test.dart`, `test/features/settings/presentation/providers/load_tank_pressures_test.dart`, `test/features/dive_log/data/repositories/tank_pressure_series_reads_test.dart`, `test/integration/uddf_round_trip_test.dart`.

**Interfaces:**
- Consumes: `TankPressureSeriesRepository.insertSeries`, `deleteForDive`, `reassignTank`, `swapTanks`; `TankPressureSample`.
- Produces: nothing new. The public signatures of the four methods are unchanged (`Map<String, List<({int timestamp, double pressure})>>` in, `void` out).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TankPressureRepository repo;
  late TankPressureSeriesRepository series;

  setUp(() async {
    db = await setUpTestDatabase();
    // seed dive 'dive-1' and tanks 'tank-a', 'tank-b' exactly as
    // tank_pressure_series_repository_test.dart does
    repo = TankPressureRepository();
    series = TankPressureSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase(db);
  });

  test('insertTankPressures writes one null-computer series per tank and skips empty tanks', () async {
    await repo.insertTankPressures('dive-1', {
      'tank-a': [(timestamp: 60, pressure: 180.0), (timestamp: 0, pressure: 200.0)],
      'tank-b': const [],
    });
    final rows = await series.getSeriesForDive('dive-1');
    expect(rows, hasLength(1));
    expect(rows.single.tankId, 'tank-a');
    expect(rows.single.computerId, isNull);
    expect(rows.single.samples.map((s) => s.pressure), [200.0, 180.0]);
    expect(await db.select(db.tankPressureProfiles).get(), isEmpty);
    final dive = await (db.select(db.dives)..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(dive.updatedAt, greaterThan(0));
  });

  test('deleteTankPressuresForDive removes every series with one tombstone each and no legacy tombstones', () async {
    final a = await series.insertSeries(diveId: 'dive-1', tankId: 'tank-a', samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)], now: 1000);
    final b = await series.insertSeries(diveId: 'dive-1', tankId: 'tank-b', samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)], now: 1000);
    await repo.deleteTankPressuresForDive('dive-1');
    expect(await series.getSeriesForDive('dive-1'), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => t.recordId).toSet(), {a, b});
    expect(tombstones.map((t) => t.entityType).toSet(), {'tankPressureSeries'});
  });

  test('replaceTankPressures deletes then inserts', () async {
    await series.insertSeries(diveId: 'dive-1', tankId: 'tank-a', samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)], now: 1000);
    await repo.replaceTankPressures('dive-1', {
      'tank-b': [(timestamp: 0, pressure: 150.0)],
    });
    final rows = await series.getSeriesForDive('dive-1');
    expect(rows.single.tankId, 'tank-b');
    expect(rows.single.samples.single.pressure, 150.0);
  });

  test('reassignTankPressureSeries and swapTankPressureSeries move series between tanks', () async {
    final a = await series.insertSeries(diveId: 'dive-1', tankId: 'tank-a', samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)], now: 1000);
    await repo.reassignTankPressureSeries(diveId: 'dive-1', fromTankId: 'tank-a', toTankId: 'tank-b');
    expect((await series.getSeriesForTank('dive-1', 'tank-b')).single.id, a);
    final b = await series.insertSeries(diveId: 'dive-1', tankId: 'tank-a', samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)], now: 1000);
    await repo.swapTankPressureSeries(diveId: 'dive-1', tankIdA: 'tank-a', tankIdB: 'tank-b');
    expect((await series.getSeriesForTank('dive-1', 'tank-a')).single.id, a);
    expect((await series.getSeriesForTank('dive-1', 'tank-b')).single.id, b);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/tank_pressure_repository_series_writes_test.dart`
Expected: fails on empty series lists (rows land in `tank_pressure_profiles`).

- [ ] **Step 3: Move the four sites**

Add `import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';` and `import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart' show TankPressureSample;`; field `final TankPressureSeriesRepository _tankSeries = TankPressureSeriesRepository();`.

`insertTankPressures`: replace the `_db.batch` with

```dart
    for (final entry in pressuresByTank.entries) {
      if (entry.value.isEmpty) continue;
      await _tankSeries.insertSeries(
        diveId: diveId,
        tankId: entry.key,
        samples: [
          for (final point in entry.value)
            TankPressureSample(timestamp: point.timestamp, pressure: point.pressure),
        ],
        now: now,
      );
    }
```

Keep the `pressuresByTank.isEmpty` early return, the dive touch, the `dives` `markRecordPending` and the notify.

`deleteTankPressuresForDive`: delete the `existing` select and the `for (final row in existing) logDeletion(entityType: 'tankPressureProfiles', ...)` loop; keep the legacy `delete(_db.tankPressureProfiles)`; add `await _tankSeries.deleteForDive(diveId);` after it. Keep the touch, mark and notify.

`reassignTankPressureSeries`: replace the `update(_db.tankPressureProfiles)` with `await _tankSeries.reassignTank(diveId, fromTankId, toTankId, now: now);` keep `_touchDive`.

`swapTankPressureSeries`: replace the two id selects and two updates with `await _tankSeries.swapTanks(diveId, tankIdA, tankIdB, now: now);` keep `_touchDive`.

Remove the `_uuid` field if nothing uses it any more (analyze will say).

- [ ] **Step 4: Run the tests**

Run the new file and every file in the Verify list, plus `tank_pressure_series_repository_test.dart`.
Expected: all pass. `tank_pressure_repairs_test.dart` seeds through `insertTankPressures`, so it exercises the series path end to end.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/tank_pressure_repository.dart test/features/dive_log/data/repositories/tank_pressure_repository_series_writes_test.dart
git commit -m "feat(series): TankPressureRepository writes tank pressure series"
```

---

### Task 5: ReparseService writers

**Files:**
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (constructor; `_replaceDiveProfiles`; the tank-pressure clear near line 138; `_replaceTankPressureProfiles`)
- Test: `test/features/dive_computer/data/services/reparse_service_series_test.dart` (new)
- Modify tests (R1 to R6): `test/features/dive_computer/data/services/reparse_service_test.dart` (legacy helper `insertProfile` near line 123, tank seeds near line 1640; it builds its own `AppDatabase(NativeDatabase.memory())` and passes `db:`), `reparse_service_surfacing_test.dart` (no legacy references; verify), `test/features/dive_log/data/services/dive_consolidation_service_test.dart` and `dive_merge_service_test.dart` construct a `ReparseService` too (verify they still pass; their own writers move in Tasks 7 and 8).

**Interfaces:**
- Consumes: `ProfileSeriesRepository({database, syncRepository})`, `deleteByComputer`, `insertSeries`; `TankPressureSeriesRepository({database, syncRepository})`, `deleteForDive`, `insertSeries`; `SyncRepository({database})`; `libdcRbtToSeconds` (existing); `groupPressuresByTank` (existing); `pigeon.ProfileSample`.
- Produces: `ReparseService({required this.db, this.trimTankPressureAtSurfacing = true, ProfileSeriesRepository? profileSeries, TankPressureSeriesRepository? tankSeries})`; a private `codec.ProfileSample _sampleFromParsed(pigeon.ProfileSample s, int timeOffset)`.

- [ ] **Step 1: Write the failing test**

`test/features/dive_computer/data/services/reparse_service_series_test.dart`, built on the fixture style of `reparse_service_test.dart` (its own in-memory `AppDatabase`, its `makeParsedDive`, its dive / computer / source seeding; copy those helpers rather than importing the other test file):

```dart
void main() {
  late AppDatabase db;
  late ReparseService service;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = ReparseService(db: db);
    profileSeries = ProfileSeriesRepository(
      database: db,
      syncRepository: SyncRepository(database: db),
    );
    tankSeries = TankPressureSeriesRepository(
      database: db,
      syncRepository: SyncRepository(database: db),
    );
  });

  tearDown(() => db.close());

  // Copy insertDive, insertComputer, insertSource and makeParsedDive from
  // reparse_service_test.dart verbatim (lines 17 to about 240 of that file).

  Future<void> apply(pigeon.ParsedDive parsed) => service.applyParsedUpdate(
    diveId: 'dive-1',
    sourceRowId: 'src-1',
    parsed: parsed,
    descriptorVendor: 'Shearwater',
    descriptorProduct: 'Perdix',
    descriptorModel: 42,
    libdivecomputerVersion: '0.8.0',
  );

  Future<void> seedDive({int? timeOffsetSeconds}) async {
    await insertDive('dive-1');
    await insertComputer('comp-1');
    await insertSource(
      id: 'src-1',
      diveId: 'dive-1',
      computerId: 'comp-1',
      timeOffsetSeconds: timeOffsetSeconds,
    );
  }

  test('applyParsedUpdate replaces the computer series with the parsed samples, offset applied', () async {
    await seedDive(timeOffsetSeconds: 5);
    final stale = await profileSeries.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      sourceId: 'src-1',
      samples: const [ProfileSample(timestamp: 0, depth: 99.0)],
      now: 1000,
    );
    await apply(
      makeParsedDive(
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(timeSeconds: 30, depthMeters: 12.0),
        ],
      ),
    );
    final rows = await profileSeries.getSeriesForDive('dive-1');
    expect(rows, hasLength(1));
    expect(rows.single.id, isNot(stale));
    expect(rows.single.computerId, 'comp-1');
    expect(rows.single.sourceId, 'src-1');
    expect(rows.single.isPrimary, isTrue);
    expect(
      rows.single.samples.map((s) => (s.timestamp, s.depth)).toList(),
      [(5, 0.0), (35, 12.0)],
    );
    expect(await db.select(db.diveProfiles).get(), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.map((t) => (t.entityType, t.recordId)).toList(),
      [('diveProfileSeries', stale)],
    );
  });

  test('a primary single-source reparse replaces the tank pressure series', () async {
    await seedDive();
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(
            id: Value('tank-0'),
            diveId: Value('dive-1'),
            computerId: Value('comp-1'),
            tankOrder: Value(0),
            o2Percent: Value(32.0),
            hePercent: Value(0.0),
            tankRole: Value('backGas'),
          ),
        );
    final stale = await tankSeries.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-0',
      computerId: 'comp-1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 999.0)],
      now: 1000,
    );
    await apply(
      makeParsedDive(
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: 0, volumeLiters: 12.0)],
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0)],
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0, pressureBar: 200.0, tankIndex: 0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 10.0, pressureBar: 150.0, tankIndex: 0),
        ],
      ),
    );
    final rows = await tankSeries.getSeriesForDive('dive-1');
    expect(rows, hasLength(1));
    expect(rows.single.id, isNot(stale));
    expect(rows.single.tankId, 'tank-0');
    expect(rows.single.computerId, 'comp-1');
    expect(rows.single.samples.map((s) => s.pressure), [200.0, 150.0]);
    expect(await db.select(db.tankPressureProfiles).get(), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.map((t) => (t.entityType, t.recordId)), contains(('tankPressureSeries', stale)));
  });

  test('ndl, ceiling and rbt derive from decoType exactly as the legacy row did', () async {
    await seedDive();
    await apply(
      makeParsedDive(
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0, decoType: 0, decoTime: 600, rbt: 12),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 20.0, decoType: 1, decoTime: 120, decoDepth: 6.0),
        ],
      ),
    );
    final samples = (await profileSeries.getSeriesForDive('dive-1')).single.samples;
    expect(samples[0].ndl, 600);
    expect(samples[0].ceiling, isNull);
    expect(samples[0].rbt, libdcRbtToSeconds(12));
    expect(samples[1].ndl, isNull);
    expect(samples[1].ceiling, 6.0);
    expect(samples[1].decoType, 1);
  });
}
```

Imports: `drift`, `drift/native.dart`, `flutter_test`, `database.dart`, `sync_repository.dart`, `reparse_service.dart`, `libdc_sample_units.dart` (`libdcRbtToSeconds`), the two series repositories, both codec files, and the pigeon API `as pigeon` (copy that import line from `reparse_service_test.dart`). The `pigeon.ProfileSample` parameter names (`timeSeconds`, `depthMeters`, `pressureBar`, `tankIndex`, `decoType`, `decoTime`, `decoDepth`, `rbt`) come from `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart`; verify before writing.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_computer/data/services/reparse_service_series_test.dart`
Expected: fails on empty series lists.

- [ ] **Step 3: Move the three sites**

Imports: `package:submersion/core/data/repositories/sync_repository.dart`, the two series repositories, `package:submersion/features/dive_log/domain/codecs/profile_sample.dart' as codec`, `.../tank_pressure_series_codec.dart' show TankPressureSample`.

Constructor and fields:

```dart
  ReparseService({
    required this.db,
    this.trimTankPressureAtSurfacing = true,
    ProfileSeriesRepository? profileSeries,
    TankPressureSeriesRepository? tankSeries,
  }) : _profileSeries =
           profileSeries ??
           ProfileSeriesRepository(
             database: db,
             syncRepository: SyncRepository(database: db),
           ),
       _tankSeries =
           tankSeries ??
           TankPressureSeriesRepository(
             database: db,
             syncRepository: SyncRepository(database: db),
           );

  final ProfileSeriesRepository _profileSeries;
  final TankPressureSeriesRepository _tankSeries;
```

`_replaceDiveProfiles`: keep the two legacy `db.delete(db.diveProfiles)` branches; add `await _profileSeries.deleteByComputer(diveId, computerId);` after them; replace the `db.batch` insert with

```dart
    if (parsed.samples.isNotEmpty) {
      await _profileSeries.insertSeries(
        diveId: diveId,
        computerId: computerId,
        sourceId: sourceId,
        isPrimary: isPrimary,
        samples: [
          for (final s in parsed.samples) _sampleFromParsed(s, timeOffset),
        ],
      );
    }
```

and add

```dart
  codec.ProfileSample _sampleFromParsed(pigeon.ProfileSample s, int timeOffset) =>
      codec.ProfileSample(
        timestamp: s.timeSeconds + timeOffset,
        depth: s.depthMeters,
        temperature: s.temperatureCelsius,
        heartRate: s.heartRate,
        heading: s.heading,
        setpoint: s.setpoint,
        ppO2: s.ppo2,
        cns: s.cns,
        ndl: s.decoType == 0 ? s.decoTime : null,
        ceiling: s.decoType != null && s.decoType != 0 ? s.decoDepth : null,
        rbt: libdcRbtToSeconds(s.rbt),
        decoType: s.decoType,
        tts: s.tts,
        o2Sensor1: s.o2Sensor1,
        o2Sensor2: s.o2Sensor2,
        o2Sensor3: s.o2Sensor3,
        o2Sensor4: s.o2Sensor4,
        o2Sensor5: s.o2Sensor5,
        o2Sensor6: s.o2Sensor6,
        o2SensorMv1: s.o2SensorMv1,
        o2SensorMv2: s.o2SensorMv2,
        o2SensorMv3: s.o2SensorMv3,
        o2SensorMv4: s.o2SensorMv4,
        o2SensorMv5: s.o2SensorMv5,
        o2SensorMv6: s.o2SensorMv6,
      );
```

(check `pigeon.ProfileSample`'s field names in `packages/libdivecomputer_plugin/pigeons/dive_computer_api.dart` and the generated Dart; the legacy insert in this file is the reference mapping).

The tank-pressure clear (inside `if (!isMultiSource && ownsStrand)`): keep `db.delete(db.tankPressureProfiles)` and add `await _tankSeries.deleteForDive(diveId);` after it.

`_replaceTankPressureProfiles`: replace the `db.batch` with

```dart
    for (final entry in pressuresByTank.entries) {
      final tankId = tankIdsByIndex[entry.key];
      if (tankId == null || entry.value.isEmpty) continue;
      await _tankSeries.insertSeries(
        diveId: diveId,
        tankId: tankId,
        computerId: computerId,
        samples: [
          for (final point in entry.value)
            TankPressureSample(timestamp: point.timestamp, pressure: point.pressure),
        ],
      );
    }
```

Keep the start/end backfill loop below it unchanged. Remove `_uuid` if it becomes unused.

Every series write here runs inside the `db.transaction` that `reparse` opens; the repositories' own transactions nest as savepoints.

- [ ] **Step 4: Run the tests, migrate reparse_service_test.dart**

New file: PASS. Then `reparse_service_test.dart`: the repositories the twins use must be `ProfileSeriesRepository(database: db, syncRepository: SyncRepository(database: db))` (same for tanks), because that file never initializes `DatabaseService`. Add the twins beside `insertProfile` and the inline tank-pressure seeds; switch the tests that assert on rows the reparse REPLACED (R2, R3, R4); tests that only read profiles the reparse did not own stay on legacy seeds (fallback). Run `reparse_service_test.dart`, `reparse_service_surfacing_test.dart`, `dive_consolidation_service_test.dart`, `dive_merge_service_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_reparse_menu_test.dart`.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_computer/data/services/reparse_service.dart test/features/dive_computer/data/services/reparse_service_series_test.dart test/features/dive_computer/data/services/reparse_service_test.dart
git commit -m "feat(series): reparse replaces profile and tank pressure series"
```

---

### Task 6: DiveSplitService

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_split_service.dart` (the tank / pressure / event selection near line 150; the profile row selection and clone near line 245; the pressure clone near line 296; the tombstone-and-delete block near line 337; the promote-after-split near line 380)
- Test: `test/features/dive_log/data/services/dive_split_service_series_test.dart` (new)
- Modify tests (R1 to R6): `test/features/dive_log/data/services/dive_split_service_test.dart` (helpers `insertProfileRow` and `insertTankPressure` near lines 70 and 106; the `deletion_log` entity-type assertions near line 335), `test/features/dive_log/data/repositories/dive_consolidation_test.dart` (its split tests switch to the series twin added in Task 2; delete the legacy helper if nothing uses it any more), `test/features/dive_log/integration/multi_computer_integration_test.dart`.

**Interfaces:**
- Consumes: `ProfileSeriesRepository.getSeriesForDive`, `insertSeries`, `deleteByIds`, `hasPrimarySeries`, `promoteOwnedBy(diveId, {sourceId, computerId, now})`; `TankPressureSeriesRepository.getSeriesForDive`, `insertSeries`, `deleteByIds`; entities `ProfileSeries` (fields `id, diveId, computerId, sourceId, isPrimary, samples`) and `series.TankPressureSeries` (`id, diveId, tankId, computerId, samples`).
- Produces: nothing for later tasks.

- [ ] **Step 1: Write the failing test**

`test/features/dive_log/data/services/dive_split_service_series_test.dart` (fixture: copy `dive_split_service_test.dart`'s dive / computer / source / tank seeding; seed series through the repositories):

```dart
void main() {
  late AppDatabase db;
  late DiveSplitService service;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  // Copy insertComputer(id, name), insertDive(id, {computerId}),
  // insertSource(id, diveId, computerId, {isPrimary, maxDepth, createdAt})
  // and insertTank(diveId, computerId) from dive_split_service_test.dart
  // verbatim (its `baseTime` constant too).

  setUp(() async {
    db = await setUpTestDatabase();
    service = DiveSplitService(DiveRepository());
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
    await insertComputer('comp-a', 'A');
    await insertComputer('comp-b', 'B');
    await insertDive('dive-1', computerId: 'comp-a');
    await insertSource('src-a', 'dive-1', 'comp-a', isPrimary: true, createdAt: DateTime.utc(2026, 1, 1));
    await insertSource('src-b', 'dive-1', 'comp-b', isPrimary: false, createdAt: DateTime.utc(2026, 1, 2));
  });

  tearDown(() async {
    await tearDownTestDatabase(db);
  });

  Future<String> sourceIdOf(String diveId) async =>
      (await (db.select(db.diveDataSources)..where((t) => t.diveId.equals(diveId))).getSingle()).id;

  test('splitting the primary source moves its series and its null-computer family to the new dive', () async {
    final a1 = await profileSeries.insertSeries(diveId: 'dive-1', computerId: 'comp-a', sourceId: 'src-a', samples: const [ProfileSample(timestamp: 0, depth: 1.0)], now: 1000);
    final b1 = await profileSeries.insertSeries(diveId: 'dive-1', computerId: 'comp-b', sourceId: 'src-b', isPrimary: false, samples: const [ProfileSample(timestamp: 0, depth: 2.0)], now: 1000);
    final e = await profileSeries.insertSeries(diveId: 'dive-1', sourceId: 'src-a', isPrimary: false, samples: const [ProfileSample(timestamp: 0, depth: 3.0)], now: 1000);
    final ta = await insertTank('dive-1', 'comp-a');
    final tb = await insertTank('dive-1', 'comp-b');
    final pa = await tankSeries.insertSeries(diveId: 'dive-1', tankId: ta, computerId: 'comp-a', samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)], now: 1000);
    final pb = await tankSeries.insertSeries(diveId: 'dive-1', tankId: tb, computerId: 'comp-b', samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)], now: 1000);

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-a');

    final newSourceId = await sourceIdOf(newDiveId);
    final moved = await profileSeries.getSeriesForDive(newDiveId);
    expect(moved.map((s) => s.samples.single.depth).toSet(), {1.0, 3.0});
    expect(moved.every((s) => s.sourceId == newSourceId), isTrue);
    expect(moved.firstWhere((s) => s.samples.single.depth == 1.0).isPrimary, isTrue);
    expect(moved.firstWhere((s) => s.samples.single.depth == 3.0).isPrimary, isFalse);
    final left = await profileSeries.getSeriesForDive('dive-1');
    expect(left.map((s) => s.id), [b1]);
    expect(left.single.isPrimary, isTrue, reason: 'promote-after-split');
    final movedTanks = await tankSeries.getSeriesForDive(newDiveId);
    expect(movedTanks.single.samples.single.pressure, 200.0);
    expect(movedTanks.single.tankId, isNot(ta), reason: 'the tank was cloned under a fresh id');
    expect((await tankSeries.getSeriesForDive('dive-1')).single.id, pb);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.where((t) => t.entityType == 'diveProfileSeries').map((t) => t.recordId).toSet(), {a1, e});
    expect(tombstones.where((t) => t.entityType == 'tankPressureSeries').map((t) => t.recordId), [pa]);
    expect(tombstones.any((t) => t.entityType == 'diveProfiles' || t.entityType == 'tankPressureProfiles'), isFalse);
    expect(await db.select(db.diveProfiles).get(), isEmpty);
    expect(await db.select(db.tankPressureProfiles).get(), isEmpty);
  });

  test('splitting a non-primary source promotes its series in the new dive', () async {
    await profileSeries.insertSeries(diveId: 'dive-1', computerId: 'comp-a', sourceId: 'src-a', samples: const [ProfileSample(timestamp: 0, depth: 1.0)], now: 1000);
    final b1 = await profileSeries.insertSeries(diveId: 'dive-1', computerId: 'comp-b', sourceId: 'src-b', isPrimary: false, samples: const [ProfileSample(timestamp: 0, depth: 2.0)], now: 1000);

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-b');

    final moved = (await profileSeries.getSeriesForDive(newDiveId)).single;
    expect(moved.samples.single.depth, 2.0);
    expect(moved.isPrimary, isTrue);
    expect(moved.computerId, 'comp-b');
    expect(moved.sourceId, await sourceIdOf(newDiveId));
    expect((await profileSeries.getSeriesForDive('dive-1')).single.isPrimary, isTrue);
    expect(
      (await db.select(db.deletionLog).get()).where((t) => t.entityType == 'diveProfileSeries').map((t) => t.recordId),
      [b1],
    );
  });
}
```

Imports: `drift` (hide `isNull`), `flutter_test`, `database.dart`, `dive_repository_impl.dart`, `dive_split_service.dart`, the two series repositories, both codec files, `test_database.dart`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/dive_split_service_series_test.dart`
Expected: the new dive has no series.

- [ ] **Step 3: Move the split**

Imports: the two series repositories; `import 'package:submersion/features/dive_log/domain/entities/profile_series.dart' as series;`. Fields: `final _profileSeries = ProfileSeriesRepository(); final _tankSeries = TankPressureSeriesRepository();`.

Read the series BEFORE the transaction deletes the old source row (the `dive_profile_series.source_id` FK is `ON DELETE SET NULL`, so reading after the delete would lose the FK ownership signal). Right after `ownedBySource` is defined (before `await _db.transaction`), add:

```dart
    final allProfileSeries = await _profileSeries.getSeriesForDive(diveId);
    final allPressureSeries = await _tankSeries.getSeriesForDive(diveId);
    bool ownedByComputer(String? computerId) =>
        source.computerId != null && computerId == source.computerId;
    // The legacy row rule, applied to whole series: not owned by another
    // source by FK, then the computer convention for the source's primacy.
    bool profileBelongsToSource(series.ProfileSeries s) {
      final notOwnedByAnotherSource = s.sourceId == null || s.sourceId == source.id;
      final byLegacyRule = source.computerId == null
          ? s.computerId == null && !s.isPrimary
          : source.isPrimary
          ? ownedByComputer(s.computerId) || s.computerId == null
          : ownedByComputer(s.computerId);
      return notOwnedByAnotherSource && byLegacyRule;
    }
    final movingProfiles = [
      for (final s in allProfileSeries)
        if (profileBelongsToSource(s)) s,
    ];
    final movingPressures = [
      for (final s in allPressureSeries)
        if (ownedByComputer(s.computerId)) s,
    ];
```

Inside the transaction:

- In the tank block (near line 150): replace `allPressures` (the legacy select) with `allPressureSeries`, and `pressureRows` with `movingPressures`; `hasRemainingRefs` reads `allPressureSeries.any((r) => r.tankId == tank.id && !owned(r.computerId))` (the `owned` closure there is the same rule as `ownedByComputer`; keep one). The loop that clones a tank for pressure rows whose tank is not owned iterates `movingPressures`.
- Profile clone (near line 245): delete the legacy `profileRows` select and the `_db.batch` insert; instead

```dart
      for (final s in movingProfiles) {
        await _profileSeries.insertSeries(
          diveId: newDiveId,
          computerId: s.computerId,
          sourceId: newSourceId,
          isPrimary: source.isPrimary ? s.isPrimary : true,
          samples: s.samples,
          now: now,
        );
      }
```

- Pressure clone (near line 296): delete the `_db.batch`; instead

```dart
      for (final s in movingPressures) {
        await _tankSeries.insertSeries(
          diveId: newDiveId,
          tankId: tankIdMap[s.tankId] ?? s.tankId,
          computerId: s.computerId,
          samples: s.samples,
          now: now,
        );
      }
```

- Tombstone-and-delete block (near line 337): delete the `for (final row in pressureRows) logDeletion('tankPressureProfiles')` loop and the legacy `delete(_db.tankPressureProfiles)` by id list, and the `for (final row in profileRows) logDeletion('diveProfiles')` loop and the legacy `delete(_db.diveProfiles)` by id list (these delete rows the service SELECTED; with no legacy select left there is nothing to delete). Instead:

```dart
      await _tankSeries.deleteByIds([for (final s in movingPressures) s.id]);
      await _profileSeries.deleteByIds([for (final s in movingProfiles) s.id]);
```

Keep the event and tank deletes exactly as they are.

- Promote-after-split (near line 380): replace the `remainingPrimary` select and the `update(_db.diveProfiles)` with

```dart
        if (!await _profileSeries.hasPrimarySeries(diveId)) {
          await _profileSeries.promoteOwnedBy(
            diveId,
            sourceId: promoted.id,
            computerId: promoted.computerId,
            now: now,
          );
        }
```

- [ ] **Step 4: Run the tests, migrate the existing ones**

New file: PASS. Then `dive_split_service_test.dart`: add the twins beside `insertProfileRow` / `insertTankPressure` (same parameters, return the series id), switch every split test (R1 to R4; the `byRecord[...]` entity-type assertions become `'diveProfileSeries'` / `'tankPressureSeries'`); `dive_consolidation_test.dart`: switch its split tests to `insertTestSeries` (Task 2's twin) and delete `insertTestProfile` if unused; `multi_computer_integration_test.dart`: apply R1 to R6 to its split scenario. Run those three plus `dive_repository_series_writes_test.dart`.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/services/dive_split_service.dart test/features/dive_log/data/services/dive_split_service_series_test.dart test/features/dive_log/data/services/dive_split_service_test.dart test/features/dive_log/data/repositories/dive_consolidation_test.dart test/features/dive_log/integration/multi_computer_integration_test.dart
git commit -m "feat(series): dive split moves profile and tank pressure series"
```

---

### Task 7: DiveMergeSnapshot and DiveMergeService

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_merge_snapshot.dart` (two new fields with defaults; `capture` fills them)
- Modify: `lib/features/dive_log/data/services/dive_merge_service.dart` (profile copy and gap fill near line 252; tank pressure copy near line 399; undo delete near line 509; undo re-insert near line 592; `_adjacentProfileRow` and `_nativeSampleIntervalSeconds` get series twins)
- Test: `test/features/dive_log/data/services/dive_merge_service_series_test.dart` (new)
- Modify tests (R1 to R6): `test/features/dive_log/data/services/dive_merge_service_test.dart` (the `createDive` helper near line 52 stamps `computer_id` on legacy rows with an `update(db.diveProfiles)` near line 65 and seeds a tank pressure row near line 110). The six tests that construct `DiveMergeSnapshot(...)` by hand (`combine_dives_dialog_test.dart`, `dive_list_selection_test.dart`, `merge_dive_dialog_test.dart`, `dive_computer_adapter_test.dart`, `universal_adapter_test.dart`, `import_consolidation_service_test.dart`) keep compiling because the new fields default to `const []`; run them to prove it.

**Interfaces:**
- Consumes: `ProfileSeriesRepository.getSeriesForDives`, `getRowsForDives`, `insertSeries`, `deleteForDive`, `restoreSeriesRow(DiveProfileSeriesRow row, {markPending, now})`; `TankPressureSeriesRepository.getSeriesForDive`, `getRowsForDives`, `insertSeries`, `deleteForDive`, `restoreSeriesRow(TankPressureSeriesRow row, {markPending, now})`; `ProfileSample.shiftedBy`, `TankPressureSample.shiftedBy`; `MergeGap` (`afterDiveId`, `beforeDiveId`, `startSeconds`, `endSeconds`), `result.segmentOffsetsSeconds`, `result.tankIdMap` (existing); `mergedSourceIdFor(diveId, sourceId)` (existing local closure).
- Produces: `DiveMergeSnapshot.profileSeriesRows` (`List<DiveProfileSeriesRow>`, default `const []`) and `DiveMergeSnapshot.tankSeriesRows` (`List<TankPressureSeriesRow>`, default `const []`), filled by `capture`; Task 8 reads them.

- [ ] **Step 1: Write the failing test**

`test/features/dive_log/data/services/dive_merge_service_series_test.dart`, on the fixture of `dive_merge_service_test.dart` (its `createDive` helper builds dives through `DiveRepository.createDive`, which writes series since Task 2; drop the legacy `update(db.diveProfiles)` computer stamp from the copy of the helper and instead re-insert the created series with the computer id: read `ProfileSeriesRepository().getSeriesForDive(id)`, `deleteForDive(id)`, then `insertSeries` again with `computerId`, same samples and flags):

```dart
  // Fixture: copy dive_merge_service_test.dart's createDive helper (it seeds
  // 'a' and 'b' fifteen minutes apart with a three-point profile through
  // DiveRepository.createDive, plus buddies, sightings, events, switches,
  // a data source and a tank) with two changes: delete the
  // `update(db.diveProfiles)` computer stamp and, when computerId is given,
  // re-insert the created series with that computer instead:
  //
  //   final created = await profileSeries.getSeriesForDive(id);
  //   await profileSeries.deleteForDive(id);
  //   for (final s in created) {
  //     await profileSeries.insertSeries(diveId: id, computerId: computerId,
  //       sourceId: s.sourceId, isPrimary: s.isPrimary, samples: s.samples,
  //       now: 1000);
  //   }
  //
  // and replace the tank_pressure_profiles insert with
  //   await tankSeries.insertSeries(diveId: id, tankId: 'tank-$id',
  //     samples: const [TankPressureSample(timestamp: 60, pressure: 180.0)],
  //     now: 1000);

  void expectAscending(Iterable<int> timestamps) {
    final list = timestamps.toList();
    for (var i = 1; i < list.length; i++) {
      expect(list[i], greaterThanOrEqualTo(list[i - 1]), reason: 'index $i');
    }
  }

  test('apply re-bases every series onto the merged timeline and fills the gap into the adjacent series', () async {
    await createDive('a', runtimeMin: 10, depth: 20);
    await createDive('b', runtimeMin: 10, depth: 20 /* fifteen minutes after a, as the fixture does */);

    final outcome = await service.apply(['a', 'b']);

    final merged = await profileSeries.getSeriesForDive(outcome.mergedDive.id);
    expect(merged, hasLength(2));
    final first = merged.firstWhere((s) => s.samples.first.timestamp == 0);
    final second = merged.firstWhere((s) => s.samples.first.timestamp != 0);
    final offsetB = second.samples.first.timestamp;
    expect(offsetB, greaterThan(600));
    expect(second.samples.map((s) => s.timestamp), [offsetB, offsetB + 300, offsetB + 600]);
    final gap = first.samples.where((s) => s.timestamp > 600 && s.timestamp < offsetB).toList();
    expect(gap, isNotEmpty, reason: 'the surface gap is filled into the segment before it');
    expect(gap.every((s) => s.depth == 0), isTrue);
    expect(gap.last.timestamp, offsetB - 1);
    expectAscending(first.samples.map((s) => s.timestamp));
    expect(first.sourceId, isNotNull);
    expect(await db.select(db.diveProfiles).get(), isEmpty);
  });

  test('apply moves tank pressure series onto the merged tanks with the segment offset', () async {
    await createDive('a', runtimeMin: 10, depth: 20);
    await createDive('b', runtimeMin: 10, depth: 20);

    final outcome = await service.apply(['a', 'b']);

    final tanks = await tankSeries.getSeriesForDive(outcome.mergedDive.id);
    expect(tanks, hasLength(2));
    final mergedTankIds = (await (db.select(db.diveTanks)..where((t) => t.diveId.equals(outcome.mergedDive.id))).get()).map((t) => t.id).toSet();
    expect(tanks.map((s) => s.tankId).toSet(), mergedTankIds);
    final timestamps = tanks.map((s) => s.samples.single.timestamp).toList()..sort();
    expect(timestamps.first, 60);
    expect(timestamps.last, greaterThan(660));
    expect(await db.select(db.tankPressureProfiles).get(), isEmpty);
  });

  test('undo tombstones the merged series and restores the original rows', () async {
    await createDive('a', runtimeMin: 10, depth: 20);
    await createDive('b', runtimeMin: 10, depth: 20);
    final before = await profileSeries.getRowsForDives(['a', 'b']);
    final beforeTanks = await tankSeries.getRowsForDives(['a', 'b']);

    final outcome = await service.apply(['a', 'b']);
    final mergedIds = (await profileSeries.getRowsForDives([outcome.mergedDive.id])).map((r) => r.id).toSet();
    final mergedTankIds = (await tankSeries.getRowsForDives([outcome.mergedDive.id])).map((r) => r.id).toSet();
    await service.undo(outcome.snapshot);

    expect(await profileSeries.getRowsForDives([outcome.mergedDive.id]), isEmpty);
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.where((t) => t.entityType == 'diveProfileSeries').map((t) => t.recordId).toSet(), mergedIds);
    expect(tombstones.where((t) => t.entityType == 'tankPressureSeries').map((t) => t.recordId).toSet(), mergedTankIds);
    expect(tombstones.any((t) => before.any((r) => r.id == t.recordId)), isFalse);
    final after = await profileSeries.getRowsForDives(['a', 'b']);
    expect(
      after.map((r) => (r.id, r.diveId, r.computerId, r.sourceId, r.isPrimary, r.samples)).toList(),
      before.map((r) => (r.id, r.diveId, r.computerId, r.sourceId, r.isPrimary, r.samples)).toList(),
    );
    final afterTanks = await tankSeries.getRowsForDives(['a', 'b']);
    expect(
      afterTanks.map((r) => (r.id, r.tankId, r.samples)).toList(),
      beforeTanks.map((r) => (r.id, r.tankId, r.samples)).toList(),
    );
  });
```

`service` is `DiveMergeService(DiveRepository())`, `profileSeries` / `tankSeries` the two zero-arg repositories; `Uint8List` samples compare by content under `expect` because `flutter_test` uses deep equality for lists. Write the fixture and the three tests in full in the file.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/dive_merge_service_series_test.dart`
Expected: the merged dive has no series (rows went to `dive_profiles`).

- [ ] **Step 3: Snapshot fields**

`dive_merge_snapshot.dart`: add to the constructor `this.profileSeriesRows = const [], this.tankSeriesRows = const [],`, the fields `final List<DiveProfileSeriesRow> profileSeriesRows; final List<TankPressureSeriesRow> tankSeriesRows;`, and in `capture`:

```dart
      profileSeriesRows: await ProfileSeriesRepository(
        database: db,
        syncRepository: SyncRepository(database: db),
      ).getRowsForDives(diveIds),
      tankSeriesRows: await TankPressureSeriesRepository(
        database: db,
        syncRepository: SyncRepository(database: db),
      ).getRowsForDives(diveIds),
```

(imports: the two repositories and `sync_repository.dart`). The legacy `profileRows` / `tankPressureRows` fields stay and are still captured; plan 2e removes them.

- [ ] **Step 4: Merge**

Imports in `dive_merge_service.dart`: the two series repositories; `codecs/profile_sample.dart` (`ProfileSample`); `entities/profile_series.dart` as `series`. Fields: `final _profileSeries = ProfileSeriesRepository(); final _tankSeries = TankPressureSeriesRepository();`.

Replace the profile `_db.batch` (row copy plus gap fill, near line 252) with a series build. Read the originals live, before anything is deleted:

```dart
      final seriesByDive = await _profileSeries.getSeriesForDives(diveIds);
      final originals = [
        for (final id in diveIds) ...(seriesByDive[id] ?? const <series.ProfileSeries>[]),
      ];
      // One draft per original series, re-based onto the merged timeline.
      final drafts = <_SeriesDraft>[
        for (final s in originals)
          _SeriesDraft(
            diveId: s.diveId,
            computerId: s.computerId,
            sourceId: s.sourceId,
            isPrimary: s.isPrimary,
            samples: [
              for (final p in s.samples)
                p.shiftedBy(result.segmentOffsetsSeconds[s.diveId] ?? 0),
            ],
          ),
      ];
      for (final gap in result.gaps) {
        if (gap.endSeconds - gap.startSeconds < 2) continue;
        final host =
            _adjacentDraft(drafts, gap.afterDiveId) ??
            _adjacentDraft(drafts, gap.beforeDiveId);
        final interval = _nativeSampleIntervalSecondsOf(originals, gap);
        final minStep = ((gap.endSeconds - gap.startSeconds) / 300).ceil();
        final step = interval > minStep ? interval : minStep;
        final timestamps = <int>[
          for (var ts = gap.startSeconds + 1; ts < gap.endSeconds; ts += step) ts,
        ];
        if (timestamps.last != gap.endSeconds - 1) {
          timestamps.add(gap.endSeconds - 1);
        }
        final surface = [
          for (final ts in timestamps) ProfileSample(timestamp: ts, depth: 0),
        ];
        if (host != null) {
          host.samples.addAll(surface);
        } else {
          // No profile on either side: the legacy rows carried a null
          // computer, a null source and is_primary true.
          drafts.add(
            _SeriesDraft(
              diveId: gap.afterDiveId,
              computerId: null,
              sourceId: null,
              isPrimary: true,
              samples: surface,
            ),
          );
        }
      }
      for (final d in drafts) {
        if (d.samples.isEmpty) continue;
        await _profileSeries.insertSeries(
          diveId: mergedId,
          computerId: d.computerId,
          sourceId: d.sourceId == null && d.computerId == null && !originals.any((s) => s.diveId == d.diveId)
              ? null
              : mergedSourceIdFor(d.diveId, d.sourceId),
          isPrimary: d.isPrimary,
          samples: d.samples,
          now: now,
        );
      }
```

The `sourceId` expression reproduces the legacy split: rows copied from an original got `mergedSourceIdFor(row.diveId, row.sourceId)`; gap rows with an adjacent row got `mergedSourceIdFor(adjacent.diveId, adjacent.sourceId)` (the host draft carries that dive and source, so the same call applies); gap rows with NO adjacent row got a null source. Simplify to exactly that: give `_SeriesDraft` a `bool synthetic` flag set only in the no-host branch, and use `sourceId: d.synthetic ? null : mergedSourceIdFor(d.diveId, d.sourceId)`.

`_SeriesDraft` is a small private class in this file (`diveId`, `computerId`, `sourceId`, `isPrimary`, `synthetic = false`, and a growable `samples` list that only this method mutates before the insert). Add the twins of the two helpers:

```dart
  /// The draft that hosts a gap's surface samples: the segment's primary
  /// series, else one with a computer, else its first series.
  _SeriesDraft? _adjacentDraft(List<_SeriesDraft> drafts, String diveId) {
    final segment = drafts.where((d) => d.diveId == diveId).toList();
    if (segment.isEmpty) return null;
    for (final d in segment) {
      if (d.isPrimary) return d;
    }
    for (final d in segment) {
      if (d.computerId != null) return d;
    }
    return segment.first;
  }

  /// Median inter-sample delta of the previous segment (then the next, then
  /// 60 s), over every series of that segment.
  int _nativeSampleIntervalSecondsOf(
    List<series.ProfileSeries> originals,
    MergeGap gap,
  ) {
    for (final diveId in [gap.afterDiveId, gap.beforeDiveId]) {
      final timestamps = [
        for (final s in originals)
          if (s.diveId == diveId)
            for (final p in s.samples) p.timestamp,
      ]..sort();
      final deltas = <int>[
        for (var i = 1; i < timestamps.length; i++)
          if (timestamps[i] - timestamps[i - 1] > 0)
            timestamps[i] - timestamps[i - 1],
      ];
      if (deltas.isNotEmpty) {
        deltas.sort();
        return deltas[deltas.length ~/ 2];
      }
    }
    return 60;
  }
```

Delete `_adjacentProfileRow` and `_nativeSampleIntervalSeconds` once nothing calls them.

Tank pressures (near line 399): replace the `_db.batch` with

```dart
      for (final id in diveIds) {
        for (final s in await _tankSeries.getSeriesForDive(id)) {
          final newTankId = result.tankIdMap[s.tankId];
          if (newTankId == null || s.samples.isEmpty) continue;
          final offset = result.segmentOffsetsSeconds[s.diveId] ?? 0;
          await _tankSeries.insertSeries(
            diveId: mergedId,
            tankId: newTankId,
            computerId: s.computerId,
            samples: [for (final p in s.samples) p.shiftedBy(offset)],
            now: now,
          );
        }
      }
```

Undo (near line 509): before the `_db.batch` of `deleteWhere`s add `await _profileSeries.deleteForDive(mergedId); await _tankSeries.deleteForDive(mergedId);` (one tombstone per merged series). Keep the legacy `deleteWhere`s. In the re-insert block (near line 592), after the batch that re-inserts `dataSourceRows` (the series FK parents: dives, computers, sources, tanks must be back first), add

```dart
      for (final r in snapshot.profileSeriesRows) {
        await _profileSeries.restoreSeriesRow(r, now: now);
      }
      for (final r in snapshot.tankSeriesRows) {
        await _tankSeries.restoreSeriesRow(r, now: now);
      }
```

Keep the legacy verbatim re-inserts of `profileRows` / `tankPressureRows` (they are empty on a packed database and harmless otherwise).

- [ ] **Step 5: Run the tests, migrate dive_merge_service_test.dart**

New file: PASS. `dive_merge_service_test.dart`: in its `createDive` helper replace the `update(db.diveProfiles)` computer stamp with the delete-and-reinsert through `ProfileSeriesRepository` described in Step 1, and the `tank_pressure_profiles` seed with `TankPressureSeriesRepository().insertSeries(...)`; apply R2 to R6 to the assertions (`db.select(db.diveProfiles)` reads become series reads; the FK comment near line 534 about `tankPressureProfiles.tankId` applies to `tank_pressure_series.tank_id` the same way). Run it, the new file, and the six snapshot-constructing tests listed in Files.
Expected: all pass.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/services/dive_merge_snapshot.dart lib/features/dive_log/data/services/dive_merge_service.dart test/features/dive_log/data/services/dive_merge_service_series_test.dart test/features/dive_log/data/services/dive_merge_service_test.dart
git commit -m "feat(series): dive merge re-bases series and snapshots them for undo"
```

---

### Task 8: DiveConsolidationService

**Files:**
- Modify: `lib/features/dive_log/data/services/dive_consolidation_service.dart` (the target stamp near line 78; the copy near line 288; the undo id sets near line 653; the undo tombstone-and-delete near line 763; the undo re-insert near line 837)
- Test: `test/features/dive_log/data/services/dive_consolidation_service_series_test.dart` (new)
- Modify tests (R1 to R6): `test/features/dive_log/data/services/dive_consolidation_service_test.dart`; verify the import-wizard adapter tests that drive consolidation (`test/features/import_wizard/data/adapters/dive_computer_adapter_consolidate_integration_test.dart`, `dive_computer_adapter_reimport_test.dart`, `universal_adapter_test.dart`, `dive_computer_adapter_test.dart`, `test/features/universal_import/presentation/providers/import_consolidation_service_test.dart`).

**Interfaces:**
- Consumes: Task 7's `snapshot.profileSeriesRows` / `snapshot.tankSeriesRows`; `ProfileSeriesRepository.getSeriesForDive`, `insertSeries`, `getRowsForDives`, `restoreSeriesRow`; `TankPressureSeriesRepository.getSeriesForDive`, `insertSeries`, `stampComputerWhereNull`, `getRowsForDives`, `restoreSeriesRow`; `shiftedBy` on both sample types; `sourceIdMap` (`Map<String?, String>`), `tankIdMap`, `secRow`, `offset` (existing locals).
- Produces: nothing for later tasks.

- [ ] **Step 1: Write the failing test**

`test/features/dive_log/data/services/dive_consolidation_service_series_test.dart`, on the fixture of `dive_consolidation_service_test.dart`:

```dart
  // Fixture: copy dive_consolidation_service_test.dart's setUp seeding for
  // the target dive 't' and the secondary dive 's' (dives, computers
  // 'comp-t' / 'comp-s', data sources, tanks) so that
  // `service.apply(targetDiveId: 't', secondaryDiveIds: ['s'])` succeeds
  // there; name the target's primary source 'src-t' and the secondary's
  // 'src-s', and give the target dive row computerId 'comp-t'.

  Future<String> copiedSourceId() async =>
      (await (db.select(db.diveDataSources)..where((t) => t.diveId.equals('t') & t.computerId.equals('comp-s'))).getSingle()).id;

  test('apply copies the secondary series onto the target as demoted, re-owned and offset', () async {
    final st = await profileSeries.insertSeries(diveId: 't', computerId: 'comp-t', sourceId: 'src-t', samples: const [ProfileSample(timestamp: 0, depth: 1.0)], now: 1000);
    await profileSeries.insertSeries(diveId: 's', computerId: 'comp-s', sourceId: 'src-s', samples: const [ProfileSample(timestamp: 0, depth: 2.0)], now: 1000);
    await profileSeries.insertSeries(diveId: 's', sourceId: 'src-s', isPrimary: false, samples: const [ProfileSample(timestamp: 0, depth: 3.0)], now: 1000);

    await service.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    final rows = await profileSeries.getSeriesForDive('t');
    expect(rows.where((s) => s.isPrimary).map((s) => s.id), [st]);
    final copied = rows.where((s) => s.id != st).toList();
    expect(copied, hasLength(2));
    expect(copied.every((s) => !s.isPrimary), isTrue);
    expect(copied.map((s) => s.computerId).toSet(), {'comp-s'}, reason: 'a null computer takes the secondary source computer');
    final source = await copiedSourceId();
    expect(copied.every((s) => s.sourceId == source), isTrue);
    final offset = (await (db.select(db.diveDataSources)..where((t) => t.id.equals(source))).getSingle()).timeOffsetSeconds ?? 0;
    expect(copied.map((s) => s.samples.single.timestamp).toSet(), {offset});
    expect(await profileSeries.getSeriesForDive('s'), isEmpty);
    expect(await db.select(db.diveProfiles).get(), isEmpty);
  });

  test('apply stamps the target computer on the target null-computer tank series', () async {
    final tankId = /* the target's tank id from the fixture */;
    final id = await tankSeries.insertSeries(diveId: 't', tankId: tankId, samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)], now: 1000);

    await service.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    final row = (await tankSeries.getRowsForDives(['t'])).firstWhere((r) => r.id == id);
    expect(row.computerId, 'comp-t');
    expect(await db.select(db.tankPressureProfiles).get(), isEmpty);
  });

  test('undo tombstones the copied series, keeps the originals and restores the secondary rows', () async {
    await profileSeries.insertSeries(diveId: 't', computerId: 'comp-t', sourceId: 'src-t', samples: const [ProfileSample(timestamp: 0, depth: 1.0)], now: 1000);
    await profileSeries.insertSeries(diveId: 's', computerId: 'comp-s', sourceId: 'src-s', samples: const [ProfileSample(timestamp: 0, depth: 2.0)], now: 1000);
    final before = await profileSeries.getRowsForDives(['t', 's']);

    final outcome = await service.apply(targetDiveId: 't', secondaryDiveIds: ['s']);
    final copiedIds = (await profileSeries.getRowsForDives(['t'])).map((r) => r.id).where((id) => !before.any((r) => r.id == id)).toSet();
    await service.undo(outcome.snapshot);

    final after = await profileSeries.getRowsForDives(['t', 's']);
    expect(
      after.map((r) => (r.id, r.diveId, r.computerId, r.sourceId, r.isPrimary, r.samples)).toList(),
      before.map((r) => (r.id, r.diveId, r.computerId, r.sourceId, r.isPrimary, r.samples)).toList(),
    );
    final tombstones = await db.select(db.deletionLog).get();
    expect(tombstones.where((t) => t.entityType == 'diveProfileSeries').map((t) => t.recordId).toSet(), copiedIds);
    expect(tombstones.any((t) => before.any((r) => r.id == t.recordId)), isFalse);
  });
```

`service` is `DiveConsolidationService(DiveRepository())`; the fixture's tank id for the target replaces the placeholder in the second test. Write the fixture and the three tests in full in the file.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/dive_consolidation_service_series_test.dart`
Expected: the target gains no series.

- [ ] **Step 3: Move the sites**

Imports and fields as in Task 7 (`_profileSeries`, `_tankSeries`, `as series`).

Stamp (near line 78): after the `update(_db.tankPressureProfiles)` computer stamp (which stays until 2e? No: it is an UPDATE on a legacy table and this plan removes those; delete it) add `await _tankSeries.stampComputerWhereNull(targetDiveId, targetRow.computerId!, now: now);` inside the same `if (targetRow.computerId != null)`.

Copy (near line 288): replace the `_db.batch` with

```dart
        for (final s in await _profileSeries.getSeriesForDive(secondary.id)) {
          if (s.samples.isEmpty) continue;
          await _profileSeries.insertSeries(
            diveId: targetDiveId,
            computerId: s.computerId ?? secRow.computerId,
            sourceId: sourceIdMap[s.sourceId] ?? sourceIdMap[null],
            isPrimary: false,
            samples: [for (final p in s.samples) p.shiftedBy(offset)],
            now: now,
          );
        }
        for (final s in await _tankSeries.getSeriesForDive(secondary.id)) {
          final mappedTank = tankIdMap[s.tankId];
          if (mappedTank == null || s.samples.isEmpty) continue;
          await _tankSeries.insertSeries(
            diveId: targetDiveId,
            tankId: mappedTank,
            computerId: secRow.computerId,
            samples: [for (final p in s.samples) p.shiftedBy(offset)],
            now: now,
          );
        }
```

(read the secondary's series BEFORE the code that deletes the secondary dive; place the loops where the legacy batch was, which runs before that delete).

Undo id sets (near line 653): add `'diveProfileSeries': {for (final r in snapshot.profileSeriesRows) r.id}` and `'tankPressureSeries': {for (final r in snapshot.tankSeriesRows) r.id}` to `snapshotIds`, and to `currentChildIds` add

```dart
        'diveProfileSeries': [
          for (final r in await _profileSeries.getRowsForDives([mergedId])) r.id,
        ],
        'tankPressureSeries': [
          for (final r in await _tankSeries.getRowsForDives([mergedId])) r.id,
        ],
```

The tombstone loop (near line 763) then logs the copied series under their series entity types with no further change. In the delete batch add `batch.deleteWhere(_db.diveProfileSeries, (t) => t.diveId.equals(mergedId));` and `batch.deleteWhere(_db.tankPressureSeries, (t) => t.diveId.equals(mergedId));` (raw deletes on purpose: the loop above already tombstoned the difference, and `restoreSeriesRow` removes the tombstones of the rows it puts back). In the re-insert block (near line 837), after the `dataSourceRows` batch, add the same two `restoreSeriesRow` loops as Task 7.

- [ ] **Step 4: Run the tests, migrate dive_consolidation_service_test.dart**

New file: PASS. `dive_consolidation_service_test.dart` (9 legacy references): add the twins, switch the consolidation tests (R1 to R5). Run it, the new file, and the five import-wizard files listed.
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/services/dive_consolidation_service.dart test/features/dive_log/data/services/dive_consolidation_service_series_test.dart test/features/dive_log/data/services/dive_consolidation_service_test.dart
git commit -m "feat(series): consolidation copies, stamps and restores series"
```

---

### Task 9: Verification

**Files:** none new.

- [ ] **Step 1: No legacy writes remain**

```bash
grep -rn "into(_db.diveProfiles)\|update(_db.diveProfiles)\|into(_db.tankPressureProfiles)\|update(_db.tankPressureProfiles)\|update(db.diveProfiles)\|into(db.diveProfiles)\|into(db.tankPressureProfiles)\|update(db.tankPressureProfiles)\|INSERT INTO dive_profiles\|UPDATE dive_profiles SET is_primary\|INSERT INTO tank_pressure_profiles\|UPDATE tank_pressure_profiles" lib --include='*.dart' | grep -v "database.dart\|database.g.dart\|profile_series_pack\|sync_data_serializer.dart\|diver_repository.dart\|dive_computer_repository_impl.dart:37[0-9]\|dive_computer_repository_impl.dart:52[0-9]"
grep -rn "batch.insert(\s*$" -A 1 lib --include='*.dart' | grep "diveProfiles\|tankPressureProfiles" | grep -v "database.g.dart"
grep -rn "logDeletion(entityType: 'diveProfiles'\|logDeletion(entityType: 'tankPressureProfiles'\|entityType: 'diveProfiles',\|entityType: 'tankPressureProfiles'," lib --include='*.dart' | grep -v sync_data_serializer.dart
```

Expected: every command prints nothing. The exclusions are plan 2d's: the sync serializer's apply / delete sites and the `UPDATE dive_profiles SET computer_id = NULL` computer-unlink statements in `diver_repository.dart` and `dive_computer_repository_impl.dart`.

- [ ] **Step 2: Run every test file this plan created or touched, individually**

The eleven new files, every migrated file named in Tasks 2 to 8, plus: `profile_series_repository_test.dart`, `profile_series_repository_restore_test.dart`, `tank_pressure_series_repository_test.dart`, `dive_repository_series_reads_test.dart`, `profiles_by_data_source_series_test.dart`, `batch_summaries_series_test.dart`, `tank_pressure_series_reads_test.dart`, `dive_computer_series_reads_test.dart`, `profile_series_pack_test.dart`, `migration_v182_profile_series_test.dart`, `database_import_graph_test.dart`, `test/core/data/repositories/sync_hlc_targets_test.dart` (or whatever the hlc registration test is called), `uddf_round_trip_test.dart`, `dive_providers_test.dart`, `profile_analysis_tick_reactivity_test.dart`.

Expected: every file passes.

- [ ] **Step 3: Format, analyze, layering**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test test/core/database/database_import_graph_test.dart
```

Expected: exit 0, "No issues found!", pass.

- [ ] **Step 4: Full suite once**

Background, output to the session scratchpad `full-suite-2c.log` with `exit=$?` appended. Known machine flakes: `local_file_resolver_test.dart` (mounted `$TMPDIR`; passes with `TMPDIR=/private/tmp/claude-501/sysvol-tmp`), `changeset_writer_test.dart`, `backup_encryption_service_test.dart`, `database_security_service_test.dart`. Any other failure: rerun the file alone once; a repeat is real. Any failure in a file this plan touched, or under `test/core/database/`, `test/features/dive_log/`, `test/features/dive_computer/`, `test/core/services/sync/`, is real.

- [ ] **Step 5: Report**

The commit list from `git log --oneline 879a9cf1624..HEAD`, the grep results, the per-file results, the full-suite summary and exit, flake reruns.

---

## Self-review

**Spec coverage.** Section 6 "Writes": `insertSeries` (exists), `replaceSeriesOwnedBy` is expressed as delete-then-insert at the two sites that need it (reparse: `deleteByComputer` + `insertSeries`; consolidation copies without deleting, as the legacy did); `demoteAll` and `promote...` (exist, used in Tasks 2, 3, 6); `deleteSeriesOwnedBy` / `deleteSeriesForDive` (`deleteOwnedBy`, `deleteByComputer`, `deleteByIds`, `deleteForDive`); tank equivalents keyed by `(diveId, tankId, computerId)` (Task 1, 4, 5, 6, 7, 8). "Semantics preserved exactly": manual edit (Task 2), restore (Task 2), split and merge (Tasks 6, 7), consolidation undo via snapshot series rows with `insertOrReplace` (`restoreSeriesRow`, Tasks 7, 8), primary-source swap marking per series (Task 2 through `demoteAll` / `promoteWinnerOwnedBy`). "Exact-duplicate dedupe moves to encode time" (the repositories, plus the stable sort added in Task 1). Section 3 "decode only in the repositories": every service consumes entities; the snapshot carries raw rows for verbatim restore and never decodes. Section 12 risk "a writer left behind": Task 9 Step 1 greps for every legacy write shape and names the 2d exclusions explicitly.

Not in this plan by design: sync apply / delete of the legacy entities and the receive-side packing shim (2d); the `UPDATE dive_profiles SET computer_id = NULL` unlink statements (2d, they become no-ops once the tables go and the series FK is `ON DELETE SET NULL`); `watchStatisticsChanges` and the SQL predicates (2d); dropping the legacy tables, the `_...Legacy` fallbacks, `TankPressurePoint.id`, `DiveMergeSnapshot.profileRows` / `tankPressureRows`, the remaining legacy seed helpers in tests (2e).

**Placeholder scan.** Every test in Tasks 1 to 8 is written out with its seeds, its call and its assertions. What the plan does not repeat is the 40 to 60 line seeding fixture of a sibling test file (reparse, split, merge, consolidation): each such task names the file and the helper signatures to copy, and the tests above them call those helpers by name. Two spots reference a fixture value rather than a literal (the target tank id in Task 8's stamp test, the fifteen-minute spacing in Task 7's `createDive` calls) and say where it comes from. No "add error handling", no "similar to Task N" (Task 8's restore loops are spelled out by reference to Task 7's code block with the same names).

**Type consistency.** `insertSeries` parameter names (`diveId`, `computerId`, `sourceId`, `isPrimary`, `samples`, `id`, `now` on profiles; `diveId`, `tankId`, `computerId`, `samples`, `id`, `now` on tanks) match plan 2a and every call in Tasks 2 to 8. `deleteByComputer(String diveId, String? computerId)` (Task 1) is called with `(diveId, computerId)` in Tasks 3 and 5. `reassignTank(diveId, fromTankId, toTankId, {now})` / `swapTanks(diveId, a, b, {now})` (Task 1) match Task 4. `stampComputerWhereNull(diveId, computerId, {now})` (Task 1) matches Task 8. `getRowsForDives(List<String>)` (Task 1) matches Tasks 7 and 8; `restoreSeriesRow(row, {markPending, now})` (2a) matches Tasks 7 and 8. `shiftedBy(int)` (Task 1) matches Tasks 7 and 8. `ProfileSeriesRepository({syncRepository, database})` / `SyncRepository({database})` (Task 1) match Tasks 5 and 7. `promoteOwnedBy(diveId, {sourceId, computerId, now})` and `hasPrimarySeries(diveId)` (2a) match Task 6. `adoptUnattributed(diveId, sourceId, {now})` and `ownsAny(diveId, {sourceId, computerId})` (Task 1) match Task 2.
