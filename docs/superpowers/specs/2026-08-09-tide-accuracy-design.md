# Tide Prediction Accuracy — Design

Date: 2026-08-09
Status: Approved (pending user review of this document)
Branch: worktree-tide-accuracy

## Problem

Tide charts have been wildly inaccurate since the feature was introduced. Two
confirmed math bugs make every prediction wrong, a placeholder data file
shadows real model data at popular sites, and the test suite contains only
smoke tests that cannot detect either failure.

### Root cause 1: double-counted time evolution

`TideCalculator.calculateHeight` (`lib/core/tide/tide_calculator.dart:82`)
computes the constituent phase as:

```
phase = speed * hoursFromEpoch + equilibriumPhase(t) - g
```

The equilibrium argument `V(t) + u`, computed from Doodson numbers at
prediction time `t`, already contains the full time evolution of the
constituent. Adding `speed * hoursFromEpoch` on top makes every constituent
advance at roughly twice its true angular speed. Verified numerically: the
code's effective M2 speed is 58.71 degrees/hour versus the true 28.98
degrees/hour, so the dominant tide cycles every ~6.1 hours instead of ~12.42.

### Root cause 2: solar mean longitude coefficients off by 10x

`AstronomicalArguments.forDateTime` (`lib/core/tide/astronomical_arguments.dart:85`)
computes the Sun's mean longitude with coefficients intended for Julian
millennia (`360007.6982779 * T`, `0.03032028 * T^2`) while `T` is measured in
Julian centuries. The Sun's longitude therefore advances 10 times too fast.
The Moon, lunar perigee, node, and solar perigee formulas all correctly use
century coefficients; only `h` is wrong. Correct values (Meeus):
`280.46646 + 36000.76983 T + 0.0003032 T^2`.

### Root cause 3: missing Doodson phase constants (found during planning)

The equilibrium argument computed from the six Doodson integers omits the
per-constituent additive phase constant from Schureman's tables. In this
codebase's convention (tau = 15t + h - s, solar time from midnight), the
correct constants are: O1-group diurnals (O1, Q1, 2Q1, Rho1, Sig1, P1, Pi1)
-90 degrees; K1-group diurnals (K1, J1, OO1, The1, Chi1, Phi1, M1)
+90 degrees; L2 and R2 +180 degrees; all others 0. Without them every
diurnal constituent is roughly 180 degrees out of phase: a purely diurnal
station (Pensacola) predicts high tide ~12 hours from the true time.

### Root cause 4: Julian date off by half a day (found during planning)

`AstronomicalArguments._toJulianDate` uses the integer Julian Day Number
formula (noon-based) but treats the result as a midnight-based Julian Date.
Every astronomical longitude is therefore evaluated 12 hours late (Moon
longitude off by 6.6 degrees), making M2 predictions ~25 minutes late. Fix:
subtract 32045.5 instead of 32045. The existing test asserting T close to 0
at J2000 noon cannot catch this: the error (0.5/36525) is inside its 0.001
tolerance.

### Root cause 5: two wrong Doodson table entries (found during planning)

In `harmonic_constituents.dart`, `The1` duplicates J1's coefficients
(correct: `[1, 2, -2, 1, 0, 0]`) and `M1` has the lunar perigee sign flipped
(correct: `[1, 0, 0, 1, 0, 0]`). Verified by differentiating the Doodson sum
against each constituent's published angular speed.

### Validation of the combined fix

A Python port of the corrected algorithm was validated during planning
against NOAA's published high/low predictions (station constituents in,
published extremes out) for three tidally distinct stations — San Francisco
9414290 (mixed), Boston 8443970 (semi-diurnal), Pensacola 8729840 (diurnal)
— on 2026-09-15 and 2027-06-15. Worst error across all stations and dates:
15.6 minutes on extreme times, 0.071 m on extreme heights. This confirms the
five fixes above are complete and the golden-test tolerances below are
achievable.

### Contributing factors

- `assets/data/tide/constituents_sites.json` is labeled
  `"source": "Sample Data"` with hand-typed constituent values and the note
  "Replace with real FES extraction for production". Site matches take
  precedence over the real FES2022 grid, so exactly the popular dive sites
  (Monterey Bay, etc.) get fabricated data.
- `test/core/tide/tide_calculator_test.dart` asserts only plausibility
  properties (heights vary, extremes alternate, range 0.5-3 m). A signal
  oscillating at double frequency passes every existing test.
- Per-dive `TideRecord` rows persisted in the main database were all computed
  by the broken engine and are therefore wrong.

## Decisions (made with user)

1. Fix the offline engine and add an online refinement layer
   (option: "Offline fix + online refinement").
2. Online source is NOAA CO-OPS only: fetch each station's published harmonic
   constituents once, cache locally, and let the fixed offline engine predict
   any date at station accuracy. Non-US sites fall back to the FES2022 grid.
3. The UI shows the data source and a caveat for model-tier estimates
   (option: "Yes, show source + caveat").
4. Structure: resolver pipeline (approach A) — a `TideConstituentResolver`
   with ordered sources returning constituents plus provenance, leaving
   `TideCalculator` a pure function of constituents.

## Architecture

### Bug fixes (in place, no structural change)

- `AstronomicalArguments`: correct the solar mean longitude to Meeus century
  coefficients.
- `TideCalculator.calculateHeight`: drop the `speed * hoursFromEpoch` term.
  The phase becomes `V(t) + u - g`, with the Doodson equilibrium argument
  evaluated at prediction time. `constituentSpeeds` remains as metadata but no
  longer drives the phase.

### New unit: TideConstituentResolver

`lib/features/tides/data/services/tide_constituent_resolver.dart`

- Input: latitude/longitude.
- Output: `ResolvedTideData` = constituents + `z0` + provenance
  (`TideDataSource.noaaStation(id, name, distanceKm)` or
  `TideDataSource.fesModel`), or null when no data is available.
- Source order:
  1. Cached NOAA station constituents within a ~25 km snap radius.
  2. If no cache entry and the device is online: fetch via
     `NoaaStationService`, persist, use it.
  3. FES2022 grid interpolation via the existing `TideDataService`.
  4. null (existing "no tide data" UI).

### New unit: NoaaStationService

`lib/features/tides/data/services/noaa_station_service.dart`

- Finds the nearest NOAA CO-OPS harmonic station to a coordinate using a
  bundled station index asset (id, name, lat, lon for the ~1,000 harmonic
  stations; a few hundred KB of JSON generated by a committed script under
  `scripts/`).
- Fetches that station's published harmonic constituents and datum offsets
  from the free CO-OPS metadata API (`api.tidesandcurrents.noaa.gov`), converts
  them to `TideConstituent` format (degrees, meters, GMT phase reference), and
  persists them to the local cache database.
- Fetch policy: opportunistic. Triggered when a tide section renders for a
  site with no cached station data. Silent failure falls back to FES.
- The freshwater gate lives at the provider/section level, not in this
  service: for `WaterType.fresh` sites no tide resolution of any tier runs,
  so no fetch can occur (same gate PR #919 established for reef data).
  Brackish and null water types are treated as ocean.

### Removed: placeholder site data

`assets/data/tide/constituents_sites.json` and the site-matching path in
`TideDataService` are deleted, along with the site-ID-based APIs that exist
only for that file (`getCalculatorForSiteId`, `getAvailableSiteIds`,
`getSiteInfo`, and `tideSiteIdsProvider`). `TideDataService` retains asset
loading and grid interpolation only.

### Provider change

`tideCalculatorProvider(GeoPoint)` is replaced by
`resolvedTideDataProvider(GeoPoint)` returning calculator plus provenance.
The ~14 downstream providers continue to derive from the calculator; tide
widgets additionally read provenance for the badge.

## Data flow and storage

Resolution flow for a dive site's tide section:

1. Site has GPS coordinates and is not `WaterType.fresh` (freshwater sites
   show no tide section and never trigger fetches).
2. `resolvedTideDataProvider` consults the resolver (order above).
3. Calculator + provenance flow to downstream providers and widgets.

### Station cache table

New table `noaa_tide_stations` in `lib/core/database/local_cache_database.dart`
(`submersion_local.db`) — not the synced main database, because station
constituents are re-derivable third-party data:

- `station_id` (text, PK)
- `name` (text)
- `latitude`, `longitude` (real)
- `constituents_json` (text)
- `datum_offset_mllw` (real, nullable) — Z0 above MLLW
- `status` (text: `ok` / `unavailable`)
- `fetched_at` (datetime)

`status` records deterministic failures (station has no harmonic data) so a
dead endpoint is not re-queried forever. Transient failures are not cached.
A restored database re-fetches instead of carrying stale cache. This follows
the established local-cache-DB convention (one migration step on the cache
ladder, no HLC/sync/backup involvement).

### Refresh policy

Harmonic constituents are stable for years. Refetch opportunistically only
when `fetched_at` is older than one year.

### Datum handling

- Station tier: apply the station's Z0 so heights match official NOAA tide
  tables (MLLW datum), which is what divers cross-check against.
- Model tier: heights remain relative to mean sea level, as today.
- The badge detail states the datum for the active tier, since absolute
  heights are not comparable across tiers.

### Stale stored TideRecord repair

No bulk migration. The dive-detail tide section lazily self-heals: when it
renders for a dive whose site has coordinates, it recomputes the tide record
and overwrites the stored row if the height differs by more than 0.05 m, the
tide state differs, or an extreme time differs by more than 10 minutes. Old
dives are corrected as they are viewed; untouched rows cost nothing.

## UI changes

Rendering of the chart, cycle graph, times table, and current-tide indicator
is unchanged; only the data behind them is fixed.

- Source badge in the tide section header:
  - Station tier: `NOAA station · <name> (<distance>)`, distance respecting
    the diver's unit settings.
  - Model tier: `Ocean-model estimate` plus a one-line caveat: "Modeled from
    satellite data — times and heights may differ near complex coastlines."
  - Tapping the badge opens a small detail sheet: source, datum, data vintage.
- The tide section is hidden entirely for `WaterType.fresh` sites.
- New localization keys (`tide_source_station`, `tide_source_model`,
  `tide_model_caveat`, datum labels) added to all 11 locale ARB files.
- Tide heights remain meters internally, rendered through the diver's
  depth-unit preference; the station distance follows the same rule.

## Error handling

- NOAA fetch failures are invisible to the diver; the section always renders
  the best available tier.
- Transient errors (timeout, no network) are not cached; the next render
  retries. Deterministic failures (no harmonic data, 404) are cached as
  `status: unavailable`.
- Malformed API payloads are treated as deterministic failures and logged;
  never partially parsed into an incomplete constituent set.
- Resolver returning null preserves the existing "no tide data available" UI.

## Testing

- Golden reference tests for the engine using independently computed test
  vectors (taken from NOAA's published predictions, not generated by our own
  code) for three stations with different tidal characters: semi-diurnal
  (US East Coast), mixed (Monterey or San Francisco), diurnal (Gulf of
  Mexico). Assert high/low times within +/-20 minutes and heights within
  +/-0.15 m using each station's own constituents. Include at least one date
  far from the present to catch epoch and nodal errors.
- Frequency regression test: the dominant period of an M2-only prediction
  must be 12.42 hours +/- 1 minute. This test alone would have caught root
  cause 1.
- Astronomy tests: solar and lunar mean longitudes validated against
  published Meeus worked examples. This catches root cause 2's error class.
- Resolver tests with mocked HTTP and an in-memory cache database: source
  ordering, snap radius, freshwater gate, offline fallback, `unavailable`
  caching, stale refetch.
- Widget test: badge renders the correct tier text; caveat appears only for
  model-tier data.
- Standard project gates: `dart format`, whole-project `flutter analyze`,
  full test suite.

## Out of scope

- WorldTides or any other paid/global station provider.
- Tidal current (flow) predictions, as distinct from height.
- Re-extracting or densifying the FES2022 grid asset.
- Performance work on grid point lookup (linear scan) beyond what the
  resolver refactor touches incidentally.
- Bulk migration of historical TideRecord rows (lazy self-heal only).
