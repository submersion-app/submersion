# Bulk membership editing (tri-state) + gear bug fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the confusing Add/Remove/Replace mode-chip UI for bulk-editing id-based reference collections (Tags, Dive Types, Buddies, Equipment) with a safe tri-state membership list, and fix the "Save as Set" diver-scoping bug.

**Architecture:** All new logic is presentation-layer plus one read query per collection. A reusable `BulkMembershipEditor` renders tri-state rows; a pure `MembershipDelta.from(...)` converts the user's choices into `(addIds, removeIds)`; `_collectCollectionOps` emits existing `AddOp`/`RemoveOp`. The service, sealed op types, `bulkAdd*`/`bulkRemove*`/`bulkReplace*` repo writes, and the undo snapshot are untouched.

**Tech Stack:** Flutter (Material 3), Drift (SQLite), Riverpod, flutter_test.

## Global Constraints

- Engine is frozen: do NOT modify `BulkDiveEditService`, the sealed `BulkCollectionOp` types, `bulkAddEquipment/Tags/DiveTypes/Buddies`, `bulkRemove*`, `bulkReplace*`, or the undo snapshot.
- Owned collections (Tanks, Weights, Sightings) keep their current editors — do not touch them.
- New user-facing strings: add to `lib/l10n/arb/app_en.arb`, then translate into all 10 non-en locales (`ar, de, es, fr, he, hu, it, nl, pt, zh`), then run `flutter gen-l10n`.
- `dart format .` must be clean and `flutter analyze` must pass over the whole project before the final commit.
- Run specific test files (not whole directories) to avoid runner timeouts.
- Buddies bulk-add uses default role `BuddyRole.buddy`; existing buddies' roles are never modified.
- Work in the worktree at `.claude/worktrees/gear-multi-dive-edit`. Commit per task.

---

### Task 1: Bug 1 regression tests — bulk equipment "add" merges, never wipes

Characterization/regression guard. Behavior is already correct on `main` (commit `30da9f93835`); these tests lock it in. They are expected to PASS immediately.

**Files:**
- Modify: `test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
- Modify: `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`

- [ ] **Step 1: Add repo-level test** inside the existing `group('bulk equipment', ...)`:

```dart
test('bulkAddEquipment merges with pre-existing gear, never wipes', () async {
  // d1 already has e1; d2 already has e2.
  await repository.bulkAddEquipment(['d1'], ['e1']);
  await repository.bulkAddEquipment(['d2'], ['e2']);

  // Bulk-add e3 to BOTH dives.
  await repository.bulkAddEquipment(['d1', 'd2'], ['e3']);

  final d1 = await (db.select(db.diveEquipment)
        ..where((t) => t.diveId.equals('d1'))).get();
  final d2 = await (db.select(db.diveEquipment)
        ..where((t) => t.diveId.equals('d2'))).get();
  expect(d1.map((r) => r.equipmentId).toSet(), {'e1', 'e3'}); // e1 survived
  expect(d2.map((r) => r.equipmentId).toSet(), {'e2', 'e3'}); // e2 survived
});
```

- [ ] **Step 2: Add service-level test** (mirrors the reporter's exact flow) after the existing `apply handles add and remove modes` test:

```dart
test('EquipmentOp add preserves existing gear on each dive', () async {
  await seed('d1');
  await diveRepo.bulkAddEquipment(['d1'], ['origEq']);

  await service.apply(
    BulkEditRequest(
      diveIds: const ['d1'],
      ops: [
        const EquipmentOp(mode: BulkCollectionMode.add, equipmentIds: ['newEq']),
      ],
    ),
  );

  expect((await equipOf('d1')).toSet(), {'origEq', 'newEq'});
});
```

- [ ] **Step 3: Run and verify PASS**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`
Expected: All tests pass. (If either fails, STOP — the engine regressed.)

- [ ] **Step 4: Commit**

```bash
git add test/features/dive_log/data/repositories/dive_repository_bulk_test.dart test/features/dive_log/data/services/bulk_dive_edit_service_test.dart
git commit -m "test(dive-log): lock in bulk equipment add-merges-not-wipes behavior"
```

---

### Task 2: Bug 2 fix — "Save as Set" stamps the active diver (failing-first)

**Files:**
- Create: `test/features/dive_log/presentation/pages/dive_edit_save_as_set_test.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_saveEquipmentAsSet`, ~line 2845)

**Interfaces:**
- Consumes: `equipmentSetListNotifierProvider` (from `lib/features/equipment/presentation/providers/equipment_set_providers.dart`), whose `.notifier.addSet(EquipmentSet)` stamps the validated diver id and refreshes.

- [ ] **Step 1: Write the failing widget test.** Seed a diver, seed an equipment item + a dive that references it, override `currentDiverIdProvider` to that diver, pump `DiveEditPage(diveId: 'd1')`, tap "Save as Set", type a name, tap Save, then assert the set is visible under that diver.

```dart
// Setup mirrors bulk_dive_edit_form_test.dart: setUpTestDatabase(), getBaseOverrides().
// Seed a diver row (db.into(db.divers).insert(...)) with id 'diver-1'.
// Create an equipment item via EquipmentRepository().createEquipment(...) -> id 'eq-1'.
// Create dive 'd1' with equipment:[that item] via DiveRepository().createDive(...).
// Override currentDiverIdProvider so state == 'diver-1' (see note below).

testWidgets('saving gear as a set makes it visible to the current diver',
    (tester) async {
  await pumpEditPage(tester, diveId: 'd1'); // helper defined in the test
  await tester.tap(find.text('Save as Set'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Tropical');
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  final sets = await EquipmentSetRepository().getAllSets(diverId: 'diver-1');
  expect(sets.map((s) => s.name), contains('Tropical'));
});
```

Note on the diver override: `getBaseOverrides()` uses `MockCurrentDiverIdNotifier()` which starts null. Add an override that seeds the id, e.g. call `container` isn't available in `testWidgets`; instead override `validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1')` in the ProviderScope so both the read path and the save path resolve `diver-1`. Import it from `lib/features/divers/presentation/providers/diver_providers.dart`.

- [ ] **Step 2: Run to verify it FAILS**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_save_as_set_test.dart`
Expected: FAIL — `getAllSets(diverId: 'diver-1')` is empty because the set was written with `diverId = null`.

- [ ] **Step 3: Apply the fix.** In `_saveEquipmentAsSet`, replace the direct repository call:

```dart
// BEFORE (~2845-2849):
final repository = ref.read(equipmentSetRepositoryProvider);
await repository.createSet(set);
ref.invalidate(equipmentSetsProvider);

// AFTER:
await ref.read(equipmentSetListNotifierProvider.notifier).addSet(set);
```

`addSet` stamps the validated diver id via `copyWith(diverId: ...)` and calls `refresh()` (which invalidates `equipmentSetsProvider`), so the manual invalidate is no longer needed. Leave the `EquipmentSet(...)` construction as-is; `addSet` supplies the diverId.

- [ ] **Step 4: Run to verify it PASSES**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_save_as_set_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_save_as_set_test.dart
git commit -m "fix(dive-log): save-as-set stamps active diver so the set is visible (#gear)"
```

---

### Task 3: Count queries — how many selected dives have each item

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add 3 methods near the bulk methods, ~line 4000)
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart` (add 1 method)
- Modify: `test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`

**Interfaces:**
- Produces:
  - `DiveRepository.equipmentCountsForDives(List<String> diveIds) -> Future<Map<String,int>>`
  - `DiveRepository.tagCountsForDives(List<String> diveIds) -> Future<Map<String,int>>`
  - `DiveRepository.diveTypeCountsForDives(List<String> diveIds) -> Future<Map<String,int>>`
  - `BuddyRepository.buddyCountsForDives(List<String> diveIds) -> Future<Map<String,int>>`
  - Each returns `{itemId: numberOfSelectedDivesThatHaveIt}`. Junctions have a composite PK on `(diveId, itemId)`, so a plain `COUNT(diveId)` grouped by itemId equals the distinct-dive count.

- [ ] **Step 1: Write the failing repo test** in `dive_repository_bulk_test.dart`:

```dart
test('equipmentCountsForDives returns per-item dive counts', () async {
  await repository.bulkAddEquipment(['d1', 'd2'], ['shared']); // on both
  await repository.bulkAddEquipment(['d1'], ['onlyD1']);       // on one
  final counts = await repository.equipmentCountsForDives(['d1', 'd2']);
  expect(counts['shared'], 2);
  expect(counts['onlyD1'], 1);
  expect(counts.containsKey('missing'), isFalse);
  expect(await repository.equipmentCountsForDives(const []), isEmpty);
});
```

- [ ] **Step 2: Run to verify it FAILS**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: FAIL — method not defined.

- [ ] **Step 3: Implement `equipmentCountsForDives`** in `dive_repository_impl.dart`:

```dart
/// {equipmentId: number of the given dives that reference it}.
Future<Map<String, int>> equipmentCountsForDives(List<String> diveIds) async {
  if (diveIds.isEmpty) return {};
  final j = _db.diveEquipment;
  final countExpr = j.diveId.count();
  final rows = await (_db.selectOnly(j)
        ..addColumns([j.equipmentId, countExpr])
        ..where(j.diveId.isIn(diveIds))
        ..groupBy([j.equipmentId]))
      .get();
  return {
    for (final r in rows) r.read(j.equipmentId)!: r.read(countExpr)!,
  };
}
```

- [ ] **Step 4: Implement the other three** by mirroring Step 3 with the right table/column:
  - `tagCountsForDives`: table `_db.diveTags`, column `tagId`.
  - `diveTypeCountsForDives`: table `_db.diveDiveTypes`, column `diveTypeId`.
  - `buddyCountsForDives` (in `buddy_repository.dart`): the dive-buddy junction used by `getBuddiesForDive` (grep that method for the table/column names), grouping by the buddy-id column.

Add analogous tests for tags, dive types, and buddies (mirror Step 1; seed via `bulkAddTags` / `bulkAddDiveTypes` / `bulkAddBuddies`).

- [ ] **Step 5: Run to verify PASS**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/buddies/data/repositories/buddy_repository.dart test/features/dive_log/data/repositories/dive_repository_bulk_test.dart
git commit -m "feat(dive-log): per-item membership count queries for bulk edit"
```

---

### Task 4: `MembershipDelta` + view-model (pure logic)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/bulk_membership_editor.dart` (types only for now)
- Create: `test/features/dive_log/presentation/widgets/bulk_membership_delta_test.dart`

**Interfaces:**
- Produces: `MembershipPresence { all, some, none }`, `MembershipChoice { ensureOn, ensureOff, leaveAsIs }`, `BulkMembershipItem { String id; String label; IconData? icon }`, and `MembershipDelta { List<String> addIds; List<String> removeIds; static MembershipDelta from(Map<String,MembershipPresence> initial, Map<String,MembershipChoice> choices) }`.

- [ ] **Step 1: Write failing tests**:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_membership_editor.dart';

void main() {
  test('ensureOn on a "some" item adds it (to the dives missing it)', () {
    final d = MembershipDelta.from(
      {'a': MembershipPresence.some},
      {'a': MembershipChoice.ensureOn},
    );
    expect(d.addIds, ['a']);
    expect(d.removeIds, isEmpty);
  });

  test('ensureOn on an "all" item is a no-op', () {
    final d = MembershipDelta.from(
      {'a': MembershipPresence.all},
      {'a': MembershipChoice.ensureOn},
    );
    expect(d.addIds, isEmpty);
    expect(d.removeIds, isEmpty);
  });

  test('ensureOff on "all" or "some" removes; on "none" is a no-op', () {
    final d = MembershipDelta.from(
      {'a': MembershipPresence.all, 'b': MembershipPresence.some, 'c': MembershipPresence.none},
      {'a': MembershipChoice.ensureOff, 'b': MembershipChoice.ensureOff, 'c': MembershipChoice.ensureOff},
    );
    expect(d.removeIds.toSet(), {'a', 'b'});
    expect(d.addIds, isEmpty);
  });

  test('leaveAsIs never changes anything', () {
    final d = MembershipDelta.from(
      {'a': MembershipPresence.some},
      {'a': MembershipChoice.leaveAsIs},
    );
    expect(d.addIds, isEmpty);
    expect(d.removeIds, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify FAIL** — `flutter test test/features/dive_log/presentation/widgets/bulk_membership_delta_test.dart` → FAIL (types undefined).

- [ ] **Step 3: Implement the types** in `bulk_membership_editor.dart`:

```dart
import 'package:flutter/widgets.dart';

enum MembershipPresence { all, some, none }
enum MembershipChoice { ensureOn, ensureOff, leaveAsIs }

class BulkMembershipItem {
  final String id;
  final String label;
  final IconData? icon;
  const BulkMembershipItem({required this.id, required this.label, this.icon});
}

class MembershipDelta {
  final List<String> addIds;
  final List<String> removeIds;
  const MembershipDelta(this.addIds, this.removeIds);

  static MembershipDelta from(
    Map<String, MembershipPresence> initial,
    Map<String, MembershipChoice> choices,
  ) {
    final add = <String>[];
    final remove = <String>[];
    for (final entry in choices.entries) {
      final presence = initial[entry.key] ?? MembershipPresence.none;
      switch (entry.value) {
        case MembershipChoice.ensureOn:
          if (presence != MembershipPresence.all) add.add(entry.key);
        case MembershipChoice.ensureOff:
          if (presence != MembershipPresence.none) remove.add(entry.key);
        case MembershipChoice.leaveAsIs:
          break;
      }
    }
    return MembershipDelta(add, remove);
  }
}
```

- [ ] **Step 4: Run to verify PASS**, then **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/bulk_membership_editor.dart test/features/dive_log/presentation/widgets/bulk_membership_delta_test.dart
git commit -m "feat(dive-log): tri-state membership delta logic for bulk edit"
```

---

### Task 5: l10n strings for the membership editor

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` + the 10 non-en arb files
- Run: `flutter gen-l10n`

- [ ] **Step 1: Add keys to `app_en.arb`** (with descriptions):

```json
"diveLog_bulkEdit_membership_onAll": "on all {count}",
"@diveLog_bulkEdit_membership_onAll": { "placeholders": { "count": { "type": "int" } } },
"diveLog_bulkEdit_membership_onSome": "on {count} of {total}",
"@diveLog_bulkEdit_membership_onSome": { "placeholders": { "count": { "type": "int" }, "total": { "type": "int" } } },
"diveLog_bulkEdit_membership_adding": "adding to all {total}",
"@diveLog_bulkEdit_membership_adding": { "placeholders": { "total": { "type": "int" } } },
"diveLog_bulkEdit_membership_removing": "removing from all",
"@diveLog_bulkEdit_membership_removing": {},
"diveLog_bulkEdit_membership_empty": "No items on the selected dives yet",
"@diveLog_bulkEdit_membership_empty": {}
```

- [ ] **Step 2: Translate into all 10 non-en locales** (`ar, de, es, fr, he, hu, it, nl, pt, zh`), keeping the placeholders identical. (Follow the existing translation convention in each file.)

- [ ] **Step 3: Regenerate + verify**

Run: `flutter gen-l10n && flutter analyze lib/l10n`
Expected: generation succeeds; the new getters exist on `AppLocalizations`.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb
git commit -m "i18n(dive-log): strings for bulk membership editor"
```

---

### Task 6: `BulkMembershipEditor` widget

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/bulk_membership_editor.dart`
- Create: `test/features/dive_log/presentation/widgets/bulk_membership_editor_test.dart`

**Interfaces:**
- Produces a `StatefulWidget`:
```dart
BulkMembershipEditor({
  required String title,
  required int totalDives,
  required List<BulkMembershipItem> items,      // items on >=1 dive, plus user-added
  required Map<String, MembershipPresence> presence, // per-item initial presence
  required VoidCallback onAdd,                   // opens the collection's picker
  Widget? addLabel,                              // e.g. "Use set" secondary action slot
  required ValueChanged<MembershipDelta> onChanged,
})
```
- Behavior: holds `Map<String, MembershipChoice> _choices`, initialized from `presence` (all->ensureOn, some->leaveAsIs, none->ensureOn). Renders one row per item with a tri-state control and a subtitle from the l10n keys (Task 5) based on presence + current choice. Tapping cycles: presence.all/none -> ensureOn<->ensureOff; presence.some -> leaveAsIs->ensureOn->ensureOff->leaveAsIs. After any change, calls `onChanged(MembershipDelta.from(presence, _choices))`. Rendering mirrors the row/`ListTile` style in `dive_edit_page.dart`'s `_equipmentChild` (leading CircleAvatar with `item.icon`, title `item.label`).

- [ ] **Step 1: Write widget tests**:

```dart
// Pump a MaterialApp with AppLocalizations delegates (see bulk_dive_edit_form_test.dart).
// Provide 3 items: a(all), b(some), c(none/just-added). totalDives: 3.

testWidgets('renders presence subtitles', (tester) async {
  MembershipDelta? last;
  await pumpEditor(tester, onChanged: (d) => last = d);
  expect(find.text('on all 3'), findsOneWidget);       // a
  expect(find.text('on 2 of 3'), findsOneWidget);      // b (seed count 2)
  // c starts checked -> "adding to all 3"
  expect(find.text('adding to all 3'), findsOneWidget);
});

testWidgets('unchecking an all-item yields a remove', (tester) async {
  MembershipDelta? last;
  await pumpEditor(tester, onChanged: (d) => last = d);
  await tester.tap(find.byKey(const ValueKey('membership-toggle-a')));
  await tester.pump();
  expect(last!.removeIds, contains('a'));
});

testWidgets('a some-item defaults to no change', (tester) async {
  MembershipDelta? last;
  await pumpEditor(tester, onChanged: (d) => last = d);
  // c is added(checked) by default -> add; a is all -> no-op; b is some -> leaveAsIs.
  expect(last?.addIds ?? const [], isNot(contains('b')));
  expect(last?.removeIds ?? const [], isNot(contains('b')));
});
```

Give each toggle a `ValueKey('membership-toggle-<id>')` in the widget so tests can target it.

- [ ] **Step 2: Run to verify FAIL**, then **Step 3: Implement the widget** per the Interfaces block, then **Step 4: Run to verify PASS**.

Run: `flutter test test/features/dive_log/presentation/widgets/bulk_membership_editor_test.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/bulk_membership_editor.dart test/features/dive_log/presentation/widgets/bulk_membership_editor_test.dart
git commit -m "feat(dive-log): tri-state BulkMembershipEditor widget"
```

---

### Task 7: Wire Equipment into the bulk form (+ hide Save as Set in bulk)

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`

**Interfaces:**
- Consumes: `equipmentCountsForDives` (Task 3), `BulkMembershipEditor` + `MembershipDelta` (Tasks 4/6).

- [ ] **Step 1:** Add bulk state: `MembershipDelta _equipmentDelta = const MembershipDelta([], [])`, a `Map<String, MembershipPresence> _equipmentPresence = {}`, and the loaded `List<BulkMembershipItem>`. In the bulk init path (`if (widget.isBulk)` around line 293/655), load `equipmentCountsForDives(bulkDiveIds!)`, resolve each id to an `EquipmentItem` (via the existing equipment fetch-by-ids), and classify presence (count==total -> all, else some). Store into state.

- [ ] **Step 2:** In `_buildBulkCollectionsSection`, replace the equipment `_collectionEntry(...)` with a `BulkMembershipEditor` bound to the equipment state; its `onAdd` opens the existing `_showEquipmentPicker` (added items -> presence.none, choice ensureOn); its secondary action is "Use set" (`_showEquipmentSetPicker`). Its `onChanged` sets `_equipmentDelta`.

- [ ] **Step 3:** In `_collectCollectionOps`, replace the equipment block with:

```dart
if (_equipmentDelta.addIds.isNotEmpty) {
  ops.add(EquipmentOp(mode: BulkCollectionMode.add, equipmentIds: _equipmentDelta.addIds));
}
if (_equipmentDelta.removeIds.isNotEmpty) {
  ops.add(EquipmentOp(mode: BulkCollectionMode.remove, equipmentIds: _equipmentDelta.removeIds));
}
```

- [ ] **Step 4:** In `_equipmentChild` (single-dive editor), guard the "Save as Set" button with `if (!widget.isBulk)` so it does not render in bulk mode.

- [ ] **Step 5:** Update `bulk_dive_edit_form_test.dart`: the `BulkCollectionModeSelector` count drops from 7 to 6 (equipment no longer uses it); add an assertion that a `BulkMembershipEditor` renders. Then add a flow test: seed d1 with e1, d2 empty; pump bulk; the editor shows e1 as "on 1 of 2"; add e2 via the picker; save; assert d1 == {e1, e2} and d2 == {e2} (existing gear preserved, no wipe).

- [ ] **Step 6: Run** `flutter test test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart` → PASS. **Step 7: Commit.**

```bash
git commit -am "feat(dive-log): tri-state bulk gear editing; hide save-as-set in bulk"
```

---

### Task 8: Wire Tags, Dive Types, and Buddies into the bulk form

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Modify: `test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`

- [ ] **Step 1:** Repeat Task 7's pattern for each collection, reusing the same state/wiring shape:
  - **Tags:** counts via `tagCountsForDives`; labels from `Tag.name`; `onAdd` uses the existing tag input; emit `TagsOp(add/remove)`.
  - **Dive types:** counts via `diveTypeCountsForDives`; labels from `diveTypesProvider` (`DiveTypeEntity` id->name); `onAdd` uses the existing dive-type multiselect; emit `DiveTypesOp(add/remove)`.
  - **Buddies:** counts via `buddyCountsForDives`; labels from `Buddy.name`; `onAdd` uses the existing `BuddyPicker`; for the AddOp build `BuddyWithRole(buddy: <buddy>, role: BuddyRole.buddy)`; for the RemoveOp pass `BuddyWithRole` entries whose `.buddy.id` are the removeIds. Emit `BuddiesOp(add/remove)`.

- [ ] **Step 2:** Remove the now-unused `_collectionModes` handling for these four reference collections and their `_collectionEntry` blocks. Keep `_collectionEntry` + `_collectionModes` for the owned collections (tanks/weights/sightings).

- [ ] **Step 3:** Update `bulk_dive_edit_form_test.dart`: `BulkCollectionModeSelector` now renders only for the 3 owned collections (findsNWidgets(3)); assert 4 `BulkMembershipEditor` widgets render.

- [ ] **Step 4: Run** the bulk form test → PASS. **Step 5: Commit.**

```bash
git commit -am "feat(dive-log): tri-state bulk editing for tags, dive types, buddies"
```

---

### Task 9: Service test — Add + Remove ops for one collection in a single request

**Files:**
- Modify: `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`

- [ ] **Step 1: Write the test** (proves the tri-state decomposition applies correctly and undo restores):

```dart
test('apply handles simultaneous add + remove ops for one collection', () async {
  await seed('d1');
  await diveRepo.bulkAddEquipment(['d1'], ['keep', 'drop']);

  final snap = await service.apply(
    BulkEditRequest(
      diveIds: const ['d1'],
      ops: [
        const EquipmentOp(mode: BulkCollectionMode.add, equipmentIds: ['added']),
        const EquipmentOp(mode: BulkCollectionMode.remove, equipmentIds: ['drop']),
      ],
    ),
  );
  expect((await equipOf('d1')).toSet(), {'keep', 'added'});

  await service.undo(snap);
  expect((await equipOf('d1')).toSet(), {'keep', 'drop'}); // restored
});
```

- [ ] **Step 2: Run to verify PASS** (engine already supports this) — `flutter test test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`. **Step 3: Commit.**

```bash
git commit -am "test(dive-log): bulk apply handles add+remove for one collection with undo"
```

---

### Task 10: Final verification

- [ ] **Step 1:** `dart format .`
- [ ] **Step 2:** `flutter analyze` (whole project) — zero issues.
- [ ] **Step 3:** Run the affected suites:

```bash
flutter test \
  test/features/dive_log/data/repositories/dive_repository_bulk_test.dart \
  test/features/dive_log/data/services/bulk_dive_edit_service_test.dart \
  test/features/dive_log/domain/entities/bulk_edit_request_test.dart \
  test/features/dive_log/presentation/widgets/bulk_membership_delta_test.dart \
  test/features/dive_log/presentation/widgets/bulk_membership_editor_test.dart \
  test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart \
  test/features/dive_log/presentation/pages/dive_edit_save_as_set_test.dart
```

- [ ] **Step 4:** Commit any formatting; summarize outcome for the user.

## Self-review notes

- Spec coverage: interaction model (Tasks 4/6), architecture/op-gen (Tasks 7/8), 4 count queries (Task 3), per-collection wrinkles incl. buddy default role (Task 8), Bug 2 fix (Task 2), Bug 1 regression (Task 1), undo (Task 9), l10n (Task 5). All covered.
- Type consistency: `MembershipDelta.from`, `BulkMembershipItem`, `MembershipPresence`, `MembershipChoice` used identically in Tasks 4/6/7/8. Count methods return `Map<String,int>` consumed identically.
- Owned collections untouched; engine untouched.
