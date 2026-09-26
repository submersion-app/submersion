# Underwater Navigation Routes Design

**Date:** 2026-09-10
**Status:** Draft
**Issues:** #1195 (Seacraft ENC3 console log), #1445 (Suunto Nautic S `DiveRoute`)

---

## Overview

Two device families deliver a *measured* underwater route as relative
X/Y/Z samples, and the app currently has nowhere to keep it:

- **Seacraft ENC / ENC3 / ENC3-PRO** navigation consoles (DPV-mounted or
  universal mount). The console dead-reckons underwater from its speed log,
  compass, IMU and pressure sensor. Logs leave the device through the
  Seacraft Console Android app or the ENC3 Auxiliary Software (Windows) as
  `NNN.DAT.csv`. The CSV carries no latitude/longitude at all; the Seacraft
  app georeferences a route by letting the diver drag an "anchor point" on a
  map.
- **Suunto Nautic S / Ocean**. The Suunto app JSON export carries
  `DiveRoute`, about 2 900 X/Y/Z samples at 1 Hz relative to
  `DiveRouteOrigin` (a lat/lon fix). `suunto_dive_parser.dart` reads the
  origin only and drops the samples (#1445).

The 3D seascape (`SpatialSitePage`, and the site seascape that overlays
many dives) already renders a horizontal swim path, but that path is an
*estimate*: `DeadReckoningService` integrates the dive computer's compass
headings at a fixed 0.25 m/s and rubber-bands the result onto the exit fix.
Its `ReckonedPath` type is exactly the frame a measured route lives in
(east/north metres, depth, seconds).

This design adds underwater routes as a first-class entity with its own
area in the app, a way to georeference and drift-correct them, a terrain
check against bathymetry, an optional link to a dive that can be made
automatically by date and time, and, once linked, makes the dive's 3D
seascape draw the measured route instead of the estimate.

---

## Requirements

Agreed workflow for the Seacraft case:

1. The diver exports the CSV from the Seacraft app and imports it into
   Submersion. The import recognises the ENC format on its own; no format
   menu, no column mapping.
2. Routes live in their **own area** of the app, where a route can be
   viewed, aligned and managed whether or not a dive exists for it.
3. A route can be **linked to a dive**, automatically by date and time
   where the match is unambiguous, otherwise by hand. A linked route is
   drawn in that dive's 3D seascape as the route.
4. The route has no coordinates, so the diver sets its **start point** on
   the 2D map. Without a start point the route still renders in 3D (its own
   local frame) but cannot appear on a map.
5. Dead reckoning drifts. To compensate, the diver may also set an **end
   point**, either "same as start" or another map position. The route is
   then re-computed proportionally so it ends there.
6. A **slider** marks up to where, from the start, the route is trusted.
   When set, the part before the mark stays as recorded and only the
   remainder is stretched proportionally onto the end point.
7. Where 3D underwater map data (bathymetry) is available, use it to
   **verify and clean up** the route: a diver cannot be inside the
   seafloor or on land.
8. Other GPS tracks must stay untouched by this ENC-specific handling:
   a separate area and a clear distinction from the GPS logger.

Everything below is designed to meet these points; the Suunto route is the
same data shape and rides along on the same store.

### Decisions (2026-09-10)

Four points that were open in earlier drafts are now settled:

1. **Name.** The area and the dive detail section are called "Underwater
   Route" (German: "Unterwasser-Route"). Device-neutral, matches the term
   both Seacraft and Suunto use for this data, and avoids confusion with
   the GPS logger's "tracks". The code keeps the `nav_track` name
   throughout, since "route" collides with router vocabulary in the
   codebase (`go_router`, `NavTrackAlignPage` route paths).
2. **Dive entry/exit coordinates.** A route's start or end point never
   writes to `dives.entry_latitude/longitude` or the exit equivalents
   automatically, not even when those fields are empty. The route detail
   page and the dive detail section instead offer an explicit "Use as dive
   entry/exit" action. Reason: the console starts logging on submersion,
   not at the actual entry point, and the dive's GPS fields feed site
   matching and the surface-drift readout elsewhere in the app, so an
   implicit write would carry an unstated assumption into code that has no
   way to know it was made.
3. **KML export from the ENC3 Auxiliary Software.** Left for later. Phase 1
   is built entirely on the CSV path; the dive's or site's location already
   gives every route a first map position via the default anchor (the
   route's site pin, see Georeferencing below), so nothing in Phase 1
   depends on whether the Windows software's KML carries the origin fix.
   If that KML
   turns out to include it, a KML importer for routes becomes a small,
   independent addition later; see the deferred item in Open Questions.
4. **Comment on #1195.** Posted after the first commit lands on the
   branch, not before, so the comment can link to the actual branch and
   fixtures rather than describe work that does not exist on disk yet.

---

## Ground truth: the Seacraft ENC3 CSV

Three files from #1195 were analysed (005: 10 rows, manufacturer sample;
002: 163 rows, manufacturer bench test; 008: 1 160 rows, a real 55-minute
DPV dive on 22.8.2026, 1 093 m, 38 m max).

Header, 12 columns, exact:

```text
Date,Time,Pos3Dx,Pos3Dy,Pos3Dz,Course,Pitch,Roll,Distance,Speed,Temp,BattV
```

| Column | Meaning | Unit | Evidence |
| --- | --- | --- | --- |
| `Date` | local date, `d.M.yyyy`, no zero padding | | `22.8.2026`, `15.1.2025` |
| `Time` | local wall clock, `H:mm:ss` | | |
| `Pos3Dx` | **northing** relative to the log start | m | heading derived from consecutive x/y deltas matches `Course` with a mean absolute error of 4.6 degrees under x = north, y = east; 138 degrees under the swapped hypothesis |
| `Pos3Dy` | **easting** | m | same test |
| `Pos3Dz` | depth, positive down | m | 1.1 to 38.0 on the real dive |
| `Course` | compass heading | degrees, 0 to 360, magnetic | |
| `Pitch`, `Roll` | console attitude | degrees | roll -178 throughout the upside-down bench test |
| `Distance` | cumulative log distance | m | 0.13 to 1 093.41; the 2D path length from x/y is 1 050 m |
| `Speed` | current speed | m/min | delta distance equals speed x dt / 60 (ratio 0.98 over 1 087 pairs); the Seacraft app's chart axis reads "m/min" |
| `Temp` | water temperature | degrees C | 7.2 at 30 m, 23.9 at the surface (lake, August) |
| `BattV` | console battery | V | 3.84 to 3.90; negative values (-1 to -4, -101) are status codes, not voltages |

Properties that shape the parser:

- The frame is NED (x north, y east, z down), origin at the first sample.
  There is no absolute position anywhere in the file.
- Sampling is irregular: 2 s typical, gaps up to 123 s (stationary or
  auto-hold), duplicate timestamps occur, and x/y stay constant while the
  speed log reads 0 (no flow means no dead-reckoning advance).
- The real log starts at 1.7 m depth: the console auto-records on
  submersion, so its first sample is a little after the dive computer's.
- Times are the console's wall clock with no zone. They match the app's
  wall-clock-as-UTC convention directly, like `timesAreWallClock` in the GPS
  track importer, and must never go through `DateTime.parse` (which folds in
  the importing machine's offset).
- The bench test (002) reads 309 m "depth" at room temperature with zero
  distance and speed. Such a file must import without crashing and can be
  flagged, but the parser is not the place to reject it.

### A surface GPS fix inside the same file (011.DAT.csv)

A fourth file from the issue author (6.9.2026, 2 155 rows, 76 minutes,
43.5 m, 1 447 m, exported from the Seacraft Console Android app) shows what
the app draws as the yellow "GPS Points Route", and it is in the CSV after
all, in the same relative metre frame:

- 1 600 rows underwater, then a surface swim from 18:46 with depth 0 and
  the dead-reckoned position barely moving.
- At 18:52:26 the position **jumps 367 m in one 2-second step** (north
  -330.6 m, east +160.4 m) while `Distance` and `Speed` freeze at their
  last values. From then on the position wobbles within about 10 m for
  17 minutes, `Pitch` sits at a constant 73 degrees, and `Temp` climbs
  from 23.8 to 26.9 degrees: the console is out of the water, lying tilted,
  warming up.
- Every step after the jump is a multiple of 0.0721 m east and 0.4241 m
  north. Those are the float32 resolution of a longitude near 8 degrees and
  a latitude near 47 degrees, converted to metres. The post-jump positions
  are therefore GPS fixes stored as float32 lat/lon and expressed relative
  to the route origin; the underwater positions are smooth dead-reckoning
  metres.

Reading: when the console re-acquires GPS at the surface it re-calibrates
its position to the fix ("FIX position" in Seacraft's description), and the
export writes that corrected position into the same columns. The jump
vector is the difference between where dead reckoning believed the diver
was and where GPS says they were. It mixes two errors that the file cannot
separate: drift accumulated underwater, and a stale origin (a fix taken at
the car park, then a walk to the water with the speed log reading zero).
The 008 file has no jump at all (largest step 1.9 m), so the parser must
handle both shapes.

Consequences for the design: the parser classifies samples into segments
(underwater, surface dead reckoning, GPS-fixed, out of water), a jump is an
event rather than a route leg, the GPS-fixed position becomes an optional
end target for the drift correction, and the route ribbon never connects
across a jump. The console clock is GPS-disciplined according to the owner,
so the delta to the dive computer is small and constant and the offset
stepper suffices.

Suunto `DiveRoute` (from #1445, to be confirmed against the #1186
fixture): X/Y/Z metres relative to `DiveRouteOrigin`, 1 Hz, Z agrees with
the depth channel to 0.62 m median, closure error about 12 m over 425 m.
Axis convention unverified; apply the same heading-versus-delta check.

---

## Why not the existing stores

**GPS logger (`gps_tracks`).** Stores absolute lat/lon surface fixes with no
depth; its job is to stamp `dives.entry_*` / `exit_*` by time. A navigation
route is relative, carries depth and speed, and *needs* an anchor rather
than providing one. Georeferencing it with a guessed anchor and writing it
as a GPS track would fake accuracy and lose the depth, speed and attitude
channels. The two stores cooperate instead: a phone GPS track supplies the
entry fix, which becomes the route's suggested start point.

**Profile series (`dive_profile_series`).** The codec field table is
append-only and could carry north/east columns under a v2 table. But pitch,
roll, speed and battery describe the console, not the diver; every consumer
of `DiveProfilePoint` would grow position fields only one device writes; a
route without a dive could not exist at all; and the console would appear
as a switchable data source with its own depth curve, which collides with
the source semantics established in #1177 and #1451. Importing the
console's depth and temperature as an *additional* data source may still be
worthwhile later, but the route does not belong there.

**Media attachment.** A picture, not data; nothing can render or query it.

---

## Relationship to the GPS logger

The route module deliberately *mirrors the shape* of the GPS logger (own
area, own table, time-window matching to dives, non-destructive
corrections) without sharing its code or its data:

- Own module `lib/features/nav_track/`, own table `nav_tracks`, own
  repository, providers, pages and match service. `GpsTrackMatchService`,
  the GPS logger page, its overview map, its LOD cache and its trim/split
  logic never see a route. None of the GPS logger's tests change.
- Where both appear on one map (the dive detail map, the site map), the
  route is its own layer with its own style (depth-coloured gradient,
  thinner stroke, start and end glyphs) and its own legend entry, so a
  diver can tell a surface track from an underwater route at a glance. The
  route never feeds the "surface drift" readout.
- Cross-links are suggestions only, never writes into the other module:
  a GPS track covering the route's time pre-fills the start and end points
  (its position at the route's first and last timestamp via the pure
  `GpsTrackMatcher.positionAt`); the GPS logger's CSV import recognises an
  ENC file and hands it over instead of showing its column-mapping form.
- Building this inside `gps_log` instead was considered and rejected: every
  ENC-specific behaviour (anchor, end point, trust slider, terrain check,
  depth channel, 3D) would need `kind == route` branches through the GPS
  code and its tests, which is the opposite of keeping GPS tracks
  unaffected.

---

## Decision

A new feature module `lib/features/nav_track/` with one synced table
`nav_tracks`, source-specific parsers (Seacraft ENC CSV now, Suunto
`DiveRoute` next), a repository, a matcher and match service, providers,
a routes area (list and detail pages), an import review page, an alignment
page, a dive detail section, and a route seascape that reuses the dive
seascape's widgets. The dive's 3D spatial providers consume a linked route
through the existing `ReckonedPath` type, so the renderer does not change.

### Module layout

```text
lib/features/nav_track/
  domain/entities/nav_track.dart               # NavTrack, NavTrackPoint, NavTrackSource, NavTrackCorrection (copyWith)
  domain/nav_track_point_codec.dart            # gzipped JSON tuples, bounded inflate, caps
  domain/nav_track_stats.dart                  # pure: distance, max/avg speed, max depth from points
  domain/nav_track_segmenter.dart              # pure: classify samples (underwater/reckoned/GPS-fixed/out-of-water), find fix events
  domain/nav_track_matcher.dart                # pure: candidate dives for a route by time window
  domain/nav_track_corrector.dart              # pure: rotation + proportional drift correction with trust mark
  domain/nav_track_georef.dart                 # pure: local ENU <-> lat/lon around the anchor
  domain/nav_track_terrain_check.dart          # pure: route vs bathymetry grid (land, below seafloor)
  domain/nav_track_path_adapter.dart           # NavTrack -> ReckonedPath for the 3D scene
  data/repositories/nav_track_repository.dart  # CRUD, link/unlink, correction update, tombstones
  data/services/nav_track_match_service.dart   # sweep: link unlinked routes to dives, never overwrites
  data/services/parsers/parsed_nav_track.dart  # ParsedNavTrack, NavTrackParseException + reason enum
  data/services/parsers/seacraft_enc_signature.dart   # looksLikeSeacraftEnc(headers), shared by every detector
  data/services/parsers/seacraft_enc_csv_parser.dart
  data/services/nav_track_import_service.dart  # prepare()/commit(), dive candidates, duplicates
  application/nav_track_scene_providers.dart   # standalone route seascape (no dive needed)
  presentation/providers/nav_track_providers.dart
  presentation/pages/nav_track_list_page.dart  # the routes area: list + map/shape split pane
  presentation/pages/nav_track_detail_page.dart# one route: stats, map, link, align, 3D, delete
  presentation/pages/nav_track_import_review_page.dart
  presentation/pages/nav_track_align_page.dart # start, end, trust slider, rotation, terrain check
  presentation/pages/nav_track_seascape_page.dart     # 3D for a route on its own
  presentation/widgets/nav_track_section.dart  # dive detail section (linked routes, link, import)
  presentation/widgets/nav_track_polyline_layer.dart  # flutter_map layer, distinct from GpsTrackPolylineLayer
  presentation/widgets/nav_track_shape_thumbnail.dart # top-down path sketch
  presentation/widgets/nav_track_handoff_card.dart    # "ENC log recognised" + link proposal
  presentation/widgets/dive_link_picker.dart   # choose a dive for a route, sorted by time distance
  presentation/nav_track_parse_error_text.dart # reason -> localized text

test/features/nav_track/...                    # mirrors lib
test/fixtures/nav_tracks/seacraft_enc3_real.csv        # 008 from #1195, no GPS fix
test/fixtures/nav_tracks/seacraft_enc3_gps_fix.csv     # 011, surface fix + 367 m jump
test/fixtures/nav_tracks/seacraft_enc3_short.csv       # 005
test/fixtures/nav_tracks/seacraft_enc3_bench.csv       # 002
```

### Schema (migration 209, implemented)

```dart
/// Measured underwater routes from navigation consoles and IMU-equipped
/// computers (spec 2026-09-10-underwater-nav-track-design). One row per
/// recording; points live in a gzipped JSON blob like gps_tracks so sync
/// moves one HLC row per route. The blob is the recording as it came off
/// the device and is never rewritten; every correction below is a
/// non-destructive parameter applied on read.
@DataClassName('NavTrackRow')
class NavTracks extends Table {
  TextColumn get id => text()();

  /// The dive this route belongs to, or null while unlinked. SET NULL on
  /// dive deletion: the recording outlives the dive and shows as unlinked
  /// in the routes area, ready to be matched again.
  TextColumn get diveId =>
      text().nullable().references(Dives, #id, onDelete: KeyAction.setNull)();

  /// 'auto' when the match sweep linked it, 'manual' when the diver did.
  /// The sweep never touches a linked row of either kind; the flag exists
  /// so the UI can say how the link came about.
  TextColumn get linkMode => text().nullable()();

  /// The route the dive's 3D seascape draws when several are linked to
  /// the same dive (two devices on one dive). The first link sets it.
  BoolColumn get isPrimary => boolean().withDefault(const Constant(true))();

  /// The dive site chosen at import (or taken from the linked dive). Gives
  /// an unlinked route a map position to start from: the site pin is the
  /// default anchor until the diver corrects it.
  TextColumn get siteId => text().nullable().references(
        DiveSites, #id, onDelete: KeyAction.setNull)();

  /// 'seacraft_enc' | 'suunto_route'. Rendering never branches on it;
  /// only the caption and the parser registry do.
  TextColumn get source => text()();
  TextColumn get sourceRef => text().nullable()(); // originating file name
  TextColumn get deviceName => text().nullable()();

  /// User-editable label; defaults to the file name.
  TextColumn get name => text().nullable()();

  /// Optional link to the console or scooter in the equipment list.
  TextColumn get equipmentId => text().nullable().references(
        Equipment, #id, onDelete: KeyAction.setNull)();

  /// Wall-clock-as-UTC epoch milliseconds (dives.entryTime convention).
  IntColumn get startTime => integer()();
  IntColumn get endTime => integer()();
  IntColumn get tzOffsetMinutes => integer().withDefault(const Constant(0))();

  /// Seconds added to the device's clock to place it on the linked dive's
  /// timeline (same idea as dive_data_sources.time_offset_seconds).
  IntColumn get timeOffsetSeconds =>
      integer().withDefault(const Constant(0))();
  IntColumn get pointCount => integer()();

  /// Summary scalars for list rows and stats, so no blob decode is needed.
  RealColumn get totalDistance => real().nullable()(); // m, device log
  RealColumn get maxDepth => real().nullable()();      // m
  RealColumn get maxSpeed => real().nullable()();      // m/s (SI at rest)
  RealColumn get avgSpeed => real().nullable()();      // m/s

  // ---- Georeferencing and drift correction (requirements 4 to 6) ----

  /// Where the route's origin sits on the map. Null until the diver sets
  /// it (or accepts a suggestion); the route then has no 2D position.
  /// Suunto supplies it from DiveRouteOrigin.
  RealColumn get anchorLatitude => real().nullable()();
  RealColumn get anchorLongitude => real().nullable()();

  /// 'none' | 'same_as_start' | 'point' | 'gps_fix'. With 'point',
  /// endLatitude and endLongitude hold the target. 'same_as_start' follows
  /// the anchor when it moves, which a copied coordinate would not.
  /// 'gps_fix' targets the first GPS-fixed sample of the recording itself
  /// (relative metres, so it also follows the anchor) and is offered only
  /// when the file contains a surface fix.
  TextColumn get endMode => text().withDefault(const Constant('none'))();
  RealColumn get endLatitude => real().nullable()();
  RealColumn get endLongitude => real().nullable()();

  /// Trust mark: fraction of the route's cumulative distance, 0 to 1, up
  /// to which the recording is taken as correct. 0 (default) means the
  /// whole route is corrected proportionally; 1 disables the correction.
  RealColumn get trustFraction => real().withDefault(const Constant(0))();

  /// Clockwise rotation applied to the route (magnetic declination, mount
  /// misalignment). The Seacraft desktop software offers the same knob.
  RealColumn get headingOffsetDeg => real().withDefault(const Constant(0))();

  IntColumn get codecVersion => integer().withDefault(const Constant(1))();

  /// Gzipped JSON array of
  /// [wallClockEpochSeconds, north, east, depth, course, pitch, roll,
  ///  distance, speed, temp, battV]; null for channels a source lacks.
  BlobColumn get points => blob()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Plus `CREATE INDEX IF NOT EXISTS idx_nav_tracks_dive ON nav_tracks(dive_id)`
and `idx_nav_tracks_start ON nav_tracks(start_time)` for the matcher.

Implemented at schema version **209**, not 205 as this section originally
named: by the time this landed, 205 and 206 were claimed by open
condition-intelligence branches and 208 by the auto-tag-dive-computer-
imports branch (all visible as sibling worktrees in this repo), exactly
the collision the "open questions" section below anticipated. Migration
follows the v202/v203 idiom for a new synced table: `currentSchemaVersion`
207 -> 209, `NavTracks` in the `@DriftDatabase` table list, `209` appended
to `migrationVersions`, one idempotent `_assertNavTracksSchema()` (using
`Migrator.createTable`, itself `IF NOT EXISTS`) called from `onUpgrade`
(`if (from < 209)`) and again from the `beforeOpen` backstop so restores
and sync-adopts self-heal. `minimumCompatibleSchemaVersion` stays
unchanged; the table is additive. `nav_tracks` is also registered in
`SyncRepository.hlcTargets` (its own schema-driven completeness test
requires this the moment the column exists, independent of whether a
write path uses it yet).

Speed is stored in m/s and displayed through the existing
`AttributeDimension.speedMps` formatting (m/min or ft/min, #1096), so the
equipment DPV attribute and the route agree on units.

### Points codec

`nav_track_point_codec.dart` mirrors `track_point_codec.dart`: gzipped JSON
tuple array, `core/utils/bounded_inflate.dart` on the way in, a typed
`NavTrackCodecException`, and hard caps on both sides
(`kMaxNavTrackPointCount = 1 << 17`, 36 hours at 1 Hz;
`kMaxNavTrackBodyBytes = 32 MiB`). Encode refuses what decode would refuse.

Sizes, measured on the fixtures and extrapolated: the real Seacraft dive
compresses to roughly 20 KB, a 2 900-sample Suunto route to roughly 40 KB.
That is the answer to the volume concern in #1445: one row per route, in
the same order of magnitude as a `gps_tracks` row, not ten times the
profile.

### Entities

`NavTrack` carries the scalars above plus `List<NavTrackPoint> points`
(hydrated on demand; list rows omit them), a `NavTrackCorrection` value
object (anchor, end mode and point, trust fraction, heading offset) and
`copyWith`. `NavTrackPoint` is `timestamp` (wall-clock-as-UTC seconds),
`north`, `east`, `depth`, and nullable `course`, `pitch`, `roll`,
`distance`, `speed`, `temperature`, `batteryVolts`. `NavTrackSource` is an
enum with a `label` for captions.

---

## The routes area (requirement 2)

Displayed name "Underwater Route" throughout (Decision 1): the Tools list
entry, the dashboard quick action, the area's own title, and the dive
detail section all use it, so the same noun appears everywhere a diver
encounters this feature.

Routes `/nav-routes` and `/nav-routes/:id`, siblings of `/gps-log` in
`app_router.dart` (same reason the GPS track pages are siblings and not
children: pushing a route from the dive detail must not stack a list page
underneath). Entry points: the Tools list next to "GPS Logger", the
dashboard quick actions card next to the GPS logger action, and the dive
detail section.

**List page** (`NavTrackListPage`): the `MapListScaffold` split pane the GPS
logger uses. Each row shows name, date, device, distance, max depth,
duration, and a link chip ("Dive #412", "unlinked"). Unlinked routes sort
first. Actions: import file, "Match now" (runs the sweep), delete. The map
pane shows anchored routes; unanchored ones show their shape thumbnail in
the row instead.

**Detail page** (`NavTrackDetailPage`): summary rows (device, distance, max
and average speed, max depth, duration, battery start and end when
present), the link card (linked dive with a jump to it, or the auto-match
proposal with "Link", or "Choose dive"), the correction status ("start
set, end same as start, trusted to 540 m", "terrain: 0 conflicts"), the
inline map with the route when anchored, and buttons "Align on map", "Open
3D", plus an overflow menu (rename, adjust clock offset, reset correction,
unlink, replace file, delete).

**Route seascape** (`NavTrackSeascapePage`): the route's own 3D view, with
no dive required. `navTrackSceneProvider(trackId)` builds the scene with
`SpatialGeometryService.buildWithFrame(path, grid: ..., gridCenter: ...,
pathAnchor: ...)`, the same call the dive seascape makes: real terrain from
`bathymetryGridProvider(quantize(anchor))` when the route is anchored,
the synthesized seafloor with its honest caption when not. The body of
`SpatialSitePage` (viewport, scrub bar, chrome, captions) is extracted into
a widget that takes a `SpatialSceneResult`, so the dive seascape and the
route seascape share one implementation and diverge only in their provider.

---

## Linking routes to dives (requirement 3)

`NavTrackMatcher` is pure: for a route window `[startTime, endTime]` and a
list of dives it returns the dives whose window (`effectiveEntryTime` to
`exitTime`, or entry plus runtime when no exit is stored) overlaps the
route window extended by a 30-minute tolerance on both sides (the same
tolerance `GpsTrackMatcher` uses), ordered by overlap. Wall-clock-as-UTC
on both sides, so no zone arithmetic.

`NavTrackMatchService.sweep({limitToDiveIds, limitToTrackIds})`:

- considers only routes with `diveId == null`;
- links a route when exactly one dive matches, with `linkMode = 'auto'`;
- leaves ambiguous and unmatched routes alone and reports them, so the UI
  can show "2 routes need a manual choice";
- never re-links, never unlinks, never overwrites a manual link;
- is triggered after a route import (limited to that route), after a
  dive-computer download (next to the GPS sweep in
  `download_providers.dart:41`), after sync (`sync_providers.dart:1340`),
  and manually from the routes area.

Manual linking: the detail page's "Choose dive" opens `DiveLinkPicker`,
dives sorted by time distance to the route with the overlap candidates on
top; the dive detail section's "Link route" opens the mirror image, routes
sorted by time distance. Linking a second route to a dive keeps the first
as primary and asks which one the 3D seascape should draw.

Deleting a dive leaves its routes unlinked (`SET NULL`); the next sweep
will not re-link them to a dive that no longer exists, and they stay
visible in the routes area. Deleting a route never touches the dive.

---

## Import and format detection (requirement 1)

One pure signature function, used by every entry point:

```dart
/// True when [headers] are a Seacraft ENC log: date, time and the three
/// Pos3D columns present (case-insensitive, trimmed, BOM stripped). Extra
/// or reordered columns are fine; a later firmware may append some.
bool looksLikeSeacraftEnc(List<String> headers);
```

Entry points and what each does with a recognised file:

| Entry point | Today | With this design |
| --- | --- | --- |
| Universal import wizard, file picker (`UniversalImportNotifier._detectFormat`, `universal_import_providers.dart:119`) | `FormatDetector._detectCsv` scores dive-log apps; an ENC file ends as "generic CSV" or unsupported | `FormatDetector` runs `looksLikeSeacraftEnc` before the app scoring and returns `ImportFormat.navTrack` with `SourceApp.seacraftEnc`. The notifier does not advance to source confirmation for that format; the file selection step shows `NavTrackHandoffCard` ("Seacraft ENC navigation log recognised. This is an underwater route, not a dive log.") leading to `NavTrackImportReviewPage`. |
| Drag and drop, share sheet (`loadFileFromBytes`, `universal_import_providers.dart:224`) | same detection path | same hand-off; the drop overlay's snackbar names the format |
| Multi-file batch in the wizard | unsupported files get `ImportFileOutcomeStatus.unsupported` | ENC files get `needsIndividualImport` with `formatName` "Seacraft ENC log", the summary lists them, and each has an "Import as route" action |
| GPS logger, "Import track" (`gps_logger_page.dart:165`) | `guessCsvMapping` fails on the ENC header and the review page shows a column-mapping form | after `readCsvHeaders`, `looksLikeSeacraftEnc` short-circuits to the review page; GPX/KML/FIT/other CSV are untouched |
| Routes area, import button | n/a | picker limited to `csv`, straight to the review page |
| Dive detail, "Underwater Route" section, import button | n/a | same, with the dive pre-selected as a manual link |

`ImportFormat.navTrack` is `isSupported == false` for the dive pipeline on
purpose: the parser registry never receives it, so nothing in
`universal_import` needs to know how to turn it into dives. The universal
importer depends on the signature function only (a pure function with no
imports of its own), which keeps the dependency edge tiny.

Detection must not produce false positives on the CSVs the app already
reads (MacDive, Diving Log, Subsurface, SSI, Garmin, Shearwater, Submersion,
GPS logger CSVs): requiring all three `Pos3D` headers makes that a
non-issue, and the test suite pins it with every existing CSV fixture.

### Review page

`NavTrackImportReviewPage` shows source and device, start and end
(formatted with `UnitFormatter`), duration, distance, max depth, max speed
in the diver's units, the segment summary ("1 600 samples underwater, 5
min surface swim, GPS fix 367 m from the reckoned end" or "no GPS fix"),
the **link proposal**: the unique time-window match pre-selected ("Link to
dive #412, 22.8.2026 10:08"), a choice when several match, "leave
unlinked" always available, and the **dive site**: pre-filled from the
linked dive, otherwise a site picker (the existing site selector with
nearest-first ordering), so the route gets a first map position from the
site pin even without a dive. With a dive selected it also shows the clock
delta between the route's first sample and `dive.effectiveEntryTime` with
an offset stepper (default 0; the console clock is GPS-disciplined, so
the delta is the dive computer's own error and stays small and constant;
a small positive delta is normal because the console starts logging on
submersion), and a depth consistency line ("route depth vs computer depth:
median difference 0.4 m"; above 3 m the page suggests adjusting the offset
or doubting the match). Warnings: no movement recorded (distance and speed
zero throughout); a duplicate (same source, same window already stored:
offer replace). "Save" commits and opens the route's detail page, from
which alignment is one tap away.

### Parser contract (`seacraft_enc_csv_parser.dart`)

- Split with the shared RFC-4180 `CsvParser` from `universal_import`
  (quotes, CRLF, BOM), never on bare commas.
- Column lookup by header name; `date`, `time`, `pos3dx`, `pos3dy`,
  `pos3dz` required, every other channel optional.
- `Date` parsed as `d.M.yyyy`, `Time` as `H:mm:ss`, combined with
  `DateTime.utc(...)` so the value is the console's wall clock reinterpreted
  as UTC on every machine.
- Numbers via `double.tryParse` after trim. A cell that fails to parse in a
  required column throws with the row number; in an optional column it
  becomes null.
- `BattV < 0` becomes null (status code). `Course` outside 0 to 360
  becomes null. Depth below -1 m is rejected, small negatives clamp to 0.
- Timestamps must be non-decreasing; equal stamps are kept (the console
  writes them); a step backwards throws.
- Fewer than two rows throws `tooShort`; more than the cap throws
  `tooLarge`; unreadable CSV throws `unreadable`. All through
  `NavTrackParseException(message, reason)` with an English message for the
  log and a `NavTrackParseReason` the UI localises, mirroring
  `TrackParseException`.
- No casts on external data anywhere: every value goes through `tryParse`,
  every list access is guarded, every optional channel is nullable, and
  `CsvParseException` is caught and re-thrown as the typed exception.

---

### Segments and GPS fixes

`NavTrackSegmenter.classify(points)` is a pure function that runs on read
(no schema, no rewrite) and tags every sample:

| Kind | Rule |
| --- | --- |
| `underwater` | depth above 0.3 m |
| `surfaceReckoned` | depth at or below 0.3 m, position advancing smoothly |
| `gpsFixed` | every sample from a **fix event** on, until depth rises above 0.3 m again |
| `outOfWater` | inside a `gpsFixed` run once `Distance` has frozen and `Temp` drifts monotonically away from the last underwater reading for more than a minute; informational only |

A **fix event** is a step of more than 50 m between consecutive samples
that are at most 5 s apart, at depth 0.3 m or shallower, with `Speed`
below 60 m/min (no scooter covers 50 m in 5 s). The 367 m step in 011
qualifies; nothing in 008 does. The step's vector and both endpoints are
kept as `NavTrackFixEvent`s on the parsed route. A second qualifying step
inside a `gpsFixed` run is GPS scatter, not a new event, and is folded into
the run.

What each consumer does with the tags:

- The 3D ribbon and the 2D route line are built from `underwater` and
  `surfaceReckoned` samples only, in recording order, and never connect
  across a fix event.
- `gpsFixed` samples are drawn on the 2D map as small yellow dots with the
  fix vector as a dashed arrow from the reckoned end, the same visual
  vocabulary as the Seacraft app, and are omitted from 3D.
- Statistics (distance, duration, average speed) stop at the last
  `underwater` or `surfaceReckoned` sample, which is also where the
  device's own `Distance` freezes.
- The review page states what it found: "surface GPS fix 5 min after
  surfacing, 367 m from the reckoned position" or "no GPS fix in this
  recording".

---

## Georeferencing and drift correction (requirements 4 to 6)

### The corrector

`NavTrackCorrector.apply(points, correction)` is a pure function from the
raw recording to corrected local east/north/depth metres, and it is the
single place the 3D adapter, the 2D layer and the terrain check read from:

1. **Rotate** every raw (north, east) by `headingOffsetDeg` about the
   origin. This corrects a compass bias (declination, mount angle) without
   distorting the shape.
2. **Cumulative distance** `s_i` per point: the device's own `distance`
   channel when present and monotone, else the 2D path length. Distance
   rather than time, because a scooter's dead-reckoning error grows with
   distance travelled (speed-log scale, compass bias), and a route that
   sits still for two minutes should not accumulate correction meanwhile.
3. **End target** in the anchor's frame: `none` means no correction;
   `same_as_start` means (0, 0); `point` means
   `enuOffsetMeters(anchor, endPoint)` from `core/utils/geo_math.dart`;
   `gps_fix` means the first `gpsFixed` sample's own (north, east), which
   makes the reckoned route end where the console's GPS said the diver
   surfaced. That last mode assumes the origin fix was good; when it was
   stale, the diver sees the whole route sit off the shore and moves the
   anchor instead, which is exactly the case the manual start point exists
   for.
4. **Proportional correction with the trust mark.** With residual
   `r = target - p_last` and `s_trust = trustFraction * s_last`:

   ```text
   p_i' = p_i                                          for s_i <= s_trust
   p_i' = p_i + r * (s_i - s_trust) / (s_last - s_trust) for s_i >  s_trust
   ```

   `trustFraction = 0` is the classic rubber band over the whole route
   (the same distribution `DeadReckoningService._rubberBand` applies to the
   estimate, only over distance instead of time); `trustFraction = 1` or a
   zero-length remainder leaves the route untouched.
5. Depth and time pass through unchanged. Raw points are never rewritten.

A second correction mode (rotate and scale the remainder about the trust
point so the shape survives intact, which suits a pure compass or speed
bias better than a translation) is cheap to add later behind the same
value object; the proportional mode is what the workflow asks for and is
the default.

### Georeferencing

`NavTrackGeoref` converts corrected local metres to lat/lon around the
anchor with `metersPerDegreeLatitude` and `metersPerDegreeLongitude(lat)`
(both in `geo_math.dart`) and back. It is used by the 2D layer, the terrain
check and the KML export.

The default anchor is the route's site pin (`siteId`, chosen at import or
inherited from the linked dive), so a freshly imported route already sits
on the right stretch of shore before any correction. Suggested start and
end points beyond that, in this order, each only offered, never applied
silently:

1. The linked dive's `entryLocation` / `exitLocation` (Shearwater Swift fix
   or a GPS-logger stamp).
2. A GPS track covering the route's time: `GpsTrackMatcher.positionAt(
   points, routeStartSeconds)` and the same at the route end.
3. For the end only: the recording's own surface GPS fix (`gps_fix`), when
   the file has one.

An unlinked route without a site has only suggestion 2 and the map's
current centre.

### The alignment page

`NavTrackAlignPage` is a full-screen flutter_map with:

- The corrected route as `NavTrackPolylineLayer` (depth-coloured), start
  and end glyphs, and the trust point marked on the route.
- **Start point**: the Seacraft idiom, a fixed crosshair over a pannable
  map with a "Set start here" button, plus a draggable marker for fine
  moves. Suggestion chips: "From dive entry", "From GPS track", "From site".
- **End point**: a control with none / same as start / place on map / from
  the recording's GPS fix (the last only when a fix event exists), the map
  option with the same crosshair flow and "From dive exit" / "From GPS
  track" chips. "Same as start" is proposed when the raw end lies within
  50 m of the origin, the shape of most shore dives on a scooter. The
  GPS-fixed samples are drawn as yellow dots so the diver can judge the fix
  against the shoreline before trusting it.
- **Trust slider** along the bottom, mapped to cumulative distance, with a
  live readout ("trusted up to 540 m, 23 min") and the remainder re-drawn
  as the thumb moves.
- **Rotation** stepper in degrees (0.5 steps) for `headingOffsetDeg`.
- The existing `DepthOverlayToggleButton` and `BathymetryDepthOverlayLayer`
  (`location: anchor`) so the seafloor ramp and contours sit under the
  route while aligning. These widgets already serve the site map and need
  no change.
- The **terrain check** readout (next section), updated as the diver
  moves anything.
- "Open 3D" and "Save". Save writes the correction columns through the
  repository (one HLC row); Cancel discards.

Every edit is reversible because the blob is never touched; "Reset
correction" restores the raw recording at the anchor.

---

## Terrain verification and cleanup (requirement 7)

`NavTrackTerrainCheck.run(correctedPoints, anchor, grid)` is pure and uses
the bathymetry the app already fetches: `bathymetryGridProvider(
BathymetryRepository.quantize(anchor))` yields a `BathymetryGrid`
(8 000 m span, `BathymetryResolver.defaultSpanMeters`, depths positive
down, negative for land, null for nodata) from swissBATHY3D, NOAA DEM,
EMODnet, GMRT or ETOPO depending on where the anchor is. Per point:

1. lat/lon via `NavTrackGeoref`;
2. seafloor depth via `bilinearInterpolateDepth(grid, lat, lon)`
   (`bathymetry/domain/bilinear_depth_interpolation.dart`), which returns
   null outside the grid or on nodata;
3. classify: `onLand` when the seafloor is at or above the waterline;
   `belowSeafloor` when the route depth exceeds the seafloor depth by more
   than a tolerance; `unknown` when the sample is null; else `ok`.

The tolerance follows the grid: `max(2 m, 0.15 * resolutionMeters)`. On
swissBATHY3D (metre-scale) and NOAA DEMs the below-seafloor test is
meaningful; on EMODnet (115 m) and ETOPO (450 m) only the on-land test is,
and the readout says so ("coarse bathymetry: only land conflicts checked").
The check reads one bilinear sample per point and runs on the UI isolate
for routes up to a few thousand points, debounced while dragging.

What the diver sees:

- A summary line: "0 points on land, 12 of 1 160 below the seafloor (max
  1.8 m), 30 unknown" with the grid's source and resolution.
- Conflicting points highlighted on the map (red dots on the route) so the
  anchor, end point or rotation can be adjusted until they clear. On the
  real dive from #1195 the route was on land because the anchor was on
  land; this check turns that from a surprise into a red count.
- In the 3D view the same route is draped over the same terrain, so a
  route inside the seafloor is visible there too.

Cleanup means correcting the *parameters*, never the *recording*:

- Manual, in Phase 1: the readout guides the diver's changes.
- **Auto-fit**, Phase 2: a grid search over anchor translation (plus or
  minus 50 m in 2 m steps) and rotation (plus or minus 15 degrees in 1
  degree steps) minimising `10 * onLand + sum(penetration metres)`, run
  in a `compute()` isolate, offered only when the grid resolution is 10 m
  or better, and always proposed with a preview rather than applied. With
  an end point set, the search keeps the rubber band engaged so the
  proposal respects the diver's end constraint.
- A second, terrain-independent check lives on the review page: route
  depth against the linked dive's depth profile at the same instants,
  which catches a wrong clock offset or a route linked to the wrong dive.

---

## 3D integration on the dive

`spatialReckonedPathProvider` (`dive_3d/application/spatial_providers.dart:28`)
gains one branch ahead of the dead-reckoning call:

```dart
final route = await ref.watch(primaryNavTrackForDiveProvider(diveId).future);
if (route != null && route.points.length >= 2) {
  return NavTrackPathAdapter.toReckonedPath(route);
}
```

`primaryNavTrackForDiveProvider` reads the linked route with
`isPrimary` and invalidates on `watchChanges()`, so linking, unlinking or
re-aligning a route swaps the dive's 3D path immediately. Unlinked routes
never reach a dive's scene.

`NavTrackPathAdapter` keeps the `underwater` and `surfaceReckoned`
samples (a route ribbon must never span a fix event), runs
`NavTrackCorrector.apply`, re-bases `timeSeconds` to the route start (the
scrub bar normalises by `durationSeconds`), and computes the extents. The seascape's own
rubber-banding onto the exit fix is not applied: the diver's correction
already is the rubber band, under their control. When both a route end and
an exit fix exist, the closure error in metres is exposed as a diagnostic
in the section, not silently absorbed.

`ReckonedPath.reconstructed` (a bool) becomes
`PathProvenance { measured, deadReckoned, straightLine }` with a
`reconstructed` getter kept for the existing call sites, plus an optional
`sourceLabel`. `SpatialSitePage` (`spatial_site_page.dart:316`) replaces the
always-true "Estimated path (dead reckoning)" chip with a
provenance-dependent one: "Recorded route (Seacraft ENC3)" for measured
routes, with "drift-corrected" appended when an end point is set.

`siteSeascapeProvider` already calls `spatialReckonedPathProvider` per dive
and anchors each path with `enuOffsetMeters(center, dive.entryLocation)`;
with a linked route the anchor is the route's own start point instead, so
the site seascape places the measured route where the diver put it.

`spatialGeometryProvider` moves scenes above 4 000 points into a
`compute()` isolate; a 1 Hz Suunto route crosses that line, which is fine
since the input is already a plain record.

---

## 2D map integration

`NavTrackPolylineLayer` builds its own `PolylineLayer` from the corrected,
georeferenced points, coloured by depth with the seascape's shallow-to-deep
ramp, thinner than the GPS stroke, with start (green) and end (red) glyphs
matching the 3D pins. It is mounted in the routes area, in
`DiveLocationsMap` beside `GpsTrackPolylineLayer` for linked routes (both
can show at once; the legend distinguishes them), and in the site map
behind a toggle. The layer renders nothing while the route has no anchor;
the pages then say "Set the start point to see the route on the map".

---

## Dive detail section

`DiveDetailSectionId.navTrack` ("Underwater Route", `Icons.route`) is
declared after `surfaceGps` and registered in `dive_detail_sections.dart`
(display name, description, icon, l10n keys, JSON id) and in
`dive_detail_page.dart` next to `_surfaceGpsCard`. It is a
`CollapsibleCardSection` like `SurfaceGpsSection`, with its own expanded
flag in `dive_detail_ui_providers.dart`.

Empty state: "No route linked" with two buttons, "Link route" (the picker
over unlinked routes, nearest in time first; hidden when none exist) and
"Import file". Populated state: one row per linked route (primary first)
with device, distance, max speed, max depth, the correction status, a
shape thumbnail, and buttons "Open route" (detail page), "Align on map" and
"Open 3D seascape"; an overflow menu with unlink and "make primary".

When the route carries a start or end point and the dive's own
`entryLocation` / `exitLocation` is empty, the section additionally shows
"Use as dive entry/exit" (Decision 2): an explicit, one-shot action, never
run automatically. Accepting it writes through the ordinary dive-edit path
so it participates in sync and undo like any manual coordinate edit; it
never overwrites a coordinate the dive already has.

---

## Sync, backup, reset

- Register `nav_tracks` in `sync_data_serializer.dart` exactly as
  `gpsTracks` is (export with the blob as base64, import upsert, delete
  and tombstone handling, table lookup, entity list) and in
  `sync_service.dart` (the record list near line 1312 and the per-entity
  flag map near line 2223). Deletes go through `SyncRepository` tombstones
  so a route deleted on one device stays deleted. Link, unlink and
  correction edits update the same row (new HLC), so an alignment done on
  the phone shows on the desktop.
- A dive deleted on one device arrives as a tombstone on the other; the
  route's `diveId` must be cleared there too (the `SET NULL` cascade fires
  locally when the dive row is removed; verify the sync delete path deletes
  the row rather than soft-marking it, else clear the link explicitly).
- Verify how a peer on an older build treats an unknown entity type from a
  newer peer before shipping; unknown types should be skipped, not fail the
  sync.
- File-based backup copies the whole database; nothing extra. Confirm the
  database reset path enumerates `allTables` rather than a hand-written
  list.

---

## Phases

**Before PR 1:** first commit on `feat/nav-track-seacraft-enc` with this
spec and the four CSV fixtures under `test/fixtures/nav_tracks/`, then the
comment on #1195 (Decision 4), linking the branch and attaching
011.DAT.csv so the maintainer sees the GPS-fix jump case before any code
review starts.

**PR 1, routes exist and reach the dive:** schema and codec; parser and
signature; detection hand-off at every entry point; review page with the
link proposal; matcher and match service with its three triggers; routes
area (list, detail, standalone 3D via the extracted seascape body); dive
detail section with link, unlink and import; 3D integration on the dive;
sync registration; l10n in all 11 locales. Routes render in their own
frame; the seascape uses the site pin or the dive's entry fix as the
terrain centre as it does today.

**PR 2, alignment:** alignment page with start, end, trust slider,
rotation, depth overlay and terrain check; 2D layer on the routes area,
the dive detail map and the site map.

**PR 3, Suunto (#1445):** in `suunto_dive_parser.dart`, where
`DiveRouteOrigin` is read today, emit a `ParsedNavTrack` with
`source = suunto_route`, the origin as anchor and the 1 Hz samples, linked
to the dive being imported; the Suunto cloud adapter and the JSON file
importer both call it. Verify the axis convention against the #1186
fixture with the heading check. No dive-computer download path can ever
supply this (the watch stores raw 10 Hz IMU only), so the JSON stays the
only source.

**Later, separate PRs:** auto-fit against bathymetry; clock alignment by
depth correlation (minimise the RMS depth difference against the linked
dive's primary profile over offsets in [-30 min, +30 min] and propose
`timeOffsetSeconds` with a confidence figure); KML export of the corrected,
georeferenced route via `kml_export_service.dart` (Seacraft names Google
Earth as a target) and GPX with depth in the elevation field; statistics
per linked equipment item ("km on the scooter"); the rotate-and-scale
correction mode; the console as an additional data source (only if divers
ask).

---

## Testing

- Signature and detection: the ENC header in every casing, with BOM, CRLF,
  appended columns; no false positive on any existing CSV fixture under
  `test/fixtures/universal_import/` and `test/fixtures/gps_tracks/`;
  `FormatDetector` returns `navTrack`; the wizard stays on file selection
  with the hand-off card; the GPS logger redirects instead of showing the
  mapping form; batch imports list the file as needing individual import.
- Parser: the four fixtures; assertions on row count, NED mapping (the
  heading derived from the first non-zero delta agrees with `Course`),
  monotone distance, non-negative speed, `BattV` sentinel to null,
  `d.M.yyyy` parsing incl. single-digit day and month, midnight rollover,
  malformed rows with the row number in the message, header-only file,
  empty file, wrong header.
- Segmenter: 011 yields exactly one fix event at 18:52:26 with the 367 m
  vector, 1 600 underwater samples, a `surfaceReckoned` run before the
  event and a `gpsFixed` run after it; the 25 m scatter step inside the
  run is not a second event; 008 yields no event; a synthetic 60 m step at
  40 m depth is not an event (a corrupt sample, flagged, not a fix); the
  ribbon adapter drops everything from the event on; statistics stop at
  the last reckoned sample.
- Matcher and sweep: unique overlap links with `linkMode = 'auto'`; two
  candidates leave the route unlinked and reported; none leaves it
  unlinked; tolerance edges; a manual link survives every sweep; a sweep is
  idempotent; deleting a dive unlinks; `limitToDiveIds` scopes the sweep.
- Corrector: identity with `endMode = none`; whole-route rubber band at
  trust 0 lands exactly on the target; prefix bit-identical when trust is
  set; `same_as_start` closes the loop; trust 1 leaves the route untouched;
  rotation preserves distances; device distance preferred over path length
  only when monotone.
- Georeferencing: round trip lat/lon to ENU to lat/lon within 1 cm at
  Swiss and equatorial latitudes.
- Terrain check with synthetic grids: land, nodata, outside the grid, a
  point just inside the tolerance, a point below the seafloor; tolerance
  scaling with resolution; the coarse-grid caption.
- Codec: round trip with nulls, cap enforcement on encode and decode,
  corrupt blob raises the typed exception.
- Repository: insert, read by dive, link and unlink bump HLC, primary
  switching, correction update, delete with tombstone, `watchChanges`.
- Providers: the primary linked route beats dead reckoning; an unlinked
  route never appears on a dive; fewer than two points falls back to the
  estimate; unlinking restores the estimate; the standalone scene builds
  with and without an anchor; the caption chip text per provenance.
- Widgets: list page rows and link chips, detail page link card states,
  section empty and populated states, review page link proposal and offset
  stepper, alignment page start/end/trust interactions with a fake map
  controller, polyline layer renders nothing without an anchor.
- Sync serializer round trip for `navTracks`; migration smoke from 207 to
  209 plus the backstop (implemented: `test/core/database/migration_v209_nav_tracks_test.dart`);
  `arb_parity_test.dart` for the new keys in all 11 locales.

---

## Open questions

The naming question and the dive entry/exit fill question from earlier
drafts are resolved; see Decisions above. One item is deliberately
deferred rather than open:

1. **ENC3 Auxiliary Software KML export.** The surface GPS fixes reach the
   CSV only as relative metres after a fix event (011.DAT.csv); no file
   carries an absolute coordinate, so the origin's latitude and longitude,
   which the console clearly knows, stay locked in the device. The
   Windows software advertises a KML export; whether that KML carries the
   origin fix has not been checked against a real export (Decision 3).
   Nothing in Phase 1 depends on the answer. If a real export shows the
   origin is in there, a small follow-up adds a KML importer for routes
   that pre-fills the start point; if not, the site-pin default anchor and
   the manual start point remain the only path, as designed.
2. Resolved: the collision happened as anticipated. Implemented at schema
   version 209 (see the Schema section above), not 205.
