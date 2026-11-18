# Buddy Country Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give buddies a country (free text plus the ISO code read from it),
editable, shown with a flag, listable, searchable, mergeable, exported and
reachable by agent access.

**Architecture:** Two nullable columns on `buddies` (schema v371). The
site rule that keeps a code in step with its text moves to
`lib/core/geography/` and both repositories call it. The UI reuses the site
country suggestions, `LocationWithFlag` and the card-slot flag pattern.

**Tech Stack:** Flutter, Drift, Riverpod, xml (UDDF).

**Spec:** `docs/design/specs/2026-11-16-buddy-country-design.md`

## Global Constraints

- Schema version 371; nullable `TEXT` columns `buddies.country` and
  `buddies.country_code`; no backfill; the compatibility floor does not move.
- Blank or whitespace-only country text is stored as null, with a null code.
- Flags follow `showCountryFlagsProvider`.
- No region field. No country on the diver profile or on buddy cards.
- New user-facing strings go in all 11 ARB files, translated.
- No em-dashes anywhere; `dart format .` before each commit.

## Review Focus

1. Editing "Italy" to "Malta" must not keep IT: Task 1 and Task 2 tests.
2. Clearing the field clears the code: Task 2 test.
3. Text no table reads ("Atlantis") keeps the text, stores no code, draws
   no flag: Task 2 and Task 5 tests.
4. An agent update that sets only `country` derives the code: Task 2
   (`updateFields`) and Task 7 tests.
5. A sync payload from an older peer without the columns still hydrates:
   Task 2 test.

---

### Task 1: Shared country code rule

**Files:**
- Create: `lib/core/geography/country_code_save.dart`
- Modify: `lib/features/dive_sites/domain/services/site_country_code.dart`
- Test: `test/core/geography/country_code_save_test.dart`

**Interfaces:**
- Produces: `typedef KnownCountryCode = ({String? country, String? code});`
  (moved), `String? countryCodeOnSave({required String? country, required KnownCountryCode known})`
  (moved), and
  `String? reconcileCountryCode({required String? country, required String? code, KnownCountryCode? before})`
  with the body of today's `reconciledCountryCode`, on plain values.
- `site_country_code.dart` exports the new file and keeps
  `reconciledCountryCode(DiveSite site, {DiveSite? before})` as a one-line
  wrapper, so no site call site changes.

- [ ] Step 1: tests for `reconcileCountryCode`: new record derives
  (`country: 'Italy', code: null, before: null` gives `'IT'`); text changed,
  code carried over (`'Malta'`, `'IT'`, before `('Italy','IT')`) gives
  `'MT'`; unchanged text without a code keeps the stored one (`'Korea'`,
  null, before `('Korea','KR')`) gives `'KR'`; cleared text gives null; a
  writer's own code is kept (`'Italy'`, `'IT'`, before `('Malta','MT')`).
- [ ] Step 2: run `flutter test test/core/geography/country_code_save_test.dart`, expect FAIL (missing file).
- [ ] Step 3: move the typedef and `countryCodeOnSave`, add
  `reconcileCountryCode`, make the site wrapper delegate.
- [ ] Step 4: run the new test plus `test/features/dive_sites/domain/` and expect PASS.
- [ ] Step 5: commit `refactor(geography): share the country code save rule`.

### Task 2: Schema v371, entity, repository

**Files:**
- Modify: `lib/core/database/tables/buddy_tables.dart` (two columns with
  doc comments), `lib/core/database/migrations/helpers/buddy_migrations.dart`
  (`_assertBuddyCountryColumns()` using `_addColumnIfMissing`),
  `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (v371 rung),
  `lib/core/database/migrations/before_open_child_columns.dart` (backstop),
  `lib/core/database/database.dart` (version 371 and `371,` in the list),
  `lib/features/buddies/domain/entities/buddy.dart` (`country`,
  `countryCode`: constructor, `copyWith` with `clearCountry`, `props`),
  `lib/features/buddies/data/repositories/buddy_repository.dart`,
  `lib/features/agent_access/data/resources/sql_column_notes.generated.dart`
  (regenerate with `dart run tool/generate_sql_column_notes.dart`).
- Test: `test/core/database/migration_v371_buddy_country_test.dart`,
  `test/features/buddies/data/buddy_repository_country_test.dart`

**Interfaces:**
- Produces: `Buddy.country`, `Buddy.countryCode` (both `String?`),
  `Buddy.copyWith({String? country, String? countryCode, bool clearCountry = false})`
  where `clearCountry` nulls both.
- Repository: `createBuddy` stores trimmed country (blank to null) and
  `reconcileCountryCode(before: null)`; `updateBuddy` reads the stored
  row's country/code first and passes it as `before`; `updateFields` with
  `country` present and `countryCode` absent writes
  `countryCode: Value(countryCodeFor(country))`.

- [ ] Step 1: migration test like `migration_v370_buoyancy_default_test.dart`:
  v371 in `migrationVersions`; a v370 `buddies` table gains both columns;
  the existing row keeps null in both.
- [ ] Step 2: repository tests: create `'Italy'` stores IT; update to
  `'Malta'` with the old code carried over stores MT; update to `'  '`
  stores null/null; `'Atlantis'` stores the text and a null code;
  `updateFields(BuddiesCompanion(country: Value('Japan')))` stores JP;
  `Buddy.fromJson`-style hydration of a sync row map without the two keys
  gives nulls (through the sync serializer's buddies path).
- [ ] Step 3: run both, expect FAIL.
- [ ] Step 4: implement; run `bash scripts/setup.sh` for codegen (never a
  `--build-filter`).
- [ ] Step 5: run both tests, `test/core/database/`, `test/features/buddies/data/`; expect PASS.
- [ ] Step 6: commit `feat(buddies): store a buddy's country (schema v371)`.

### Task 3: Edit page field

**Files:**
- Create: `lib/features/buddies/presentation/widgets/buddy_country_field.dart`
- Modify: `lib/features/dive_sites/domain/services/site_suggestions.dart`,
  `lib/features/buddies/presentation/pages/buddy_edit_page.dart`, ARB files
- Test: `test/features/dive_sites/domain/site_suggestions_test.dart` (add),
  `test/features/buddies/presentation/pages/buddy_edit_country_test.dart`

**Interfaces:**
- Produces: `List<String> suggestedCountryNames(Iterable<String?> used)`
  (used names first, case-insensitively distinct and sorted, then
  `isoCountryNames` not already used); `suggestedCountries(sites)`
  delegates to it.
- `BuddyCountryField({required TextEditingController controller, required List<String> suggestions, InputDecoration Function(InputDecoration)? decorate})`:
  a `RawAutocomplete<String>` over a `TextFormField`, options shown with
  `AutocompleteOptionsList`, prefix icon `Icons.public`,
  `TextCapitalization.words`. `decorate` lets the page wrap it with
  `_withMergeTextDecoration(key: 'country', ...)`.
- Strings: `buddies_field_country` "Country", `buddies_field_countryHint`
  "e.g. Italy".

- [ ] Step 1: tests: `suggestedCountryNames(['Malta', 'malta', null, 'Bonaire'])`
  starts `['Bonaire', 'Malta']` and then has no "Malta" again; widget test:
  the field sits after the social field, typing "Ita" offers "Italy",
  saving writes country "Italy" and code "IT", editing an existing buddy
  shows its stored country.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: implement; suggestions come from the buddies and sites the
  page already can watch (`allBuddiesProvider`, `sitesProvider`); the save
  uses `countryCodeOnSave(known: (country: original?.country, code: original?.countryCode))`.
- [ ] Step 4: run, expect PASS; `flutter analyze`.
- [ ] Step 5: commit `feat(buddies): edit a buddy's country`.

### Task 4: Merge

**Files:**
- Modify: `lib/features/buddies/presentation/pages/buddy_merge_form_controller.dart`,
  `buddy_edit_page.dart`
- Test: `test/features/buddies/presentation/pages/buddy_merge_country_test.dart`

- [ ] Step 1: test: merging a buddy with "Italy" and one with none
  preselects "Italy"; cycling offers each distinct country; the survivor
  saves IT.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: add `countryController` to `initialize` and a `'country'`
  text field like `'phone'`; wire the merge cycle button.
- [ ] Step 4: run with `test/features/buddies/`, expect PASS.
- [ ] Step 5: commit `feat(buddies): choose the country when merging buddies`.

### Task 5: Detail page and list field

**Files:**
- Modify: `buddy_detail_page.dart`, `lib/features/buddies/domain/constants/buddy_field.dart`,
  `buddy_list_tile.dart`, `compact_buddy_list_tile.dart`, ARB files
- Test: `test/features/buddies/presentation/pages/buddy_detail_country_test.dart`,
  `test/features/buddies/domain/buddy_field_test.dart` (add or create),
  `test/features/buddies/presentation/widgets/buddy_list_tile_country_test.dart`

**Interfaces:**
- `BuddyField.country`: icon `Icons.public`, width 130, min 70, sortable,
  category `'contact'`, `extractValue` gives `buddy.country`. Strings
  `enum_buddyField_country` "Country", `enum_buddyField_country_short`
  "Country".
- Detail page: a contact row after phone, `LocationWithFlag(country:,
  countryCode:, text:, fallbackLeading: Icon(Icons.public))`; the contact
  card's visibility condition includes `country`.
- Tiles: subtitle wrapped in `LocationWithFlag` when the subtitle slot's
  field is `BuddyField.country`, as `site_list_tile.dart` does.

- [ ] Step 1: tests: detail page shows "Italy" and a `CountryFlag`; with
  flags off it shows the icon instead; "Atlantis" shows the icon; the
  adapter extracts and sorts by country; a tile with subtitle slot country
  draws a `CountryFlag`, with the default email slot draws none.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: implement.
- [ ] Step 4: run with `test/features/buddies/`, expect PASS.
- [ ] Step 5: commit `feat(buddies): show a buddy's country and flag`.

### Task 6: Search and query

**Files:**
- Modify: `lib/features/buddies/query/buddy_query_entity.dart`,
  `lib/features/query/presentation/query_label_lookup.dart`, ARB files
- Test: existing buddy query tests under `test/features/buddies/query/`
  or `test/core/query/` (add cases)

- [ ] Step 1: tests: text search "ital" finds a buddy from Italy;
  `country = "Italy"` matches " Italy " (trimmed, as sites); `country is empty`
  matches a buddy without one.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: add the `textSearchSql` entry and a trimmed `country` text
  field (`labelKey: 'query_buddies_country'`, string "Country").
- [ ] Step 4: run the query tests, expect PASS.
- [ ] Step 5: commit `feat(buddies): search and query buddies by country`.

### Task 7: UDDF and agent access

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_participant_writers.dart`,
  `lib/core/services/export/uddf/uddf_import_parsers.dart`,
  `lib/features/dive_import/data/services/uddf_entity_importer.dart`,
  `lib/features/agent_access/data/documents/training_documents.dart`,
  `lib/features/agent_access/data/writes/families/buddy_writes.dart`
- Test: the existing UDDF buddy round-trip and agent buddy write tests (add cases)

- [ ] Step 1: tests: export writes `<buddy><address><country>Italy</country></address>`
  after `<personal>`, and a trimmed export leaves it out; import reads it
  back and the buddy stores IT; `buddyDocument` has `country` and
  `country_code`; an agent create and an update with `country` store the
  derived code.
- [ ] Step 2: run, expect FAIL.
- [ ] Step 3: implement; codec `'country': FieldCodec.text(maxLength: 100, nullable: true)`.
- [ ] Step 4: run with `test/architecture/` (agent write coverage), expect PASS.
- [ ] Step 5: commit `feat(buddies): export, import and agent access for buddy country`.

### Task 8: Docs and full checks

- [ ] Step 1: a line on the country field in `docs/user/buddies-and-dive-centers.md`.
- [ ] Step 2: `dart format .`, `flutter analyze`, `test/architecture/`,
  `test/shared/`, `test/features/buddies/`, `test/features/settings/presentation/conflicts/`,
  `test/core/database/`.
- [ ] Step 3: commit `docs(buddies): describe the buddy country field`.
