# Planner Redesign Phase 4: Rates and Gas Options (no-schema slice) - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** The Subsurface-parity engine/UI items that need NO schema migration: expose ascent rate and descent rate as plan controls (existing persisted columns), wire descent rate into the engine, and expose the O2-narcotic toggle. Multi-band ascent rates, only-switch-at-required-stops, and surface segment are added as engine capability defaulted to current behavior.

**Scope note (deliberate deferral):** This branch is at schema v112 while main's ladder is at v117; adding a v113 migration here would collide on merge. Therefore the schema-requiring parity items - per-segment setpoint (G4/G6), per-segment dive-mode (G5), plan start date/time (G12), tissue-init-from-all-dives (G13), overlap detection (G14), per-tank deco-switch depth (G18), reverse profile persistence (G15) - are deferred to a Phase 4b that claims a coordinated schema version after this PR merges. This plan delivers G7 (partial), G8, G11, and lays the G9/G10 engine seam.

**Architecture:** `SchedulePolicy` gains an optional `ascentRateBands` and `descentRate` (defaulting to the legacy single-rate behavior); `PlanEngine` sources them from `DivePlan.ascentRate`/`descentRate` (both already persisted + synced). A new Rates setup section edits the two existing scalars. O2-narcotic is an existing `AppSettings` field surfaced as a planner toggle.

## Global Constraints

Same as phases 1-3. No schema change. New l10n keys in all 11 locales.

## Verified facts

- `DivePlan` has `descentRate` (18.0, currently UNUSED by engine) and `ascentRate` (9.0, used) columns - both persisted on `dive_plans` and synced (generic serialization). No migration to use them.
- `SchedulePolicy({stopIncrement, lastStopDepth, ascentRate, gasSwitchStopSeconds, airBreaks})`; `PlanEngine.compute` builds it from `plan.lastStopDepth/ascentRate/gasSwitchStopSeconds/airBreaks` (~line 102).
- `PlanEngineConfig.o2Narcotic` sourced from `settings.o2Narcotic` (AppSettings bool, default true). Toggling it flips END/best-mix basis.
- Notifier has `updateName/updateSacRate/updateAltitude/...`; add `updateRates`.
- `DivePlanState` (plan_result.dart:465) carries UI fields; `ascentRate`/`descentRate` are NOT currently on it (they live on DivePlan, preserved via `existing` in the mapper). This plan adds them to DivePlanState + mapper so the UI can edit them.

---

### Task 1: SchedulePolicy descent rate + ascent-rate-band seam (engine, pure)

**Files:**
- Modify: `lib/core/deco/schedule_policy.dart`
- Test: `test/core/deco/schedule_policy_test.dart` (create if absent)

Add to `SchedulePolicy`: `final double descentRate;` (default 18.0) and `final List<double>? ascentRateBands;` (null = use single `ascentRate` everywhere). Add `double ascentRateForDepth(double depthMeters, double meanDepthMeters)` returning the band rate (below 75% mean, 75-50%, 50%-to-6m, 6m-to-surface) when bands present, else `ascentRate`. Bands list is `[belowMean75, mean75to50, mean50to6, last6m]`.

TDD: test that with null bands, `ascentRateForDepth` always returns `ascentRate`; with a 4-element list and mean depth 40m, depth 35m returns band[0], 25m returns band[1], 10m returns band[2], 4m returns band[3]. Commit `feat(deco): schedule policy descent rate and ascent-rate bands`.

### Task 2: Wire descent + ascent rate through the engine

**Files:**
- Modify: `lib/features/planner/domain/services/plan_engine.dart` (SchedulePolicy construction ~line 102; ascent schedule call)
- Test: `test/features/planner/plan_engine_rates_test.dart`

Pass `descentRate: plan.descentRate` and `ascentRate: plan.ascentRate` into the `SchedulePolicy`. Where the ascent schedule uses a single ascent rate, keep `ascentRate` (bands are the seam for Phase 4b UI; engine already honors `ascentRateForDepth` if the model calls it - if `BuhlmannGf.schedule` uses `policy.ascentRate` directly, leave it; the band method is available for later). The observable Phase-4 change: a plan with `ascentRate` 6 produces a longer TTS than one with 9 (slower ascent). 

TDD: build a DivePlan (45m/20min bottom) with ascentRate 9 vs 6; assert `compute(...).ttsAtBottom` is greater for the slower rate. Commit `feat(planner): plan ascent rate affects the computed schedule`.

### Task 3: DivePlanState + mapper carry ascent/descent rate

**Files:**
- Modify: `lib/features/dive_planner/domain/entities/plan_result.dart` (DivePlanState: add `double ascentRate` default 9.0, `double descentRate` default 18.0, copyWith, props)
- Modify: `lib/features/planner/domain/services/dive_plan_state_mapper.dart` (carry both directions; stop relying on `existing` for these two)
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (add `void updateRates({double? ascent, double? descent})`)
- Test: extend the mapper's existing test (find `test/features/planner/dive_plan_state_mapper*` or add cases) to round-trip the two rates.

TDD for the notifier: `updateRates(ascent: 6)` sets state.ascentRate 6 and isDirty. Commit `feat(planner): edit ascent and descent rate in plan state`.

### Task 4: Rates setup section + O2-narcotic toggle

**Files:**
- Create: `lib/features/dive_planner/presentation/widgets/setup/plan_rates_section.dart` (ascent + descent sliders, 1-30 m/min)
- Modify: `lib/features/dive_planner/presentation/widgets/setup/plan_environment_section.dart` (add O2-narcotic SwitchListTile bound to the settings notifier's o2Narcotic setter)
- Modify: `lib/features/planner/presentation/panes/plan_setup_accordion.dart` (insert a 'rates' section after 'deco')
- Modify: 11 arb files (`plannerCanvas_rates_title`, `plannerCanvas_rates_ascent`, `plannerCanvas_rates_descent`, `plannerCanvas_o2Narcotic`)
- Test: `test/features/planner/panes/plan_rates_section_test.dart` + extend accordion test for the new tile count (6 -> 7 OC, 7 -> 8 CCR... verify current counts first).

Section titles reuse where possible; "Rates" is a new key. The O2-narcotic toggle reads `settings.o2Narcotic` and calls the settings notifier setter (verify method name; grep `o2Narcotic` in settings_providers). TDD: rates section renders two sliders and updates state; accordion shows the Rates tile. Commit `feat(planner): rates setup section and O2-narcotic toggle`.

### Task 5: Phase gate

`dart format .`, `flutter analyze`, `flutter test test/features/planner/ test/features/dive_planner/ test/core/deco/`, l10n in 11 locales, clean tree.

## Self-Review

- Delivers: G8 (descent rate), G7 seam (bands available; per-band UI is 4b), G11 (O2 narcotic), engine ascent-rate effect. Explicitly defers all schema-column items with rationale.
- No schema migration; uses existing synced columns.
- Type consistency: `ascentRateForDepth`, `updateRates`, `ascentRateBands` used consistently.
