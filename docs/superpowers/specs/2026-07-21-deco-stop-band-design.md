# Deco Stop Band on the Dive Profile

**Date:** 2026-07-21
**Status:** Approved design, ready for planning

## Goal

Render decompression stops on the dive profile chart as a stepped, shaded
region spanning from the stop depth up to the surface, instead of only the
smooth ceiling curve the app draws today. The band is switchable
between app-calculated values and dive-computer-reported values through a new
settings toggle, mirroring the existing ceiling toggle.

## Background: what already exists

The switchability infrastructure is largely built:

- [dive_profile_chart.dart](../../../lib/features/dive_log/presentation/widgets/dive_profile_chart.dart)
  `_buildCeilingLine` draws a smooth, red dashed ceiling curve with a light fill
  to the surface.
- `MetricDataSource` (`computer` / `calculated`) in
  [profile_metrics.dart](../../../lib/core/constants/profile_metrics.dart),
  with `ceilingSource` in the legend provider and a `default_ceiling_source`
  column in `diver_settings`.
- Dive-computer stop depth is persisted in `dive_profiles.ceiling`, written from
  the parser's `decoDepth` whenever `decoType != 0`. It is already the
  computer's own stop depth, quantized by the computer.
- `decoStopIncrement` (default 3.0 m) already exists in diver settings.

The gap is the *shape*: stops belong on stop-increment boundaries and should be
drawn as steps; this app draws a smooth curve.

## Design

### 1. Data pipeline

A new `decoStopCurve` is computed in the profile analysis provider and passed to
the chart as a new parameter, keeping the chart a dumb renderer.

**Calculated source:** quantize the pre-overlay `analysis.ceilingCurve` by
rounding each value up to the next multiple of the diver's `decoStopIncrement`.
A value of zero stays zero, meaning no obligation.

**Computer source:** read `profile[i].ceiling` raw, with no rounding. Some
computers use non-3 m stop spacing, and re-rounding would misrepresent what the
computer actually displayed. Nulls become 0.

The pre-overlay detail is load-bearing. `overlayComputerDecoData` in
[profile_analysis_provider.dart](../../../lib/features/dive_log/presentation/providers/profile_analysis_provider.dart)
already rewrites `analysis.ceilingCurve` with computer data when
`ceilingSource == computer`. The band must resolve its own source independently
against the original calculated curve, otherwise selecting "computer" for the
ceiling line would silently drag the band along with it.

**Fallback:** if the computer source is selected but no point in the profile has
a DC ceiling, fall back to calculated and report the resolved source through a
new `decoStopActual` field on `MetricSourceInfo`, so the legend can show which
source is genuinely in use. This matches the existing NDL/ceiling/TTS/CNS
fallback behavior.

Quantization lives in a pure function in
`lib/features/dive_log/domain/services/deco_stop_curve.dart` — no widget
dependency, directly unit-testable.

### 2. Rendering

A new file
`lib/features/dive_log/presentation/widgets/deco_stop_band.dart` holds a
top-level builder returning a `LineChartBarData`. It deliberately does not go
into `dive_profile_chart.dart`, which is already 4953 lines against the 800-line
maximum in CLAUDE.md. The chart calls the builder next to `_buildCeilingLine`.

- **Step shape:** fl_chart (^1.1.1) supports this natively via
  `isStepLineChart: true` plus `lineChartStepData`, so no custom painter is
  needed. The step direction holds each stop value forward from its sample
  until the next transition, so the vertical edge lands at the moment the stop
  level changes.
- **Fill:** `belowBarData` with `cutOffY: 0` and `applyCutOffY: true`, so the
  band spans from the stop depth up to the surface.
- **Gaps:** where the curve is 0 there is no obligation and the band collapses
  to zero height on its own. No special-case gap handling.
- **Decimation:** the existing `_decimatedCurveIndices` is unsuitable for a step
  curve, because it can drop the exact samples where a transition occurs.
  Instead, run-length encode: keep only indices where the quantized value
  changes. This is lossless for a piecewise-constant curve and produces far
  fewer points than the raw profile.
- **Color:** the ceiling's red family — a translucent fill at roughly 0.18 alpha
  and no stroke at all. The band is a background zone, not a second curve, so
  drawing an outline along its upper edge would compete with the ceiling line
  drawn over it. The existing smooth dashed red ceiling line stays and is drawn
  on top. Green was rejected because it already belongs to NDL in this app's
  palette.
- **Layering:** band first, smooth ceiling line second, so the dashed curve
  stays legible against the fill.
- **Tooltip:** a "Deco stop" row alongside the existing Ceiling row, showing the
  current stop depth, or an em-dash when there is no obligation.

All three chart consumers (`dive_detail_page`, `fullscreen_profile_page`,
`dive_profile_panel`) share the single `DiveProfileChart` widget, so they pick
this up without individual changes.

### 3. Settings and persistence

Two new `diver_settings` columns, schema version **129 to 130**:

| Column | Type | Default | Mirrors |
| ------ | ---- | ------- | ------- |
| `show_deco_stops_on_profile` | BOOL NOT NULL | true | `show_ceiling_on_profile` |
| `default_deco_stop_source` | INTEGER NOT NULL | 1 (calculated) | `default_ceiling_source` |

Defaulting visibility to on means existing users see the band immediately, but
it only appears on dives that actually incurred an obligation.

The migration must satisfy all four steps this repo requires for a non-nullable
column addition:

1. PRAGMA-guarded idempotent `_assert…Column` helpers, never bare
   `m.addColumn` — partial-schema migration tests instantiate old databases
   without unrelated tables and crash on unguarded DDL.
2. Helpers called from **both** the `if (from < 130)` `onUpgrade` block **and**
   the `beforeOpen` backstop section.
3. The exact-latest schema tripwire test updated to 130. It may be skipped on
   Windows full runs, so forgetting it fails only on CI.
4. Both keys seeded in `_applyDiverSettingDefaults` in
   [sync_data_serializer.dart](../../../lib/core/services/sync/sync_data_serializer.dart),
   or sync import of pre-column payloads throws in `DiverSetting.fromJson`.

### 4. UI surfaces

Each mirrors its ceiling counterpart:

- Visibility default in `default_visible_metrics_page.dart`.
- Source picker in `settings_page.dart`, next to the ceiling source picker.
- Per-dive legend entry with a source selector in `dive_profile_legend.dart`.
- Legend state gains `showDecoStops` and `decoStopSource` fields, threaded
  through `copyWith`, equality, and `hashCode` like the existing fields.

## Testing

Tests are written before implementation, per the project's TDD rule.

**Quantization unit tests**

- Rounds up to the next increment (4.2 m to 6 m at a 3 m increment).
- Exact multiples are unchanged (6.0 m stays 6.0 m).
- Zero stays zero.
- Non-3 m increments are honored.
- Computer values pass through untouched, including non-3 m values such as
  4.5 m.

**Source-resolution tests**

- Calculated reads the pre-overlay curve even when `ceilingSource == computer`.
- Computer with no DC data anywhere falls back to calculated and reports
  `decoStopActual == calculated`.
- Computer with partial DC data uses DC values where present.

**Rendering tests**

- Run-length decimation preserves every step transition.
- A curve that is entirely zero produces no visible band.

**Persistence tests**

- Migration from 129 to 130 adds both columns and is idempotent when run twice.
- Legacy sync payload lacking both keys imports without throwing.

`flutter test | tail` masks the exit code in this repo, so the suite must be run
with the exit status captured explicitly.

## Out of scope

- Stop duration labels on the band. The design keeps depth-only rendering;
  labels can follow if the band proves useful.
- Showing calculated and computer bands simultaneously for comparison. The
  chosen model is one band at a time, selected by source.
- Any change to the deco algorithm itself. This is a rendering and plumbing
  feature over existing curves.
