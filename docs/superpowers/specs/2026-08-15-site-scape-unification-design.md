# Site Scape Unification - Design

**Date:** 2026-08-15
**Status:** Approved (design dialogue with Eric, 2026-08-15)
**Depends on:** PR #1073 (seascape contours + chart mode + appearance sync);
delivery starts only after it merges.
**Part of:** the seascape usefulness program. This batch sits between the
program's slice 1 (shipped in #1073) and slice 2 (site features), and
supersedes the standalone site seascape page.

## Problem

The 2D site map and the 3D bathymetry view are separate worlds: different
pages, different affordances, no shared imagery or depth information. The
diver wants map imagery draped on the 3D terrain, depth coloring on the 2D
map, one unified home for both, and a Dive Details header card whose
"View Site" pill becomes real map/3D actions.

## Decisions (Eric, 2026-08-15)

- Unification model: **3D inside the sites map**, as an **in-place morph**:
  the map pane itself becomes the 3D terrain view for the selected site's
  region, with a 2D/3D toggle. The standalone `SiteSeascapePage` dissolves.
- **Site detail embeds the same pane**: its 200px map card and fullscreen
  variant become the morphable view too (the most-unified option).
- 3D imagery: **surface mode with blend** (Depth / Imagery / Blend), using
  the diver's active map style tiles so 2D and 3D always match.
- 2D depth overlay: **toggle, selected site only**, state persisted in the
  synced appearance settings, off by default.
- Dive Details header card: the "View Site" pill is replaced by **Map and
  3D pills targeting the site terrain** (the unified map in 2D or 3D mode);
  the card-body tap still opens site detail, and the dive's own swim-path
  3D stays on the profile card's buttons.
- Architecture: **Approach A**, one reusable `SiteScapeView` pane with
  host-injected map layers.
- Delivery: three PRs in order: (1) 2D depth overlay, (2) 3D imagery
  drape, (3) unification. Each gets its own worktree and plan.

## Design

### PR 1: 2D depth overlay

New pure builder `bathymetry_overlay_image.dart` (bathymetry feature,
presentation side): renders a `BathymetryGrid` to a `ui.Image` at roughly
4 pixels per cell. Wet cells use `BathymetryTerrainBuilder.depthColor`
honoring the appearance settings (ramp range, banded); land and nodata
cells are FULLY TRANSPARENT so the basemap's real cartography shows
through; contour polylines from `marchGrid` are stroked on top (majors
heavier, custom colors respected). Async via `PictureRecorder`, cached per
(grid identity, appearance) so panning never regenerates.

Placement: flutter_map `OverlayImageLayer` (currently unused in the repo)
with `LatLngBounds` from the grid corners, above tiles and below markers,
opacity ~0.75. Mercator-vs-rectangle error over an 8 km box is sub-pixel.

Control: a depth toggle joins the map controls (heat-map toggle at
top-right is the template; icon `Icons.water`), visible only with a site
selected. `SeascapeAppearance` gains `mapDepthOverlay: bool` (default
false), so the choice syncs per diver and the appearance sheet stays the
single settings surface. The overlay reads the selected site's grid via
the cache-first `bathymetryGridProvider`; when the grid is known absent,
enabling still records the (global, synced) preference but shows the
standard no-bathymetry notice and the layer stays away for that site
(correction at planning time: a global flag should not be blocked by one
site's missing data). The site detail embedded map gains the same layer
for its own site in this PR.

### PR 2: 3D imagery drape

`TerrainImageryService` (bathymetry feature, data side): for a grid box
and the active `MapStyle`, pick the zoom where the box spans ~3 to 5 tiles
(about z13-z14 for 8 km), compute the slippy tile range (extract and share
the lat/lon-to-tile math already in the dive-list thumbnail code), fetch
tiles via `MapTileConfig.tileUrl` (keyless), stitch tiles onto one
tile-aligned canvas; the UV frame maps the grid box into it (correction
at planning time: cropping bought nothing the frame does not). Cache the
resulting `ui.Image` in memory per (grid, style). A one-pixel WHITE TEXEL is
reserved in a padded corner. Any failure or offline yields null and the
terrain silently falls back to depth colors (no spinner, no error state).

Rendering: `MeshData` gains optional `textureCoordinates` (uv per vertex).
The terrain builder computes UVs by projecting each vertex's lat/lon into
the stitched image's Mercator frame. The painter's merged-soup path, when
given an image and a terrain mesh with UVs, emits `Vertices.raw` with
texture coordinates and paints with an `ImageShader`; flat shading stays
baked in vertex colors, modulated against the shader by the drawVertices
blend mode. Contours and walls in the same merged call carry UVs at the
reserved white texel so their vertex colors pass through modulation
unchanged: the merge group MUST remain one drawVertices call (one Paint,
one shader) to preserve the occlusion fix. Paths, pins, and water are
untouched.

Surface mode: `SeascapeAppearance` gains
`surfaceMode: depth | imagery | blend` (default depth), a three-way
segmented control in the appearance sheet. Imagery mode uses shading-only
(white x shade) vertex colors; Blend uses ramp x shade so depth tints the
photo. The legend hides in imagery mode and shows for depth and blend.
Attribution: the provenance chip line gains
`MapTileConfig.attribution(style)` whenever imagery is visible.

### PR 3: Unification

New `lib/features/site_scape/`:

- `SiteScapeView`: stateful pane with modes map2d / terrain3d / chart and
  a 2D/3D segmented control docked with the map buttons. The 2D half hosts
  a `FlutterMap` whose layers the HOST injects (tiles, built-in sites,
  clusters, heat map, depth overlay, attribution); the 3D half is
  `SiteTerrainPane`. 3D enables only with a selected site; no bathymetry
  disables the toggle with the existing no-bathymetry message as tooltip.
- `SiteTerrainPane`: the extraction of `SiteSeascapePage`'s body (provider
  watch, viewport, chips, legend, hover tooltip, provenance/attribution
  chips, tune + chart controls) into a host-agnostic widget.
- Camera continuity: 2D to 3D adopts the selected site's grid; 3D to 2D
  fits the map camera to the grid bounds.

Hosts and entry points:

- Sites map page (`site_map_content.dart`): wraps its map in the pane; the
  info card's terrain button flips the mode in place. Route accepts
  `?site=<id>&scape=3d` (the `?site=` mechanism already exists) so other
  screens can land directly in 3D.
- Site detail: the embedded map card and its fullscreen variant become
  `SiteScapeView` with the single-pin layer; the app bar terrain button
  opens the fullscreen variant already in 3D. The career button is
  unchanged.
- Dive detail header card: the "View Site" pill
  (`diveLog_detail_viewSite`) is replaced by compact Map and 3D pills
  navigating to the unified map focused on the dive's site in the
  respective mode. Card-body tap keeps opening site detail; the swim-path
  3D stays on the profile card.
- Deleted: `SiteSeascapePage` and its pushes. Untouched: the per-dive
  `SpatialSitePage`.

Mode is ephemeral: each entry starts where the caller asked (default 2D);
persistent knobs stay in the appearance sheet.

Corrections at planning time (PR 3): the sites surface has no `?site=`
mechanism; master-detail uses `?selected=` + `?view=map`, so the deep
link lives on the standalone route `/sites/map?site=<id>&scape=3d`.
Chart stays an internal toggle of `SiteTerrainPane`, not a third
`SiteScapeView` mode. BOTH sites-map surfaces host the pane: the
master-detail `SiteMapContent` AND the standalone `SiteMapPage`, which
also gains the `BathymetryDepthOverlayLayer` its toggle was flipping
without rendering (PR 1 gap). `SiteScapeView` is mode-controlled: hosts
hold the ephemeral mode in their own state, and the 2D stack stays
alive under `Offstage` so the map camera survives mode flips.

## Testing

- PR 1: image-builder unit tests on tiny grids (transparent land pixels,
  wet ramp pixels, contour strokes present, banded/range variants); widget
  tests for the toggle (appears with selection, persists via settings,
  no-bathymetry feedback).
- PR 2: tile-range math vectors (lat/lon to z/x/y at chosen zooms), UV
  projection vectors (corner vertices land on image corners), painter
  tests for the textured merge path (UVs emitted, white-texel UVs on
  draped non-terrain meshes), fallback-to-depth when the image is null,
  legend visibility per surface mode.
- PR 3: per-host widget tests with bounded pumps: mode toggle swaps panes
  and cameras, deep link lands in 3D, disabled toggle without bathymetry,
  dive card pills navigate with the right query params, site detail
  fullscreen opens in 3D, seascape-page routes are gone.
- Established traps apply throughout: settings-notifier overrides, bounded
  pumps on map-hosting pages, l10n keys in ALL 11 locales, gen-l10n from
  the project root.

## Out of scope

- Unifying the per-dive `SpatialSitePage` (dive-scoped, keeps its page).
- Imagery in the flythrough/career scenes.
- Offline tile prefetch for the 3D drape (the 2D map's FMTC cache is not
  reused in PR 2; a shared byte-level tile cache is a later refinement).
- Multi-site depth overlays on the 2D map (selected site only).

## File plan (indicative)

New: `lib/features/bathymetry/presentation/bathymetry_overlay_image.dart`,
`lib/features/bathymetry/data/terrain_imagery_service.dart`,
`lib/features/site_scape/presentation/site_scape_view.dart`,
`lib/features/site_scape/presentation/site_terrain_pane.dart`, shared
slippy-tile math helper, plus tests for each.

Touched: `mesh_data.dart` (+`textureCoordinates`), `preview_painter.dart`
(texture path), `bathymetry_terrain_builder.dart` (UVs),
`seascape_appearance.dart` (+`mapDepthOverlay`, +`surfaceMode`),
`terrain_appearance_sheet.dart`, `site_map_content.dart`,
`site_detail_page.dart`, `dive_detail_page.dart` (header card pills),
router (query params), l10n (all locales). Deleted:
`site_seascape_page.dart` (+ its test moves to the pane).
