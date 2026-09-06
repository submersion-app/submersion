# 3D Seascape: Extent and Detail

Status: proposed
Date: 2026-09-05
Related: `2026-07-28-site-bathymetry-seascape-design.md`,
`2026-07-28-seascape-axes-and-extent-design.md`,
`2026-08-15-seascape-contours-chart-mode-design.md`

## Problem

Two complaints, reported together:

1. The seascape shows too little area. It is "very constrained".
2. Dives close to shore look like they sit on the shoreline, with no real
   detail around the dive itself.

The current scene is a single 8 km square grid capped at 120x120 cells, so
67 m per cell at best. That square is the entire seascape: panning and
zooming reveal nothing beyond it, and zooming in past the cell size only
magnifies the same triangles.

## Measured evidence

All figures below come from the app's exact request shapes issued live on
2026-09-05.

### Bonaire (12.0930 N, 68.2870 W), 8 km box

| | EMODnet (tier 1, selected today) | GMRT (tier 2, never reached) |
| --- | --- | --- |
| Grid | 71 x 71 | 136 x 133 |
| Cell size | 115 m | 60 m |
| Known cells | 2,611 of 5,041 (48% nodata) | 18,088 of 18,088 (0% nodata) |
| Land cells | 0 | 45%, with a real coastline |
| Max depth in box | 668 m | 637 m |
| Wet cells shallower than 40 m | 5.6% | 2.3% |

### NOAA NCEI DEM mosaic ImageServer

`identify?returnCatalogItems=true&maxItemCount=25` returns every DEM in the
mosaic stack under a point with its `LowPS` cell size:

| Site | Best catalog item | Cell size |
| --- | --- | --- |
| Florida Keys | `ncei19_n25x25_w080x50_2016v1` | 3.4 m |
| La Jolla | `san_diego_navd88` | 10.3 m |
| Bonaire | `ETOPO_2022_v1_15s_surface_elev` | 464 m |

`maxItemCount` is load-bearing: the response truncates to three items by
default, which hides La Jolla's 10 m DEM behind ETOPO.

`exportImage` with `format=tiff&pixelType=F32` returns an uncompressed,
**tiled** (128 x 128 tiles), little-endian float32 GeoTIFF at any requested
size up to 20000 x 20000. A 2 km box at Molasses Reef returned 256 x 256 at
7.8 m per cell, values -1.5 m to -39.2 m, zero nodata. A shoreline box
returned 53.7% land above zero.

### Render budget

GMRT holds ~60 m natively at any span, so a naive 30 km box would be
504 x 495 cells = 496,964 triangles. The painter is a CPU painter's
algorithm with a full per-frame triangle sort and no depth buffer, so
uniform scaling is not available.

Measured end to end on 2026-09-05, after PR 1 landed, the cap is the
binding constraint well before the painter is:

| Site | Fetched | Rendered after the 120 cap | Triangles |
| --- | --- | --- | --- |
| Bonaire | 133 x 136 @ 60 m | 67 x 68 @ 120 m | 8,844 |
| Florida Keys | 256 x 256 @ 31 m | 86 x 86 @ 94 m | 14,450 |
| Medes Islands | 70 x 94 @ 115 m | unchanged | 12,834 |

Two consequences for PR 3. Real scenes run 8,800 to 14,500 triangles, not
the 28,322 a full 120 x 120 would produce, so there is more headroom than a
worst-case reading of the cap suggests. And `maxGridDim` currently discards
most of what the new source layer fetches: Bonaire renders at 120 m from a
60 m grid, which is no better than the 115 m EMODnet tile it replaced. PR 1
delivers coverage and a real coastline there; the resolution win is still
locked behind the cap, and raising it is the single highest-leverage change
left. It stays gated on the budget measurement rather than guessed at.

## Root causes

1. **Tier order selects the worse source.** `BathymetryResolver.resolve`
   accepts the first tier returning >= 10% wet cells. EMODnet's Caribbean
   tile returns 99.96% wet, so it always wins at Bonaire despite having half
   the resolution, half the cells missing, and no land at all.
2. **Nodata renders as flat shoreline.** `BathymetryTerrainBuilder
   .surfaceDepth` maps `null` to depth 0.0, and the colour branch treats
   `raw == null` as `landColor`. EMODnet's 48% nodata therefore becomes a
   flat sand-coloured slab at the waterline. This is the literal cause of
   "looks like it's basically on the shoreline".
3. **The dive zone is vertically crushed.** `SpatialProjection.maxDepth`
   comes from the deepest cell in the box. At Bonaire that is 668 m, so the
   0-40 m band where diving happens occupies 6% of scene height. Widening
   the box makes this strictly worse, because a wider box catches deeper
   water.
4. **The cell cap discards fetched detail.** `downsampleTo(120)` uses an
   integer stride, so GMRT's 136 columns collapse to 68: a 2x loss to clear
   a cap exceeded by 13%. It also picks every Nth sample rather than
   averaging, so the discarded cells contribute nothing.

## Design

### 1. Capability-driven source selection

`BathymetrySource` gains:

```dart
Future<SourceCapability?> probe(GeoPoint center);

class SourceCapability {
  final double cellSizeMeters;   // declared, best available at this point
  final String detail;           // provenance, e.g. the DEM's catalogue name
}
```

`probe` returns null for "I do not cover this point", replacing the
synchronous `covers`. EMODnet, GMRT and ETOPO answer from constants without
a network call. `NoaaDemSource` answers from the `identify` pre-flight and
returns null when the best `LowPS` is coarser than
`NoaaDemSource.usefulCellSizeMeters` (50 m), so the mosaic's ETOPO fallback
never masquerades as high-resolution data.

`BathymetryResolver` probes every source concurrently, then orders them by
**materially better resolution only**: a source preempts the declared list
order when its declared cell size is more than `preemptionFactor` (2.0)
finer. Within that factor, the declared order stands, so a regional survey
still outranks a global grid of nominally similar resolution.

This band matters. GMRT declares ~60 m against EMODnet's 115 m, a factor of
1.9, so a flat resolution sort would demote EMODnet across all of Europe on
a nominal number. Measured on 2026-09-05, GMRT's European grids are not
block-upsampled GEBCO (identical-neighbour fractions of 4.2% at the Medes
Islands and 0.1% at Zakynthos, against the ~87% a nearest-neighbour upsample
would show), but the Medes grid's 0.70 m median neighbour step is smooth
enough that its true information content is unproven. NOAA CUDEM at 3.4 m
clears the factor by 18x and rightly preempts everything.

Bonaire is fixed by the floors rather than by the ordering: EMODnet stays
ahead of GMRT on declared resolution, then fails the known-cell floor at
48%, and the resolver falls through to GMRT. That is the intended division
of labour. Ordering promotes materially better data; the floors reject data
that is nominally fine but actually absent.

The resolver fetches in the resulting order and accepts the first grid
passing **both** floors:

- `minWetFraction` 0.10 (unchanged)
- `minKnownFraction` 0.60 (new): the fraction of non-nodata cells

The known-cell floor is what rejects EMODnet's 48%-nodata Bonaire tile. A
source failing either floor falls through to the next; the definitive-versus
-transient distinction and its caching rules are unchanged.

Changing selection changes which grid a coordinate resolves to, but the
cache key is `<lat>,<lon>@<span>` and cached rows never expire, so every
already-visited site would keep serving its old EMODnet grid forever. The
key therefore gains a selection-generation token, `@8000v2`, bumped whenever
selection logic changes. Old rows go inert exactly as they did at the 4 km
to 8 km change.

Declared resolution is a claim, not a measurement. GMRT in particular
returns a fine nominal grid even where the underlying data is upsampled
GEBCO. The known-cell floor plus the existing provenance caption are the
mitigation; this design does not attempt to measure information content.

### 2. Nodata renders as a hole

`surfaceDepth` stops inventing a waterline value for nodata. Grid quads
with any nodata corner are omitted from the terrain index buffer. The
translucent water plane already spans the full box, so a gap reads as water
with no data rather than as land.

`TerrainCeiling`, `sampleGridDepth` and the hover picker already return null
for nodata cells and need no change. Contours, walls and the depth ramp
already skip them.

### 3. Nested level of detail

Two grids are fetched per site and merged into one terrain mesh.

```
+---------------------------------------+
|                                       |   OUTER
|             +-----------+             |   outerSpanMeters (24 km default)
|             |   INNER   |             |   outerMaxDim cells
|             |     * site|             |
|             +-----------+             |   INNER
|                                       |   innerSpanMeters (2 km default)
+---------------------------------------+   innerMaxDim cells, native res
```

- **Inner grid**: `innerSpanMeters` centred on the site, requested at the
  finest resolution the winning source offers, capped at `innerMaxDim`.
- **Outer grid**: `outerSpanMeters`, requested coarse, capped at
  `outerMaxDim`.
- **Merge**: outer quads whose centre falls inside the inner box are
  dropped, leaving a rectangular hole. The inner grid fills it.
- **Stitch band**: a ring of triangles bridges the outer hole's edge to the
  inner grid's edge, with vertices welded to both. The two grids have
  different cell sizes, so their edge vertices do not correspond; without
  the band the seam is a see-through crack at every camera angle.

Sources may differ between the two grids (CUDEM inner, GMRT outer). Vertical
datums then differ, which the original seascape design correctly warned
against mosaicking. The mitigation is explicit: the inner grid is offset by
the **median delta along its boundary ring**, sampled against the outer grid
at the same coordinates. The offset is recorded on the merged grid and
surfaced in the provenance caption. It is never applied silently, and it is
skipped entirely when both grids come from one source.

Cache keys gain a role suffix: `<lat>,<lon>@in<span>` and
`<lat>,<lon>@out<span>`. Existing `@8000` rows go inert, as they did at the
4 km to 8 km change.

### 4. Depth scale from the site's dives

`SpatialProjection.maxDepth` stops being the box maximum. The new
`depthWindowMeters` is:

1. the deepest recorded dive at this site multiplied by 1.25, floored at
   20 m and clamped to the grid's own maximum; or
2. with no dives on record, the 80th percentile of the box's wet cells.

`siteSeascapeProvider` already gathers `atSite` dives for path
reconstruction, so the deepest dive is available with no new query.

Terrain deeper than the window renders past the box floor and is clipped by
the viewport. `SceneProjector` fits to the declared `bounds.sceneMinY` and
`sceneMaxY` rather than to actual geometry extent, so this needs only that
`sceneMinY` stay pinned at `-SceneBounds.ySpan`. The current
`math.min(-SceneBounds.ySpan, proj.yOf(pinDepth))` grows the frame to keep a
deep site pin in view; that growth is removed, because it would re-crush the
scene and undo this change. A site pin deeper than the window is clamped to
the floor with its recorded depth still shown in the marker label.

The depth axis is built from the same window, so its ticks stay linear and
truthful. The ramp's `rampMaxDepthMeters` appearance setting is unchanged
and still controls colour only.

### 5. Averaging downsample

`BathymetryGrid.downsampleTo` averages each stride block's known cells
instead of picking the block's first sample, and returns nodata only where a
block is entirely nodata. Striding discards up to 3/4 of a fetched grid; a
block mean keeps the information and suppresses single-cell noise.

### 6. Render budget, measured first

`innerMaxDim` and `outerMaxDim` are **not** fixed by this design. The first
implementation task instruments `Dive3dScenePainter` frame time against
triangle count on real hardware and sets both from the measurement. Today's
scene is ~28,300 triangles; the merged scene will be larger, and the budget
is the binding constraint on every dimension above. No dimension is chosen
by guess.

`_isolateCellThreshold` (4000 cells) already routes large scenes through
`compute()`. The merged scene exceeds it in every case, so the isolate path
becomes the norm rather than the exception, and the synchronous path remains
only for widget tests.

## Provenance

The caption must name both grids: source, cell size and span for each, plus
the datum offset when one was applied. A scene whose inner and outer grids
come from different sources is a legitimate composite, and the UI says so.

## Testing

- `BathymetryResolver`: probe ordering, the known-cell floor rejecting a
  48%-nodata grid, fall-through on a failed floor, and the unchanged
  definitive-versus-transient contract.
- `NoaaDemSource`: `identify` parsing including the `maxItemCount`
  truncation trap, the 50 m usefulness threshold declining Bonaire, and the
  tiled float32 GeoTIFF parser against a recorded fixture.
- `BathymetryGrid.downsampleTo`: block means, all-nodata blocks staying
  nodata, and the resolution claim tracking the stride.
- Terrain builder: nodata quads absent from the index buffer, land and wet
  cells unaffected.
- LOD merge: the outer hole matches the inner extent, the stitch band leaves
  no gap (every boundary edge shared by exactly two triangles), and the
  datum offset is the boundary-ring median.
- Depth window: deepest-dive derivation, the 20 m floor, the grid clamp, the
  no-dives percentile fallback, and `sceneMinY` staying pinned when terrain
  runs deeper than the window.
- A render regression extending the existing `map_frame_handedness_test`
  approach: a synthetic asymmetric two-level grid rendered through the real
  painter, asserting the seam produces no background pixels along the
  boundary ring.

## Delivery

Three PRs, each independently shippable and each a visible improvement on
its own. Later phases do not silently depend on earlier ones landing.

**PR 1: source layer.** `probe`/`SourceCapability`, capability-ordered
selection, the known-cell floor, `NoaaDemSource`, and the averaging
downsample. No change to the scene's architecture, but on its own it moves
Bonaire from 115 m EMODnet to 60 m GMRT with a real coastline, and gives US
coastal sites 3 m to 10 m CUDEM.

**PR 2: honesty and vertical scale.** Nodata quads dropped, the depth window
derived from the site's dives, `sceneMinY` pinned, the site pin clamped, and
the depth axis rebuilt from the window. On its own this is what stops
near-shore dives reading as beached.

**PR 3: nested level of detail.** The painter budget measurement first, then
the inner and outer grids, the merge with its hole, the stitch band, the
datum offset, the two-role cache keys, and the composite provenance caption.
The constants come from the measurement taken at the head of this PR.

## Out of scope

- Zoom-driven refetching. The two levels are fixed per site.
- More than two levels.
- Any new appearance setting. Spans and caps are constants until there is
  evidence divers want to tune them.
- Measuring a source's true information content as opposed to its declared
  resolution.
