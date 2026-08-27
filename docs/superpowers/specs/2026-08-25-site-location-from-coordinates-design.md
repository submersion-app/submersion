# Dive Site Location From Coordinates: Design

> **Schema version:** the column landed as **v166**, not v162. `origin/main`
> claimed v163 while this branch was open and v164/v165 were reserved for two
> other open PRs, so the migration, helper, ladder entry and test were
> renumbered in the merge commit. Every "v162" below is the number as planned.

**Status:** approved 2026-08-25
**Issue:** #1187
**Branches:** `worktree-issue-1187-site-field-wipe` (PR A, bounded fix) and
`worktree-issue-1187-site-geocoding` (PR B, this design)
**Supersedes nothing.** Extends the reverse-geocoding introduced in v1.1 and
the English pin from issue #214 (PR #784).

## Problem

Issue #1187 (Android 1.7.5.6566, German UI) bundles three complaints:

1. Picking coordinates fills only Country and Region. Town and body of water
   stay empty even though the picker preview already shows the town
   ("Weggis, Luzern, Switzerland"). Island is also empty.
2. The filled names are English ("Switzerland" in a German UI).
3. The reporter's stated real reason for the report: site data they entered
   by hand, including how difficult each site is, disappears and is then
   missing on both their Windows and Android devices. They assumed sync.

## Findings

Every claim below was verified by reading the cited lines in this worktree
and, for the OpenStreetMap ones, by querying Nominatim with the reporter's own
coordinates (47.027631, 8.400640).

**F1. The data loss is a local whole-row overwrite, not sync.** Sync
serialises and applies every `dive_sites` column with full-row
`toJson`/`fromJson` (`sync_data_serializer.dart:4556`, `:2419`), merged
per row by HLC. The wipe happens earlier:
`dive_repository_impl.dart:3000` and `:3359` build `dive.site` with 9 of the
entity's 24 fields (no `difficulty`, `waterType`, `minDepth`, `city`,
`island`, `bodyOfWater`, `hazards`, `accessNotes`, `mooringNumber`,
`parkingInfo`, `entryMethod`, `exitMethod`, `isShared`).
`altitude_resolver.dart:56` does `site.copyWith(altitude: meters)` on that
partial entity and `dive_altitude_enricher.dart:41` hands it to
`SiteRepository.updateSite`, whose `_writeSiteUpdate`
(`site_repository_impl.dart:173-196`) writes every column unconditionally.
`dive_edit_page.dart:4104` (altitude autofill) and `:2255` (photo GPS
write-back) do the same. The row is marked pending with a fresh HLC, so the
other device accepts the wipe as a newer edit. That is "missing from both".
The trigger is ordinary: import or edit any dive at a site that has no
stored altitude. "How difficult each dive site is" is the `difficulty`
column, one of the wiped ones.

**F2. Town is already returned and then discarded.**
`LocationService.reverseGeocode` (`location_service.dart:224`) returns
`(country, region, locality)`; the web path maps
`city ?? town ?? village` into `locality` (`:268-312`).
`site_edit_page.dart` fills only `country` and `region` in all three flows
(`_geocodeSeed` `:210`, `_useMyLocation` `:1379`, `_pickFromMap` `:1429`).
`LocationPickerMap` returns `locality` in `PickedLocation` and the page
ignores it.

**F3. Body of water is available for lakes and bays, not for seas.**
Nominatim's default (address) layer never mentions water. With
`layer=natural`, the reporter's point returns class `water`, type `lake`,
name "Lake Lucerne" (English) or "Vierwaldstättersee" (German). A point in
the middle of the same lake returned class `natural`, type
`mountain_range`, "Urner Alps", so the result must be filtered by class.
Open-sea points (Cozumel, Ras Mohammed) return "Unable to geocode" on the
natural layer because OpenStreetMap does not map oceans as polygons.

**F4. Island has no reliable source.** Bonaire came back as
`municipality`, Cozumel as `county`, Sa Dragonera (Mallorca) as nothing.
There is no `island` address key to read. Guessing from `municipality` or
`county` would be wrong more often than right.

**F5. The English pin is deliberate and the reason no longer fully
applies.** `location_service.dart:54-63` pins `Locale('en')` and
`accept-language=en` because issue #214 saw the platform geocoder answer in
the device locale, storing "Spanien" on one device and "España" on another,
which fragmented statistics grouping. Since then the app language became a
synced per-diver setting (`diver_settings.locale`,
`database.dart:1663`). A synced, explicit language code gives every device
of one diver the same answer, which is what #214 actually needed.

**F6. No re-lookup exists.** Geocoding fires only when a new site is seeded
from a dive's GPS, on "Use my location", and on "Pick from map", and each
fills only empty country/region. Sites created before PR #784 or by import
have no way to be enriched. The bug-campaign log
(`docs/superpowers/plans/2026-07-31-bug-campaign-log.md:61`) already notes
the missing backfill.

**F7. `SiteRepositoryImpl._mapRowToSite` (`site_repository_impl.dart:820`)
is a pure row-to-entity mapper** (no photo loading, no I/O), so it can be
shared with the dive repository without changing behaviour.

## Scope

Confirmed with the user on 2026-08-25:

- **PR A (bounded, lands first):** stop the whole-row overwrite (F1).
- **PR B (this design):** fill town and body of water from coordinates, a
  synced "place name language" setting, a per-site "Look up from
  coordinates" action, and a bulk "Fill in missing location details" action
  that only ever writes empty fields.
- Island stays a manual field (F4). The issue reply will say why.
- Body of water is filled for lakes, reservoirs, rivers, bays and straits.
  Seas are not filled (F3). The issue reply will say why.
- The bulk action never overwrites existing values. A per-site explicit
  lookup can, after confirmation.
- The place name language defaults to English so no existing user's data
  changes shape. There is no "follow app language" mode, because the app
  language can be `system`, which resolves per device and would reopen #214.

## PR A: stop wiping site fields

Not part of this spec's implementation plan; recorded here because it is the
reporter's real complaint and the two PRs share the issue.

1. Extract `_mapRowToSite` into `mapDiveSiteRow(DiveSite row)` in
   `lib/features/dive_sites/data/mappers/dive_site_row_mapper.dart` and use
   it from both `SiteRepositoryImpl` and the two sites in
   `dive_repository_impl.dart`. `dive.site` then carries every column.
2. The three write-backs stop routing a whole entity through `updateSite`.
   `AltitudeResolution.siteWriteBack` becomes `siteAltitudeWriteBack:
   ({String siteId, double altitudeMeters})?` and callers apply it with the
   existing column-patch method
   `applyImportedMetadata(siteId, DiveSitesCompanion(altitude: Value(m)))`,
   which marks the row pending and stamps HLC exactly like `updateSite`.
   `_updateSiteWithPhotoGps` patches latitude, longitude and altitude the
   same way. A targeted patch cannot clobber columns it never read.
3. Tests: a `DiveAltitudeEnricher` test seeding a site with difficulty,
   water type, city, body of water, hazards and `isShared = true` and no
   altitude, importing a dive there, asserting every field survives and
   altitude is set; a `DiveRepository.getDive` test asserting `dive.site`
   carries `difficulty` and the other previously missing fields.
4. Data already lost is not recoverable by code. The issue reply says so.

## PR B design

### 1. LocationService contract

`reverseGeocode` returns a `PlaceLookup` value and takes a required
language code:

```dart
class PlaceLookup {
  const PlaceLookup({this.country, this.region, this.locality, this.bodyOfWater});
  final String? country;
  final String? region;
  final String? locality;
  final String? bodyOfWater;
  bool get isEmpty;
}

Future<PlaceLookup> reverseGeocode(
  double latitude,
  double longitude, {
  required String languageCode,
});
```

- Address lookup keeps its shape: on mobile the `geocoding` placemark with
  `Locale(languageCode)`, falling back to Nominatim
  `/reverse?format=json&zoom=10&accept-language=<code>` with the existing
  key fallbacks (`state ?? province ?? region`, `city ?? town ?? village`).
  The `Accept-Language` header carries the same code.
- Body of water is a second, web-only request:
  `/reverse?format=json&zoom=14&layer=natural&accept-language=<code>`.
  The hit is accepted only when `class == 'water'` (any type: lake,
  reservoir, river, ...) or `class == 'natural'` with `type` in
  `{bay, strait}`. Everything else, including "Unable to geocode", yields
  `bodyOfWater: null`. The name comes from the response's `name` field. A
  failure in this request never discards the address result; it is logged
  and the lookup returns without a body of water.
- A single `_NominatimThrottle` inside the service delays every Nominatim
  request so that consecutive requests are at least one second apart. It
  uses `clock.now()` so fakeAsync tests can drive it. This one mechanism
  covers the two-request interactive lookup and the bulk pass.
- `buildReverseGeocodeUri` gains `languageCode`; a new
  `buildNaturalFeatureUri` builds the natural-layer URI. Both stay public
  so tests can pin them.
- `forwardGeocode` (dive centres only) is unchanged.
- The parameter is required so no caller can silently keep the old pin.
  Callers: `site_edit_page`, `location_picker_map` (whose `PickedLocation`
  gains `bodyOfWater`), `region_download_dialog` (reads the provider),
  `uddf_entity_importer` (receives the code through its constructor from
  the provider that builds it), and `getCurrentLocation` (which takes the
  same parameter and forwards it).

### 2. Place name language setting

- Column: `diver_settings.place_name_language TEXT NOT NULL DEFAULT 'en'`.
- Migration v162: `_assertPlaceNameLanguageColumn()` guarded by
  `PRAGMA table_info('diver_settings')`, no-op when the table is absent,
  modeled on `_assertGasModelColumn`. `currentSchemaVersion` becomes 162
  and 162 is appended to `migrationVersions`. Ladder step follows the v161
  block at `database.dart:8534`. Test
  `test/core/database/migration_v162_place_name_language_test.dart` with
  the four standard cases (upgrade adds the column with default `'en'`,
  fresh DB has it, helper no-ops without the table, ladder contains 162).
- `AppSettings.placeNameLanguage` (String, default `'en'`), `copyWith`,
  `SettingsNotifier.setPlaceNameLanguage`, and a
  `placeNameLanguageProvider` selector, all following `coordinateFormat`.
- `DiverSettingsRepository`: insert companion, update companion, and row
  mapping. The mapping falls back to `'en'` when the stored code is not one
  of the app's supported language codes, so a value from a newer peer
  cannot put an unknown code into `accept-language`.
- Sync: `_applyDiverSettingDefaults` gets `'placeNameLanguage': 'en'` with
  a `// v162:` comment so payloads from older peers hydrate. Add a case to
  `test/core/services/sync/sync_diver_settings_fallback_test.dart`.
  Export and import are full-row; nothing else changes.
- UI: one `_buildUnitTile` row in `settings_page.dart` beside Coordinate
  format. Title "Place name language", value = the language's native name,
  subtitle "Used when country, region, town and body of water are looked up
  from coordinates. Existing sites are not changed." The picker lives in
  `lib/features/settings/presentation/widgets/place_name_language_picker.dart`
  following `coordinate_format_picker.dart` (a `show...Picker` function, a
  testable list widget, a `placeNameLanguageLabel` function). Options are
  `LanguageSettingsPage.supportedLocales` minus `system`, so there is no
  second hand-maintained language list.

### 3. Site form

- `LocationSection` gains a third action, "Look up from coordinates",
  enabled only while both latitude and longitude parse as valid numbers.
  The helper text becomes "Choose a location method or look up the
  coordinates to auto-fill country, region, town and body of water".
- `site_edit_page` replaces the duplicated fill-empty code in
  `_geocodeSeed`, `_useMyLocation` and `_pickFromMap` with one
  `_applyPlaceLookup(PlaceLookup lookup, {required bool overwrite})` that
  writes `country`, `region`, `city` (from `locality`) and `bodyOfWater`.
  With `overwrite: false` only empty controllers change. The seed path
  keeps its `_isApplyingInitialValues` wrapper so it does not dirty the
  form; the other paths set `_hasChanges` only when a controller changed.
- `_lookupFromCoordinates()`: parse the controllers, show the existing
  "getting location" busy state, call the service with the diver's place
  name language, then `_applyPlaceLookup(overwrite: false)`. Outcomes:
  - at least one field filled: done, form dirty;
  - nothing empty and at least one found value differs from the current
    one: a dialog lists the found values (only the differing fields) with
    Replace and Keep; Replace calls `_applyPlaceLookup(overwrite: true)`;
  - lookup returned nothing: snackbar "No location details found for these
    coordinates";
  - exception: error snackbar with the existing wording style.
- `LocationPickerMap` passes the language to its preview and confirm
  lookups and returns `bodyOfWater` in `PickedLocation`.
- The save path is unchanged. It never geocodes (the v1.5.6 guarantee that
  a manually cleared Region stays cleared stands, and the existing tests
  for Grand Turk and Bonaire keep passing).

### 4. Bulk backfill

- `mergeMissingLocationDetails(current, found)` in
  `lib/features/dive_sites/domain/services/site_location_merge.dart`: a
  pure function over four nullable strings that returns the values to write
  (only where `current` is null or blank and `found` is non-blank) or null
  when there is nothing to write. Both the form's fill-empty path and the
  bulk service use it, so the "only empty" rule has one home.
- `SiteRepository.fillMissingLocationDetails(String siteId, PlaceLookup
  found)`: reads the row, calls the merge function, writes only the
  returned columns through a `DiveSitesCompanion` in one transaction,
  marks the row pending, notifies the sync event bus, and returns whether
  anything changed. The site edit page does not use it (it works on
  controllers); the bulk service does.
- `SiteLocationBackfillService` in
  `lib/features/dive_sites/domain/services/site_location_backfill_service.dart`
  depends on `SiteRepository`, `LocationService` and the language code.
  `run({required diverId, required onProgress, required isCancelled})`:
  1. Select the diver's sites that have coordinates and at least one empty
     target field (country, region, city, bodyOfWater). Report `total`.
  2. For each site, in order: if `isCancelled()` stop; look up; call
     `fillMissingLocationDetails`; report progress.
  3. Per-site failures are logged, counted as failed, and the run
     continues. A `SocketException` on the first request aborts the run
     with an "offline" outcome so the user is not shown 104 failures.
  4. Return `BackfillSummary(updated, unchanged, failed, cancelled)`.
- `siteLocationBackfillProvider`: a notifier holding `idle | running(done,
  total) | finished(summary)`. Starting while running is a no-op. The
  dialog reads it, so rebuilds and navigation do not lose the run.
- UI on the sites list overflow menu: "Fill in missing location details…".
  Confirmation dialog: "Looks up N sites on OpenStreetMap and fills only
  empty country, region, town and body of water fields. Takes about M
  minutes." (M from N at two seconds per site.) Then a progress dialog
  with a linear indicator, "12 of 104", and Cancel. Then a summary
  snackbar: "Updated X sites, Y unchanged, Z failed".

### 5. Localisation and documentation

- Every new string is added to all 11 ARB files
  (`ar, de, en, es, fr, he, hu, it, nl, pt, zh`).
- No release note is written in the PR; release notes are assembled at
  release time from the merged PRs.
- After both PRs merge, reply on #1187 with: the cause of the data loss
  and that lost values cannot be recovered by the app; town and body of
  water now fill; island has no OpenStreetMap source; seas are not mapped
  as areas so body of water works for lakes, reservoirs, rivers, bays and
  straits; the new language setting and why its default is English; the
  bulk action for their 100+ sites.

## Testing

- `location_service_test`: language code in reverse URI, header and native
  locale; natural-layer URI; filter accepts lake and bay, rejects
  mountain range and saddle and "Unable to geocode"; natural-layer HTTP
  failure keeps the address result; throttle spaces two requests one
  second apart under fakeAsync.
- Migration v162 ladder test; `DiverSettingsRepository` round-trip and
  unknown-code fallback; sync older-peer defaults; picker widget test;
  settings row shows the native language name.
- `site_edit_page` tests: explicit lookup fills only empty fields; Replace
  dialog path replaces, Keep leaves fields alone; "nothing found" snackbar;
  pick-from-map now fills town and body of water (regression for the
  discarded `locality`); the existing Grand Turk and Bonaire tests are
  unchanged.
- `mergeMissingLocationDetails` unit tests (blank vs null, nothing to
  write).
- `SiteLocationBackfillService` tests with a fake repository and fake
  location service: selection excludes sites without coordinates and sites
  with every field filled; only empty columns are written; cancel between
  sites; a failing site is counted and the run continues; offline abort;
  summary counts.
- Sites-list dialog widget test: confirmation text, progress updates,
  summary snackbar.

## Out of scope

- Filling island (F4).
- Seas and oceans as body of water (F3).
- Localising `SiteDifficulty.displayName`, which is hard-coded English
  today; unrelated to this issue.
- Field-level sync merging for sites (today the higher HLC wins the whole
  row). Worth its own issue; not what the reporter hit.
- Re-geocoding existing values after changing the place name language. The
  setting's subtitle says existing sites are not changed; the per-site
  Replace dialog covers individual corrections.
