# Trip Gas Logistics PR 1: Data and Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the trip cylinder data model with no UI: two synced trip child tables, the dive tank link column carried end to end, the domain entities, the repository, the pure state fold and the read providers.

**Architecture:** A `trip_cylinders` row is a slot the diver holds on a trip; `trip_cylinder_events` is its ledger of fills and adjustments; a nullable `dive_tanks.trip_cylinder_id` records which slot a dive breathed from. A slot's state is a pure fold over events and linked tanks ordered by instant, and nothing derived is stored. Both tables sync as updatedAt-clocked children of trips exactly like `tripDayWeather`.

**Tech Stack:** Flutter, Dart, Drift over SQLite, Riverpod (through `core/providers/provider.dart`), Equatable, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-25-trip-gas-logistics-design.md` (sections Data model, Sync registration, Deletion, Deriving a slot's state, Testing, Delivery item 1).

## Global Constraints

- Schema rung **228**. Main is at 226 and PR #2315 holds 227. Re-run the ladder check in Task 1 step 1 and again before push; if 228 is taken, `grep -rn 228` the branch and renumber every site.
- `minimumCompatibleSchemaVersion` stays **224**: this rung is additive (tables plus one nullable column, no backfill).
- Entity type keys `tripCylinders` and `tripCylinderEvents`; tables `trip_cylinders` and `trip_cylinder_events`; Drift data classes `TripCylinderRow` and `TripCylinderEventRow` (the domain classes own the plain names, as `DiveCenterGearNoteRow` does).
- Timestamps are integer epoch milliseconds. `occurred_at` and `dives.dive_date_time` share the wall-clock-as-UTC frame; rows are read back with `isUtc: true`.
- Metric storage only: liters, bar, percentages 0 to 100. No display code in this PR.
- Every repository write outside a `batch` closure calls `markRecordPending`; every delete calls `logDeletion`; every write ends with `SyncEventBus.notifyLocalChange()`.
- No em-dashes or en-dashes as punctuation, no emojis, and no tool or model attribution anywhere in code, comments, commits or the PR (see the Attribution section of the contributor guide).
- Codegen after any `database.dart` edit: `grep build_runner scripts/setup.sh | sh` (the bare `build` token is refused in a Bash command; this pipes the line from the setup script instead).
- `dart format .` after every task; `flutter analyze --fatal-infos` clean before the final commit.
- Run tests unpiped (`flutter test <path>`); a `| grep` hides the exit status. Do not overlap runs.
- One commit per task, message describing the change only. PR body carries `Part of #2325`.
- The feature worktree on branch `ericgriffin/trip-scale-gas-logistics-865434` is already initialized (submodules, pub get, codegen).

## Review Focus

1. A dive whose trip changes through `updateDive` while its tank still points at a slot of the old trip: the link must be nulled, not kept. Pinned in Task 3.
2. A fill and a dive logged at the same instant: the fill applies first, so the slot reads as used, not full. Pinned in Task 7.
3. An event `kind` this build does not know, arriving from a newer peer: it reads as an adjustment and never throws. Pinned in Tasks 2 and 5.
4. Deleting a slot that linked dives used: the tanks keep their copied specs and mix, only the link is nulled, and those tanks are staged for sync. Pinned in Task 5.
5. A bulk tank replace from a template copied off a linked tank must not stamp that slot onto every dive; only a restore writes the link. Pinned in Task 3.

## File Structure

Create:
- `lib/features/trips/domain/entities/trip_cylinder.dart`: the slot entity.
- `lib/features/trips/domain/entities/trip_cylinder_event.dart`: the ledger entity, its kind enum and parser, the wall-clock helper.
- `lib/features/trips/domain/entities/trip_cylinder_state.dart`: `TripCylinderStatus`, `TripCylinderTankUse` (lean linked-tank facts), `TripCylinderState`.
- `lib/features/trips/domain/services/trip_cylinder_state_fold.dart`: `foldCylinderState` and `suggestTripCylinder`, pure.
- `lib/features/dive_log/data/repositories/trip_cylinder_links.dart`: two top-level functions that null `dive_tanks.trip_cylinder_id` and stage the tanks (dive_log owns the column).
- `lib/features/trips/data/repositories/trip_cylinder_repository.dart`: slots, events, tank uses, tick stream, deletion.
- `lib/features/trips/presentation/providers/trip_cylinder_providers.dart`: repository, slots and states providers.
- Tests listed per task.

Modify:
- `lib/core/database/database.dart`: tables, column, registry, version, ladder, helper, rung, backstop.
- `lib/features/dive_log/domain/entities/dive.dart`: `DiveTank.tripCylinderId`.
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart`: six tank sites plus the foreign-trip guard.
- `lib/features/dive_log/data/services/bulk_dive_edit_service.dart`, `lib/features/dive_log/domain/services/sequential_tank_merge.dart`, `lib/features/dive_log/presentation/widgets/tank_editor.dart`: carry the field.
- `lib/core/data/repositories/sync_repository.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/core/services/sync/sync_service.dart`, `lib/core/services/sync/conflict_reference.dart`: registration.
- `lib/features/trips/data/repositories/trip_repository.dart`, `lib/features/divers/data/repositories/diver_delete_steps.dart`, `lib/features/divers/data/repositories/diver_repository.dart`: deletion and trip-move paths.
- Hand-maintained test lists named in Tasks 1, 4, 6 and 8.

---

### Task 1: Schema rung 228

**Files:**
- Modify: `lib/core/database/database.dart` (table classes after line 222, `DiveTanks` column after line 1044, registry after line 4288, version at 4298, ladder after 4953, helper after 8524, rung after 12549, backstop after 12679)
- Modify: `test/core/database/migration_v226_media_cloud_asset_id_test.dart:48-55`
- Test: `test/core/database/migration_v228_trip_cylinders_test.dart`

**Interfaces:**
- Produces: Drift tables `tripCylinders` (`TripCylinderRow`, `TripCylindersCompanion`) and `tripCylinderEvents` (`TripCylinderEventRow`, `TripCylinderEventsCompanion`); `DiveTanks.tripCylinderId` (`DiveTank.tripCylinderId` on the Drift row, `DiveTanksCompanion.tripCylinderId`); `AppDatabase.currentSchemaVersion == 228`.

- [ ] **Step 1: Re-check the schema ladder**

Run:
```bash
unset GITHUB_TOKEN; for n in $(gh pr list --repo submersion-app/submersion --state open --limit 60 --json number --jq '.[].number'); do v=$(gh pr diff "$n" --repo submersion-app/submersion 2>/dev/null | grep -E "^\+\s*static const int currentSchemaVersion = [0-9]+" | grep -oE "[0-9]+" | tail -1); [ -n "$v" ] && echo "PR #$n -> v$v"; done; git fetch -q origin main && git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion = "
```
Expected: `PR #2315 -> v227` (others at or below 226), main at 226. If any PR shows 228, this PR takes the next free number; replace 228 everywhere below.

- [ ] **Step 2: Write the failing migration test**

Create `test/core/database/migration_v228_trip_cylinders_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v228: trip-scale gas logistics, phase 1 (issue #2325). Two children
/// of trips, trip_cylinders and trip_cylinder_events, and the
/// dive_tanks.trip_cylinder_id link.
void main() {
  /// Pre-v228 dive_tanks: only the columns the rung and its assertions touch.
  const preV228DiveTanks = '''
    CREATE TABLE dive_tanks (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL,
      o2_percent REAL NOT NULL DEFAULT 21.0,
      he_percent REAL NOT NULL DEFAULT 0.0,
      tank_order INTEGER NOT NULL DEFAULT 0,
      computer_id TEXT
    )
  ''';

  /// A v226 database with every parent the new tables reference, the tables
  /// the beforeOpen backstops touch, one pre-v228 tank row, and neither new
  /// table. If a backstop throws on a missing column of one of these stub
  /// tables, add that column here, as the v221 fixture did for tags.
  NativeDatabase setupDb({
    int userVersion = 226,
    bool withTrips = true,
    bool linkColumnAlreadyAdded = false,
  }) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        if (withTrips) {
          rawDb.execute('CREATE TABLE trips (id TEXT PRIMARY KEY)');
        }
        rawDb.execute(preV228DiveTanks);
        rawDb.execute(
          "INSERT INTO dive_tanks (id, dive_id, o2_percent, computer_id) "
          "VALUES ('t1', 'd1', 32.0, 'dc1')",
        );
        if (linkColumnAlreadyAdded) {
          rawDb.execute(
            'ALTER TABLE dive_tanks ADD COLUMN trip_cylinder_id TEXT',
          );
        }
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1)),
            applies_to_equipment INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_equipment IN (0, 1))
          )
        ''');
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'dflt_value': c.data['dflt_value'],
          'pk': c.data['pk'],
        },
    ];
  }

  Future<String?> ddlOf(AppDatabase db, String type, String name) async {
    final rows = await db
        .customSelect(
          'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [Variable<String>(type), Variable<String>(name)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String?>('sql');
  }

  /// on_delete action of the dive_tanks foreign key that starts at [column].
  Future<String?> tankLinkAction(AppDatabase db, String column) async {
    final links = await db
        .customSelect("PRAGMA foreign_key_list('dive_tanks')")
        .get();
    for (final l in links) {
      if (l.read<String>('from') == column) {
        return l.read<String>('on_delete').toUpperCase();
      }
    }
    return null;
  }

  const cylinderColumns = <String>[
    'id',
    'trip_id',
    'equipment_id',
    'label',
    'volume',
    'working_pressure',
    'material',
    'preset_name',
    'sort_order',
    'notes',
    'created_at',
    'updated_at',
    'hlc',
  ];

  const eventColumns = <String>[
    'id',
    'trip_cylinder_id',
    'kind',
    'occurred_at',
    'bottle_label',
    'pressure',
    'o2_percent',
    'he_percent',
    'analyzed_o2',
    'analyzed_he',
    'dive_center_id',
    'cost',
    'currency',
    'is_package',
    'note',
    'created_at',
    'updated_at',
    'hlc',
  ];

  test('v228 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 228);
    expect(AppDatabase.migrationVersions, contains(228));
    // Counted from 227 so it holds whether or not #2315's rung has landed.
    expect(AppDatabase.migrationStepCount(227), 1);
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('adds trip_cylinders and trip_cylinder_events', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(await columnsOf(db, 'trip_cylinders'), containsAll(cylinderColumns));
    expect(await columnsOf(db, 'trip_cylinder_events'), containsAll(eventColumns));
  });

  test('adds dive_tanks.trip_cylinder_id and keeps the existing row', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(await columnsOf(db, 'dive_tanks'), contains('trip_cylinder_id'));

    // Column only: an existing tank keeps its attribution and reads back
    // with no slot, never an invented one.
    final row = await db
        .customSelect(
          "SELECT computer_id, trip_cylinder_id FROM dive_tanks WHERE id = 't1'",
        )
        .getSingle();
    expect(row.data['computer_id'], 'dc1');
    expect(row.data['trip_cylinder_id'], isNull);
  });

  test('the links carry the actions the spec fixes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final slots = await ddlOf(db, 'table', 'trip_cylinders');
    expect(slots, contains('REFERENCES trips (id)'));
    expect(slots, contains('REFERENCES equipment (id) ON DELETE SET NULL'));

    final events = await ddlOf(db, 'table', 'trip_cylinder_events');
    expect(
      events,
      contains('REFERENCES trip_cylinders (id) ON DELETE CASCADE'),
    );
    expect(
      events,
      contains('REFERENCES dive_centers (id) ON DELETE SET NULL'),
    );

    expect(await tankLinkAction(db, 'trip_cylinder_id'), 'SET NULL');
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    for (final table in const ['trip_cylinders', 'trip_cylinder_events']) {
      expect(await tableInfo(upgraded, table), await tableInfo(fresh, table));
      expect(
        await ddlOf(upgraded, 'table', table),
        await ddlOf(fresh, 'table', table),
      );
    }
    expect(
      await tankLinkAction(upgraded, 'trip_cylinder_id'),
      await tankLinkAction(fresh, 'trip_cylinder_id'),
    );
  });

  test('the rung is idempotent when the link column already exists', () async {
    // An interrupted upgrade, or a database that reached this version from
    // a parallel branch, leaves the column already added. The guard must
    // skip the ALTER rather than fail on a duplicate column.
    final db = AppDatabase(setupDb(linkColumnAlreadyAdded: true));
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dive_tanks')").get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'trip_cylinder_id'), hasLength(1));
  });

  test(
    'a database stamped v228 without the tables heals in beforeOpen',
    () async {
      // A parallel branch that claimed 228 first carries a device past the
      // rung; the beforeOpen backstop must build what the rung would have.
      final db = AppDatabase(setupDb(userVersion: 228));
      addTearDown(db.close);

      expect(await columnsOf(db, 'trip_cylinders'), contains('trip_id'));
      expect(
        await columnsOf(db, 'trip_cylinder_events'),
        contains('trip_cylinder_id'),
      );
      expect(await columnsOf(db, 'dive_tanks'), contains('trip_cylinder_id'));
    },
  );

  test('a fixture without trips skips the tables and the column', () async {
    // A partial fixture written for an older rung must not gain tables whose
    // foreign keys point nowhere, nor a link column with no parent.
    final db = AppDatabase(setupDb(withTrips: false));
    addTearDown(db.close);

    expect(await columnsOf(db, 'trip_cylinders'), isEmpty);
    expect(await columnsOf(db, 'trip_cylinder_events'), isEmpty);
    expect(await columnsOf(db, 'dive_tanks'), isNot(contains('trip_cylinder_id')));
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v228_trip_cylinders_test.dart`
Expected: FAIL. The first test fails on `currentSchemaVersion` being 226; the table tests fail because `trip_cylinders` does not exist.

- [ ] **Step 4: Add the two table classes**

In `lib/core/database/database.dart`, directly after the closing `}` of `class TripDayWeather` (line 222), insert:

```dart
/// A cylinder slot the diver holds on a trip (v228, issue #2325): one of the
/// N bottles in the truck, not a specific bottle. A rental slot stands
/// alone; an owned cylinder links through [equipmentId] and copies its
/// specs here at creation. The operator's number for the bottle currently
/// in the slot rides on each fill event (TripCylinderEvents.bottleLabel), so
/// a swap at the fill station is one event, never a new row.
///
/// A child of trips with its own updatedAt and hlc, synced like
/// TripDayWeather. Metric storage (liters, bar); conversion happens at
/// display time.
@DataClassName('TripCylinderRow')
class TripCylinders extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text().references(Trips, #id)();

  /// The owned cylinder in this slot, if any. Deleting the item clears the
  /// link; the slot keeps the specs it copied.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// The slot's name, or the owned bottle's mark: "Truck 3", "My HP100".
  TextColumn get label => text().withDefault(const Constant(''))();
  RealColumn get volume => real().nullable()(); // liters
  RealColumn get workingPressure => real().nullable()(); // bar
  TextColumn get material => text().nullable()(); // TankMaterial.name
  TextColumn get presetName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The ledger of a trip cylinder slot (v228, issue #2325): a fill (where,
/// when, pressure, the mix ordered, what the analyzer read, the operator's
/// bottle number, what it cost) or an adjustment (a corrected pressure, a
/// "mark empty"). A dive's consumption is not a row here: it is the
/// dive_tanks.trip_cylinder_id link. The slot's current state is derived
/// from the two and never stored.
@DataClassName('TripCylinderEventRow')
class TripCylinderEvents extends Table {
  TextColumn get id => text()();
  TextColumn get tripCylinderId => text().references(
    TripCylinders,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// TripCylinderEventKind.name: fill or adjustment.
  TextColumn get kind => text()();

  /// The diver's wall clock as UTC epoch milliseconds, the frame
  /// dives.dive_date_time uses, so fills and dives order on one timeline.
  IntColumn get occurredAt => integer()();

  /// The operator's number for the bottle now in the slot (fills).
  TextColumn get bottleLabel => text().nullable()();

  /// Fill pressure, or the corrected current pressure (bar).
  RealColumn get pressure => real().nullable()();
  RealColumn get o2Percent => real().nullable()(); // the mix ordered
  RealColumn get hePercent => real().nullable()();
  RealColumn get analyzedO2 => real().nullable()(); // what the analyzer read
  RealColumn get analyzedHe => real().nullable()();
  TextColumn get diveCenterId => text().nullable().references(
    DiveCenters,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get cost => real().nullable()();

  /// Null means the diver's default currency, as the service cost defaults
  /// do; a NOT NULL default would make every fill silently claim USD.
  TextColumn get currency => text().nullable()();
  BoolColumn get isPackage => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 5: Add the link column to `DiveTanks`**

Directly after the `regulatorEquipmentId` getter's closing `)();` (line 1044), insert:

```dart

  /// v228: the trip cylinder slot this tank was breathed from (issue
  /// #2325). User-authored through the tank editor; downloads and re-parses
  /// never write it. Set null when the slot goes, like every other nullable
  /// link on this table.
  TextColumn get tripCylinderId => text().nullable().references(
    TripCylinders,
    #id,
    onDelete: KeyAction.setNull,
  )();
```

- [ ] **Step 6: Register the tables**

In the `@DriftDatabase(tables: [...])` list, after `DiveCenterGearNotes,` (line 4288), add:

```dart
    // Trip cylinder slots and their ledger (v228, issue #2325)
    TripCylinders,
    TripCylinderEvents,
```

- [ ] **Step 7: Bump the version and the ladder**

Change line 4298 to `static const int currentSchemaVersion = 228;`. After the `226,` entry that closes `migrationVersions` (line 4953), add:

```dart
    // v228: trip-scale gas logistics, phase 1 (issue #2325). trip_cylinders
    // and trip_cylinder_events, two children of trips, and the nullable
    // dive_tanks.trip_cylinder_id link. Tables and one column, no backfill,
    // so the floor stays at 224. 227 is held by PR #2315 (hidden built-in
    // tank presets).
    228,
```

- [ ] **Step 8: Add the idempotent schema helper**

After `_assertDiveCenterGearNotesSchema` (its closing `}` at line 8524), insert:

```dart

  /// Idempotent creation of the v228 trip cylinder tables and the
  /// dive_tanks.trip_cylinder_id link (issue #2325). Called from the v228
  /// rung and the beforeOpen backstop.
  ///
  /// Skipped on a partial migration-test fixture that lacks a parent table,
  /// so a fixture written for an older rung does not gain tables whose
  /// foreign keys point nowhere, nor a link column with no parent. The
  /// column is added after the tables so its reference has a target.
  Future<void> _assertTripCylindersSchema() async {
    for (final parent in const ['trips', 'equipment', 'dive_centers']) {
      if (!await _tableExists(parent)) return;
    }
    await createMigrator().createTable(tripCylinders);
    await createMigrator().createTable(tripCylinderEvents);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_trip_cylinders_trip_id '
      'ON trip_cylinders(trip_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_trip_cylinder_events_cylinder_id '
      'ON trip_cylinder_events(trip_cylinder_id)',
    );
    await _addColumnIfMissing(
      'dive_tanks',
      'trip_cylinder_id',
      'TEXT REFERENCES trip_cylinders(id) ON DELETE SET NULL',
    );
    if (await _tableExists('dive_tanks')) {
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_dive_tanks_trip_cylinder '
        'ON dive_tanks(trip_cylinder_id)',
      );
    }
  }
```

- [ ] **Step 9: Add the onUpgrade rung**

After the v226 rung (line 12549, `if (from < 226) await reportProgress();`), insert:

```dart

        // v228: trip cylinder slots, their ledger and the dive_tanks link
        // (issue #2325). Tables and one nullable column, no backfill.
        if (from < 228) {
          await _assertTripCylindersSchema();
        }
        if (from < 228) await reportProgress();
```

- [ ] **Step 10: Add the beforeOpen backstop**

After the v221 backstop call (line 12679, `await _assertDiveCenterGearNotesSchema();`), insert:

```dart

        // v228 backstop: the trip cylinder tables and the dive_tanks link
        // (parallel-branch version-collision self-heal; all idempotent).
        await _assertTripCylindersSchema();
```

- [ ] **Step 11: Run codegen**

Run: `grep build_runner scripts/setup.sh | sh`
Expected: exits 0; `lib/core/database/database.g.dart` now defines `TripCylinderRow`, `TripCylinderEventRow`, `TripCylindersCompanion`, `TripCylinderEventsCompanion` and `DiveTanksCompanion.tripCylinderId`. Check with `grep -c "TripCylinderRow" lib/core/database/database.g.dart` (greater than 0).

- [ ] **Step 12: Run the test to verify it passes**

Run: `flutter test test/core/database/migration_v228_trip_cylinders_test.dart`
Expected: PASS, all 8 tests. If a beforeOpen backstop throws on a missing column of a stub table in the fixture, add that column to the fixture's `CREATE TABLE`, as the v221 fixture did for `tags`.

- [ ] **Step 13: Relax the v226 test**

In `test/core/database/migration_v226_media_cloud_asset_id_test.dart`, replace lines 48-55 with:

```dart
  test('v226 is at or below the current schema version and in the ladder', () {
    // Relaxed once v228 (trip cylinders) landed on top; the newest rung owns
    // the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(226));
    expect(AppDatabase.migrationVersions, contains(226));
    // Counted from 225 so it holds whether or not #1978's rung has landed.
    expect(AppDatabase.migrationStepCount(225), greaterThanOrEqualTo(1));
```

- [ ] **Step 14: Run the neighbouring migration tests**

Run: `flutter test test/core/database/migration_v226_media_cloud_asset_id_test.dart test/core/database/migration_v221_dive_center_gear_notes_test.dart test/core/database/migration_v210_dive_tank_equipment_set_null_test.dart test/core/database/migration_v194_tank_transmitter_serial_test.dart`
Expected: PASS.

- [ ] **Step 15: Format and commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v228_trip_cylinders_test.dart test/core/database/migration_v226_media_cloud_asset_id_test.dart
git commit -m "feat(db): schema v228, trip cylinder slots, ledger and dive tank link (#2325)"
```

---

### Task 2: Domain entities

**Files:**
- Create: `lib/features/trips/domain/entities/trip_cylinder.dart`
- Create: `lib/features/trips/domain/entities/trip_cylinder_event.dart`
- Create: `lib/features/trips/domain/entities/trip_cylinder_state.dart`
- Test: `test/features/trips/domain/entities/trip_cylinder_event_test.dart`

**Interfaces:**
- Consumes: `GasMix` from `lib/features/dive_log/domain/entities/dive.dart` (`const GasMix({double o2 = 21.0, double he = 0.0})`), `TankMaterial` from `lib/core/constants/enums.dart`.
- Produces: `TripCylinder`, `TripCylinderEvent`, `enum TripCylinderEventKind { fill, adjustment }`, `TripCylinderEventKind tripCylinderEventKindFromName(String? name)`, `DateTime tripCylinderWallClock(DateTime local)`, `enum TripCylinderStatus { full, partial, empty, unknown }`, `TripCylinderTankUse`, `TripCylinderState`. Later tasks use exactly these names and constructor parameters.

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/domain/entities/trip_cylinder_event_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

void main() {
  final at = DateTime.utc(2026, 3, 9, 8, 15);

  TripCylinderEvent fill({
    double? o2 = 32,
    double? he,
    double? analyzedO2,
    double? analyzedHe,
  }) => TripCylinderEvent(
    id: 'e1',
    tripCylinderId: 'c1',
    kind: TripCylinderEventKind.fill,
    occurredAt: at,
    pressure: 200,
    o2Percent: o2,
    hePercent: he,
    analyzedO2: analyzedO2,
    analyzedHe: analyzedHe,
    createdAt: at,
    updatedAt: at,
  );

  group('kind parsing', () {
    test('known names round-trip', () {
      expect(tripCylinderEventKindFromName('fill'), TripCylinderEventKind.fill);
      expect(
        tripCylinderEventKindFromName('adjustment'),
        TripCylinderEventKind.adjustment,
      );
    });

    test('an unknown or missing name is an adjustment, never a throw', () {
      // A newer peer may add a kind this build does not know.
      expect(
        tripCylinderEventKindFromName('swap'),
        TripCylinderEventKind.adjustment,
      );
      expect(
        tripCylinderEventKindFromName(null),
        TripCylinderEventKind.adjustment,
      );
    });
  });

  group('mix getters', () {
    test('analyzed wins over ordered', () {
      final e = fill(o2: 32, analyzedO2: 31.6);
      expect(e.orderedMix!.o2, 32);
      expect(e.analyzedMix!.o2, 31.6);
      expect(e.effectiveMix!.o2, 31.6);
    });

    test('ordered stands in when nothing was analyzed', () {
      final e = fill(o2: 36);
      expect(e.analyzedMix, isNull);
      expect(e.effectiveMix!.o2, 36);
      expect(e.effectiveMix!.he, 0);
    });

    test('no mix at all yields null', () {
      expect(fill(o2: null).effectiveMix, isNull);
    });

    test('helium rides along with each reading', () {
      final e = fill(o2: 21, he: 35, analyzedO2: 20.5, analyzedHe: 34);
      expect(e.orderedMix!.he, 35);
      expect(e.analyzedMix!.he, 34);
    });
  });

  test('copyWith can clear a nullable field', () {
    final cleared = fill(analyzedO2: 31.6).copyWith(analyzedO2: null);
    expect(cleared.analyzedO2, isNull);
    expect(cleared.o2Percent, 32);
  });

  test('the wall-clock helper keeps the local reading and stamps it UTC', () {
    final local = DateTime(2026, 3, 9, 8, 15, 30);
    final wall = tripCylinderWallClock(local);
    expect(wall.isUtc, isTrue);
    expect(wall, DateTime.utc(2026, 3, 9, 8, 15, 30));
  });

  test('a slot copies with cleared specs', () {
    final slot = TripCylinder(
      id: 'c1',
      tripId: 't1',
      label: 'Truck 1',
      volume: 11.1,
      workingPressure: 207,
      material: TankMaterial.aluminum,
      createdAt: at,
      updatedAt: at,
    );
    final bare = slot.copyWith(volume: null, material: null);
    expect(bare.volume, isNull);
    expect(bare.material, isNull);
    expect(bare.workingPressure, 207);
    expect(bare, isNot(equals(slot)));
    expect(slot.copyWith(), slot);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/trips/domain/entities/trip_cylinder_event_test.dart`
Expected: FAIL to compile, the entity files do not exist.

- [ ] **Step 3: Write the slot entity**

Create `lib/features/trips/domain/entities/trip_cylinder.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// One cylinder slot the diver holds on a trip: one of the N bottles in the
/// truck, not a specific bottle. A rental slot stands alone; an owned
/// cylinder links through [equipmentId] and copies its specs here at
/// creation. The operator's number for the bottle currently in the slot
/// rides on each fill event, so a swap at the fill station is one event and
/// the board shows N chips all week.
///
/// Metric: [volume] in liters, [workingPressure] in bar. Shown in the active
/// diver's units at display time.
class TripCylinder extends Equatable {
  final String id;
  final String tripId;

  /// The owned cylinder in this slot, if any.
  final String? equipmentId;

  /// The slot's name, or the owned bottle's mark: "Truck 3", "My HP100".
  final String label;
  final double? volume;
  final double? workingPressure;
  final TankMaterial? material;

  /// The preset the slot was made from, when it was.
  final String? presetName;
  final int sortOrder;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripCylinder({
    required this.id,
    required this.tripId,
    this.equipmentId,
    this.label = '',
    this.volume,
    this.workingPressure,
    this.material,
    this.presetName,
    this.sortOrder = 0,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  TripCylinder copyWith({
    String? id,
    String? tripId,
    Object? equipmentId = _undefined,
    String? label,
    Object? volume = _undefined,
    Object? workingPressure = _undefined,
    Object? material = _undefined,
    Object? presetName = _undefined,
    int? sortOrder,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripCylinder(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      equipmentId: equipmentId == _undefined
          ? this.equipmentId
          : equipmentId as String?,
      label: label ?? this.label,
      volume: volume == _undefined ? this.volume : volume as double?,
      workingPressure: workingPressure == _undefined
          ? this.workingPressure
          : workingPressure as double?,
      material: material == _undefined
          ? this.material
          : material as TankMaterial?,
      presetName: presetName == _undefined
          ? this.presetName
          : presetName as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    equipmentId,
    label,
    volume,
    workingPressure,
    material,
    presetName,
    sortOrder,
    notes,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
```

- [ ] **Step 4: Write the event entity**

Create `lib/features/trips/domain/entities/trip_cylinder_event.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

/// What a ledger row records.
enum TripCylinderEventKind {
  /// Gas went in: pressure, the mix ordered, what the analyzer read, the
  /// bottle number now in the slot, where, and what it cost.
  fill,

  /// A correction: a pressure read off the gauge, or "mark empty".
  adjustment,
}

/// Reads a stored kind. A name this build does not know (a newer peer) is an
/// adjustment: it applies whatever pressure it carries and never throws.
TripCylinderEventKind tripCylinderEventKindFromName(String? name) =>
    TripCylinderEventKind.values.firstWhere(
      (k) => k.name == name,
      orElse: () => TripCylinderEventKind.adjustment,
    );

/// [local] as the frame `Dive.dateTime` and `TripCylinderEvent.occurredAt`
/// share: the wall-clock reading stamped UTC, so a fill at 08:15 and a dive
/// at 09:00 order correctly whatever zone the device is in.
DateTime tripCylinderWallClock(DateTime local) => DateTime.utc(
  local.year,
  local.month,
  local.day,
  local.hour,
  local.minute,
  local.second,
);

/// One row of a slot's ledger.
///
/// [occurredAt] is the diver's wall clock in the UTC frame `Dive.dateTime`
/// uses (see [tripCylinderWallClock]). Pressures in bar, percentages 0 to
/// 100. [currency] null means the diver's default currency.
class TripCylinderEvent extends Equatable {
  final String id;
  final String tripCylinderId;
  final TripCylinderEventKind kind;
  final DateTime occurredAt;

  /// The operator's number for the bottle now in the slot (fills).
  final String? bottleLabel;

  /// Fill pressure, or the corrected current pressure.
  final double? pressure;
  final double? o2Percent;
  final double? hePercent;
  final double? analyzedO2;
  final double? analyzedHe;
  final String? diveCenterId;
  final double? cost;
  final String? currency;
  final bool isPackage;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TripCylinderEvent({
    required this.id,
    required this.tripCylinderId,
    required this.kind,
    required this.occurredAt,
    this.bottleLabel,
    this.pressure,
    this.o2Percent,
    this.hePercent,
    this.analyzedO2,
    this.analyzedHe,
    this.diveCenterId,
    this.cost,
    this.currency,
    this.isPackage = false,
    this.note = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// The mix ordered, when the row carries one.
  GasMix? get orderedMix =>
      o2Percent == null ? null : GasMix(o2: o2Percent!, he: hePercent ?? 0);

  /// What the analyzer read, when the row carries it.
  GasMix? get analyzedMix =>
      analyzedO2 == null ? null : GasMix(o2: analyzedO2!, he: analyzedHe ?? 0);

  /// The mix the slot holds after this event: analyzed over ordered.
  GasMix? get effectiveMix => analyzedMix ?? orderedMix;

  TripCylinderEvent copyWith({
    String? id,
    String? tripCylinderId,
    TripCylinderEventKind? kind,
    DateTime? occurredAt,
    Object? bottleLabel = _undefined,
    Object? pressure = _undefined,
    Object? o2Percent = _undefined,
    Object? hePercent = _undefined,
    Object? analyzedO2 = _undefined,
    Object? analyzedHe = _undefined,
    Object? diveCenterId = _undefined,
    Object? cost = _undefined,
    Object? currency = _undefined,
    bool? isPackage,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripCylinderEvent(
      id: id ?? this.id,
      tripCylinderId: tripCylinderId ?? this.tripCylinderId,
      kind: kind ?? this.kind,
      occurredAt: occurredAt ?? this.occurredAt,
      bottleLabel: bottleLabel == _undefined
          ? this.bottleLabel
          : bottleLabel as String?,
      pressure: pressure == _undefined ? this.pressure : pressure as double?,
      o2Percent: o2Percent == _undefined
          ? this.o2Percent
          : o2Percent as double?,
      hePercent: hePercent == _undefined
          ? this.hePercent
          : hePercent as double?,
      analyzedO2: analyzedO2 == _undefined
          ? this.analyzedO2
          : analyzedO2 as double?,
      analyzedHe: analyzedHe == _undefined
          ? this.analyzedHe
          : analyzedHe as double?,
      diveCenterId: diveCenterId == _undefined
          ? this.diveCenterId
          : diveCenterId as String?,
      cost: cost == _undefined ? this.cost : cost as double?,
      currency: currency == _undefined ? this.currency : currency as String?,
      isPackage: isPackage ?? this.isPackage,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripCylinderId,
    kind,
    occurredAt,
    bottleLabel,
    pressure,
    o2Percent,
    hePercent,
    analyzedO2,
    analyzedHe,
    diveCenterId,
    cost,
    currency,
    isPackage,
    note,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
```

- [ ] **Step 5: Write the state entities**

Create `lib/features/trips/domain/entities/trip_cylinder_state.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

/// What the board says about a slot right now.
enum TripCylinderStatus {
  /// The last thing that happened was a fill, or a gauge reading near the
  /// working pressure.
  full,

  /// Used since the last fill, but above the empty line.
  partial,

  /// At or below the empty line; nobody dives this bottle again.
  empty,

  /// Nothing has happened to the slot yet.
  unknown,
}

/// A dive tank's use of a slot, lean: what the fold needs and nothing else.
/// [entryTime] is the dive's `dateTime`, in the wall-clock-as-UTC frame.
class TripCylinderTankUse extends Equatable {
  final String tankId;
  final String diveId;
  final DateTime entryTime;
  final double? startPressure;
  final double? endPressure;
  final GasMix gasMix;

  const TripCylinderTankUse({
    required this.tankId,
    required this.diveId,
    required this.entryTime,
    this.startPressure,
    this.endPressure,
    this.gasMix = const GasMix(),
  });

  @override
  List<Object?> get props => [
    tankId,
    diveId,
    entryTime,
    startPressure,
    endPressure,
    gasMix,
  ];
}

/// A slot with its derived state. Nothing here is stored; it is recomputed
/// from the ledger and the linked tanks on every read.
class TripCylinderState extends Equatable {
  final TripCylinder cylinder;

  /// Current pressure in bar; null when the last item left it unknown.
  final double? pressure;

  /// The mix the slot holds; null before the first fill with a mix.
  final GasMix? mix;

  /// The latest fill's bottle number, else the slot's own label.
  final String bottleLabel;
  final TripCylinderStatus status;
  final TripCylinderEvent? lastFill;

  /// When the last timeline item happened (fill, adjustment or dive).
  final DateTime? lastEventAt;

  /// Distinct dives that breathed from the slot.
  final int linkedDiveCount;

  const TripCylinderState({
    required this.cylinder,
    this.pressure,
    this.mix,
    required this.bottleLabel,
    required this.status,
    this.lastFill,
    this.lastEventAt,
    this.linkedDiveCount = 0,
  });

  @override
  List<Object?> get props => [
    cylinder,
    pressure,
    mix,
    bottleLabel,
    status,
    lastFill,
    lastEventAt,
    linkedDiveCount,
  ];
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/trips/domain/entities/trip_cylinder_event_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/trips/domain/entities/trip_cylinder.dart lib/features/trips/domain/entities/trip_cylinder_event.dart lib/features/trips/domain/entities/trip_cylinder_state.dart test/features/trips/domain/entities/trip_cylinder_event_test.dart
git commit -m "feat(trips): trip cylinder slot, event and state entities (#2325)"
```

---

### Task 3: `DiveTank.tripCylinderId` end to end

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart:1123-1253` (`DiveTank` field, constructor, `copyWith`, `props`)
- Create: `lib/features/dive_log/data/repositories/trip_cylinder_links.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (createDive insert 1588-1596, updateDive update 1882-1889, updateDive insert 1914-1920, list mapper 3967-3973, detail mapper 4390-4396, `_tankCompanion` 6626-6656, plus the guard calls)
- Modify: `lib/features/dive_log/data/services/bulk_dive_edit_service.dart:352-383` (`_tanksFromRows`)
- Modify: `lib/features/dive_log/domain/services/sequential_tank_merge.dart:176-182` (`_fold`)
- Modify: `lib/features/dive_log/presentation/widgets/tank_editor.dart:333-357` (`_notifyChange`)
- Modify: `lib/core/services/sync/sync_service.dart:2497-2504` (`parentRefs['diveTanks']`)
- Modify: `lib/core/services/sync/conflict_reference.dart:99` (`_defaultTargets`)
- Test: `test/features/dive_log/data/repositories/dive_tank_trip_cylinder_link_test.dart`
- Test: `test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart`

**Interfaces:**
- Consumes: Task 1's `DiveTanksCompanion.tripCylinderId`, `tripCylinders` table.
- Produces: `DiveTank.tripCylinderId` (`String?`), `DiveTank.copyWith({String? tripCylinderId, bool clearTripCylinderId = false})`; top-level `Future<void> clearTripCylinderLinks(AppDatabase db, SyncRepository syncRepository, Iterable<String> cylinderIds, {required int now})` and `Future<void> clearForeignTripCylinderLinks(AppDatabase db, SyncRepository syncRepository, String diveId, {required String? tripId, required int now})` in `trip_cylinder_links.dart`.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/dive_log/data/repositories/dive_tank_trip_cylinder_link_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive_tanks.trip_cylinder_id link (v228, issue #2325): user-authored,
/// so an edit writes it and a rebuild must carry it; meaningless outside its
/// trip, so a move to another trip drops it.
void main() {
  late AppDatabase db;
  late DiveRepository repo;
  late String tripA;
  late String tripB;

  Trip trip(String name) {
    final now = DateTime.now();
    return Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 14),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> insertSlot(String id, String tripId) => db
      .into(db.tripCylinders)
      .insert(
        TripCylindersCompanion.insert(
          id: id,
          tripId: tripId,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<String?> linkOf(String tankId) async => (await db
          .customSelect(
            'SELECT trip_cylinder_id FROM dive_tanks WHERE id = ?',
            variables: [Variable<String>(tankId)],
          )
          .getSingle())
      .readNullable<String>('trip_cylinder_id');

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    final trips = TripRepository();
    tripA = (await trips.createTrip(trip('Bonaire'))).id;
    tripB = (await trips.createTrip(trip('Curacao'))).id;
    await insertSlot('slot-a', tripA);
    await insertSlot('slot-b', tripB);
  });
  tearDown(tearDownTestDatabase);

  test('the link survives create, read and update, and clears on request', () async {
    final dive = createTestDiveWithBottomTime(id: 'd1').copyWith(
      tripId: tripA,
      tanks: const [
        DiveTank(id: 't1', gasMix: GasMix(o2: 32), tripCylinderId: 'slot-a'),
      ],
    );
    await repo.createDive(dive);

    final loaded = await repo.getDiveById('d1');
    expect(loaded!.tanks.single.tripCylinderId, 'slot-a');

    // An edit that rebuilds the tank keeps the link.
    await repo.updateDive(
      loaded.copyWith(tanks: [loaded.tanks.single.copyWith(endPressure: 60)]),
    );
    expect((await repo.getDiveById('d1'))!.tanks.single.tripCylinderId, 'slot-a');

    // And an explicit clear removes it.
    final linked = (await repo.getDiveById('d1'))!;
    await repo.updateDive(
      linked.copyWith(
        tanks: [linked.tanks.single.copyWith(clearTripCylinderId: true)],
      ),
    );
    expect((await repo.getDiveById('d1'))!.tanks.single.tripCylinderId, isNull);
  });

  test('the list mapper carries the link too', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tripId: tripA,
        tanks: const [DiveTank(id: 't1', tripCylinderId: 'slot-a')],
      ),
    );
    final byIds = await repo.getDivesByIds(['d1']);
    expect(byIds.single.tanks.single.tripCylinderId, 'slot-a');
  });

  test('moving the dive to another trip drops a link into the old trip', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tripId: tripA,
        tanks: const [DiveTank(id: 't1', tripCylinderId: 'slot-a')],
      ),
    );
    final dive = (await repo.getDiveById('d1'))!;

    // Same trip: the link stays.
    await repo.updateDive(dive.copyWith(notes: 'Salt Pier'));
    expect(await linkOf('t1'), 'slot-a');

    // Another trip: the slot is not on it, so the link goes.
    await repo.updateDive(dive.copyWith(tripId: tripB));
    expect(await linkOf('t1'), isNull);
  });

  test('a dive created on no trip cannot hold a link', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(
        tanks: const [DiveTank(id: 't1', tripCylinderId: 'slot-a')],
      ),
    );
    expect(await linkOf('t1'), isNull);
  });

  test('a bulk replace stamps the link only when restoring', () async {
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd1').copyWith(tripId: tripA),
    );
    await repo.createDive(
      createTestDiveWithBottomTime(id: 'd2').copyWith(tripId: tripA),
    );
    const template = DiveTank(id: 'tpl', tripCylinderId: 'slot-a');

    // A template copied from a linked tank must not put that slot on every
    // dive it lands on.
    await repo.bulkReplaceTanks(['d1'], const [template]);
    final d1 = (await repo.getDiveById('d1'))!;
    expect(d1.tanks.single.tripCylinderId, isNull);

    // An undo restoring captured rows writes what it captured.
    await repo.bulkReplaceTanks(['d2'], const [template], restoreLinks: true);
    final d2 = (await repo.getDiveById('d2'))!;
    expect(d2.tanks.single.tripCylinderId, 'slot-a');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_tank_trip_cylinder_link_test.dart`
Expected: FAIL to compile: `DiveTank` has no `tripCylinderId`.

- [ ] **Step 3: Add the field to `DiveTank`**

In `lib/features/dive_log/domain/entities/dive.dart`, after the `regulatorEquipmentId` field (line 1126), add:

```dart

  /// The trip cylinder slot this tank was breathed from (v228, issue
  /// #2325). User-authored: the tank editor sets it and downloads never
  /// touch it. Meaningless outside the dive's trip, so the repository drops
  /// it when the dive moves.
  final String? tripCylinderId;
```

In the constructor (lines 1148-1167), after `this.regulatorEquipmentId,` add `this.tripCylinderId,`.

In `copyWith`, after `bool clearRegulatorEquipmentId = false,` (line 1195) add:

```dart
    String? tripCylinderId,
    bool clearTripCylinderId = false,
```

and in its body, after the `regulatorEquipmentId:` assignment (lines 1221-1223) add:

```dart
      tripCylinderId: clearTripCylinderId
          ? null
          : (tripCylinderId ?? this.tripCylinderId),
```

In `props` (lines 1233-1253), after `regulatorEquipmentId,` add `tripCylinderId,`.

- [ ] **Step 4: Write the link-clearing helpers**

Create `lib/features/dive_log/data/repositories/trip_cylinder_links.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

/// Nulls the slot link on every tank pointing at [cylinderIds] and stages
/// those tanks, the way clearCylinderGearLinks does for gear. The schema's
/// ON DELETE SET NULL would clear them too, but a cascade reaches no peer;
/// staging the tank sends the cleared row. A trip holds a handful of slots,
/// so no chunking is needed here.
Future<void> clearTripCylinderLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  Iterable<String> cylinderIds, {
  required int now,
}) async {
  final ids = cylinderIds.toSet().toList();
  if (ids.isEmpty) return;
  final tanks = await (db.select(
    db.diveTanks,
  )..where((t) => t.tripCylinderId.isIn(ids))).get();
  if (tanks.isEmpty) return;
  await (db.update(db.diveTanks)..where((t) => t.tripCylinderId.isIn(ids)))
      .write(const DiveTanksCompanion(tripCylinderId: Value(null)));
  for (final tank in tanks) {
    await syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: tank.id,
      localUpdatedAt: now,
    );
  }
}

/// Drops the links on [diveId]'s tanks that point at a slot of any trip
/// other than [tripId] (every link when [tripId] is null) and stages those
/// tanks. A link means nothing outside its trip, so a dive that moves, or
/// leaves its trip, cannot keep one.
Future<void> clearForeignTripCylinderLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  String diveId, {
  required String? tripId,
  required int now,
}) async {
  final rows = await db
      .customSelect(
        '''
        SELECT t.id FROM dive_tanks t
        WHERE t.dive_id = ?1
          AND t.trip_cylinder_id IS NOT NULL
          AND (?2 IS NULL OR t.trip_cylinder_id NOT IN
               (SELECT id FROM trip_cylinders WHERE trip_id = ?2))
        ''',
        variables: [Variable<String>(diveId), Variable<String>(tripId)],
        readsFrom: {db.diveTanks, db.tripCylinders},
      )
      .get();
  if (rows.isEmpty) return;
  final ids = rows.map((r) => r.read<String>('id')).toList();
  await (db.update(db.diveTanks)..where((t) => t.id.isIn(ids))).write(
    const DiveTanksCompanion(tripCylinderId: Value(null)),
  );
  for (final id in ids) {
    await syncRepository.markRecordPending(
      entityType: 'diveTanks',
      recordId: id,
      localUpdatedAt: now,
    );
  }
}
```

- [ ] **Step 5: Thread the column through `dive_repository_impl.dart`**

Add the import at the top of the file's local-imports group:

```dart
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
```

Six sites, each adding one line next to `regulatorEquipmentId`:

1. createDive batch insert (1588-1596): after `regulatorEquipmentId: Value(tank.regulatorEquipmentId),` add `tripCylinderId: Value(tank.tripCylinderId),`.
2. updateDive existing-tank UPDATE (1882-1889): after `regulatorEquipmentId: Value(tank.regulatorEquipmentId),` add:
   ```dart
                // The slot link is user-authored like the regulator, so an
                // edit writes it; every rebuild site must carry it.
                tripCylinderId: Value(tank.tripCylinderId),
   ```
3. updateDive new-tank INSERT (1914-1920): add `tripCylinderId: Value(tank.tripCylinderId),`.
4. List mapper (3967-3973): after `regulatorEquipmentId: t.regulatorEquipmentId,` add `tripCylinderId: t.tripCylinderId,`.
5. Detail mapper (4390-4396): same line.
6. `_tankCompanion` (6626-6656): after the `regulatorEquipmentId:` line add:
   ```dart
    // The trip cylinder slot, kept out of templates for the same reason as
    // the registry link: only a restore writes it.
    tripCylinderId: withLink ? Value(t.tripCylinderId) : const Value.absent(),
   ```

Then the guard. In `createDive`, find the loop that marks the new tanks pending (search `entityType: 'diveTanks'` inside `createDive`, after the tank batch at 1588). Directly after that loop, still inside the method's transaction, add:

```dart
      // A link into another trip's slot means nothing on this dive.
      await clearForeignTripCylinderLinks(
        _db,
        _syncRepository,
        dive.id,
        tripId: dive.tripId,
        now: now,
      );
```

In `updateDive`, after the tank section (the new-tank INSERT at 1914-1920 and its pending marks), add the same six lines. `now` is the method's existing epoch-millis local; if the method names it differently, use that name.

- [ ] **Step 6: Carry the field through the other rebuild sites**

`lib/features/dive_log/data/services/bulk_dive_edit_service.dart`, in `_tanksFromRows` (352-383), after `regulatorEquipmentId: r.regulatorEquipmentId,` add `tripCylinderId: r.tripCylinderId,`.

`lib/features/dive_log/domain/services/sequential_tank_merge.dart`, in `_fold` (176-182), after the `regulatorEquipmentId:` lines add `tripCylinderId: earlier.tripCylinderId ?? later.tripCylinderId,`.

`lib/features/dive_log/presentation/widgets/tank_editor.dart`, in `_notifyChange` (333-357), after `regulatorEquipmentId: _regulatorEquipmentId,` add:

```dart
        // The slot link is carried, not edited, here; the picker that sets it
        // arrives with the board (PR 3 of #2325). Dropping it would let
        // updateDive wipe it on the next save.
        tripCylinderId: widget.tank.tripCylinderId,
```

`lib/core/services/sync/sync_service.dart`, in `parentRefs['diveTanks']` (2497-2504), after the `regulatorEquipmentId` entry add:

```dart
      // v228: the trip cylinder slot; nullable, so a slot the peer never
      // sent, or has deleted, only clears the link.
      (field: 'tripCylinderId', parent: 'tripCylinders', nullable: true),
```

`lib/core/services/sync/conflict_reference.dart`, in `_defaultTargets` after `'tripId': 'trips',` (line 99) add `'tripCylinderId': 'tripCylinders',`.

- [ ] **Step 7: Run the repository test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_tank_trip_cylinder_link_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 8: Write the failing tank editor test**

Create `test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart`. Copy the `_PresetListNotifier` class, the `_apeks` constant, the `_reload` provider and the `_pump` helper verbatim from `test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart` lines 1-100 (same imports), then add:

```dart
void main() {
  testWidgets('an edit keeps the trip cylinder link', (tester) async {
    DiveTank? changed;
    await _pump(
      tester,
      equipment: const [_apeks],
      tank: const DiveTank(id: 'tank-1', tripCylinderId: 'slot-1'),
      onChanged: (t) => changed = t,
    );

    // Any edit rebuilds the tank field by field; picking a regulator is the
    // one edit this editor already has a keyed control for.
    await tester.tap(find.byKey(const Key('tank-regulator-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apeks XTX').last);
    await tester.pumpAndSettle();

    expect(changed?.regulatorEquipmentId, 'reg-a');
    expect(changed?.tripCylinderId, 'slot-1');
  });
}
```

- [ ] **Step 9: Run the widget test**

Run: `flutter test test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart`
Expected: PASS (Step 6 already carries the field). If it fails on `tripCylinderId` being null, `_notifyChange` is missing the line from Step 6.

- [ ] **Step 10: Run the neighbouring suites**

Run: `flutter test test/features/dive_log/data/repositories test/features/dive_log/domain/services test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart`
Expected: PASS, except `sync_parent_refs_completeness_test` may now report `diveTanks.tripCylinderId -> tripCylinders` only if `trip_cylinders` is already in its `deletableParents`; it is not yet, so expect PASS. Task 4 adds the parent and the two new entities.

- [ ] **Step 11: Format and commit**

```bash
dart format .
git add lib/features/dive_log lib/core/services/sync/sync_service.dart lib/core/services/sync/conflict_reference.dart test/features/dive_log
git commit -m "feat(dive-log): carry the trip cylinder link on dive tanks (#2325)"
```

---

### Task 4: Sync registration for `tripCylinders` and `tripCylinderEvents`

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart:54` (`hlcTargets`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (SyncData field 290, constructor 386, `toJson` 477, `fromJson` 569, `_baseTables` 919, `_buildSyncData` 1922, export methods after 6939, `fetchRecord` 2498, `fetchRecords` 2932, `upsertRecord` 3834, `upsertRecords` 4709, `recordIdsFor` 5406, `_syncTableFor` 5789, `deleteRecord` 6152)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` after the `equipment` entry at 1357, `entityHasUpdatedAt` 2328, `parentRefs` 2601)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` line 34, `deletableParents` 121-139)
- Test: `test/core/services/sync/trip_cylinders_sync_test.dart`

**Interfaces:**
- Consumes: Task 1's Drift tables and data classes.
- Produces: entity types `tripCylinders` and `tripCylinderEvents` known to every sync path; `SyncData.tripCylinders` and `SyncData.tripCylinderEvents`.

- [ ] **Step 1: Write the failing per-entity sync test**

Create `test/core/services/sync/trip_cylinders_sync_test.dart`:

```dart
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// The two trip cylinder entities (v228, issue #2325) through every sync
/// path a trip child takes: fetch, upsert, ids, delete, delta export,
/// registration, and the SQLite actions a peer's delete relies on.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 'trip-1',
            name: 'Bonaire',
            startDate: 0,
            endDate: 0,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.tripCylinders)
        .insert(
          TripCylindersCompanion.insert(
            id: 'slot-1',
            tripId: 'trip-1',
            label: const Value('Truck 1'),
            volume: const Value(11.1),
            workingPressure: const Value(207.0),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.tripCylinderEvents)
        .insert(
          TripCylinderEventsCompanion.insert(
            id: 'fill-1',
            tripCylinderId: 'slot-1',
            kind: 'fill',
            occurredAt: 1000,
            bottleLabel: const Value('14'),
            pressure: const Value(200.0),
            o2Percent: const Value(32.0),
            analyzedO2: const Value(31.6),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('tripCylinders export, fetch, upsert, and delete round-trip', () async {
    final record = await serializer.fetchRecord('tripCylinders', 'slot-1');
    expect(record, isNotNull);
    expect(record!['label'], 'Truck 1');
    expect(record['volume'], 11.1);

    await serializer.upsertRecord('tripCylinders', {
      ...record,
      'label': 'Truck A',
      'updatedAt': 2,
    });
    final merged = await serializer.fetchRecord('tripCylinders', 'slot-1');
    expect(merged!['label'], 'Truck A');

    expect(await serializer.recordIdsFor('tripCylinders'), contains('slot-1'));

    await serializer.deleteRecord('tripCylinders', 'slot-1');
    expect(await serializer.fetchRecord('tripCylinders', 'slot-1'), isNull);
  });

  test('tripCylinderEvents export, fetch, upsert, and delete round-trip', () async {
    final record = await serializer.fetchRecord('tripCylinderEvents', 'fill-1');
    expect(record, isNotNull);
    expect(record!['kind'], 'fill');
    expect(record['analyzedO2'], 31.6);
    expect(record['bottleLabel'], '14');

    await serializer.upsertRecord('tripCylinderEvents', {
      ...record,
      'analyzedO2': 31.8,
      'updatedAt': 2,
    });
    final merged = await serializer.fetchRecord('tripCylinderEvents', 'fill-1');
    expect(merged!['analyzedO2'], 31.8);

    expect(
      await serializer.recordIdsFor('tripCylinderEvents'),
      contains('fill-1'),
    );

    await serializer.deleteRecord('tripCylinderEvents', 'fill-1');
    expect(await serializer.fetchRecord('tripCylinderEvents', 'fill-1'), isNull);
  });

  test('a peer row with the columns this build knows applies without the rest', () async {
    // A 228 peer sends every column; the merge fills NOT NULL defaults for
    // any it leaves out (_withSchemaDefaults), so a minimal record applies.
    await serializer.upsertRecord('tripCylinders', {
      'id': 'slot-2',
      'tripId': 'trip-1',
      'createdAt': 3,
      'updatedAt': 3,
    });
    final row = await (db.select(
      db.tripCylinders,
    )..where((t) => t.id.equals('slot-2'))).getSingle();
    expect(row.label, '');
    expect(row.sortOrder, 0);
    expect(row.notes, '');
  });

  test('the delta export filters on each row own hlc', () async {
    await (db.update(db.tripCylinders)..where((t) => t.id.equals('slot-1')))
        .write(
          const TripCylindersCompanion(
            hlc: Value('2026-08-16T00:00:00.000-0000'),
          ),
        );
    await (db.update(
      db.tripCylinderEvents,
    )..where((t) => t.id.equals('fill-1'))).write(
      const TripCylinderEventsCompanion(
        hlc: Value('2026-08-16T00:00:00.000-0000'),
      ),
    );

    Future<(int, int)> counts(String? watermark) async {
      final payload = await serializer.exportChangeset(
        deviceId: 'device-1',
        hlcWatermark: watermark,
        deletions: const [],
      );
      return (
        payload.data.tripCylinders.length,
        payload.data.tripCylinderEvents.length,
      );
    }

    expect(await counts(null), (1, 1));
    expect(await counts('2026-08-17T00:00:00.000-0000'), (0, 0));
    expect(await counts('2026-08-15T00:00:00.000-0000'), (1, 1));
  });

  test('deleting a slot record cascades its ledger and clears tank links', () async {
    // What a peer's tombstone does on arrival: SQLite's own actions.
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 2000,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't1',
            diveId: 'd1',
          ).copyWith(tripCylinderId: const Value('slot-1')),
        );

    await serializer.deleteRecord('tripCylinders', 'slot-1');

    expect(await serializer.fetchRecord('tripCylinderEvents', 'fill-1'), isNull);
    final tank = await db
        .customSelect(
          'SELECT trip_cylinder_id FROM dive_tanks WHERE id = ?',
          variables: [Variable<String>('t1')],
        )
        .getSingle();
    expect(tank.readNullable<String>('trip_cylinder_id'), isNull);
  });

  test('both entities are registered as hlc targets', () {
    // An omission here is silent: _stampHlc no-ops on an unknown entity
    // type, the column stays NULL, and the delta export excludes the row
    // from every changeset forever.
    expect(SyncRepository.hlcTargets['tripCylinders']!.table, 'trip_cylinders');
    expect(
      SyncRepository.hlcTargets['tripCylinderEvents']!.table,
      'trip_cylinder_events',
    );
  });

  test('both entities carry an updatedAt flag and their parent refs', () {
    expect(SyncService.entityHasUpdatedAt['tripCylinders'], isTrue);
    expect(SyncService.entityHasUpdatedAt['tripCylinderEvents'], isTrue);

    final slotRefs = SyncService.parentRefs['tripCylinders']!;
    expect(
      slotRefs,
      containsAll(const [
        (field: 'tripId', parent: 'trips', nullable: false),
        (field: 'equipmentId', parent: 'equipment', nullable: true),
      ]),
    );
    final eventRefs = SyncService.parentRefs['tripCylinderEvents']!;
    expect(
      eventRefs,
      containsAll(const [
        (field: 'tripCylinderId', parent: 'tripCylinders', nullable: false),
        (field: 'diveCenterId', parent: 'diveCenters', nullable: true),
      ]),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/services/sync/trip_cylinders_sync_test.dart`
Expected: FAIL. `fetchRecord('tripCylinders', ...)` returns null or throws for an unknown entity type; `payload.data.tripCylinders` does not compile.

- [ ] **Step 3: Register the hlc targets**

In `lib/core/data/repositories/sync_repository.dart`, after line 54 (`'tripDayWeather': ...`), add:

```dart
    'tripCylinders': (table: 'trip_cylinders', pk: 'id'),
    'tripCylinderEvents': (table: 'trip_cylinder_events', pk: 'id'),
```

- [ ] **Step 4: Register in the serializer, eleven sites**

In `lib/core/services/sync/sync_data_serializer.dart`, at each site add the two entries right after the `tripDayWeather` entry, keeping the same relative order everywhere (the base-publish parity test requires `_baseTables` to match `toJson` order):

1. Fields (after line 290):
   ```dart
  final List<Map<String, dynamic>> tripCylinders;
  final List<Map<String, dynamic>> tripCylinderEvents;
   ```
2. Constructor (after line 386):
   ```dart
    this.tripCylinders = const [],
    this.tripCylinderEvents = const [],
   ```
3. `toJson` (after line 477):
   ```dart
    'tripCylinders': tripCylinders,
    'tripCylinderEvents': tripCylinderEvents,
   ```
4. `fromJson` (after line 569):
   ```dart
      tripCylinders: _parseList(json['tripCylinders']),
      tripCylinderEvents: _parseList(json['tripCylinderEvents']),
   ```
5. `_baseTables` (after line 919):
   ```dart
    (key: 'tripCylinders', table: _db.tripCylinders, blob: false, full: null),
    (
      key: 'tripCylinderEvents',
      table: _db.tripCylinderEvents,
      blob: false,
      full: null,
    ),
   ```
6. `_buildSyncData` (after line 1922):
   ```dart
      tripCylinders: await _safeExport(
        'tripCylinders',
        () => _exportTripCylinders(hlcSince),
      ),
      tripCylinderEvents: await _safeExport(
        'tripCylinderEvents',
        () => _exportTripCylinderEvents(hlcSince),
      ),
   ```
7. Export methods, after `_exportTripDayWeather` (line 6939):
   ```dart

  Future<List<Map<String, dynamic>>> _exportTripCylinders(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.tripCylinders);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> _exportTripCylinderEvents(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.tripCylinderEvents);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
   ```
8. `fetchRecord` (after line 2498):
   ```dart
      case 'tripCylinders':
        final row = await (_db.select(
          _db.tripCylinders,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'tripCylinderEvents':
        final row = await (_db.select(
          _db.tripCylinderEvents,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
   ```
9. `fetchRecords` (after line 2932):
   ```dart
      case 'tripCylinders':
        final rows = await (_db.select(
          _db.tripCylinders,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
      case 'tripCylinderEvents':
        final rows = await (_db.select(
          _db.tripCylinderEvents,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
   ```
10. `upsertRecord` (after line 3834):
    ```dart
      case 'tripCylinders':
        await _db
            .into(_db.tripCylinders)
            .insertOnConflictUpdate(
              TripCylinderRow.fromJson(data).toCompanion(false),
            );
        return;
      case 'tripCylinderEvents':
        await _db
            .into(_db.tripCylinderEvents)
            .insertOnConflictUpdate(
              TripCylinderEventRow.fromJson(data).toCompanion(false),
            );
        return;
    ```
11. `upsertRecords` (after line 4709):
    ```dart
      case 'tripCylinders':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.tripCylinders,
            records
                .map((r) => TripCylinderRow.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
      case 'tripCylinderEvents':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.tripCylinderEvents,
            records
                .map((r) => TripCylinderEventRow.fromJson(r).toCompanion(false))
                .toList(),
          ),
        );
        return;
    ```
12. `recordIdsFor` (after line 5406):
    ```dart
      case 'tripCylinders':
        return plain(_db.tripCylinders, _db.tripCylinders.id);
      case 'tripCylinderEvents':
        return plain(_db.tripCylinderEvents, _db.tripCylinderEvents.id);
    ```
13. `_syncTableFor` (after line 5789):
    ```dart
      case 'tripCylinders':
        return _db.tripCylinders;
      case 'tripCylinderEvents':
        return _db.tripCylinderEvents;
    ```
14. `deleteRecord` (after line 6152):
    ```dart
      case 'tripCylinders':
        await (_db.delete(
          _db.tripCylinders,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'tripCylinderEvents':
        await (_db.delete(
          _db.tripCylinderEvents,
        )..where((t) => t.id.equals(recordId))).go();
        return;
    ```

`_withSchemaDefaults` needs nothing: it discovers the table through `_syncTableFor`.

- [ ] **Step 5: Register in the sync service**

In `lib/core/services/sync/sync_service.dart`:

1. `mergeOrder`: after the `equipment` entry (line 1357) add, so each child follows every parent it references (trips, equipment, dive centers) and precedes dives:
   ```dart
          // Trip cylinder slots reference trips and equipment; their ledger
          // references the slots and dive centers. Both before dives, whose
          // tanks link the slots.
          (
            type: 'tripCylinders',
            records: data.tripCylinders,
            hasUpdatedAt: true,
          ),
          (
            type: 'tripCylinderEvents',
            records: data.tripCylinderEvents,
            hasUpdatedAt: true,
          ),
   ```
2. `entityHasUpdatedAt` (after line 2328):
   ```dart
    'tripCylinders': true,
    'tripCylinderEvents': true,
   ```
3. `parentRefs` (after line 2601):
   ```dart
    'tripCylinders': [
      (field: 'tripId', parent: 'trips', nullable: false),
      (field: 'equipmentId', parent: 'equipment', nullable: true),
    ],
    'tripCylinderEvents': [
      (field: 'tripCylinderId', parent: 'tripCylinders', nullable: false),
      (field: 'diveCenterId', parent: 'diveCenters', nullable: true),
    ],
   ```

- [ ] **Step 6: Update the hand-maintained completeness lists**

In `test/core/services/sync/sync_parent_refs_completeness_test.dart`:
- In `syncedTables`, after line 34 (`'trip_day_weather': 'tripDayWeather',`) add:
  ```dart
    'trip_cylinders': 'tripCylinders',
    'trip_cylinder_events': 'tripCylinderEvents',
  ```
- In `deletableParents` (lines 121-139) add `'trip_cylinders',` so the two foreign keys into it (`dive_tanks.trip_cylinder_id`, `trip_cylinder_events.trip_cylinder_id`) are checked against `parentRefs`.

- [ ] **Step 7: Run the new test and the pinning tests**

Run: `flutter test test/core/services/sync/trip_cylinders_sync_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_adopt_streaming_parity_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/base_publish_streaming_parity_test.dart test/core/services/sync/cross_version_roundtrip_test.dart test/core/services/sync/trip_day_weather_sync_test.dart`
Expected: PASS. A failure in `base_publish_streaming_parity_test` means `_baseTables` order differs from `toJson` order; a failure in `sync_parent_refs_completeness_test` names the exact missing ref.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add lib/core/data/repositories/sync_repository.dart lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart test/core/services/sync/trip_cylinders_sync_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart
git commit -m "feat(sync): register trip cylinder slots and events (#2325)"
```

---

### Task 5: `TripCylinderRepository`

**Files:**
- Create: `lib/features/trips/data/repositories/trip_cylinder_repository.dart`
- Test: `test/features/trips/data/repositories/trip_cylinder_repository_test.dart`

**Interfaces:**
- Consumes: Task 2 entities; Task 3's `clearTripCylinderLinks`; `SyncRepository.markRecordPending({entityType, recordId, localUpdatedAt})` and `logDeletion({entityType, recordId})`.
- Produces: `class TripCylinderRepository` with `Stream<void> watchTripCylinderChanges()`, `Future<List<TripCylinder>> getCylindersForTrip(String tripId)`, `Future<TripCylinder?> getCylinderById(String id)`, `Future<TripCylinder> createCylinder(TripCylinder cylinder)`, `Future<void> updateCylinder(TripCylinder cylinder)`, `Future<void> deleteCylinder(String id)`, `Future<void> deleteByTripId(String tripId)`, `Future<Map<String, List<TripCylinderEvent>>> getEventsForTrip(String tripId)`, `Future<List<TripCylinderEvent>> getEventsForCylinder(String cylinderId)`, `Future<TripCylinderEvent> createEvent(TripCylinderEvent event)`, `Future<void> updateEvent(TripCylinderEvent event)`, `Future<void> deleteEvent(String id)`, `Future<Map<String, List<TripCylinderTankUse>>> getTankUsesForTrip(String tripId)`, `Future<int> countLinkedDives(String cylinderId)`.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/trips/data/repositories/trip_cylinder_repository_test.dart`:

```dart
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TripCylinderRepository repository;
  late String tripId;
  late String otherTripId;

  final at = DateTime.utc(2026, 3, 9, 8, 0);

  Trip trip(String name) {
    final now = DateTime.now();
    return Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 14),
      createdAt: now,
      updatedAt: now,
    );
  }

  TripCylinder slot({String label = 'Truck 1', int sortOrder = 0}) =>
      TripCylinder(
        id: '',
        tripId: tripId,
        label: label,
        volume: 11.1,
        workingPressure: 207,
        material: TankMaterial.aluminum,
        presetName: 'al80',
        sortOrder: sortOrder,
        createdAt: at,
        updatedAt: at,
      );

  TripCylinderEvent fill(String cylinderId, {DateTime? when, String? kind}) =>
      TripCylinderEvent(
        id: '',
        tripCylinderId: cylinderId,
        kind: TripCylinderEventKind.fill,
        occurredAt: when ?? at,
        bottleLabel: '14',
        pressure: 200,
        o2Percent: 32,
        analyzedO2: 31.6,
        cost: 12.5,
        currency: 'USD',
        createdAt: at,
        updatedAt: at,
      );

  Future<int> pendingCountFor(String entityType, String recordId) async {
    final row = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? "
          "AND record_id = ? AND sync_status = 'pending'",
          variables: [Variable<String>(entityType), Variable<String>(recordId)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<int> tombstonesFor(String entityType, String recordId) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM deletion_log '
          'WHERE entity_type = ? AND record_id = ?',
          variables: [Variable<String>(entityType), Variable<String>(recordId)],
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<void> insertDiveWithTank({
    required String diveId,
    required String tankId,
    required int entryMillis,
    required String cylinderId,
    double? start,
    double? end,
    double o2 = 32,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: entryMillis,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: tankId, diveId: diveId).copyWith(
            tripCylinderId: Value(cylinderId),
            startPressure: Value(start),
            endPressure: Value(end),
            o2Percent: Value(o2),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    repository = TripCylinderRepository();
    final trips = TripRepository();
    tripId = (await trips.createTrip(trip('Bonaire'))).id;
    otherTripId = (await trips.createTrip(trip('Curacao'))).id;
  });

  tearDown(tearDownTestDatabase);

  group('slots', () {
    test('create mints an id, stages the row and reads back in board order', () async {
      final second = await repository.createCylinder(
        slot(label: 'Truck 2', sortOrder: 1),
      );
      final first = await repository.createCylinder(slot(label: 'Truck 1'));

      expect(first.id, isNotEmpty);
      expect(await pendingCountFor('tripCylinders', first.id), 1);

      final listed = await repository.getCylindersForTrip(tripId);
      expect(listed.map((c) => c.label), ['Truck 1', 'Truck 2']);
      expect(listed.first.volume, 11.1);
      expect(listed.first.material, TankMaterial.aluminum);
      expect(listed.first.presetName, 'al80');
      expect(second.tripId, tripId);
      expect(await repository.getCylindersForTrip(otherTripId), isEmpty);
    });

    test('update rewrites the editable columns', () async {
      final created = await repository.createCylinder(slot());
      await repository.updateCylinder(
        created.copyWith(label: 'Truck A', volume: 12.2, notes: 'DIN valve'),
      );
      final read = await repository.getCylinderById(created.id);
      expect(read!.label, 'Truck A');
      expect(read.volume, 12.2);
      expect(read.notes, 'DIN valve');
      expect(read.workingPressure, 207);
    });

    test('an unknown stored material reads as null, never a throw', () async {
      final created = await repository.createCylinder(slot());
      await db.customUpdate(
        "UPDATE trip_cylinders SET material = 'titanium' WHERE id = ?",
        variables: [Variable<String>(created.id)],
      );
      final read = await repository.getCylinderById(created.id);
      expect(read!.material, isNull);
    });

    test('delete tombstones the slot and its ledger and clears tank links', () async {
      final created = await repository.createCylinder(slot());
      final event = await repository.createEvent(fill(created.id));
      await insertDiveWithTank(
        diveId: 'd1',
        tankId: 't1',
        entryMillis: at.millisecondsSinceEpoch + 3600000,
        cylinderId: created.id,
        start: 200,
        end: 60,
      );

      await repository.deleteCylinder(created.id);

      expect(await repository.getCylinderById(created.id), isNull);
      expect(await repository.getEventsForCylinder(created.id), isEmpty);
      expect(await tombstonesFor('tripCylinders', created.id), 1);
      expect(await tombstonesFor('tripCylinderEvents', event.id), 1);

      // The tank keeps everything but the link, and is staged so a peer
      // learns of the cleared link rather than relying on its own cascade.
      final tank = await db
          .customSelect(
            'SELECT trip_cylinder_id, end_pressure, o2_percent '
            "FROM dive_tanks WHERE id = 't1'",
          )
          .getSingle();
      expect(tank.readNullable<String>('trip_cylinder_id'), isNull);
      expect(tank.read<double>('end_pressure'), 60);
      expect(tank.read<double>('o2_percent'), 32);
      expect(await pendingCountFor('diveTanks', 't1'), 1);
    });

    test('deleteByTripId removes only that trip slots', () async {
      await repository.createCylinder(slot());
      await repository.createCylinder(
        slot().copyWith(tripId: otherTripId, label: 'Other'),
      );

      await repository.deleteByTripId(tripId);

      expect(await repository.getCylindersForTrip(tripId), isEmpty);
      expect(await repository.getCylindersForTrip(otherTripId), hasLength(1));
    });
  });

  group('events', () {
    test('create, read grouped by slot in time order, update, delete', () async {
      final a = await repository.createCylinder(slot(label: 'A'));
      final b = await repository.createCylinder(slot(label: 'B', sortOrder: 1));
      final later = await repository.createEvent(
        fill(a.id, when: at.add(const Duration(hours: 5))),
      );
      final earlier = await repository.createEvent(fill(a.id));
      await repository.createEvent(fill(b.id));

      expect(await pendingCountFor('tripCylinderEvents', earlier.id), 1);

      final grouped = await repository.getEventsForTrip(tripId);
      expect(grouped.keys, containsAll([a.id, b.id]));
      expect(grouped[a.id]!.map((e) => e.id), [earlier.id, later.id]);
      expect(grouped[a.id]!.first.analyzedO2, 31.6);
      expect(grouped[a.id]!.first.cost, 12.5);
      expect(grouped[a.id]!.first.currency, 'USD');
      expect(grouped[a.id]!.first.occurredAt, at);
      expect(grouped[a.id]!.first.occurredAt.isUtc, isTrue);

      await repository.updateEvent(later.copyWith(analyzedO2: 31.9, note: 'reanalyzed'));
      final forA = await repository.getEventsForCylinder(a.id);
      expect(forA.last.analyzedO2, 31.9);
      expect(forA.last.note, 'reanalyzed');

      await repository.deleteEvent(later.id);
      expect(await repository.getEventsForCylinder(a.id), hasLength(1));
      expect(await tombstonesFor('tripCylinderEvents', later.id), 1);
    });

    test('an unknown stored kind reads as an adjustment', () async {
      final a = await repository.createCylinder(slot());
      final e = await repository.createEvent(fill(a.id));
      await db.customUpdate(
        "UPDATE trip_cylinder_events SET kind = 'swap' WHERE id = ?",
        variables: [Variable<String>(e.id)],
      );
      final read = await repository.getEventsForCylinder(a.id);
      expect(read.single.kind, TripCylinderEventKind.adjustment);
      expect(read.single.pressure, 200);
    });

    test('a slot from another trip is not in this trip ledger', () async {
      final other = await repository.createCylinder(
        slot().copyWith(tripId: otherTripId),
      );
      await repository.createEvent(fill(other.id));
      expect(await repository.getEventsForTrip(tripId), isEmpty);
    });
  });

  group('tank uses', () {
    test('returns lean facts per slot in entry order, skipping other trips', () async {
      final a = await repository.createCylinder(slot(label: 'A'));
      final other = await repository.createCylinder(
        slot().copyWith(tripId: otherTripId),
      );
      final t0 = at.millisecondsSinceEpoch;
      await insertDiveWithTank(
        diveId: 'd2',
        tankId: 't2',
        entryMillis: t0 + 7200000,
        cylinderId: a.id,
        start: 200,
        end: 70,
        o2: 32,
      );
      await insertDiveWithTank(
        diveId: 'd1',
        tankId: 't1',
        entryMillis: t0 + 3600000,
        cylinderId: a.id,
        start: 200,
        o2: 21,
      );
      await insertDiveWithTank(
        diveId: 'd3',
        tankId: 't3',
        entryMillis: t0,
        cylinderId: other.id,
      );

      final uses = await repository.getTankUsesForTrip(tripId);
      expect(uses.keys, [a.id]);
      final forA = uses[a.id]!;
      expect(forA.map((u) => u.tankId), ['t1', 't2']);
      expect(forA.first.entryTime, DateTime.utc(2026, 3, 9, 9, 0));
      expect(forA.first.entryTime.isUtc, isTrue);
      expect(forA.first.endPressure, isNull);
      expect(forA.first.gasMix, const GasMix());
      expect(forA.last.endPressure, 70);
      expect(forA.last.gasMix.o2, 32);
      expect(forA.last.diveId, 'd2');

      expect(await repository.countLinkedDives(a.id), 2);
      expect(await repository.countLinkedDives(other.id), 0);
    });
  });

  test('the change tick fires on a slot write', () async {
    final fired = repository.watchTripCylinderChanges().first;
    await repository.createCylinder(slot());
    await expectLater(fired, completes);
  });
}
```

If `GasMix` does not implement `==`, replace `expect(forA.first.gasMix, const GasMix())` with `expect(forA.first.gasMix.o2, 21)`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/trips/data/repositories/trip_cylinder_repository_test.dart`
Expected: FAIL to compile, the repository does not exist.

- [ ] **Step 3: Write the repository**

Create `lib/features/trips/data/repositories/trip_cylinder_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart'
    as domain;
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart'
    as domain;
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart'
    show TripCylinderTankUse;

/// Reads and writes the cylinder slots of a trip and their ledger, and reads
/// the lean facts the state fold needs from the dive log.
///
/// Slots and events are their own synced entities (`tripCylinders`,
/// `tripCylinderEvents`). A dive's consumption is the
/// `dive_tanks.trip_cylinder_id` link, which belongs to the dive: this
/// repository only ever clears it, when the slot it points at goes.
class TripCylinderRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(TripCylinderRepository);

  /// Emits when anything the board reads changes: the slots, their ledger,
  /// or the dive tanks and dives that consume them. A sync pull that
  /// rewrites a tank row never touches the dives row, so dive_tanks is
  /// watched on its own.
  Stream<void> watchTripCylinderChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.tripCylinders),
      TableUpdateQuery.onTable(_db.tripCylinderEvents),
      TableUpdateQuery.onTable(_db.diveTanks),
      TableUpdateQuery.onTable(_db.dives),
    ]),
  );

  // ---------------------------------------------------------------- slots

  /// The slots of a trip in board order.
  Future<List<domain.TripCylinder>> getCylindersForTrip(String tripId) async {
    try {
      final rows =
          await (_db.select(_db.tripCylinders)
                ..where((t) => t.tripId.equals(tripId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.sortOrder),
                  (t) => OrderingTerm.asc(t.createdAt),
                ]))
              .get();
      return rows.map(_mapCylinder).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read cylinders for trip: $tripId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<domain.TripCylinder?> getCylinderById(String id) async {
    final row = await (_db.select(
      _db.tripCylinders,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapCylinder(row);
  }

  /// Inserts a slot. An empty id is minted; timestamps are set here.
  Future<domain.TripCylinder> createCylinder(
    domain.TripCylinder cylinder,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = cylinder.id.isEmpty ? _uuid.v4() : cylinder.id;
      await _db
          .into(_db.tripCylinders)
          .insert(
            TripCylindersCompanion.insert(
              id: id,
              tripId: cylinder.tripId,
              equipmentId: Value(cylinder.equipmentId),
              label: Value(cylinder.label),
              volume: Value(cylinder.volume),
              workingPressure: Value(cylinder.workingPressure),
              material: Value(cylinder.material?.name),
              presetName: Value(cylinder.presetName),
              sortOrder: Value(cylinder.sortOrder),
              notes: Value(cylinder.notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'tripCylinders',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      final stamp = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true);
      return cylinder.copyWith(id: id, createdAt: stamp, updatedAt: stamp);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create cylinder for trip: ${cylinder.tripId}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Rewrites the editable columns of a slot. The trip is not one of them.
  Future<void> updateCylinder(domain.TripCylinder cylinder) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.tripCylinders,
      )..where((t) => t.id.equals(cylinder.id))).write(
        TripCylindersCompanion(
          equipmentId: Value(cylinder.equipmentId),
          label: Value(cylinder.label),
          volume: Value(cylinder.volume),
          workingPressure: Value(cylinder.workingPressure),
          material: Value(cylinder.material?.name),
          presetName: Value(cylinder.presetName),
          sortOrder: Value(cylinder.sortOrder),
          notes: Value(cylinder.notes),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tripCylinders',
        recordId: cylinder.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update cylinder: ${cylinder.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Deletes a slot, its ledger, and the link on every tank that used it.
  /// The tanks keep their copied specs and mix; only the link goes, and they
  /// are staged so a peer learns of it rather than relying on its own
  /// ON DELETE SET NULL. Every removed row is tombstoned.
  Future<void> deleteCylinder(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        await clearTripCylinderLinks(_db, _syncRepository, [id], now: now);
        final events = await (_db.select(
          _db.tripCylinderEvents,
        )..where((t) => t.tripCylinderId.equals(id))).get();
        await (_db.delete(
          _db.tripCylinderEvents,
        )..where((t) => t.tripCylinderId.equals(id))).go();
        for (final event in events) {
          await _syncRepository.logDeletion(
            entityType: 'tripCylinderEvents',
            recordId: event.id,
          );
        }
        await (_db.delete(
          _db.tripCylinders,
        )..where((t) => t.id.equals(id))).go();
        await _syncRepository.logDeletion(
          entityType: 'tripCylinders',
          recordId: id,
        );
      });
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to delete cylinder: $id', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Every slot of a trip, for `TripRepository.deleteTrip`.
  Future<void> deleteByTripId(String tripId) async {
    final rows = await (_db.select(
      _db.tripCylinders,
    )..where((t) => t.tripId.equals(tripId))).get();
    for (final row in rows) {
      await deleteCylinder(row.id);
    }
    if (rows.isNotEmpty) {
      _log.info('Deleted ${rows.length} cylinders for trip: $tripId');
    }
  }

  // --------------------------------------------------------------- events

  /// The whole ledger of a trip, keyed by slot id, each list in time order.
  Future<Map<String, List<domain.TripCylinderEvent>>> getEventsForTrip(
    String tripId,
  ) async {
    final events = _db.tripCylinderEvents;
    final slots = _db.tripCylinders;
    final rows =
        await (_db.select(events).join([
                innerJoin(slots, slots.id.equalsExp(events.tripCylinderId)),
              ])
              ..where(slots.tripId.equals(tripId))
              ..orderBy([OrderingTerm.asc(events.occurredAt)]))
            .get();
    final out = <String, List<domain.TripCylinderEvent>>{};
    for (final row in rows) {
      final event = _mapEvent(row.readTable(events));
      (out[event.tripCylinderId] ??= []).add(event);
    }
    return out;
  }

  Future<List<domain.TripCylinderEvent>> getEventsForCylinder(
    String cylinderId,
  ) async {
    final rows =
        await (_db.select(_db.tripCylinderEvents)
              ..where((t) => t.tripCylinderId.equals(cylinderId))
              ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
            .get();
    return rows.map(_mapEvent).toList();
  }

  Future<domain.TripCylinderEvent> createEvent(
    domain.TripCylinderEvent event,
  ) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = event.id.isEmpty ? _uuid.v4() : event.id;
      await _db
          .into(_db.tripCylinderEvents)
          .insert(
            TripCylinderEventsCompanion.insert(
              id: id,
              tripCylinderId: event.tripCylinderId,
              kind: event.kind.name,
              occurredAt: event.occurredAt.millisecondsSinceEpoch,
              bottleLabel: Value(event.bottleLabel),
              pressure: Value(event.pressure),
              o2Percent: Value(event.o2Percent),
              hePercent: Value(event.hePercent),
              analyzedO2: Value(event.analyzedO2),
              analyzedHe: Value(event.analyzedHe),
              diveCenterId: Value(event.diveCenterId),
              cost: Value(event.cost),
              currency: Value(event.currency),
              isPackage: Value(event.isPackage),
              note: Value(event.note),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'tripCylinderEvents',
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      final stamp = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true);
      return event.copyWith(id: id, createdAt: stamp, updatedAt: stamp);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create event for cylinder: ${event.tripCylinderId}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateEvent(domain.TripCylinderEvent event) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.tripCylinderEvents,
      )..where((t) => t.id.equals(event.id))).write(
        TripCylinderEventsCompanion(
          kind: Value(event.kind.name),
          occurredAt: Value(event.occurredAt.millisecondsSinceEpoch),
          bottleLabel: Value(event.bottleLabel),
          pressure: Value(event.pressure),
          o2Percent: Value(event.o2Percent),
          hePercent: Value(event.hePercent),
          analyzedO2: Value(event.analyzedO2),
          analyzedHe: Value(event.analyzedHe),
          diveCenterId: Value(event.diveCenterId),
          cost: Value(event.cost),
          currency: Value(event.currency),
          isPackage: Value(event.isPackage),
          note: Value(event.note),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: 'tripCylinderEvents',
        recordId: event.id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to update event: ${event.id}', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await (_db.delete(
        _db.tripCylinderEvents,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'tripCylinderEvents',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error('Failed to delete event: $id', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ----------------------------------------------------------- tank uses

  /// The dive tanks linked to a trip's slots, as the lean facts the state
  /// fold needs: no profile, no gear, no full dive. Keyed by slot id, each
  /// list in entry order.
  Future<Map<String, List<TripCylinderTankUse>>> getTankUsesForTrip(
    String tripId,
  ) async {
    final rows = await _db
        .customSelect(
          '''
          -- stats-scope-exempt: the board counts every dive on the trip, the
          -- ones excluded from statistics included, as the trip's dive list does
          SELECT t.id AS tank_id, t.dive_id, d.dive_date_time,
                 t.start_pressure, t.end_pressure, t.o2_percent, t.he_percent,
                 t.trip_cylinder_id
          FROM dive_tanks t
          JOIN dives d ON d.id = t.dive_id
          WHERE t.trip_cylinder_id IN
                (SELECT id FROM trip_cylinders WHERE trip_id = ?)
          ORDER BY d.dive_date_time ASC, t.tank_order ASC
          ''',
          variables: [Variable.withString(tripId)],
          readsFrom: {_db.diveTanks, _db.dives, _db.tripCylinders},
        )
        .get();
    final out = <String, List<TripCylinderTankUse>>{};
    for (final r in rows) {
      final use = TripCylinderTankUse(
        tankId: r.read<String>('tank_id'),
        diveId: r.read<String>('dive_id'),
        entryTime: DateTime.fromMillisecondsSinceEpoch(
          r.read<int>('dive_date_time'),
          isUtc: true,
        ),
        startPressure: r.readNullable<double>('start_pressure'),
        endPressure: r.readNullable<double>('end_pressure'),
        gasMix: GasMix(
          o2: r.read<double>('o2_percent'),
          he: r.read<double>('he_percent'),
        ),
      );
      (out[r.read<String>('trip_cylinder_id')] ??= []).add(use);
    }
    return out;
  }

  /// Distinct dives that breathed from a slot, for the delete confirmation.
  Future<int> countLinkedDives(String cylinderId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(DISTINCT dive_id) AS n FROM dive_tanks '
          'WHERE trip_cylinder_id = ?',
          variables: [Variable.withString(cylinderId)],
          readsFrom: {_db.diveTanks},
        )
        .getSingle();
    return row.read<int>('n');
  }

  // -------------------------------------------------------------- mappers

  domain.TripCylinder _mapCylinder(TripCylinderRow r) => domain.TripCylinder(
    id: r.id,
    tripId: r.tripId,
    equipmentId: r.equipmentId,
    label: r.label,
    volume: r.volume,
    workingPressure: r.workingPressure,
    // A material this build does not know reads as unknown, not as a guess.
    material: r.material == null
        ? null
        : TankMaterial.values.where((m) => m.name == r.material).firstOrNull,
    presetName: r.presetName,
    sortOrder: r.sortOrder,
    notes: r.notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
  );

  domain.TripCylinderEvent _mapEvent(TripCylinderEventRow r) =>
      domain.TripCylinderEvent(
        id: r.id,
        tripCylinderId: r.tripCylinderId,
        kind: domain.tripCylinderEventKindFromName(r.kind),
        occurredAt: DateTime.fromMillisecondsSinceEpoch(
          r.occurredAt,
          isUtc: true,
        ),
        bottleLabel: r.bottleLabel,
        pressure: r.pressure,
        o2Percent: r.o2Percent,
        hePercent: r.hePercent,
        analyzedO2: r.analyzedO2,
        analyzedHe: r.analyzedHe,
        diveCenterId: r.diveCenterId,
        cost: r.cost,
        currency: r.currency,
        isPackage: r.isPackage,
        note: r.note,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt, isUtc: true),
      );
}
```

`firstOrNull` on an `Iterable` comes from `package:collection/collection.dart`; add that import if the analyzer asks for it.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/trips/data/repositories/trip_cylinder_repository_test.dart`
Expected: PASS, 11 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/data/repositories/trip_cylinder_repository.dart test/features/trips/data/repositories/trip_cylinder_repository_test.dart
git commit -m "feat(trips): trip cylinder repository (#2325)"
```

---

### Task 6: Deletion and trip-move paths

**Files:**
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (imports 1-18, `deleteTrip` 252-300, `assignDiveToTrip` 346-364, `removeDiveFromTrip` 366-384, `assignDivesToTrip` 467-507)
- Modify: `lib/features/divers/data/repositories/diver_delete_steps.dart:84-113` (`diverTripAndSiteSteps`)
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (Step 3 of `deleteDiverWithReassignment`, around line 654)
- Modify: `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart:658-673` (`clearedReferences`)
- Modify: `test/features/divers/data/repositories/diver_delete_tombstones_test.dart:174-236` (the trip children seeder)
- Test: `test/features/trips/data/repositories/trip_repository_cylinders_test.dart`

**Interfaces:**
- Consumes: Task 5's `TripCylinderRepository.deleteByTripId`; Task 3's `clearForeignTripCylinderLinks` and `clearTripCylinderLinks`; `deleteDiverRows` and `_idsOf` already in `diver_repository.dart`.
- Produces: nothing new; the invariants that a slot never outlives its trip and a link never outlives its trip.

- [ ] **Step 1: Write the failing trip repository test**

Create `test/features/trips/data/repositories/trip_repository_cylinders_test.dart`:

```dart
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';

import '../../../../helpers/test_database.dart';

/// A slot never outlives its trip, and a tank link never outlives the
/// dive's membership of that trip (issue #2325).
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late TripCylinderRepository cylinders;
  late String tripA;
  late String tripB;
  late String slotA;
  late String slotB;

  final at = DateTime.utc(2026, 3, 9, 8, 0);

  Trip trip(String name) {
    final now = DateTime.now();
    return Trip(
      id: '',
      name: name,
      startDate: DateTime(2026, 3, 8),
      endDate: DateTime(2026, 3, 14),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> insertDiveWithTank(String diveId, String tankId, {String? tripId, required String cylinderId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: at.millisecondsSinceEpoch,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: tankId,
            diveId: diveId,
          ).copyWith(tripCylinderId: Value(cylinderId), endPressure: const Value(60.0)),
        );
  }

  Future<String?> linkOf(String tankId) async => (await db
          .customSelect(
            'SELECT trip_cylinder_id FROM dive_tanks WHERE id = ?',
            variables: [Variable<String>(tankId)],
          )
          .getSingle())
      .readNullable<String>('trip_cylinder_id');

  Future<int> tombstonesFor(String entityType, String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log '
                'WHERE entity_type = ? AND record_id = ?',
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n');

  setUp(() async {
    db = await setUpTestDatabase();
    trips = TripRepository();
    cylinders = TripCylinderRepository();
    tripA = (await trips.createTrip(trip('Bonaire'))).id;
    tripB = (await trips.createTrip(trip('Curacao'))).id;
    slotA = (await cylinders.createCylinder(
      TripCylinder(id: '', tripId: tripA, label: 'A', createdAt: at, updatedAt: at),
    )).id;
    slotB = (await cylinders.createCylinder(
      TripCylinder(id: '', tripId: tripB, label: 'B', createdAt: at, updatedAt: at),
    )).id;
  });

  tearDown(tearDownTestDatabase);

  test('deleting a trip takes its slots, tombstones them and clears links', () async {
    await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);

    await trips.deleteTrip(tripA);

    expect(await cylinders.getCylindersForTrip(tripA), isEmpty);
    expect(await cylinders.getCylindersForTrip(tripB), hasLength(1));
    expect(await tombstonesFor('tripCylinders', slotA), 1);
    expect(await linkOf('t1'), isNull);
    // The dive itself survives, off the trip, with its tank data intact.
    final tank = await db
        .customSelect("SELECT end_pressure FROM dive_tanks WHERE id = 't1'")
        .getSingle();
    expect(tank.read<double>('end_pressure'), 60);
  });

  test('removing a dive from its trip drops its links', () async {
    await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);

    await trips.removeDiveFromTrip('d1');

    expect(await linkOf('t1'), isNull);
    expect(await cylinders.getCylindersForTrip(tripA), hasLength(1));
  });

  test('assigning a dive to another trip drops links into the old one', () async {
    await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);

    await trips.assignDiveToTrip('d1', tripB);

    expect(await linkOf('t1'), isNull);
  });

  test('assigning a dive to the trip its slot is on keeps the link', () async {
    // A dive that already carries a link into trip A, then is (re)assigned
    // to trip A: nothing to drop.
    await insertDiveWithTank('d1', 't1', tripId: null, cylinderId: slotA);

    await trips.assignDiveToTrip('d1', tripA);

    expect(await linkOf('t1'), slotA);
  });

  test('the batch assign drops foreign links per dive', () async {
    await insertDiveWithTank('d1', 't1', tripId: tripA, cylinderId: slotA);
    await insertDiveWithTank('d2', 't2', tripId: tripB, cylinderId: slotB);

    await trips.assignDivesToTrip(['d1', 'd2'], tripB);

    expect(await linkOf('t1'), isNull);
    expect(await linkOf('t2'), slotB);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/trips/data/repositories/trip_repository_cylinders_test.dart`
Expected: FAIL. `deleteTrip` leaves the slot in place (or throws on the FK from `trip_cylinders.trip_id`); the assign and remove tests find the link still set.

- [ ] **Step 3: Wire `TripRepository`**

In `lib/features/trips/data/repositories/trip_repository.dart` add two imports to the local group:

```dart
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
```

In `deleteTrip`, after `await TripDayWeatherRepository().deleteByTripId(id);` (line 275) add:

```dart
        // Slots, their ledger and the links on the tanks that used them.
        await TripCylinderRepository().deleteByTripId(id);
```

In `assignDiveToTrip`, before the `customUpdate` (line 350) add:

```dart
      // A link into another trip's slot means nothing on this dive.
      await clearForeignTripCylinderLinks(
        _db,
        _syncRepository,
        diveId,
        tripId: tripId,
        now: DateTime.now().millisecondsSinceEpoch,
      );
```

In `removeDiveFromTrip`, before the `customUpdate` (line 370) add:

```dart
      // Off the trip, the dive can hold no slot link at all.
      await clearForeignTripCylinderLinks(
        _db,
        _syncRepository,
        diveId,
        tripId: null,
        now: DateTime.now().millisecondsSinceEpoch,
      );
```

In `assignDivesToTrip`, inside the transaction's `for (final diveId in diveIds)` loop (line 476), before the `customUpdate`, add:

```dart
          await clearForeignTripCylinderLinks(
            _db,
            _syncRepository,
            diveId,
            tripId: tripId,
            now: now,
          );
```

- [ ] **Step 4: Run the trip repository test**

Run: `flutter test test/features/trips/data/repositories/trip_repository_cylinders_test.dart test/features/trips/data/repositories/trip_day_weather_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Extend the diver delete tests**

In `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart`, in `clearedReferences` (lines 658-673) after `'trip_day_weather.trip_id',` add `'trip_cylinders.trip_id',`.

In `test/features/divers/data/repositories/diver_delete_tombstones_test.dart`, in the `'a private trip and its children'` seeder, before its `return [` (line 224) add:

```dart
      await db
          .into(db.tripCylinders)
          .insert(
            TripCylindersCompanion.insert(
              id: 'slot-a',
              tripId: 'trip-a',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.tripCylinderEvents)
          .insert(
            TripCylinderEventsCompanion.insert(
              id: 'fill-a',
              tripCylinderId: 'slot-a',
              kind: 'fill',
              occurredAt: stale,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
```

and to the returned list add:

```dart
        ('trip_cylinders', 'tripCylinders', 'slot-a'),
        ('trip_cylinder_events', 'tripCylinderEvents', 'fill-a'),
```

- [ ] **Step 6: Run the diver delete tests to see them fail**

Run: `flutter test test/features/divers/data/repositories/diver_delete_owned_tables_test.dart test/features/divers/data/repositories/diver_delete_tombstones_test.dart`
Expected: FAIL. The owned-tables test reports `trip_cylinders.trip_id` unhandled only if Step 5's list edit is missing; the tombstones test fails because the delete either violates the FK from `trip_cylinders` or leaves `slot-a` and `fill-a` without tombstones.

- [ ] **Step 7: Add the diver delete steps**

In `lib/features/divers/data/repositories/diver_delete_steps.dart`, after `const _ofDiverTrips = ...;` (line 83) add:

```dart
const _ofDiverTripCylinders =
    'trip_cylinder_id IN (SELECT id FROM trip_cylinders WHERE $_ofDiverTrips)';
```

In `diverTripAndSiteSteps` (lines 91-113), before the `trip_day_weather` entry, add:

```dart
  // The ledger first: it cascades from its slot, and a cascade logs nothing.
  (
    table: 'trip_cylinder_events',
    entityType: 'tripCylinderEvents',
    where: _ofDiverTripCylinders,
  ),
  (
    table: 'trip_cylinders',
    entityType: 'tripCylinders',
    where: _ofDiverTrips,
  ),
```

In `lib/features/divers/data/repositories/diver_repository.dart`, add the import:

```dart
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
```

and directly before `await deleteDiverRows(_db, _syncRepository, id, diverTripAndSiteSteps);` (around line 654) add:

```dart
        // Other divers' surviving tanks can still link this diver's trip
        // slots. Cleared and staged here, as the gear links are below: the
        // schema's SET NULL reaches no peer.
        await clearTripCylinderLinks(
          _db,
          _syncRepository,
          await _idsOf(
            'SELECT id FROM trip_cylinders WHERE trip_id IN '
            '(SELECT id FROM trips WHERE diver_id = ?)',
            [id],
          ),
          now: DateTime.now().millisecondsSinceEpoch,
        );
```

- [ ] **Step 8: Run the diver delete suites**

Run: `flutter test test/features/divers/data/repositories`
Expected: PASS.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib/features/trips/data/repositories/trip_repository.dart lib/features/divers/data/repositories/diver_delete_steps.dart lib/features/divers/data/repositories/diver_repository.dart test/features/trips/data/repositories/trip_repository_cylinders_test.dart test/features/divers/data/repositories/diver_delete_owned_tables_test.dart test/features/divers/data/repositories/diver_delete_tombstones_test.dart
git commit -m "feat(trips): trip cylinders follow their trip through deletion and moves (#2325)"
```

---

### Task 7: The pure state fold and the picker suggestion

**Files:**
- Create: `lib/features/trips/domain/services/trip_cylinder_state_fold.dart`
- Test: `test/features/trips/domain/services/trip_cylinder_state_fold_test.dart`

**Interfaces:**
- Consumes: Task 2's `TripCylinder`, `TripCylinderEvent`, `TripCylinderEventKind`, `TripCylinderTankUse`, `TripCylinderState`, `TripCylinderStatus`; `GasMix`.
- Produces: `TripCylinderState foldCylinderState({required TripCylinder cylinder, required List<TripCylinderEvent> events, required List<TripCylinderTankUse> uses})`; `TripCylinder? suggestTripCylinder({required List<TripCylinderState> states, required GasMix tankMix, Set<String> excludedCylinderIds = const {}})`; constants `kTripCylinderEmptyBar = 50.0` and `kTripCylinderFullFraction = 0.9`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/trips/domain/services/trip_cylinder_state_fold_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

/// Pure arithmetic over one slot's timeline. Every expectation here was
/// worked out by hand from the spec's rules before the fold existed.
void main() {
  final t0 = DateTime.utc(2026, 3, 9, 8, 0);
  DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

  final slot = TripCylinder(
    id: 'c1',
    tripId: 't1',
    label: 'Truck 1',
    volume: 11.1,
    workingPressure: 207,
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderEvent fill(
    int minutes, {
    String id = 'f',
    double? pressure = 200,
    double? o2 = 32,
    double? analyzedO2,
    String? label,
  }) => TripCylinderEvent(
    id: '$id$minutes',
    tripCylinderId: 'c1',
    kind: TripCylinderEventKind.fill,
    occurredAt: at(minutes),
    pressure: pressure,
    o2Percent: o2,
    analyzedO2: analyzedO2,
    bottleLabel: label,
    createdAt: t0,
    updatedAt: t0,
  );

  TripCylinderEvent adjust(int minutes, {double? pressure, double? o2}) =>
      TripCylinderEvent(
        id: 'a$minutes',
        tripCylinderId: 'c1',
        kind: TripCylinderEventKind.adjustment,
        occurredAt: at(minutes),
        pressure: pressure,
        o2Percent: o2,
        createdAt: t0,
        updatedAt: t0,
      );

  TripCylinderTankUse dive(
    int minutes, {
    String diveId = 'd',
    String tankId = 'k',
    double? end = 60,
    double o2 = 32,
  }) => TripCylinderTankUse(
    tankId: '$tankId$minutes',
    diveId: '$diveId$minutes',
    entryTime: at(minutes),
    startPressure: 200,
    endPressure: end,
    gasMix: GasMix(o2: o2),
  );

  TripCylinderState fold({
    List<TripCylinderEvent> events = const [],
    List<TripCylinderTankUse> uses = const [],
  }) => foldCylinderState(cylinder: slot, events: events, uses: uses);

  group('foldCylinderState', () {
    test('an untouched slot is unknown and wears its own label', () {
      final s = fold();
      expect(s.status, TripCylinderStatus.unknown);
      expect(s.pressure, isNull);
      expect(s.mix, isNull);
      expect(s.bottleLabel, 'Truck 1');
      expect(s.lastFill, isNull);
      expect(s.lastEventAt, isNull);
      expect(s.linkedDiveCount, 0);
    });

    test('a fill makes it full with the analyzed mix and the bottle number', () {
      final f = fill(0, analyzedO2: 31.6, label: '14');
      final s = fold(events: [f]);
      expect(s.status, TripCylinderStatus.full);
      expect(s.pressure, 200);
      expect(s.mix!.o2, 31.6);
      expect(s.bottleLabel, '14');
      expect(s.lastFill, f);
      expect(s.lastEventAt, at(0));
    });

    test('a fill with no pressure reads as the working pressure', () {
      expect(fold(events: [fill(0, pressure: null)]).pressure, 207);
    });

    test('ordered mix stands in until something is analyzed', () {
      final s = fold(events: [fill(0, o2: 32), fill(60, o2: 36, analyzedO2: 35.8)]);
      expect(s.mix!.o2, 35.8);
      expect(fold(events: [fill(0, o2: 32)]).mix!.o2, 32);
    });

    test('a dive after the fill leaves it partial at the end pressure', () {
      final s = fold(events: [fill(0)], uses: [dive(60, end: 60, o2: 33)]);
      expect(s.status, TripCylinderStatus.partial);
      expect(s.pressure, 60);
      // The dive never changes the slot's mix; its own mix is its own truth.
      expect(s.mix!.o2, 32);
      expect(s.linkedDiveCount, 1);
      expect(s.lastEventAt, at(60));
    });

    test('a dive timestamped before the last fill does not spend it', () {
      // Tuesday's dive imported on Friday slots into Tuesday.
      final s = fold(events: [fill(120)], uses: [dive(60)]);
      expect(s.status, TripCylinderStatus.full);
      expect(s.pressure, 200);
    });

    test('on one instant the fill applies before the dive', () {
      final s = fold(events: [fill(60)], uses: [dive(60)]);
      expect(s.status, TripCylinderStatus.partial);
      expect(s.pressure, 60);
    });

    test('on one instant a correction applies after the dive', () {
      final s = fold(events: [fill(0), adjust(60, pressure: 0)], uses: [dive(60)]);
      expect(s.status, TripCylinderStatus.empty);
      expect(s.pressure, 0);
    });

    test('mark empty is empty', () {
      final s = fold(events: [fill(0), adjust(30, pressure: 0)]);
      expect(s.status, TripCylinderStatus.empty);
    });

    test('a dive ending at the empty line is empty', () {
      expect(
        fold(events: [fill(0)], uses: [dive(30, end: 50)]).status,
        TripCylinderStatus.empty,
      );
      expect(
        fold(events: [fill(0)], uses: [dive(30, end: 51)]).status,
        TripCylinderStatus.partial,
      );
    });

    test('a gauge reading near the working pressure is full', () {
      // 0.9 * 207 = 186.3
      expect(
        fold(events: [adjust(0, pressure: 190)]).status,
        TripCylinderStatus.full,
      );
      expect(
        fold(events: [adjust(0, pressure: 186)]).status,
        TripCylinderStatus.partial,
      );
    });

    test('a correction with no pressure changes nothing but the clock', () {
      final s = fold(events: [fill(0), adjust(30)]);
      expect(s.pressure, 200);
      expect(s.status, TripCylinderStatus.partial);
      expect(s.lastEventAt, at(30));
    });

    test('a correction can carry a mix', () {
      expect(fold(events: [fill(0), adjust(30, pressure: 150, o2: 30)]).mix!.o2, 30);
    });

    test('a dive with no end pressure leaves the pressure unknown but used', () {
      final s = fold(events: [fill(0)], uses: [dive(60, end: null)]);
      expect(s.pressure, isNull);
      expect(s.status, TripCylinderStatus.partial);
    });

    test('the bottle number carries until a fill names another', () {
      final s = fold(events: [fill(0, label: '14'), fill(60), fill(120, label: '7')]);
      expect(s.bottleLabel, '7');
      expect(fold(events: [fill(0, label: '14'), fill(60)]).bottleLabel, '14');
      expect(fold(events: [fill(0, label: '14'), fill(60, label: '')]).bottleLabel, '14');
    });

    test('linked dives are counted once per dive, not per tank', () {
      final twoTanks = [
        TripCylinderTankUse(tankId: 'k1', diveId: 'd1', entryTime: at(60), endPressure: 100),
        TripCylinderTankUse(tankId: 'k2', diveId: 'd1', entryTime: at(60), endPressure: 90),
        dive(120),
      ];
      expect(fold(events: [fill(0)], uses: twoTanks).linkedDiveCount, 2);
    });

    test('a second fill after a dive restores full', () {
      final s = fold(events: [fill(0), fill(120)], uses: [dive(60)]);
      expect(s.status, TripCylinderStatus.full);
      expect(s.pressure, 200);
      expect(s.lastFill!.id, 'f120');
    });
  });

  group('suggestTripCylinder', () {
    TripCylinderState state(
      String id, {
      TripCylinderStatus status = TripCylinderStatus.full,
      double? o2 = 32,
      int? filledAt = 0,
      int sortOrder = 0,
    }) => TripCylinderState(
      cylinder: slot.copyWith(id: id, sortOrder: sortOrder),
      pressure: 200,
      mix: o2 == null ? null : GasMix(o2: o2),
      bottleLabel: id,
      status: status,
      lastFill: filledAt == null
          ? null
          : fill(filledAt, id: id).copyWith(tripCylinderId: id),
      lastEventAt: at(filledAt ?? 0),
    );

    test('oldest fill first among matching mixes', () {
      final pick = suggestTripCylinder(
        states: [state('late', filledAt: 60), state('early', filledAt: 0)],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'early');
    });

    test('a matching mix beats an older fill of another mix', () {
      final pick = suggestTripCylinder(
        states: [state('air', o2: 21, filledAt: 0), state('ean', o2: 32, filledAt: 60)],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'ean');
    });

    test('within one point of O2 counts as matching', () {
      final pick = suggestTripCylinder(
        states: [state('a', o2: 31.2, filledAt: 0), state('b', o2: 34, filledAt: 60)],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'a');
    });

    test('an air tank takes the oldest full slot whatever its mix', () {
      final pick = suggestTripCylinder(
        states: [state('ean', o2: 32, filledAt: 0), state('air', o2: 21, filledAt: 60)],
        tankMix: const GasMix(),
      );
      expect(pick!.id, 'ean');
    });

    test('no matching mix falls back to any full slot', () {
      final pick = suggestTripCylinder(
        states: [state('air', o2: 21, filledAt: 0)],
        tankMix: const GasMix(o2: 36),
      );
      expect(pick!.id, 'air');
    });

    test('only full slots qualify, and excluded ones are skipped', () {
      final pick = suggestTripCylinder(
        states: [
          state('used', status: TripCylinderStatus.partial, filledAt: 0),
          state('sibling', filledAt: 10),
          state('free', filledAt: 20),
        ],
        tankMix: const GasMix(o2: 32),
        excludedCylinderIds: {'sibling'},
      );
      expect(pick!.id, 'free');
    });

    test('nothing full means no suggestion', () {
      expect(
        suggestTripCylinder(
          states: [state('a', status: TripCylinderStatus.empty)],
          tankMix: const GasMix(o2: 32),
        ),
        isNull,
      );
      expect(suggestTripCylinder(states: const [], tankMix: const GasMix()), isNull);
    });

    test('a slot full by gauge reading sorts after any filled slot', () {
      final pick = suggestTripCylinder(
        states: [state('gauge', filledAt: null), state('filled', filledAt: 300)],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'filled');
    });

    test('ties break on board order', () {
      final pick = suggestTripCylinder(
        states: [state('second', filledAt: 0, sortOrder: 1), state('first', filledAt: 0, sortOrder: 0)],
        tankMix: const GasMix(o2: 32),
      );
      expect(pick!.id, 'first');
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/trips/domain/services/trip_cylinder_state_fold_test.dart`
Expected: FAIL to compile, the service file does not exist.

- [ ] **Step 3: Write the fold**

Create `lib/features/trips/domain/services/trip_cylinder_state_fold.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';

/// At or below this many bar a slot is empty: the planner's default reserve,
/// and on a rental trip the line below which nobody dives the bottle again.
/// A constant, not a setting.
const double kTripCylinderEmptyBar = 50;

/// An adjustment at or above this share of the working pressure is a full
/// bottle: a gauge reading of 190 on a 207 bar cylinder is not a partial.
const double kTripCylinderFullFraction = 0.9;

/// Order on one instant: the fill before the dive it was for, a correction
/// after the dive it corrects.
const int _rankFill = 0;
const int _rankDive = 1;
const int _rankAdjustment = 2;

class _Item {
  final int at;
  final int rank;
  final TripCylinderEvent? event;
  final TripCylinderTankUse? use;

  const _Item({required this.at, required this.rank, this.event, this.use});
}

/// Pure. Walks the slot's fills, adjustments and linked dive tanks in time
/// order and reports where that leaves it. Nothing is stored; a corrected
/// fill time or a late import re-sorts on the next read.
///
/// Rules, applied in order down the timeline:
/// - A fill sets the pressure (its own, else the working pressure), the mix
///   (analyzed over ordered, else unchanged) and the bottle label when it
///   carries one.
/// - An adjustment sets the pressure when it carries one, and the mix when
///   it carries one.
/// - A dive tank sets the pressure to its end pressure; unknown makes the
///   pressure unknown but the slot used. It never changes the slot's mix.
///
/// Status comes from the last item: a fill is full; an adjustment at or
/// above [kTripCylinderFullFraction] of the working pressure is full;
/// otherwise at or below [kTripCylinderEmptyBar] is empty, an unknown
/// pressure is partial, and anything else is partial. No items is unknown.
TripCylinderState foldCylinderState({
  required TripCylinder cylinder,
  required List<TripCylinderEvent> events,
  required List<TripCylinderTankUse> uses,
}) {
  final items = <_Item>[
    for (final e in events)
      _Item(
        at: e.occurredAt.millisecondsSinceEpoch,
        rank: e.kind == TripCylinderEventKind.fill ? _rankFill : _rankAdjustment,
        event: e,
      ),
    for (final u in uses)
      _Item(at: u.entryTime.millisecondsSinceEpoch, rank: _rankDive, use: u),
  ]..sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    return byTime != 0 ? byTime : a.rank.compareTo(b.rank);
  });

  double? pressure;
  GasMix? mix;
  String? bottleLabel;
  TripCylinderEvent? lastFill;
  _Item? last;

  for (final item in items) {
    final event = item.event;
    if (event != null) {
      switch (event.kind) {
        case TripCylinderEventKind.fill:
          pressure = event.pressure ?? cylinder.workingPressure;
          mix = event.effectiveMix ?? mix;
          final label = event.bottleLabel;
          if (label != null && label.isNotEmpty) bottleLabel = label;
          lastFill = event;
        case TripCylinderEventKind.adjustment:
          if (event.pressure != null) pressure = event.pressure;
          final adjustedMix = event.effectiveMix;
          if (adjustedMix != null) mix = adjustedMix;
      }
    } else {
      pressure = item.use!.endPressure;
    }
    last = item;
  }

  return TripCylinderState(
    cylinder: cylinder,
    pressure: pressure,
    mix: mix,
    bottleLabel: bottleLabel ?? cylinder.label,
    status: _statusOf(cylinder, last, pressure),
    lastFill: lastFill,
    lastEventAt: last == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(last.at, isUtc: true),
    linkedDiveCount: uses.map((u) => u.diveId).toSet().length,
  );
}

TripCylinderStatus _statusOf(
  TripCylinder cylinder,
  _Item? last,
  double? pressure,
) {
  if (last == null) return TripCylinderStatus.unknown;
  final event = last.event;
  if (event != null && event.kind == TripCylinderEventKind.fill) {
    return TripCylinderStatus.full;
  }
  final working = cylinder.workingPressure;
  if (event != null &&
      event.kind == TripCylinderEventKind.adjustment &&
      pressure != null &&
      working != null &&
      pressure >= kTripCylinderFullFraction * working) {
    return TripCylinderStatus.full;
  }
  if (pressure == null) return TripCylinderStatus.partial;
  if (pressure <= kTripCylinderEmptyBar) return TripCylinderStatus.empty;
  return TripCylinderStatus.partial;
}

/// Pure. The slot to preselect for a tank being added to a dive on this
/// trip: a full slot not in [excludedCylinderIds] (the slots sibling tanks
/// on the same dive already took). When [tankMix] is not plain air, slots
/// whose mix lands within one point of O2 and He are preferred; with none
/// matching, any full slot will do. Oldest fill first; a slot full by gauge
/// reading, with no fill, sorts last; ties break on board order. Null when
/// nothing is full.
TripCylinder? suggestTripCylinder({
  required List<TripCylinderState> states,
  required GasMix tankMix,
  Set<String> excludedCylinderIds = const {},
}) {
  final full = states
      .where(
        (s) =>
            s.status == TripCylinderStatus.full &&
            !excludedCylinderIds.contains(s.cylinder.id),
      )
      .toList();
  if (full.isEmpty) return null;

  final isAir = (tankMix.o2 - 21).abs() < 0.5 && tankMix.he.abs() < 0.5;
  final matching = isAir
      ? full
      : full.where((s) {
          final mix = s.mix;
          return mix != null &&
              (mix.o2 - tankMix.o2).abs() <= 1.0 &&
              (mix.he - tankMix.he).abs() <= 1.0;
        }).toList();
  final pool = matching.isEmpty ? full : matching;

  int filledAt(TripCylinderState s) =>
      s.lastFill?.occurredAt.millisecondsSinceEpoch ?? _neverFilled;
  pool.sort((a, b) {
    final byFill = filledAt(a).compareTo(filledAt(b));
    return byFill != 0
        ? byFill
        : a.cylinder.sortOrder.compareTo(b.cylinder.sortOrder);
  });
  return pool.first.cylinder;
}

/// Sorts a slot with no fill after every filled one.
const int _neverFilled = 1 << 62;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/trips/domain/services/trip_cylinder_state_fold_test.dart`
Expected: PASS, 26 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/trips/domain/services/trip_cylinder_state_fold.dart test/features/trips/domain/services/trip_cylinder_state_fold_test.dart
git commit -m "feat(trips): fold a trip cylinder slot state from its ledger and dives (#2325)"
```

---

### Task 8: Providers and the change-tick guards

**Files:**
- Create: `lib/features/trips/presentation/providers/trip_cylinder_providers.dart`
- Modify: `test/architecture/repository_tick_stream_test.dart` (the `group('trips', ...)` around lines 602-645)
- Test: `test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`

**Interfaces:**
- Consumes: Task 5's repository, Task 7's `foldCylinderState`, `ref.invalidateSelfWhen` from `core/providers/provider.dart`.
- Produces: `tripCylinderRepositoryProvider` (`Provider<TripCylinderRepository>`), `tripCylindersProvider` (`FutureProvider.family<List<TripCylinder>, String>`), `tripCylinderStatesProvider` (`FutureProvider.family<List<TripCylinderState>, String>`). PR 2's card and board read these.

- [ ] **Step 1: Write the failing provider test**

Create `test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late TripCylinderRepository repository;
  late String tripId;

  final at = DateTime.utc(2026, 3, 9, 8, 0);

  setUp(() async {
    db = await setUpTestDatabase();
    container = ProviderContainer();
    addTearDown(container.dispose);
    repository = TripCylinderRepository();
    final now = DateTime.now();
    tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  });

  tearDown(tearDownTestDatabase);

  Future<TripCylinder> slot(String label, {int sortOrder = 0}) =>
      repository.createCylinder(
        TripCylinder(
          id: '',
          tripId: tripId,
          label: label,
          workingPressure: 207,
          sortOrder: sortOrder,
          createdAt: at,
          updatedAt: at,
        ),
      );

  Future<void> fill(String cylinderId, {double o2 = 32}) => repository.createEvent(
    TripCylinderEvent(
      id: '',
      tripCylinderId: cylinderId,
      kind: TripCylinderEventKind.fill,
      occurredAt: at,
      pressure: 200,
      o2Percent: o2,
      createdAt: at,
      updatedAt: at,
    ),
  );

  Future<void> diveOn(String cylinderId, {required int minutesAfter, double end = 60}) async {
    final entry = at.add(Duration(minutes: minutesAfter)).millisecondsSinceEpoch;
    final diveId = 'd$minutesAfter';
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: entry,
            tripId: Value(tripId),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(id: 't$minutesAfter', diveId: diveId).copyWith(
            tripCylinderId: Value(cylinderId),
            endPressure: Value(end),
          ),
        );
  }

  test('a trip with no slots yields no states and no slots', () async {
    expect(await container.read(tripCylindersProvider(tripId).future), isEmpty);
    expect(await container.read(tripCylinderStatesProvider(tripId).future), isEmpty);
  });

  test('states come back in board order with the fold applied', () async {
    final b = await slot('B', sortOrder: 1);
    final a = await slot('A');
    await fill(a.id);
    await fill(b.id);
    await diveOn(b.id, minutesAfter: 60);

    final states = await container.read(tripCylinderStatesProvider(tripId).future);
    expect(states.map((s) => s.cylinder.label), ['A', 'B']);
    expect(states[0].status, TripCylinderStatus.full);
    expect(states[0].mix!.o2, 32);
    expect(states[1].status, TripCylinderStatus.partial);
    expect(states[1].pressure, 60);
    expect(states[1].linkedDiveCount, 1);
  });

  test('a fill written later refreshes the states', () async {
    final a = await slot('A');
    final before = await container.read(tripCylinderStatesProvider(tripId).future);
    expect(before.single.status, TripCylinderStatus.unknown);

    // Keep the provider alive across the write, as a page would.
    final sub = container.listen(tripCylinderStatesProvider(tripId), (_, _) {});
    addTearDown(sub.close);
    await fill(a.id);
    // The tick is a stream; give the invalidation a turn to land.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final after = await container.read(tripCylinderStatesProvider(tripId).future);
    expect(after.single.status, TripCylinderStatus.full);
  });

  test('a tank link written straight to dive_tanks refreshes too', () async {
    final a = await slot('A');
    await fill(a.id);
    final sub = container.listen(tripCylinderStatesProvider(tripId), (_, _) {});
    addTearDown(sub.close);
    expect(
      (await container.read(tripCylinderStatesProvider(tripId).future)).single.status,
      TripCylinderStatus.full,
    );

    // A sync pull rewrites tank rows without touching the dives row.
    await diveOn(a.id, minutesAfter: 60);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      (await container.read(tripCylinderStatesProvider(tripId).future)).single.status,
      TripCylinderStatus.partial,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`
Expected: FAIL to compile, the providers file does not exist.

- [ ] **Step 3: Write the providers**

Create `lib/features/trips/presentation/providers/trip_cylinder_providers.dart`:

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

final tripCylinderRepositoryProvider = Provider<TripCylinderRepository>(
  (ref) => TripCylinderRepository(),
);

/// The slots of a trip in board order.
final tripCylindersProvider =
    FutureProvider.family<List<TripCylinder>, String>((ref, tripId) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripCylinderChanges());
      return repository.getCylindersForTrip(tripId);
    });

/// Every slot of a trip with its derived state: the ledger and the linked
/// tanks folded by [foldCylinderState]. Two lean queries beyond the slots
/// themselves; no dive is hydrated. Refreshes on any write to the slots,
/// their ledger, dive tanks or dives.
final tripCylinderStatesProvider =
    FutureProvider.family<List<TripCylinderState>, String>((
      ref,
      tripId,
    ) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripCylinderChanges());

      final cylinders = await repository.getCylindersForTrip(tripId);
      if (cylinders.isEmpty) return const [];
      final events = await repository.getEventsForTrip(tripId);
      final uses = await repository.getTankUsesForTrip(tripId);
      return [
        for (final cylinder in cylinders)
          foldCylinderState(
            cylinder: cylinder,
            events: events[cylinder.id] ?? const [],
            uses: uses[cylinder.id] ?? const [],
          ),
      ];
    });
```

- [ ] **Step 4: Run the provider test**

Run: `flutter test test/features/trips/presentation/providers/trip_cylinder_providers_test.dart`
Expected: PASS, 4 tests. If the two refresh tests are flaky on the 50 ms wait, raise it to 200 ms; the tick is not debounced, so the invalidation lands within one event-loop turn of the write.

- [ ] **Step 5: Add the tick case to the architecture guard**

In `test/architecture/repository_tick_stream_test.dart`, add the import:

```dart
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
```

and inside `group('trips', ...)` (after the `watchItineraryChanges fires` test) add:

```dart
    test('watchTripCylinderChanges fires on a slot write', () async {
      await seedParents();
      expect(
        await fires(
          TripCylinderRepository().watchTripCylinderChanges(),
          () => db
              .into(db.tripCylinders)
              .insert(
                TripCylindersCompanion.insert(
                  id: 'slot-1',
                  tripId: 't1',
                  createdAt: now,
                  updatedAt: now,
                ),
              ),
        ),
        isTrue,
      );
    });

    test('watchTripCylinderChanges fires on a dive tank write', () async {
      // The board's consumption side lives on dive_tanks; a sync pull that
      // rewrites a tank never touches the dives row.
      await seedParents();
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive-tick',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      expect(
        await fires(
          TripCylinderRepository().watchTripCylinderChanges(),
          () => db
              .into(db.diveTanks)
              .insert(DiveTanksCompanion.insert(id: 'tank-tick', diveId: 'dive-tick')),
        ),
        isTrue,
      );
    });
```

If `seedParents()` already inserts a dive, reuse its id instead of inserting `dive-tick`.

- [ ] **Step 6: Run the architecture guards**

Run: `flutter test test/architecture`
Expected: PASS. `provider_change_tick_test` passes because both providers call `ref.invalidateSelfWhen`; `repository_tick_stream_test` passes with the two new cases.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/features/trips/presentation/providers/trip_cylinder_providers.dart test/features/trips/presentation/providers/trip_cylinder_providers_test.dart test/architecture/repository_tick_stream_test.dart
git commit -m "feat(trips): trip cylinder slot and state providers (#2325)"
```

---

### Task 9: Whole-branch verification and the pull request

**Files:**
- No new files. Verification, formatting, the ladder re-check and the PR.

- [ ] **Step 1: Re-check the schema ladder once more**

Run the command from Task 1 step 1 again. Expected: no open PR other than this branch claims 228. If one now does, renumber (`grep -rn "228" lib/core/database/database.dart test/core/database/migration_v228_trip_cylinders_test.dart docs/superpowers/specs/2026-09-25-trip-gas-logistics-design.md`), rename the migration test file to the new number, and re-run Task 1 step 12.

- [ ] **Step 2: Format and analyze the whole project**

Run:
```bash
dart format .
flutter analyze --fatal-infos
```
Expected: `No issues found!`. An info-level finding fails CI, so fix every line it names.

- [ ] **Step 3: Run every suite this PR touches**

Run, one at a time, never overlapping:
```bash
flutter test test/core/database
flutter test test/core/services/sync
flutter test test/features/trips
flutter test test/features/dive_log/data test/features/dive_log/domain test/features/dive_log/presentation/widgets/tank_editor_regulator_test.dart test/features/dive_log/presentation/widgets/tank_editor_trip_cylinder_test.dart
flutter test test/features/divers
flutter test test/architecture
```
Expected: every run ends `All tests passed!`. A failure in a file this PR never touched means main is red; check `origin/main` before blaming the branch.

- [ ] **Step 4: Confirm nothing forbidden slipped in**

Run:
```bash
git diff origin/main...HEAD | grep -nP "^\+.*(\x{2014}|\x{2013})"
```
Expected: no output. Then scan the same diff for the two tool-attribution terms the contributor guide's Attribution section forbids; that pattern is deliberately not written into this tracked file, because spelling the terms would itself break the rule.

- [ ] **Step 5: Commit any formatting fallout**

```bash
git status --short
git add -u
git commit -m "style: format trip cylinder data layer"
```
Skip the commit if `git status --short` prints nothing.

- [ ] **Step 6: Push and open the pull request**

```bash
git push -u origin ericgriffin/trip-scale-gas-logistics-865434
```

Then, in one Bash call so the token override holds:

```bash
unset GITHUB_TOKEN; gh pr create --repo submersion-app/submersion --base main --title "feat(trips): trip cylinder slots, ledger and dive tank link (phase 1 data and sync)" --body "$(cat <<'BODY'
Part of #2325

Phase 1 of trip-scale gas logistics, data and sync only. No UI.

## What this adds

- Schema v228: `trip_cylinders` (a slot the diver holds on a trip, optionally linked to an owned equipment cylinder), `trip_cylinder_events` (its ledger of fills and adjustments), and a nullable `dive_tanks.trip_cylinder_id` link with ON DELETE SET NULL. Additive rung, no backfill; the compatibility floor stays at 224. 227 is held by #2315.
- Domain entities `TripCylinder`, `TripCylinderEvent` and `TripCylinderState`, and the pure `foldCylinderState` plus the picker suggestion rule from the spec.
- `DiveTank.tripCylinderId` carried through create, update, both mappers, the bulk-edit undo mapper, sequential tank merge and the tank editor's rebuild. A bulk template does not stamp the link; only a restore does.
- `TripCylinderRepository` with a change tick over slots, ledger, dive tanks and dives; lean tank-use query, no dive hydration.
- Sync registration for both entities at every serializer site, modelled on `tripDayWeather`, with parent refs for trips, equipment, dive centers and the new link on dive tanks.
- Deletion: a trip takes its slots and ledger with tombstones and clears tank links; deleting a slot clears links and stages the tanks; a dive leaving or changing trip drops links into the old trip; diver deletion tombstones the new children and clears other divers' links.

## Spec

`docs/superpowers/specs/2026-09-25-trip-gas-logistics-design.md`, Delivery item 1. PRs 2 to 5 follow, each off main after this merges.

## Testing

Migration tests for v228 (upgrade, fresh parity, idempotency, backstop heal, partial fixture); per-entity sync round trip and the pinning suites; repository, deletion and provider tests; the fold vectors; the architecture guards.
BODY
)"
```

Expected: the PR URL. Then bind it in the desktop app so CI is watched (`get_status`, and `bind_pr` if the PR is not reported), and do not enable auto-merge.

- [ ] **Step 7: Record the state**

Update the memory note `project_trip_gas_logistics_program.md` with the PR number and "PR 1 open, CI pending", and its index line in `MEMORY.md`.
