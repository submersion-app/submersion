# Counterfactual Dive Lab Phase 4 (Extras: CCR Bailout, Ascent Policy, Buoyancy) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose the two remaining intervention kinds in the lab UI (bail out to open circuit on CCR/SCR dives, ascent-policy tweaks) and add buoyancy rows to the delta panel by running the buoyancy twin over the counterfactual profile.

**Architecture:** The Phase 1 engine already compiles and replays `BailOutIntervention` and `AscentPolicyIntervention`; this phase adds their editors to `LabAddInterventionSheet` and their availability rules. Buoyancy: a new `labBuoyancyProvider(diveId)` builds two `TwinInput`s with `BuoyancyTwinAssembler` (actual = hydrated dive + measured pressures; counterfactual = the same rig over `ScenarioOutcome.counterfactualDepths/Timestamps` with per-tank start/end from `ScenarioConsumption`), runs `runBuoyancyTwin` under `compute`, and the panel renders a buoyancy section (net at the anchor, peak lift demand, min ditchable lead; actual | what-if | delta) plus `TwinSummaryRows` style tiles.

**Tech Stack:** existing `lib/core/buoyancy` twin, `BuoyancyTwinAssembler.composeRigTerms`, `weightCalibrationProvider`, `latestDiverWeightProvider`, Riverpod, l10n (11 locales).

**Spec:** `docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md` (intervention table rows `bailOut` and `ascentPolicy`; delta metrics "buoyancy: net at the last stop, peak lift demand, min ditchable lead"; Phase 4 row).

## Global Constraints

Same as Phases 2-3 (worktree, absolute paths, no em-dashes, format/analyze clean, l10n in all 11 ARBs, local commits only).

## File structure

```
lib/features/dive_lab/presentation/widgets/lab_add_intervention_sheet.dart   (modify: bailOut + ascentPolicy kinds and editors)
lib/features/dive_lab/presentation/providers/lab_buoyancy_provider.dart      (new: BuoyancyComparison + labBuoyancyProvider + pure buildCounterfactualTwinInput)
lib/features/dive_lab/presentation/widgets/lab_delta_panel.dart             (modify: buoyancy section)
lib/features/dive_lab/presentation/pages/dive_lab_page.dart                  (modify: pass the buoyancy comparison to the panel)
lib/l10n/arb/*.arb (+ generated)
test/features/dive_lab/presentation/widgets/lab_add_intervention_sheet_extras_test.dart
test/features/dive_lab/presentation/providers/lab_buoyancy_provider_test.dart
test/features/dive_lab/presentation/widgets/lab_delta_panel_buoyancy_test.dart
```

---

### Task 1: l10n keys

`diveLab_panel_buoyancy` (Buoyancy), `diveLab_buoyancy_netAtStop` (Net buoyancy at the stop), `diveLab_buoyancy_peakLift` (Peak lift demand), `diveLab_buoyancy_minDitchable` (Min ditchable lead), `diveLab_buoyancy_unavailable` (Buoyancy needs tanks or an exposure suit on the dive.), `diveLab_sheet_ascentRate` (Ascent rate ({unit}/min)), `diveLab_sheet_lastStop` (Last stop depth), `diveLab_sheet_extraLastStop` (Extend the last stop (min)), `diveLab_sheet_gasSwitchStop` (Gas-switch stop (s)), `diveLab_sheet_bailoutTank` (Bailout cylinder), `diveLab_sheet_allBailout` (All bailout cylinders). Translate into the other 10 locales; `flutter gen-l10n`; commit `feat(dive-lab): strings for bailout, ascent policy and buoyancy`.

### Task 2: Sheet kinds + editors

- `kLabPhase2Kinds` becomes `kLabInterventionKinds` = all eight minus those not yet offered; availability: `bailOut` only when `inputs.diveMode != DiveMode.oc` (the spec's CCR/SCR rule); `switchGas` hidden on loop dives (already); `ascentPolicy` always.
- `_BailOutEditor`: dropdown over bailout-role tanks plus "All bailout cylinders" (default) plus "Hypothetical cylinder" (reusing the O2/He/volume/pressure fields). Builds `BailOutIntervention(tank: null | ExistingTankRef | HypotheticalTankRef)`.
- `_AscentPolicyEditor`: ascent rate stepper (3..18 m/min by 1, displayed in the diver's depth unit per minute: convert with `units.convertDepth`), last-stop depth toggle (3 m / 6 m; displayed converted), extra last-stop minutes stepper (0..10), gas-switch stop seconds stepper (0..180 by 30). Builds `AscentPolicyIntervention(ascentRate:, lastStopDepth:, extraLastStopSeconds:, gasSwitchStopSeconds:)` with only changed fields non-null.
- [ ] Test: CCR dive inputs (diveMode ccr, tanks back (diluent role) + bailout 32%): sheet offers "Bail out to open circuit" and not "Switch gas"; tapping it + Add yields `BailOutIntervention` with a null tank; "Ascent policy" + one stepper tap + Add yields `AscentPolicyIntervention(extraLastStopSeconds: 60)` (or the field tapped) and flips the mode to re-plan.
- [ ] Commit `feat(dive-lab): bailout and ascent-policy editors`

### Task 3: Buoyancy comparison provider

```dart
class BuoyancyComparison { final TwinOutputs actual; final TwinOutputs counterfactual; final double? wingLiftCapacityKg; }
/// Pure: the counterfactual twin input from the actual one and the outcome
/// (profile swapped; each tank's start/end pressure from the consumption
/// pass when known, else the actual tank's; no measured series).
TwinInput buildCounterfactualTwinInput({required TwinInput actual, required ScenarioOutcome outcome});
final labBuoyancyProvider = FutureProvider.autoDispose.family<BuoyancyComparison?, String>((ref, diveId) async { ... });
```
Sources: `labRequestInputsProvider(diveId)` (the hydrated `dive` + profile), `scenarioOutcomeProvider(diveId)` (null -> null), `tankPressuresProvider(diveId)`, `weightCalibrationProvider`, `latestDiverWeightProvider`; `BuoyancyTwinAssembler.assemble(dive: inputs.dive.copyWith(profile: inputs.profile), tankPressures:, model:, bodyWeightKg:)` (null -> null: unmodelable); run both twins with `compute(runBuoyancyTwin, ...)` (tests override via a `labTwinRunnerProvider` like the engine runner); `TwinAnalyzer.analyze` each; wing lift from `dive.equipment` bcd.
- [ ] Test: pure `buildCounterfactualTwinInput` swaps the profile and applies consumption end pressures; provider test with a synchronous runner returns a comparison whose counterfactual profile length equals the outcome's.
- [ ] Commit `feat(dive-lab): buoyancy twin over the counterfactual`

### Task 4: Buoyancy rows in the panel

`LabDeltaPanel` gains `buoyancy: BuoyancyComparison?`; a section (`diveLab_panel_buoyancy`) with three rows actual | what-if | delta: net at the stop (`verdict.netKg`, `units.formatWeight`, better when closer to 0: colour neutral), peak lift demand (`peakLiftDemandKg`, lower better; error when > wing), min ditchable (`minDitchableKg`, lower better). `DiveLabPage` watches `labBuoyancyProvider(diveId)` and passes `valueOrNull`. When null: the section shows `diveLab_buoyancy_unavailable` only when the dive has tanks or a suit (else the section is omitted).
- [ ] Test: panel with a stubbed `BuoyancyComparison` renders the three labels and formatted kg values.
- [ ] Commit `feat(dive-lab): buoyancy rows in the delta panel`

### Task 5: Verification

- [ ] format, analyze, `flutter test test/features/dive_lab test/features/dive_log/presentation/providers`; commit `chore(dive-lab): phase 4 verification`.

## Self-review notes

- The engine's `bailOut` replay uses the bailout pool by depth and `bailOut` re-plan compiles an OC plan at stressed SAC (Phase 1); loop gas segments for CCR dives come from the provider (`loopGasSegments`), so a CCR dive's actual timeline is analysed with setpoints and the bailout counterfactual on OC, which is the spec's semantics.
- Buoyancy in replay mode: the counterfactual profile equals the actual one, so only tank end pressures differ (gas share / switch); the rows then show the gas-swing effect alone.
