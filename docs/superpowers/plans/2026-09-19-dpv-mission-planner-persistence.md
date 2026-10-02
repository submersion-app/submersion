# DPV Mission Planner, PR 2 (persistence and sync) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist a plan's DPV mission (the `DivePlan.mission` added in PR 1) in three synced tables, carry it through the planner's editing state and the `.subplan` file format, and delete, duplicate and sync it with its plan.

**Architecture:** Three Drift tables keyed to `dive_plans.plan_id` like `dive_plan_segments`, added by a table-only schema rung v241 with an idempotent create that also runs as a startup backstop. Row mapping and the write/read/delete logic live in two new files under `lib/features/planner/data/repositories/`, so the already 805-line `DivePlanRepository` only gains thin calls. Sync follows the plan-segment model exactly: each row carries its own hlc, is exported by it, and merges last-writer-wins.

**Tech Stack:** Flutter, Dart 3, Drift, `flutter_test`, the in-repo sync serializer and service.

**Spec:** `docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md` (issue #2086), "Persistence" section. PR 1 (#2138) supplies the entities. This plan amends the spec in Task 7 (see "Deviations from the spec").

## Global Constraints

- No em-dashes (U+2014), en-dashes as punctuation, or double hyphens as punctuation anywhere: code, comments, tests, commit messages. Rewrite the sentence.
- No tool or model attribution in any file, commit message or PR text, and no co-author trailers.
- No emojis in code, comments or docs.
- Immutability: build new lists, never mutate entity lists.
- Never declare a table, a migration helper or a rung in `database.dart`; `test/core/database/database_table_libraries_test.dart` fails on it (see Task 1).
- A new file stays under 400 lines. `dive_plan_repository.dart` (805 lines) gains at most 60.
- Imports grouped dart, flutter, packages, local; absolute `package:submersion/...` imports.
- `dart format .` before every commit; `flutter analyze` on the whole project before the final commit (infos fail CI).
- Run tests one file or a small list at a time; never overlap two local test runs.
- Commit messages: conventional prefix, body line `Refs #2086`.
- The PR body says `Refs #2086` (PR 3 of 3 closes it).

## Deviations from the spec (decided with the user, 2026-09-19)

- Legs and members reference `plan_id` (to `dive_plans`), not `mission_id`. Every existing seam (diver deletion, repository delete-and-reinsert, sync parent references, the index list) models children one level under their plan.
- The mission row's `id` is its plan's id. `plan_id` is still a column with a UNIQUE key and the foreign key, so a plan can never carry two missions.
- `buddy_id`, `diver_id` and `scooter_equipment_id` are plain text, not foreign keys. A foreign key with no delete action would block deleting the buddy, diver or equipment item, and the spec already says a missing scooter falls back to its snapshot.
- Schema version v241: main is at v240 with the sync floor at 240 (2026-09-27), and no open PR claims a higher rung. No test requires a contiguous ladder. Re-check `origin/main` before opening the PR (Task 7).
- Split database layout (#2506, after the spec was written): the tables go in a new library `lib/core/database/tables/dive_plan_mission_tables.dart`, the idempotent create in `migrations/helpers/dive_plan_migrations.dart`, the rung in `migrations/ladder/rungs_v231_onward.dart` and the backstop in `migrations/before_open.dart`. `database.dart` only lists them. Task 7 updates the spec sentence that still names `database.dart`.
- Revision 2026-09-25 (spec section of that name): the mission row gains `environment`, `walk_speed_mps` and `surface_swim_limit_m`; each leg gains `shore_swim_m` and `shore_walk_m`. PR #2138 carries the matching domain fields (`DpvMission.environment`, `walkSpeedMps`, `surfaceSwimLimitM`, `MissionLeg.shoreExit`).

## File Structure

| File | Status | Responsibility |
| --- | --- | --- |
| `lib/core/database/tables/dive_plan_mission_tables.dart` | create | the three table classes |
| `lib/core/database/database.dart` | modify | import and export the library, table list, version constant, ladder entry |
| `lib/core/database/migrations/helpers/dive_plan_migrations.dart` | modify | `_assertDivePlanMissionSchema` |
| `lib/core/database/migrations/ladder/rungs_v231_onward.dart` | modify | the v241 rung |
| `lib/core/database/migrations/before_open.dart` | modify | the v241 backstop |
| `lib/core/database/performance_indexes.dart` | modify | two plan-id indexes |
| `lib/core/data/repositories/sync_repository.dart` | modify | three `hlcTargets` entries |
| `lib/features/divers/data/repositories/diver_owned_rows.dart` | modify | three children of `dive_plans` |
| `lib/features/planner/data/repositories/dive_plan_mission_rows.dart` | create | entity to companion and row to entity mapping |
| `lib/features/planner/data/repositories/dive_plan_mission_store.dart` | create | write, read, delete, re-mint ids, sync bookkeeping |
| `lib/features/planner/data/repositories/dive_plan_repository.dart` | modify | call the store from save, load, delete, duplicate, watch |
| `lib/core/services/sync/sync_data_serializer.dart` | modify | 14 registration sites |
| `lib/core/services/sync/sync_service.dart` | modify | apply order, updated-at map, parent refs |
| `lib/features/dive_planner/domain/entities/plan_result.dart` | modify | `DivePlanState.mission` |
| `lib/features/planner/domain/services/dive_plan_state_mapper.dart` | modify | mission both ways |
| `lib/features/planner/data/services/plan_file_mission_codec.dart` | create | mission to and from the file map |
| `lib/features/planner/data/services/plan_file_codec.dart` | modify | version 3, optional `mission` block |
| `docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md` | modify | record the deviations |

---

### Task 1: Schema v241 and the guards it trips

The database code is split (#2506): tables live in libraries under `lib/core/database/tables/`, migration helpers in `part` files under `lib/core/database/migrations/` as `extension` members on `AppDatabase`. `test/core/database/database_table_libraries_test.dart` fails if `database.dart` gains any top-level declaration or any `AppDatabase` member beyond its allow-list, and if a file under `tables/` or `migrations/` passes 800 lines. So `database.dart` gets only an import, an export, three table-list entries, the version constant and a ladder entry. Anchor every edit on the quoted text, not on line numbers: main moves.

**Files:**
- Create: `lib/core/database/tables/dive_plan_mission_tables.dart`
- Modify: `lib/core/database/database.dart` (import and export next to `dive_plan_tables.dart`; the `@DriftDatabase` table list after `DivePlanSegments,`; `currentSchemaVersion`; `migrationVersions` after `240,`)
- Modify: `lib/core/database/migrations/helpers/dive_plan_migrations.dart` (`_assertDivePlanMissionSchema` at the end of `extension DivePlanMigrations`)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (the rung after `if (from < 240) await reportProgress();`)
- Modify: `lib/core/database/migrations/before_open.dart` (the backstop after the v100 block that ends `await Migrator(this).createTable(divePlanSegments);`)
- Modify: `lib/core/database/performance_indexes.dart` (after `idx_dive_plan_segments_plan_id`)
- Modify: `lib/core/data/repositories/sync_repository.dart` (after `'divePlanSegments'` in `hlcTargets`)
- Modify: `lib/features/divers/data/repositories/diver_owned_rows.dart` (children of `dive_plans`)
- Modify: `test/core/database/migration_v240_profile_events_dive_index_test.dart` (relax the tripwire)
- Modify: `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart` (seeder rows and `clearedReferences`)
- Create: `test/core/database/migration_v241_dive_plan_missions_test.dart`

**Interfaces:**
- Produces: Drift tables `DivePlanMissions`, `DivePlanMissionLegs`, `DivePlanMissionMembers`; data classes `DivePlanMission`, `DivePlanMissionLeg`, `DivePlanMissionMember`; companions `DivePlanMissionsCompanion`, `DivePlanMissionLegsCompanion`, `DivePlanMissionMembersCompanion`; accessors `db.divePlanMissions`, `db.divePlanMissionLegs`, `db.divePlanMissionMembers`; sync entity types `divePlanMissions`, `divePlanMissionLegs`, `divePlanMissionMembers`. Every importer of `package:submersion/core/database/database.dart` sees the tables through its export.

- [ ] **Step 1: Write the failing migration test**

The fixture follows `migration_v238_saved_queries_test.dart`: the other beforeOpen backstops return early when their parent table is missing, so the fixture holds only `dive_plans`. If a backstop throws on it anyway, add only the table or column that backstop names.

```dart
// test/core/database/migration_v241_dive_plan_missions_test.dart
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v241 adds the DPV mission tables (issue #2086): dive_plan_missions,
/// dive_plan_mission_legs and dive_plan_mission_members, children of
/// dive_plans. Table-only rung, additive, floor stays at 240.

const _tables = [
  'dive_plan_missions',
  'dive_plan_mission_legs',
  'dive_plan_mission_members',
];

/// A database at [userVersion] holding only dive_plans, or nothing.
NativeDatabase _fixture({required int userVersion, bool withPlans = true}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      if (withPlans) {
        rawDb.execute('CREATE TABLE dive_plans (id TEXT NOT NULL PRIMARY KEY)');
      }
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<List<Map<String, Object?>>> _tableInfo(
  AppDatabase db,
  String table,
) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return [
    for (final r in rows)
      {
        'name': r.data['name'],
        'type': r.data['type'],
        'notnull': r.data['notnull'],
        'dflt_value': r.data['dflt_value'],
        'pk': r.data['pk'],
      },
  ];
}

Future<String?> _ddl(AppDatabase db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(table)],
      )
      .get();
  return rows.isEmpty ? null : rows.single.read<String?>('sql');
}

void main() {
  test('v241 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 241);
    expect(AppDatabase.migrationVersions, contains(241));
    expect(AppDatabase.migrationStepCount(240), 1);
    // Table-only rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a database from a v240 build gains the three tables', () async {
    final db = AppDatabase(_fixture(userVersion: 240));
    addTearDown(db.close);

    expect(
      await _columns(db, 'dive_plan_missions'),
      containsAll(<String>[
        'id',
        'plan_id',
        'battery_reserve_fraction',
        'default_current_speed_mps',
        'default_current_sets_toward_deg',
        'environment',
        'walk_speed_mps',
        'surface_swim_limit_m',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(
      await _columns(db, 'dive_plan_mission_legs'),
      containsAll(<String>[
        'id',
        'plan_id',
        'sort_order',
        'label',
        'distance_m',
        'depth_m',
        'heading_deg',
        'current_speed_mps',
        'current_sets_toward_deg',
        'shore_swim_m',
        'shore_walk_m',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(
      await _columns(db, 'dive_plan_mission_members'),
      containsAll(<String>[
        'id',
        'plan_id',
        'sort_order',
        'display_name',
        'buddy_id',
        'diver_id',
        'sac_bottom',
        'swim_speed_mps',
        'scooter_equipment_id',
        'scooter_name',
        'scooter_speed_mps',
        'scooter_burn_seconds',
        'tow_speed_factor',
        'tow_burn_factor',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('every table references its plan, and a plan has one mission', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    for (final table in _tables) {
      expect(
        await _ddl(db, table),
        contains('REFERENCES dive_plans (id)'),
        reason: table,
      );
    }
    expect(await _ddl(db, 'dive_plan_missions'), contains('UNIQUE(plan_id)'));
    // Soft links: a foreign key with no delete action would block deleting
    // the buddy, the diver or the equipment item.
    final members = await _ddl(db, 'dive_plan_mission_members');
    expect(members, isNot(contains('REFERENCES buddies')));
    expect(members, isNot(contains('REFERENCES divers')));
    expect(members, isNot(contains('REFERENCES equipment')));
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(_fixture(userVersion: 240));
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    for (final table in _tables) {
      expect(
        await _tableInfo(upgraded, table),
        await _tableInfo(fresh, table),
        reason: table,
      );
      expect(await _ddl(upgraded, table), await _ddl(fresh, table));
    }
  });

  test('a database already at v241 without the tables gains them', () async {
    // A database that arrives by restore or sync-adopt, or one a parallel
    // branch stamped with this version, never runs the rung; only the
    // beforeOpen backstop can add the tables there.
    final db = AppDatabase(
      _fixture(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);

    for (final table in _tables) {
      expect(await _columns(db, table), contains('plan_id'), reason: table);
    }
  });

  test(
    'a database opened without dive_plans gains it and the mission tables',
    () async {
      // The v100 backstop re-creates dive_plans on every open (the
      // version-collision and restore cases). The mission tables must be
      // there too, whatever order the backstops run in, or every plan save
      // fails until the next launch.
      final db = AppDatabase(
        _fixture(
          userVersion: AppDatabase.currentSchemaVersion,
          withPlans: false,
        ),
      );
      addTearDown(db.close);

      expect(await _columns(db, 'dive_plans'), contains('id'));
      for (final table in _tables) {
        expect(await _columns(db, table), contains('plan_id'), reason: table);
      }
    },
  );
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v241_dive_plan_missions_test.dart`
Expected: FAIL, `currentSchemaVersion` is 240 and the tables are absent.

- [ ] **Step 3: Add the table library**

Create `lib/core/database/tables/dive_plan_mission_tables.dart`. The header matches `query_tables.dart`: the file-level coverage ignore replaces the per-class `coverage:ignore-start` markers older table files carry.

```dart
/// The DPV mission layered on a saved dive plan.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/dive_plan_tables.dart';

/// A DPV mission layered on a saved dive plan (v241, issue #2086). At most
/// one row per plan, and no row means the plan has no mission. The row's id
/// is its plan's id; `plan_id` still carries the foreign key and the unique
/// key so a plan can never carry two.
class DivePlanMissions extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();

  /// Fraction of scooter burn time that must remain at the surface.
  RealColumn get batteryReserveFraction => real()();

  /// Current inherited by legs without their own; both null for none.
  RealColumn get defaultCurrentSpeedMps => real().nullable()();
  RealColumn get defaultCurrentSetsTowardDeg => real().nullable()();

  /// MissionEnvironment.name: overhead or openWater.
  TextColumn get environment =>
      text().withDefault(const Constant('overhead'))();

  /// Walking speed for a shore exit, m/s.
  RealColumn get walkSpeedMps => real().withDefault(const Constant(0.8))();

  /// Longest acceptable surface swim, metres; null for no limit.
  RealColumn get surfaceSwimLimitM => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {planId},
  ];
}

/// One outbound leg of a plan's DPV mission route (v241, issue #2086),
/// keyed to its plan like `dive_plan_segments`. The return is derived.
class DivePlanMissionLegs extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// The waypoint the leg ends at, for example "T" or "Jump 2".
  TextColumn get label => text()();
  RealColumn get distanceM => real()();
  RealColumn get depthM => real()();
  RealColumn get headingDeg => real()();

  /// This leg's current; both null inherits the mission default.
  RealColumn get currentSpeedMps => real().nullable()();
  RealColumn get currentSetsTowardDeg => real().nullable()();

  /// Open water shore exit from this leg's waypoint; both null for none.
  RealColumn get shoreSwimM => real().nullable()();
  RealColumn get shoreWalkM => real().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One diver on a plan's DPV mission (v241, issue #2086), with a snapshot
/// of their scooter. `buddy_id`, `diver_id` and `scooter_equipment_id` are
/// soft links with no foreign key: a key with no delete action would block
/// deleting the buddy, diver or item, and a missing scooter falls back to
/// the snapshot columns.
class DivePlanMissionMembers extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text().references(DivePlans, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get displayName => text()();
  TextColumn get buddyId => text().nullable()();
  TextColumn get diverId => text().nullable()();

  /// Bottom surface air consumption, litres per minute.
  RealColumn get sacBottom => real()();
  RealColumn get swimSpeedMps => real()();
  TextColumn get scooterEquipmentId => text().nullable()();
  TextColumn get scooterName => text()();
  RealColumn get scooterSpeedMps => real()();
  IntColumn get scooterBurnSeconds => integer()();
  RealColumn get towSpeedFactor => real()();
  RealColumn get towBurnFactor => real()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 4: Wire it into database.dart**

After `import 'package:submersion/core/database/tables/dive_plan_tables.dart';` add:

```dart
import 'package:submersion/core/database/tables/dive_plan_mission_tables.dart';
```

and after `export 'package:submersion/core/database/tables/dive_plan_tables.dart';` add:

```dart
export 'package:submersion/core/database/tables/dive_plan_mission_tables.dart';
```

(`dart format` keeps directives in the order written; if the analyzer's `directives_ordering` lint asks for another position, follow it.)

In the `@DriftDatabase(tables: [...])` list, directly after `DivePlanSegments,` (before `// CSV import presets (local-only)`):

```dart
    // DPV mission planner (v241, issue #2086)
    DivePlanMissions,
    DivePlanMissionLegs,
    DivePlanMissionMembers,
```

Change `static const int currentSchemaVersion = 240;` to `241`. Leave `minimumCompatibleSchemaVersion` at 240.

In `migrationVersions`, directly after the `240,` entry:

```dart
    // v241: DPV mission planner (issue #2086). dive_plan_missions,
    // dive_plan_mission_legs and dive_plan_mission_members, children of
    // dive_plans. Table-only rung, no backfill; an older reader keeps the
    // new entity types as inert unknowns, so the floor stays at 240.
    241,
```

- [ ] **Step 5: Add the helper, the rung and the backstop**

At the end of `extension DivePlanMigrations on AppDatabase` in `migrations/helpers/dive_plan_migrations.dart` (before its closing `}`):

```dart

  /// Idempotent creation of the v241 DPV mission tables (issue #2086).
  /// Called from the v241 rung and the beforeOpen backstop.
  ///
  /// Not guarded on dive_plans: SQLite accepts a REFERENCES clause to a
  /// table that does not exist yet, so the create does not depend on where
  /// it runs relative to the v100 backstop that re-creates dive_plans.
  Future<void> _assertDivePlanMissionSchema() async {
    final migrator = Migrator(this);
    await migrator.createTable(divePlanMissions);
    await migrator.createTable(divePlanMissionLegs);
    await migrator.createTable(divePlanMissionMembers);
  }
```

(`createTable` emits `CREATE TABLE IF NOT EXISTS`, which is what makes the helper safe to run on every open. It deliberately has no `_tableExists('dive_plans')` guard: a guard made the backstop's result depend on running after the v100 block, and a database opened without `dive_plans` came up with no mission tables.)

In `migrations/ladder/rungs_v231_onward.dart`, directly after `if (from < 240) await reportProgress();`:

```dart
    // v241: DPV mission planner (issue #2086). Table-only rung, no
    // backfill: a plan without a mission row has no mission. Re-asserted
    // in beforeOpen.
    if (from < 241) {
      await _assertDivePlanMissionSchema();
    }
    if (from < 241) await reportProgress();
```

In `migrations/before_open.dart`, directly after the v100 block that ends `await Migrator(this).createTable(divePlanSegments);`, next to the other plan tables (the helper is order-independent, so this placement is for readability):

```dart

    // v241 backstop: re-assert the DPV mission tables. A database that
    // arrives by restore or sync-adopt never runs onUpgrade.
    await _assertDivePlanMissionSchema();
```

In `performance_indexes.dart`, after the `idx_dive_plan_segments_plan_id` entry:

```dart
  (
    name: 'idx_dive_plan_mission_legs_plan_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_plan_mission_legs_plan_id '
        'ON dive_plan_mission_legs(plan_id)',
  ),
  (
    name: 'idx_dive_plan_mission_members_plan_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_plan_mission_members_plan_id '
        'ON dive_plan_mission_members(plan_id)',
  ),
```

(`dive_plan_missions.plan_id` needs no entry: its UNIQUE key is an index.)

- [ ] **Step 6: Regenerate and run the migration test**

This worktree has not run codegen since it was created from main, so the first build is cold (about 4 minutes after #2506).

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/migration_v241_dive_plan_missions_test.dart
```

Expected: PASS, 6 tests.

- [ ] **Step 7: Relax the v240 tripwire**

The newest rung's test owns the exact version assertion. Confirm it is still v240's (`grep -rln "currentSchemaVersion, 240)" test`); if main has moved on, relax whichever test that grep names instead. In `test/core/database/migration_v240_profile_events_dive_index_test.dart`, replace the first test with:

```dart
  test('v240 is at or below the current schema version and in the ladder', () {
    // Relaxed once v241 (DPV mission planner) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(240));
    expect(AppDatabase.migrationVersions, contains(240));
    expect(AppDatabase.migrationStepCount(239), greaterThanOrEqualTo(1));
  });
```

Its floor test (`minimumCompatibleSchemaVersion, 240`) stays as it is: this rung does not move the floor.

- [ ] **Step 8: Register the clocks and the diver ownership**

In `sync_repository.dart`, `hlcTargets`, after `'divePlanSegments': ...,`:

```dart
    'divePlanMissions': (table: 'dive_plan_missions', pk: 'id'),
    'divePlanMissionLegs': (table: 'dive_plan_mission_legs', pk: 'id'),
    'divePlanMissionMembers': (table: 'dive_plan_mission_members', pk: 'id'),
```

In `diver_owned_rows.dart`, replace the `dive_plans` entry's `children` list with (mission rows first; they reference only the plan):

```dart
    children: [
      (
        table: 'dive_plan_mission_legs',
        entityType: 'divePlanMissionLegs',
        parentColumn: 'plan_id',
      ),
      (
        table: 'dive_plan_mission_members',
        entityType: 'divePlanMissionMembers',
        parentColumn: 'plan_id',
      ),
      (
        table: 'dive_plan_missions',
        entityType: 'divePlanMissions',
        parentColumn: 'plan_id',
      ),
      (
        table: 'dive_plan_segments',
        entityType: 'divePlanSegments',
        parentColumn: 'plan_id',
      ),
      (
        table: 'dive_plan_tanks',
        entityType: 'divePlanTanks',
        parentColumn: 'plan_id',
      ),
    ],
```

and extend the comment above the entry: `// Mission rows, then segments before tanks: ...` keeping the rest of the sentence.

In `diver_delete_owned_tables_test.dart`:

1. In `clearedReferences`, after `'checklist_template_items.template_id',` add (the set is alphabetical):

```dart
      'dive_plan_mission_legs.plan_id',
      'dive_plan_mission_members.plan_id',
      'dive_plan_missions.plan_id',
```

2. In the seeder that inserts `plan-a` (it returns the `('dive_plans', 'divePlans', 'plan-a')` triple), insert a mission, a leg and a member before the `return`, and add them to the returned list:

```dart
      await db
          .into(db.divePlanMissions)
          .insert(
            DivePlanMissionsCompanion.insert(
              id: 'plan-a',
              planId: 'plan-a',
              batteryReserveFraction: 1 / 3,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.divePlanMissionLegs)
          .insert(
            DivePlanMissionLegsCompanion.insert(
              id: 'pleg-a',
              planId: 'plan-a',
              label: 'T',
              distanceM: 300,
              depthM: 20,
              headingDeg: 90,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.divePlanMissionMembers)
          .insert(
            DivePlanMissionMembersCompanion.insert(
              id: 'pmember-a',
              planId: 'plan-a',
              displayName: 'Sam',
              sacBottom: 15,
              swimSpeedMps: 0.2,
              scooterName: 'Blacktip',
              scooterSpeedMps: 0.9,
              scooterBurnSeconds: 5400,
              towSpeedFactor: 0.6,
              towBurnFactor: 1.5,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
```

```dart
      return [
        ('dive_plans', 'divePlans', 'plan-a'),
        ('dive_plan_tanks', 'divePlanTanks', 'ptank-a'),
        ('dive_plan_segments', 'divePlanSegments', 'pseg-a'),
        ('dive_plan_missions', 'divePlanMissions', 'plan-a'),
        ('dive_plan_mission_legs', 'divePlanMissionLegs', 'pleg-a'),
        ('dive_plan_mission_members', 'divePlanMissionMembers', 'pmember-a'),
      ];
```

- [ ] **Step 9: Run the guards**

```bash
flutter test test/core/database/migration_v241_dive_plan_missions_test.dart test/core/database/migration_v240_profile_events_dive_index_test.dart test/core/database/database_table_libraries_test.dart test/core/database/performance_indexes_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart test/features/divers/data/repositories/diver_delete_owned_tables_test.dart
flutter test test/architecture/
```

Expected: PASS. If a guard in `test/core/services/sync/child_hlc_test.dart` enumerates tables with an `hlc` column, run it too and add the three entity types wherever it lists `divePlanSegments`. If `test/core/database/` holds a test that lists every table library or every `@DriftDatabase` entry, run it and add the new library there.

- [ ] **Step 10: Format and commit**

```bash
dart format lib/core test/core test/features/divers
git add lib/core/database/tables/dive_plan_mission_tables.dart lib/core/database/database.dart lib/core/database/migrations/helpers/dive_plan_migrations.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/database/migrations/before_open.dart lib/core/database/performance_indexes.dart lib/core/data/repositories/sync_repository.dart lib/features/divers/data/repositories/diver_owned_rows.dart test/core/database/migration_v241_dive_plan_missions_test.dart test/core/database/migration_v240_profile_events_dive_index_test.dart test/features/divers/data/repositories/diver_delete_owned_tables_test.dart
git commit -m "feat(planner): add the v241 DPV mission tables

Refs #2086"
```

Generated files (`*.g.dart`) are not tracked; do not stage them.

---

### Task 2: Mission row mapping

**Files:**
- Create: `lib/features/planner/data/repositories/dive_plan_mission_rows.dart`
- Test: `test/features/planner/mission/dive_plan_mission_rows_test.dart`

**Interfaces:**
- Consumes: Task 1 data classes and companions; PR 1 entities.
- Produces:

```dart
abstract final class DivePlanMissionRows {
  static db.DivePlanMissionsCompanion mission(String planId, DpvMission mission, int now, {int? createdAt});
  static db.DivePlanMissionLegsCompanion leg(String planId, MissionLeg leg, int sortOrder, int now, {int? createdAt});
  static db.DivePlanMissionMembersCompanion member(String planId, MissionMember member, int sortOrder, int now, {int? createdAt});
  static DpvMission toMission(db.DivePlanMission row, List<db.DivePlanMissionLeg> legs, List<db.DivePlanMissionMember> members);
}
```

`toMission` sorts legs and members by `sortOrder` and sets each entity's `order` to its position.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/dive_plan_mission_rows_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/planner/data/repositories/dive_plan_mission_rows.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

const _member = MissionMember(
  id: 'm1',
  order: 0,
  displayName: 'Sam',
  buddyId: 'buddy-1',
  sacBottom: 16,
  swimSpeedMps: 0.25,
  scooter: ScooterSpec(
    equipmentId: 'eq-1',
    name: 'Blacktip',
    ratedSpeedMps: 0.9,
    burnTimeSeconds: 5400,
    towSpeedFactor: 0.55,
    towBurnFactor: 1.7,
  ),
);

const _leg = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
  current: CurrentVector(speedMps: 0.2, setsTowardDeg: 45),
);

void main() {
  test('the mission companion uses the plan id as its id', () {
    const mission = DpvMission(
      batteryReserveFraction: 0.4,
      defaultCurrent: CurrentVector(speedMps: 0.1, setsTowardDeg: 180),
    );
    final c = DivePlanMissionRows.mission('plan-1', mission, 1000);
    expect(c.id.value, 'plan-1');
    expect(c.planId.value, 'plan-1');
    expect(c.batteryReserveFraction.value, 0.4);
    expect(c.defaultCurrentSpeedMps.value, 0.1);
    expect(c.defaultCurrentSetsTowardDeg.value, 180);
    expect(c.createdAt.value, 1000);
    expect(c.updatedAt.value, 1000);
  });

  test('an existing createdAt survives, updatedAt moves', () {
    final c = DivePlanMissionRows.leg('plan-1', _leg, 2, 5000, createdAt: 10);
    expect(c.createdAt.value, 10);
    expect(c.updatedAt.value, 5000);
    expect(c.sortOrder.value, 2);
  });

  test('rows round-trip back to the same mission', () {
    const mission = DpvMission(
      legs: [_leg],
      team: [_member],
      batteryReserveFraction: 0.25,
    );
    final missionRow = db.DivePlanMission(
      id: 'plan-1',
      planId: 'plan-1',
      batteryReserveFraction: 0.25,
      environment: 'overhead',
      walkSpeedMps: 0.8,
      createdAt: 1,
      updatedAt: 1,
    );
    final legRow = db.DivePlanMissionLeg(
      id: 'L1',
      planId: 'plan-1',
      sortOrder: 0,
      label: 'T',
      distanceM: 300,
      depthM: 20,
      headingDeg: 90,
      currentSpeedMps: 0.2,
      currentSetsTowardDeg: 45,
      createdAt: 1,
      updatedAt: 1,
    );
    final memberRow = db.DivePlanMissionMember(
      id: 'm1',
      planId: 'plan-1',
      sortOrder: 0,
      displayName: 'Sam',
      buddyId: 'buddy-1',
      sacBottom: 16,
      swimSpeedMps: 0.25,
      scooterEquipmentId: 'eq-1',
      scooterName: 'Blacktip',
      scooterSpeedMps: 0.9,
      scooterBurnSeconds: 5400,
      towSpeedFactor: 0.55,
      towBurnFactor: 1.7,
      createdAt: 1,
      updatedAt: 1,
    );
    expect(
      DivePlanMissionRows.toMission(missionRow, [legRow], [memberRow]),
      mission,
    );
  });

  test('legs and members come back in sort order with order renumbered', () {
    db.DivePlanMissionLeg leg(String id, int sort) => db.DivePlanMissionLeg(
      id: id,
      planId: 'p',
      sortOrder: sort,
      label: id,
      distanceM: 100,
      depthM: 10,
      headingDeg: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final mission = DivePlanMissionRows.toMission(
      db.DivePlanMission(
        id: 'p',
        planId: 'p',
        batteryReserveFraction: 1 / 3,
        environment: 'overhead',
        walkSpeedMps: 0.8,
        createdAt: 1,
        updatedAt: 1,
      ),
      [leg('b', 7), leg('a', 3)],
      const [],
    );
    expect(mission.legs.map((l) => l.id), ['a', 'b']);
    expect(mission.legs.map((l) => l.order), [0, 1]);
    expect(mission.defaultCurrent, isNull);
  });

  test('the open-water fields round-trip through the rows', () {
    const mission = DpvMission(
      environment: MissionEnvironment.openWater,
      walkSpeedMps: 1.1,
      surfaceSwimLimitM: 250,
    );
    final c = DivePlanMissionRows.mission('p', mission, 1);
    expect(c.environment.value, 'openWater');
    expect(c.walkSpeedMps.value, 1.1);
    expect(c.surfaceSwimLimitM.value, 250);
    const leg = MissionLeg(
      id: 'L1',
      order: 0,
      label: 'T',
      distanceM: 100,
      depthM: 10,
      headingDeg: 0,
      shoreExit: ShoreExit(surfaceSwimM: 120, walkM: 400),
    );
    final l = DivePlanMissionRows.leg('p', leg, 0, 1);
    expect(l.shoreSwimM.value, 120);
    expect(l.shoreWalkM.value, 400);

    final restored = DivePlanMissionRows.toMission(
      db.DivePlanMission(
        id: 'p',
        planId: 'p',
        batteryReserveFraction: 1 / 3,
        environment: 'openWater',
        walkSpeedMps: 1.1,
        surfaceSwimLimitM: 250,
        createdAt: 1,
        updatedAt: 1,
      ),
      [
        db.DivePlanMissionLeg(
          id: 'L1',
          planId: 'p',
          sortOrder: 0,
          label: 'T',
          distanceM: 100,
          depthM: 10,
          headingDeg: 0,
          shoreSwimM: 120,
          shoreWalkM: 400,
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      const [],
    );
    expect(restored.environment, MissionEnvironment.openWater);
    expect(restored.walkSpeedMps, 1.1);
    expect(restored.surfaceSwimLimitM, 250);
    expect(
      restored.legs.single.shoreExit,
      const ShoreExit(surfaceSwimM: 120, walkM: 400),
    );
  });

  test('an unknown environment name reads as overhead', () {
    final mission = DivePlanMissionRows.toMission(
      db.DivePlanMission(
        id: 'p',
        planId: 'p',
        batteryReserveFraction: 1 / 3,
        environment: 'cave2030',
        walkSpeedMps: 0.8,
        createdAt: 1,
        updatedAt: 1,
      ),
      const [],
      const [],
    );
    expect(mission.environment, MissionEnvironment.overhead);
  });

  test('a half-written current is read as no current', () {
    final legRow = db.DivePlanMissionLeg(
      id: 'L1',
      planId: 'p',
      sortOrder: 0,
      label: 'T',
      distanceM: 100,
      depthM: 10,
      headingDeg: 0,
      currentSpeedMps: 0.3,
      createdAt: 1,
      updatedAt: 1,
    );
    final mission = DivePlanMissionRows.toMission(
      db.DivePlanMission(
        id: 'p',
        planId: 'p',
        batteryReserveFraction: 1 / 3,
        environment: 'overhead',
        walkSpeedMps: 0.8,
        createdAt: 1,
        updatedAt: 1,
      ),
      [legRow],
      const [],
    );
    expect(mission.legs.single.current, isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/dive_plan_mission_rows_test.dart`
Expected: FAIL, the import does not resolve.

- [ ] **Step 3: Write the mapping**

```dart
// lib/features/planner/data/repositories/dive_plan_mission_rows.dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

/// Row and entity mapping for a plan's DPV mission (v241, issue #2086).
///
/// The mission row's id is its plan's id. Legs and members store their list
/// position as `sort_order` and read it back as their `order`.
abstract final class DivePlanMissionRows {
  static db.DivePlanMissionsCompanion mission(
    String planId,
    DpvMission mission,
    int now, {
    int? createdAt,
  }) {
    return db.DivePlanMissionsCompanion(
      id: Value(planId),
      planId: Value(planId),
      batteryReserveFraction: Value(mission.batteryReserveFraction),
      defaultCurrentSpeedMps: Value(mission.defaultCurrent?.speedMps),
      defaultCurrentSetsTowardDeg: Value(mission.defaultCurrent?.setsTowardDeg),
      environment: Value(mission.environment.name),
      walkSpeedMps: Value(mission.walkSpeedMps),
      surfaceSwimLimitM: Value(mission.surfaceSwimLimitM),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  static db.DivePlanMissionLegsCompanion leg(
    String planId,
    MissionLeg leg,
    int sortOrder,
    int now, {
    int? createdAt,
  }) {
    return db.DivePlanMissionLegsCompanion(
      id: Value(leg.id),
      planId: Value(planId),
      sortOrder: Value(sortOrder),
      label: Value(leg.label),
      distanceM: Value(leg.distanceM),
      depthM: Value(leg.depthM),
      headingDeg: Value(leg.headingDeg),
      currentSpeedMps: Value(leg.current?.speedMps),
      currentSetsTowardDeg: Value(leg.current?.setsTowardDeg),
      shoreSwimM: Value(leg.shoreExit?.surfaceSwimM),
      shoreWalkM: Value(leg.shoreExit?.walkM),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  static db.DivePlanMissionMembersCompanion member(
    String planId,
    MissionMember member,
    int sortOrder,
    int now, {
    int? createdAt,
  }) {
    final scooter = member.scooter;
    return db.DivePlanMissionMembersCompanion(
      id: Value(member.id),
      planId: Value(planId),
      sortOrder: Value(sortOrder),
      displayName: Value(member.displayName),
      buddyId: Value(member.buddyId),
      diverId: Value(member.diverId),
      sacBottom: Value(member.sacBottom),
      swimSpeedMps: Value(member.swimSpeedMps),
      scooterEquipmentId: Value(scooter.equipmentId),
      scooterName: Value(scooter.name),
      scooterSpeedMps: Value(scooter.ratedSpeedMps),
      scooterBurnSeconds: Value(scooter.burnTimeSeconds),
      towSpeedFactor: Value(scooter.towSpeedFactor),
      towBurnFactor: Value(scooter.towBurnFactor),
      createdAt: Value(createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  static DpvMission toMission(
    db.DivePlanMission row,
    List<db.DivePlanMissionLeg> legRows,
    List<db.DivePlanMissionMember> memberRows,
  ) {
    final legs = [...legRows]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final members = [...memberRows]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return DpvMission(
      legs: [
        for (final (i, r) in legs.indexed)
          MissionLeg(
            id: r.id,
            order: i,
            label: r.label,
            distanceM: r.distanceM,
            depthM: r.depthM,
            headingDeg: r.headingDeg,
            current: _current(r.currentSpeedMps, r.currentSetsTowardDeg),
            shoreExit: _shore(r.shoreSwimM, r.shoreWalkM),
          ),
      ],
      team: [
        for (final (i, r) in members.indexed)
          MissionMember(
            id: r.id,
            order: i,
            displayName: r.displayName,
            buddyId: r.buddyId,
            diverId: r.diverId,
            sacBottom: r.sacBottom,
            swimSpeedMps: r.swimSpeedMps,
            scooter: ScooterSpec(
              equipmentId: r.scooterEquipmentId,
              name: r.scooterName,
              ratedSpeedMps: r.scooterSpeedMps,
              burnTimeSeconds: r.scooterBurnSeconds,
              towSpeedFactor: r.towSpeedFactor,
              towBurnFactor: r.towBurnFactor,
            ),
          ),
      ],
      batteryReserveFraction: row.batteryReserveFraction,
      defaultCurrent: _current(
        row.defaultCurrentSpeedMps,
        row.defaultCurrentSetsTowardDeg,
      ),
      // An unknown name (a newer peer's environment) reads as overhead, the
      // conservative choice: it never offers a surface exit that may not be.
      environment:
          MissionEnvironment.values.asNameMap()[row.environment] ??
          MissionEnvironment.overhead,
      walkSpeedMps: row.walkSpeedMps,
      surfaceSwimLimitM: row.surfaceSwimLimitM,
    );
  }

  /// A shore exit needs both halves; a row with one reads as none.
  static ShoreExit? _shore(double? swimM, double? walkM) {
    if (swimM == null || walkM == null) return null;
    return ShoreExit(surfaceSwimM: swimM, walkM: walkM);
  }

  /// A current needs both halves; a row with one of them (a partial sync or
  /// a hand-edited database) reads as no current rather than a guess.
  static CurrentVector? _current(double? speedMps, double? setsTowardDeg) {
    if (speedMps == null || setsTowardDeg == null) return null;
    return CurrentVector(speedMps: speedMps, setsTowardDeg: setsTowardDeg);
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/planner/mission/dive_plan_mission_rows_test.dart`
Expected: PASS, 5 tests. If a Drift data class constructor rejects a named argument, open `lib/core/database/database.g.dart`, find `class DivePlanMissionLeg extends DataClass`, and match its constructor.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/planner/data/repositories test/features/planner/mission
git add lib/features/planner/data/repositories/dive_plan_mission_rows.dart test/features/planner/mission/dive_plan_mission_rows_test.dart
git commit -m "feat(planner): map DPV missions to and from their rows

Refs #2086"
```

---

### Task 3: Mission store and repository wiring

**Files:**
- Create: `lib/features/planner/data/repositories/dive_plan_mission_store.dart`
- Modify: `lib/features/planner/data/repositories/dive_plan_repository.dart` (`watchPlanChanges`, `savePlan`, `getPlan`, `deletePlan`, `duplicatePlan`)
- Test: `test/features/planner/dive_plan_repository_mission_test.dart`

**Interfaces:**
- Consumes: `DivePlanMissionRows` (Task 2); `SyncRepository.markRecordPending({required String entityType, required String recordId, required int localUpdatedAt})` and `SyncRepository.logDeletion({required String entityType, required String recordId})` (existing).
- Produces:

```dart
class MissionRowIds {
  final bool mission;
  final List<String> legIds;
  final List<String> memberIds;
  static const none = MissionRowIds(mission: false, legIds: [], memberIds: []);
  bool get isEmpty;
}

class DivePlanMissionStore {
  const DivePlanMissionStore();
  /// Inside the caller's transaction. Returns (written, removed).
  Future<(MissionRowIds, MissionRowIds)> write(db.AppDatabase d, String planId, DpvMission? mission, int now);
  Future<DpvMission?> read(db.AppDatabase d, String planId);
  Future<MissionRowIds> idsFor(db.AppDatabase d, String planId);
  /// Inside the caller's transaction.
  Future<void> deleteAll(db.AppDatabase d, String planId);
  DpvMission remint(DpvMission mission, String Function() newId);
  Future<void> recordWrite(SyncRepository sync, String planId, MissionRowIds written, MissionRowIds removed, int now);
  Future<void> recordDeletion(SyncRepository sync, String planId, MissionRowIds removed);
}
```

- [ ] **Step 1: Write the failing repository test**

Open `test/features/planner/dive_plan_repository_test.dart` first and copy its `setUp`/`tearDown` (it uses `setUpTestDatabase` from `test/helpers/test_database.dart`) and any `SyncClock` configuration it does, so the new file opens the database the same way.

```dart
// test/features/planner/dive_plan_repository_mission_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

import '../../helpers/test_database.dart';

const _gas = GasMix(o2: 21);

MissionLeg _leg(String id, int order) => MissionLeg(
  id: id,
  order: order,
  label: id,
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
  current: const CurrentVector(speedMps: 0.1, setsTowardDeg: 270),
);

MissionMember _member(String id, int order) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  scooter: const ScooterSpec(
    name: 'Blacktip',
    ratedSpeedMps: 0.9,
    burnTimeSeconds: 5400,
  ),
);

domain.DivePlan _plan({DpvMission? mission}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Mission plan',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [
    DiveTank(id: 'tank-1', volume: 24, startPressure: 200, gasMix: _gas),
  ],
  segments: [
    PlanSegment.hold(
      id: 'seg-1',
      depth: 20,
      durationMinutes: 20,
      tankId: 'tank-1',
      gasMix: _gas,
    ),
  ],
  mission: mission,
  createdAt: DateTime(2026, 9, 19),
  updatedAt: DateTime(2026, 9, 19),
);

final _mission = DpvMission(
  legs: [_leg('L1', 0), _leg('L2', 1)],
  team: [_member('m1', 0), _member('m2', 1)],
  batteryReserveFraction: 0.4,
  defaultCurrent: const CurrentVector(speedMps: 0.05, setsTowardDeg: 10),
);

void main() {
  late db.AppDatabase database;
  late DivePlanRepository repository;

  setUp(() async {
    database = await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<int> count(String table) async => (await database
          .customSelect('SELECT COUNT(*) AS n FROM $table')
          .getSingle())
      .read<int>('n');

  test('a plan without a mission stores no mission rows', () async {
    await repository.savePlan(_plan());
    expect(await count('dive_plan_missions'), 0);
    expect((await repository.getPlan('plan-1'))!.mission, isNull);
  });

  test('a mission round-trips through save and load', () async {
    await repository.savePlan(_plan(mission: _mission));
    final loaded = await repository.getPlan('plan-1');
    expect(loaded!.mission, _mission);
    expect(await count('dive_plan_mission_legs'), 2);
    expect(await count('dive_plan_mission_members'), 2);
  });

  test('a re-save drops removed legs and members and keeps createdAt', () async {
    await repository.savePlan(_plan(mission: _mission));
    final before = await (database.select(
      database.divePlanMissionLegs,
    )..where((t) => t.id.equals('L1'))).getSingle();

    await repository.savePlan(
      _plan(
        mission: _mission.copyWith(
          legs: [_leg('L1', 0)],
          team: [_member('m2', 0)],
        ),
      ),
    );

    final loaded = (await repository.getPlan('plan-1'))!.mission!;
    expect(loaded.legs.map((l) => l.id), ['L1']);
    expect(loaded.team.map((m) => m.id), ['m2']);
    final after = await (database.select(
      database.divePlanMissionLegs,
    )..where((t) => t.id.equals('L1'))).getSingle();
    expect(after.createdAt, before.createdAt);
  });

  test('saving without the mission removes every mission row', () async {
    await repository.savePlan(_plan(mission: _mission));
    await repository.savePlan(_plan());
    expect(await count('dive_plan_missions'), 0);
    expect(await count('dive_plan_mission_legs'), 0);
    expect(await count('dive_plan_mission_members'), 0);
    expect((await repository.getPlan('plan-1'))!.mission, isNull);
  });

  test('removed rows and a removed mission are tombstoned', () async {
    await repository.savePlan(_plan(mission: _mission));
    await repository.savePlan(_plan());
    final tombstones = await database
        .customSelect('SELECT entity_type, record_id FROM deletion_log')
        .get();
    final logged = {
      for (final r in tombstones)
        '${r.read<String>('entity_type')}:${r.read<String>('record_id')}',
    };
    expect(
      logged,
      containsAll(<String>[
        'divePlanMissions:plan-1',
        'divePlanMissionLegs:L1',
        'divePlanMissionLegs:L2',
        'divePlanMissionMembers:m1',
        'divePlanMissionMembers:m2',
      ]),
    );
  });

  test('deleting the plan deletes and tombstones its mission', () async {
    await repository.savePlan(_plan(mission: _mission));
    await repository.deletePlan('plan-1');
    expect(await count('dive_plan_missions'), 0);
    expect(await count('dive_plan_mission_legs'), 0);
    expect(await count('dive_plan_mission_members'), 0);
    final n = await database
        .customSelect(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'divePlanMissions' AND record_id = 'plan-1'",
        )
        .getSingle();
    expect(n.read<int>('n'), 1);
  });

  test('a duplicate carries the mission under fresh ids', () async {
    await repository.savePlan(_plan(mission: _mission));
    final copy = await repository.duplicatePlan('plan-1');

    final mission = (await repository.getPlan(copy!.id))!.mission!;
    expect(mission.legs.map((l) => l.label), ['L1', 'L2']);
    expect(mission.team.map((m) => m.displayName), ['m1', 'm2']);
    expect(mission.legs.map((l) => l.id), isNot(contains('L1')));
    expect(mission.team.map((m) => m.id), isNot(contains('m1')));
    expect(mission.batteryReserveFraction, 0.4);
    // The source keeps its own rows.
    expect((await repository.getPlan('plan-1'))!.mission, _mission);
  });
}
```

Confirm the deletion log's table and column names before running: `grep -n "class DeletionLog" -A 12 lib/core/database/tables/sync_tables.dart`. If they differ from `deletion_log`, `entity_type` and `record_id`, use the real names in both tombstone tests.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/dive_plan_repository_mission_test.dart`
Expected: FAIL. The mission round-trip test sees a null mission, because nothing writes the rows yet.

- [ ] **Step 3: Write the store**

```dart
// lib/features/planner/data/repositories/dive_plan_mission_store.dart
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/planner/data/repositories/dive_plan_mission_rows.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';

/// The mission rows a write or delete touched, for sync bookkeeping.
class MissionRowIds {
  /// Whether the mission row itself (id = plan id) is included.
  final bool mission;
  final List<String> legIds;
  final List<String> memberIds;

  const MissionRowIds({
    required this.mission,
    required this.legIds,
    required this.memberIds,
  });

  static const none = MissionRowIds(mission: false, legIds: [], memberIds: []);

  bool get isEmpty => !mission && legIds.isEmpty && memberIds.isEmpty;
}

/// Persistence for a plan's DPV mission (v241, issue #2086), kept apart
/// from `DivePlanRepository` so that file does not grow further.
///
/// [write] and [deleteAll] run inside the caller's transaction; the
/// `record*` methods run after it commits, so a rollback leaves no stray
/// pending marker or tombstone.
class DivePlanMissionStore {
  const DivePlanMissionStore();

  /// Upserts [mission] for [planId] and deletes the legs and members it no
  /// longer lists; a null [mission] deletes every mission row of the plan.
  /// Returns the rows written and the rows removed.
  Future<(MissionRowIds, MissionRowIds)> write(
    db.AppDatabase d,
    String planId,
    DpvMission? mission,
    int now,
  ) async {
    final existingMission = await (d.select(
      d.divePlanMissions,
    )..where((t) => t.planId.equals(planId))).getSingleOrNull();
    final existingLegs = await (d.select(
      d.divePlanMissionLegs,
    )..where((t) => t.planId.equals(planId))).get();
    final existingMembers = await (d.select(
      d.divePlanMissionMembers,
    )..where((t) => t.planId.equals(planId))).get();

    if (mission == null) {
      await deleteAll(d, planId);
      return (
        MissionRowIds.none,
        MissionRowIds(
          mission: existingMission != null,
          legIds: [for (final r in existingLegs) r.id],
          memberIds: [for (final r in existingMembers) r.id],
        ),
      );
    }

    final legCreatedAt = {for (final r in existingLegs) r.id: r.createdAt};
    final memberCreatedAt = {
      for (final r in existingMembers) r.id: r.createdAt,
    };
    await d
        .into(d.divePlanMissions)
        .insertOnConflictUpdate(
          DivePlanMissionRows.mission(
            planId,
            mission,
            now,
            createdAt: existingMission?.createdAt,
          ),
        );
    for (final (i, leg) in mission.legs.indexed) {
      await d
          .into(d.divePlanMissionLegs)
          .insertOnConflictUpdate(
            DivePlanMissionRows.leg(
              planId,
              leg,
              i,
              now,
              createdAt: legCreatedAt[leg.id],
            ),
          );
    }
    for (final (i, member) in mission.team.indexed) {
      await d
          .into(d.divePlanMissionMembers)
          .insertOnConflictUpdate(
            DivePlanMissionRows.member(
              planId,
              member,
              i,
              now,
              createdAt: memberCreatedAt[member.id],
            ),
          );
    }

    final keptLegs = {for (final l in mission.legs) l.id};
    final keptMembers = {for (final m in mission.team) m.id};
    final removedLegs = [
      for (final r in existingLegs)
        if (!keptLegs.contains(r.id)) r.id,
    ];
    final removedMembers = [
      for (final r in existingMembers)
        if (!keptMembers.contains(r.id)) r.id,
    ];
    if (removedLegs.isNotEmpty) {
      await (d.delete(
        d.divePlanMissionLegs,
      )..where((t) => t.id.isIn(removedLegs))).go();
    }
    if (removedMembers.isNotEmpty) {
      await (d.delete(
        d.divePlanMissionMembers,
      )..where((t) => t.id.isIn(removedMembers))).go();
    }

    return (
      MissionRowIds(
        mission: true,
        legIds: [for (final l in mission.legs) l.id],
        memberIds: [for (final m in mission.team) m.id],
      ),
      MissionRowIds(
        mission: false,
        legIds: removedLegs,
        memberIds: removedMembers,
      ),
    );
  }

  /// The mission stored for [planId], or null when the plan has none.
  Future<DpvMission?> read(db.AppDatabase d, String planId) async {
    final row = await (d.select(
      d.divePlanMissions,
    )..where((t) => t.planId.equals(planId))).getSingleOrNull();
    if (row == null) return null;
    final legs = await (d.select(
      d.divePlanMissionLegs,
    )..where((t) => t.planId.equals(planId))).get();
    final members = await (d.select(
      d.divePlanMissionMembers,
    )..where((t) => t.planId.equals(planId))).get();
    return DivePlanMissionRows.toMission(row, legs, members);
  }

  /// Every mission row [planId] owns, for tombstoning a plan delete.
  Future<MissionRowIds> idsFor(db.AppDatabase d, String planId) async {
    final mission = await (d.select(
      d.divePlanMissions,
    )..where((t) => t.planId.equals(planId))).getSingleOrNull();
    final legs = await (d.select(
      d.divePlanMissionLegs,
    )..where((t) => t.planId.equals(planId))).get();
    final members = await (d.select(
      d.divePlanMissionMembers,
    )..where((t) => t.planId.equals(planId))).get();
    return MissionRowIds(
      mission: mission != null,
      legIds: [for (final r in legs) r.id],
      memberIds: [for (final r in members) r.id],
    );
  }

  /// Deletes every mission row of [planId]. The rows reference the plan with
  /// no delete action, so this runs before the plan row is deleted.
  Future<void> deleteAll(db.AppDatabase d, String planId) async {
    await (d.delete(
      d.divePlanMissionLegs,
    )..where((t) => t.planId.equals(planId))).go();
    await (d.delete(
      d.divePlanMissionMembers,
    )..where((t) => t.planId.equals(planId))).go();
    await (d.delete(
      d.divePlanMissions,
    )..where((t) => t.planId.equals(planId))).go();
  }

  /// [mission] with a fresh id on every leg and member, for a duplicated
  /// plan: row ids are global, so the copy cannot reuse the source's.
  DpvMission remint(DpvMission mission, String Function() newId) {
    return mission.copyWith(
      legs: [for (final l in mission.legs) l.copyWith(id: newId())],
      team: [for (final m in mission.team) m.copyWith(id: newId())],
    );
  }

  /// Marks [written] pending and tombstones [removed], after the commit.
  Future<void> recordWrite(
    SyncRepository sync,
    String planId,
    MissionRowIds written,
    MissionRowIds removed,
    int now,
  ) async {
    if (written.mission) {
      await sync.markRecordPending(
        entityType: 'divePlanMissions',
        recordId: planId,
        localUpdatedAt: now,
      );
    }
    for (final id in written.legIds) {
      await sync.markRecordPending(
        entityType: 'divePlanMissionLegs',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    for (final id in written.memberIds) {
      await sync.markRecordPending(
        entityType: 'divePlanMissionMembers',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    await recordDeletion(sync, planId, removed);
  }

  /// Tombstones [removed]: children first, then the mission row.
  Future<void> recordDeletion(
    SyncRepository sync,
    String planId,
    MissionRowIds removed,
  ) async {
    for (final id in removed.legIds) {
      await sync.logDeletion(entityType: 'divePlanMissionLegs', recordId: id);
    }
    for (final id in removed.memberIds) {
      await sync.logDeletion(
        entityType: 'divePlanMissionMembers',
        recordId: id,
      );
    }
    if (removed.mission) {
      await sync.logDeletion(entityType: 'divePlanMissions', recordId: planId);
    }
  }
}
```

- [ ] **Step 4: Wire the repository**

In `dive_plan_repository.dart`:

Add the import after the `sync_event_bus.dart` import:

```dart
import 'package:submersion/features/planner/data/repositories/dive_plan_mission_store.dart';
```

Add a field under `_log`:

```dart
  final _missions = const DivePlanMissionStore();
```

In `watchPlanChanges`, add to the table list after `_db.divePlanEquipment,`:

```dart
      _db.divePlanMissions,
      _db.divePlanMissionLegs,
      _db.divePlanMissionMembers,
```

In `savePlan`, declare next to `removedEquipmentIds`:

```dart
    var missionWritten = MissionRowIds.none;
    var missionRemoved = MissionRowIds.none;
```

At the end of the transaction body (after the equipment junction `for (final id in removedEquipmentIds)` delete loop, still inside `_db.transaction`):

```dart
        (missionWritten, missionRemoved) = await _missions.write(
          _db,
          plan.id,
          plan.mission,
          now,
        );
```

After the committed-bookkeeping loop over `removedEquipmentIds` and before `SyncEventBus.notifyLocalChange();`:

```dart
      await _missions.recordWrite(
        _syncRepository,
        plan.id,
        missionWritten,
        missionRemoved,
        now,
      );
```

In `getPlan`, replace `return _mapPlan(` ... `);` with:

```dart
      final plan = _mapPlan(
        row,
        tankRows,
        segmentRows,
        equipmentIds: equipmentRows.map((r) => r.equipmentId).toList(),
        gearProvenance: [
          for (final r in equipmentRows)
            GearProvenance(
              equipmentId: r.equipmentId,
              viaEquipmentId: r.viaEquipmentId,
              viaSetId: r.viaSetId,
            ),
        ],
      );
      final mission = await _missions.read(_db, id);
      return mission == null ? plan : plan.copyWith(mission: mission);
```

In `deletePlan`, before `await _db.transaction(`:

```dart
      final missionIds = await _missions.idsFor(_db, id);
```

Inside that transaction, as its first statement:

```dart
        await _missions.deleteAll(_db, id);
```

After the transaction, before the segment tombstone loop:

```dart
      await _missions.recordDeletion(_syncRepository, id, missionIds);
```

In `duplicatePlan`, in the `source.copyWith(` call that builds `copy`, add:

```dart
      mission: source.mission == null
          ? null
          : _missions.remint(source.mission!, _uuid.v4),
```

- [ ] **Step 5: Run the tests**

```bash
flutter test test/features/planner/dive_plan_repository_mission_test.dart test/features/planner/dive_plan_repository_test.dart
```

Expected: PASS, the 7 new tests and the existing repository suite. Then check the file budget:

```bash
wc -l lib/features/planner/data/repositories/dive_plan_repository.dart lib/features/planner/data/repositories/dive_plan_mission_store.dart
```

Expected: the repository at most 865 lines; the store under 400.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/features/planner/data test/features/planner
git add lib/features/planner/data/repositories/dive_plan_mission_store.dart lib/features/planner/data/repositories/dive_plan_repository.dart test/features/planner/dive_plan_repository_mission_test.dart
git commit -m "feat(planner): save, load, delete and duplicate a plan's DPV mission

Refs #2086"
```

---

### Task 4: Sync serializer and service

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (14 sites, each directly after the matching `divePlanSegments` site)
- Modify: `lib/core/services/sync/sync_service.dart` (3 sites)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart`
- Test: `test/features/planner/dive_plan_mission_sync_test.dart`

**Interfaces:**
- Consumes: Task 1 tables; Task 3 repository save.
- Produces: `SyncData.divePlanMissions`, `SyncData.divePlanMissionLegs`, `SyncData.divePlanMissionMembers` (`List<Map<String, dynamic>>`); entity types handled by `fetchRecord`, `upsertRecord`, `deleteRecord`.

- [ ] **Step 1: Write the failing sync test**

```dart
// test/features/planner/dive_plan_mission_sync_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

import '../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  const gas = GasMix(o2: 32);
  const mission = DpvMission(
    legs: [
      MissionLeg(
        id: 'leg-1',
        order: 0,
        label: 'T',
        distanceM: 300,
        depthM: 20,
        headingDeg: 90,
      ),
    ],
    team: [
      MissionMember(
        id: 'member-1',
        order: 0,
        displayName: 'Sam',
        sacBottom: 15,
        scooter: ScooterSpec(
          name: 'Blacktip',
          ratedSpeedMps: 0.9,
          burnTimeSeconds: 5400,
        ),
      ),
    ],
  );

  DivePlan plan() => DivePlan(
    id: 'plan-1',
    name: 'Sync mission',
    gfLow: 40,
    gfHigh: 80,
    tanks: const [
      DiveTank(id: 'tank-1', volume: 11.1, startPressure: 200, gasMix: gas),
    ],
    segments: [
      PlanSegment.hold(
        id: 'seg-1',
        depth: 20,
        durationMinutes: 20,
        tankId: 'tank-1',
        gasMix: gas,
      ),
    ],
    mission: mission,
    createdAt: DateTime(2026, 9, 19),
    updatedAt: DateTime(2026, 9, 19),
  );

  test('export carries the mission, leg and member rows', () async {
    await DivePlanRepository().savePlan(plan());
    final changeset = await SyncDataSerializer().exportChangeset(
      deviceId: 'device-a',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(changeset.data.divePlanMissions.map((r) => r['id']), ['plan-1']);
    expect(changeset.data.divePlanMissionLegs.map((r) => r['id']), ['leg-1']);
    expect(
      changeset.data.divePlanMissionMembers.map((r) => r['id']),
      ['member-1'],
    );
    expect(changeset.data.divePlanMissionLegs.single['planId'], 'plan-1');
  });

  test('rows re-import through upsertRecord and read back as the mission', () async {
    await DivePlanRepository().savePlan(plan());
    final serializer = SyncDataSerializer();
    final changeset = await serializer.exportChangeset(
      deviceId: 'device-a',
      hlcWatermark: null,
      deletions: const [],
    );
    final missionRow = changeset.data.divePlanMissions.single;
    final legRow = changeset.data.divePlanMissionLegs.single;
    final memberRow = changeset.data.divePlanMissionMembers.single;

    await serializer.deleteRecord('divePlanMissionLegs', 'leg-1');
    await serializer.deleteRecord('divePlanMissionMembers', 'member-1');
    await serializer.deleteRecord('divePlanMissions', 'plan-1');
    expect(await serializer.fetchRecord('divePlanMissions', 'plan-1'), isNull);

    await serializer.upsertRecord('divePlanMissions', missionRow);
    await serializer.upsertRecord('divePlanMissionLegs', legRow);
    await serializer.upsertRecord('divePlanMissionMembers', memberRow);

    expect(
      (await DivePlanRepository().getPlan('plan-1'))!.mission,
      mission,
    );
  });

  test('the changeset JSON round-trips the mission lists', () async {
    await DivePlanRepository().savePlan(plan());
    final changeset = await SyncDataSerializer().exportChangeset(
      deviceId: 'device-a',
      hlcWatermark: null,
      deletions: const [],
    );
    final restored = SyncData.fromJson(changeset.data.toJson());
    expect(restored.divePlanMissions, changeset.data.divePlanMissions);
    expect(restored.divePlanMissionLegs, changeset.data.divePlanMissionLegs);
    expect(
      restored.divePlanMissionMembers,
      changeset.data.divePlanMissionMembers,
    );
  });
}
```

Before running, confirm `SyncData.toJson` and `SyncData.fromJson` are the names in the serializer (`grep -n "Map<String, dynamic> toJson\|factory SyncData.fromJson" lib/core/services/sync/sync_data_serializer.dart`); use the real names if they differ.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/dive_plan_mission_sync_test.dart`
Expected: FAIL, "The getter 'divePlanMissions' isn't defined for the type 'SyncData'".

- [ ] **Step 3: Register the tables in the serializer**

Each block goes directly after the `divePlanSegments` item at the same site. List the sites with `grep -n "divePlanSegments" lib/core/services/sync/sync_data_serializer.dart` (14 of them, in the order below); the file moves on main, so anchor on that text, not on line numbers.

1. `SyncData` fields:

```dart
  final List<Map<String, dynamic>> divePlanMissions;
  final List<Map<String, dynamic>> divePlanMissionLegs;
  final List<Map<String, dynamic>> divePlanMissionMembers;
```

2. `SyncData` constructor:

```dart
    this.divePlanMissions = const [],
    this.divePlanMissionLegs = const [],
    this.divePlanMissionMembers = const [],
```

3. `toJson` map:

```dart
    'divePlanMissions': divePlanMissions,
    'divePlanMissionLegs': divePlanMissionLegs,
    'divePlanMissionMembers': divePlanMissionMembers,
```

4. `fromJson`:

```dart
      divePlanMissions: _parseList(json['divePlanMissions']),
      divePlanMissionLegs: _parseList(json['divePlanMissionLegs']),
      divePlanMissionMembers: _parseList(json['divePlanMissionMembers']),
```

5. Table registry (the `(key: 'divePlanSegments', ...)` record):

```dart
    (
      key: 'divePlanMissions',
      table: _db.divePlanMissions,
      blob: false,
      full: null,
    ),
    (
      key: 'divePlanMissionLegs',
      table: _db.divePlanMissionLegs,
      blob: false,
      full: null,
    ),
    (
      key: 'divePlanMissionMembers',
      table: _db.divePlanMissionMembers,
      blob: false,
      full: null,
    ),
```

6. `exportChangeset`:

```dart
      divePlanMissions: await _safeExport(
        'divePlanMissions',
        () => _exportDivePlanMissions(hlcSince),
      ),
      divePlanMissionLegs: await _safeExport(
        'divePlanMissionLegs',
        () => _exportDivePlanMissionLegs(hlcSince),
      ),
      divePlanMissionMembers: await _safeExport(
        'divePlanMissionMembers',
        () => _exportDivePlanMissionMembers(hlcSince),
      ),
```

7. `fetchRecord` switch:

```dart
      case 'divePlanMissions':
        final row = await (_db.select(
          _db.divePlanMissions,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'divePlanMissionLegs':
        final row = await (_db.select(
          _db.divePlanMissionLegs,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'divePlanMissionMembers':
        final row = await (_db.select(
          _db.divePlanMissionMembers,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

8. The id-list fetch switch:

```dart
      case 'divePlanMissions':
        final rows = await (_db.select(
          _db.divePlanMissions,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'divePlanMissionLegs':
        final rows = await (_db.select(
          _db.divePlanMissionLegs,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'divePlanMissionMembers':
        final rows = await (_db.select(
          _db.divePlanMissionMembers,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```

9. `upsertRecord` switch:

```dart
      case 'divePlanMissions':
        await _db
            .into(_db.divePlanMissions)
            .insertOnConflictUpdate(
              DivePlanMission.fromJson(data).toCompanion(false),
            );
        return;
      case 'divePlanMissionLegs':
        await _db
            .into(_db.divePlanMissionLegs)
            .insertOnConflictUpdate(
              DivePlanMissionLeg.fromJson(data).toCompanion(false),
            );
        return;
      case 'divePlanMissionMembers':
        await _db
            .into(_db.divePlanMissionMembers)
            .insertOnConflictUpdate(
              DivePlanMissionMember.fromJson(data).toCompanion(false),
            );
        return;
```

10. Batch upsert switch:

```dart
      case 'divePlanMissions':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.divePlanMissions,
            records
                .map((r) => DivePlanMission.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
      case 'divePlanMissionLegs':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.divePlanMissionLegs,
            records
                .map((r) => DivePlanMissionLeg.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
      case 'divePlanMissionMembers':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.divePlanMissionMembers,
            records
                .map(
                  (r) => DivePlanMissionMember.fromJson(r).toCompanion(false),
                )
                .toList(),
          ),
        );
        return;
```

11. The `plain(...)` switch:

```dart
      case 'divePlanMissions':
        return plain(_db.divePlanMissions, _db.divePlanMissions.id);
      case 'divePlanMissionLegs':
        return plain(_db.divePlanMissionLegs, _db.divePlanMissionLegs.id);
      case 'divePlanMissionMembers':
        return plain(
          _db.divePlanMissionMembers,
          _db.divePlanMissionMembers.id,
        );
```

12. The table-lookup switch:

```dart
      case 'divePlanMissions':
        return _db.divePlanMissions;
      case 'divePlanMissionLegs':
        return _db.divePlanMissionLegs;
      case 'divePlanMissionMembers':
        return _db.divePlanMissionMembers;
```

13. `deleteRecord` switch:

```dart
      case 'divePlanMissions':
        await (_db.delete(
          _db.divePlanMissions,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'divePlanMissionLegs':
        await (_db.delete(
          _db.divePlanMissionLegs,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'divePlanMissionMembers':
        await (_db.delete(
          _db.divePlanMissionMembers,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

14. Export functions, after `_exportDivePlanSegments`:

```dart
  Future<List<Map<String, dynamic>>> _exportDivePlanMissions(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.divePlanMissions);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDivePlanMissionLegs(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.divePlanMissionLegs);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportDivePlanMissionMembers(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.divePlanMissionMembers);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

After the edits, list every site to make sure none was missed:

```bash
grep -c "divePlanSegments" lib/core/services/sync/sync_data_serializer.dart
grep -c "divePlanMissionLegs" lib/core/services/sync/sync_data_serializer.dart
```

Expected: the two counts are equal (each site names both).

- [ ] **Step 4: Register the tables in the sync service**

In `sync_service.dart`:

1. Apply order, after the `divePlanSegments` record:

```dart
          // Mission rows reference only their plan, applied above.
          (
            type: 'divePlanMissions',
            records: data.divePlanMissions,
            hasUpdatedAt: true,
          ),
          (
            type: 'divePlanMissionLegs',
            records: data.divePlanMissionLegs,
            hasUpdatedAt: true,
          ),
          (
            type: 'divePlanMissionMembers',
            records: data.divePlanMissionMembers,
            hasUpdatedAt: true,
          ),
```

2. The updated-at map, after `'divePlanSegments': true,`:

```dart
    'divePlanMissions': true,
    'divePlanMissionLegs': true,
    'divePlanMissionMembers': true,
```

3. `parentRefs`, after the `divePlanSegments` entry:

```dart
    'divePlanMissions': [
      (field: 'planId', parent: 'divePlans', nullable: false),
    ],
    'divePlanMissionLegs': [
      (field: 'planId', parent: 'divePlans', nullable: false),
    ],
    'divePlanMissionMembers': [
      (field: 'planId', parent: 'divePlans', nullable: false),
    ],
```

In `sync_parent_refs_completeness_test.dart`, after `'dive_plan_segments': 'divePlanSegments',` in `syncedTables`:

```dart
    'dive_plan_missions': 'divePlanMissions',
    'dive_plan_mission_legs': 'divePlanMissionLegs',
    'dive_plan_mission_members': 'divePlanMissionMembers',
```

- [ ] **Step 5: Run the sync tests**

```bash
flutter test test/features/planner/dive_plan_mission_sync_test.dart test/features/planner/dive_plan_sync_round_trip_test.dart test/core/services/sync/dive_plan_sync_round_trip_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart
```

Expected: PASS. Then run every other test in `test/core/services/sync/` that names `divePlanSegments` (`grep -ln divePlanSegments test/core/services/sync/*.dart`) one file at a time; a test that enumerates `SyncData` keys or entity types may need the three new names added next to `divePlanSegments`.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/core/services/sync test/core/services/sync test/features/planner
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/features/planner/dive_plan_mission_sync_test.dart
git commit -m "feat(planner): sync a plan's DPV mission rows

Refs #2086"
```

---

### Task 5: Editing state and mapper

**Files:**
- Modify: `lib/features/dive_planner/domain/entities/plan_result.dart` (`DivePlanState`, from `class DivePlanState extends Equatable`: its fields, constructor, `copyWith` signature and body, and `props`. The file is already 920 lines, over the 800 cap, and this adds about eight; do not split it in this PR)
- Modify: `lib/features/planner/domain/services/dive_plan_state_mapper.dart`
- Test: `test/features/planner/mission/dive_plan_state_mission_test.dart`

**Interfaces:**
- Produces: `DivePlanState.mission` (`DpvMission?`), `DivePlanState.copyWith({DpvMission? mission, bool clearMission = false})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/dive_plan_state_mission_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

domain.DivePlan _plan({DpvMission? mission}) => domain.DivePlan(
  id: 'plan-1',
  name: 'State mission',
  gfLow: 40,
  gfHigh: 80,
  mission: mission,
  createdAt: DateTime(2026, 9, 19),
  updatedAt: DateTime(2026, 9, 19),
);

void main() {
  const mission = DpvMission(batteryReserveFraction: 0.5);

  test('the mission travels from the plan into the state and back', () {
    final state = stateFromDivePlan(_plan(mission: mission));
    expect(state.mission, mission);
    expect(divePlanFromState(state).mission, mission);
  });

  test('a state without a mission clears it from the existing plan', () {
    final existing = _plan(mission: mission);
    final state = stateFromDivePlan(existing).copyWith(clearMission: true);
    expect(state.mission, isNull);
    expect(divePlanFromState(state, existing: existing).mission, isNull);
  });

  test('the mission takes part in state equality', () {
    final a = stateFromDivePlan(_plan());
    expect(a.copyWith(mission: mission), isNot(a));
    expect(a.copyWith(mission: mission).copyWith(clearMission: true), a);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/dive_plan_state_mission_test.dart`
Expected: FAIL, "The getter 'mission' isn't defined for the type 'DivePlanState'".

- [ ] **Step 3: Add the field and map it**

In `plan_result.dart`, add the import after the `gear_provenance.dart` import:

```dart
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
```

After `final Map<String, double>? plannedWeightPlacement;`:

```dart

  /// The DPV mission being planned, or null. Travels with the state so
  /// turning the mission off clears it on save.
  final DpvMission? mission;
```

In the constructor, after `this.plannedWeightPlacement,`: `this.mission,`

In `copyWith`'s parameters, after `bool clearPlannedWeight = false,`:

```dart
    DpvMission? mission,
    bool clearMission = false,
```

In the `copyWith` body, after the `plannedWeightPlacement:` entry:

```dart
      mission: clearMission ? null : (mission ?? this.mission),
```

In `props`, after `plannedWeightPlacement,`: `mission,`

In `dive_plan_state_mapper.dart`, in `divePlanFromState`'s `base.copyWith(`, after `clearPlannedWeight: state.plannedWeightKg == null,`:

```dart
    mission: state.mission,
    clearMission: state.mission == null,
```

In `stateFromDivePlan`, after `plannedWeightPlacement: plan.plannedWeightPlacement,`:

```dart
    mission: plan.mission,
```

Update the doc comment on `divePlanFromState`: append ", and the DPV mission" to the sentence listing what travels WITH the state.

- [ ] **Step 4: Run the tests**

```bash
flutter test test/features/planner/mission/dive_plan_state_mission_test.dart test/features/dive_planner/domain/entities/plan_result_test.dart test/features/planner/save_load_round_trip_test.dart
```

If `save_load_round_trip_test.dart` lives elsewhere, find it with `find test -name save_load_round_trip_test.dart`. Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dive_planner lib/features/planner test/features/planner
git add lib/features/dive_planner/domain/entities/plan_result.dart lib/features/planner/domain/services/dive_plan_state_mapper.dart test/features/planner/mission/dive_plan_state_mission_test.dart
git commit -m "feat(planner): carry the DPV mission through the planner state

Refs #2086"
```

---

### Task 6: Plan file format version 3

**Files:**
- Create: `lib/features/planner/data/services/plan_file_mission_codec.dart`
- Modify: `lib/features/planner/data/services/plan_file_codec.dart`
- Test: `test/features/planner/mission/plan_file_mission_codec_test.dart`

**Interfaces:**
- Produces: `Map<String, dynamic> missionToFileMap(DpvMission mission)`, `DpvMission missionFromFileMap(Map<String, dynamic> map, String Function() newId)`, `subplanVersion == 3`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/planner/mission/plan_file_mission_codec_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/data/services/plan_file_codec.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

const _mission = DpvMission(
  legs: [
    MissionLeg(
      id: 'L1',
      order: 0,
      label: 'T',
      distanceM: 300,
      depthM: 20,
      headingDeg: 90,
      current: CurrentVector(speedMps: 0.2, setsTowardDeg: 45),
    ),
    MissionLeg(
      id: 'L2',
      order: 1,
      label: 'Jump 2',
      distanceM: 150,
      depthM: 25,
      headingDeg: 180,
      shoreExit: ShoreExit(surfaceSwimM: 120, walkM: 400),
    ),
  ],
  team: [
    MissionMember(
      id: 'm1',
      order: 0,
      displayName: 'Sam',
      buddyId: 'buddy-1',
      sacBottom: 16,
      swimSpeedMps: 0.25,
      scooter: ScooterSpec(
        equipmentId: 'eq-1',
        name: 'Blacktip',
        ratedSpeedMps: 0.9,
        burnTimeSeconds: 5400,
        towSpeedFactor: 0.55,
        towBurnFactor: 1.7,
      ),
    ),
  ],
  batteryReserveFraction: 0.4,
  defaultCurrent: CurrentVector(speedMps: 0.05, setsTowardDeg: 10),
  environment: MissionEnvironment.openWater,
  walkSpeedMps: 1.1,
  surfaceSwimLimitM: 250,
);

domain.DivePlan _plan({DpvMission? mission}) => domain.DivePlan(
  id: 'plan-1',
  name: 'File mission',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [DiveTank(id: 'tank-1', volume: 12, gasMix: GasMix(o2: 21))],
  mission: mission,
  createdAt: DateTime(2026, 9, 19),
  updatedAt: DateTime(2026, 9, 19),
);

/// The mission with ids blanked, so a comparison ignores the fresh ids an
/// import mints.
DpvMission _withoutIds(DpvMission m) => m.copyWith(
  legs: [for (final l in m.legs) l.copyWith(id: '')],
  team: [for (final t in m.team) t.copyWith(id: '')],
);

void main() {
  test('the format is at version 3', () {
    expect(subplanVersion, 3);
  });

  test('a mission survives export and import under fresh ids', () {
    final imported = subplanFromJson(planToSubplanJson(_plan(mission: _mission)));
    final mission = imported.mission!;
    expect(_withoutIds(mission), _withoutIds(_mission));
    expect(mission.legs.map((l) => l.id), isNot(contains('L1')));
    expect(mission.team.single.id, isNot('m1'));
  });

  test('the buddy, diver and scooter links are not exported', () {
    // They name rows in the exporting install; on another install they
    // would dangle or, worse, match an unrelated row.
    final json = jsonDecode(planToSubplanJson(_plan(mission: _mission)));
    final member = json['plan']['mission']['team'][0] as Map<String, dynamic>;
    expect(member.containsKey('buddyId'), isFalse);
    expect(member.containsKey('diverId'), isFalse);
    expect(member.containsKey('scooterEquipmentId'), isFalse);
    final imported = subplanFromJson(jsonEncode(json));
    expect(imported.mission!.team.single.buddyId, isNull);
    expect(imported.mission!.team.single.scooter.equipmentId, isNull);
    expect(imported.mission!.team.single.scooter.name, 'Blacktip');
  });

  test('a plan without a mission writes no mission block', () {
    final json = jsonDecode(planToSubplanJson(_plan()));
    expect((json['plan'] as Map).containsKey('mission'), isFalse);
    expect(subplanFromJson(jsonEncode(json)).mission, isNull);
  });

  test('a version 2 file still imports, without a mission', () {
    final json = jsonDecode(planToSubplanJson(_plan()));
    json['version'] = 2;
    expect(subplanFromJson(jsonEncode(json)).mission, isNull);
  });

  test('a mission block missing a required field is rejected', () {
    final json = jsonDecode(planToSubplanJson(_plan(mission: _mission)));
    (json['plan']['mission']['legs'][0] as Map).remove('distanceM');
    expect(() => subplanFromJson(jsonEncode(json)), throwsFormatException);
  });
}
```

Note the deliberate choice in the third test: `buddyId`, `diverId` and the scooter's `equipmentId` are dropped on export, because they name rows of the exporting install. Add this to the spec in Task 7.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/planner/mission/plan_file_mission_codec_test.dart`
Expected: FAIL, `subplanVersion` is 2 and the mission is null after import.

- [ ] **Step 3: Write the mission codec**

```dart
// lib/features/planner/data/services/plan_file_mission_codec.dart
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

/// The `mission` block of a version 3 `.subplan` file (issue #2086).
///
/// Links to a buddy, a diver profile or an equipment item are not written:
/// they name rows of the exporting install, which on another install would
/// dangle or match an unrelated row. The scooter's numbers travel as the
/// snapshot they already are.
Map<String, dynamic> missionToFileMap(DpvMission mission) {
  return {
    'batteryReserveFraction': mission.batteryReserveFraction,
    'defaultCurrent': _currentToMap(mission.defaultCurrent),
    'environment': mission.environment.name,
    'walkSpeedMps': mission.walkSpeedMps,
    'surfaceSwimLimitM': mission.surfaceSwimLimitM,
    'legs': [
      for (final leg in mission.legs)
        {
          'label': leg.label,
          'distanceM': leg.distanceM,
          'depthM': leg.depthM,
          'headingDeg': leg.headingDeg,
          'current': _currentToMap(leg.current),
          'shoreExit': leg.shoreExit == null
              ? null
              : {
                  'surfaceSwimM': leg.shoreExit!.surfaceSwimM,
                  'walkM': leg.shoreExit!.walkM,
                },
        },
    ],
    'team': [
      for (final member in mission.team)
        {
          'displayName': member.displayName,
          'sacBottom': member.sacBottom,
          'swimSpeedMps': member.swimSpeedMps,
          'scooter': {
            'name': member.scooter.name,
            'ratedSpeedMps': member.scooter.ratedSpeedMps,
            'burnTimeSeconds': member.scooter.burnTimeSeconds,
            'towSpeedFactor': member.scooter.towSpeedFactor,
            'towBurnFactor': member.scooter.towBurnFactor,
          },
        },
    ],
  };
}

/// Reads a `mission` block, minting ids with [newId]. Throws
/// [FormatException] when a required number is missing; a cast failure on a
/// malformed file is converted by the caller.
DpvMission missionFromFileMap(
  Map<String, dynamic> map,
  String Function() newId,
) {
  double required(Map<String, dynamic> m, String key) {
    final value = m[key];
    if (value is! num) {
      throw FormatException('Mission field "$key" is missing');
    }
    return value.toDouble();
  }

  final legs = <MissionLeg>[];
  for (final (i, raw) in (map['legs'] as List? ?? const []).indexed) {
    final leg = raw as Map<String, dynamic>;
    legs.add(
      MissionLeg(
        id: newId(),
        order: i,
        label: leg['label'] as String? ?? '',
        distanceM: required(leg, 'distanceM'),
        depthM: required(leg, 'depthM'),
        headingDeg: required(leg, 'headingDeg'),
        current: _currentFromMap(leg['current']),
        shoreExit: _shoreFromMap(leg['shoreExit']),
      ),
    );
  }

  final team = <MissionMember>[];
  for (final (i, raw) in (map['team'] as List? ?? const []).indexed) {
    final member = raw as Map<String, dynamic>;
    final scooter = member['scooter'] as Map<String, dynamic>;
    team.add(
      MissionMember(
        id: newId(),
        order: i,
        displayName: member['displayName'] as String? ?? '',
        sacBottom: required(member, 'sacBottom'),
        swimSpeedMps:
            (member['swimSpeedMps'] as num?)?.toDouble() ??
            kDefaultSwimSpeedMps,
        scooter: ScooterSpec(
          name: scooter['name'] as String? ?? '',
          ratedSpeedMps: required(scooter, 'ratedSpeedMps'),
          burnTimeSeconds: required(scooter, 'burnTimeSeconds').round(),
          towSpeedFactor:
              (scooter['towSpeedFactor'] as num?)?.toDouble() ??
              kDefaultTowSpeedFactor,
          towBurnFactor:
              (scooter['towBurnFactor'] as num?)?.toDouble() ??
              kDefaultTowBurnFactor,
        ),
      ),
    );
  }

  return DpvMission(
    legs: legs,
    team: team,
    batteryReserveFraction:
        (map['batteryReserveFraction'] as num?)?.toDouble() ??
        kDefaultBatteryReserveFraction,
    defaultCurrent: _currentFromMap(map['defaultCurrent']),
    environment:
        MissionEnvironment.values.asNameMap()[map['environment']] ??
        MissionEnvironment.overhead,
    walkSpeedMps:
        (map['walkSpeedMps'] as num?)?.toDouble() ?? kDefaultWalkSpeedMps,
    surfaceSwimLimitM: (map['surfaceSwimLimitM'] as num?)?.toDouble(),
  );
}

ShoreExit? _shoreFromMap(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final swim = raw['surfaceSwimM'];
  final walk = raw['walkM'];
  if (swim is! num || walk is! num) return null;
  return ShoreExit(surfaceSwimM: swim.toDouble(), walkM: walk.toDouble());
}

Map<String, dynamic>? _currentToMap(CurrentVector? current) {
  if (current == null) return null;
  return {
    'speedMps': current.speedMps,
    'setsTowardDeg': current.setsTowardDeg,
  };
}

CurrentVector? _currentFromMap(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final speed = raw['speedMps'];
  final toward = raw['setsTowardDeg'];
  if (speed is! num || toward is! num) return null;
  return CurrentVector(
    speedMps: speed.toDouble(),
    setsTowardDeg: toward.toDouble(),
  );
}
```

- [ ] **Step 4: Wire it into the file codec**

In `plan_file_codec.dart`:

1. Add the import after the `plan_segment.dart` import:

```dart
import 'package:submersion/features/planner/data/services/plan_file_mission_codec.dart';
```

2. Change `const subplanVersion = 2;` to `const subplanVersion = 3;` and append to the format doc comment:

```dart
///
/// Version 3 adds an optional `mission` block: a DPV mission's route, team
/// and scooter numbers (issue #2086). It is absent for a plan without one,
/// and version 1 and 2 files import with no mission.
```

3. In `planToSubplanJson`, inside the `'plan'` map after the `'segments': [...]` entry:

```dart
      if (plan.mission != null) 'mission': missionToFileMap(plan.mission!),
```

4. In `_planFromMap`, in the returned `domain.DivePlan(...)`, after `segments: segments,`:

```dart
    mission: plan['mission'] is Map<String, dynamic>
        ? missionFromFileMap(plan['mission'] as Map<String, dynamic>, _uuid.v4)
        : null,
```

- [ ] **Step 5: Run the codec tests**

```bash
flutter test test/features/planner/mission/plan_file_mission_codec_test.dart test/features/planner/plan_file_codec_test.dart
```

Expected: PASS. The existing codec test builds files with `'version': subplanVersion` and `subplanVersion + 1`, so it follows the bump. If it pins the literal `2` as the current version anywhere, change that assertion to `subplanVersion`.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/features/planner/data/services test/features/planner
git add lib/features/planner/data/services/plan_file_mission_codec.dart lib/features/planner/data/services/plan_file_codec.dart test/features/planner/mission/plan_file_mission_codec_test.dart
git commit -m "feat(planner): carry the DPV mission in plan files (format v3)

Refs #2086"
```

---

### Task 7: Spec amendment and whole-project verification

**Files:**
- Modify: `docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md` ("Persistence" section)

- [ ] **Step 1: Bring the spec up to date**

The spec was amended in PR #2138 (commit "revise the DPV mission design after issue feedback"): legs and members keyed by `plan_id`, the mission id equal to the plan id, soft links, the five open-water columns and the file format fields. Two sentences in its "Persistence" section predate the database split and the v240 floor:

1. `Three new tables in \`lib/core/database/database.dart\`, following the` becomes `Three new tables in \`lib/core/database/tables/dive_plan_mission_tables.dart\`, following the`.
2. The paragraph that begins `The migration rung takes the next free number at implementation time.` becomes: `The migration rung takes the next free number at implementation time: v241, on 2026-09-27 main is at v240 with the sync floor at 240, and the table-only rung leaves the floor there.` (keep the sentences after it). Rewrap the paragraph to the file's width.

Then confirm nothing contradicts the implementation:

```bash
grep -n "mission_id\|v229\|database.dart" docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md
```

Expected: no `mission_id`, no `v229`, and no `database.dart` in the persistence section. If Step 5 had to renumber the rung, use that number here instead.

- [ ] **Step 2: Format and analyze the whole project**

```bash
dart format . && git status --short
flutter analyze
```

Expected: no files changed by the formatter beyond the spec; `No issues found!`.

- [ ] **Step 3: Architecture guards**

```bash
flutter test test/architecture/
```

Expected: PASS.

- [ ] **Step 4: One full suite run, in the background, with nothing else running**

```bash
flutter test --reporter=failures-only
```

Expected: exit 0. Do not pipe it into `grep` (the pipe hides the exit status); redirect to a file and read the file.

- [ ] **Step 5: Re-check the schema version against main**

```bash
git fetch origin
git show origin/main:lib/core/database/database.dart | grep -o 'currentSchemaVersion = [0-9]*'
gh pr list --state open --search "currentSchemaVersion" --json number,title
```

If main is still at 240, nothing to do. If it moved to 241 or above, merge `origin/main` (take main's side of `database.dart`, `rungs_v231_onward.dart` and `before_open.dart`, then re-add this PR's lines) and renumber this rung to the next free version in: the ladder entry and its comment, `currentSchemaVersion`, the rung in `rungs_v231_onward.dart`, the backstop comment in `before_open.dart`, the helper's doc comment, the table doc comments, the migration test (file name, tripwire, `migrationStepCount`) and the spec. Relax the new newest rung's tripwire instead of v240's if main's rung now owns it. If main raised `minimumCompatibleSchemaVersion`, update the floor assertion in the migration test to match. Then rerun Task 1's Step 9.

- [ ] **Step 6: Commit the spec and any renumbering**

```bash
git add docs/superpowers/specs/2026-09-18-dpv-mission-planner-design.md
git add lib/core/database test/core/database   # only if Step 5 renumbered
git commit -m "docs(planner): record the DPV mission tables' layout and rung

Refs #2086"
```

---

## Self-review

**Spec coverage.** Persistence section: three tables (Task 1), migration and backstop (Task 1), sync registry, serializer export and import, diver-owned rows, indexes (Tasks 1 and 4), repository write inside the transaction with bookkeeping after commit, load, delete, duplicate with new ids (Task 3), codec version 3 with v2 compatibility (Task 6), `DivePlanState.mission` and the mapper (Task 5). The spec's UI, providers, scooter overlay resolver and l10n belong to PR 3.

**Type consistency.** `DivePlanMissionRows` (Task 2) is called by `DivePlanMissionStore` (Task 3). `MissionRowIds` and the store's record signature returned by `write` are used only in Task 3. Entity type strings `divePlanMissions`, `divePlanMissionLegs`, `divePlanMissionMembers` are identical in Tasks 1, 3 and 4. The Drift class names follow from the table class names in Task 1.

**Guards this plan trips on purpose.** The hlc registration guard and the diver-deletion reference guard fail the moment Task 1 adds the tables, which is why Task 1 registers the clocks and the ownership before it commits. The parent-refs completeness guard only checks tables it lists, so Task 4 adds the three names there.
