# Dive Planner Phase 4: CCR Planning + Bailout — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Real CCR planning — constant-ppO2 loading AND loop deco schedules (removing the "CCR schedules breathe OC" Phase 1 limitation), setpoint low/high with a depth switch, O2/diluent consumption, a worst-case bailout solver with scrub-to-bailout readout, and the canvas UI for all of it.

**Architecture (the key move):** the constant-ppO2 loop is expressed as a **depth-dependent effective-fraction `AscentGasPlan`** (`CcrLoopAscentGas`): at depth d, the loop's inspired partial pressures (via `ClosedCircuit.inspiredAt`) divide by alveolar pressure to give effective fN2/fHe — so the UNCHANGED Bühlmann schedule machinery computes loop deco exactly at constant-depth stops. No engine-core edits. Branch: stacked on `worktree-dive-planner-phase3-canvas` (PR #486).

**Spec:** "CCR and bailout (Phase 4)" section. Global constraints as Phase 3 (l10n all locales, units, format/analyze, commit per task, no Co-Authored-By).

---

### Task 1: `CcrLoopAscentGas` (core engine, additive)

**Files:** Create `lib/core/deco/ascent/ccr_loop_ascent_gas.dart`; Test `test/core/deco/ccr_loop_ascent_gas_test.dart`.

```dart
class CcrLoopAscentGas extends AscentGasPlan {
  CcrLoopAscentGas({required DiveEnvironment environment,
    required double setpointLow, required double setpointHigh,
    required double switchDepth,          // > switchDepth => high setpoint
    required double diluentFO2, double diluentFHe = 0.0});
  double setpointAt(double depthMeters);  // depth > switchDepth ? high : low
  @override AscentGas gasForDepth(double depthMeters); // effective fractions
  @override List<double> switchDepthsBetween(double deeper, double shallower);
  // returns [switchDepth] when strictly crossed (setpoint change = gas change)
}
```
`gasForDepth`: `amb = env.pressureAtDepth(d)`, `pAlv = max(amb - waterVaporPressure, 0)`, inspired = `ClosedCircuit(setpoint: setpointAt(d), diluentFO2, diluentFHe).inspiredAt(amb)`, return `AscentGas(fN2: inspired.pN2/pAlv, fHe: inspired.pHe/pAlv)` (guard pAlv<=0 → all-zero). `breakGasForDepth` stays null (loop gas is never pure O2 at stop depths under a 1.3 setpoint, and air breaks don't apply to loop deco).

- [ ] Tests (python3-computed): effective fN2 at 40 m, SP 1.3, Tx18/45 diluent equals `pN2/pAlv` from the Task-4 Phase-1 vector (1.6412207/4.9373); fractions at 3 m (SP clamped) are ~0; `setpointAt` honors switchDepth on both sides; `switchDepthsBetween(21, 3)` with switchDepth 10 returns `[10.0]`, `(9, 3)` returns `[]`; round-trip: `calculateSegment(breathing: ClosedCircuit(...))` equals `calculateSegment(fN2: gasForDepth(d).fN2, fHe: ...)` tensions at the same constant depth (proves the equivalence the design rests on).
- [ ] Implement; deco suite green; format+commit `feat(deco): CCR loop as a depth-dependent ascent gas plan`.

---

### Task 2: PlanEngine CCR mode (loading, loop deco, consumption)

**Files:** Modify `plan_engine.dart`, `dive_plan.dart` (effective-setpoint getters); Test `test/features/planner/plan_engine_ccr_test.dart`.

- `domain.DivePlan`: `double get effectiveSetpointLow => setpointLow ?? 0.7;` `effectiveSetpointHigh => setpointHigh ?? 1.3;` `effectiveSetpointSwitchDepth => setpointSwitchDepth ?? 10.0;`
- `PlanEngineConfig`: add `o2MetabolicRateLpm = 1.0`, `loopVolumeLiters = 6.0`.
- `PlanEngine.compute` when `plan.mode == PlanMode.ccr`:
  - Segment loading breathes `ClosedCircuit(setpoint: setpointAt(segment.avgDepth), diluentFO2/FHe: segment gas)`; NDL at segment end likewise.
  - Ascent plan = `CcrLoopAscentGas` (diluent = last segment's gas); schedule/TTS therefore run on the loop.
  - Consumption: O2 = `o2MetabolicRateLpm × runtime-minutes(incl. deco)` charged to the `TankRole.oxygenSupply` tank when present (else uncharged); diluent = `loopVolumeLiters × (pressureAt(maxDepth) − surface)` charged to the `TankRole.diluent` tank when present, else the first segment's tank. Bailout-role tanks consume NOTHING in the main plan. OC-role SAC consumption paths skipped for ccr.
  - Issues: END/density already evaluate segment gas (= diluent) ✓; add `ndlExceededNoDecoGas`-analog: when ccr, deco, and NO `TankRole.bailout` tank → reuse `ndlExceededNoDecoGas` with a bailout-specific message? NO — add enum value `noBailoutCarried` (alert). Remove the "computed as OC" doc note.
- [ ] Tests: CCR Tx18/45 60 m/25 min SP .7/1.3/10 → stops exist and total deco is LESS than the same plan computed as OC on the diluent (higher loop ppO2 shallow); O2 liters == rate×runtime within 1 L; diluent charged to diluent-role tank; bailout tank untouched; `noBailoutCarried` raised without a bailout tank and cleared with one; OC plans byte-identical to Phase 3 behavior (existing parity test still green).
- [ ] Format+commit `feat(planner): CCR loop deco schedules and consumption in PlanEngine`.

---

### Task 3: Editing state + mapper carry mode/setpoints

**Files:** Modify `plan_result.dart` (DivePlanState), `dive_planner_providers.dart` (notifier), `dive_plan_state_mapper.dart`; extend `test/features/planner/dive_plan_state_mapper_test.dart`.

- `DivePlanState` += `PlanMode mode` (default `PlanMode.oc`), `double? setpointLow/setpointHigh/setpointSwitchDepth` (+copyWith with clear flags, props). Import `dive_plan.dart` for `PlanMode` (no cycle: dive_plan imports only plan_segment).
- Notifier: `updateMode(PlanMode)`, `updateSetpoints({double? low, double? high, double? switchDepth})` (isDirty+updatedAt as siblings do).
- Mapper: state→plan carries mode/setpoints (drop them from the `existing`-preserved set); plan→state restores them.
- [ ] Tests: mode/setpoints round-trip state→plan→state; a CCR plan loaded then saved keeps setpoints without `existing`.
- [ ] Format+commit `feat(planner): CCR mode and setpoints in the planner editing state`.

---

### Task 4: Bailout solver + provider

**Files:** Create `lib/features/planner/domain/services/bailout_solver.dart`; provider in `plan_canvas_providers.dart`; Test `test/features/planner/bailout_solver_test.dart`.

```dart
class BailoutPoint { final int runtimeSeconds; final double depthMeters;
  final int ttsSeconds; final double litersRequired; }
class BailoutOutcome { final List<BailoutPoint> points;
  final BailoutPoint worstCase; final double availableLiters;
  bool get sufficient => worstCase.litersRequired <= availableLiters;
  BailoutPoint nearest(double runtimeSeconds); }
class BailoutSolver {
  const BailoutSolver({PlanEngineConfig config = const PlanEngineConfig()});
  BailoutOutcome? solve(domain.DivePlan plan); // null: not ccr / no bailout tanks / no segments
}
```
Solve: CCR-load minute-by-minute through the user segments (depth linearly interpolated inside each segment; sample interval `max(60, totalSeconds ~/ 40)` seconds — bounded ≤ ~40 samples, plus always the exact end-of-bottom sample). At each sample: OC schedule from that depth on `OptimalOcAscentGas(bailout-role tanks, ppO2Deco)`, TTS, and liters = `sacStressedEffective × Σ(minutes × pressureAt(depth))` over travel legs (plan.ascentRate) + stops + final surfacing. `availableLiters` = Σ `gasVolume(tank)` over bailout tanks. Worst case = max liters.
Provider: `final planBailoutProvider = Provider<BailoutOutcome?>` watching state + config (compute only when ccr).

- [ ] Tests: square 60 m/25 min CCR plan with one AL80 EAN50 bailout → worstCase at (or within one sample of) end-of-bottom; litersRequired monotonic non-decreasing across the bottom phase; `sufficient` flips when the bailout tank shrinks (3 L) vs a pair of large tanks; returns null for OC plans and when no bailout tanks.
- [ ] Format+commit `feat(planner): worst-case bailout solver`.

---

### Task 5: Canvas CCR UI + l10n

**Files:** Modify `plan_canvas_page.dart` (badge toggle, CCR settings section in the settings sheet), `plan_results_sheet.dart` (+bailout section), `plan_canvas_chart.dart` (scrub readout appends bailout TTS); Create `lib/features/planner/presentation/widgets/ccr_settings_section.dart`; ARBs (en + 10 locales); Test `test/features/planner/ccr_ui_test.dart`.

- Badge: `PlanChip(label: mode name uppercased)` wrapped in InkWell → `updateMode(toggled)`.
- `CcrSettingsSection` (shown in the settings sheet when ccr): three numeric `TextFormField`s (low/high in bar, switch depth in display units) writing `updateSetpoints`; own controllers in a StatefulWidget (dialog-controller-dispose rule: owned by State.dispose).
- Results sheet: when ccr and `planBailoutProvider` non-null: header `plannerCanvas_bailout_title`, rows worst-case (RT′ @ depth), bailout TTS, required vs available liters (error color + `plannerCanvas_bailout_insufficient` row when short).
- Scrub readout: when ccr and outcome non-null, append ` · BO {tts}′` from `nearest(scrubTime)` (`plannerCanvas_scrub_bailout` key).
- l10n keys (~8): `plannerCanvas_bailout_available`, `_insufficient`, `_required`, `_title`, `_tts`, `_worstCase`, `plannerCanvas_ccr_setpointHigh`, `_setpointLow`, `_switchDepth`, `plannerCanvas_scrub_bailout` — en + all 10 locales, gen-l10n zero untranslated.
- [ ] Widget tests: badge toggles state mode; CCR plan with bailout tank shows the bailout section values; insufficient case renders the error row.
- [ ] Format+commit `feat(planner): CCR canvas controls and bailout readouts`.

---

### Task 6: Verification sweep

- [ ] `flutter analyze` clean; `dart format .` stable; `flutter test test/core/deco/ test/features/planner/ test/features/dive_planner/` green; commit anything outstanding.

**Out of scope:** per-stop manual setpoint overrides; measured-ppO2 loading; SCR planning UI; bailout contingency TABLES on the slate (Phase 7); persisted o2-rate/loop-volume settings (engine-config defaults for now).
