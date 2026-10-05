# Gas-Switch Efficiency: Late and Missed Deco Gas Switches

**Date:** 2026-10-05

Tracking: issue #2939. Refs Discussion #326, follow-up to #458 and the
[2026-06-28 gas-aware ascent spec](./2026-06-28-gas-aware-ascent-deco-design.md).

## Problem

Since #458 the calculated ascent (TTS, ceiling, stop schedule) assumes the
diver switches to the best eligible gas at its MOD. The #458 spec deliberately
kept technique feedback out of TTS, so TTS stays physical and cross-checkable
against the dive computer, and deferred it to "a separate metric" that was
never built.

A diver who sits on back gas through 21 m with EAN50 clipped on gets no
feedback: the calculated TTS stays optimal and nothing shows that the real
ascent cost more decompression than it needed to.

## Goals

- Detect late and missed open-circuit deco gas switches by comparing the gas
  actually breathed with the gas the projection already assumes.
- Quantify each one: the delay (time and depth) and the extra deco it caused.
- Shade each flagged window on the profile chart as a toggleable overlay with
  a tooltip.
- Summarise the result on the dive detail page and as a safety review finding.

## Non-Goals

- No change to TTS, ceiling, deco stops, CNS or any other `DecoStatus` value
  or `ProfileAnalysis` curve. This is a read-only comparison layered on top.
- No CCR/SCR or bailout analysis (`CcrLoopAscentGas` is out of scope).
- No invented gases: only cylinders recorded on the dive.
- No flag for an early switch (deeper than MOD). That is a ppO2 exposure
  question the existing ppO2 warnings already answer.
- No user-configurable tolerance. The thresholds are fixed rules.

## Decisions

| Question | Decision |
| --- | --- |
| Cost metric | Tissue replay: the largest TTS gap between the as-dived tissues and tissues replayed with an on-time switch |
| Tolerance | Late only when the switch is more than one deco stop increment shallower than the ideal depth, or more than 2 minutes after the ideal time |
| No-deco dives | Flag a window only if the ceiling was above zero at some sample in it |
| Overlay persistence | Persisted per-diver default, default ON |
| Summary | Card in the dive detail Deco section, plus a safety review rule |
| Architecture | Pure analyzer called inside `ProfileAnalysisService.analyze` (approach A) |

Rejected architectures:

- A separate provider computing the metric outside `analyze()`. It would have
  to re-resolve GF source, environment, residual tissues and the ascent gas
  set, and any drift from `_resolveAnalysisService` would make the "ideal"
  switch point disagree with TTS.
- Emitting counterfactual series from `processProfileWithGasSegments`. That
  touches the engine path that must stay byte-identical.

## Detection

### Inputs

All inputs already exist inside `ProfileAnalysisService.analyze` on the OC
path: the sanitized `depths`, `timestamps`, the recorded `gasSegments`, the
`OptimalOcAscentGas` plan built from `buildAvailableGases` (same "Plan ascent
with" filter and `ppO2MaxDeco` MODs as TTS), `startCompartments`, the GF pair,
the environment and the schedule policy (stop increment, last stop depth).

The analyzer runs only when the dive mode is OC, the ascent plan is an
`OptimalOcAscentGas`, and the plan holds at least two distinct mixes. Gases
are matched by mix (fO2, fHe), never by tank, so two sidemount cylinders of the
same mix never produce a "missed" switch. `buildAvailableGases` already
deduplicates identical mixes.

### Ideal switch time per gas

For each available gas `g` with MOD `M(g)`:

- `g` is **assessed** only if some sample is deeper than `M(g) + 1.0 m`. A gas
  the dive never took below its MOD has no ascent crossing, so it is never
  assessed. An 18 m dive carrying EAN50 is not flagged for leaving it clipped
  off during the bottom phase. The 1 m hysteresis absorbs waves and sensor
  noise at a stop near the MOD.
- `idealTimestamp(g)` is the timestamp of the first sample at or above
  `M(g)` after the last sample deeper than `M(g) + 1.0 m`. A gas with no such
  sample (a recording that stops inside the hysteresis band) is not assessed.
- `idealDepth(g)` is `min(M(g), depth at idealTimestamp(g))`.

This makes the "final ascent" a per-gas property, so a multi-level dive that
comes shallower than a deco gas's MOD mid-dive and then descends again is not
flagged.

### Per-sample comparison

At each sample `i` with timestamp `t`:

- The **eligible set** is every assessed gas whose `idealTimestamp <= t` and
  whose MOD is at or below `depths[i]` (so a sample inside the 1 m hysteresis
  band never demands the switch). When it is empty, the sample is not behind.
- The **ideal gas** is the choice of an `OptimalOcAscentGas` built over the
  eligible set only, at `depths[i]`. The plan's own preference and
  tie-breaking rules (highest O2, then higher He, then lower N2) are reused,
  not reimplemented.
- The **actual gas** is the recorded segment active at `t`. Mixes are compared
  by fO2 and fHe within 0.005, because recorded air segments carry
  `airN2Fraction` (0.7902) while cylinders derive 0.79.
- The sample is **behind** when the ideal gas has a strictly higher fO2 than
  the actual gas **and** the diver has not yet breathed the ideal gas since its
  `idealTimestamp`. The second condition keeps air breaks (a deliberate return
  to a leaner gas after switching, for example 5 minutes of back gas every 20
  minutes on O2) from reading as late switches.

A **window** is a maximal run of behind samples sharing the same ideal gas. Its
ideal time and depth are those of its first sample: `idealTimestamp` is that
sample's timestamp and `idealDepth` is `min(MOD, depth there)`. It ends at the
first sample where any of the following happens:

- The diver switches to the ideal gas. This is a **late** window.
- The ideal gas changes to a richer gas, for example from EAN50 to O2 at 6 m.
- The dive ends.

A window whose gas the diver breathes at any sample from the window's start
onward is **late**, with the switch at the first such sample. A window whose gas
is never breathed from its start onward is a **missed** window. Example: skipping EAN50 and switching
straight to O2 at 6 m gives a missed-EAN50 window from the EAN50 ideal time to
the O2 switch.

### Flag rule

A window is flagged only if the ceiling (from the existing
`ProfileAnalysis.ceilingCurve`, read only) is above zero at some sample in it.
Then:

- **Late:** flagged when `idealDepth - switchDepth > stopIncrement` (the diver
  setting, default 3 m) or `switchTimestamp - idealTimestamp > 120 s`.
- **Missed:** always flagged.

`switchDepth` is the profile depth at the switch timestamp, because
`GasSwitch.depth` is nullable.

### Delay

- `delaySeconds = (switchTimestamp ?? endTimestamp) - idealTimestamp`.
- `depthDelayMeters = idealDepth - switchDepth` for a late window; null for a
  missed one.

## Extra deco (tissue replay)

The analyzer owns its own `BuhlmannAlgorithm` instance, configured exactly like
the analysis engine. It never mutates the analysis engine and never reads back
`decoStatuses`.

1. Replay the profile from the dive start with the recorded gases
   (`calculateSegment` per sample interval, seeded from `startCompartments`
   when present). This reproduces the running GF-low anchor, which
   `DecoStatus` does not store, so the fork state is exact.
2. At a window's first sample, capture the state (compartments plus
   `gfLowCeilingAnchor`) and fork into two runs over the identical depth
   trace to the end of the dive:
   - **actual:** the recorded gases throughout;
   - **counterfactual:** the window's ideal gas for every sample inside the
     window, the recorded gases afterwards.
3. Every 30 s of dive time (and at the window's last sample), compute TTS for
   both runs with the same `OptimalOcAscentGas` plan and schedule policy,
   using `restoreState` on a scratch engine so the TTS search never disturbs
   the replay.
4. `extraDecoSeconds` for the window is the maximum of
   `ttsActual - ttsCounterfactual` over those evaluation points, floored at 0.

The peak gap works for both kinds. For a late switch it lands near the
recorded switch. For a missed switch it lands mid-deco, where a "TTS at the
end" measure would read zero once both runs have surfaced.

Each window is costed with only itself fixed. `totalExtraDecoSeconds` comes
from one more counterfactual run that fixes every flagged window at once. It
is not a sum, because the windows interact.

The 30 s stride bounds the cost: the analysis already computes TTS at every
sample, so this adds at most two TTS evaluations per 30 s of the remaining
dive per window.

## Data model

New immutable types in `lib/core/deco/gas_switch/`, each with `copyWith` and
Equatable:

```dart
enum GasSwitchWindowKind { late, missed }

class GasSwitchWindow {
  final GasSwitchWindowKind kind;
  final double fO2;
  final double fHe;
  final int idealTimestamp;
  final double idealDepth;
  final int? switchTimestamp; // null when missed
  final double? switchDepth; // null when missed
  final int endTimestamp;
  final int delaySeconds;
  final double? depthDelayMeters; // null when missed
  final int extraDecoSeconds;
}

class GasSwitchEfficiency {
  final bool evaluated; // OC, >= 2 mixes, a deco obligation, >= 1 gas assessed
  final List<GasSwitchWindow> windows; // flagged only, time-ordered
  final int totalExtraDecoSeconds;
}
```

`ProfileAnalysis` gains a nullable `gasSwitchEfficiency` field, included in
`copyWith`, `empty()` and equality. It is null on gauge, CCR and SCR dives and
when the plan holds fewer than two mixes. `evaluated` is false when the dive
had no deco obligation or no gas was assessed (a dive that never went below any
gas's MOD, where bottom time and deco cannot be told apart). It lets the UI
tell "all
switches on time" apart from "not applicable". `ProfileAnalysis` is never
persisted, so `analysisEngineVersion` does not change.

## UI

### Profile chart overlay

- `ProfileLegendState.showLateGasSwitches` is seeded from a new persisted
  diver setting, `defaultShowLateGasSwitches`, which defaults to ON. A
  `toggleLateGasSwitches()` method is added, and the six spots in
  `profile_legend_provider.dart` are updated.
- Persisting the default needs:
  - a diver-settings column;
  - a migration rung in `lib/core/database/migrations/ladder/rungs_v231_onward.dart`
    (schema 260 to 261; nothing is added to `database.dart` beyond the
    version constant);
  - the sync serializer default;
  - `diver_settings_repository.dart` and `settings_providers.dart`;
  - a toggle on the Appearance settings page, next to the existing
    gas-switch-markers default, which is where that default already lives.
- `ProfileLegendConfig.hasLateGasSwitches` is true when the analysis has at
  least one flagged window. It is OR-ed into `hasSecondaryToggles`.
- The chart options dialog gets a row in its Markers section, next to the gas
  switch markers row, and `active_legend_entries.dart` gets a legend chip.
- Bands: `DiveProfileChart` gains a `gasSwitchEfficiency` parameter, passed as
  `analysis?.gasSwitchEfficiency` at its three call sites
  (`dive_profile_chart_host.dart`, `dive_profile_panel.dart`,
  `fullscreen_profile_page.dart`), right beside the `ttsCurve` each already
  passes from the same analysis. They are drawn in
  `_buildHighlightRangeAnnotations`,
  before the cell-divergence and selection bands, gated by the new toggle, not
  by `_showO2Cells`. Each band is tinted with `GasColors.forMixFraction` of the
  gas that should have been breathed, at alpha 0.12, and clamped with
  `visibleHighlightSpan`.
- Tooltip: when the cursor sample falls inside a flagged window,
  `_buildTooltipRowsForIndex` adds short rows, because a row value gets only
  half of the tooltip's 320 px width:
  - "Late switch" (or "Missed switch"): the gas, for example "EAN50";
  - "Delay": "4:40 / 6 m", or "2:10" for a switch late by time alone; no
    delay row for a missed switch;
  - "Extra deco": "+3:00".
  Depth uses the active diver's unit settings, and gas labels reuse the
  existing mix formatter.
- The TTS and ceiling curves are not touched.

### Dive detail

A "Gas switches" card is added inside the Deco section's `_decoPanelCards`, in
`dive_detail_page.dart`, next to the deco status and O₂ toxicity cards. The
card is its own widget file in `lib/features/dive_log/presentation/widgets/`.
It is shown only when `gasSwitchEfficiency?.evaluated == true`.

- When there are flagged windows, it lists one row per window: the gas, the
  ideal depth and the actual switch depth (or "not switched"), the delay and
  the extra deco. It ends with a total line.
- When none are flagged, it shows one line: "All gas switches on time".

### Safety review

- `SafetyRuleId.lateGasSwitch` produces one finding per flagged window:
  - `startTimestamp` and `endTimestamp` are the window;
  - `value` is the extra deco in seconds;
  - severity is caution, or significant when the extra deco is 5 min or more.
- `SafetyReviewService.engineVersion` goes from 5 to 6, so each dive is
  re-reviewed lazily the next time it is analysed.
- The rule reads `analysis.gasSwitchEfficiency`. No new review input is
  needed.
- Copy is added in `safety_finding_text.dart`, and the rule is added to the
  name switch in `safety_settings_page.dart` so it can be toggled.
- Tapping the finding highlights the window through the existing
  `profileHighlightRangeFor`.

### Localization

New keys go in all 11 ARB files, following the `diveLog_legend_label_*`,
`safetyReview_*`, `safetySettings_rule_*` and dive detail key patterns. Run
the l10n generator afterwards.

## Testing (TDD)

- **Analyzer unit tests** (synthetic profiles, `lib/core/deco/gas_switch/`):
  - on time within tolerance (switch at 21 m for EAN50 with MOD 22 m, 60 s
    procedure), not flagged;
  - late by depth (switch at 15 m), flagged with depth delay;
  - late by time (3 min on back gas at 21 m before switching), flagged;
  - missed gas (EAN50 never breathed), flagged as missed;
  - skipped intermediate gas (straight to O2 at 6 m), EAN50 missed and no O2
    window;
  - a mid-dive excursion above the MOD followed by a descent, not flagged;
  - a shallow deco dive never deeper than the deco gas's MOD, gas not
    assessed, `evaluated == false` and nothing flagged;
  - a no-deco dive with an unused deco bottle, `evaluated == false`, nothing
    flagged;
  - sidemount cylinders of the same mix, nothing flagged;
  - air breaks on O2 at 6 m after an on-time switch, nothing flagged;
  - a recorded switch to a gas outside the plan (a pony bottle excluded by the
    `decoStageOnly` gas set) creates no window of its own;
  - `extraDecoSeconds > 0` for late and missed windows, and 0 when the
    counterfactual equals the actual;
  - the total from the all-fixed run is at most the sum of the per-window
    costs.
- **Byte identity:** with the analyzer on, every other `ProfileAnalysis` field
  equals the analyzer-off result for the OC fixture
  `test/dives/001_short_deco_single_gas_switch.ssrf.xml` and for a synthetic
  multi-gas dive. The CCR fixtures produce a null `gasSwitchEfficiency`.
- **Safety review:** the rule emits the right severity and range, is skipped
  when disabled, and `engineVersion` is 6.
- **Legend provider:** the seed from settings and the toggle.
- **Widgets:** the chart draws a band per flagged window only while the toggle
  is on, and the tooltip row text appears in metric and imperial units. The
  detail card renders the list, the "on time" line, and nothing when not
  evaluated.
- **Settings:** the migration test for the new column (default ON), the
  repository round-trip, and the sync serializer default.

## Acceptance Criteria

- Late and missed OC deco gas switches are detected against the same gas set,
  MODs and tie-breaking as the TTS projection, with the tolerance and
  obligation rules above.
- Each flagged window reports delay and extra deco by tissue replay. The dive
  reports a total.
- The profile chart shades each window, with a tooltip, behind a toggle whose
  default is a persisted diver setting.
- Dive detail shows the Gas switches card, and the safety review raises
  `lateGasSwitch` findings.
- TTS, ceiling, deco stops, CNS and every other `ProfileAnalysis` value are
  byte-identical to `main`.
- Depths and times follow the diver's unit settings.
