# Bulk Dive Editing — Engine + Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the fully-tested data engine for bulk-editing dives (set-based repository writes, an orchestration service, and per-dive undo) plus the enhanced multi-select gestures, so the upcoming bulk-edit form has a correct, sync-safe foundation to call into.

**Architecture:** New bulk methods on `DiveRepository`, `BuddyRepository`, and `SpeciesRepository` perform set-based SQL writes (never looping `updateDive`). A `BulkDiveEditService` composes them inside one Drift transaction, captures a per-dive `BulkEditSnapshot` before mutating, and fires a single `SyncEventBus.notifyLocalChange()`. The dive list gains a selection anchor for shift-click ranges and a date-range selector. The bulk-edit *form* (reusing `DiveEditPage` in a bulk mode) is a separate follow-up plan that consumes this engine.

**Tech Stack:** Dart/Flutter, Drift (SQLite ORM, companions), Riverpod, flutter_test.

## Global Constraints

- **Never loop `updateDive`** for bulk writes — it delete-and-re-inserts every child row. Use set-based `UPDATE ... WHERE id IN` / targeted inserts.
- Every touched row is marked for sync: `_syncRepository.markRecordPending(entityType: <camelCaseTable>, recordId: <id>, localUpdatedAt: now)`; every deletion: `_syncRepository.logDeletion(entityType: <camelCaseTable>, recordId: <id>)`. `now` is always `final now = DateTime.now().millisecondsSinceEpoch;` (int).
- `entityType` strings (exact): `'dives'`, `'diveTanks'`, `'diveWeights'`, `'diveEquipment'`, `'diveBuddies'`, `'sightings'`, `'diveTags'`.
- **New bulk repository methods do NOT call `SyncEventBus.notifyLocalChange()` and do NOT open their own transaction.** `BulkDiveEditService` owns the transaction boundary and calls `notifyLocalChange()` exactly once. (The pre-existing `bulkUpdateTrip`/`bulkAddTags`/etc. keep their self-contained behavior; we are adding new methods alongside them.)
- **Name-clash rule:** Drift generates row classes `Dive`, `DiveTank`, `DiveWeight`, `Sighting` that collide with the domain entities. In every new/edited file, import domain entities `as domain` (or a distinct prefix) and use Drift row classes unprefixed. Reconstruct companions from Drift rows with `row.toCompanion(false)` (so prior NULLs are written back, not left absent).
- Enums persist via `.name` (e.g. `tankRole`, `weightType`, `waterType`), except `diveMode`/`scrType` which use `.code` (see `updateDive`).
- Repositories use the implicit default constructor and resolve the DB via `DatabaseService.instance.database`; tests use `setUpTestDatabase()` / `tearDownTestDatabase()` from `test/helpers/test_database.dart` and construct `DiveRepository()` directly.
- Test imports: `import 'package:drift/drift.dart' hide isNull, isNotNull;` (drift and flutter_test both export those matchers) and `import '.../entities/dive.dart' as domain;`.
- New user-facing strings extend the existing `diveLog_*` l10n namespace and must be added to all 10 non-English ARB files (`lib/l10n/arb/app_<locale>.arb`) and regenerated with `flutter gen-l10n`.
- Run `dart format .` before every commit. Commit messages: conventional prefixes, no `Co-Authored-By` lines.

---

## Phase 1 — DiveRepository bulk write methods

All Phase 1 tasks add methods to `lib/features/dive_log/data/repositories/dive_repository_impl.dart` and tests to a new file `test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`. They mirror the verbatim shape of the existing `bulkUpdateTrip` (`dive_repository_impl.dart:3625`).

### Task 1: `bulkUpdateFields` — generic scalar set-based update

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add method in the "Bulk Operations" section near line 3625)
- Test: `test/features/dive_log/data/repositories/dive_repository_bulk_test.dart` (new)

**Interfaces:**
- Produces: `Future<void> bulkUpdateFields(List<String> diveIds, DivesCompanion partial)` — writes only the columns present (non-`absent`) in `partial` to every dive in `diveIds`, forcing `updatedAt = now`; marks each dive pending. No transaction, no notify.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/data/repositories/dive_repository_bulk_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seed(String id, {String notes = ''}) =>
      repository.createDive(domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: notes));

  group('bulkUpdateFields', () {
    test('writes only the given columns, bumps updatedAt, skips other dives', () async {
      await seed('d1', notes: 'keep');
      await seed('d2', notes: 'keep2');
      await seed('d3', notes: 'untouched');

      await repository.bulkUpdateFields(
        ['d1', 'd2'],
        const DivesCompanion(rating: Value(5), waterType: Value('salt')),
      );

      final r1 = await (db.select(db.dives)..where((t) => t.id.equals('d1'))).getSingle();
      final r3 = await (db.select(db.dives)..where((t) => t.id.equals('d3'))).getSingle();
      expect(r1.rating, 5);
      expect(r1.waterType, 'salt');
      expect(r1.notes, 'keep'); // untouched column preserved
      expect(r3.rating, isNull); // dive outside the id list untouched
      expect(r3.waterType, isNull);
    });

    test('is a no-op for an empty id list', () async {
      await repository.bulkUpdateFields(const [], const DivesCompanion(rating: Value(3)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: FAIL — `The method 'bulkUpdateFields' isn't defined for the type 'DiveRepository'`.

- [ ] **Step 3: Write minimal implementation**

```dart
  /// Bulk-set the columns present in [partial] on every dive in [diveIds].
  /// Absent columns are left untouched (Drift writes only present columns).
  /// Forces `updatedAt = now` and marks each dive pending. Does NOT open a
  /// transaction or notify sync — BulkDiveEditService owns those.
  Future<void> bulkUpdateFields(
    List<String> diveIds,
    DivesCompanion partial,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.dives)..where((t) => t.id.isIn(diveIds)))
        .write(partial.copyWith(updatedAt: Value(now)));
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_bulk_test.dart
git commit -m "feat(dive-log): add DiveRepository.bulkUpdateFields generic bulk scalar update"
```

### Task 2: `bulkAppendNotes` — concatenate text to many dives' notes

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Test: `test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`

**Interfaces:**
- Produces: `Future<void> bulkAppendNotes(List<String> diveIds, String textToAppend)` — appends `textToAppend` to each dive's notes via a single SQL `||` update (existing-empty notes get just the text), bumps `updatedAt`, marks pending.

- [ ] **Step 1: Write the failing test** (add inside `main()`)

```dart
  group('bulkAppendNotes', () {
    test('appends to existing notes and to empty notes', () async {
      await seed('a', notes: 'Cozumel');
      await seed('b', notes: '');

      await repository.bulkAppendNotes(['a', 'b'], '\nGreat viz');

      final ra = await (db.select(db.dives)..where((t) => t.id.equals('a'))).getSingle();
      final rb = await (db.select(db.dives)..where((t) => t.id.equals('b'))).getSingle();
      expect(ra.notes, 'Cozumel\nGreat viz');
      expect(rb.notes, '\nGreat viz');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart -p vm --plain-name bulkAppendNotes`
Expected: FAIL — `bulkAppendNotes` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
  /// Append [textToAppend] to the notes of every dive in [diveIds].
  Future<void> bulkAppendNotes(List<String> diveIds, String textToAppend) async {
    if (diveIds.isEmpty || textToAppend.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final placeholders = List.filled(diveIds.length, '?').join(', ');
    await _db.customUpdate(
      "UPDATE dives SET notes = COALESCE(notes, '') || ?, updated_at = ? "
      'WHERE id IN ($placeholders)',
      variables: [
        Variable.withString(textToAppend),
        Variable.withInt(now),
        ...diveIds.map(Variable.withString),
      ],
      updates: {_db.dives},
    );
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add DiveRepository.bulkAppendNotes"
```

### Task 3: `bulkReplaceTags`

**Files:** Modify repo; test file above.

**Interfaces:**
- Produces: `Future<void> bulkReplaceTags(List<String> diveIds, List<String> tagIds)` — sets each dive's tag membership to exactly `tagIds` (delete-all-for-dives + re-insert), logging deletions and marking inserts pending.

Note: `diveTags` references `Tags`; the test disables FK enforcement so it can exercise the junction logic without seeding the tag catalog.

- [ ] **Step 1: Write the failing test**

```dart
  group('bulkReplaceTags', () {
    setUp(() async {
      await db.customStatement('PRAGMA foreign_keys = OFF'); // test-only isolation
    });

    test('replaces existing tag membership with the given set', () async {
      await seed('d1');
      await repository.bulkAddTags(['d1'], ['old-tag']); // pre-existing membership

      await repository.bulkReplaceTags(['d1'], ['t1', 't2']);

      final rows = await (db.select(db.diveTags)..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.map((r) => r.tagId).toSet(), {'t1', 't2'});
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart --plain-name bulkReplaceTags`
Expected: FAIL — `bulkReplaceTags` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
  /// Replace each dive's tag membership with exactly [tagIds].
  Future<void> bulkReplaceTags(List<String> diveIds, List<String> tagIds) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(_db.diveTags)
          ..where((t) => t.diveId.isIn(diveIds)))
        .get();
    await (_db.delete(_db.diveTags)..where((t) => t.diveId.isIn(diveIds))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(entityType: 'diveTags', recordId: row.id);
    }
    for (final diveId in diveIds) {
      for (final tagId in tagIds) {
        final id = _uuid.v4();
        await _db.into(_db.diveTags).insert(DiveTagsCompanion(
              id: Value(id),
              diveId: Value(diveId),
              tagId: Value(tagId),
              createdAt: Value(now),
            ));
        await _syncRepository.markRecordPending(
            entityType: 'diveTags', recordId: id, localUpdatedAt: now);
      }
    }
    await (_db.update(_db.dives)..where((t) => t.id.isIn(diveIds)))
        .write(DivesCompanion(updatedAt: Value(now)));
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
          entityType: 'dives', recordId: diveId, localUpdatedAt: now);
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add DiveRepository.bulkReplaceTags"
```

### Task 4: Equipment bulk Add / Remove / Replace

**Files:** Modify repo; test file above.

**Interfaces:**
- Produces:
  - `Future<void> bulkAddEquipment(List<String> diveIds, List<String> equipmentIds)`
  - `Future<void> bulkRemoveEquipment(List<String> diveIds, List<String> equipmentIds)`
  - `Future<void> bulkReplaceEquipment(List<String> diveIds, List<String> equipmentIds)`
  - `diveEquipment` is a composite-key junction (`{diveId, equipmentId}`, no `id`); the sync recordId convention is `'$diveId|$equipmentId'`.

- [ ] **Step 1: Write the failing test**

```dart
  group('bulk equipment', () {
    setUp(() async {
      await db.customStatement('PRAGMA foreign_keys = OFF');
    });

    test('add then remove adjusts membership; replace overwrites', () async {
      await seed('d1');
      await repository.bulkAddEquipment(['d1'], ['e1', 'e2']);
      var rows = await (db.select(db.diveEquipment)..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.map((r) => r.equipmentId).toSet(), {'e1', 'e2'});

      await repository.bulkRemoveEquipment(['d1'], ['e1']);
      rows = await (db.select(db.diveEquipment)..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.map((r) => r.equipmentId).toSet(), {'e2'});

      await repository.bulkReplaceEquipment(['d1'], ['e9']);
      rows = await (db.select(db.diveEquipment)..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.map((r) => r.equipmentId).toSet(), {'e9'});
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart --plain-name "bulk equipment"`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
  Future<void> _bumpDives(List<String> diveIds, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.isIn(diveIds)))
        .write(DivesCompanion(updatedAt: Value(now)));
    for (final diveId in diveIds) {
      await _syncRepository.markRecordPending(
          entityType: 'dives', recordId: diveId, localUpdatedAt: now);
    }
  }

  Future<void> bulkAddEquipment(List<String> diveIds, List<String> equipmentIds) async {
    if (diveIds.isEmpty || equipmentIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      for (final equipmentId in equipmentIds) {
        await _db.into(_db.diveEquipment).insertOnConflictUpdate(
            DiveEquipmentCompanion(
                diveId: Value(diveId), equipmentId: Value(equipmentId)));
        await _syncRepository.markRecordPending(
            entityType: 'diveEquipment',
            recordId: '$diveId|$equipmentId',
            localUpdatedAt: now);
      }
    }
    await _bumpDives(diveIds, now);
  }

  Future<void> bulkRemoveEquipment(List<String> diveIds, List<String> equipmentIds) async {
    if (diveIds.isEmpty || equipmentIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(_db.diveEquipment)
          ..where((t) => t.diveId.isIn(diveIds) & t.equipmentId.isIn(equipmentIds)))
        .get();
    await (_db.delete(_db.diveEquipment)
          ..where((t) => t.diveId.isIn(diveIds) & t.equipmentId.isIn(equipmentIds)))
        .go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
          entityType: 'diveEquipment',
          recordId: '${row.diveId}|${row.equipmentId}');
    }
    await _bumpDives(diveIds, now);
  }

  Future<void> bulkReplaceEquipment(List<String> diveIds, List<String> equipmentIds) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(_db.diveEquipment)
          ..where((t) => t.diveId.isIn(diveIds)))
        .get();
    await (_db.delete(_db.diveEquipment)..where((t) => t.diveId.isIn(diveIds))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
          entityType: 'diveEquipment',
          recordId: '${row.diveId}|${row.equipmentId}');
    }
    for (final diveId in diveIds) {
      for (final equipmentId in equipmentIds) {
        await _db.into(_db.diveEquipment).insertOnConflictUpdate(
            DiveEquipmentCompanion(
                diveId: Value(diveId), equipmentId: Value(equipmentId)));
        await _syncRepository.markRecordPending(
            entityType: 'diveEquipment',
            recordId: '$diveId|$equipmentId',
            localUpdatedAt: now);
      }
    }
    await _bumpDives(diveIds, now);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add bulk equipment add/remove/replace"
```

### Task 5: Tanks bulk Add (with `onlyIfEmpty`) + Replace

**Files:** Modify repo; test file above.

**Interfaces:**
- Consumes: `domain.DiveTank` (fields: `name`, `volume`, `workingPressure`, `startPressure`, `endPressure`, `gasMix` (`.o2`, `.he`), `role` (`.name`), `material` (`.name`), `order`, `presetName`).
- Produces:
  - `Future<void> bulkAddTank(List<String> diveIds, domain.DiveTank tank, {bool onlyIfEmpty = false})` — appends one new tank (fresh UUID, `tankOrder` = current tank count) to each dive; when `onlyIfEmpty`, skips dives that already have any tank.
  - `Future<void> bulkReplaceTanks(List<String> diveIds, List<domain.DiveTank> tanks)` — sets each dive's tank list to `tanks` (fresh UUID + sequential `tankOrder` per dive). Note: replace cascades to delete `tank_pressure_profiles`/`gas_switches` for the old tanks.

Tanks reference only `Dives`, so the test does not need FK off (it seeds dives).

- [ ] **Step 1: Write the failing test**

```dart
  group('bulk tanks', () {
    const al80 = domain.DiveTank(
      id: '',
      name: 'AL80',
      volume: 11.1,
      gasMix: domain.GasMix(o2: 21, he: 0),
    );

    test('bulkAddTank appends; onlyIfEmpty skips dives that already have a tank', () async {
      await seed('empty');
      await seed('hasTank');
      await repository.bulkAddTank(['hasTank'], al80); // give it one first

      await repository.bulkAddTank(['empty', 'hasTank'], al80, onlyIfEmpty: true);

      final emptyTanks =
          await (db.select(db.diveTanks)..where((t) => t.diveId.equals('empty'))).get();
      final hasTankTanks =
          await (db.select(db.diveTanks)..where((t) => t.diveId.equals('hasTank'))).get();
      expect(emptyTanks.length, 1); // got the tank
      expect(emptyTanks.single.tankName, 'AL80');
      expect(emptyTanks.single.tankOrder, 0);
      expect(hasTankTanks.length, 1); // skipped — still just the original
    });

    test('bulkReplaceTanks overwrites the whole list', () async {
      await seed('d1');
      await repository.bulkAddTank(['d1'], al80);
      await repository.bulkReplaceTanks(['d1'], const [
        domain.DiveTank(id: '', name: 'D12', volume: 24, gasMix: domain.GasMix(o2: 32)),
      ]);
      final rows = await (db.select(db.diveTanks)..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.length, 1);
      expect(rows.single.tankName, 'D12');
      expect(rows.single.o2Percent, 32);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart --plain-name "bulk tanks"`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
  DiveTanksCompanion _tankCompanion(String id, String diveId, domain.DiveTank t, int order) =>
      DiveTanksCompanion(
        id: Value(id),
        diveId: Value(diveId),
        volume: Value(t.volume),
        workingPressure: Value(t.workingPressure),
        startPressure: Value(t.startPressure),
        endPressure: Value(t.endPressure),
        o2Percent: Value(t.gasMix.o2),
        hePercent: Value(t.gasMix.he),
        tankOrder: Value(order),
        tankRole: Value(t.role.name),
        tankMaterial: Value(t.material?.name),
        tankName: Value(t.name),
        presetName: Value(t.presetName),
      );

  Future<void> bulkAddTank(
    List<String> diveIds,
    domain.DiveTank tank, {
    bool onlyIfEmpty = false,
  }) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final changed = <String>[];
    for (final diveId in diveIds) {
      final existing =
          await (_db.select(_db.diveTanks)..where((t) => t.diveId.equals(diveId))).get();
      if (onlyIfEmpty && existing.isNotEmpty) continue;
      final tankId = _uuid.v4();
      await _db.into(_db.diveTanks).insert(_tankCompanion(tankId, diveId, tank, existing.length));
      await _syncRepository.markRecordPending(
          entityType: 'diveTanks', recordId: tankId, localUpdatedAt: now);
      changed.add(diveId);
    }
    if (changed.isNotEmpty) await _bumpDives(changed, now);
  }

  Future<void> bulkReplaceTanks(List<String> diveIds, List<domain.DiveTank> tanks) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      final existing =
          await (_db.select(_db.diveTanks)..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(_db.diveTanks)..where((t) => t.diveId.equals(diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(entityType: 'diveTanks', recordId: row.id);
      }
      for (var i = 0; i < tanks.length; i++) {
        final tankId = _uuid.v4();
        await _db.into(_db.diveTanks).insert(_tankCompanion(tankId, diveId, tanks[i], i));
        await _syncRepository.markRecordPending(
            entityType: 'diveTanks', recordId: tankId, localUpdatedAt: now);
      }
    }
    await _bumpDives(diveIds, now);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add bulk tank add (onlyIfEmpty) and replace"
```

### Task 6: Weights bulk Add + Replace

**Files:** Modify repo; test file above.

**Interfaces:**
- Consumes: `domain.DiveWeight` (fields: `id`, `weightType` (`.name`), `amountKg`, `notes`).
- Produces: `bulkAddWeights(List<String> diveIds, List<domain.DiveWeight> weights)` and `bulkReplaceWeights(List<String> diveIds, List<domain.DiveWeight> weights)` — owned rows; fresh UUID per dive per weight; `createdAt = now`.

- [ ] **Step 1: Write the failing test**

```dart
  group('bulk weights', () {
    final belt = domain.DiveWeight(id: '', weightType: domain.WeightType.belt, amountKg: 4, notes: '');

    test('add appends; replace overwrites', () async {
      await seed('d1');
      await repository.bulkAddWeights(['d1'], [belt]);
      var rows = await (db.select(db.diveWeights)..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.length, 1);
      expect(rows.single.amountKg, 4);

      await repository.bulkReplaceWeights(['d1'], [
        domain.DiveWeight(id: '', weightType: domain.WeightType.integrated, amountKg: 6, notes: ''),
      ]);
      rows = await (db.select(db.diveWeights)..where((t) => t.diveId.equals('d1'))).get();
      expect(rows.length, 1);
      expect(rows.single.amountKg, 6);
    });
  });
```

(If `WeightType` enum values differ, use the project's actual values — check `lib/features/dive_log/domain/entities/dive.dart` `enum WeightType`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart --plain-name "bulk weights"`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
  DiveWeightsCompanion _weightCompanion(String id, String diveId, domain.DiveWeight w, int now) =>
      DiveWeightsCompanion(
        id: Value(id),
        diveId: Value(diveId),
        weightType: Value(w.weightType.name),
        amountKg: Value(w.amountKg),
        notes: Value(w.notes),
        createdAt: Value(now),
      );

  Future<void> bulkAddWeights(List<String> diveIds, List<domain.DiveWeight> weights) async {
    if (diveIds.isEmpty || weights.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      for (final w in weights) {
        final id = _uuid.v4();
        await _db.into(_db.diveWeights).insert(_weightCompanion(id, diveId, w, now));
        await _syncRepository.markRecordPending(
            entityType: 'diveWeights', recordId: id, localUpdatedAt: now);
      }
    }
    await _bumpDives(diveIds, now);
  }

  Future<void> bulkReplaceWeights(List<String> diveIds, List<domain.DiveWeight> weights) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      final existing =
          await (_db.select(_db.diveWeights)..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(_db.diveWeights)..where((t) => t.diveId.equals(diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(entityType: 'diveWeights', recordId: row.id);
      }
      for (final w in weights) {
        final id = _uuid.v4();
        await _db.into(_db.diveWeights).insert(_weightCompanion(id, diveId, w, now));
        await _syncRepository.markRecordPending(
            entityType: 'diveWeights', recordId: id, localUpdatedAt: now);
      }
    }
    await _bumpDives(diveIds, now);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add bulk weights add and replace"
```

---

## Phase 2 — Buddy & Species repository bulk methods

### Task 7: `BuddyRepository` bulk Add / Remove / Replace

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart`
- Test: `test/features/buddies/data/repositories/buddy_repository_bulk_test.dart` (new)

**Interfaces:**
- Consumes: `domain.BuddyWithRole` (`buddy.id`, `role` (`.name`)).
- Produces:
  - `bulkAddBuddies(List<String> diveIds, List<domain.BuddyWithRole> buddies)` — upsert per (dive, buddy), preserving role.
  - `bulkRemoveBuddies(List<String> diveIds, List<String> buddyIds)`
  - `bulkReplaceBuddies(List<String> diveIds, List<domain.BuddyWithRole> buddies)`
  - None call `notifyLocalChange` or open a transaction.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/buddies/data/repositories/buddy_repository_bulk_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart' as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late BuddyRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF'); // skip seeding dives/buddies catalogs
    repository = BuddyRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.BuddyWithRole bwr(String id) => domain.BuddyWithRole(
        buddy: domain.Buddy(
          id: id,
          name: 'B$id',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        role: BuddyRole.buddy,
      );

  test('bulkAddBuddies links each buddy to each dive', () async {
    await repository.bulkAddBuddies(['d1', 'd2'], [bwr('x'), bwr('y')]);
    final d1 = await (db.select(db.diveBuddies)..where((t) => t.diveId.equals('d1'))).get();
    expect(d1.map((r) => r.buddyId).toSet(), {'x', 'y'});
    final d2 = await (db.select(db.diveBuddies)..where((t) => t.diveId.equals('d2'))).get();
    expect(d2.length, 2);
  });

  test('bulkReplaceBuddies overwrites; bulkRemoveBuddies subtracts', () async {
    await repository.bulkAddBuddies(['d1'], [bwr('x'), bwr('y')]);
    await repository.bulkReplaceBuddies(['d1'], [bwr('z')]);
    var rows = await (db.select(db.diveBuddies)..where((t) => t.diveId.equals('d1'))).get();
    expect(rows.map((r) => r.buddyId).toSet(), {'z'});

    await repository.bulkRemoveBuddies(['d1'], ['z']);
    rows = await (db.select(db.diveBuddies)..where((t) => t.diveId.equals('d1'))).get();
    expect(rows, isEmpty);
  });
}
```

(Confirm `domain.Buddy`'s required constructor params against `lib/features/buddies/domain/entities/buddy.dart` before running.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_repository_bulk_test.dart`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Write minimal implementation** (add to `BuddyRepository`, mirroring `setBuddiesForDive`/`addBuddyToDive`)

```dart
  Future<void> _bumpDive(String diveId, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId)))
        .write(DivesCompanion(updatedAt: Value(now)));
    await _syncRepository.markRecordPending(
        entityType: 'dives', recordId: diveId, localUpdatedAt: now);
  }

  Future<void> bulkAddBuddies(
    List<String> diveIds,
    List<domain.BuddyWithRole> buddies,
  ) async {
    if (diveIds.isEmpty || buddies.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      for (final bwr in buddies) {
        final existing = await (_db.select(_db.diveBuddies)
              ..where((t) => t.diveId.equals(diveId) & t.buddyId.equals(bwr.buddy.id)))
            .getSingleOrNull();
        if (existing != null) {
          await (_db.update(_db.diveBuddies)
                ..where((t) => t.diveId.equals(diveId) & t.buddyId.equals(bwr.buddy.id)))
              .write(DiveBuddiesCompanion(role: Value(bwr.role.name)));
          await _syncRepository.markRecordPending(
              entityType: 'diveBuddies', recordId: existing.id, localUpdatedAt: now);
        } else {
          final id = _uuid.v4();
          await _db.into(_db.diveBuddies).insert(DiveBuddiesCompanion(
                id: Value(id),
                diveId: Value(diveId),
                buddyId: Value(bwr.buddy.id),
                role: Value(bwr.role.name),
                createdAt: Value(now),
              ));
          await _syncRepository.markRecordPending(
              entityType: 'diveBuddies', recordId: id, localUpdatedAt: now);
        }
      }
      await _bumpDive(diveId, now);
    }
  }

  Future<void> bulkRemoveBuddies(List<String> diveIds, List<String> buddyIds) async {
    if (diveIds.isEmpty || buddyIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_db.select(_db.diveBuddies)
          ..where((t) => t.diveId.isIn(diveIds) & t.buddyId.isIn(buddyIds)))
        .get();
    await (_db.delete(_db.diveBuddies)
          ..where((t) => t.diveId.isIn(diveIds) & t.buddyId.isIn(buddyIds)))
        .go();
    for (final row in existing) {
      await _syncRepository.logDeletion(entityType: 'diveBuddies', recordId: row.id);
    }
    for (final diveId in diveIds) {
      await _bumpDive(diveId, now);
    }
  }

  Future<void> bulkReplaceBuddies(
    List<String> diveIds,
    List<domain.BuddyWithRole> buddies,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      final existing =
          await (_db.select(_db.diveBuddies)..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(_db.diveBuddies)..where((t) => t.diveId.equals(diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(entityType: 'diveBuddies', recordId: row.id);
      }
      for (final bwr in buddies) {
        final id = _uuid.v4();
        await _db.into(_db.diveBuddies).insert(DiveBuddiesCompanion(
              id: Value(id),
              diveId: Value(diveId),
              buddyId: Value(bwr.buddy.id),
              role: Value(bwr.role.name),
              createdAt: Value(now),
            ));
        await _syncRepository.markRecordPending(
            entityType: 'diveBuddies', recordId: id, localUpdatedAt: now);
      }
      await _bumpDive(diveId, now);
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/buddies/data/repositories/buddy_repository_bulk_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(buddies): add bulk buddy add/remove/replace for dives"
```

### Task 8: `SpeciesRepository` bulk Add + Replace sightings

**Files:**
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart`
- Test: `test/features/marine_life/data/repositories/species_repository_bulk_test.dart` (new)

**Interfaces:**
- Consumes: `domain.Sighting` (uses `speciesId`, `count`, `notes`; `id`/`diveId` are re-keyed per dive).
- Produces: `bulkAddSightings(List<String> diveIds, List<domain.Sighting> sightings)` and `bulkReplaceSightings(List<String> diveIds, List<domain.Sighting> sightings)`. No notify/transaction.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/marine_life/data/repositories/species_repository_bulk_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart' as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late SpeciesRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = SpeciesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.Sighting s(String speciesId, {int count = 1}) => domain.Sighting(
        id: '',
        diveId: '',
        speciesId: speciesId,
        speciesName: '',
        count: count,
      );

  test('bulkAddSightings inserts a sighting per dive per template', () async {
    await repository.bulkAddSightings(['d1', 'd2'], [s('turtle', count: 2)]);
    final d1 = await (db.select(db.sightings)..where((t) => t.diveId.equals('d1'))).get();
    expect(d1.single.speciesId, 'turtle');
    expect(d1.single.count, 2);
    final d2 = await (db.select(db.sightings)..where((t) => t.diveId.equals('d2'))).get();
    expect(d2.length, 1);
  });

  test('bulkReplaceSightings overwrites per dive', () async {
    await repository.bulkAddSightings(['d1'], [s('turtle')]);
    await repository.bulkReplaceSightings(['d1'], [s('shark')]);
    final rows = await (db.select(db.sightings)..where((t) => t.diveId.equals('d1'))).get();
    expect(rows.single.speciesId, 'shark');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/marine_life/data/repositories/species_repository_bulk_test.dart`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
  Future<void> _bumpDive(String diveId, int now) async {
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId)))
        .write(DivesCompanion(updatedAt: Value(now)));
    await _syncRepository.markRecordPending(
        entityType: 'dives', recordId: diveId, localUpdatedAt: now);
  }

  Future<void> bulkAddSightings(
    List<String> diveIds,
    List<domain.Sighting> sightings,
  ) async {
    if (diveIds.isEmpty || sightings.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      for (final sighting in sightings) {
        final id = _uuid.v4();
        await _db.into(_db.sightings).insert(SightingsCompanion(
              id: Value(id),
              diveId: Value(diveId),
              speciesId: Value(sighting.speciesId),
              count: Value(sighting.count),
              notes: Value(sighting.notes),
            ));
        await _syncRepository.markRecordPending(
            entityType: 'sightings', recordId: id, localUpdatedAt: now);
      }
      await _bumpDive(diveId, now);
    }
  }

  Future<void> bulkReplaceSightings(
    List<String> diveIds,
    List<domain.Sighting> sightings,
  ) async {
    if (diveIds.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final diveId in diveIds) {
      final existing =
          await (_db.select(_db.sightings)..where((t) => t.diveId.equals(diveId))).get();
      await (_db.delete(_db.sightings)..where((t) => t.diveId.equals(diveId))).go();
      for (final row in existing) {
        await _syncRepository.logDeletion(entityType: 'sightings', recordId: row.id);
      }
      for (final sighting in sightings) {
        final id = _uuid.v4();
        await _db.into(_db.sightings).insert(SightingsCompanion(
              id: Value(id),
              diveId: Value(diveId),
              speciesId: Value(sighting.speciesId),
              count: Value(sighting.count),
              notes: Value(sighting.notes),
            ));
        await _syncRepository.markRecordPending(
            entityType: 'sightings', recordId: id, localUpdatedAt: now);
      }
      await _bumpDive(diveId, now);
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/marine_life/data/repositories/species_repository_bulk_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(marine-life): add bulk sightings add and replace"
```

---

## Phase 3 — Request/Snapshot models, orchestration service, undo

### Task 9: `BulkEditRequest` + collection-op model

**Files:**
- Create: `lib/features/dive_log/domain/entities/bulk_edit_request.dart`
- Test: `test/features/dive_log/domain/entities/bulk_edit_request_test.dart` (new)

**Interfaces:**
- Produces:
  - `enum BulkCollectionMode { add, remove, replace }`
  - `sealed class BulkCollectionOp` with subclasses `TagsOp(mode, tagIds)`, `EquipmentOp(mode, equipmentIds)`, `BuddiesOp(mode, buddies)`, `TanksOp(mode, tanks, onlyIfEmpty)`, `WeightsOp(mode, weights)`, `SightingsOp(mode, sightings)`.
  - `class BulkEditRequest { List<String> diveIds; DivesCompanion scalars; String? notesAppend; List<BulkCollectionOp> ops; bool get hasScalarChanges; }`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';

void main() {
  test('hasScalarChanges is false for an all-absent companion', () {
    const req = BulkEditRequest(diveIds: ['a'], scalars: DivesCompanion());
    expect(req.hasScalarChanges, isFalse);
  });

  test('hasScalarChanges is true when any column is present', () {
    const req = BulkEditRequest(diveIds: ['a'], scalars: DivesCompanion(rating: Value(5)));
    expect(req.hasScalarChanges, isTrue);
  });

  test('TagsOp carries mode and ids', () {
    const op = TagsOp(mode: BulkCollectionMode.add, tagIds: ['t1']);
    expect(op.mode, BulkCollectionMode.add);
    expect(op.tagIds, ['t1']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/bulk_edit_request_test.dart`
Expected: FAIL — file/types not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

enum BulkCollectionMode { add, remove, replace }

sealed class BulkCollectionOp {
  const BulkCollectionOp();
}

class TagsOp extends BulkCollectionOp {
  final BulkCollectionMode mode;
  final List<String> tagIds;
  const TagsOp({required this.mode, required this.tagIds});
}

class EquipmentOp extends BulkCollectionOp {
  final BulkCollectionMode mode;
  final List<String> equipmentIds;
  const EquipmentOp({required this.mode, required this.equipmentIds});
}

class BuddiesOp extends BulkCollectionOp {
  final BulkCollectionMode mode;
  final List<BuddyWithRole> buddies; // ids for remove read from .buddy.id
  const BuddiesOp({required this.mode, required this.buddies});
}

class TanksOp extends BulkCollectionOp {
  final BulkCollectionMode mode; // add | replace
  final List<DiveTank> tanks;
  final bool onlyIfEmpty;
  const TanksOp({required this.mode, required this.tanks, this.onlyIfEmpty = false});
}

class WeightsOp extends BulkCollectionOp {
  final BulkCollectionMode mode; // add | replace
  final List<DiveWeight> weights;
  const WeightsOp({required this.mode, required this.weights});
}

class SightingsOp extends BulkCollectionOp {
  final BulkCollectionMode mode; // add | replace
  final List<Sighting> sightings;
  const SightingsOp({required this.mode, required this.sightings});
}

class BulkEditRequest {
  final List<String> diveIds;
  final DivesCompanion scalars;
  final String? notesAppend;
  final List<BulkCollectionOp> ops;

  const BulkEditRequest({
    required this.diveIds,
    this.scalars = const DivesCompanion(),
    this.notesAppend,
    this.ops = const [],
  });

  /// True when at least one column of [scalars] is present (non-absent).
  bool get hasScalarChanges => scalars.toColumns(false).isNotEmpty;
}
```

(`Companion.toColumns(false)` returns only present columns — the canonical Drift way to detect a non-empty companion.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/bulk_edit_request_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add BulkEditRequest and collection-op model"
```

### Task 10: `BulkEditSnapshot` model

**Files:**
- Create: `lib/features/dive_log/domain/entities/bulk_edit_snapshot.dart`

**Interfaces:**
- Produces: `class BulkEditSnapshot` holding `List<Dive> priorDiveRows` (Drift rows) plus nullable per-collection prior membership maps keyed by diveId: `Map<String, List<String>>? priorTagIds`, `priorEquipmentIds`; `Map<String, List<BuddyWithRole>>? priorBuddies`; `Map<String, List<DiveTank>>? priorTanks` (Drift rows); `Map<String, List<DiveWeight>>? priorWeights` (Drift rows); `Map<String, List<Sighting>>? priorSightings` (Drift rows). A `null` map means that collection was untouched and must not be restored.

This task is a pure data holder, exercised by the service tests (Task 11/12). No standalone test.

- [ ] **Step 1: Write the implementation**

```dart
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';

/// Captured prior state for undoing one bulk edit. All collections are keyed by
/// diveId. A null map = that collection was not touched and must not be restored.
class BulkEditSnapshot {
  final List<Dive> priorDiveRows; // Drift rows (scalar + notes undo via toCompanion)
  final Map<String, List<String>>? priorTagIds;
  final Map<String, List<String>>? priorEquipmentIds;
  final Map<String, List<BuddyWithRole>>? priorBuddies;
  final Map<String, List<DiveTank>>? priorTanks; // Drift DiveTanks rows
  final Map<String, List<DiveWeight>>? priorWeights; // Drift DiveWeights rows
  final Map<String, List<Sighting>>? priorSightings; // Drift Sightings rows

  const BulkEditSnapshot({
    required this.priorDiveRows,
    this.priorTagIds,
    this.priorEquipmentIds,
    this.priorBuddies,
    this.priorTanks,
    this.priorWeights,
    this.priorSightings,
  });
}
```

Note the name clashes: here `Dive`, `DiveTank`, `DiveWeight`, `Sighting` are the **Drift row** types from `database.dart`; `BuddyWithRole` is the domain type. The service file (Task 11) imports domain entities `as domain` to keep them distinct.

- [ ] **Step 2: Commit** (no test yet — covered by the service)

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add BulkEditSnapshot data holder"
```

### Task 11: `BulkDiveEditService.apply` — transactional apply + snapshot

**Files:**
- Create: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart`
- Test: `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart` (new)

**Interfaces:**
- Consumes: `DiveRepository`, `BuddyRepository`, `SpeciesRepository` bulk methods (Phase 1-2); `BulkEditRequest`; `BulkEditSnapshot`.
- Produces: `class BulkDiveEditService { BulkDiveEditService(this._diveRepo, this._buddyRepo, this._speciesRepo); Future<BulkEditSnapshot> apply(BulkEditRequest req); }` — captures prior state, runs all writes inside one `db.transaction`, fires one `notifyLocalChange()`, returns the snapshot.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late BulkDiveEditService service;
  late DiveRepository diveRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    service = BulkDiveEditService(diveRepo, BuddyRepository(), SpeciesRepository());
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seed(String id) =>
      diveRepo.createDive(domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''));

  test('apply writes scalars + notes-append + a tag op and returns a snapshot', () async {
    await seed('d1');
    await seed('d2');

    final snap = await service.apply(BulkEditRequest(
      diveIds: const ['d1', 'd2'],
      scalars: const DivesCompanion(rating: Value(4)),
      notesAppend: ' trip',
      ops: const [TagsOp(mode: BulkCollectionMode.replace, tagIds: ['t1'])],
    ));

    final r1 = await (db.select(db.dives)..where((t) => t.id.equals('d1'))).getSingle();
    expect(r1.rating, 4);
    expect(r1.notes, ' trip');
    final tags = await (db.select(db.diveTags)..where((t) => t.diveId.equals('d1'))).get();
    expect(tags.single.tagId, 't1');
    expect(snap.priorDiveRows.length, 2);
    expect(snap.priorTagIds, isNotNull); // tag op was touched
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`
Expected: FAIL — service not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_snapshot.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

class BulkDiveEditService {
  BulkDiveEditService(this._diveRepo, this._buddyRepo, this._speciesRepo);

  final DiveRepository _diveRepo;
  final BuddyRepository _buddyRepo;
  final SpeciesRepository _speciesRepo;

  AppDatabase get _db => DatabaseService.instance.database;

  Future<BulkEditSnapshot> apply(BulkEditRequest req) async {
    final ids = req.diveIds;
    if (ids.isEmpty) {
      return const BulkEditSnapshot(priorDiveRows: []);
    }

    // Capture prior state BEFORE mutating (reads outside the transaction).
    final priorDiveRows =
        await (_db.select(_db.dives)..where((t) => t.id.isIn(ids))).get();

    Map<String, List<String>>? priorTagIds;
    Map<String, List<String>>? priorEquipmentIds;
    Map<String, List<BuddyWithRole>>? priorBuddies;
    Map<String, List<DiveTank>>? priorTanks;
    Map<String, List<DiveWeight>>? priorWeights;
    Map<String, List<Sighting>>? priorSightings;

    for (final op in req.ops) {
      switch (op) {
        case TagsOp():
          final rows =
              await (_db.select(_db.diveTags)..where((t) => t.diveId.isIn(ids))).get();
          priorTagIds = {for (final id in ids) id: <String>[]};
          for (final r in rows) {
            priorTagIds[r.diveId]!.add(r.tagId);
          }
        case EquipmentOp():
          final rows =
              await (_db.select(_db.diveEquipment)..where((t) => t.diveId.isIn(ids))).get();
          priorEquipmentIds = {for (final id in ids) id: <String>[]};
          for (final r in rows) {
            priorEquipmentIds[r.diveId]!.add(r.equipmentId);
          }
        case BuddiesOp():
          priorBuddies = {
            for (final id in ids) id: await _buddyRepo.getBuddiesForDive(id),
          };
        case TanksOp():
          final rows =
              await (_db.select(_db.diveTanks)..where((t) => t.diveId.isIn(ids))).get();
          priorTanks = {for (final id in ids) id: <DiveTank>[]};
          for (final r in rows) {
            priorTanks[r.diveId]!.add(r);
          }
        case WeightsOp():
          final rows =
              await (_db.select(_db.diveWeights)..where((t) => t.diveId.isIn(ids))).get();
          priorWeights = {for (final id in ids) id: <DiveWeight>[]};
          for (final r in rows) {
            priorWeights[r.diveId]!.add(r);
          }
        case SightingsOp():
          final rows =
              await (_db.select(_db.sightings)..where((t) => t.diveId.isIn(ids))).get();
          priorSightings = {for (final id in ids) id: <Sighting>[]};
          for (final r in rows) {
            priorSightings[r.diveId]!.add(r);
          }
      }
    }

    await _db.transaction(() async {
      if (req.hasScalarChanges) {
        await _diveRepo.bulkUpdateFields(ids, req.scalars);
      }
      if (req.notesAppend != null && req.notesAppend!.isNotEmpty) {
        await _diveRepo.bulkAppendNotes(ids, req.notesAppend!);
      }
      for (final op in req.ops) {
        await _applyOp(ids, op);
      }
    });

    SyncEventBus.notifyLocalChange();

    return BulkEditSnapshot(
      priorDiveRows: priorDiveRows,
      priorTagIds: priorTagIds,
      priorEquipmentIds: priorEquipmentIds,
      priorBuddies: priorBuddies,
      priorTanks: priorTanks,
      priorWeights: priorWeights,
      priorSightings: priorSightings,
    );
  }

  Future<void> _applyOp(List<String> ids, BulkCollectionOp op) async {
    switch (op) {
      case TagsOp(:final mode, :final tagIds):
        switch (mode) {
          case BulkCollectionMode.add:
            await _diveRepo.bulkAddTags(ids, tagIds);
          case BulkCollectionMode.remove:
            await _diveRepo.bulkRemoveTags(ids, tagIds);
          case BulkCollectionMode.replace:
            await _diveRepo.bulkReplaceTags(ids, tagIds);
        }
      case EquipmentOp(:final mode, :final equipmentIds):
        switch (mode) {
          case BulkCollectionMode.add:
            await _diveRepo.bulkAddEquipment(ids, equipmentIds);
          case BulkCollectionMode.remove:
            await _diveRepo.bulkRemoveEquipment(ids, equipmentIds);
          case BulkCollectionMode.replace:
            await _diveRepo.bulkReplaceEquipment(ids, equipmentIds);
        }
      case BuddiesOp(:final mode, :final buddies):
        switch (mode) {
          case BulkCollectionMode.add:
            await _buddyRepo.bulkAddBuddies(ids, buddies);
          case BulkCollectionMode.remove:
            await _buddyRepo
                .bulkRemoveBuddies(ids, buddies.map((b) => b.buddy.id).toList());
          case BulkCollectionMode.replace:
            await _buddyRepo.bulkReplaceBuddies(ids, buddies);
        }
      case TanksOp(:final mode, :final tanks, :final onlyIfEmpty):
        if (mode == BulkCollectionMode.replace) {
          await _diveRepo.bulkReplaceTanks(ids, tanks);
        } else {
          for (final tank in tanks) {
            await _diveRepo.bulkAddTank(ids, tank, onlyIfEmpty: onlyIfEmpty);
          }
        }
      case WeightsOp(:final mode, :final weights):
        if (mode == BulkCollectionMode.replace) {
          await _diveRepo.bulkReplaceWeights(ids, weights);
        } else {
          await _diveRepo.bulkAddWeights(ids, weights);
        }
      case SightingsOp(:final mode, :final sightings):
        if (mode == BulkCollectionMode.replace) {
          await _speciesRepo.bulkReplaceSightings(ids, sightings);
        } else {
          await _speciesRepo.bulkAddSightings(ids, sightings);
        }
    }
  }

}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/services/bulk_dive_edit_service_test.dart` and `flutter analyze lib/features/dive_log/data/services/bulk_dive_edit_service.dart`
Expected: PASS; analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add BulkDiveEditService.apply with snapshot capture"
```

### Task 12: `BulkDiveEditService.undo`

**Files:**
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart`
- Test: `bulk_dive_edit_service_test.dart`

**Interfaces:**
- Produces: `Future<void> undo(BulkEditSnapshot snapshot)` — restores each prior dive row's scalar columns (`row.toCompanion(false)` + fresh `updatedAt`), and for every non-null collection map, restores that dive's prior membership (replace-with-prior). One transaction, one notify.

- [ ] **Step 1: Write the failing test** (append to the service test)

```dart
  test('undo restores prior scalar values and tag membership', () async {
    await seed('d1');
    await diveRepo.bulkUpdateFields(['d1'], const DivesCompanion(rating: Value(2)));
    await diveRepo.bulkReplaceTags(['d1'], ['orig']);

    final snap = await service.apply(BulkEditRequest(
      diveIds: const ['d1'],
      scalars: const DivesCompanion(rating: Value(9)),
      ops: const [TagsOp(mode: BulkCollectionMode.replace, tagIds: ['new'])],
    ));

    await service.undo(snap);

    final r = await (db.select(db.dives)..where((t) => t.id.equals('d1'))).getSingle();
    expect(r.rating, 2); // restored
    final tags = await (db.select(db.diveTags)..where((t) => t.diveId.equals('d1'))).get();
    expect(tags.single.tagId, 'orig'); // restored
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/services/bulk_dive_edit_service_test.dart --plain-name undo`
Expected: FAIL — `undo` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
  final _sync = SyncRepository();

  Future<void> undo(BulkEditSnapshot snapshot) async {
    if (snapshot.priorDiveRows.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ids = snapshot.priorDiveRows.map((r) => r.id).toList();

    await _db.transaction(() async {
      // Restore scalar columns from the full prior row (nullToAbsent: false so
      // prior NULLs are restored, not left absent), with a fresh updatedAt so
      // the undo wins LWW; then mark each dive pending.
      for (final row in snapshot.priorDiveRows) {
        await (_db.update(_db.dives)..where((t) => t.id.equals(row.id)))
            .write(row.toCompanion(false).copyWith(updatedAt: Value(now)));
        await _sync.markRecordPending(
            entityType: 'dives', recordId: row.id, localUpdatedAt: now);
      }

      // Restore each touched collection per dive (replace-with-prior).
      final tags = snapshot.priorTagIds;
      if (tags != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceTags([id], tags[id] ?? const []);
        }
      }
      final equip = snapshot.priorEquipmentIds;
      if (equip != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceEquipment([id], equip[id] ?? const []);
        }
      }
      final buddies = snapshot.priorBuddies;
      if (buddies != null) {
        for (final id in ids) {
          await _buddyRepo.bulkReplaceBuddies([id], buddies[id] ?? const []);
        }
      }
      final tanks = snapshot.priorTanks;
      if (tanks != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceTanks([id], _tanksFromRows(tanks[id] ?? const []));
        }
      }
      final weights = snapshot.priorWeights;
      if (weights != null) {
        for (final id in ids) {
          await _diveRepo.bulkReplaceWeights([id], _weightsFromRows(weights[id] ?? const []));
        }
      }
      final sightings = snapshot.priorSightings;
      if (sightings != null) {
        for (final id in ids) {
          await _speciesRepo
              .bulkReplaceSightings([id], _sightingsFromRows(sightings[id] ?? const []));
        }
      }
    });

    SyncEventBus.notifyLocalChange();
  }

  // Map Drift rows (unprefixed types from database.dart) back to the domain
  // objects the bulk-replace methods consume (domain imported with prefixes
  // `de` = dive.dart, `se` = species.dart).
  List<de.DiveTank> _tanksFromRows(List<DiveTank> rows) => [
        for (final r in rows)
          de.DiveTank(
            id: '',
            name: r.tankName,
            volume: r.volume,
            workingPressure: r.workingPressure,
            startPressure: r.startPressure,
            endPressure: r.endPressure,
            gasMix: de.GasMix(o2: r.o2Percent, he: r.hePercent),
            role: de.TankRole.values.firstWhere(
                (e) => e.name == r.tankRole, orElse: () => de.TankRole.backGas),
            material: r.tankMaterial == null
                ? null
                : de.TankMaterial.values.firstWhere(
                    (e) => e.name == r.tankMaterial, orElse: () => de.TankMaterial.aluminum),
            presetName: r.presetName,
          ),
      ];

  List<de.DiveWeight> _weightsFromRows(List<DiveWeight> rows) => [
        for (final r in rows)
          de.DiveWeight(
            id: '',
            weightType: de.WeightType.values.firstWhere(
                (e) => e.name == r.weightType, orElse: () => de.WeightType.values.first),
            amountKg: r.amountKg,
            notes: r.notes,
          ),
      ];

  List<se.Sighting> _sightingsFromRows(List<Sighting> rows) => [
        for (final r in rows)
          se.Sighting(
            id: '',
            diveId: '',
            speciesId: r.speciesId,
            speciesName: '',
            count: r.count,
            notes: r.notes,
          ),
      ];
```

Add these imports to `bulk_dive_edit_service.dart` (the `de`/`se` prefixes keep the domain entities distinct from the identically-named Drift rows; `database.dart` stays unprefixed for the rows):

```dart
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as de;
import 'package:submersion/features/marine_life/domain/entities/species.dart' as se;
```

`bulkReplaceTanks` recomputes `tankOrder` by index, so restored tanks need no explicit order. Confirm the domain constructor params and enum spellings (`de.TankRole.backGas`, `de.TankMaterial.aluminum`, `de.WeightType`) against `lib/features/dive_log/domain/entities/dive.dart` before running, then run `flutter analyze lib/features/dive_log/data/services/`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/services/bulk_dive_edit_service_test.dart` and `flutter analyze lib/features/dive_log/data/services/`
Expected: PASS; analyze clean.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add BulkDiveEditService.undo (per-dive restore)"
```

### Task 13: `bulkDiveEditServiceProvider`

**Files:**
- Create: `lib/features/dive_log/presentation/providers/bulk_dive_edit_provider.dart`
- Test: none (trivial wiring; covered when the form consumes it in Plan 2)

**Interfaces:**
- Produces: `final bulkDiveEditServiceProvider = Provider<BulkDiveEditService>(...)` wiring the three repositories from their existing providers.

- [ ] **Step 1: Write the implementation**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

final bulkDiveEditServiceProvider = Provider<BulkDiveEditService>((ref) {
  return BulkDiveEditService(
    ref.watch(diveRepositoryProvider),
    ref.watch(buddyRepositoryProvider),
    ref.watch(speciesRepositoryProvider),
  );
});
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/dive_log/presentation/providers/bulk_dive_edit_provider.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add bulkDiveEditServiceProvider"
```

---

## Phase 4 — Selection mechanics (anchor, shift-click, date range)

All Phase 4 changes are in `lib/features/dive_log/presentation/widgets/dive_list_content.dart` unless noted. Tests go in `test/features/dive_log/presentation/widgets/dive_list_selection_test.dart` (new).

### Task 14: Selection anchor + shift-click range selection

**Files:**
- Modify: `dive_list_content.dart` — add `int? _anchorIndex`; update `_enterSelectionMode`, `_toggleSelection`; add `_selectRangeTo(int index, List<DiveSummary> dives)`; pass an `onSelectRange`/shift-aware tap into the list tiles.
- Test: `dive_list_selection_test.dart`

**Interfaces:**
- Produces: `void _selectRangeTo(int index, List<DiveSummary> dives)` — selects every dive between `_anchorIndex` and `index` inclusive. Pure list math is extracted to a testable top-level function `List<String> rangeIds(List<DiveSummary> dives, int anchor, int target)`.

- [ ] **Step 1: Write the failing test** (test the pure range helper — fast and deterministic)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart'
    show rangeIds;
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

DiveSummary summary(String id) => DiveSummary(id: id, dateTime: DateTime(2026, 1, 1));

void main() {
  test('rangeIds returns inclusive span regardless of direction', () {
    final dives = ['a', 'b', 'c', 'd'].map(summary).toList();
    expect(rangeIds(dives, 1, 3), ['b', 'c', 'd']);
    expect(rangeIds(dives, 3, 1), ['b', 'c', 'd']); // reversed
    expect(rangeIds(dives, 2, 2), ['c']); // single
  });
}
```

(Confirm `DiveSummary`'s required constructor params against `lib/features/dive_log/domain/entities/dive_summary.dart`; adjust the `summary` helper accordingly.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: FAIL — `rangeIds` not defined.

- [ ] **Step 3: Write minimal implementation**

Add a top-level function in `dive_list_content.dart` (above the widget class):

```dart
/// Inclusive id span between [anchor] and [target] indices in [dives].
List<String> rangeIds(List<DiveSummary> dives, int anchor, int target) {
  final lo = anchor < target ? anchor : target;
  final hi = anchor < target ? target : anchor;
  return [for (var i = lo; i <= hi; i++) dives[i].id];
}
```

Add the anchor field and wire it:

```dart
  int? _anchorIndex;
```

In `_enterSelectionMode`, accept and store an index (overload-friendly): change call sites in the `itemBuilder` to pass the row `index`, and set `_anchorIndex = index` when entering. In `_toggleSelection`, set `_anchorIndex` to the toggled dive's index. Add:

```dart
  void _selectRangeTo(int index, List<DiveSummary> dives) {
    final anchor = _anchorIndex ?? index;
    setState(() {
      _selectedIds.addAll(rangeIds(dives, anchor, index));
      _anchorIndex = index;
    });
  }
```

In the detailed/compact `itemBuilder`, wrap the tile so a Shift-modified tap calls `_selectRangeTo(index, dives)` instead of `_handleItemTap`. The minimal mechanism: read `HardwareKeyboard.instance.isShiftPressed` inside the `onTap`:

```dart
    onTap: () {
      if (_isSelectionMode &&
          HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
              k == LogicalKeyboardKey.shiftLeft || k == LogicalKeyboardKey.shiftRight)) {
        _selectRangeTo(index, dives);
      } else {
        _handleItemTap(dive);
      }
    },
```

Add `import 'package:flutter/services.dart';` for `HardwareKeyboard`/`LogicalKeyboardKey`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): shift-click range selection with a selection anchor"
```

### Task 15: "Select by date range" action

**Files:**
- Modify: `dive_list_content.dart` — add `_selectByDateRange(List<DiveSummary> dives)` and an icon button in both `_buildSelectionAppBar` (line 1143) and `_buildSelectionBar` (line 1192).
- l10n: add `diveLog_selection_tooltip_selectDateRange` (Task 16).

**Interfaces:**
- Produces: `Future<void> _selectByDateRange(List<DiveSummary> dives)` — shows `showDateRangePicker`, then adds every dive whose `dateTime` falls within `[start, end]` (inclusive of the end day) to `_selectedIds`. The pure predicate is extracted as `bool inDateRange(DiveSummary d, DateTimeRange r)` for testing.

- [ ] **Step 1: Write the failing test**

```dart
  test('inDateRange includes dives on the boundary days', () {
    final r = DateTimeRange(start: DateTime(2026, 6, 1), end: DateTime(2026, 6, 3));
    expect(inDateRange(summary('a', DateTime(2026, 6, 1, 8)), r), isTrue);
    expect(inDateRange(summary('b', DateTime(2026, 6, 3, 23)), r), isTrue);
    expect(inDateRange(summary('c', DateTime(2026, 5, 31)), r), isFalse);
  });
```

(Extend the `summary` helper to take a `DateTime`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart --plain-name inDateRange`
Expected: FAIL — `inDateRange` not defined.

- [ ] **Step 3: Write minimal implementation**

Top-level helper:

```dart
/// True if [d]'s date falls within [r] (inclusive of the end calendar day).
bool inDateRange(DiveSummary d, DateTimeRange r) {
  final day = DateTime(d.dateTime.year, d.dateTime.month, d.dateTime.day);
  final endDay = DateTime(r.end.year, r.end.month, r.end.day);
  return !day.isBefore(DateTime(r.start.year, r.start.month, r.start.day)) &&
      !day.isAfter(endDay);
}
```

Method + toolbar buttons:

```dart
  Future<void> _selectByDateRange(List<DiveSummary> dives) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (range == null) return;
    setState(() {
      _selectedIds.addAll(dives.where((d) => inDateRange(d, range)).map((d) => d.id));
    });
  }
```

Add this `IconButton` to both selection toolbars (next to select-all):

```dart
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: context.l10n.diveLog_selection_tooltip_selectDateRange,
            onPressed: () => _selectByDateRange(dives),
          ),
```

(In `_buildSelectionBar`, the table-mode caller passes `const []`; keep the button but it will select nothing there — acceptable, matching the existing select-all limitation in table mode.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: PASS. (l10n key added in Task 16; until then use a literal string or land Task 16 first.)

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(dive-log): add Select-by-date-range to multi-select toolbars"
```

### Task 16: Localize the new selection strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (+ all 10 non-English ARB files)
- Run: `flutter gen-l10n`

**Interfaces:**
- Produces l10n key `diveLog_selection_tooltip_selectDateRange` (and any other new selection strings) used in Task 15.

- [ ] **Step 1: Add the English template key**

In `lib/l10n/arb/app_en.arb`, alongside the other `diveLog_selection_tooltip_*` keys:

```json
  "diveLog_selection_tooltip_selectDateRange": "Select by date range",
```

- [ ] **Step 2: Add translations to all 10 non-English ARB files**

Add the same key with a translated value to each of: `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`. (German example: `"diveLog_selection_tooltip_selectDateRange": "Nach Datumsbereich auswählen",`.)

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations*.dart` with the new getter; no errors.

- [ ] **Step 4: Verify analyze + tests**

Run: `flutter analyze lib/features/dive_log/presentation/widgets/dive_list_content.dart` then `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: No issues; tests PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "i18n(dive-log): localize select-by-date-range tooltip in all locales"
```

---

## Final verification

- [ ] Run the full new-test surface:
  `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart test/features/buddies/data/repositories/buddy_repository_bulk_test.dart test/features/marine_life/data/repositories/species_repository_bulk_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart test/features/dive_log/domain/entities/bulk_edit_request_test.dart test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
- [ ] `flutter analyze` (whole project) — clean.
- [ ] `dart format --set-exit-if-changed .` — clean.

---

## Next plan (Plan 2): DiveEditPage bulk mode

The engine above is consumed by a follow-up plan that adds the user-facing bulk-edit form. That plan needs a verbatim extraction pass over the edit-form **section widgets** (`lib/features/dive_log/presentation/widgets/edit_sections/*.dart`) so the per-field gate code is real, not guessed. Its tasks:

1. `DiveEditPage(bulkDiveIds:)` constructor param + `isBulk` getter + mutual-exclusion assert (mirror `SiteEditPage.mergeSiteIds`/`isMerging`, `site_edit_page.dart:32`).
2. A `/dives/bulk-edit` route taking `state.extra as List<dynamic>?).cast<String>()` (mirror `/dives/match-sites`, `app_router.dart:267`), plus a thin `BulkDiveEditPage` wrapper (mirror `SiteMergePage`).
3. Replace `_showBulkEditSheet` (`dive_list_content.dart:428`) with a "Bulk edit…" action that pushes the route with `_selectedIds.toList()`.
4. A `BulkFieldGate` widget (leading toggle) and `isBulk` branches that (a) hide identity/measured sections, (b) wrap each shown field in a gate, (c) render the dive-mode rebreather cascade as gated sub-fields (decision: rebreather group stays available, collapsed, when mode is unchanged), (d) give collections the Add/Remove/Replace selector with the tank-Add `onlyIfEmpty` checkbox, (e) give notes Set/Append.
5. A bulk `_saveDive` branch that builds a `BulkEditRequest` from the enabled gates and calls `bulkDiveEditServiceProvider`, then shows the snackbar-undo (mirror `_confirmAndDelete`, `dive_list_content.dart:228`) wired to `BulkDiveEditService.undo`.
6. A confirm dialog summarizing the change with the contradiction guard (mode = OC + CCR fields) and the destructive replace-tanks warning (the #276 cascade).
7. l10n for all new form strings across all 11 locales.
