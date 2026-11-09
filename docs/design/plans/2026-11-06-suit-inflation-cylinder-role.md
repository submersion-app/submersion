# Suit Inflation Cylinder Role Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Suit Inflation tank role and equipment marking, and keep every
suit inflation cylinder out of every breathing gas calculation while still
listing it on the dive.

**Architecture:** One rule (`TankRole.isBreathingGas`), one Dart filter
(`breathingTanks`), one switch re-target (`breathingGasSwitches`) and one SQL
predicate (`breathingTankSql`). Each calculation applies them where it starts,
not leaf by leaf. Plans never hold the role, so the planner changes only at
its entry points.

**Tech Stack:** Flutter, Dart, Riverpod, Drift (SQLite), ARB localization.

**Spec:** `docs/design/specs/2026-11-06-suit-inflation-cylinder-role-design.md`

## Global Constraints

- No schema change. The role is stored by name (`suitInflation`), and the
  equipment marking is a choice attribute in `equipment_attributes`.
- Enum value `TankRole.suitInflation('Suit Inflation')`; SQL literal
  `'suitInflation'`.
- The SQL predicate is NULL-safe:
  `(<alias>.tank_role IS NULL OR <alias>.tank_role <> 'suitInflation')`.
- Equipment attribute key `cylinder_use`, choices `breathing_gas` and
  `suit_inflation`; unset means breathing gas.
- New strings go in all 11 ARB files under `lib/l10n/arb/` (ar, de, en, es,
  fr, he, hu, it, nl, pt, zh); run `flutter gen-l10n`.
- Physical uses keep the suit cylinder: buoyancy and gas weight, fills,
  inventory, service. Breathed-gas uses drop it.
- No em-dashes anywhere. Files at most 800 lines. Paths are built with `p.join`.
- Before each commit: `dart format .`, `flutter analyze`, and the touched
  test directories. After adding a `lib/` file, also run `test/architecture/`
  and `test/shared/`.

## Review Focus

1. **A dive whose only cylinder is the suit bottle.** No SAC, no RMV, no gas
   class, tank configuration "no tanks", no crash in any analysis that used
   `tanks.first`. Pinned in Tasks 3, 4, 5 and 8.
2. **The suit bottle listed first, with a pressure drop, on a sidemount dive
   (no backmount role).** It must not become the SAC reference, the starting
   gas, or the isolate's starting fractions. Pinned in Tasks 3 and 5.
3. **A downloaded switch to an air suit bottle after a deco gas.** It is
   re-targeted to the air back gas, so deco does not stay on the deco mix.
   Pinned in Tasks 2 and 5.
4. **A CCR dive with untagged loop gas and an argon bottle.** The bottle is
   never chosen as the diluent and never counts as a bailout. Pinned in Task 5.
5. **Tanks with a NULL `tank_role` in SQL.** They still count after the
   predicate is added. Pinned in Task 4.

---

### Task 1: The role, the rule, and every exhaustive switch

**Files:**
- Modify: `lib/core/constants/app_enums.dart` (TankRole)
- Modify: `lib/features/dive_log/domain/services/multi_cylinder_consumption.dart`
- Modify: `lib/features/dive_log/domain/entities/dive.dart`
- Modify: `lib/features/dive_log/data/sql/multi_cylinder_sac_sql.dart`
- Modify: `lib/features/dive_log/presentation/widgets/tank_enum_display.dart`
- Modify: `lib/features/equipment/figure/domain/figure_composer.dart`
- Modify: `lib/features/planner/domain/services/tank_mod.dart`
- Modify: `lib/features/insights/presentation/pages/insights_gas_page.dart`
- Modify: `lib/features/planner/data/repositories/dive_plan_repository.dart:1047`
- Modify: ARB files (`enum_tankRole_suitInflation` = "Suit Inflation",
  `insights_gas_tankRole_suitInflation` = "Suit")
- Test: `test/features/dive_log/domain/services/breathing_tanks_test.dart` (new)
- Test: existing role enumerating tests (`tank_role_icon_test.dart`,
  `tank_editor_role_icon_test.dart`, `conflict_labels_complete_test.dart`,
  `conflict_enum_labels_test.dart`, `cylinder_config_item_editor_test.dart`,
  `test/l10n/kept_english_values.dart`) updated for the new value.

**Interfaces:**
- Produces: `TankRole.suitInflation`; `extension on TankRole { bool get isBreathingGas }`
  (in `app_enums.dart`, false only for `suitInflation`);
  `List<DiveTank> breathingTanks(List<DiveTank> tanks)` in
  `multi_cylinder_consumption.dart` (order kept);
  `List<DiveTank> get breathingTanks` on `Dive`;
  `String breathingTankSql(String alias)` in `multi_cylinder_sac_sql.dart`.

- [ ] **Step 1: Write the failing tests**

```dart
test('suit inflation is the only role that is not breathing gas', () {
  for (final role in TankRole.values) {
    expect(role.isBreathingGas, role != TankRole.suitInflation);
  }
});
test('breathingTanks drops suit cylinders and keeps order', () {
  final suit = tank('s', role: TankRole.suitInflation);
  final a = tank('a', role: TankRole.sidemountLeft);
  final b = tank('b', role: TankRole.sidemountRight);
  expect(breathingTanks([suit, a, b]), [a, b]);
});
test('breathingTankSql keeps NULL roles', () {
  expect(breathingTankSql('t'),
      "(t.tank_role IS NULL OR t.tank_role <> 'suitInflation')");
});
test('a saved plan with an unknown role loads as back gas', ...);
```

- [ ] **Step 2: Run, expect FAIL** (`flutter test test/features/dive_log/domain/services/breathing_tanks_test.dart`: `suitInflation` undefined).
- [ ] **Step 3: Implement.**
  - Add the enum value and the getter.
  - Icon arm `SubmersionIcons.tankPony`. Figure zones are the same as pony (stage left/right). `usesDecoLimit` returns false.
  - Insights label arm: `'suitInflation' => l10n.insights_gas_tankRole_suitInflation`.
  - The plan repository parses with `TankRole.values.where((r) => r.name == t.role).firstOrNull ?? TankRole.backGas`.
  - Add the ARB keys and run `flutter gen-l10n`.
- [ ] **Step 4: Run the new test and the enumerating tests; expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): add the Suit Inflation tank role`.

### Task 2: Gas switches re-targeted off suit cylinders

**Files:**
- Create: `lib/features/dive_log/domain/services/breathing_gas_switches.dart`
- Test: `test/features/dive_log/domain/services/breathing_gas_switches_test.dart`

**Interfaces:**
- Consumes: `breathingTanks`, `sacReferenceTankOf`, `sameGasTolerancePct`.
- Produces:
  `List<GasSwitchWithTank> breathingGasSwitches(List<GasSwitchWithTank> switches, List<DiveTank> tanks)`
  and `List<GasSwitch> breathingRawGasSwitches(List<GasSwitch> switches, List<DiveTank> tanks)`.
  - A switch whose tank is a breathing tank, or is not in [tanks], is kept unchanged.
  - A switch whose tank is a suit cylinder gets `tankId` set to the first breathing tank whose mix is within `sameGasTolerancePct` of the suit tank's mix, with the SAC reference tank preferred when it matches. The `GasSwitchWithTank` also takes that tank's name and mix fields.
  - With no match, the switch is dropped.

- [ ] **Step 1: Failing tests:** `re-targets an air suit switch to the air back gas`; `prefers the SAC reference tank among several matches`; `drops a suit switch with no breathing tank on its mix`; `leaves breathing switches untouched`; `leaves switches on unknown tanks untouched`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement both functions.** The raw form reads the suit tank's mix from [tanks]; the `WithTank` form maps over it.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): move gas switches off suit inflation cylinders`.

### Task 3: Dart consumption (SAC, RMV, ranges, usage windows, export)

**Files:**
- Modify: `multi_cylinder_consumption.dart`: `sacReferenceTankOf` and `referencePressureDrop` filter with `breathingTanks` internally. Every caller is then covered.
- Modify: `dive.dart`: `rmvFor` and `sac` loop over and guard on `breathingTanks`, not `tanks`.
- Modify: `range_gas_consumption.dart`, `gas_usage_segments_service.dart`, `tank_usage_range.dart` (`startingTankOf`, `tankUsageWindows` use breathing tanks; a single-tank dive whose tank is suit gets no window).
- Modify: `lib/core/constants/dive_field_extractor.dart:93-101,236-258`: first breathing tank, and gas consumed over breathing tanks.
- Modify: `derived_metrics_service.dart` `_referenceTank`: breathing tanks only.
- Test: add to the existing tests of each file (`multi_cylinder_consumption_test.dart`, `dive_sac_test.dart` or the file holding `Dive.sac` tests, `range_gas_consumption_test.dart`, `tank_usage_range_test.dart`, `dive_field_extractor_test.dart`, `derived_metrics_service_test.dart`).

- [ ] **Step 1: Failing tests.** Each file gets: `a suit cylinder listed first with a 50 bar drop changes nothing` (result equal to the same dive without it) and `a dive whose only tank is suit has no SAC/RMV/gas consumed` (null).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement as listed.**
- [ ] **Step 4: Run `flutter test test/features/dive_log/domain test/core/constants test/features/explore`, expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): leave suit inflation cylinders out of SAC and gas used`.

### Task 4: SQL consumption and statistics

**Files:**
- Modify: `multi_cylinder_sac_sql.dart` `diveSacPressureSql`: `breathingTankSql('sac_t')` in `cylinders(...)`, plus `breathingTankSql('t2')` and `breathingTankSql('t3')` in the reference choice.
- Modify: `lib/features/insights/data/repositories/insights_repository.dart`:
  - `getSacVolumePerDive`
  - `getGasMixDistribution`
  - `getSacVolumeRecords`
  - `getSacVolumeByTankRole`
  - `getSacPressureByTankRole`
  
  Add the predicate to every `dive_tanks` join used for gas.
- Modify: `insights_repository_focus_series.dart` (`getGasUsedPerDive`), `insights_repository_focus.dart` (`gas_class`, `first_tank_volume`), `insights_repository_chart_dives.dart` (`_gasTypeSql`), `insights/data/tank_configuration_sql.dart` (the tank rows it feeds the classifier).
- Modify: `dive_repository_impl.dart:3344-3347` (`max_o2`/`max_he`), `dive_filter_query.dart:78-86` (O2 filter), `dive_word_meanings.dart:247-258` (gas words).
- Test: the existing SQL tests for each (`multi_cylinder_sac_sql_test.dart`, `insights_repository_*_test.dart`, `tank_configuration_sql_test.dart`, the query-language tests) on an in-memory database.

- [ ] **Step 1: Failing tests:**
  - `suit cylinder adds nothing to SQL SAC`: the dive's SQL SAC equals `Dive.sac` from Task 3, with the suit row first.
  - `suit-only dive has NULL SAC and no gas class`.
  - `a NULL tank_role row still counts`.
  - `SAC by role has no suitInflation bucket`.
  - `an argon bottle logged as 21% does not make a trimix dive an Air dive`.
  - `"air" query word ignores the suit bottle`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Interpolate `breathingTankSql(alias)` into each WHERE/ON.
- [ ] **Step 4: Run `flutter test test/features/insights test/features/dive_log/data test/features/dive_log/query`, expect PASS.**
- [ ] **Step 5: Commit** `feat(insights): leave suit inflation cylinders out of gas statistics`.

### Task 5: Profile analysis, per-cylinder SAC, CCR

**Files:**
- Modify: `gas_analysis_providers.dart` `_segmentInputs`: `tanks: breathingTanks(...)` and `gasSwitches: breathingGasSwitches(...)` on both branches.
- Modify: `profile_analysis_provider.dart`:
  - Where the analysed `tanks` list is built (around :1296-1301), wrap it in `breathingTanks`.
  - Re-target the switches before `scopedGasSwitches`.
  - The isolate fractions at :1372-1377 and :2157-2162 read the first breathing tank.
  - `combineMultiTankPressures` receives breathing tanks only.
  - Per-tank logged pressure lines still draw for the suit tank.
- Modify: `gas_analysis_service.dart` `calculateCylinderSac`: skip a non-breathing tank, and use the first breathing tank as the fallback in `calculateGasSwitchSegments`. `gas_analysis_service_ccr.dart`: no row for a suit tank.
- Modify: `ccr_cylinder_use.dart` `ccrDiveUse`: skip non-breathing tanks. `ccr_gas_schedule.dart` `classifyCcrGasChanges`: ignore a change to a non-breathing tank. `ccr_bailout_timeline.dart` `openCircuitTargetRole`: never maps a suit role to bailout. `profile_analysis_provider.dart` `resolveCcrDiluentMix`: skip suit tanks.
- Modify: `estimated_tank_pressure_synthesizer.dart`: no series for a non-breathing tank.
- Modify: `insights_repository_ccr_gas_use.dart:61`: pass breathing tanks.
- Test: existing `profile_analysis_provider_*_test.dart`, `gas_analysis_service_test.dart`, `ccr_*_test.dart`, `estimated_tank_pressure_synthesizer_test.dart`.

- [ ] **Step 1: Failing tests:**
  - `sidemount dive with the suit bottle first starts on the sidemount mix`.
  - `deco schedule unchanged by a suit cylinder` (compare ceilings and CNS with and without).
  - `downloaded switch to air suit bottle after EAN50 re-targets to back gas`.
  - `suit tank gets no cylinder SAC row`.
  - `CCR untagged loop gas never resolves to the argon bottle`.
  - `argon pressure drop is not diluent use`.
  - `suit tank gets no estimated series`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement as listed.**
- [ ] **Step 4: Run `flutter test test/features/dive_log`, expect PASS.**
- [ ] **Step 5: Commit** `feat(dive-log): keep suit inflation cylinders out of deco, oxygen exposure and CCR gas`.

### Task 6: Planner never holds a suit cylinder

**Files:**
- Modify: `dive_to_plan_converter.dart` `_mapTanks` and `usedTankIds`: drop non-breathing tanks. Also drop segments and switches that pointed at one; Task 2's re-target runs first.
- Modify: `dive_planner_providers.dart`:
  - `addTank(DiveTank)` returns `bool`, false and no change for a suit tank.
  - `loadPlan` strips suit tanks.
  - `updateTank` refuses a change to the suit role.
- Modify: `plan_saved_tanks_bar.dart`: saved cylinders with the suit role are not listed. When a configuration is applied, the rest is added and a SnackBar shows `planner_suitCylinderLeftOut` ("The suit inflation cylinder was left out: plans hold breathing gas only.").
- Modify: `plan_file_codec.dart`: strip on import.
- Modify: `agent_access/.../dive_plan_writes.dart`: validation rejects `suitInflation` as a plan tank role with a clear error.
- Modify: ARB `planner_suitCylinderLeftOut`.
- Test: `dive_to_plan_converter_test.dart`, `dive_planner_providers_test.dart`, `plan_saved_tanks_bar_test.dart`, `plan_file_codec_test.dart`, `dive_plan_writes_test.dart`.

- [ ] **Step 1: Failing tests:** `What-if leaves the suit bottle out`; `addTank refuses a suit tank`; `loadPlan strips a suit tank`; `saved suit cylinder is not offered`; `config with a suit cylinder adds the rest and shows the SnackBar`; `agent plan write rejects suitInflation`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Plan the rest of the configuration as usual.
- [ ] **Step 4: Run `flutter test test/features/planner test/features/dive_planner test/features/agent_access`, expect PASS.**
- [ ] **Step 5: Commit** `feat(planner): keep suit inflation cylinders out of plans`.

### Task 7: Dive Lab

**Files:**
- Modify: `tank_schedule.dart` `TankSchedule.fromDive`: build from `breathingTanks(dive.tanks)` and the re-targeted switches.
- Modify: `scenario_engine.dart:59-70,515-520`, `lab_add_intervention_sheet.dart` (tank lists), `scenario_plan_handoff.dart:136-150`, `lab_delta_panel.dart:115-118`: read breathing tanks.
- Test: `tank_schedule_test.dart`, `scenario_engine_test.dart`.

- [ ] **Step 1: Failing tests:** `suit bottle is never the primary, best tank or lost-tank candidate`; `consumption pass has no counter for it`.
- [ ] **Step 2: Run, expect FAIL.** **Step 3: Implement.** **Step 4: `flutter test test/features/dive_lab`, PASS.**
- [ ] **Step 5: Commit** `feat(dive-lab): leave suit inflation cylinders out of scenarios`.

### Task 8: Insights tank configuration, trips, split-dive merge

**Files:**
- Modify: `tank_configuration_classifier.dart`: classify `breathingTanks(tanks)`. If none, the result is `noTanks`.
- Modify: `trip_gas_record_builder.dart`: breathed litres and gas totals skip a non-breathing tank. `fill_forecast.dart` is unchanged.
- Modify: `sequential_tank_merge.dart:129-140`: a suit tank merges only with a suit tank.
- Test: `tank_configuration_classifier_test.dart`, `trip_gas_record_builder_test.dart`, `fill_forecast_test.dart` (pins that fills still count), `sequential_tank_merge_test.dart`.

- [ ] **Step 1: Failing tests:** `suit bottle adds no multiGas`; `suit-only dive is noTanks`; `trip breathed litres skip the suit bottle`; `fill forecast still counts it`; `air suit bottle does not merge into air back gas`.
- [ ] **Step 2-4:** as above, `flutter test test/features/insights test/features/trips test/features/dive_log/domain`.
- [ ] **Step 5: Commit** `feat(insights): classify tank configurations without suit inflation cylinders`.

### Task 9: Data quality and download cleanup

**Files:**
- Modify: `gas_mod_detector.dart`: start from the first breathing tank and re-targeted switches.
- Modify: `gas_switch_time_suggestions.dart` `hasBreathingStarts`: exclude non-breathing.
- Modify: `tank_assignment_detector.dart`, `transmitter_role_detector.dart`, `quality_context_builder.dart`: a suit tank is neither loop nor OC gas.
- Modify: `bailout_gas_claim.dart`, `unused_oc_gas_cleanup.dart`, `transmitters/data/services/bailout_mix_fixer.dart`: a suit tank is never claimed, removed or re-mixed.
- Test: each detector's and service's existing test file.

- [ ] **Step 1: Failing tests:**
  - `suit bottle first does not raise a hypoxic finding`.
  - `no switch-time suggestion for a suit tank`.
  - `bailout claim skips the suit tank`.
  - `unused OC cleanup keeps the suit tank`.
  - `bailout mix fixer leaves the suit tank`.
- [ ] **Step 2-4:** `flutter test test/features/data_quality test/features/dive_computer test/features/transmitters`.
- [ ] **Step 5: Commit** `feat(data-quality): treat suit inflation cylinders as non-breathing`.

### Task 10: Dive edit and dive detail UI

**Files:**
- Modify: `logged_tank_mod.dart` `loggedTankModLimit`: null for a non-breathing tank, so the tank editor and cylinders card show no MOD.
- Modify: `gas_switches_editor.dart:266`: the target dropdown lists breathing tanks only.
- Modify: `cylinders_card.dart`: a suit tank shows its role chip and pressures, with no SAC, MOD or gas-used figure.
- Test: `cylinders_card_test.dart`, `gas_switches_editor_test.dart`, `tank_editor_test.dart` (the role dropdown offers Suit Inflation with the pony glyph).

- [ ] **Step 1: Failing widget tests** for each item above.
- [ ] **Step 2-4:** `flutter test test/features/dive_log/presentation`.
- [ ] **Step 5: Commit** `feat(dive-log): show suit inflation cylinders on the dive without gas figures`.

### Task 11: Equipment Cylinder use attribute and its defaults

**Files:**
- Modify: `equipment_attribute_catalog.dart`: tank attribute `EquipmentAttributeDef(key: 'cylinder_use', kind: AttributeKind.choice, choiceKeys: ['breathing_gas', 'suit_inflation'])`, plus `EquipmentAttrKeys.cylinderUse`.
- Modify: `equipment_attribute_l10n.dart` and the ARB files:
  - `attrLabel_cylinder_use` "Cylinder use"
  - `attrChoice_cylinder_use_breathing_gas` "Breathing gas"
  - `attrChoice_cylinder_use_suit_inflation` "Suit inflation"
- Modify: `equipment_item.dart`: `bool get isSuitInflationCylinder` reads the attribute.
- Modify: `tank_editor.dart` `_useOwnCylinder`: when `item.isSuitInflationCylinder`, set the role to Suit Inflation.
- Modify: `transmitter_edit_page.dart` `_applyGear`: when the linked cylinder is marked suit, the role field becomes Suit Inflation, ahead of the history suggestion.
- Test: `equipment_attribute_catalog_test.dart`, the filter sheet test (the Tank choices include Cylinder use), `tank_editor_test.dart`, `transmitter_edit_page_test.dart`.

- [ ] **Step 1: Failing tests:** `tank catalog has cylinder_use`; `filter sheet offers Cylinder use for Tank`; `picking a suit-marked cylinder sets the role`; `linking a suit-marked cylinder sets the transmitter role`.
- [ ] **Step 2-4:** `flutter test test/features/equipment test/features/transmitters test/features/dive_log/presentation/widgets`.
- [ ] **Step 5: Commit** `feat(equipment): mark a cylinder as a suit inflation bottle`.

### Task 12: Subsurface import

**Files:**
- Modify: `subsurface_xml_parser.dart` `_mapTankRole`: `'not used'` maps to `TankRole.suitInflation`.
- Test: `subsurface_xml_parser_test.dart`.

- [ ] **Step 1: Failing test** `cylinder use="not used" imports as Suit Inflation`. **Steps 2-4** as usual. **Step 5: Commit** `feat(file-import): read Subsurface's not-used cylinder as suit inflation`.

### Task 13: Sweep and final checks

- [ ] **Step 1:** `grep -rn "dive.tanks\|plan.tanks\|\.tanks\.first\|JOIN dive_tanks" lib` and check each hit that computes breathed gas against the spec's split. Any new site gets its fix and test here, and is listed for the PR.
- [ ] **Step 2:** `dart format .`, then `flutter analyze` on the whole repo (expect no issues).
- [ ] **Step 3:** `flutter test test/architecture test/shared test/l10n`, expect PASS.
- [ ] **Step 4:** Run every touched test directory once more together, expect PASS.
- [ ] **Step 5: Commit** any sweep fixes as `fix(dive-log): <site> skips suit inflation cylinders`.
