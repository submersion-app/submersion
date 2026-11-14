# Set Bundles and Body Composition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An equipment set can carry other sets, weight presets and cylinder configurations and applies that whole bundle everywhere a set is applied; the weight prediction can use a typed body fat percentage, sex and birth year.

**Architecture:** A set gains three ordered id lists stored in three junction tables. A pure resolver turns a set into a bundle (gear, weight entries, cylinders). The dive editor applies a bundle to its in-memory form; one data service applies it to persisted dives for imports, bulk edit and rules. Body composition becomes an explicit fat percentage in `BodyComposition`, carried through the fitted model the way height is today.

**Tech Stack:** Flutter, Dart, Drift (SQLite), Riverpod, mockito, flutter_test.

**Spec:** `docs/design/specs/2026-11-13-set-bundles-and-body-composition-design.md`. Issue: #4525. Release: v1.8.5.

## Global Constraints

- Schema goes from 362 to 364 in one bump covering both parts. Tables live in `lib/core/database/tables/`, the helper in `lib/core/database/migrations/helpers/`, the rung in `lib/core/database/migrations/ladder/rungs_v340_onward.dart`, backstops in a `before_open` part file. `database.dart` only registers tables.
- No file over 800 lines. `equipment_set_edit_page.dart` is 799 and `dive_edit_page.dart` is 7000 with part files: new code for both goes in new files.
- Every displayed weight, volume and pressure goes through `UnitFormatter`. Stored values are metric.
- Every new string is added to every ARB locale and the generated l10n is refreshed.
- Paths are built with `p.join`; temp space through `Directory.systemTemp`.
- A test that replaces process-wide state restores it in `addTearDown`.
- TDD: the failing test first, one test file per `flutter test` run while red. Never run the whole suite locally. Before each commit: `dart format .`, `flutter analyze` (whole repo), the affected test files, and `test/architecture/` plus `test/shared/` when a file was added under `lib/`.
- Mocks are regenerated with an unfiltered `dart run build_runner build --delete-conflicting-outputs`, never `--build-filter`.
- No em-dashes in any file or message. No emojis. No tool or model attribution anywhere.
- Commits: `feat(equipment): ...` for part 1, `feat(divers): ...` or `feat(buoyancy): ...` for part 2.
- Unattended paths never replace or add to weights already on a dive and never insert a cylinder into a dive that has tanks.

## Review Focus

1. A set whose included set, weight preset or cylinder configuration was deleted, unshared, or arrived by sync in a shape that breaks one-level nesting: the bundle resolves without it and never loops. Test in Task 2 (`resolve ignores unknown ids and deeper includes`).
2. The same set applied twice, or a dive re-imported: no duplicate gear, weights or cylinders. Test in Task 9 (`applying twice changes nothing the second time`).
3. A dive holding only the legacy scalar weight: treated as having weights. Test in Task 9 (`a positive legacy weight_amount blocks the fill`).
4. A set and a set it includes landing in one pass: the inner set's lead and cylinders count once. Test in Task 9 (`an included set landing with its outer set is absorbed`).
5. Imperial units and a comma-decimal locale: totals, check titles and the body fat field read and display correctly. Tests in Task 6 (`tile shows the lead total in pounds`) and Task 19 (`body fat accepts a comma decimal`).

---

## File Structure

Created:

| File | Responsibility |
| --- | --- |
| `lib/core/database/tables/equipment_set_bundle_tables.dart` | The three junction tables. |
| `lib/core/database/migrations/helpers/set_bundle_migrations.dart` | v364 creation of the tables and the three new columns. |
| `lib/features/equipment/domain/entities/set_bundle.dart` | `SetBundle` value object. |
| `lib/features/equipment/domain/services/set_bundle_resolver.dart` | Pure resolution, nesting rule, absorption. |
| `lib/features/equipment/data/services/set_bundle_loader.dart` | Loads sets, presets and configurations and resolves bundles. |
| `lib/features/equipment/data/services/dive_set_bundle_applier.dart` | Writes a bundle's weights and tanks to a persisted dive. |
| `lib/features/equipment/presentation/providers/set_bundle_providers.dart` | `setBundleProvider`, `setBundleSummaryProvider`. |
| `lib/features/equipment/presentation/widgets/set_bundle_sections.dart` | Edit-page sections for included sets, weights, tanks. |
| `lib/features/equipment/presentation/widgets/set_bundle_summary.dart` | Read-only bundle sections for the detail page and the tile line. |
| `lib/features/dive_log/presentation/pages/dive_edit_page_set_bundle.dart` | Part file: applying a bundle to the editor form. |
| `lib/features/dive_log/presentation/widgets/set_weights_choice_dialog.dart` | Add, Replace or Keep question. |
| `lib/features/trips/domain/services/trip_set_bundle.dart` | Cylinder drafts and the lead checklist title from a bundle. |

Modified files are named in each task.

---

### Task 0: Before screenshots

**Files:**
- Untracked only: the source is kept in `.dart_tool/shots/src/shots_test.dart` and copied to `test/tmp_shots/shots_test.dart` to run. Nothing here is ever staged.

App control was declined for this work, so screenshots are widget-test renders (throwaway `matchesGoldenFile` with `--update-goldens`).

- [ ] **Step 1:** Write `shots_test.dart` with one `testWidgets` per screen, each pumping the real page with the provider overrides its own test file uses, and capturing `find.byType(MaterialApp)`:
  - set edit page (`equipment_set_edit_page_test.dart` harness), a set with six items
  - set detail page (`equipment_set_detail_figure_test.dart` harness)
  - set list with three sets (`equipment_set_list_content_test.dart` harness)
  - add body weight dialog open, and the body weight list (`body_weight_edit_page_test.dart`)
  - weight planner page scrolled to the body inputs (`weight_planner_page_test.dart`)
  - personal info page (`personal_info_edit_page_test.dart`)
  - pre-dive start sheet with a set chosen (`start_session_sheet_test.dart`)
  - trip gear tab (`trip_gear_tab_test.dart`)
  In `setUpAll` (never in a test body) load Roboto Regular, Medium and Bold and `MaterialIcons-Regular.otf` from `<flutterRoot>/bin/cache/artifacts/material_fonts/` with `FontLoader`, resolving `flutterRoot` from `flutter --version --machine`. Use the app theme through `AppThemeRegistry.resolveTheme` with `textTheme.apply(fontFamily: 'Roboto')`, light brightness. Surface: 1280 x 900 logical at `devicePixelRatio = 2.0` (so `physicalSize = Size(2560, 1800)`), with `addTearDown(tester.view.reset)`. Imperial weight units, so lead reads in pounds.
- [ ] **Step 2:** Run `flutter test test/tmp_shots/shots_test.dart --update-goldens`. Expected: all pass and write PNGs under `test/tmp_shots/goldens/`.
- [ ] **Step 3:** Open each PNG and check it shows real text and icons, not boxes. Copy them to `.dart_tool/shots/before/` named `<nn>-<screen>-before.png`, then delete `test/tmp_shots/`. Confirm `git status --porcelain` is empty.

### Task 1: Schema v364

**Files:**
- Create: `lib/core/database/tables/equipment_set_bundle_tables.dart`
- Create: `lib/core/database/migrations/helpers/set_bundle_migrations.dart`
- Modify: `lib/core/database/tables/diver_tables.dart` (after `divingSince`, line 67), `lib/core/database/tables/weight_tables.dart` (`DiverWeightEntries`, after `heightCm`)
- Modify: `lib/core/database/database.dart` (register the three tables beside 116-118; `currentSchemaVersion = 364` at 325; append `364` to `migrationVersions` after 1677)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (new `part` line in 57-137)
- Modify: `lib/core/database/migrations/ladder/rungs_v340_onward.dart` (after the v362 rung at 174-175)
- Modify: `lib/core/database/migrations/before_open_table_backstops.dart` and `before_open_child_columns.dart` (never `before_open.dart`, which is 799 lines)
- Modify: `tool/demo_data/src/seeders/gear_seeder.dart` (206-235): give one demo set an included set, a weight preset and a cylinder configuration, so `test/tool/demo_data/coverage_test.dart` finds rows. If the seeder order makes presets unavailable there, add the three tables to `demoCoverageExclusions` in `tool/demo_data/src/checks/coverage_check.dart:8` with a reason instead.
- Regenerate: `lib/features/agent_access/data/resources/sql_column_notes.generated.dart` with `dart run tool/generate_sql_column_notes.dart`
- Test: `test/core/database/migration_v364_set_bundles_test.dart` (copy the shape of `migration_v362_dive_deco_status_test.dart`)

**Interfaces:**
- Produces three Drift tables, each with an `id` primary key (the plain-id sync path `weight_preset_entries` uses, not the composite-key path of `equipment_set_items`, which has unguarded spots in `compositeHlcKeys`, `_baseTables` paging and `fetchRecord`):

  | Class / getter | Data class | Columns |
  | --- | --- | --- |
  | `EquipmentSetIncludes` / `equipmentSetIncludes` | `EquipmentSetIncludeRow` | `id`, `setId` -> `equipment_sets` cascade, `includedSetId` -> `equipment_sets` cascade, `sortOrder` int default 0, `createdAt` int, `hlc` text nullable |
  | `EquipmentSetWeightPresets` / `equipmentSetWeightPresets` | `EquipmentSetWeightPresetRow` | same, with `presetId` -> `weight_presets` cascade |
  | `EquipmentSetCylinderConfigs` / `equipmentSetCylinderConfigs` | `EquipmentSetCylinderConfigRow` | same, with `configId` -> `cylinder_configs` cascade |

  The sync entity names equal the getters. Each table has a doc comment, since the SQL notes are generated from it.
- New columns: `Divers.sex` (`text().nullable()`), `Divers.birthYear` (`integer().nullable()`), `DiverWeightEntries.bodyFatPercent` (`real().nullable()`).
- Helper functions: `_assertSetBundleTables()` returns early unless `equipment_sets`, `weight_presets` and `cylinder_configs` exist, creates each table behind `_tableExists` with `Migrator(this).createTable(...)`, then `CREATE UNIQUE INDEX IF NOT EXISTS idx_<table>_pair ON <table>(set_id, <ref column>)` for each. `_assertBodyCompositionColumns()` uses `_addColumnIfMissing` for `divers.sex TEXT`, `divers.birth_year INTEGER`, `diver_weight_entries.body_fat_percent REAL`, each behind `_tableExists`.
- Rung: `if (from < 364) await _assertSetBundleTables(); if (from < 364) await _assertBodyCompositionColumns(); if (from < 364) await reportProgress();` with a comment naming issue #4525 and that it is table-and-column only with no backfill.
- Nullable columns and new tables do not raise `minimumCompatibleSchemaVersion`.

- [ ] **Step 1: Write the failing test:** `a fresh database has the three tables and the three columns`, `a database at 362 gains them on upgrade`, `the pair index rejects the same preset twice in one set`, `deleting a set, a weight preset or a cylinder configuration removes its junction rows`, `running the helpers twice is harmless`.
- [ ] **Step 2: Run** it. Expected: fails to compile (getters missing).
- [ ] **Step 3: Implement** the tables, columns, helper, rung, backstops and registration. Run codegen unfiltered in the background: `dart run build_runner build --delete-conflicting-outputs`. Regenerate the SQL notes.
- [ ] **Step 4: Run** the new test, then each alone: `test/core/database/fresh_schema_declared_columns_test.dart`, `migration_column_names_test.dart`, `database_table_libraries_test.dart`, `test/tool/demo_data/coverage_test.dart`, `test/features/agent_access/data/resources/schema_resource_test.dart`. Expected: pass. (`change_log_policy_test.dart` and the sync guards go red until Task 1b.)
- [ ] **Step 5:** No commit yet: Task 1b completes the same schema change.

### Task 1b: Sync, change log and guards for the new schema

**Files:**
- Modify: `lib/core/database/change_log/change_log_policy.dart` (`changeLogTables` near 90: the three tables `ChangeLogClass.tracked`, keeping the map sorted; `changeLogParents` near 334: each with `ChangeLogParent(rootTable: 'equipment_sets', column: 'set_id')`)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets` near 203-209: `(table: '<table>', pk: 'id')` for each)
- Modify: `lib/core/services/sync/sync_data_serializer.dart`: mirror every `weightPresetEntries` arm for the three entities: `SyncData` field, constructor, `toJson`, `fromJson` (354/504/642/793); `_baseTables` with `table:` (1421-1426), in the same order as `toJson`; `parentGatedChildEntities` (2018); `parentGatedTables` (2257); `_buildSyncDataUnmemoised` with `_withPendingChildren` (2854-2861); `fetchRecord` (3914); `fetchRecords` (4458); `upsertRecord` (6080); `upsertRecords` (7748); `recordIdsFor` (8408); `_syncTableFor` (8954); `deleteRecord` (9598); and an `_export...` method each, gated on the parent set's `hlc` like `_exportWeightPresetEntries` (10990-11008). If the file's own size guard objects, put the three export methods in a part file as its neighbours do.
- Modify: `lib/core/services/sync/sync_service.dart`: apply list entries after `weightPresetEntries` (1837-1841) with `hasUpdatedAt: false`; `entityHasUpdatedAt` `false` (near 3096); `parentRefs` (near 3779): `setId -> equipmentSets`, `includedSetId -> equipmentSets`, `presetId -> weightPresets`, `configId -> cylinderConfigs`, all `nullable: false`
- Modify: `lib/core/services/sync/conflict_reference.dart` (`_defaultTargets` near 88-110: `includedSetId -> equipmentSets`, `presetId -> weightPresets`)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/people_planning_fields.dart` (`sex` as `FieldKind.enumValue`, `birthYear` as `FieldKind.number` beside `divingSince` at 152, `bodyFatPercent` as `FieldKind.percent` beside `heightCm` at 234) and `conflict_enum_labels_people.dart` (a labeler for `DiverSex`)
- Modify: `lib/features/agent_access/data/documents/gear_documents.dart` (`equipmentSetDocument` 128-137 gains `included_set_ids`, `weight_preset_ids`, `cylinder_config_ids`), `records/families/gear_records.dart` (250-282), `documents/profile_documents.dart` (10-37: `sex`, `birth_year`), `writes/families/diver_writes.dart` (fields 39-71, year validation 117-125, `_applied` 194-235), `documents/logbook_documents.dart` (160-166: `body_fat_percent`), `records/families/logbook_records.dart` (183-192), `writes/families/weight_entry_writes.dart` (fields 31-35, create 66-80, update 83-101, range 3 to 60)
- Modify tests that hand-list tables: `test/features/agent_access/data/records/record_catalog_guard_test.dart` (`_foldedTables` at 40), `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` near 45-55, and add `cylinder_configs` to `deletableParents` at 168-207 so the `configId` reference is guarded)
- Modify: ARB files: `settings_conflict_field_sex` "Sex", `settings_conflict_field_birthYear` "Birth year", `settings_conflict_field_bodyFatPercent` "Body fat"
- Test: `test/core/services/sync/set_bundle_lists_sync_test.dart`, `test/core/services/sync/body_composition_columns_sync_test.dart` (shape of `buddy_card_columns_sync_test.dart`)

**Interfaces:**
- Consumes: Task 1 tables.
- Produces: sync entity types `equipmentSetIncludes`, `equipmentSetWeightPresets`, `equipmentSetCylinderConfigs`, record id = the row `id`. Later tasks mark rows pending with `markRecordPending(entityType: '<entity>', recordId: row.id)` and log removals with `logDeletion`.

- [ ] **Step 1: Write the failing tests:** in `set_bundle_lists_sync_test.dart`: `a set's three lists export and apply on another database, in order`, `a junction row applies after its set, preset and configuration in one payload`, `a deleted junction row is deleted on the peer`, `a pending junction row is exported even when its set's clock did not move`. In the columns test: `sex, birth year and body fat survive an export and apply round trip`.
- [ ] **Step 2: Run** `set_bundle_lists_sync_test.dart`. Expected: fails (unknown entity type).
- [ ] **Step 3: Implement.** Add the ARB keys to all 11 locales and run `flutter gen-l10n`.
- [ ] **Step 4: Run each alone:** the two new tests; `test/core/database/change_log/change_log_policy_test.dart`; in `test/core/services/sync/`: `sync_hlc_target_registration_test.dart`, `child_hlc_test.dart`, `child_column_clears_test.dart`, `pending_child_export_test.dart`, `sync_base_streaming_parity_test.dart`, `base_publish_streaming_parity_test.dart`, `sync_data_serializer_record_ids_test.dart`, `sync_parent_refs_completeness_test.dart`; `test/architecture/child_write_restamps_test.dart`; `test/features/settings/presentation/conflicts/conflict_field_catalogue_coverage_test.dart`; `test/features/settings/presentation/widgets/conflict_reference_labels_test.dart`; `test/features/agent_access/data/records/record_catalog_guard_test.dart`; `test/features/agent_access/data/records/profile_records_test.dart`; `test/l10n/arb_parity_test.dart` and `untranslated_english_values_test.dart`. Then `flutter analyze` for the whole repository. Expected: pass and clean.
- [ ] **Step 5: Commit** `feat(equipment): schema v364 for set bundles and body composition`.

### Task 2: Set entity lists, bundle and resolver

**Files:**
- Modify: `lib/features/equipment/domain/entities/equipment_set.dart`
- Create: `lib/features/equipment/domain/entities/set_bundle.dart`
- Create: `lib/features/equipment/domain/services/set_bundle_resolver.dart`
- Test: `test/features/equipment/domain/entities/equipment_set_test.dart` (extend)
- Test: `test/features/equipment/domain/services/set_bundle_resolver_test.dart`

**Interfaces:**
- Produces:
  - `EquipmentSet.includedSetIds`, `.weightPresetIds`, `.cylinderConfigIds`: `List<String>`, default `const []`, in the constructor, `copyWith` and `props`.
  - `class SetBundle extends Equatable { final String setId; final List<String> gearIds; final List<WeightEntryDraft> weights; final List<CylinderConfigItem> cylinders; double get totalWeightKg; bool get isEmpty; bool get hasGear; List<DiveWeight> toDiveWeights({required String diveId, required String Function() newId}); }`
  - `abstract final class SetBundleResolver`:
    - `static List<String> effectiveGearIds(EquipmentSet set, Map<String, EquipmentSet> setsById)`
    - `static SetBundle resolve(EquipmentSet set, {required Map<String, EquipmentSet> setsById, required Map<String, WeightPreset> presetsById, required Map<String, CylinderConfig> configsById})`
    - `static List<EquipmentSet> absorb(List<EquipmentSet> landing)`: drops every set that another set in the list includes, keeping order.
    - `static bool canInclude(EquipmentSet outer, EquipmentSet candidate, Iterable<EquipmentSet> allSets)`: false when `candidate.id == outer.id`, when the candidate has includes, when any set already includes `outer`, or when divers differ.
    - `static List<EquipmentSet> outerSetsOf(String setId, Iterable<EquipmentSet> allSets)`
    - `static bool sameWeights(List<DiveWeight> onDive, List<WeightEntryDraft> fromBundle)`: equal length and, in order, equal `weightType`, `label`, `notes` and `amountKg` within 1e-6.

- [ ] **Step 1: Write the failing tests** in `set_bundle_resolver_test.dart`:
  - `resolve puts included sets first, then own lists`: outer set with own gear `[cam]`, preset `belt6`, config `stage`; included set with gear `[bp, reg]`, preset `base6`, config `al80`. Expect `gearIds == ['bp', 'reg', 'cam']`, weights in order base then belt, `totalWeightKg` equal to the sum, cylinders al80 then stage.
  - `resolve removes duplicate gear`: `reg` in both sets appears once.
  - `resolve counts a preset reached twice twice`.
  - `resolve renumbers cylinder sortOrder 0..n-1 across configurations`: two configurations whose items both start at `sortOrder: 0` come out 0, 1, 2 in list order.
  - `resolve ignores unknown ids and deeper includes`: an included set id missing from `setsById`, a preset id missing, and an included set that itself has `includedSetIds` (its includes are ignored, its own lists still count).
  - `absorb drops a set another landing set includes` and `absorb keeps unrelated sets in order`.
  - `canInclude` cases: self, candidate with includes, outer already included by a third set, different diver, and the allowed case.
  - `sameWeights` true for equal sequences, false for a different amount, order or length.
  - In `equipment_set_test.dart`: `copyWith carries the three lists` and `props include the three lists`.
- [ ] **Step 2: Run** `flutter test test/features/equipment/domain/services/set_bundle_resolver_test.dart`. Expected: fails to compile (types missing).
- [ ] **Step 3: Implement** the entity fields, `SetBundle` and `SetBundleResolver`. Renumbering uses `CylinderConfigItem.copyWith(sortOrder: i)` (add the `copyWith` if the entity lacks one). `toDiveWeights` mirrors `WeightPreset.toDiveWeights`.
- [ ] **Step 4: Run** both test files. Expected: pass.
- [ ] **Step 5: Commit** `feat(equipment): resolve a set into a bundle of gear, weights and tanks`.

### Task 3: Repository reads and writes the three lists

**Files:**
- Modify: `lib/features/equipment/data/repositories/equipment_set_repository_impl.dart` (639 lines; if it would pass 800, move the bundle-list reads and writes to an extension in `equipment_set_repository_bundle_lists.dart`)
- Modify: `lib/features/dive_log/data/repositories/gear_template_dive_queries.dart` (`membersOfSet`)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_gear_sets.dart` (`_setItems`)
- Modify: `lib/features/equipment/data/services/equipment_set_for_computer_linker.dart` (SQL at 84-88, member ids at the apply loop)
- Modify: `lib/features/equipment/data/services/dive_equipment_defaulter.dart` (`_applyBestSet` member ids)
- Test: `test/features/equipment/data/repositories/equipment_set_repository_bundle_lists_test.dart`
- Test: extend `test/features/dive_log/data/repositories/dive_repository_gear_sets_test.dart`, `test/features/equipment/data/services/equipment_set_for_computer_linker_test.dart`

**Interfaces:**
- Consumes: Task 1 tables, Task 2 entity fields and `SetBundleResolver.canInclude`.
- Produces on `EquipmentSetRepository`:
  - `getAllSets` and `getSetById` populate the three lists ordered by `sort_order`. `getSetById(includeItems: true)` returns `items` for the EFFECTIVE gear (own plus included sets'), while `equipmentIds` stays the set's own.
  - `Future<List<String>> getEffectiveEquipmentIds(String setId)`
  - `createSet` and `updateSet` write the three lists as a diff: insert with a fresh uuid and `sort_order` = list index, update `sort_order` when it moved, delete what left. Every inserted or re-ordered row is marked pending under its Task 1b entity name with its row `id`, and a re-order UPDATE also stamps `hlc: Value(await syncRepository.issueRowClock())` (required by `child_write_restamps_test.dart`); removals call `logDeletion` with the row `id`. A write that breaks the nesting rule throws `ArgumentError`.
  - `watchSetChanges()` also watches the three junction tables.
  - `updateSet` still returns the own-gear diff `({added, removed})`.
- `membersOfSet`, `_setItems` and the computer linker treat a set as containing its included sets' gear. Linker SQL becomes a `UNION` of direct members and members of included sets.

- [ ] **Step 1: Write the failing tests** in `equipment_set_repository_bundle_lists_test.dart` (in-memory database, as `equipment_set_repository_items_test.dart` does):
  - `createSet stores the three lists in order and getSetById returns them`.
  - `updateSet reorders, adds and removes list entries and marks them pending`: assert the junction rows and that a removed entry has a deletion logged.
  - `getSetById(includeItems: true) returns own and included sets' items; equipmentIds stays own`.
  - `getEffectiveEquipmentIds unions own and included gear without duplicates`.
  - `updateSet throws when the set would include a set that has includes`, `... include itself`, `... gain includes while another set includes it`.
  - `deleting a weight preset removes it from the set`, same for a cylinder configuration and an included set (cascade).
  - `watchSetChanges ticks when a junction row changes`.
  - Extend the gear-sets test: `bulkAddEquipmentSets adds an included set's gear tagged with the outer set`. Extend the linker test: `a set that reaches the computer through an included set is applied`.
- [ ] **Step 2: Run** the new file. Expected: fails to compile or fails on the first expectation.
- [ ] **Step 3: Implement.** Load the lists for many sets with one query per junction table (`where setId.isIn(ids)`), not per set.
- [ ] **Step 4: Run** the new file, then `dive_repository_gear_sets_test.dart`, `equipment_set_for_computer_linker_test.dart`, `dive_equipment_defaulter_set_test.dart`, `dive_repository_set_history_test.dart`, `test/architecture/repository_tick_stream_test.dart`, each alone. Expected: pass.
- [ ] **Step 5: Commit** `feat(equipment): store included sets, weight presets and cylinder configurations on a set`.

### Task 4: Bundle loader and providers

**Files:**
- Create: `lib/features/equipment/data/services/set_bundle_loader.dart`
- Create: `lib/features/equipment/presentation/providers/set_bundle_providers.dart`
- Test: `test/features/equipment/data/services/set_bundle_loader_test.dart`
- Test: `test/features/equipment/presentation/providers/set_bundle_providers_test.dart`

**Interfaces:**
- Produces:
  - `class SetBundleLoader { SetBundleLoader({EquipmentSetRepository? sets, WeightPresetRepository? presets, CylinderConfigRepository? configs}); Future<List<SetBundle>> load(List<String> setIds, {required String? diverId}); Future<SetBundle?> loadOne(String setId); }`. `load` returns bundles in the order given, after `SetBundleResolver.absorb`, skipping unknown ids. It reads all of the diver's sets, presets and configurations once.
  - `final setBundleLoaderProvider = Provider<SetBundleLoader>(...)`
  - `final setBundleProvider = FutureProvider.family<SetBundle?, String>(...)`: re-runs on `watchSetChanges()`, `watchWeightPresetsChanges()` and `watchConfigsChanges()`.
  - `class SetBundleSummary { final int gearCount; final double leadKg; final int cylinderCount; }` and `final setBundleSummaryProvider = FutureProvider.family<SetBundleSummary?, String>(...)`.

- [ ] **Step 1: Write the failing tests:** `load resolves each set with its presets and configurations`, `load absorbs an included set that is also requested`, `load skips an unknown set id`, `setBundleProvider refreshes when a preset's entries change`.
- [ ] **Step 2: Run.** Expected: fails to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both files. Expected: pass.
- [ ] **Step 5: Commit** `feat(equipment): load set bundles for the pages and the apply paths`.

### Task 5: Set edit page sections

**Files:**
- Create: `lib/features/equipment/presentation/widgets/set_bundle_sections.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_set_edit_page.dart` (state fields, `_values`, `_initializeFromSet`, `_initializeFromClone`, the `EquipmentSet(...)` built in `_saveSet`, one widget inserted after the geofences editor). Net growth must stay under the 800-line guard: move `_buildEquipmentCheckbox` to a private widget file if needed.
- Modify: `lib/features/equipment/presentation/helpers/equipment_set_form_values.dart` (constructor, `blank`, `of`, `retainingEquipment`, `props`)
- Modify: `lib/features/equipment/domain/services/equipment_set_clone_seed.dart` (copy the three lists)
- Modify: `lib/features/agent_access/data/writes/families/equipment_set_writes.dart` (`create` at 177 and `update` at 217 carry the three lists so an agent update does not wipe them; expose them as `included_set_ids`, `weight_preset_ids`, `cylinder_config_ids` relations beside `equipment_ids`)
- Modify: ARB files for the new strings
- Test: `test/features/equipment/presentation/widgets/set_bundle_sections_test.dart`
- Test: extend `equipment_set_form_values_test.dart`, `equipment_set_clone_seed_test.dart`, `equipment_set_edit_page_test.dart`, `equipment_set_edit_discard_test.dart`

**Interfaces:**
- Consumes: Task 2 `canInclude`, Task 4 providers, `WeightPresetPickerSheet`, `EquipmentSetPickerSheet`, `cylinderConfigsProvider`.
- Produces: `class SetBundleSections extends ConsumerWidget { const SetBundleSections({super.key, required this.setId, required this.diverId, required this.includedSetIds, required this.weightPresetIds, required this.cylinderConfigIds, required this.onIncludedSetsChanged, required this.onWeightPresetsChanged, required this.onCylinderConfigsChanged}); }` with `ValueChanged<List<String>>` callbacks. Three sections, each a header with an add action and a `ReorderableListView` (shrink-wrapped) of rows with a remove button. The weights header shows the total through `UnitFormatter.formatWeight`. Below the three, a line "Applies in total: N items, W, C cylinders" from a locally resolved bundle. The cylinder configuration add action opens a simple bottom sheet listing `cylinderConfigsProvider` (the existing `ApplyConfigurationMenu` is a popup, not reusable here). The set add action lists only sets passing `canInclude`.
- New l10n keys (English): `equipment_setEdit_includedSets_title` "Included sets", `equipment_setEdit_includedSets_add` "Add set", `equipment_setEdit_weights_title` "Weights", `equipment_setEdit_weights_add` "Add weight preset", `equipment_setEdit_weights_total` "Total {weight}", `equipment_setEdit_tanks_title` "Tanks", `equipment_setEdit_tanks_add` "Add cylinder configuration", `equipment_setEdit_bundle_total` "Applies in total: {items} items, {weight}, {cylinders} cylinders", `equipment_setEdit_bundle_noGearHint` "A set with no gear leaves no set tag on a dive, so it cannot be removed from a dive as a set."

- [ ] **Step 1: Write the failing tests:**
  - sections test: `adding a weight preset reports the new ordered list`, `removing an included set reports the list without it`, `the set picker hides sets that cannot be included`, `the weights total follows the unit setting` (imperial shows `lb`), `reordering reports the new order`.
  - form values: `props differ when a list changes or its order changes`.
  - clone seed: `the seed copies the three lists`.
  - edit page: `saving passes the three lists to the repository`, and in the discard test `adding a weight preset marks the form changed`.
- [ ] **Step 2: Run** the sections test. Expected: fails to compile.
- [ ] **Step 3: Implement.** Add every key to every ARB locale and refresh generated l10n.
- [ ] **Step 4: Run** the five test files one at a time, then `test/architecture/` and `test/shared/`. Expected: pass.
- [ ] **Step 5: Commit** `feat(equipment): edit a set's included sets, weights and tanks`.

### Task 6: Set detail page, tile and picker

**Files:**
- Create: `lib/features/equipment/presentation/widgets/set_bundle_summary.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart` (insert the summary after the gear list, before geofences; mark gear rows that come from an included set)
- Modify: `lib/features/equipment/presentation/widgets/equipment_set_tile.dart` (subtitle count from `setBundleSummaryProvider`, plus lead total and cylinder count when non-zero)
- Modify: `lib/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart` (`requireGear` flag; a set is tappable when it has items, or when `!requireGear` and its bundle is not empty)
- Modify: `lib/features/weight_planner/presentation/widgets/rig_composer.dart` (pass `requireGear: true`)
- Test: `test/features/equipment/presentation/widgets/set_bundle_summary_test.dart`, extend `equipment_set_list_content_test.dart`, `equipment_set_picker_sheet_test.dart`, `equipment_set_detail_labels_test.dart`

**Interfaces:**
- Consumes: Task 4 providers.
- Produces: `class SetBundleSummaryCard extends ConsumerWidget { const SetBundleSummaryCard({super.key, required this.set}); }`; `EquipmentSetPickerSheet({..., bool requireGear = false})`.
- New l10n keys: `equipment_setDetail_fromSet` "From {setName}", `equipment_sets_leadTotal` "{weight} lead", `equipment_sets_cylinderCount` plural "{count} cylinder(s)".

- [ ] **Step 1: Write the failing tests:** `summary lists included sets, presets with a total, and configurations`, `tile shows the lead total in pounds` (imperial settings, 5.44 kg shows `12.0 lb`), `tile counts effective gear`, `picker offers a set with only weights`, `picker with requireGear hides a set with only weights`, `detail marks gear that comes from an included set`.
- [ ] **Step 2: Run** the summary test. Expected: fails to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the four files one at a time, plus `equipment_set_detail_figure_test.dart` and `test/features/global_search/presentation/global_search_rows_test.dart` (both render the tile or the detail figure). Expected: pass.
- [ ] **Step 5: Commit** `feat(equipment): show a set's bundle on its page, tile and picker`.

### Task 7: Set history over effective gear

**Files:**
- Modify: `lib/features/equipment/presentation/helpers/equipment_set_history_save.dart`
- Modify: `lib/features/equipment/presentation/widgets/assembly_history_dialog.dart` (`askSetHistory` gains `List<String> alsoSetIds = const []`, whose logged-dive counts are added)
- Test: extend `test/features/equipment/presentation/helpers/equipment_set_history_save_test.dart`, `test/features/dive_log/data/repositories/dive_repository_set_history_test.dart`

**Interfaces:**
- Consumes: `SetBundleResolver.effectiveGearIds`, `outerSetsOf`, `equipmentSetsProvider`, `DiveRepository.rewriteSetOnDives`.
- Produces: `saveSetWithHistory` keeps its signature. Before `updateSet` it captures the effective gear of the set and of every set that includes it; after, it recomputes them and replays `SetItemAdded` / `SetItemRemoved` on each set id whose effective gear changed. The question is asked when any of those diffs is non-empty.

- [ ] **Step 1: Write the failing tests:** `changing the included sets asks and rewrites dives carrying the set`, `editing an included set's gear rewrites dives carrying the outer set`, `changing only weight presets or cylinder configurations does not ask and replays nothing`, and in the repository test `rewriteSetOnDives keeps gear that an included set still provides`.
- [ ] **Step 2: Run** the helper test. Expected: the three new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both files and `equipment_set_edit_history_test.dart`. Expected: pass.
- [ ] **Step 5: Commit** `feat(equipment): update past dives when an included set changes`.

### Task 8: Dive editor applies the bundle

**Files:**
- Create: `lib/features/dive_log/presentation/pages/dive_edit_page_set_bundle.dart` (part of `dive_edit_page.dart`, like `dive_edit_page_annotations.dart`)
- Create: `lib/features/dive_log/presentation/widgets/set_weights_choice_dialog.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`: the four call sites (`_applyEquipmentDefaultsOnEmpty` 4367, `_reevaluateGeofenceForSite` 4388, the suggestion banner Apply 4472, `_showEquipmentSetPicker` 4756) call the new method after `_addGear`; the `items.isEmpty` guards become "bundle is empty".
- Test: `test/features/dive_log/presentation/pages/dive_edit_set_bundle_test.dart`
- Test: `test/features/dive_log/presentation/widgets/set_weights_choice_dialog_test.dart`

**Interfaces:**
- Consumes: `setBundleProvider`, `SetBundleResolver.sameWeights`, `DiveTankConfigAdapter.apply`, `confirmCylinderOverwrites`, `GearExpander`.
- Produces:
  - `enum SetWeightsChoice { add, replace, keep }` and `Future<SetWeightsChoice?> showSetWeightsChoiceDialog(BuildContext context, {required String setName, required String setTotal, required String currentTotal})`.
  - In the part file: `Future<void> _applySetBundle(EquipmentSet set, {required bool auto})`. Order of work:
    1. Load the bundle (`setBundleProvider(set.id).future`). Null or empty: return.
    2. Absorb: for every set id in `GearTree.setIds(_gearRows)` that `set.includedSetIds` contains, re-tag its rows to `set.id` and remember its bundle.
    3. Weights. Empty `_weights`: fill. Else if the bundle has weights: when `_weights` matches the combined weights of the absorbed sets (`sameWeights`), replace silently; else when `auto`, leave; else ask and act on the choice (null means keep).
    4. Tanks. Bundle has cylinders and the form still holds the untouched starter (`!_tanksDirty && !widget.isEditing && _tanks.length == 1`): replace `_tanks` with `adapter.apply(tanks: const [], items: bundle.cylinders, ...).tanks`. Otherwise merge with `adapter.apply(tanks: _tanks, ...)`; when it reports overwrites and `!auto`, call `confirmCylinderOverwrites(configName: set.name)` and re-apply with `overwrite: true` on yes, skip tanks on no. Any tank change sets `_tanksDirty = true` and bumps `_tankRowGeneration`.
    5. `_markDirty()` only when `!auto`, matching `_addGear(markDirty:)`.
- New l10n keys: `diveLog_edit_setWeights_title` "Use the weights from {setName}?", `diveLog_edit_setWeights_body` "This dive already has {current}. The set carries {setTotal}.", `diveLog_edit_setWeights_add` "Add", `diveLog_edit_setWeights_replace` "Replace", `diveLog_edit_setWeights_keep` "Keep current".

- [ ] **Step 1: Write the failing tests** in `dive_edit_set_bundle_test.dart` (harness copied from `dive_edit_equipment_default_test.dart` and `dive_edit_apply_cylinder_config_test.dart`):
  - `a new dive with a default set gets its gear, weights and cylinders, and the starter tank is replaced with the set's gas` (set config AL80 EAN32: the form shows one tank at 32%).
  - `picking a set on a dive with weights asks, and Add appends`, `... Replace swaps`, `... Keep leaves them`.
  - `picking a set that includes the auto-applied default shows one set chip and replaces the default's weights without asking`.
  - `picking a set whose cylinder differs from an edited tank asks before overwriting, and declining still applies gear and weights`.
  - `a set with only weights can be picked and fills the Weights section`.
  - `auto-apply leaves the form clean` (no unsaved-changes prompt on back).
  - Dialog test: each button pops its `SetWeightsChoice`.
- [ ] **Step 2: Run** `dive_edit_set_bundle_test.dart`. Expected: fails.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the two new files, then `dive_edit_equipment_default_test.dart`, `dive_edit_geofence_suggestion_test.dart`, `dive_edit_gear_tree_test.dart`, `dive_edit_weight_preset_test.dart`, `dive_edit_apply_cylinder_config_test.dart`, each alone. Expected: pass.
- [ ] **Step 5: Commit** `feat(dive-log): apply a set's weights and tanks in the dive editor`.

### Task 9: Unattended bundle applier

**Files:**
- Create: `lib/features/equipment/data/services/dive_set_bundle_applier.dart`
- Modify: `test/architecture/agent_write_coverage_exempt.dart` if the guard lists the new write methods
- Test: `test/features/equipment/data/services/dive_set_bundle_applier_test.dart`

**Interfaces:**
- Consumes: `SetBundleLoader`, `CylinderConfigApplier.plan`, `ExistingTank`, `DiveRepository.bulkAddWeights`, `bulkReplaceWeights`, `DiveChildRowRepository.addTank` and `updateTank`.
- Produces:
  - `class DiveSetBundleApplier { DiveSetBundleApplier({AppDatabase? db, SetBundleLoader? loader, DiveRepository? dives, DiveChildRowRepository? rows}); }`
  - `Future<({bool weights, bool tanks})> apply({required String diveId, required List<String> setIds})`: loads the bundles (absorbed, in the given order); combines their weights and cylinders. Weights: written with `bulkAddWeights` only when the dive has no `dive_weights` rows and `dives.weight_amount` is null or not positive. Tanks: `CylinderConfigApplier.plan` over the dive's `dive_tanks` rows; with no rows, every `InsertTank` is written with `addTank`; with rows, only `FillTank` ops are written with `updateTank`, skipping fills for tanks named by an overwrite that changes the role (the rule `DiveTankConfigAdapter.apply` uses). Returns what changed. Never throws to the caller: failures are logged and reported as no change.
  - `Future<({bool weights, bool tanks})> applyTagged({required String diveId, String? leadSetId, bool retagAbsorbed = false})`: the set ids are `leadSetId` first, then the distinct `via_set_id` values on the dive's gear ordered by set name. With `retagAbsorbed`, gear rows tagged with a set that another landing set includes are re-tagged to that outer set through `DiveRepository.replaceGearRows`, so the dive shows one chip. New-dive seams pass `true`; the existing-dive seam passes `false`.
  - `Future<bool> swapWeights({required String diveId, required String fromSetId, required String toSetId})`: when the dive's weights equal the `from` bundle's (`sameWeights`), replaces them with the `to` bundle's through `bulkReplaceWeights` (an empty list removes them) and returns true.

- [ ] **Step 1: Write the failing tests** (in-memory database):
  - `fills weights and inserts cylinders on a dive with neither`.
  - `leaves weights alone when the dive has weight rows`.
  - `a positive legacy weight_amount blocks the fill`.
  - `with tanks present it fills a missing size and inserts nothing` (dive tank back gas with null volume; set has back gas AL80 and a deco cylinder: volume filled, still one tank).
  - `it never changes a gas mix or a size that is already set`.
  - `two sets landing together combine their weights in order`.
  - `an included set landing with its outer set is absorbed` (weights equal the outer bundle once).
  - `applying twice changes nothing the second time` (returns false, false; row counts equal).
  - `applyTagged puts the lead set first and orders the rest by name`.
  - `applyTagged with retagAbsorbed moves an included set's gear tags to the outer set`, and `without it the tags stay`.
  - `swapWeights replaces untouched weights and leaves edited ones`, `swapWeights removes them when the new set has none`.
  - `written rows are marked pending for sync`.
- [ ] **Step 2: Run.** Expected: fails to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the file and `test/architecture/`. Expected: pass.
- [ ] **Step 5: Commit** `feat(equipment): apply a set's weights and tanks to saved dives`.

### Task 10: Import seams and location re-match

**Files:**
- Modify: `lib/features/equipment/data/services/dive_equipment_defaulter.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (new-dive branch near 1802 and after `insertTanks` near 2090; existing-dive branch near 2457)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (after 3245), `health_dive_writer.dart` (after 111), `lib/features/dive_import/presentation/providers/dive_import_providers.dart` (after 408)
- Test: extend `dive_equipment_defaulter_set_test.dart`, `dive_equipment_defaulter_position_test.dart`; new `test/features/dive_log/data/repositories/dive_computer_import_set_bundle_test.dart`; extend `uddf_entity_importer_test.dart`

**Interfaces:**
- Consumes: Task 9 applier, Task 3 effective ids.
- Produces on `DiveEquipmentDefaulter`:
  - `Future<String?> applyDefaultSetIfEmpty({required String diveId, required String? diverId, required List<GeoPoint> divePoints})`: the id of the set it chose, or null. A best set with no usable gear but a non-empty bundle is still returned (no gear is written). `applyDefaultEquipmentIfEmpty` delegates and returns `!= null`.
  - `Future<String?> applySetForImportedDive(Dive dive)`; `applyForImportedDive` delegates.
  - `applyForNewPosition`: after it applies a best set it calls `applier.apply(diveId, [setId])`; in the swap branch it calls `applier.swapWeights(...)` then `applier.apply(diveId, [fencedId])`.
  - Constructor gains `DiveSetBundleApplier? bundleApplier`.
- Seams: file, UDDF and Health seams call `DiveSetBundleApplier().applyTagged(diveId: dive.id, leadSetId: <id from the defaulter>)` after the computer-set linker. The computer download keeps the defaulter and linkers where they are, remembers the defaulter's set id in a local, and calls `applyTagged` after `insertTanks` inside the new-dive path. The existing-dive seam calls `applyTagged(diveId:)` after its linker.

- [ ] **Step 1: Write the failing tests:**
  - defaulter: `the default set's weights and cylinders land on an imported dive`, `a default set with no gear still applies its weights`, `a dive that already has gear gets nothing`.
  - position: `replacing the default set swaps untouched weights for the fenced set's`, `edited weights survive the swap`.
  - computer import: `a downloaded dive keeps the computer's tanks, gets the set's size filled in, and gets no extra cylinder`; `a downloaded dive with no tanks from the computer gets the set's cylinders`; `the default set and a computer-linked set combine their weights`.
  - UDDF importer: `an imported dive with its own weights keeps them`.
- [ ] **Step 2: Run** the defaulter set test. Expected: new tests fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** each touched test file alone, plus `gear_twin_defaulter_ordering_test.dart`, `import_positioned_equipment_test.dart`, `dive_import_notifier_test.dart`. Regenerate mocks if a mocked class gained a method. Expected: pass.
- [ ] **Step 5: Commit** `feat(equipment): apply set weights and tanks on import`.

### Task 11: Bulk edit

**Files:**
- Modify: `lib/features/dive_log/domain/entities/bulk_edit_request.dart` (new `class SetBundlesOp extends BulkCollectionOp { final List<String> setIds; }`)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart` (snapshot weights and tank ids when a `SetBundlesOp` is present; apply; undo)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` bulk mode (`_bulkUseEquipmentSet` 4913 records the picked set id; op assembly 2156-2270 emits one `SetBundlesOp`; the summary row names it) and `lib/features/dive_log/presentation/widgets/bulk_equipment_sets.dart` if the staging lives there
- Test: `test/features/dive_log/data/services/bulk_dive_edit_set_bundles_test.dart`, extend `bulk_membership_wiring_test.dart`

**Interfaces:**
- Consumes: Task 9 `apply`.
- Produces: `SetBundlesOp`. In the service: before the transaction work, `priorWeights` is captured for all target dives and `tanksBefore` is taken when a `SetBundlesOp` is present; filled tank rows are captured in `priorTankSpecRows`; after the ops, `createdTankIds = tanksAfter - tanksBefore`. Undo then restores through the existing `bulkReplaceWeights`, `_tankUndo.undo` and `bulkRestoreTankRows` paths. A set picked in bulk mode with no gear is still staged.

- [ ] **Step 1: Write the failing tests:** `a SetBundlesOp fills weights only on dives without them`, `it inserts cylinders only on dives without tanks and fills gaps on the rest`, `undo removes the weights and cylinders it wrote and restores filled columns`, `undo leaves dives it did not change untouched`; wiring test: `using a set in bulk mode sends its gear and a SetBundlesOp`.
- [ ] **Step 2: Run** the service test. Expected: fails to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the two files, `bulk_dive_edit_service_equipment_sets_test.dart`, `bulk_dive_edit_tank_undo_test.dart`. Expected: pass.
- [ ] **Step 5: Commit** `feat(dive-log): bulk edit applies a set's weights and tanks, with undo`.

### Task 12: Rules

**Files:**
- Modify: `lib/features/rules/data/services/dive_rule_applier.dart` (`_equipmentSets` 172-212, `writeMembership` 258-261)
- Modify: `lib/features/rules/data/services/rule_undo_service.dart` (`_undoOne` 226-247: route fields `weights` and `tanks`)
- Modify: `lib/features/rules/presentation/widgets/rule_change_list.dart` and `rule_labels.dart` so the two new fields have labels
- Test: `test/features/rules/data/rule_set_bundles_test.dart`, extend `rule_undo_service_test.dart`, `rule_change_list_test.dart`

**Interfaces:**
- Consumes: Task 9 `apply`.
- Produces: after `bulkAddEquipmentSets` in an add action, `apply(diveId, setIds)` runs for each target dive. For each dive whose weights changed, a `ruleChange(rule, id, 'weights', before, after)` is recorded, where each side is a list of `{'id', 'type', 'kg', 'label', 'notes'}`. For tanks, `ruleChange(rule, id, 'tanks', before, after)` with each side a list of `{'id', 'role', 'volume', 'pressure', 'material', 'start', 'name', 'o2', 'he', 'order'}`. A dive counts as changed by the action when its gear, weights or tanks changed. Undo: when the dive's current weights equal `after`, restore `before` with `bulkReplaceWeights`; when its current tanks equal `after`, delete the tanks whose ids are not in `before` and restore the changed columns of the rest with `bulkRestoreTankRows`. Otherwise the change is reported as blocked, as other fields are.
- New l10n keys: `rules_change_weights` "Weights", `rules_change_tanks` "Tanks".

- [ ] **Step 1: Write the failing tests:** `adding a set by rule fills weights and records the change`, `a dive with weights is not touched and records nothing for weights`, `undo restores weights and removes inserted cylinders`, `undo is blocked for weights the diver edited after the run`, `the change list labels the two fields`.
- [ ] **Step 2: Run** `rule_set_bundles_test.dart`. Expected: fails.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the three files and `rule_equipment_sets_test.dart`, `rule_undo_membership_test.dart`. Expected: pass.
- [ ] **Step 5: Commit** `feat(rules): a rule that adds a set applies its weights and tanks, with undo`.

### Task 13: Dive planner tanks

**Files:**
- Modify: `lib/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart` (`_showSetPicker` 104-123)
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (new notifier method)
- Test: extend `test/features/dive_planner/presentation/plan_gear_weights_section_test.dart`, `dive_planner_providers_test.dart`

**Interfaces:**
- Produces: `void DivePlanNotifier.addSetCylinders(List<CylinderConfigItem> items, {required String Function() newId})`. When the plan's only tank equals `defaultPlanTank(id: thatTank.id)`, it is removed first. Each item becomes a tank through `DiveTankConfigAdapter().tankFromItem`; an item is skipped when the plan has a tank with the same role, volume, working pressure and gas mix, or when its role is not breathing gas. One state update, `isDirty: true`.

- [ ] **Step 1: Write the failing tests:** `adding a set's cylinders replaces the untouched default tank`, `an edited default tank is kept`, `a cylinder already in the plan is not added again`, `a suit inflation cylinder is skipped`; widget: `picking a set adds its gear and cylinders to the plan`.
- [ ] **Step 2: Run** the providers test. Expected: fails to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both files. Expected: pass.
- [ ] **Step 5: Commit** `feat(planner): a set adds its cylinders to the plan`.

### Task 14: Pre-dive checklist

**Files:**
- Modify: `lib/features/pre_dive/domain/services/session_item_composer.dart` (new parameter)
- Modify: `lib/features/pre_dive/presentation/widgets/start_session_sheet.dart` (`sessionSetGear` uses effective gear; `_begin` builds the titles)
- Test: extend `session_item_composer_test.dart`, `start_session_sheet_test.dart`, `session_set_gear_test.dart`

**Interfaces:**
- Produces: `compose({..., List<String> setCheckTitles = const []})`. The titles become plain `PreDiveItemType.check` rows, no `equipmentId`, appended right after the set's gear rows with the placeholder's `sectionId` and `isRequired`. The sheet builds them: one for the lead, `preDive_setChecks_weights` "Weights: {total} ({breakdown})" with each entry as "label or type, amount", and one per cylinder, its label or `formatTankVolume` plus mix. The agent write path passes none.

- [ ] **Step 1: Write the failing tests:** `set check titles follow the set's gear rows as plain checks`, `no titles means the rows are unchanged`; sheet: `a session from a set with 5.44 kg of lead shows a Weights check in pounds`; `sessionSetGear includes an included set's gear`.
- [ ] **Step 2: Run** the composer test. Expected: fails to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the three files. Expected: pass.
- [ ] **Step 5: Commit** `feat(pre-dive): a session from a set checks its weights and cylinders`.

### Task 15: Trip gear

**Files:**
- Create: `lib/features/trips/domain/services/trip_set_bundle.dart`
- Modify: `lib/features/trips/presentation/widgets/gear/trip_gear_add_sheet.dart` (`_apply` 172-246 and the set case at 74-78)
- Test: `test/features/trips/domain/services/trip_set_bundle_test.dart`, extend `test/features/trips/presentation/widgets/gear/trip_gear_tab_test.dart`

**Interfaces:**
- Produces:
  - `List<TripCylinder> tripCylinderDraftsFromBundle(SetBundle bundle, {required String tripId, required List<TripCylinder> existing, required DateTime now})`: one spec-only draft per cylinder (label, volume, working pressure, material), minus those already on the board, matched one for one against slots with a null `equipmentId` on those four fields.
  - `Future<String?> pickTripChecklist(BuildContext context, List<TripChecklist> checklists)`: a simple dialog, returns the chosen id.
  - In `_apply`: after packing gear, slot the drafts through `createCylinders`; then for a bundle with lead, find the trip's checklists: none means no item and the snackbar adds `trips_gear_leadNoChecklist`; one is used; several ask. The item title is `trips_gear_leadItem` "Lead: {weight}"; it is skipped when that checklist already has an item with the same title.
- New l10n keys: `trips_gear_leadItem`, `trips_gear_leadNoChecklist` "Lead was not added: this trip has no checklist.", `trips_gear_pickChecklist` "Add the lead to which checklist?".

- [ ] **Step 1: Write the failing tests:** `drafts skip cylinders already slotted, one for one` (two AL80 in the bundle, one on the board: one draft), `drafts carry label, size, pressure and material`; widget: `adding a set slots its cylinders and adds a lead item to the only checklist`, `with no checklist the lead is skipped and the message says so`, `adding the same set again adds nothing`.
- [ ] **Step 2: Run** the domain test. Expected: fails to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** both files and `trip_cylinder_repository_test.dart`. Expected: pass.
- [ ] **Step 5: Commit** `feat(trips): adding a set slots its cylinders and lists its lead`.

### Task 16: UDDF carries included sets

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (set element near 1350-1380), `uddf_import_parsers.dart` (`parseEquipmentSet` 917), `lib/features/dive_import/data/services/uddf_entity_importer.dart` (`_importEquipmentSets` 2285-2334)
- Test: extend the existing UDDF set export and import tests (find with `grep -rl "equipmentsets" test/`)

**Interfaces:**
- Produces: each exported set writes one `<includedsetref ref="..."/>` child per included set, using the same id scheme as the set's own id. Import reads them into `includedSetIds` after all sets exist, dropping references it cannot resolve or that break the nesting rule.

- [ ] **Step 1: Write the failing tests:** `a set's included sets survive an export and import round trip`, `an unresolvable included-set reference is dropped`.
- [ ] **Step 2: Run.** Expected: fails.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the touched files. Expected: pass.
- [ ] **Step 5: Commit** `feat(equipment): UDDF keeps a set's included sets`.

### Task 17: Body fields on the entities

**Files:**
- Modify: `lib/core/constants/app_enums.dart` (new `enum DiverSex { female, male }`)
- Modify: `lib/features/divers/domain/entities/diver.dart` (`DiverSex? sex`, `int? birthYear`; `copyWith` with the `_unset` sentinel; `props`)
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (`_mapRowToDiver` 1211-1245; companions in `createDiver` 280-310 and `updateDiver` 387-411)
- Modify: `lib/features/divers/domain/entities/diver_weight_entry.dart` (`double? bodyFatPercent`)
- Modify: `lib/features/divers/data/repositories/diver_weight_entry_repository.dart` (`_mapRow`, create and update companions)
- Test: extend `diver_copywith_clear_test.dart`, `diver_repository_test.dart`, `diver_weight_entry_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 columns `divers.sex`, `divers.birth_year`, `diver_weight_entries.body_fat_percent`.
- Produces: the fields above. `sex` is stored as the enum name; an unknown stored name reads as null.

- [ ] **Step 1: Write the failing tests:** `copyWith sets and clears sex and birthYear`, `a diver's sex and birth year round-trip through the repository`, `an unknown stored sex reads as null`, `a weight entry's body fat round-trips`, `an entry without body fat reads null`.
- [ ] **Step 2: Run** the entry repository test. Expected: fails to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the three files. Expected: pass.
- [ ] **Step 5: Commit** `feat(divers): store body fat percentage, sex and birth year`.

### Task 18: Body composition model

**Files:**
- Modify: `lib/core/buoyancy/body_composition.dart`
- Modify: `lib/core/buoyancy/weight_prediction_engine.dart` (`RigSpec` 45-79, `fit` 149-170 and 271, `FittedWeightModel` 344-373, `predict` 392-408)
- Modify: `lib/features/dive_log/data/services/buoyancy_twin_assembler.dart` (`composeRigTerms` 124-160)
- Modify: `lib/features/dive_log/presentation/widgets/buoyancy_section.dart` (268) and `lib/features/weight_planner/presentation/widgets/weight_prediction_card.dart` (49): label for the measured term
- Test: extend `test/core/buoyancy/body_composition_test.dart`, `weight_prediction_engine_test.dart`, `test/features/dive_log/data/services/buoyancy_twin_assembler_test.dart`

**Interfaces:**
- Produces in `BodyComposition`:
  - Constants `minBodyFatPercent = 3.0`, `maxBodyFatPercent = 60.0`, `neutralAgeYears = 40`, `minAdultAgeYears = 16`, `measuredTermLabel = 'bodyFat'`.
  - `static bool isPlausibleBodyFat(double percent)`
  - `static int? ageYears({required int? birthYear, required DateTime at})`: null for a null birth year or an age under 16.
  - `static double estimatedFatPercent({required double bmi, int? ageYears, DiverSex? sex})` = `1.20 * bmi + 0.23 * (ageYears ?? 40) - 10.8 * (male 1, female 0, null 0.5) - 5.4`.
  - `static double referenceFatPercent(double bodyMassKg)`: the estimate at `referenceHeightCm` with neutral age and sex.
  - `static int? displayEstimate({required double? weightKg, required double? heightCm, required int? ageYears, required DiverSex? sex})`: null unless all four are known and plausible; rounded and clamped to 3..60.
  - `static bool hasTerm({required double bodyMassKg, required double? heightCm, double? bodyFatPercent})`: a plausible typed value, or a computable BMI.
  - `static double leadTermKg({required double bodyMassKg, required double? heightCm, double? bodyFatPercent, int? ageYears, DiverSex? sex})` = `bodyMassKg * leadPerKgFatSwap * (fat - reference) / 100`; zero when `hasTerm` is false.
  - `static String termLabelFor({double? bodyFatPercent})`: `measuredTermLabel` for a plausible typed value, else `termLabel`.
- `RigSpec` gains `double? bodyFatPercent`. `fit` gains `double? bodyFatPercent, int? ageYears, DiverSex? sex`. `FittedWeightModel` gains the same three fields, kept only when the fit subtracted a term; `bodyCompositionCalibrated` becomes `heightCm != null || bodyFatPercent != null || supportingDives == 0`. `predict` and `composeRigTerms` use the rig's or caller's `bodyFatPercent`, else the model's, and the model's age and sex. `composeRigTerms` gains `double? bodyFatPercent`.
- New l10n key: `tools_weight_bodyFatTerm` "Body fat (measured)".

- [ ] **Step 1: Write the failing tests:**
  - `with no body fat, sex or age the term equals the BMI term`: for masses 45, 60, 80, 110, 140 kg and heights 150, 165, 175, 190, 205 cm, the new `leadTermKg` equals `mass * 0.012 * 0.2 * (bmi - referenceBmi)` within 1e-9.
  - `a typed body fat replaces the estimate`: 80 kg, 175 cm, typed 20: term equals `80 * 0.2 * (20 - referenceFatPercent(80)) / 100`.
  - `a typed body fat needs no height`.
  - `male lowers and female raises the term by the same amount`: 80 kg at 175 cm, age 40: minus and plus `80 * 0.2 * 5.4 / 100`.
  - `age above 40 raises the term`.
  - `an age under 16 counts as unknown`, `an implausible typed value is ignored`.
  - `displayEstimate is null unless all four inputs are known` and `displayEstimate rounds and clamps`.
  - Engine: `fit remembers the body inputs it subtracted and predict adds the same term back` (a fit with typed 25 then `predict` with an empty rig carries a `bodyFat` term equal to the fit's), `predict with a rig body fat overrides the model's`, `a fit without a real body weight subtracts nothing and stores no body inputs`.
  - Assembler: `composeRigTerms labels a measured term bodyFat`.
- [ ] **Step 2: Run** `body_composition_test.dart`. Expected: fails to compile.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** the three files, then `test/features/weight_planner/presentation/weight_prediction_card_test.dart`. Expected: pass, including every pre-existing test unchanged.
- [ ] **Step 5: Commit** `feat(buoyancy): use measured body fat, sex and age in the weight prediction`.

### Task 19: Body inputs in the app

**Files:**
- Modify: `lib/features/divers/presentation/providers/diver_weight_entry_providers.dart` (new providers)
- Modify: `lib/features/weight_planner/presentation/providers/weight_planner_providers.dart` (`fit` call at 78-86 passes the new inputs)
- Modify: `lib/features/settings/presentation/pages/body_weight_edit_page.dart` (dialog field, estimate line, list subtitle, dispose the dialog's controllers)
- Modify: `lib/features/weight_planner/presentation/widgets/rig_composer.dart` and `weight_planner_page.dart` (body fat `NumberField`, estimate helper, `_predict`, `_buoyancyOutcome`, `_saveBodyWeightToProfile`)
- Modify: `lib/features/settings/presentation/pages/personal_info_edit_page.dart` (Sex dropdown, Birth year field)
- Test: extend `diver_weight_entry_providers_test.dart`, `body_weight_edit_page_test.dart`, `weight_planner_page_test.dart`, `personal_info_edit_page_test.dart`, `weight_planner_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 17 and 18.
- Produces:
  - `latestDiverBodyFatProvider = FutureProvider<double?>`: the newest entry with a plausible `bodyFatPercent`.
  - `diverBodyProfileProvider = FutureProvider<({DiverSex? sex, int? ageYears})>`: from the current diver, age at today.
  - Sex uses `DropdownButtonFormField<DiverSex?>` with a null "Not set" item (pattern: `instructor_picker_field.dart:88`). Birth year is a `TextFormField` validated with `numberValidator(context, integer: true, ...)` to 1900 through the current year.
- New l10n keys: `bodyWeight_bodyFatLabel` "Body fat (%)", `bodyWeight_bodyFatHelper` "Optional. Left blank, body composition is estimated from height and weight.", `bodyWeight_bodyFatEstimate` "Estimated: about {percent}%", `bodyWeight_bodyFatEstimateHint` "Add sex and birth year under Personal info to see an estimate.", `bodyWeight_bodyFatRange` "Enter a value from 3 to 60", `bodyWeight_bodyFatValue` "{percent}% body fat", `diverProfile_sex_label` "Sex", `diverProfile_sex_female` "Female", `diverProfile_sex_male` "Male", `diverProfile_sex_notSet` "Not set", `diverProfile_birthYear_label` "Birth year", `diverProfile_bodyEstimate_note` "Used only to estimate body composition for weight prediction.", `diverProfile_birthYear_invalid` "Enter a year from 1900 to {year}".

- [ ] **Step 1: Write the failing tests:**
  - providers: `latest body fat carries forward past an entry without one`, `an implausible stored value is skipped`.
  - body weight page: `saving with body fat stores it`, `body fat accepts a comma decimal` (locale `de`, input `18,5` stores 18.5), `a value outside 3 to 60 is rejected`, `the estimate shows when weight, height, sex and birth year are known`, `the hint shows otherwise`, `the list shows body fat on entries that have it`.
  - weight planner: `typing body fat changes the prediction and labels the term measured`, `saving to the profile stores the typed body fat`.
  - personal info: `sex and birth year save to the diver`, `clearing both saves nulls`, `a birth year in the future is rejected`.
  - planner providers: `the calibration passes body fat, sex and age to fit`.
- [ ] **Step 2: Run** `diver_weight_entry_providers_test.dart`. Expected: fails to compile.
- [ ] **Step 3: Implement.** Add every key to every ARB locale and refresh generated l10n.
- [ ] **Step 4: Run** the five files one at a time, then `diver_profile_hub_page_test.dart`, `rig_composer_gear_picker_test.dart`, `test/architecture/`, `test/shared/`. Expected: pass.
- [ ] **Step 5: Commit** `feat(divers): enter body fat, sex and birth year`.

### Task 20: Screenshots and wrap-up

**Files:**
- No tracked files. Throwaway tests live in `test/tmp_shots/` and are deleted before the last commit.

- [ ] **Step 1:** Re-run the throwaway screenshot tests written before Task 1 against the finished code, with new states added: set edit with the three sections, set detail with the bundle summary, set list tile, the editor's weights question, add body weight dialog with the estimate, weight planner body inputs, personal info with Sex and Birth year, a pre-dive session from a set, trip gear after adding a set. Light theme; add dark and phone width only where colours or layout changed.
- [ ] **Step 2:** Copy the PNGs out, delete `test/tmp_shots/` and its goldens, confirm `git status` shows no leftover.
- [ ] **Step 3:** `dart format .`, `flutter analyze`, `test/architecture/`, `test/shared/`, `test/core/database/`.
- [ ] **Step 4:** If the build corrected anything else in the design doc, update it and commit `docs(equipment): align the set bundle design with the build`.
