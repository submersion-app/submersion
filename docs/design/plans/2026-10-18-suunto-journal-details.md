# Suunto Journal Dive Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Suunto cloud import brings every journal detail (dive center, visibility, current, weight, marine life, suit, environment, comfort, buoyancy, state of mind, private notes) onto the imported dive, each only where the dive has none.

**Architecture:** The listing parser turns `journal` into an immutable `SuuntoJournal` carried on the workout summary and the parsed dive, replacing the `buddies` list added in #3266. A `SuuntoJournalWriter` applies it after save from `SuuntoDiveImportCore._fillFromWorkout`, each detail in its own try/catch, through small fill-if-missing repository methods.

**Tech Stack:** Flutter, Dart, Drift (SQLite), mockito, flutter_test.

**Spec:** `docs/design/specs/2026-10-18-suunto-journal-details-design.md`

## Global Constraints

- Nothing written in Submersion is overwritten; every write checks emptiness first, in SQL where it is a column.
- A re-import of the same dive adds nothing.
- The legacy `dives.visibility` column is never written.
- Only codes seen in real data map: visibility `good` to `VisibilityBand.good`, current `none` to `CurrentStrength.none`. Any other code becomes a custom field labelled `Visibility` or `Current` holding Suunto's `value` text (the `id` when `value` is blank).
- Custom field labels, exactly: `Suit`, `Environment`, `Comfort`, `Buoyancy`, `State of mind`, `Visibility`, `Current`. Several values join with `", "`.
- Weight: unit `KG`, `LB` or `LBS` (case-insensitive), one `DiveWeight` of `WeightType.belt`; 1 lb = 0.45359237 kg; any other unit skips the weight.
- New species: `SpeciesCategory.other`; sighting count 1.
- Private notes go below the `description` text after one blank line, through the existing `fillNotesIfEmpty`.
- One failing write is logged and never stops the others or the import.
- Fixtures for the cloud API live under `test/fixtures/suunto_cloud/`, never `test/fixtures/suunto/`.

## Review Focus

1. A journal whose values are blank or whitespace: nothing is written for that field, no empty custom field appears. (Task 1 test `blank values yield nothing`.)
2. Re-importing the same dive: no second custom field, sighting, weight or center link. (Task 4 test `a second attach adds nothing`.)
3. A dive the diver already edited: visibility measured as 8 m, a center set, a `suit` field of their own, all left untouched. (Task 4 test `leaves what the diver already logged`.)
4. Mixed-case labels or species names already present (`suit`, `aal`): treated as present. (Task 2 and Task 4 tests.)
5. A journal of the wrong shape (a string where a list is expected, a list entry that is not a map): parsed as absent, the rest still read. (Task 1 test `malformed shapes are passed over`.)

---

### Task 1: Parse the journal

**Files:**
- Create: `lib/core/services/suunto_cloud/suunto_journal.dart`
- Modify: `lib/core/services/suunto_cloud/suunto_cloud_client.dart` (replace `buddies` and `_buddiesOf` with `journal`; notes join private notes)
- Modify: `lib/core/services/suunto_cloud/suunto_dive_parser.dart` (`SuuntoParsedDive.buddies` becomes `journal`)
- Modify: `lib/features/import_wizard/presentation/widgets/suunto_cloud_adapter_steps.dart` (copyWith `journal:`)
- Modify: `lib/features/import_wizard/data/adapters/suunto_buddy_writer.dart` (read `parsed.journal.buddies`)
- Test: `test/core/services/suunto_cloud/suunto_journal_test.dart`, update `suunto_cloud_client_test.dart`, `suunto_cloud_adapter_steps_test.dart`, `suunto_buddy_writer_test.dart`, `suunto_dive_import_core_buddies_test.dart`

**Interfaces:**
- Produces:
  - `class SuuntoJournal` (const, immutable) with fields `List<String> buddies`, `String? diveCenter`, `SuuntoCoded? visibility`, `SuuntoCoded? current`, `double? weightKg`, `List<String> suit`, `List<String> environment`, `List<String> marineLife`, `List<String> comfort`, `List<String> buoyancy`, `List<String> stateOfMind`, `String? privateNotes`; `static const empty`; `static SuuntoJournal parse(Object? journal)`; `bool get isEmpty`.
  - `class SuuntoCoded { final String id; final String text; }`, where `text` is `value` trimmed, falling back to `id`.
  - `SuuntoWorkoutSummary.journal` (default `SuuntoJournal.empty`); `SuuntoParsedDive.journal` (default empty) and `copyWith({SuuntoJournal? journal})`.

- [ ] **Step 1: Write failing tests** in `suunto_journal_test.dart`:
  - `reads every field of the real workout`: parse `payload[0].journal` of the fixture; expect buddies `['Buddy 1','Buddy 2','Buddy 3']`, diveCenter `'Dive Center'`, visibility `('good','Gut')`, current `('none','Keine')`, weightKg `12.0`, suit `['Drysuit']`, environment `['See']`, marineLife `['Aal','Barsch','Krebse']`, comfort `['Optimal']`, buoyancy `['Negativ','Neutral']`, stateOfMind `['Entspannt']`, privateNotes null.
  - `converts pounds to kilograms`: `{'diveWeights': {'value': 10, 'unit': 'lbs'}}` gives `closeTo(4.5359237, 1e-9)`; unit `'stone'` gives null.
  - `blank values yield nothing`: every list entry `{'value': '  '}`, diveCenter value `''`, privateNotes `' '` give empty lists and nulls, `isEmpty` true.
  - `malformed shapes are passed over`: `diveSuit: 'x'`, `diveBuddy: [1, {'value': 'Ann'}]`, `diveCenter: 'TKL'`, `diveWeights: {'value': 'heavy'}` give suit empty, buddies `['Ann']`, diveCenter null, weightKg null; `parse(null)` and `parse('x')` give `SuuntoJournal.empty`.
  - Keep the #3266 dedup rule for buddies (case-insensitive, first spelling kept); apply it to every list.
- [ ] **Step 2: Update the client test** `reads the dive buddies from a real workout journal` to assert `dives.single.journal.buddies`, and add `joins private notes below the notes`: `description: 'Night dive'`, `journal: {'privateNotes': ' Cold '}` gives notes `'Night dive\n\nCold'`; private notes alone give `'Cold'`.
- [ ] **Step 3: Run** `flutter test test/core/services/suunto_cloud/` and expect compile FAIL on `SuuntoJournal` / `journal`.
- [ ] **Step 4: Implement** `SuuntoJournal.parse`, wire it into `_toWorkoutSummary`, move buddies into it, and rename `buddies` to `journal` in the parsed dive, the fetch step, the buddy writer and their tests.
- [ ] **Step 5: Run** `flutter test test/core/services/suunto_cloud/ test/features/import_wizard/` and expect PASS.
- [ ] **Step 6: Commit** `feat(import-wizard): parse the Suunto workout journal`.

### Task 2: Fill-if-missing repository methods

**Files:**
- Create: `lib/features/dive_log/data/repositories/dive_fill_if_empty_repository.dart`
- Modify: `lib/features/dive_centers/data/repositories/dive_center_repository.dart` (add find-or-create)
- Test: `test/features/dive_log/data/repositories/dive_fill_if_empty_repository_test.dart`, `test/features/dive_centers/data/repositories/dive_center_find_or_create_test.dart`

**Interfaces:**
- Produces, on `class DiveFillIfEmptyRepository` (reads `DatabaseService.instance.database`, owns a `SyncRepository`, each write marks its record pending and returns whether it wrote):
  - `Future<bool> linkDiveCenterIfNone(String diveId, String centerId)`: `dive_center_id IS NULL` guard; marks the dive pending.
  - `Future<bool> fillVisibilityRangeIfEmpty(String diveId, VisibilityRange range)`: writes `visibility_min_meters` / `visibility_max_meters` only when `visibility`, `visibility_meters`, `visibility_min_meters` and `visibility_max_meters` are all NULL; marks the dive pending.
  - `Future<bool> fillCurrentStrengthIfEmpty(String diveId, CurrentStrength strength)`: stores `strength.name` when `current_strength IS NULL`; marks the dive pending.
  - `Future<int> addCustomFieldsIfMissing(String diveId, List<({String key, String value})> fields)`: skips a key the dive already has (case-insensitive) or that repeats within `fields`; new rows get `sortOrder` after the dive's current maximum; each row marked pending as `diveCustomFields`; bumps the dive's `updated_at` and marks it pending once if anything was added; returns the count added.
- Produces, on `DiveCenterRepository`: `Future<domain.DiveCenter> findOrCreateByName(String name, {required String diverId})`: `unicode_lower(name)` match among `diver_id = ? OR diver_id IS NULL`, the diver's own first; an unowned match is claimed via `updateDiveCenter(center.copyWith(diverId: diverId))`; otherwise created with `createDiveCenter`.

- [ ] **Step 1: Write failing tests** against `setUpTestDatabase()` (insert divers/dives with raw SQL as `suunto_buddy_writer_test.dart` does):
  - each fill method writes on an empty dive and returns true; returns false and changes nothing when the column is set; visibility returns false when only `visibility_meters` is set, and when only the legacy `visibility` is set.
  - `addCustomFieldsIfMissing` with existing `suit` and new `[Suit, Environment, Environment]` adds only `Environment` once, returns 1, sortOrder above the existing row.
  - `findOrCreateByName`: reuses the diver's `TKL` for `tkl`; claims an unowned `TKL`; ignores another diver's `TKL` and creates one for this diver.
- [ ] **Step 2: Run** them and expect FAIL (undefined).
- [ ] **Step 3: Implement** the methods (SQL guards in `customUpdate`, like `DiveRepository.fillNotesIfEmpty`).
- [ ] **Step 4: Run** the two test files and expect PASS; run `flutter test test/architecture/`.
- [ ] **Step 5: Commit** `feat(dive-log): fill-if-missing writes for imported dive details`.

### Task 3: Map codes and labels

**Files:**
- Create: `lib/features/import_wizard/data/adapters/suunto_journal_mapping.dart`
- Test: `test/features/import_wizard/data/adapters/suunto_journal_mapping_test.dart`

**Interfaces:**
- Produces:
  - `VisibilityBand? suuntoVisibilityBand(String id)`: `{'good': VisibilityBand.good}`, else null.
  - `CurrentStrength? suuntoCurrentStrength(String id)`: `{'none': CurrentStrength.none}`, else null.
  - `List<({String key, String value})> suuntoCustomFields(SuuntoJournal journal)`: in order `Suit`, `Environment`, `Comfort`, `Buoyancy`, `State of mind`, then `Visibility` / `Current` only when the code is unmapped; values joined with `", "`; empty lists omitted.

- [ ] **Step 1: Write failing tests:** `good` maps, `excellent` and `GOOD` do not (ids are compared exactly); the fixture journal yields exactly `[(Suit, Drysuit), (Environment, See), (Comfort, Optimal), (Buoyancy, Negativ, Neutral), (State of mind, Entspannt)]`; a journal with visibility `('excellent','Exzellent')` adds `(Visibility, Exzellent)`.
- [ ] **Step 2: Run** and expect FAIL. **Step 3: Implement.** **Step 4: Run** and expect PASS.
- [ ] **Step 5: Commit** `feat(import-wizard): map Suunto journal codes and labels`.

### Task 4: Write the journal onto the dive

**Files:**
- Create: `lib/features/import_wizard/data/adapters/suunto_journal_writer.dart`
- Modify: `lib/features/import_wizard/data/adapters/suunto_dive_import_core.dart` (`journalWriter` constructor param, default `SuuntoJournalWriter()`; `_fillFromWorkout` calls it after notes and buddies with the diver's scale)
- Modify: `suunto_cloud_adapter.dart`, `suunto_file_adapter.dart` (`super.journalWriter`); `lib/core/router/app_router.dart` (pass a writer built from the providers for the cloud adapter)
- Test: `test/features/import_wizard/data/adapters/suunto_journal_writer_test.dart`; extend `suunto_dive_import_core_buddies_test.dart` (rename to `suunto_dive_import_core_workout_test.dart`) with a recording journal writer

**Interfaces:**
- Consumes: Task 1 `SuuntoJournal`, Task 2 repository methods, Task 3 mapping, `DiveRepository.addWeightIfNone`, `SpeciesRepository.getOrCreateSpecies` / `getSightingsForDive` / `addSighting`.
- Produces: `class SuuntoJournalWriter({DiveFillIfEmptyRepository? fill, DiveCenterRepository? centers, DiveRepository? dives, SpeciesRepository? species})` with `Future<void> attach(String diveId, SuuntoParsedDive parsed, String diverId, {required VisibilityScale scale})`. Each of center, visibility, current, weight, sightings, custom fields runs in its own try/catch with a log line naming it. The core reads the scale as `(_ref?.read(settingsProvider) ?? const AppSettings()).visibilityScale`.

- [ ] **Step 1: Write failing writer tests** (real test database):
  - `fills an empty dive from the real workout`: center `Dive Center` linked, visibility range equals `VisibilityScale.tropical.rangeFor(VisibilityBand.good)`, current `none`, one belt weight of 12 kg, sightings `Aal`, `Barsch`, `Krebse` (count 1, new species category other), the five custom fields from Task 3.
  - `uses the diver's scale`: with `VisibilityScale.coldWater` the stored range equals `coldWater.rangeFor(good)`.
  - `leaves what the diver already logged`: dive with `visibility_meters = 8`, another center, a `suit` custom field, a weight, a sighting of an existing `aal` species: none of those change, and no second `Aal` species exists.
  - `a second attach adds nothing`: row counts for custom fields, sightings, weights and species unchanged after attaching twice.
  - `one failing detail does not stop the others`: a `DiveCenterRepository` subclass whose `findOrCreateByName` throws; every other detail is still written.
- [ ] **Step 2: Write the failing core test** `the journal writer runs on the same paths as the buddies`: new dive, replace source, folded consolidation and kept standalone call it with the right dive id and diver; skip and same-computer consolidation do not.
- [ ] **Step 3: Run** both and expect FAIL. **Step 4: Implement** the writer and wire it through the core, adapters and router. **Step 5: Run** `flutter test test/features/import_wizard/ test/core/services/suunto_cloud/ test/architecture/` and expect PASS.
- [ ] **Step 6: Commit** `feat(import-wizard): bring Suunto journal details onto imported dives`.

### Task 5: Finish

- [ ] Run `dart format .` and `flutter analyze`, expect "No issues found".
- [ ] Run `flutter test test/features/universal_import/data/services/format_detector_test.dart test/features/dive_log/ test/features/dive_centers/ test/features/marine_life/` and expect PASS.
- [ ] Update `docs/user/import-export.md` only if it lists what the Suunto import brings over (today it does not; then no change).
