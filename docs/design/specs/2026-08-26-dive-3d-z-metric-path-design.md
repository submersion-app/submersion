# Dive 3D View: Z-Metric Path - Design

Date: 2026-08-26
Status: approved in brainstorming, awaiting spec review
Supersedes the single-dive scene described in
`2026-07-11-dive-3d-view-design.md` (sections 3 and 4). The tissue,
comparison, career, and seascape scenes are unaffected except where noted.

## Problem

The single-dive 3D scene draws a depth-time ribbon extruded 0.09 units into
Z. Z carries no data, so orbiting reveals nothing the 2D chart does not show,
and the scene has no axes, ticks, labels, or hover. Temperature strata wash
over the ceiling and curtain. The original spec's "axes and grid" item was
deferred ("plan deviation 5" in `grid_builder.dart`) and only ever built for
the tissue and seascape scenes.

## Decision

Replace the slab with a **3D path**: X = run time, Y = depth, Z = a metric
the diver picks from a list (or None). The path is a tube colored by a
separately chosen metric. Its shadows on the three walls of the scene box
are three 2D charts at once: depth vs time on the back wall, metric vs time
on the floor, depth vs metric on the left wall. Full axis chrome, hover
tooltips, labeled markers, and camera presets make each of those readable.

Decisions taken during brainstorming:

- Replace the existing scene; the Z picker includes **None**, which is also
  the automatic fallback when the chosen metric has no data.
- Color stays an **independent** metric (today's chips). Default color = the
  Z metric; picking a color chip decouples them.
- Overlays that survive: deco ceiling as a **margin sheet** (default on),
  labeled **markers** (default on), depth **curtain** (default off),
  temperature **strata** (default off). New: **wall shadows** (default on).
- The path is a tube, not a surface; drop lines and shadows carry the
  height cue that a curtain would otherwise give.

## Section 1: Scene geometry

### Inputs

`SceneGeometryService.build(data, colorMetric, zMetric, zAxis)`:

- `colorMetric: SceneMetric` as today.
- `zMetric: SceneMetric?`; null means None.
- `zAxis: ZAxisSpec?` = `{lo, hi, step, symbol}` in the diver's display
  unit, computed by the provider (Section 2). Null whenever `zMetric` is
  null.

`SceneMetric` gains `tts`; `Dive3dSceneData.ttss` already carries the
values. `MetricPalette` gains a TTS ramp (neutral to amber).

### Z series

The Z metric series is resampled onto the decimated timestamps the same way
tank pressure is today (`_resampledPressure`). Interior nulls are linearly
interpolated between their non-null neighbors; leading and trailing nulls
take the nearest non-null value, so the path never breaks. A series with
fewer than two non-null samples is treated as None (the provider makes this
decision so the UI can disable the chip; the builder asserts it).

### Scene box

- X = 0..`xSpan` (10), time via `bounds.xOf`.
- Y = 0..-`ySpan` (6), depth via `bounds.yOf`; the floor is the max-depth
  plane as today.
- Z = -2.5..+2.5 (`SceneBounds.zPathHalfSpan`, new constant). `zOf(v)` maps
  `lo..hi` onto that range with larger values toward the viewer (+Z). None
  mode places every sample at Z = 0 **but keeps the same box**, so chrome and
  camera do not jump when the diver switches metrics.
- `SceneBounds` is constructed with `sceneMinZ/maxZ` set to the path span,
  the way the tissue builder widens its box, so the projector fits it. The
  shared `zSlabHalfWidth` used by the compare scene is not changed.

### Builders

- `PathBuilder.build(times, depths, zs, sampleColors, bounds)`: a tube made
  of two crossed triangle strips along `(xOf(t), yOf(d), z)`: one strip with
  half-width `zHalfWidth` (0.09) in Z, one with the same half-width in Y.
  Per-vertex colors from `MetricPalette.colorsFor(colorMetric, ...)`.
  Replaces `RibbonBuilder.build` for this scene; `RibbonBuilder` itself
  stays for the compare and career scenes.
- `CeilingBuilder.build(times, depths, zs, ceilings, bounds)`: becomes the
  margin sheet, a vertical quad strip between `yOf(depth)` and
  `yOf(ceiling)` at the sample's Z for every sample with a non-null,
  non-zero ceiling. Amber at 0.35; a segment is red where depth is
  shallower than the ceiling (the existing violation test).
- `RibbonBuilder.curtain(times, depths, zs, bounds)`: the translucent sheet
  from the path to the floor, following Z. Overlay `curtain`, default off.
- `StrataBuilder`: unchanged planes, spanning the full Z box. Overlay
  `strata`, default off.
- `MarkerLayout.layout(data, bounds, zs)`: markers anchor at the sample's
  `(x, y, z)`.
- `ShadowBuilder.build(times, depths, zs, bounds)` (new): thin quads
  (`GridBuilder`'s trick, half-thickness 0.015, lifted 0.02 off the wall
  toward the box interior) for three shadows and the drop lines:
  - back wall (Z = `sceneMinZ`): depth vs time,
  - floor (Y = `sceneMinY`): Z metric vs time,
  - left wall (X = 0): depth vs Z metric,
  - drop lines from the path to the floor at about 24 evenly spaced
    samples.
  Neutral gray at 0.45 (drop lines 0.3). Overlay `shadows` (new
  `SceneOverlay.shadows`), default on. Not emitted in None mode, where the
  shadows would duplicate the path.
- `GridBuilder` is deleted; its depth lines become part of the axis frame.
- `ScrubPath.zs` is populated so the scrub cursor rides the 3D path.

Layer order stays back to front: strata, shadows, curtain, ceiling sheet,
path. Decimation (`targetPoints` 2000) and the `compute()` threshold are
unchanged.

## Section 2: Chrome and units

### Axis frame and labels

`buildDiveAxes({bounds, depthTicks, timeTicks, zAxis, depthTitle, timeTitle,
zTitle})` in `domain/geometry/dive_axes.dart` returns `(AxisFrame,
AxisLabelSet)`, the pair the seascape already builds. Pure geometry and
plain strings; no Canvas, no l10n.

- Axes on the visible edges: depth up the front-left edge (X = 0,
  Z = `sceneMaxZ`); time along the front floor edge (Y = `sceneMinY`,
  Z = `sceneMaxZ`); Z metric along the right floor edge (X = `xSpan`).
- Ticks tagged `tickX`/`tickY`/`tickZ`; titles and tick values as
  `AxisLabel`s anchored in world coordinates so they track the camera.
- Wall grids (`frameGrid`) at every tick: back wall (depth lines, time
  verticals), floor (time lines, Z lines), left wall (depth lines, Z
  verticals).
- Depth ticks: every 10 m or 25 ft (7.62 m) from 0 to max depth, labeled
  with the number only; the unit lives in the title ("Depth (ft)").
- Time ticks: a nice step (1, 2, 5, 10, 15, 30, 60 min) giving 4-6 ticks
  across the runtime.
- Z ticks: every `zAxis.step` from `lo` to `hi`.
- In None mode the Z axis, its ticks, and the floor/left-wall Z grid lines
  are omitted; the box outline remains.

### Units

`dive3dGeometryProvider` already watches `settingsProvider` for the grid
step. It now also builds `ZAxisSpec`:

- Convert the Z series to display units through `UnitFormatter`:
  temperature (C/F), tank pressure (bar/psi), ascent rate (m/min or ft/min).
  ppO2, CNS %, heart rate, and TTS minutes are unit-free.
- `lo`/`hi` snap outward from the data min/max to a nice step that yields
  4-6 ticks. The seascape's private nice-step routine in
  `domain/spatial/seascape_axes.dart` moves to
  `lib/features/dive_3d/domain/geometry/nice_step.dart` and both callers
  use it.
- Scene Z values are therefore display-unit numbers, and tick labels are
  plain numbers with the symbol in the axis title.

Because the provider watches settings, a unit change rebuilds the scene;
the family key is `(diveId, colorMetric, zMetric)`.

### Painting

The wall grid must sit behind the path; axes, ticks, labels, and the hover
ring in front. Today `axisChromeOnly` paints all chrome in front (correct
over terrain, wrong across a tube). The viewport's `axisChromeOnly` boolean
becomes `chromeMode`:

- `none`: dive scene until now; no chrome (kept for the compare scene).
- `tissue`: frame behind, wireframe/overlay/chrome painters as today.
- `axesOnly`: seascape; everything in front, as today.
- `framed`: **dive path**; `TissueFramePainter` restricted to `frameGrid`
  segments behind the scene, `AxisChromePainter` (axes, ticks, labels, hover
  ring, guides) in front.

`diveChromeStyle(context)` beside `seascapeChromeStyle`: neutral axis color
for all three axes, faint grid, theme label color. Red is reserved for the
ceiling violation.

## Section 3: Hover, readout, and markers

### Picking

A `HoverPicker` interface replaces the tissue-typed hover plumbing in
`Dive3dInteractiveViewport`:

```dart
abstract interface class HoverPicker {
  ScenePick? pick(SceneProjector projector, Offset cursor);
}

class ScenePick {
  final double x, y, z;   // world anchor for the ring and guides
  final Object payload;   // TissuePick or PathPick
}
```

- `TissueHoverPicker(grid)` wraps `pickNearestTissueVertex`; its payload is
  the unchanged `TissuePick`, so `TissueHoverTooltip`, the tissue overlay
  painter, and their tests keep working.
- `PathHoverPicker(scrubPath)` returns the nearest projected path sample
  within 12 px; payload `PathPick(index)` (decimated index).
- Viewport parameters `surfaceGrid` + `hoverPick: ValueNotifier<TissuePick?>`
  become `picker: HoverPicker?` + `hoverPick: ValueNotifier<ScenePick?>?`.
  `surfaceGrid` stays as a tissue-only input, consumed by
  `TissueChromePainter` and `TissueOverlayPainter` for the wireframe and
  overlay; only hover picking moves behind the interface. Projection
  caching and the pan un-translation rules are unchanged.
- Touch devices pick on tap (a tap that hits no marker), as the tissue
  scene does.

`AxisChromePainter` draws the pick ring at `ScenePick.x/y/z`. In `framed`
mode it also draws three dashed guide lines from the anchor to the back
wall, the floor, and the left wall, which is what ties the path to its
shadows.

### Tooltip and readout

- `DiveHoverTooltip`: a `Positioned` overlay under `IgnorePointer` (the
  tissue pattern) showing run time (m:ss), depth, temperature, ascent rate,
  ppO2, CNS, ceiling and TTS when present, and one line per tank pressure.
  The Z metric's row is emphasized. Values come from full-resolution
  `Dive3dSceneData` by mapping the decimated index to its timestamp and
  looking up the nearest full-resolution sample; every number passes
  through `UnitFormatter`.
- `diveReadoutRows(data, timestamp, units, l10n)` is the single row builder
  shared by the tooltip, the rebuilt `SceneReadoutPanel` (scrub-driven,
  compact two-column grid replacing today's one-line string), and the
  marker sheet.

### Markers

- Gas-switch billboards show the mix name (from `GasSwitchWithTank`),
  bookmarks show their event text, photos keep the thumbnail. Labels are
  drawn by the chrome painter with `TextPainter` (the tissue axis labels set
  the precedent).
- The marker tap sheet shows the readout rows at the marker's time instead
  of "N min"; photos still open the existing viewer.

## Section 4: Controls, defaults, and data flow

- Top bar: a "Z axis" menu button listing None plus only the metrics the
  dive actually has, beside the existing color chips. The Overlays menu
  gains "Wall shadows"; defaults are ceiling on, markers on, shadows on,
  curtain off, strata off.
- Default Z = temperature when present, otherwise None. Default color = the
  Z metric; selecting a color chip decouples color from Z. Both live as
  session state in `Dive3dPage` (like `_metric` today); no persistence.
- `dive3dGeometryProvider` key: `(diveId, colorMetric, zMetric)`. It builds
  `ZAxisSpec` from settings and data, decides the None fallback, and keeps
  the synchronous path below 2000 samples (the `compute()` hop deadlocks
  fakeAsync in widget tests). `dive3dSceneDataProvider` is unchanged.
- Camera presets: a pose menu next to the zoom buttons with Default
  (yaw -32, pitch 22), Front (yaw 0, pitch 0: depth vs time), Side
  (yaw -90, pitch 0: depth vs metric), Top (yaw 0, pitch 90: metric vs
  time). Double-tap still resets to Default. Presets are yaw/pitch pairs
  applied through the viewport's existing pose logic.
- Unchanged: the `view_in_ar` entry point on the profile card, the Tissue
  and Computers scenes (they see only the picker and chrome-mode renames),
  play/scrub, marker taps, zoom and pan gestures, the decimator.
- Degraded states: no profile samples hides the entry point (unchanged); a
  metric absent from the dive is not listed; a metric that loses its data
  (source switch) falls back to None and the menu reflects it.

## Section 5: Testing and delivery

### Tests (TDD, each unit first)

Domain, pure Dart:

- `PathBuilder`: vertex and index counts, Z taken from the series, all Z = 0
  in None mode, colors mirror the palette output.
- `ShadowBuilder`: three shadows plus drop lines, lifted off their walls,
  none emitted in None mode.
- `CeilingBuilder`: sheet spans path to ceiling at the path's Z, red on
  violation, absent without ceilings.
- Z series resampling: interior gap interpolation, ends held, fewer than
  two samples means None.
- `ZAxisSpec` and `nice_step`: hand-computed vectors for temperature in C
  and F, pressure in bar and psi, ascent rate, ppO2.
- `buildDiveAxes`: roles present, tick positions match `xOf`/`yOf`/`zOf`,
  label text, Z axis omitted in None mode.
- `SceneGeometryService`: layer presence per overlay, layer order,
  `scrubPath.zs`, TTS metric on both axes.

Picking and rendering:

- `PathHoverPicker`: nearest sample, radius cutoff, pan-independence.
- `TissueHoverPicker`: parity with `pickNearestTissueVertex` on the existing
  fixtures.
- Headless `PictureRecorder` probes: grid pixels behind the tube, axis
  pixels in front, in `framed` mode.

Widgets:

- `Dive3dPage`: Z menu lists only present metrics; temperature default and
  None fallback; overlay defaults; pose presets; tooltip on hover and on
  tap; imperial labels (F, psi, ft) when settings say so.
- `Dive3dInteractiveViewport`: `chromeMode.framed` wiring, picker plumbing,
  existing tissue and seascape tests unchanged.

Known traps from earlier 3D work: keep geometry synchronous under 2000
samples; use bounded pumps, not `pumpAndSettle`, where painters repaint on
a listenable; headless text renders as boxes (assert placement, not
glyphs); the projected-vertex cache key must include the pose.

### Verification before the PR

Whole-project `flutter analyze` (infos are CI-fatal), `dart format .`, l10n
keys added to all 11 ARBs and `flutter gen-l10n` run, one full test suite
run, and a macOS smoke on a real deco dive with temperature and tank
pressure (check both unit systems).

### Delivery

One PR from the `worktree-dive-3d-path` worktree. No schema change, no new
dependencies. The 2D profile chart is untouched.

## Out of scope

- Multiple simultaneous Z metrics (the metric-lane alternative); a second
  path or lanes can be added later on the same builders.
- Persisting the Z and color choices.
- Any change to the tissue, comparison, career, or seascape scenes beyond
  the viewport parameter renames.
- Spatial (heading-based) swim paths; that remains the seascape scene.
