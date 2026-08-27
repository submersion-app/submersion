# Built-in dive sites on the Sites map — Design

Date: 2026-06-28

## Summary

Add an opt-in toggle to the Sites map view that overlays markers for the
sites in the app's built-in (bundled) dive-site database alongside the user's
own sites. Built-in markers use a distinct, visually recessive style (hollow
grey map-pin) so the user's own sites remain the focus. Tapping a built-in
marker opens an info card with an "Add to my sites" action that imports the
site into the user's library. Built-in sites that the user already has are
hidden (deduped) so each real-world site appears once.

## Background

The bundled database lives at `assets/data/dive_sites.json` (3,612 sites,
3,256 with coordinates). It is loaded by `DiveSiteApiService` into
`ExternalDiveSite` objects and, today, is used only for search and import
suggestions — it is never drawn on the map.

The Sites map is rendered by two near-duplicate widgets, both of which are
live and must gain this feature:

- `SiteMapPage` (`lib/features/dive_sites/presentation/pages/site_map_page.dart`)
  — the full-page `/sites/map` route.
- `SiteMapContent`
  (`lib/features/dive_sites/presentation/widgets/site_map_content.dart`)
  — the master-detail map pane used by `site_list_page.dart`.

Both build the user's markers as a filled, colored circle (color by rating or
dive count) with a white `Icons.scuba_diving` glyph, clustered via
`flutter_map_marker_cluster`.

## Decisions (from brainstorming)

1. **Tap behavior:** built-in marker tap shows an info card with an
   "Add to my sites" action (discovery + import).
2. **Density:** built-in markers are always visible when the toggle is on
   (no zoom gating), but styled to be visually recessive.
3. **Marker style:** hollow teardrop map-pin in muted slate-grey, smaller than
   the user's markers; clearly distinct in both shape and color.
4. **Overlap:** built-in sites that match one of the user's sites are hidden
   (deduped) via the existing matcher's proximity rule.
5. **Approach:** shared providers + a shared marker-layer widget consumed by
   both map widgets (not a full unification of the two maps, and not inline
   duplication).

## Architecture

All new logic lives in small, independently testable units; the two map files
each gain only a conditional layer and a toggle button.

### Data layer

- Extend `DiveSiteApiService` with a method returning all bundled sites that
  have coordinates (reusing the existing `_loadBundledSites` cache so the JSON
  is parsed once). Sites without coordinates are excluded.
- New `builtInSitesProvider : FutureProvider<List<ExternalDiveSite>>` reading
  `diveSiteApiServiceProvider`. Static for the app lifetime; never invalidated.

### Toggle

- New `showBuiltInSitesProvider : StateProvider<bool>` defaulting to `false`,
  mirroring the in-memory convention of `heatMapSettingsProvider` (resets each
  launch; not persisted — out of scope).
- New `BuiltInSitesToggleButton` widget (modeled on `HeatMapToggleButton`)
  placed in the action row of `SiteMapPage` and the controls overlay of
  `SiteMapContent`.
- New l10n keys for the toggle tooltip/label, added across all locale ARB
  files.

### Dedup

- New `visibleBuiltInSitesProvider` that combines `builtInSitesProvider` with
  the user's sites (`sitesWithCountsProvider`) and suppresses any built-in
  site within the matcher's inner radius of an existing user site.
- Reuses `distanceMeters` (`core/utils/geo_math.dart`) and the
  `SiteMatchSensitivity.balanced` inner radius (150 m) so "same site" has one
  consistent definition with the import-time matcher's existing-site
  precedence rule.
- To keep 3,256 x N affordable, user sites are bucketed into a coarse lat/lng
  grid; each built-in is tested only against user sites in nearby buckets.
  Result is memoized and recomputed only when the user's site list changes.

### Rendering

- New shared `BuiltInSiteMarkerLayer` widget under
  `dive_sites/presentation/widgets/`. Both maps include it conditionally:
  `if (showBuiltIn) BuiltInSiteMarkerLayer(...)`.
- Internally a **separate** `MarkerClusterLayerWidget` from the user-sites
  cluster layer, so the two marker kinds never merge into one ambiguous
  cluster bubble.
- Placed **below** the user-sites layer in the `children:` list so the user's
  markers always draw on top.
- Marker: hollow teardrop map-pin, muted slate-grey outline (no fill), ~28px
  vs. the user's 40px. Built from the static deduped list and memoized, so
  marker widgets do not rebuild on pan/zoom; only the cheap selection
  highlight changes.
- Cluster bubble: muted grey, smaller and thinner than the user clusters
  (which use `colorScheme.secondary`), so a built-in cluster is visually
  distinct.

### Interaction

- Map selection currently tracks a single `String? selectedId` keyed to the
  user's sites. Widen it to a `MapSiteSelection { kind: own | builtIn, id }`
  (or equivalent) so a built-in selection does not collide with an own-site
  selection.
- Tapping a built-in pin selects it (kind `builtIn`) and shows an info card
  with name, country/region, and max depth, plus a primary "Add to my sites"
  action that:
  1. converts via the existing `ExternalDiveSite.toDiveSite(diverId:)`,
  2. saves through the normal site repository create path,
  3. on success: the new site appears as the user's colored marker, and the
     built-in pin disappears because the dedup now suppresses it — immediate
     feedback.

## Testing (TDD)

- **Dedup unit tests:** a built-in coincident with a user site is suppressed;
  a far-away built-in is kept; grid-bucketed results are identical to a naive
  cross-product.
- **Provider tests:** `builtInSitesProvider` excludes coordinate-less sites;
  `showBuiltInSitesProvider` defaults to `false`.
- **Widget tests:** the layer renders nothing when the toggle is off; renders
  grey pins when on; tapping a built-in pin yields a `builtIn`-kind selection
  (not an own-site selection); "Add to my sites" calls the repository create
  path and the marker flips kind.
- **Add-flow test:** after add, the previously-shown built-in is deduped out.

## Out of scope (YAGNI)

- Unifying `SiteMapPage` and `SiteMapContent` (worthwhile, but a separate
  refactor).
- Persisting the toggle across launches (matches the in-memory heat-map
  convention).
- Region/country filtering of built-in sites.
- Offline search improvements.

## Affected / new files

New:

- `builtInSitesProvider`, `showBuiltInSitesProvider`, `visibleBuiltInSitesProvider`
  (in `dive_sites/presentation/providers/`).
- `BuiltInSiteMarkerLayer` and `BuiltInSitesToggleButton` widgets.
- `MapSiteSelection` selection type (shared map-list selection).
- Dedup helper (grid bucketing) under `dive_sites/domain/` with unit tests.

Modified:

- `DiveSiteApiService` — add all-with-coordinates accessor.
- `site_map_page.dart`, `site_map_content.dart` — conditional layer + toggle
  button + widened selection handling.
- l10n ARB files — toggle strings.
