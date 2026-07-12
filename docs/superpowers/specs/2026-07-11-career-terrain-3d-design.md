# Career Terrain 3D Scene - Design (dive 3D view, phase 2)

**Date:** 2026-07-11
**Status:** Approved (autonomous build per uninterrupted directive)
**Depends on:** the dive 3D view foundation - `Scene3d`, the CustomPainter
renderer, `Dive3dInteractiveViewport`, `RibbonBuilder`. No external library.

## What it shows

A "terrain" of a diver's history: many dives rendered as parallel depth-time
ribbons stacked along the Z axis. Seen from above/side it reads as a
landscape whose ridges and troughs are individual dive profiles - how your
diving at a site (or over a season) evolved. Entered from a dive site (all
dives at that site) or the statistics tab (a date range).

## Scene geometry

Shared coordinate convention: X = run time, Y = depth (down), Z = dive
index. All dives in the set share one time scale and one depth scale so
they are directly comparable:
- X = time / maxDurationSeconds * xSpan (a 20 min dive is 1/3 the width of
  a 60 min dive in the same set - relative duration preserved).
- Y = -depth / maxDepthMeters * ySpan (shared depth scale).
- Z = dive index spread across a widened Z extent (grows with count), so
  the stack is legible. Requires `SceneBounds` to carry a scene Z range
  (added alongside the existing scene Y range).

Each dive is a thin depth ribbon (reusing `RibbonBuilder`) at its Z offset,
colored by a per-set metric:
- **Recency** (default): older dives cool/faded, newer dives saturated.
- **Max depth**: shallow green to deep blue.

A faint base grid plane and shared depth-grid lines give scale. The scrub
cursor is omitted (a career view is a static object, not a time replay);
the timeline bar hides in this scene.

## Data

`careerSceneDataProvider(CareerQuery)` where `CareerQuery` is either
`{siteId}` or `{fromDate, toDate}` (+ an optional cap, default 60 dives,
newest kept; `log()` the drop). It gathers each dive's downsampled profile
(the ~120-point mini-profile the repo already loads for lists is ideal) and
the dive's date + max depth. A pure `CareerGeometryService` turns the set
into a `Scene3d`.

## Components

```
lib/features/dive_3d/
  domain/career/
    career_scene_data.dart        // set of {index, date, maxDepth, times, depths}
    career_geometry_service.dart  // -> Scene3d (stacked ribbons + grid)
  application/career_providers.dart
  presentation/pages/career_terrain_page.dart   // reuses the viewport
```

Entry points: a "3D history" action on the dive site detail page (site
dives) and on the statistics tab (recent range). Both push
`CareerTerrainPage`.

## Testing

- `CareerGeometryService`: N dives -> N ribbon layers at distinct Z; shared
  time/depth scaling; recency vs depth coloring; empty set -> empty scene;
  cap enforcement.
- Provider: assembles from mocked dives + profiles; site vs date-range
  queries; cap + newest-kept.
- Widget: the page renders the viewport with a built scene; no scrub bar.

## Deferred

- Per-dive selection/highlight and drill-into-dive from the terrain.
- Site-relative horizontal placement (that is the spatial scene's job).
