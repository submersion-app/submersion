# Bulk Tank Roles by Position Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Edit Selected, Tanks, Update set a different role per tank position (tank 1 Sidemount left, tank 2 Sidemount right) across every selected dive whose tank count matches.

**Architecture:** `TankSpecsOp` gains an optional ordered `slotRoles` list. A pure domain function maps one dive's tanks (sorted by `tankOrder`) to roles, or returns null on a mismatch. `bulkUpdateTankSpecs` writes the other ticked fields to every tank as today and the role per row from that map. The existing in-place write and its by-id undo snapshot are reused unchanged.

**Tech Stack:** Flutter, Riverpod, Drift, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-11-16-bulk-tank-roles-by-position-design.md`

## Global Constraints

- Exact match only: a dive gets roles only when its tank count equals `slotRoles.length`.
- Two tanks on one dive sharing a `tankOrder` make the dive a mismatch.
- Writing a role clears `role_source` (existing `_tankSpecsCompanion` behaviour).
- Other ticked fields still apply to every tank of every dive with tanks, matching or not.
- "Role by tank position" starts with `[TankRole.sidemountLeft, TankRole.sidemountRight]`; minimum one position.
- New strings go into all 23 ARB files under `lib/l10n/arb/`; no em-dashes in any string or comment.

## Review Focus

- A dive with three tanks (sidemount pair plus an argon bottle) keeps all three roles untouched. Test in Task 2.
- A dive whose two tanks share `tankOrder` 0 keeps its roles. Test in Task 1 and Task 2.
- Role by position plus Volume ticked: a mismatched dive still gets the volume. Test in Task 2.
- Undo after a per-position update restores each tank's prior role and `role_source`. Test in Task 2 (service).
- Switching back to "Same role on every tank", or unticking Role, sends no `slotRoles`. Test in Task 4.

---

### Task 1: Position-to-role mapping

**Files:**
- Create: `lib/features/dive_log/domain/bulk_edit/tank_slot_roles.dart`
- Test: `test/features/dive_log/domain/bulk_edit/tank_slot_roles_test.dart`

**Interfaces:**
- Produces: `Map<String, TankRole>? slotRolesForDive(List<({String id, int order})> tanks, List<TankRole> slotRoles)`: tank id to role, or null when `slotRoles` is empty, the counts differ, or two tanks share an order.

- [ ] **Step 1: Write the failing tests** `assigns roles by ascending order regardless of list order` (tanks `[(id:'b',order:1),(id:'a',order:0)]`, roles `[sidemountLeft, sidemountRight]` gives `{'a': sidemountLeft, 'b': sidemountRight}`), `returns null when counts differ` (3 tanks, 2 roles; 1 tank, 2 roles), `returns null when two tanks share an order`, `returns null for no roles`.
- [ ] **Step 2: Run** `flutter test test/features/dive_log/domain/bulk_edit/tank_slot_roles_test.dart`; expect a compile failure.
- [ ] **Step 3: Implement** `slotRolesForDive`, sorting a copy (never mutating the input).
- [ ] **Step 4: Run the test again**; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): map tank positions to roles for bulk edit`.

### Task 2: Write roles by position

**Files:**
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_request.dart` (`TankSpecsOp`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (`bulkUpdateTankSpecs`, new `divesWithSlotRoleMismatchCount` beside `divesWithoutTanksCount`)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` (`_applyOp`, the `TankSpecsOp` arm)
- Test: `test/features/dive_log/data/repositories/dive_repository_bulk_test.dart`, `test/features/dive_log/data/services/bulk_dive_edit_service_test.dart`

**Interfaces:**
- Consumes: `slotRolesForDive` (Task 1).
- Produces:
  - `TankSpecsOp({required DiveTank specs, required Set<TankSpecField> fields, List<TankRole>? slotRoles})`, with `final List<TankRole>? slotRoles`. Read only when `fields` contains `TankSpecField.role`.
  - `Future<int> bulkUpdateTankSpecs(List<String> diveIds, DiveTank specs, Set<TankSpecField> fields, {List<TankRole>? slotRoles})`: with `slotRoles`, the companion is built from `fields` minus role, and each row in a matching dive also gets `tankRole` and `roleSource: null`. A row that ends up with an empty companion is not written or marked pending. Returns the number of dives that had a row written.
  - `Future<int> divesWithSlotRoleMismatchCount(List<String> diveIds, List<TankRole> slotRoles)`: dives with at least one tank for which `slotRolesForDive` is null. Dives with no tanks are not counted (the existing no-tanks line reports them).

- [ ] **Step 1: Write failing repository tests** in a new group `bulkUpdateTankSpecs slotRoles`: two-tank dive gets left then right and keeps pressures; three-tank dive keeps all roles; shared-`tankOrder` dive keeps roles (set with a direct `db.update` of `tankOrder`); role-only edit returns 1 for a mixed selection of one matching and one three-tank dive; role by position plus `TankSpecField.volume` writes the volume on the three-tank dive too; a role-source-tagged tank has `roleSource` null after. Group `divesWithSlotRoleMismatchCount`: counts the three-tank dive, not the matching one, not a tankless one; empty ids give 0.
- [ ] **Step 2: Write the failing service test** in group `TankSpecsOp`: `undo restores roles set by position`. Seed two tanks with roles `stage` and `deco`, apply with `slotRoles: [sidemountLeft, sidemountRight]`, undo, expect `stage` and `deco` back.
- [ ] **Step 3: Run** both files; expect failures (unknown named parameter).
- [ ] **Step 4: Implement** the op field, the repository changes, and pass `slotRoles` through in the service. Group the one existing SELECT by dive id; keep it one query.
- [ ] **Step 5: Run both files again**; expect PASS, including every pre-existing test.
- [ ] **Step 6: Commit** `feat(dive-log): set tank roles by position in bulk update`.

### Task 3: Editor UI and strings

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart` (new `showRole` flag, default true; false hides the role dropdown and lets the preset picker take the row)
- Modify: `lib/features/dive_log/presentation/widgets/bulk_tank_specs_editor.dart`
- Create: `lib/features/dive_log/presentation/widgets/bulk_tank_slot_roles_editor.dart`
- Modify: all 23 `lib/l10n/arb/app_*.arb`
- Test: `test/features/dive_log/presentation/widgets/bulk_tank_specs_editor_test.dart`

**Interfaces:**
- Produces:
  - `BulkTankSpecsEditor` gains `required List<TankRole>? slotRoles` and `required ValueChanged<List<TankRole>?> onSlotRolesChanged`. Null means "Same role on every tank".
  - `BulkTankSlotRolesEditor({required List<TankRole> roles, required ValueChanged<List<TankRole>> onChanged})`: one row per position, label `diveLog_tank_title(i + 1)`, a `DropdownButtonFormField<TankRole>` of `TankRoleOption` keyed `bulk-tank-slot-role-$i`, a remove `IconButton` keyed `bulk-tank-slot-remove-$i` (disabled with one row), and an add `TextButton.icon` keyed `bulk-tank-slot-add` that appends `TankRole.backGas`. Below the rows, the hint string.
- Strings (English; translate for each locale):
  - `diveLog_bulkEdit_tankRoleSameForAll`: "Same role on every tank"
  - `diveLog_bulkEdit_tankRoleByPosition`: "Role by tank position"
  - `diveLog_bulkEdit_tankRoleAddPosition`: "Add position"
  - `diveLog_bulkEdit_tankRoleRemovePosition`: "Remove position"
  - `diveLog_bulkEdit_tankRolesByPositionHint` (plural on `count`): "Only dives with exactly 1 tank get this role." / "Only dives with exactly {count} tanks get these roles, in tank order."
  - `diveLog_bulkEdit_tankRolesSkipped` (plural on `count`): "1 dive has a different number of tanks than the positions set, so its tank roles stay as they are." / "{count} dives have a different number of tanks than the positions set, so their tank roles stay as they are."

- [ ] **Step 1: Write failing widget tests:** the Same/By position `SegmentedButton<bool>` appears only when Role is ticked; choosing By position calls `onSlotRolesChanged([sidemountLeft, sidemountRight])` and hides the `TankEditor` role dropdown (`find.byKey(ValueKey('tank-role-...'))` absent); add appends `backGas`; remove is disabled at one row; changing row 2 to `deco` reports `[sidemountLeft, deco]`; choosing Same reports null.
- [ ] **Step 2: Run** the editor test file; expect failures.
- [ ] **Step 3: Add the ARB strings** (English with `@` metadata for the plurals, translations in every other file), then run `flutter gen-l10n`.
- [ ] **Step 4: Implement** `showRole`, `BulkTankSlotRolesEditor`, and the toggle in `BulkTankSpecsEditor`. The template card passes `showRole: slotRoles == null || !fields.contains(TankSpecField.role)`.
- [ ] **Step 5: Run** the editor test file plus `test/features/dive_log/presentation/widgets/tank_editor_test.dart` if present; expect PASS.
- [ ] **Step 6: Commit** `feat(dive-log): role by tank position editor in bulk tank update`.

### Task 4: Wire into the bulk form

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_bulkTankSpecs` state near line 1493, `_bulkTanksEditor`, op building near line 2307, confirm dialog near line 2714)
- Test: `test/features/dive_log/presentation/pages/bulk_dive_edit_form_test.dart`

**Interfaces:**
- Consumes: `TankSpecsOp.slotRoles` and `divesWithSlotRoleMismatchCount` (Task 2), `BulkTankSpecsEditor.slotRoles` (Task 3).

- [ ] **Step 1: Write failing form tests:** `tank Update sets roles by position` (two dives: one with two tanks, one with three; tick Role, choose Role by tank position, Save; the dialog shows the `tankRolesSkipped` text for 1 dive; Apply; the two-tank dive reads left/right and the three-tank dive keeps its roles) and `switching back to Same role writes the template role` (tick Role, By position, then Same, pick Stage in the template, Save, Apply; both tanks are Stage).
- [ ] **Step 2: Run** the form test file filtered with `--plain-name "roles by position"`, then the second test; expect failures.
- [ ] **Step 3: Implement:** state `List<TankRole>? _bulkTankSlotRoles`, passed to the editor with `_markDirty()` on change; the op sends `slotRoles` only when `_bulkTankSpecFields` contains role; before the dialog, compute the mismatch count when the op has `slotRoles`; the dialog shows its line beside the existing skipped line, and the dialog body appears when either count is above zero or changes exist.
- [ ] **Step 4: Run** the form test file, the editor test file, `test/features/dive_log/data/`, and `test/architecture/`; expect PASS.
- [ ] **Step 5: Run** `dart format .` and `flutter analyze`; expect no issues.
- [ ] **Step 6: Commit** `feat(dive-log): bulk edit sets tank roles by position`.
