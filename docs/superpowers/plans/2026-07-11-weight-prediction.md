# Weight Prediction (Weight Planner) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Predict how much lead a diver should carry (and where to place it) for a planned rig, personalized from their logged dive history, surfaced as an upgraded Weight Planner tool and a Gear & Weights section in the Dive Planner.

**Architecture:** A pure-Dart hybrid engine in `lib/core/buoyancy/` computes deterministic physics terms (tank near-empty buoyancy, water-density shift) and learns personal + per-gear-item terms via ridge regression toward priors from the diver's feedback-corrected dive history. Schema migration v104 adds weighting feedback on dives, buoyancy metadata on equipment, dated diver weight entries, a plan-equipment junction, and planned-weight snapshot columns on plans. A new `lib/features/weight_planner/` feature assembles history observations and provides shared UI.

**Tech Stack:** Flutter 3.x, Drift (SQLite), Riverpod, go_router, Equatable. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-11-weight-prediction-design.md` (committed in this worktree).

## Global Constraints

- Work in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/weight-prediction`, branch `worktree-weight-prediction`. Run ALL commands from the worktree root. Never `cd` to the main checkout.
- Schema migration number is **v104** — claimed by this feature. (A parallel 3D-flythrough effort was explicitly told NOT to use v104.)
- All weights stored in **kg**; display via `UnitFormatter` (`lib/core/utils/unit_formatter.dart`): `formatWeight(kg)`, `convertWeight(kg)`, `weightToKg(display)`, `weightSymbol`. Construct as `UnitFormatter(ref.watch(settingsProvider))` — there is no unitFormatterProvider.
- Every new user-facing string goes into `lib/l10n/arb/app_en.arb` AND all 10 other locale files (`app_es`, `app_fr`, `app_de`, `app_it`, `app_nl`, `app_pt`, `app_ar`, `app_he`, `app_hu`, `app_zh`) with genuine translations (repo practice — never English placeholders). Regenerate with `flutter gen-l10n`. Key naming: `feature_component_leafCamelCase`, alphabetical order within the arb.
- After any change to `lib/core/database/database.dart` or Drift tables: `dart run build_runner build --delete-conflicting-outputs`.
- No emojis anywhere. `dart format .` (whole repo) must produce no changes before each commit. `flutter analyze` must be clean (run whole-project, never pipe through `tail`/`head`).
- Commit messages: conventional style (`feat(scope): ...`), no Co-Authored-By line, no session URL.
- Run single test files, not the whole suite, during iteration: `flutter test test/path/file_test.dart`. The pre-push hook runs format/analyze/full tests; pushing from this worktree requires `git push --no-verify` (the hook runs against the main tree, a known repo trap) — but only push when Eric asks.
- Sync conventions are load-bearing: `diver_weight_entries` is an HLC entity (upsert via `.toCompanion(false)`, registered in `_hlcTargets` and `_hlcTables`); `dive_plan_equipment` is a clockless composite-PK junction (plain companion upsert, NEVER `.toCompanion(false)`, needs `parentRefs`). Getting these backwards causes cross-device data loss.

## File Structure

New files:

| File | Responsibility |
| --- | --- |
| `lib/core/buoyancy/gear_feature.dart` | `GearFeature`: per-item prior buoyancy from metadata or type defaults (incl. wetsuit thickness parsing) |
| `lib/core/buoyancy/buoyancy_physics.dart` | Water-density and tank near-empty buoyancy terms + constants catalog |
| `lib/core/buoyancy/ridge_regression.dart` | Weighted ridge regression via normal equations |
| `lib/core/buoyancy/weight_prediction_engine.dart` | `WeightObservation`, `RigSpec`, fit + predict + confidence + breakdown |
| `lib/core/buoyancy/placement_predictor.dart` | Split predicted total across `WeightType`s from history |
| `lib/features/weight_planner/data/repositories/weight_history_repository.dart` | Batch SQL: dives + weights + equipment + tanks -> observations |
| `lib/features/weight_planner/presentation/providers/weight_planner_providers.dart` | Observations, calibration, plan-prediction providers |
| `lib/features/weight_planner/presentation/pages/weight_planner_page.dart` | The rewritten tool page |
| `lib/features/weight_planner/presentation/widgets/rig_composer.dart` | Shared gear/tank/water/body-weight input card |
| `lib/features/weight_planner/presentation/widgets/weight_prediction_card.dart` | Shared result card (total, placement, confidence, breakdown, delta) |
| `lib/features/divers/domain/entities/diver_weight_entry.dart` | Dated body-mass entity |
| `lib/features/divers/data/repositories/diver_weight_entry_repository.dart` | CRUD + HLC sync bookkeeping |
| `lib/features/divers/presentation/providers/diver_weight_entry_providers.dart` | Diver-scoped providers |
| `lib/features/settings/presentation/pages/body_weight_edit_page.dart` | Body weight history page (hub section) |
| `lib/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart` | Gear & Weights card in the plan editor |

Deleted: `lib/core/utils/weight_calculator.dart`, `lib/features/tools/presentation/pages/weight_calculator_page.dart` (Task 13; no test file exists for either — verified).

Heavily modified: `lib/core/database/database.dart`, `lib/core/database/performance_indexes.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/sync_service.dart`, `lib/core/data/repositories/sync_repository.dart`, equipment/dive/planner entities + repositories, `dive_edit_page.dart`, `equipment_edit_page.dart`, `plan_canvas_page.dart`, `app_router.dart`, arb files.

---

### Task 1: Schema v104 — tables, columns, migration, backstop, indexes

**Files:**
- Modify: `lib/core/database/database.dart` (table classes near line 737; `tables:` list at line 2000-2077; `currentSchemaVersion` line 2086; `migrationVersions` lines 2091-2193; `_hlcTables` lines 2202-2230; `onUpgrade` after line 5068; `beforeOpen` backstop after line 5140)
- Modify: `lib/core/database/performance_indexes.dart` (append to `kPerformanceIndexes`, lines 23-266)
- Test: `test/core/database/migration_v104_weight_prediction_test.dart`

**Interfaces:**
- Consumes: existing Drift tables `Dives`, `Equipment`, `DivePlans`, `Divers`.
- Produces: Drift tables `DiverWeightEntries` (data class `DiverWeightEntryRow`), `DivePlanEquipment`; generated columns `dives.weightingFeedback/.weightingFeedbackKg`, `equipment.buoyancyKg/.weightKg`, `divePlans.plannedWeightKg/.plannedWeightPlacement`. Later tasks depend on these generated names exactly.

- [x] **Step 1: Write the failing migration test**

Mirror `test/core/database/migration_v103_dive_roles_test.dart` (all four shapes). Create `test/core/database/migration_v104_weight_prediction_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

// Minimal v103-shape fixture: only the tables/columns the v104 migration and
// its beforeOpen backstop touch.
NativeDatabase _v103Db({int? userVersion}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = ${userVersion ?? 103}');
      rawDb.execute('''CREATE TABLE divers (id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL, created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL)''');
      rawDb.execute('''CREATE TABLE dives (id TEXT PRIMARY KEY NOT NULL,
          diver_id TEXT, dive_date_time INTEGER NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          diver_role TEXT, hlc TEXT)''');
      rawDb.execute('''CREATE TABLE equipment (id TEXT PRIMARY KEY NOT NULL,
          diver_id TEXT, name TEXT NOT NULL, type TEXT NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          hlc TEXT)''');
      rawDb.execute('''CREATE TABLE dive_plans (id TEXT PRIMARY KEY NOT NULL,
          diver_id TEXT, name TEXT NOT NULL, gf_low INTEGER NOT NULL,
          gf_high INTEGER NOT NULL, created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL, hlc TEXT)''');
      rawDb.execute("INSERT INTO dives (id, dive_date_time, created_at, "
          "updated_at) VALUES ('d1', 1000, 1000, 1000)");
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('fresh database has v104 tables and columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table'").get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['diver_weight_entries', 'dive_plan_equipment']));
    expect(await _columns(db, 'dives'),
        containsAll(['weighting_feedback', 'weighting_feedback_kg']));
    expect(await _columns(db, 'equipment'),
        containsAll(['buoyancy_kg', 'weight_kg']));
    expect(await _columns(db, 'dive_plans'),
        containsAll(['planned_weight_kg', 'planned_weight_placement']));
  });

  test('real onUpgrade from v103 creates tables/columns preserving rows',
      () async {
    final db = AppDatabase(_v103Db());
    addTearDown(db.close);
    expect(await _columns(db, 'dives'), contains('weighting_feedback'));
    expect(await _columns(db, 'equipment'), contains('buoyancy_kg'));
    expect(await _columns(db, 'dive_plans'), contains('planned_weight_kg'));
    final rows = await db.customSelect('SELECT id FROM dives').get();
    expect(rows.single.read<String>('id'), 'd1');
    final idx = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='idx_diver_weight_entries_diver_id'").get();
    expect(idx, isNotEmpty);
  });

  test('beforeOpen backstop heals a DB at currentSchemaVersion missing '
      'the v104 objects', () async {
    final db = AppDatabase(
        _v103Db(userVersion: AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    expect(await _columns(db, 'dives'), contains('weighting_feedback'));
    final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='diver_weight_entries'").get();
    expect(tables, isNotEmpty);
  });

  test('version ladder includes 104', () {
    expect(AppDatabase.currentSchemaVersion, 104);
    expect(AppDatabase.migrationVersions, contains(104));
  });
}
```

- [x] **Step 2: Run it to verify failure**

Run: `flutter test test/core/database/migration_v104_weight_prediction_test.dart`
Expected: FAIL (`currentSchemaVersion` is 103; tables missing).

- [x] **Step 3: Add table classes and columns in database.dart**

Insert after the `DiveWeights` table class (ends near line 737):

```dart
/// Dated body-mass measurements per diver (weight prediction, v104).
@DataClassName('DiverWeightEntryRow')
class DiverWeightEntries extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id)();
  IntColumn get measuredAt => integer()(); // Unix ms
  RealColumn get weightKg => real()();
  RealColumn get heightCm => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Junction: equipment attached to a saved dive plan (v104).
class DivePlanEquipment extends Table {
  TextColumn get planId =>
      text().references(DivePlans, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {planId, equipmentId};
}
```

In `Dives` (after `weightType`, line ~450):

```dart
  // Weighting feedback (v104): 'correct' | 'overweighted' | 'underweighted'.
  TextColumn get weightingFeedback => text().nullable()();
  // Magnitude in kg; direction implied by weightingFeedback.
  RealColumn get weightingFeedbackKg => real().nullable()();
```

In `Equipment` (after `size`, line ~685):

```dart
  // Buoyancy metadata (v104): net in-water buoyancy in kg (positive floats),
  // and dry weight in kg (feeds displacement scaling).
  RealColumn get buoyancyKg => real().nullable()();
  RealColumn get weightKg => real().nullable()();
```

In `DivePlans` (after `turnPressureFraction`):

```dart
  /// Accepted weight prediction snapshot (v104). Placement is a JSON object
  /// keyed by WeightType.name -> kg.
  RealColumn get plannedWeightKg => real().nullable()();
  TextColumn get plannedWeightPlacement => text().nullable()();
```

Register `DiverWeightEntries` and `DivePlanEquipment` in the `@DriftDatabase(tables: [...])` list (lines 2000-2077). Bump `currentSchemaVersion` to `104` (line 2086). Append `104,` to `migrationVersions` (line 2192). Add `'diver_weight_entries'` to `_hlcTables` (lines 2202-2230) — NOT `dive_plan_equipment` (no hlc column).

- [x] **Step 4: Add the onUpgrade block and beforeOpen backstop**

After the `if (from < 103) await reportProgress();` line (~5068):

```dart
        if (from < 104) {
          await m.createTable(diverWeightEntries);
          await m.createTable(divePlanEquipment);
          Future<void> addColumnIfMissing(
              String table, String column, String type) async {
            final cols =
                await customSelect("PRAGMA table_info('$table')").get();
            final has = cols.any((c) => c.read<String>('name') == column);
            if (cols.isNotEmpty && !has) {
              await customStatement(
                  'ALTER TABLE $table ADD COLUMN $column $type');
            }
          }

          await addColumnIfMissing('dives', 'weighting_feedback', 'TEXT');
          await addColumnIfMissing('dives', 'weighting_feedback_kg', 'REAL');
          await addColumnIfMissing('equipment', 'buoyancy_kg', 'REAL');
          await addColumnIfMissing('equipment', 'weight_kg', 'REAL');
          await addColumnIfMissing('dive_plans', 'planned_weight_kg', 'REAL');
          await addColumnIfMissing(
              'dive_plans', 'planned_weight_placement', 'TEXT');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_diver_weight_entries_diver_id '
              'ON diver_weight_entries(diver_id)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_dive_plan_equipment_plan_id '
              'ON dive_plan_equipment(plan_id)');
        }
        if (from < 104) await reportProgress();
```

In `beforeOpen`, after the v103 backstop block (ends ~line 5140), add the symmetric v104 backstop (same DDL, using `createMigrator().createTable(...)` and the same PRAGMA-guarded ALTERs — copy the helper closure locally since scope differs).

- [x] **Step 5: Add performance index entries**

Append to `kPerformanceIndexes` in `lib/core/database/performance_indexes.dart` (record typedef `({String name, String ddl})`):

```dart
  // -- diver_weight_entries (v104) --------------------------------------
  (
    name: 'idx_diver_weight_entries_diver_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_diver_weight_entries_diver_id '
        'ON diver_weight_entries(diver_id)',
  ),
  // -- dive_plan_equipment (v104) ----------------------------------------
  (
    name: 'idx_dive_plan_equipment_plan_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_plan_equipment_plan_id '
        'ON dive_plan_equipment(plan_id)',
  ),
```

- [x] **Step 6: Regenerate and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/core/database/migration_v104_weight_prediction_test.dart test/core/database/performance_indexes_test.dart`
Expected: PASS.

- [x] **Step 7: Commit**

```bash
git add lib/core/database/ test/core/database/migration_v104_weight_prediction_test.dart
git commit -m "feat(db): schema v104 for weight prediction (feedback, buoyancy, weight entries, plan equipment)"
```

---

### Task 2: Sync wiring for the two new tables

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncData field ~line 247, ctor ~298, toJson ~350, fromJson ~403, `_baseTables` 544-690, `_buildSyncData` ~1015, `fetchRecord` switch ~1369, `fetchRecords` ~1574, `upsertRecord` ~1868, `upsertRecords` ~2321, `recordIdsFor` ~2581, `_syncTableFor` ~2740, `deleteRecord` ~2972)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` ~line 929, `entityHasUpdatedAt` 1498-1548, `parentRefs` 1564-1652)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets` lines 29-63)
- Test: `test/core/services/sync/sync_weight_prediction_test.dart`

**Interfaces:**
- Consumes: Task 1 generated Drift classes (`diverWeightEntries`, `divePlanEquipment` tables; `DiverWeightEntryRow`).
- Produces: sync entity types `'diverWeightEntries'` (HLC) and `'divePlanEquipment'` (clockless junction, composite record id `'planId|equipmentId'`). Repositories in Tasks 3/6 use these exact entityType strings.

- [x] **Step 1: Run the structural sync tests to see them fail**

Run: `flutter test test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart`
Expected: FAIL — these tests enumerate `SyncData().toJson()` keys, `recordIdsFor` cases, and FK parent refs; the new tables from Task 1 make them fail until wired. (If they pass before any edit, they key off the serializer not the schema — proceed; they must still pass after Step 3.)

- [x] **Step 2: Write the failing round-trip test**

Mirror `test/core/services/sync/sync_dive_roles_test.dart`. Cover: export includes rows from both tables; `upsertRecord('diverWeightEntries', ...)` round-trips a full row and an explicit-null `height_cm` clears the local value (`.toCompanion(false)` semantics); `upsertRecord('divePlanEquipment', ...)` inserts a junction row given parents exist; `deleteRecord('divePlanEquipment', 'p1|e1')` removes it; `recordIdsFor` returns composite ids for the junction.

- [x] **Step 3: Wire the serializer, service, and repository**

For `diverWeightEntries`, copy the `diveRoles` template at every listed location; `_baseTables` entry:

```dart
      (key: 'diverWeightEntries', table: _db.diverWeightEntries, blob: false, full: null),
```

`upsertRecord` case (HLC entity — full-row overwrite):

```dart
      case 'diverWeightEntries':
        await _db.into(_db.diverWeightEntries).insertOnConflictUpdate(
              DiverWeightEntryRow.fromJson(data).toCompanion(false),
            );
```

For `divePlanEquipment`, copy the `diveEquipment` template (composite id via `_splitCompositeId`, line ~3055; export template `_exportDiveEquipment` referenced from `_baseTables` lines 550-555). Its upsert uses the plain data-class companion — do NOT add `.toCompanion(false)`.

`sync_service.dart`:
- `mergeOrder`: `(type: 'diverWeightEntries', records: data.diverWeightEntries, hasUpdatedAt: true)` placed after the divers entry; `(type: 'divePlanEquipment', records: data.divePlanEquipment, hasUpdatedAt: false)` placed after both `divePlans` and `equipment` entries.
- `entityHasUpdatedAt`: `'diverWeightEntries': true,` `'divePlanEquipment': false,`
- `parentRefs`:

```dart
      'divePlanEquipment': [
        (field: 'planId', parent: 'divePlans', nullable: false),
        (field: 'equipmentId', parent: 'equipment', nullable: false),
      ],
```

No `parentRefs` entry for `diverWeightEntries` (diverId is repointed by DiverMergeRepository — same convention as other diver-scoped tables, see comment at sync_service.dart:1560).

`sync_repository.dart` `_hlcTargets`:

```dart
    'diverWeightEntries': (table: 'diver_weight_entries', pk: 'id'),
```

- [x] **Step 4: Run all sync tests**

Run: `flutter test test/core/services/sync/`
Expected: PASS (structural + new round-trip + existing suites).

- [x] **Step 5: Commit**

```bash
git add lib/core/services/sync/ lib/core/data/repositories/sync_repository.dart test/core/services/sync/sync_weight_prediction_test.dart
git commit -m "feat(sync): wire diver_weight_entries and dive_plan_equipment into changeset sync"
```

---

### Task 3: DiverWeightEntry entity, repository, providers

**Files:**
- Create: `lib/features/divers/domain/entities/diver_weight_entry.dart`
- Create: `lib/features/divers/data/repositories/diver_weight_entry_repository.dart`
- Create: `lib/features/divers/presentation/providers/diver_weight_entry_providers.dart`
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (`deleteDiverWithReassignment`, per-diver delete block lines 437-467)
- Test: `test/features/divers/data/repositories/diver_weight_entry_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 table; sync entityType `'diverWeightEntries'` from Task 2; `SyncRepository.markRecordPending/logDeletion`; `validatedCurrentDiverIdProvider`.
- Produces:

```dart
class DiverWeightEntry extends Equatable {
  final String id; final String diverId; final DateTime measuredAt;
  final double weightKg; final double? heightCm;
  final DateTime createdAt; final DateTime updatedAt;
  DiverWeightEntry copyWith({...});
}
class DiverWeightEntryRepository {
  DiverWeightEntryRepository([AppDatabase? db]);           // DatabaseService fallback
  Future<List<DiverWeightEntry>> getEntriesForDiver(String diverId); // measuredAt desc
  Future<DiverWeightEntry?> latestEntry(String diverId);
  Future<DiverWeightEntry?> entryNearest(String diverId, DateTime at);
  Future<DiverWeightEntry> createEntry(DiverWeightEntry entry);
  Future<void> updateEntry(DiverWeightEntry entry);
  Future<void> deleteEntry(String id);
  Stream<void> watchChanges();
}
// Providers:
final diverWeightEntryRepositoryProvider = Provider<DiverWeightEntryRepository>(...);
final diverWeightEntriesProvider = FutureProvider<List<DiverWeightEntry>>(...);   // active diver, self-invalidating
final latestDiverWeightProvider = FutureProvider<DiverWeightEntry?>(...);
```

- [x] **Step 1: Write failing repository tests** — in-memory DB pattern from `test/features/dive_log/data/repositories/view_config_repository_test.dart:17-40` (`AppDatabase(NativeDatabase.memory())`, `DatabaseService.instance.setTestDatabase(db)`, insert a diver row in setUp). Test: create then read back ordered desc; `latestEntry` returns newest by `measuredAt`; `entryNearest` picks the closest-dated entry on both sides; delete removes and (via `SyncRepository`) writes a `deletion_log` tombstone row (assert `SELECT * FROM deletion_log WHERE record_id = ?` non-empty); created row has non-null `hlc` after `markRecordPending`.
- [x] **Step 2: Run to verify failure** — `flutter test test/features/divers/data/repositories/diver_weight_entry_repository_test.dart` — FAIL (files missing).
- [x] **Step 3: Implement entity + repository** — mirror `DiveRoleRepository` (`lib/features/dive_roles/data/repositories/dive_role_repository.dart`): every mutation writes the row with `updatedAt` then `await _syncRepository.markRecordPending(entityType: 'diverWeightEntries', recordId: id, localUpdatedAt: now)` then `SyncEventBus.notifyLocalChange()`; delete uses `logDeletion(entityType: 'diverWeightEntries', recordId: id)`. `entryNearest`: fetch all for diver, pick min `|measuredAt - at|` in Dart (entry counts are tiny). ID generation: `const Uuid().v4()` when `entry.id` is empty.
- [x] **Step 4: Implement providers** — mirror `equipment_providers.dart` scoping: `final diverId = await ref.watch(validatedCurrentDiverIdProvider.future); if (diverId == null) return [];` and self-invalidate via `ref.listen`-free pattern used there (subscribe to `repository.watchChanges()` with `ref.onDispose` cancel + `ref.invalidateSelf()`).
- [x] **Step 5: Wire diver deletion** — in `deleteDiverWithReassignment` add `await customStatement('DELETE FROM diver_weight_entries WHERE diver_id = ?', [id]);` alongside the equipment delete block (lines 437-467), matching its style.
- [x] **Step 6: Run tests, format, commit**

```bash
flutter test test/features/divers/
dart format .
git add lib/features/divers/ test/features/divers/
git commit -m "feat(divers): dated body weight entries with sync + providers"
```

---

### Task 4: Equipment buoyancy/weight fields through the stack

**Files:**
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart` (fields, ctor, `copyWith` 83-124, `props` 127-146)
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (create companion 174-203, update companion 234-258, `_mapRowToEquipment` 540, `searchEquipment` manual mapping 409-451)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (partial equipment mapper in the batch join, lines 215-241)
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (equipment headers/rows, lines 240-253)
- Test: extend `test/features/equipment/` repository test (or create `test/features/equipment/data/equipment_buoyancy_fields_test.dart`)

**Interfaces:**
- Produces: `EquipmentItem.buoyancyKg` (`double?`), `EquipmentItem.weightKg` (`double?`) — read by the engine feature layer (Task 12) and the gear edit form (Task 15).

- [x] **Step 1: Failing test** — round-trip an `EquipmentItem(buoyancyKg: -2.5, weightKg: 3.0)` through `createEquipment`/`getEquipmentById` and through `searchEquipment`; assert the dive batch join (create dive with linked equipment, `getDiveById`) carries the fields.
- [x] **Step 2: Run to verify failure.**
- [x] **Step 3: Implement** — add both fields everywhere listed. `copyWith` uses the entity's existing plain `value ?? this.value` pattern (clearing happens by rebuilding the entity in the edit form — matches current form behavior). New columns flow through sync automatically (whole-row serialization) — no serializer edits.
- [x] **Step 4: CSV export** — add `Buoyancy (kg)` and `Dry Weight (kg)` headers + row values in the equipment section of `csv_export_service.dart`.
- [x] **Step 5: Run equipment + dive_log repository tests, format, commit**

```bash
flutter test test/features/equipment/ test/features/dive_log/data/
git add lib/features/equipment/ lib/features/dive_log/ lib/core/services/export/csv/ test/
git commit -m "feat(equipment): buoyancy and dry weight metadata fields"
```

---

### Task 5: Weighting feedback on the Dive entity and repository

**Files:**
- Modify: `lib/core/constants/enums.dart` (after `WeightType`, line ~275)
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (fields near line 80, ctor, `copyWith` 553-555 region, `props` 734-736 region)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (create companion ~909, update companion ~1147, full-dive row mapper ~2668 and ~3022)
- Test: `test/features/dive_log/data/repositories/dive_weighting_feedback_test.dart`

**Interfaces:**
- Produces:

```dart
enum WeightingFeedback {
  correct('Felt right'),
  overweighted('Overweighted'),
  underweighted('Underweighted');
  final String displayName;
  const WeightingFeedback(this.displayName);
}
// Dive gains: final WeightingFeedback? weightingFeedback;
//             final double? weightingFeedbackKg;
```

Stored as `.name` strings; parsed with `WeightingFeedback.values.firstWhere((f) => f.name == raw, orElse: ...)` guarded by null check (follow the `WeightType` parse idiom in the same mapper).

- [x] **Step 1: Failing test** — create a dive with `weightingFeedback: WeightingFeedback.overweighted, weightingFeedbackKg: 2.0`, read via `getDiveById`, assert round-trip; update to `correct`/null magnitude, assert; `DiveSummary` list mapping remains unaffected.
- [x] **Step 2: Run to verify failure.**
- [x] **Step 3: Implement** enum + entity + companions + mappers. Note `Dive.copyWith` in this repo uses plain `??` — to allow clearing feedback the edit page rebuilds the `Dive` from form state (same approach the page already uses for other nullable fields), so no sentinel needed.
- [x] **Step 4: Run, format, commit** — `git commit -m "feat(dive-log): weighting feedback fields on dives"`

---

### Task 6: DivePlan equipment list + planned weight snapshot

**Files:**
- Modify: `lib/features/planner/domain/entities/dive_plan.dart` (add fields to `DivePlan`, ctor, `props`)
- Modify: `lib/features/planner/data/repositories/dive_plan_repository.dart` (`savePlan` :51, `_planCompanion` :329, `_mapPlan` :428, `watchPlanChanges` :40)
- Modify: `lib/features/dive_planner/domain/entities/plan_result.dart` (`DivePlanState` :465, `copyWith` :598)
- Modify: `lib/features/planner/domain/services/dive_plan_state_mapper.dart` (both directions)
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (`DivePlanNotifier` mutations)
- Test: `test/features/planner/data/dive_plan_equipment_persistence_test.dart`

**Interfaces:**
- Consumes: Task 1 junction table; sync entityType `'divePlanEquipment'` (Task 2).
- Produces (used by Tasks 12 and 17):

```dart
// DivePlan gains:
final List<String> equipmentIds;                 // default const []
final double? plannedWeightKg;
final Map<String, double>? plannedWeightPlacement; // WeightType.name -> kg

// DivePlanState gains the same three fields (+ copyWith params).
// DivePlanNotifier gains:
void setEquipmentIds(List<String> ids);          // copyWith + isDirty
void setPlannedWeight(double? totalKg, Map<String, double>? placement);
```

- [x] **Step 1: Failing persistence test** — in-memory DB; insert parent divers/equipment rows; `savePlan` a plan with `equipmentIds: ['e1', 'e2']` and `plannedWeightKg: 6.5, plannedWeightPlacement: {'integrated': 4.5, 'trimWeights': 2.0}`; `getPlan` returns them; re-save with `['e1']` and assert the removed junction row is gone AND `deletion_log` has a tombstone with `record_id = '<planId>|e2'`; assert `watchPlanChanges` fires on junction-only changes.
- [x] **Step 2: Run to verify failure.**
- [x] **Step 3: Implement persistence** — inside `savePlan`'s existing transaction, after the tanks block, mirror the diff pattern:

```dart
      final existingEqRows = await (_db.select(_db.divePlanEquipment)
            ..where((e) => e.planId.equals(plan.id)))
          .get();
      final existingEqIds = existingEqRows.map((r) => r.equipmentId).toSet();
      final keptEqIds = plan.equipmentIds.toSet();
      for (final id in keptEqIds.difference(existingEqIds)) {
        await _db.into(_db.divePlanEquipment).insert(
              DivePlanEquipmentCompanion.insert(
                  planId: plan.id, equipmentId: id),
              mode: InsertMode.insertOrIgnore,
            );
      }
      final removedEqIds = existingEqIds.difference(keptEqIds);
      for (final id in removedEqIds) {
        await (_db.delete(_db.divePlanEquipment)
              ..where((e) =>
                  e.planId.equals(plan.id) & e.equipmentId.equals(id)))
            .go();
      }
```

After the transaction, in the sync bookkeeping section (:129-160), add `markRecordPending(entityType: 'divePlanEquipment', recordId: '${plan.id}|$id', ...)` for added ids and `logDeletion(entityType: 'divePlanEquipment', recordId: '${plan.id}|$id')` for removed ids (composite-id convention — mirror how `bulkRemoveEquipment` logs `diveEquipment` deletions, `dive_repository_impl.dart:4453`).

`_planCompanion`: `plannedWeightKg: Value(plan.plannedWeightKg), plannedWeightPlacement: Value(plan.plannedWeightPlacement == null ? null : jsonEncode(plan.plannedWeightPlacement)),`. `_mapPlan`: decode with `(jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()))`; hydrate `equipmentIds` from a junction select. Add `divePlanEquipment` to the `watchPlanChanges` table set.

- [x] **Step 4: Thread through state + mapper + notifier** (fields default to `const []`/null in `newPlan`).
- [x] **Step 5: Run planner tests, format, commit** — `flutter test test/features/planner/ test/features/dive_planner/` then `git commit -m "feat(planner): plan equipment junction and planned weight snapshot"`

---

### Task 7: Weight history observations query

**Files:**
- Create: `lib/core/buoyancy/weight_observation.dart`
- Create: `lib/features/weight_planner/data/repositories/weight_history_repository.dart`
- Test: `test/features/weight_planner/data/weight_history_repository_test.dart`

**Interfaces:**
- Produces (consumed by the engine in Task 10 and providers in Task 12):

```dart
// lib/core/buoyancy/weight_observation.dart — pure Dart, imports only
// core/constants. This is the engine's training-row type.
class ObservedTank {
  final double? volumeL; final double? workingPressureBar;
  final TankMaterial? material; final String? presetName;
  const ObservedTank({this.volumeL, this.workingPressureBar, this.material, this.presetName});
}
class WeightObservation {
  final String diveId;
  final DateTime diveDateTime;
  final WaterType? waterType;
  final double carriedKg;                    // sum(dive_weights) else legacy weightAmount
  final Map<String, double> placement;       // WeightType.name -> kg (may be empty)
  final List<String> equipmentIds;
  final List<ObservedTank> tanks;
  final String? feedback;                    // WeightingFeedback.name
  final double? feedbackKg;
  const WeightObservation({...});
}

class WeightHistoryRepository {
  WeightHistoryRepository([AppDatabase? db]);
  /// All dives of [diverId] that recorded any weight, ordered oldest-first.
  Future<List<WeightObservation>> observationsForDiver(String diverId);
}
```

- [x] **Step 1: Failing test** — seed an in-memory DB with: a diver; dive A (salt, 2 `dive_weights` rows 4.0 integrated + 2.0 trimWeights, 2 equipment links, 1 tank row with material/volume, feedback overweighted 1.5); dive B (legacy `weight_amount` 8.0 only, no dive_weights); dive C (no weights at all). Assert: 2 observations (C excluded); A's `carriedKg == 6.0` with placement map populated; B's `carriedKg == 8.0` with empty placement; equipment ids and tank fields present; ordering oldest-first.
- [x] **Step 2: Run to verify failure.**
- [x] **Step 3: Implement** with four batch queries (no per-dive N+1): select candidate dives (`diverId` match AND (`weightAmount` not null OR id in dive_weights)), then `dive_weights`, `dive_equipment`, `dive_tanks` each with `.isIn(diveIds)`, assemble maps in Dart. Parse `waterType`/material with the `values.firstWhere(orElse)` idiom.
- [x] **Step 4: Run, format, commit** — `git commit -m "feat(weight-planner): batch weight history observations query"`

---

### Task 8: Gear features and buoyancy physics

**Files:**
- Create: `lib/core/buoyancy/gear_feature.dart`
- Create: `lib/core/buoyancy/buoyancy_physics.dart`
- Test: `test/core/buoyancy/gear_feature_test.dart`, `test/core/buoyancy/buoyancy_physics_test.dart`

**Interfaces:**
- Consumes: `EquipmentType`, `TankMaterial`, `WaterType` from `lib/core/constants/enums.dart`; `TankPresets.matchBySpecs` from `lib/core/constants/tank_presets.dart`. NO feature imports (pure core).
- Produces:

```dart
class GearFeature {
  final String id;            // equipment item id (feature key)
  final String label;         // display name
  final double priorKg;       // prior buoyancy-offset term (lead-equivalent)
  final double priorStrength; // ridge lambda (virtual observations)
  final double dryMassKg;     // for displacement scaling (metadata or default)
  final bool hasUserSpec;     // buoyancyKg metadata was present
  const GearFeature({...});

  /// Builds priors from metadata when present, else type defaults.
  /// Wetsuit thickness parsed from name/size via RegExp(r'(\d+(?:\.\d+)?)\s*mm').
  factory GearFeature.fromEquipment({
    required String id, required EquipmentType type, required String name,
    String? size, double? buoyancyKg, double? weightKg,
  });
}

class BuoyancyPhysics {
  static const double densitySaltKgL = 1.025;   // reference
  static const double densityBrackishKgL = 1.010;
  static const double densityFreshKgL = 1.000;
  static const double defaultBodyMassKg = 75.0;
  static const double defaultReserveBar = 50.0;
  static const double airDensityKgPerLBar = 0.001225;

  /// Lead-equivalent shift vs the salt-water baseline. Negative in fresh.
  static double waterTermKg({WaterType? waterType, required double totalMassKg});

  /// Near-empty tank buoyancy (empty catalog value minus reserve-gas mass).
  static double tankTermKg({String? presetName, double? volumeL,
      double? workingPressureBar, TankMaterial? material,
      double reserveBar = defaultReserveBar});

  /// Approximate tank dry mass for displacement scaling.
  static double tankDryMassKg({String? presetName, double? volumeL, TankMaterial? material});
}
```

Type priors in `GearFeature.fromEquipment` (weak priors, `priorStrength = 2.0`; metadata priors use the user's `buoyancyKg` with `priorStrength = 8.0`):
wetsuit with parsed thickness `t` mm -> `1.0 * t` (clamped 0..8), wetsuit unknown -> 4.0, drysuit -> 10.0, bcd -> -0.5, hood -> 0.3, gloves -> 0.2, boots -> 0.4, all other types -> 0.0. Types `EquipmentType.weights` and `EquipmentType.tank` are EXCLUDED from features entirely (return null from the feature-building path in Task 12 — the factory itself may throw `ArgumentError` for them to enforce this). Default `dryMassKg` when `weightKg` null: wetsuit 2.0, drysuit 3.0, bcd 3.5, else 0.5.

Tank catalog in `buoyancy_physics.dart` — `emptyBuoyancyKg` and `dryMassKg` keyed by `TankPresets` names (initial values; verify against manufacturer spec sheets before finalizing golden vectors and adjust if a sheet disagrees):

```dart
const Map<String, ({double emptyBuoyancyKg, double dryMassKg})> kTankCatalog = {
  'al40': (emptyBuoyancyKg: 0.9, dryMassKg: 6.8),
  'al63': (emptyBuoyancyKg: 1.2, dryMassKg: 12.2),
  'al80': (emptyBuoyancyKg: 1.7, dryMassKg: 14.2),
  'hp80': (emptyBuoyancyKg: -1.3, dryMassKg: 13.0),
  'hp100': (emptyBuoyancyKg: -1.0, dryMassKg: 15.0),
  'hp120': (emptyBuoyancyKg: -1.4, dryMassKg: 18.0),
  'lp85': (emptyBuoyancyKg: -0.5, dryMassKg: 14.5),
  'steel10': (emptyBuoyancyKg: -1.2, dryMassKg: 12.5),
  'steel12': (emptyBuoyancyKg: -1.4, dryMassKg: 14.5),
  'steel15': (emptyBuoyancyKg: -1.8, dryMassKg: 17.5),
  'al30Stage': (emptyBuoyancyKg: 0.5, dryMassKg: 5.5),
  'al40Stage': (emptyBuoyancyKg: 0.9, dryMassKg: 6.8),
};
```

Resolution order in `tankTermKg`: explicit `presetName` in catalog -> `TankPresets.matchBySpecs(volumeL, workingPressureBar)?.name` in catalog -> per-material fallback `emptyBuoyancyKg = volumeL * f` with f: aluminum +0.15, steel -0.12, carbonFiber +0.30 (volume null -> 11.0 default). Then subtract reserve gas mass: `volumeL * reserveBar * airDensityKgPerLBar`. `waterTermKg = totalMassKg * (density(waterType)/densitySaltKgL - 1.0)`; null waterType -> 0.

- [x] **Step 1: Compute expected vectors with python3** (repo rule: never from recall):

```bash
python3 - <<'EOF'
rho_salt, rho_fresh, rho_brack = 1.025, 1.000, 1.010
for m in (75, 90, 105):
    print('fresh', m, m*(rho_fresh/rho_salt-1))
    print('brack', m, m*(rho_brack/rho_salt-1))
# al80 near-empty at 50 bar reserve: 1.7 - 11.1*50*0.001225
print('al80 nearEmpty', 1.7 - 11.1*50*0.001225)
# steel12 near-empty: -1.4 - 12.0*50*0.001225
print('steel12 nearEmpty', -1.4 - 12.0*50*0.001225)
# material fallback 11L aluminum: 11*0.15 - 11*50*0.001225
print('fallbackAl 11L', 11*0.15 - 11*50*0.001225)
EOF
```

Record the printed values as `closeTo(value, 0.001)` expectations.

- [x] **Step 2: Write failing tests** — water term signs/magnitudes from Step 1; tank term for catalog hit (`presetName: 'al80'`), spec-match hit (volume 11.1, wp 207 -> matches al80), material fallback, null-volume fallback; gear priors: `7mm Farmer John` name parses to 7.0 prior, `buoyancyKg: -2.0` metadata wins with strength 8.0, drysuit default 10.0, `EquipmentType.weights` throws.
- [x] **Step 3: Run to verify failure, implement, run to green.**
- [x] **Step 4: Commit** — `git commit -m "feat(buoyancy): gear feature priors and physics terms"`

---

### Task 9: Ridge regression solver

**Files:**
- Create: `lib/core/buoyancy/ridge_regression.dart`
- Test: `test/core/buoyancy/ridge_regression_test.dart`

**Interfaces:**
- Produces:

```dart
/// Solves argmin_b  sum_i w_i (y_i - x_i . b)^2  +  sum_j lambda_j (b_j - prior_j)^2
/// via normal equations (X^T W X + diag(lambda)) b = X^T W y + diag(lambda) prior,
/// Gaussian elimination with partial pivoting. p is small (tens).
class RidgeRegression {
  static List<double> solve({
    required List<List<double>> x,      // n rows of length p
    required List<double> y,            // length n
    required List<double> weights,      // length n, >= 0
    required List<double> prior,        // length p
    required List<double> lambda,       // length p, > 0
  });
}
```

- [x] **Step 1: Failing tests** (verify expectations with python3/numpy where nontrivial):
  - n=0 -> returns `prior` exactly.
  - Single feature, many consistent observations -> coefficient converges near the data value, far from prior.
  - Two perfectly correlated features (always co-occur): the SUM of their coefficients matches the data-determined sum within 1e-6 even though the split follows priors.
  - Known 2x2 system solved by hand matches to 1e-9.
  - Observation weights: a weight-0 row has no influence.
- [x] **Step 2: Implement** — build the p-by-p normal matrix and RHS in doubles, eliminate with partial pivoting; throw `StateError` on a singular pivot below 1e-12 (cannot happen with lambda > 0, guard anyway).
- [x] **Step 3: Run to green, commit** — `git commit -m "feat(buoyancy): weighted ridge regression solver"`

---

### Task 10: WeightPredictionEngine — fit, predict, confidence, breakdown

**Files:**
- Create: `lib/core/buoyancy/weight_prediction_engine.dart`
- Test: `test/core/buoyancy/weight_prediction_engine_test.dart`

**Interfaces:**
- Consumes: Tasks 7 (`WeightObservation`), 8, 9.
- Produces (consumed by providers Task 12 and UI Tasks 13/17):

```dart
class TankSpec {
  final String? presetName; final double? volumeL;
  final double? workingPressureBar; final TankMaterial? material;
}
class RigSpec {
  final List<GearFeature> gear;
  final List<TankSpec> tanks;
  final WaterType? waterType;
  final double? bodyWeightKg;
}
enum TermSource { measured, userSpec, typeDefault, physics }
class PredictionTerm { final String label; final double kg; final TermSource source; }
enum PredictionConfidence { low, medium, high }
class WeightPrediction {
  final double totalKg;                       // clamped >= 0
  final List<PredictionTerm> terms;
  final PredictionConfidence confidence;
  final int supportingDives;
}

class WeightPredictionEngine {
  static const double kDefaultFeedbackMagnitudeKg = 1.0;
  static const double kPersonalPriorStrength = 2.0;
  static const double kRecencyHalfLifeDays = 730.0;

  /// gearById resolves observation equipment ids to features; unresolvable
  /// ids (deleted gear) get a zero-prior weak feature so history still fits.
  static FittedWeightModel fit({
    required List<WeightObservation> observations,
    required GearFeature? Function(String equipmentId) gearById,
    double? bodyWeightKg,
    DateTime? now,                             // injectable for tests
  });
}
class FittedWeightModel {
  WeightPrediction predict(RigSpec rig);
  double get residualStdKg;
  int get supportingDives;
}
```

Fit algorithm (spell out in code comments):
1. For each observation with `carriedKg > 0`: corrected `y = carried + adj - physics` where adj = `-(feedbackKg ?? 1.0)` for overweighted, `+(feedbackKg ?? 1.0)` for underweighted, `0` otherwise; physics = `sum(tankTermKg per tank) + waterTermKg(waterType, totalMass)` with totalMass = `(bodyWeightKg ?? 75) + sum(gear dryMass) + sum(tankDryMassKg)`.
2. Observation weight = `(feedback == correct ? 2.0 : 1.0) * pow(0.5, ageDays / 730)` (spec: only "correct"-rated dives count double; over/underweighted dives are corrected in step 1 and count normal).
3. Features: index 0 = personal intercept (prior `2.0 + max(0, ((bodyWeightKg ?? 75) - 70) / 10)`, lambda 2.0); one column per distinct equipment id across observations (prior/lambda from its `GearFeature`).
4. Solve ridge; compute weighted residual std; if any |residual| > 3 sigma and n >= 5, multiply that row's weight by 0.2 and solve once more (single reweight pass — deterministic).
5. `predict(rig)`: total = personal coef + sum over rig gear (fitted coef if the item was in the fit, else its prior) + physics terms for the rig; clamp >= 0. Terms: one per gear item (source: `measured` if in fit with >= 3 supporting uses, `userSpec` if `hasUserSpec`, else `typeDefault`), one per tank + one water term (source `physics`), one personal term (source `measured` if supportingDives >= 3 else `typeDefault`).
6. Confidence: `high` if supportingDives >= 10 AND informed-coverage >= 0.75 AND bodyWeightKg != null AND residualStd <= 1.5; `medium` if supportingDives >= 3 AND coverage >= 0.5; else `low`. Informed-coverage = fraction of rig gear features that have metadata OR >= 3 occurrences in observations (1.0 for an empty gear list).

- [x] **Step 1: Write failing golden-scenario tests** (synthetic observations built by a local helper; `now` injected; assert direction and bounded magnitude, not exact values):
  - Zero history -> prediction equals priors + physics; confidence `low`; total >= 0.
  - 20 identical salt dives (suit S + bcd B, al80, carried 8.0, feedback correct) -> predict same rig salt within +/- 0.5 of 8.0, confidence `high` given bodyWeight set; predict same rig FRESH -> lower by 1.5-3.5 kg (water term at ~90-100 kg total mass).
  - Gear swap never seen: replace suit S with unseen drysuit (prior 10, suit S fitted ~5) -> total increases by 3.0-7.0.
  - Chronic overweighting: 15 dives carried 10.0 all flagged overweighted magnitude 2.0 -> prediction 7.5-8.5.
  - Correlated pair: suit+bcd always together; prediction for the PAIR matches history sum within 0.5 even though individual terms differ from priors.
  - Outlier: one dive at 25 kg among 10 at 8 kg barely moves the prediction (< 0.7 shift vs without it).
- [x] **Step 2: Run to verify failure, implement, iterate to green.**
- [x] **Step 3: Commit** — `git commit -m "feat(buoyancy): hybrid weight prediction engine with calibration"`

---

### Task 11: Placement predictor

**Files:**
- Create: `lib/core/buoyancy/placement_predictor.dart`
- Test: `test/core/buoyancy/placement_predictor_test.dart`

**Interfaces:**

```dart
class PlacementPredictor {
  /// Returns null when no observation qualifies. incrementKg: 0.5 for kg
  /// display, 0.453592 for lb display. Largest-remainder allocation so the
  /// parts sum exactly to totalKg rounded to the increment.
  static Map<String, double>? predict({
    required double totalKg,
    required List<WeightObservation> observations,
    String? exposureItemId,      // rig's wetsuit/drysuit equipment id
    required double incrementKg,
    int maxObservations = 10,
  });
}
```

Filter: observations with non-empty `placement`, containing `exposureItemId` in `equipmentIds` when provided (when null or nothing matches, fall back to all placement-bearing observations); take the `maxObservations` most recent; average each WeightType fraction; multiply by total; round with largest remainder.

- [x] **Step 1: Failing tests** — fractions averaged correctly; parts sum exactly to the rounded total for awkward splits (e.g. total 6.6, increment 0.5, fractions 2/3-1/3); exposure filter applied then fallback; null when no placement history.
- [x] **Step 2: Implement, run to green, commit** — `git commit -m "feat(buoyancy): placement predictor with largest-remainder rounding"`

---

### Task 12: Weight planner providers

**Files:**
- Create: `lib/features/weight_planner/presentation/providers/weight_planner_providers.dart`
- Test: `test/features/weight_planner/presentation/weight_planner_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 4, 6, 7, 8, 10, 11; `validatedCurrentDiverIdProvider`; `allEquipmentProvider`; `divePlanNotifierProvider`; `DiveRepository().watchDivesChanges()` (`dive_repository_impl.dart:74`).
- Produces (consumed by Tasks 13 and 17):

```dart
final weightHistoryRepositoryProvider = Provider<WeightHistoryRepository>((ref) => WeightHistoryRepository());

/// Active diver's observations; invalidates on dive table changes.
final weightObservationsProvider = FutureProvider<List<WeightObservation>>(...);

/// Fitted model for the active diver (observations + gear features + latest
/// body weight entry). Refits when any input changes.
final weightCalibrationProvider = FutureProvider<FittedWeightModel>(...);

/// Converts an EquipmentItem to a GearFeature; returns null for the excluded
/// types (weights, tank).
GearFeature? gearFeatureFor(EquipmentItem item);

/// Live prediction for the plan being edited (Gear & Weights section).
final planWeightPredictionProvider = Provider<WeightPrediction?>(...);
```

`planWeightPredictionProvider` mirrors `planBailoutProvider` (`plan_canvas_providers.dart:231`): watch `divePlanNotifierProvider` state + `weightCalibrationProvider`/`allEquipmentProvider`/`latestDiverWeightProvider` `.valueOrNull` (return null while loading); build `RigSpec` from `state.equipmentIds` resolved to items, `state.tanks` mapped to `TankSpec(presetName: t.presetName, volumeL: t.volume, workingPressureBar: t.workingPressure, material: t.material)`, `state.waterType`, latest body weight; return `model.predict(rig)`.

- [x] **Step 1: Failing tests** — with a `ProviderContainer` and overridden inputs (synthetic observations via overriding `weightObservationsProvider`, equipment via `allEquipmentProvider`): calibration fits and predicts; `gearFeatureFor` excludes `weights`/`tank` types and passes metadata through; `planWeightPredictionProvider` returns null while calibration loads and a prediction once available.
- [x] **Step 2: Implement, run to green, format, commit** — `git commit -m "feat(weight-planner): calibration and prediction providers"`

---

### Task 13: Weight Planner page (tool rewrite)

**Files:**
- Create: `lib/features/weight_planner/presentation/pages/weight_planner_page.dart`
- Create: `lib/features/weight_planner/presentation/widgets/rig_composer.dart`
- Create: `lib/features/weight_planner/presentation/widgets/weight_prediction_card.dart`
- Modify: `lib/core/router/app_router.dart` (import line 114; route builder lines 246-250 -> `WeightPlannerPage`)
- Modify: `lib/features/tools/presentation/pages/tools_page.dart:53` (fix pre-existing bug: navigate to `/planning/weight-calculator`, not `/tools/weight-calculator`)
- Delete: `lib/features/tools/presentation/pages/weight_calculator_page.dart`, `lib/core/utils/weight_calculator.dart`
- Modify: all 11 arb files
- Test: `test/features/weight_planner/presentation/weight_planner_page_test.dart`

**Interfaces:**
- Consumes: Task 12 providers; `EquipmentPickerSheet`/`EquipmentSetPickerSheet` (`lib/features/dive_log/presentation/widgets/pickers/`, invocation pattern at `dive_edit_page.dart:2884/2899`); `tankPresetsProvider`; `UnitFormatter`.
- Produces: `WeightPlannerPage` at route `/planning/weight-calculator` (route name `weightCalculator` unchanged); `RigComposer` and `WeightPredictionCard` widgets reused by Task 17.

Page structure (ConsumerStatefulWidget): local state `List<EquipmentItem> _gear`, `List<TankPresetEntity> _tanks` (start with one: first preset or none), `WaterType? _water = WaterType.salt`, `TextEditingController _bodyWeight` (prefilled from `latestDiverWeightProvider` once), `double? _previousTotal` + `Timer? _deltaTimer` for the 4-second delta chip. Body: `SingleChildScrollView` with `RigComposer` (gear chips with delete, Use Set / Add Gear buttons opening the picker sheets, tank preset dropdown rows with add/remove, `SegmentedButton<WaterType>` for water, body-weight `TextField` with `units.weightSymbol` suffix and a save-to-profile `IconButton` that calls `DiverWeightEntryRepository.createEntry` when tapped) and `WeightPredictionCard`.

`WeightPredictionCard` renders from a `WeightPrediction?` + placement: big total `units.formatWeight(totalKg)`, placement rows (`WeightType` displayName + amount), confidence line `tools_weight_basedOnDives(supportingDives)` + level label, transient delta chip when `_previousTotal != null`, and an `ExpansionTile` breakdown listing each `PredictionTerm` with a source tag label. Prediction computed synchronously in build: `ref.watch(weightCalibrationProvider)` `.when(...)`; on data, build `RigSpec` from local state (gear -> `gearFeatureFor`, tanks -> `TankSpec`, body weight parsed via `units.weightToKg`) and call `model.predict`; placement via `PlacementPredictor.predict(totalKg: ..., observations: ref.watch(weightObservationsProvider).valueOrNull ?? const [], exposureItemId: <first wetsuit/drysuit in _gear>, incrementKg: settings.weightUnit == WeightUnit.kilograms ? 0.5 : 0.453592)`.

New l10n keys (add to `app_en.arb` + translate in all 10 other locales; reuse existing `tools_weight_title`, `tools_weight_waterType`, `tools_weight_notSpecified`, `tools_weight_bodyWeightOptional`, `planning_card_weightCalculator_*`):

```json
"tools_weight_addGear": "Add gear",
"tools_weight_useSet": "Use set",
"tools_weight_tanks": "Tanks",
"tools_weight_addTank": "Add tank",
"tools_weight_predictedWeight": "Predicted weight",
"tools_weight_basedOnDives": "Based on {count} logged dives",
"@tools_weight_basedOnDives": {"placeholders": {"count": {"type": "int"}}},
"tools_weight_confidence_high": "High confidence",
"tools_weight_confidence_medium": "Medium confidence",
"tools_weight_confidence_low": "Low confidence - estimate",
"tools_weight_placementTitle": "Suggested placement",
"tools_weight_breakdownTitle": "How this was calculated",
"tools_weight_source_measured": "measured from your dives",
"tools_weight_source_userSpec": "from your gear specs",
"tools_weight_source_typeDefault": "default estimate",
"tools_weight_source_physics": "physics",
"tools_weight_personalTerm": "Personal baseline",
"tools_weight_waterTerm": "Water type",
"tools_weight_deltaVsPrevious": "{delta} vs previous rig",
"@tools_weight_deltaVsPrevious": {"placeholders": {"delta": {"type": "String"}}},
"tools_weight_saveToProfile": "Save weight to profile",
"tools_weight_noGear": "Add the gear you plan to dive to personalize the prediction."
```

- [x] **Step 1: Failing widget test** — pump with `testApp` helper (`test/helpers/test_app.dart`) + overrides: `weightObservationsProvider` -> synthetic list, `allEquipmentProvider` -> two items, `tankPresetsProvider` -> built-ins, `latestDiverWeightProvider` -> entry(80kg). Assert: predicted total renders; removing a gear chip changes the displayed total; confidence line present.
- [x] **Step 2: Run to verify failure.**
- [x] **Step 3: Implement widgets + page; swap the router import/builder; fix `tools_page.dart:53`; delete the two legacy files; add l10n keys to all 11 arbs; `flutter gen-l10n`.**
- [x] **Step 4: Run the widget test + `flutter analyze` (deleting `WeightCalculator` must leave no dangling imports).**
- [x] **Step 5: Format + commit** — `git commit -m "feat(weight-planner): data-driven weight planner tool replacing static calculator"`

---

### Task 14: Weighting feedback control in the dive edit form

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (state near line 192; load near lines 614-627; `_weightChild` lines 3863-3915; save `Dive(...)` construction near line 4455)
- Modify: all 11 arb files
- Test: `test/features/dive_log/presentation/pages/dive_edit_weight_feedback_test.dart`

**Interfaces:**
- Consumes: Task 5 (`WeightingFeedback`, `Dive.weightingFeedback/.weightingFeedbackKg`).

State additions: `WeightingFeedback? _weightingFeedback;` and `final _feedbackAmountController = TextEditingController();` (wire into initState listeners/dispose like siblings). Load in `_initializeFromDive` where weights load (~614): set from `dive.weightingFeedback`, populate controller with `units.convertWeight(dive.weightingFeedbackKg!)` when present. Save: `weightingFeedback: _weightingFeedback, weightingFeedbackKg: <parse via units.weightToKg, only when feedback != null && != correct>` in the `Dive(...)` construction.

UI appended at the end of `_weightChild` (after the add button):

```dart
        const SizedBox(height: 12),
        Text(context.l10n.diveLog_edit_weightFeedback_label,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        SegmentedButton<WeightingFeedback>(
          emptySelectionAllowed: true,
          segments: [
            ButtonSegment(value: WeightingFeedback.correct,
                label: Text(context.l10n.diveLog_edit_weightFeedback_correct)),
            ButtonSegment(value: WeightingFeedback.overweighted,
                label: Text(context.l10n.diveLog_edit_weightFeedback_over)),
            ButtonSegment(value: WeightingFeedback.underweighted,
                label: Text(context.l10n.diveLog_edit_weightFeedback_under)),
          ],
          selected: {if (_weightingFeedback != null) _weightingFeedback!},
          onSelectionChanged: (sel) => setState(() {
            _weightingFeedback = sel.isEmpty ? null : sel.first;
            _markDirty();
          }),
        ),
        if (_weightingFeedback == WeightingFeedback.overweighted ||
            _weightingFeedback == WeightingFeedback.underweighted) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _feedbackAmountController,
            decoration: InputDecoration(
              labelText: context.l10n
                  .diveLog_edit_weightFeedback_amount(units.weightSymbol),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
```

l10n keys: `diveLog_edit_weightFeedback_label` = "How was your weighting?", `_correct` = "Felt right", `_over` = "Overweighted", `_under` = "Underweighted", `_amount` = "By about how much ({unit})" (placeholder `unit`, type String). All 11 locales.

- [x] **Step 1: Failing widget test** — mirror `dive_edit_page_test.dart` setup (in-memory DB + `buildOverrides`); create a dive, open editor, `ensureVisible` then tap "Overweighted" segment, enter 2 in the amount field, save; assert repository dive has `weightingFeedback == overweighted` and `weightingFeedbackKg == 2.0` (kg units in test settings). Second test: editing a dive with feedback pre-selects the segment.
- [x] **Step 2: Run to verify failure, implement, run to green.**
- [x] **Step 3: l10n all locales + gen; format; commit** — `git commit -m "feat(dive-log): weighting feedback capture on dive edit"`

---

### Task 15: Equipment edit Advanced fields

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (controllers lines 33-41 region; init 87; dispose 74-83; new `_buildAdvancedSection` mirroring `_buildServiceSection` at 587, inserted into the `ListView` after line 320; save `_saveEquipment` 772-818)
- Modify: all 11 arb files
- Test: `test/features/equipment/presentation/equipment_edit_advanced_test.dart`

**Interfaces:**
- Consumes: Task 4 fields. This form does not yet import settings/UnitFormatter — add `final units = UnitFormatter(ref.watch(settingsProvider));` in build and pass into the section builder.

Two `TextFormField`s in a "Advanced" card: buoyancy (suffix `units.weightSymbol`, hint varies by `_selectedType` via a switch: wetsuit/drysuit -> "Positive: how much it floats", tank -> "Leave empty - tanks use their own specs", default -> "Negative if it sinks") and dry weight (suffix `units.weightSymbol`). Populate from `equipment.buoyancyKg/.weightKg` via `units.convertWeight`; save with `units.weightToKg(double.tryParse(text))` or null when empty (mirroring the purchase-price parse at lines 802-804).

l10n keys: `equipment_edit_advanced_title` = "Advanced", `equipment_edit_buoyancyLabel` = "Buoyancy ({unit})", `equipment_edit_dryWeightLabel` = "Dry weight ({unit})", `equipment_edit_buoyancyHint_exposure` = "Positive: how much it floats", `equipment_edit_buoyancyHint_generic` = "Negative if it sinks", `equipment_edit_buoyancyHint_tank` = "Leave empty - tanks use their own specifications". All 11 locales.

- [x] **Step 1: Failing widget test** — pump edit page for an existing item, `ensureVisible` the Advanced card (labels are NOT uppercased in this page's cards — match exact strings), enter buoyancy -2.5 and weight 3, save, assert repository row values (kg test units).
- [x] **Step 2: Implement, green, l10n, format, commit** — `git commit -m "feat(equipment): advanced buoyancy and dry weight fields on gear edit"`

---

### Task 16: Body weight page, hub tile, route

**Files:**
- Create: `lib/features/settings/presentation/pages/body_weight_edit_page.dart`
- Modify: `lib/features/settings/presentation/pages/diver_profile_hub_page.dart` (`_buildSectionTilesCard`, add tile after line 210)
- Modify: `lib/core/router/app_router.dart` (sub-route near line 966: `path: 'body-weight'` under `diver-profile`)
- Modify: all 11 arb files
- Test: `test/features/settings/presentation/pages/body_weight_edit_page_test.dart`

**Interfaces:**
- Consumes: Task 3 repository/providers.

Page (ConsumerWidget): AppBar title; body = list of `diverWeightEntriesProvider` entries (date via `MaterialLocalizations`/existing date format idiom in sibling pages, weight `units.formatWeight`, height when present, trailing delete `IconButton` -> `deleteEntry` + `ref.invalidate(diverWeightEntriesProvider)`); FAB opens an `AlertDialog` with weight field (required, unit suffix), height field (optional, cm), date picker row defaulting to today (`showDatePicker`); save -> `createEntry` with the active diver id from `validatedCurrentDiverIdProvider`.

Hub tile: icon `Icons.monitor_weight`, title `diverProfile_bodyWeight_title`, subtitle = latest entry formatted or `diverProfile_bodyWeight_empty`, route `/settings/diver-profile/body-weight`.

l10n keys: `diverProfile_bodyWeight_title` = "Body Weight", `diverProfile_bodyWeight_empty` = "Not recorded", `bodyWeight_addEntry` = "Add measurement", `bodyWeight_weightLabel` = "Weight ({unit})", `bodyWeight_heightLabel` = "Height (cm)", `bodyWeight_dateLabel` = "Date", `bodyWeight_deleteTooltip` = "Delete entry". All 11 locales.

- [x] **Step 1: Failing widget test** — pump page with repo-backed in-memory DB; add an entry via dialog; assert list shows it and repository persisted it; delete removes it.
- [x] **Step 2: Implement page + tile + route, green, l10n, format, commit** — `git commit -m "feat(settings): dated body weight history in diver profile"`

---

### Task 17: Planner "Gear & Weights" section

**Files:**
- Create: `lib/features/dive_planner/presentation/widgets/plan_gear_weights_section.dart`
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart` (phone `ListView` line 283: append after `PlanTankList()`; wide `ListView` after line 345)
- Modify: all 11 arb files
- Test: `test/features/dive_planner/presentation/plan_gear_weights_section_test.dart`

**Interfaces:**
- Consumes: Task 6 notifier mutations (`setEquipmentIds`, `setPlannedWeight`); Task 12 `planWeightPredictionProvider`; picker sheets; `allEquipmentProvider`.

`PlanGearWeightsSection extends ConsumerWidget` returning a `Card` (mirror `PlanTankList` structure, `plan_tank_list.dart:26`): header row (title + Use Set / Add icons opening the picker sheets; on selection call `ref.read(divePlanNotifierProvider.notifier).setEquipmentIds([...state.equipmentIds, item.id])`), `Wrap` of `InputChip`s (label = equipment name resolved from `allEquipmentProvider`, `onDeleted` removes the id), then a prediction row: `ref.watch(planWeightPredictionProvider)` -> when non-null show `units.formatWeight(prediction.totalKg)` + confidence label + a `TextButton` "Use as planned weight" calling `setPlannedWeight(prediction.totalKg, <placement from PlacementPredictor over observations>)`; when the plan already has `plannedWeightKg`, show it with a check icon. Water type and tanks come from the plan state — no inputs here.

l10n keys: `planner_gearWeights_title` = "Gear & Weights", `planner_gearWeights_predicted` = "Predicted: {weight}" (String placeholder), `planner_gearWeights_accept` = "Use as planned weight", `planner_gearWeights_planned` = "Planned: {weight}" (String placeholder), `planner_gearWeights_addGear` = "Add gear", `planner_gearWeights_useSet` = "Use set", `planner_gearWeights_empty` = "Add gear to predict your weighting". All 11 locales.

- [x] **Step 1: Failing widget test** — pump `PlanGearWeightsSection` inside `testApp` with overrides (`divePlanNotifierProvider` state containing one tank + equipmentIds, calibration overridden as in Task 12's test); assert prediction text renders; tap accept; assert `state.plannedWeightKg` set.
- [x] **Step 2: Implement + insert into both `plan_canvas_page.dart` ListViews** (the phone list is `const` — remove `const` from the list literal since the section is const-constructible anyway, keep `const` if possible).
- [x] **Step 3: Green, l10n, format, commit** — `git commit -m "feat(planner): gear and weights section with live weight prediction"`

---

### Task 18: Finalization sweep

**Files:** none new.

- [x] **Step 1: Full formatting + analysis**

Run: `dart format .` (must output "0 changed"). Run: `flutter analyze` (whole project, zero issues).

- [x] **Step 2: Run the feature test surface**

Run: `flutter test test/core/buoyancy/ test/core/database/migration_v104_weight_prediction_test.dart test/core/services/sync/ test/features/weight_planner/ test/features/divers/ test/features/equipment/ test/features/dive_log/ test/features/planner/ test/features/dive_planner/ test/features/settings/ test/l10n/`
Expected: all PASS.

- [x] **Step 3: l10n completeness check** — `flutter gen-l10n` runs clean; grep each new key across all 11 arb files and confirm 11 hits per key.

- [x] **Step 4: Final commit of any stragglers**

```bash
git add -A
git commit -m "chore(weight-planner): formatting and finalization sweep"
```

---

## Explicit scope notes

- UDDF export is intentionally unchanged: UDDF has no standard element for weighting feedback, per-item buoyancy, or body-weight history; raw backup (byte copy) and sync changesets carry all new data automatically. CSV gains the two equipment columns (Task 4).
- The `weights` and `tank` `EquipmentType`s never become gear features (lead is the predicted quantity; tanks are modeled from the tank list).
- `dives.weightAmount` legacy scalar stays untouched; observations fall back to it when `dive_weights` is empty.
