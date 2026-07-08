# Dive-GPS-anchored site picker + seeded new-site creation

- **Date:** 2026-07-08
- **Status:** Approved design, pending implementation plan
- **Scope decision:** "Approach 3" — core re-anchor + seeded new-site + unit-aware distance + reverse-geocode on seed

## Problem

When a dive is downloaded (or matched to a phone GPS track), it carries entry/exit
GPS fixes. In the **dive edit form**, the site picker that lets a diver choose or
create a site does not use those coordinates:

- The picker sorts/labels site distances from the **device's** current location
  (`_currentLocation`), which is meaningless for a dive logged elsewhere days ago.
- The **"New Dive Site"** button opens the site editor with **no** coordinates, so
  the diver must re-enter GPS that the dive already knows.

We want the picker to anchor on the **dive's own GPS** when it has one, and to seed
the new-site form with those coordinates — while leaving GPS-less dives behaving
exactly as they do today.

## What already exists (reused, not rebuilt)

Most of the machinery is already present; the change is re-pointing it.

- `SitePickerSheet` — `lib/features/dive_log/presentation/widgets/pickers/site_picker_sheet.dart`
  - Already computes per-site distance (`_distanceToSite`, `:44-53`), sorts
    nearest-first with GPS-less sites last (`:189-199`), shows a "Sorted by
    distance" header (`:86-101`), renders per-site distance with a <50 km "nearby"
    highlight (`:236`, `:260-270`), and hosts the "New Dive Site" button
    (`:104-108`, and the empty-state variant `:176-181`).
  - All of that is gated on a single nullable anchor (`currentLocation`). Only
    referenced from `dive_edit_page.dart`.
- `dive_edit_page.dart` — `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
  - `_existingDive` (declared `:227`, assigned `:510`) holds the loaded dive, so
    `entryLocation`/`exitLocation` are in hand — no new query.
  - `_currentLocation` (device GPS, `:230`/`:675`) is what the picker uses today
    (`:1939`).
  - `_showSitePicker` (`:1927-1963`) opens the sheet, and on the
    `_createNewSiteSentinel` (`:90`) result pushes `context.push<String>('/sites/new')`
    (`:1953`), then loads the returned id and selects it (`:1956-1959`).
- `SiteEditPage` — `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
  - Has lat/lng fields and a `_isApplyingInitialValues` seam (`:84`, `:126-129`)
    that suppresses dirty-marking while fields are seeded (`:159`-`:187`).
  - Fills **only-empty** country/region from reverse-geocode in "Use my location"
    (`:1419-1487`, fill `:1460-1465`) and "Pick from map" (`:1489-1526`, fill
    `:1510-1515`); `_saveSite` deliberately does **not** geocode (`:2035-2040`).
  - Returns the saved id via `context.pop(savedId)` (`:2143-2147`).
  - Reverse-geocode is reached through `locationServiceProvider`
    (`lib/core/providers/location_service_provider.dart:9`).
- Distance/geocode primitives:
  - `distanceMeters(GeoPoint, GeoPoint)` — Haversine, `lib/core/utils/geo_math.dart:10-20`.
  - `LocationService.reverseGeocode(lat, lng)` → `({country, region, locality})`,
    `lib/core/services/location_service.dart:188-224`.
  - `GeoPoint` — `lib/features/dive_sites/domain/entities/dive_site.dart:203-215`.
- Router: `/sites/new` at `lib/core/router/app_router.dart:379`
  (`builder: (context, state) => const SiteEditPage()`).

## Behavior contract

**Dive being edited has GPS** (`entryLocation`, else `exitLocation`):

1. Existing sites in the picker show distance from that point and are sorted
   nearest-first; GPS-less sites sink to the bottom (existing sort rule).
2. The picker header reads "Sorted by distance from this dive" (new string) with a
   dive-appropriate icon.
3. "New Dive Site" opens the site editor pre-filled with the dive's lat/lng, and
   best-effort reverse-geocodes country/region into the (empty) fields.
4. Selecting or creating a site associates it to the dive via the normal dive-edit
   save path (unchanged).

**Dive being edited has no GPS:** identical to today. Guaranteed structurally — the
anchor resolves to `diveGps ?? _currentLocation`, so a null dive-GPS passes today's
device-location value through unchanged, and "New Dive Site" pushes `/sites/new`
with no `extra`.

**Coordinate selection:** entry wins when both entry and exit exist; exit is used
only when entry is absent (`entryLocation ?? exitLocation`).

## Design

### A. Anchor the picker on the dive's GPS

`SitePickerSheet`:

- Add `final GeoPoint? diveLocation;`. Resolve `anchor = diveLocation ?? currentLocation`
  (convert `currentLocation` to a `GeoPoint` for a single code path) and key all
  distance/sort logic off `anchor`.
- Replace the `LocationService.instance.distanceBetween` call with the pure
  `distanceMeters(GeoPoint, GeoPoint)` from `geo_math.dart` — drops a singleton
  dependency and makes the sheet unit-testable.
- Header: when `diveLocation != null`, show the new
  `diveLog_sitePicker_sortedByDiveDistance` string ("Sorted by distance from this
  dive") with a dive/place icon; otherwise keep the existing
  `diveLog_sitePicker_sortedByDistance` + `my_location`.
- Keep the existing "nearby" highlight rule (threshold unchanged), recomputed against
  the resolved anchor in meters.

`dive_edit_page._showSitePicker`:

- Compute `final anchor = _existingDive?.entryLocation ?? _existingDive?.exitLocation;`
  (see Open item 1 on prefill dives).
- Pass `diveLocation: anchor` to `SitePickerSheet` (continue passing
  `currentLocation: _currentLocation` for the fallback).
- On the create-new branch: `context.push<String>('/sites/new', extra: anchor)` when
  `anchor != null`, else the existing no-`extra` push.

### B. Unit-aware, auto-scaling distance readout

`UnitFormatter.formatDistance` (`lib/core/utils/unit_formatter.dart:41-44`) converts
into the diver's **depth** unit (m/ft) with no km/mi scaling — a 50 km site would
render "50000m"/"164042ft". It is unsuitable for site distances.

- Add a new `UnitFormatter.formatGeoDistance(double meters)` that respects the
  metric/imperial preference (derived from `settings.depthUnit`) and auto-scales:
  metric → `m` under 1 km, else `km`; imperial → `ft` under 1 mi (5280 ft), else `mi`.
  Decimal rules mirror today's picker (major unit `<10` → one decimal, else rounded;
  minor unit rounded to whole m/ft).
- The picker uses `formatGeoDistance` (via `ref.watch(settingsProvider)` →
  `UnitFormatter`) in place of the hardcoded-km/m `_formatDistance` (`:56-64`).
- Output format should embed the unit symbol to avoid a combinatorial set of
  per-unit "away" l10n keys (see Open item 2).

### C. Seed the new-site form

`SiteEditPage`:

- Add `final GeoPoint? initialLocation;` to the constructor; ignored when editing or
  merging (assert / guard against `siteId`/`mergeSiteIds`).
- On init, when creating and `initialLocation != null`:
  1. Seed `_latitudeController`/`_longitudeController` inside `_isApplyingInitialValues`
     so the pre-filled form is **not** marked dirty (a diver who backs out is not
     nagged).
  2. Fire a best-effort `reverseGeocode(initialLocation)` via `locationServiceProvider`;
     when it returns and the widget is still mounted, fill **only-empty**
     country/region (non-clobbering), matching the "Pick from map" convention. Do not
     hold `_isApplyingInitialValues` across the await; set it only around the
     synchronous controller writes.

Router `/sites/new` (`app_router.dart:379`):

- `SiteEditPage(initialLocation: state.extra is GeoPoint ? state.extra as GeoPoint : null)`.
  The defensive cast keeps the other three `/sites/new` callers (`site_map_page.dart:125`,
  `site_list_page.dart:72`, `site_list_content.dart:920`), which pass no `extra`,
  byte-identical.

## Edge cases

- Both entry & exit present → entry. Only exit → exit. Neither → device fallback
  (today's behavior).
- Geocode fails / offline → coords still seeded; country/region stay empty.
- Diver types into country/region before the geocode returns → only-empty fill never
  overwrites their input.
- Other `/sites/new` callers → unaffected (defensive `extra` cast).

## Testing (TDD)

- **Unit — `formatGeoDistance`:** metric vs imperial selection from `depthUnit`;
  m↔km and ft↔mi thresholds; decimal rules; boundary values (999 m, 1 km, ~1 mi).
- **Unit — sort:** given an anchor and a mix of sited/unsited candidates, ordering is
  nearest-first with unsited last (exercise the resolved-anchor path).
- **Widget — picker:** with `diveLocation` set, sites sort by the dive anchor and the
  dive header string shows; with `diveLocation == null` and `currentLocation` set,
  falls back to device sorting and the original header.
- **Widget — `SiteEditPage` seed:** `initialLocation` seeds lat/lng without setting
  `_hasChanges`; an overridden `locationServiceProvider` returns a placemark and only
  the empty country/region get filled (pre-typed values survive). No live network.
- **Widget — router:** `/sites/new` with a `GeoPoint` `extra` yields
  `initialLocation`; with no `extra`, `initialLocation` is null.
- **Widget — `_showSitePicker`:** a GPS dive passes the anchor to the sheet and
  `extra` to the push; a GPS-less dive passes neither.
- Follow project conventions: SettingsNotifier mocks kept in sync; geocode overridden
  via provider; Drift/fakeasync awaits wrapped where needed.

## Localization

- New string `diveLog_sitePicker_sortedByDiveDistance` ("Sorted by distance from this
  dive") added to `app_en.arb` and all non-English locales
  (`ar, de, es, fr, he, hu, it, nl, pt, zh`), then regenerate localizations.
- Any additional distance-unit strings introduced by `formatGeoDistance` follow the
  same all-locales rule (minimized per Open item 2).

## Non-goals (YAGNI)

- No DB/schema change, no migration.
- No changes to the post-download **site-match review** flow or the **dive-detail**
  Surface GPS section.
- No new distance surfaces beyond this picker.
- The 50 km "nearby" highlight threshold is unchanged.
- Seeding does not populate depth/difficulty/etc. — only coordinates and (best-effort)
  country/region.

## Open items (resolve during planning)

1. **Prefill dives:** confirm whether `DivePrefill` (`dive_edit_page.dart:112`) exposes
   entry/exit GPS. If it does, extend the anchor to
   `_existingDive?.entry ?? _existingDive?.exit ?? prefill?.entry ?? prefill?.exit`;
   if not, `_existingDive` is the sole source and new/manual dives use the device
   fallback (acceptable).
2. **`formatGeoDistance` output shape:** decide symbol-embedded string vs l10n
   `{value} away` phrasing, to minimize new localized keys while keeping the existing
   "away" tone. Prefer the shape that adds the fewest new strings.
3. **Header icon:** pick the dive-anchored header icon (e.g. `Icons.place` /
   `Icons.scuba_diving`) for the `diveLocation != null` case.
