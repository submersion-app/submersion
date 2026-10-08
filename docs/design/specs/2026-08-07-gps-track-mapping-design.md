# GPS Track Mapping — Design

**Date:** 2026-08-07
**Status:** Approved for planning
**Schema:** main DB v144 (re-verify against `origin/main` before pushing), local cache DB +1

## Problem

Submersion records GPS surface tracks today (PR #497, schema v101) but never draws
them. `GpsLoggerPage` lists each recording session as a `ListTile` showing a fix
count and a duration — the geometry is stored and invisible. A diver who recorded
a boat day cannot see where the boat went, cannot tell which track belongs to
which dive, and cannot get the data back out of the app.

This design covers the full lifecycle: rendering tracks across four surfaces,
importing tracks from external sources, exporting them, and editing them.

## Goals

1. Draw recorded tracks on maps in four places: the GPS Log list, a track detail
   page, an all-tracks overview, and the dive detail Surface GPS section.
2. Convey more than raw geometry — colorize by speed or elapsed time, mark where
   dives happened, and let the user tap a point to read time and speed.
3. Accept tracks from GPX, FIT, KML, and CSV sources.
4. Export tracks as GPX and KML.
5. Trim and split tracks without risking data loss through sync.

## Non-goals

- Live "follow me" rendering during an active recording. The existing
  `GpsRecordingStrip` covers in-progress feedback.
- Route planning or track creation by drawing on a map.
- Elevation or barometric data. Surface tracks are 2D by definition here.

## Domain constraints

**Timestamps are wall-clock-as-UTC.** Track points are epoch *seconds*; track
`startTime`/`endTime` are *milliseconds*. Both are the recording device's local
wall clock reinterpreted as UTC — the same convention as `dives.entryTime`, which
is precisely why timestamp matching works with no conversion. Every formatter in
this feature renders UTC components directly and never calls `toLocal()`.
`gps_logger_page.dart:239-246` is the reference implementation.

**The track is the boat's path, not the diver's.** During a dive the recording
phone is on the surface. On a drift dive the in-window track is the boat following
bubbles; on a moored dive it is a near-stationary smudge. UI copy says "Surface
track" and never implies it is the diver's route.

**Units follow diver settings.** Per CLAUDE.md, anything displaying units respects
the active diver's preferences. `UnitFormatter` has no speed formatter today; this
adds one (knots / km·h⁻¹ / mph) derived from the existing distance-unit preference,
plus l10n keys for the legend, translated to all supported locales.

## Architecture

One pure-Dart geometry core, one caching layer, one shared render path, four thin
surfaces. Import, export, and editing attach at the repository, never at the view.

### Domain core

```
lib/features/gps_log/domain/
  track_geometry.dart      simplify() · windowTo() · boundsOf() · speedMpsBetween()
  track_colorization.dart  TrackColorMode · bucketize() → List<TrackRun>
```

`track_geometry.dart` implements Douglas–Peucker simplification, time-window
slicing, bounds computation with antimeridian normalization, and inter-fix speed.
It reuses `distanceMeters` from `core/utils/geo_math.dart` rather than adding a
second haversine implementation.

`track_colorization.dart` defines `TrackColorMode { uniform, speed, elapsed }` and
turns a point list into `TrackRun`s — contiguous spans sharing a quantized bucket
index. Eight buckets. Runs are the unit `PolylineLayer` consumes.

Both files are pure functions over `List<GpsTrackPoint>`: no Flutter imports, no
Drift, no I/O. They test as plain unit tests against hand-computed vectors.

### Why bucketed runs rather than a gradient

`Polyline` exposes `gradientColors` and `colorsStop`, which appears to solve
colorization directly. It does not. flutter_map 8.3 implements it as
`ui.Gradient.linear(offsets.first, offsets.last, ...)`
(`polyline_layer/painter.dart:274`) — a straight screen-space gradient between the
line's first and last points, not along arc length. A boat track that runs out to a
reef and returns has start ≈ end, collapsing the gradient toward degenerate.

Quantizing into buckets and emitting one `Polyline` per contiguous same-bucket run
produces roughly 50–200 polylines for a real track. This keeps `PolylineLayer`'s
viewport culling, border rendering, and — critically — hit-testing, which
tap-to-inspect depends on. Discrete bands also map one-to-one onto legend rows,
which reads better than a continuous ramp.

A hand-written `CustomPainter` layer (as `HeatMapLayer` already does with a
fragment shader) was considered and rejected: it would require reimplementing
projection, culling, and hit-testing for marginal fidelity gain.

### Level-of-detail cache

A new `gps_track_geometry_cache` table in `local_cache_database.dart`, keyed
`(trackId, lodLevel)`, storing simplified points plus an explicit status
(`ok` / `empty` / `unavailable`) so a legitimately empty track caches as `empty`
rather than being re-derived forever.

Three LOD levels, with Douglas–Peucker tolerance expressed in metres so the
simplification is independent of screen density:

| Level | Tolerance | Used by |
|---|---|---|
| `thumbnail` | 50 m | Row thumbnails, overview map unselected tracks |
| `overview` | 10 m | Overview map selected track, detail page zoomed out |
| `detail` | 2 m | Detail page at zoom ≥ 14, tap-to-inspect |

Tap-to-inspect always resolves against the full decoded point list, not the
simplified one, so the reported timestamp and speed are the real recorded values
rather than a survivor of decimation.

This deliberately does **not** go in the main synced database. Simplified geometry
is fully re-derivable from the stored blob, which is the test for the local cache
DB: putting it in `submersion.db` would cost a `currentSchemaVersion` bump, HLC
timestamps, tombstones, merge rules, and backup weight, for data any device
regenerates in milliseconds.

The local cache ladder has had parallel-branch version collisions before, so the
new table ships with a `beforeOpen` `CREATE TABLE IF NOT EXISTS` self-heal,
matching the bathymetry and reef tables.

Two tiers: the thumbnail LOD persists to disk so a cold-start list scroll is
instant; interactive zoom LODs memoize in-provider for the session only.

### Providers

```
lib/features/gps_log/presentation/providers/gps_track_map_providers.dart
  gpsTrackDetailProvider(trackId)          hydrated track (gunzip + decode)
  gpsTrackGeometryProvider(trackId, lod)   simplified via compute(), cached
  divesOnTrackProvider(trackId)            dives whose entryTime falls in window
  trackForDiveProvider(diveId)             the inverse, for Surface GPS
```

### Data flow

```
gps_tracks.points (blob)
   │  gunzip + jsonDecode        decodeTrackPoints() — exists
   ▼
List<GpsTrackPoint>              ~21,000 for a 6h day at 1Hz
   │  simplify(tolerance(lod))   Douglas–Peucker inside compute()
   ▼
List<GpsTrackPoint>              ~300 (thumbnail) → ~2,000 (zoomed in)
   │  bucketize(mode, 8)
   ▼
List<TrackRun>                   ~50–200 contiguous same-bucket spans
   ▼
PolylineLayer(polylines: [...])  one Polyline per run
```

Decode is the expensive step and happens once per track behind a
`FutureProvider.family`. Simplification and bucketization are cheap transforms
downstream. Switching colorization mode re-runs only `bucketize` — no re-decode,
no re-simplify — which is what makes the toggle feel instantaneous.

`compute()` is the established isolate pattern in this codebase (tide calculator,
EXIF extractor, sync service).

## Surfaces

### 1. Row thumbnail — `gps_track_thumbnail.dart`

An 88×64 `FlutterMap` with `InteractiveFlag.none`, so it never enters the gesture
arena against the parent `ListView`. Camera set once via `CameraFit.bounds` on the
track's bounding box, clamped to zoom ≤ 12 so tracks from the same trip resolve to
the same cached tiles rather than fetching fresh per row. Thumbnail LOD, uniform
color — quantized bands are illegible at this size.

Tiles come from the shared `map_tile_providers.dart` and the existing
`flutter_map_tile_caching` store. When tiles fail — offline on a boat, the normal
case for this feature — `errorTileCallback` drops to a shape-only `CustomPainter`
rendering the path on a tinted chip.

Each thumbnail sits in a `RepaintBoundary`, and `ListView.builder` limits
instantiation to visible rows.

**Known risk with a defined remedy.** Twenty visible rows means twenty live
`FlutterMap` instances, each carrying a controller, camera, and tile manager. The
implementation plan must include a scroll-performance check against a 50-track
list. If it janks, the remedy is pre-rendering each thumbnail once to PNG bytes
cached in the local cache DB, so rows render `Image.memory` and the list holds zero
map instances.

### 2. Track detail — `/gps-log/:id`

Full-bleed map wrapped in `TrackpadZoomMap`, with `MapCompassButton` and
`MapAttribution` to match every other map in the app.

- **Colorization toggle** in the app bar: uniform / speed / elapsed.
- **Legend** overlaid bottom-left, one row per bucket, speeds formatted through the
  new `UnitFormatter` speed method.
- **Dive markers** from `divesOnTrackProvider`, placed at each dive's entry
  position; tapping one navigates to that dive's detail page.
- **Start and end markers** distinct from dive markers.
- **Tap-to-inspect**: each `Polyline` run carries its index as `hitValue`;
  `PolylineLayer` hit-testing returns the run, then a nearest-point search within
  that run identifies the fix. An info card shows timestamp, speed, and accuracy.
- **Stats header**: distance, duration, average and max speed, fix count, and the
  number of dives on this track.
- **Overflow menu**: rename, export (GPX / KML, share or save), trim, split, delete.

### 3. Overview — `/gps-log/map`

`MapListScaffold(sectionKey: 'gps-tracks')`, the same shell as
`DiveActivityMapPage`, reached from a map icon in the GPS Log app bar with
`onBackPressed: () => context.go('/gps-log')`. Desktop gets the split pane, mobile
gets map plus info-card overlay, both inherited from the scaffold.

All tracks render at thumbnail LOD in a muted uniform color; the selected track
promotes to full colorization and the camera fits it.
`mapListSelectionProvider('gps-tracks')` binds the panes bidirectionally. A
date-range filter lives in the app bar — "every track ever" is the one query in
this feature that grows without bound.

**Route ordering.** `/gps-log/map` and `/gps-log/:id` both match two segments, so
the static `map` route must be declared before the parameterized route or it gets
swallowed. Nesting `:id` under `/gps-log` is safe here: the known double-page bug
arises when two matched segments render the *same* widget off shared notifier
state, which does not apply when list and detail are different widgets.

### 4. Dive detail — extending `SurfaceGpsSection`

`DiveLocationsMap` gains optional `trackRuns` and `trackBounds` parameters;
existing callers pass nothing and are unaffected.

`SurfaceGpsSection` watches `trackForDiveProvider(dive.id)`. When a track covers
the dive, it draws the window from entry − 15 min to exit + 15 min, auto-fitted,
with a "full track" chip that expands to the whole recording. A new row in the
coordinate list — `Surface track · 1,842 fixes` — pushes `/gps-log/:id`.

The section's existing lazy gate (`surface_gps_section.dart:105-109`, which builds
map content only when expanded) must be preserved: a collapsed section performs no
blob decode.

## Schema changes

### Main DB — v144

Main is at `currentSchemaVersion = 142`; the media integration branch holds a
contiguous 139–143. **Re-grep `origin/main` immediately before pushing** — this
ladder has had parallel-branch collisions.

`gps_tracks` gains five columns, all nullable or defaulted so existing rows migrate
without rewriting a blob:

| Column | Type | Purpose |
|---|---|---|
| `source` | TEXT, default `phone` | `phone` \| `gpx` \| `fit` \| `kml` \| `csv` |
| `sourceRef` | TEXT, nullable | Originating filename or device |
| `name` | TEXT, nullable | User-editable label |
| `trimStartTime` | INT, nullable | Wall-clock-as-UTC ms |
| `trimEndTime` | INT, nullable | Wall-clock-as-UTC ms |

All five thread through `sync_data_serializer.dart`. Defaulted columns need
hydration on the sync path so peers on older schemas do not push nulls back over
them. Any write that changes which points a row represents must restate `source`
explicitly rather than using `Value.absent()`.

Rendering code treats `source` as opaque — no view logic branches on provenance.

### Local cache DB — +1

`gps_track_geometry_cache`: `(trackId, lodLevel, points BLOB, status TEXT,
createdAt INT)`, primary key `(trackId, lodLevel)`, with a `beforeOpen`
`CREATE TABLE IF NOT EXISTS` self-heal.

## Import

```
lib/features/gps_log/data/services/track_import/
  track_import_service.dart    orchestrator
  gpx_track_parser.dart
  kml_track_parser.dart
  csv_track_parser.dart
lib/features/dive_import/data/services/fit/
  fit_track_extractor.dart
```

The orchestrator picks a file, sniffs the format, parses, dedupes against existing
tracks, inserts, and triggers the existing match sweep.

**Dedupe rule.** An incoming track is flagged as a probable duplicate when its
time span overlaps an existing track's span by more than 80% *and* the two share a
`source`. Flagged tracks appear in the import review step as "looks like a
duplicate of X" with skip / import-anyway / replace choices — the importer never
silently drops or merges. Tracks from different sources that overlap in time are
imported normally, since a phone recording and a handheld GPS recording of the same
boat day are legitimately distinct records.

- **GPX** parses `<trk><trkseg><trkpt lat lon><time>`. The `xml` package is already
  a dependency.
- **KML** parses `<gx:Track>` (`<when>` and `<gx:coord>` pairs).
- **CSV** requires a column-mapping step in the UI: latitude, longitude, timestamp
  column, and timestamp format. This is the heaviest of the four parsers for that
  reason.
- **FIT** extends the existing FIT pipeline. `fit_parser_service.dart:131-137`
  already walks every record reading `positionLat`/`positionLong` and discards all
  but the last; `fit_track_extractor.dart` collects that stream into a track.

**Per-point timestamps are required.** They are optional in all four formats, but a
track without them can neither be matched to dives nor colorized by speed or time.
Files lacking them are rejected with a clear message rather than threading a
nullable-timestamp path through the entire model.

**Timezone handling.** GPX `<time>` and KML `<when>` carry real UTC. The app's
convention is wall-clock-as-UTC. The existing `toWallClockEpochSeconds` converts
using `timestamp.toLocal()` — the *importing* device's zone — so a Cozumel track
imported in Seattle lands two hours off and silently matches nothing.

The importer therefore resolves the track's own offset and stores it in the
existing `tzOffsetMinutes` column, defaulting to the offset implied by any
overlapping dives, falling back to device-local, and editable in the import review
step. Conversion is `realUtc + tzOffset → wall-clock components → reinterpret as
UTC`.

## Export

```
lib/core/services/export/gpx/gpx_export_service.dart
```

`buildGpxDocument(track)` is a pure string builder with no I/O, so it is
golden-testable. `<gx:Track>` support is added to the existing
`kml_export_service.dart`.

Both convert back — wall-clock-as-UTC plus `tzOffsetMinutes` → real UTC — so an
export/re-import round trip is lossless.

Two entry points per format, honoring the established duality:

- `shareTrackGpx()` → `saveAndShareFile`, share sheet only
- `saveTrackGpxToFile()` → returns `String?`, null on user cancel

`file_export_utils.dart` currently has `saveImageToFile` and `savePdfToFile` but no
generic text equivalent, so this adds `saveTextToFile`. Without it the "Save to…"
menu item would quietly behave as share-only.

Exports respect trim bounds.

## Trim and split

**Trim is non-destructive.** It writes `trimStartTime` and `trimEndTime`; the
points blob is never rewritten. Trimming is therefore free, fully reversible via
"Reset trim", a tiny sync payload, and incapable of losing a fix.

Every consumer reads through a single `effectivePoints` accessor on
`GpsTrackRepository`, so rendering, statistics, export, and dive matching cannot
individually forget to respect the bounds.

**Split is destructive and ordered defensively.** At a chosen time *t*: build both
point lists, write both children (new ids, inheriting `source`, `tzOffsetMinutes`,
and a suffixed `name`), **then** `logDeletion` the parent. A crash between those
steps leaves two children and the parent — visible duplicates the user can delete.
The reverse order could leave nothing.

Both operations invalidate the affected `gps_track_geometry_cache` rows.

UI is a trim mode on the track detail map: a timeline scrubber with two draggable
handles for trim, one handle plus confirmation for split, with the affected portion
of the polyline dimmed live as handles move.

## Error handling

| Condition | Behavior |
|---|---|
| Undecodable blob | `AsyncError` → "track data unreadable" row offering delete. Never crashes the list. |
| Tile fetch failure | Shape-only `CustomPainter` fallback on thumbnails; standard empty tiles on full maps. |
| Import parse failure | Per-file error in a review list; partial success allowed, matching the bulk-import precedent. |
| Zero- or one-point track | Render a marker, not a degenerate polyline. `calculateZoomForBounds` already returns 12.0 for ≤ 1 point. |
| Antimeridian crossing | Longitudes normalized before bounds computation. A Pacific track spanning ±180° otherwise makes `LatLngBounds.fromPoints` wrap the globe. |
| Track with no overlapping dives | Detail page renders normally with an empty dive-marker set and a "no dives on this track" stat. |

## Testing

**Unit** — the core is pure functions, so these carry the weight:

- Douglas–Peucker against hand-computed vectors (compute expected output by hand,
  do not snapshot whatever the implementation happens to produce)
- Bucket assignment and contiguous-run merging
- Inter-fix speed math
- Time-window slicing, including windows extending past track bounds
- Timezone round trip: real UTC → wall-clock-as-UTC → real UTC
- Antimeridian bounds normalization

**Golden** — GPX and KML output strings for a fixed input track.

**Parser** — fixture files per format, including malformed input, empty tracks, and
timestamp-less files (which must be rejected, not silently accepted).

**Widget**

- Thumbnail offline fallback path
- Colorization toggle changes rendered runs
- Tap-to-inspect returns the correct fix
- `SurfaceGpsSection` with and without an associated track. Adding a provider
  dependency to a shared widget reliably breaks existing consumer tests unless they
  override it, so every existing `SurfaceGpsSection` test needs
  `trackForDiveProvider` overridden.

**Router** — `/gps-log/map` versus `/gps-log/:id` ordering. Assert route
*structure*, not `findMatch().fullPath`, which is identical either way and does not
distinguish the bug.

**Sync** — new columns round-trip; trim bounds survive a sync cycle; split produces
two children and one tombstone on the peer.

**Performance** — 50-track list scroll (gates the thumbnail remedy described
above); 21,000-point track render on the detail page.

## Build order

Phased so each phase ships independently, even though this is one spec.

1. **Schema and core** — the full v144 migration (all five `gps_tracks` columns at
   once), the local cache table, `track_geometry`, `track_colorization`, the
   `effectivePoints` accessor, and the providers. No UI. Fully unit-tested.
2. **Track detail page** — `/gps-log/:id`, colorization toggle, legend, dive
   markers, tap-to-inspect, stats. First user-visible value.
3. **Thumbnails and overview** — row thumbnails with offline fallback, the
   performance check, `/gps-log/map` with date filtering.
4. **Dive detail integration** — `DiveLocationsMap` track parameters,
   `SurfaceGpsSection` windowing, existing test overrides.
5. **Export** — GPX service, KML `<gx:Track>`, `saveTextToFile`, menu entries.
6. **Import** — four parsers, timezone resolution, dedupe, review step, CSV column
   mapping.
7. **Trim and split** — trim bounds UI, ordered split, scrubber, cache
   invalidation.

All five new columns land in a single v144 migration in phase 1, even though
`source` is not read until phase 6 and the trim bounds are not written until phase
7. One migration on a collision-prone ladder is materially safer than three, and it
keeps later phases free of schema work.

`effectivePoints` also lands in phase 1, returning the full point list until trim
bounds exist. Every consumer reads through it from the start, so phase 7 changes
one accessor rather than auditing every call site.

## Open questions

None. All decisions in this document are settled.
