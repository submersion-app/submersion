# Conditions Section: Weather Fetch Placement and Altitude Auto-Fill

**Date:** 2026-08-06
**Status:** Approved

## Problem

Two related ergonomics problems in the dive edit form's Conditions section:

1. The "Fetch weather" action sits at the Weather subsection overline, halfway
   down the section, even though the fetch fills fields above it (air
   temperature) as well as below it (humidity, wind, surface pressure, cloud
   cover, precipitation, description).
2. Altitude is a manual text field even though the app frequently knows where
   the dive happened: the dive's own logged entry/exit GPS coordinates, the
   selected site's stored `altitude`, or the site's coordinates.

## Scope

- Reorder rows within the Conditions section of the dive edit page.
- Add an elevation lookup service and an altitude resolution rule.
- Auto-fill altitude at four trigger points (site edit, add-GPS-to-site, dive
  edit form, import paths).
- No database schema change. No changes to the dive detail page, bulk edit, or
  statistics.

## 1. Conditions section layout

New row order inside `ConditionsSection`
(`lib/features/dive_log/presentation/widgets/edit_sections/conditions_section.dart`,
rows built in `dive_edit_page.dart`):

1. **Auto-fill overline** (new, first row): a `FormOverline` carrying the
   existing "Fetch weather" `FormOverlineAction`. Same enablement (selected
   site has coordinates), same busy spinner, same confirm-before-overwrite
   dialog, same snackbars. Only the position changes. The overline label is a
   new l10n string ("Auto-fill"), translated to all 10 non-English locales.
2. Water temperature, air temperature (unchanged).
3. Environment rows, unchanged order: dive types, visibility, water type,
   current direction, current strength, swell height, altitude (with its
   existing deco warning), entry method, exit method.
4. **"Weather" overline without the action button**, followed by the weather
   rows unchanged: humidity, wind speed, wind direction, surface pressure,
   cloud cover, precipitation, description.

Behavior addition to the fetch action: after the weather fetch completes, if
the altitude field is still empty, run the altitude resolver (section 3). This
gives users a manual retry path when the automatic fill failed offline.

## 2. ElevationService

New file `lib/features/weather/data/services/elevation_service.dart`,
mirroring `WeatherService`:

- Injectable `http.Client` constructor parameter.
- Calls Open-Meteo's elevation API: `https://api.open-meteo.com/v1/elevation`
  with `latitude`/`longitude` query parameters; the response is
  `{"elevation": [<double>]}`.
- `Future<double?> fetchElevation({required double latitude, required double longitude})`
  returns meters above sea level, or null on any failure (network, non-200,
  malformed body). Never throws.
- Result post-processing: clamp negative values to 0, round to the nearest
  whole meter. A result of 0 is a valid value (sea level) and is stored.
- Requests use a short timeout (5 seconds) so callers never hang on it.

Provider `elevationServiceProvider` added to
`lib/features/weather/presentation/providers/weather_providers.dart` beside
`weatherServiceProvider`, watching the existing `weatherHttpClientProvider`.

## 3. Altitude resolution rule

A shared domain helper (new file
`lib/features/weather/domain/services/altitude_resolver.dart`) encodes one
precedence rule used by every trigger
point. Given the dive's entry/exit locations and the selected site:

1. **Dive's logged GPS** (entry location, else exit location): call the
   elevation API. The dive's own position is ground truth for this dive.
2. **Site's stored altitude** (`DiveSite.altitude`): use directly. This is
   also the fallback when step 1's lookup fails.
3. **Site's coordinates**: call the elevation API, and **write the result back
   to the site record** via the site repository so step 2 resolves locally for
   every future dive at that site.
4. Nothing available or all lookups failed: leave the field empty; manual
   entry works exactly as today.

Invariants:

- Auto-fill only ever writes to an **empty** altitude field. A manually
  entered value is never overwritten.
- The resolver returns the altitude in meters plus whether a site write-back
  is needed; callers decide how to apply it (controller text vs. entity
  field).

## 4. Trigger points

1. **Site edit page** (`site_edit_page.dart` / `location_section.dart`): when
   the coordinate fields become valid — typed, filled by the locate action, or
   set from the map picker — and the altitude field is empty, fetch elevation
   and fill the altitude controller. The value is visible and editable before
   the user saves. If the lookup fails, nothing happens.
2. **Dive edit "Add GPS to site" action** (`dive_edit_page.dart`,
   `_addGpsToSite` path): after setting the site's coordinates, fetch
   elevation and include the altitude in the same site update when the site's
   altitude is null.
3. **Dive edit form**: on load of an existing or new dive, and again on site
   assignment (`_assignSite`), if the altitude controller is empty, run the
   resolver and fill the controller. This fill alone does not mark the form
   dirty — opening and closing a dive must not prompt "discard changes?". The
   value persists only when the user saves. Site write-back from step 3 of the
   resolver does happen immediately (it is a normal site edit, not part of the
   dive form's dirty state).
4. **Import paths**: dive computer downloads
   (`lib/features/dive_computer/data/services/dive_import_service.dart`) and
   file imports (persistence path used by
   `lib/features/dive_import/presentation/providers/dive_import_providers.dart`)
   run a best-effort enrichment for newly created dives that have GPS
   coordinates and null altitude. A per-run cache keyed by rounded coordinates
   (4 decimal places, roughly 11 m) ensures a batch of dives at one location
   triggers one lookup. Lookups never block or fail the import; on timeout or
   error the dive imports with null altitude.

## 5. Data, sync, and error handling

- No schema change: `dives.altitude` and `dive_sites.altitude` already exist.
- The site write-back is a normal repository update; HLC bumps and the change
  syncs like any user edit.
- All background lookups are silent best-effort: no snackbars, no retry
  queues, no persisted error state. The existing fetch-weather snackbars
  (success, unavailable, error) are unchanged.
- Unit display: the altitude field continues to use
  `UnitFormatter.convertAltitude` / `altitudeToMeters`; the resolver operates
  in meters internally.

## 6. Testing

- `ElevationService` unit tests with a mocked `http.Client`: success, non-200,
  malformed body, timeout, negative clamp, rounding.
- Resolver unit tests covering all four precedence branches, the
  lookup-failure fallback from step 1 to step 2, and the write-back signal.
- Widget test for the Conditions section row order: auto-fill overline first,
  fetch action present there and absent from the Weather overline.
- Dive edit page tests: auto-fill on load fills an empty controller, does not
  overwrite a populated one, and does not mark the form dirty.
- Import enrichment test with a mocked service verifying the coordinate cache
  (N dives at one location, one lookup) and that lookup failure still imports
  the dive.
- Known trap: `dive_edit_page.dart` gains a dependency on
  `elevationServiceProvider`; existing consumer widget tests need the mock
  wired in the same change (analyzer will not catch this).

## Out of scope

- Backfilling altitude for existing dives (no background maintenance job).
- Elevation from the weather API's grid-cell elevation field.
- Any change to deco/altitude warning calculations.
