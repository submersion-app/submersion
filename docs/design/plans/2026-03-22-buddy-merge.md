# Buddy Merge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to merge duplicate buddy entries, relinking dive associations and supporting undo, mirroring the sites merge pattern.

**Architecture:** Data layer adds `mergeBuddies()`/`undoMerge()` to `BuddyRepository` with snapshot-based undo. DiveBuddies junction relinking uses role hierarchy for collision resolution. UI reuses `BuddyEditPage` in merge mode with per-field cycling. Multi-select with merge + delete actions is added to the buddy list.

**Tech Stack:** Flutter, Drift ORM, Riverpod, go_router, Material 3

**Spec:** `docs/superpowers/specs/2026-03-22-buddy-merge-design.md`

---

### Task 1: Add snapshot classes and `mergeBuddies()` to BuddyRepository

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart`
- Test: `test/features/buddies/data/repositories/buddy_merge_test.dart`

- [ ] **Step 1: Write failing test for basic merge (no junction collisions)**

```dart
// test/features/buddies/data/repositories/buddy_merge_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart' as domain;
import 'package:submersion/core/constants/enums.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late db.AppDatabase database;
  late BuddyRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = BuddyRepository();
    database = DatabaseService.instance.database;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('mergeBuddies', () {
    test('merges two buddies with no shared dives', () async {
      // Create two buddies
      final buddyA = await repository.createBuddy(domain.Buddy(
        id: '',
        name: 'Alice',
        email: 'alice@example.com',
        notes: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      final buddyB = await repository.createBuddy(domain.Buddy(
        id: '',
        name: 'Bob',
        email: 'bob@example.com',
        phone: '555-0100',
        notes: 'Good buddy',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // Create a dive and assign buddyB to it
      final now = DateTime.now().millisecondsSinceEpoch;
      await database.into(database.dives).insert(db.DivesCompanion.insert(
        id: 'dive1',
        diveDateTime: now,
        createdAt: now,
        updatedAt: now,
      ));
      await repository.addBuddyToDive('dive1', buddyB.id, BuddyRole.buddy);

      // Merge: survivor is buddyA with merged fields
      final mergedBuddy = buddyA.copyWith(
        name: 'Alice',
        email: 'alice@example.com',
        phone: '555-0100',
      );
      final result = await repository.mergeBuddies(
        mergedBuddy: mergedBuddy,
        buddyIds: [buddyA.id, buddyB.id],
      );

      // Verify result
      expect(result, isNotNull);
      expect(result!.survivorId, buddyA.id);
      expect(result.snapshot, isNotNull);

      // Survivor should be updated
      final survivor = await repository.getBuddyById(buddyA.id);
      expect(survivor!.name, 'Alice');
      expect(survivor.phone, '555-0100');

      // BuddyB should be deleted
      final deleted = await repository.getBuddyById(buddyB.id);
      expect(deleted, isNull);

      // Dive1 should now reference buddyA
      final diveBuddies = await repository.getBuddiesForDive('dive1');
      expect(diveBuddies.length, 1);
      expect(diveBuddies.first.buddy.id, buddyA.id);
      expect(diveBuddies.first.role, BuddyRole.buddy);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_test.dart`
Expected: FAIL - `mergeBuddies` method not found

- [ ] **Step 3: Implement snapshot classes and `mergeBuddies()`**

Add to the bottom of `lib/features/buddies/data/repositories/buddy_repository.dart`, before the closing of the file:

```dart
/// Snapshot of a DiveBuddies junction row for undo.
class DiveBuddySnapshot {
  final String id;
  final String diveId;
  final String buddyId;
  final String role;

  const DiveBuddySnapshot({
    required this.id,
    required this.diveId,
    required this.buddyId,
    required this.role,
  });
}

/// Snapshot captured before a buddy merge for undo.
class BuddyMergeSnapshot {
  final domain.Buddy originalSurvivor;
  final List<domain.Buddy> deletedBuddies;
  final List<DiveBuddySnapshot> deletedDiveBuddyEntries;
  final List<DiveBuddySnapshot> modifiedDiveBuddyEntries;

  const BuddyMergeSnapshot({
    required this.originalSurvivor,
    required this.deletedBuddies,
    required this.deletedDiveBuddyEntries,
    required this.modifiedDiveBuddyEntries,
  });
}

/// Result from a buddy merge operation.
class BuddyMergeResult {
  final String survivorId;
  final BuddyMergeSnapshot? snapshot;

  const BuddyMergeResult({required this.survivorId, this.snapshot});
}
```

Add `mergeBuddies()` method to `BuddyRepository` class. Reference the role hierarchy (must include ALL `BuddyRole` enum values -- `buddy`, `diveGuide`, `instructor`, `student`, `diveMaster`, `solo`):
```dart
static const _roleRank = {
  'solo': 0,
  'student': 1,
  'buddy': 2,
  'diveGuide': 3,
  'diveMaster': 4,
  'instructor': 5,
};
```

The method must:
1. Validate >= 2 IDs, all exist, same diverId
2. Capture snapshot: original survivor, deleted buddies, all DiveBuddies for duplicates
3. Also query survivor's DiveBuddies to detect collisions
4. In transaction:
   a. Update survivor row with merged fields
   b. For each duplicate's DiveBuddies entry:
      - If survivor has no entry on that dive: update buddyId to survivor
      - If collision: compare roles, upgrade survivor if needed (snapshot original), delete duplicate entry
   c. Delete duplicate buddy rows (CASCADE cleans remaining junction rows)
   d. Log deletions for sync
5. Notify SyncEventBus
6. Return BuddyMergeResult

Follow the exact pattern of `site_repository_impl.dart:198-317` `mergeSites()`, adapted for junction table handling.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/data/repositories/buddy_repository.dart test/features/buddies/data/repositories/buddy_merge_test.dart
git commit -m "feat(buddies): add mergeBuddies() with snapshot classes"
```

---

### Task 2: Add role collision tests and junction relinking edge cases

**Files:**
- Modify: `test/features/buddies/data/repositories/buddy_merge_test.dart`

- [ ] **Step 1: Write test for role collision resolution**

```dart
test('collision: keeps higher-ranked role (instructor > buddy)', () async {
  final buddyA = await repository.createBuddy(domain.Buddy(
    id: '', name: 'Alice', notes: '',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final buddyB = await repository.createBuddy(domain.Buddy(
    id: '', name: 'Bob', notes: '',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));

  final now = DateTime.now().millisecondsSinceEpoch;
  await database.into(database.dives).insert(db.DivesCompanion.insert(
    id: 'dive1', diveDateTime: now, createdAt: now, updatedAt: now,
  ));

  // Both on same dive with different roles
  await repository.addBuddyToDive('dive1', buddyA.id, BuddyRole.buddy);
  await repository.addBuddyToDive('dive1', buddyB.id, BuddyRole.instructor);

  final result = await repository.mergeBuddies(
    mergedBuddy: buddyA.copyWith(name: 'Alice'),
    buddyIds: [buddyA.id, buddyB.id],
  );

  // Should have one entry with instructor role (the higher-ranked one)
  final diveBuddies = await repository.getBuddiesForDive('dive1');
  expect(diveBuddies.length, 1);
  expect(diveBuddies.first.buddy.id, buddyA.id);
  expect(diveBuddies.first.role, BuddyRole.instructor);

  // Snapshot should capture the modified entry (original role was buddy)
  expect(result!.snapshot!.modifiedDiveBuddyEntries.length, 1);
  expect(result.snapshot!.modifiedDiveBuddyEntries.first.role, 'buddy');
});
```

- [ ] **Step 2: Write test for 3+ buddy merge with multi-way collision**

```dart
test('merges 3 buddies with overlapping dives', () async {
  final buddyA = await repository.createBuddy(domain.Buddy(
    id: '', name: 'A', notes: '',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final buddyB = await repository.createBuddy(domain.Buddy(
    id: '', name: 'B', notes: '',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final buddyC = await repository.createBuddy(domain.Buddy(
    id: '', name: 'C', notes: '',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));

  final now = DateTime.now().millisecondsSinceEpoch;
  await database.into(database.dives).insert(db.DivesCompanion.insert(
    id: 'dive1', diveDateTime: now, createdAt: now, updatedAt: now,
  ));

  await repository.addBuddyToDive('dive1', buddyA.id, BuddyRole.buddy);
  await repository.addBuddyToDive('dive1', buddyB.id, BuddyRole.diveMaster);
  await repository.addBuddyToDive('dive1', buddyC.id, BuddyRole.instructor);

  final result = await repository.mergeBuddies(
    mergedBuddy: buddyA.copyWith(name: 'A'),
    buddyIds: [buddyA.id, buddyB.id, buddyC.id],
  );

  final diveBuddies = await repository.getBuddiesForDive('dive1');
  expect(diveBuddies.length, 1);
  expect(diveBuddies.first.buddy.id, buddyA.id);
  expect(diveBuddies.first.role, BuddyRole.instructor); // highest rank
});
```

- [ ] **Step 3: Write test for buddy with zero dives**

```dart
test('merges buddy with no dives', () async {
  final buddyA = await repository.createBuddy(domain.Buddy(
    id: '', name: 'Alice', notes: '',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final buddyB = await repository.createBuddy(domain.Buddy(
    id: '', name: 'Bob', notes: '',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));

  final result = await repository.mergeBuddies(
    mergedBuddy: buddyA.copyWith(name: 'Alice'),
    buddyIds: [buddyA.id, buddyB.id],
  );

  expect(result, isNotNull);
  expect(result!.survivorId, buddyA.id);
  expect(await repository.getBuddyById(buddyB.id), isNull);
});
```

- [ ] **Step 4: Run all tests**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_test.dart`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add test/features/buddies/data/repositories/buddy_merge_test.dart
git commit -m "test(buddies): add role collision and edge case merge tests"
```

---

### Task 3: Add `undoMerge()` to BuddyRepository

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart`
- Modify: `test/features/buddies/data/repositories/buddy_merge_test.dart`

- [ ] **Step 1: Write failing test for undo**

```dart
test('undoMerge restores all buddies and junction entries', () async {
  final buddyA = await repository.createBuddy(domain.Buddy(
    id: '', name: 'Alice', email: 'alice@test.com', notes: '',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));
  final buddyB = await repository.createBuddy(domain.Buddy(
    id: '', name: 'Bob', phone: '555-0100', notes: '',
    createdAt: DateTime.now(), updatedAt: DateTime.now(),
  ));

  final now = DateTime.now().millisecondsSinceEpoch;
  await database.into(database.dives).insert(db.DivesCompanion.insert(
    id: 'dive1', diveDateTime: now, createdAt: now, updatedAt: now,
  ));
  await database.into(database.dives).insert(db.DivesCompanion.insert(
    id: 'dive2', diveDateTime: now, createdAt: now, updatedAt: now,
  ));

  await repository.addBuddyToDive('dive1', buddyA.id, BuddyRole.buddy);
  await repository.addBuddyToDive('dive1', buddyB.id, BuddyRole.instructor);
  await repository.addBuddyToDive('dive2', buddyB.id, BuddyRole.buddy);

  final result = await repository.mergeBuddies(
    mergedBuddy: buddyA.copyWith(name: 'Alice', phone: '555-0100'),
    buddyIds: [buddyA.id, buddyB.id],
  );

  // Undo
  await repository.undoMerge(result!.snapshot!);

  // Both buddies should exist again
  final restoredA = await repository.getBuddyById(buddyA.id);
  final restoredB = await repository.getBuddyById(buddyB.id);
  expect(restoredA, isNotNull);
  expect(restoredB, isNotNull);
  expect(restoredA!.name, 'Alice');
  expect(restoredA.email, 'alice@test.com');

  // Original dive assignments should be restored
  final dive1Buddies = await repository.getBuddiesForDive('dive1');
  expect(dive1Buddies.length, 2);

  final dive2Buddies = await repository.getBuddiesForDive('dive2');
  expect(dive2Buddies.length, 1);
  expect(dive2Buddies.first.buddy.id, buddyB.id);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_test.dart --name "undoMerge"`
Expected: FAIL - `undoMerge` not found

- [ ] **Step 3: Implement `undoMerge()`**

Add to `BuddyRepository`:

```dart
Future<void> undoMerge(BuddyMergeSnapshot snapshot) async {
  final now = DateTime.now().millisecondsSinceEpoch;

  try {
    _log.info('Undoing buddy merge: restoring ${snapshot.deletedBuddies.length} buddies');

    await _db.transaction(() async {
      // 1. Restore survivor to original state
      await _updateBuddyRow(snapshot.originalSurvivor, now);
      await _syncRepository.markRecordPending(
        entityType: 'buddies',
        recordId: snapshot.originalSurvivor.id,
        localUpdatedAt: now,
      );

      // 2. Re-create deleted buddies
      for (final buddy in snapshot.deletedBuddies) {
        await _db.into(_db.buddies).insert(BuddiesCompanion(
          id: Value(buddy.id),
          diverId: Value(buddy.diverId),
          name: Value(buddy.name),
          email: Value(buddy.email),
          phone: Value(buddy.phone),
          certificationLevel: Value(buddy.certificationLevel?.name),
          certificationAgency: Value(buddy.certificationAgency?.name),
          photoPath: Value(buddy.photoPath),
          notes: Value(buddy.notes),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
        await _syncRepository.markRecordPending(
          entityType: 'buddies', recordId: buddy.id, localUpdatedAt: now,
        );
      }

      // 3. Restore deleted DiveBuddies entries
      for (final entry in snapshot.deletedDiveBuddyEntries) {
        await _db.into(_db.diveBuddies).insert(DiveBuddiesCompanion(
          id: Value(entry.id),
          diveId: Value(entry.diveId),
          buddyId: Value(entry.buddyId),
          role: Value(entry.role),
          createdAt: Value(now),
        ));
        await _syncRepository.markRecordPending(
          entityType: 'diveBuddies', recordId: entry.id, localUpdatedAt: now,
        );
      }

      // 4. Restore modified DiveBuddies entries (revert role changes)
      for (final entry in snapshot.modifiedDiveBuddyEntries) {
        await (_db.update(_db.diveBuddies)
          ..where((t) => t.id.equals(entry.id))
        ).write(DiveBuddiesCompanion(role: Value(entry.role)));
        await _syncRepository.markRecordPending(
          entityType: 'diveBuddies', recordId: entry.id, localUpdatedAt: now,
        );
      }
    });

    SyncEventBus.notifyLocalChange();
    _log.info('Undo buddy merge complete');
  } catch (e, stackTrace) {
    _log.error('Failed to undo buddy merge', e, stackTrace);
    rethrow;
  }
}
```

Also add the helper `_updateBuddyRow()` (includes `diverId` to support undo restoring the original diver association):
```dart
Future<void> _updateBuddyRow(domain.Buddy buddy, int now) async {
  await (_db.update(_db.buddies)..where((t) => t.id.equals(buddy.id))).write(
    BuddiesCompanion(
      diverId: Value(buddy.diverId),
      name: Value(buddy.name),
      email: Value(buddy.email),
      phone: Value(buddy.phone),
      certificationLevel: Value(buddy.certificationLevel?.name),
      certificationAgency: Value(buddy.certificationAgency?.name),
      photoPath: Value(buddy.photoPath),
      notes: Value(buddy.notes),
      updatedAt: Value(now),
    ),
  );
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_test.dart`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/data/repositories/buddy_repository.dart test/features/buddies/data/repositories/buddy_merge_test.dart
git commit -m "feat(buddies): add undoMerge() with junction restoration"
```

---

### Task 4: Add `bulkDeleteBuddies()` to BuddyRepository

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart`
- Modify: `test/features/buddies/data/repositories/buddy_merge_test.dart`

- [ ] **Step 1: Write failing test**

```dart
group('bulkDeleteBuddies', () {
  test('deletes multiple buddies', () async {
    final buddyA = await repository.createBuddy(domain.Buddy(
      id: '', name: 'A', notes: '',
      createdAt: DateTime.now(), updatedAt: DateTime.now(),
    ));
    final buddyB = await repository.createBuddy(domain.Buddy(
      id: '', name: 'B', notes: '',
      createdAt: DateTime.now(), updatedAt: DateTime.now(),
    ));

    await repository.bulkDeleteBuddies([buddyA.id, buddyB.id]);

    expect(await repository.getBuddyById(buddyA.id), isNull);
    expect(await repository.getBuddyById(buddyB.id), isNull);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_test.dart --name "bulkDeleteBuddies"`
Expected: FAIL

- [ ] **Step 3: Implement `bulkDeleteBuddies()`**

Add to `BuddyRepository`, mirroring `site_repository_impl.dart:171-188`:

```dart
Future<void> bulkDeleteBuddies(List<String> ids) async {
  if (ids.isEmpty) return;
  try {
    _log.info('Bulk deleting ${ids.length} buddies');
    await (_db.delete(_db.buddies)..where((t) => t.id.isIn(ids))).go();
    for (final id in ids) {
      await _syncRepository.logDeletion(entityType: 'buddies', recordId: id);
    }
    SyncEventBus.notifyLocalChange();
    _log.info('Bulk deleted ${ids.length} buddies');
  } catch (e, stackTrace) {
    _log.error('Failed to bulk delete buddies', e, stackTrace);
    rethrow;
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/buddies/data/repositories/buddy_merge_test.dart`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/data/repositories/buddy_repository.dart test/features/buddies/data/repositories/buddy_merge_test.dart
git commit -m "feat(buddies): add bulkDeleteBuddies()"
```

---

### Task 5: Add provider support for merge/undo/bulkDelete

**Files:**
- Modify: `lib/features/buddies/presentation/providers/buddy_providers.dart`

- [ ] **Step 1: Add `mergeBuddies()` and `undoMerge()` to `BuddyListNotifier`**

Add these methods to the `BuddyListNotifier` class in `buddy_providers.dart`, after the existing `deleteBuddy()` method at line 252:

```dart
Future<BuddyMergeSnapshot?> mergeBuddies(
  Buddy mergedBuddy,
  List<String> buddyIds,
) async {
  if (buddyIds.length < 2) return null;

  final dedupedIds = buddyIds.toSet().toList(growable: false);
  final survivorId = dedupedIds.first;

  final result = await _repository.mergeBuddies(
    mergedBuddy: mergedBuddy.copyWith(id: survivorId),
    buddyIds: dedupedIds,
  );

  await refresh();
  _invalidateMergeProviders(dedupedIds);

  return result?.snapshot;
}

Future<void> undoMerge(BuddyMergeSnapshot snapshot) async {
  await _repository.undoMerge(snapshot);
  final affectedIds = [
    snapshot.originalSurvivor.id,
    ...snapshot.deletedBuddies.map((b) => b.id),
  ];
  _invalidateMergeProviders(affectedIds);
  await refresh();
}

Future<void> bulkDeleteBuddies(List<String> ids) async {
  await _repository.bulkDeleteBuddies(ids);
  for (final id in ids) {
    _ref.invalidate(buddyByIdProvider(id));
  }
  _ref.invalidate(allBuddiesWithDiveCountProvider);
  await refresh();
}

void _invalidateMergeProviders(List<String> buddyIds) async {
  _ref.invalidate(allBuddiesProvider);
  _ref.invalidate(allBuddiesWithDiveCountProvider);
  for (final id in buddyIds) {
    _ref.invalidate(buddyByIdProvider(id));
    _ref.invalidate(buddyStatsProvider(id));
    // Invalidate dive-buddy associations: get affected dive IDs and invalidate
    final diveIds = await _repository.getDiveIdsForBuddy(id);
    for (final diveId in diveIds) {
      _ref.invalidate(buddiesForDiveProvider(diveId));
    }
    _ref.invalidate(diveIdsForBuddyProvider(id));
    _ref.invalidate(divesForBuddyProvider(id));
  }
}
```

Also add the necessary import at the top of the file:

```dart
import 'package:submersion/features/buddies/domain/entities/buddy.dart' as domain;
```

Note: The file already imports `buddy.dart` without alias (line 11). The `domain` alias is only needed for the `mergeBuddies` method parameter type since it uses the domain `Buddy` class. Check if a naming conflict exists -- if not, the existing import suffices. The `BuddyMergeResult` and `BuddyMergeSnapshot` come from the repository import which is already present.

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/features/buddies/presentation/providers/buddy_providers.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/features/buddies/presentation/providers/buddy_providers.dart
git commit -m "feat(buddies): add merge/undo/bulkDelete to BuddyListNotifier"
```

---

### Task 6: Add localization keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`

- [ ] **Step 1: Add l10n keys to English ARB**

Add these entries to `lib/l10n/arb/app_en.arb`. Place them near the existing `buddies_` keys. Follow the exact pattern from `diveSites_list_selection_*` and `diveSites_edit_merge_*` keys (lines 2823-2951 of app_en.arb):

```json
"buddies_list_selection_closeTooltip": "Close Selection",
"buddies_list_selection_count": "{count} selected",
"@buddies_list_selection_count": {
  "placeholders": {
    "count": {"type": "int"}
  }
},
"buddies_list_selection_selectAllTooltip": "Select All",
"buddies_list_selection_deselectAllTooltip": "Deselect All",
"buddies_list_selection_mergeTooltip": "Merge Selected",
"buddies_list_selection_deleteTooltip": "Delete Selected",
"buddies_list_merge_snackbar": "Merged {count} {count, plural, =1{buddy} other{buddies}}",
"@buddies_list_merge_snackbar": {
  "placeholders": {
    "count": {"type": "int"}
  }
},
"buddies_list_merge_undo": "Undo",
"buddies_list_merge_restored": "Merge undone",
"buddies_list_bulkDelete_title": "Delete Buddies",
"buddies_list_bulkDelete_content": "Are you sure you want to delete {count} {count, plural, =1{buddy} other{buddies}}? This action cannot be undone.",
"@buddies_list_bulkDelete_content": {
  "placeholders": {
    "count": {"type": "int"}
  }
},
"buddies_list_bulkDelete_cancel": "Cancel",
"buddies_list_bulkDelete_confirm": "Delete",
"buddies_list_bulkDelete_snackbar": "Deleted {count} {count, plural, =1{buddy} other{buddies}}",
"@buddies_list_bulkDelete_snackbar": {
  "placeholders": {
    "count": {"type": "int"}
  }
},
"buddies_edit_merge_title": "Merge Buddies",
"buddies_edit_merge_fieldSourceCycleTooltip": "Use value from next selected buddy",
"buddies_edit_merge_fieldSourceLabel": "From {buddyName} ({current}/{total})",
"@buddies_edit_merge_fieldSourceLabel": {
  "placeholders": {
    "buddyName": {"type": "String"},
    "current": {"type": "int"},
    "total": {"type": "int"}
  }
},
"buddies_edit_merge_confirmTitle": "Merge Buddies",
"buddies_edit_merge_confirmBody": "This will merge {count} buddies into one. Dive associations will be combined under the surviving buddy. The other buddies will be deleted.",
"@buddies_edit_merge_confirmBody": {
  "placeholders": {
    "count": {"type": "int"}
  }
},
"buddies_edit_merge_loadingErrorTitle": "Merge Buddies",
"buddies_edit_merge_loadingErrorBody": "Failed to load buddies: {error}",
"@buddies_edit_merge_loadingErrorBody": {
  "placeholders": {
    "error": {"type": "String"}
  }
},
"buddies_edit_merge_notEnoughTitle": "Merge Buddies",
"buddies_edit_merge_notEnoughBody": "Not enough buddies to merge."
```

- [ ] **Step 2: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Successful generation of l10n Dart files

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/arb/app_en.arb lib/l10n/generated/
git commit -m "feat(l10n): add buddy merge and selection mode localization keys"
```

---

### Task 7: Add `mergeBuddyIds` parameter stub, create BuddyMergePage, and add route

**Files:**

- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart` (parameter only)
- Create: `lib/features/buddies/presentation/pages/buddy_merge_page.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Add `mergeBuddyIds` parameter to BuddyEditPage (stub only)**

In `lib/features/buddies/presentation/pages/buddy_edit_page.dart`, add to the widget class:

- `final List<String>? mergeBuddyIds;` field
- Add to constructor: `this.mergeBuddyIds,`
- Add assert: `assert(buddyId == null || mergeBuddyIds == null, 'buddyId and mergeBuddyIds are mutually exclusive')`
- Add getter: `bool get isMerging => mergeBuddyIds != null && mergeBuddyIds!.length > 1;`

This is a stub so BuddyMergePage and the route can compile. The full merge logic is added in Task 8.

- [ ] **Step 2: Create BuddyMergePage**

```dart
// lib/features/buddies/presentation/pages/buddy_merge_page.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';

class BuddyMergePage extends StatelessWidget {
  final List<String> buddyIds;

  const BuddyMergePage({super.key, required this.buddyIds});

  @override
  Widget build(BuildContext context) {
    return BuddyEditPage(mergeBuddyIds: buddyIds);
  }
}
```

- [ ] **Step 3: Add route to app_router.dart**

In `lib/core/router/app_router.dart`, add the import at the top:

```dart
import 'package:submersion/features/buddies/presentation/pages/buddy_merge_page.dart';
```

Add the merge route inside the `/buddies` route's `routes:` list (after the `new` route at line 401, before the `:buddyId` route at line 413):

```dart
GoRoute(
  path: 'merge',
  name: 'mergeBuddy',
  builder: (context, state) {
    final buddyIds =
        (state.extra as List<dynamic>?)?.cast<String>() ??
        const <String>[];
    return BuddyMergePage(buddyIds: buddyIds);
  },
),
```

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze lib/core/router/app_router.dart lib/features/buddies/presentation/pages/buddy_merge_page.dart lib/features/buddies/presentation/pages/buddy_edit_page.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/presentation/pages/buddy_edit_page.dart lib/features/buddies/presentation/pages/buddy_merge_page.dart lib/core/router/app_router.dart
git commit -m "feat(buddies): add mergeBuddyIds stub, BuddyMergePage wrapper, and /buddies/merge route"
```

---

### Task 8: Add merge mode to BuddyEditPage

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_edit_page.dart`

This is the largest task. It adds the `isMerging` flag, merge data loading, per-field cycling UI, and the merge save path. Follow the exact pattern from `site_edit_page.dart`.

- [ ] **Step 1: Add merge state fields to `_BuddyEditPageState`**

The `mergeBuddyIds` parameter and `isMerging` getter were already added in Task 7. Now add merge state fields to `_BuddyEditPageState`:
```dart
late final Future<_MergeLoadData>? _mergeLoadFuture;
final Map<String, List<_MergeFieldCandidate<String>>> _mergeTextCandidates = {};
final Map<String, int> _mergeFieldIndices = {};
List<_MergeFieldCandidate<CertificationLevel?>> _certLevelCandidates = [];
List<_MergeFieldCandidate<CertificationAgency?>> _certAgencyCandidates = [];
List<_MergeFieldCandidate<String?>> _photoCandidates = [];
String? _mergedPhotoPath;
```

- [ ] **Step 2: Add private helper classes at the bottom of the file**

```dart
class _MergeLoadData {
  final List<domain.Buddy> buddies;
  const _MergeLoadData({required this.buddies});
}

class _MergeFieldCandidate<T> {
  final String buddyId;
  final String buddyName;
  final T value;
  const _MergeFieldCandidate({
    required this.buddyId,
    required this.buddyName,
    required this.value,
  });
}
```

Note: Import the buddy entity with alias if not already done:
```dart
import 'package:submersion/features/buddies/domain/entities/buddy.dart' as domain;
```

- [ ] **Step 3: Implement merge data loading and field initialization**

Add `_loadMergeData()`, `_initializeMergeTextField()`, `_buildDistinctCandidates()`, `_firstMeaningfulIndex()` methods, following `site_edit_page.dart:778-860` exactly but adapted for buddy fields.

In `initState()`, add `_mergeLoadFuture = widget.isMerging ? _loadMergeData() : null;` and wrap the body in a `FutureBuilder` when `isMerging` to load the merge data before showing the form.

The `_loadMergeData()` method:
- Fetches all buddies by ID using `repository.getBuddyById()` for each
- Orders by selection order
- Calls `_initializeMergeTextField()` for each text field (name, email, phone, notes)
- Builds distinct candidates for cert level, cert agency, and photo path

- [ ] **Step 4: Add merge cycling UI helpers**

Add `_buildMergeCycleButton()`, `_withMergeTextDecoration()`, `_cycleTextField()`, `_selectTextFieldCandidate()` methods, following `site_edit_page.dart:862-940`.

Add `_cycleCertLevel()`, `_cycleCertAgency()`, `_cyclePhoto()` methods for enum/photo cycling.

- [ ] **Step 5: Update the form fields to show merge cycling when `isMerging`**

For each text field (name, email, phone, notes), wrap the `InputDecoration` with `_withMergeTextDecoration()` when `isMerging`.

For cert level and cert agency dropdowns, add the cycle button and source label when `isMerging` and multiple candidates exist (follow `site_edit_page.dart:1027-1177` pattern).

For the photo section, when `isMerging` and multiple photo candidates exist, show thumbnail previews with the cycle button.

- [ ] **Step 6: Update title and save logic for merge mode**

Update the AppBar/embedded header title:
```dart
widget.isMerging
    ? context.l10n.buddies_edit_merge_title
    : isEditing
        ? context.l10n.buddies_title_edit
        : context.l10n.buddies_title_add
```

Update `_saveBuddy()` to handle the merge path. Add `_confirmMerge()` dialog:
```dart
Future<bool> _confirmMerge() async {
  final count = widget.mergeBuddyIds?.length ?? 0;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.buddies_edit_merge_confirmTitle),
      content: Text(context.l10n.buddies_edit_merge_confirmBody(count)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.l10n.buddies_edit_merge_title),
        ),
      ],
    ),
  );
  return confirmed == true;
}
```

In `_saveBuddy()`, add the merge branch (before the existing `isEditing` branch):
```dart
if (widget.isMerging) {
  final confirmed = await _confirmMerge();
  if (!confirmed) return;

  final mergeSnapshot = await ref
      .read(buddyListNotifierProvider.notifier)
      .mergeBuddies(buddy, widget.mergeBuddyIds!);
  final savedId = widget.mergeBuddyIds!.first;

  if (mounted) {
    context.pop(BuddyMergeResult(
      survivorId: savedId,
      snapshot: mergeSnapshot,
    ));
  }
  return;
}
```

Add import for `BuddyMergeResult`:
```dart
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
```

- [ ] **Step 7: Verify compilation**

Run: `flutter analyze lib/features/buddies/presentation/pages/buddy_edit_page.dart`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add lib/features/buddies/presentation/pages/buddy_edit_page.dart
git commit -m "feat(buddies): add merge mode to BuddyEditPage with per-field cycling"
```

---

### Task 9: Add selection mode to BuddyListContent

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart`

Follow `site_list_content.dart:64-643` pattern exactly.

- [ ] **Step 1: Add selection state fields**

Add to `_BuddyListContentState`:
```dart
bool _isSelectionMode = false;
final Set<String> _selectedIds = {};
BuddyMergeSnapshot? _mergeSnapshot;
```

Add import:
```dart
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
```

- [ ] **Step 2: Add selection helper methods**

Add `_enterSelectionMode()`, `_exitSelectionMode()`, `_toggleSelection()`, `_selectAll()`, `_deselectAll()` methods. Follow `site_list_content.dart:157-197`.

- [ ] **Step 3: Add `_startMerge()` method**

```dart
Future<void> _startMerge() async {
  final selectedCount = _selectedIds.length;
  final result = await context.push<BuddyMergeResult>(
    '/buddies/merge',
    extra: _selectedIds.toList(),
  );

  if (!mounted || result == null) return;

  _mergeSnapshot = result.snapshot;
  final mergedId = result.survivorId;
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  setState(() {
    _isSelectionMode = false;
    _selectedIds.clear();
  });

  if (widget.onItemSelected != null) {
    _selectionFromList = true;
    widget.onItemSelected!(mergedId);
  }

  if (_mergeSnapshot != null && mounted) {
    scaffoldMessenger.clearSnackBars();
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.buddies_list_merge_snackbar(selectedCount)),
        duration: const Duration(seconds: 5),
        showCloseIcon: true,
        action: SnackBarAction(
          label: context.l10n.buddies_list_merge_undo,
          onPressed: () async {
            if (_mergeSnapshot != null) {
              await ref
                  .read(buddyListNotifierProvider.notifier)
                  .undoMerge(_mergeSnapshot!);
              _mergeSnapshot = null;
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.buddies_list_merge_restored),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add `_confirmAndDelete()` method**

Follow `site_list_content.dart:256-326` pattern, adapted for buddies:

```dart
Future<void> _confirmAndDelete() async {
  final count = _selectedIds.length;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.buddies_list_bulkDelete_title),
      content: Text(context.l10n.buddies_list_bulkDelete_content(count)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.buddies_list_bulkDelete_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(context.l10n.buddies_list_bulkDelete_confirm),
        ),
      ],
    ),
  );

  if (confirmed == true && mounted) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final idsToDelete = _selectedIds.toList();
    _exitSelectionMode();

    await ref
        .read(buddyListNotifierProvider.notifier)
        .bulkDeleteBuddies(idsToDelete);

    if (mounted) {
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.buddies_list_bulkDelete_snackbar(idsToDelete.length)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
```

- [ ] **Step 5: Add selection app bar builders**

Add `_buildCompactSelectionAppBar()` and `_buildSelectionAppBar()` methods following `site_list_content.dart:549-643`:

```dart
Widget _buildCompactSelectionAppBar(
  BuildContext context,
  List<BuddyWithDiveCount> buddies,
) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
    ),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close, size: 20),
          tooltip: context.l10n.buddies_list_selection_closeTooltip,
          onPressed: _exitSelectionMode,
        ),
        Text(
          context.l10n.buddies_list_selection_count(_selectedIds.length),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.select_all, size: 20),
          tooltip: context.l10n.buddies_list_selection_selectAllTooltip,
          onPressed: _selectedIds.length < buddies.length
              ? () => _selectAll(buddies)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.deselect, size: 20),
          tooltip: context.l10n.buddies_list_selection_deselectAllTooltip,
          onPressed: _selectedIds.isNotEmpty ? _deselectAll : null,
        ),
        IconButton(
          icon: const Icon(Icons.merge_type, size: 20),
          tooltip: context.l10n.buddies_list_selection_mergeTooltip,
          onPressed: _selectedIds.length > 1 ? _startMerge : null,
        ),
        IconButton(
          icon: Icon(
            Icons.delete, size: 20,
            color: Theme.of(context).colorScheme.error,
          ),
          tooltip: context.l10n.buddies_list_selection_deleteTooltip,
          onPressed: _selectedIds.isNotEmpty ? _confirmAndDelete : null,
        ),
      ],
    ),
  );
}
```

- [ ] **Step 6: Wire up selection mode in the build method**

Update `_handleItemTap()` to check `_isSelectionMode` first (like `site_list_content.dart:132-136`).

Add long-press handler to `DenseBuddyListTile` (or wrap it) to enter selection mode.

Update the `build()` method to swap between normal app bar and selection app bar when `_isSelectionMode` is true.

Add checkboxes to list tiles when in selection mode.

- [ ] **Step 7: Verify compilation**

Run: `flutter analyze lib/features/buddies/presentation/widgets/buddy_list_content.dart`
Expected: No errors

- [ ] **Step 8: Commit**

```bash
git add lib/features/buddies/presentation/widgets/buddy_list_content.dart
git commit -m "feat(buddies): add selection mode with merge and bulk delete to buddy list"
```

---

### Task 10: Run full test suite and format

**Files:**
- All modified files

- [ ] **Step 1: Format all code**

Run: `dart format lib/ test/`

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Run full test suite**

Run: `flutter test`
Expected: ALL PASS

- [ ] **Step 4: Fix any issues found**

Address any failing tests or analyzer warnings.

- [ ] **Step 5: Final commit if any formatting/fix changes**

```bash
git add -A
git commit -m "chore: format and fix buddy merge implementation"
```
