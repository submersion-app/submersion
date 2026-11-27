# Dive profile: time-only zoom, ascent-rate axis, restoring the right axis

Source: discussion #4764 ("A few suggestions to improve the display of dive
profiles"). Release v1.8.7.

## Intent

A diver reading the full-screen profile wants to look closely at one part of
the dive (a stop, an ascent, a gas switch) without losing the depth scale, and
wants the right-hand axis to label what the chart is actually showing. The
discussion asked for four things:

1. Zoom each axis independently, so you can zoom into part of the dive while
   keeping the vertical (depth) scale.
2. Offer ascent rate as a right-axis scale, since its bars can already be shown.
3. Move the right axis off temperature when the temperature line is hidden.
4. A way to bring the right axis back after hiding it (today only a restart
   does).

Request 3 already shipped in #5016 (in the v1.8.6 build). This design covers 1,
2 and 4. When the PR lands, reply on the discussion pointing at #5016 for 3.

## Goals

- A diver can zoom the time axis alone, on every input (mouse wheel, trackpad
  pinch and scroll, touch pinch, the +/- buttons, double-tap), with depth always
  shown surface to maximum depth.
- The existing "Keep overlays in view" behaviour and the new time-only zoom are
  one decision, presented as one control with no combination that does nothing.
- Ascent rate can drive the right axis, with labels that read true against the
  ascent-rate bars.
- After choosing "None" for the right axis, the diver can pick a metric again
  without leaving the chart.

## Non-goals

- Depth-only zoom. Nobody asked for it, and it would need per-axis gestures
  (rejected below).
- Changing any default. Every diver keeps today's zoom behaviour and right-axis
  metric until they change them.
- Changing the Insights trend chart, which shares `ChartViewport`. It must
  behave exactly as today. (The Connections canvas has its own
  `GraphViewport` and is untouched.)

## Anti-goals

- A drawn plot and gesture math that disagree about the visible window (the
  zoom bugs in #2350 and the MetalSDF work came from that class of drift).
- Rewriting anyone's stored setting. No migration converts
  `profileMetricsFollowViewport`.
- An ascent-rate axis whose labels don't line up with the bars.

## Approaches considered

For splitting the zoom (the one real how-choice):

1. **Separate depth zoom on the shared `ChartViewport` (chosen).** `zoom` stays
   the time zoom; a new `zoomY` drives `visibleHeight` and the vertical offset
   clamp. Zoom operations take which axes to scale. Other callers keep both
   factors equal, so they see no change. One type, one set of anchor math.
2. **Keep one zoom and ignore the vertical window in time-only mode.** Smaller
   diff, but about six read sites (metric band, visible depth range, pan clamp,
   focal math, touch pinch, playback recentring) would each have to remember the
   mode. A missed one makes drawing and touch disagree. Rejected.
3. **A profile-only viewport type wrapping `ChartViewport`.** Duplicates the
   anchor math for no gain over 1. Rejected.

For the zoom control's interaction, also considered and rejected: per-axis
gestures (Shift/Alt modifiers, horizontal vs vertical pinch). They are invisible
without a hint, and classifying pinch direction misfires on phones.

For restoring the right axis, also considered and rejected: a small button left
at the chart's right edge. It sits on the plot and competes with the readout
card and markers at phone width. "None" is rare, so the smallest fix that reuses
the existing menu won.

## Design

### 1. Zoom choice

One control named **Zoom** with three values:

| Value | Time axis | Depth axis | Metric overlays (NDL, ppO2, temperature...) |
| --- | --- | --- | --- |
| Both axes, magnify overlays (default) | zooms | zooms | stretched over the whole dive's depth, so they magnify |
| Both axes, keep overlays in view | zooms | zooms | re-fitted to the visible depth slice (`MetricBand` from the viewport) |
| Time only | zooms | always surface to max depth | full height (the band is the full band) |

Where it appears:

- **Chart options, Display section**: replaces the "Keep overlays in view"
  behaviour row. Applies to this chart session only, seeded from the saved
  default, as `metricsFollowViewport` is today.
- **Settings, Appearance, Dive Profile**: replaces the "Keep overlays in view
  when zooming" switch. Sets the saved default.

Both are a three-way pick (a dropdown or segmented choice matching the
surrounding rows' style; builder's call which widget fits each place).

Behaviour in Time only:

- Every zoom input changes the time window only, anchored at the cursor, pinch
  focal point or centre as today. Depth stays 0 to max.
- Vertical panning does nothing (there is nowhere to pan). Horizontal panning
  works as today, including one-finger drag when zoomed.
- Double-tap zooms time about the tap; double-tap when zoomed resets as today.
- Playback recentring (`centredOn`) keeps working; with `zoomY == 1` the
  vertical offset clamps to 0 by itself.

Switching values while zoomed:

- To Time only: keep the time window, snap depth to full (`zoomY = 1`,
  `offsetY = 0`).
- From Time only back to a both-axes value: keep the time window, depth stays
  full until the next zoom gesture, after which both factors scale together
  from where they are.

### 2. Viewport model

`ChartViewport` (`lib/core/ui/chart_viewport.dart`) gains `zoomY`:

- `zoom` remains the time (x) zoom; `visibleWidth = 1 / zoom`.
- `zoomY` defaults to `zoom` when not given, so every existing constructor call
  and every non-profile caller keeps equal zoom.
- `visibleHeight = 1 / zoomY`; `offsetY` clamps to `[0, 1 - 1 / zoomY]`.
- `isZoomed` is true when either factor is above 1.
- `sameWindowAs` compares `zoomY` too.
- `zoomedAt(focalX, focalY, factor)` gains a way to scale x only (an `axes`
  parameter or a separate method; builder's call). Both-axes scaling multiplies
  each factor by `factor` and clamps each to `[minZoom, zoomLimit]`
  independently, so after a switch from Time only the two can differ and keep
  their ratio until one hits a limit.
- `forWindow`, `withZoomLimit`, `lerp`, `pannedBy`, `centredOn` carry `zoomY`
  through; `lerp` interpolates the vertical window edges the same way it does
  the horizontal ones.

The profile chart's gesture paths pass the mode when zooming: wheel
(`onPointerSignal`), trackpad (`TrackpadZoomGestureRecognizer` handler), touch
pinch (cumulative against `_gestureStartViewport`), buttons (`_zoomIn`,
`_zoomOut`), double-tap. The touch pinch path also pans, so in Time only its
vertical pan component is dropped.

Most places that use the depth window read `visibleHeight` / `offsetY` (metric
band, visible depth range, bar cache signatures) and need no mode check; the bar
cache's band key already covers vertical changes (`MetricBand.cacheKey`). Three
places divide or scale depth by the time zoom `zoom` and must switch to `zoomY`:

- `ProfilePlotFrame.withViewport` (`profile_plot_frame.dart`) sizes the depth
  span by `viewport.zoom` and `other.zoom`; its `==` and `hashCode` must include
  `zoomY`. The pinned profile copy (`_copyMappingAt`) relies on it.
- The mouse-drag pan in `dive_profile_chart.dart` (`pannedBy(-d.dx / plotW /
  zoom, -d.dy / plotH / zoom)`): the vertical term divides by `zoomY`.
- The touch-pinch pan (`vp.pannedBy(... / vp.zoom, ... / vp.zoom)`): same.

Zoom controls when the factors differ: in the profile chart `zoomY <= zoom`
always holds. Both-axes zooming multiplies both factors (so a ratio below 1
stays below 1 and both clamp at the same limits), and Time only snaps
`zoomY` to 1. So the controls keep reading the time zoom, as today
(`_zoomNotifier.value = value.zoom`): the readout shows it, `-` and reset
show while it is above 1, and `+` is disabled at the time limit. In the one
case where time sits at the limit with depth below it (just after leaving
Time only), the wheel, pinch and trackpad can still zoom depth; only the `+`
button stops, which is acceptable.

Scope: Time only applies to every chart that reads `profileLegendProvider`
(the dive detail card, full screen, the pinned copy, the planner's logged-dive
chart, Dive Lab, the profile panel), exactly as "Keep overlays in view" does
today.

### 3. Storage

- New diver setting `profileZoomTimeOnly`, a bool, stored in `diver_settings`
  next to `profileMetricsFollowViewport` with the same shape, because the two
  make up one control and must persist alike: a nullable column (null means
  never set, read as false), listed in the sync serializer's
  `_nullMeansUnsetKeys`, a device-local SharedPreferences key used while no
  diver exists, and the same adoption path into the diver's row
  (`adoptDeviceLocalValues` in `settings_providers.dart`, adopting only a
  non-default value with the conditional IS NULL write). A plain non-null
  column would lose a Time only pick made before a diver exists while keeping
  the other two values.
- Needs a schema rung (current schema 386); table in
  `lib/core/database/tables/`, rung in `lib/core/database/migrations/`, never
  in `database.dart`. The rung only adds the column. No rung writes existing
  data.
- `AppSettings` gains the field and a setter; the conflict catalogue
  (`diver_settings_fields.dart`) and sync serializer gain the column like any
  diver setting.
- The three-way value is derived from the pair:
  Time only when `profileZoomTimeOnly`; else Keep overlays in view when
  `profileMetricsFollowViewport`; else Magnify. Choosing Time only sets only
  `profileZoomTimeOnly = true` and leaves `profileMetricsFollowViewport`
  alone, so going back restores the diver's previous both-axes choice.
  Choosing a both-axes value sets `profileZoomTimeOnly = false` and
  `profileMetricsFollowViewport` accordingly.
- `ProfileLegendState` gets the session copy (`zoomTimeOnly`) seeded from
  settings, alongside `metricsFollowViewport`. A presentation-layer enum (for
  example `ProfileZoomMode`) can wrap the pair for the two controls.

### 4. Ascent rate on the right axis

- The axis menu stops filtering out `ProfileRightAxisMetric.ascentRate`. It
  appears in its category when the dive has rate data.
- Picking it turns the ascent-rate bars on (`_withLineOn` already sets
  `showAscentRateLine`).
- The axis scale matches the bars exactly: 0 at the vertical middle of the plot
  rect, ascents above (+), descents below (-), the top and bottom edges at
  `DiveProfileChart.ascentRateAxisRange(...).max`, shown in the diver's depth
  unit per minute. It is fixed to the plot rect, like the bars: it does not
  change with depth zoom or the Zoom choice.
  This means a second way to label the right axis: ticks placed by plot
  fraction, not by unmapping a `MetricBand`. Today the resolver can already
  return `ascentRate` (as the preferred metric or the Settings default), but
  its labels come from `MetricBand.unmap` and do not match the bars; this fixes
  that.
- Hovering the bars switches the axis to ascent rate for the hover, as hovering
  a tagged line does. "None" still wins over hover, as today.
- `resolveRightAxisMetric` stops excluding ascent rate: it is a fallback after
  every other metric (last in the fallback order), counted as drawn when the
  bars are on and the dive has rate data.
- The Settings default-axis dropdown already lists Ascent Rate; no change there
  beyond it now rendering correctly.

### 5. Right axis row in chart options

- The Display section gains a **Right axis** row, under Zoom. It shows what
  the axis shows on the chart right now (the metric the resolver picked, the
  same one the axis menu checks), not the diver's stored preference. It reads
  "None" whenever there is no right axis, whether the diver chose "None" or no
  line besides depth is drawn. It opens the same metric menu as tapping the
  axis (the "None" entry included).
- Picking a metric clears "None" and turns its line on
  (`setRightAxisMetric`). Picking "None" hides it (`hideRightAxis`).
- Present wherever chart options are, which is every `DiveProfileChart` that
  shows its legend: the dive detail page, full screen, the planner's
  logged-dive chart, Dive Lab and the profile panel. In depth-and-pressure-only
  mode the legend is hidden, so the row needs no hiding of its own.
- Plumbing: the axis menu and the resolved axis metric live in the chart's
  state today (`_showRightAxisMetricSelector`, built from which metrics have
  data). The options dialog sees only `ProfileLegendConfig` and the legend
  state, so the chart hands it what it needs (the available metrics and the
  axis currently shown), and the menu-building moves out of the chart state
  into a shared builder both entry points call.

## Constraints

- Units: rate labels and the depth axis respect the active diver's units.
- l10n: every new string goes through the ARB files (the three Zoom values,
  "Zoom", "Right axis", any subtitle).
- Range of divers: check the Zoom choice and the ascent-rate axis on a 6 m reef
  dive with few samples and a deep trimix dive with long stops, at phone and
  desktop width, light and dark.
- Gestures: keep widget shape stable across mode flips above the gesture
  recognizers (#2350); test continuous trackpad zoom with several
  `panZoomUpdate`s and a `pump()` between each, on a chart without `exportKey`.
- Tests that override settings use `settingsProvider`; add the new setter to
  every concrete `SettingsNotifier` fake.

## Left to the builder

- The exact widget for the three-way Zoom control in each place.
- Whether `zoomedAt` takes an axes parameter or a sibling method.
- Tick count and formatting for the ascent-rate axis (match the other axes'
  density; show the sign).
- The right-axis menu's position when opened from the chart options row.
