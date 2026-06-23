# Ascent Rate Graphing — Design (issue #242)

Date: 2026-06-23
Branch: `worktree-issue-242-ascent-rate-not-graphed`
Status: Approved (design choices confirmed with user)

## Problem

Reported in [#242](https://github.com/submersion-app/submersion/issues/242): the dive
profile graph does not show ascent rate, even when the "Ascent Rate" legend toggle is
checked. The reporter (UDDF import from Subsurface, Teric computer) sees "Ascent Rate
Warning" event markers but no ascent-rate visualization.

### Root cause (confirmed)

The "Ascent Rate" overlay toggle is bound to `ProfileLegendState.showAscentRateColors`,
but that flag only adds a "Rate" row to the chart tooltip. **No `lineBarsData` entry or
depth-line coloring ever consumes the ascent-rate data**, so toggling it on renders
nothing on the plot. The field is documented as "Whether to color depth line by ascent
rate", but git history shows the depth line was always drawn in a single solid colour
(`AppColors.chartDepth`) — the coloring was never implemented. This is an unfinished
feature, not a regression.

The data itself is fine: `AscentRateCalculator.calculateProfileRates` derives
`List<AscentRatePoint>` purely from profile depth/time samples, so it is populated for
every dive including UDDF imports (the warning markers the reporter sees are generated
from the same data). The fix is entirely in the presentation layer.

## Goals

1. Make the existing "Ascent Rate" toggle actually visualize ascent rate on the plot.
2. Add a precise, readable ascent-rate magnitude line as a distinct, optional overlay.
3. No data-layer, import, persistence, or sync changes.

Non-goals: changing how ascent rate is calculated; touching the multi-computer depth
rendering; adding a new persisted user setting (the new line toggle is session-only).

## Design

Two independent, user-toggleable visualizations, both fed by the already-computed
`analysis.ascentRates` (already passed to `DiveProfileChart.ascentRates`).

### Part 1 — Depth-line band coloring (full velocity coloring)

Reuses the existing toggle `showAscentRateColors` (already defaults **on** via
`settings.showAscentRateColors`).

- When the toggle is on (single-computer path only), the depth line is split into
  consecutive runs by `AscentRatePoint.category` and each run is coloured via the
  existing `_getAscentRateColor`:
  - `safe` (≤9 m/min) → green
  - `warning` (9–12 m/min) → orange
  - `danger` (>12 m/min) → red
- `AscentRatePoint.category` is magnitude-based (`categorize()` uses `.abs()`), so fast
  descents colour too — this is full "velocity coloring", matching dive-computer
  convention.
- Adjacent runs share their boundary sample so the line stays continuous (no gaps).
- Each segment keeps a subtle gradient fill in its own category colour (low alpha),
  Subsurface-style.
- When the toggle is **off**, render today's single solid `AppColors.chartDepth` segment
  with fill (unchanged behaviour).
- Multi-computer mode (`computerProfiles.length >= 2`) is untouched — it keeps
  per-computer colours.

New private builder `_buildVelocityColoredDepthLines(colorScheme, units)` replaces the
single-segment branch inside `_buildGasColoredDepthLines`. The existing
`_buildSingleDepthSegment(color, units, start, end, showFill)` is reused per run.

### Part 2 — Separate ascent-rate line + right-axis metric

New session-only toggle `showAscentRateLine` (default off; no persisted setting, mirroring
`showMod`). Gated on the same data availability as Part 1 (`config.hasAscentRates`).

- New private builder `_buildAscentRateLine(chartMaxDepth)`: a lime, dashed
  `LineChartBarData` plotting **signed** rate (m/min) via
  `_mapValueToDepth(signedRate, chartMaxDepth, min, max)` so descents dip below and
  ascents rise above the vertical mid-plot. No fill.
- New right-axis metric `ProfileRightAxisMetric.ascentRate` so the user can select it for a
  labelled m/min scale (consistent with SAC / Heart Rate). It is **not** added to
  `fallbackPriority`, so it never auto-claims the axis.

#### Axis range alignment (correctness-critical)

The line and the right-axis tick labels must use the **same** range or the labels lie.
Introduce a single helper:

```
({double min, double max})? _ascentRateAxisRange()
  // null when ascentRates is null/empty
  // maxAbs = max(|rateMetersPerMin|) over points
  // span   = max(maxAbs, criticalThreshold * 1.25)   // floor ≈ 15 m/min so the scale is meaningful
  // return (min: -span, max: span)                    // symmetric about 0
```

Used by both `_getMetricRange(ascentRate)` and the `build()`-time min/max passed to
`_buildAscentRateLine`. Values are stored in m/min (metres); unit conversion happens at
display time.

#### Enum + four switch arms (all in `dive_profile_chart.dart`)

`ProfileRightAxisMetric.ascentRate(displayName: 'Ascent Rate', shortName: 'Rate',
color: lime, unitSuffix: null, category: primary)`.

- `_hasDataForMetric` → `widget.ascentRates != null && widget.ascentRates!.isNotEmpty`
- `_getMetricRange` → `_ascentRateAxisRange()`
- `_formatRightAxisValue` → `units.convertDepth(value).toStringAsFixed(0)` (m/min → ft/min)
- `_rightAxisLabel` → explicit case `'$name (${units.depthSymbol}/min)'` (don't rely on the
  static `unitSuffix` default, which can't honour units)

The generic `_mapDepthToMetricValue` already handles a symmetric linear range for tick
positioning — no change.

### Tooltip

The existing "Rate" tooltip row is gated on `_showAscentRateColors`. Change the gate to
`_showAscentRateColors || _showAscentRateLine` in **both** tooltip paths (external
`_emitExternalTooltip` and the built-in `LineTouchTooltipData` builder).

### State / provider (`profile_legend_provider.dart`)

Add `showAscentRateLine` to `ProfileLegendState`: field, constructor default `false`,
`copyWith`, `==`, `hashCode`, and `activeSecondaryCount`. Add `toggleAscentRateLine()` to
the `ProfileLegend` notifier. Not initialised from settings (default false).

### Legend (`dive_profile_legend.dart`)

In the "Overlays" section, add a new toggle item below the existing "Ascent Rate" item:
- label `context.l10n.diveLog_legend_label_ascentRateLine`
- color `Colors.lime`
- `isEnabled: legendState.showAscentRateLine`, `onTap: legendNotifier.toggleAscentRateLine`

Update `_MoreOptionsButton._activeSecondaryCount` to count it when
`config.hasAscentRates && legendState.showAscentRateLine`.

The existing "Ascent Rate" item (label `diveLog_legend_label_ascentRate`) is unchanged and
now drives the band coloring.

### Chart wiring (`dive_profile_chart.dart` `lineBarsData`)

Add after the existing overlay lines:
```
if (_showAscentRateLine && widget.ascentRates != null)
  _buildAscentRateLine(totalMaxDepth),
```
Sync `_showAscentRateLine = legendState.showAscentRateLine;` alongside the other
`legendState` syncs in `build()`.

### Localization

New key `diveLog_legend_label_ascentRateLine` = "Ascent Rate Line" added to all 11
`lib/l10n/arb/app_*.arb` files (en + ar, de, es, fr, he, hu, it, nl, pt, zh — translated,
not English fallbacks), then `flutter gen-l10n` (via build_runner) regenerated. The
existing `diveLog_legend_label_ascentRate` ("Ascent Rate") is reused for the coloring
toggle. No new metric display-name key is required — `ProfileRightAxisMetric.displayName`
is a hard-coded enum string like the other metrics.

## Behaviour change

Because `showAscentRateColors` already defaults on, once Part 1 lands every dive with a
fast ascent shows green/orange/red velocity coloring by default. This is the feature
finally working as labelled; no migration needed.

## Testing (TDD — failing tests first)

Follow existing chart test patterns (pump `DiveProfileChart`, read `LineChart`
`LineChartData`). Mark new pure helpers `@visibleForTesting` where unit testing is cleaner
than widget extraction.

1. **Band coloring**: a profile spanning safe/warning/danger yields multiple depth
   segments whose colours map to category; a uniform profile yields a single segment;
   toggle off → single solid `AppColors.chartDepth` segment.
2. **Rate line**: present in `lineBarsData` when `showAscentRateLine` on, absent when off;
   lime + dashed; signed mapping (a descent sample maps below mid-plot, an ascent above).
3. **Axis range helper**: `_ascentRateAxisRange` symmetric, honours the floor, null when
   no data.
4. **Metric switch arms**: `_hasDataForMetric`, `_getMetricRange`, `_formatRightAxisValue`
   (m→ft conversion), `_rightAxisLabel` for `ascentRate`.
5. **Provider**: `toggleAscentRateLine` flips state; `activeSecondaryCount` reflects it.
6. **Tooltip**: "Rate" row shown when either toggle on, hidden when both off.
7. **Regression**: existing dive_profile_chart tests still pass (update any that assert a
   single depth segment when coloring is on).

## Files touched

- `lib/core/constants/profile_metrics.dart` — add `ascentRate` enum value.
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` — velocity
  coloring builder, rate-line builder, range helper, 4 switch arms, `lineBarsData` +
  `build()` sync, tooltip gate.
- `lib/features/dive_log/presentation/providers/profile_legend_provider.dart` — new
  toggle state + method.
- `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` — new legend item
  + active count.
- `lib/l10n/arb/app_*.arb` (11) + regenerated `app_localizations*.dart`.
- Tests under `test/features/dive_log/...` (new + updates).
