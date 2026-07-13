# 3D Tissue View — Axes, Grid, and Hover Tooltips

- Date: 2026-07-12
- Status: Approved design, pending implementation plan
- Scope: The `SceneKind.tissue` scene only (dive/computers scenes untouched)

## Goal

Make the 3D tissue saturation surface readable as a graph, not just a colored
blob:

1. Draw **X / Y / Z axis lines** with tick marks (no painted numbers).
2. Draw a **grid** — both a draped wireframe on the surface itself and a faint
   floor/back-wall reference frame.
3. Show a **tooltip on hover** (and tap, for touch) reporting the value at any
   location on the surface.

The axes are: **X = dive time**, **Y = saturation %**, **Z = compartment #**.

## Current state (what exists today)

- `lib/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart`
  `SubsurfaceTissueBuilder.build(List<DecoStatus>, {colorFn})` builds a
  height-field `Scene3d`: an `n x k` grid of vertices where `n` = decimated
  time columns (cap `targetColumns = 220`), `k` = 16 compartments. For each
  vertex, `Y-height` and `color` both come from
  `subsurfacePercentage(compartment, ambient)`; a translucent red plane marks
  100% (the M-value / deco limit) at `referenceHeight = 3.0`.
- `lib/features/dive_3d/presentation/renderer/scene_projector.dart`
  `SceneProjector` — orthographic (yaw about Y, pitch about X, drop view-Z,
  fit-to-canvas). Key API: `project(x,y,z) -> Offset`, `viewOf(x,y,z)`,
  `viewDepth(x,y,z)` (larger = nearer camera). Default camera yaw -32, pitch 22.
- `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart`
  `Dive3dInteractiveViewport` — owns camera state (`_yaw/_pitch/_zoom`),
  gestures (pan rotates, scroll zooms, double-tap resets), a `CustomPaint`
  whose `painter` is `Dive3dScenePainter` (the surface) and whose
  `foregroundPainter` is `_ScrubCursorPainter` (the scrub dot). Tap hit-tests
  only markers (24 px), of which the tissue scene has none.
- `lib/features/dive_3d/application/tissue_providers.dart`
  `tissueDecoStatusesProvider` (family by diveId) and `tissue3dSceneProvider`.
- `lib/features/dive_3d/presentation/pages/dive_3d_page.dart`
  Hosts the viewport in a `Stack` via `_sceneScaffold`; overlays
  (`TissueLegend`, `TissueReadoutPanel`, controls) are `Positioned` widgets.
  A shared `ValueNotifier<double> _position` drives scrub without page rebuilds.
- `DecoStatus` (`lib/core/deco/entities/deco_status.dart`) has **no timestamp**;
  `TissueCompartment` has `compartmentNumber` (1-16) and `halfTimeN2` (minutes).

### Established conventions to respect

- **No on-canvas text in the 3D subsystem.** Numeric context lives in overlaid
  Flutter widgets (`TissueLegend`, `TissueReadoutPanel`). This is why the axes
  carry ticks but no painted numbers; the tooltip is the precise readout.
- **Overlays are `Positioned` widgets in the page `Stack`.**
- **Shared `ValueNotifier` for high-frequency UI state** (the scrub position)
  so only the affected layer repaints.
- **Many small files**, feature-scoped; theme-aware colors for light/dark.

## Non-goals

- No changes to the dive or computers scenes.
- No ray-cast/interpolated picking — nearest grid vertex is sufficient given
  the dense grid (up to 220 x 16).
- No repetitive-dive chain / N2-He toggle (that is the separate, unbuilt
  `2026-07-11-tissue-saturation-3d-design.md` phase-2 vision).
- No new persisted data or schema changes.

## Design decisions (confirmed with user)

| Decision | Choice |
| --- | --- |
| Grid placement | **Both**: draped wireframe on the surface + faint floor/wall reference frame |
| Axis labeling | **Ticks + tooltip for values** (no numbers painted on the canvas) |
| Touch support | Hover for pointer devices; **tap** performs the same pick on touch |
| Tooltip time | Derived: `normalizedProgress[col] x dive runtime` (uniform-sampling approximation, documented) |
| Axis colors | X=amber, Y=green, Z=blue (avoid red, which reads as the M-value plane); theme-tuned |

## Architecture

### 1. `TissueSurfaceGrid` (new value object)

The flat mesh vertex list loses the grid topology that both the wireframe (needs
adjacent vertices) and the picker (needs screen->cell mapping) require. Introduce
one small immutable value object, built once, consumed by both.

`lib/features/dive_3d/domain/tissue/tissue_surface_grid.dart`

```
class TissueSurfaceGrid {
  final int columns;            // n (decimated time columns)
  final int compartments;       // k (16)
  final Float32List positions;  // n*k*3 world coords (x, y=height, z), same order as the mesh
  final List<double> normalizedTimes;   // length n, 0..1 progress per column
  final List<int> compartmentNumbers;   // length k, 1..16 (fast -> slow)
  final List<double> halfTimesN2;       // length k, minutes
  final Float32List saturationPct;      // n*k, subsurfacePercentage per cell

  Vector3-like positionAt(int col, int comp);   // or (x,y,z) record
  double percentAt(int col, int comp);
}
```

`SubsurfaceTissueBuilder` already computes every one of these values inside its
build loop (it currently discards `pct` after deriving height/color). Change
`build` to also assemble and return a `TissueSurfaceGrid` alongside the `Scene3d`
(either a small result record `({Scene3d scene, TissueSurfaceGrid grid})`, or a
second static method that returns the grid; the record keeps a single pass).
The `positions` array is the **same** array/order used for the surface mesh, so
wireframe and picking align exactly with what is drawn.

### 2. Providers

`tissue_providers.dart`:

- Change `tissue3dSceneProvider` (or add `tissueSurfaceGridProvider`) so the
  grid is available to the page. Prefer a single provider returning
  `({Scene3d scene, TissueSurfaceGrid grid})?` to guarantee they are built from
  one pass and never drift.
- Add a small `tissueRuntimeSecondsProvider` (family by diveId) that reads the
  dive's runtime from the existing dive provider (`dive_providers.dart`, already
  imported by the page) for the tooltip's time conversion. If runtime is
  unavailable, the tooltip falls back to showing normalized progress as `NN%`.

### 3. Axis + tick + frame-grid geometry

`lib/features/dive_3d/domain/geometry/axis_frame.dart` — a pure builder that,
given `SceneBounds`, produces renderer-neutral line segments (in world coords)
for:

- **Three axis lines** from the origin corner `(x=0, y=sceneMinY, z=sceneMinZ)`:
  - X (time): to `(xSpan, sceneMinY, sceneMinZ)`
  - Y (saturation): to `(0, sceneMaxY, sceneMinZ)`
  - Z (compartment): to `(0, sceneMinY, sceneMaxZ)`
- **Tick marks** (short perpendicular segments) along each axis:
  - Y ticks at 0 / 50 / 100% (the 100% tick coincides with the red plane at
    `referenceHeight`).
  - X ticks at evenly spaced progress fractions (e.g. every 25%).
  - Z ticks per compartment (or every other, to reduce clutter).
- **Frame grid** lines on the floor plane (`y = sceneMinY`) and the two back
  walls (`x = 0` wall and `z = sceneMaxZ` wall), spaced to match the ticks.

Output is data (lists of `(start,end)` world-coord segments, tagged by role so
the painter can color axes distinctly from grid lines). Pure and unit-testable;
no `Canvas` dependency.

### 4. Painters

The viewport gains two optional painter responsibilities, enabled only when the
tissue chrome inputs are supplied:

- **Background frame painter** (`_TissueFramePainter`): draws the `axis_frame`
  **frame grid** lines. Rendered *behind* the surface (as the `CustomPaint.painter`
  of a layer beneath the scene) so the opaque surface occludes it via paint
  order — correct occlusion for free. Faint `colorScheme.outline`-ish lines at
  low alpha.
- **Foreground chrome painter** (`_TissueChromePainter`): draws, in order,
  1. the **draped wireframe** — decimated iso-time lines (~12 columns) and
     iso-compartment lines (all 16 rows) connecting adjacent `TissueSurfaceGrid`
     vertices, projected via `projector.project`, low alpha
     (`colorScheme.onSurface` ~0.15);
  2. the **axis lines + ticks** from `axis_frame`, in the axis colors;
  3. the **hover marker** — a ring at the picked vertex (styled like the scrub
     cursor: light fill + dark stroke), repainting on the pick `ValueNotifier`.

Because a `CustomPaint` exposes a single `foregroundPainter`, the scrub cursor
and the chrome are combined: either compose them in one foreground painter that
takes both `scrubPosition` and `pick` as `Listenable`s (via
`Listenable.merge`), or nest a second `CustomPaint`. Preference: a single
foreground painter that `super(repaint: Listenable.merge([scrubPosition, pick]))`
and draws chrome then cursor — one layer, minimal churn.

Occlusion note (accepted simplification): the draped wireframe is a foreground
pass with no depth test, so gridlines on the far side of the surface show
faintly through the front. Decimation + low alpha keep this subtle. Upgrading to
depth-correct wireframe (baking into the mesh pipeline) is out of scope.

### 5. Picking

`lib/features/dive_3d/domain/tissue/tissue_surface_picker.dart` — a pure
function plus a tiny cache:

```
TissuePick? pickNearest({
  required Offset cursor,
  required List<Offset> projectedVertices, // n*k screen points, cached
  required List<double> viewDepths,        // n*k, for front-most tie-break
  required int columns,
  required int compartments,
  double thresholdPx = 20,
});
```

Algorithm: scan the projected vertices; keep the nearest within `thresholdPx`;
on near-ties (within ~4 px) prefer the greater `viewDepth` (front-facing) so the
cursor picks the visible surface rather than a vertex hidden behind it.

`TissuePick` carries only raw location: `{ int col, int comp, Offset screenPos }`
(or null). Display values are resolved downstream (by the tooltip widget, given
the grid + runtime), keeping the picker pure and free of formatting concerns:
`time = runtimeSeconds * normalizedTimes[col]` (or normalized % fallback),
`compartmentNumber = compartmentNumbers[comp]`, `halfTimeN2 = halfTimesN2[comp]`,
`percent = saturationPct[col*k+comp]`, and a saturation **state** derived from
`percent` using half-open intervals:

| percent | state | l10n key |
| --- | --- | --- |
| `< 45` | On-gassing (undersaturated) | `dive3d_tissue_stateOnGassing` |
| `[45, 55)` | Equilibrium | `dive3d_tissue_stateEquilibrium` |
| `[55, 100]` | Off-gassing (supersaturated) | `dive3d_tissue_stateOffGassing` |
| `> 100` | Past M-value | `dive3d_tissue_statePastMValue` |

(Thresholds chosen around the 50% = ambient-equilibrium convention; wording
aligns with the existing legend's on-/off-gassing language.)

Caching: the viewport recomputes `projectedVertices` + `viewDepths` only when
`(yaw, pitch, zoom, size)` change (memoized field), not per hover event. Up to
3520 projections per camera change is trivial.

### 6. Tooltip widget + hover/tap wiring

- `lib/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart` — a
  compact card:
  - line 1: `mm:ss` (or `NN%`) + `Comp {n}` + `{halfTime} min N2`
  - line 2: `Saturation {percent}%` + state word (colored by the color scale)
- The **page** owns `ValueNotifier<TissuePick?> _hoverPick`. The viewport wraps
  its gesture stack in a `MouseRegion(onHover, onExit)` that runs the picker and
  writes `_hoverPick`; `onTapUp` does the same for touch (tap toggles/sets the
  pick, exit/tap-empty clears it). The chrome painter repaints on `_hoverPick`
  to draw the marker. A `ValueListenableBuilder<TissuePick?>` in the page
  `Stack` renders `TissueHoverTooltip` at `pick.screenPos` (offset so it does
  not sit under the cursor and clamped to stay on screen). This mirrors the
  `_position` notifier pattern → no page rebuild per hover.

### 7. Viewport API change

Extend `Dive3dInteractiveViewport` with optional, backward-compatible inputs:

```
final TissueSurfaceGrid? surfaceGrid;     // enables wireframe + picking
final AxisFrame? axisFrame;               // enables axes/ticks + frame grid
final int? runtimeSeconds;                // for tooltip time
final ValueNotifier<TissuePick?>? hoverPick;  // pick output channel
```

All null for the dive/computers scenes → identical behavior to today. When
supplied (tissue scene), the viewport enables the `MouseRegion`, the background
frame painter, and the chrome+cursor foreground painter. `dive_3d_page.dart`
`_buildTissueBody` / `_sceneScaffold` pass these through and add the tooltip
`ValueListenableBuilder` to the `Stack`.

## Data flow

```
tissueDecoStatusesProvider(diveId)
  -> SubsurfaceTissueBuilder.build -> (Scene3d scene, TissueSurfaceGrid grid)
  -> tissue scene provider  ---------------------------------+
dive runtime (dive_providers) -> tissueRuntimeSecondsProvider|
                                                             v
Dive3dPage._buildTissueBody:
  AxisFrame.build(scene.bounds) --------------------+
  ValueNotifier<TissuePick?> _hoverPick             |
                                                    v
  Dive3dInteractiveViewport(scene, surfaceGrid, axisFrame, runtimeSeconds, hoverPick)
    - background: _TissueFramePainter(axisFrame.frameGrid)
    - surface:    Dive3dScenePainter (unchanged)
    - foreground: chrome (wireframe + axes/ticks + marker) + scrub cursor
    - MouseRegion.onHover / onTapUp -> pickNearest(...) -> _hoverPick.value
  Stack overlay: ValueListenableBuilder(_hoverPick) -> TissueHoverTooltip
```

## Localization

New ARB keys (add to `app_en.arb` and **all 10 non-en locales**, then
regenerate localizations):

- `dive3d_tissue_tooltipCompartment` ("Comp {number}")
- `dive3d_tissue_tooltipHalfTime` ("{minutes} min N2")
- `dive3d_tissue_tooltipSaturation` ("Saturation {percent}%")
- `dive3d_tissue_stateOnGassing`, `dive3d_tissue_stateEquilibrium`,
  `dive3d_tissue_stateOffGassing`, `dive3d_tissue_statePastMValue`
- `dive3d_tissue_tooltipProgress` ("{percent}% of dive") — time fallback

No new axis-name strings: axes are named already by the existing
`dive3d_tissue_legendAxes`.

## Testing plan

Unit (pure, fast):
- `tissue_surface_grid_test.dart` — builder emits correct dimensions, per-cell
  `saturationPct` matches `subsurfacePercentage`, `positions` align with the
  mesh, monotonic `normalizedTimes`, compartment numbers/half-times length `k`.
- `axis_frame_test.dart` — axis endpoints at the expected bounds corners; Y
  ticks include 0/50/100%; frame-grid line counts; roles tagged correctly.
- `tissue_surface_picker_test.dart` — nearest vertex within threshold; returns
  null beyond threshold; front-most tie-break by `viewDepth`; empty grid guard;
  state-word thresholds (44/45/55/100/101 boundaries).

Widget:
- Extend `dive_3d_page_test.dart` — switching to the tissue scene, a hover over
  the viewport publishes a pick and renders `TissueHoverTooltip` with expected
  text; camera reset clears/repositions correctly. Use
  `tester.runAsync` around any drift/async per the repo's fakeasync note if the
  provider overrides require it.

Guards: empty / single-sample / all-flat (NaN-safe) surfaces produce no grid,
no picks, and no tooltip rather than throwing.

## Files

New:
- `lib/features/dive_3d/domain/tissue/tissue_surface_grid.dart`
- `lib/features/dive_3d/domain/tissue/tissue_surface_picker.dart`
- `lib/features/dive_3d/domain/geometry/axis_frame.dart`
- `lib/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart`
- Painters (`_TissueFramePainter`, `_TissueChromePainter`) — new file(s) under
  `presentation/renderer/` or co-located with the viewport.
- Tests listed above.

Changed:
- `lib/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart` (emit grid)
- `lib/features/dive_3d/application/tissue_providers.dart` (expose grid + runtime)
- `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart`
  (optional chrome inputs, `MouseRegion`, painters, picking)
- `lib/features/dive_3d/presentation/pages/dive_3d_page.dart` (wire grid,
  axis frame, hover notifier, tooltip overlay)
- `lib/l10n/arb/*.arb` (+ regenerated localizations)

## Risks / accepted simplifications

- **Draped wireframe occlusion is approximate** (foreground pass). Mitigated by
  decimation + low alpha. Depth-correct wireframe is a future upgrade.
- **Tooltip time is an approximation** (`progress x runtime`, assumes uniform
  sampling), consistent with the 2D charts working in index space. Documented in
  code; falls back to `% of dive` when runtime is unavailable.
- **Hover is pointer-only**; tap covers touch. No new gesture conflicts (tap was
  previously marker-only, and the tissue scene has no markers).

## Post-review revisions (2026-07-13)

Changes made after the initial implementation, in response to user feedback and
the PR review:

- **Axis labels — decision reversed.** The "ticks only, no on-canvas numbers"
  rule above was reversed at the user's request ("no units or labels on the
  axis"). The chrome painter now draws axis **titles** (Time / Saturation % /
  Compartment) and **tick values** (minutes / 0-50-100% / compartment numbers)
  via `TextPainter`, honoring the locale's `TextDirection` for RTL. On-canvas
  text in the tissue scene is therefore intentional; the no-text convention
  still holds for the dive/computers scenes.
- **Compartment (Z) axis widened.** `SubsurfaceTissueBuilder.zHalfWidth` (3.5)
  replaces the shared `SceneBounds.zSlabHalfWidth` (1.0) for the tissue scene
  only, so the 16 compartments spread out enough to read and to carry labels.
  The dive scene's reference planes are unaffected.
- **Pan + discoverable zoom.** The viewport gained two-finger trackpad pan
  (`PointerPanZoom` -> screen-space `Transform.translate`, cursor un-translated
  for picking; the published pick's `screenPos` adds `_pan` back so the tooltip
  overlay, which sits outside the Transform, stays on the vertex), trackpad
  pinch-zoom, and an on-screen +/-/reset control column. One-finger drag still
  rotates; the mouse wheel still zooms. **Scope note:** unlike the tissue chrome
  (axes/grid/labels/tooltip), which stays gated behind the nullable tissue-only
  params, this camera interaction (rotate/pan/zoom + controls) is a general
  viewport capability and applies to every scene the viewport renders (the dive
  scene as well as tissue); the computers scene uses a different widget and is
  unaffected. The earlier "zero blast radius" note therefore covers the chrome,
  not the camera controls.
- **Review fixes.** Projection cache keyed by grid identity; `shouldRepaint`
  covers style/bounds; tooltip guards out-of-range picks; picker uses squared
  distance and guards zero compartments.
```