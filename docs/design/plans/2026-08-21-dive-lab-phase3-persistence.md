# Counterfactual Dive Lab Phase 3 (Persistence, Sync, Saved Sheet, Teaser Card) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Saved scenarios: a synced `dive_scenarios` table and repository, Save / Saved actions on the lab page (open, rename, duplicate, delete), and a "What if" teaser section on dive detail listing the dive's saved scenarios with a one-line summary and a New-scenario CTA.

**Architecture:** Drift table `DiveScenarios` (schema v161, FK to dives with cascade, `hlc` column) registered on the 18 sync sites the `dive_plans` tables use, passing the structural sync tests. `DiveScenarioRepository` mirrors `DivePlanRepository` (sync-log pending markers after the transaction, `logDeletion` tombstones, `watchScenarioChanges`). Providers: repository, per-dive list, per-scenario outcome for summaries. UI: AppBar Save/Saved on `DiveLabPage`, a `LabSavedScenariosSheet` mirroring `SavedPlansSheet`, and `DiveDetailSectionId.diveLab` + `DiveLabSection`.

**Tech Stack:** Drift, the existing sync serializer/service/repository, Riverpod (legacy StateNotifier), Material 3, l10n (11 locales), flutter_test with the in-memory DB helpers.

**Spec:** `docs/superpowers/specs/2026-08-21-counterfactual-dive-lab-design.md` ("Persistence, sync and sharing", "Teaser card", "Saved scenarios"). Earlier plans: phase1-engine, phase2-lab-page.

## Global Constraints

- Worktree `.claude/worktrees/counterfactual-dive-lab`; absolute paths; `pwd` before `flutter test`.
- Schema version: claim **v161** (main is at v160 as of 2026-08-21; re-grep `currentSchemaVersion` on `origin/main` at merge time and renumber if taken; say so in the ladder comment). Do NOT raise `minimumCompatibleSchemaVersion` (a new table is additive).
- No em-dashes; no emojis; `dart format` + `flutter analyze` clean; files under 800 lines.
- l10n keys `diveLab_*` + `diveDetailSection_diveLab_*` in all 11 ARBs; `flutter gen-l10n`; commit generated files.
- Commits local only, no `Co-Authored-By`.

## File structure

```
lib/core/database/database.dart                      (modify: DiveScenarios table, v161 migration, beforeOpen backstop, ladder)
lib/core/database/performance_indexes.dart           (modify: idx_dive_scenarios_dive_id)
lib/core/services/sync/sync_data_serializer.dart     (modify: 14 sites)
lib/core/services/sync/sync_service.dart             (modify: mergeOrder, entityHasUpdatedAt, parentRefs)
lib/core/data/repositories/sync_repository.dart      (modify: hlcTargets)
test/core/services/sync/sync_parent_refs_completeness_test.dart (modify: syncedTables map)
test/core/database/migration_v161_dive_scenarios_test.dart
test/core/services/sync/dive_scenario_sync_round_trip_test.dart

lib/features/dive_lab/data/repositories/dive_scenario_repository.dart
lib/features/dive_lab/presentation/providers/dive_scenario_providers.dart   (repository, list, saved outcome + summary)
lib/features/dive_lab/presentation/widgets/lab_saved_scenarios_sheet.dart
lib/features/dive_lab/presentation/widgets/dive_lab_section.dart            (teaser card)
lib/features/dive_lab/presentation/pages/dive_lab_page.dart                  (modify: Save/Saved actions, open a saved scenario)
lib/features/dive_lab/presentation/providers/lab_draft_provider.dart         (modify: scenarioId/name on the draft, loadScenario)
lib/core/constants/dive_detail_sections.dart                                  (modify: diveLab section)
lib/features/dive_log/presentation/pages/dive_detail_page.dart               (modify: section builder arm)
lib/l10n/arb/*.arb + generated

test/features/dive_lab/data/dive_scenario_repository_test.dart
test/features/dive_lab/presentation/providers/dive_scenario_providers_test.dart
test/features/dive_lab/presentation/widgets/lab_saved_scenarios_sheet_test.dart
test/features/dive_lab/presentation/widgets/dive_lab_section_test.dart
test/features/dive_lab/presentation/pages/dive_lab_page_save_test.dart
```

---

### Task 1: `DiveScenarios` table, v161 migration, performance index

**Files:** `lib/core/database/database.dart`, `lib/core/database/performance_indexes.dart`, test `test/core/database/migration_v161_dive_scenarios_test.dart`.

**Interfaces:**
```dart
class DiveScenarios extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diveId => text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get branchSeconds => integer()();
  TextColumn get mode => text().withDefault(const Constant('replay'))();
  /// Versioned JSON envelope from scenario_intervention_codec (formatVersion + interventions).
  TextColumn get interventionsJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}
```
- Register `DiveScenarios,` in `@DriftDatabase(tables: [...])`; `currentSchemaVersion = 161`; append `161,` with a `// v161 (Dive Lab): dive_scenarios, saved what-if scenarios on a logged dive.` comment; `Future<void> _assertDiveScenariosSchema()` = `createMigrator().createTable(diveScenarios)` + `CREATE INDEX IF NOT EXISTS idx_dive_scenarios_dive_id ON dive_scenarios(dive_id)`; in `onUpgrade`: `if (from < 161) { await _assertDiveScenariosSchema(); } if (from < 161) await reportProgress();` immediately before `beforeOpen`; in `beforeOpen` after the v160 backstop: `// v161 backstop ...` + `await _assertDiveScenariosSchema();`.
- `performance_indexes.dart`: add `(name: 'idx_dive_scenarios_dive_id', ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_scenarios_dive_id ON dive_scenarios(dive_id)')`.

- [ ] **Test** (model on `migration_v100_dive_plans_test.dart`): v161 creates the table with `id, dive_id, name, notes, branch_seconds, mode, interventions_json, created_at, updated_at, hlc` from `user_version = 160` with a minimal `dives` parent; backstop heal at user_version 161 without the table; ladder membership (`currentSchemaVersion >= 161`, `migrationVersions contains 161`); fresh DB exposes `db.diveScenarios`.
- [ ] Run `dart run build_runner build --delete-conflicting-outputs` (Drift codegen for the new table), then the test, `test/core/database/performance_indexes_test.dart`, and `test/core/database/` migration tests.
- [ ] Commit `feat(db): dive_scenarios table at v161`

---

### Task 2: Sync registration (18 sites) + structural tests + round trip

**Files:** `sync_data_serializer.dart` (SyncData field `diveScenarios` after `divePlanEquipment` in the field list, ctor default, `toJson`, `fromJson`, `_baseTables` entry `(key: 'diveScenarios', table: _db.diveScenarios, blob: false, full: null)` right after the `divePlanEquipment` entry, `exportData` `diveScenarios: await _safeExport('diveScenarios', () => _exportDiveScenarios(hlcSince))`, `fetchRecord`, `fetchRecords`, `upsertRecord`, `upsertRecords`, `recordIdsFor` (`plain(_db.diveScenarios, _db.diveScenarios.id)`), `_syncTableFor`, `deleteRecord`, and `_exportDiveScenarios(String? hlcSince)` exporter filtering `hlc > hlcSince`); `sync_service.dart` (`mergeOrder`: `(type: 'diveScenarios', records: data.diveScenarios, hasUpdatedAt: true)` placed after `divePlanEquipment`, i.e. after `dives`; `entityHasUpdatedAt['diveScenarios'] = true`; `parentRefs['diveScenarios'] = [(field: 'diveId', parent: 'dives', nullable: false)]`); `sync_repository.dart` (`'diveScenarios': (table: 'dive_scenarios', pk: 'id')`); `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`'dive_scenarios': 'diveScenarios'` in `syncedTables`).
- [ ] **Test** `test/core/services/sync/dive_scenario_sync_round_trip_test.dart` modeled on `dive_plan_sync_round_trip_test.dart`: insert a dive + scenario, `exportData` contains it, a second DB `upsertRecords` then `recordIdsFor`/`deleteRecord` round trip; FK ON.
- [ ] Run `flutter test test/core/services/sync` (structural tests) + the round trip.
- [ ] Commit `feat(sync): register dive_scenarios`

---

### Task 3: `DiveScenarioRepository` + providers

**Files:** `lib/features/dive_lab/data/repositories/dive_scenario_repository.dart`, `lib/features/dive_lab/presentation/providers/dive_scenario_providers.dart`, tests.

**Interfaces:**
```dart
class DiveScenarioRepository {
  Stream<void> watchScenarioChanges();                       // tableUpdates on diveScenarios
  Future<DiveScenario> saveScenario(DiveScenario scenario);  // insertOnConflictUpdate; keeps createdAt of an existing row; updatedAt = now; markRecordPending after the write; SyncEventBus.notifyLocalChange; returns the stored scenario
  Future<DiveScenario?> getScenario(String id);
  Future<List<DiveScenario>> getScenariosForDive(String diveId);   // newest updatedAt first
  Future<void> deleteScenario(String id);                    // delete + logDeletion('diveScenarios', id) + notify
  Future<DiveScenario?> duplicateScenario(String id);        // fresh uuid, name + ' (2)' style suffix via l10n-free rule: name + ' 2'? -> use `'$name (copy)'` is English; instead keep the same name and let the UI rename: duplicate copies the name unchanged
}
final diveScenarioRepositoryProvider = Provider<DiveScenarioRepository>((_) => DiveScenarioRepository());
final diveScenariosForDiveProvider = FutureProvider.family<List<DiveScenario>, String>((ref, diveId) { repo; ref.invalidateSelfWhen(repo.watchScenarioChanges()); return repo.getScenariosForDive(diveId); });
typedef SavedScenarioKey = ({String diveId, String scenarioId});
/// Runs the engine for a saved scenario (summary lines on the teaser card); null when ineligible.
final savedScenarioOutcomeProvider = FutureProvider.autoDispose.family<ScenarioOutcome?, SavedScenarioKey>(...);   // uses labRequestInputsProvider + scenarioEngineRunnerProvider
```
Row mapping: `mode` by `ScenarioMode.values.byName` (fallback replay), interventions via `decodeInterventions` (a `FormatException` maps to an empty list and is logged), timestamps ms since epoch.
- [ ] **Tests** (real DB): save/get/list order/delete + tombstone row in `deletion_log`/`getPendingRecords` as the plan repository test does; duplicate yields a new id; deleting the dive cascades (FK ON) so `getScenariosForDive` is empty; providers test: list provider reflects a save (invalidateSelfWhen) and the outcome provider returns a branch at the saved seconds with a synchronous runner.
- [ ] Commit `feat(dive-lab): scenario repository and providers`

---

### Task 4: l10n keys (11 locales)

Keys: `diveLab_action_save` (Save), `diveLab_action_saved` (Saved scenarios), `diveLab_save_title` (Name this scenario), `diveLab_saved_snackbar` (Scenario saved), `diveLab_saved_title` (Saved scenarios), `diveLab_saved_empty` (No saved scenarios for this dive yet.), `diveLab_saved_open` (Open), `diveLab_saved_rename` (Rename), `diveLab_saved_duplicate` (Duplicate), `diveLab_saved_delete` (Delete), `diveLab_saved_deleteConfirm` (Delete "{name}"?), `diveLab_summary_replay` (Replay at {time}), `diveLab_summary_replan` (Re-plan at {time}), `diveLab_section_new` (New scenario), `diveLab_section_hint` (Branch this dive at any moment and compare what would have happened.), `diveDetailSection_diveLab_name` (What if), `diveDetailSection_diveLab_description` (Saved what-if scenarios from the Dive Lab). Translate all; gen-l10n; commit `feat(dive-lab): strings for saved scenarios`.

---

### Task 5: Draft loading + Save/Saved on the lab page + saved sheet

**Files:** `lab_draft_provider.dart` (add `scenarioId`, `name` to `LabDraft`; `loadScenario(DiveScenario)` sets branch/mode/interventions/id/name; `toScenario(diveId, {String? id, String? name})` uses them), `dive_lab_page.dart` (`DiveLabPage({diveId, scenarioId})`, `showDiveLab(context, diveId, {scenarioId})`; on first build with `scenarioId` load it through the repository into the draft (once); AppBar actions: Save (name dialog via `showPlanNameDialog(context, initialName: draft.name ?? defaultName, title: l10n.diveLab_save_title)`, then `saveScenario`, snackbar, draft keeps the id), Saved (opens `showLabSavedScenariosSheet(context, diveId)`)), `lab_saved_scenarios_sheet.dart` (list from `diveScenariosForDiveProvider`; tile: name + `summary` subtitle (mode at time + chip labels); tap = load into the draft and pop; trailing delete + menu rename/duplicate).
Default name: `'${mode label at time}'` + for each intervention ` · chip label`.
- [ ] **Tests**: sheet test (seeded repository via real DB: lists scenarios, tapping loads the draft; delete removes; rename dialog renames); page save test (override repository with the real one + DB; tap Save, enter a name, confirm; repository has one scenario; second Save updates in place).
- [ ] Commit `feat(dive-lab): save, load and manage scenarios from the lab page`

---

### Task 6: Teaser section on dive detail

**Files:** `dive_detail_sections.dart` (`diveLab` enum value after `buoyancy`? Place after `safetyReview` so it sits near the profile: insert after `sacSegments`; five switch arms; `defaultSections` entry; NOT hidden in gauge mode by the registry (the builder returns [] for gauge)), `dive_detail_page.dart` (`_sectionBuilders` arm: `if (dive.isGauge || dive.profile.length < 2) return []; return [const SizedBox(height: 24), DiveLabSection(diveId: dive.id)];`), `dive_lab_section.dart` (Card: title `diveDetailSection_diveLab_name`, hint, list of saved scenarios with summary line (from `savedScenarioOutcomeProvider` verdict, "Computing…" while loading, plain name when unavailable), tap -> `showDiveLab(context, diveId, scenarioId:)`; `FilledButton.tonalIcon(New scenario)` -> `showDiveLab`).
- [ ] **Tests**: `dive_lab_section_test.dart` (renders CTA with no scenarios; renders seeded scenario names); the sections settings page/enum tests in `test/` that enumerate sections still pass (`flutter test test/features/settings test/core/constants`).
- [ ] Commit `feat(dive-lab): What if section on dive detail`

---

### Task 7: Verification

- [ ] `dart format lib test`; `flutter analyze`; `flutter test test/core/database test/core/services/sync test/features/dive_lab test/features/dive_log/presentation test/features/settings test/features/planner`
- [ ] Commit `chore(dive-lab): phase 3 verification`

## Self-review notes

- Spec coverage: table + repository + 18-site sync + structural tests (Tasks 1-3), Saved sheet with open/duplicate/rename/delete (Task 5; multi-select for PDF arrives with Phase 5), teaser card with lazily computed summary and New-scenario CTA (Task 6), dive deletion cascades (FK cascade at the DB level, the same mechanism dive tanks/profiles use; the `dives` tombstone covers the children on the remote). Backup/restore: rides the DB.
- Deviation from the spec text: the spec listed "tombstone columns"; this codebase has no per-row tombstones (deletion_log via `logDeletion`), so the table carries `hlc` only.
