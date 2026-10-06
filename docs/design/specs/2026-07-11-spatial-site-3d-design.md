# Spatial Site 3D Scene - Design (dive 3D view, phase 2)

**Date:** 2026-07-11
**Status:** Approved (autonomous build per uninterrupted directive)
**Depends on:** the dive 3D view foundation - `Scene3d`, the CustomPainter
renderer, `Dive3dInteractiveViewport`; the merged per-sample `heading`
(#563); `geo_math` (`distanceMeters`, `initialBearingDegrees`). No external
library, no external bathymetry data.

## What it shows

The dive placed in a reconstructed 3D seascape: the swim path threaded
through a synthesized seafloor, viewable above the waterline (a map-like
top-down look) and below it (a terrain fly-through). Suunto-app-style, but
honest about what is known vs inferred.

## Honesty stance (important)

There is no underwater positioning and no bathymetry in the app. The scene
is a **reconstruction**, and it says so:
- The **path** is dead-reckoned from per-sample compass heading and an
  estimated swim speed, anchored at the entry GPS fix and rubber-banded to
  the exit fix when both exist. Without heading it degrades to a straight
  entry->exit line. A caption states "Estimated path (dead reckoning)".
- The **terrain** is synthesized: the diver's deepest excursions are known
  seafloor points; elsewhere the surface interpolates toward the site max
  depth. It is a plausible cradle for the path, not surveyed bathymetry.
  A caption states "Synthesized seafloor".

## Coordinate system

A local east-north-up meter frame anchored at the entry point. X = easting,
Z = northing, Y = -depth. `SceneBounds` fits the horizontal bounding box to
xSpan/zSpan (via the scene Z range already added) and depth to ySpan.

## Pipeline

1. **DeadReckoningService** (pure): inputs = per-sample (time s, depth m,
   heading deg?), the exit offset in local meters (from
   `distanceMeters`/`initialBearingDegrees(entry, exit)`, null if no exit
   fix), and a swim-speed estimate (default ~0.25 m/s horizontal, only
   while moving/at depth). Integrates heading x step into an (east, north)
   path; if an exit offset exists, applies a linear drift correction so the
   path lands on it (rubber-banding accumulated dead-reckoning error).
   Fallback when no headings: straight line entry->exit (or a short drift
   when no exit). Output: list of (east, north, depth) + a `reconstructed`
   flag and a `bounds` (min/max east/north/depth).

2. **TerrainBuilder** (pure): a heightmap grid over the path's horizontal
   bounding box (padded). Each cell's seafloor depth = the max dive depth
   among nearby path points (inverse-distance weighted), blended toward the
   site max depth as a floor for far cells. Emits a terrain mesh colored by
   depth (shallow teal -> deep navy) and a translucent water-surface plane
   at Y=0.

3. **SpatialPathBuilder** (pure): the swim path as a bright 3D tube/ribbon
   through (easting, -depth, northing), colored by depth or time; entry and
   exit markers on the water surface.

4. **SpatialGeometryService**: assembles `Scene3d` layers = [terrain,
   water(overlay), path], markers = [entry, exit], bounds, and a scrub path
   following the diver along the route over time.

## Components

```
lib/core/utils/geo_math.dart                 // + destinationOffsetMeters helper if needed
lib/features/dive_3d/domain/spatial/
  dead_reckoning_service.dart      // path reconstruction
  reckoned_path.dart               // result: points + bounds + reconstructed flag
  terrain_builder.dart             // seafloor heightmap + water plane
  spatial_path_builder.dart        // 3D path ribbon + markers
  spatial_geometry_service.dart    // -> Scene3d
lib/features/dive_3d/application/spatial_providers.dart
lib/features/dive_3d/presentation/pages/spatial_site_page.dart
```

Entry point: a "3D seascape" action on the dive detail profile card header
(next to the existing 3D button), enabled when the dive has a profile.

## Interaction

Orbit/zoom via the shared viewport. The scrub timeline moves the diver
cursor along the path (the scene provides a 3D scrub path). Overlay toggles
for water surface and terrain. Two captions (estimated path / synthesized
seafloor) are always visible so the reconstruction is never mistaken for
survey data.

## Testing

- DeadReckoning: straight north headings -> path goes +north; rubber-band
  lands on the exit offset; no-heading fallback is a straight entry->exit
  line; empty/degenerate inputs safe.
- Terrain: grid vertex/index counts; cells near a deep path point are deep;
  far cells approach site max depth; water plane at Y=0.
- Path builder: ribbon vertex counts; markers at entry/exit.
- Geometry service: layer set; scene bounds fit the horizontal box; scrub
  path present.
- Providers: assembles from mocked profile + heading + entry/exit + site;
  null when no profile.
- Widget: page renders viewport + both captions.

## Deferred

- Real bathymetry ingestion (external data source, licensing) - the
  synthesized terrain is explicitly a placeholder for it.
- Surface GPS boat-track draping.
- Doppler/DVL or dive-computer speed if a future computer reports it.
