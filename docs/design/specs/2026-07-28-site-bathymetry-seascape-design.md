# Site Bathymetry Seascape - Design

**Date:** 2026-07-28
**Status:** Approved (design dialogue with Eric, 2026-07-28)
**Supersedes in part:** the synthesized-terrain-only stance of
`2026-07-11-spatial-site-3d-design.md` (that scene remains as the fallback).
**Depends on:** the dive 3D view foundation (`Scene3d`, `Dive3dInteractiveViewport`,
CustomPainter renderer), `DeadReckoningService`, `geo_math`,
`local_cache_database.dart` (local ladder at v6 on main; this takes v7 —
PR #728 reef data, unmerged, also claims v7 on its branch; whichever merges
second renumbers).

## Problem

The current 3D Seascape is per-dive and only becomes meaningful when a dive
has per-sample compass heading and/or entry/exit GPS fixes. Most divers have
neither, so the scene degenerates to a straight-line path through a seafloor
synthesized from that one dive's depth samples. The one datum nearly every
logged dive has is a **dive site with GPS coordinates** - so the feature is
re-anchored on the site, rendering **real bathymetry** around the site pin.

## Decisions (Eric, 2026-07-28)

- **Terrain source: real bathymetry data** (not aggregated dive depths, not
  better synthetic art).
- **Placement: both** - a new site-level seascape page, and the existing
  per-dive seascape upgrades to real terrain when available.
- **Multi-source from day one**, architecture: **best-source-wins resolver**
  (Approach A). No mosaic/blending (vertical-datum seams: EMODnet is LAT,
  GMRT/ETOPO are MSL-referenced). No server-side proxy.
- **Site scene contents: all of** site pin + max-depth marker, dive
  entry/exit markers, reconstructed dive paths, nearby-site pins.
- All work in worktree `site-bathymetry-seascape`.

## Verified data sources (live-checked 2026-07-28)

| Tier | Source | Coverage | Resolution | Format | License |
|---|---|---|---|---|---|
| 1 | EMODnet ERDDAP DTM 2024 (`erddap.emodnet.eu`, datasets `bathymetry_dtm_2024`, `bathymetry_dtm_carib_2024`) | European seas + Caribbean tile (lat 11-19 N, lon -70.5..-59.5) | ~115 m surveyed | ERDDAP JSON | CC-BY 4.0, commercial OK |
| 2 | GMRT GridServer (`gmrt.org/services/GridServer`) | Global | ~61-100 m where multibeam exists, ~450 m background | ESRI ASCII (`format=esriascii`) | CC-BY 4.0, commercial OK, "not for navigation" |
| 3 | NOAA ERDDAP ETOPO 2022 (`coastwatch.pfeg.noaa.gov`, mirror `oceanwatch.pifsc.noaa.gov`, dataset `ETOPO_2022_v1_15s`) | Global | 15 arc-sec (~450 m) | ERDDAP JSON | US public domain |

All keyless. Ruled out: OpenTopography API (commercial key embedding
prohibited), NOAA BlueTopo direct-from-app (COG + per-tile UTM parsing burden
in Dart), OpenTopoData public server (1000 calls/day testing tier),
Open-Meteo elevation (no bathymetry - returns 0.0 over ocean).

Source quirks to pin in parsers:
- GMRT: `nodata_value -2147483648` appears literally; rows run north to
  south; `cellsize` may be scientific notation; land cells carry positive
  elevations. (Planning decision: the `/services/GridServer/metadata`
  pre-flight is deferred — a fixed ~4 km box at `resolution=high` plus the
  repository's 120-cell downsample cap makes it an extra round-trip and
  failure mode for no change in outcome.)
- ERDDAP JSON (both servers): depth column mixes int and float - parse as
  `num`; land cells are `null` (EMODnet); grid is cell-centered on the fixed
  grid, not the requested bounds.
- EMODnet vertical datum is LAT, not MSL - fine standalone, never mix into
  another source's grid.

## Architecture

### New feature: `lib/features/bathymetry/`

Terrain data is not 3D-specific (future consumers: site maps, depth-shaded
map layers). Mirrors `lib/features/reef/` third-party-data structure.

```
lib/features/bathymetry/
  domain/
    bathymetry_grid.dart        // entity: origin lat/lon, cell sizes (deg),
                                // rows x cols, List<double?> depths (row-major,
                                // null = nodata), sourceId, resolutionMeters,
                                // fetchedAt. Pure Dart.
    bathymetry_source.dart      // interface: id, covers(GeoPoint),
                                // fetch(center, spanMeters) -> BathymetryGrid?
  data/
    sources/
      emodnet_source.dart       // tier 1, coverage-box gated
      gmrt_source.dart          // tier 2, global primary
      etopo_erddap_source.dart  // tier 3, fallback + mirror failover
    bathymetry_resolver.dart    // walks tiers, first grid with enough wet cells
    bathymetry_repository.dart  // cache-first getGrid(GeoPoint)
  application/
    bathymetry_providers.dart   // grid provider (family by quantized center)
```

### Resolver

Order: EMODnet (only inside its coverage boxes) -> GMRT -> ETOPO ERDDAP.
Accept the first grid with at least 10% wet cells (non-null, negative
depth) - a site pinned slightly onshore still finds water, while an inland
coordinate yields a definitive `empty`. The winning
source id + resolution ride along for the provenance caption.

Default request box ~4 km square; ETOPO requests ~10 km (coarse cells need
the wider box for enough samples). Grid capped at ~120x120 cells with
downsampling above that.

### Cache (`local_cache_database.dart`, v6 -> v7)

(Ladder note, corrected at planning time: main's local cache DB is at v6 —
reef's v7 claim lives on the unmerged PR #728 branch. This feature takes
v6 -> v7 here; second-to-merge renumbers.)

New table `BathymetryCache`, keyed by **quantized coordinate** (not site id)
so nearby sites, re-pinned sites, and site-less GPS-fixed dives share a
fetch. Quantum: 0.02 degrees (~2 km) - coordinates within the same 0.02
degree cell share one grid, and the 4 km request box still covers a pin up
to ~1.4 km from the quantized center. Columns: key, centerLat, centerLon, sourceId, resolutionMeters, grid
JSON blob, status (`ok` / `empty` / `unavailable`), fetchedAt.

- Statuses are **definitive answers only**. A transient network failure
  writes no row - next visit retries. (Reef-data rule, applied verbatim.)
- No TTL - the seafloor does not move. A manual refresh action can force
  refetch.
- Local-only DB: never synced, never backed up; restored devices refetch.

### Scene assembly (`lib/features/dive_3d/`)

- `BathymetryTerrainBuilder` (new, in `domain/spatial/`): `BathymetryGrid` ->
  terrain mesh in the local east-north-up frame anchored at the site pin
  (Y = -depth), existing teal->navy depth ramp, water plane at Y = 0. Land
  cells (elevation >= 0) render in a distinct sand/rock tone so shorelines
  read. Existing synthesized `TerrainBuilder` unchanged, as fallback.
- `SiteSeascapeGeometryService` (new, in `domain/spatial/` alongside the
  other spatial builders) -> `Scene3d`:
  - Layers: terrain, water (overlay).
  - Markers: site pin on the surface + max-depth marker at the site's
    recorded max depth; entry/exit markers for every dive at the site with
    GPS fixes; nearby-site pins for other sites inside the grid bounds
    (label-only in v1).
  - Paths: dead-reckoned ribbons for dives with heading data, each anchored
    at its own entry fix (site pin when absent). Paths and marker groups are
    overlay-toggleable; heavy sites stay readable.
- Per-dive upgrade: `spatialGeometryProvider` tries the bathymetry grid
  first (centered on the dive's site pin, else its entry GPS fix), falls
  back to the synthesized terrain. Same `SpatialSitePage`.
- **Paths never deform real terrain.** Dead-reckoned paths may clip through
  the seafloor where the horizontal estimate is off; the "Estimated path"
  caption owns that honestly. (The synthesized fallback still cradles the
  path as today.)

### UI

- `SiteSeascapePage` (new): shared interactive viewport + overlay toggles.
  No time scrub (no single timeline at site level). Entry: action on the
  site detail page.
- `SpatialSitePage` (existing): unchanged layout; terrain upgrades when a
  grid resolves.
- Captions become provenance labels: "Seafloor: GMRT ~61 m - CC-BY" (source
  name + resolution + license), or the existing "Synthesized seafloor" chip
  on fallback. Attribution also listed in About/credits (satisfies CC-BY
  for GMRT/EMODnet).
- All new strings localized in all 10 non-English locales + l10n regen.

## Error handling

- Scene providers never silently return null on error (PR #659 lesson).
  Every terminal state renders: real-terrain scene, synthesized fallback, or
  an explicit no-profile/no-site message. A fetch failure is never a
  spinner.
- Per-source timeout (~10 s); one in-flight fetch per cache key (dedupe);
  resolver failure degrades cleanly to synthesized terrain.
- No auto-prefetch sweeps in v1 - fetch on first view only (polite to
  keyless government servers).
- Offline is a first-class state: cached grid renders identically; no cache
  -> synthesized terrain + honest caption; no dialogs.
- `compute()` isolate only above the size threshold, synchronous below
  (FakeAsync deadlock rule).

## Testing

- **Parser fixtures** from recorded live payloads: GMRT ESRI ASCII (nodata
  sentinel, scientific-notation cellsize, north-south rows), ERDDAP JSON
  (int/float/null mixing), EMODnet land nulls. No live network in tests.
- **Resolver**: coverage-box gating, tier order, mirror failover, wet-cell
  threshold (onshore pin finds water; inland coordinate -> `empty`).
- **Cache**: quantized-key sharing, status semantics, transient failure
  writes nothing, no-TTL.
- **Builders/scene**: vertex counts, land vs water coloring, Y = -depth
  mapping, marker/path anchoring in the local frame, nearby-site inclusion.
- **Widget**: both pages render every terminal state; regression test that
  error states never leave a `CircularProgressIndicator` up.

## Delivery

Small PR stack in worktree `site-bathymetry-seascape`, roughly:
1. Bathymetry feature: entity, sources, resolver, cache (local DB v8),
   repository, providers, parser fixtures + tests.
2. Site seascape: geometry service, page, site-detail entry point, l10n.
3. Per-dive upgrade: provider fallback chain, provenance captions, credits.

Exact task slicing belongs to the implementation plan (writing-plans).

## Deferred

- Mosaic/blending of sources (datum reconciliation required first).
- NOAA BlueTopo / CUDEM high-res US data (needs server-side preprocessing).
- Tapping a nearby-site pin to navigate to that site's seascape.
- Auto-prefetch (e.g. on site save) and bulk prefetch for offline trips.
- Real bathymetry in the flythrough/career scenes.
