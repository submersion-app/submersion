# Country flags per list Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single Country flags switch with one switch per section (Sites, Dives, Buddies, Trips), and draw flags on dive cards and as a badge on buddy avatars (issue #5001).

**Architecture:** Three new boolean columns on `diver_settings` (v388), seeded from the existing switch by the rung and, for rows new to a device, by the sync apply path. A `FlagSection` enum routes every flag through its section's switch in `lib/shared/widgets/country_flag.dart`. Each section's appearance page hosts its own switch tile.

**Tech Stack:** Flutter, Drift, Riverpod, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-11-27-per-list-country-flags-design.md`

## Global Constraints

- The existing column `show_country_flags`, its Dart names (`showCountryFlags`, `setShowCountryFlags`, `showCountryFlagsProvider`) and its sync and conflict key `showCountryFlags` stay as they are and now mean Sites only. Renaming would break every fake `SettingsNotifier` that overrides the setter.
- New columns: `show_dive_country_flags`, `show_buddy_country_flags`, `show_trip_country_flags`, each `INTEGER NOT NULL DEFAULT 1 CHECK (<col> IN (0, 1))`. Dart: `showDiveCountryFlags`, `showBuddyCountryFlags`, `showTripCountryFlags`.
- Schema 388; `minimumCompatibleSchemaVersion` does not move.
- The rung copies, `beforeOpen` only asserts. No `updated_at` or HLC stamp.
- New rungs and helpers go in `lib/core/database/migrations/`, columns in `lib/core/database/tables/diver_tables.dart`; `database.dart` only gets the version bump and the `migrationVersions` entry.
- Every new string in all 11 ARB files, then `flutter gen-l10n`.
- No em-dashes anywhere. Run only the test files written or changed, by path.

## Review Focus

1. A device set up fresh pulls settings an older peer published with flags off: all four switches must come out off. (Task 2)
2. An upgraded device that already holds the row receives an older peer's row: its own per-section values must survive. (Task 2)
3. The rung runs on a database that already carries a new column (an earlier partial upgrade): that column's value must not be overwritten. (Task 1)
4. A partial migration fixture with no `show_country_flags` column: the rung must not throw. (Task 1)
5. A compact dive card whose title slot is not the site, or a dive whose site has no recognised country: no flag and no gap. (Task 4)

---

### Task 1: Settings storage and model

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (after `showCountryFlags`)
- Create: `lib/core/database/migrations/helpers/country_flag_switches_migrations.dart` (a `part of '../app_database_migrations.dart'`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (add the `part`)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (v388 rung)
- Modify: `lib/core/database/migrations/before_open_settings_columns.dart` (v388 backstop)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 388`, `migrationVersions` entry 388)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (fields, constructor, `copyWith`, setters, providers)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (the three companion and row mappings beside `showCountryFlags`)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`
- Modify: every ARB file (conflict labels), `test/helpers/mock_providers.dart` and any fake notifier `flutter analyze` flags
- Test: `test/core/database/migration_v388_country_flag_switches_test.dart` (new), `test/features/settings/data/repositories/diver_settings_repository_country_flags_test.dart`, `test/features/settings/presentation/providers/country_flags_setter_test.dart`, `test/features/settings/presentation/providers/every_setter_waits_for_load_test.dart`, `test/features/settings/presentation/conflicts/profile_color_fields_test.dart`

**Interfaces:**
- Produces: `AppSettings.showDiveCountryFlags`, `.showBuddyCountryFlags`, `.showTripCountryFlags` (bool, default `true`); `SettingsNotifier.setShowDiveCountryFlags(bool)`, `setShowBuddyCountryFlags(bool)`, `setShowTripCountryFlags(bool)` (through `_update`); `showDiveCountryFlagsProvider`, `showBuddyCountryFlagsProvider`, `showTripCountryFlagsProvider` (`Provider<bool>`, selecting from `settingsProvider`); conflict keys `showDiveCountryFlags`, `showBuddyCountryFlags`, `showTripCountryFlags`.

- [ ] **Step 1: Write the failing migration test** modelled on `migration_v387_ccr_setpoint_switch_test.dart`, with a fixture `dbAt(387, {bool? flags, bool withNewColumns = false})` that creates `diver_settings (id, diver_id[, show_country_flags][, the three new columns])`:
  - `v388 is in the ladder and keeps the floor`: `migrationVersions` contains 388, floor is not 388.
  - `upgrading copies flags off into every new switch`: `show_country_flags = 0` gives `{0, 0, 0}` for the three new columns.
  - `upgrading copies flags on`: `show_country_flags = 1` gives `{1, 1, 1}`.
  - `a database already carrying a new column keeps its value`: fixture with `show_dive_country_flags = 0` and `show_country_flags = 1` keeps the dive column at 0.
  - `a fixture with no show_country_flags column upgrades without throwing`: new columns read 1.
  - `the new columns are booleans`: `UPDATE ... = 2` throws.
- [ ] **Step 2: Run it** with `flutter test test/core/database/migration_v388_country_flag_switches_test.dart`; expect FAIL (388 not in ladder).
- [ ] **Step 3: Implement** the columns in `diver_tables.dart`, then in the new helper file:
  - `Future<void> _assertCountryFlagSwitchColumns()`: `_addColumnIfMissing` for each column with the DDL above. Called from `beforeOpen` and the rung.
  - `Future<void> _seedCountryFlagSwitches()`, ladder only: read `tableColumnNames(this, 'diver_settings')` once before asserting; return if the table is absent or `show_country_flags` is missing; assert the columns; then one `UPDATE diver_settings SET <col> = show_country_flags, ...` naming only the columns that were missing before the assert.
  - Rung: `if (from < 388) await _seedCountryFlagSwitches(); if (from < 388) await _assertCountryFlagSwitchColumns(); if (from < 388) await reportProgress();` with a comment in the house style naming issue #5001 and that the floor does not move.
- [ ] **Step 4: Run the migration test**; expect PASS.
- [ ] **Step 5: Extend the repository, setter, every-setter and conflict tests**: each new field defaults on, round-trips off and on through `updateSettingsForDiver`, survives `copyWith`; each setter waits for load (add the three `n.setShow...(!d.show...)` lines); `diverSettingsFields` has the three keys as `FieldKind.boolean`. Run each changed file; expect FAIL, then implement the model, setters, providers, repository mappings, conflict entries and ARB labels ("Country flags (sites)", "(dives)", "(buddies)", "(trips)" in English; translate the other 10), run `flutter gen-l10n`, and run them again; expect PASS.
- [ ] **Step 6: `flutter analyze`**, add the three setters to every fake notifier it reports, re-run until clean.
- [ ] **Step 7: Commit** `feat(settings): store a country flags switch per section`.

### Task 2: Sync seeds the new switches on rows new to a device

**Files:**
- Create: `lib/core/services/sync/diver_settings_flag_switches.dart`
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (both apply paths beside `_withDerivedDistanceUnit`; `_applyDiverSettingDefaults` gains the three keys `true`)
- Test: `test/core/services/sync/sync_diver_settings_flag_switches_test.dart` (new, modelled on `sync_diver_settings_distance_unit_test.dart`)

**Interfaces:**
- Produces: `Map<String, dynamic> withDerivedFlagSwitches(String entityType, Map<String, dynamic> data)`: for `diverSettings` only, each of the three keys that is absent or null takes `data['showCountryFlags']` when that is a bool; otherwise returns `data` unchanged.

- [ ] **Step 1: Write the failing tests** (legacy payload = an exported row with the three keys removed):
  - `a new row from an older peer with flags off arrives with every switch off` (via `upsertRecord`).
  - `the batch path derives the same` (via the batch upsert the distance unit test uses).
  - `a row this device already holds keeps its own section switches`: local row with dives off, sites on; legacy payload with `showCountryFlags: true`; dives stays off.
  - `a full payload is applied as sent`: all four keys present and different, stored verbatim.
- [ ] **Step 2: Run**; expect the first two to FAIL (columns default to on).
- [ ] **Step 3: Implement** `withDerivedFlagSwitches` and call it inside `_withDerivedDistanceUnit`'s position in both paths (after `_withLocalForOmitted`, before `_withSchemaDefaults`).
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(sync): seed per-section flag switches for settings from older peers`.

### Task 3: Every flag reads its section's switch

**Files:**
- Modify: `lib/shared/widgets/country_flag.dart`
- Modify callers: `lib/features/dive_sites/presentation/widgets/{site_list_tile,compact_site_list_tile,dense_site_list_tile,site_detail_header}.dart` (sites), `lib/features/dive_log/presentation/widgets/dive_hero_header.dart` (dives), `lib/features/buddies/presentation/pages/buddy_detail_page.dart` and `lib/features/buddies/presentation/widgets/{buddy_list_tile,compact_buddy_list_tile}.dart` (buddies), `lib/features/trips/presentation/widgets/trip_country_flags.dart` (trips)
- Test: `test/shared/widgets/country_flag_test.dart`, and the existing tests that override `showCountryFlagsProvider` for a non-site widget: `dive_hero_header_test.dart`, `trip_country_flags_test.dart`, `buddy_detail_country_test.dart`

**Interfaces:**
- Consumes: the four switch providers from Task 1.
- Produces: `enum FlagSection { sites, dives, buddies, trips }` with `ProviderListenable<bool> get switchProvider`; `String? shownFlagCode(WidgetRef ref, {required FlagSection section, required String? country, required String? code})`; `LocationWithFlag({..., required FlagSection section})`.

- [ ] **Step 1: Write the failing tests** in `country_flag_test.dart`: `each section follows only its own switch`: for each `FlagSection`, with only that section's provider off, a `LocationWithFlag` of that section draws no `CountryFlag` and one of another section does.
- [ ] **Step 2: Run**; expect FAIL (no `section` parameter).
- [ ] **Step 3: Implement** the enum and parameters, pass the section at every caller listed above (trips: `_shownCountries` watches `FlagSection.trips.switchProvider`), and move the three non-site tests' overrides to their section's provider.
- [ ] **Step 4: Run** `country_flag_test.dart` and every test file touched; expect PASS.
- [ ] **Step 5: Commit** `feat(settings): route each country flag through its section's switch`.

### Task 4: Flags on dive cards

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (`DiveListTile`: two new params `siteCountry`, `siteCountryCode`; the location line becomes `LocationWithFlag(section: FlagSection.dives, ...)`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_item.dart` (pass the summary's country fields to both tiles; correct the doc comment that says the home page's Recent dives uses this widget)
- Modify: `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart` (params `siteCountry`, `siteCountryCode`; flag before the title)
- Modify: `lib/features/dive_log/presentation/widgets/unfilled_dive_chip.dart` (`diveTileSemanticsLabel` gains optional `String? country`)
- Modify: ARB files (one key, `diveLog_listPage_siteWithCountry`: "{site}, {country}")
- Test: `test/features/dive_log/presentation/widgets/dive_list_country_flags_test.dart` (new)

**Interfaces:**
- Consumes: `FlagSection`, `shownFlagCode`, `LocationWithFlag` from Task 3.

- [ ] **Step 1: Write the failing tests** (pump `DiveListItem` with a `DiveSummary` for Blue Hole, `siteRegion: 'Lighthouse Reef'`, `siteCountry: 'Belize'`, `siteCountryCode: 'BZ'`):
  - `detailed card draws the flag beside the location` (one `CountryFlag`).
  - `compact card draws the flag before a site-name title`.
  - `compact card draws no flag when the title slot is not the site` (title slot `DiveField.maxDepth`).
  - `a site with no recognised country draws no flag` (country `Atlantis`, no code; the title's left edge matches a flagless card's).
  - `the Dives switch off hides both cards' flags`.
  - `compact card's label names the country when the flag is drawn` (`find.bySemanticsLabel` contains `Belize`).
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.** Compact rule: flag when `titleField` is `DiveField.siteName` or `DiveField.siteLocation` and `shownFlagCode(ref, section: FlagSection.dives, ...)` is non-null; laid out as `LocationWithFlag` around the title text so the flag centres on the first line. Pass the country to `diveTileSemanticsLabel` only in that case.
- [ ] **Step 4: Run** the new file plus `dive_tile_title_wrap_test.dart` and `compact_dive_list_tile_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): show the site's country flag on dive cards`.

### Task 5: Flag badge on buddy avatars

**Files:**
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_tile.dart` (badge on `_BuddyAvatar`; the subtitle no longer wraps in `LocationWithFlag`; row semantics label adds the country when the badge draws)
- Modify: ARB files (one key, `buddies_listTile_semanticsWithCountry`: "{name}, {country}")
- Test: `test/features/buddies/presentation/widgets/buddy_list_tile_country_test.dart`

**Interfaces:**
- Consumes: `shownFlagCode(ref, section: FlagSection.buddies, ...)` from Task 3.

- [ ] **Step 1: Rewrite the standard-row tests** (keep the compact-row ones as they are):
  - `a standard row with an email subtitle draws one flag on the avatar` (one `CountryFlag`, a descendant of the avatar's `Stack`).
  - `a standard row with a Country subtitle still draws exactly one flag`.
  - `a buddy with no country draws no badge`.
  - `the Buddies switch off hides the badge`.
  - `the row's label names the country when the badge draws`.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** the badge: a `Stack` around the 40 px avatar with the `CountryFlag` (height 11) at the bottom trailing corner, offset a few pixels outside the circle, on a `DecoratedBox` ring in `colorScheme.surface` so it reads on a photo.
- [ ] **Step 4: Run** the file plus `buddy_list_tile_test.dart` and `compact_buddy_list_tile_test.dart`; expect PASS.
- [ ] **Step 5: Commit** `feat(buddies): show a buddy's flag as a badge on their avatar`.

### Task 6: A switch on each section's appearance page

**Files:**
- Create: `lib/features/settings/presentation/widgets/section_country_flags_tile.dart`
- Modify: `lib/features/settings/presentation/pages/section_appearance_page.dart` (after `_buildListFieldsTile`, for `sites`, `dives`, `buddies`, `trips`)
- Modify: `lib/features/settings/presentation/widgets/appearance_settings_tiles.dart` (remove the global tile and `showCountryFlags` from its select)
- Modify: ARB files (four subtitles `settings_appearance_countryFlags_subtitle_{sites,dives,buddies,trips}`; remove the now-unused `settings_appearance_countryFlags_subtitle`; the title key stays)
- Test: `test/features/settings/presentation/widgets/section_country_flags_tile_test.dart` (new), `test/features/settings/presentation/widgets/appearance_settings_tiles_test.dart`, `test/features/settings/presentation/pages/section_appearance_page_test.dart`

**Interfaces:**
- Consumes: the setters and providers from Task 1.
- Produces: `SectionCountryFlagsTile({required FlagSection section})`, a `SwitchListTile` keyed `ValueKey('section-country-flags-<section.name>')`, `secondary: Icon(Icons.flag_outlined)`.

- [ ] **Step 1: Write the failing tests**: each section's tile shows its value and its toggle calls only its own setter; the Dives, Sites, Buddies and Trips pages each show exactly one tile and Equipment shows none; the Appearance page shows no country flags tile.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** with English subtitles "Show a small flag beside each site's location", "...each dive's site location", "...on each buddy's photo", "...beside each trip's countries"; translate into the other 10 locales; `flutter gen-l10n`.
- [ ] **Step 4: Run** the three files; expect PASS.
- [ ] **Step 5: Commit** `feat(settings): a country flags switch on each section's appearance page`.

### Task 7: Finish

- [ ] `dart format .`, `flutter analyze` (whole repo) clean.
- [ ] After screenshots with the throwaway golden harness (dive list, buddy list light and dark, Appearance, the four section pages), then delete `test/zz_shots/`.
