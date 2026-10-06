# Suunto DiveRoute import design

Issue: #1445. Narrows "PR 3, Suunto" of
[2026-09-10-underwater-nav-track-design.md](2026-09-10-underwater-nav-track-design.md).

## Problem

The Suunto Nautic S (and Ocean) records an inertial route. The Suunto app's
JSON export carries it as `DiveRoute`: about 2 900 X/Y/Z samples at 1 Hz, in
metres relative to `DiveRouteOrigin` (a lat/lon fix in degrees). The watch
itself stores only raw 10 Hz IMU data, so no dive-computer download can ever
supply the route; the JSON is the only source.

Today `SuuntoDiveParser` reads `DiveRouteOrigin` as a fallback entry fix and
drops the samples. The 3D seascape therefore draws a dead-reckoned
"Estimated path" for a dive whose real path is in the file.

Two further gaps:

- There is no Suunto JSON *file* import. `SuuntoSmlNormalizer` accepts the
  app's `DeviceLog` export shape, but only the Suunto Cloud wizard calls it.
  A dropped `.json` falls through `FormatDetector` as `unknown`.
- No dive import path writes a route. `NavTrackRepository.insertImportedRoute`
  is called only by the standalone Seacraft review page, and derives its
  anchor from a site pin or the dive's entry fix.

The storage itself exists (`NavTracks`, schema v230): points are a gzipped
JSON blob in local north/east/depth metres, about 40 KB for a route of this
size, and `NavTrackSource.suuntoRoute` is already defined.

## Outcome

A Suunto dive that carries `DiveRoute`, imported from the Suunto Cloud or from
the app's JSON export file, arrives with that route stored as an underwater
route linked to the dive and anchored at `DiveRouteOrigin`. The 3D view draws
the measured path instead of the estimate, with no renderer changes.

Accuracy caveat from the reporter: absolute position is roughly +/-20 m (one
surface fix, which is probably the surfacing rather than the entry position;
IMU closure error about 12 m over 425 m). The shape is good. Nothing in this
design claims metre-level absolute accuracy; the existing alignment tools
(anchor, end target, trust, rotation) remain the way to correct it.

## Design

### 1. Parsing DiveRoute

New pure helper `SuuntoDiveRouteParser` in `lib/core/services/suunto_cloud/`.

Input: the normalized samples, plus the sample clock correction
`SuuntoDiveParser` already computes for the dive start
(`_sampleClockCorrection`, the #2604 fix). Output: a nullable route value
holding the `NavTrackPoint` list and the origin.

- Every sample with a `DiveRoute` map `{X, Y, Z}` becomes one point.
- Timestamp: that sample's `TimeISO8601`, through the same wall-clock-as-UTC
  conversion and clock correction as the dive start, as epoch seconds. This
  keeps the route on the same time base as the dive profile for both the
  cloud and the file source.
- Axis mapping, checked against three real Nautic S exports from the
  reporter (#1445; trimmed fixture `test/fixtures/suunto/nautic_s_dive_route.json`):
  the route is east/north/up, so X is east and Y is north. The frame is
  inferred from Z being up-positive (negative underwater); the GPS fixes
  are too noisy against the route's 30 m+ drift to fit heading directly,
  and the export carries no compass channel.
- Depth comes from the export's own `Depth` channel, linearly interpolated
  to each route sample's time (holding the nearest reading outside its
  span). Z reads about 1.024 x depth + 0.35 m, as if computed for fresh
  water, so it is used only as a fallback (`-Z`, clamped at 0) for an
  export with no Depth channel.
- The route has no samples while the diver is at the surface (start and
  mid-dive surface intervals) and resumes at the same X/Y: Suunto does not
  use the surface GPS fixes to correct it.
- A point with a missing or non-finite coordinate is dropped.
- Fewer than 2 points: no route; the dive imports exactly as today.
- More than `kMaxNavTrackPointCount`: no route (the dive still imports),
  using the existing `validateNavTrackPointCount`.
- Origin: the first non-null-island `DiveRouteOrigin`, which `_FirstPass`
  already finds. A missing or (0, 0) origin leaves the route unanchored.

`SuuntoParsedDive` gains a nullable `route` field (points, origin, device
name). `SuuntoDiveParser.parse` fills it, so the cloud and file paths both
receive it without further wiring.

### 2. Anchor and identity

The route's origin is `DiveRouteOrigin` by definition (X/Y are relative to
it), so it anchors there, not at the footer entry fix and not at the site
pin. `insertImportedRoute` gains optional `anchorLatitude` and
`anchorLongitude` parameters; when both are given they override the
site/entry fallback. Existing callers are unchanged.

- `source`: `NavTrackSource.suuntoRoute`.
- `sourceRef`: a stable key built from the device serial number and the
  dive's start time, so a re-import of the same dive finds the same route.
- `deviceName`: the parsed device name.
- `tzOffsetMinutes`: the column default, as for Seacraft.

### 3. Suunto JSON file import

- **Detection.** New `ImportFormat.suuntoJson` (display name "Suunto JSON",
  `SourceApp.suunto`). `FormatDetector` adds a JSON check between the XML
  and DL7 checks: after any BOM and leading whitespace the content starts
  with `{`, and the first 8 KB contains `"DeviceLog"` (app export) or
  `"suunto/sml"` (cloud shape). Like `navTrack`, the universal parser does
  not support it: it is a hand-off, not a parse.
- **Hand-off, following the Seacraft pattern.**
  - Universal wizard: stays on file selection and shows a
    `SuuntoJsonHandoffCard` ("This is a Suunto app export") whose Import
    button opens the Suunto file wizard with the bytes.
  - Batch import: the file is listed as needing individual import.
  - Share or drop onto the app: `incoming_file_handler` routes straight to
    the Suunto file wizard.
  - No new tile on the Transfer page; the existing File import card reaches
    it through detection.
- **`SuuntoFileAdapter`** (new `ImportSourceType.suuntoFile`). Its
  acquisition step takes the handed-off bytes, or picks one or more `.json`
  files. Each file goes through `jsonDecode`, `SuuntoSmlNormalizer.parse`
  and `SuuntoDiveParser.parse`. A file that is not JSON, not a dive
  (`ActivityType != 51`) or has no header is listed with its reason and
  skipped; the others still import. The review, duplicate and import steps
  are the same as the cloud wizard's.
- **Shared import core.** `SuuntoCloudAdapter`'s duplicate checking, its
  three write paths (new, replace source, consolidate), computer resolution
  and notes handling move into `SuuntoDiveImportCore`, which both adapters
  delegate to. Cloud behaviour does not change; its existing tests guard the
  extraction.
- **l10n.** Hand-off card, file step and per-file error strings, in every
  locale.

### 4. Writing the route

`SuuntoDiveImportCore._attachRoute(diveId, parsed)` runs next to
`_fillNotes`, once the dive id is settled, when the parsed dive has a route:

| Dive action | Route behaviour |
| --- | --- |
| New dive | Insert, linked to the dive. It becomes primary through `_shouldBePrimary` (a new dive has none). |
| Skip | The dive is untouched. When the matched dive has no Suunto route yet, the route is linked to it (`attachIfMissing`), so dives imported before routes were read gain them without Replace source rewriting the dive. |
| Replace source | Find a `suunto_route` linked to that dive with the same `sourceRef`. If found, insert the new route and call `NavTrackRepository.replace(old, withRouteId: new)`, which hands over the primary role. Otherwise insert. |
| Consolidate | Attach to the surviving dive (or the kept-standalone one). A route from another source (e.g. Seacraft) keeps primary; the Suunto route is secondary. A consolidation skipped because the dive is already this computer's reading backfills like Skip. |

A route that fails to parse or write is logged and never fails the dive
import, the same contract as `_fillNotes`.

Sync needs nothing new: `insertImportedRoute` already marks the record
pending and notifies the sync bus.

### 5. Display

`spatialReckonedPathProvider` already prefers the primary route through
`NavTrackPathAdapter`, so the provenance chip shows a recorded route instead
of "Estimated path". The dive detail Route section lists the route with the
existing "Suunto" source label.

**Route-scale scene** (follow-up from the reporter's test of the draft PR).
The dive's 3D scene is built on the bathymetry tile, about 8 km across.
Everything in it is sized in scene units, which then mean hundreds of
metres: the ribbon was about 128 m wide and each pin about 80 m. An 80 m
route was therefore a dot, and zooming the camera in only magnified that.
A camera-only fit was tried and reverted for this reason.

A dive whose path is a measured route now gets a scene at the route's own
scale:

- `SpatialSitePage` sends it to the standalone dive scene, even at a site
  with terrain. Switching the route off makes the path an estimate again
  and brings back the site seascape.
- `spatialGeometryProvider` resamples the tile onto the route's padded
  window (`routeWindowGrid`). It uses bilinear depths, keeps the source and
  resolution, and pads by the same amount the scene builder pads the path,
  so the scene frame is exactly that window. Ribbon, pins, axes and
  contours are then at route scale.
- The satellite drape is framed on the whole tile, so it is left off there.
- At 115 m bathymetry cells the seafloor under a 100 m window is nearly
  flat. That is accurate: the data has no finer detail.

## Testing

TDD throughout.

- Route parser: axis mapping, Z sign and clamp, timestamp with clock
  correction (equal to the dive start's time base), non-finite points
  dropped, fewer than 2 points gives no route, null-island origin gives no
  anchor, point cap.
- Normalizer: the cloud `sml` shape carries `DiveRoute` through to the
  flattened samples.
- `FormatDetector`: both JSON shapes detected as `suuntoJson`; an unrelated
  JSON is not; no false positive on any existing fixture under
  `test/fixtures/`.
- Import core: route behaviour for each dive action in the table; a route
  write failure still imports the dive; the cloud adapter's existing tests
  stay green after the extraction.
- Repository: an explicit anchor overrides the site and entry fallback.
- Widgets: the hand-off card, the file step's per-file error list.
- Real fixture: a trimmed Nautic S export from the reporter under
  `test/fixtures/suunto/`, asserting the verified axis convention (heading
  against movement, Z against `Depth`).

## Rollout gate

The axis convention had to be verified against a real export before the PR
left draft. Done with the reporter's three Nautic S exports (#1445): see
"Parsing DiveRoute" above.

## Out of scope

- Reading the 10 Hz raw IMU from the watch binary (dead reckoning research,
  not a decode).
- UDDF export of the route (UDDF has no element for it; KML/GPX export of
  routes is a later PR in the parent spec).
- Bathymetry auto-fit.
