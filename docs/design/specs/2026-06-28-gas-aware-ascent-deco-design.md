# Gas-Aware Ascent for Imported-Dive Decompression

**Date:** 2026-06-28

Tracking: GitHub Discussion #326, related issue #298. Follow-up to
[2026-03-31 Imported Profile Multi-Gas Decompression Analysis](./2026-03-31-imported-profile-gas-aware-deco-design.md).

## Problem

The earlier [2026-03-31 multi-gas spec](./2026-03-31-imported-profile-gas-aware-deco-design.md) made *tissue loading* honor recorded gas switches: `processProfileWithGasSegments` splits the bottom-phase loading at each switch boundary and loads each sub-interval with its active gas. That part is implemented and correct on `main`.

What it did not address — and what Discussion #326 reports — is the *forward-looking* part of the calculation. Every projection (TTS, ceiling-during-deco, stop schedule) still simulates the ascent on the **single gas active at the current sample**. Real dive computers plan the ascent using *all* gases the diver carries, so Submersion overestimates TTS during the bottom phase and then shows a discontinuous downward step at each recorded switch that does not correspond to any real change in decompression obligation.

Because Submersion drives heatmaps, CNS/O2 projections, warnings, and summary statistics off these calculated values, the overestimate is not merely cosmetic — it poisons every deco-derived UI element. (Display-only separation of calculated vs. recorded values — "Variant 2" in the discussion — is therefore explicitly rejected as the primary fix; it is kept only as a complementary transparency feature.)

The mental model is two distinct questions that need two gas models:

| Question | Gas model | Drives |
| --- | --- | --- |
| "What is my obligation *if I ascend optimally from here, now*?" | Best available gas at each simulated stop depth (**ideal**) | TTS curve, ceiling, stop schedule, heatmaps, CNS/O2 projections, warnings |
| "What did my tissues *actually* do?" | Recorded gas at recorded switch depths (**already correct, per the 2026-03-31 spec**) | Realized tissue loading, surfacing GF |

TTS, by definition and by what every dive computer displays, is the *optimal* time-to-surface from this instant — which is exactly why a real dive computer's recorded TTS curve is smooth while ours steps.

## Goals

- Make the simulated ascent select the best breathable gas at each simulated stop depth.
- Eliminate the discontinuous TTS step at recorded gas switches.
- Use the diver's existing `ppO2MaxDeco` setting as the deco-gas eligibility ceiling (default 1.6 bar); do not add a parallel setting.
- Preserve existing single-gas behavior exactly, and keep the Bühlmann math shared rather than forked.
- Keep the recorded dive-computer TTS overlay (`overlayComputerDecoData`) authoritative where present.

## Non-Goals

- No "penalty period" baked into TTS to shame late switches. TTS must stay physical and cross-checkable against the dive computer and a clean-room ZHL-16C run. Technique-quality feedback is a separate metric, deferred.
- No invented gases — only cylinders actually recorded on the dive.
- CCR/SCR gas-aware ascent is out of scope and deferred to a dedicated follow-up spec; this pass changes only the open-circuit ascent. CCR/SCR dives keep today's behavior unchanged (no `CcrLoopAscentGas`, no bailout modeling here).
- No change to the bottom-phase tissue-loading path delivered by the 2026-03-31 spec.
- No planner UX redesign; the planner only gains the ability to choose the ideal-gas ascent model.

## Current Architecture

All file/line references are current as of this writing, verified against `main`.

- `lib/core/deco/buhlmann_algorithm.dart`
  - `calculateDecoSchedule({currentDepth, fN2, fHe})` (`:277`), `_calculateStopTime(stopDepth, fN2, fHe)` (`:336`), `_simulateAscent(from, to, fN2, fHe)` (`:378`), `calculateTts({currentDepth, fN2, fHe})` (`:408`) — all use a single gas for the whole simulated ascent.
  - `getDecoStatus({currentDepth, fN2, fHe, ...})` (`:448`) — single gas; passes it straight to schedule + TTS.
  - `processProfileWithGasSegments(...)` (`:535`) — loads tissues per recorded sub-interval gas (the 2026-03-31 work, correct), then calls `getDecoStatus` with **only** `_activeGasAtTimestamp(timestamps[i], gasSegments)` (`:622-626`). This is where the single-gas ascent assumption lives.
- There is **no** `availableGases` / best-gas selection anywhere in `lib/` today.
- `ProfileGasSegment` (`lib/core/deco/entities/profile_gas_segment.dart`) carries `{startTimestamp, fN2, fHe}` only — no O2 fraction (derive `fO2 = 1 - fN2 - fHe`), no tank role, no MOD.
- Available-gas source data exists on the dive: `DiveTanks` (`database.dart:383`) has `o2Percent`, `hePercent`, `tankRole` (`backGas`, `stage`, `deco`, `bailout`). `buildProfileGasSegments(dive, gasSwitches)` (`profile_analysis_provider.dart:172`) already enumerates the primary tank and recorded switches.
- `DecoStatus` (`lib/core/deco/entities/deco_status.dart`) carries `compartments, ndlSeconds, ceilingMeters, ttsSeconds, gfLow, gfHigh, decoStops, currentDepthMeters, ambientPressureBar`.

## Solution

### High-Level Approach

Introduce a pluggable ascent-gas strategy and run the existing ascent simulation with the best gas at each simulated depth, instead of the single currently-active gas. **Scope is open-circuit only** — CCR/SCR are deferred to a follow-up (see CCR / SCR below) and keep today's behavior. The bottom-phase loading path is untouched; only the per-sample *projection* changes.

### Ascent-Gas Strategy

A strategy object answers one question — "what inert fractions do I breathe at this ascent depth?" — and keeps `BuhlmannAlgorithm` ignorant of tank roles and ppO2 policy.

```dart
// lib/core/deco/ascent/ascent_gas_plan.dart

class AscentGas {
  const AscentGas({required this.fN2, required this.fHe});
  final double fN2;
  final double fHe;
}

abstract class AscentGasPlan {
  /// Gas to breathe at [depthMeters] during a simulated ascent.
  AscentGas gasForDepth(double depthMeters);
}
```

Implementations:

- `FixedAscentGas({fN2, fHe})` — today's behavior; one gas the whole way up. Used by single-gas dives and the planner's default path.
- `OptimalOcAscentGas({gases, maxPpO2})` — open-circuit. Picks the breathable gas with the highest O2 whose ppO2 at depth `d` does not exceed `maxPpO2`, where `maxPpO2` is the diver's `ppO2MaxDeco` setting. Eligibility reuses `O2ToxicityCalculator.calculateMod(fO2, maxPpO2)` rather than re-deriving ppO2 inline. Ties broken by lowest inert narcotic load, then highest O2, then a deterministic mix order for stability.

A `CcrLoopAscentGas` (setpoint + diluent) is **not** part of this spec — it is deferred to the CCR follow-up (see CCR / SCR below).

### Threading Through the Ascent Primitives

`calculateDecoSchedule`, `calculateTts`, `_calculateStopTime`, and `_simulateAscent` take an `AscentGasPlan` and query it per depth; `calculateSegment` (the tissue-loading primitive) is unchanged. Each gas switches at its **MOD** — the deepest depth where its ppO2 stays at or below `ppO2MaxDeco`. To honor that, an ascent leg is **split at any gas-switch (MOD) depth it crosses**: `_simulateAscent` walks the leg and subdivides wherever `ascentGas.gasForDepth` changes, loading each sub-leg on the gas eligible at that sub-leg's deeper end. `_calculateStopTime` resolves its gas at the stop depth.

This one rule unifies two cases:

- **Stop-to-stop legs (3 m apart):** no MOD falls strictly inside a 3 m leg for standard gases, so the split is a no-op and the switch lands exactly at the stop — ascending 9 m → 6 m the diver stays on EAN50 and switches to O2 at the 6 m stop, never breathing O2 on the 9 → 6 leg.
- **Travel to the first stop (a potentially long leg):** a gas MOD can fall mid-leg, so the leg splits and the switch happens **on the fly** at the MOD — leaving 40 m with a first stop at 12 m and EAN50 (MOD ~21 m), the diver ascends 40 → 21 m on back gas, switches to EAN50 at 21 m, then continues 21 → 12 m on EAN50.

A leg therefore never breathes a gas impermissible at its current depth, and a richer gas is picked up as soon as it becomes breathable. This matches how Subsurface/MultiDeco and real dive computers plan the ascent and is what the clean-room ZHL-16C cross-check assumes. The split logic is documented inline because it materially affects the curve near switch depths.

Thin `fN2/fHe` overloads are kept, delegating to `FixedAscentGas`, so existing single-gas callers and tests do not churn.

### `getDecoStatus` and `processProfileWithGasSegments`

`getDecoStatus` gains an optional `AscentGasPlan? ascentGas`; when null it builds a `FixedAscentGas` from `fN2/fHe` (today's behavior). `processProfileWithGasSegments` builds the plan **once** from the full OC gas set and passes it into each per-sample `getDecoStatus`:

```dart
List<DecoStatus> processProfileWithGasSegments({
  required List<double> depths,
  required List<int> timestamps,
  required List<ProfileGasSegment> gasSegments,
  AscentGasPlan? ascentGasPlan,   // null => FixedAscentGas(active gas) per sample (legacy)
});
```

The bottom-phase loading loop is unchanged (still `_activeGasAtTimestamp(...)` per sub-interval). The active gas at the sample remains the **floor** of the ascent: the back gas the diver is breathing now is always in the available-gas set, so an optimal OC plan can never select something worse than what they are on.

### Available Gases

Source: `dive.tanks`, mapped to `AvailableGas { fN2, fHe, role, maxPpO2Mod }`, built next to `buildProfileGasSegments` (e.g. `buildAvailableGases(dive)`) so loading segments and the ascent plan derive from one place. Every cylinder recorded on the dive is included — a cylinder's presence is proof it was carried and breathable; no invented gases (consistent with the import-raw-data-only rule). A setting **"Plan ascent with"** chooses `All carried cylinders` (default) vs. `Only deco/stage/bailout + current back gas`.

### CCR / SCR (deferred)

CCR/SCR gas-aware ascent is **out of scope** for this spec and deferred to a dedicated follow-up. CCR/SCR dives keep today's path unchanged: `useOcGasSegments` already gates the gas-segment path on `diveMode == DiveMode.oc` (`profile_analysis_service.dart:573`), so rebreather dives continue through `processProfile` on the existing fixed-fraction gas and are byte-identical to `main`. A regression test asserts this.

The follow-up must address **both halves coherently** — a loop-aware (`ambient − setpoint`) *bottom-phase* loading model *and* the matching setpoint+diluent `CcrLoopAscentGas` ascent. Today's CCR bottom-phase loading is fixed-diluent (CCR never takes the OC gas-segment path), so adding only a loop-aware ascent would reintroduce a bottom→ascent model discontinuity at the current sample — the very artifact this work removes for OC.

### Rollout & Precedence

This change moves every deco-derived number, so it ships behind a reversible setting (defaulted on for new computes). Where a dive has recorded computer TTS, `overlayComputerDecoData` still wins per-metric; the improved calc matters most for dives without recorded TTS and for the planner. The change is purely computational — no schema or stored-data migration; curves recompute on next open.

## Edge Cases

- **Single-gas dive / no switches** — `FixedAscentGas`; output byte-identical to `main`.
- **Switch at timestamp 0** — handled by the existing gas-schedule construction; the start gas is simply that switch's gas.
- **No eligible OC gas at depth** — fall back to the deepest-usable gas; the back gas (always included) guarantees at least one option.
- **CCR / SCR dive** — unchanged from `main` (see CCR / SCR deferred); covered by a no-change regression test.
- **NDL** — unchanged: stays computed on the gas actually being breathed at the current sample (NDL answers "how long at this depth on this gas," not an ascent projection), so it is intentionally not ascent-plan-aware.
- **Late or missing real switch** — TTS stays optimal and honest (no penalty); divergence from the as-dived ascent is surfaced later as a separate efficiency metric, not here.

## Files Expected To Change

| File | Change |
| --- | --- |
| `lib/core/deco/ascent/ascent_gas_plan.dart` | **New** — `AscentGas`, `AscentGasPlan`, `FixedAscentGas`, `OptimalOcAscentGas`, `AvailableGas` |
| `lib/core/deco/buhlmann_algorithm.dart` | Thread `AscentGasPlan` through `calculateDecoSchedule` / `calculateTts` / `_calculateStopTime` / `_simulateAscent` / `getDecoStatus` / `processProfileWithGasSegments`; split each ascent leg at any gas-switch (MOD) depth it crosses; keep `fN2/fHe` overloads |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` | Add `buildAvailableGases(dive)`; build the `OptimalOcAscentGas` plan and pass it into analysis (OC path only) |
| `lib/features/dive_log/data/services/profile_analysis_service.dart` | Plumb the plan through `analyze()` for the OC path; CCR/SCR path unchanged (already gated by `useOcGasSegments`) |
| `lib/features/dive_planner/data/services/plan_calculator_service.dart` | Select `OptimalOcAscentGas` (ideal) vs. `FixedAscentGas` per the existing gas model |
| Settings surface (existing deco/units settings) | "Plan ascent with" (all vs. deco-only), respecting active-diver settings; reuse the existing `ppO2MaxDeco` diver setting as the eligibility ceiling (no new ppO2 setting) |
| `test/core/deco/tts_gas_switch_regression_test.dart` | **New** — step-free TTS across a switch; single-gas equivalence; CCR/SCR path unchanged vs. `main` |
| `test/core/deco/buhlmann_algorithm_test.dart` | `AscentGasPlan` selection + overload-delegation + MOD-split / on-the-fly-switch tests |

## Testing

Use only the committed fixtures in `test/dives/`. This spec exercises the OC fixture `001_short_deco_single_gas_switch.ssrf.xml`; the CCR fixtures (`002_ccr_only_low_sp_no_calculated_po2.ssrf.xml`, `003_ccr_with_setpoint_switch_and_calculated_po2.ssrf.xml`) are reserved for the deferred CCR follow-up and are used here only to assert the CCR path is unchanged. Any other recording under `test/dives/` is a private local file and must not be referenced.

### Core Algorithm Tests

- `FixedAscentGas` returns a constant; the `fN2/fHe` overloads produce identical results to an explicit `FixedAscentGas` (single-gas equivalence).
- `OptimalOcAscentGas` picks the highest-O2 eligible gas at depth, honors the `ppO2MaxDeco` ceiling via `calculateMod`, and tie-breaks deterministically.
- **MOD split — stop-to-stop**: ascending 9 m → 6 m with O2 available, the diver stays on the deeper-eligible gas (e.g. EAN50) and switches to O2 on arrival at the 6 m stop — never breathes O2 on the 9→6 leg.
- **MOD split — on the fly to first stop**: leaving 40 m with EAN50 (MOD ~21 m) and a first stop at 12 m, the leg splits at 21 m — back gas 40→21 m, EAN50 21→12 m — so the switch happens mid-ascent, not deferred to the stop.
- An air-to-richer-gas ascent yields lower-or-equal TTS / ceiling versus all-air for the same profile (NDL is unchanged — it stays on the current breathing gas).

### Service & Provider Tests

- `buildAvailableGases` maps `dive.tanks` mixes, honors the "all vs. deco-only" setting, invents no gases.
- A single-segment / no-switch dive matches legacy single-gas analysis exactly.
- A CCR/SCR dive is byte-identical to `main` (the gas-aware ascent never engages off the OC path).

### Fixture & Validation Tests

- **OC shape — fixture 001**: with `OptimalOcAscentGas`, calculated TTS is monotone, step-free across the recorded switch, and reads 0 at the surface. This fixture's recorded TTS is a fixed-plan replay and is **not** GF-50/75-consistent, so it validates *shape only* — never assert absolute TTS against it.
- **CCR unchanged — fixtures 002 / 003**: analysis output is identical to `main` (no behavioral change for rebreather dives in this pass).
- **Absolute correctness — clean-room ZHL-16C/GF** cross-check (per-sample TTS) against an independent implementation; this, not the fixtures, pins the absolute numbers.

## Acceptance Criteria

- The simulated ascent selects the best available gas, switching each gas at its MOD — at the stop for 3 m legs, and on the fly (leg split at the MOD) on the travel to the first stop; no discontinuous TTS step remains at recorded gas switches.
- Single-gas dives produce byte-identical TTS to `main`.
- CCR/SCR dives are unchanged from `main` (gas-aware ascent is OC-only this pass).
- The eligibility ceiling reuses the existing `ppO2MaxDeco` diver setting; a "plan ascent with" gas-set setting is available. No new ppO2 setting is added.
- The recorded dive-computer TTS overlay remains authoritative where present.
- The regression test and clean-room cross-check pass; fixture 001 reads 0 TTS at the surface.

## Future Work

- **CCR/SCR gas-aware ascent (dedicated follow-up)** — a `CcrLoopAscentGas` setpoint+diluent ascent model *and* a matching loop-aware (`ambient − setpoint`) bottom-phase loading model, delivered together so the bottom and ascent share one CCR gas model. Bailout (OC) modeling for CCR TTS also lives here.
- Efficiency / technique metric derived from `idealTts` vs. `realizedTts` (replay recorded switch depths), surfaced in dive analysis rather than in TTS.
- Side-by-side calculated-vs-recorded TTS display (Subsurface-style) for transparency.
- "Real ascent" model option (replay recorded switch depths) for users who want the as-dived projection rather than the optimal one.
- Companion implementation plan in `docs/superpowers/plans/` once this design is approved.
