# Logbook Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (the maintainer chose inline execution). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optional, diver-defined rules ("if this query matches, do these actions") that run on dives and sites after an import, after creating by hand, or on demand, with a preview, a detailed change list, and a synced history whose runs can be undone later.

**Architecture:** A new feature `lib/features/rules/`. A rule stores its condition as the existing versioned query JSON and its actions as a new versioned JSON list. A `RuleEngine` runs rules in order inside one transaction. It finds each rule's matches with `QueryIdSetRunner` (scoped to the target ids the trigger supplies, and to what the diver may edit), applies actions through the existing dive bulk primitives and new site writes, and records one `rule_run_changes` row per field changed. A dry run is the same pass rolled back. `RuleUndoService` reverses a run, skipping anything edited since. Three new synced, diver-owned tables (schema rung 292).

**Tech Stack:** Flutter, Dart, Drift (SQLite), Riverpod 3, go_router, ARB localisation (11 locales).

**Spec:** `docs/design/specs/2026-10-18-logbook-rules-design.md` (issue #3513). Read it first; this plan argues from it.

## Global Constraints

- One PR, release v1.8.3, `Closes #3513`.
- No rules exist by default; with no rules every flow behaves exactly as before.
- Rules never run on sync, backup restore, undo, merge or buddy mirroring.
- A rule may change only what the diver could change by hand: dives with `diver_id` = the rule's diver, and sites with `diver_id` = the rule's diver and `shared_library_id IS NULL`. Unlogged planned dives (`is_planned = 1`) are never targets.
- New tables live in `lib/core/database/tables/rule_tables.dart`, never in `database.dart`; every file stays under 800 lines (`dive_edit_page.dart` and `site_edit_page.dart` already exceed it: add only a call there, put logic in new files).
- Schema rung 292 (re-check the next free number before pushing; main moves).
- Every user-facing string is in ARB, translated into all 10 non-en locales (`ar de es fr he hu it nl pt zh`), and `flutter gen-l10n` is run AFTER the translations (memory: l10n ordering trap).
- Values are stored canonical (metres, bar, Celsius, enum `.name`, entity ids) and shown and entered in the active diver's units.
- No em dashes anywhere (code, comments, ARB, commits). No mention of the tool in any commit or PR text.
- Paths built with `p.join`; tests restore any global state they replace; tests use `setUpTestDatabase()` / `tearDownTestDatabase` from `test/helpers/test_database.dart`.
- `dart format .`, `flutter analyze`, the affected tests and `test/architecture/` before each commit that adds files under `lib/`.

## Review Focus

1. **A large logbook:** "Run all" over 3,000 dives must not exceed SQLite's bound-variable limit. Every `IN (...)` list of ids is chunked at 500 (Task 6 pins it with a 1,200-dive test).
2. **A referenced item deleted elsewhere:** a tag, gear item, type, buddy, course, trip or centre that a rule names is deleted, possibly on another device and arriving by sync. The rule's other actions still run, that action is reported as skipped, and nothing throws (Task 8).
3. **Imperial diver:** a "set swell height 3 ft" action stores 0.9144 m and shows "3 ft" in the card, the preview and the history (Tasks 3 and 12).
4. **A rule changed or deleted after it ran:** the history still shows the rule's name from the time of the run, and undo still works with `rule_id` null (Task 10).
5. **The data moves between preview and Apply:** Apply recomputes rather than replaying the preview, and the result count it reports is the real one (Task 13).

---

## File Structure

New, under `lib/features/rules/`:

| File | Responsibility |
| --- | --- |
| `domain/rule_subject.dart` | `RuleSubject`, `RuleTrigger`, `RuleRunTrigger` enums |
| `domain/entities/rule.dart` | `Rule`, `RuleLoadProblem` |
| `domain/entities/rule_action.dart` | sealed `RuleAction` and its variants, `DiveCollection`, `SiteCollection`, `MembershipMode` |
| `domain/site_rule_field.dart` | `SiteRuleField` enum (column, value kind) |
| `domain/rule_field_value.dart` | `RuleValueKind`, value maps for set-field actions, `bulkInputsFor` |
| `domain/rule_actions_json.dart` | versioned JSON for action lists, `RuleJsonException` |
| `domain/entities/rule_run.dart` | `RuleRun`, `RuleChange`, `RuleRunResult`, `RuleUndoResult` |
| `data/repositories/rule_repository.dart` | rules CRUD, reorder, duplicate, watch |
| `data/repositories/rule_run_repository.dart` | runs and changes: insert, list, mark undone, delete |
| `data/services/rule_target_scope.dart` | eligibility SQL, chunked id queries, match count |
| `data/services/dive_rule_applier.dart` | applies one dive action to ids, returns `RuleChange`s |
| `data/services/site_rule_applier.dart` | the same for sites |
| `data/services/rule_engine.dart` | ordered pass, dry run, recording |
| `data/services/rule_undo_service.dart` | undo with skip rules |
| `data/services/rule_target_labels.dart` | labels for the change list (dive number, site, date; site name, place) |
| `presentation/providers/rule_providers.dart` | repositories, engine, lists, runs |
| `presentation/pages/rules_page.dart` | Settings > Manage > Rules |
| `presentation/pages/rule_edit_page.dart` | the editor |
| `presentation/pages/rule_history_page.dart` | history list |
| `presentation/pages/rule_run_page.dart` | one run's change list and undo |
| `presentation/widgets/rule_action_card.dart` | one action's card |
| `presentation/widgets/rule_action_picker_sheet.dart` | "+ Add action" picker |
| `presentation/widgets/rule_value_input.dart` | per-kind value input, unit-aware |
| `presentation/widgets/rule_change_list.dart` | change list, grouped by target or rule |
| `presentation/widgets/rule_preview_sheet.dart` | preview then Apply |
| `presentation/widgets/import_rules_box.dart` | the import summary box |
| `presentation/run_rules_flow.dart` | `runRulesOnDemand`, `runRulesAfterCreate` (preview, apply, snackbars) |

Other new files: `lib/core/database/tables/rule_tables.dart`, `lib/core/database/migrations/helpers/rule_migrations.dart`, tests mirroring each under `test/features/rules/`, `test/core/database/migration_v292_rules_test.dart`, `test/core/services/sync/rules_sync_round_trip_test.dart`.

Moved: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` → `lib/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart` (the data layer needs `BulkField` and `buildScalarCompanion`).

---

### Task 1: Move the bulk scalar field set into the domain layer

**Files:**
- Move: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart` → `lib/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart`
- Modify: its two importers (find with `grep -rln bulk_edit_field_set.dart lib test`)

**Interfaces:**
- Produces: `BulkField`, `BulkScalarInputs`, `buildScalarCompanion(Set<BulkField>, BulkScalarInputs) → DivesCompanion` at the new path, unchanged.

- [ ] **Step 1:** `git mv` the file, update both imports.
- [ ] **Step 2:** Run `flutter analyze` and `flutter test test/features/dive_log/presentation/pages/` (bulk edit tests). Expected: clean, PASS.
- [ ] **Step 3:** Commit `refactor(dive-log): move the bulk scalar field set into the domain layer`.

### Task 2: Rule domain model and action JSON

**Files:**
- Create: `domain/rule_subject.dart`, `domain/entities/rule.dart`, `domain/entities/rule_action.dart`, `domain/site_rule_field.dart`, `domain/rule_actions_json.dart`
- Test: `test/features/rules/domain/rule_actions_json_test.dart`, `test/features/rules/domain/rule_test.dart`

**Interfaces:**
- Produces:
  - `enum RuleSubject { dives, sites }` with `QuerySubject get querySubject`.
  - `enum RuleTrigger { afterImport, afterManualCreate }`. Stored as comma-joined names; unknown names are dropped on read.
  - `enum RuleRunTrigger { imported, createdByHand, onDemandAll, onDemandSelection }`.
  - `enum MembershipMode { add, remove }`.
  - `enum DiveCollection { diveTypes, tags, equipment, buddies, courses }`.
  - `enum SiteCollection { tags, siteTypes }`.
  - `sealed class RuleAction`. Its variants:
    - `SetDiveFieldAction(BulkField field, Map<String, Object?> values)`
    - `DiveMembershipAction(DiveCollection collection, MembershipMode mode, List<String> ids, {String? buddyRoleId})`
    - `AppendDiveNotesAction(String text)`
    - `SetSiteFieldAction(SiteRuleField field, Object value)`
    - `SiteMembershipAction(SiteCollection collection, MembershipMode mode, List<String> ids)`
    - `AppendSiteDescriptionAction(String text)`
    - `UnknownRuleAction(Map<String, Object?> raw)`
  - `bool get appliesTo(RuleSubject)` on each variant. Value equality on all variants.
  - `enum SiteRuleField` with members `waterType, difficulty, country, region, city, island, bodyOfWater, minDepth, maxDepth, altitude, entryMethod, exitMethod, hazards, accessNotes, mooringNumber, parkingInfo`. Each member carries `String column` (the SQL column) and `RuleValueKind kind`.
  - `const int kRuleActionsJsonVersion = 1;`
  - `Map<String, Object?> ruleActionsToJson(List<RuleAction>)` produces `{'version': 1, 'actions': [{'kind': ..., ...}]}`.
  - `List<RuleAction> ruleActionsFromJson(Map<String, Object?>)`: throws `RuleJsonException` for a missing or newer version or a malformed shape. An unknown `kind` becomes `UnknownRuleAction`.
  - `enum RuleLoadProblem { unreadable, invalid, unknownSubject, unresolvedRef, newerVersion }`.
  - `class Rule` holds:
    - `id`, `diverId`, `subject`, `name`, `enabled`
    - `Set<RuleTrigger> triggers`
    - `QueryNode? condition`, `String conditionJson`
    - `List<RuleAction> actions`, `String actionsJson`
    - `int sortOrder`, `DateTime createdAt`, `DateTime updatedAt`
    - `RuleLoadProblem? problem`
    - `copyWith`
    - `bool get isRunnable => problem == null && actions.isNotEmpty && !actions.any((a) => a is UnknownRuleAction)`

- [ ] **Step 1: Write the failing tests.**
  - `round-trips every action kind`: one instance of each known variant goes through `ruleActionsFromJson(ruleActionsToJson(list))` and comes back equal.
  - `refuses a newer version`: `{'version': 2, 'actions': []}` throws `RuleJsonException`.
  - `keeps an unknown kind`: `{'kind': 'addTank'}` comes back as `UnknownRuleAction` with the raw map intact.
  - `a rule with an unknown action is not runnable`.
  - `a rule with no actions is not runnable`.
  - `triggers parse ignoring unknown names`: `'afterImport,later'` gives `{afterImport}`.
- [ ] **Step 2:** `flutter test test/features/rules/domain/`. Expected: FAIL (files missing).
- [ ] **Step 3:** Implement the files. The JSON keys per kind are `setDiveField{field, values}`, `diveMembership{collection, mode, ids, role?}`, `appendDiveNotes{text}`, `setSiteField{field, value}`, `siteMembership{collection, mode, ids}` and `appendSiteDescription{text}`. Enum values are written as `.name`.
- [ ] **Step 4:** Run the tests. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): rule domain model and versioned action JSON`.

### Task 3: Set-field values and unit handling

**Files:**
- Create: `domain/rule_field_value.dart`
- Test: `test/features/rules/domain/rule_field_value_test.dart`

**Interfaces:**
- Consumes: `BulkField`, `BulkScalarInputs`, `buildScalarCompanion` (Task 1).
- Produces:
  - `enum RuleValueKind { text, number, enumName, boolean, rating, entityRef }`.
  - `RuleValueKind diveFieldKind(BulkField)`.
  - `List<String> diveFieldValueKeys(BulkField)`: the `BulkScalarInputs` member names a field writes. For example, `visibility` → `['visibilityMeters', 'visibilityMinMeters', 'visibilityMaxMeters']`, `diluentGas` → `['diluentO2', 'diluentHe']`, `diveCenter` → `['diveCenterId']`.
  - `BulkScalarInputs bulkInputsFor(BulkField field, Map<String, Object?> values)`.
  - `DivesCompanion diveCompanionFor(SetDiveFieldAction a) => buildScalarCompanion({a.field}, bulkInputsFor(a.field, a.values))`.
  - `FieldDimension? diveFieldDimension(BulkField)` and `FieldDimension? siteFieldDimension(SiteRuleField)` (depth, length, pressure, temperature or none), used by the UI for unit conversion.
  - `List<BulkField> kRuleSettableDiveFields`: every `BulkField` except `diverRole`, which rides `DiverRolesOp` and is not in the catalogue.

- [ ] **Step 1: Write failing tests.**
  - `every settable field builds a non-empty companion` from a sample value per kind.
  - `visibility writes the three columns and clears the legacy bucket`, matching bulk edit.
  - `diluent writes O2 and He`.
  - `swell height 0.9144 is stored as given (metres)`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): set-field values over the bulk edit field set`.

### Task 4: Tables, migration rung 292, backstop and indexes

**Files:**
- Create: `lib/core/database/tables/rule_tables.dart`, `lib/core/database/migrations/helpers/rule_migrations.dart`, `test/core/database/migration_v292_rules_test.dart`
- Modify:
  - `lib/core/database/database.dart`: import, add the 3 tables to `@DriftDatabase(tables:)`, `currentSchemaVersion` 292, append 292 to `migrationVersions`
  - `lib/core/database/migrations/app_database_migrations.dart`: `part` line
  - `lib/core/database/migrations/ladder/rungs_v231_onward.dart`: rung 292
  - `lib/core/database/migrations/before_open_table_backstops.dart`: backstop call
  - `lib/core/database/performance_indexes.dart`: indexes
  - The schema-version tripwire test: demote the previous `== currentVersion` assertion to `contains(291)`

**Interfaces:**
- Produces three Drift tables:
  - `@DataClassName('RuleRow') class Rules` with columns:
    - `id` text PK, `diverId` text nullable FK→Divers
    - `subject`, `name` text; `enabled` bool default true; `triggers` text default `'afterImport'`
    - `conditionJson`, `actionsJson` text; `sortOrder` int default 0
    - `createdAt`, `updatedAt` int; `hlc` text nullable
  - `@DataClassName('RuleRunRow') class RuleRuns` with columns:
    - `id` PK, `diverId` nullable FK→Divers, `trigger` text
    - `sourceLabel`, `deviceLabel` text nullable
    - `ranAt` int, `changedCount` int, `undoneAt` int nullable
    - `createdAt`, `updatedAt`, `hlc`
  - `@DataClassName('RuleRunChangeRow') class RuleRunChanges` with columns:
    - `id` PK, `runId` text FK→RuleRuns ON DELETE CASCADE
    - `subject`, `targetId` text; `ruleId` text nullable, no FK (the rule may be deleted); `ruleName` text
    - `field` text, `beforeJson`, `afterJson` text, `sortOrder` int
    - `createdAt`, `updatedAt`, `hlc`
- Indexes:
  - `idx_rules_diver(diver_id, subject, sort_order)`
  - `idx_rule_runs_diver(diver_id, ran_at)`
  - `idx_rule_run_changes_run(run_id, sort_order)`
  - `idx_rule_run_changes_target(subject, target_id)`
- Migration helper: `extension RuleMigrations on AppDatabase { Future<void> _assertRuleSchema() }`. It is idempotent, returns early if `divers` is missing, and is modelled on `_assertSavedQueriesSchema`.

- [ ] **Step 1: Write the failing migration test.** Model it on `migration_v238_saved_queries_test.dart`:
  - a v291 database migrates to 292 with the three tables and four indexes;
  - running the backstop twice is harmless;
  - `migrationVersions.last == 292 == currentSchemaVersion`.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement, then run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 4:** Run `flutter test test/core/database/`. Expected: PASS, including `database_table_libraries_test.dart` and the tripwire.
- [ ] **Step 5:** Commit `feat(rules): rules, rule_runs and rule_run_changes tables (v292)`.

### Task 5: Sync registration and diver ownership

**Files:**
- Modify:
  - `lib/core/data/repositories/sync_repository.dart` (`hlcTargets`)
  - `lib/core/services/sync/sync_data_serializer.dart`: every arm `savedQueries` has, which are `SyncData` field, ctor default, `toJson`, `fromJson`, `_baseTables`, export, `fetchRecord`, `fetchRecords`, `upsertRecord`, `upsertRecords`, `recordIdsFor`, `recordIdForEntity`, `deleteAllRecords`, `_syncTableFor` and `deleteRecord`. Use entity names `rules`, `ruleRuns`, `ruleRunChanges`.
  - `lib/core/services/sync/sync_service.dart`:
    - add to `mergeOrder`, with `ruleRunChanges` after `ruleRuns`
    - add to `entityHasUpdatedAt`
    - `parentRefs`: `'ruleRunChanges': [(field: 'runId', parent: 'ruleRuns', nullable: false)]`
  - `lib/features/divers/data/repositories/diver_owned_rows.dart`: add `rules` and `rule_runs` to the owned tables; the change rows go with their run by cascade.
  - `lib/features/settings/presentation/conflicts/catalogue/conflict_field_catalogue.dart`: labels for every new non-bookkeeping column, with ARB keys.
  - Guard-test fixtures that list entities explicitly:
    - `test/core/services/sync/sync_parent_refs_completeness_test.dart`
    - `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart`
    - `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart`
- Test: `test/core/services/sync/rules_sync_round_trip_test.dart`. Model it on `saved_queries_sync_round_trip_test.dart`.

**Interfaces:**
- Produces: the three entities sync like `savedQueries`. Deleting a diver deletes and tombstones its rules and runs.

- [ ] **Step 1: Write the failing round-trip test.**
  - A rule, a run and two changes exported on device A and applied on device B arrive equal.
  - A deleted run tombstones and removes its changes on B.
  - A change whose run is missing is dropped, not fatal.
- [ ] **Step 2:** Run it, plus `flutter test test/core/services/sync/ test/features/divers/ test/features/settings/presentation/conflicts/`. Expected: the new test FAILs; the guards FAIL naming the new entities.
- [ ] **Step 3:** Implement every arm until all of those pass.
- [ ] **Step 4:** Run the same command. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): sync rules and their run history per diver`.

### Task 6: Repositories and target scope

**Files:**
- Create: `data/repositories/rule_repository.dart`, `data/repositories/rule_run_repository.dart`, `data/services/rule_target_scope.dart`
- Test: `test/features/rules/data/rule_repository_test.dart`, `rule_run_repository_test.dart`, `rule_target_scope_test.dart`

**Interfaces:**
- Consumes: Tasks 2 and 4; `loadSavedQuery` (wrap a rule's condition as a transient `SavedQuery` to reuse its validation); `QueryIdSetRunner`, `compileQuery`, `appQueryRegistry`.
- Produces:
  - `RuleRepository`. Use `entityType = 'rules'`, plus `_stamp` that marks pending and notifies, as `SavedQueryRepository` does.
    - `Stream<void> watchRulesChanges()`
    - `Future<List<Rule>> getAll({required RuleSubject subject, required String diverId, required NameIndex names})`: ordered by `sort_order`, then name. Each rule's `problem` is set from `loadSavedQuery` and from `RuleJsonException` (`newerVersion`).
    - `Future<Rule?> getById(String id, {required NameIndex names})`
    - `Future<String> create({required String diverId, required RuleSubject subject, required String name, required Set<RuleTrigger> triggers, required QueryNode? condition, required List<RuleAction> actions})`: `sortOrder` = max + 1.
    - `Future<void> update(Rule rule)`
    - `Future<void> setEnabled(String id, bool enabled)`
    - `Future<void> reorder(RuleSubject subject, String diverId, List<String> orderedIds)`
    - `Future<String> duplicate(String id)`: the name gets the localised " (copy)" suffix, passed in by the caller.
    - `Future<void> delete(String id)`: calls `logDeletion`.
  - `RuleRunRepository`
    - `Stream<void> watchRunsChanges()`
    - `Future<String> insertRun({required String diverId, required RuleRunTrigger trigger, String? sourceLabel, String? deviceLabel, required List<RuleChange> changes})`: one transaction. Sets `changedCount` to the number of distinct `(subject, targetId)` pairs.
    - `Future<List<RuleRun>> getRuns(String diverId)`: newest first.
    - `Future<RuleRun?> getRun(String id)`
    - `Future<List<RuleChange>> getChanges(String runId)`
    - `Future<void> markUndone(String id, DateTime at)`
    - `Future<void> deleteRun(String id)`
    - `Future<void> deleteAllRuns(String diverId)`
  - `RuleChange`: `subject`, `targetId`, `ruleId?`, `ruleName`, `field` (a `BulkField.name`, a `DiveCollection.name`, `notes`, a `SiteRuleField.name`, a `SiteCollection.name`, or `description`; `subject` disambiguates), `Object? before`, `Object? after`. Both values are JSON-encodable.
  - `RuleRun`: `id`, `diverId`, `trigger`, `sourceLabel`, `deviceLabel`, `ranAt`, `changedCount`, `undoneAt`.
  - `RuleTargetScope`
    - `const int kRuleIdChunk = 500;`
    - `QueryScope scopeFor(RuleSubject s, String diverId, Iterable<String> chunkIds)`:
      - dives: `r0.diver_id = ? AND COALESCE(r0.is_planned, 0) = 0 AND r0.id IN (...)`
      - sites: `r0.diver_id = ? AND r0.shared_library_id IS NULL AND r0.id IN (...)`
    - `Future<Set<String>> matches(Rule rule, String diverId, Set<String> targetIds)`: chunked over `kRuleIdChunk`. An empty condition matches every eligible target.
    - `Future<Set<String>> allEligibleIds(RuleSubject s, String diverId)`
    - `Future<int> countMatches(QueryNode? condition, RuleSubject s, String diverId)`: for the editor's live count.

- [ ] **Step 1: Write the failing tests.**
  - Repository:
    - create, list in order, reorder, duplicate, delete with tombstone;
    - rows of another diver are not listed;
    - a rule with an unresolved reference loads with `problem == unresolvedRef`;
    - a rule whose actions JSON is version 2 loads with `problem == newerVersion`.
  - Run repository:
    - `changedCount` counts distinct targets, not changes;
    - newest first;
    - deleting a run removes its changes.
  - Scope:
    - another diver's dive is never matched;
    - a planned dive is never matched;
    - a library site is never matched;
    - another profile's shared site is never matched;
    - `depth > 30` matches only the deep dive;
    - **1,200 target ids** returns the right set without error (chunking);
    - an empty condition matches all eligible targets.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): rule and run repositories, and the editable-target scope`.

### Task 7: Site write primitives

**Files:**
- Modify: `lib/features/dive_sites/data/repositories/site_classification_repository.dart` (add `removeTags`, `removeTypes`), `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (add `appendDescription`)
- Test: the existing tests for those repositories (add cases)

**Interfaces:**
- Produces:
  - `Future<void> removeTags(String siteId, List<String> tagIds, {bool notify = true, String? actingDiverId})`
  - `Future<void> removeTypes(String siteId, List<String> typeIds, {bool notify = true, String? actingDiverId})`
  - Both mirror `addTags`/`addTypes`: the same library guard and the same child-row sync handling (tombstone each removed `site_tags`/`site_site_types` row).
  - `Future<void> appendDescription(String siteId, String text)`: writes `description || (description = '' ? '' : '\n') || text`, bumps `updatedAt` and marks pending.
  - Set-field writes reuse `applyImportedMetadata(siteId, DiveSitesCompanion)`.

- [ ] **Step 1: Write failing tests.**
  - `removeTags removes only the named tags and tombstones them`.
  - `removeTags on a site without the tag is a no-op`.
  - The same pair for types.
  - `appendDescription adds a newline only when the description is not empty`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(dive-sites): remove site tags and types, append to a description`.

### Task 8: Action appliers

**Files:**
- Create: `data/services/dive_rule_applier.dart`, `data/services/site_rule_applier.dart`
- Test: `test/features/rules/data/dive_rule_applier_test.dart`, `site_rule_applier_test.dart`

**Interfaces:**
- Consumes: the dive repository bulk primitives (`bulkUpdateFields`, `bulkAddTags`/`bulkRemoveTags`, `bulkAddDiveTypes`/`bulkRemoveDiveTypes`, `bulkAddEquipment`/`bulkRemoveEquipment`, `bulkAddCourses`/`bulkRemoveCourses`, `BuddyRepository.bulkAddBuddies`/`bulkRemoveBuddies`); Task 3; Task 7.
- Produces:
  - `class AppliedAction { final List<RuleChange> changes; final bool skippedMissingRef; }`
  - `DiveRuleApplier.apply(Rule rule, RuleAction action, List<String> diveIds) → Future<AppliedAction>`
  - `SiteRuleApplier.apply(Rule rule, RuleAction action, List<String> siteIds) → Future<AppliedAction>`
- Semantics. Each applier reads "before" for the given ids, works out the ids where the action changes something, writes only those, and records one `RuleChange` per changed target:
  - **Set field.** `before` and `after` are maps of column name → value for the columns `diveCompanionFor` writes (one column for a site field). A target already holding the "after" map gets no write and no change.
  - **Membership.** `before` and `after` are the sorted id lists of that collection on the target. Buddies are lists of `{'id': buddyId, 'role': roleId}`. Adding an id that is present, or removing one that is absent, changes nothing.
  - **Append.** `before` and `after` are the full text. The separator is `\n` only when `before` is not empty.
  - **Missing reference.** Ids that no longer exist (tag, type, gear, buddy, course, site type, trip, centre) are dropped from the action. If nothing is left, the action changes nothing and `skippedMissingRef` is true.
  - **Notifications.** Never notify (`notify: false` where offered); the engine notifies once.

- [ ] **Step 1: Write failing tests** (dives and sites; three dives at 20, 35 and 45 m):
  - `set water type overwrites an existing value and records before/after`.
  - `set to the value already held records nothing`.
  - `add dive type Deep to two dives, one already Deep, records one change`.
  - `remove tag records the list without it`.
  - `append notes uses a newline only after existing text`.
  - `add a deleted tag is skipped with skippedMissingRef`.
  - `add buddy carries the role`.
  - Sites: `set country`, `add site tag`, `remove site type`, `append description`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Batch reads per collection over the id list, chunked at `kRuleIdChunk`.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): apply dive and site actions and record each change`.

### Task 9: Rule engine

**Files:**
- Create: `data/services/rule_engine.dart`, `domain/entities/rule_run.dart` (`RuleRunResult` alongside `RuleRun`)
- Test: `test/features/rules/data/rule_engine_test.dart`

**Interfaces:**
- Consumes: Tasks 6 and 8; `DeviceDisplayNameService().resolve()` for `deviceLabel`; `SyncEventBus.notifyLocalChange()`.
- Produces:
  - `class RuleRunRequest { final String diverId; final RuleRunTrigger trigger; final String? sourceLabel; final Map<RuleSubject, Set<String>?> targets; final List<String>? onlyRuleIds; final bool includeDisabled; }`
    - A `null` target set means all eligible ids of that subject.
    - `onlyRuleIds` narrows the run to those rules, for "Run on all" from a row; with it, `includeDisabled` is true.
    - Automatic triggers filter rules by trigger (`afterImport` for `imported`, `afterManualCreate` for `createdByHand`). On-demand triggers ignore trigger flags.
  - `class RuleRunResult { final String? runId; final List<RuleChange> changes; final int changedTargetCount; final Map<String, int> changedCountByRule; final List<String> skippedRuleNames; final List<String> skippedActionRuleNames; final int targetCount; }`
  - `RuleEngine.preview(RuleRunRequest) → Future<RuleRunResult>`: `runId` is null and the database is unchanged.
  - `RuleEngine.run(RuleRunRequest) → Future<RuleRunResult>`: writes and records; `runId` is null when nothing changed, and then no run row is written.
- Algorithm:
  - One `db.transaction`. Dive rules first, then site rules; within a subject, `sortOrder` order.
  - For each runnable rule: `matches` over that subject's target set, evaluated against the current transaction state; then each action in order through the applier.
  - Rules that are not runnable go to `skippedRuleNames`.
  - `preview` runs the same body and throws a private `_RollbackPreview` carrying the result. It catches the throw outside the transaction and returns the result, so the preview and the apply share one code path.
  - `run` inserts the run (Task 6) inside the same transaction and calls `notifyLocalChange()` once after commit.

- [ ] **Step 1: Write failing tests.**
  - `chaining`: rule 1 "if depth > 30 add equipment Drysuit" and rule 2 "if gear.name = Drysuit add tag cold". Both apply to the 35 m dive. Swapping their order leaves the tag off.
  - `preview leaves the database unchanged and equals the later run's changes`.
  - `nothing changed writes no run row and returns runId null`.
  - `disabled rule is skipped by automatic and Run all, but runs with onlyRuleIds`.
  - `afterImport-only rule does not run for createdByHand`.
  - `rule with an unresolved condition is reported in skippedRuleNames, others still run`.
  - `targets limit the run to the given ids`.
  - `notifies once per run` (count `SyncEventBus` notifications; restore it in tearDown).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): ordered rule engine with a rollback preview`.

### Task 10: Undo

**Files:**
- Create: `data/services/rule_undo_service.dart`
- Test: `test/features/rules/data/rule_undo_service_test.dart`

**Interfaces:**
- Consumes: Tasks 6 to 9.
- Produces:
  - `class RuleUndoResult { final int restoredTargets; final int skippedEditedTargets; final int skippedDeletedTargets; final bool nothingYet; final bool alreadyUndone; }`
  - `RuleUndoService.undo(String runId) → Future<RuleUndoResult>`: one transaction, one notify.
- Per change:
  - **Field:** the current column map equals `after` → write `before`; otherwise skipped (edited).
  - **Membership:** `added = after − before` is removed where still present; `removed = before − after` is re-added where still absent. For buddies, re-add with the recorded role. Counted as restored if any item was reverted, otherwise as skipped (edited).
  - **Append:** if the current text ends with `after.substring(before.length)`, strip that suffix; otherwise skipped.
  - **Missing target:** counted as skipped (deleted).
- If not a single change could be reverted and at least one change exists, the result is `nothingYet` and the run is NOT marked undone. Otherwise `markUndone(now)`. A run already undone returns `alreadyUndone` and writes nothing.

- [ ] **Step 1: Write failing tests.**
  - `restores a field still at the rule's value`.
  - `skips a field edited since and reports it`.
  - `membership undo removes the rule's addition but keeps a type the diver added after`.
  - `re-adds a removed tag only if still absent`.
  - `strips appended notes only while they still end the text`.
  - `deleted dive counts as skipped`.
  - `nothing revertible leaves the run undoable (nothingYet)`.
  - `second undo is refused`.
  - `undo works after the rule was deleted (ruleId null)`, with the history keeping `ruleName`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): undo a rule run, skipping later edits`.

### Task 11: Providers, routes and the Rules page

**Files:**
- Create: `presentation/providers/rule_providers.dart`, `presentation/pages/rules_page.dart`, `data/services/rule_target_labels.dart`
- Modify: `lib/core/router/app_router.dart` (routes `/rules`, `/rules/new`, `/rules/:id`, `/rules/history`, `/rules/history/:runId`), `lib/features/settings/presentation/pages/settings_page.dart` (Manage entry after Saved queries), `lib/l10n/arb/app_en.arb`
- Test: `test/features/rules/presentation/rules_page_test.dart`

**Interfaces:**
- Produces:
  - Repository and service providers: `ruleRepositoryProvider`, `ruleRunRepositoryProvider`, `ruleEngineProvider`, `ruleUndoServiceProvider`. They carry `// no-tick:` comments, as service providers do for the provider-tick guard.
  - `rulesProvider.family<List<Rule>, RuleSubject>`: active diver, invalidated on `watchRulesChanges` and on the name index.
  - `ruleRunsProvider`: active diver, invalidated on `watchRunsChanges`.
  - `RuleTargetLabels.labelsFor(RuleSubject, Iterable<String> ids) → Future<Map<String, String>>`: dives as "#412 Salt Pier, 14 Mar 2026" via the preference-aware date formatter; sites as "name, country".
- Page:
  - Two sections, Dive rules and Site rules, each a `ReorderableListView` block with drag handles, modelled on `saved_queries_page.dart`.
  - Each row shows the name, `QueryPrinter` text of the condition, a one-line action summary, the trigger labels and a `Switch`, plus a menu with Run on all, Duplicate and Delete (with a confirm).
  - A row with a problem shows its localised problem text.
  - App bar actions: History, Run all (a menu: dives / sites), New rule.
  - Empty state: one line explaining rules plus a New rule button.

- [ ] **Step 1: Write failing widget tests.**
  - `empty state shows New rule`.
  - `lists dive and site rules in their sections in sort order`.
  - `toggling the switch persists enabled`.
  - `a rule with a problem shows the problem text`.
  - `a rule whose action names a deleted tag shows a broken-action warning on its row`.
  - `Settings > Manage shows Rules and opens the page`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Add English ARB keys, prefixed `rules_`, and run `flutter gen-l10n`.
- [ ] **Step 4:** Run, plus `flutter test test/architecture/`. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): Rules page under Settings > Manage`.

### Task 12: Rule editor

**Files:**
- Create: `presentation/pages/rule_edit_page.dart`, `presentation/widgets/rule_action_card.dart`, `presentation/widgets/rule_action_picker_sheet.dart`, `presentation/widgets/rule_value_input.dart`
- Test: `test/features/rules/presentation/rule_edit_page_test.dart`, `rule_value_input_test.dart`

**Interfaces:**
- Consumes: `EntityQueryEditor(root:, value:, onChanged:)`; `RuleTargetScope.countMatches`; the existing pickers for tags, dive types, equipment, buddies (with role), courses, site types, dive centres and trips; `UnitFormatter` and the active diver's unit settings; `FormRow`, `NumberField`.
- Produces: `RuleEditPage({String? ruleId})`. A new rule chooses its subject on a segmented control; an existing rule shows the subject read-only.
- Editor:
  - Fields: name (required); triggers as two checkboxes worded per subject, with the note "you can always run it yourself"; the condition, with a live "Matches N of your dives/sites" line (debounced 300 ms; the empty condition warns "Matches every dive").
  - The Then list:
    - Action cards with edit and remove, plus "+ Add action". The picker is a searchable list of the subject's catalogue: Set <field> for each field, Add/Remove <collection>, Append to notes/description.
    - Save is disabled until there is a name and at least one valid action.
    - A broken action card (a missing reference) shows a warning.
  - `RuleValueInput` picks its control from `RuleValueKind`: text field, `NumberField` in display units converted to canonical on change, enum dropdown with localised names, switch, rating stars, or an entity picker.

- [ ] **Step 1: Write failing tests.**
  - `new dive rule: name, condition depth > 60ft, add dive type Deep, save → repository has the rule with the condition JSON and one action`.
  - `imperial diver: set swell height 3 ft stores 0.9144 and the card shows 3 ft`.
  - `Save disabled with no actions`.
  - `editing an existing rule keeps its id and subject`.
  - `picker search filters actions`.
  - `a rule saved by a newer version opens read-only with the newer-version note and no Save`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement, with English ARB keys and `gen-l10n`.
- [ ] **Step 4:** Run, plus `test/architecture/`. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): rule editor with an action picker`.

### Task 13: Change list, preview and the on-demand flow

**Files:**
- Create: `presentation/widgets/rule_change_list.dart`, `presentation/widgets/rule_preview_sheet.dart`, `presentation/run_rules_flow.dart`
- Modify: `rules_page.dart` (wire Run all and Run on all)
- Test: `test/features/rules/presentation/rule_change_list_test.dart`, `run_rules_flow_test.dart`

**Interfaces:**
- Produces:
  - `RuleChangeList({required List<RuleChange> changes, required Map<String, String> labels, RuleChangeGrouping grouping})` with `enum RuleChangeGrouping { target, rule }`.
    - Each line reads "Rule: Field  before → after".
    - Field names are localised; values are formatted in the diver's units; entity ids are shown as names.
    - For memberships, the line names what was added and removed.
    - The list is built lazily, because a run can be large.
  - `Future<void> runRulesOnDemand(BuildContext, WidgetRef, {required RuleSubject subject, Set<String>? targetIds, List<String>? onlyRuleIds})`:
    1. `preview`.
    2. If nothing changes, show "No changes: N dives already match your rules" and stop.
    3. Otherwise show the sheet: title "Apply N rules to M dives?", subtitle "X dives will change", a grouping toggle, the list, and Cancel / "Apply to X dives".
    4. On Apply, call `run` (recomputed, not replayed) and show a snackbar "Rules changed X dives" with Undo.

- [ ] **Step 1: Write failing tests.**
  - `preview sheet shows the per-dive changes and the count`.
  - `Cancel changes nothing`.
  - `Apply writes and the snackbar Undo reverts`.
  - `data changed after preview: Apply reports the real count`. Make an extra matching dive between preview and Apply; the snackbar names the new total.
  - `grouping by rule regroups lines`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement, with English ARB keys and `gen-l10n`.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): preview and run rules on demand`.

### Task 14: History and run detail

**Files:**
- Create: `presentation/pages/rule_history_page.dart`, `presentation/pages/rule_run_page.dart`
- Test: `test/features/rules/presentation/rule_history_page_test.dart`

**Interfaces:**
- History page:
  - Newest first. Each row shows the date and time (preference-aware), the trigger wording ("After import (Perdix 2)", "Logged by hand", "Run by hand on all dives", "Run on a selection"), "N dives/sites changed by <rule names>", the device, and either an "Undone <date>" state or an Undo action.
  - Menu: delete entry; app bar: Clear history (with a confirm).
- Run page:
  - Shows `RuleChangeList` for the run, plus an Undo button.
  - The undo result messages are:
    - "Undone."
    - "Undone. N were edited after this run; those changes were left alone."
    - "Nothing to undo on this device yet; try again after syncing."
    - "Already undone."

- [ ] **Step 1: Write failing tests.**
  - `lists runs newest first with trigger wording`.
  - `Undo marks the row undone and shows the skipped count`.
  - `nothingYet keeps Undo available`.
  - `Clear history removes all runs after confirm`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement, with English ARB keys and `gen-l10n`.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): run history with undo`.

### Task 15: After-import pass and the import summary box

**Files:**
- Modify:
  - `lib/features/dive_import/data/services/uddf_entity_importer.dart`: collect created site ids at the `createSite` call (~:2112) into `UddfEntityImportResult.siteIds`
  - `lib/features/import_wizard/data/adapters/universal_adapter.dart`: pass `siteIds` into `UnifiedImportResult.importedSiteIds`, and per diver into `DiverImportOutcome.siteIds` when it is multi-diver
  - `lib/features/import_wizard/domain/models/unified_import_result.dart`: `importedSiteIds` (default const `[]`)
  - `lib/features/import_wizard/domain/models/diver_import_outcome.dart`: `siteIds`
  - `lib/features/import_wizard/presentation/providers/import_wizard_providers.dart`: `_applyRules` after `_applyImportTags`; the state gains `List<RuleRunResult> ruleRuns` and `String? rulesWarning`
  - `lib/features/import_wizard/presentation/widgets/import_summary_step.dart`: render `ImportRulesBox` when `ruleRuns` has changes
- Create: `presentation/widgets/import_rules_box.dart`
- Test: `test/features/import_wizard/presentation/providers/import_wizard_rules_test.dart`, `test/features/rules/presentation/import_rules_box_test.dart`, and a case in the UDDF importer test for `siteIds`

**Interfaces:**
- `_applyRules(UnifiedImportResult result)`:
  - Skipped when `token.isCancelled`.
  - For each diver: `diverOutcomes` when non-empty, else the active diver with `importedDiveIds` / `importedSiteIds`. Run `RuleEngine.run(RuleRunRequest(diverId, trigger: imported, sourceLabel: <the adapter's display name>, targets: {dives: ids, sites: siteIds}))`.
  - Errors are caught; `rulesWarning` is then "Dives imported; rules could not run: <message>". The import result is kept.
- `ImportRulesBox({required List<RuleRunResult> runs})`:
  - "Rules changed N of these dives", with per-rule counts summed across runs.
  - "See changes" pushes a page showing `RuleChangeList` over all runs.
  - "Undo rule changes" undoes every run and then shows the undo message; the imported dives stay.

- [ ] **Step 1: Write failing tests.**
  - The wizard, with a fake adapter returning two dive ids and one site id:
    - `an afterImport rule tags the deep dive and state.ruleRuns has the change`;
    - `no rules: ruleRuns empty, no box`;
    - `cancelled import runs no rules`;
    - `rules failure keeps the import and sets rulesWarning`;
    - `multi-diver import runs each diver's rules on their dives`.
  - The box: `Undo rule changes reverts and keeps the dives`.
  - The UDDF importer: `siteIds lists created sites only, not matched existing ones`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement, with English ARB keys and `gen-l10n`.
- [ ] **Step 4:** Run, plus `flutter test test/features/import_wizard/ test/features/dive_import/`. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): run rules after an import and report them on the summary`.

### Task 16: After creating by hand

**Files:**
- Modify:
  - `lib/features/dive_log/presentation/pages/dive_edit_page.dart`: in `_saveDive`'s new-dive branch, after the child saves (~:6545), one call
  - `lib/features/planner/presentation/pages/plan_canvas_page.dart` (~:765, after "log plan" adds the dive)
  - the callers of `convertPlanToActualDive` in the edit page (~:6359) and `dive_detail_page.dart` (~:1739); the planned-fill service is an import and stays out
  - `lib/features/dive_sites/presentation/pages/site_edit_page.dart`: create branch, after expected species (~:2128)
  - `lib/features/dive_sites/presentation/providers/site_providers.dart`: `importSite` (~:921/934)
  - `site_map_page.dart` (~:598) and `site_map_content.dart` (~:599): built-in site adds
  - `lib/features/dive_sites/data/services/site_matching_service.dart`: `createAndLink`/`_applyOne` new sites; return the created ids so the review notifier can call the flow
- Test: `test/features/rules/presentation/run_rules_after_create_test.dart`, plus one case each in the dive edit and site edit page tests

**Interfaces:**
- Produces: `Future<void> runRulesAfterCreate(BuildContext, WidgetRef, {required RuleSubject subject, required List<String> ids})`.
  - Runs `RuleEngine.run` with `trigger: createdByHand` for the active diver.
  - On changes, shows a snackbar "Rules changed this dive: Deep, Boat" with a Details action. Details pushes the run page from Task 14.
  - Silent when nothing changed.
  - Failures are logged and shown as a snackbar; they never block the save.

- [ ] **Step 1: Write failing tests.**
  - `new dive saved by hand gets the afterManualCreate rule's type and a snackbar`.
  - `editing an existing dive runs no rules`.
  - `afterImport-only rule does not run on a hand-logged dive`.
  - `new site created by hand gets the site rule's tag`.
  - `logging a plan runs the rules once`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement, with English ARB keys and `gen-l10n`.
- [ ] **Step 4:** Run, plus `flutter test test/features/dive_log/presentation/pages/ test/features/dive_sites/`. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): run rules when a dive or site is created by hand`.

### Task 17: Apply rules to a selection

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_bulkActions`, ~:1633), `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (`_bulkActions`, ~:1273)
- Test: one case each in the existing dive list and site list widget tests

**Interfaces:**
- Consumes: `runRulesOnDemand(subject:, targetIds: selected)`.
- Produces: `BulkAction(id: 'apply_rules', icon: Icons.rule, label: l10n.rules_action_applyRules, ...)`.
  - Placed after bulk edit in the dive list and after `addToLibrary` in the site list.
  - Returns `completed` after Apply and `cancelled` on Cancel.
  - The preview says how many selected items were outside the editable scope ("3 selected sites are not yours to change and were left out").

- [ ] **Step 1: Write failing tests.**
  - `dive selection: Apply rules opens the preview for the selected dives only`.
  - `site selection with a library site: preview says one was left out`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement, with English ARB keys and `gen-l10n`.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat(rules): apply rules to selected dives or sites`.

### Task 18: Translations and final verification

**Files:**
- Modify: the 10 non-en ARB files in `lib/l10n/arb/`, the generated `app_localizations_*.dart`

- [ ] **Step 1:** Translate every new key into `ar de es fr he hu it nl pt zh`. Insert each key next to its `rules_` neighbours, because ARBs are feature-grouped. Every `=1{}` plural branch must interpolate `{count}`, not a literal digit.
- [ ] **Step 2:** Run `flutter gen-l10n` (last), then `grep -A1 "get rules_page_title" lib/l10n/arb/app_localizations_de.dart`. Expected: a German string. Check `git diff --numstat lib/l10n/arb/` shows even counts across locales.
- [ ] **Step 3:** Run `dart format .`, `flutter analyze`, `flutter test test/architecture/ test/shared/` and `flutter test test/features/rules/ test/core/database/ test/core/services/sync/ test/features/import_wizard/ test/features/dive_sites/ test/features/dive_log/`. Expected: clean, PASS. Then run the full suite in the background with output logged to the scratchpad.
- [ ] **Step 4:** Commit `i18n(rules): translate logbook rules strings`.
