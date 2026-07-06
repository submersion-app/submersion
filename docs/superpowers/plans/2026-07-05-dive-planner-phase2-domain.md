# Dive Planner Phase 2: Plan Domain, Persistence, Sync, PlanEngine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist dive plans (three synced Drift tables at schema v100), give them a repository with full sync participation, build the `PlanEngine` orchestrator on the Phase 1 engine seams (`DecoModel`/`BreathingConfig`/`SchedulePolicy`/`DiveEnvironment`), and make the existing planner's save/load stubs real.

**Architecture:** New feature module `lib/features/planner/` (domain entities + PlanEngine + repository). The OLD `dive_planner` feature keeps `PlanCalculatorService` untouched and keeps rendering — Phase 3 cuts the UI over. Persistence follows the checklists-v98 recipe exactly (the most recent three-table synced feature). Branch: stacked on `worktree-dive-planner-phase1-engine` (PR #484) — the engine API this builds on.

**Tech Stack:** Drift 2.30 (codegen via build_runner), the app's changeset-log sync (HLC conflict resolution), Riverpod, pure-Dart engine.

**Spec:** `docs/superpowers/specs/2026-07-05-dive-planner-redesign-design.md` (section "Plan domain and persistence (Phase 2)")

## Global Constraints

- Schema version goes **99 → 100** (`lib/core/database/database.dart:1847`). Memory note "v98+" is stale; v98=checklists, v99=buddy roles already exist.
- All 18 sync registration sites (14 serializer + 3 sync_service + 1 sync_repository) MUST be filled; the structural tests (`sync_base_streaming_parity_test.dart`, `sync_parent_refs_completeness_test.dart`, `sync_data_serializer_record_ids_test.dart`) are the safety net — run them after registration.
- Entity type strings (used in sync + deletion log, never change them): `divePlans`, `divePlanTanks`, `divePlanSegments`. SQLite tables: `dive_plans`, `dive_plan_tanks`, `dive_plan_segments`.
- `.toCompanion(false)` for upserts of HLC entities (all three tables have `hlc`).
- After every repository write: `markRecordPending` + `SyncEventBus.notifyLocalChange()`; after every delete: `logDeletion` per row (children too — parent-surviving child deletes need per-row tombstones).
- Existing tests must keep passing. `dart format .` before each commit; `flutter analyze` clean. Run specific test files, not broad dirs. Commit per task (pre-authorized), no Co-Authored-By.
- Python3 for any computed test vectors — never from recall.
- Old planner behavior unchanged except: save/load actually persist (Task 7).

---

### Task 1: Schema v100 — three plan tables + migration

**Files:**
- Modify: `lib/core/database/database.dart` (table classes near the checklist tables ~line 130-198 region; `@DriftDatabase` list :1769; `currentSchemaVersion` :1847; `migrationVersions` :1852; `onUpgrade` chain end ~:4624; `beforeOpen` backstop ~:4626)
- Test: `test/core/database/migration_v100_dive_plans_test.dart`

**Interfaces:**
- Produces: Drift tables `DivePlans`, `DivePlanTanks`, `DivePlanSegments`; generated data classes `DivePlan`, `DivePlanTank`, `DivePlanSegment` (+`Companion`s, `.fromJson/.toJson/.toCompanion`). Later tasks import these from `database.dart` and alias domain entities `as domain`.

- [ ] **Step 1: Write the failing migration test**

Model on `test/core/database/migration_v98_checklists_test.dart` (read it first, copy its structure): open `NativeDatabase.memory(setup: (raw) { raw.execute('PRAGMA user_version = 99'); /* minimal parents: divers, dives, dive_sites tables as the v98 test does for its parents */ })`, then open `AppDatabase`, then for each of `dive_plans`, `dive_plan_tanks`, `dive_plan_segments` assert via `PRAGMA table_info(...)`:
- `dive_plans` has columns: `id`, `diver_id`, `name`, `notes`, `mode`, `site_id`, `source_dive_id`, `linked_dive_id`, `altitude`, `water_type`, `gf_low`, `gf_high`, `descent_rate`, `ascent_rate`, `last_stop_depth`, `gas_switch_stop_seconds`, `air_break_o2_seconds`, `air_break_break_seconds`, `sac_bottom`, `sac_deco`, `sac_stressed`, `reserve_pressure`, `surface_interval_seconds`, `setpoint_low`, `setpoint_high`, `setpoint_switch_depth`, `deviation_depth_delta`, `deviation_time_minutes`, `turn_pressure_rule`, `turn_pressure_fraction`, `summary_max_depth`, `summary_runtime_seconds`, `summary_tts_seconds`, `created_at`, `updated_at`, `hlc`
- `dive_plan_tanks` has: `id`, `plan_id`, `name`, `volume`, `working_pressure`, `start_pressure`, `gas_o2`, `gas_he`, `role`, `material`, `preset_name`, `sort_order`, `created_at`, `updated_at`, `hlc`
- `dive_plan_segments` has: `id`, `plan_id`, `type`, `start_depth`, `end_depth`, `duration_seconds`, `tank_id`, `gas_o2`, `gas_he`, `rate`, `switch_to_tank_id`, `sort_order`, `created_at`, `updated_at`, `hlc`
- indexes `idx_dive_plan_tanks_plan_id` and `idx_dive_plan_segments_plan_id` exist
- include the "recovers databases stranded at v99" collision test from the v98 model (set user_version 100 with tables missing → beforeOpen re-assert heals).

Run: `flutter test test/core/database/migration_v100_dive_plans_test.dart` — expected FAIL (tables missing).

- [ ] **Step 2: Add the three Drift table classes** (place after the checklist tables):

```dart
/// Saved dive plans (Phase 2 of the planner redesign).
class DivePlans extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// PlanMode enum name: 'oc' | 'ccr'.
  TextColumn get mode => text().withDefault(const Constant('oc'))();
  TextColumn get siteId => text().nullable().references(DiveSites, #id)();

  /// Tissue-seeding source dive (repetitive planning, Phase 6).
  TextColumn get sourceDiveId => text().nullable().references(Dives, #id)();

  /// Executed dive this plan is linked to (plan-vs-actual, Phase 6).
  TextColumn get linkedDiveId => text().nullable().references(Dives, #id)();
  RealColumn get altitude => real().nullable()();

  /// WaterType enum name; null = unspecified (EN13319 density).
  TextColumn get waterType => text().nullable()();
  IntColumn get gfLow => integer()();
  IntColumn get gfHigh => integer()();
  RealColumn get descentRate => real().withDefault(const Constant(18.0))();
  RealColumn get ascentRate => real().withDefault(const Constant(9.0))();
  RealColumn get lastStopDepth => real().withDefault(const Constant(3.0))();
  IntColumn get gasSwitchStopSeconds =>
      integer().withDefault(const Constant(0))();

  /// Air-break policy; both null = no air breaks.
  IntColumn get airBreakO2Seconds => integer().nullable()();
  IntColumn get airBreakBreakSeconds => integer().nullable()();
  RealColumn get sacBottom => real().withDefault(const Constant(15.0))();

  /// Null = derive 0.8x / 2.5x of sacBottom.
  RealColumn get sacDeco => real().nullable()();
  RealColumn get sacStressed => real().nullable()();
  RealColumn get reservePressure => real().withDefault(const Constant(50.0))();
  IntColumn get surfaceIntervalSeconds => integer().nullable()();

  /// CCR setpoints (Phase 4 UI; persisted now to avoid a later migration).
  RealColumn get setpointLow => real().nullable()();
  RealColumn get setpointHigh => real().nullable()();
  RealColumn get setpointSwitchDepth => real().nullable()();

  /// Contingency config (Phase 5 UI).
  RealColumn get deviationDepthDelta =>
      real().withDefault(const Constant(5.0))();
  IntColumn get deviationTimeMinutes =>
      integer().withDefault(const Constant(5))();

  /// TurnPressureRule enum name; null = none.
  TextColumn get turnPressureRule => text().nullable()();
  RealColumn get turnPressureFraction => real().nullable()();

  /// Denormalized list-display summary (no engine run per list row).
  RealColumn get summaryMaxDepth => real().nullable()();
  IntColumn get summaryRuntimeSeconds => integer().nullable()();
  IntColumn get summaryTtsSeconds => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution
  /// (nullable: rows written before HLC rollout fall back to updatedAt).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tanks carried on a saved dive plan.
class DivePlanTanks extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();
  TextColumn get name => text().nullable()();
  RealColumn get volume => real().nullable()();
  RealColumn get workingPressure => real().nullable()();
  RealColumn get startPressure => real().nullable()();
  RealColumn get gasO2 => real().withDefault(const Constant(21.0))();
  RealColumn get gasHe => real().withDefault(const Constant(0.0))();

  /// TankRole enum name.
  TextColumn get role => text().withDefault(const Constant('backGas'))();

  /// TankMaterial enum name; null = unspecified.
  TextColumn get material => text().nullable()();
  TextColumn get presetName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// User-authored segments (the bottom portion) of a saved dive plan.
class DivePlanSegments extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();

  /// SegmentType enum name.
  TextColumn get type => text()();
  RealColumn get startDepth => real()();
  RealColumn get endDepth => real()();
  IntColumn get durationSeconds => integer()();
  TextColumn get tankId => text().references(DivePlanTanks, #id)();
  RealColumn get gasO2 => real()();
  RealColumn get gasHe => real()();
  RealColumn get rate => real().nullable()();
  TextColumn get switchToTankId => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

NOTE: the generated data class for `DivePlans` is `DivePlan` — it collides with the domain aggregate added in Task 3; domain code uses `as domain` imports per codebase convention (`hide`/alias, see `trip_checklist_repository.dart`).

- [ ] **Step 3: Register + migrate**

1. Add `DivePlans, DivePlanTanks, DivePlanSegments` to the `@DriftDatabase(tables: [...])` list.
2. `currentSchemaVersion` → `100`; append `100` to `migrationVersions`.
3. Append the `if (from < 100)` block at the end of `onUpgrade`, using idempotent raw DDL exactly mirroring the v98 checklist block (CREATE TABLE IF NOT EXISTS with the snake_case columns from Step 1's list, then `CREATE INDEX IF NOT EXISTS idx_dive_plan_tanks_plan_id ON dive_plan_tanks(plan_id)` and `idx_dive_plan_segments_plan_id ON dive_plan_segments(plan_id)`), then `if (from < 100) await reportProgress();`.
4. Replace the v99 `beforeOpen` re-assert backstop with a v100 one (same pattern as :4637-4649): re-run the three `CREATE TABLE IF NOT EXISTS` + two `CREATE INDEX IF NOT EXISTS` statements on every open. Keep the v99 re-asserts too (append, don't remove).

- [ ] **Step 4: Codegen + test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/migration_v100_dive_plans_test.dart
```
Expected: PASS. Also run one existing migration test to confirm the chain still works: `flutter test test/core/database/migration_v98_checklists_test.dart`.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v100_dive_plans_test.dart
git commit -m "feat(planner): dive plan tables at schema v100"
```

---

### Task 2: Sync registration — all 18 sites

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (14 sites)
- Modify: `lib/core/services/sync/sync_service.dart` (3 sites)
- Modify: `lib/core/data/repositories/sync_repository.dart` (1 site)
- Test: `test/core/services/sync/dive_plan_sync_round_trip_test.dart`

**Interfaces:**
- Produces: full sync participation for entity types `divePlans`, `divePlanTanks`, `divePlanSegments`. Task 4's repository relies on `markRecordPending`/`logDeletion` working for these types.

- [ ] **Step 1: Serializer — 14 sites** in `sync_data_serializer.dart`, each copying the adjacent checklist entries verbatim with the new names (order everywhere: plans → tanks → segments, parent before child; tanks BEFORE segments because segments FK tanks):

1. Fields (~:235): `final List<Map<String, dynamic>> divePlans;` + `divePlanTanks` + `divePlanSegments`
2. Constructor defaults (~:281): `this.divePlans = const [],` (x3)
3. `toJson()` (~:328): `'divePlans': divePlans,` (x3)
4. `fromJson()` (~:376): `divePlans: _parseList(json['divePlans']),` (x3)
5. `_baseTables` (~:566): `(key: 'divePlans', table: _db.divePlans, blob: false, full: null),` then `divePlanTanks`, then `divePlanSegments`
6. `_buildSyncData` (~:941): `divePlans: await _safeExport('divePlans', () => _exportDivePlans(hlcSince)),` (x3)
7. `fetchRecord` switch (~:1257): three cases mirroring checklists
8. `fetchRecords` switch (~:1457): three cases
9. `upsertRecord` switch (~:1699): `case 'divePlans': await _db.into(_db.divePlans).insertOnConflictUpdate(DivePlan.fromJson(data).toCompanion(false)); return;` (x3 — data classes `DivePlan`/`DivePlanTank`/`DivePlanSegment`)
10. `upsertRecords` batch switch (~:2077): three cases via `insertAllOnConflictUpdate`
11. `recordIdsFor` (~:2373): `return plain(_db.divePlans, _db.divePlans.id);` (x3)
12. `_syncTableFor` (~:2496): three cases
13. `deleteRecord` switch (~:2685): three cases
14. Export helpers (~:3085), one per table on the checklist template:

```dart
Future<List<Map<String, dynamic>>> _exportDivePlans(String? hlcSince) async {
  final query = _db.select(_db.divePlans);
  if (hlcSince != null) {
    query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
  }
  final rows = await query.get();
  return rows.map((r) => r.toJson()).toList();
}
```

- [ ] **Step 2: sync_service.dart — 3 sites**

15. `mergeOrder` (~:835), AFTER the checklist entries:
```dart
(type: 'divePlans', records: data.divePlans, hasUpdatedAt: true),
(type: 'divePlanTanks', records: data.divePlanTanks, hasUpdatedAt: true),
(type: 'divePlanSegments', records: data.divePlanSegments, hasUpdatedAt: true),
```
16. `entityHasUpdatedAt` map (~:1439): the same three keys, `true`.
17. `parentRefs` (~:1553):
```dart
'divePlans': [
  (field: 'siteId', parent: 'diveSites', nullable: true),
  (field: 'sourceDiveId', parent: 'dives', nullable: true),
  (field: 'linkedDiveId', parent: 'dives', nullable: true),
],
'divePlanTanks': [(field: 'planId', parent: 'divePlans', nullable: false)],
'divePlanSegments': [
  (field: 'planId', parent: 'divePlans', nullable: false),
  (field: 'tankId', parent: 'divePlanTanks', nullable: false),
],
```
Check what the checklists did for `diverId` (whether divers refs are required) and mirror; `sync_parent_refs_completeness_test.dart` is the arbiter — run it and add exactly what it demands (parent key names must match its conventions, e.g. `diveSites` vs `dive_sites`; copy from existing entries).

- [ ] **Step 3: sync_repository.dart — site 18**, `_hlcTargets` (~:38):
```dart
'divePlans': (table: 'dive_plans', pk: 'id'),
'divePlanTanks': (table: 'dive_plan_tanks', pk: 'id'),
'divePlanSegments': (table: 'dive_plan_segments', pk: 'id'),
```

- [ ] **Step 4: Structural tests + FK-ON round trip**

Run the safety-net tests:
```bash
flutter test test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_extra_entities_round_trip_test.dart
```
Fix whatever they flag. Then write `test/core/services/sync/dive_plan_sync_round_trip_test.dart` modeled on `checklist_sync_round_trip_test.dart` (FK ON via `setUpTestDatabase()`): insert a plan + 2 tanks + 3 segments directly via Drift companions (real FK chain), export via `SyncDataSerializer().exportData(...)`, assert counts, JSON round-trip through `SyncData.fromJson(jsonDecode(jsonEncode(...)))`, re-assert; then `upsertRecord` each into a second in-memory DB and verify rows land (FK ON — insertion order plans → tanks → segments).

Run: the new test — expected PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart lib/core/data/repositories/sync_repository.dart test/core/services/sync/dive_plan_sync_round_trip_test.dart
git commit -m "feat(sync): register dive plan tables across the sync pipeline"
```

---

### Task 3: Domain aggregate — `domain.DivePlan`

**Files:**
- Create: `lib/features/planner/domain/entities/dive_plan.dart`
- Test: `test/features/planner/dive_plan_entity_test.dart`

**Interfaces:**
- Consumes: `PlanSegment` (from `dive_planner/domain/entities/plan_segment.dart` — reused, NOT duplicated), `DiveTank`/`GasMix` (from `dive_log/domain/entities/dive.dart`), `WaterType`/`TankRole` enums, `AirBreakPolicy` (engine type, reused).
- Produces (Tasks 4-7 use these exact names):

```dart
enum PlanMode { oc, ccr }
enum TurnPressureRule { allUsable, halves, thirds, custom }
class DivePlan extends Equatable {
  // identity/meta
  final String id; final String name; final String notes;
  final String? siteId; final DateTime createdAt; final DateTime updatedAt;
  // mode + environment
  final PlanMode mode; final double? altitude; final WaterType? waterType;
  // deco settings
  final int gfLow; final int gfHigh;
  final double descentRate; final double ascentRate;
  final double lastStopDepth; final int gasSwitchStopSeconds;
  final AirBreakPolicy? airBreaks;
  // gas planning
  final double sacBottom; final double? sacDeco; final double? sacStressed;
  final double reservePressure;
  // repetitive context
  final Duration? surfaceInterval; final String? sourceDiveId;
  final String? linkedDiveId;
  // CCR (Phase 4) + contingency (Phase 5) config — persisted, unused yet
  final double? setpointLow; final double? setpointHigh;
  final double? setpointSwitchDepth;
  final double deviationDepthDelta; final int deviationTimeMinutes;
  final TurnPressureRule? turnPressureRule; final double? turnPressureFraction;
  // content
  final List<PlanSegment> segments; final List<DiveTank> tanks;
  // derived defaults
  double get sacDecoEffective => sacDeco ?? sacBottom * 0.8;
  double get sacStressedEffective => sacStressed ?? sacBottom * 2.5;
  double get maxDepth; // max over segments' start/end depth, 0 if empty
  // copyWith with clear-flags for every nullable field
}
class DivePlanSummary extends Equatable {
  final String id; final String name; final DateTime updatedAt;
  final double? maxDepth; final int? runtimeSeconds; final int? ttsSeconds;
  final PlanMode mode;
}
```

Defaults in the unnamed constructor mirror the DB defaults (mode oc, notes '', rates 18/9, lastStop 3, gasSwitchStopSeconds 0, sacBottom 15, reservePressure 50, deviation 5 m/5 min).

- [ ] **Step 1: Write failing tests** — construct a `DivePlan`, assert `sacDecoEffective`/`sacStressedEffective` derivation (15 → 12 / 37.5) and explicit override; `maxDepth` from segments; `copyWith` clear-flags null out `airBreaks`, `surfaceInterval`, `sourceDiveId`. Run → FAIL (file missing).

- [ ] **Step 2: Implement** the entity exactly per the interface block (plain Equatable, no Drift imports). Run tests → PASS.

- [ ] **Step 3: Commit**

```bash
dart format .
git add lib/features/planner/ test/features/planner/dive_plan_entity_test.dart
git commit -m "feat(planner): DivePlan domain aggregate"
```

---

### Task 4: DivePlanRepository

**Files:**
- Create: `lib/features/planner/data/repositories/dive_plan_repository.dart`
- Create: `lib/features/planner/presentation/providers/plan_repository_providers.dart`
- Test: `test/features/planner/dive_plan_repository_test.dart`

**Interfaces:**
- Consumes: Drift tables (Task 1), sync hooks (Task 2), `domain.DivePlan` (Task 3).
- Produces:

```dart
class DivePlanRepository {
  Stream<void> watchPlanChanges(); // tableUpdates on all three tables
  Future<void> savePlan(domain.DivePlan plan, {PlanSummaryData? summary});
  Future<domain.DivePlan?> getPlan(String id);   // with ordered tanks+segments
  Future<List<domain.DivePlanSummary>> getAllPlanSummaries(); // newest first
  Future<void> deletePlan(String id);            // children first, tombstones per row
  Future<domain.DivePlan?> duplicatePlan(String id); // new ids, "name (copy)"
}
class PlanSummaryData { final double maxDepth; final int runtimeSeconds; final int? ttsSeconds; }
```

Follow `trip_checklist_repository.dart` shape exactly: `AppDatabase get _db => DatabaseService.instance.database;`, `SyncRepository()`, `LoggerService.forClass`, `import ... database.dart` with domain entities `as domain` (mind the `DivePlan` name collision: import the DATABASE with `show`/`hide` or alias — mirror how checklists resolved `Trip`).

**savePlan semantics (sync-safe child diffing):** inside a transaction, upsert the plan row and every current tank/segment row (stable child ids come from the domain objects); collect previously-persisted child ids, and delete rows whose ids are gone. AFTER the transaction commits: `markRecordPending` for the plan and every upserted child, `logDeletion` for every removed child, then one `SyncEventBus.notifyLocalChange()` (transaction discipline per `applyTemplate` in the checklist repo).

**deletePlan:** delete segments, tanks, then plan (FK order); `logDeletion` for every row of all three types; notify.

- [ ] **Step 1: Write failing tests** (FK ON via `setUpTestDatabase()` — read `test/helpers/test_database.dart` and an existing repo test for setup):
- save → getPlan round-trips every field (incl. airBreaks, waterType, surfaceInterval, enums)
- getAllPlanSummaries returns saved summary numbers without loading children
- re-save with a removed segment: row gone AND a `deletion_log` row exists for it (`entityType: 'divePlanSegments'`)
- deletePlan removes all rows + writes tombstones for plan/tanks/segments
- duplicatePlan: new ids everywhere, segments' tankId remapped to the NEW tank ids, name suffixed " (copy)"
- sync_records: savePlan marks plan + children pending (query `sync_records` or use SyncRepository API as checklist tests do)

Run → FAIL.

- [ ] **Step 2: Implement repository + mappers** (row↔domain: enums by `.name` with `values.byName`, millis↔DateTime, gasO2/gasHe↔`GasMix`, `Duration`↔seconds; segments/tanks ordered by `sortOrder` and written with their list index as `sortOrder`). Providers: `Provider<DivePlanRepository>` + `FutureProvider<List<domain.DivePlanSummary>>` with `ref.invalidateSelfWhen(repo.watchPlanChanges())`.

- [ ] **Step 3: Run tests → PASS, commit**

```bash
dart format .
git add lib/features/planner/ test/features/planner/dive_plan_repository_test.dart
git commit -m "feat(planner): DivePlanRepository with full sync participation"
```

---

### Task 5: PlanEngine — outcome types + schedule + tissue timeline

**Files:**
- Create: `lib/features/planner/domain/entities/plan_outcome.dart`
- Create: `lib/features/planner/domain/services/plan_engine.dart`
- Test: `test/features/planner/plan_engine_schedule_test.dart`

**Interfaces:**
- Consumes: `DecoModel`/`BuhlmannGf`/`BuhlmannState`/`DecoSegment`/`DecoSchedule`, `SchedulePolicy`/`AirBreakPolicy`, `OpenCircuit`, `DiveEnvironment.forConditions`, `OptimalOcAscentGas`/`AvailableGas`, `O2ToxicityCalculator` (CNS/OTU/MOD), `domain.DivePlan`.
- Produces:

```dart
enum PlanIssueSeverity { info, warning, alert, critical }
enum PlanIssueType {
  ppO2High, ppO2Critical, hypoxicGas, endExceeded,
  gasDensityHigh, gasDensityCritical, cnsWarning, cnsCritical,
  otuHigh, gasReserveViolation, gasOut, ndlExceededNoDecoGas,
}
class PlanIssue { type, severity, message, atRuntime?, atDepth?, segmentId?, value?, threshold? }
class PlanStop { depthMeters, durationSeconds, airBreakSeconds, gasFO2, gasFHe, tankId?, arrivalRuntimeSeconds }
class SegmentOutcome { segmentId, startRuntime, endRuntime, ndlAtEnd, ceilingAtEnd, ttsAtEnd, cns, otu, maxPpO2 }
class PlanTankUsage { tankId, litersUsed, remainingPressure?, percentUsed, reserveViolation }
class PlanOutcome {
  runtimeSeconds, maxDepth, ndlAtBottom, ttsAtBottom,
  stops (List<PlanStop>), segmentOutcomes (List<SegmentOutcome>),
  tankUsages, cnsEnd, otuTotal, issues (severity-sorted desc),
  endTissue (BuhlmannState), tissueTimeline (List<(int runtimeSeconds, BuhlmannState)>),
  bool get isDiveable => no critical issues;
}
class PlanEngineConfig {
  ppO2Working = 1.4, ppO2Deco = 1.6, cnsWarningThreshold = 80,
  o2Narcotic = true, endLimitMeters = 30.0, otuLimit = 300.0,
  // density thresholds live in gas_density.dart (Task 6)
}
class PlanEngine {
  PlanEngine({PlanEngineConfig config = const PlanEngineConfig()});
  PlanOutcome compute(domain.DivePlan plan);
}
```

**compute() flow (Phase 2 = OC only; `mode == ccr` yields a single critical issue "CCR planning arrives in a later update" and an OC-computed outcome on the diluent-free path — i.e. compute as OC):**
1. `env = DiveEnvironment.forConditions(altitudeMeters: plan.altitude, waterType: plan.waterType)`.
2. `policy = SchedulePolicy(lastStopDepth: plan.lastStopDepth, ascentRate: plan.ascentRate, gasSwitchStopSeconds: plan.gasSwitchStopSeconds, airBreaks: plan.airBreaks)`.
3. `model = BuhlmannGf(gfLow: plan.gfLow/100, gfHigh: plan.gfHigh/100, environment: env, policy: policy)`.
4. `state = model.initial()`; TODO-free repetitive context: if `plan.surfaceInterval != null` the engine accepts an optional `TissueState? startState` parameter on `compute` (Phase 6 feeds it; default null).
5. Per ordered segment: `state = model.applySegment(state, DecoSegment(startDepth, endDepth, durationSeconds), OpenCircuit(fO2: gasMix.o2/100, fHe: gasMix.he/100))`; record `(runtime, state)` into tissueTimeline; SegmentOutcome via `model.ndlSeconds(state, depthMeters: endDepth, breathing: seg gas)`, `model.ceilingMeters(state, currentDepth: endDepth)`, and `model.schedule(...).ttsSeconds` at the segment end; track ndl/tts at the deepest/bottom segment (same rule as PlanCalculatorService: `type == bottom || endDepth >= maxDepth - 0.1`).
6. Ascent gases: `AvailableGas` per tank with `maxPpO2Mod = O2ToxicityCalculator.calculateMod(o2/100, maxPpO2: config.ppO2Deco)`; `schedule = model.schedule(state, currentDepth: lastEndDepth, gases: OptimalOcAscentGas(gases, maxPpO2: config.ppO2Deco))`.
7. Map engine stops → `PlanStop` (gas via `plan.gasForDepth` equivalent: `OptimalOcAscentGas.gasForDepth(stop.depthMeters)`; tankId = carried tank whose mix matches, deepest-MOD tiebreak; arrival runtimes accumulate ascent legs at `plan.ascentRate` like `_buildDecoSchedule` does today).
8. `runtimeSeconds` = segments + stops + ascent legs; `endTissue` = state after applying stops? NO — keep parity with today: endTissueState = state at end of user segments (stops are simulated inside `schedule`). Document that choice.

- [ ] **Step 1: Write failing tests**
- **Parity test (the pin):** a 45 m / 25 min air plan (descent 18 m/min + bottom + one AL80) run through BOTH `PlanCalculatorService.calculatePlan` (legacy) and `PlanEngine.compute` produces identical stop depths/durations and equal `ttsAtBottom` (BuhlmannGf's default-policy path is bit-compatible with the legacy engine — proven in Phase 1).
- Trimix multi-gas plan (Tx18/45 60 m/25 min + EAN50 + O2 tanks): stops include gas switches; every `PlanStop` at ≤6 m carries fO2 1.0; `arrivalRuntimeSeconds` strictly increases.
- `plan.airBreaks` set → total deco longer than without, and some `PlanStop.airBreakSeconds > 0` (mirrors the Phase 1 schedule_policy test shape).
- `lastStopDepth: 6` → no stop shallower than 6 m.
- tissueTimeline has one entry per segment with increasing runtime.

Run → FAIL.

- [ ] **Step 2: Implement** `plan_outcome.dart` + `plan_engine.dart` per the flow. Run tests → PASS.

- [ ] **Step 3: Commit**

```bash
dart format .
git add lib/features/planner/domain/ test/features/planner/plan_engine_schedule_test.dart
git commit -m "feat(planner): PlanEngine schedule generation on the DecoModel seam"
```

---

### Task 6: PlanEngine — consumption + PlanIssues; shared gas-density helper

**Files:**
- Create: `lib/core/deco/gas_density.dart`
- Modify: `lib/features/dive_log/data/services/profile_analysis_service.dart` (`_calculateDensityCurve` uses the helper)
- Modify: `lib/features/planner/domain/services/plan_engine.dart`
- Test: `test/core/deco/gas_density_test.dart`, `test/features/planner/plan_engine_issues_test.dart`

**Interfaces:**
- Produces:

```dart
// lib/core/deco/gas_density.dart
const double gasDensityWarnGPerL = 5.2;
const double gasDensityCriticalGPerL = 6.2;
double gasDensityGPerL({required double fO2, required double fHe, required double ambientPressureBar});
```

- [ ] **Step 1: Extract the density formula.** Read `ProfileAnalysisService._calculateDensityCurve` and move its exact math (molar masses and the molar-volume divisor it uses — do not change the numbers) into `gasDensityGPerL`; make the service call the helper. Compute one pinned vector with python3 using the SAME constants you extracted (e.g. air at 40 m standard env) and write `gas_density_test.dart` asserting it plus `density(air @ >52m) > 5.2`. Run existing analysis tests to prove no drift: `flutter test test/features/dive_log/presentation/providers/profile_analysis_provider_test.dart`.

- [ ] **Step 2: Consumption in PlanEngine.** Per segment: `liters = sac × minutes × env.pressureAtDepth(avgDepth)` where `sac` is `sacBottom` for descent/bottom segments and `sacDecoEffective` for ascent/deco/safety segments; per stop: `sacDecoEffective × stopMinutes × env.pressureAtDepth(stopDepth)` charged to the stop's matched tank; ascent legs between stops at `sacDecoEffective` on the leg's gas/tank. Remaining pressure per tank via `pressureAfterConsuming` (compressibility, from `gas_compressibility.dart`). Produce `PlanTankUsage` per tank.

- [ ] **Step 3: Issues.** Emit, severity-sorted (critical > alert > warning > info):
- `ppO2Critical` (> ppO2Deco anywhere) / `ppO2High` (> ppO2Working on a working segment)
- `hypoxicGas`: inspired pO2 < 0.16 bar at any segment start depth on its gas (use `OpenCircuit.inspiredAt(env.pressureAtDepth(depth)).pO2`)
- `endExceeded`: `GasMix.end(depth, o2Narcotic: config.o2Narcotic) > config.endLimitMeters` at a segment's max depth (warning)
- `gasDensityCritical`/`gasDensityHigh` vs the new constants at each segment's max depth on its gas
- `cnsCritical` (>= 100) / `cnsWarning` (>= config threshold); `otuHigh` (> config.otuLimit, warning) — CNS/OTU via `O2ToxicityCalculator` per segment average ppO2 exactly as `PlanCalculatorService` does today, plus deco stops at stop ppO2
- `gasOut` (remaining <= 0, critical) / `gasReserveViolation` (remaining < plan.reservePressure, alert)
- `ndlExceededNoDecoGas` (alert): deco obligation exists AND no tank with role `deco`/`stage` and fO2 > back-gas fO2

- [ ] **Step 4: Write failing tests then implement** (`plan_engine_issues_test.dart`):
- air 66 m plan → `ppO2Critical`; Tx10/70 at 3 m start → `hypoxicGas`
- air 45 m → `endExceeded` (END > 30) and `gasDensityHigh` or `Critical` (air at 45 m: compute classification with python3 from the extracted constants and assert the exact type)
- tiny tank → `gasOut`; barely-insufficient reserve → `gasReserveViolation`
- deco dive with only back gas → `ndlExceededNoDecoGas`; add EAN50 deco tank → issue gone
- issues list sorted by severity descending
- consumption: python3-computed liters for one segment (15 L/min × 20 min × 4.0 bar = 1200 L) matches `PlanTankUsage.litersUsed` for a single-segment plan (no stops case: 30 m/20 min NDL dive... use a short bottom time that yields no deco, e.g. 30 m/10 min, and assert descent+bottom+direct-ascent liters within 1 L of hand-computed)

Run → PASS after implementation.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/deco/gas_density.dart lib/features/dive_log/data/services/profile_analysis_service.dart lib/features/planner/ test/core/deco/gas_density_test.dart test/features/planner/plan_engine_issues_test.dart
git commit -m "feat(planner): PlanEngine consumption and severity-sorted plan issues"
```

---

### Task 7: Wire save/load into the existing planner

**Files:**
- Create: `lib/features/planner/domain/services/dive_plan_state_mapper.dart`
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (`DivePlanNotifier.markSaved` → real save; add `loadPlanById`)
- Modify: `lib/features/dive_planner/presentation/pages/dive_planner_page.dart` (honor `planId`; remove the save TODO)
- Test: `test/features/planner/dive_plan_state_mapper_test.dart`, `test/features/dive_planner/save_load_round_trip_test.dart`

**Interfaces:**
- Produces:

```dart
// dive_plan_state_mapper.dart
// `existing` preserves fields the legacy state doesn't carry (mode, rates,
// contingency/CCR config) across an edit-save cycle; null = defaults.
domain.DivePlan divePlanFromState(DivePlanState state, {domain.DivePlan? existing});
DivePlanState stateFromDivePlan(domain.DivePlan plan);   // isDirty: false
```

Mapping notes: `state.gfLow/gfHigh/sacRate/reservePressure/altitude/siteId/notes/name/segments/tanks/surfaceInterval/createdAt/updatedAt` map 1:1 (`sacRate` ↔ `sacBottom`); everything new (mode, rates, lastStop, airBreaks, deviation, setpoints, waterType, sourceDiveId, linkedDiveId) takes the DivePlan constructor defaults / null and round-trips untouched when loading a plan saved by a future phase.

- [ ] **Step 1: Mapper + failing round-trip test** — state → plan → state equals the original (modulo `isDirty`); plan with non-default Phase-4/5 fields → state → plan preserves them (mapper must carry the original plan through: `stateFromDivePlan` keeps a reference? NO — keep it simple and lossy-safe: `divePlanFromState` accepts an optional `existing` plan whose non-state fields are preserved: `domain.DivePlan divePlanFromState(DivePlanState state, {domain.DivePlan? existing})`). Test both paths.

- [ ] **Step 2: Notifier wiring.**
- `DivePlanNotifier` gains a `DivePlanRepository` (constructor-injected via its provider) and a `domain.DivePlan? _loaded` field (the `existing` for the mapper).
- `markSaved()` becomes `Future<void> save({PlanSummaryData? summary})`: builds `divePlanFromState(state, existing: _loaded)`, calls `repository.savePlan(plan, summary: summary)`, stores `_loaded = plan`, sets `isDirty: false`. Keep `markSaved()` as a deprecated alias calling `save()` so existing call sites compile.
- New `Future<bool> loadPlanById(String id)`: `repository.getPlan(id)` → if found `_loaded = plan; state = stateFromDivePlan(plan); return true`.
- `dive_planner_page.dart`: where the save action shows the TODO snackbar (~line 205), call `await notifier.save(summary: PlanSummaryData(maxDepth: result.maxDepth, runtimeSeconds: result.totalRuntime, ttsSeconds: result.ttsAtBottom))` using the current `planResultsProvider` value, then a success snackbar. In `initState`, if `widget.planId != null`, schedule `Future.microtask(() => notifier.loadPlanById(widget.planId!))` (Riverpod 3 forbids provider mutation during build/dispose — microtask pattern per project memory).

- [ ] **Step 3: Round-trip test** (`save_load_round_trip_test.dart`, ProviderContainer-level, FK-ON test DB): build a plan in the notifier (addSimplePlan + rename), `await save()`, `newPlan()`, `await loadPlanById(id)` → state segments/tanks/name/gf match the saved ones; `getAllPlanSummaries()` shows the plan with the summary numbers.

- [ ] **Step 4: Run + commit**

```bash
flutter test test/features/planner/dive_plan_state_mapper_test.dart test/features/dive_planner/save_load_round_trip_test.dart test/features/dive_planner/presentation/providers/dive_planner_providers_test.dart
dart format .
git add lib/features/planner/ lib/features/dive_planner/ test/features/planner/ test/features/dive_planner/
git commit -m "feat(planner): persist plans - save and load wired into the planner"
```

---

### Task 8: Full verification sweep

- [ ] Run, in order (specific files/dirs per the timeout convention):
```bash
flutter test test/core/database/migration_v100_dive_plans_test.dart
flutter test test/core/services/sync/   # full sync suite — the structural net
flutter test test/features/planner/ test/features/dive_planner/
flutter test test/core/deco/
flutter analyze
dart format .
```
Expected: all green, analyze clean, format no changes. If the full sync directory is too slow for one Bash call, split it alphabetically into 2-3 runs.

- [ ] Commit anything outstanding, then done. Phase 2 exit criteria: plans persist and sync; PlanEngine produces schedule + consumption + issues from a `domain.DivePlan`; old planner UX unchanged except working save/load.

## Explicitly out of scope (later phases)

- New planner UI, saved-plans list page, cutover (Phase 3)
- CCR PlanEngine paths, bailout (Phase 4) — setpoint columns persisted only
- Contingency computation: deviations, lost gas, turn pressure (Phase 5) — config columns persisted only
- Tissue seeding from logged dives / SAC auto-fill / plan-vs-actual / convert-to-dive (Phase 6) — `sourceDiveId`/`linkedDiveId` columns persisted only
