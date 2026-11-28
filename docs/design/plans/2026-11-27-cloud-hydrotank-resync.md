# Hydrotank role on resync of Cloud dives: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** "Resync from original file" gives a Shearwater Cloud Avelo dive imported before #4662 its Hydrotank role.

**Architecture:** The re-parse rule "stored back gas, no role source, parse says Hydrotank" becomes one pure function in the dive-log domain. `ReparseService` and `DiveReimportService._carryOverTanks` both call it. Resync also writes the file's role on a cylinder it inserts.

**Tech Stack:** Dart, Drift, flutter_test.

**Spec:** `docs/design/specs/2026-11-27-cloud-hydrotank-resync-design.md`

## Global Constraints

- Only a stored back gas with a null `role_source` changes, and only to `hydrotank`. Every other stored role stays.
- No UI, l10n or schema change.
- Run only the test files this plan names, by path. The pre-push hook runs the rest.

## Review Focus

- The file names a role as a `TankRole` value rather than a string (parsers differ): a new cylinder still takes it.
- A transmitter the diver set up for the Hydrotank's serial: the post-resync transmitter fill must not turn the Hydrotank back (it fills only back-gas rows), so the Hydrotank stays.
- A stored back gas whose role was read off the transmitter name (`role_source = transmitterName`) is not upgraded by this rule.
- A file role this build does not know, on a new cylinder: the row keeps the back-gas default.
- A file without a Hydrotank leaves a stored back gas as back gas.

---

### Task 1: Shared Hydrotank upgrade rule

**Files:**
- Create: `lib/features/dive_log/domain/services/hydrotank_role_upgrade.dart`
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (the `hydrotanks` set and the third clause of `roleIsComputers`, near line 1176)
- Test: `test/features/dive_log/domain/services/hydrotank_role_upgrade_test.dart`

**Interfaces:**
- Produces: `bool upgradesToHydrotank({required String? storedRole, required String? storedRoleSource, required String? parsedRole})`: true when `storedRoleSource == null`, `storedRole == TankRole.backGas.name` and `parsedRole == TankRole.hydrotank.name`.

- [ ] **Step 1: Write the failing test** with cases: back gas + null source + hydrotank is true; pony + hydrotank is false; back gas + `transmitterName` source + hydrotank is false; back gas + null source + backGas is false; hydrotank + hydrotank is false; null parsed role is false.
- [ ] **Step 2: Run it:** `flutter test test/features/dive_log/domain/services/hydrotank_role_upgrade_test.dart`. Expected: compile failure, the function does not exist.
- [ ] **Step 3: Implement** the function. In `ReparseService`, replace the `hydrotanks` index set with a map of parsed index to role from `resolvedTanks`, and the third clause with `upgradesToHydrotank(storedRole: existing.tankRole, storedRoleSource: existing.roleSource, parsedRole: <role at index>)`. Move the existing comment onto the function.
- [ ] **Step 4: Run** the new test and `test/features/dive_computer/data/services/reparse_service_test.dart`. Expected: all pass, including the group "DiveTanks carry-over: the Avelo Hydrotank (#4657)".
- [ ] **Step 5: Commit** `refactor(dive-computer): share the Hydrotank upgrade rule`.

### Task 2: Resync applies the rule and the file's role on new cylinders

**Files:**
- Modify: `lib/features/dive_import/data/services/dive_reimport_service.dart` (`_carryOverTanks`)
- Test: `test/features/dive_import/data/services/dive_reimport_hydrotank_test.dart` (new; same setup as `dive_reimport_transmitter_serial_test.dart`)

**Interfaces:**
- Consumes: `upgradesToHydrotank` from Task 1.
- The file's role is `t['role']`, either a `String` or a `TankRole`; read it as a name, and treat a name `TankRole` does not know as none.

- [ ] **Step 1: Write the failing tests**, each seeding one cylinder at order 0 and resyncing `{'order': 0, 'startPressure': 200.0, 'role': ...}`:
  - `a stored back gas the file tags as the Hydrotank becomes one`: seeded `backGas`, file `'hydrotank'`; expect `tankRole == 'hydrotank'`, `roleSource` null.
  - `another stored role stays`: seeded `pony`, file `'hydrotank'`; expect `'pony'`.
  - `a name-derived back gas is left to its own rule`: seeded `backGas` with `roleSource: 'transmitterName'`, file `'hydrotank'`; expect `'backGas'`.
  - `a file without a Hydrotank changes nothing`: seeded `backGas`, file `'backGas'` and a second run with no `role` key; expect `'backGas'`.
  - `a cylinder the file gained takes the file's role`: resync with a second tank at order 1, role `TankRole.hydrotank` (the enum); expect the new row's role `'hydrotank'`.
  - `a cylinder the file gained with an unknown role is back gas`: role `'futureRole'`; expect `'backGas'`.
  - `a transmitter the diver set up does not undo the Hydrotank`: a configured `Transmitter` with serial `'76287'` and role `TankRole.sidemountLeft`; seeded `backGas`; file `{'order': 0, 'startPressure': 200.0, 'transmitterSerial': '76287', 'role': 'hydrotank'}`; expect `'hydrotank'`.
- [ ] **Step 2: Run** `flutter test test/features/dive_import/data/services/dive_reimport_hydrotank_test.dart`. Expected: the upgrade and new-row tests fail; the "stays" and "changes nothing" tests pass.
- [ ] **Step 3: Implement.** On a matched row, add `tankRole: Value('hydrotank')` to the existing companion when `upgradesToHydrotank` holds, else `Value.absent()`. On an inserted row, write `tankRole` when the file's role is a known `TankRole` name.
- [ ] **Step 4: Run** the new test file, `dive_reimport_service_test.dart` and `dive_reimport_transmitter_serial_test.dart`. Expected: all pass.
- [ ] **Step 5:** `dart format .` and `flutter analyze`. Expected: no issues.
- [ ] **Step 6: Commit** `feat(dive-import): resync gives a Cloud Avelo dive its Hydrotank role`.
