# Tide Site Time and Offline Grid: Design

Date: 2026-09-26
Status: Approved in conversation, pending review of this document
Branch: ericgriffin/tide-calculation-accuracy-d51e4a
Follows: `docs/design/specs/2026-08-09-tide-accuracy-design.md` (PR #932)

## Problem

Tides shown for dives are wrong, and the offline ocean-model tier is too
coarse to trust near coastlines. The harmonic engine itself is correct: the
August golden tests still hold it to within 20 minutes and 0.15 m of NOAA's
published predictions. Two independent causes remain.

### Cause 1: dive wall-clock time fed to the engine as an instant

Submersion stores dive times as wall-clock-as-UTC by design: a 10:00 entry in
Bonaire is stored as `DateTime.utc(..., 10, 0)` so it displays as 10:00 on
any device. The tide engine needs a real instant, because the tide depends on
where the Moon and Sun actually are. Three call sites pass the wall-clock value
straight in:

- the save path in `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
  (`resolved.calculator.getStatus(entryDateTime)`),
- `healedTideRecordProvider` in
  `lib/features/tides/presentation/providers/tide_providers.dart`,
- the uncached fallback in `_tideCard` in
  `lib/features/dive_log/presentation/pages/dive_detail_page.dart`.

At a site at UTC-4 the engine evaluates the tide four hours early. The high
and low times it returns are real UTC instants, which the dive page then
formats verbatim as if they were local wall-clock, so every displayed time
is off by the site's UTC offset. In the diurnal-leaning Caribbean tides at the
maintainer's own sites, this also flips rising and falling. It affects the
NOAA station tier and the model tier equally. The site page is unaffected
because it uses `DateTime.now()`, a real instant, which makes the dive page
look inconsistent with it.

### Cause 2: the bundled FES2022 grid is 1 degree

`assets/data/tide/constituents_grid.json` holds FES2022 constituents at
1.0 degree (111 km) as 70 MB of JSON. FES2022 itself is published at
1/30 degree. The app bilinearly blends open-ocean values up to 111 km apart to
estimate the tide inside a bay. Measured against native-resolution FES2022
over 30 days of extremes (90th percentile error), with both columns using the
same complex-plane interpolation so the difference is resolution alone:

| Site | 1.0 deg | 0.1 deg (this design) |
|---|---|---|
| Escambron, Puerto Rico | 72 min / 9.7 cm | 0 min / 0.0 cm |
| Tulamben, Bali | 79 min / 18.1 cm | 1 min / 0.1 cm |
| Gili, Lombok | 83 min / 22.2 cm | 3 min / 0.7 cm |
| Komodo | 45 min / 18.8 cm | 6 min / 2.1 cm |
| Raja Ampat | 30 min / 10.1 cm | 9 min / 2.7 cm |
| Cornwall | 13 min / 7.7 cm | 1 min / 2.8 cm |
| Monterey | no data | 0 min / 0.0 cm |

The shipped code, which interpolates amplitude and phase separately, measures
the same or worse (Escambron 97 minutes, Komodo 30 cm). Any cell with a land
corner returns null today, which is why Monterey gets nothing from the grid. Lookup is also a linear scan over all 44,000 points per
corner, and the whole file is JSON-parsed on first use. Neither survives a
finer grid, so the asset format and the reader must change together.

## Decisions (made with the maintainer)

1. Fix both causes in one spec and one PR.
2. The site's time zone comes from an offline coordinate lookup at compute
   time. No stored site time zone, no schema change, no sync change.
3. Resolve the zone with `lat_lng_to_timezone`, the lookup main's importers
   already use (amended 2026-09-28; the first version vendored the CC0
   `tz-lookup` quadtree). Tides read back wall clocks the importers wrote,
   so both must use the same zone, and the two lookups disagreed at some
   sites (Socorro: Mazatlan versus Mexico_City, an hour apart).
4. Coastal layer at 0.1 degree (about 11 km) within 30 km of any non-ocean
   cell, plus a 1-degree global layer. About 54 MB of assets, replacing
   today's 70 MB.

## Part 1: Site time

### Rule

The harmonic engine only ever sees real instants. Presentation only ever sees
site wall-clock. One unit converts between them, and nothing else in the tide
feature knows the difference exists.

### New unit: `SiteTimeZone`

`lib/core/util/site_time_zone.dart`.

- `String zoneIdFor(double latitude, double longitude)`: the IANA zone from
  `lat_lng_to_timezone`, the same offline lookup the importers use. Offshore
  points resolve to the nearest land zone, keeping its daylight saving.
  Coordinates outside the valid range return the `Etc/GMT` zone for their
  longitude, because the lookup maps even invalid input to some zone.
- `DateTime instantFromWallClock(DateTime wallClockUtc, double latitude, double longitude)`:
  builds a `TZDateTime` in the site zone from the wall-clock components and
  returns its UTC instant.
- `DateTime wallClockFromInstant(DateTime instant, double latitude, double longitude)`:
  the inverse. Returns a `DateTime.utc` carrying the site's wall-clock digits,
  the flavor every existing tide formatter already expects.
- DST is resolved by tzdata for the actual date through the `timezone`
  package, which the app already depends on. `SiteTimeZone` loads the
  database through the shared `ensureTimeZoneDatabase()`
  (`lib/core/util/time_zone_database.dart`), never directly, because a
  reload resets `tz.local`.
- A zone id absent from tzdata (a future rename) falls back to the
  longitude-based `Etc/GMT` zone and logs once.

### Engine boundary

`lib/features/tides/domain/services/tide_status_for_dive.dart` exposes one
function:

```dart
Future<TideStatus> tideStatusForDive({
  required TideCalculator calculator,
  required DateTime entryWallClock,
  required GeoPoint location,
});
```

It converts the entry wall-clock to an instant with `SiteTimeZone`, then calls
`getStatusAsync`. The three call sites listed under Cause 1 switch to it. The
edit page's save path already builds a `DateTime.utc` wall-clock value, so all
three inputs are the same flavor.

### Storage

`TideRecord` continues to store real UTC instants for `highTideTime` and
`lowTideTime`, which is what those columns already claim. Rows written before
this fix hold instants shifted by the site offset. The existing lazy
self-heal in `healedTideRecordProvider` overwrites them on first view, because
the fresh computation now differs by hours, far beyond the 10-minute and
0.05 m thresholds in `tide_record_heal.dart`. No migration and no new heal
logic.

### Presentation boundary

- `TideRecord` gains `toSiteWallClock(GeoPoint location)`, returning a copy
  whose two times are mapped through `wallClockFromInstant`.
- Dive page: `_tideCard` passes the mapped record to `_buildTideCard`. The
  entry time is already wall-clock, so the cycle graph, the high and low rows,
  and the header range all show site wall-clock with no formatter change.
  Differences between mapped values are unchanged, so `_calculateCycleTimes`
  and `TideCycleGraph` need no math changes. The comments claiming these are
  "stored wall-clock instants" are rewritten to say what is now true.
- Site page (`TideSection`): the providers keep computing with real instants.
  The section maps `now`, the prediction list and the extremes list into site
  wall-clock (via the existing `copyWith(time:)` on `TidePrediction` and
  `TideExtreme`) before handing them to `TideChart`, `TideTimesTable`,
  `CurrentTideIndicator` and `_buildChartTimeRange`, and passes the mapped
  `now` explicitly instead of letting each widget default to
  `DateTime.now()`. The "Tomorrow" label from #2243 compares calendar dates,
  so it stays correct once `now` and the extremes share a clock.

## Part 2: Offline grid

### Asset layout

`assets/data/tide/constituents_grid.json` and `assets/data/tide/metadata.json`
are replaced by a directory `assets/data/tide/fes/`:

- `manifest.json`: model name, source extraction date, band definition, the
  ordered constituent list, cell encoding version, and both layer grids
  (origin, resolution, dimensions, tile size). The Dart reader and the tests
  treat it as the single source of truth.
- `global.bin`: the 1-degree layer, dense, latitude -80 to 80 (161 rows) by
  longitude -180 to 179 (360 columns), wrapping in longitude. About 5.8 MB.
- `coastal/tile_<row>_<col>.bin`: the 0.1-degree coastal layer over latitude
  -80 to 80 and longitude -180 to 180 (wrapping), cut into 100 by 100 cell
  tiles indexed from the south-west corner. Only tiles containing at least
  one coastal cell are written: 351 of 612. About 48 MB.

`pubspec.yaml` lists the new asset directories. The NOAA station index asset
is unaffected.

### Band definition

A cell is coastal when it has valid FES2022 data and lies within 30 km (on the
native 1/30-degree grid) of any cell whose FES2022B mask class is not 0
("ocean native data"). Seeding from classes 1, 2 and 3 matters: small
islands such as Cozumel are class 1 (extrapolated) rather than class 2
(land), and a band seeded from land alone misses most dive sites. With this
definition every sampled dive site has all four surrounding cells in the band
except Sipadan and the Belize Blue Hole (two of four) and the Maldives (none;
atolls are below the mask's resolution, so the global layer answers there,
where open-ocean tides vary slowly).

Lake cells (mask class 3) are never stored, in either layer. FES2022 gives
them zero amplitudes rather than no data; stored, they would chart a flat
tide on lakes and pull neighbouring coastal cells toward zero during
interpolation.

### Cell encoding

Little-endian. Per constituent, in manifest order: amplitude as `int16`
millimetres and phase as `uint16` hundredths of a degree (Greenwich phase lag,
the same convention as today's asset; verified by matching M2 phases at
Cairns, Nanaimo and the Caribbean sites). Amplitude `-1` marks no data for
that constituent. Quantization error is under 1 mm and 0.01 degree.

### Constituent set

The 25 constituents present in both FES2022 and the engine's tables
(`constituentSpeeds`, Doodson numbers, nodal factors): M2, S2, N2, K2, 2N2,
Mu2, Nu2, L2, T2, Eps2, La2, R2, K1, O1, P1, Q1, J1, Mf, Mm, Ssa, Sa, Msqm,
Mtm, M4, MS4. That is 100 bytes per cell. The nine FES2022 constituents the
engine cannot predict (M3, M6, M8, MN4, N4, S4, S1, MKS2, MSf) are omitted;
along coasts they average about 3 cm of combined amplitude. Extending the
engine's tables is separate work.

### Tile encoding

1. Header: magic `SFT1`, `uint16` version, `int16` tile row, `int16` tile
   column, `uint16` rows, `uint16` columns (edge tiles may be partial).
2. Occupancy bitmap: one bit per cell, row-major.
3. Row prefix counts: one `uint32` per row, the number of populated cells
   before that row.
4. Populated cells, packed row-major, 100 bytes each.

A cell's offset is the row prefix count plus the popcount of the bitmap bits
before its column in that row, times 100. No index structure beyond that,
and every read is a plain `ByteData` offset.

### Reader: `FesGridReader`

`lib/features/tides/data/services/fes_grid_reader.dart`. `TideDataService`
keeps its public surface (`getCalculatorForLocation`, `hasTideData`,
`getMetadata`) and delegates to it; the JSON parsing, `_getGridPoint` linear
scan and `_interpolatePhase` go away.

- Loads `manifest.json` once. Loads tiles on demand through
  `rootBundle.load` and keeps them in an in-memory map for the process
  lifetime (a lookup touches at most four tiles; a tile is at most 1 MB).
  Loads `global.bin` only when the coastal layer has no corner for a point.
- Interpolation: bilinear over the four surrounding cells in the complex
  plane, summing weight times amplitude times e^(i phase) and taking modulus
  and argument. Corners without data are dropped and the remaining weights
  renormalized. Coastal first, then global, then null.
- `TideDataMetadata` reads from the manifest. `TideDataSource.fesModel` gains
  `resolutionKm` so the badge sheet can show it.

### Extraction: `scripts/tide/extract_fes_grid.py`

Reads the FES2022B `ocean_tide_extrapolated` NetCDF files and
`mask_fes2022B.nc` directly with `numpy` and `netCDF4` (both on PyPI; no
PyFES, no conda). Computes the band, subsamples every third native cell for
the coastal layer and every thirtieth for the global layer, and writes the
manifest, `global.bin` and the tiles. A `--verify` flag re-reads the output
and compares a random sample of cells against the NetCDF source within the
quantization bound. A `--vectors` flag writes the accuracy test fixture
described under Testing.

`scripts/tide/README.md` is rewritten around this script with a plain venv.
`extract_fes_constituents.py`, `generate_fes_config.py`,
`export_dive_sites.dart` and `requirements.txt` are deleted, along with the
stale PyFES section of `docs/README.md`.

## Part 3: Providers, UI and error handling

### Providers

- `healedTideRecordProvider` calls `tideStatusForDive`. Its family key is
  unchanged, so detail-page tests that override it keep working.
- The now-relative providers (`tidePredictionsProvider`,
  `tideExtremesProvider`, `currentTideStatusProvider` and the range variants)
  are unchanged: they compute with real instants, and `TideSection` does the
  mapping.

### UI wording

Two new keys, following the existing `tides_source_*` naming, added to all
11 locale ARB files:

- `tides_source_siteLocalTime`: "Times are shown in the dive site's local
  time." Shown in the source sheet on both tiers.
- `tides_source_modelResolution`: "{km} km ocean-model grid", with the
  distance rendered through the diver's unit settings. Shown in the source
  sheet on the model tier beside the existing datum line.

The existing model caveat stays.

### Error handling

- Zone lookup always returns a zone id. The only failure is an id missing
  from tzdata, which falls back to longitude-based `Etc/GMT` and logs once.
- Missing or malformed tile: treated as no coastal data, so the global layer
  answers. Malformed manifest or `global.bin`: logged, and the reader returns
  null, which is the existing "no tide data" state. Never a crash and never a
  partial constituent set.
- Self-heal thresholds are unchanged. The save path and the heal path share
  `tideStatusForDive`, so they cannot disagree.
- Zone lookups are pure and cheap and are not cached.

### Sync and schema

No changes. `TideRecord` columns keep their meaning, no site field is added,
and the local cache database is untouched.

## Testing

Every oracle comes from outside this codebase.

### Site time

- Agreement: at ten dive sites, including offshore reefs and places where
  lookups have disagreed, `zoneIdFor` equals the MacDive importer's zone.
- Coverage: every zone returned over a 4-degree global grid resolves in the
  bundled tzdata.
- Offsets: Monterey in January and July, Sydney (southern DST), Adelaide
  (half-hour zone), Bonaire (no DST), and an open-ocean point that takes the
  nearest land zone (the Azores),
  each asserted against published offsets.
- DST edges: a wall-clock time inside the spring-forward gap and one inside
  the fall-back overlap. The test pins the `timezone` package's resolution and
  the doc comment states it.
- Round trip away from DST edges returns the same digits.
- A zone id missing from tzdata falls back to longitude-based `Etc/GMT`.

### The bug, against NOAA local time

New NOAA hilo fixtures fetched with `time_zone=lst_ldt`, so NOAA performs the
local-time conversion independently of this code: San Francisco on dates
straddling a DST change, and one non-DST Caribbean station. Each NOAA local
time is passed to `tideStatusForDive` as a dive entry wall-clock, and the
result is mapped through `toSiteWallClock`. The shown high and low times must
match NOAA's local times within 20 minutes. The current code fails by the full
UTC offset, so the test is red first.

### Grid reader

- Small synthetic tiles written by the extraction script's own encoder,
  committed as fixtures: bitmap and popcount lookup, an empty row, the last
  cell of a partial edge tile.
- Interpolation: phase across the 0/360 wrap, opposed phases cancelling,
  renormalization with missing corners, null with no corners.
- Fallbacks: outside the band uses the global layer; a malformed tile falls
  back to global; a malformed manifest returns null.
- Guard: the manifest's constituent list is a subset of `constituentSpeeds`.

### Accuracy against native FES2022

`extract_fes_grid.py --vectors` writes constituents interpolated from the
native 1/30-degree data at about 30 coastal dive sites, including the
maintainer's Bonaire, Cozumel and Puerto Rico sites, Komodo, Tulamben, Gili,
Raja Ampat, Cornwall, Monterey and Cairns. The test loads the real bundled
asset, computes 30 days of extremes from both, and requires 90th-percentile
errors within 10 minutes and 5 cm at every site. Monterey must resolve.

### Integration and UI

- Self-heal: a record written by the old path at a Bonaire site, four hours
  off, is overwritten on first view; a record written by the new path is left
  alone.
- Dive page widget test: site-local high and low times regardless of the test
  host's time zone.
- Site tide section widget test: `now` and upcoming extremes in site
  wall-clock.
- Source sheet: the local-time line on both tiers; the resolution line on the
  model tier only.

### Gates

- The August NOAA golden tests and the M2 period regression pass untouched.
- `dart format`, whole-project `flutter analyze`, the `test/architecture/`
  guards, and one full suite run.

## Out of scope

- A stored or user-editable site time zone.
- Extending the engine's constituent tables to the nine omitted FES2022
  constituents.
- Tidal current predictions.
- Changes to the NOAA station tier, its snap radius or its cache.
- Bulk migration of stored tide records (the lazy self-heal covers them).

## Tracking

Every PR must link an issue. An issue describing both causes, with the
measurements above, is opened before the PR, and the PR body uses
`Closes #<n>`.
