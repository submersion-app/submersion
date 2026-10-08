# Media map mode

Date: 2026-09-25
Status: approved design, implementation plan pending
Branch: ericgriffin/media-map-mode-260133
Issue: #2329 (the PR body must say `Closes #2329`). Follow-up for migrating
the existing maps onto the shared camera helpers: #2330.

## Problem

The media library can be browsed as a grid, by dive, or on a timeline, but
never by place. Dives and dive sites each have a map mode; media does not,
even though the `media` table has carried its own `latitude` and `longitude`
since the EXIF, QuickTime, GoPro GPMF and gallery readers started filling
them on import.

The purpose of the new mode, fixed during brainstorming, is to relive dives
by place: every photo or video that can be located appears on the map as a
thumbnail, tapping leads to the viewer, and the map obeys the library's
active filter.

## Decisions

Taken during brainstorming and fixed for this spec.

- The map is a fourth `MediaLibraryViewMode`, `map`, rendered inline in the
  library body on every platform. It is not a pushed page, unlike the dive
  and site maps on phones.
- Placement order for an item: its own GPS fix, then its dive's entry fix,
  then its dive's site, then the site it is attached to directly. Both GPS
  sources must pass the existing `isPlausibleFix` check; a `(0, 0)` fix falls
  through.
- Markers and clusters are thumbnails, not icons.
- Tapping a cluster whose members can still be separated zooms in, as the
  dive map does. Tapping a cluster whose members all share one point, or any
  cluster at maximum zoom, opens a place strip: an in-map bottom overlay with
  a horizontal strip of the stacked thumbnails.
- Tapping a lone thumbnail opens the viewer directly.
- Shared map plumbing: only the stateless camera helpers are extracted (a
  `MapCameraAnimator` and a `boundsForPoints` function). The dive, site and
  dive-center maps keep their private copies; migrating them is follow-up
  issue #2330, not part of this PR.
- Map mode has no multi-select. Switching to it clears any active selection.
- The map shows how many in-scope items have no location.

## Architecture

### Data

**No schema change.** The map reads columns that already exist:
`media.latitude` / `media.longitude`, `dives.entry_latitude` /
`dives.entry_longitude` through `media.dive_id`, `dive_sites.latitude` /
`dive_sites.longitude` through `dives.site_id`, and the same site columns
again through `media.site_id`.

**`MediaMapPoint`** (`lib/features/media/domain/entities/media_map_point.dart`)
is one located item:

| Field | Type | Meaning |
| --- | --- | --- |
| `entry` | `MediaLibraryEntry` | The item plus dive number, dive date and site name, as the grid already carries |
| `point` | `LatLng` | The resolved position |
| `placement` | `MediaPlacement` | `ownGps`, `diveEntry`, `diveSite` or `attachedSite` |
| `placeLabel` | `String?` | For a site placement, the name of the site the item sits at (the dive's site, or the attached site when placement fell through to it). For a GPS placement, the nearest known context: the dive's site, else the attached site. Null when no site is known |

**`resolveMediaPlacement`**
(`lib/features/media/domain/services/media_placement_resolver.dart`, next to
`photo_gps_point_selector.dart`) is a pure function taking the four candidate
coordinate pairs and returning a `(LatLng, MediaPlacement)?`. It applies
`isPlausibleFix` from `lib/features/media/data/services/gps_fix.dart` to the
own and dive-entry fixes, so the map rejects a bad fix exactly as the
site-suggestion feature does. Site coordinates are trusted as stored. A null
result means the item is unlocated.

**`MediaLibraryRepository.getMapPoints({String? diverId, required
MediaLibraryFilter filter})`** returns `List<MediaMapPoint>`. It reuses
`_baseWhere` so the map has the same diver scoping and filter semantics as
the grid, then:

- joins `dives` through `media.dive_id`, `dive_sites` through `dives.site_id`,
  and a second aliased `dive_sites` through `media.site_id`. The paged query
  lacks that second join, which is why site-attached media (issue #959)
  needs this query rather than a large page;
- keeps only rows whose `file_type` is photo or video, so documents never
  reach the map;
- keeps only rows where at least one of the four coordinate pairs is present;
- orders by the library's date key ascending, then id, the timeline's order;
- maps each row through `resolveMediaPlacement` in Dart and drops the rows
  that resolve to null.

A companion `countInScope(diverId, filter)` runs `COUNT(*)` over the same
predicate and photo/video restriction. The unlocated count is that total
minus the resolved points.

**`watchMapChanges()`** on the same repository emits on writes to `media`,
`dives` or `dive_sites`, debounced on `MediaRepository.changeTickDebounce`
like `watchMediaChanges()`. The extra tables matter: editing a site's
coordinates or a dive's entry fix must move the photos placed by them.
`test/architecture/repository_tick_stream_test.dart` gets a case for each of
the two non-obvious tables.

**`mediaMapPointsProvider`**
(`lib/features/media/presentation/providers/media_map_providers.dart`) is an
`AsyncNotifierProvider.autoDispose` exposing a `MediaMapState` of `points`
and `unlocatedCount`. It watches the repository provider,
`currentDiverIdProvider` and `mediaLibraryFilterProvider`, and subscribes to
`watchMapChanges()` to reload, following `MediaLibraryNotifier`. Auto-dispose
is explicit because Riverpod 3 defaults it off, and leaving map mode should
release the point list.

### Presentation

**`MediaMapContent`**
(`lib/features/media/presentation/widgets/media_map_content.dart`) fills the
library body in map mode. Its tree mirrors the dive map:

- `TrackpadZoomMap` around a `FlutterMap` with `rotatableMapInteraction`, the
  world `CameraConstraint`, min zoom 2, max zoom 18, and an `onTap` that
  closes the place strip;
- `submersionTileLayer(ref)`;
- a `MarkerClusterLayerWidget` with `maxClusterRadius: 80`,
  `zoomToBoundsOnClick: false`, and a 56dp cluster size;
- `MapAttribution`;
- overlays: `MapCompassButton`, a fit-all button reusing the dive map's
  tooltip key, a small controls card carrying the unlocated label when the
  count is above zero, the empty-state card, and the place strip.

No heat map, seascape, bathymetry or built-in site layers.

**`MediaMapMarker`**
(`lib/features/media/presentation/widgets/media_map_marker.dart`) is a 56dp
rounded square: a 2dp surface-coloured border and a soft shadow around
`MediaItemView(item, thumbnail: true, targetSize: Size(112, 112), fit:
BoxFit.cover)`, with the grid's video badge for video rows. Each `Marker` is
keyed by media id so the thumbnail's resolved bytes survive the cluster
layer rebuilding on zoom.

**`MediaMapClusterMarker`** (same file) is the same tile with a count badge
in a corner. The representative item is the first favorite in the cluster,
otherwise the oldest. The cluster builder recovers the cluster's points from
its markers' media-id keys through a lookup map the widget keeps per build.

**Tapping.**

- A marker tap opens the viewer on that item with a one-item list.
- A cluster tap inspects the node's markers. If every marker's point equals
  the first's, or the camera zoom is within 0.01 of the maximum, it opens the
  place strip with the node's points. Otherwise it calls
  `animator.animateToBounds(node.bounds)`.
- A map background tap closes the strip.

**`MediaPlaceStrip`**
(`lib/features/media/presentation/widgets/media_place_strip.dart`) is an
in-map overlay aligned to the bottom centre, inside `SafeArea`, 16dp margin,
at most 640dp wide, 160dp tall. It shows the place label, or the
coordinates formatted through `UnitFormatter.formatCoordinates` so the
diver's coordinate format setting is respected, a localized item count, a
close button, and a horizontal list of 96dp thumbnails in date order, oldest
first, the same order the points arrive in.
Tapping a thumbnail pushes `MediaViewerPage(mediaList: stripItems,
initialMediaId: tapped, showGoToDive: true)`. The library view's private
`_openViewer` becomes a small shared helper so the grid and the map push the
viewer the same way.

It is an overlay rather than `showModalBottomSheet` so the map stays
pannable underneath and the panel behaves the same on a phone and on a wide
desktop window, matching how `MapInfoCard` sits on the other maps.

**Camera.** The widget fits all points when the first data arrives and again
after a filter change. It does this by listening to
`mediaLibraryFilterProvider` and setting a pending-fit flag that the next
data delivery consumes. Reloads caused by table writes do not refit, because
media-store uploads stamp rows constantly and a refit would yank the camera
mid-browse. The fit-all button refits on demand.

### Shared camera helpers

**`MapCameraAnimator`**
(`lib/features/maps/presentation/widgets/map_camera_animator.dart`) takes a
`MapController` and a `TickerProvider` and offers:

| Method | Behaviour carried over verbatim from the dive map |
| --- | --- |
| `animateTo(LatLng target)` | 500ms ease-in-out; target zoom is 12 when the current zoom is below 10, otherwise unchanged |
| `animateToBounds(LatLngBounds bounds)` | 800ms ease-in-out to `CameraFit.bounds` with 120dp padding and max zoom 14 |
| `fitAll(List<LatLng> points)` | one point moves to zoom 12; otherwise `fitCamera` on the bounds with 50dp padding |
| `dispose()` | stops and disposes any in-flight animation |

The defaults are the existing maps' values so a later migration is
behaviour-preserving. `dispose()` is the one improvement: the current copies
create an `AnimationController` per call and cannot cancel it if the widget
goes away mid-animation.

**`boundsForPoints(List<LatLng> points)`** joins `calculateZoomForBounds` in
`lib/features/maps/domain/map_utils.dart`: it skips out-of-range points, pads
by ten percent of the span, and clamps to the valid ranges, exactly as the
private `_calculateBounds` copies do.

## View mode and toolbar

- `MediaLibraryViewMode` gains `map`. `MediaLibraryViewModeNotifier` already
  persists by name and falls back to `grid` for an unknown name, so a
  downgrade is safe and no migration is needed.
- `MediaLibraryView` adds a `map` case that renders `MediaMapContent`.
- `MediaLibraryToolbar` wraps its row in a `LayoutBuilder`. When the row has
  room, the segmented button shows four segments, the new one with
  `Icons.map`. When it does not, the segmented button is replaced by one menu
  button showing the current mode's icon and listing all four modes, in the
  style of `ListViewModeToggle.menuItems`. The width threshold is measured
  during implementation at 320dp, not guessed here.
- In map mode the sort button stays hidden (it already is outside grid mode),
  the filter button and active filter chips stay, and the selection button
  is hidden.
- When the selected mode becomes `map` while `selection.isActive`, the
  toolbar calls `selection.exit()` before setting the mode.

## States

| State | Treatment |
| --- | --- |
| Loading | The grid's progress treatment |
| No located items | Centred card, like the dive map's: a title and a one-line hint that items are placed by their own GPS, their dive's fix, or their dive's site |
| Query error | A retry card that invalidates the provider |
| Unresolvable thumbnail | `MediaItemView`'s existing placeholder; no special path |
| Missing-files banner | Unchanged, above the map as above the grid |

## Localisation

New keys, in all eleven ARB files, feature-grouped in the non-English files
next to the existing `media_library_viewMode_*` keys:

- the map segment tooltip and menu label;
- the strip's item count, a CLDR plural with `one` and `other` categories
  and no literal digit in the `one` branch;
- the unlocated label, the same plural shape;
- the empty-state title and hint;
- the strip's close tooltip;
- semantics labels for a marker ("open media") and a cluster ("N items at
  place").

The fit-all tooltip reuses `diveLog_map_tooltip_fitAllSites`.

## Deliberately out of scope

- Heat map, 3D seascape, bathymetry and built-in site layers.
- Multi-select on the map.
- Remembering the camera position between visits.
- Panning the map to filter the grid.
- Migrating `DiveMapContent`, `SiteMapContent` and `DiveCenterMapContent`
  onto `MapCameraAnimator` and `boundsForPoints`. That is issue #2330.

## Testing

Tests are written first.

**Unit**

- `resolveMediaPlacement`: own fix wins; an implausible `(0, 0)` own fix
  falls through to the dive entry fix; then to the dive's site; then to the
  attached site; all absent returns null; an implausible dive entry fix also
  falls through.
- `boundsForPoints`: one point, many points, an out-of-range point skipped,
  clamping at the poles.
- `MapCameraAnimator`: `animateTo` lands the controller on the target;
  `fitAll` with one point moves to zoom 12; `dispose()` during an animation
  does not throw.

**Repository** (in-memory database, following the existing library
repository tests)

- `getMapPoints`: dive-linked rows scoped to the diver, unlinked and
  site-only rows global; signatures and documents excluded; one row per
  placement kind resolved to the expected point and label; a site-attached
  row with no dive found through the second join; ordering by date then id.
- `countInScope` agrees with the grid's notion of scope.
- `watchMapChanges` emits on a `dives` write and on a `dive_sites` write, in
  the architecture tick-stream suite.

**Widget**

- `MediaMapContent`, with `mediaMapPointsProvider` overridden and the
  media-store and serving-recorder overrides the tile test uses: the map
  renders; markers appear for the points; the empty card shows for no points;
  the unlocated label shows its count; a cluster of co-located points opens
  the strip on tap; a strip thumbnail pushes the viewer; a background tap
  closes the strip; zooming does not re-run thumbnail resolution for a marker
  that stays on screen.
- `MediaLibraryToolbar`: four segments at a wide width; the menu button at
  320dp; choosing `map` with a selection active exits selection.
- `MediaLibraryView`: the `map` mode renders `MediaMapContent`.
- `test/architecture/` passes after the new files land, since it scans all
  of `lib/`.

## Risks

- **Thumbnail churn on zoom.** The cluster plugin recomputes clusters on
  every zoom change. Media-id keys keep `MediaItemView` state alive when a
  marker persists, and the widget test above pins that. If the plugin
  recreates elements regardless, the mitigation is a small per-widget
  thumbnail cache, decided by measurement.
- **Memory on dense areas.** Thousands of decoded thumbnails while panning
  a dense region. `MediaItemView` bounds decode width by `cacheWidth` and the
  Flutter image cache evicts; profile before adding anything.
- **Toolbar width.** The threshold is measured, not estimated; the wrong
  threshold is a layout overflow on 320dp phones, which the toolbar test at
  320dp catches.
- **Viewer freeze.** The known media viewer analysis-cascade freeze applies
  to the viewer from any entry point and is not changed here.
