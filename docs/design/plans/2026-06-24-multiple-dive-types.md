# Multiple Dive Types Per Dive — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a single dive carry multiple dive types (e.g. recreational + shore + photography), consistently across the editor, bulk editor, display, filtering, statistics, sync, and import/export.

**Architecture:** A new `dive_dive_types` junction table (surrogate-UUID rows, cloned from the `DiveTags` pattern) is the source of truth for a dive's type set. The existing `dives.dive_type` text column is retained as a denormalized "representative" slug (= the first selected type) for back-compat over sync and single-value export formats. The domain `Dive` exposes `List<String> diveTypeIds`; `diveTypeId` becomes a getter returning the first. Every dive keeps the existing invariant of having at least one type.

**Tech Stack:** Flutter 3.x, Drift ORM (SQLite), Riverpod, flutter_test. Tests use the project's `setUpTestDatabase()` / `tearDownTestDatabase()` harness and `DiveRepository()`.

## Global Constraints

- **Schema version:** bump `AppDatabase.currentSchemaVersion` from 91 to **92**; add a `if (from < 92)` block to the `onUpgrade` ladder followed by `if (from < 92) await reportProgress();`.
- **Junction PK is a surrogate UUID, never a composite `(diveId, diveTypeId)`.** This is load-bearing for sync correctness (keeps us clear of the #347 junction-sync data-loss bug). Reinserts always use fresh `_uuid.v4()`.
- **At-least-one invariant:** no code path may leave a dive with zero types. Empty results coerce to `['recreational']`.
- **Representative column:** any write to a dive's type set also writes `dives.dive_type = typeIds.first`.
- **Formatting:** run `dart format .` (whole project) before each commit; CI checks the whole project.
- **Analyze:** `flutter analyze` must report "No issues found!" before each commit.
- **Localization:** any new user-facing string is added to `lib/l10n/arb/app_en.arb` (source) and the other locale ARBs (English fallback acceptable where no translation exists), then regenerated. Exact keys/English text are given in the relevant tasks.
- **Commit style:** Conventional Commits, no `Co-Authored-By` trailer (matches repo convention).
- **Tests:** TDD — write the failing test first. Run specific test files, not whole directories, to avoid timeouts.

---

## Task 1: Schema — `dive_dive_types` table + v92 migration

**Files:**
- Modify: `lib/core/database/database.dart` (add table ~after `DiveTags` at `:1122`; register in `@DriftDatabase(tables: [...])` near `:1597`; bump `currentSchemaVersion` at `:1643`; add migration block in `onUpgrade` at `:1817`; add 92 to the migration-versions list at `:1645`)
- Test: `test/core/database/dive_dive_types_migration_test.dart`

**Interfaces:**
- Produces: Drift table `DiveDiveTypes` → generated row class `DiveDiveType`, `DiveDiveTypesCompanion`, accessor `db.diveDiveTypes`. Top-level `const kSeedDiveDiveTypesSql`. Schema v92.

- [ ] **Step 1: Write the failing test** (`test/core/database/dive_dive_types_migration_test.dart`) — tests the seed SQL deterministically against a hand-built prior-schema table using `package:sqlite3`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/core/database/database.dart' show kSeedDiveDiveTypesSql;

void main() {
  test('v92 seed inserts one junction row per dive from its dive_type slug', () {
    final db = sqlite3.openInMemory();
    db.execute('CREATE TABLE dives (id TEXT PRIMARY KEY, dive_type TEXT)');
    db.execute('''
      CREATE TABLE dive_dive_types (
        id TEXT PRIMARY KEY, dive_id TEXT, dive_type_id TEXT, created_at INTEGER)
    ''');
    db.execute('''
      INSERT INTO dives (id, dive_type) VALUES
        ('d1', 'wreck'), ('d2', ''), ('d3', NULL)
    ''');

    db.execute(kSeedDiveDiveTypesSql);

    final rows = db.select(
      'SELECT dive_id, dive_type_id FROM dive_dive_types ORDER BY dive_id',
    );
    expect(rows.length, 3);
    expect(rows[0]['dive_type_id'], 'wreck'); // d1 keeps its slug
    expect(rows[1]['dive_type_id'], 'recreational'); // d2 empty -> default
    expect(rows[2]['dive_type_id'], 'recreational'); // d3 null -> default
    // ids are unique and non-empty
    final ids = db.select('SELECT id FROM dive_dive_types');
    expect(ids.map((r) => r['id']).toSet().length, 3);
    db.dispose();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/dive_dive_types_migration_test.dart`
Expected: FAIL — `kSeedDiveDiveTypesSql` is not defined.

- [ ] **Step 3: Add the table, the seed SQL constant, registration, version bump, and migration block**

Add the table class (after `DiveTags`):

```dart
/// Junction table for dive types (many-to-many). Surrogate UUID PK (never a
/// composite key) so fresh-id reinserts never collide with a replaced row's
/// tombstone — this is how the junction stays clear of the #347 sync bug.
class DiveDiveTypes extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get diveTypeId => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add the seed SQL as a top-level constant (self-contained — no `Date.now`, so it is reusable by the test):

```dart
/// Seeds one junction row per existing dive from its representative dive_type
/// slug. Used by the v92 migration and asserted directly in tests.
const kSeedDiveDiveTypesSql = '''
  INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at)
  SELECT
    lower(hex(randomblob(16))),
    id,
    COALESCE(NULLIF(dive_type, ''), 'recreational'),
    CAST(strftime('%s','now') AS INTEGER) * 1000
  FROM dives
''';
```

Register `DiveDiveTypes` in the `@DriftDatabase(tables: [...])` list. Bump `static const int currentSchemaVersion = 92;`. Add `92` to the migration-versions list at `:1645`. In `onUpgrade`, after the last existing block:

```dart
if (from < 92) {
  await m.createTable(diveDiveTypes);
  await customStatement(kSeedDiveDiveTypesSql);
}
if (from < 92) await reportProgress();
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: success; `database.g.dart` now contains `DiveDiveType`, `DiveDiveTypesCompanion`, `db.diveDiveTypes`.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/database/dive_dive_types_migration_test.dart`
Expected: PASS.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/dive_dive_types_migration_test.dart
git commit -m "feat(db): add dive_dive_types junction table + v92 migration (#414)"
```

---

## Task 2: Domain entities — `diveTypeIds` on `Dive` and `DiveSummary`

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (field `:42`, getter `:221`, constructor, `copyWith`, `props`)
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart` (field `:22`, ctor `:46`, `fromDive` `:74`, `copyWith`, `props`)
- Test: `test/features/dive_log/domain/entities/dive_dive_types_test.dart`

**Interfaces:**
- Produces: `Dive.diveTypeIds: List<String>` (source of truth, default `['recreational']`); `String get Dive.diveTypeId => diveTypeIds.first`; `List<String> get Dive.diveTypeNames`; `static String Dive.diveTypeDisplayName(String id)`; `Dive.copyWith({List<String>? diveTypeIds})`. `DiveSummary.diveTypeIds: List<String>`; `String get DiveSummary.diveTypeId`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  Dive make(List<String> ids) =>
      Dive(id: 'd', dateTime: DateTime(2026, 1, 1), diveTypeIds: ids);

  test('diveTypeId getter returns the first type', () {
    expect(make(['shore', 'wreck']).diveTypeId, 'shore');
  });

  test('defaults to a single recreational type', () {
    expect(Dive(id: 'd', dateTime: DateTime(2026, 1, 1)).diveTypeIds,
        ['recreational']);
  });

  test('diveTypeNames capitalizes each slug', () {
    expect(make(['night', 'deep_wreck']).diveTypeNames, ['Night', 'Deep wreck']);
  });

  test('copyWith replaces the set', () {
    expect(make(['shore']).copyWith(diveTypeIds: ['cave']).diveTypeIds, ['cave']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_dive_types_test.dart`
Expected: FAIL — `diveTypeIds` named parameter does not exist.

- [ ] **Step 3: Edit `dive.dart`**

Replace the stored field at `:42` (`final String diveTypeId;`) with:

```dart
  final List<String> diveTypeIds; // References dive_types table (>= 1, first = representative)
  final DiveTypeEntity? diveType; // Optional loaded entity (for display)
```

In the constructor, replace `this.diveTypeId = 'recreational'` with `this.diveTypeIds = const ['recreational']`.

Replace the `diveTypeName` getter region (`:220-229`) with:

```dart
  /// Display name for the representative (first) dive type.
  String get diveTypeName =>
      diveType?.name ?? diveTypeDisplayName(diveTypeId);

  /// Representative (first) dive type slug. Always present (>= 1 invariant).
  String get diveTypeId =>
      diveTypeIds.isEmpty ? 'recreational' : diveTypeIds.first;

  /// Display names for all of this dive's types.
  List<String> get diveTypeNames =>
      diveTypeIds.map(diveTypeDisplayName).toList();

  /// Capitalize a slug for display, e.g. 'deep_wreck' -> 'Deep wreck'.
  static String diveTypeDisplayName(String id) {
    if (id.isEmpty) return 'Recreational';
    return id[0].toUpperCase() + id.substring(1).replaceAll('_', ' ');
  }
```

In `copyWith`: replace the `String? diveTypeId` parameter with `List<String>? diveTypeIds`, and the assignment `diveTypeId: diveTypeId ?? this.diveTypeId` with `diveTypeIds: diveTypeIds ?? this.diveTypeIds`. In `props`: replace `diveTypeId` with `diveTypeIds`.

- [ ] **Step 4: Edit `dive_summary.dart`**

Replace field `:22` `final String diveTypeId;` with `final List<String> diveTypeIds;` and add a getter:

```dart
  String get diveTypeId =>
      diveTypeIds.isEmpty ? 'recreational' : diveTypeIds.first;
```

Constructor `:46`: `this.diveTypeIds = const ['recreational']`. `fromDive` `:74`: `diveTypeIds: dive.diveTypeIds`. `copyWith`: parameter `List<String>? diveTypeIds` and `diveTypeIds: diveTypeIds ?? this.diveTypeIds`. `props`: `diveTypeIds`.

- [ ] **Step 5: Fix construction sites flagged by the compiler**

Run: `grep -rn "diveTypeId:" lib test` — update each `Dive(... diveTypeId: x ...)` / `DiveSummary(... diveTypeId: x ...)` / `.copyWith(diveTypeId: x)` to pass `diveTypeIds: [x]` (or `diveTypeIds: xs` where a list is available). Repository mappers are handled in Task 3; fix any others here (tests, factories).

- [ ] **Step 6: Run test + analyze**

Run: `flutter test test/features/dive_log/domain/entities/dive_dive_types_test.dart` → PASS
Run: `flutter analyze` → No issues found!

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/dive_log/domain/entities/dive.dart lib/features/dive_log/domain/entities/dive_summary.dart test/features/dive_log/domain/entities/dive_dive_types_test.dart
git commit -m "feat(dive): model dive types as a list on Dive/DiveSummary (#414)"
```

---

## Task 3: Repository — persist & hydrate the type set (single dive)

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (insert `:688`, update `:928`, full-dive mappers `:2221` & `:2569`, summary query `:1388`)
- Test: `test/features/dive_log/data/repositories/dive_repository_dive_types_test.dart`

**Interfaces:**
- Consumes: `db.diveDiveTypes`, `Dive.diveTypeIds`, `_uuid` (existing field), `_syncRepository` (existing).
- Produces: private `Future<void> _replaceDiveTypeRows(String diveId, List<String> typeIds, int now)` (delete + logDeletion + reinsert fresh UUIDs + markRecordPending + write representative). `createDive`/`updateDive` persist the set; mappers + summary hydrate `diveTypeIds`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  test('createDive persists the full type set and representative column', () async {
    await repository.createDive(domain.Dive(
      id: 'd1', dateTime: DateTime(2026, 1, 1),
      diveTypeIds: const ['shore', 'wreck', 'night'],
    ));

    final rows = await (db.select(db.diveDiveTypes)
          ..where((t) => t.diveId.equals('d1')))
        .get();
    expect(rows.map((r) => r.diveTypeId).toSet(), {'shore', 'wreck', 'night'});

    final dive = await db.select(db.dives).getSingle();
    expect(dive.diveType, 'shore'); // representative = first

    final loaded = await repository.getDiveById('d1');
    expect(loaded!.diveTypeIds, ['shore', 'wreck', 'night']);
  });

  test('updateDive replaces the type set', () async {
    await repository.createDive(domain.Dive(
      id: 'd1', dateTime: DateTime(2026, 1, 1),
      diveTypeIds: const ['shore'],
    ));
    final dive = (await repository.getDiveById('d1'))!;
    await repository.updateDive(dive.copyWith(diveTypeIds: const ['cave', 'deep']));

    final loaded = await repository.getDiveById('d1');
    expect(loaded!.diveTypeIds, ['cave', 'deep']);
    final row = await db.select(db.dives).getSingle();
    expect(row.diveType, 'cave');
  });

  test('a legacy dive with only the column (no junction rows) falls back', () async {
    await db.into(db.dives).insert(
          DivesCompanion.insert(
            id: 'legacy',
            diveDateTime: DateTime(2026, 1, 1),
            diveType: const Value('drift'),
          ),
          mode: InsertMode.insertOrReplace,
        );
    final loaded = await repository.getDiveById('legacy');
    expect(loaded!.diveTypeIds, ['drift']); // hydrated from the column
  });
}
```

(Adjust `DivesCompanion.insert` required fields to match the generated signature; the point is a dive row with `dive_type='drift'` and no junction rows.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_dive_types_test.dart`
Expected: FAIL — junction not written; `diveTypeIds` not hydrated.

- [ ] **Step 3: Add the private writer and call it from create/update**

Add this method (model on `bulkReplaceTags` at `:3684`, single-dive scope):

```dart
/// Replace [diveId]'s dive-type rows with exactly [typeIds] (>= 1 enforced),
/// and write the representative `dives.dive_type` column. Fresh UUIDs per row.
Future<void> _replaceDiveTypeRows(
  String diveId,
  List<String> typeIds,
  int now,
) async {
  final types = typeIds.isEmpty ? const ['recreational'] : typeIds;
  final existing = await (_db.select(_db.diveDiveTypes)
        ..where((t) => t.diveId.equals(diveId)))
      .get();
  await (_db.delete(_db.diveDiveTypes)
        ..where((t) => t.diveId.equals(diveId)))
      .go();
  for (final row in existing) {
    await _syncRepository.logDeletion(
        entityType: 'diveDiveTypes', recordId: row.id);
  }
  for (final typeId in types) {
    final id = _uuid.v4();
    await _db.into(_db.diveDiveTypes).insert(DiveDiveTypesCompanion(
          id: Value(id),
          diveId: Value(diveId),
          diveTypeId: Value(typeId),
          createdAt: Value(now),
        ));
    await _syncRepository.markRecordPending(
        entityType: 'diveDiveTypes', recordId: id, localUpdatedAt: now);
  }
  // Keep the denormalized representative column in lockstep with the set so
  // create/update AND the bulk methods (Task 4) all stay consistent.
  await (_db.update(_db.dives)..where((t) => t.id.equals(diveId)))
      .write(DivesCompanion(diveType: Value(types.first)));
}
```

In `createDive` and `updateDive`: keep writing the representative column (`diveType: Value(dive.diveTypeId)` — the getter already returns `diveTypeIds.first`), and after the dive row is written, call `await _replaceDiveTypeRows(dive.id, dive.diveTypeIds, now);` (use the same `now` the method already computes). If create/update is not already inside a transaction, wrap the row write + `_replaceDiveTypeRows` in `_db.transaction(() async { ... })`.

- [ ] **Step 4: Hydrate `diveTypeIds` in the mappers**

In each full-dive mapper (`:2221`, `:2569`), after loading other child collections, load the junction rows and set `diveTypeIds`, falling back to the column:

```dart
final typeRows = await (_db.select(_db.diveDiveTypes)
      ..where((t) => t.diveId.equals(row.id)))
    .get();
final diveTypeIds = typeRows.isEmpty
    ? [row.diveType]
    : (typeRows..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
        .map((r) => r.diveTypeId)
        .toList();
```

Pass `diveTypeIds: diveTypeIds` to the `Dive(...)` constructor (replacing `diveTypeId: row.diveType`).

In the `DiveSummary` raw-SQL query (`:1388`), add a correlated `group_concat` so the list loads in one query:

```sql
(SELECT group_concat(ddt.dive_type_id, ',')
   FROM dive_dive_types ddt WHERE ddt.dive_id = d.id) AS dive_type_ids
```

Map it: `final raw = row.read<String?>('dive_type_ids'); final ids = (raw == null || raw.isEmpty) ? [row.read<String>('dive_type')] : raw.split(',');` then `diveTypeIds: ids`.

- [ ] **Step 5: Run test + analyze** → PASS / No issues found!

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_dive_types_test.dart`

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_dive_types_test.dart
git commit -m "feat(dive): persist and hydrate the dive-type set on create/update (#414)"
```

---

## Task 4: Repository — bulk junction methods (add/remove/replace)

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (near `bulkReplaceTags` `:3684` / `bulkAddTags` `:4038` / `bulkRemoveTags` `:4082`)
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (expose on the notifiers, mirror `bulkAddTags`/`bulkRemoveTags` at `:432/442/844/854`)
- Test: `test/features/dive_log/data/repositories/dive_repository_dive_types_bulk_test.dart`

**Interfaces:**
- Produces: `Future<void> DiveRepository.bulkReplaceDiveTypes(List<String> diveIds, List<String> typeIds)`, `bulkAddDiveTypes(...)`, `bulkRemoveDiveTypes(...)`. Each maintains the representative column and the >= 1 invariant.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<List<String>> typesOf(String id) async =>
      (await repository.getDiveById(id))!.diveTypeIds..sort();

  Future<void> seed(String id, List<String> t) => repository.createDive(
        domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), diveTypeIds: t),
      );

  test('replace sets exactly the given types and representative', () async {
    await seed('d1', ['shore']);
    await repository.bulkReplaceDiveTypes(['d1'], ['cave', 'deep']);
    expect(await typesOf('d1'), ['cave', 'deep']);
    expect((await db.select(db.dives).getSingle()).diveType, 'cave');
  });

  test('add unions without dropping existing', () async {
    await seed('d1', ['shore']);
    await repository.bulkAddDiveTypes(['d1'], ['wreck']);
    expect(await typesOf('d1'), ['shore', 'wreck']);
  });

  test('remove drops the given types', () async {
    await seed('d1', ['shore', 'wreck']);
    await repository.bulkRemoveDiveTypes(['d1'], ['wreck']);
    expect(await typesOf('d1'), ['shore']);
  });

  test('remove that would empty a dive falls back to recreational', () async {
    await seed('d1', ['shore']);
    await repository.bulkRemoveDiveTypes(['d1'], ['shore']);
    expect(await typesOf('d1'), ['recreational']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_dive_types_bulk_test.dart`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Implement the three methods**

`bulkReplaceDiveTypes` iterates `diveIds` and, for each, calls `_replaceDiveTypeRows(id, typeIds, now)` (Task 3 — which handles junction rows, fresh-UUID reinserts, `logDeletion`, `markRecordPending`, and the representative column), then bumps `dives.updatedAt` + `markRecordPending(entityType: 'dives', ...)` exactly as `bulkReplaceTags` does at `:3720-3727`. `bulkAddDiveTypes` / `bulkRemoveDiveTypes` (cloning `bulkAddTags` `:4038` / `bulkRemoveTags` `:4082`) first read each dive's current set from `dive_dive_types`, compute the new set (union for add; set-difference for remove, coerced to `['recreational']` if it would be empty), then delegate to the same `_replaceDiveTypeRows` + dive-bump path per dive. Mirror `bulkReplaceTags`'s `TableUpdateQuery.onTable(...)` notification, adding `_db.diveDiveTypes`.

- [ ] **Step 4: Expose on the providers**

In `dive_providers.dart`, add `bulkAddDiveTypes` / `bulkRemoveDiveTypes` / `bulkReplaceDiveTypes` pass-throughs on the same notifiers that expose `bulkAddTags`/`bulkRemoveTags` (`:432/442/844/854`).

- [ ] **Step 5: Run test + analyze** → PASS / clean

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/data/repositories/dive_repository_dive_types_bulk_test.dart
git commit -m "feat(dive): bulk add/remove/replace dive types (#414)"
```

---

## Task 5: Sync — register the `diveDiveTypes` entity

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (field cf. `:219`, default `:260`, `toJson` `:302`, `fromJson` `:345`, export `:588` + a `_exportDiveDiveTypes`, import case cf. `:1089-1092`)
- Modify: `lib/core/services/sync/sync_service.dart` (record list cf. `:836`; registrations `:1242`, `:1301`)
- Test: `test/core/services/sync/dive_dive_types_sync_test.dart`

**Interfaces:**
- Consumes: `db.diveDiveTypes`, generated `DiveDiveType.fromJson` / `toJson`.
- Produces: sync entity key `'diveDiveTypes'` carried in the sync payload with `hasUpdatedAt: false`.

- [ ] **Step 1: Write the failing test** — round-trip + the #347 scenario (replace membership; serialize the changeset including the tombstones of the replaced rows; apply to a second DB; assert the final set is exactly the new one, with no resurrection of replaced rows):

```dart
// Build two AppDatabases via the test harness; on db A create a dive with
// types ['shore','wreck'], then bulkReplaceDiveTypes(['d1'], ['cave']).
// Export the changeset (pending records + deletions) from A, import into B,
// and assert B's dive 'd1' has exactly ['cave'] — the replaced 'shore'/'wreck'
// junction rows do NOT reappear (their tombstones are honored), and 'cave'
// is present (its fresh-UUID row is not shadowed by any tombstone).
```

Use the existing sync test helpers as the model (find a sibling test that exports+imports a changeset between two harness DBs; mirror its setup). Assert via `db.select(db.diveDiveTypes)`.

- [ ] **Step 2: Run test to verify it fails** — `'diveDiveTypes'` not a known entity.

- [ ] **Step 3: Register the entity** — add `diveDiveTypes` everywhere `diveTags` appears in `sync_data_serializer.dart` (the list field, its default `const []`, `toJson` key `'diveDiveTypes'`, `fromJson` parse via `_parseList`, the `_safeExport('diveDiveTypes', () => _exportDiveDiveTypes(hlcSince))` call, a `_exportDiveDiveTypes` method cloned from `_exportDiveTags`, and an import `case 'diveDiveTypes': ... .into(_db.diveDiveTypes).insertOnConflictUpdate(DiveDiveType.fromJson(data));`). In `sync_service.dart`, add `(type: 'diveDiveTypes', records: data.diveDiveTypes, hasUpdatedAt: false)` to the record list and register it in the maps at `:1242`/`:1301`.

- [ ] **Step 4: Run test + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/dive_dive_types_sync_test.dart
git commit -m "feat(sync): replicate dive_dive_types junction (#414)"
```

---

## Task 6: Filtering — match dives by type membership

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:1495-1498` (SQL filter)
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart:186` (in-memory filter)
- Test: `test/features/dive_log/data/repositories/dive_repository_dive_type_filter_test.dart`

**Interfaces:** unchanged public API (`DiveFilterState.diveTypeId` stays single — "filter by a type"); only the match semantics change to membership.

- [ ] **Step 1: Write the failing test** — seed a dive with `['shore','wreck']`; filter by `diveTypeId: 'wreck'`; assert the dive is returned (it would not match `dive_type = 'wreck'` since the representative is `'shore'`):

```dart
test('filtering by a type matches dives that have it among several', () async {
  await repository.createDive(domain.Dive(
    id: 'd1', dateTime: DateTime(2026, 1, 1),
    diveTypeIds: const ['shore', 'wreck'],
  ));
  final results = await repository.getDiveSummaries(
    filter: const DiveFilterState(diveTypeId: 'wreck'),
  );
  expect(results.map((d) => d.id), contains('d1'));
});
```

(`getDiveSummaries({String? diverId, DiveFilterState filter, ...})` at `:1283` is the
filtered list query; it calls `_buildFilterWhereClauses` at `:1481`.)

- [ ] **Step 2: Run test to verify it fails** — representative is `'shore'`, so `dive_type = 'wreck'` returns nothing.

- [ ] **Step 3: Change both filters.** SQL (`:1495`):

```dart
if (filter.diveTypeId != null) {
  clauses.add(
    'EXISTS (SELECT 1 FROM dive_dive_types ddt '
    'WHERE ddt.dive_id = d.id AND ddt.dive_type_id = ?)',
  );
  args.add(Variable(filter.diveTypeId!));
}
```

In-memory (`dive_filter_state.dart:186`): replace `dive.diveTypeId != diveTypeId` with `!dive.diveTypeIds.contains(diveTypeId)`.

- [ ] **Step 4: Run test + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_log/domain/models/dive_filter_state.dart test/features/dive_log/data/repositories/dive_repository_dive_type_filter_test.dart
git commit -m "feat(dive): filter by dive-type membership (#414)"
```

---

## Task 7: Statistics — count toward each type

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart:469-477` (`getDiveTypeDistribution`)
- Modify: `lib/features/dive_types/data/repositories/dive_type_repository.dart:314` (`getDiveTypeStatistics` JOIN) and `:356` (`isDiveTypeInUse`)
- Test: `test/features/statistics/data/repositories/dive_type_distribution_test.dart`

**Interfaces:** unchanged return types; only the SQL changes to go through the junction.

- [ ] **Step 1: Write the failing test** — seed two dives: A `['night','wreck']`, B `['night']`; assert `getDiveTypeDistribution` returns night=2, wreck=1 (counts sum to 3 > 2 dives):

```dart
test('a multi-type dive counts toward each of its types', () async {
  // seed A with ['night','wreck'] and B with ['night'] via the dive repo
  final dist = await statsRepo.getDiveTypeDistribution();
  final byLabel = {for (final s in dist) s.label: s.count};
  expect(byLabel['Night'], 2);
  expect(byLabel['Wreck'], 1);
});
```

- [ ] **Step 2: Run test to verify it fails** — current SQL groups the single `dive_type` column (night=1 from each representative; wreck=0).

- [ ] **Step 3: Rewrite the SQL.** `getDiveTypeDistribution` (`:469`):

```sql
SELECT ddt.dive_type_id AS dive_type, COUNT(*) AS count
FROM dive_dive_types ddt
JOIN dives d ON d.id = ddt.dive_id
WHERE 1=1 $diverFilter
GROUP BY ddt.dive_type_id
ORDER BY count DESC
```

(The `$diverFilter` now references `d.diver_id`.) In `dive_type_repository.getDiveTypeStatistics` (`:314`), JOIN `dive_dive_types ddt ON ddt.dive_type_id = dt.id` then `dives d ON d.id = ddt.dive_id` instead of `dives d ON dt.id = d.dive_type`. In `isDiveTypeInUse` (`:356`), replace `SELECT COUNT(*) FROM dives WHERE dive_type = ?` with `SELECT COUNT(*) FROM dive_dive_types WHERE dive_type_id = ?`.

- [ ] **Step 4: Run test + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/statistics/data/repositories/statistics_repository.dart lib/features/dive_types/data/repositories/dive_type_repository.dart test/features/statistics/data/repositories/dive_type_distribution_test.dart
git commit -m "feat(stats): count dives toward each of their types (#414)"
```

---

## Task 8: Editor widget — `DiveTypeMultiSelectField`

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart`
- Modify: `lib/l10n/arb/app_en.arb` (+ other locale ARBs): keys `diveLog_edit_label_diveTypes` = "Dive Types", `diveLog_edit_addCustomType` = "Add custom type…"
- Test: `test/features/dive_log/presentation/widgets/dive_type_multi_select_field_test.dart`

**Interfaces:**
- Produces: `DiveTypeMultiSelectField` — a `ConsumerStatefulWidget` with `final List<String> selectedTypeIds; final ValueChanged<List<String>> onChanged;`. At rest renders selected types as a `Wrap` of chips + a dropdown caret; tapping opens an overlay of `CheckboxListTile`s (from `diveTypeListNotifierProvider`) plus an "Add custom type…" tile; enforces >= 1 (the last checked item cannot be unchecked). The "Add custom type…" tile prompts for a name, creates a `DiveTypeEntity` via the dive-types repository/provider, and auto-checks it.

- [ ] **Step 1: Write the failing widget test** — pump the widget with `selectedTypeIds: ['shore']`, override `diveTypeListNotifierProvider` with a small fake list (shore/wreck/night); assert a chip labeled "Shore" renders; tap to open; tap "Wreck"; assert `onChanged` fired with `['shore','wreck']`; open and attempt to uncheck the last remaining type and assert it stays selected (>= 1).

- [ ] **Step 2: Run test to verify it fails** — widget does not exist.

- [ ] **Step 3: Implement the widget.** Use a `FormField<List<String>>`-style trigger styled like the surrounding `FormRow`s (`lib/shared/widgets/forms/form_row.dart`); open an anchored overlay (e.g. `MenuAnchor`, with a height-constrained scrollable `ListView` of `CheckboxListTile`; fall back to `showModalBottomSheet` on narrow widths) listing all types from `diveTypeListNotifierProvider`. Toggling a checkbox updates a local working set and calls `onChanged`. Disable the checkbox of the last remaining selected type. The "Add custom type…" tile shows a name dialog, calls the dive-types creation provider (the same one the manage-types page uses), and adds the new slug to the selection.

- [ ] **Step 4: Run test + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
dart run build_runner build --delete-conflicting-outputs   # regenerate l10n
git add lib/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart lib/l10n test/features/dive_log/presentation/widgets/dive_type_multi_select_field_test.dart
git commit -m "feat(dive): add multi-select dive-type field widget (#414)"
```

---

## Task 9: Wire the widget into the single-dive editor

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (state `:140`, load `:459`, picker `:2933-2972`, save `:3997`)
- Test: extend `test/.../dive_edit_page` tests (or add `dive_edit_page_dive_types_test.dart`)

**Interfaces:** consumes `DiveTypeMultiSelectField` (Task 8); produces a dive saved with `diveTypeIds`.

- [ ] **Step 1: Write the failing test** — open the edit page for a dive with `diveTypeIds: ['shore','wreck']`; assert both chips render; toggle one off; save; assert the persisted dive's `diveTypeIds` updated.

- [ ] **Step 2: Run test to verify it fails.**

- [ ] **Step 3: Edit the page.** Replace `String _selectedDiveTypeId = 'recreational';` (`:140`) with `List<String> _selectedDiveTypeIds = const ['recreational'];`. Load (`:459`): `_selectedDiveTypeIds = List.from(dive.diveTypeIds);`. Replace the `Consumer`/`DropdownButtonFormField<String>` block (`:2933-2972`) with:

```dart
DiveTypeMultiSelectField(
  selectedTypeIds: _selectedDiveTypeIds,
  onChanged: (ids) => setState(() => _selectedDiveTypeIds = ids),
),
```

Save (`:3997`): `diveTypeIds: _selectedDiveTypeIds` (replacing `diveTypeId: _selectedDiveTypeId`).

- [ ] **Step 4: Run test + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_page_dive_types_test.dart
git commit -m "feat(dive): multi-select dive types in the dive editor (#414)"
```

---

## Task 10: Bulk edit — domain op + service + undo

**Files:**
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_request.dart` (add `DiveTypesOp`)
- Modify: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` (add `diveTypes` to `BulkCollectionType` `:47`)
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_snapshot.dart` (add `priorDiveTypeIds`)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` (snapshot capture `:54`, `_applyOp` `:196`, `undo` `:130`, snapshot construction `:117`)
- Test: `test/features/dive_log/data/services/bulk_dive_edit_service_dive_types_test.dart`

**Interfaces:**
- Produces: `class DiveTypesOp extends BulkCollectionOp { final BulkCollectionMode mode; final List<String> diveTypeIds; }`; `BulkCollectionType.diveTypes`; `BulkEditSnapshot.priorDiveTypeIds: Map<String, List<String>>?`.

- [ ] **Step 1: Write the failing test** — apply a `DiveTypesOp(mode: add, diveTypeIds: ['wreck'])` to two seeded dives; assert each gains 'wreck'; apply a `remove` that would empty one and assert it falls back to `['recreational']`; capture the snapshot, then `undo` and assert the prior sets are restored.

- [ ] **Step 2: Run test to verify it fails.**

- [ ] **Step 3: Add the op + enum + snapshot field.** In `bulk_edit_request.dart`:

```dart
class DiveTypesOp extends BulkCollectionOp {
  final BulkCollectionMode mode; // add | remove | replace
  final List<String> diveTypeIds;
  const DiveTypesOp({required this.mode, required this.diveTypeIds});
}
```

Add `diveTypes` to `BulkCollectionType`. In `bulk_edit_snapshot.dart`, add `final Map<String, List<String>>? priorDiveTypeIds;` to the class + constructor (mirror `priorTagIds`).

- [ ] **Step 4: Wire the service.** Capture (in `apply`, the `switch (op)` at `:54`): add

```dart
case DiveTypesOp():
  final rows = await (_db.select(_db.diveDiveTypes)
        ..where((t) => t.diveId.isIn(ids)))
      .get();
  priorDiveTypeIds = {for (final id in ids) id: <String>[]};
  for (final r in rows) {
    priorDiveTypeIds[r.diveId]!.add(r.diveTypeId);
  }
```

Pass `priorDiveTypeIds: priorDiveTypeIds` in the `BulkEditSnapshot(...)` construction (`:117`). In `_applyOp` (`:196`) add:

```dart
case DiveTypesOp(:final mode, :final diveTypeIds):
  switch (mode) {
    case BulkCollectionMode.add:
      await _diveRepo.bulkAddDiveTypes(ids, diveTypeIds);
    case BulkCollectionMode.remove:
      await _diveRepo.bulkRemoveDiveTypes(ids, diveTypeIds);
    case BulkCollectionMode.replace:
      await _diveRepo.bulkReplaceDiveTypes(ids, diveTypeIds);
  }
```

In `undo` (`:130`), after the tags restore block, add:

```dart
final diveTypes = snapshot.priorDiveTypeIds;
if (diveTypes != null) {
  for (final id in ids) {
    await _diveRepo.bulkReplaceDiveTypes([id], diveTypes[id] ?? const []);
  }
}
```

- [ ] **Step 5: Run test + analyze** → PASS / clean (the sealed `BulkCollectionOp` switch will force the new arm).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dive_log/domain/entities/bulk_edit_request.dart lib/features/dive_log/domain/entities/bulk_edit_snapshot.dart lib/features/dive_log/data/services/bulk_dive_edit_service.dart lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart test/features/dive_log/data/services/bulk_dive_edit_service_dive_types_test.dart
git commit -m "feat(dive): bulk dive-type collection op with undo (#414)"
```

---

## Task 11: Bulk edit — UI lane change

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` (remove `BulkField.diveType` `:12`, `BulkScalarInputs.diveTypeId` `:56`/`:94`, `buildScalarCompanion` case `:141-143`, `_bulkDiveTypeDropdown` `:740`, its registration `:801-804`)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (bulk-mode collection entries near the tags `_collectionEntry` at `:1003`) — add a `_collectionEntry(type: BulkCollectionType.diveTypes, ...)` with the Add/Remove/Replace mode selector and `DiveTypeMultiSelectField`, and construct a `DiveTypesOp` in the request builder where `TagsOp` is built (`:1054`)
- Modify: `lib/l10n/arb/*` — key `diveLog_edit_section_diveTypes` = "Dive Types"
- Test: widget test for the bulk collection entry (mode selector present; selecting types builds a `DiveTypesOp`)

- [ ] **Step 1: Write the failing test** — in bulk mode, assert the dive-types collection entry renders a mode selector (Add/Remove/Replace) and the multi-select field, and that confirming produces a `BulkEditRequest` whose `ops` contains a `DiveTypesOp` with the chosen mode + ids.

- [ ] **Step 2: Run test to verify it fails.**

- [ ] **Step 3: Remove the scalar path and add the collection entry.** Delete the scalar dive-type members listed in Files. Mirror the tags collection entry (`:1003-1011`) for `BulkCollectionType.diveTypes`, using `DiveTypeMultiSelectField` as the editor and the existing mode-selector widget the other collections use. Where the request's `ops` list is assembled (near `TagsOp(...)` at `:1054`), append `DiveTypesOp(mode: diveTypesMode, diveTypeIds: _selectedBulkDiveTypeIds)` when the dive-types collection is enabled.

- [ ] **Step 4: Run test + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
dart run build_runner build --delete-conflicting-outputs
git add lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/l10n test/...
git commit -m "feat(dive): move bulk dive-type edit to the collection lane (#414)"
```

---

## Task 12: Display — chips on detail + joined table column

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:2501-2505` (type row → chip `Wrap`)
- Modify: `lib/core/constants/dive_field_extractor.dart:132-133` & `:164-167` (return joined names)
- Test: `test/.../dive_detail` widget test (chips) + `test/.../dive_field_extractor_test.dart`

- [ ] **Step 1: Write the failing test** — extractor returns `'Shore, Wreck'` for a dive with `['shore','wreck']` (both `Dive` and `DiveSummary` paths); detail page renders two chips.

- [ ] **Step 2: Run test to verify it fails.**

- [ ] **Step 3: Implement.** In `dive_field_extractor.dart`, return `dive.diveTypeNames.join(', ')` for the `Dive` case (`:132`) and `summary.diveTypeIds.map(Dive.diveTypeDisplayName).join(', ')` for the `DiveSummary` case (`:164`). In `dive_detail_page.dart`, replace the plain-text type row with a `Wrap` of `Chip`s built from `dive.diveTypeNames`, styled like `_buildTagsSection` (`:3317`).

- [ ] **Step 4: Run test + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/core/constants/dive_field_extractor.dart test/...
git commit -m "feat(dive): show all dive types as chips and in the table column (#414)"
```

---

## Task 13: Import/Export — UDDF (multiple `<divetype>`)

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart:233`, `uddf_export_builders.dart:243` (emit one `<divetype>` per type)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart:532` & `_parseDiveType` `:2027`, `lib/features/dive_import/data/services/uddf_entity_importer.dart:1109-1164` (parse all `<divetype>` into a list)
- Test: `test/.../uddf_dive_types_roundtrip_test.dart`

- [ ] **Step 1: Write the failing test** — export a dive with `['shore','wreck']`, re-import, assert `diveTypeIds == ['shore','wreck']` (order-insensitive); import a `<dive>` with two `<divetype>` children → two slugs.

- [ ] **Step 2: Run test to verify it fails.**

- [ ] **Step 3: Implement.** Export: replace the single `builder.element('divetype', nest: dive.diveTypeId)` with a loop over `dive.diveTypeIds`. Import: change `_parseDiveType` to return `List<String>` by mapping every `<divetype>` element (dedupe, ensure >= 1, default `['recreational']`), and have `uddf_entity_importer.dart` set `diveTypeIds:` from it (replacing the single `diveTypeId` at `:1164`).

- [ ] **Step 4: Run test + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/export/uddf/ lib/features/dive_import/data/services/uddf_entity_importer.dart test/...
git commit -m "feat(uddf): import/export multiple dive types per dive (#414)"
```

---

## Task 14: Import/Export — CSV + MacDive

**Files:**
- Modify: `lib/core/services/export/csv/csv_export_service.dart:167` (join names), `lib/features/universal_import/data/csv/transforms/value_converter.dart:176` & `:370` (`parseDiveType` returns/keeps a list; split on `;`/`,`), `csv_transformer.dart:277`, `dive_extractor.dart:17`
- Modify: MacDive — `macdive_value_mapper.dart:69` to map the already-parsed `List<String> diveTypes` (`macdive_xml_models.dart:105`) into `diveTypeIds` instead of flattening
- Test: `test/.../csv_dive_types_test.dart`, `test/.../macdive_dive_types_test.dart`

- [ ] **Step 1: Write the failing tests** — CSV export of `['shore','wreck']` yields the cell `"Shore; Wreck"`; CSV import of `"Shore; Wreck"` yields `['shore','wreck']`; MacDive `<types><type>Boat</type><type>Night</type></types>` yields `['boat','night']`.

- [ ] **Step 2: Run tests to verify they fail.**

- [ ] **Step 3: Implement.** CSV export: `dive.diveTypeNames.join('; ')`. CSV import: split the raw value on `;`/`,`, trim, map each via the existing slug mapper, dedupe, default `['recreational']`; route into `diveTypeIds`. MacDive: map each parsed type string through `normalizeDiveType` and collect into `diveTypeIds`.

- [ ] **Step 4: Run tests + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/export/csv/ lib/features/universal_import/ test/...
git commit -m "feat(import): multiple dive types via CSV and MacDive (#414)"
```

---

## Task 15: Export — Excel + PDF (membership-aware)

**Files:**
- Modify: `lib/core/services/export/excel/excel_export_service.dart:215` (join names) & `:599-609` (specialty counts → membership)
- Modify: `lib/core/services/pdf_templates/pdf_template_padi.dart:214-216` (training detection → membership)
- Test: `test/.../excel_dive_types_test.dart` (or extend existing export tests)

- [ ] **Step 1: Write the failing test** — a dive with `['night','drift']` increments BOTH the night and drift specialty counts; PADI `isTrainingDive` is true when any type contains 'training'.

- [ ] **Step 2: Run test to verify it fails.**

- [ ] **Step 3: Implement.** Excel per-dive cell: `dive.diveTypeNames.join('; ')`. Specialty counts: replace `diveTypeName.toLowerCase().contains('night')` etc. with `dive.diveTypeIds.any((t) => t.contains('night'))` (and the same for drift/wreck). PDF: `isTrainingDive = dive.diveTypeIds.any((t) => t.toLowerCase().contains('training')) || dive.courseId != null`.

- [ ] **Step 4: Run test + analyze** → PASS / clean

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/services/export/excel/excel_export_service.dart lib/core/services/pdf_templates/pdf_template_padi.dart test/...
git commit -m "feat(export): membership-aware dive-type counts in Excel/PDF (#414)"
```

---

## Task 16: Cleanup — remove the dead `enum DiveType` + full verification

**Files:**
- Modify: `lib/core/constants/enums.dart:4-22` (delete `enum DiveType`)

- [ ] **Step 1: Confirm it is unused**

Run: `grep -rnE "\\bDiveType\\b" lib test | grep -v "DiveTypes\|DiveTypeId\|DiveTypeEntity\|DiveTypeName\|diveType\|DiveDiveType"`
Expected: no references to the bare enum (the generated `DiveType` row class is named via the `dive_types` table and is a separate symbol; ensure no remaining import of the enum specifically).

- [ ] **Step 2: Delete the enum** (`enums.dart:4-22`). If any file imported it solely for the enum, remove that usage.

- [ ] **Step 3: Run analyze + the full affected test set**

```bash
flutter analyze
flutter test test/features/dive_log test/features/statistics test/features/dive_types test/core/database test/core/services/sync
```
Expected: No issues found! and all green.

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add lib/core/constants/enums.dart
git commit -m "chore: remove dead legacy DiveType enum (#414)"
```

---

## Final verification (not a commit — a gate before opening a PR)

- [ ] `flutter analyze` → "No issues found!"
- [ ] Run the full affected suites (dive_log, statistics, dive_types, sync, import/export) green.
- [ ] Manually sanity-check on macOS (`flutter run -d macos`): create a dive with 3 types; confirm chips on detail; filter by one of the non-first types; check the statistics "by type" breakdown; bulk add/remove a type across 2 dives + undo.
- [ ] Update release notes per repo convention (`docs/releases/v<version>.md`).
