# Planner Redesign Phase 5: SCR Breathing Mode (validated slice) - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans.

**Goal:** Expose the engine's existing, test-validated CMF SCR breathing model as a selectable plan mode (OC / CCR / SCR), reusing the already-covered `Scr` config - no new deco math.

**Scope note (deliberate deferral - safety):** The spec's Phase 5 also calls for (a) passive pSCR, whose loop physics differ from the existing CMF `Scr` model, and (b) recreational mode, an NDL-maximization solver. Both are NEW safety-critical deco algorithms that the spec itself says require independent Python golden-vector validation (VPM-B-class rigor). Producing and validating that math is not safe in an autonomous pass, so both are deferred to a golden-vector-validated follow-up. This plan ships only the SCR mode that reuses validated code.

**Update (deferral resolved, same PR):** Both deferred items were subsequently implemented in this PR under the required validation. Passive pSCR (`PassiveScr` in `lib/core/deco/entities/breathing_config.dart`) is a faithful port of Subsurface's `pscr_o2`, verified against the Subsurface source and covered by hand-computed vectors in `test/core/deco/passive_scr_test.dart`. The recreational NDL solver (`RecreationalNdlSolver` in `lib/features/planner/domain/services/recreational_ndl_solver.dart`) is a thin layer over the validated Buhlmann model, cross-checked against `DecoModel.ndlSeconds`. VPM-B (Phase 6) shipped with its own golden vectors (`test/core/deco/vpm_b_golden_test.dart`).

**Architecture:** `PlanMode` gains `scr` (stored as the string `'scr'` in the existing TEXT column - no migration; `PlanMode.values.byName` already parses it). `PlanEngine._breathingFor` gets an SCR branch constructing the validated `Scr` from the segment gas as supply, with the injection rate from `PlanEngineConfig`. The header mode control cycles OC -> CCR -> SCR.

## Global Constraints

Same as prior phases. No schema migration. New l10n in 11 locales.

## Verified facts

- `enum PlanMode { oc, ccr }` (dive_plan.dart:9). DB: `mode: Value(plan.mode.name)` write, `PlanMode.values.byName(r.mode)` read - adding `scr` needs no migration.
- `Scr({required supplyFO2, supplyFHe=0, required injectionRateLpm, vo2=ScrCalculator.defaultVo2})` - validated by `test/core/deco/breathing_config_test.dart`.
- `PlanEngine._breathingFor(plan, gas, depth)` branches ccr -> ClosedCircuit else OpenCircuit (plan_engine.dart:68). `isCcr` bool computed at compute() (~line 94) drives ascent-gas and tank-usage paths.
- The header OC/CCR toggle lives in `plan_canvas_page.dart` (`updateMode` flips oc<->ccr). `CcrSettingsSection` shows only when mode==ccr in the accordion.

---

### Task 1: PlanMode.scr + engine breathing branch

**Files:**
- Modify: `lib/features/planner/domain/entities/dive_plan.dart` (enum)
- Modify: `lib/features/planner/domain/services/plan_engine.dart` (`_breathingFor`, and any `isCcr`-only path that should also treat SCR as loop-based for tank usage - review `_computeTankUsages` vs `_computeCcrTankUsages`; SCR consumption uses the supply injection, so route SCR through OC-style SAC tank usage for a first cut, documented)
- Modify: `lib/features/planner/domain/services/plan_engine.dart` PlanEngineConfig: add `scrInjectionRateLpm` (default 12.0)
- Test: `test/features/planner/plan_engine_scr_test.dart`

Engine `_breathingFor` SCR branch:
```dart
if (plan.mode == domain.PlanMode.scr) {
  return Scr(
    supplyFO2: gas.o2 / 100.0,
    supplyFHe: gas.he / 100.0,
    injectionRateLpm: config.scrInjectionRateLpm,
  );
}
```
Tank usage: SCR is not CCR; leave the `isCcr` gate as-is so SCR uses OC SAC-based tank usage (a defensible first cut; true SCR supply modeling is a follow-up - document with a comment).

TDD: an SCR plan (45m/20min air) computes without throwing and yields a different `cnsEnd` than the OC plan of the same profile (loop pO2 differs from OC ambient pO2). Also assert `PlanMode.values.byName('scr') == PlanMode.scr`. Commit `feat(planner): SCR breathing mode reuses the validated CMF loop model`.

### Task 2: Mode selector cycles OC/CCR/SCR + l10n

**Files:**
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart` (the app-bar mode `PlanChip`: tap cycles oc->ccr->scr->oc; label shows the mode name uppercased)
- Modify: 11 arb files if a new label key is needed (the chip can show the literal enum name uppercased - 'OC'/'CCR'/'SCR' are acronyms, not translatable, so NO new l10n needed; verify the existing chip uses a literal not a key)
- Test: extend `test/features/planner/ccr_ui_test.dart` or `plan_canvas_page_test.dart` - tapping the mode chip cycles through the three modes.

Cycle helper:
```dart
domain.PlanMode _nextMode(domain.PlanMode m) => switch (m) {
  domain.PlanMode.oc => domain.PlanMode.ccr,
  domain.PlanMode.ccr => domain.PlanMode.scr,
  domain.PlanMode.scr => domain.PlanMode.oc,
};
```
Chip label: `planState.mode.name.toUpperCase()`; emphasized when not OC. Commit `feat(planner): plan mode chip cycles OC, CCR, and SCR`.

### Task 3: Phase gate

`dart format .`, `flutter analyze`, `flutter test test/features/planner/ test/features/dive_planner/ test/core/deco/`, l10n, clean tree.

## Self-Review

- Ships SCR mode reusing validated `Scr`. Explicitly defers passive pSCR and recreational NDL-solver (new deco math) with a safety rationale.
- No schema migration (enum string in existing column).
- Type consistency: `scrInjectionRateLpm`, `PlanMode.scr`, `_nextMode` consistent.
