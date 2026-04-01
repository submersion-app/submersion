# Imported Profile Gas-Aware Decompression Analysis

**Date:** 2026-03-31

## Problem

Imported dives can contain multiple tanks and explicit gas-switch events, but the current historical-profile decompression analysis path still collapses the whole dive to a single gas mix.

Today, `profileAnalysisProvider` derives `o2Fraction` and `heFraction` from `dive.tanks.first` and passes those single values into `ProfileAnalysisService.analyze(...)`. `ProfileAnalysisService` then computes one `n2Fraction` / `heFraction` pair and feeds that through `BuhlmannAlgorithm.processProfile(...)` for the entire dive.

That means the displayed and derived decompression metrics for imported dives:

- NDL
- Ceiling
- TTS
- Deco status / stops
- Tissue loading / GF metrics

all assume the diver breathed the first tank for the full dive, even when the imported dive includes gas switches to richer deco gases such as EAN32, EAN50, or oxygen.

This creates two user-facing correctness problems:

1. Imported multi-gas dives show more aggressive tissue loading and deco obligations than they should when a richer gas was actually used on ascent or at stops.
2. The app already has multi-gas planner logic and imported gas-switch records, so the historical-dive analysis path is lagging behind the rest of the model.

## Goals

- Make imported historical-dive decompression analysis gas-aware.
- Use imported tank gas mixes and gas-switch timestamps when they are available.
- Preserve the existing single-gas behavior for dives that truly only have one gas or have no switch records.
- Keep the core Bühlmann implementation reusable and avoid introducing imported-dive-specific decompression math.
- Add sanity tests proving that an otherwise identical dive with a switch to EAN32 loads tissues less aggressively than the same profile calculated entirely on air.

## Non-Goals

- No change to the planner authoring UX or manual planner segment editing.
- No attempt to infer undocumented gas switches from pressure changes alone in this first pass.
- No change to dive-computer overlay precedence for imported `ndl`, `ceiling`, `tts`, or `cns` data.
- No change to repetitive-dive carryover rules beyond ensuring the end-of-dive compartments now reflect the correct gases actually breathed.
- No broader "deco model validity framework" for every possible bad-input condition in this pass.

### Explicitly Out Of Scope For This Pass

The following are valid future decompression-validity concerns, but they are not part of this implementation unless they are already required by the current gas-switch changes:

- dives with no usable gas definition at all,
- impossible gas definitions such as `O2 + He > 100%`,
- corrupted or non-monotonic profile timestamps,
- profile data too incomplete to support meaningful Bühlmann stepping,
- altitude or surface-pressure validation beyond current behavior,
- CCR/SCR import cases that would require a different gas-model interpretation than the current OC-style imported-profile analysis.

This feature only introduces explicit invalidation for:

- unresolved or unusable gas-switch data on the current dive, and
- prior-dive carryover that depends on a previous dive already marked invalid for that same reason.

## Current Architecture

### Historical Dive Analysis Path

1. `profileAnalysisProvider` loads a `Dive` plus profile data.
2. It chooses one gas from `dive.tanks.first`.
3. It computes residual CNS, OTU, and tissue state from earlier dives.
4. It runs `ProfileAnalysisService.analyze(...)` in a background isolate.
5. `ProfileAnalysisService` passes one gas pair through `BuhlmannAlgorithm.processProfile(...)`.
6. UI panels and chart curves consume the resulting `ProfileAnalysis`.

### Existing Gas-Aware Data Already in the App

- `DiveTank` records store per-tank gas mixes.
- `GasSwitch` / `GasSwitchWithTank` records store imported switch timestamps and target tanks.
- `gasSwitchesProvider` already loads those switch records for dive-detail visualizations.
- `PlanCalculatorService` already demonstrates the intended multi-gas pattern: apply the current gas per segment, not once per dive.

The missing piece is the bridge between imported gas-switch data and historical decompression analysis.

## Solution

### High-Level Approach

Teach the historical dive analysis path to segment the imported profile by active gas and process those segments sequentially through the existing Bühlmann engine.

Instead of:

- one dive
- one gas
- one `processProfile(...)` call

the new flow becomes:

- one dive
- one ordered gas schedule derived from the imported dive
- one continuous tissue state stepped through the profile with the active gas in effect for each sample interval

### Design Decision: Keep Gas Awareness Above the Core Compartment Math

Do not fork or special-case the Bühlmann equations for imported dives.

`BuhlmannAlgorithm.calculateSegment(...)` already accepts `fN2` and `fHe` per segment, which is exactly the interface needed for gas switching. The change should happen at the profile-processing layer:

- either extend `BuhlmannAlgorithm.processProfile(...)` to accept a gas schedule,
- or add a new gas-aware profile-processing entry point and keep the existing single-gas method as a convenience wrapper.

The preferred design is a new explicit gas-aware API so call sites cannot accidentally pass a mixed-gas dive through the single-gas path.

### New Domain Model: Gas Schedule Over a Profile

Add a lightweight analysis-only model describing which gas is active over which timestamps.

Example shape:

```dart
class ProfileGasSegment {
  final int startTimestamp;
  final int? endTimestamp;
  final double o2Fraction;
  final double heFraction;
  final String? tankId;
}
```

This model is intentionally simpler than planner segments:

- no depth data
- no duration ownership beyond timestamps
- no planner-only concerns like reserve gas or warning generation

Its job is only to answer: "What gas should the decompression engine use for this profile interval?"

### Gas Schedule Construction Rules

Build the gas schedule in `profileAnalysisProvider` before isolate execution.

Rules:

1. Use the first tank as the default starting gas when at least one tank exists.
2. Load imported gas-switch records in timestamp order.
3. Each switch changes the active gas from that timestamp forward.
4. If any switch points to a missing tank, or to a tank without a usable gas mix, treat the gas-aware decompression analysis as invalid rather than silently guessing.
5. If there are no switch records, keep the current single-gas behavior.

This keeps the source-of-truth policy in the provider layer, where the dive, tanks, switches, and user preferences are already available.

### Analysis Validity and Failure Semantics

Bad gas-switch records are not just a minor logging concern. If the imported profile says the diver switched gases, but the app cannot resolve the target tank or its gas mix, then the app no longer knows what inert-gas fractions were actually breathed for part of the dive. In that situation, continuing to show calculated NDL / ceiling / TTS / deco-stop outputs as though they were trustworthy is misleading.

For this feature, gas-aware decompression should therefore have an explicit validity concept.

Recommended behavior:

- if the dive has no gas switches, preserve the current single-gas analysis path,
- if the dive has gas switches and all referenced tanks resolve cleanly, run gas-aware decompression normally,
- if the dive has gas switches but any switch cannot be resolved to a usable gas mix, mark calculated decompression as invalid for that dive.

When decompression is invalid because of unresolved gas-switch data:

- do not silently fall back to "keep using the previous gas" for calculated decompression metrics,
- prefer computer-reported decompression metrics if they exist and the user selected that source,
- otherwise suppress or clearly mark calculated deco outputs as unavailable / unreliable.

This design intentionally favors honesty over continuity.

### Calc / DC Comparison UX

Replace the current per-metric `DC / Calc` source selector with two independent visibility toggles per metric when dive-computer data exists for that metric:

- `Calc`
- `DC`

Behavior:

- only show the pair of toggles for metrics that actually have imported dive-computer data,
- if a metric has no dive-computer data, show no `DC / Calc` toggles for that metric and continue to display calculated data only,
- default to calculated data visible and dive-computer data hidden,
- allow the user to show either source, neither source, or both sources for the same metric,
- preserve existing settings support by treating the calculated series as the default baseline view.

Rendering guidance:

- calculated data should use the solid line,
- dive-computer data should use a dotted line of the same color,
- this makes overlap visually obvious when the two models agree and makes divergence easier to inspect when they differ.

Rationale:

- many dive computers only emit some decompression metrics sparsely,
- showing both series independently avoids blending incompatible sources into one line,
- the comparison also becomes a useful debugging and validation tool for multi-gas imported dives.

### Invalid Gas-Switch UX

For the first UI pass, surface invalid gas-switch resolution as a visible warning icon adjacent to the existing "more chart options" control.

Behavior:

- show a yellow caution icon when calculated decompression is invalid because of an unresolved gas switch,
- place the icon immediately to the right of the "more chart options" control so the warning is visible without opening the menu,
- on hover / long-press, show tooltip text that identifies the failing switch timestamp.

Suggested stronger copy:

- `Calculated deco unavailable: unknown gas switch at 18:42`

The stronger copy is preferable because it explains the consequence, not just the underlying record problem. If there are multiple invalid switches, the UI can either:

- show the first invalid timestamp in the tooltip for brevity, or
- summarize with a plural form such as `Calculated deco unavailable: 2 unknown gas switches`.

The implementation should use the timestamp already present on the unresolved switch record and format it consistently with the rest of the dive-detail UI.

### Interface Implications

The current interface does not appear to have a first-class concept of decompression-analysis validity or reliability. As part of this work, introduce an explicit status/warning shape somewhere in the analysis output path.

Possible forms:

- `decoCalculationState`
- `decoCalculationWarnings`
- `gasScheduleResolutionState`
- `isCalculatedDecoReliable`

The exact field names and placement can follow the existing interface style once the current UI/result types are reviewed more closely, but the feature should not ship with invalid gas-switch analysis represented only as logs.

### Analysis Service API Changes

Extend `ProfileAnalysisService.analyze(...)` to accept either:

- `List<ProfileGasSegment>? gasSegments`

or a richer analysis input object that contains the gas schedule.

When `gasSegments` is null or empty:

- preserve the current one-gas path exactly.

When `gasSegments` is present:

- reset or preload tissues as today,
- iterate sample-to-sample through the profile,
- resolve the active gas for each interval,
- call `calculateSegment(...)` with that interval's gas,
- snapshot `DecoStatus` at each profile point.

`BuhlmannAlgorithm` should expose a helper for this gas-aware profile traversal so the service and tests do not duplicate sample stepping logic.

### Recommended Core API Addition

Add a new method in `BuhlmannAlgorithm`:

```dart
List<DecoStatus> processProfileWithGasSegments({
  required List<double> depths,
  required List<int> timestamps,
  required List<ProfileGasSegment> gasSegments,
})
```

Behavior:

- validates non-empty, time-ordered gas segments,
- resolves the active gas for each profile interval,
- applies the segment gas to `calculateSegment(...)`,
- preserves the existing safety-stop-aware TTS countdown logic,
- returns the same `DecoStatus` series shape the rest of the app already expects.

The existing `processProfile(...)` remains as a wrapper for the single-gas case.

### Provider Integration

`profileAnalysisProvider` should:

1. Load `gasSwitchesProvider(dive.id)` alongside the dive.
2. Convert the dive's tanks plus switch records into ordered `ProfileGasSegment` values.
3. Pass those gas segments into `_ProfileAnalysisInput`.
4. Forward them into `ProfileAnalysisService.analyze(...)`.

This keeps the isolate boundary explicit and prevents the analysis service from taking a repository dependency.

### Dive Planner / Historical Dive Parity

This change brings historical-dive analysis closer to planner semantics:

- planner path: explicit gas per segment
- imported profile path: explicit gas per timestamp range

They do not need to share the exact same input types, but they should share the same fundamental rule:

> Tissue loading for each interval is driven by the gas actually being breathed during that interval.

## Edge Cases

### No Tanks

If an imported dive has no tanks, keep the current fallback of air unless some other import path already supplied a usable gas mix.

### No Gas Switches

Single-gas behavior remains unchanged.

### Gas Switch at Timestamp 0

Honor it. It overrides the default "first tank" assumption immediately.

### Multiple Switches at the Same Timestamp

Use the last switch in timestamp order after sorting. Log a debug warning for duplicate timestamps.

### Switch Beyond Profile End

Ignore it.

### Missing Tank Referenced by Switch

Do not silently continue with a guessed gas schedule. Treat gas-aware calculated decompression as invalid unless the interface intentionally surfaces that degraded state and suppresses misleading outputs.

### Computer-Reported Deco Overlays

Overlay precedence is unchanged for this phase, but the long-term UI direction is to show calculated and dive-computer series independently instead of forcing a single source choice.

For the current implementation and migration path:

- if computer-reported `ndl`, `ceiling`, `tts`, or `cns` data exists, the existing overlay path can still provide those values,
- if calculated deco is invalid and no computer data exists for a metric, the UI should not present a normal calculated value for that metric without an explicit degraded-data indication.

For the follow-up `Calc` / `DC` dual-toggle implementation:

- `Calc` visible should show calculated data only when calculated deco is valid; otherwise it should remain blank and rely on the warning indicator,
- `DC` visible should show dive-computer data only for metrics that have imported computer data,
- sparse dive-computer data should be rendered as a distinct dive-computer series rather than silently merged back into calculated values.

### Repetitive Dives

Improved automatically. The carried-forward end-of-dive tissue compartments will now reflect the actual gas schedule used during the imported dive instead of an all-on-first-tank approximation.

## Files Expected to Change

| File | Change |
|------|--------|
| `lib/core/deco/constants/buhlmann_coefficients.dart` | Normalize `airN2Fraction` from `0.79` to `0.7902` |
| `lib/core/deco/buhlmann_algorithm.dart` | Add gas-aware profile processing helper and keep single-gas wrapper behavior |
| `lib/core/deco/entities/` | Add a lightweight gas-schedule entity if the model lives in core |
| `lib/features/dive_log/data/services/profile_analysis_service.dart` | Accept gas schedule input and use gas-aware processing when present |
| `lib/features/dive_log/presentation/providers/profile_analysis_provider.dart` | Load gas switches, build gas schedule, pass it through isolate input |
| `lib/features/dive_log/data/services/profile_analysis_service.dart` or related analysis result types | Add explicit validity / warning state for unresolved gas-switch decompression |
| `lib/features/dive_log/presentation/providers/gas_switch_providers.dart` | No functional change required; reused as the switch source |
| `test/core/deco/buhlmann_algorithm_test.dart` | Add gas-aware profile-processing and tissue-loading sanity tests |
| `test/features/dive_log/data/services/profile_analysis_service_test.dart` | Add imported-profile multi-gas analysis tests |
| `test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart` | Add provider-level gas-schedule integration tests |

## Testing

### Reference-Validation Notes

Some of the exact benchmark values we should test against depend on the constants and coefficient tables actually used by this codebase.

Important examples:

- This implementation currently uses water vapor correction via `(ambientPressure - 0.0627)`.
- Surface-saturated tissues in this code load toward inspired surface nitrogen, not raw `0.79`.
- Expected surface M-values must be derived from the exact `a` / `b` coefficients in `buhlmann_coefficients.dart`.

As part of this work, normalize `airN2Fraction` to `0.7902` so the implementation better matches canonical Bühlmann-style references. The benchmark expectations in the tests should then be computed from the updated repo constants rather than preserving compatibility with the older rounded approximation.

### Constant Normalization

Include a small foundational cleanup in the same work:

- change `airN2Fraction` in `buhlmann_coefficients.dart` from `0.79` to `0.7902`,
- update any directly dependent tests to use the normalized constant,
- prefer deriving expected inspired-gas values from helpers/constants in test code rather than repeating stale literals.

This is intentionally in scope because the new benchmark tests are meant to validate against standard Bühlmann assumptions, and the code should align with that baseline instead of baking the older rounded constant into the new suite.

### Core Algorithm Tests

Add unit tests in `test/core/deco/buhlmann_algorithm_test.dart` for the new gas-aware profile-processing path:

- Single-gas wrapper parity:
  - `processProfileWithGasSegments(...)` with one air segment matches the existing single-gas `processProfile(...)` outputs.
- Gas switch changes tissue loading:
  - identical dive profile,
  - case A: calculated entirely on air,
  - case B: switch from air to EAN32 at the start of ascent,
  - assert lower leading-compartment inert gas loading in case B near the end of the dive.
- Gas switch changes decompression outputs in the right direction:
  - the EAN32-switch case should have lower-or-equal ceiling, lower-or-equal TTS, and greater-or-equal NDL than the all-air case at equivalent timestamps after the switch.

### Additional Bühlmann Validation Tests

Add a deeper benchmark subsection in `test/core/deco/buhlmann_algorithm_test.dart` and, where appropriate, in dedicated helper/constant tests.

#### 1. Half-Time Convergence Test

Purpose:

- verify the compartment loading math itself, independent of profile-processing logic.

Test shape:

- initialize a compartment to a known starting inert-gas pressure,
- expose it to a constant inspired-gas pressure,
- run exactly one half-time,
- assert the compartment has moved 50% of the way from start pressure to inspired pressure.

Recommendation:

- write this against the project's actual inspired-pressure helper and current constants rather than hardcoding an external variant.
- if needed, expose or factor a small helper so the test can validate the same math path used by `calculateSegment(...)`.

#### 2. Saturation Equilibrium Test

Purpose:

- prove that a very long constant-depth exposure asymptotically converges to the inspired partial pressure for every compartment.

Test shape:

- hold the model at constant depth for far longer than the slowest half-time,
- assert all 16 compartments are within a tight epsilon of the expected inspired inert-gas pressure.

This should be written for:

- air,
- and at least one richer nitrox mix.

#### 3. Alveolar / Inspired Gas Constant Check

Purpose:

- pin the water-vapor-corrected inspired-gas calculation so future refactors do not silently drift.

Test shape:

- assert `calculateInspiredN2(1.0, airN2Fraction)` matches the current implementation contract,
- assert deeper inspired-gas values scale correctly with gas fraction.

This is especially important because tiny differences here change NDLs and tissue pressures everywhere else. After the constant normalization above, these tests should explicitly reflect the `0.7902` baseline.

#### 4. Surface M-Value Benchmark Test

Purpose:

- validate the `a` / `b` coefficient table and `M0 = a + (1 / b)` logic.

Test shape:

- choose representative fast, medium, and slow compartments,
- compute their surface M-values from the exact coefficient table in this repo,
- assert the values match the expected results for those same constants.

This should live either in `buhlmann_algorithm_test.dart` or in a dedicated coefficient/compartment test file.

#### 5. Standard Air NDL / Ceiling Sanity Profile

Purpose:

- keep a recognizable real-world sanity profile in the suite, not just directional comparisons.

Test shape:

- square-profile air dive at 30m with GF 100/100,
- validate that NDL is in a plausible narrow range for this implementation,
- validate that extending the exposure beyond that point produces a positive ceiling / deco obligation.

This should not overfit to one descent-handling convention, but it should be strong enough to catch major regressions in raw Bühlmann behavior.

### Sanity Regression Tests Requested

Add explicit tests similar in spirit to the existing shallow-dive sanity tests:

- "all-air vs EAN32 switch" tissue sanity:
  - for the same imported profile, tissues should load less aggressively after switching to EAN32 than if the diver stayed on air.
- "all-air vs EAN32 switch" deco sanity:
  - the switched profile should never produce worse deco metrics than the all-air baseline once the richer gas is in use.

These tests should be written with enough margin to avoid overfitting to one exact minute count while still pinning the direction of the effect.

### Additional Gas-Fraction Validation Tests

Add gas-fraction-specific tests that ensure the implementation is not accidentally hardcoded for air.

#### 1. Inspired Pressure Ratio Test

At a fixed depth:

- compare inspired nitrogen on air vs EAN50,
- assert the ratio of loading pressure tracks the ratio of nitrogen fractions.

This can be done directly against the inspired-gas helper and indirectly against one-minute tissue-loading deltas in a fast compartment.

#### 2. Gas Switch Slope Test

Purpose:

- verify that a gas switch changes the tissue-loading slope immediately.

Test shape:

- stay at depth on air long enough to load fast tissues,
- switch to EAN50 while remaining at the same depth,
- assert the next interval's loading rate drops materially versus staying on air.

This is one of the most important tests for the new gas-aware imported-profile path.

#### 3. 6m Off-Gassing Benchmark

Purpose:

- verify that richer gases increase off-gassing efficiency at shallow stops.

Test shape:

- preload a representative compartment,
- compare 10 minutes at 6m on air vs EAN50,
- assert the EAN50 case finishes with lower inert-gas pressure than the air case.

This should be tested directly on compartment pressure, not just on NDL/TTS summaries.

#### 4. ppO2 Safety Gate

Purpose:

- verify that the gas-aware path does not treat an unsafe deco gas as merely a decompression benefit.

Test shape:

- analyze an EAN50 dive at an obviously unsafe depth,
- assert the existing ppO2 warning / critical logic fires.

This belongs primarily in planner or profile-analysis service tests, but it is worth calling out here because richer-gas support must not bypass safety checks.

### Service-Level Tests

Add `ProfileAnalysisService` tests that:

- verify `gasSegments` changes `ndlCurve`, `ceilingCurve`, and/or end-of-dive compartments compared with the same profile analyzed as all-air,
- verify null `gasSegments` preserves current behavior,
- verify malformed gas schedule inputs fail fast with a clear `ArgumentError`.
- verify unresolved switch targets or tanks with missing gas mixes mark calculated decompression as invalid rather than silently continuing.
- verify benchmark-style gas-switch cases:
  - air-only vs switch-to-EAN32 ascent,
  - air-only vs EAN50 shallow-stop off-gassing,
  - unsafe EAN50-at-depth still triggers ppO2 warnings.

### Provider-Level Tests

Add provider tests that:

- create a dive with two tanks and one imported gas switch,
- verify the analysis path no longer behaves like `dive.tanks.first` for the entire dive,
- verify missing or invalid gas-switch references produce an explicit invalid / unavailable calculated-deco state,
- verify computer-reported deco overlays can still populate metrics when calculated deco is invalid.

## Scope Boundaries

- No planner UI redesign in this work.
- No retroactive inference of switch events from tank pressure changes.
- No per-sample gas labeling added to the profile point entity in this first design.
- No attempt to model CCR/SCR gas switches differently here; that remains separate from this imported OC multi-gas improvement unless a specific import path already supplies that data in a compatible form.

## Open Questions

1. Should the gas-schedule entity live in `core/deco` or `features/dive_log`?
   - Recommendation: place it in `core/deco` if `BuhlmannAlgorithm` consumes it directly.

2. Should the provider always load gas switches, or only when `dive.tanks.length > 1`?
   - Recommendation: always load them; the logic is simpler and avoids hidden assumptions.

3. Should the same gas-aware path also drive gas-dependent curves like ppN2 and ppHe?
   - Recommendation: yes if practical in the same change, because those curves are currently also single-gas approximations for imported multi-gas dives.
   - If that broadens the implementation too much, the first milestone should still fix decompression metrics and document the remaining gas-analysis follow-up.

## Expected Outcome

After this change, imported dives with recorded gas switches will no longer be analyzed as if the diver stayed on the first tank for the entire dive. NDL, ceiling, TTS, deco stops, tissue loading, and repetitive-dive carryover will reflect the richer gases actually used during ascent and decompression, and the new sanity tests will guard against regressing back to the current all-air approximation.
