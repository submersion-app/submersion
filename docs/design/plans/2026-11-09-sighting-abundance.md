# Sighting Abundance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (this plan runs native, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A sighting records how many animals as Seen, a REEF group (Single, Few, Many, Abundant) or an exact number, with Seen as the default for new sightings and every existing sighting kept as an exact count.

**Architecture:** A pure `SightingAbundance` enum owns the REEF ranges, the storage mapping (null = Exact) and the merge rule. A nullable `sightings.abundance` text column (schema v350, sync floor raised to 350) stores it beside the unchanged `count`. Entities, the repository, the add/edit UI, badges, totals, import/export, agent writes, merge and search all read through that enum.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, flutter_test, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-11-09-sighting-abundance-design.md`

## Global Constraints

- Stored values: `seen`, `single`, `few`, `many`, `abundant`; **NULL means Exact**. Unknown text reads as Exact.
- REEF ranges: Single 1, Few 2 to 10, Many 11 to 100, Abundant more than 100.
- New sightings default to Seen; for Seen and the groups `count` is stored as 1.
- Existing rows are never rewritten (no backfill in the rung).
- Schema v350 (348 and 349 are claimed by sibling branches; #4327 also claims 347 and will renumber). `minimumCompatibleSchemaVersion` rises 336 to 350.
- Badge text: Seen shows nothing; Exact shows `x<n>` (so `x1` too); groups show the localized group name.
- Every new string goes into all 11 ARB files, each placed beside a key of the same feature group (ARBs are feature-grouped, not sorted).
- No em-dashes anywhere; no emojis; `dart format .` before each commit.
- Never run build_runner with `--build-filter`; run it unfiltered.

## Review Focus

1. A sighting synced in from a pre-v350 peer (JSON with no `abundance` key) must read as Exact with its count, not Seen. Test in Task 2.
2. Editing an existing Exact sighting and saving without touching the chips must keep it Exact with the same count (the edit sheet must start from the stored value, not the Seen default). Test in Task 6.
3. Switching from Exact 7 to Few and back to Exact in the dialog: the stepper reappears at 7 within the same dialog session, and saving a group stores count 1. Test in Task 6.
4. An agent update that sends only `count` on a Seen sighting turns it Exact with that count; one that sends only `abundance: few` stores count 1. Test in Task 7.
5. The UDDF importer given a `<sighting>` with no `count` attribute creates a Seen sighting; one with `count="1"` creates Exact 1. Test in Task 7.

---

### Task 1: SightingAbundance domain type

**Files:**
- Create: `lib/features/marine_life/domain/entities/sighting_abundance.dart`
- Test: `test/features/marine_life/domain/entities/sighting_abundance_test.dart`

**Interfaces:**
- Produces:
  - `enum SightingAbundance { seen, single, few, many, abundant, exact }`
  - `String? get storageValue` (null for `exact`, else `name`)
  - `static SightingAbundance fromStorage(String? value)` (null or unknown gives `exact`)
  - `bool get isGroup` (single, few, many, abundant)
  - `static SightingAbundance groupForCount(int count)` (1 single, 2..10 few, 11..100 many, >100 abundant; count < 1 treated as 1)
  - `typedef SightingAmount = ({SightingAbundance abundance, int count});`
  - `static SightingAmount combine(SightingAmount a, SightingAmount b)`

- [ ] **Step 1: Write the failing tests**

```dart
test('storage round trip, null and unknown are exact', () {
  for (final a in SightingAbundance.values) {
    expect(SightingAbundance.fromStorage(a.storageValue), a);
  }
  expect(SightingAbundance.exact.storageValue, isNull);
  expect(SightingAbundance.fromStorage(null), SightingAbundance.exact);
  expect(SightingAbundance.fromStorage('lots'), SightingAbundance.exact);
});
test('groupForCount follows the REEF ranges', () {
  expect(SightingAbundance.groupForCount(1), SightingAbundance.single);
  expect(SightingAbundance.groupForCount(2), SightingAbundance.few);
  expect(SightingAbundance.groupForCount(10), SightingAbundance.few);
  expect(SightingAbundance.groupForCount(11), SightingAbundance.many);
  expect(SightingAbundance.groupForCount(100), SightingAbundance.many);
  expect(SightingAbundance.groupForCount(101), SightingAbundance.abundant);
});
test('combine: two exact counts add up', () {
  expect(combine(exact(3), exact(4)), exact(7));
});
test('combine: seen is neutral', () {
  expect(combine(seen, exact(3)), exact(3));
  expect(combine(few, seen), few);
  expect(combine(seen, seen), seen);
});
test('combine: otherwise the larger group, exact placed in its group', () {
  expect(combine(exact(3), few), few);          // count 1
  expect(combine(exact(50), few), many);        // count 1
  expect(combine(single, abundant), abundant);
});
```

(`exact(n)`, `few`, `seen` and so on are local test helpers building `SightingAmount` records; a group or Seen always carries count 1.)

- [ ] **Step 2: Run, expect FAIL** (`flutter test test/features/marine_life/domain/entities/sighting_abundance_test.dart`: file not found / undefined).
- [ ] **Step 3: Implement** the enum and `combine`. Rule: both exact gives sum; if one side is Seen return the other; else rank each side (an exact side ranks as `groupForCount(count)`), return the higher-ranked group with count 1 (rank order single < few < many < abundant; ties keep the first).
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(marine-life): add the sighting abundance type`.

### Task 2: Schema v350, sync floor, sync round trip

**Files:**
- Modify: `lib/core/database/tables/marine_life_tables.dart` (Sightings: `TextColumn get abundance => text().nullable()();`)
- Create: `lib/core/database/migrations/helpers/sighting_abundance_migrations.dart` (`extension SightingAbundanceMigrations on AppDatabase { Future<void> _assertSightingAbundanceColumn() }` using `_tableExists('sightings')` then `_addColumnIfMissing('sightings', 'abundance', 'TEXT')`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (add the `part`)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (v350 entry: comment says column only, no backfill, raises the floor; re-asserted in beforeOpen)
- Modify: `lib/core/database/migrations/before_open_child_columns.dart` (call after `_assertDiveComputerAutoDownloadDisabledColumn`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 350`, append 350 to `migrationVersions`, `minimumCompatibleSchemaVersion = 350` with a "Raised 336 -> 350" paragraph in its doc comment explaining the explicit-null overwrite from an upgraded old peer)
- Modify: `test/core/database/migration_v336_trip_checklists_test.dart:138` (`greaterThanOrEqualTo(336)`)
- Test: `test/core/database/migration_v350_sighting_abundance_test.dart`, plus a case in the existing sync serializer test for sightings (find it with `grep -rln "'sightings'" test/core/services/sync`)

- [ ] **Step 1: Write the failing tests**, modelled on `migration_v347_dive_card_photo_background_test.dart`:
  - `v350 is in the ladder`: `currentSchemaVersion >= 350`, `migrationVersions` contains 350, `migrationStepCount(347) == migrationStepCount(350) + 1`.
  - `the column raises the sync floor`: `minimumCompatibleSchemaVersion == 350`.
  - `upgrading from v347 keeps an existing sighting exact`: raw v347 DB with a sightings row (count 1); after open, `abundance` column exists and the row's `abundance` is null.
  - Serializer: importing a sightings record map with no `abundance` key yields a row with null abundance; a record with `'abundance': 'few'` round trips through export and import unchanged.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** the files above, then `dart run build_runner build --delete-conflicting-outputs` (unfiltered, in the background; check the log for "Built with").
- [ ] **Step 4: Run** the new tests, `test/core/database/` and `test/core/services/sync/`; expect PASS. Any test pinning `currentSchemaVersion` to 347 or the floor to 336 exactly gets a `greaterThanOrEqualTo`.
- [ ] **Step 5: Commit** `feat(marine-life): store sighting abundance (schema v350)`.

### Task 3: Entities and repository

**Files:**
- Modify: `lib/features/marine_life/domain/entities/species.dart` (`Sighting.abundance`, default `SightingAbundance.seen`; `copyWith`, `props`; `SightingAmount get amount`)
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (`MarineSighting.abundance`, same default, `copyWith`/`props`)
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart` (`addSighting({..., SightingAbundance abundance = SightingAbundance.seen, int count = 1, ...})`; `updateSighting`, `bulkAddSightings`, `bulkReplaceSightings` write `abundance: Value(s.abundance.storageValue)`; both getters read `SightingAbundance.fromStorage(row.data['abundance'] as String?)`; a non-exact write stores count 1)
- Modify: `lib/features/marine_life/presentation/providers/species_providers.dart` (`SightingsNotifier.addSighting` and `saveForDive` pass `abundance`)
- Test: `test/features/marine_life/data/repositories/species_repository_test.dart` (existing file; add a group)

**Interfaces:**
- Consumes: Task 1 `SightingAbundance`, `SightingAmount`.
- Produces: `Sighting.abundance`, `MarineSighting.abundance`, `SpeciesRepository.addSighting(abundance:)`.

- [ ] **Step 1: Write failing tests:** `addSighting` with no amount reads back Seen, count 1; `addSighting(abundance: exact, count: 3)` reads back Exact 3; `addSighting(abundance: few, count: 9)` stores count 1; `updateSighting` from Seen to Exact 5 persists; `getSightingsForDives` maps a raw row with NULL abundance to Exact.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the repository test file and `test/features/marine_life/`; expect PASS.
- [ ] **Step 5: Commit** `feat(marine-life): carry abundance through sightings`.

### Task 4: Totals count dives

**Files:**
- Modify: `lib/features/insights/data/repositories/insights_repository.dart` (top species: `COUNT(DISTINCT s.dive_id) AS total_count`; species insights: `COUNT(*) AS total_sightings`, top sites `COUNT(DISTINCT s.dive_id) AS sighting_count`)
- Modify: `lib/features/marine_life/data/repositories/seen_species_repository.dart` (`COUNT(*) AS total_sightings`)
- Modify: `lib/features/marine_life/domain/entities/seen_species.dart` (doc: number of logged sightings, one per species per dive)
- Modify: `lib/features/marine_life/domain/seen_species_filter.dart` (`mostSightings` renamed `mostDives`, ordered by `diveCount`, then name)
- Modify: `lib/features/marine_life/presentation/pages/species_page.dart` (default `mostDives`, label key `marineLife_speciesPage_sort_mostDives`)
- Modify: `lib/features/marine_life/presentation/widgets/seen_species_tile.dart` (drop the sightings part)
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page.dart` (drop the Total sightings card; Dives and Sites remain)
- Modify: all 11 ARBs: add `marineLife_speciesPage_sort_mostDives` ("Most dives"), remove `marineLife_speciesPage_sort_mostSightings` and `marineLife_speciesDetail_totalSightingsLabel` if nothing else uses them (grep first)
- Test: existing tests for these files (`grep -rln 'mostSightings\|totalSightings\|total_count' test`), updated, plus one insights repository test: a species with an Exact 40 sighting and a Few sighting on two dives ranks with 2, not 41

- [ ] **Step 1: Write/adjust the failing tests** (the ranking-by-dives case above; seen-species `totalSightings` equals the number of sighting rows; `mostDives` sort orders by `diveCount`; the tile shows no "sightings" text; the detail page shows no Total sightings card).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement**, then `flutter gen-l10n`.
- [ ] **Step 4: Run** `test/features/insights/`, `test/features/marine_life/`; expect PASS.
- [ ] **Step 5: Commit** `feat(marine-life): count dives, not animals, in species totals`.

### Task 5: Labels, badge, PDF and trip day card

**Files:**
- Create: `lib/features/marine_life/presentation/sighting_abundance_display.dart` (`String sightingAbundanceName(AppLocalizations l10n, SightingAbundance a)`, `String? sightingAmountLabel(AppLocalizations l10n, SightingAmount amount)`: Seen null, Exact `x<n>`, group its name)
- Create: `lib/features/marine_life/presentation/widgets/sighting_amount_badge.dart` (`SightingAmountBadge({required SightingAmount amount})`, the existing `primaryContainer` pill, `SizedBox.shrink()` for Seen)
- Modify: `lib/features/dive_log/presentation/widgets/dive_sighting_row.dart` and `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (~6172) to use the badge
- Modify: `lib/core/services/pdf_templates/pdf_template_detailed.dart` (`Name x3` for exact, `Name (Few)` for a group, name alone for Seen; the PDF has `l10n`)
- Modify: `lib/features/trips/presentation/widgets/story/trip_story_day_card.dart` (`_SightingChips` folds with `SightingAbundance.combine` and labels with `sightingAmountLabel`)
- Modify: all 11 ARBs: `marineLife_abundance_seen` "Seen", `_single` "Single", `_few` "Few", `_many` "Many", `_abundant` "Abundant", `_exact` "Exact", `marineLife_abundance_ranges` "Few 2 to 10, Many 11 to 100, Abundant 100+", `marineLife_abundance_label` "How many"
- Test: `test/features/marine_life/presentation/sighting_abundance_display_test.dart`, widget tests for the badge, the dive sighting row, the trip day card, and the PDF line

- [ ] **Step 1: Write failing tests:** label for Exact 1 is `x1`, Few is "Few", Seen is null; badge renders nothing for Seen; trip card with Exact 3 and Exact 4 for one species shows `Turtle x7`, with Exact 3 and Many shows `Turtle Many`, with Seen only shows `Turtle`; the PDF line text for Few is `Name (Few)`.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement**, `flutter gen-l10n`.
- [ ] **Step 4: Run** the new and touched test files; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): show sighting abundance badges`.

### Task 6: The How many picker

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/pickers/sighting_abundance_picker.dart` (`SightingAbundancePicker({required SightingAmount value, required ValueChanged<SightingAmount> onChanged})`: "How many" label, a `Wrap` of `ChoiceChip`s in enum order, the ranges helper line, and the existing +/- stepper (min 1, tooltips `diveLog_sighting_decreaseCount` / `diveLog_sighting_increaseCount`) only while Exact is picked. It remembers the last exact count for the dialog session so Exact to Few to Exact restores it; a group or Seen is reported with count 1.)
- Modify: `lib/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart` (callback becomes `void Function(Species species, SightingAmount amount, String notes)`; new `final bool showAbundance` default true; the dialog starts at Seen)
- Modify: `lib/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet.dart` (picker replaces the stepper, starts from `sighting.amount`, saves `abundance` and `count`)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (~6225 caller builds the `Sighting` with the amount; ~6689 save passes `abundance`)
- Modify: `lib/features/media/presentation/widgets/media_species_sheet.dart` (`showAbundance: false`, new callback shape)
- Test: widget tests for the picker, the add dialog and the edit sheet (`test/features/dive_log/presentation/widgets/pickers/`)

- [ ] **Step 1: Write failing tests:** the add dialog opens with Seen selected and no stepper; tapping Exact shows the stepper at 1; Exact 7 to Few to Exact shows 7; tapping Add with Few reports `(few, 1)`; the edit sheet opened on Exact 4 shows Exact selected and 4, and saving untouched reports Exact 4; `showAbundance: false` hides the chip row.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/features/dive_log/presentation/` and `test/features/media/presentation/`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): pick seen, a REEF group or an exact count`.

### Task 7: Import, export, agent writes, merge, bulk edit, search

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart:478` and `uddf_shared_dive_writer.dart:281` (Exact writes `count`; otherwise no `count` and an `abundance` attribute with the storage value)
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart:1572` (no `count` attribute leaves the key out; read `abundance`)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:3763,3785` (`abundance` key wins; else an int `count` is Exact; else Seen)
- Modify: `lib/features/universal_import/data/services/divinglog_sightings_mapper.dart:46` (drop `'count': 1`)
- Modify: `lib/features/agent_access/data/writes/families/sighting_writes.dart` (`'abundance': FieldCodec.enumName(SightingAbundance.values)`; create: neither gives Seen, `count` alone gives Exact; update: `count` alone makes Exact, a non-exact `abundance` stores count 1), `lib/features/agent_access/data/documents/dive_document.dart` (`'abundance': s.abundance.name`), `lib/features/agent_access/data/records/families/dive_records.dart` (`summaryKeys` adds `abundance`)
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart:334-360` (same-species merge uses `SightingAbundance.combine`), `lib/features/dive_log/data/services/dive_merge_service.dart:180,640` (read and write the column), `lib/features/dive_log/data/services/bulk_dive_edit_service.dart:500` (carry `abundance`)
- Modify: `lib/features/dive_log/query/dive_child_query_entities.dart:122` (`'CASE WHEN {r}.abundance IS NULL THEN {r}.count END'`, so only Exact rows match)
- Test: existing test files for each (find with `grep -rln` on the class names), plus the Review Focus cases 4 and 5

- [ ] **Step 1: Write failing tests:** UDDF export of a Few sighting has `abundance="few"` and no `count`; export then import keeps Few; import of a `<sighting>` without `count` is Seen, with `count="1"` is Exact 1; Diving Log sightings import as Seen; agent create with nothing is Seen, with `count: 5` is Exact 5; agent update rules from Review Focus 4; the dive document carries `abundance`; merging Exact 3 with Exact 4 gives Exact 7 and Exact 3 with Many gives Many; the `sightings.count > 0` query matches an Exact row and not a Few row; bulk edit copies keep the abundance.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `test/core/services/export/`, `test/features/dive_import/`, `test/features/universal_import/`, `test/features/agent_access/`, `test/features/dive_log/`; expect PASS.
- [ ] **Step 5: Commit** `feat(dive-log): keep sighting abundance through import, export, merge and agent writes`.

### Task 8: Whole-branch checks

- [ ] **Step 1:** `dart format .`, then `flutter analyze` (whole repo); expect no issues.
- [ ] **Step 2:** `flutter test test/architecture/ test/shared/ test/core/database/`; expect PASS (new files under `lib/`).
- [ ] **Step 3:** Run every test directory touched above once more together; expect PASS.
- [ ] **Step 4:** Commit any formatting-only changes as `style: format`.
