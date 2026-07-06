# Linear Tank Pressure Line — Design (issue #197)

Date: 2026-07-06
Branch: `issue-197-linear-tank-pressure-line`
Status: Approved (design choices confirmed with user)

## Problem

Reported in [#197](https://github.com/submersion-app/submersion/issues/197): when a dive
has a tank with manually-entered start/end pressures but **no air-integrated (AI)
transmitter data**, the dive profile chart draws no pressure information at all. The
request is to graph a linear start→end pressure line for such tanks so manual-entry dives
still get a pressure visualization.

### Why nothing is drawn today

A dive's per-tank pressure lives in two places:

- `DiveTanks.startPressure` / `endPressure` — two scalar values per tank
  (`database.dart:595-596`; domain `DiveTank`, `dive.dart:911`). Present for manual entry
  or computers that only log start/end.
- `TankPressureProfiles` — the time-series table populated by AI transmitters
  (`database.dart:1589`; domain `TankPressurePoint`, `dive.dart:893`).

The chart's pressure curve is built solely from the time-series map. `_hasMultiTankPressure`
(`dive_profile_chart.dart:532`) is `tankPressures != null && isNotEmpty`, and
`_buildMultiTankPressureLines` (`dive_profile_chart.dart:3585`) early-returns `[]` when that
is false. `TankPressureRepository.getTankPressuresForDive` (`tank_pressure_repository.dart:23`)
only emits map keys for tanks that have rows. So a tank with start/end pressures but zero
transmitter samples produces **no map key → no line**. The stored start/end pressures are
used only by the equipment table and the tooltip's start/end resolution, never as a chart
series. This is an unimplemented case, not a regression.

## Goals

1. Draw a linear start→end pressure line for any tank that has both pressures but no
   time-series data.
2. Shape the line like a real transmitter would have recorded it: flat while the tank is
   unused, sloping while it is being breathed (windowed by gas switches), flat again after.
3. Mark the line as **estimated** wherever pressure is surfaced (legend, tooltip, readout)
   so an interpolation is never mistaken for measured data.
4. No changes to stored data, SAC analysis, import, or export.

Non-goals: feeding the synthetic series into SAC/consumption (the Cylinder SAC card already
derives average SAC from start−end pressure); depth-weighting the drop rate (the issue asks
for a *linear* line, and depth-weighting would reintroduce the SAC modeling we are excluding);
persisting synthetic samples; changing how real AI pressure lines render.

## Design

The synthetic series is built **in memory at the chart-read path and never persisted.**
`TankPressureProfiles` keeps meaning "real measured data," so SAC analysis
(`profile_analysis_provider.dart:722`, which reads the repository directly) and UDDF export
(which also reads the repository) continue to see real data only — no "is this row fake?"
guard ever leaks into the data layer.

### 1. Trigger (evaluated per tank)

For each `DiveTank` in `dive.tanks`: if it already has rows in the real `tankPressures`
map, use them unchanged. Otherwise synthesize **iff** all of:

- `startPressure != null && endPressure != null`
- `startPressure > endPressure` — skips a flat "no gas used" line (`start == end`) and a
  physically impossible rising line (`end > start`, i.e. bad/absent data)
- the dive has a depth profile (`diveDurationSeconds > 0`)

Tanks that have real data and tanks that qualify for synthesis can coexist on the same dive
(mixed AI + manual); each is decided independently.

### 2. Active-tank intervals (new, reuses the proven timeline algorithm)

To window the line we need, per tankId, the `[start, end)` intervals during which that tank
was the breathed gas. `buildGasUsageSegments` (`gas_usage_segments_service.dart`) already
implements exactly this walk for the gas-timeline strip — starting tank = lowest
`DiveTank.order`, switches sorted and clamped to `[0, diveDurationSeconds]`, initial segment
`0→firstSwitch` (skipped if a switch sits at t=0), each switch running to the next and the
last to dive end — but it keys segments by **gas mix** and merges adjacent same-gas segments,
which would blur two tanks that share a mix. So it is not directly reusable.

Add a tank-keyed sibling in the same service file:

```
/// Per-tank active intervals: for each tankId, the [start, end) windows during
/// which it was the breathed gas. Same starting-tank + switch-walk rules as
/// buildGasUsageSegments, but keyed by tankId with NO gas-mix merging.
Map<String, List<({int start, int end})>> buildActiveTankIntervals({
  required List<DiveTank> tanks,
  required List<GasSwitchWithTank> gasSwitches,
  required int diveDurationSeconds,
});
```

- Starting tank (active from t=0) = the tank with the lowest `order`, matching
  `buildGasUsageSegments`. This is the one genuinely inferred input: "which tank you start
  the dive on" is not explicitly recorded.
- No switches → the starting tank owns one interval `[0, diveDurationSeconds]`; every other
  tank has none.
- A tank switched to and later away has one interval per use; a back gas returned to after a
  deco excursion has two intervals with a gap between them.

Optional cleanup (not required for v1, guarded by the existing gas-strip regression tests):
extract the shared switch-walk into one private helper that both `buildGasUsageSegments` and
`buildActiveTankIntervals` consume. Kept out of v1 scope to avoid perturbing the gas strip's
merge behavior.

### 3. Synthesized series shape (transmitter-style flat–drop–flat)

For a synthesized tank with `startPressure` S, `endPressure` E (S > E) and active intervals
`I = [(a1,b1), (a2,b2), …]` sorted by start:

- `totalActive = Σ(bk − ak)`. If `I` is empty or `totalActive ≤ 0` (a tank with start/end but
  no derivable window — e.g. never switched to and not the starting tank), **fall back** to a
  single interval `[0, diveDurationSeconds]` — a plain full-dive straight line.
- `dropRate = (S − E) / totalActive` (bar per second). Pressure is constant off-window and
  drops linearly on-window, so the total drop is distributed across the active intervals in
  proportion to their duration.
- Emit `TankPressurePoint`s (linear segments between consecutive points):
  - leading flat at S from `0` to `a1` if `a1 > 0`;
  - for each interval `(ak, bk)`: point `(ak, P)`, then `P −= dropRate·(bk−ak)`, point `(bk, P)`;
  - the gap to the next interval is drawn flat automatically by the segment from `(bk, P)` to
    `(a{k+1}, P)`;
  - trailing flat at E from the last `bn` to `diveDurationSeconds` (clamp the final pressure to
    E to absorb floating-point drift).

Worked example — a 40 min (2400 s) dive. Back gas AL80 (S=200, E=65) is the starting tank,
with a deco excursion to an EAN50 bottle (S=190, E=130) from 20–30 min; two switches are
recorded (to EAN50 at 1200 s, back to AL80 at 1800 s):

```
Back gas AL80  — active [0,1200]+[1800,2400], totalActive 1800 s, drop 135 bar (0.075 bar/s):
  (0,200) (1200,110)     // breathed: 200 -> 110   (0.075 x 1200 = 90)
  (1200,110) (1800,110)  // flat while on EAN50
  (1800,110) (2400,65)   // breathed again: 110 -> 65   (0.075 x 600 = 45)

Deco EAN50     — active [1200,1800], totalActive 600 s, drop 60 bar:
  (0,190) (1200,190)     // flat, full, until first breathed
  (1200,190) (1800,130)  // breathed: 190 -> 130
  (1800,130) (2400,130)  // flat, ~empty, after switch-away
```

The back gas shows drop–flat–drop (its 135 bar split 90/45 across the two active windows in
proportion to their durations); the deco bottle shows flat–drop–flat. For the common
single-tank recreational dive this collapses to exactly two points `(0, S) (diveEnd, E)` —
one straight line, zero added complexity.

### 4. Rendering & "estimated" marking

The synthesized points are placed into the same `tankPressures` map the chart already
consumes (see §5), so `_hasMultiTankPressure`, per-tank visibility initialization
(`_scheduleTankPressureVisibilityInitialization`, default visible), the tooltip interpolation
`_interpolateTankPressure` (`dive_profile_chart.dart:673`), and the legend's per-tank section
(`dive_profile_legend.dart:580`) all light up with no structural change.

A new `Set<String> estimatedTankIds` is threaded from the provider (§5) into
`DiveProfileChart` (new field) and its legend config. It drives three touch-ups:

- **Line builder** `_buildMultiTankPressureLines` (`dive_profile_chart.dart:3585`): for a
  tankId in `estimatedTankIds`, build the `LineChartBarData` with `isCurved: false` (crisp
  piecewise-linear — curve smoothing would round the flat→drop corners). Color, dash pattern
  (`_getTankDashPattern`), and `barWidth: 2` are unchanged, i.e. it looks like a normal
  pressure line; its straightness plus the label carry the "estimated" meaning. Real lines
  keep `isCurved: true`.
- **Legend** (`dive_profile_legend.dart:580`): tank rows whose tankId is estimated get an
  "estimated" badge/suffix next to the tank label. Toggle behavior is unchanged (per-tank
  `toggleTankPressure`, default visible).
- **Tooltip / draggable readout** (`dive_profile_chart.dart:1234` and `:2811`): append a
  localized "(est.)" suffix to the pressure row for estimated tankIds. The interpolated value
  itself needs no special handling.

### 5. Provider wiring

`tankPressuresProvider` (`dive_providers.dart:950`) is left untouched (it still feeds any
non-chart consumers and, indirectly, is what we augment). Add a composing provider:

```
/// Real per-tank pressures augmented with in-memory linear estimates for tanks
/// that have start/end pressures but no transmitter data. Chart-only; never persisted.
final estimatedTankPressuresProvider =
    FutureProvider.family<EstimatedTankPressures, String>((ref, diveId) async {
  final real = await ref.watch(tankPressuresProvider(diveId).future);
  final dive = await ref.watch(diveProvider(diveId).future);          // dive_providers.dart:160
  final switches = await ref.watch(gasSwitchesProvider(diveId).future); // gas_switch_providers.dart:9
  if (dive == null) return EstimatedTankPressures(real, const <String>{});
  return synthesizeEstimatedTankPressures(
    existing: real,
    tanks: dive.tanks,
    gasSwitches: switches,
    diveDurationSeconds: dive.profile.isEmpty ? 0 : dive.profile.last.timestamp,
  );
});
```

`EstimatedTankPressures` is a small immutable holder for
`({Map<String, List<TankPressurePoint>> pressures, Set<String> estimatedTankIds})`. It
self-invalidates transitively because all three watched providers already invalidate on
`watchDiveDetailChanges()`.

`synthesizeEstimatedTankPressures(...)` is the pure, Flutter/DB-free entry point (§1–§3): it
calls `buildActiveTankIntervals`, applies the trigger rule, builds the flat–drop–flat points,
copies real entries through untouched, and returns the augmented map plus the set of
synthesized tankIds. This is where the bulk of the unit tests point.

The three chart hosts — `dive_profile_panel.dart` (`:248`+), `dive_detail_page.dart`, and
`fullscreen_profile_page.dart` — replace their `tankPressuresProvider` watch with
`estimatedTankPressuresProvider`, pass `result.pressures` to `tankPressures:`, and pass
`result.estimatedTankIds` to the new `estimatedTankIds:` chart argument. Each host already
holds `dive`, `gasSwitches`, and `tankPressures` in scope, so no other plumbing changes.

## Data integrity

Because synthesis happens only in `estimatedTankPressuresProvider` / the pure helper, the
following remain fed exclusively by real `TankPressureProfiles` rows and are therefore
unaffected: SAC curve and instrument tiles (`computeAnalysisForProfile` →
`combineMultiTankPressures`, `profile_analysis_provider.dart:722`), the Cylinder SAC card,
and all export paths (UDDF and others read `TankPressureRepository` directly). No migration,
sync, or schema change.

## Testing (TDD — failing tests first)

Unit tests on the pure functions (no widget pumping):

1. **`buildActiveTankIntervals`**: single tank / no switches → one full-dive interval for the
   lowest-`order` tank, none for others; a stage switched to at 1800s and back at 2400s → the
   stage owns `[1800,2400)`; a back gas returned to after an excursion → two intervals with a
   gap; a switch exactly at t=0 → no zero-length leading interval; switches clamped to bounds.
2. **`synthesizeEstimatedTankPressures` trigger**: synthesizes only when both pressures set,
   `start > end`, and duration > 0; real-data tanks pass through untouched; `start == end`,
   `end > start`, missing pressures, and empty profile all skip; mixed dive yields real for
   one tank and synthetic for another.
3. **Series shape**: single-tank dive → exactly `(0,S)`,`(end,E)`; stage bottle → leading flat
   at S, single linear drop, endpoint at E; two-interval back gas → drop split proportionally,
   flat in the gap, final point clamped to E; no-window tank → full-dive straight-line fallback.
4. **`estimatedTankIds`**: contains exactly the synthesized tankIds and never a real-data tankId.

Widget tests (pump `DiveProfileChart`, read `LineChart` `LineChartData`), following existing
chart test patterns; mark new helpers `@visibleForTesting` where cleaner:

5. **Line present & crisp**: a manual-only dive yields a pressure `LineChartBarData` with
   `isCurved == false`; a real-AI dive keeps `isCurved == true`.
6. **Legend**: an estimated tank row shows the "estimated" badge; a real tank row does not;
   the per-tank toggle still hides/shows the synthetic line.
7. **Tooltip/readout**: the pressure row for an estimated tank carries the "(est.)" suffix.
8. **Regression**: existing `dive_profile_chart` / gas-strip tests still pass (no change to
   `buildGasUsageSegments` output; real pressure rendering unchanged).

## Localization

New key(s) for the "estimated" badge and the "(est.)" suffix (a single key reused for both,
or two keys) added to all 11 `lib/l10n/arb/app_*.arb` files (en + ar, de, es, fr, he, hu, it,
nl, pt, zh — translated, not English fallbacks), then `flutter gen-l10n` regenerated.

## Files touched

- `lib/features/dive_log/data/services/gas_usage_segments_service.dart` — add
  `buildActiveTankIntervals` (tank-keyed sibling).
- `lib/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart` (new) —
  pure `synthesizeEstimatedTankPressures` + `EstimatedTankPressures` holder (sits beside
  `gas_usage_segments_service.dart`, which it depends on; both are DB-free pure services).
- `lib/features/dive_log/presentation/providers/dive_providers.dart` — new
  `estimatedTankPressuresProvider`.
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` — new
  `estimatedTankIds` field; `isCurved:false` for estimated tanks in
  `_buildMultiTankPressureLines`; "(est.)" suffix in tooltip + readout rows; pass estimated
  set into legend config.
- `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` — "estimated" badge on
  estimated tank rows; config field.
- `lib/features/dive_log/presentation/widgets/dive_profile_panel.dart`,
  `lib/features/dive_log/presentation/pages/dive_detail_page.dart`,
  `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart` — consume
  `estimatedTankPressuresProvider`; pass `estimatedTankIds`.
- `lib/l10n/arb/app_*.arb` (11) + regenerated `app_localizations*.dart`.
- Tests under `test/features/dive_log/...` (new unit + widget, updates to regressions).
