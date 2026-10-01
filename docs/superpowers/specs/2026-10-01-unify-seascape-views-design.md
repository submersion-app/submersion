# Unify the dive, site and nav-track 3D seascape views

Issue: #2694

## Problem

Three separate presentation-layer implementations all render "the terrain
around a dive site," with no shared code above the low-level rendering
pipeline:

- `SiteTerrainPane`
  (`lib/features/site_scape/presentation/site_terrain_pane.dart`) - the
  richest of the three: markers, site features, zoom-dependent LOD (patch
  layer), photo-terrain mode, chart mode. Keyed by `siteId`, backed by
  `siteSeascapeProvider`.
- `SpatialSitePage`
  (`lib/features/dive_3d/presentation/pages/spatial_site_page.dart`) - a
  single dive's reconstructed path with a playback timeline, but none of the
  above overlays. Keyed by `diveId`, backed by `spatialGeometryProvider`.
- `NavTrackSeascapePage`
  (`lib/features/nav_track/presentation/pages/nav_track_seascape_page.dart`)
  - deliberately the simplest: viewport and scrub bar only, no hover
    tooltip, no bathymetry pick, no depth legend, no appearance sheet. Keyed
    by `trackId`, backed by `navTrackSceneProvider`. Its own doc comment
    already names the shared-base extraction as deferred work (see the
    design spec referenced there,
    `2026-09-10-underwater-nav-track-design.md`).

All three build on the same lower-level pieces (`Dive3dInteractiveViewport`,
`SceneOverlay`, `Scene3d`), so the duplication sits entirely at the page/pane
level: overlay selection, chip rows, captions, hover-tooltip wiring, axis
setup, and (for the dive and track cases) the playback timeline.

A structural difference matters for the design: a dive always belongs to a
site, but an underwater route does not. `NavTrackSeascapePage` loads its
terrain via a free-floating anchor point (`route.anchor`, see
`nav_track_scene_providers.dart`), not via a site id - there may be no
`DiveSite` row to key off of.

## Decisions

1. **`SiteTerrainPane` becomes the shared base** for all three. The
   site-only case (no dive, no route) keeps its exact current behavior. Only
   one existing caller today (`site_scape_view.dart`), so the blast radius of
   changing the pane's API is small.
2. **One optional, nullable context parameter** on `SiteTerrainPane`, working
   name `playbackContext` (not `routeOverlay` - that collides with the
   existing `SceneOverlay` enum already used for marker/contour/wall/feature
   toggles; two unrelated concepts must not share the word "overlay"), with
   separate sealed variants for the dive case and the nav-track case. `null`
   means today's site-only pane, unchanged. Every new piece of UI below gates
   on this one parameter - deliberately one mechanism, not a separate flag
   per feature.
3. **What `playbackContext != null` unlocks**, each attached to an existing
   structure rather than a new one:
   - a timeline/scrub bar at the bottom (`SafeArea` block), with its own
     `AnimationController` managed inside the pane (mirrors
     `SpatialSitePage._player` / `NavTrackSeascapePage._player` today).
     `SiteTerrainPane`'s state class must carry `SingleTickerProviderStateMixin`
     unconditionally (Dart mixins are static, can't be added only when a
     context is present); the controller itself is only instantiated when
     `playbackContext != null`, so the site-only path pays nothing for it.
   - a path-provenance caption ("recorded" vs. "estimated") and the "show
     measured route" filter chip - **dive variant only**. A nav-track route
     has no dead-reckoned alternative to toggle against (it IS the recorded
     route), so the nav-track variant must not expose this chip/caption at
     all.
4. **The dive variant needs a scene-merge step, not just reuse.** Checked
   where `Scene3d.scrubPath` actually gets built: `siteSeascapeProvider`
   never sets it (a site shows multiple dive paths as static lines, nothing
   to scrub along); only `spatial_geometry_service.dart` (the dive path)
   does. So the dive case requires a new step that combines the site's scene
   (terrain, markers, features) with the dive's path + `scrubPath` into one
   `Scene3d` - e.g. `Scene3d(layers: site.layers, markers: [...site.markers,
   ...diveMarkers], bounds: site.bounds, scrubPath: dive.scrubPath)`. Not a
   new low-level structure (`ScrubPath` already exists and the pane already
   rebuilds `Scene3d` instances for the LOD patch layer, see `displayScene` in
   `site_terrain_pane.dart`), but a real, previously unnamed step.
5. **`SiteTerrainPane` needs a second terrain-loading path, gated on
   `NavTrack.siteId`, not on "is this a nav-track."** `NavTrack` already has
   an optional `siteId` field that `navTrackSceneProvider` currently ignores
   entirely, always loading by anchor point instead. Correct behavior:
   - route **with** `siteId` -> normal site-based load, full markers /
     features / LOD, looks exactly like opening that site today.
   - route **without** `siteId` -> anchor-point load (today's
     `navTrackSceneProvider` behavior), terrain + path only, no markers, no
     features, no LOD. **Confirmed as acceptable**: this is an existing
     limitation (no site record to hang markers/features/LOD off), not a
     regression, so it is kept as-is and documented rather than solved.
   The dive case never needs this second path (a dive always has a site).
6. **`SpatialSitePage` and `NavTrackSeascapePage` become routers**, not pure
   wrappers: when the dive/route has a site, they render a thin
   `Scaffold`/`AppBar` wrapper around `SiteTerrainPane` with the matching
   `playbackContext`; when it does not (a dive with no site, or a route with
   no `siteId`), they fall back to their existing standalone implementation
   unchanged. Revised from the original plan to unconditionally delete that
   code: the standalone path is still the ONLY implementation for the
   siteless case (decision 5's "route without siteId" branch), so deleting
   it outright would have left that case with nothing to render. Kept, not
   removed; only renamed to `_DiveSeascapeStandalone` /
   `_NavTrackSeascapeStandalone`.
7. **Single PR covers all three** (dive, site, nav-track) - not phased, per
   explicit request on the issue to not defer the nav-track case - but
   implemented as separate, independently committed steps within that PR
   (naming/param plumbing, scene-merge step, `siteId` routing in the nav-track
   provider, wrapper migration), so partial progress survives even if a later
   step hits trouble.

## Open implementation questions (not yet decided)

- Exact shape of the dive and nav-track `playbackContext` variant types -
  nav-track's "additional properties specific to underwater routes" mentioned
  in the issue are not yet enumerated.
- Whether `siteSeascapeProvider` and the anchor-based loading path share a
  common internal provider, or stay as two separate code paths feeding the
  same pane.
- Doc comment on `SiteTerrainPane` needs to describe all resulting operating
  modes (site-only, site+dive, route with site, route without site).
