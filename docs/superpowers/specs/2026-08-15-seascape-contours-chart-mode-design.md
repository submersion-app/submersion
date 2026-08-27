# Seascape Contours and Chart Mode - Design

**Date:** 2026-08-15
**Status:** Approved (design dialogue with Eric, 2026-08-15)
**Depends on:** the site bathymetry seascape
(`2026-07-28-site-bathymetry-seascape-design.md`, shipped in PR #763) and its
axes/extent addendum (`2026-07-28-seascape-axes-and-extent-design.md`).
**Incorporates:** issue #1065 (nautical chart analysis request): steep-wall
shading, configurable ramp range, banded/continuous gradient, custom contour
levels, and a sites-map entry point. The issue's measure-points idea stays in
slice 4 of the program.
**Part of:** the seascape usefulness program (slice 1 of 5, see Program
Context below).

## Problem

The 3D seascape renders real bathymetry but reads as scenery: a smooth
teal-to-navy ramp gives no precise depth structure, and there is no way to
get the classic "nautical chart" read of a site. Divers briefing a dive want
to see isobaths (where the 10 m line runs, where the wall drops), and they
want a north-up plan view they can read in ten seconds.

## Program Context

Brainstormed 2026-08-15. The seascape serves four jobs (pre-dive briefing,
post-dive story, site knowledge base, quick orientation), delivered as five
slices, each its own spec/plan/PR cycle:

1. **Terrain legibility: contour lines + chart mode (this spec).**
2. Site features: diver-placed annotations (wreck, mooring, entry/exit,
   swim-through, hazard, typical-current arrow), a new synced table.
   Currents are deliberately diver-annotated, not model-derived: no public
   model resolves flow at dive-site scale, and the seascape's honesty
   principle forbids fake precision.
3. Wreck suggestions: OSM seamarks (Overpass) + NOAA ENC wrecks as a
   keyless cached source layer, surfaced as suggestions the diver accepts
   into site features.
4. Briefing tools: two-point measure (distance, bearing, depth profile
   along the line) and depth-limit shading (cert depth or MOD of a chosen
   mix). Demand evidence: issue #1065 independently requests map measure
   points.
5. Dive coverage layer: aggregate path ribbons into a "where I've been"
   density trace.

## Decisions (Eric, 2026-08-15)

- Contour levels are unit-aware nice values in the diver's display unit.
- Contours render as occlusion-correct ribbon meshes, not chrome lines.
- Major contours get depth labels in the 3D orbit view as well as in chart
  mode.
- Chart mode lives on the site seascape page as a mode toggle: locked
  north-up top-down orthographic plan view.
- The depth legend shows in BOTH modes and on BOTH seascape pages (site and
  per-dive), not only in chart mode.
- The per-dive seascape page gets a "Contours" FilterChip (a chip row above
  the time scrub bar) instead of hardcoding contours on.
- No export/share button in this slice; no chart mode on the per-dive page.

Second pass (Eric, 2026-08-15, incorporating issue #1065, all four accepted):

- Steep-wall highlighting as its own overlay with a user-set angle
  threshold.
- A terrain-appearance sheet on both seascape pages: ramp depth range,
  banded vs continuous gradient, contour mode, line thickness, wall
  threshold. Persisted in `AppSettings`.
- Custom contour levels with optional per-level colors and ONE global line
  thickness slider (no per-level thickness).
- The seascape becomes reachable from the dive-sites map marker callout,
  not only the site detail app bar.

Post-review amendments (Eric, 2026-08-15, after using the build):

- The contour line thickness option is REMOVED (no slider, no
  `contourThickness` field; ribbon widths are the fixed minor/major
  constants). Legacy stored JSON containing the field still decodes.
- The compass rose stays pinned in its corner under pan: the chrome
  painter receives the viewport's pan offset and pre-subtracts it for
  fixed chrome, while world-anchored chrome keeps riding the pan.
- The occlusion mechanism below is CORRECTED: layer order alone cannot
  occlude draped geometry, so the renderer depth-sorts draped layers
  together with the terrain.

## Design

### Contour generation

New pure-domain builder `lib/features/dive_3d/domain/spatial/contour_builder.dart`:

- Marching squares over `BathymetryGrid.depthsMeters`. Any cell whose four
  corners include a `null` (nodata) or land value is skipped entirely, so
  contours stop at the edge of known data instead of interpolating fiction.
- Per-cell segments are joined into polylines (shared-endpoint chaining) so
  ribbons are continuous and labels have a curve to anchor to.
- Polyline vertices map through the same ENU-to-scene projection as the
  terrain mesh (`enuBounds` + `spatial_projection.dart`), so contours lie
  exactly on the terrain surface.
- **Levels:** computed at nice values in the diver's display depth unit
  using the existing 1/2/5 x 10^n `niceStep` logic from
  `seascape_axes.dart`. Selection rule: the minor interval is the smallest
  nice step, floored at 1 display unit, that yields at most 15 levels across
  the wet depth range (0 to `grid.maxDepthMeters` in display units).
  (Correction at planning time: without the floor, the at-most-15 rule alone
  can never produce fewer than 2 levels, so the flat-site guard would be
  dead code and near-flat sites would get centimeter contours.) Every 5th
  level is a major
  contour. A feet diver gets 20/40/60 ft lines; a meters diver gets
  5/10/15 m lines. Levels convert to meters for marching; label text stays
  in display units.
- **Flat-site guard:** if fewer than 2 levels fit in the depth range, no
  contours are emitted (Auto mode only; Custom lists are explicit).
- **Custom levels (issue #1065):** the terrain-appearance sheet can switch
  contour mode from Auto to Custom: a user-edited list of depths in the
  display unit, each with an optional color defaulting to the standard ink.
  In Custom mode every level is labeled (custom lists are short by nature).
  An empty Custom list falls back to Auto. Levels deeper than the terrain
  simply produce no line (marching squares finds no crossings).
- Output type `ContourSet`: per level, `levelMeters`, `isMajor`, `labelText`,
  optional color override, and scene-space polylines.

The builder is a pure function (no IO, no throws by design) and runs inside
the existing geometry services, so it rides the current `compute()` isolate
path for grids above 4000 cells.

### Rendering: ribbon meshes under the contours overlay

Chrome-painted polylines were rejected: the chrome foreground has no
occlusion, so lines on the far side of a ridge would draw through it.
Instead each polyline becomes a thin triangle-strip ribbon (the dive-path
ribbon pattern), lifted a small epsilon above the terrain surface to avoid
z-fighting the mesh, and packaged as `SceneLayer`s gated by a new
`SceneOverlay.contours` value (default visible on both seascape scenes).

Occlusion (corrected post-review): the painter draws each mesh whole in
layer order, and its back-to-front triangle sort is per-mesh, so layer
order alone would paint every ribbon over the terrain, far side included.
Draped layers (contours, walls) therefore carry
`SceneLayer.drapedOnTerrain`; the renderer merges the terrain plus all
visible draped layers into one triangle soup and depth-sorts them together
(each triangle keeping its source mesh's opacity), while paths, pins, and
water keep plain layer order on top. Chip toggling stays free: hidden
draped layers are simply excluded from the merge.

Styling: minor contours are fine, semi-transparent light ink; major
contours are wider and more opaque, at fixed widths (the thickness option
was removed post-review). Default colors are fixed constants beside the
terrain ramp constants in the builder; Custom-mode per-level colors
override them.

### Contour labels

Labeled levels are the Auto majors, or every level in Custom mode. Labels
show only while the contours overlay is visible (no separate toggle).

- **3D orbit view:** each labeled contour carries a small set of candidate
  anchor points sampled along its polyline. Per paint, `AxisChromePainter`
  projects the candidates and draws the label at the candidate nearest the
  camera (highest view-space z), which naturally sits on the visible front
  side of the terrain. Screen-aligned text with a subtle halo, one label per
  major contour.
- **Chart mode:** same machinery; top-down means no occlusion concerns, so
  labels are always legible.
- Anchor data rides a new nullable `contourLabels` field on the same result
  records that carry `axisInputs` (`SpatialSceneResult`,
  `SiteSeascapeReady`).

### Chart mode (site seascape page only)

A mode toggle in the site seascape page's app bar switches between 3D orbit
and chart:

- **Camera:** top-down orthographic, locked north-up. Rotation gestures are
  disabled; pan and pinch-zoom remain. Entering chart mode snaps
  zoom-to-fit on the terrain box. Because the projector is orthographic, the
  top-down view is a geometrically true plan view; the existing axes remain
  visible as the scale frame and the compass rose stays pinned north-up.
- **Engine trap:** positive pitch tips scene-north toward screen bottom at
  yaw 0, so the exact yaw/pitch pair for north-up is verified in a unit test
  via the existing `compassNeedleAngle` helper, never assumed.
- **Water plane:** hidden in chart mode. From above it only tints the map
  blue and muddies depth colors. The water layer gains a
  `SceneOverlay.water` gate: always on in 3D orbit, excluded from the chart
  mode visible set, never exposed as a user chip. (Visibility routes through
  the overlay gate because the scene is immutable data and the viewport a
  dumb renderer; rebuilding geometry to hide a plane, or a page-side special
  case in the viewport, would both be the wrong seam.)

Chart mode only exists on the site page, which only renders with a real
bathymetry grid, so it can never show synthesized terrain.

### Depth legend

New widget `seascape_depth_legend.dart`: a compact vertical ramp bar
(teal at 0 to navy) with tick marks at the active contour levels (Auto
majors, or the Custom list), values in display units, plus the sand swatch
labeled as land. The legend follows the appearance settings: a smooth bar
when the gradient is continuous, discrete swatches when banded, and when a
custom ramp range is active the bar ends at the range max with a "+" cap
indicating deeper terrain clamps to the deepest color. Shown top-right on
BOTH seascape pages in BOTH modes, clear of the provenance chip (top-left),
compass (bottom-left), and overlay chips (bottom center). Hidden on
synthesized terrain.

### Terrain appearance sheet (issue #1065)

Both seascape pages gain a tune icon opening a settings sheet, persisted in
`AppSettings` (the `tissueColorScheme` precedent) so choices stick across
sessions and apply to both pages:

- **Color depth range:** a toggle plus a max-depth slider with manual input
  (shallow end pinned at 0). When on, the ramp spans 0 to the custom max
  instead of the grid's deepest cell; deeper terrain clamps to the deepest
  color. This resolves the drop-off compression trade-off flagged in the
  axes spec (deepest-cell normalization crushing reef color range).
- **Gradient style:** continuous (default, current behavior) or banded into
  10 equal segments across the active ramp range.
- **Contour mode:** Auto (default) or Custom, with the Custom level/color
  editor.
- **Steep-wall threshold:** angle slider (5 to 90 degrees) with manual
  input, default 22 degrees, with a one-line caption explaining that grid
  resolution smooths
  real walls flatter than they are (a sheer wall inside one ~67 m cell reads
  as a modest slope), which is why the default is well under 45.

Persistence (amended post-review: Eric wants the knobs to sync): the knobs
live on `AppSettings` as ONE `SeascapeAppearance` value object (fields:
`rampMaxDepthMeters` nullable, `rampBanded`, `contourMode`, `customLevels`,
`wallAngleDeg`), stored PER-DIVER as a single JSON string in a new nullable
`diver_settings.seascape_appearance` TEXT column (main-DB migration v151,
with the idempotent-DDL beforeOpen backstop). Sync rides the existing
whole-row diver_settings serialization for free; the column's nullability
tolerates rows from older builds. The SharedPreferences key remains only as
the fallback store while no diver exists: on the first load with a diver,
a row that has never held a value adopts the pref exactly once (written
through immediately so it syncs), and the pref is then removed so a stale
copy can never resurrect a value reset on another device.

### Steep-wall highlighting (issue #1065)

Slope per cell is computed by central differences over real-meter spacing
(degree cell sizes converted via the grid's latitude). Cells steeper than
the threshold become a translucent red highlight mesh, duplicated cell
quads lifted a small epsilon above the terrain, packaged as `SceneLayer`s
gated by a new `SceneOverlay.steepWalls` value with its own "Walls"
FilterChip beside "Contours" on both pages, default OFF.

Walls are a separate overlay layer rather than tint baked into terrain
vertex colors for the same reason contours are: toggling a pre-built layer
is free, while baking would force a geometry rebuild per flip. Changing the
threshold rebuilds geometry through the settings watch, same as a unit
change. Never shown on synthesized terrain.

### Sites-map entry point (issue #1065)

The dive-sites map's marker callout gains the same terrain/seascape action
as the site detail app bar (icon + tooltip reused), gated on the site
having coordinates. Exact callout widget located at planning time.

### Integration

- `SceneOverlay` gains `contours`, `water`, and `steepWalls`. The
  analytical dive scene's overlay menu (`dive_3d_page.dart`) does an
  exhaustive switch over this enum: all new values get labels there but are
  filtered out of that menu, the same way `paths` was handled when the
  seascape shipped.
- **Site seascape page:** adds FilterChips "Contours" (default on) and
  "Walls" (default off), plus the appearance-sheet tune icon and the chart
  mode toggle in the app bar.
- **Per-dive seascape page:** gains a compact chip row above the
  `TimeScrubBar` with "Contours" and "Walls" chips, plus the tune icon
  (markers stay hardcoded; that scene has no markers today, and water stays
  internal).
- Both geometry services (`site_seascape_geometry_service.dart`,
  `spatial_geometry_service.dart`) invoke the contour builder only when the
  terrain is real bathymetry. The synthesized fallback gets no contours, no
  legend, and no chart mode: contours assert "this is the real isobath,"
  matching the precedent that hover inspection is disabled on invented
  terrain.
- Levels depend on the display unit, and geometry now also depends on the
  appearance settings (ramp range, banded, contour mode/levels, thickness,
  wall threshold), so the geometry providers gain a settings dependency and
  rebuild when any of those change (a 20 ft contour is not a 6 m contour).
  Known trap: a new provider dependency breaks consumer widget tests that
  lack a settings override; all touched page tests get the
  `_TestSettingsNotifier` pattern.
- New l10n keys (chip labels, chart mode toggle tooltip, legend land label,
  overlay menu labels, appearance sheet labels and captions) are translated
  in ALL supported locales, and `flutter gen-l10n` runs from the project
  root.

### Edge cases

- Nodata holes: marching squares skips cells touching null corners.
- Near-flat sites: fewer than 2 fitting levels means no contour lines; the
  legend still shows the ramp.
- Unit switch: levels, labels, and legend all recompute via the settings
  watch. Custom contour levels are stored in meters internally and
  re-rendered in the active display unit.
- Degenerate label placement: if every candidate anchor of a contour
  projects off-screen, its label is skipped that frame.
- Ramp range max set shallower than the terrain: deeper cells clamp to the
  deepest color; the legend's "+" cap signals the clamp.
- Wall threshold at the extremes: 0 degrees would tint everything, so the
  slider floor is 5 degrees; 90 degrees tints nothing and is allowed.

## Testing

TDD throughout:

- `contour_builder` unit tests with hand-computed marching-squares vectors:
  a tiny 3x3 grid with a known saddle, null-corner skipping, polyline
  joining, level selection in both unit systems, flat-site guard, custom
  level lists (colors, empty-list fallback, level below terrain), label
  anchor sampling.
- Steep-wall builder unit tests with hand-computed slope vectors: a known
  incline grid where the expected angle is derivable by hand, threshold
  boundary cases, latitude-corrected cell spacing.
- Ramp tests: banded quantization boundaries (10 segments over the active
  range), custom range clamping, continuous default unchanged.
- Chart-mode camera preset unit test asserting north-up via
  `compassNeedleAngle`.
- Widget tests: contours and walls chips toggle their layers on both pages,
  chart mode toggle swaps camera and chrome (legend present, water hidden,
  labels on), legend renders ticks in the active unit and swatches when
  banded, appearance sheet round-trips its settings, sites-map callout
  action navigates. Established patterns apply: settings-notifier override,
  bounded pumps on pages hosting maps or never-settling animations.
- `dart format .` and `flutter analyze` clean before push.

## Out of scope (this slice)

- Export/share chart as image (respect the existing share-vs-save duality
  when it comes).
- Chart mode on the per-dive seascape page.
- Any contour line thickness control (removed post-review) and per-site
  appearance overrides (appearance settings are global).
- Slices 2 to 5 of the program (site features, wreck suggestions, measure +
  depth-limit shading, coverage layer). Issue #1065's measure request lands
  in slice 4.

## File plan

New:
- `lib/features/dive_3d/domain/spatial/seascape_appearance.dart` (+ tests)
- `lib/features/dive_3d/domain/spatial/contour_builder.dart` (+ tests)
- `lib/features/dive_3d/domain/spatial/wall_highlight_builder.dart`
  (+ tests)
- `lib/features/dive_3d/presentation/widgets/seascape_depth_legend.dart`
  (+ tests)
- `lib/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart`
  (+ tests)

Touched:
- `lib/features/dive_3d/presentation/scene_overlay.dart` (three new values:
  `contours`, `water`, `steepWalls`)
- `lib/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart`
- `lib/features/dive_3d/domain/spatial/spatial_geometry_service.dart`
- `lib/features/dive_3d/application/site_seascape_providers.dart`
- `lib/features/dive_3d/application/spatial_providers.dart`
- `lib/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart`
  (`AxisChromePainter`: contour labels)
- `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart`
  (chart camera lock, label inputs)
- `lib/features/dive_3d/presentation/pages/site_seascape_page.dart`
- `lib/features/dive_3d/presentation/pages/spatial_site_page.dart`
- `lib/features/dive_3d/presentation/pages/dive_3d_page.dart` (exhaustive
  switch entries)
- `lib/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart`
  (ramp range + banded gradient)
- `lib/features/settings/presentation/providers/settings_providers.dart`
  (`AppSettings` gains the `seascapeAppearance` field; note `AppSettings`
  is defined IN settings_providers.dart, no separate entity file)
- `lib/shared/widgets/map_list_layout/map_info_card.dart` (trailing slot)
- `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
  (seascape action on the marker callout)
- `lib/l10n/arb/*.arb` (all locales)
