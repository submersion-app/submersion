# Surface GPS Interactive Map — Design

- **Date:** 2026-05-25
- **Status:** Approved (ready for implementation plan)
- **Area:** Dive log → dive detail page → Surface GPS section

## Problem

The Surface GPS section in the dive detail page currently shows entry/exit
coordinates as plain text rows plus an "Open in maps" button that launches an
external OpenStreetMap URL. It does not visualize the points, the coordinates
are not copyable, and it does not show the associated dive site.

We want the section to:

1. Show entry and exit coordinates as **interactive links** — tapping a
   coordinate focuses the map on that point, with a separate **copy icon** to
   copy the coordinate text.
2. Show an **embedded map** (like the sites map view) plotting the entry point,
   the exit point, and — when the dive is linked to a dive site — the dive
   site's own coordinates.
3. **Remove** the "Open in maps" button entirely.

## Existing code this builds on

- `_buildSurfaceGpsSection` in
  `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (the section
  being replaced). It already computes **drift** (distance + bearing between
  entry and exit) via `distanceMeters` / `initialBearingDegrees` /
  `formatBearing`, and shows it as the collapsed subtitle.
- `_buildHeaderSection` in the same file already renders a **faded,
  non-interactive `FlutterMap`** behind the dive stats, with entry (green,
  `Icons.south`, `0xFF34C759`), exit (orange, `Icons.north`, `0xFFFF9F0A`), and
  site (`Icons.scuba_diving`, `colorScheme.primary`) markers plus a dotted
  entry→exit polyline. The marker builder is `_mapPin`.
- Map plumbing already exists: `mapTileUrlProvider`, `mapTileMaxZoomProvider`,
  and `TileCacheService.instance` (offline tile caching).
- Data model: `Dive.entryLocation`, `Dive.exitLocation` (`GeoPoint?`), and
  `Dive.site` (`DiveSite?` with `location` `GeoPoint?`).
- Section visibility gate (unchanged): the section renders only when
  `entryLocation` or `exitLocation` is non-null
  (`dive_detail_page.dart` ~line 325).
- Existing tap-to-copy pattern (`Clipboard.setData` + SnackBar) in
  `site_detail_page.dart`, and `GeoPoint.toString()` formats at 6 decimals.

## Decisions (settled during brainstorming)

| Topic | Decision |
| ----- | -------- |
| Coordinate tap | Tapping a coordinate **focuses the map** on that point. Copying is a **separate copy icon**. |
| Layout | **Map on top**, coordinate rows below (collapsible card retained). |
| Map interactivity | **Inline live map** (pan/zoom + programmatic recenter) **plus a fullscreen expand**. |
| Marker style | **Color + icon** pins: Entry green ↓, Exit orange ↑, Site blue anchor. |
| Track line | **Keep** the dashed Entry→Exit polyline (surface drift). |
| Header vs new map | **Keep both.** Header stays a decorative faded map; the new section map is functional. |
| Architecture | **Shared `DiveLocationsMap` widget**, used by the inline map, the fullscreen page, **and** the (refactored) header map. |
| Site icon | **Anchor** (`Icons.anchor`) everywhere — replaces the header's `Icons.scuba_diving`. |

## Architecture

### New: `DiveLocationsMap` widget

`lib/features/dive_log/presentation/widgets/dive_locations_map.dart`

A `ConsumerWidget` that renders the map core from typed inputs. It is the single
source of truth for how dive locations are drawn.

```dart
DiveLocationsMap({
  GeoPoint? entry,
  GeoPoint? exit,
  GeoPoint? site,
  bool interactive = false,
  MapController? controller,
})
```

Responsibilities:

- Build the `FlutterMap` with `TileLayer` using `mapTileUrlProvider`,
  `mapTileMaxZoomProvider`, and `TileCacheService.instance` (same as the header
  today).
- `interactive` toggles `InteractionOptions` flags between
  `InteractiveFlag.none` (header / preview) and `InteractiveFlag.all`
  (inline + fullscreen).
- Marker layer for whichever of entry/exit/site are non-null (see Marker spec).
- `PolylineLayer` with the dotted entry→exit line **only when both** entry and
  exit are present (existing style: strokeWidth 3, `onSurface` alpha 0.7,
  `StrokePattern.dotted()`).
- Initial camera frames all present points using `CameraFit` (with padding);
  for a single point, center on it at a sensible zoom (~14).
- Include `MapAttribution`.
- Move `_mapPin` into this widget as the marker builder.

This widget contains **no clipboard, navigation, or row logic** — it only draws
a map.

### New: `SurfaceGpsSection` widget

`lib/features/dive_log/presentation/widgets/surface_gps_section.dart`

A `ConsumerStatefulWidget` that owns the section's interactive state. Replaces
the `_buildSurfaceGpsSection` method.

```dart
SurfaceGpsSection({ required Dive dive, String? sourceName })
```

Responsibilities:

- Hold a `MapController` (state).
- Render the existing `CollapsibleCardSection` (title
  `diveLog_detail_section_surfaceGps`, icon `Icons.my_location`,
  collapsed subtitle = drift / entryOnly / exitOnly as today), wired to
  `surfaceGpsSectionExpandedProvider` /
  `collapsibleSectionProvider.notifier.setSurfaceGpsExpanded`.
- Content: inline `DiveLocationsMap(interactive: true, controller: ...)` with an
  overlaid **expand** button, then the coordinate rows, then the drift row.
- A private `_GpsCoordinateRow` widget per point: colored dot + label +
  link-styled coordinate (tap → focus) + copy `IconButton`.
- Tap coordinate → `controller.move(LatLng(point), focusZoom)` where
  `focusZoom ≈ 16` (instant move for v1; animated pan is a future enhancement,
  see below).
- Copy icon → `Clipboard.setData(ClipboardData(text: point.toString()))` +
  `SnackBar` using the copied-confirmation string.
- Expand button → push `DiveLocationsMapPage` (see below).

### New: `DiveLocationsMapPage`

`lib/features/dive_log/presentation/pages/dive_locations_map_page.dart`

A fullscreen `Scaffold` + `AppBar` (title from a new l10n string) whose body is
`DiveLocationsMap(interactive: true)` filling the screen, given the same
entry/exit/site points. Opened via
`Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(...))` so it
covers the bottom navigation. Not deep-linkable (acceptable for a leaf map view).

### Changed: `dive_detail_page.dart`

- Replace the `_buildSurfaceGpsSection(...)` call (~line 338) with the
  `SurfaceGpsSection` widget.
- Delete `_buildSurfaceGpsSection`, `_openInMaps`, and `_mapPin`. Remove the
  `url_launcher` import if it is no longer used elsewhere in the file.
- Refactor `_buildHeaderSection`: replace its inline `FlutterMap` (the
  `Positioned.fill` map) with `DiveLocationsMap(interactive: false, ...)`,
  keeping the surrounding `Stack` chrome (gradient overlay, stat content, and
  the "View site" chip / `InkWell` navigation). Preserve current behavior of
  passing the **site marker only when there is no GPS** (pass `site:` only when
  `!hasGps`). The header's appearance is unchanged except the site glyph becomes
  the anchor.

## Marker spec

| Point | Color | Icon | Marker key |
| ----- | ----- | ---- | ---------- |
| Entry | `0xFF34C759` (green) | `Icons.south` | `gps-entry-marker` |
| Exit | `0xFFFF9F0A` (orange) | `Icons.north` | `gps-exit-marker` |
| Site | `colorScheme.primary` (blue) | `Icons.anchor` | `gps-site-marker` |

Entry/exit keys are unchanged from today so existing header tests keep passing.
The dotted polyline gets key `gps-track-line`.

## Coordinate formatting

- **Display** in rows: 5 decimals (`toStringAsFixed(5)`), unchanged from today.
- **Copied** text: `GeoPoint.toString()` (6 decimals), matching the dive-site
  copy behavior elsewhere in the app.
- **Drift**: distance via `units.formatDistance` (respects unit settings) and
  bearing via `formatBearing` — unchanged.

## Data flow

`diveProvider(id)` → `Dive` (already loaded by the page) → passed into
`SurfaceGpsSection` and `_buildHeaderSection`. No new providers or repository
changes. Interactions are local widget state (`MapController`, clipboard,
navigation).

## Edge cases

- **Site without coordinates** → no site marker, no site row.
- **Only entry or only exit** → that one marker + row; no track line; no drift
  row; collapsed subtitle uses the existing entryOnly / exitOnly strings.
- **No entry and no exit** → section not rendered (gate unchanged). Site-only
  dives still show their location via the header map.
- **Offline** → existing `TileCacheService` caching applies; no new handling.
- **MapController** is only used on user tap (after first build), so there is no
  controller-before-ready issue. Guard the fullscreen page against an
  all-null input even though the gate makes it unreachable.

## Localization additions

Add these keys (all locale ARB files):

- `diveLog_detail_surfaceGps_site` — the "Site" row label.
- `diveLog_detail_locationsMap_title` — the fullscreen page title.
- `diveLog_detail_coordinatesCopied` — the copy confirmation SnackBar text. (A
  dive-log-specific key rather than reusing `diveSites_detail_coordinatesCopied`,
  to keep feature ownership clean.)

The `diveLog_detail_openInMaps` string becomes unused; remove it if no other
references remain.

## Testing strategy (TDD)

- **`DiveLocationsMap`**: marker count for each combination (entry only;
  entry+exit shows the polyline; +site shows the site marker); site marker keyed
  `gps-site-marker`; preserves `gps-entry-marker` / `gps-exit-marker`.
- **`SurfaceGpsSection`**: renders Entry/Exit/Site rows when present; the copy
  icon writes the expected 6-decimal text (intercept the clipboard
  `SystemChannel`); tapping a coordinate moves the injected `MapController`;
  **"Open in maps" is absent** (regression); drift row appears only when both
  points exist.
- **`DiveLocationsMapPage`**: renders an interactive `DiveLocationsMap` with the
  expected markers.
- Re-run the existing dive-detail / header tests to confirm the header refactor
  is behavior-preserving (marker keys unchanged).

## Out of scope / future enhancements

- **Animated pan** on coordinate tap (would need a tween or the
  `flutter_map_animations` package). v1 uses an instant `controller.move`.
- Changing the header map's interactivity or the "View site" behavior.
- Any change to how entry/exit GPS data is imported or stored.

## File summary

**New**

- `lib/features/dive_log/presentation/widgets/dive_locations_map.dart`
- `lib/features/dive_log/presentation/widgets/surface_gps_section.dart`
- `lib/features/dive_log/presentation/pages/dive_locations_map_page.dart`

**Changed**

- `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- ARB localization files (new strings; remove unused `openInMaps`).
