# Country flags beside dive site locations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a small, optional flag beside a site's location on the site list, site details, dive details, trip list and trip details (issue #4426).

**Architecture:** A pure resolver in `lib/core/geography/` turns a site's free-text country into an ISO alpha-2 code from a generated CLDR name table plus a hand-kept alias list; Safety's emergency region switches to it. One `CountryFlag` widget (backed by the `country_flags` package) draws a flag for a code, and every surface goes through a setting-aware wrapper so the synced per-diver `showCountryFlags` switch hides all of them. Trip flags come from one batched query over the same dive set the trip dive count uses.

**Tech Stack:** Flutter, Riverpod, drift (SQLite), `country_flags` (MIT, `jovial_svg`), CLDR JSON (`cldr-json`), Python 3 for the generator.

**Spec:** `docs/design/specs/2026-11-10-site-country-flags-design.md`

## Global Constraints

- No flag, and no placeholder, when the country text does not resolve. A wrong flag is worse than none: exact (folded) matches only, never substring or fuzzy.
- Flag size: 16x11 logical pixels in list rows; height matched to the line's text in headers; 2px corner radius; hairline outline (0.5px, `colorScheme.outlineVariant`).
- The flag beside a visible country name is excluded from semantics. Trip flags (no country name beside them) carry a semantic label and tooltip listing the country names.
- `showCountryFlags` defaults to true, syncs per diver, and hides every flag on every surface.
- Trip flags use the trip dive count's dive set: `tripDivesJoinSql` plus `DiveStatsScope.and`, scoped to the current diver. Ordered by dive count descending, ties by earliest dive. Trip list shows at most 3 flags then "+N"; trip details shows all.
- On site details the flag replaces the `location_on_outlined` pin; the pin returns when there is no flag.
- Every new string is added to all 11 ARB files (`en es fr de it nl pt hu ar he zh`) and regenerated with `flutter gen-l10n`.
- Settings are read with `settingsProvider.select(...)` or a dedicated provider (the `settings_watch_scanner` architecture test).
- No em-dash characters anywhere (code, comments, docs, commits).
- Before each commit: `dart format .`, `flutter analyze`, the affected tests, and `flutter test test/architecture/` when files under `lib/` were added. Never the whole suite.

## Review Focus

1. **Names that contain a country but are not one** ("Gulf of Mexico", "Mexico City", "Red Sea, Egypt"): no flag. Pinned in Task 2.
2. **Whitespace, case and accents** ("  méxico ", "MEXICO", "Mexique", "Curacao" vs "Curaçao"): resolve. Pinned in Task 2.
3. **A name meaning different countries in two languages:** dropped from the table, so no flag. Pinned in Task 1 (generator) and Task 2.
4. **Shared trip with another diver's dives in another country:** the current diver sees only their own countries. Pinned in Task 7.
5. **Long location line in a narrow phone row with a flag:** the text still ellipsizes, and the flag never wraps onto its own line. Pinned in Task 5.

---

### Task 1: CLDR country name table and its generator

**Files:**
- Create: `scripts/geography/generate_country_names.py`
- Create: `scripts/geography/generate_country_names_test.py`
- Create (generated, committed): `lib/core/geography/country_names.generated.dart`

**Interfaces:**
- Produces: `const Map<String, String> cldrCountryNameCodes` (folded name to alpha-2) and `const Map<String, String> alpha3ToAlpha2` in `country_names.generated.dart`, plus `const Set<String> assignedAlpha2Codes`.

- [ ] **Step 1: Write the failing Python tests**

`test_folds_case_and_accents` (`fold("  Curaçao ") == "curacao"`), `test_drops_names_mapping_to_two_codes` (given two locales mapping "x" to "AA" and "BB", the output has no "x"), `test_keeps_only_assigned_codes` (territory keys "EU", "UN", "QO", "001" and anything with a digit are excluded; "MX" kept), `test_includes_alt_short_and_alt_variant` (`"GB-alt-short": "UK"` adds "uk" to GB), `test_adds_official_language_names` (given territoryInfo where MV has `dv` with `_officialStatus: "official"`, the Dhivehi name of MV from the `dv` locale maps to MV, and a non-official language of MV adds nothing).

- [ ] **Step 2: Run** `python3 -m pytest scripts/geography/generate_country_names_test.py -v`. Expected: FAIL (module missing).

- [ ] **Step 3: Implement the generator.** Download pinned `cldr-json` release files over HTTPS: `cldr-localenames-full/main/<lang>/territories.json` for the 11 place-name languages and `cldr-core/supplemental/codeMappings.json` (alpha3). Then, from `cldr-core/supplemental/territoryInfo.json`, every language with an `_officialStatus` (`official`, `de_facto_official`, `official_regional`) for a territory: fetch that locale's `territories.json` (skip a locale CLDR does not ship) and add only that territory's own name from it. Pin the version as a constant at the top. Assigned codes are the territory keys that have an `alpha3` in codeMappings. The fold must equal Dart's `textSortKey` from `lib/core/text/text_sort.dart` (read `fuzzy.normalize` and mirror it; Task 2's parity test enforces this). Write sorted maps so regeneration is diff-stable; the file header says it is generated, by which script, and from which CLDR version.

- [ ] **Step 4: Run tests** (PASS), then run the generator and check the Dart file compiles: `python3 scripts/geography/generate_country_names.py && flutter analyze lib/core/geography`.

- [ ] **Step 5: Commit** `feat(geography): generate CLDR country name table`

### Task 2: Country code resolver

**Files:**
- Create: `lib/core/geography/country_code.dart`
- Test: `test/core/geography/country_code_test.dart`

**Interfaces:**
- Consumes: Task 1's maps; `textSortKey` from `lib/core/text/text_sort.dart`.
- Produces: `String? countryCodeFor(String? text)`, which returns an upper-case assigned alpha-2 code or null.

- [ ] **Step 1: Write the failing tests.** Expectations: `'Mexico'`, `'  méxico '`, `'MEXIQUE'`, `'Messico'`, `'墨西哥'`, `'mx'`, `'MEX'` give `'MX'`. `'UK'`, `'England'`, `'Scotland'`, `'Wales'`, `'Northern Ireland'` give `'GB'`. `'Holland'` gives `'NL'`. `'Bonaire'`, `'Sint Eustatius'`, `'Saba'` give `'BQ'`. `'USA'`, `'U.S.A.'` give `'US'`. `'Czech Republic'` gives `'CZ'`. `'Curacao'` and `'Curaçao'` both give `'CW'`. `'República Dominicana'` gives `'DO'`, `'مصر'` gives `'EG'`, `'ދިވެހިރާއްޖެ'` gives `'MV'`. `null`, `''`, `'  '`, `'EU'`, `'ZZ'`, `'Gulf of Mexico'`, `'Mexico City'`, `'Red Sea, Egypt'`, `'Atlantis'` give null. A parity test: for 50 table names, `textSortKey(name)` equals the key the generator produced (guards Python/Dart fold drift).

- [ ] **Step 2: Run** `flutter test test/core/geography/country_code_test.dart`. Expected: FAIL.

- [ ] **Step 3: Implement `countryCodeFor`.** Order: blank to null; strip periods; fold with `textSortKey`; a 2-letter key that is in `assignedAlpha2Codes` returns it; a 3-letter key in `alpha3ToAlpha2` returns that; the alias map; then `cldrCountryNameCodes`. The alias map is a private const in this file holding every entry of Safety's current `_isoFromCountry` table plus the spec's additions, keyed by folded text.

- [ ] **Step 4: Run tests.** Expected: PASS.

- [ ] **Step 5: Commit** `feat(geography): resolve free-text country to ISO code`

### Task 3: Emergency region uses the shared resolver

**Files:**
- Modify: `lib/features/safety/presentation/providers/emergency_providers.dart` (delete `_isoFromCountry`, call `countryCodeFor`)
- Test: the existing emergency provider tests under `test/features/safety/`

- [ ] **Step 1: Add failing tests** to the emergency region provider tests: site country `'Mexique'` gives `'MX'`; `'UK'` gives `'GB'`; `'EU'` gives null (worldwide). Keep the existing cases.
- [ ] **Step 2: Run** the safety provider tests. Expected: the new cases FAIL.
- [ ] **Step 3: Replace** `return _isoFromCountry(country);` with `return countryCodeFor(country);` and delete the private function.
- [ ] **Step 4: Run** `flutter test test/features/safety/`. Expected: PASS (update any old case that asserted a pass-through of an unassigned code, citing the spec).
- [ ] **Step 5: Commit** `refactor(safety): resolve emergency region through shared country codes`

### Task 4: The `showCountryFlags` setting

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (`BoolColumn get showCountryFlags => boolean().withDefault(const Constant(true))();` beside `showMapBackgroundOnSiteCards`)
- Create: `lib/core/database/migrations/helpers/country_flags_migrations.dart` (`_assertShowCountryFlagsColumn()`, `_addColumnIfMissing('diver_settings', 'show_country_flags', 'INTEGER NOT NULL DEFAULT 1')`), registered as a `part` in `app_database_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (new rung), `lib/core/database/migrations/before_open_settings_columns.dart` (backstop), `lib/core/database/database.dart` (`currentSchemaVersion`, and the version comment list near line 1629)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (the three places `showMapBackgroundOnSiteCards` appears), `lib/features/settings/presentation/providers/settings_providers.dart` (field default `true`, constructor, `copyWith`, `setShowCountryFlags`, `showCountryFlagsProvider`), `lib/core/services/sync/sync_data_serializer.dart` (default `'showCountryFlags': true`), `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`, `lib/features/settings/presentation/widgets/appearance_settings_tiles.dart` (`AppearanceGeneralTiles`: a `SwitchListTile` with `Icons.flag_outlined` after the trend-gaps tile, so it sits in the main Appearance page's General group rather than one feature's sub-page, since it covers sites, dives and trips)
- Modify: all 11 `lib/l10n/arb/app_*.arb`: `settings_appearance_countryFlags_title` ("Country flags"), `settings_appearance_countryFlags_subtitle` ("Show a small flag beside site locations and trips"), `settings_conflict_field_showCountryFlags` ("Country flags")
- Modify: test fakes that override the settings notifier setters (`test/helpers/mock_providers.dart` and the three page tests that override `setShowMapBackgroundOnSiteCards`) when the notifier interface requires it
- Test: the migration test for the ladder, the diver settings repository test, the appearance page test

**Interfaces:**
- Produces: `final showCountryFlagsProvider = Provider<bool>(...)` (selects `s.showCountryFlags`); `SettingsNotifier.setShowCountryFlags(bool)`.

- [ ] **Step 1: Pick the schema version.** Main holds 357. Check open PRs that bump `currentSchemaVersion` (`gh pr list --state open --search currentSchemaVersion` and `gh pr diff` on likely ones); take the next free number and say why in the rung comment, as the existing rungs do.
- [ ] **Step 2: Write failing tests:** migrating from the previous version adds `show_country_flags` with every existing row reading true; repository round-trips false; appearance page shows the switch and toggling it calls `setShowCountryFlags(false)`; conflict catalogue has a `showCountryFlags` entry.
- [ ] **Step 3: Run** them. Expected: FAIL.
- [ ] **Step 4: Implement** following `showMapBackgroundOnSiteCards` everywhere it appears; run `dart run build_runner build --delete-conflicting-outputs` and `flutter gen-l10n`. Defaulted column with no backfill, so the sync compatibility floor does not move.
- [ ] **Step 5: Run** the tests above plus `test/architecture/`. Expected: PASS.
- [ ] **Step 6: Commit** `feat(settings): add a switch for country flags`

### Task 5: `CountryFlag` and the setting-aware location row

**Files:**
- Modify: `pubspec.yaml` (`country_flags: ^4.1.2`; run `flutter pub get`)
- Create: `lib/shared/widgets/country_flag.dart`
- Test: `test/shared/widgets/country_flag_test.dart`

**Interfaces:**
- Consumes: `countryCodeFor` (Task 2), `showCountryFlagsProvider` (Task 4).
- Produces:
  - `class CountryFlag extends StatelessWidget { const CountryFlag({required String code, double height = 11}) }`: width is `height * 16 / 11`, 2px radius, hairline outline, wrapped in `ExcludeSemantics`.
  - `class LocationWithFlag extends ConsumerWidget { const LocationWithFlag({required String? country, required Widget text, Widget? fallbackLeading, double flagHeight = 11, double gap = 4}) }`: a `Row(mainAxisSize: min)` of the flag (when the setting is on and `countryCodeFor(country)` is non-null) or `fallbackLeading` (otherwise), then `Flexible(child: text)`. The row uses `CrossAxisAlignment.start` and the leading widget is vertically centred on the text's first line (the dive hero header's location wraps onto two lines on a phone), and the text keeps its own `maxLines`/overflow.

- [ ] **Step 1: Write failing widget tests:** known country with setting on shows a `CountryFlag` with code `'MX'`; setting off shows `fallbackLeading` and no flag; unknown country shows `fallbackLeading`; the flag has no semantics node; at a 320px width a 200-character location ellipsizes on one line and the flag stays on the same line (Review Focus 5).
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement** with `country_flags` (`CountryFlag.fromCountryCode` and its `theme` sizing in 4.x; read the package's README for the exact 4.x API).
- [ ] **Step 4: Run** the tests and `test/architecture/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): add a country flag widget`

### Task 6: Flags on site and dive surfaces

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_tile.dart`, `compact_site_list_tile.dart` (subtitle slot: wrap in `LocationWithFlag` only when the subtitle field is `SiteField.location` or `SiteField.country`), `dense_site_list_tile.dart` (its `location` text)
- Modify: `lib/features/dive_sites/presentation/widgets/site_detail_header.dart` (`LocationWithFlag` with `fallbackLeading` = the existing 20px `Icons.location_on_outlined`, gap 8, flag height matched to `bodyLarge`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_hero_header.dart` and `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_embedded_header.dart` (the `locationString` line, no fallback)
- Test: the existing widget tests for each of these files

- [ ] **Step 1: Add failing tests** per widget: a site with country `'Mexico'` renders one `CountryFlag`; with `showCountryFlagsProvider` overridden to false it renders none; `SiteDetailHeader` renders the pin when the country is `'Atlantis'` or the setting is off, and no pin when a flag shows. Compact/detailed tiles with a non-location subtitle field show no flag.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the affected tests. Expected: PASS.
- [ ] **Step 5: Commit** `feat(dive-sites): show country flags on sites and dives`

### Task 7: Trip country codes

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (new method)
- Modify: `lib/features/trips/presentation/providers/` trip providers file (new provider)
- Test: `test/features/trips/data/repositories/trip_repository_test.dart` (or the existing repository test file), provider test

**Interfaces:**
- Produces: `Future<Map<String, List<TripCountry>>> getTripCountries({String? diverId})` where `class TripCountry { final String code; final String name; }` (`name` is the first stored country text seen for that code, for the tooltip). One SQL query: `trips t` joined with `tripDivesJoinSql(tripAlias: 't', diveAlias: 'd', joinKind: 'INNER', extraOn: <same diver and DiveStatsScope clause as getAllTripsWithStats>)`, then `JOIN dive_sites s ON s.id = d.site_id`, grouped by `t.id, s.country`, selecting `COUNT(DISTINCT d.id)` and `MIN(d.entry_time)` (use whichever dive time column `getAllTripsWithStats`' neighbours order by). Resolution, merging rows that resolve to the same code, and ordering happen in Dart.
- Produces: `final tripCountriesProvider = FutureProvider<Map<String, List<TripCountry>>>` keyed to the validated current diver, invalidated on dive, site and trip changes the same way the trip list provider is.

- [ ] **Step 1: Write failing repository tests:** a trip with 3 Mexico dives and 1 Belize dive gives `[MX, BZ]`; "Mexico" and "México" on two sites merge into one MX; a site with "Atlantis" contributes nothing; a parent trip includes its side trip's countries; on a shared trip another diver's Egypt dive is not in the current diver's list (Review Focus 4); a dive excluded by `DiveStatsScope` contributes nothing; a tie in count orders by earliest dive.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the trip repository and provider tests and `test/architecture/` (provider tick and disposal scanners). Expected: PASS.
- [ ] **Step 5: Commit** `feat(trips): load each trip's countries`

### Task 8: Flags on trip surfaces

**Files:**
- Create: `lib/features/trips/presentation/widgets/trip_country_flags.dart`
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart` (`TripListTile`), `compact_trip_list_tile.dart`, `dense_trip_list_tile.dart` (after the trip name), the trip Overview tab's large title block ("Malta and Gozo 2026" with the plane icon and the date line below it; find it from `trip_overview_tab.dart`), which shows at every width. Not the app bar or pane title: on a phone the app bar title already truncates, and flags there would cost name characters
- Modify: all 11 ARB files: `trips_countryFlags_more` ("+{count}"), `trips_countryFlags_semantics` ("Countries: {names}")
- Test: `test/features/trips/presentation/widgets/trip_country_flags_test.dart` and the existing tile and detail page tests

**Interfaces:**
- Consumes: `tripCountriesProvider`, `CountryFlag`, `showCountryFlagsProvider`.
- Produces: `class TripCountryFlags extends ConsumerWidget { const TripCountryFlags({required String tripId, int? maxFlags}) }`. Renders nothing when the setting is off, the data is loading or the list is empty; otherwise up to `maxFlags` flags (all when null) 2px apart, then "+N" in `bodySmall` `onSurfaceVariant` when more remain, the whole group in one `Semantics(label: ...)` and `Tooltip` naming every country.

- [ ] **Step 1: Write failing tests:** 5 countries with `maxFlags: 3` show 3 flags and "+2"; `maxFlags: null` shows 5 and no "+N"; setting off shows nothing; semantics label lists all 5 names; each trip tile variant passes `maxFlags: 3`; the detail page header passes null.
- [ ] **Step 2: Run.** Expected: FAIL.
- [ ] **Step 3: Implement**, then `flutter gen-l10n`.
- [ ] **Step 4: Run** the affected tests and `test/architecture/`. Expected: PASS.
- [ ] **Step 5: Commit** `feat(trips): show country flags on trips`

---

## Follow-up tasks (stored country code)

### Task F1: `dive_sites.country_code` and its backfill
- `DiveSites.countryCode` (`text().nullable()`), schema v360 rung with
  `_assertSiteCountryCodeColumn()` (beforeOpen backstop too) and a rung-only
  backfill that sets `country_code = countryCodeFor(country)` where it is null.
- `DiveSite.countryCode` with `copyWith(countryCode:, clearCountryCode:)`,
  props, the row mapper and every repository companion that writes `country`.
- `DiveSite.flagCountryCode` getter: `countryCode ?? countryCodeFor(country)`.
- Tests: migration from v359 backfills a recognised country, leaves an
  unrecognised one null, keeps an existing code; repository round-trip.

### Task F2: geocoding carries the code
- `PlaceLookup.countryCode` and `LocationResult.countryCode`; native from
  `Placemark.isoCountryCode`, web from `address['country_code']`, upper-cased.
- `mergeLocationDetails` writes the code whenever it writes the country;
  `applyLocationDetails` stores it.
- Site editor: a geocoded country keeps the geocoder's code; a hand-edited
  country recomputes it with `countryCodeFor` (null when unrecognised).
- Tests for each rule.

### Task F3: lookups prefer the stored code
- `LocationWithFlag` takes `countryCode` and prefers it over `country`.
- Site tiles, site details and the dive header pass the site's code.
- `TripCountryQueries` reads `s.country_code`; the tally prefers it.
- `DiveSummary.siteCountryCode`; `emergencyRegionProvider` prefers it.
- Tests: a site whose text is unrecognised but whose code is stored shows its
  flag, counts toward its trip, and picks its emergency region.
