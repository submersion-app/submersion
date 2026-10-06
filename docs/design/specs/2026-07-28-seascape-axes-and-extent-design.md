# Seascape Axes and Extended Extent - Design

**Date:** 2026-07-28
**Status:** Approved (Eric, 2026-07-28; implement in PR #763)
**Depends on:** `2026-07-28-site-bathymetry-seascape-design.md` (built), the
tissue chrome pipeline (`AxisFrame`, `AxisLabelSet`, `TissueChromeStyle`,
viewport `axisFrame`/`axisLabels`/`chromeStyle` params), `UnitFormatter` +
`settingsProvider`.

## What changes

1. Both seascape views (per-dive `SpatialSitePage`, site `SiteSeascapePage`)
   gain **always-visible distance and depth axes**.
2. The bathymetry request span **doubles from 4 km to 8 km** so the scene
   shows more surrounding seafloor.

## Axes

- **Placement**: a map-frame at the waterline plus a descending depth axis,
  all anchored at the scene's origin corner (min-east, min-north):
  - X axis: along the south edge at y = 0, from min-east to max-east.
  - Z axis: along the west edge at y = 0, from min-north to max-north.
  - Y (depth) axis: from the corner at y = 0 straight down to
    `yOf(maxDepth)`.
- **No wall or floor grids** - axes, ticks, and labels only; the scenic
  look stays.
- **Ticks and units**: tick values are nice steps (1/2/5 x 10^n, targeting
  ~5 divisions) computed in the DIVER'S depth display unit
  (`settings.depthUnit`: meters or feet) for both depth and horizontal
  distance, then converted back to scene coordinates. Tick labels are plain
  numbers measured from the origin corner (0, step, 2·step, ...). Axis
  titles carry the unit: "Distance (m)" / "Depth (ft)" - localized titles,
  unit symbol appended in code.
- **Honesty note**: the scene deliberately exaggerates the vertical scale
  (depth normalizes to the scene box independently of horizontal extent).
  Real-valued axes on both dimensions make that explicit.

## Components

```
lib/features/dive_3d/domain/spatial/seascape_axes.dart   // NEW, pure
  class SeascapeAxes { final AxisFrame frame; final AxisLabelSet labels; }
  SeascapeAxes buildSeascapeAxes({
    required SpatialProjection projection,
    required double minEast, maxEast, minNorth, maxNorth,   // meters
    required double maxDepthMeters,
    required double displayUnitInMeters,   // 1.0 (m) or 0.3048 (ft)
    required String unitSymbol,            // 'm' / 'ft'
    required String distanceTitle,         // localized
    required String depthTitle,            // localized
  })
lib/features/dive_3d/presentation/seascape_chrome.dart   // NEW, tiny
  TissueChromeStyle seascapeChromeStyle(BuildContext)    // theme-derived colors
```

Pages construct the axes from the scene's projection inputs and pass
`axisFrame` / `axisLabels` / `chromeStyle` to the shared viewport exactly
as the tissue view does. `TissueChromeStyle` is reused as-is (it is only a
color set). Verify the viewport renders chrome without the tissue-only
`surfaceGrid`; decouple if accidentally coupled.

The projection inputs must reach the pages: `SiteSeascapeReady` and
`SpatialSceneResult` gain a plain
`({double minEast, double maxEast, double minNorth, double maxNorth, double maxDepth})`
record (`axisInputs`), captured where the scene's projection is built. The
PAGES build `SeascapeAxes` from it - localized titles and unit settings
are presentation concerns unavailable in the pure geometry layer, and the
record keeps the compute() isolate payload plain.

l10n: reuse an existing "Depth" key if suitable (`dive3d_metric_depth`),
add `dive3d_seascape_axis_distance` ("Distance") if no existing key fits.
All 10 non-English locales + regen, per convention.

## Extended extent

- `BathymetryResolver` span constant: 4000 -> **8000** meters (ETOPO keeps
  its 10 km minimum). GMRT still returns ~60 m cells at this size; the
  repository's 120x120 downsample cap bounds memory and paint cost.
- **Cache-key versioning**: existing cached grids are 4 km and never
  expire, so the span folds into the cache key:
  `"<lat>,<lon>@<spanMeters>"` (e.g. `12.16,-68.30@8000`). A span change
  refetches naturally; stale rows are inert leftovers in the local-only,
  never-backed-up cache DB.
- Site scene nearby-sites radius and per-dive surroundings grow
  automatically (both derive from grid bounds).

## Testing

- Builder unit tests: nice-step selection in meters and feet, tick counts,
  label values measured from the corner, depth-axis endpoints, degenerate
  inputs (zero spans) safe.
- Repository: key format includes the span; a key-format change misses old
  cache rows (fetches anew).
- Resolver: sources receive the 8000 m span.
- Widget tests: both pages pass chrome to the viewport; existing terminal-
  state tests stay green.

## Addendum: hover inspection (approved 2026-07-28)

Hovering the terrain shows latitude/longitude (5 decimals) and seafloor
depth (diver's units) at that vertex, mirroring the tissue view's hover.

- **Data**: results carry the downsampled `BathymetryGrid` — required on
  `SiteSeascapeReady`, nullable on `SpatialSceneResult`. Hover exists only
  over real bathymetry; the synthesized seafloor is invented data, so no
  hover there.
- **Pick lattice**: reuse the viewport's existing machinery by building
  its pick grid with `columns = grid.rows`, `compartments = grid.cols`,
  `positions = scene.layers.first.mesh.positions` (the terrain mesh's own
  vertex array; index layouts match `row*cols + col` exactly, so picking
  aligns pixel-for-pixel with the rendered surface). Tissue-specific
  fields stay empty; the hover path never reads them.
- **Viewport**: hover MouseRegion gates on `surfaceGrid != null &&
  hoverPick != null` (not the full tissue-chrome bundle);
  `AxisChromePainter` gains optional pick inputs and draws the hover ring,
  repainting on the pick listenable.
- **Tooltip**: `SeascapeHoverTooltip` positioned by the existing clamping
  layout delegate; land/nodata cells show coordinates with an em-dash for
  depth. Mouse-driven, matching tissue; no tap-to-inspect.
- **Tests**: lattice index alignment, cell -> lat/lon/depth mapping,
  tooltip rendering per cell kind, no hover wiring without a grid.

## Addendum: compass (approved 2026-07-29)

A small compass rose fixed in the viewport's bottom-left corner of both
seascape views: circle, needle, "N" at the needle tip. The needle points
along the screen-projected direction of scene-north (+Z), computed by
projecting two world points through the existing SceneProjector and taking
the screen delta — so it tracks yaw AND pitch honestly. Drawn by
AxisChromePainter (seascape-only, repaints on camera change, no new
plumbing); hidden when the projection degenerates (viewing straight along
north). Pure helper `compassNeedleAngle(SceneProjector)` carries the math
and its unit tests (yaw rotation tracks, degenerate null).

## Out of scope

- Grid walls/floors, axis toggles, scrub-position readouts (the readout
  panel already exists for the per-dive scene).
- Depth-ramp renormalization for drop-off sites (flagged trade-off:
  deepest-cell normalization compresses reef color range near walls;
  orbit/zoom handles focus).
