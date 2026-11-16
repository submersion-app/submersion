# Dive Type Favourites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This plan runs Native (superpowers:executing-plans, in one session).

**Goal:** Let each diver star dive types so starred types come first in the dive type pickers (#4413).

**Architecture:** A per-diver set of starred ids in a new nullable `diver_settings.favourite_dive_type_ids` column, carried by `AppSettings` and the existing diver_settings save, load and sync. A pure ordering function puts favourites first; the checklist sheet and the Refine filter dropdown apply it. One reusable star button toggles a favourite from the sheet and from Settings > Dive Types.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), ARB l10n.

**Spec:** `docs/design/specs/2026-11-16-dive-type-favourites-design.md`

## Global Constraints

- Schema version 371 (main is at 370 and no open PR claims 371). Column only, nullable, no backfill; the sync floor (`minimumCompatibleSchemaVersion`) does not move.
- No table or rung code in `database.dart` beyond the version constant and the `migrationVersions` entry; the column assert lives in a new part file under `lib/core/database/migrations/helpers/`.
- Encode the set with the repository's existing `_encodeDisabledRules` / `_decodeDisabledRules` (sorted JSON list, null when empty, malformed reads as empty).
- Favourites never change the order of `diveTypesProvider` itself, exports, badge rows or the settings page sections.
- Hiding wins: `visibleBuiltIns` runs before ordering, so a hidden starred built-in stays out unless the dive already has it.
- Copy (English): header "Favourites", tooltips "Add to favourites" / "Remove from favourites", conflict field "Favourite dive types". Every ARB locale gets translations.
- No em-dashes anywhere, no emojis, `dart format .` before each commit.

## Review Focus

1. A starred type that is also hidden: absent from the sheet and dropdown unless the dive already has it. Test in Task 4.
2. A starred id that matches no type (deleted custom type): ignored, and the sheet shows no empty "Favourites" header. Tests in Tasks 1 and 4.
3. Tapping a star in the open sheet: the row does not move and its checkbox does not change; the star fills at once. Test in Task 4.
4. Two divers on one database: one diver's stars never show for the other. Test in Task 2.
5. A corrupt `favourite_dive_type_ids` value (non-JSON, wrong type): settings load with no favourites instead of failing. Test in Task 2.

---

### Task 1: Ordering and toggle helpers

**Files:**
- Create: `lib/features/dive_types/domain/favourite_dive_types.dart`
- Test: `test/features/dive_types/domain/favourite_dive_types_test.dart`

**Interfaces:**
- Produces:
  - `List<T> favouritesFirst<T>(List<T> all, Set<String> favourites, {required String Function(T) idOf})`: stable partition, favourites first, each group in incoming order; returns `all` itself when `favourites` is empty or matches nothing.
  - `Set<String> withDiveTypeFavourite(Set<String> current, String id, bool favourite)`: returns `current` itself when nothing changes, else a new set.

- [ ] **Step 1: Write the failing tests** (`favouritesFirst` on string ids with `idOf: (s) => s`)
  - `favouritesFirst(['a','b','c','d'], {'c','a'})` equals `['a','c','b','d']`.
  - `favouritesFirst(['a','b'], {})` is `identical` to the input.
  - `favouritesFirst(['a','b'], {'zzz'})` is `identical` to the input (dangling id ignored).
  - `withDiveTypeFavourite({'a'}, 'b', true)` equals `{'a','b'}`; `withDiveTypeFavourite({'a'}, 'a', false)` equals `{}`; `withDiveTypeFavourite({'a'}, 'a', true)` is `identical` to the input.
- [ ] **Step 2: Run** `flutter test test/features/dive_types/domain/favourite_dive_types_test.dart`; expect FAIL (file missing).
- [ ] **Step 3: Implement both functions** in the new file.
- [ ] **Step 4: Run the test again**; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-types): order favourite dive types first`.

### Task 2: Storage (schema v371, settings, sync, conflicts)

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (add `TextColumn get favouriteDiveTypeIds => text().nullable()();` with a v371 comment, next to `defaultShowBuoyancy`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 371`; append `371` with a comment to the migration versions list after `370`)
- Create: `lib/core/database/migrations/helpers/dive_type_favourites_migrations.dart` (`extension DiveTypeFavouritesMigrations on AppDatabase` with `Future<void> _assertFavouriteDiveTypeIdsColumn()` calling `_addColumnIfMissing('diver_settings', 'favourite_dive_type_ids', 'TEXT')`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part directive)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (`if (from < 371)` assert plus `reportProgress()`, commented like v370)
- Modify: `lib/core/database/migrations/before_open_settings_columns.dart` (v371 backstop)
- Modify: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` (regenerate with its generator if one exists, otherwise add `'favourite_dive_type_ids': 'dive types this diver starred to list first in the pickers'`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`final Set<String> favouriteDiveTypeIds;` default `const {}`, copyWith; `SettingsNotifier.setDiveTypeFavourite(String id, bool favourite)` via `_update` and `withDiveTypeFavourite`, returning `s` unchanged when identical)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (the three places `hiddenTankPresetIds` is written or read)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart` (`'favouriteDiveTypeIds'`, `FieldKind.opaque`, label `settings_conflict_field_favouriteDiveTypeIds`)
- Modify: `lib/l10n/arb/app_*.arb` (conflict label in every locale), then `flutter gen-l10n`
- Modify: `test/helpers/mock_providers.dart`, `test/features/insights/presentation/pages/records_page_test.dart` (the two SettingsNotifier fakes without `noSuchMethod` get `setDiveTypeFavourite`; the mock updates its state like its `setBuiltInHidden`)
- Modify: `test/features/settings/presentation/providers/every_setter_waits_for_load_test.dart` (add `n.setDiveTypeFavourite('recreational', true)`)
- Test: `test/core/database/migration_v371_dive_type_favourites_test.dart`, `test/features/settings/data/repositories/diver_settings_repository_dive_type_favourites_test.dart`

**Interfaces:**
- Consumes: `withDiveTypeFavourite` (Task 1).
- Produces: `AppSettings.favouriteDiveTypeIds` (`Set<String>`), `SettingsNotifier.setDiveTypeFavourite(String id, bool favourite) -> Future<void>`.

- [ ] **Step 1: Write the failing migration test**, modelled on `migration_v269_hidden_built_ins_test.dart`: a v370 `diver_settings` without the column upgrades to a null `favourite_dive_type_ids` and keeps its row; `migrationVersions` contains 371; `currentSchemaVersion` is at least 371; `minimumCompatibleSchemaVersion` unchanged (copy v370's floor assertion).
- [ ] **Step 2: Write the failing repository tests**, modelled on `diver_settings_repository_hidden_built_ins_test.dart`:
  - a new diver has `favouriteDiveTypeIds` empty;
  - create with `{'shore'}`, update to `{'shore','dry'}`, read back `{'shore','dry'}`;
  - favourites are per diver: d1 `{'night'}`, d2 reads empty;
  - a raw `UPDATE diver_settings SET favourite_dive_type_ids = 'not json'` reads back as empty, and `'{"a":1}'` reads back as empty.
- [ ] **Step 3: Run both test files**; expect FAIL (column and field missing).
- [ ] **Step 4: Implement the files listed above**, then `dart run build_runner build --delete-conflicting-outputs` in the background (never `--build-filter`).
- [ ] **Step 5: Run** both new tests, `test/core/database/`, `test/core/services/sync/`, `test/features/settings/`; expect PASS. Run `flutter analyze` (whole repo).
- [ ] **Step 6: Commit** `feat(settings): store each diver's favourite dive types`.

### Task 3: The star button

**Files:**
- Create: `lib/features/dive_types/presentation/widgets/dive_type_favourite_button.dart`
- Modify: `lib/l10n/arb/app_*.arb` (`diveTypes_favourite_add` "Add to favourites", `diveTypes_favourite_remove` "Remove from favourites", `diveTypes_favourites_header` "Favourites"), `flutter gen-l10n`
- Test: `test/features/dive_types/presentation/widgets/dive_type_favourite_button_test.dart`

**Interfaces:**
- Consumes: `AppSettings.favouriteDiveTypeIds`, `SettingsNotifier.setDiveTypeFavourite`.
- Produces:
  - `Key diveTypeFavouriteButtonKey(String id)` returning `ValueKey('diveTypeFavourite:$id')`.
  - `final favouriteDiveTypeIdsProvider = Provider<Set<String>>` selecting a sorted, newline-joined key from `settingsProvider` (same shape as `hiddenBuiltInIdsProvider`), in `lib/features/dive_types/presentation/providers/dive_type_providers.dart`.
  - `class DiveTypeFavouriteButton extends ConsumerWidget { const DiveTypeFavouriteButton({required String diveTypeId}); }`: an `IconButton` with `Icons.star` (colour `colorScheme.primary`) when starred, `Icons.star_border` otherwise, tooltip from the two new keys, `onPressed` calls `setDiveTypeFavourite(id, !starred)`.

- [ ] **Step 1: Write the failing widget tests** with `MockSettingsNotifier`: an unstarred type shows `Icons.star_border` and tooltip "Add to favourites"; tapping it makes the mock's `favouriteDiveTypeIds` contain the id and the icon becomes `Icons.star` with tooltip "Remove from favourites"; tapping again removes it.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** the provider and the button.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-types): add a favourite star button`.

### Task 4: Checklist sheet (dive edit, bulk edit, certification dialogs)

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_type_multi_select_field_favourites_test.dart` (reuse the harness shape of `dive_type_multi_select_field_test.dart`)

**Interfaces:**
- Consumes: `favouritesFirst`, `favouriteDiveTypeIdsProvider`, `DiveTypeFavouriteButton`, `diveTypes_favourites_header`.

Behaviour: on tap the field computes `visibleBuiltIns(...)` as today, then `favouritesFirst(...)` with the favourites read at that moment, and passes the frozen list plus the frozen set of ids that were starred and present. The sheet renders, when that set is non-empty, a header row ("Favourites", `titleSmall` in `colorScheme.primary`, padded like the title row), the starred rows, then a `Divider`, then the rest. Each row is a `CheckboxListTile` with `controlAffinity: ListTileControlAffinity.leading` and `secondary: DiveTypeFavouriteButton(diveTypeId: t.id)`, so the checkbox moves to the leading side (as in the approved sketch) and the star sits on the trailing side with its own tap target.

- [ ] **Step 1: Write the failing widget tests** (types shore, wreck, night, in that order):
  - favourites `{'night'}`: the row titles, by vertical position, are `['Night','Shore','Wreck']`, and the text "Favourites" is shown once;
  - no favourites: no "Favourites" text and order `['Shore','Wreck','Night']`;
  - favourites `{'deleted-type'}`: no "Favourites" text;
  - favourites `{'night'}` and night hidden, dive selected `['shore']`: Night absent; with selected `['night']`: Night present under the header;
  - with the sheet open, tap the star on Wreck: the mock now holds `{'wreck'}`, Wreck's star shows `Icons.star`, row order is unchanged, Wreck's checkbox value is unchanged and `onChanged` was not called;
  - close and reopen: Wreck now sits under the header.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement** the ordering in `build`/`_openPicker` and the grouped sheet.
- [ ] **Step 4: Run** the new file and `dive_type_multi_select_field_test.dart`, plus `test/features/certifications/`; expect PASS (adjust an existing test only where the leading checkbox changes a finder, and say so in the commit body).
- [ ] **Step 5: Commit** `feat(dive-log): list favourite dive types first in the type checklist`.

### Task 5: Refine filter dropdown

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group.dart:204-225`
- Test: add to the existing Refine group test that covers the dive type dropdown (find it with `grep -rln "diveLog_filter_allTypes\|sectionDiveType" test`), or a new `refine_dive_type_favourites_test.dart` beside it.

**Interfaces:**
- Consumes: `favouritesFirst`, `favouriteDiveTypeIdsProvider`.

- [ ] **Step 1: Write the failing test**: with types Shore, Wreck, Night and favourites `{'night'}`, opening the dropdown lists the options with Night first, then Shore, Wreck.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement**: build `options` from `favouritesFirst(types, favourites, idOf: (t) => t.id)`.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): list favourite dive types first in the type filter`.

### Task 5b: Connections search

**Files:**
- Modify: `lib/features/connections/presentation/panel/entity_search_field.dart` (`_merge` gains a `Set<String> favouriteDiveTypeIds` parameter; after its busiest-first sort, apply `favouritesFirst` with `idOf: (n) => n.ref.kind == ConnectionKind.diveType ? n.ref.id : ''`, so a species or site sharing an id is never lifted)
- Test: the existing entity search field test (find with `grep -rln "entity-search" test`), or a new `entity_search_field_favourites_test.dart` beside it

**Interfaces:**
- Consumes: `favouritesFirst`, `favouriteDiveTypeIdsProvider`.

- [ ] **Step 1: Write the failing test**: hits Reef site (40 dives), Shore dive type (10), Night dive type (2); favourites `{'night'}`: hit keys in order `search-hit-<night wire>`, then Reef, then Shore. With no favourites the order is Reef, Shore, Night.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the test and `test/features/connections/`; expect PASS.
- [ ] **Step 5: Commit** `feat(connections): rank favourite dive types first in the search`.

### Task 6: Settings > Dive Types stars, docs, final checks

**Files:**
- Modify: `lib/features/dive_types/presentation/pages/dive_types_page.dart` (`_buildDiveTypeTile` trailing `Row`: `DiveTypeFavouriteButton` first, before the badge, on every row)
- Modify: the user doc that describes Settings > Dive Types (find with `grep -rli "dive types" docs/user`), one short paragraph on starring
- Test: `test/features/dive_types/presentation/pages/dive_types_page_favourites_test.dart` (harness from `dive_types_page_hide_test.dart`)

- [ ] **Step 1: Write the failing widget tests**: every row (custom `mine` and built-in `night`) has `diveTypeFavouriteButtonKey(id)`; tapping the one on `night` puts `night` in the mock's favourites and does not open the edit dialog; section order and row order are unchanged after the tap.
- [ ] **Step 2: Run**; expect FAIL.
- [ ] **Step 3: Implement**, and write the doc paragraph.
- [ ] **Step 4: Run** the new test, `test/features/dive_types/`, `test/architecture/`, `test/shared/`; `flutter analyze`; `dart format .`; expect all clean.
- [ ] **Step 5: Commit** `feat(dive-types): star dive types from the Dive Types settings page`.
