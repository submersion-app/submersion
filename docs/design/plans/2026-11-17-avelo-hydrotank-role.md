# Avelo Hydrotank Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mark the Hydrotank of a Shearwater Avelo-mode dive with a new tank role, and make every calculation that reads cylinder pressure as gas used treat that cylinder's pressure as not measured.

**Architecture:** A libdivecomputer fork patch tags transmitter slot T1 with a new `DC_USAGE_HYDROTANK` (4) in Avelo mode. The existing usage-to-role path in `parsed_tank_resolver.dart` maps it to `TankRole.hydrotank`. A new `TankRole.pressureMeasuresGasUse` getter (Dart) and `gasUseTankSql` (SQL) sit beside `isBreathingGas` / `breathingTankSql`, and every consumption site switches to them; breathing-gas sites keep the old rule.

**Tech Stack:** C (libdivecomputer fork), Flutter/Dart, Drift SQL, Riverpod, ARB l10n.

**Spec:** `docs/design/specs/2026-11-17-avelo-hydrotank-role-design.md` (issue #4657)

## Global Constraints

- No em-dashes anywhere; no AI tool attribution in any commit, PR or comment.
- No schema change, no migration rung. `dive_tanks.tank_role` stays free text; the stored value is `hydrotank`.
- `DC_USAGE_HYDROTANK` is appended after `DC_USAGE_SIDEMOUNT`, numeric value 4.
- A Hydrotank stays in deco, CNS/OTU, gas switches, MOD/MND, gas density, planner and dive lab gas lists.
- A Hydrotank is a backmount cylinder: it joins `backmountRoles` (Dart) and `_backmountRolesSql` (SQL), so it stays the SAC reference.
- New ARB keys go in every locale file. Run `flutter gen-l10n` after ARB edits.
- After any new file under `lib/`, run `test/architecture/` and `test/shared/`.
- Run only the test files being worked on; never a whole feature folder or the suite.
- Pressures shown follow the active diver's pressure unit.

## Review Focus

1. A Hydrotank plus a pony on a normal transmitter: whole-dive SAC blank, pony keeps its per-cylinder SAC and gas used. (Task 5 and Task 6 tests.)
2. An Avelo dive with only a Hydrotank: no SAC anywhere (dive page, insights SAC, trip gas used), and the dive is not flagged by the pressure anomaly detector for its rises. (Tasks 5, 6, 7.)
3. A diver-set role on an Avelo dive's T1 cylinder (pony, stage) survives re-parse; only a stored back gas is upgraded. (Task 3.)
4. An Avelo-mode log whose T1 never read a pressure (transmitter off): no tank tagged, import unchanged. (Task 1.)
5. A hand-set Hydrotank with no pressure series: the editor hides the surface-breathing minutes field, and the cylinders card still shows MOD. (Task 8.)

---

### Task 1: Fork patch, Hydrotank usage in Avelo mode

**Files:**
- Modify: `packages/libdivecomputer_plugin/third_party/libdivecomputer/include/libdivecomputer/parser.h` (`dc_usage_t`)
- Modify: `packages/libdivecomputer_plugin/third_party/libdivecomputer/src/shearwater_predator_parser.c` (cache pass, just before tank compaction)
- Create: `packages/libdivecomputer_plugin/test/native/test_shearwater_avelo_hydrotank.c`, registered in `packages/libdivecomputer_plugin/test/native/CMakeLists.txt`
- Create: `packages/libdivecomputer_plugin/patches/0010-shearwater-avelo-hydrotank-usage.patch`

**Interfaces:**
- Produces: `DC_USAGE_HYDROTANK` (= 4) on the parsed tank fed by transmitter slot T1 when the dive mode byte is `M_AVELO` (12). Reaches Dart as `pigeon.TankInfo.usage == 4` with no binding change.

- [ ] **Step 1: Write the failing native test.** Load `fixtures/petrel3_ccr_o2_cells.bin` (as `test_tank_transmitter_serial.c` does), copy it, and patch the copy into an Avelo log in the test: set opening record 4 byte 1 to 12, and every record whose type byte is `0x01` to `0x03`. Comment each byte offset with how it was found. Tests:
  - `test_avelo_t1_is_hydrotank`: parse the patched copy; the tank whose serial is 123086 has `usage == DC_USAGE_HYDROTANK`.
  - `test_avelo_other_tanks_untouched`: the tank with serial 109623 does not have usage 4. (In Avelo mode T2 reads no pressure, so expect `tank_count == 1`; if so, assert that instead and say why in a comment.)
  - `test_non_avelo_unchanged`: the unpatched fixture's tanks never carry usage 4.
- [ ] **Step 2: Run it and see it fail.** From `packages/libdivecomputer_plugin/test/native`: `cmake -B build && cmake --build build && ctest --test-dir build -R avelo --output-on-failure`. Expected: FAIL (usage is 0) or compile error on the missing enum value.
- [ ] **Step 3: Implement.** Append `DC_USAGE_HYDROTANK` with a `/* Submersion patch (Avelo Hydrotank): ... */` comment. In the cache pass, after the sample loop and before compaction: `if (divemode == M_AVELO && tank[0].active) tank[0].usage = DC_USAGE_HYDROTANK;`. This replaces a sidemount tag from the GTR mode byte, which the comment says.
- [ ] **Step 4: Run the native test and the existing Shearwater native tests** (`ctest --test-dir build --output-on-failure`). Expected: all PASS.
- [ ] **Step 5: Commit in the submodule** on a topic branch `avelo-hydrotank-usage` cut from the current gitlink, then write the `patches/0010-...` file from that commit (`git format-patch -1`), and commit the native test, CMake entry and patch file in the main repo. The gitlink bump waits for Task 9.

### Task 2: The Hydrotank role

**Files:**
- Modify: `lib/core/constants/app_enums.dart` (`TankRole`)
- Modify: `lib/features/dive_log/domain/services/multi_cylinder_consumption.dart` (`backmountRoles`)
- Modify: every exhaustive `switch` on `TankRole` the analyzer reports (at least `tank_enum_display.dart`, `role_consumption.dart`, `tank_mod.dart`, `figure_composer.dart`, conflict enum labels)
- Modify: `lib/l10n/arb/app_*.arb` (all locales)
- Test: `test/core/constants/tank_role_hydrotank_test.dart` (create)

**Interfaces:**
- Produces: `TankRole.hydrotank` (stored name `hydrotank`, display name `'Hydrotank'`); `bool get pressureMeasuresGasUse` on `TankRole`; `backmountRoles == {backGas, twinSet, hydrotank}`; l10n key `enum_tankRole_hydrotank`.

- [ ] **Step 1: Write the failing test.**
  ```dart
  test('hydrotank is breathing gas whose pressure does not measure gas use', () {
    expect(TankRole.hydrotank.isBreathingGas, isTrue);
    expect(TankRole.hydrotank.pressureMeasuresGasUse, isFalse);
    expect(TankRole.suitInflation.pressureMeasuresGasUse, isFalse);
    for (final r in TankRole.values.where((r) => r != TankRole.hydrotank && r != TankRole.suitInflation)) {
      expect(r.pressureMeasuresGasUse, isTrue, reason: r.name);
    }
    expect(TankRole.fromName('hydrotank'), TankRole.hydrotank);
    expect(backmountRoles, contains(TankRole.hydrotank));
  });
  ```
- [ ] **Step 2: Run** `flutter test test/core/constants/tank_role_hydrotank_test.dart`. Expected: FAIL (no `hydrotank`).
- [ ] **Step 3: Implement.** Add `hydrotank('Hydrotank')` after `twinSet` with a doc comment citing issue #4657; add the getter with a doc comment explaining it beside `isBreathingGas`. Add `hydrotank` to `backmountRoles`. Fix each analyzer-reported exhaustive switch: display name `enum_tankRole_hydrotank` ("Hydrotank" in every locale, a product name, kept untranslated), icon the back-gas icon, figure zone the back-gas zone, `consumptionRoleGroupOf` returns null (its rates are pressure-based), MOD check as back gas.
- [ ] **Step 4: Run** the new test, `flutter analyze`, and the existing tests of each file touched in Step 3 (for example `test/features/insights/domain/role_consumption_test.dart`). Expected: PASS, no analyzer issues.
- [ ] **Step 5: Commit** `feat(dive-log): add the Hydrotank tank role`.

### Task 3: Import maps the usage, registry and re-parse precedence

**Files:**
- Modify: `lib/features/dive_computer/data/services/parsed_tank_resolver.dart` (`_inferRole`)
- Modify: `lib/features/dive_computer/data/services/transmitter_registry_matcher.dart` (`applyTransmitterRegistry`)
- Modify: `lib/features/transmitters/data/services/transmitter_tank_fill.dart` (`transmitterFillFor`)
- Modify: `lib/features/dive_computer/data/services/reparse_service.dart` (`roleIsComputers`)
- Test: `test/features/dive_computer/data/services/parsed_tank_resolver_hydrotank_test.dart` (create), `transmitter_registry_matcher_test.dart`, `test/features/transmitters/data/services/transmitter_tank_fill_test.dart`, `test/features/dive_computer/data/services/reparse_service_hydrotank_test.dart` (create, built like `reparse_service_test.dart`)

**Interfaces:**
- Consumes: `TankRole.hydrotank` (Task 2); `TankInfo.usage == 4` (Task 1).

- [ ] **Step 1: Write the failing tests.**
  - resolver: a parsed tank with `usage: 4` resolves to role `'hydrotank'` with `roleSource == null`, whatever its O2 (21 and 50).
  - registry: a tank with role `'hydrotank'` matched by a registry entry whose role is `backGas` keeps `'hydrotank'`; it still takes the entry's name, preset, gear link and size.
  - fill: `transmitterFillFor` on a stored row with role `hydrotank` leaves `tankRole` absent.
  - re-parse: stored T1 row `backGas`, `roleSource` null, parse yields `hydrotank` → stored role becomes `hydrotank`. Stored role `pony` → stays `pony`. Stored `hydrotank` and parse yields `hydrotank` → unchanged. (A diver's hand edit back to `backGas` is upgraded again: the spec's accepted known limit, so no test pins the opposite.)
- [ ] **Step 2: Run** those four test files. Expected: FAIL.
- [ ] **Step 3: Implement.** `_inferRole`: `case 4: // DC_USAGE_HYDROTANK` returns `TankRole.hydrotank.name`. `applyTransmitterRegistry`: when the tank's role is `hydrotank`, keep it and apply the rest of the entry. `transmitterFillFor`: never replace a stored `hydrotank`. `roleIsComputers`: also true when the stored role is `backGas`, the source is null, and this parse's role for that index is `hydrotank`.
- [ ] **Step 4: Run** the four files plus `reparse_service_test.dart` and `parsed_tank_resolver_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-computer): import the Avelo Hydrotank as its own role`.

### Task 4: Shearwater Cloud import

**Files:**
- Modify: `lib/features/universal_import/data/services/shearwater_transmitter_serials.dart` (`withTransmitterSerials`)
- Test: `test/features/universal_import/data/services/shearwater_transmitter_serials_test.dart`

**Interfaces:**
- Consumes: `TankInfo.usage == 4`; `TankRole.hydrotank`. Uses whatever key the Cloud tank maps already use for the role downstream (check `mapTanks` consumers; if none, the key the generic tank import reads, `'role'`).

- [ ] **Step 1: Write the failing tests.** A metadata tank paired (in slot order, and by unique start pressure) with a parsed tank of `usage: 4` gets the Hydrotank role; a paired tank of `usage: 0` gets none; an unpaired metadata tank gets none even when a parsed tank has usage 4.
- [ ] **Step 2: Run** the file. Expected: FAIL.
- [ ] **Step 3: Implement** the role alongside `'transmitterSerial'` in the paired branch; rename the function only if its doc comment no longer fits (then update its callers).
- [ ] **Step 4: Run** the file and `shearwater_dive_mapper_profile_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(universal-import): carry the Avelo Hydrotank through Shearwater Cloud import`.

### Task 5: Dart consumption treats a Hydrotank as unmeasured

**Files (each site switches from `isBreathingGas` to `pressureMeasuresGasUse` only where it reads pressure as gas used):**
- `lib/features/dive_log/domain/services/multi_cylinder_consumption.dart` (`referencePressureDrop`: a reference whose pressure does not measure gas use returns null; another such cylinder adds nothing. `breathingTanks` and `sacReferenceTankOf` keep `isBreathingGas`)
- `lib/features/dive_log/data/services/gas_analysis_service.dart:403` (no per-cylinder SAC or gas used)
- `lib/features/dive_log/data/repositories/derived_metrics_repository.dart:125` (no SAC drift blob)
- `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart:94` (`combineMultiTankPressures`: series left out, which also blanks the app's GTR and SAC curve)
- `lib/features/trips/data/repositories/trip_cylinder_repository.dart:740` (`breathing` false, so no litres)
- `lib/features/dive_log/presentation/widgets/tank_editor.dart:177` (no surface-breathing minutes)
- Keep `isBreathingGas` at every other site listed in the spec's sort; the commit message lists them.
- Test: `test/features/dive_log/domain/services/multi_cylinder_consumption_hydrotank_test.dart` (create), `test/features/dive_log/data/services/gas_analysis_hydrotank_test.dart` (create, modelled on `gas_analysis_suit_inflation_test.dart`), `derived_metrics_repository_test.dart`, the existing `combineMultiTankPressures` test file, `trip_gas_record_builder_test.dart` or `trip_cylinder_repository_test.dart`, `tank_editor_test.dart`

**Interfaces:**
- Consumes: `TankRole.pressureMeasuresGasUse`, `backmountRoles` (Task 2).

- [ ] **Step 1: Write the failing tests.**
  - `referencePressureDrop` with a Hydrotank (10 L, 200 to 185 bar) as reference and a pony (3 L, 200 to 170) returns null; `sacReferenceTankOf` returns the Hydrotank.
  - gas analysis on that dive: the pony has a per-cylinder SAC, the Hydrotank has none; on a Hydrotank-only dive, no SAC.
  - derived metrics: a Hydrotank's series is not a tank blob.
  - `combineMultiTankPressures` with only a Hydrotank series returns null.
  - trip: a Hydrotank row has `breathing == false`.
  - tank editor: role Hydrotank, no pressure series → surface-breathing field absent; MOD row present.
- [ ] **Step 2: Run** those files. Expected: FAIL.
- [ ] **Step 3: Implement** the switches above, each with a one-line comment citing issue #4657.
- [ ] **Step 4: Run** the files, plus `multi_cylinder_consumption_test.dart`, `gas_analysis_suit_inflation_test.dart`, `range_gas_consumption_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-log): keep Hydrotank pressure out of gas consumption`.

### Task 6: SQL consumption mirrors the Dart rule

**Files:**
- Modify: `lib/features/dive_log/data/sql/multi_cylinder_sac_sql.dart`: add `'hydrotank'` to `_backmountRolesSql`; add `String gasUseTankSql(String alias)` (excludes `suitInflation` and `hydrotank`, keeps NULL roles); use it in `diveSacPressureSql`'s `cylinders(...)` so a Hydrotank reference never joins `measured`
- Modify: `lib/features/dive_log/data/sql/gas_use_sql.dart` (`_surfaceSeconds`, both aliases)
- Modify: `lib/features/insights/data/repositories/insights_repository.dart:439` and `:651`, `insights_repository_focus_series.dart:85` (SAC rows); keep `breathingTankSql` at the gas-type, gas-class, first-volume, role-consumption-dive-list, chart-dive and trip-unlinked sites
- Test: `test/features/insights/data/repositories/insights_repository_hydrotank_test.dart` (create, modelled on `insights_repository_suit_inflation_test.dart`), plus the existing test that covers `diveSacPressureSql` (find with `grep -rl diveSacPressureSql test`)

**Interfaces:**
- Produces: `gasUseTankSql(String alias)`.

- [ ] **Step 1: Write the failing tests.** In an in-memory database: a dive with a Hydrotank and a pony has NULL SQL SAC, and Dart `Dive.sac` agrees; a Hydrotank-only dive is absent from the insights SAC rows; a pony on that dive still appears in per-cylinder SAC rows.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** as listed.
- [ ] **Step 4: Run** the new file, the `diveSacPressureSql` test, and `insights_repository_suit_inflation_test.dart`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(insights): leave Hydrotank pressure out of SAC statistics`.

### Task 7: Pressure anomaly detector

**Files:**
- Modify: `lib/features/data_quality/domain/detectors/pressure_anomaly_detector.dart` (skip the rise and implausible-consumption checks for a tank whose role does not measure gas use; keep the mixed-source, glitch and endpoint checks; `version` 6 to 7 with a comment)
- Test: `test/features/data_quality/domain/detectors/pressure_anomaly_detector_hydrotank_test.dart` (create, modelled on `suit_inflation_detectors_test.dart`)

- [ ] **Step 1: Write the failing test.** A Hydrotank series that rises 20 bar mid-dive (pump-in) and falls again yields no `rise:` finding and no consumption finding; the same series on a back-gas tank still yields the rise finding.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the new file and the existing pressure anomaly tests. Expected: PASS.
- [ ] **Step 5: Commit** `fix(data-quality): do not flag Hydrotank pumping as a pressure rise`.

### Task 8: Cylinders card and screenshots

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/cylinders_card.dart` (gas used and SAC gated on `pressureMeasuresGasUse`; MOD and MND stay on `isBreathingGas`; a Hydrotank shows the line `diveLog_cylinders_hydrotankNote`)
- Modify: every `lib/l10n/arb/app_*.arb` (`diveLog_cylinders_hydrotankNote`: "Hydrotank pressure does not measure gas used", translated per locale)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (`tankTooltipLabel(DiveTank? tank, String fallbackLabel)`: callers pass the localized role name as the fallback for an unnamed Hydrotank instead of "Tank N") and the pinned strip's `tankLabel` in `pinned_profile/layers/strip_layer_sources.dart`'s caller, so the pressure line reads "Hydrotank (Air)"
- Test: `test/features/dive_log/presentation/widgets/cylinders_card_hydrotank_test.dart` (create, modelled on `cylinders_card_suit_inflation_test.dart`); the existing `tankTooltipLabel` test (find with `grep -rl tankTooltipLabel test`)

- [ ] **Step 1: Before screenshots** (before any `lib/` change in this plan, so take them right after Task 1): a dev-DB dive with a back-gas cylinder showing SAC on the cylinders card, and the tank editor's role picker. Light mode, desktop width.
- [ ] **Step 2: Write the failing widget test.** A Hydrotank cylinder shows its role, start and end pressure, MOD, and the note; no gas-used or SAC text; a pony on the same dive shows its SAC. An unnamed Hydrotank's pressure tooltip label is "Hydrotank (Air)"; a named one keeps its name.
- [ ] **Step 3: Run.** Expected: FAIL.
- [ ] **Step 4: Implement**, then `flutter gen-l10n`.
- [ ] **Step 5: Run** the new file, `cylinders_card_test.dart`, `cylinders_card_suit_inflation_test.dart`, `test/architecture/`, `test/shared/`. Expected: PASS.
- [ ] **Step 6: After screenshots** of the same screens with the cylinder set to Hydrotank.
- [ ] **Step 7: Commit** `feat(dive-log): show the Hydrotank on the cylinders card`.

### Task 9: Land the fork patch

- [ ] **Step 1:** Push the submodule topic branch to `submersion-app/libdivecomputer` and open a PR into `submersion-patches`.
- [ ] **Step 2:** Merge it with a merge commit (never squash or rebase).
- [ ] **Step 3:** Bump the gitlink to that merge commit; `git merge-base --is-ancestor <old pin> <new pin>` must succeed (the CI gitlink ancestry gate).
- [ ] **Step 4:** Rebuild the macOS app and rerun the native tests. Commit `build(libdc): pin the Avelo Hydrotank usage patch`.

## Appendix: the call-site sort (as built)

Every place that checked for a suit inflation bottle, sorted by what it reads. "Gas use" sites moved to `pressureMeasuresGasUse`, `gasUseTankSql` or the whole-dive guard `breathesUnmeasuredTank` / `diveBreathesUnmeasuredTankSql`; "breathing" sites keep `isBreathingGas` / `breathingTankSql`, so a Hydrotank stays in them.

**Gas use (a Hydrotank's pressure counts as not measured)**
- `multi_cylinder_consumption.dart` `referencePressureDrop`; `dive.dart` `Dive.rmvFor` (whole dive blank)
- `gas_analysis_service.dart` cylinder SAC loop and `_calculateSegmentSac`
- `derived_metrics_repository.dart` SAC drift blobs (none when a Hydrotank is breathed)
- `profile_analysis_provider.dart` `combineMultiTankPressures` (SAC curve, app GTR)
- `range_gas_consumption.dart` (range panel SAC and RMV)
- `dive_field_extractor.dart` `_computeGasConsumed` (Gas consumed field, exports)
- `sac_segments_availability.dart` (no false "no pressure recorded" note)
- `trip_cylinder_repository.dart` / `trip_gas_record_builder.dart` (`measuresGasUse`)
- `tank_editor.dart` surface-breathing minutes
- `estimated_tank_pressure_synthesizer.dart` (no estimated line)
- `gas_switch_time_suggestions.dart` `hasBreathingStarts`; `tank_assignment_detector.dart` inactive-drop check; `pressure_anomaly_detector.dart` rise, swap and consumption checks
- `cylinders_card.dart` gas used, loop use, SAC, Used label; `pdf_template_detailed.dart` pressure used; `plan_source_dive_compare_strip.dart` actual gas
- SQL: `diveSacPressureSql`, `gas_use_sql.dart` `_surfaceSeconds`, insights SAC-in-litres (dive left out), `getGasUsedPerDive`

**Breathing (a Hydrotank stays in)**
- deco and gas: `_selectOcPrimaryTank`, `buildAvailableGases`, `breathing_gas_switches.dart`, `ccr_*`, `tank_usage_range.dart`, `gas_switch_writes.dart`, `gas_switches_editor.dart`, `tank_mod.dart`, cylinders card MOD/MND and MOD note
- planner and dive lab: `plan_breathing_tanks.dart`, `dive_planner_providers.dart`, `plan_saved_tanks_bar.dart`, `dive_snapshot.dart`, `lab_request_inputs_provider.dart`, `dive_plan_fields.dart`
- classification and identity: `counted_cylinders.dart`, `tank_configuration_classifier.dart`, `sequential_tank_merge.dart`, `dive_consolidation_builder.dart`, `transmitter_role_detector.dart`, `trip_cylinder_tank_link.dart`
- SQL: `breathingTankSql` in gas mix, gas class, first volume, role-consumption dive list, chart dives, trip unlinked tanks, max O2/He, `sacReferenceIdSql`

**Registry**: `transmitter_registry_matcher.dart`, `transmitter_tank_fill.dart`, `transmitter_auto_registrar.dart` and `transmitter_repository.dart` `lastRoleForEquipment` never carry a dive's Hydrotank role into the per-transmitter registry.
