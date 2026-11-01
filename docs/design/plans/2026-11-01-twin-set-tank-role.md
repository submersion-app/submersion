# Twin Set Tank Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Twin Set tank role with its own glyph, make the Insights tank configuration count twins only from that role, and give divers a one-tap way to re-role cylinders the old guessing counted as twins.

**Architecture:** One new `TankRole` value stored by name, a `backmountRoles` set beside `sidemountRoles` for every "is this the primary back-mounted gas" check, and the classifier reduced to role rules. The old name-and-size rule survives only as a finder behind a SQL function; a new Insights repository part counts its candidates, a new `DiveRepository.setTankRoles` re-roles them, and a note on the Tank configuration card exposes both.

**Tech Stack:** Flutter, Riverpod, Drift with registered SQL functions, ARB localization over eleven locales, the equipment icon font built by `tool/build_equipment_icon_font.py` (fonttools is installed for the system `python3`).

**Spec:** `docs/design/specs/2026-11-01-twin-set-tank-role-design.md`

## Global Constraints

- No schema bump; a role is stored by name in `dive_tanks.tank_role`.
- No em-dashes anywhere; no AI tool named in commits, code or PR text.
- Every ARB locale (ar, de, en, es, fr, he, hu, it, nl, pt, zh) gets every new key, inserted beside its feature-group neighbours (the files are feature-grouped, not sorted). Run `flutter gen-l10n` after each ARB edit; the generated `lib/l10n/arb/app_localizations*.dart` files are committed and the pre-push hook rejects stale ones.
- A plural whose `=1` branch names the number writes `{count}` in that branch, never a literal digit (the `=1` branch is the CLDR `one` category and prints for zero in fr and pt).
- Anything displaying volume respects the diver's unit settings.
- Before each commit: `dart format .`, `flutter analyze`, the task's tests. After any new file under `lib/`: `flutter test test/architecture/ test/shared/`.
- Test paths are platform-agnostic; tests that touch process-wide state restore it.
- Each task commits with `feat(<scope>): ...`; scope is `dive-log` or `insights` per the task's main directory.

## Review Focus

1. A dive with a Twin Set row and a Deco row counts as twin backmount with the deco-gas extra, and "Mark as twin sets" never changes the deco row. Pinned in Task 5 (classifier) and Task 7 (repository).
2. A Twin Set on a CCR dive: the base is rebreather (mode wins), and the bailout ascent gas set keeps the twin set as open-circuit gas rather than reading it as diluent. Pinned in Task 2 (CCR schedule) and Task 3 (ascent gases).
3. Two Twin Set rows with no volumes on one dive pair one to one for SAC, in Dart and in SQL. Pinned in Task 3 and Task 4.
4. A candidate cylinder on another diver's dive is not counted and not re-roled. Pinned in Task 6.
5. A synced peer on an older build reads `twinSet` as Back Gas; the SQL classifier already has that test and it must still pass. Checked in Task 5.

---

### Task 1: The glyph

**Files:**
- Modify: `tool/equipment_glyphs.py` (append after the `second_stage` glyph, the last `add(...)`)
- Modify: `assets/fonts/submersion-equipment.ttf` (rebuilt)
- Modify: `lib/core/icons/submersion_icons.dart:135-145`

**Interfaces:**
- Produces: `SubmersionIcons.tankTwinSet`, `IconData(0xe91f, fontFamily: fontFamily)`.

- [ ] **Step 1: Draw the glyph**

Add `tank_twin_set` ("Twin Set", "Two upright cylinders joined by a manifold, both solid.") as the last `add(...)` in `tool/equipment_glyphs.py`. Build it from the existing helpers: two `_tank_pts` cylinders at the sidemount positions (`left_x 2.4`, `right_x 13.8`, `SIDEMOUNT_Y`, `SIDEMOUNT_W`, `SIDEMOUNT_H`, scale `0.8`, knob `-1` on the left and `+1` on the right), both solid, plus one `bar(...)` across the top joining the two valve bodies at the manifold height (`SIDEMOUNT_Y - 2.4`), width about `1.6`. Nothing hollow, so it reads apart from the sidemount pair.

- [ ] **Step 2: Build and verify the font**

Run:
```bash
python3 tool/build_equipment_icon_font.py --verify
```
Expected: the verify listing names `tank_twin_set` at code point `0xe91f` with bounds inside the 24 unit box, and every earlier glyph keeps its code point.

- [ ] **Step 3: Look at it**

`python3 tool/equipment_glyphs.py` prints the path data. Write one SVG in the scratchpad placing `tank_twin_set`, `tank_sidemount_left` and `tank_back_gas` side by side at 24 px and 96 px with `fill-rule="nonzero"`, rasterize with `qlmanage -t -s 900 -o <scratchpad> sheet.svg`, and read the PNG. Adjust the bar height or width until the manifold reads as one piece at 24 px.

- [ ] **Step 4: Add the constant**

In `submersion_icons.dart`, after `secondStage`:
```dart
/// Two upright cylinders joined across the top by a manifold, both solid:
/// a twin set. Both solid is what tells it from the sidemount pair.
static const IconData tankTwinSet = IconData(0xe91f, fontFamily: fontFamily);
```

- [ ] **Step 5: Commit**

```bash
git add tool/equipment_glyphs.py assets/fonts/submersion-equipment.ttf lib/core/icons/submersion_icons.dart
git commit -m "feat(dive-log): draw the twin set glyph"
```

---

### Task 2: The role

**Files:**
- Modify: `lib/core/constants/enums.dart:293-305`
- Modify: `lib/features/dive_log/presentation/widgets/tank_enum_display.dart:19-47`
- Modify: `lib/features/dive_log/domain/services/multi_cylinder_consumption.dart:11` (beside `sidemountRoles`)
- Modify: `lib/features/planner/domain/services/tank_mod.dart:66-75`
- Modify: `lib/features/dive_log/domain/services/ccr_gas_schedule.dart:70-80, 96-99`
- Modify: `lib/features/equipment/figure/domain/figure_composer.dart:112-129`
- Modify: `lib/l10n/arb/app_*.arb` (eleven files), key `enum_tankRole_twinSet` after `enum_tankRole_stage`
- Test: `test/features/dive_log/presentation/widgets/tank_role_icon_test.dart`
- Test: `test/features/dive_log/domain/services/ccr_gas_schedule_test.dart`
- Test: `test/features/planner/domain/services/tank_mod_test.dart` (create if absent)

**Interfaces:**
- Produces: `TankRole.twinSet` (`displayName` "Twin Set"), declared immediately after `backGas`.
- Produces: `const Set<TankRole> backmountRoles = {TankRole.backGas, TankRole.twinSet};` in `multi_cylinder_consumption.dart`.
- Produces: `TankRole.twinSet.icon == SubmersionIcons.tankTwinSet`; `localizedName` returns `l10n.enum_tankRole_twinSet`.

- [ ] **Step 1: Write the failing tests**

In `tank_role_icon_test.dart`, add to the first test:
```dart
expect(TankRole.twinSet.icon, SubmersionIcons.tankTwinSet);
```
and a new test:
```dart
test('twin set is declared right after back gas', () {
  expect(TankRole.values.indexOf(TankRole.twinSet),
      TankRole.values.indexOf(TankRole.backGas) + 1);
});
```
In `ccr_gas_schedule_test.dart`, add:
```dart
test('a twin set on a CCR dive is explicit open-circuit gas', () {
  final tank = DiveTank(id: 't', role: TankRole.twinSet,
      gasMix: const GasMix(o2: 21));
  expect(ccrCylinderRole(tank), TankRole.twinSet);
});
```
In `tank_mod_test.dart`:
```dart
test('a twin set uses the bottom limit like back gas', () {
  expect(usesDecoLimit(TankRole.twinSet, const GasMix(o2: 32)), isFalse);
  expect(modLimitClassFor(TankRole.twinSet, const GasMix(o2: 32)),
      ModLimitClass.bottom);
});
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/presentation/widgets/tank_role_icon_test.dart test/features/dive_log/domain/services/ccr_gas_schedule_test.dart test/features/planner/domain/services/tank_mod_test.dart`
Expected: compile errors naming `TankRole.twinSet`.

- [ ] **Step 3: Add the enum value and the shared set**

In `enums.dart` insert `twinSet('Twin Set'),` after `backGas('Back Gas'),` with a doc line: a manifolded pair logged as one cylinder with the combined volume (issue #3374). In `multi_cylinder_consumption.dart` add `backmountRoles` with a doc comment: the roles that mean the primary gas worn on the back.

- [ ] **Step 4: Handle the exhaustive switches**

- `tank_enum_display.dart`: `localizedName` arm `TankRole.twinSet => l10n.enum_tankRole_twinSet`; `icon` arm `TankRole.twinSet => SubmersionIcons.tankTwinSet`.
- `tank_mod.dart` `usesDecoLimit`: add `TankRole.twinSet` to the `false` group.
- `ccr_gas_schedule.dart`: the `switch` at line 73 gains `TankRole.twinSet` in whichever group `TankRole.backGas` is in; `ccrCylinderRole` is unchanged (it already returns any non-Back-Gas role as is), but its doc comment gains one sentence: a Twin Set is a role the diver chose, so it is open-circuit gas on a CCR dive.
- `figure_composer.dart` `_zonesForTankRole`: `TankRole.twinSet` joins the `backTank` group.

- [ ] **Step 5: Localize the name**

Add `"enum_tankRole_twinSet"` after `"enum_tankRole_stage"` in every ARB: en "Twin Set", de "Doppelgerät", fr "Bi-bouteille", es "Bibotella", it "Bibombola", nl "Dubbelset", pt "Bi-cilindro", hu "Ikerpalack", ar "طقم مزدوج", he "צמד בלונים", zh "双瓶". Run `flutter gen-l10n`.

- [ ] **Step 6: Run the tests and analyze**

Run: the three test files from Step 2, then `flutter analyze`.
Expected: all pass, no analyzer issues (the analyzer confirms no other exhaustive switch was missed).

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/enums.dart lib/features/dive_log lib/features/planner/domain/services/tank_mod.dart lib/features/equipment/figure/domain/figure_composer.dart lib/l10n test/features
git commit -m "feat(dive-log): add the twin set tank role"
```

---

### Task 3: Twin set as backmount gas in Dart

**Files:**
- Modify: `lib/features/dive_log/domain/services/multi_cylinder_consumption.dart:34-41, 106-111`
- Modify: `lib/features/dive_log/domain/services/tank_usage_range.dart:113`
- Modify: `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:190-196, 398`
- Modify: `lib/features/dive_lab/domain/services/tank_schedule.dart:46, 179`
- Modify: `lib/features/dive_lab/domain/services/scenario_engine.dart:515`
- Modify: `lib/features/dive_lab/presentation/widgets/lab_delta_panel.dart:116`
- Test: `test/features/dive_log/domain/services/multi_cylinder_consumption_test.dart`
- Test: `test/features/dive_log/domain/services/tank_usage_range_test.dart`
- Test: `test/features/dive_log/build_available_gases_test.dart`

**Interfaces:**
- Consumes: `backmountRoles` from Task 2.
- Produces: `isMatchedPair(a, b)` true when both roles are `twinSet` (no gas check); `sacReferenceTankOf` prefers any `backmountRoles` cylinder.

Not changed, on purpose: `downloaded_tank_defaults.dart` and `unused_oc_gas_cleanup.dart` fill and recognise the default single-cylinder preset on a Back Gas row only; a twin set's volume is never a single preset's. `transmitter_auto_registrar.dart` only falls back to Back Gas for an unknown name.

- [ ] **Step 1: Write the failing tests**

`multi_cylinder_consumption_test.dart`:
```dart
test('two twin set rows are a matched pair whatever their gas', () {
  expect(isMatchedPair(tank(TankRole.twinSet, o2: 21), tank(TankRole.twinSet, o2: 32)), isTrue);
});
test('a twin set is the SAC reference ahead of a stage', () {
  final twin = tank(TankRole.twinSet);
  expect(sacReferenceTankOf([tank(TankRole.stage), twin]), same(twin));
});
```
`tank_usage_range_test.dart`: copy the existing "back gas spans a dive with no switches" case with role `twinSet`, expecting one range `(start: diveStart, end: diveEnd)`.
`build_available_gases_test.dart`:
```dart
test('decoStageOnly keeps a twin set as the floor', () { /* air twinSet + ean50; expect 0.21 present */ });
test('a twin set stays in a CCR bailout gas set', () { /* forCcrBailout: true, tanks [twinSet air, diluent]; expect 0.21 present */ });
```
Use the file's existing `_diveWith` helper, giving the air tank role `twinSet`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/dive_log/domain/services/multi_cylinder_consumption_test.dart test/features/dive_log/domain/services/tank_usage_range_test.dart test/features/dive_log/build_available_gases_test.dart`
Expected: the new cases fail (twin set not paired, not the reference, dropped from the gas set).

- [ ] **Step 3: Replace the Back Gas comparisons**

At each listed site replace `t.role == TankRole.backGas` with `backmountRoles.contains(t.role)`. In `isMatchedPair` add the clause `(a.role == TankRole.twinSet && b.role == TankRole.twinSet)` before the Back Gas clause and extend its doc comment. In `profile_analysis_provider.dart` line 398 the `keep` test becomes `backmountRoles.contains(role) || role == TankRole.deco || ...`.

- [ ] **Step 4: Run the tests**

Run: the three files from Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log lib/features/dive_lab test/features/dive_log
git commit -m "feat(dive-log): treat a twin set as backmount gas"
```

---

### Task 4: The consumption SQL mirror

**Files:**
- Modify: `lib/features/dive_log/data/sql/multi_cylinder_sac_sql.dart`
- Test: `test/features/insights/data/repositories/insights_repository_multi_cylinder_sac_test.dart`

**Interfaces:**
- Consumes: the Task 3 Dart rules, which this file mirrors.

- [ ] **Step 1: Write the failing parity tests**

In the "SAC in pressure per minute" group, modelled on `sums unsized back-gas doubles logged as independents`:
```dart
test('sums two unsized twin set rows one to one', () async { /* two twinSet rows, no volumes, drops 100 and 80; expect the Dart Dive.sac value */ });
test('a twin set is the reference ahead of a stage', () async { /* twinSet + stage, both sized; expect the stage drop converted into twin-set bar */ });
```
In "RMV borrows a matched partner volume": `test('twin set rows borrow like a sidemount pair', ...)`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/insights/data/repositories/insights_repository_multi_cylinder_sac_test.dart`
Expected: the new cases fail.

- [ ] **Step 3: Extend the SQL**

Add `const String _backmountRolesSql = "('backGas', 'twinSet')";`. In `consumptionVolumeSql` add a clause `OR ($tank.tank_role = 'twinSet' AND $partner.tank_role = 'twinSet')`. In `diveSacPressureSql`: the `cylinders` projection gains `sac_t.tank_role = 'twinSet' AS twin_set`; the CASE gains `WHEN sac_c.twin_set AND sac_r.twin_set THEN 1.0` before the Back Gas line; the reference subquery uses `t2.tank_role IN $_backmountRolesSql` and `t3.tank_role IN $_backmountRolesSql` in place of the `= 'backGas'` comparisons. Update the doc comments to say "backmount gas (back gas or twin set)".

- [ ] **Step 4: Run the whole file**

Run: the same command.
Expected: PASS, including the existing Back Gas cases.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/sql/multi_cylinder_sac_sql.dart test/features/insights/data/repositories/insights_repository_multi_cylinder_sac_test.dart
git commit -m "feat(dive-log): mirror the twin set pair rule in SQL"
```

---

### Task 5: The classifier stops guessing

**Files:**
- Modify: `lib/features/insights/domain/tank_configuration/tank_configuration_classifier.dart:9-70`
- Create: `lib/features/insights/domain/tank_configuration/twin_set_candidates.dart`
- Modify: `lib/features/insights/presentation/widgets/tank_configuration_card.dart` (nothing yet; the note text key changes value only)
- Modify: `lib/l10n/arb/app_*.arb`, value of `insights_gas_tankConfig_note`
- Test: `test/features/insights/domain/tank_configuration/tank_configuration_classifier_test.dart`
- Test: `test/features/insights/domain/tank_configuration/twin_set_candidates_test.dart` (the `looksLikeTwinSet` group moves here)
- Test: `test/features/insights/data/tank_configuration_sql_test.dart:229-253`
- Test: `test/features/insights/presentation/widgets/tank_configuration_card_test.dart:117-121`

**Interfaces:**
- Produces: `bool looksLikeTwinSet(DiveTank tank)` and `const double twinSetMinVolumeLiters = 20.0` now exported from `twin_set_candidates.dart`, unchanged in behaviour, with a doc comment saying they are the migration finder (issue #3374), not a classification rule.
- Produces: `classifyTankConfiguration` base rule order: rebreather, noTanks, sidemount, twinBackmount (any `TankRole.twinSet`), other (no `backmountRoles` cylinder), singleBackmount.

- [ ] **Step 1: Rewrite the classifier tests**

In `tank_configuration_classifier_test.dart` replace the four twin tests (lines 85-115) with:
```dart
test('one twin set cylinder is twin backmount', () { expect(classify([tank(TankRole.twinSet)]).base, TankBaseConfiguration.twinBackmount); });
test('a twin set plus a deco bottle is twin backmount with deco gas', () { /* extras contains decoGas */ });
test('two backGas on one gas are single backmount', () { /* 21 and 21.3 */ });
test('one backGas of 24 L is single backmount', () {});
test('a backGas named D12 is single backmount', () {});
test('a twin set in ccr mode is a rebreather', () { /* mode: DiveMode.ccr */ });
```
Move the `looksLikeTwinSet` group to `twin_set_candidates_test.dart`, importing the new file, and add `test('a twin set row is never a candidate', ...)` and `test('a 24 L stage is not a candidate', ...)` expecting false.

In `tank_configuration_sql_test.dart` replace the tests at lines 229-253 with `twin by a twin set role`, and turn the matched pair, 22 L, D12 and preset cases into `single backmount` expectations.

In `tank_configuration_card_test.dart` line 120 the note assertion becomes `find.textContaining('Twin Set')`.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/insights/domain/tank_configuration test/features/insights/data/tank_configuration_sql_test.dart test/features/insights/presentation/widgets/tank_configuration_card_test.dart`
Expected: the rewritten cases fail; `twin_set_candidates_test.dart` fails to import.

- [ ] **Step 3: Move the finder and simplify the classifier**

Create `twin_set_candidates.dart` holding `twinSetMinVolumeLiters`, the three regexes, `looksLikeTwinSet` and `_namesTwin`, plus `bool isTwinSetCandidate(DiveTank tank) => tank.role == TankRole.backGas && looksLikeTwinSet(tank);`. In the classifier delete them and `isMatchedPair`'s use; `_base` becomes the six rules in the Interfaces block, using `backmountRoles`. Update the file's doc comment (no more "downloads tag every gas under 41%" paragraph).

- [ ] **Step 4: Change the note text**

`insights_gas_tankConfig_note` in all locales: en "A dive counts as twin backmount when a cylinder's role is Twin Set, and as sidemount when its cylinders are Sidemount Left and Right." Translate in each locale's own words. Run `flutter gen-l10n`.

- [ ] **Step 5: Run the tests, the architecture guards and the parity test**

Run: the Step 2 command plus `flutter test test/features/insights/data/tank_configuration_parity_test.dart test/architecture/ test/shared/`.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/insights lib/l10n test/features/insights
git commit -m "feat(insights): count twin backmount dives from the twin set role"
```

---

### Task 6: Finding the candidates

**Files:**
- Modify: `lib/features/insights/data/tank_configuration_sql.dart:60-80` (register the new function beside the two existing ones)
- Create: `lib/features/insights/data/repositories/insights_repository_twin_set_candidates.dart` (a `part of 'insights_repository.dart'`, declared after the `tank_configuration` part)
- Modify: `lib/features/insights/data/repositories/insights_repository.dart:56` (add the `part`)
- Test: `test/features/insights/data/twin_set_candidates_sql_test.dart`

**Interfaces:**
- Produces: SQL function `twin_set_candidate(tank_role, tank_name, preset_name, volume)` returning 1 or 0, registered by `registerTankConfigurationFunctions`; constant `kTwinSetCandidateFunction`.
- Produces:
  ```dart
  typedef TwinSetCandidates = ({List<String> tankIds, List<String> diveIds});
  Future<TwinSetCandidates> getTwinSetCandidates({String? diverId});
  ```
  on `InsightsRepository`. Whole logbook of that diver, not the Insights filter: it is a migration aid. Both lists are distinct; `diveIds` in dive date order.

- [ ] **Step 1: Write the failing test**

`twin_set_candidates_sql_test.dart`, with the `insertDive`/`insertTank` helpers copied from `tank_configuration_sql_test.dart` (give `insertDive` a `diverId` parameter):
```dart
test('names, presets and 20 L back gas are candidates', () async { /* D12 name, twin_12 preset, 22 L volume: three tanks on three dives; expect tankIds length 3, diveIds length 3 */ });
test('a 24 L stage and a twin set are not', () async { /* expect empty */ });
test('two candidates on one dive give one dive id', () async {});
test('another diver\'s dive is left out', () async { /* diverId 'other' */ });
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/insights/data/twin_set_candidates_sql_test.dart`
Expected: FAIL, `getTwinSetCandidates` undefined.

- [ ] **Step 3: Register the function and write the query**

In `tank_configuration_sql.dart` add `kTwinSetCandidateFunction = 'twin_set_candidate'` and register it in `registerTankConfigurationFunctions` with `AllowedArgumentCount(4)`, building a `DiveTank` from the four arguments (role via the existing `_tankRolesByName` fallback to Back Gas) and returning `isTwinSetCandidate(tank) ? 1 : 0`. In the new part:
```sql
SELECT t.id AS tank_id, d.id AS dive_id
FROM dive_tanks t JOIN dives d ON d.id = t.dive_id
WHERE twin_set_candidate(t.tank_role, t.tank_name, t.preset_name, t.volume) = 1
  [AND d.diver_id = ?]
ORDER BY d.dive_date_time, t.tank_order, t.rowid
```
Wrap in the repository's `try`/`_log.error`/`rethrow` pattern.

- [ ] **Step 4: Run the test**

Run: the Step 2 command.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights test/features/insights/data/twin_set_candidates_sql_test.dart
git commit -m "feat(insights): find cylinders that look like a twin set"
```

---

### Task 7: Re-roling cylinders in the repository

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (after `bulkUpdateTankSpecs`, line 8190)
- Test: `test/features/dive_log/data/repositories/dive_repository_set_tank_roles_test.dart`

**Interfaces:**
- Produces: `Future<int> setTankRoles(List<String> tankIds, TankRole role)` on `DiveRepository`. Writes `tank_role = role.name` and `role_source = NULL` on exactly those rows, marks each `diveTanks` row pending, bumps the parent dives with `_bumpDives`, in one `_db.transaction`, and returns the number of rows changed. Unlike `bulkUpdateTankSpecs` it owns its transaction; Drift's table updates notify the dive streams.

- [ ] **Step 1: Write the failing test**

Using `setUpTestDatabase` and the `insertDive`/`insertTank` helper pattern:
```dart
test('changes only the named rows and keeps pressures', () async { /* dive with candidate t1 (backGas, 200/50) and deco t2; setTankRoles(['t1'], TankRole.twinSet); t1.role twinSet, t1 pressures intact, t2.role deco */ });
test('clears the transmitter-name role source', () async { /* t1 roleSource 'transmitterName' before; null after */ });
test('marks the tank and its dive pending for sync', () async { /* dives.updated_at bumped; sync pending rows for diveTanks t1 and dives d1 */ });
test('an empty list changes nothing and returns 0', () async {});
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_set_tank_roles_test.dart`
Expected: FAIL, method undefined.

- [ ] **Step 3: Implement `setTankRoles`**

Reuse `_tankSpecsCompanion(DiveTank(... role: role ...), {TankSpecField.role})` for the companion so `role_source` clearing stays in one place; select the rows by id to learn their dive ids; update, mark pending, `_bumpDives`.

- [ ] **Step 4: Run the test**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_repository_set_tank_roles_test.dart
git commit -m "feat(dive-log): set the role of a list of cylinders"
```

---

### Task 8: The note on the Tank configuration card

**Files:**
- Modify: `lib/features/insights/presentation/providers/insights_providers.dart:189-200` (the candidates provider, after `tankConfigurationStatsProvider`, since `_keepAliveWithExpiry` is private to that file)
- Create: `lib/features/insights/presentation/providers/twin_set_review_providers.dart` (the dismissed notifier)
- Create: `lib/features/insights/presentation/widgets/twin_set_review_note.dart`
- Modify: `lib/features/insights/presentation/widgets/tank_configuration_card.dart:185-193` (insert the note between the bars and the explanation text)
- Modify: `lib/l10n/arb/app_*.arb`, new keys after `insights_gas_tankConfig_note`
- Test: `test/features/insights/presentation/widgets/twin_set_review_note_test.dart`
- Test: `test/features/insights/presentation/widgets/tank_configuration_card_test.dart`

**Interfaces:**
- Consumes: `getTwinSetCandidates` (Task 6), `setTankRoles` (Task 7), `openHeldChartDives` from `open_chart_dives.dart`, `sharedPreferencesProvider`, `currentDiverIdProvider`, `unitFormatterProvider`.
- Produces:
  ```dart
  final twinSetCandidatesProvider = FutureProvider<TwinSetCandidates>(...);  // same expiry pattern as tankConfigurationStatsProvider
  final twinSetReviewDismissedProvider = StateNotifierProvider<TwinSetReviewDismissedNotifier, bool>(...);
  // key 'twin_set_review_dismissed.<diverId>' in SharedPreferences
  class TwinSetReviewNote extends ConsumerWidget { const TwinSetReviewNote({super.key}); }
  ```
  The note renders nothing when candidates are empty, the provider is loading or failed, or dismissed is true.

New ARB keys (English; translate in every locale):
- `insights_gas_twinSetReview_title`: `{count, plural, =1{{count} dive has a cylinder that looks like a twin set.} other{{count} dives have cylinders that look like a twin set.}}`
- `insights_gas_twinSetReview_body`: "Their names or sizes say twin, double, D12, 2x12, or {size} and up, but their role is Back Gas, so they count as single backmount." with placeholder `size` (a String from `formatTankVolume(twinSetMinVolumeLiters, null)`).
- `insights_gas_twinSetReview_mark`: "Mark as twin sets"
- `insights_gas_twinSetReview_review`: "Review dives"
- `insights_gas_twinSetReview_dismiss`: "Dismiss"
- `insights_gas_twinSetReview_confirmTitle`: "Set role to Twin Set?"
- `insights_gas_twinSetReview_confirmBody`: `{tanks, plural, =1{Set the role of {tanks} cylinder on {dives} to Twin Set? Other cylinders on those dives are left alone.} other{Set the role of {tanks} cylinders on {dives} to Twin Set? Other cylinders on those dives are left alone.}}` where `dives` is itself the rendered `insights_gas_twinSetReview_diveCount` plural: `{count, plural, =1{{count} dive} other{{count} dives}}`.
- `insights_gas_twinSetReview_confirm`: "Set role"
- `insights_gas_twinSetReview_done`: `{count, plural, =1{{count} cylinder set to Twin Set} other{{count} cylinders set to Twin Set}}`
- `insights_gas_twinSetReview_chart`: "Looks like a twin set" (the row label for the dive list chip)

- [ ] **Step 1: Write the failing widget tests**

`twin_set_review_note_test.dart`, pumping `TwinSetReviewNote` with `twinSetCandidatesProvider` and `twinSetReviewDismissedProvider` overridden and a `RecordingInsightsRepository`-style fake `DiveRepository` for `setTankRoles`:
```dart
testWidgets('hidden with no candidates', ...);            // findsNothing for the title
testWidgets('names the dive count with the plural', ...); // 14 dives -> '14 dives have cylinders that look like a twin set.'
testWidgets('one dive uses the singular', ...);
testWidgets('hidden once dismissed', ...);
testWidgets('dismiss stores the flag under the diver id', ...); // SharedPreferences fake, key contains diver id
testWidgets('mark asks first, names both counts, then re-roles the candidate tanks', ...); // tap Mark; dialog text contains '15 cylinders on 14 dives'; tap Set role; fake received (tankIds, TankRole.twinSet); SnackBar '15 cylinders set to Twin Set'
testWidgets('cancelling the dialog changes nothing', ...);
testWidgets('review opens the dive list with the candidate dive ids', ...); // same pattern as the card test's 'tapping a bar' group, asserting DiveFilterState.diveIds equals the candidate diveIds
```
In `tank_configuration_card_test.dart` add `testWidgets('shows the twin set note above the explanation when there are candidates', ...)` with the providers overridden, asserting the title text is found and sits above the explanation text in the column.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/insights/presentation/widgets/twin_set_review_note_test.dart test/features/insights/presentation/widgets/tank_configuration_card_test.dart`
Expected: compile errors for the missing providers and widget.

- [ ] **Step 3: Add the ARB keys and generate**

All eleven locales, then `flutter gen-l10n`.

- [ ] **Step 4: Implement the providers**

`twinSetCandidatesProvider` in `insights_providers.dart` reads `insightsRepositoryProvider` and `currentDiverIdProvider` and calls `_keepAliveWithExpiry(ref)` like its neighbour. `TwinSetReviewDismissedNotifier(prefs, diverId)` in the new providers file reads the key on construction and exposes `Future<void> dismiss()`.

- [ ] **Step 5: Implement the widget**

A `Card`-less block: title in `titleSmall`, body in `bodySmall` with `onSurfaceVariant`, then a `Wrap` of three buttons: `FilledButton.tonal` for Mark, `TextButton` for Review and Dismiss. Mark shows an `AlertDialog` with the confirm body; on confirm it calls `ref.read(diveRepositoryProvider).setTankRoles(candidates.tankIds, TankRole.twinSet)`, invalidates `twinSetCandidatesProvider` and `tankConfigurationStatsProvider`, and shows the done SnackBar. Review calls `openHeldChartDives(context, ref, chart: l10n.insights_gas_tankConfig_title, row: l10n.insights_gas_twinSetReview_chart, ids: candidates.diveIds)`. Dismiss calls the notifier.

- [ ] **Step 6: Place it on the card**

In `tank_configuration_card.dart` insert `const TwinSetReviewNote()` and a 12 px gap before the explanation `Text`, inside the `Column`.

- [ ] **Step 7: Run the tests and guards**

Run: the Step 2 command plus `flutter test test/features/insights/presentation test/architecture/ test/shared/`.
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/insights lib/l10n test/features/insights
git commit -m "feat(insights): offer to re-role cylinders that look like a twin set"
```

---

### Task 9: Where else the role shows

**Files:**
- Modify: `lib/features/insights/presentation/pages/insights_gas_page.dart:182-194`
- Modify: `lib/l10n/arb/app_*.arb`, key `insights_gas_tankRole_twinSet` after `insights_gas_tankRole_stage` (en "Twin Set")
- Modify: `lib/features/equipment/figure/domain/figure_composer.dart:138-157`
- Test: `test/features/insights/presentation/pages/insights_gas_page_widget_test.dart`
- Test: `test/features/equipment/figure/domain/figure_composer_test.dart`
- Test: `test/features/dive_log/presentation/widgets/cylinders_card_role_test.dart`

**Interfaces:**
- Consumes: `TankRole.twinSet`, `SubmersionIcons.tankTwinSet`.

- [ ] **Step 1: Write the failing tests**

`insights_gas_page_widget_test.dart`: in whichever test seeds `sacByTankRoleProvider`, add a `'twinSet'` entry and expect the text 'Twin Set' (not 'twinSet').
`figure_composer_test.dart`:
```dart
test('one twin set tank draws the doubles piece on its own', () {
  final model = composeFigure([item('t1', EquipmentType.tank, tankRole: TankRole.twinSet)]);
  expect(model.byId('t1')!.zone, FigureZone.backTank);
  expect(model.byId('t1')!.pieceIds, ['tank_doubles_back']);
});
```
(the `item` helper already takes a tank role for the "dive tank role places the tank" test; reuse its parameter name.)
`cylinders_card_role_test.dart`:
```dart
testWidgets('a lone twin set still shows its role and glyph', ...); // one tank role twinSet; find.byIcon(SubmersionIcons.tankTwinSet) findsOneWidget and text 'Twin Set'
testWidgets('a lone back gas cylinder hides the role row', ...);   // keep the existing behaviour pinned if no test does
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/insights/presentation/pages/insights_gas_page_widget_test.dart test/features/equipment/figure/domain/figure_composer_test.dart test/features/dive_log/presentation/widgets/cylinders_card_role_test.dart`
Expected: the new cases fail.

- [ ] **Step 3: Implement**

- `insights_gas_page.dart`: arm `'twinSet' => context.l10n.insights_gas_tankRole_twinSet`.
- `_mergeDoubles`: when the back zone holds exactly one tank whose `item.tankRole == TankRole.twinSet`, give it `['tank_doubles_back']`; the two-tank branch is unchanged. Update the doc comment.
- The cylinders card and the PDF template compare to `TankRole.backGas` alone and need no code change; the test pins that.

- [ ] **Step 4: Run the tests**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/insights lib/features/equipment lib/l10n test/features
git commit -m "feat(insights): label the twin set role on the gas page and the figure"
```

---

### Task 10: Whole-branch verification

- [ ] **Step 1: Format and analyze the whole repo**

Run: `dart format . && flutter analyze`
Expected: no changes from format, no analyzer issues.

- [ ] **Step 2: Run every touched area**

Run: `flutter test test/features/insights test/features/dive_log test/features/dive_lab test/features/equipment test/features/planner test/architecture test/shared test/core/database`
Expected: all pass. Run with `TZ=` unset and then `TZ=Australia/Sydney` for the insights directory, since CI runs under that zone.

- [ ] **Step 3: Grep for stragglers**

Run: `grep -rn "TankRole.backGas\b" lib --include='*.dart' | grep -v "_test"` and read each hit against the spec's three exceptions (cylinders card, PDF, CCR reinterpretation) and the download-time defaults; anything else that means "primary backmount gas" is a miss.

- [ ] **Step 4: Screenshots**

Per the build-feature skill: role dropdown in the dive editor, the Tank configuration card with the note, light and dark, before and after.
