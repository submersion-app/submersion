# Dive Planner Phase 5: Contingencies — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One-tap deviation plans (+depth / +time / both) with ghost overlays on the canvas, lost-deco-gas schedules, turn-pressure per bottom tank, and rock-bottom (min-gas) validation — the spec's "Contingencies (Phase 5)".

**Architecture:** A `ContingencyService` derives modified `DivePlan`s (deeper/longer bottom, tank removed) and runs them through the existing `PlanEngine`; nothing new in the engine core. Turn pressure and min-gas land as fields on `PlanTankUsage` plus one new `PlanIssueType.minGasViolation`. Editing state gains the contingency config (deltas, turn rule) like Phase 4's setpoints. Branch: stacked on `worktree-dive-planner-phase4-ccr` (PR #488). Global constraints as Phases 3–4.

---

### Task 1: `ContingencyService` — deviations + lost gas

**Files:** Create `lib/features/planner/domain/services/contingency_service.dart`; Test `test/features/planner/contingency_service_test.dart`.

```dart
class DeviationOutcome { final String key; // 'deeper' | 'longer' | 'both'
  final domain.DivePlan plan; final PlanOutcome outcome; }
class LostGasOutcome { final DiveTank tank; final PlanOutcome outcome; }
class ContingencyService {
  const ContingencyService({PlanEngineConfig config});
  List<DeviationOutcome> deviations(domain.DivePlan plan);
  List<LostGasOutcome> lostGas(domain.DivePlan plan); // OC only; [] for CCR
}
```
- Deviations (skip when no segments): `deeper` = every bottom segment's depth + `deviationDepthDelta` (descent segments' end depth likewise when they feed the deepened bottom — implement as: any segment start/end depth that EQUALS the plan max depth gets +delta); `longer` = every bottom segment + `deviationTimeMinutes`; `both` = both edits. Each computed via `PlanEngine.compute`.
- Lost gas: for each `deco`/`stage`-role tank, a plan without it (and without segments referencing it — bottom segments never do) → outcome. Empty list for CCR (bailout covers loop loss) and when no such tanks.

- [ ] Tests: deeper deviation has `maxDepth == base + delta` and `totalDecoSeconds > base`; longer likewise; lost EAN50 on a trimix plan lengthens deco vs base and its stops at ≤ 22 m no longer breathe EAN50; CCR plan → `lostGas` empty; deltas honored from the plan fields.
- [ ] Implement; format+commit `feat(planner): contingency service for deviation and lost-gas plans`.

---

### Task 2: Turn pressure + min-gas in PlanEngine

**Files:** Modify `plan_outcome.dart` (PlanTankUsage +`turnPressureBar`, +`minGasBar`; PlanIssueType +`minGasViolation`), `plan_engine.dart`, `plan_results_sheet.dart` (message case); ARBs (+`plannerCanvas_issue_minGas`, `plannerCanvas_gas_turnAt`, `plannerCanvas_gas_minGas`); Test extend `plan_engine_issues_test.dart`.

- `PlanEngineConfig` += `buddyFactor = 2.0` (two divers share the rock-bottom ascent).
- Turn pressure (OC, rule non-null, bottom/backGas-role tanks with startPressure): `usable = start − reserve`, `turn = start − usable × fraction` where fraction = allUsable 1.0 / halves 0.5 / thirds 1/3 / custom `turnPressureFraction ?? 1/3`.
- Min gas (OC, backGas-role tanks): liters for a direct stressed ascent from `plan.maxDepth` on that tank's gas — schedule from maxDepth with `FixedAscentGas(tank gas)` at END-OF-BOTTOM tissue state is overkill; per rock-bottom convention use the NO-DECO emergency form: 1 min at max depth + ascent at `plan.ascentRate` to surface, at `sacStressedEffective × buddyFactor`, pressure-integrated — then `minGasBar` via the tank's volume (ideal-bar conversion is the field convention: liters / volume). Issue `minGasViolation` (alert) when `remainingPressure < minGasBar`.
- [ ] Tests: thirds rule on 200 bar start / 50 reserve → turn at 150; minGas positive and violation fires for a small tank on a deep plan, absent for a big one; CCR plans get neither.
- [ ] Format+commit `feat(planner): turn pressure and rock-bottom validation`.

---

### Task 3: Editing state + mapper contingency config

**Files:** `plan_result.dart` (DivePlanState += `deviationDepthDelta` (double, default 5), `deviationTimeMinutes` (int, default 5), `turnPressureRule` (TurnPressureRule?), `turnPressureFraction` (double?)), notifier `updateContingencies({...})`, mapper both ways; extend mapper test.
- [ ] Round-trip tests; format+commit `feat(planner): contingency config in the planner editing state`.

---

### Task 4: Canvas UI — ghost overlays, contingency sections, settings

**Files:** `plan_canvas_providers.dart` (extract `buildCanvasSeries({segments, outcome})` top-level; `planDeviationsProvider`, `selectedDeviationProvider = StateProvider<String?>`, `deviationGhostSeriesProvider`), `plan_canvas_chart.dart` (ghost `LineChartBarData`, grey dashed), new `contingency_chips.dart` (selector row: Base / +Xm / +X′ / both), `plan_results_sheet.dart` (Deviations + Lost gas sections with mini runtime tables; turn/min-gas on gas rows), new `contingency_settings_section.dart` (two numeric fields + rule dropdown, shown in plan settings for OC), page wiring; l10n (~8 keys, all locales); widget tests.
- [ ] Tests: selecting a deviation adds a second (ghost) line bar; deviations section lists three tables for an OC deco plan; gas row shows `turn @` when a rule is set.
- [ ] Format+commit `feat(planner): contingency overlays and tables on the canvas`.

---

### Task 5: Verification sweep

- [ ] `flutter analyze` clean; format stable; `flutter test test/core/deco/ test/features/planner/ test/features/dive_planner/` green; gen-l10n zero untranslated.

**Out of scope:** slate export of contingency tables (Phase 7); per-stop lost-gas re-switching UI; cave same-way-back.
