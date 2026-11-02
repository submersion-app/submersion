# Gas Switch Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the diver add, change and remove gas switches on the dive edit page, with re-parse and file resync leaving an edited list alone and re-parse keeping hand-added cylinders.

**Architecture:** A `gas_switches_edited` flag on the dive row marks a list the diver owns; a new `DiverGasSwitchWriter` diffs the editor's list against the stored rows in one transaction and sets the flag. Re-parse and resync read the flag before touching switches, and re-parse stops deleting cylinders with no source index. The editor is a self-contained widget under the cylinders in the gas and gear group, fed by the page's state like the tank rows.

**Tech Stack:** Flutter, Riverpod, Drift (schema v333), flutter_test, build_runner codegen, ARB localisation.

**Spec:** `docs/design/specs/2026-11-01-gas-switch-editing-design.md`

## Global Constraints

- No em-dashes anywhere; no emojis; no mention of any AI tool in code, commits or the PR.
- Immutable state: copy, never mutate, lists and entities.
- Units through `UnitFormatter` (`convertDepth`, `depthToMeters`, `depthSymbol`); storage is metres.
- Paths with `p.join`; temp space via `Directory.systemTemp`.
- A test that replaces process-wide state restores it in `addTearDown`.
- Files stay under 800 lines; `before_open.dart` and `dive_migrations.dart` (749 lines) are near the cap.
- New ARB keys go in every locale: `app_en, app_ar, app_de, app_es, app_fr, app_he, app_hu, app_it, app_nl, app_pt, app_zh`, anchored on a neighbouring `diveLog_edit_` key (every ARB is feature-grouped). A plural uses `one{...}` with `{count}`, never a hard-coded digit.
- Schema version 333. Draft PR #4028 also claims 333; the beforeOpen backstop re-asserts the column, so whichever merges second renumbers. Re-check `origin/main` before the first push.
- Run `dart format .`, `flutter analyze`, the touched tests, `test/architecture/` and `test/shared/` before every commit that adds a file under `lib/`.
- TDD: each task writes its failing test first.

## Review Focus

1. A switch at exactly the runtime is valid and one second later is not (Task 8 tests both edges).
2. A depth typed in feet is stored in metres, and an emptied depth stores null (Task 8 and Task 9).
3. A dive logged by two computers: a save never touches the other computer's switches (Task 3 test).
4. A re-parse of an edited dive whose switch names a cylinder the unused-gas cleanup would drop keeps that cylinder (Task 5 test).
5. An untouched list saves nothing and never sets the flag, so a dive the diver only looked at keeps today's re-parse behaviour (Task 3 and Task 9 tests).

---

### Task 1: Schema v333, `dives.gas_switches_edited`

**Files:**
- Modify: `lib/core/database/tables/dive_tables.dart` (class `Dives`, after `excludedFromGasStats`)
- Modify: `lib/core/database/migrations/helpers/dive_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart:736-739`
- Modify: `lib/core/database/migrations/before_open_child_columns.dart:45-48`
- Modify: `lib/core/database/database.dart:312` and the `migrationVersions` list at `:460`
- Create: `test/core/database/migration_v333_dive_gas_switches_edited_test.dart`

**Interfaces:**
- Produces: Drift column `Dives.gasSwitchesEdited` (`BoolColumn`, default false), generated `Dive.gasSwitchesEdited` getter and `DivesCompanion.gasSwitchesEdited`.

- [ ] **Step 1: Write the failing test**, modelled line for line on `test/core/database/migration_v330_buddy_excluded_from_rankings_test.dart`:

```dart
test('v333 is in the migration ladder', () {
  expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(333));
  expect(AppDatabase.migrationVersions, contains(333));
});
test('a fresh database has the column, NOT NULL with a false default', ...)
  // PRAGMA table_info('dives'): name 'gas_switches_edited', notnull 1, dflt_value '0'
test('an existing dive upgrades to unedited', ...)
  // user_version 330, a minimal dives table (id, dive_date_time, created_at, updated_at, notes),
  // one row; after open: SELECT gas_switches_edited = 0
```

- [ ] **Step 2: Run it**: `flutter test test/core/database/migration_v333_dive_gas_switches_edited_test.dart`. Expected: FAIL (no column, 333 not in ladder).

- [ ] **Step 3: Add the column** in `Dives`: `BoolColumn get gasSwitchesEdited => boolean().withDefault(const Constant(false))();` with a comment: v333, set once the diver saves a change to the dive's gas switches; re-parse and resync then leave the switch list alone (issue #32).

- [ ] **Step 4: Add the helper** in `dive_migrations.dart`, beside `_assertDiveTankSourceIdColumn`: `Future<void> _assertDiveGasSwitchesEditedColumn() => _addColumnIfMissing('dives', 'gas_switches_edited', 'INTEGER NOT NULL DEFAULT 0');`

- [ ] **Step 5: Add the rung** after v332 in `rungs_v231_onward.dart`: `if (from < 333) await _assertDiveGasSwitchesEditedColumn(); if (from < 333) await reportProgress();` with a v333 comment. Add the same call at the end of `_assertChildRowColumns` in `before_open_child_columns.dart` (every dive read selects the whole row).

- [ ] **Step 6: Bump** `currentSchemaVersion = 333` and append `333` to `migrationVersions`.

- [ ] **Step 7: Regenerate**: `dart run build_runner build --delete-conflicting-outputs`. Expected: `database.g.dart` gains `gasSwitchesEdited`.

- [ ] **Step 8: Run** the new test, `test/core/database/fresh_schema_declared_columns_test.dart`, `test/core/database/migration_v330_buddy_excluded_from_rankings_test.dart` and `test/core/services/sync/cross_version_roundtrip_test.dart`. Expected: PASS.

- [ ] **Step 9: Commit**: `feat(database): flag a dive whose gas switches the diver edited (v333)`

---

### Task 2: Domain helpers: depth at a time, starting cylinder

**Files:**
- Create: `lib/features/dive_log/domain/services/profile_depth_at.dart`
- Modify: `lib/features/dive_log/domain/services/tank_usage_range.dart:77-88`
- Create: `test/features/dive_log/domain/services/profile_depth_at_test.dart`
- Modify: `test/features/dive_log/domain/services/tank_usage_range_test.dart`

**Interfaces:**
- Produces: `double? profileDepthAt(List<DiveProfilePoint> profile, int timestamp)`: linear interpolation between the bracketing points; null for an empty profile or a time outside its span; exact at a sample.
- Produces: `DiveTank? startingTankOf({required List<DiveTank> tanks, required Iterable<GasSwitch> switches, required int diveStart})`: null for no tanks; otherwise the private `_startingTank` rule (a switch within `startingSwitchGraceSeconds` of `diveStart` names it, else `sacReferenceTankOf`). `_startingTank` delegates to it; switches naming an unknown tank are ignored.

- [ ] **Step 1: Write the failing tests**

```dart
// profile_depth_at_test.dart
test('empty profile is null', ...)                       // profileDepthAt(const [], 10) == null
test('a sample time returns that depth', ...)            // points (0,0),(60,10),(120,20): at 60 -> 10
test('between samples interpolates', ...)                // at 90 -> 15
test('outside the span is null', ...)                    // at 121 -> null, at -1 -> null
// tank_usage_range_test.dart, new group 'startingTankOf'
test('a switch in the first minute names the start', ...) // switch t=30 to deco -> deco
test('a later switch leaves the back gas', ...)           // switch t=600 to deco -> back gas
test('a switch to an unknown tank is ignored', ...)
test('no tanks is null', ...)
```

- [ ] **Step 2: Run them**: `flutter test test/features/dive_log/domain/services/profile_depth_at_test.dart test/features/dive_log/domain/services/tank_usage_range_test.dart`. Expected: FAIL (undefined).

- [ ] **Step 3: Implement** both functions. `startingTankOf` filters `switches` to known tank ids, sorts by timestamp, and applies the existing rule; `_startingTank` becomes a call to it.

- [ ] **Step 4: Run** the same command. Expected: PASS.

- [ ] **Step 5: Commit**: `feat(dive-log): depth at a profile time and the starting cylinder as public helpers`

---

### Task 3: `DiverGasSwitchWriter`

**Files:**
- Create: `lib/features/dive_log/data/services/diver_gas_switch_writer.dart`
- Create: `test/features/dive_log/data/services/diver_gas_switch_writer_test.dart`

**Interfaces:**
- Consumes: `SafetyFindingsRepository.clearReviewForDive(AppDatabase, SyncRepository, String diveId)`; `SyncRepository.markRecordPending`, `logDeletion`; `SyncEventBus.notifyLocalChange()`; `GasSwitch` entity.
- Produces:

```dart
class DiverGasSwitchWriter {
  DiverGasSwitchWriter({AppDatabase? db, SyncRepository? sync});
  // db defaults to DatabaseService.instance.database, sync to SyncRepository(),
  // as BulkTankUndoWriter does.

  /// Replaces the switches the editor showed with [switches]. [loadedIds] are
  /// the ids the editor loaded; an id in both is updated (timestamp, tankId,
  /// depth; computerId untouched), one only in [switches] is inserted with
  /// computerId null, one only in [loadedIds] is deleted and tombstoned.
  /// Switches the editor did not load (another computer's) are never touched.
  /// Returns false and writes nothing when nothing differs.
  Future<bool> save({
    required String diveId,
    required List<GasSwitch> switches,
    required Set<String> loadedIds,
    DateTime? now,
  });
}
```

When something differs, inside one `db.transaction`: the row writes, `markRecordPending('gasSwitches', id, localUpdatedAt: now)` per inserted or updated row, `logDeletion('gasSwitches', id)` per deleted row, then the dive: `updatedAt = now`, `gasSwitchesEdited = true`, `markRecordPending('dives', diveId, ...)`, then `clearReviewForDive`. After the transaction, `SyncEventBus.notifyLocalChange()`. An update with the same timestamp, tankId and depth as the stored row counts as unchanged.

- [ ] **Step 1: Write the failing tests** with `setUpTestDatabase`/`tearDownTestDatabase` (see `test/features/dive_import/data/services/dive_reimport_service_test.dart`), seeding a dive, two tanks, a computer `comp-1`, a stored switch `gs-1` (computerId `comp-1`, t=0, tank-a) and `gs-other` (computerId `comp-2`, t=0, tank-a):

```dart
test('an added switch is inserted without a computer', ...)
  // switches: [gs-1 unchanged, new id 'gs-new' t=900 tank-b depth 21.0], loadedIds {gs-1}
  // -> row gs-new: computerId null, depth 21.0; result true
test('an edited switch keeps its id and computer', ...)
  // gs-1 with t=30 -> row gs-1 timestamp 30, computerId 'comp-1', no tombstone
test('a dropped switch is deleted and tombstoned', ...)
  // switches [], loadedIds {gs-1} -> no gs-1 row; sync deletion log has gasSwitches/gs-1
test('the other computer\'s switch is never touched', ...)
  // every case above: gs-other still present and unchanged
test('a save marks the dive edited, bumps it and drops its review', ...)
  // seed a diveSafetyReviews row for the dive (SafetyFindingsRepository.saveReview, as
  // reparse_service_safety_review_test.dart does); after save: dives.gasSwitchesEdited true,
  // updatedAt == now, getReview(diveId) == null, sync pending has dives/diveId;
  // and with a second dive seeded a day later, DiveRepository().getResidualHistoryRevision
  // for that later dive differs before and after the save (the next dive's residual
  // loading re-derives from this one's new stamp)
test('an unchanged list writes nothing', ...)
  // switches == stored, loadedIds == their ids -> result false, gasSwitchesEdited false,
  // updatedAt unchanged, review still stored
```

- [ ] **Step 2: Run**: `flutter test test/features/dive_log/data/services/diver_gas_switch_writer_test.dart`. Expected: FAIL (class undefined).

- [ ] **Step 3: Implement** `DiverGasSwitchWriter.save` as specified.

- [ ] **Step 4: Run** the test. Expected: PASS.

- [ ] **Step 5: Commit**: `feat(dive-log): save the diver's gas switch edits in one transaction`

---

### Task 4: Re-parse leaves an edited switch list alone

**Files:**
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart:180-200` (read the dive row), `:283-295` (delete and tombstone), `:338-344` (`_insertGasSwitches`), `:375-378` (staging)
- Create: `test/features/dive_computer/data/services/reparse_service_gas_switch_edits_test.dart`

**Interfaces:**
- Consumes: `Dive.gasSwitchesEdited` from Task 1.
- Produces: a local `final rewritesSwitches = rewritesTanks && !diveRow.gasSwitchesEdited;` gating the three switch steps. `_tankSeries.deleteForDive` and everything else keep their current `rewritesTanks` gate.

- [ ] **Step 1: Write the failing tests**, copying the `insertDive`/`insertComputer`/`insertSource`/`makeParsedDive` helpers from `reparse_service_test.dart` (the file owns its helpers; copy, do not import), with one parsed tank at index 0 carrying a switch at t=0:

```dart
test('an edited dive keeps its switches through a re-parse', ...)
  // dives.gasSwitchesEdited true; stored 'gs-dc' (computerId comp-1, t=0, tank-0) and
  // 'gs-mine' (computerId null, t=900, tank-1); after applyParsedUpdate: both rows present
  // with the same timestamps; no gasSwitches tombstone; nothing staged for gasSwitches
test('an unedited dive still takes the computer\'s switches', ...)
  // gasSwitchesEdited false, same rows -> gs-mine gone, one switch at t=0 to tank-0
```

- [ ] **Step 2: Run**: `flutter test test/features/dive_computer/data/services/reparse_service_gas_switch_edits_test.dart`. Expected: the first FAILS (gs-mine deleted), the second PASSES.

- [ ] **Step 3: Implement**: read `final diveRow = await (db.select(db.dives)..where((t) => t.id.equals(diveId))).getSingle();` beside the `sourceRows` read; compute `rewritesSwitches`; gate the delete-and-tombstone, `_insertGasSwitches` and `stage('gasSwitches', ...)` on it, with a comment naming issue #32.

- [ ] **Step 4: Run** the new file plus `test/features/dive_computer/data/services/reparse_service_test.dart` and `reparse_service_sync_test.dart`. Expected: PASS.

- [ ] **Step 5: Commit**: `feat(dive-computer): re-parse leaves an edited gas switch list alone`

---

### Task 5: Re-parse keeps hand-added cylinders and the ones a switch names

**Files:**
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (`_carryOverTanks`: the keep set at `:1055-1063`, `dropUnusedOcGases` at `:1072-1074`, the deletion loop at `:1185-1194`)
- Modify: `test/features/dive_computer/data/services/reparse_service_test.dart:2452-2563`
- Modify: `test/features/dive_computer/data/services/reparse_service_unused_gas_test.dart`

**Interfaces:**
- Produces: `_carryOverTanks` gains `required Set<String> switchedTankIds` (the `tankId`s of the dive's stored `gas_switches`, read in `applyParsedUpdate` before the tank step). Indices whose matched row id is in it join the bailout claim's `keep` set and the `dropUnusedOcGases` `keep` set. In the deletion loop, an unmatched row with `sourceTankIndex == null` is skipped (kept).

- [ ] **Step 1: Flip the pinned test** in `reparse_service_test.dart`: tank-1 (no source index) is now kept, so `expect(tanks.length, 3)` and `tanks.map((t) => t.tankOrder)` is `[0, 1, 2]`, with a comment: a row with no source index is the diver's and a re-parse keeps it (issue #32). Add beside it:

```dart
test('a computer cylinder the parse no longer reports is still removed', ...)
  // same seed but tank-1 has sourceTankIndex: Value(1); parse reports 0 and 2 -> tank-1 gone
```

- [ ] **Step 2: Add to `reparse_service_unused_gas_test.dart`**, using its own fixture helpers:

```dart
test('a gas cylinder a stored switch names is kept', ...)
  // the unused Air row's id named by a gas_switches row (computerId null), dive
  // gasSwitchesEdited true, switch on -> the row survives and the switch still names it
```

- [ ] **Step 3: Run**: `flutter test test/features/dive_computer/data/services/reparse_service_test.dart test/features/dive_computer/data/services/reparse_service_unused_gas_test.dart`. Expected: the flipped test and both new tests FAIL.

- [ ] **Step 4: Implement** the three changes in `_carryOverTanks` and the `switchedTankIds` read in `applyParsedUpdate` (after Task 4's gating, so on an edited dive the rows are still there to read; on an unedited dive they were just deleted and the set is empty, which is today's behaviour).

- [ ] **Step 5: Run** the two files plus `reparse_service_series_test.dart`, `reparse_service_surfacing_test.dart`, `reparse_service_empty_parse_test.dart`. Expected: PASS.

- [ ] **Step 6: Commit**: `fix(dive-computer): re-parse keeps hand-added cylinders and the ones a switch names`

---

### Task 6: Resync leaves an edited switch list alone

**Files:**
- Modify: `lib/features/dive_import/data/services/dive_reimport_service.dart:534-545`
- Modify: `test/features/dive_import/data/services/dive_reimport_service_test.dart` (beside the test at `:267`)

- [ ] **Step 1: Write the failing test**

```dart
test('an edited switch list survives the resync (#32)', ...)
  // seedDive, then UPDATE dives SET gas_switches_edited = 1; seedTank tank-a; switch gs-old;
  // applyReimport with 'gasSwitches': [{timestamp: 0, tankIndex: 0}, {timestamp: 600, ...}]
  // -> exactly one switch, id 'gs-old'; no gasSwitches deletion logged
```

- [ ] **Step 2: Run**: `flutter test test/features/dive_import/data/services/dive_reimport_service_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement**: at the top of `_replaceGasSwitches`, read the dive row and `if (dive.gasSwitchesEdited) return;` with a comment.

- [ ] **Step 4: Run** the file. Expected: PASS.

- [ ] **Step 5: Commit**: `feat(dive-import): resync leaves an edited gas switch list alone`

---

### Task 7: Strings

**Files:**
- Modify: the eleven ARB files under `lib/l10n/arb/`, anchored after `diveLog_edit_addTank`'s group neighbours (`diveLog_edit_gasSwitches_*` sorts into the `diveLog_edit_` block).

**Interfaces:**
- Produces these keys (English values fixed here; other locales translated by the implementer):

| key | en |
| --- | --- |
| `diveLog_edit_overline_gasSwitches` | Gas switches |
| `diveLog_edit_gasSwitches_caption` | When you changed cylinders. Deco, tissue loading and per-tank SAC follow these switches. |
| `diveLog_edit_gasSwitches_startsOn` | Starts on {tank} |
| `diveLog_edit_gasSwitches_add` | Add Switch |
| `diveLog_edit_gasSwitches_time` | Time |
| `diveLog_edit_gasSwitches_switchTo` | Switch to |
| `diveLog_edit_gasSwitches_depth` | Depth |
| `diveLog_edit_gasSwitches_remove` | Remove switch |
| `diveLog_edit_gasSwitches_timeFormatError` | Use minutes:seconds |
| `diveLog_edit_gasSwitches_timeRangeError` | Must be within the dive |
| `diveLog_edit_gasSwitches_duplicateError` | Another switch is at this time |
| `diveLog_edit_gasSwitches_removedWithTank` | {count, plural, one{{count} gas switch removed with its tank} other{{count} gas switches removed with their tank}} |

- [ ] **Step 1: Add the keys** to `app_en.arb` with `@` metadata (placeholders `tank` String, `count` int), then to each other locale.
- [ ] **Step 2: Regenerate**: `flutter gen-l10n`. Expected: `app_localizations.dart` gains the getters; `flutter analyze lib/l10n` clean.
- [ ] **Step 3: Commit**: `feat(l10n): gas switch editor strings`

---

### Task 8: The editor widgets

**Files:**
- Create: `lib/shared/widgets/forms/minutes_seconds_field.dart`
- Create: `lib/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor.dart`
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/gas_gear_section.dart`
- Create: `test/shared/widgets/forms/minutes_seconds_field_test.dart`
- Create: `test/features/dive_log/presentation/widgets/edit_sections/gas_switches_editor_test.dart`
- Modify: `test/features/dive_log/presentation/widgets/edit_sections/gas_gear_section_test.dart`

**Interfaces:**
- Consumes: Task 7 strings; `TankRoleDisplay.localizedName(l10n)`; `GasMix.name`; `l10n.diveLog_edit_tankCard_title(number)`; `FormOverline`, `FormCaption`, `FormAppendRow`.
- Produces:

```dart
// minutes_seconds_field.dart (no l10n inside: labels are passed in)
int? parseMinutesSeconds(String text);   // "12:30" -> 750, "7" -> 420, "1:7" -> 67, "ab"/"1:60" -> null
String formatMinutesSeconds(int seconds); // 750 -> "12:30", 67 -> "1:07"
class MinutesSecondsField extends StatefulWidget {
  const MinutesSecondsField({
    super.key,
    required this.seconds,            // int?; the field shows formatMinutesSeconds, '' for null
    required this.onChanged,          // ValueChanged<int?>: parsed value on every edit, null when unparsable
    required this.label,
    required this.formatErrorText,    // shown by the validator when the text does not parse
    this.validator,                   // String? Function(int seconds): extra rule once parsed
  });
}

// gas_switches_editor.dart
enum GasSwitchField { time, tank, depth }
class GasSwitchesEditor extends StatelessWidget {
  const GasSwitchesEditor({
    super.key,
    required this.switches,              // List<GasSwitch>, sorted here by timestamp
    required this.tanks,                 // List<DiveTank>, editor order
    required this.units,                 // UnitFormatter
    required this.maxTimestamp,          // int?; null = no upper bound
    required this.startingTank,          // DiveTank?; null hides the Starts on line
    required this.removedWithTankCount,  // int; > 0 shows the notice
    required this.onChanged,             // void Function(GasSwitch updated, GasSwitchField field)
    required this.onRemove,              // ValueChanged<String> (switch id)
    required this.onAdd,                 // VoidCallback
  });
}
```

Row layout: `FormOverline(diveLog_edit_overline_gasSwitches)`, `FormCaption(diveLog_edit_gasSwitches_caption)`, a `FormCaption` with `diveLog_edit_gasSwitches_startsOn(label)`, the notice caption when the count is positive, one row per switch, `FormAppendRow(diveLog_edit_gasSwitches_add, onAdd)`. A row is a `Row` of `MinutesSecondsField` (flex 2), a `DropdownButtonFormField<String>` over tank ids (flex 3), a depth `TextFormField` with `units.depthSymbol` suffix (flex 2) and a remove `IconButton` with the remove tooltip. The tank option label is `'${l10n.diveLog_edit_tankCard_title(i + 1)} · ${tank.role.localizedName(l10n)} · ${tank.gasMix.name}'`; the Starts on line uses the same label. The time validator returns `diveLog_edit_gasSwitches_timeRangeError` when `seconds < 0` or `maxTimestamp != null && seconds > maxTimestamp`, and `diveLog_edit_gasSwitches_duplicateError` when another switch has the same timestamp. Depth shows `units.convertDepth(m)` to one decimal and reports `units.depthToMeters(parsed)` (null for empty text) through `onChanged(..., GasSwitchField.depth)`. Validators run through the enclosing `Form`, which is how the page blocks Save.

`GasGearSection` gains `final Widget? gasSwitchesChild;` rendered inside the `showTankControls` column after `?applyConfigChild`.

- [ ] **Step 1: Write the failing tests**

```dart
// minutes_seconds_field_test.dart
test('parse', ...)      // the five cases in the signature comment
test('format', ...)     // 750 -> '12:30', 67 -> '1:07', 0 -> '0:00'
testWidgets('typing reports the parsed seconds', ...)        // type '12:30' -> onChanged(750)
testWidgets('unparsable text fails validation with the format text', ...)
// gas_switches_editor_test.dart (host: MaterialApp + Form with a GlobalKey, two tanks:
//   back gas Air and deco EAN50; one switch gs-1 t=600 to the deco tank; units metric)
testWidgets('rows sort by time and show the starting cylinder', ...)
  // switches given out of order render in time order; 'Starts on Tank 1 · Back Gas · Air'
testWidgets('a time one second past the runtime fails validation, the runtime itself passes', ...)
  // maxTimestamp 1800: '30:00' -> form validates; '30:01' -> false with the range text
testWidgets('two switches at one time fail validation', ...)
testWidgets('a typed depth in feet reaches onChanged in metres', ...)
  // units imperial; type '66' -> onChanged depth closeTo(20.1, 0.1), field GasSwitchField.depth
testWidgets('clearing the depth reports null', ...)
testWidgets('remove and add call back', ...)                 // onRemove('gs-1'), onAdd()
testWidgets('the removed-with-tank notice shows for a positive count', ...)
// gas_gear_section_test.dart
testWidgets('renders the gas switches child under the tank controls', ...)
testWidgets('hides the gas switches child for a gauge dive', ...)
```

Read `memory/project_formsection_widget_test_gotchas.md` (via the widget-test traps index) before writing the hosts.

- [ ] **Step 2: Run** the three test files. Expected: FAIL (undefined widgets).

- [ ] **Step 3: Implement** the three files.

- [ ] **Step 4: Run** the three files plus `test/features/dive_log/presentation/widgets/edit_sections/tank_row_test.dart`. Expected: PASS.

- [ ] **Step 5: Commit**: `feat(dive-log): gas switch editor widgets`

---

### Task 9: Wire the editor into the dive edit page

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`: state fields near `_tanks` (`:440`), `_loadExistingDive` (`:1024-1030`), `_removeTank` (`:4143`), `_buildGasGearSection` (`:3700-3745`), `_saveDive` after `updateDive`/`addDive` (`:6372-6420`)
- Create: `test/features/dive_log/presentation/pages/dive_edit_gas_switches_test.dart`

**Interfaces:**
- Consumes: `GasSwitchesEditor`, `GasSwitchField`, `DiverGasSwitchWriter.save`, `profileDepthAt`, `startingTankOf`, `GasSwitch.appliesTo`.
- Page state (immutable updates):

```dart
List<GasSwitch> _gasSwitches = const [];
Set<String> _loadedGasSwitchIds = const {};
Set<String> _depthTouchedSwitchIds = const {};
int _removedSwitchNotice = 0;
bool _gasSwitchesDirty = false;
```

Rules the page applies:
- **Load:** in `_loadExistingDive`, `repository.getGasSwitchesForDive(dive.id)`, keep `g.gasSwitch` for those where `dive.computerId == null || g.gasSwitch.appliesTo(dive.computerId!)`; `_loadedGasSwitchIds` is their ids.
- **Visible** when `_tanks.length >= 2 && _diveMode != DiveMode.gauge && !_isPlanned`; otherwise `gasSwitchesChild` is null and nothing is saved.
- **maxTimestamp:** `_existingDive?.profile.last.timestamp` when the profile is non-empty; else the runtime field (`_runtimeController`, whole minutes) times 60; else the duration field (`_durationController`, bottom time, minutes) times 60; else exit minus entry in seconds when both are set; else null.
- **startingTank:** `startingTankOf(tanks: _tanks, switches: _gasSwitches, diveStart: 0)`.
- **onChanged(updated, field):** replace the switch by id; `_gasSwitchesDirty = true`; `_removedSwitchNotice = 0`; if `field == GasSwitchField.depth` add the id to `_depthTouchedSwitchIds`; if `field == GasSwitchField.time` and the id is not touched and the profile is non-empty, set `depth = profileDepthAt(profile, updated.timestamp)`.
- **onAdd:** a `GasSwitch` with `id: _uuid.v4()`, `diveId: widget.diveId ?? ''`, `timestamp` = last switch's timestamp + 60 (0 with no switches), clamped to `maxTimestamp` when set, `tankId` = the first tank whose id differs from the cylinder active at that time (the last switch at or before it, else `startingTank`), `depth` from `profileDepthAt` when there is a profile, `createdAt: DateTime.now()`, `computerId: null`.
- **onRemove(id):** drop it; dirty; notice 0.
- **`_removeTank(index)`:** also drop every switch whose `tankId` is that tank's; when any was dropped set `_removedSwitchNotice` to the count and `_gasSwitchesDirty = true`.
- **Save:** after the dive write that yields `savedDiveId`, when `_gasSwitchesDirty` and the list is visible: `await DiverGasSwitchWriter().save(diveId: savedDiveId, switches: [for (final s in _gasSwitches) s.copyWith(diveId: savedDiveId)], loadedIds: _loadedGasSwitchIds)`.

- [ ] **Step 1: Write the failing tests**, modelled on `test/features/dive_log/presentation/pages/dive_edit_ccr_setpoint_seed_test.dart` (`pumpEditor`, `onSaved`), seeding through `DiveRepository.createDive` a dive with two tanks (Air back gas, EAN50 deco) and a profile `(0, 0), (600, 30), (1200, 30), (1800, 0)`:

```dart
testWidgets('adding a switch saves it with the profile depth and marks the dive edited', ...)
  // expand Gas & Gear, tap 'Add Switch', enter '15:00', pick the deco tank, Save;
  // wait for onSaved; gas_switches has one row: timestamp 900, that tank, depth 30.0,
  // computerId null; dives.gasSwitchesEdited true
testWidgets('removing a tank removes its switch on save', ...)
  // seed a switch to the deco tank; remove the deco tank row; the notice text appears;
  // Save; gas_switches empty; a gasSwitches tombstone exists
testWidgets('a dive with one tank shows no gas switch list', ...)
testWidgets('an untouched list saves nothing', ...)
  // seed a switch; open, change the notes only, Save; gasSwitchesEdited stays false
```

A tap never blurs a field (memory `blur-skip`): commit the time field with `tester.testTextInput.receiveAction(TextInputAction.done)` or by tapping the next field before Save. Drive the save through `onSaved`, not `runAsync` reads mid-transaction (memory `drift-transaction-read-deadlock`).

- [ ] **Step 2: Run**: `flutter test test/features/dive_log/presentation/pages/dive_edit_gas_switches_test.dart`. Expected: FAIL (no list, no rows).

- [ ] **Step 3: Implement** the page changes; the list builder is a private `_buildGasSwitchesChild(UnitFormatter units)` of about forty lines, with the rules above as small private methods so the page's growth stays minimal.

- [ ] **Step 4: Run** the new file, `dive_edit_ccr_setpoint_seed_test.dart`, `dive_edit_apply_cylinder_config_test.dart` and `test/features/dive_log/presentation/widgets/edit_sections/`. Expected: PASS.

- [ ] **Step 5: Commit**: `feat(dive-log): edit gas switches on the dive edit page`

---

### Task 10: Whole-tree checks

- [ ] **Step 1:** `dart format .` then `flutter analyze`. Expected: no issues.
- [ ] **Step 2:** `flutter test test/architecture test/shared test/core/database test/features/dive_log test/features/dive_computer test/features/dive_import`. Expected: PASS, no skips.
- [ ] **Step 3:** Fix anything red, re-run, commit as `fix(dive-log): ...` describing the fix.

After this task the build-feature skill resumes: after-screenshots of the gas and gear group (phone and desktop widths), the PR with `Closes #32, closes #3058`, the spec and plan links, then the review rounds.
