# Cylinder Passports Fleet Phase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record which tagged cylinder each dive tank came from (`dive_tanks.passport_id`) and show "You have used this cylinder N times" with the dives on the foreign and own passports.

**Architecture:** A nullable identity column on `dive_tanks` (rung 287), threaded through the entity and every hand-built tank row, stamped by the tank editor and the foreign passport's "Use on a dive". A read-only `PassportUsageRepository` derives the dives per passport id for the active diver; a shared `PassportUsageCard` renders them on both passport pages, and the tank editor's scan snack bar names the earlier-use count.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod 3, go_router, ARB l10n.

**Spec:** [docs/design/specs/2026-10-12-cylinder-passports-fleet-design.md](../specs/2026-10-12-cylinder-passports-fleet-design.md)

## Global Constraints

- Schema rung: 287 (renumbered from 285 and then 286 at merge time, after #3306 and #3319 shipped those). `currentSchemaVersion = 287`; 282 is held by open PR #3133. Re-check main before pushing.
- `passport_id` is user-authored identity: downloads, re-parse and re-import never write it; `dive_tanks.equipment_id` stays the transmitter registry's.
- No backfill of existing rows; the floor (`minimumCompatibleSchemaVersion`) does not move.
- Nothing new goes into `database.dart` beyond the version constant and the `migrationVersions` entry. Helpers live in `lib/core/database/migrations/helpers/`, rungs in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, the every-open backstop in `before_open_child_columns.dart`.
- Usage counts only dives whose `diver_id` is the active diver (all dives when no diver id, like `DiveRepository` list reads); a dive counts once however many of its tanks match.
- Every displayed date goes through `UnitFormatter`; every string goes into all 11 ARB files (feature-grouped: insert next to the `passport_foreign_*` / `passport_scan_*` keys); plurals use `one`/`other` with `{count}`, never a hardcoded digit.
- No em dashes anywhere (code, comments, ARB, commits). No emojis.
- `dart format .` and `flutter analyze` clean before every commit; run `test/architecture/` and `test/shared/` after adding files under `lib/`.

## Review Focus

1. **A tag that carries only its identity** (no size, no mix): the tank keeps its spec and preset, and still gets the passport id. Pinned in Task 4.
2. **A custom default preset that loads after a "Use on a dive" prefill** replaces the untouched first tank: it must keep the passport id. Pinned in Task 5.
3. **Picking None in the trip slot picker** after a scan keeps the passport id; picking a real slot clears it. Pinned in Task 4.
4. **Re-scanning a cylinder on the dive being edited** must not count that dive as an earlier use. Pinned in Task 7.
5. **A usage lookup that throws during a scan** must not turn a successful fill into a failure message. Pinned in Task 7.

---

### Task 1: Schema rung 287 and the entity field

**Files:**
- Modify: `lib/core/database/tables/dive_tables.dart` (class `DiveTanks`, after `sourceId`)
- Modify: `lib/core/database/migrations/helpers/dive_migrations.dart` (after `_assertTankUsageDurationColumn`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v286 block)
- Modify: `lib/core/database/migrations/before_open_child_columns.dart`
- Modify: `lib/core/database/performance_indexes.dart` (after `idx_dive_tanks_equipment`)
- Modify: `lib/core/database/database.dart:265` and the `migrationVersions` list
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (class `DiveTank`)
- Modify: `test/core/database/migration_v284_profile_metric_colors_test.dart` only if it asserts the exact current version (it uses `greaterThanOrEqualTo`, so expect no change)
- Create: `test/core/database/migration_v287_tank_passport_id_test.dart`
- Create: `test/features/dive_log/domain/entities/dive_tank_passport_id_test.dart`

**Interfaces:**
- Produces: column `DiveTanks.passportId` (`TextColumn`, nullable), generated `DiveTank.passportId` on the Drift row class and `DiveTanksCompanion.passportId`; domain `DiveTank.passportId` (`String?`), `DiveTank.copyWith({String? passportId, bool clearPassportId = false})`; index `idx_dive_tanks_passport_id`.

- [ ] **Step 1: Write the failing migration test**

`test/core/database/migration_v287_tank_passport_id_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v287: dive_tanks.passport_id, the tagged cylinder a tank came
/// from (issue #2650).
void main() {
  /// A v286 database whose dive_tanks lacks the column.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 286');
      rawDb.execute(
        'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
        "dive_id TEXT NOT NULL, tank_role TEXT NOT NULL DEFAULT 'backGas')",
      );
      rawDb.execute(
        'INSERT INTO dive_tanks (id, dive_id, tank_role) '
        "VALUES ('t1', 'd1', 'stage')",
      );
    },
  );

  test('v287 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(287));
    expect(AppDatabase.migrationVersions, contains(287));
    expect(
      AppDatabase.migrationStepCount(286),
      AppDatabase.migrationStepCount(287) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(287));
  });

  test('upgrading from v286 adds a null passport_id and keeps the row', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final rows = await db
        .customSelect('SELECT tank_role, passport_id FROM dive_tanks')
        .get();
    expect(rows.single.read<String>('tank_role'), 'stage');
    expect(rows.single.read<String?>('passport_id'), isNull);
  });

  test('a fresh database has the column and its index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await db
        .customSelect("PRAGMA table_info('dive_tanks')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('passport_id'));
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_dive_tanks_passport_id'",
        )
        .get();
    expect(idx, hasLength(1));
  });
}
```

- [ ] **Step 2: Write the failing entity test**

`test/features/dive_log/domain/entities/dive_tank_passport_id_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  const tank = DiveTank(id: 't1', passportId: 'p-1');

  test('copyWith keeps, replaces and clears the passport id', () {
    expect(tank.copyWith(startPressure: 200).passportId, 'p-1');
    expect(tank.copyWith(passportId: 'p-2').passportId, 'p-2');
    expect(tank.copyWith(clearPassportId: true).passportId, isNull);
  });

  test('the passport id is part of equality', () {
    expect(tank, isNot(const DiveTank(id: 't1')));
    expect(tank, const DiveTank(id: 't1', passportId: 'p-1'));
  });
}
```

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/core/database/migration_v287_tank_passport_id_test.dart test/features/dive_log/domain/entities/dive_tank_passport_id_test.dart`
Expected: FAIL (compile error: no named parameter `passportId`; migration test fails on the version).

- [ ] **Step 4: Add the column**

In `lib/core/database/tables/dive_tables.dart`, class `DiveTanks`, directly after the `sourceId` column:

```dart
  /// v287: the passport id of the tagged cylinder this tank was filled
  /// from (issue #2650), set when the diver scanned a tag or picked a
  /// cylinder that has one. An identity, not a link: a rental's id has no
  /// equipment row. User-authored; downloads and re-parses never write it.
  TextColumn get passportId => text().nullable()();
```

- [ ] **Step 5: Add the idempotent helper**

In `lib/core/database/migrations/helpers/dive_migrations.dart`, after `_assertTankUsageDurationColumn`:

```dart
  /// Idempotent DDL for the v287 dive_tanks.passport_id column (issue
  /// #2650). Called from the v287 rung and re-asserted in beforeOpen like
  /// the other column-assert helpers. Its index is a performance index.
  Future<void> _assertTankPassportIdColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_tanks')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('passport_id')) return;
    await customStatement('ALTER TABLE dive_tanks ADD COLUMN passport_id TEXT');
  }
```

- [ ] **Step 6: Add the rung, the backstop and the index**

Append to the end of the ladder method in `rungs_v231_onward.dart`, after the `if (from < 286) await reportProgress();` line:

```dart
    // v287: dive_tanks.passport_id (issue #2650). Column only, no backfill:
    // nothing recorded which tag an older tank came from. Re-asserted in
    // beforeOpen; the index is in performance_indexes.dart.
    if (from < 287) {
      await _assertTankPassportIdColumn();
    }
    if (from < 287) await reportProgress();
```

In `before_open_child_columns.dart`, after `await _assertTankUsageDurationColumn();`:

```dart

    // v287: dive_tanks.passport_id (issue #2650).
    await _assertTankPassportIdColumn();
```

and update the method's caller comment in `before_open.dart` ("v194, v254, v259 and v270 backstops") to read "v194, v254, v259, v270 and v287 backstops".

In `performance_indexes.dart`, after the `idx_dive_tanks_equipment` entry:

```dart
  // v287: a passport's usage card finds the dives whose tanks came from one
  // tagged cylinder (issue #2650).
  (
    name: 'idx_dive_tanks_passport_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_tanks_passport_id '
        'ON dive_tanks(passport_id)',
  ),
```

In `database.dart`: `static const int currentSchemaVersion = 287;` and append after the `286,` entry:

```dart
    // v287: dive_tanks.passport_id (issue #2650). Additive nullable column,
    // so the floor stays at 280.
    287,
```

- [ ] **Step 7: Add the entity field**

In `lib/features/dive_log/domain/entities/dive.dart`, class `DiveTank`:

Field, after `tripCylinderId`:

```dart
  /// The passport id of the tagged cylinder this tank was filled from (v287,
  /// issue #2650): set by a scan or a pick of a cylinder that has one,
  /// cleared by a preset or a trip slot. An identity, not a link, so a
  /// rental with no gear row still counts its uses. User-authored like
  /// [tripCylinderId]: downloads never touch it.
  final String? passportId;
```

Constructor: add `this.passportId,` after `this.tripCylinderId,`.

`copyWith` parameters: add after `bool clearTripCylinderId = false,`:

```dart
    String? passportId,
    bool clearPassportId = false,
```

`copyWith` body: add after the `tripCylinderId:` entry:

```dart
      passportId: clearPassportId ? null : (passportId ?? this.passportId),
```

`props`: add `passportId,` after `tripCylinderId,`.

- [ ] **Step 8: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes; `database.g.dart` gains `passportId` on `DiveTank` and `DiveTanksCompanion`.

- [ ] **Step 9: Run the tests to verify they pass**

Run: `flutter test test/core/database/migration_v287_tank_passport_id_test.dart test/features/dive_log/domain/entities/dive_tank_passport_id_test.dart test/core/database/`
Expected: PASS. If an older migration test asserts `currentSchemaVersion` equals 286 exactly, relax it to `greaterThanOrEqualTo(286)` as the v259 test does.

- [ ] **Step 10: Commit**

```bash
dart format lib/core/database lib/features/dive_log/domain test/core/database test/features/dive_log/domain
git add lib/core/database/tables/dive_tables.dart lib/core/database/migrations/helpers/dive_migrations.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/database/migrations/before_open_child_columns.dart lib/core/database/migrations/before_open.dart lib/core/database/performance_indexes.dart lib/core/database/database.dart lib/features/dive_log/domain/entities/dive.dart test/core/database/migration_v287_tank_passport_id_test.dart test/features/dive_log/domain/entities/dive_tank_passport_id_test.dart
git commit -m "feat(dive-log): add dive_tanks.passport_id (schema v287)"
```

---

### Task 2: Keep the passport id on every tank write path

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (createDive batch insert near line 1925; updateDive update near 2262 and insert near 2300; full mapper near 4244; list mapper near 4695; `_tankCompanion` near 7188)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` (`_tanksFromRows`, near line 395)
- Modify: `lib/features/dive_log/domain/services/sequential_tank_merge.dart` (`_fold`, near line 182)
- Create: `test/features/dive_log/data/repositories/dive_tank_passport_id_test.dart`
- Modify: `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart` (one new test)
- Create: `test/features/dive_log/domain/services/sequential_tank_merge_passport_test.dart`
- Modify: `test/features/dive_centers/domain/services/rental_memory_resolver_test.dart` if it exists, else create it beside the resolver's other tests (one test)

**Interfaces:**
- Consumes: `DiveTank.passportId`, `DiveTanksCompanion.passportId`, Drift row `DiveTank.passportId` (Task 1).
- Produces: `DiveRepository.getDiveById` and the list reads return `passportId`; `createDive`/`updateDive` persist it; `bulkReplaceTanks(..., restoreLinks: true)` restores it.

- [ ] **Step 1: Write the failing repository tests**

`test/features/dive_log/data/repositories/dive_tank_passport_id_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  test('the passport id survives create, read and update', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tanks: const [DiveTank(id: 't1', passportId: 'p-1')],
      ),
    );
    final loaded = (await repo.getDiveById('d1'))!;
    expect(loaded.tanks.single.passportId, 'p-1');

    // An edit that rebuilds the tank keeps it.
    await repo.updateDive(
      loaded.copyWith(
        tanks: [loaded.tanks.single.copyWith(startPressure: 200)],
      ),
    );
    final edited = (await repo.getDiveById('d1'))!;
    expect(edited.tanks.single.passportId, 'p-1');

    // An explicit clear removes it.
    await repo.updateDive(
      edited.copyWith(
        tanks: [edited.tanks.single.copyWith(clearPassportId: true)],
      ),
    );
    expect((await repo.getDiveById('d1'))!.tanks.single.passportId, isNull);
  });

  test('a tank added on update carries its passport id', () async {
    await repo.createDive(createTestDiveWithBottomTime(id: 'd1'));
    final loaded = (await repo.getDiveById('d1'))!;
    await repo.updateDive(
      loaded.copyWith(
        tanks: [...loaded.tanks, const DiveTank(id: 't9', passportId: 'p-9')],
      ),
    );
    final tanks = (await repo.getDiveById('d1'))!.tanks;
    expect(tanks.singleWhere((t) => t.id == 't9').passportId, 'p-9');
  });

  test('the list mapper carries it too', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tanks: const [DiveTank(id: 't1', passportId: 'p-1')],
      ),
    );
    final listed = await repo.getDivesByIds(['d1']);
    expect(listed.single.tanks.single.passportId, 'p-1');
  });

  test('a bulk replace stamps it only when restoring', () async {
    await repo.createDive(createTestDiveWithBottomTime(id: 'd1'));
    await repo.createDive(createTestDiveWithBottomTime(id: 'd2'));
    const template = DiveTank(id: 'tpl', passportId: 'p-1');

    // A template copied from one tagged tank must not claim that physical
    // cylinder on every dive it lands on.
    await repo.bulkReplaceTanks(['d1'], const [template]);
    expect((await repo.getDiveById('d1'))!.tanks.single.passportId, isNull);

    await repo.bulkReplaceTanks(['d2'], const [template], restoreLinks: true);
    expect((await repo.getDiveById('d2'))!.tanks.single.passportId, 'p-1');
  });
}
```

If `getDivesByIds` is not the list read that uses the second mapper (near line 4695), use the method that does: read the enclosing method name around that line and call it instead.

- [ ] **Step 2: Write the failing undo test**

Append to `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`, beside `'undoing a tank replace restores its recorded usage (#1496)'`, using that file's `seed` and `tank` helpers:

```dart
  test('undoing a tank replace restores its passport id (#2650)', () async {
    await seed('d1');
    await diveRepo.bulkAddTank(['d1'], tank('OrigTank'));
    await db.customStatement("UPDATE dive_tanks SET passport_id = 'p-1'");
    final snap = await service.apply(
      BulkEditRequest(
        diveIds: const ['d1'],
        ops: [
          TanksOp(mode: BulkCollectionMode.replace, tanks: [tank('NewTank')]),
        ],
      ),
    );

    await service.undo(snap);

    final row = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals('d1'))).getSingle();
    expect(row.tankName, 'OrigTank');
    expect(row.passportId, 'p-1');
  });
```

- [ ] **Step 3: Write the failing merge and rental-memory tests**

Create `test/features/dive_log/domain/services/sequential_tank_merge_passport_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/sequential_tank_merge.dart';

void main() {
  var n = 0;
  String id() => 'm${n++}';

  Dive half(String diveId, DiveTank tank, DateTime at) =>
      Dive(id: diveId, dateTime: at, tanks: [tank]);

  test('one cylinder across two halves keeps the passport id (#2650)', () {
    final merged = mergeSequentialTanks([
      half(
        'd1',
        const DiveTank(
          id: 'a',
          gasMix: GasMix(o2: 32),
          startPressure: 200,
          endPressure: 120,
        ),
        DateTime.utc(2026, 1, 1, 10),
      ),
      half(
        'd2',
        const DiveTank(
          id: 'b',
          gasMix: GasMix(o2: 32),
          startPressure: 120,
          endPressure: 60,
          passportId: 'p-1',
        ),
        DateTime.utc(2026, 1, 1, 11),
      ),
    ], idGenerator: id);
    expect(merged.tanks, hasLength(1));
    expect(merged.tanks.single.passportId, 'p-1');
  });
}
```

The two halves match on gas mix with a non-rising pressure, so they fold into one cylinder; the later half's id fills the earlier half that has none.

For `RentalMemory.tanksForNewDive` (in `lib/features/dive_centers/domain/services/rental_memory_resolver.dart`), add a test that a source tank with `passportId: 'p-1'` produces a new-dive tank whose `passportId` is null. Build the `RentalMemory` the way the existing resolver tests do.

- [ ] **Step 4: Run them to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_tank_passport_id_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`
Expected: FAIL (passport id read back as null). The rental-memory test already passes (the copy names its fields); keep it as the pin.

- [ ] **Step 5: Thread it through `dive_repository_impl.dart`**

createDive batch insert (`DiveTanksCompanion(` near line 1925): after the `tripCylinderId:` entry add

```dart
                passportId: Value(tank.passportId),
```

updateDive existing-tank update (near line 2262): after the `tripCylinderId:` entry add

```dart
                // The tagged cylinder is user-authored like the slot, so an
                // edit writes it (issue #2650).
                passportId: Value(tank.passportId),
```

updateDive new-tank insert (near line 2300): after the `tripCylinderId:` entry add

```dart
                    passportId: Value(tank.passportId),
```

Both row-to-entity mappers (near lines 4244 and 4695): after `tripCylinderId: t.tripCylinderId,` add

```dart
              passportId: t.passportId,
```

`_tankCompanion` (near line 7188): after the `tripCylinderId:` entry add

```dart
    // The tagged cylinder (issue #2650): one physical tank, so a template
    // applied to many dives never carries it; only a restore writes it.
    passportId: withLink ? Value(t.passportId) : const Value.absent(),
```

Then run `grep -n "DiveTanksCompanion(\|domain.DiveTank(" lib/features/dive_log/data/repositories/dive_repository_impl.dart` and confirm every site that writes `tripCylinderId` now also writes `passportId`; sites that do not write `tripCylinderId` (computer-owned partial updates) stay untouched.

- [ ] **Step 6: Thread it through undo and the merge fold**

`bulk_dive_edit_service.dart`, `_tanksFromRows`, after `tripCylinderId: r.tripCylinderId,`:

```dart
        // The tagged cylinder (#2650), restore-only like the slot.
        passportId: r.passportId,
```

`sequential_tank_merge.dart`, `_fold`, after the `tripCylinderId:` entry:

```dart
  passportId: earlier.passportId ?? later.passportId,
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/dive_tank_passport_id_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart test/features/dive_log/domain/services/ test/features/dive_centers/`
Expected: PASS.

- [ ] **Step 8: Pin sync and the whole-row copy paths**

Add to `dive_tank_passport_id_test.dart`:

```dart
  test('a sync export and re-import of a tank row keeps it', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tanks: const [DiveTank(id: 't1', passportId: 'p-1')],
      ),
    );
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('t1'))).getSingle();
    // Sync ships dive_tanks rows as their Drift JSON (sync_data_serializer
    // diveTanks arm), so the column round-trips through toJson/fromJson.
    final copy = DiveTank.fromJson(row.toJson());
    expect(copy.passportId, 'p-1');
  });
```

with imports `package:submersion/core/services/database_service.dart` and `package:submersion/core/database/database.dart` show `DiveTank` under a prefix (for example `import 'package:submersion/core/database/database.dart' as db_rows;` and `db_rows.DiveTank.fromJson`) so it does not clash with the domain `DiveTank`.

Run: `flutter test test/features/dive_log/data/repositories/dive_tank_passport_id_test.dart test/core/services/sync/`
Expected: PASS (the serializer batch coverage test needs no new entry: no new entity).

- [ ] **Step 9: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log test/features/dive_centers
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/data/services/bulk_dive_edit_service.dart lib/features/dive_log/domain/services/sequential_tank_merge.dart test/features/dive_log/data/repositories/dive_tank_passport_id_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart
git add test/features/dive_log/domain/services/sequential_tank_merge_passport_test.dart <the rental-memory test file touched in Step 3>
git commit -m "feat(dive-log): keep a tank's passport id through edits, undo and merges"
```

---

### Task 3: Passport usage repository and provider

**Files:**
- Create: `lib/features/cylinder_passports/domain/entities/passport_usage.dart`
- Create: `lib/features/cylinder_passports/data/repositories/passport_usage_repository.dart`
- Modify: `lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart`
- Create: `test/features/cylinder_passports/data/repositories/passport_usage_repository_test.dart`

**Interfaces:**
- Consumes: `dive_tanks.passport_id` (Task 1), persisted by `DiveRepository.createDive` (Task 2).
- Produces:
  - `class PassportUsageDive { final String diveId; final DateTime dateTime; final int? diveNumber; final String? siteName; }` (Equatable, const constructor with named required `diveId`, `dateTime`).
  - `class PassportUsageRepository { Future<List<PassportUsageDive>> usageFor(String passportId, {required String? diverId, String? excludeDiveId}); Stream<void> watchChanges(); }`
  - `final passportUsageRepositoryProvider = Provider<PassportUsageRepository>`
  - `final passportUsageProvider = FutureProvider.family<List<PassportUsageDive>, String>` (keyed by passport id; watches `validatedCurrentDiverIdProvider`, refreshes on `watchChanges()`).

- [ ] **Step 1: Write the failing repository test**

`test/features/cylinder_passports/data/repositories/passport_usage_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/passport_usage_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository dives;
  final usage = PassportUsageRepository();

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> dive(
    String id,
    DateTime at, {
    String? diverId,
    int? number,
    String? siteId,
    List<String?> passports = const ['p-1'],
  }) => dives.createDive(
    Dive(
      id: id,
      diverId: diverId,
      diveNumber: number,
      dateTime: at,
      site: siteId == null ? null : DiveSite(id: siteId, name: 'Bari Reef'),
      tanks: [
        for (var i = 0; i < passports.length; i++)
          DiveTank(id: '$id-t$i', order: i, passportId: passports[i]),
      ],
    ),
  );

  test('lists the matching dives newest first with site and number', () async {
    await SiteRepository().createSite(
      const DiveSite(id: 's1', name: 'Bari Reef'),
    );
    await dive('old', DateTime.utc(2025, 3, 10), number: 7);
    await dive('new', DateTime.utc(2026, 3, 12), number: 41, siteId: 's1');
    await dive('other', DateTime.utc(2026, 4, 1), passports: const ['p-2']);

    final result = await usage.usageFor('p-1', diverId: null);
    expect(result.map((d) => d.diveId), ['new', 'old']);
    expect(result.first.siteName, 'Bari Reef');
    expect(result.first.diveNumber, 41);
    expect(result.first.dateTime, DateTime.utc(2026, 3, 12));
    expect(result.last.siteName, isNull);
  });

  test('a dive with two tanks from one tag counts once', () async {
    await dive('d1', DateTime.utc(2026, 1, 1), passports: const ['p-1', 'p-1']);
    expect(await usage.usageFor('p-1', diverId: null), hasLength(1));
  });

  test('counts only the given diver', () async {
    await dive('mine', DateTime.utc(2026, 1, 1), diverId: 'me');
    await dive('theirs', DateTime.utc(2026, 1, 2), diverId: 'buddy');
    final result = await usage.usageFor('p-1', diverId: 'me');
    expect(result.map((d) => d.diveId), ['mine']);
  });

  test('leaves out the dive being edited', () async {
    await dive('a', DateTime.utc(2026, 1, 1));
    await dive('b', DateTime.utc(2026, 1, 2));
    final result = await usage.usageFor(
      'p-1',
      diverId: null,
      excludeDiveId: 'b',
    );
    expect(result.map((d) => d.diveId), ['a']);
  });

  test('a passport never used gives nothing', () async {
    await dive('a', DateTime.utc(2026, 1, 1), passports: const [null]);
    expect(await usage.usageFor('p-1', diverId: null), isEmpty);
  });
}
```

Before running, check how `Dive` carries its site (`site:` with a `DiveSite`, or `siteId:`) and how `SiteRepository.createSite` is named, and adjust the seed helper to the real API; the assertions stay as written. If the site row must exist for the FK, keep the `createSite` call.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/cylinder_passports/data/repositories/passport_usage_repository_test.dart`
Expected: FAIL (compile error: `passport_usage_repository.dart` not found).

- [ ] **Step 3: Write the entity**

`lib/features/cylinder_passports/domain/entities/passport_usage.dart`:

```dart
import 'package:equatable/equatable.dart';

/// One dive whose tanks came from a tagged cylinder (issue #2650): what the
/// passport's usage card lists for it.
class PassportUsageDive extends Equatable {
  final String diveId;

  /// The dive's date and time, wall clock stored as UTC like every dive.
  final DateTime dateTime;
  final int? diveNumber;

  /// Null when the dive has no site.
  final String? siteName;

  const PassportUsageDive({
    required this.diveId,
    required this.dateTime,
    this.diveNumber,
    this.siteName,
  });

  PassportUsageDive copyWith({
    String? diveId,
    DateTime? dateTime,
    int? diveNumber,
    String? siteName,
  }) => PassportUsageDive(
    diveId: diveId ?? this.diveId,
    dateTime: dateTime ?? this.dateTime,
    diveNumber: diveNumber ?? this.diveNumber,
    siteName: siteName ?? this.siteName,
  );

  @override
  List<Object?> get props => [diveId, dateTime, diveNumber, siteName];
}
```

- [ ] **Step 4: Write the repository**

`lib/features/cylinder_passports/data/repositories/passport_usage_repository.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/passport_usage.dart';

/// The dives a tagged cylinder was used on (issue #2650), derived from
/// `dive_tanks.passport_id`. Read-only: stamping happens where tanks are
/// edited.
class PassportUsageRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  /// The distinct dives with a tank whose passport id is [passportId],
  /// newest first. [diverId] limits them to that diver's dives (all dives
  /// when null, like the dive list); [excludeDiveId] leaves one out.
  Future<List<PassportUsageDive>> usageFor(
    String passportId, {
    required String? diverId,
    String? excludeDiveId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT d.id AS dive_id, d.dive_date_time AS dive_date_time, '
          'd.dive_number AS dive_number, s.name AS site_name '
          'FROM dives d '
          'LEFT JOIN dive_sites s ON s.id = d.site_id '
          'WHERE EXISTS (SELECT 1 FROM dive_tanks t '
          'WHERE t.dive_id = d.id AND t.passport_id = ?) '
          '${diverId == null ? '' : 'AND d.diver_id = ? '}'
          '${excludeDiveId == null ? '' : 'AND d.id != ? '}'
          'ORDER BY d.dive_date_time DESC, d.id',
          variables: [
            Variable.withString(passportId),
            if (diverId != null) Variable.withString(diverId),
            if (excludeDiveId != null) Variable.withString(excludeDiveId),
          ],
          readsFrom: {_db.dives, _db.diveTanks, _db.diveSites},
        )
        .get();
    return [
      for (final r in rows)
        PassportUsageDive(
          diveId: r.read<String>('dive_id'),
          dateTime: DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('dive_date_time'),
            isUtc: true,
          ),
          diveNumber: r.read<int?>('dive_number'),
          siteName: r.read<String?>('site_name'),
        ),
    ];
  }

  /// Ticks when a dive, a tank or a site changes, so a usage card refreshes.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.dives),
      TableUpdateQuery.onTable(_db.diveTanks),
      TableUpdateQuery.onTable(_db.diveSites),
    ]),
  );
}
```

- [ ] **Step 5: Run the repository test to verify it passes**

Run: `flutter test test/features/cylinder_passports/data/repositories/passport_usage_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Add the providers**

In `cylinder_passport_providers.dart`, add imports for `passport_usage_repository.dart`, `passport_usage.dart` and `package:submersion/features/divers/presentation/providers/diver_providers.dart`, then:

```dart
final passportUsageRepositoryProvider = Provider<PassportUsageRepository>(
  (ref) => PassportUsageRepository(),
);

/// The active diver's dives with a tank from the cylinder whose passport id
/// is the key, newest first (issue #2650).
final passportUsageProvider =
    FutureProvider.family<List<PassportUsageDive>, String>((
      ref,
      passportId,
    ) async {
      final repository = ref.watch(passportUsageRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      return repository.usageFor(passportId, diverId: diverId);
    });
```

If importing `diver_providers.dart` here creates an import cycle that `flutter analyze` or `test/architecture/` reports, move `passportUsageProvider` into a new file `lib/features/cylinder_passports/presentation/providers/passport_usage_providers.dart` with the same content.

- [ ] **Step 7: Run analyze and the architecture guards**

Run: `flutter analyze lib/features/cylinder_passports && flutter test test/architecture/ test/shared/`
Expected: no issues; PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/cylinder_passports test/features/cylinder_passports
git add lib/features/cylinder_passports/domain/entities/passport_usage.dart lib/features/cylinder_passports/data/repositories/passport_usage_repository.dart lib/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart test/features/cylinder_passports/data/repositories/passport_usage_repository_test.dart
git commit -m "feat(cylinder-passports): read the dives a tagged cylinder was used on"
```

---

### Task 4: Stamp the passport id in the tank editor

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart`
- Modify: `test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart`
- Modify: `test/features/dive_log/presentation/widgets/tank_editor_own_cylinder_test.dart`
- Modify: `test/features/dive_log/presentation/widgets/tank_editor_preset_cylinders_test.dart`
- Modify: `test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart`

**Interfaces:**
- Consumes: `DiveTank.passportId`/`clearPassportId` (Task 1); `cylinderPassportRepositoryProvider` and `CylinderPassportRepository.getPassportId(String equipmentId)` (existing).
- Produces: every `onChanged` tank carries `passportId` per spec section 6.1.

- [ ] **Step 1: Write the failing scan tests**

In `tank_editor_scan_test.dart` (its `pump`, `scan`, `own`, `stranger`, `ownId` and `al80Tank` are in scope), add:

```dart
  group('passport id (#2650)', () {
    testWidgets('a foreign scan stamps the tag id', (tester) async {
      DiveTank? changed;
      await pump(
        tester,
        scanned: 'https://submersion.app/c#f=1&p=$stranger&v=10',
        onChanged: (t) => changed = t,
      );
      await scan(tester);
      expect(changed!.passportId, stranger);
    });

    testWidgets('an own scan stamps the tag id', (tester) async {
      DiveTank? changed;
      await pump(
        tester,
        scanned: 'https://submersion.app/c#f=1&p=$own',
        onChanged: (t) => changed = t,
        onOwnCylinderUsed: (_) async {},
      );
      await scan(tester);
      expect(changed!.passportId, own);
    });

    testWidgets('an identity-only tag stamps the id and keeps the spec', (
      tester,
    ) async {
      DiveTank? changed;
      final l10n = await pump(
        tester,
        scanned: 'https://submersion.app/c#f=1&p=$stranger',
        onChanged: (t) => changed = t,
        tank: al80Tank,
      );
      await scan(tester);
      expect(changed!.passportId, stranger);
      expect(changed!.presetName, 'al80');
      expect(changed!.volume, 11.1);
      expect(find.text(l10n.passport_foreign_noDetails), findsOneWidget);
    });

    testWidgets('a hand edit keeps the id', (tester) async {
      DiveTank? changed;
      await pump(
        tester,
        scanned: null,
        onChanged: (t) => changed = t,
        tank: al80Tank.copyWith(passportId: 'p-1'),
      );
      await tester.enterText(find.byKey(const Key('tank-o2-field')), '32');
      await tester.pumpAndSettle();
      expect(changed!.passportId, 'p-1');
    });

    testWidgets('a preset clears the id', (tester) async {
      DiveTank? changed;
      await pump(
        tester,
        scanned: null,
        onChanged: (t) => changed = t,
        tank: al80Tank.copyWith(passportId: 'p-1'),
      );
      await tester.tap(find.byKey(const Key('tank-preset-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HP100').last);
      await tester.pumpAndSettle();
      expect(changed!.passportId, isNull);
    });
  });
```

Replace the existing test `'a tag with no details changes nothing and says so'` with the identity-only test above (its `expect(changed, isNull)` no longer holds: the tag now identifies the cylinder). For the O2 field and the preset item, use the keys and labels the existing tests in `tank_editor_test.dart` and `tank_editor_preset_cylinders_test.dart` already use (read them; adjust `Key('tank-o2-field')` and `'HP100'` to match).

- [ ] **Step 2: Write the failing pick and slot tests**

In `tank_editor_own_cylinder_test.dart`, beside `'a picked cylinder fills spec and newest fill, and joins the '`, add a test that assigns a passport id to the seeded cylinder first:

```dart
  testWidgets('a picked cylinder stamps its passport id (#2650)', (
    tester,
  ) async {
    await tester.runAsync(
      () => CylinderPassportRepository().assignPassportId(
        equipmentId: cylinderId,
        passportId: '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab',
      ),
    );
    DiveTank? changed;
    // Pump and pick exactly as the neighbouring test does.
    await pumpAndPick(tester, onChanged: (t) => changed = t);
    expect(changed!.passportId, '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab');
  });

  testWidgets('a picked cylinder with no passport id clears one', (
    tester,
  ) async {
    DiveTank? changed;
    await pumpAndPick(
      tester,
      onChanged: (t) => changed = t,
      tank: const DiveTank(id: 'tank-1', passportId: 'p-old'),
    );
    expect(changed!.passportId, isNull);
  });
```

`cylinderId` and `pumpAndPick` stand for the file's seeded cylinder id variable and its pump-then-pick sequence; read the neighbouring test and inline those exact calls (if the file has no helper, copy the neighbouring test's body and change only the assertions). Add the equivalent pair to `tank_editor_preset_cylinders_test.dart` for a cylinder chosen in the preset dropdown.

In `tank_editor_trip_cylinder_test.dart`, add:

```dart
  testWidgets('picking a slot clears the passport id (#2650)', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a', pressure: 205, o2: 32)],
      tank: const DiveTank(id: 'tank-1', passportId: 'p-1'),
      onChanged: (t) => changed = t,
    );
    await _openTripCylinderPicker(tester);
    await tester.tap(find.textContaining('Truck a').last);
    await tester.pumpAndSettle();

    expect(changed!.tripCylinderId, 'a');
    expect(changed!.passportId, isNull);
  });

  testWidgets('None keeps the passport id (#2650)', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [],
      tripId: 't1',
      slots: [filledSlot('a')],
      tank: const DiveTank(
        id: 'tank-1',
        tripCylinderId: 'a',
        passportId: 'p-1',
      ),
      onChanged: (t) => changed = t,
    );
    await _openTripCylinderPicker(tester);
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();

    expect(changed!.tripCylinderId, isNull);
    expect(changed!.passportId, 'p-1');
  });
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart test/features/dive_log/presentation/widgets/tank_editor_own_cylinder_test.dart test/features/dive_log/presentation/widgets/tank_editor_preset_cylinders_test.dart test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart`
Expected: the new tests FAIL (`passportId` null or unchanged).

- [ ] **Step 4: Hold the id in editor state**

In `_TankEditorState`, after the `_regulatorEquipmentId` field:

```dart
  /// The tagged cylinder this tank came from (issue #2650). Set by a scan
  /// or a cylinder pick, cleared by a preset or a trip slot, kept by hand
  /// edits.
  String? _passportId;
```

In `_initializeControllers`, after `_regulatorEquipmentId = widget.tank.regulatorEquipmentId;`:

```dart
    _passportId = widget.tank.passportId;
```

In `_currentTank()`, after `tripCylinderId: widget.tank.tripCylinderId,`:

```dart
      // Only a cylinder choice changes it; a hand edit is the same metal.
      passportId: _passportId,
```

- [ ] **Step 5: Clear it on a preset and a slot**

`_applyPreset`: inside its `setState(() { ... })`, add as the first line `_passportId = null;`.

The None-preset branch in `_buildPresetAndRoleRow` becomes:

```dart
              } else {
                _specChoice++;
                setState(() {
                  _selectedPreset = null;
                  _passportId = null;
                });
                _notifyChange();
              }
```

`_pickTripCylinder`: change the `widget.onChanged(...)` argument so a real slot clears the id and None keeps it:

```dart
    widget.onChanged(
      slot == null
          ? current.copyWith(clearTripCylinderId: true)
          : tankFromTripCylinder(current.copyWith(clearPassportId: true), slot),
    );
```

(keep whatever follows in that call unchanged).

- [ ] **Step 6: Stamp it on scans and picks**

Give `_applyScannedSpec` a required `passportId` and stamp it even when there is nothing else to fill:

```dart
  bool _applyScannedSpec({
    required String? passportId,
    double? volumeL,
    double? workingPressureBar,
    TankMaterial? material,
    GasMix? mix,
  }) {
    final idChanged = passportId != _passportId;
    _passportId = passportId;
    // A computer logged what this tank breathed; the cylinder's last fill
    // does not replace it (issue #3021).
    final fillMix = isComputerRecordedTank(widget.tank) ? null : mix;
    if (volumeL == null &&
        workingPressureBar == null &&
        material == null &&
        fillMix == null) {
      // Nothing to fill, but the tag still says which cylinder this is.
      if (idChanged) _notifyChange();
      return false;
    }
```

(the rest of the method is unchanged; its final `_notifyChange()` now carries the id).

`_fillFromTag`, `ForeignCylinder` case: pass `passportId: tag.passportId` to `_applyScannedSpec`.

`_useOwnCylinder` gains a `String? passportId` positional parameter after `fills` and passes it to `_applyScannedSpec(passportId: passportId, ...)`. Update its doc comment: "fills the tank with its spec, newest of [fills] and [passportId]".

`_fillFromTag`, `OwnCylinder` case: call `_useOwnCylinder(item, fills, tag.passportId, messenger, l10n)`.

`_fillFromOwnCylinder`: read the id before the race check:

```dart
      final fills = await ref.read(fillsForEquipmentProvider(item.id).future);
      final passportId = await ref
          .read(cylinderPassportRepositoryProvider)
          .getPassportId(item.id);
      if (!mounted || choice != _specChoice) return;
      await _useOwnCylinder(item, fills, passportId, messenger, l10n);
```

- [ ] **Step 7: Run the tank editor tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/`
Expected: PASS, including the existing race tests ("is not overwritten by ...", "a preset chosen while a cylinder loads is not overwritten"), which pin that a lost race leaves the id alone.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log
git add lib/features/dive_log/presentation/widgets/tank_editor.dart test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart test/features/dive_log/presentation/widgets/tank_editor_own_cylinder_test.dart test/features/dive_log/presentation/widgets/tank_editor_preset_cylinders_test.dart test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart
git commit -m "feat(dive-log): stamp the scanned or picked cylinder's passport id on a tank"
```

---

### Task 5: "Use on a dive" carries the passport id to the new dive

**Files:**
- Modify: `lib/features/cylinder_passports/domain/services/passport_dive_tank.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (prefill tank near line 824; async default preset near line 736)
- Modify: `test/features/cylinder_passports/domain/services/passport_dive_tank_test.dart`
- Modify: the dive edit page prefill test (find it with `grep -rl "DivePrefill(" test/features/dive_log/presentation/pages | xargs grep -l "tank:"`)

**Interfaces:**
- Consumes: `DiveTank.passportId` (Task 1).
- Produces: `tankFromPassport(tag)` returns a tank with `passportId == tag.passportId`; a `DivePrefill.tank` keeps it on the page's first tank.

- [ ] **Step 1: Write the failing tests**

In `passport_dive_tank_test.dart`:

```dart
  test('the tank names the tag it came from (#2650)', () {
    final tank = tankFromPassport(
      const CylinderPassportPayload(passportId: 'p-1', volumeL: 10),
    );
    expect(tank.passportId, 'p-1');
  });
```

(construct the payload the way the file's other tests do if its constructor needs more fields).

In the dive edit page prefill test file, add two tests modelled on its existing `DivePrefill(tank: ...)` test:

1. A prefill tank `DiveTank(id: '', volume: 10, passportId: 'p-1')`: after pumping, saving or reading the page's first tank (whichever the neighbouring test asserts through) gives `passportId == 'p-1'`.
2. A prefill tank with only `passportId: 'p-1'` (no volume, name, pressure or material) while a custom default preset resolves: the first tank takes the preset's volume and still has `passportId == 'p-1'`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_dive_tank_test.dart <the prefill test file>`
Expected: FAIL.

- [ ] **Step 3: Implement**

`passport_dive_tank.dart`: update the doc comment ("A copy of the spec, plus the tag's passport id so the diver's uses of this cylinder can be counted (issue #2650). The id is left for the dive edit page to assign.") and add `passportId: tag.passportId,` to the returned `DiveTank`.

`dive_edit_page.dart`, prefill branch (`if (p.tank case final t?)`): add `passportId: t.passportId,` to the `DiveTank(` it builds, after `presetName:`.

`dive_edit_page.dart`, the async default preset replacement (`if (!_tanksDirty && ...)`): add to the rebuilt `DiveTank(`

```dart
                // A tag that described nothing still named the cylinder
                // (issue #2650).
                passportId: existing.passportId,
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/cylinder_passports/domain/services/passport_dive_tank_test.dart <the prefill test file> test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/cylinder_passports lib/features/dive_log test/features
git add lib/features/cylinder_passports/domain/services/passport_dive_tank.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/cylinder_passports/domain/services/passport_dive_tank_test.dart <the prefill test file>
git commit -m "feat(cylinder-passports): carry the tag's passport id into Use on a dive"
```

---

### Task 6: Strings and `PassportUsageCard`

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb` (insert after `passport_foreign_notInGear`; the scan key after `passport_scan_filledFrom`)
- Regenerate: `lib/l10n/arb/app_localizations*.dart` (committed)
- Create: `lib/features/cylinder_passports/presentation/widgets/passport_usage_card.dart`
- Create: `test/features/cylinder_passports/presentation/widgets/passport_usage_card_test.dart`

**Interfaces:**
- Consumes: `passportUsageProvider`, `PassportUsageDive` (Task 3).
- Produces: `PassportUsageCard({Key? key, required String passportId, required PassportUsageTitle title})` with `enum PassportUsageTitle { foreign, own }`; l10n getters `passport_usage_foreignTitle(int count)`, `passport_usage_ownTitle(int count)`, `passport_usage_lastUsed(String date)`, `passport_usage_noSite`, `passport_usage_diveNumber(int number)`, `passport_usage_showAll(int count)`, `passport_usage_loadFailed`, `passport_scan_filledFromUsed(int count, String name)` (check the generated parameter order, see Step 3).

- [ ] **Step 1: Add the English strings**

In `app_en.arb`, after the `passport_foreign_notInGear` entry:

```json
  "passport_usage_foreignTitle": "{count, plural, one{You have used this cylinder {count} time} other{You have used this cylinder {count} times}}",
  "@passport_usage_foreignTitle": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "passport_usage_ownTitle": "{count, plural, one{Used on {count} dive} other{Used on {count} dives}}",
  "@passport_usage_ownTitle": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "passport_usage_lastUsed": "Last used {date}",
  "@passport_usage_lastUsed": {
    "placeholders": {
      "date": {"type": "String"}
    }
  },
  "passport_usage_noSite": "No site",
  "passport_usage_diveNumber": "Dive {number}",
  "@passport_usage_diveNumber": {
    "placeholders": {
      "number": {"type": "int"}
    }
  },
  "passport_usage_showAll": "Show all {count}",
  "@passport_usage_showAll": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
  "passport_usage_loadFailed": "Could not load your dives with this cylinder",
```

After the `passport_scan_filledFrom` entry:

```json
  "passport_scan_filledFromUsed": "{count, plural, one{Filled from {name}. Used on {count} earlier dive.} other{Filled from {name}. Used on {count} earlier dives.}}",
  "@passport_scan_filledFromUsed": {
    "placeholders": {
      "name": {"type": "String"},
      "count": {"type": "int"}
    }
  },
```

- [ ] **Step 2: Add the translations**

Same keys, same placement, in each other ARB (no `@` metadata blocks in non-English files unless that file already carries them for neighbouring keys; follow the file). Values:

| Key | de | es | fr |
| --- | --- | --- | --- |
| foreignTitle | `{count, plural, one{Diese Flasche bereits {count}-mal benutzt} other{Diese Flasche bereits {count}-mal benutzt}}` | `{count, plural, one{Has usado esta botella {count} vez} other{Has usado esta botella {count} veces}}` | `{count, plural, one{Vous avez utilisé cette bouteille {count} fois} other{Vous avez utilisé cette bouteille {count} fois}}` |
| ownTitle | `{count, plural, one{Auf {count} Tauchgang benutzt} other{Auf {count} Tauchgängen benutzt}}` | `{count, plural, one{Usada en {count} inmersión} other{Usada en {count} inmersiones}}` | `{count, plural, one{Utilisée sur {count} plongée} other{Utilisée sur {count} plongées}}` |
| lastUsed | `Zuletzt benutzt am {date}` | `Último uso: {date}` | `Dernière utilisation : {date}` |
| noSite | `Kein Tauchplatz` | `Sin sitio` | `Aucun site` |
| diveNumber | `Tauchgang {number}` | `Inmersión {number}` | `Plongée {number}` |
| showAll | `Alle {count} anzeigen` | `Mostrar las {count}` | `Tout afficher ({count})` |
| loadFailed | `Die Tauchgänge mit dieser Flasche konnten nicht geladen werden` | `No se pudieron cargar tus inmersiones con esta botella` | `Impossible de charger vos plongées avec cette bouteille` |
| filledFromUsed | `{count, plural, one{Übernommen von {name}. Auf {count} früheren Tauchgang benutzt.} other{Übernommen von {name}. Auf {count} früheren Tauchgängen benutzt.}}` | `{count, plural, one{Completado desde {name}. Usada en {count} inmersión anterior.} other{Completado desde {name}. Usada en {count} inmersiones anteriores.}}` | `{count, plural, one{Rempli depuis {name}. Utilisée sur {count} plongée précédente.} other{Rempli depuis {name}. Utilisée sur {count} plongées précédentes.}}` |

| Key | it | nl | pt |
| --- | --- | --- | --- |
| foreignTitle | `{count, plural, one{Hai usato questa bombola {count} volta} other{Hai usato questa bombola {count} volte}}` | `{count, plural, one{Je hebt deze fles {count} keer gebruikt} other{Je hebt deze fles {count} keer gebruikt}}` | `{count, plural, one{Você usou este cilindro {count} vez} other{Você usou este cilindro {count} vezes}}` |
| ownTitle | `{count, plural, one{Usata in {count} immersione} other{Usata in {count} immersioni}}` | `{count, plural, one{Gebruikt bij {count} duik} other{Gebruikt bij {count} duiken}}` | `{count, plural, one{Usado em {count} mergulho} other{Usado em {count} mergulhos}}` |
| lastUsed | `Ultimo utilizzo: {date}` | `Laatst gebruikt op {date}` | `Último uso: {date}` |
| noSite | `Nessun sito` | `Geen duikstek` | `Sem local` |
| diveNumber | `Immersione {number}` | `Duik {number}` | `Mergulho {number}` |
| showAll | `Mostra tutte ({count})` | `Alle {count} tonen` | `Mostrar todos ({count})` |
| loadFailed | `Impossibile caricare le tue immersioni con questa bombola` | `Je duiken met deze fles konden niet worden geladen` | `Não foi possível carregar seus mergulhos com este cilindro` |
| filledFromUsed | `{count, plural, one{Compilato da {name}. Usata in {count} immersione precedente.} other{Compilato da {name}. Usata in {count} immersioni precedenti.}}` | `{count, plural, one{Ingevuld vanuit {name}. Gebruikt bij {count} eerdere duik.} other{Ingevuld vanuit {name}. Gebruikt bij {count} eerdere duiken.}}` | `{count, plural, one{Preenchido a partir de {name}. Usado em {count} mergulho anterior.} other{Preenchido a partir de {name}. Usado em {count} mergulhos anteriores.}}` |

| Key | hu | zh | ar | he |
| --- | --- | --- | --- | --- |
| foreignTitle | `{count, plural, one{Ezt a palackot {count} alkalommal használta} other{Ezt a palackot {count} alkalommal használta}}` | `{count, plural, other{您已使用此气瓶 {count} 次}}` | `{count, plural, one{لقد استخدمت هذه الأسطوانة {count} مرة} other{لقد استخدمت هذه الأسطوانة {count} مرة}}` | `{count, plural, one{השתמשת במיכל הזה {count} פעם} other{השתמשת במיכל הזה {count} פעמים}}` |
| ownTitle | `{count, plural, one{{count} merülésen használva} other{{count} merülésen használva}}` | `{count, plural, other{用于 {count} 次潜水}}` | `{count, plural, one{استُخدمت في {count} غطسة} other{استُخدمت في {count} غطسة}}` | `{count, plural, one{שימש ב-{count} צלילה} other{שימש ב-{count} צלילות}}` |
| lastUsed | `Utoljára használva: {date}` | `上次使用：{date}` | `آخر استخدام: {date}` | `שימוש אחרון: {date}` |
| noSite | `Nincs merülőhely` | `无潜点` | `لا يوجد موقع` | `אין אתר` |
| diveNumber | `{number}. merülés` | `第 {number} 次潜水` | `الغطسة {number}` | `צלילה {number}` |
| showAll | `Mind a(z) {count} megjelenítése` | `显示全部 {count} 项` | `عرض الكل ({count})` | `הצג את כל {count}` |
| loadFailed | `Nem sikerült betölteni a palackkal végzett merüléseit` | `无法加载您使用此气瓶的潜水记录` | `تعذّر تحميل غطساتك بهذه الأسطوانة` | `לא ניתן לטעון את הצלילות שלך עם המיכל הזה` |
| filledFromUsed | `{count, plural, one{Kitöltve innen: {name}. {count} korábbi merülésen használva.} other{Kitöltve innen: {name}. {count} korábbi merülésen használva.}}` | `{count, plural, other{已从 {name} 填入。此前用于 {count} 次潜水。}}` | `{count, plural, one{مُلئ من {name}. استُخدمت في {count} غطسة سابقة.} other{مُلئ من {name}. استُخدمت في {count} غطسة سابقة.}}` | `{count, plural, one{מולא מתוך {name}. שימש ב-{count} צלילה קודמת.} other{מולא מתוך {name}. שימש ב-{count} צלילות קודמות.}}` |

The English `passport_foreign_notInGear` neighbour is where each locale's block goes; JSON-escape nothing extra (none of these values contain quotes or backslashes).

- [ ] **Step 3: Regenerate and check the argument order**

Run: `flutter gen-l10n`
Then: `grep -n "String passport_scan_filledFromUsed\|String passport_usage_" lib/l10n/arb/app_localizations.dart`
Expected: the eight getters exist. Note `passport_scan_filledFromUsed`'s parameter order (placeholders map order: `name`, then `count`), and call it in that order in Task 7.

- [ ] **Step 4: Write the failing card test**

`test/features/cylinder_passports/presentation/widgets/passport_usage_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/passport_usage.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_usage_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  List<PassportUsageDive> dives(int n) => [
    for (var i = 0; i < n; i++)
      PassportUsageDive(
        diveId: 'd$i',
        dateTime: DateTime.utc(2026, 3, 12 - i),
        diveNumber: 40 - i,
        siteName: i == 0 ? 'Bari Reef' : null,
      ),
  ];

  Future<(AppLocalizations, List<String>)> pump(
    WidgetTester tester, {
    required Future<List<PassportUsageDive>> Function() usage,
    PassportUsageTitle title = PassportUsageTitle.foreign,
  }) async {
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: PassportUsageCard(passportId: 'p-1', title: title),
            ),
          ),
        ),
        GoRoute(
          path: '/dives/:diveId',
          builder: (_, state) {
            pushed.add(state.pathParameters['diveId']!);
            return const Scaffold();
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          passportUsageProvider('p-1').overrideWith((ref) => usage()),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      AppLocalizations.of(tester.element(find.byType(Scaffold).first)),
      pushed,
    );
  }

  testWidgets('hidden when the cylinder was never used', (tester) async {
    await pump(tester, usage: () async => const []);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('foreign title, last used, rows newest first', (tester) async {
    final (l10n, _) = await pump(tester, usage: () async => dives(3));
    expect(find.text(l10n.passport_usage_foreignTitle(3)), findsOneWidget);
    expect(find.text('Bari Reef'), findsOneWidget);
    expect(find.text(l10n.passport_usage_noSite), findsNWidgets(2));
    expect(find.text(l10n.passport_usage_diveNumber(40)), findsOneWidget);
    expect(find.textContaining('Last used'), findsOneWidget);
  });

  testWidgets('own title', (tester) async {
    final (l10n, _) = await pump(
      tester,
      usage: () async => dives(2),
      title: PassportUsageTitle.own,
    );
    expect(find.text(l10n.passport_usage_ownTitle(2)), findsOneWidget);
  });

  testWidgets('five rows, then Show all expands in place', (tester) async {
    final (l10n, _) = await pump(tester, usage: () async => dives(7));
    expect(find.byKey(const Key('passport_usage_row')), findsNWidgets(5));
    await tester.tap(find.text(l10n.passport_usage_showAll(7)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('passport_usage_row')), findsNWidgets(7));
    expect(find.text(l10n.passport_usage_showAll(7)), findsNothing);
  });

  testWidgets('a row opens its dive', (tester) async {
    final (_, pushed) = await pump(tester, usage: () async => dives(1));
    await tester.tap(find.text('Bari Reef'));
    await tester.pumpAndSettle();
    expect(pushed, ['d0']);
  });

  testWidgets('a load error shows one line', (tester) async {
    final (l10n, _) = await pump(
      tester,
      usage: () async => throw StateError('database is locked'),
    );
    expect(find.text(l10n.passport_usage_loadFailed), findsOneWidget);
  });
}
```

If `MockSettingsNotifier` requires different setup in `mock_providers.dart` (for example shared preferences), copy the override list from `passport_trip_card_test.dart`.

- [ ] **Step 5: Run it to verify it fails**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/passport_usage_card_test.dart`
Expected: FAIL (compile error: `passport_usage_card.dart` not found).

- [ ] **Step 6: Write the card**

`lib/features/cylinder_passports/presentation/widgets/passport_usage_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/passport_usage.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('PassportUsageCard');

/// How the card's header counts: a stranger's cylinder ("You have used this
/// cylinder N times") or the diver's own ("Used on N dives").
enum PassportUsageTitle { foreign, own }

/// The diver's dives with a tank from the cylinder whose passport id is
/// [passportId] (issue #2650): a count, the last date and the dives, each
/// opening its dive. Shows nothing until the cylinder has been used.
class PassportUsageCard extends ConsumerStatefulWidget {
  const PassportUsageCard({
    super.key,
    required this.passportId,
    required this.title,
  });

  final String passportId;
  final PassportUsageTitle title;

  /// Rows shown before "Show all".
  static const collapsedRows = 5;

  @override
  ConsumerState<PassportUsageCard> createState() => _PassportUsageCardState();
}

class _PassportUsageCardState extends ConsumerState<PassportUsageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final usage = ref.watch(passportUsageProvider(widget.passportId));
    return usage.when(
      loading: () => const SizedBox.shrink(),
      error: (e, stackTrace) {
        _log.error(
          'Failed to load the dives of a cylinder',
          error: e,
          stackTrace: stackTrace,
        );
        return Card(
          margin: const EdgeInsets.only(top: 12),
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(context.l10n.passport_usage_loadFailed),
          ),
        );
      },
      data: (dives) => dives.isEmpty ? const SizedBox.shrink() : _card(dives),
    );
  }

  Widget _card(List<PassportUsageDive> dives) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final count = dives.length;
    final shown = _expanded
        ? dives
        : dives.take(PassportUsageCard.collapsedRows).toList();
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                switch (widget.title) {
                  PassportUsageTitle.foreign =>
                    l10n.passport_usage_foreignTitle(count),
                  PassportUsageTitle.own => l10n.passport_usage_ownTitle(count),
                },
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                l10n.passport_usage_lastUsed(
                  units.formatDate(dives.first.dateTime),
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final dive in shown)
              ListTile(
                key: const Key('passport_usage_row'),
                dense: true,
                title: Text(dive.siteName ?? l10n.passport_usage_noSite),
                subtitle: Text(
                  [
                    units.formatDate(dive.dateTime),
                    if (dive.diveNumber case final n?)
                      l10n.passport_usage_diveNumber(n),
                  ].join('  '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/dives/${dive.diveId}'),
              ),
            if (!_expanded && count > PassportUsageCard.collapsedRows)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton(
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(l10n.passport_usage_showAll(count)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

Check `LoggerService`'s constructor form against `scan_cylinder_tag.dart` (`const LoggerService('scanCylinderTag')`) and that `l10n_extension.dart` provides `context.l10n` (it does in `scan_cylinder_tag.dart`). The `'  '` row separator is two spaces; if `dive_list` rows use a localized separator helper, use that instead.

- [ ] **Step 7: Run it to verify it passes**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/passport_usage_card_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/cylinder_passports test/features/cylinder_passports
git add lib/l10n/arb/ lib/features/cylinder_passports/presentation/widgets/passport_usage_card.dart test/features/cylinder_passports/presentation/widgets/passport_usage_card_test.dart
git commit -m "feat(cylinder-passports): add the cylinder usage card and its strings"
```

---

### Task 7: Place the card on both passports and name earlier uses on a scan

**Files:**
- Modify: `lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart` (`_body`, after the "Not in your gear" `Card`)
- Modify: `lib/features/cylinder_passports/presentation/pages/passport_page.dart` (card list, between `PassportFillHistoryCard` and `PassportTagCard`)
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (`_fillFromTag`, `ForeignCylinder` case)
- Modify: `test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart`
- Modify: `test/features/cylinder_passports/presentation/pages/passport_page_test.dart`
- Modify: `test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart`

**Interfaces:**
- Consumes: `PassportUsageCard`, `PassportUsageTitle` (Task 6); `passportUsageProvider`, `passportUsageRepositoryProvider`, `PassportUsageRepository.usageFor` (Task 3); `TankEditor.diveId` (existing); `l10n.passport_scan_filledFromUsed` (Task 6).

- [ ] **Step 1: Write the failing page tests**

`foreign_passport_page_test.dart`: extend `pump` with an optional `List<PassportUsageDive> usage = const []` and add `passportUsageProvider(id).overrideWith((ref) async => usage)` to the overrides it passes to `testApp` (append to `overrides`). Then add:

```dart
  testWidgets('a cylinder used before says so above the spec (#2650)', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      full,
      usage: [
        PassportUsageDive(diveId: 'd1', dateTime: DateTime.utc(2025, 3, 12)),
      ],
    );
    final title = find.text(l10n.passport_usage_foreignTitle(1));
    expect(title, findsOneWidget);
    // Directly under "not in your gear", above the spec rows.
    expect(
      tester.getTopLeft(title).dy,
      greaterThan(
        tester.getTopLeft(find.text(l10n.passport_foreign_notInGear)).dy,
      ),
    );
    // Above the first spec row (the volume row's label).
    expect(
      tester.getTopLeft(title).dy,
      lessThan(
        tester
            .getTopLeft(find.text(attributeLabel(l10n, EquipmentAttrKeys.volumeL)))
            .dy,
      ),
    );
  });

  testWidgets('a cylinder never used shows no usage card', (tester) async {
    final l10n = await pump(tester, full);
    expect(find.text(l10n.passport_usage_foreignTitle(0)), findsNothing);
  });
```

Import `attributeLabel` and `EquipmentAttrKeys` from the files `foreign_passport_page.dart` imports them from.

`passport_page_test.dart`: in its `pump`, override `passportUsageProvider` for the seeded cylinder's passport id with two dives, and add a test that `l10n.passport_usage_ownTitle(2)` shows and sits below the fill history card's title and above the tag card's title. Add one more test: a cylinder with no passport id (the page before minting) shows no usage card. Use the file's existing seeding; read its `pump` first.

- [ ] **Step 2: Write the failing scan snack bar tests**

In `tank_editor_scan_test.dart`, give `pump` an optional `String? diveId` passed to `TankEditor(diveId: diveId)`, and add:

```dart
  group('earlier uses on a foreign scan (#2650)', () {
    Future<void> seedUse(String diveId) => DiveRepository().createDive(
      Dive(
        id: diveId,
        dateTime: DateTime.utc(2025, 3, 12),
        tanks: const [DiveTank(id: '', passportId: stranger)],
      ),
    );

    testWidgets('names how often the cylinder was used', (tester) async {
      await tester.runAsync(() async {
        await seedUse('d1');
        await seedUse('d2');
      });
      final l10n = await pump(
        tester,
        scanned: 'https://submersion.app/c#f=1&p=$stranger&v=10',
        onChanged: (_) {},
      );
      await scan(tester);
      expect(
        find.text(l10n.passport_scan_filledFromUsed('Cylinder', 2)),
        findsOneWidget,
      );
    });

    testWidgets('leaves out the dive being edited', (tester) async {
      await tester.runAsync(() => seedUse('d1'));
      final l10n = await pump(
        tester,
        scanned: 'https://submersion.app/c#f=1&p=$stranger&v=10',
        onChanged: (_) {},
        diveId: 'd1',
      );
      await scan(tester);
      expect(
        find.text(
          l10n.passport_scan_filledFrom(l10n.passport_foreign_defaultName),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failing lookup still reports the fill', (tester) async {
      final l10n = await pump(
        tester,
        scanned: 'https://submersion.app/c#f=1&p=$stranger&v=10',
        onChanged: (_) {},
        extra: [
          passportUsageRepositoryProvider.overrideWithValue(
            _BrokenUsage(),
          ),
        ],
      );
      await scan(tester);
      expect(
        find.text(
          l10n.passport_scan_filledFrom(l10n.passport_foreign_defaultName),
        ),
        findsOneWidget,
      );
    });
  });
```

with, at file level:

```dart
class _BrokenUsage extends PassportUsageRepository {
  @override
  Future<List<PassportUsageDive>> usageFor(
    String passportId, {
    required String? diverId,
    String? excludeDiveId,
  }) async => throw StateError('database is locked');
}
```

Use `l10n.passport_foreign_defaultName` in place of `'Cylinder'` in the first test (the tag carries no `n`, so the snack bar names the default). Seeding a dive with no `diverId` while `MockCurrentDiverIdNotifier` supplies a diver id would filter it out: give `seedUse` the same diver id the mock returns (read `MockCurrentDiverIdNotifier` in `mock_providers.dart`).

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/cylinder_passports/presentation/pages/ test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart`
Expected: the new tests FAIL.

- [ ] **Step 4: Place the cards**

`foreign_passport_page.dart`, in `_body`, directly after the `Card(child: ListTile(... passport_foreign_notInGear ...))`:

```dart
        // A rental scanned again a season later: the diver's own history
        // with this physical tank (issue #2650).
        PassportUsageCard(
          passportId: tag.passportId,
          title: PassportUsageTitle.foreign,
        ),
```

`passport_page.dart`, between `PassportFillHistoryCard(...)` and `PassportTagCard(`, using the `passportId` the page already watches (line ~102):

```dart
                if (passportId != null)
                  PassportUsageCard(
                    passportId: passportId,
                    title: PassportUsageTitle.own,
                  ),
```

Match the spacing widgets the neighbouring cards use (if each card is followed by a `SizedBox`, add one).

- [ ] **Step 5: Name earlier uses in the scan snack bar**

In `tank_editor.dart`, `_fillFromTag`, replace the `ForeignCylinder` case body's snack bar with:

```dart
        case ForeignCylinder(:final tag):
          if (choice != _specChoice) return;
          final filled = _applyScannedSpec(
            passportId: tag.passportId,
            volumeL: tag.volumeL,
            workingPressureBar: tag.workingPressureBar?.toDouble(),
            material: tag.material,
            mix: tag.fill?.gasMix,
          );
          final name = tag.name ?? l10n.passport_foreign_defaultName;
          final earlier = filled ? await _earlierUses(tag.passportId) : 0;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                !filled
                    ? l10n.passport_foreign_noDetails
                    : earlier > 0
                    ? l10n.passport_scan_filledFromUsed(name, earlier)
                    : l10n.passport_scan_filledFrom(name),
              ),
            ),
          );
```

and add to the state class:

```dart
  /// How many of the active diver's other dives used the cylinder whose
  /// passport id is [passportId] (issue #2650); this dive does not count.
  /// Zero when the lookup fails: the fill already happened, and a count is
  /// not worth reporting it as a failure.
  Future<int> _earlierUses(String passportId) async {
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final dives = await ref
          .read(passportUsageRepositoryProvider)
          .usageFor(
            passportId,
            diverId: diverId,
            excludeDiveId: widget.diveId,
          );
      return dives.length;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to count earlier uses of a cylinder',
        error: e,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }
```

Pass `name` and `earlier` in the order Task 6 Step 3 found for `passport_scan_filledFromUsed`. Add the imports `validatedCurrentDiverIdProvider` (`diver_providers.dart`) if `tank_editor.dart` lacks it.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/cylinder_passports/ test/features/dive_log/presentation/widgets/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib/features test/features
git add lib/features/cylinder_passports/presentation/pages/foreign_passport_page.dart lib/features/cylinder_passports/presentation/pages/passport_page.dart lib/features/dive_log/presentation/widgets/tank_editor.dart test/features/cylinder_passports/presentation/pages/foreign_passport_page_test.dart test/features/cylinder_passports/presentation/pages/passport_page_test.dart test/features/dive_log/presentation/widgets/tank_editor_scan_test.dart
git commit -m "feat(cylinder-passports): show a cylinder's dives on its passports and on a scan"
```

---

### Task 8: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze`
Expected: no changes left unstaged by format; "No issues found!".

- [ ] **Step 2: Guards and the affected areas**

Run: `flutter test test/architecture/ test/shared/ test/core/database/ test/core/services/sync/ test/features/cylinder_passports/ test/features/dive_log/ test/features/dive_centers/ test/features/trips/`
Expected: PASS. A guard failure on a file this branch did not touch: check main first (see the repo's main-red notes) before changing it.

- [ ] **Step 3: l10n staleness**

Run: `flutter gen-l10n && git status --porcelain lib/l10n`
Expected: no output (the committed generated files are current).

- [ ] **Step 4: Spec coverage check**

Walk spec sections 5.3, 5.4, 6.1 to 6.4 and 7.1 to 7.2 and name the test that pins each line; add any missing test to the owning task's test file and commit it as `test(cylinder-passports): <what>`.

- [ ] **Step 5: Commit any fixes**

```bash
git add <the files changed by fixes>
git commit -m "fix(cylinder-passports): <what the verification found>"
```
