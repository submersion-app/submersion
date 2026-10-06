# Cylinder Passports 4: Trip Assignment for Gear Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver pack any gear for a trip through a synced `trip_equipment` link, see "Packed for <trip>" on a cylinder's passport (including trips where it is a trip gas cylinder slot), and manage a trip's gear from a Gear card on the trip page.

**Architecture:** A new table `trip_equipment` (schema v248), a parent-gated child of `trips` that syncs exactly like `equipment_shares` (no `updated_at`, own `hlc`, exported through the trip's clock plus pending marks, the (trip, item) pair reconciled to the lowest id). `TripEquipmentRepository` owns writes and tombstones; trip, equipment and diver deletes call it. Two providers read it: the trip's gear (visible items only) and an item's trips (packed links unioned with `trip_cylinders` slots, ranked in progress, then upcoming, then past). Two cards render them: `PassportTripCard` and `TripGearCard`.

**Tech Stack:** Flutter 3.47, Dart 3.13, Drift, Riverpod 3, go_router, flutter gen-l10n (11 locales).

**Spec:** `docs/design/specs/2026-09-25-smart-cylinder-passports-design.md`, sections 8 (Trip card row), 10.4, 10.6, 10.7, 10.8, and the "4 Trip assignment" row of section 17. Task 1 amends it with the 2026-09-29 decisions.

## Global Constraints

- Never use an em dash or an en dash as punctuation, in code, comments, strings, docs, commits or the PR.
- No mention of Claude, Claude Code or Anthropic in any commit, PR text or file.
- Never add a table or a rung to `database.dart` beyond the `@DriftDatabase` list, `currentSchemaVersion` and `migrationVersions` entries (`test/core/database/database_table_libraries_test.dart` enforces it). Files under `tables/` and `migrations/` stay under 800 lines.
- Schema: v248 (246 is claimed by #2409, 247 by #2579). Re-check open PRs before opening this one; renumber in every place if taken. `minimumCompatibleSchemaVersion` does not move. No backfill: no existing row changes.
- Every repository write and its `markRecordPending` share one `_db.transaction`; `markRecordPending` runs after any `batch`, never inside it; `SyncEventBus.notifyLocalChange()` after the transaction.
- A child change never re-stamps its parent (no write to `trips` or `equipment` rows).
- Anything that shows units goes through `UnitFormatter`; this plan shows none.
- New strings go in all 11 ARB files (ar de en es fr he hu it nl pt zh); run `flutter gen-l10n`; `test/l10n` must pass (it includes the Spanish and Portuguese accent guard).
- Tests restore any process-wide state they change, in a teardown.
- Imports grouped dart, flutter, packages, local; `dart format .` before every commit.

## Review Focus

1. A diver packs an item on one phone while a peer packs the same item for the same trip under another id: after sync both devices hold one row (the lower id). Pinned in Task 3 (`a peer copy of a pair under another id converges on one row`).
2. Deleting a trip or an item on one device removes its packed rows on every device, with tombstones, and a peer that still holds a link never revives it onto a deleted trip. Pinned in Task 2 (`deleting a trip tombstones its packed rows`, `deleting an item tombstones its packed rows`) and Task 3 (`a trips tombstone drops its packed rows`).
3. A diver who cannot see an item (not owner, not sharee) sees nothing of it on a trip's Gear card, even when the trip is shared. Pinned in Task 4 (`gear the diver cannot see is left off`).
4. An item whose only link to a trip is a trip gas slot still reads "Packed for <trip>" on its passport, but offers no Unassign for that trip. Pinned in Task 5 (`a slot-only trip shows without Unassign`).
5. The trip page's existing tests pump it with no database: the Gear card must render nothing while loading or on error, so those tests stay green without new overrides. Pinned in Task 6 (`renders nothing while the gear is loading`) and by running `trip_detail_page_test.dart` unchanged.

---

## File structure

| File | Responsibility |
| --- | --- |
| `lib/core/database/tables/trip_tables.dart` | + `TripEquipment` table |
| `lib/core/database/database.dart` | `@DriftDatabase` entry, `currentSchemaVersion = 248`, `migrationVersions` entry |
| `lib/core/database/migrations/helpers/trip_migrations.dart` | + `_assertTripEquipmentSchema()` |
| `lib/core/database/migrations/ladder/rungs_v231_onward.dart` | + v248 rung |
| `lib/core/database/migrations/before_open.dart` | + v248 backstop |
| `lib/core/database/performance_indexes.dart` | + `idx_trip_equipment_equipment`, `idx_trip_cylinders_equipment` |
| `lib/features/trips/data/repositories/trip_equipment_repository.dart` (new) | pack, unpack, reads, deletes with tombstones, change tick |
| `lib/features/trips/data/repositories/trip_cylinder_repository.dart` | + `tripIdsForEquipment` |
| `lib/features/trips/data/repositories/trip_repository.dart` | `deleteTrip` calls `deleteByTripId` |
| `lib/features/equipment/data/repositories/equipment_repository_impl.dart` | `deleteEquipment` calls `deleteForEquipment` |
| `lib/features/divers/data/repositories/diver_delete_steps.dart` | two steps |
| `lib/core/data/repositories/sync_repository.dart` | `hlcTargets` entry |
| `lib/core/services/sync/sync_service.dart` | `mergeOrder`, `entityHasUpdatedAt`, `parentRefs` |
| `lib/core/services/sync/sync_data_serializer.dart` | every arm |
| `lib/features/trips/presentation/providers/trip_equipment_providers.dart` (new) | repository provider, `tripGearProvider`, `equipmentTripsProvider`, `PackedTrip` |
| `lib/features/cylinder_passports/presentation/widgets/passport_trip_card.dart` (new) | the passport Trip card |
| `lib/features/cylinder_passports/presentation/pages/passport_page.dart` | adds the card |
| `lib/features/trips/presentation/widgets/trip_gear_card.dart` (new) | the trip page Gear card |
| `lib/features/trips/presentation/pages/trip_detail_page.dart` | four placements |
| `lib/l10n/arb/app_*.arb` | strings |

---

### Task 1: The table and the v248 rung (plus the spec amendment)

**Files:**
- Modify: `docs/design/specs/2026-09-25-smart-cylinder-passports-design.md` (section 8 Trip row, section 10.4, section 17 row 4)
- Modify: `lib/core/database/tables/trip_tables.dart` (append after `TripChecklistItems`)
- Modify: `lib/core/database/database.dart` (`@DriftDatabase` list end at `ConnectionMaps,`; `currentSchemaVersion`; `migrationVersions` tail)
- Modify: `lib/core/database/migrations/helpers/trip_migrations.dart` (append a helper)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v245 block)
- Modify: `lib/core/database/migrations/before_open.dart` (after the v245 backstop)
- Modify: `lib/core/database/performance_indexes.dart`
- Modify: `test/core/database/migration_v245_certifications_buddy_index_test.dart` (relax the pin)
- Test: `test/core/database/migration_v248_trip_equipment_test.dart` (new)

**Interfaces:**
- Produces: Drift table `tripEquipment` (SQL `trip_equipment`), data class `TripEquipmentRow`, companion `TripEquipmentCompanion`, generated `$TripEquipmentTable`; columns `id`, `tripId`, `equipmentId`, `createdAt`, `hlc`; unique key `{tripId, equipmentId}`.

- [ ] **Step 1: Amend the spec**

In section 10.4 change "modelled on `equipment_shares` (v219)" to "modelled on `equipment_shares` (v234)", and add after the table:

```markdown
Decided 2026-09-29: a cylinder's passport Trip card also lists the trips
where the cylinder is a trip gas slot (`trip_cylinders.equipment_id`), so
it reads "Packed for <trip>" either way. Assign and Unassign on the card
touch `trip_equipment` only; a slot stays the cylinder board's business.
The trip page's Gear card sits right after the Cylinders card.
```

In section 17's row 4, change the version note to "v248".

- [ ] **Step 2: Write the failing migration test**

`test/core/database/migration_v248_trip_equipment_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v248: trip_equipment (issue #2338).
void main() {
  /// A v247 database with only the parents trip_equipment points at.
  NativeDatabase setupDb({bool withTrips = true}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 247');
      rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
      rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
      if (withTrips) {
        rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
      }
    },
  );

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<bool> hasIndex(AppDatabase db, String name) async => (await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
            variables: [Variable(name)],
          )
          .get())
      .isNotEmpty;

  test('v248 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 248);
    expect(AppDatabase.migrationVersions.last, 248);
    expect(AppDatabase.migrationStepCount(247), 1);
  });

  test('upgrading from v247 creates trip_equipment and its index', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_equipment'), {
      'id',
      'trip_id',
      'equipment_id',
      'created_at',
      'hlc',
    });
    expect(await hasIndex(db, 'idx_trip_equipment_equipment'), isTrue);
  });

  test('the (trip, item) pair is unique', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customStatement("INSERT INTO trips (id) VALUES ('t1')");
    await db.customStatement("INSERT INTO equipment (id) VALUES ('e1')");
    await db.customStatement(
      "INSERT INTO trip_equipment (id, trip_id, equipment_id, created_at) "
      "VALUES ('a', 't1', 'e1', 0)",
    );
    expect(
      () => db.customStatement(
        "INSERT INTO trip_equipment (id, trip_id, equipment_id, created_at) "
        "VALUES ('b', 't1', 'e1', 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('a fixture without trips gains no trip_equipment', () async {
    final db = AppDatabase(setupDb(withTrips: false));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_equipment'), isEmpty);
  });
}
```

Its imports, in place of the three above:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:submersion/core/database/database.dart';
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v248_trip_equipment_test.dart`
Expected: FAIL (`currentSchemaVersion` is 245; no `trip_equipment`).

- [ ] **Step 4: The table**

Append to `lib/core/database/tables/trip_tables.dart`:

```dart
/// Gear packed for a trip (v248, issue #2338). A parent-gated child of
/// `trips`, modelled on `equipment_shares`: no updated_at, its own clock,
/// exported through the trip's clock plus pending marks. Any equipment type
/// may be packed. Both parents cascade.
@DataClassName('TripEquipmentRow')
class TripEquipment extends Table {
  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  IntColumn get createdAt => integer()();

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {tripId, equipmentId},
  ];
}
```

In `database.dart`, after `ConnectionMaps,` in `@DriftDatabase(tables: [...])`:

```dart
    // Gear packed for a trip (v248, issue #2338)
    TripEquipment,
```

Set `static const int currentSchemaVersion = 248;` and append to `migrationVersions` after `245,`:

```dart
    // v248: trip_equipment, gear packed for a trip (issue #2338).
    // Table-only rung, no backfill; the floor does not move. 246 is held by
    // #2409 and 247 by #2579.
    248,
```

- [ ] **Step 5: The helper, rung, backstop and indexes**

Append to `helpers/trip_migrations.dart` (inside the extension, after `_assertTripCylindersSchema`):

```dart
  /// The trip_equipment table and its item index (v248, issue #2338).
  /// Called from the v248 rung and the beforeOpen backstop. Skipped on a
  /// partial migration-test fixture that lacks a parent table.
  Future<void> _assertTripEquipmentSchema() async {
    for (final parent in const ['trips', 'equipment']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(tripEquipment);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_trip_equipment_equipment '
      'ON trip_equipment(equipment_id)',
    );
  }
```

`Migrator.createTable` issues `CREATE TABLE IF NOT EXISTS`, so the helper is idempotent. In `rungs_v231_onward.dart`, after the v245 block:

```dart
    // v248: gear packed for a trip (issue #2338). Table-only rung, no
    // backfill; re-asserted in beforeOpen.
    if (from < 248) {
      await _assertTripEquipmentSchema();
    }
    if (from < 248) await reportProgress();
```

In `before_open.dart`, after the v245 backstop:

```dart
    // v248 backstop: trip_equipment and its item index (idempotent).
    await _assertTripEquipmentSchema();
```

In `performance_indexes.dart`, append to `kPerformanceIndexes`:

```dart
  // A passport's trips: packed links by item (v248, issue #2338).
  (
    name: 'idx_trip_equipment_equipment',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_trip_equipment_equipment '
        'ON trip_equipment(equipment_id)',
  ),
  // A passport's trips: trip gas slots by item (issue #2338).
  (
    name: 'idx_trip_cylinders_equipment',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_trip_cylinders_equipment '
        'ON trip_cylinders(equipment_id)',
  ),
```

In `migration_v245_certifications_buddy_index_test.dart`, relax its pin as v244's test does:

```dart
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(245));
    expect(AppDatabase.migrationVersions, contains(245));
```

and drop its `migrationStepCount(244)` line only if it no longer holds (it should still be 1).

- [ ] **Step 6: Codegen and run**

Run: `dart run build_runner build --delete-conflicting-outputs`, then `flutter test test/core/database`
Expected: PASS, including `database_table_libraries_test.dart` and `performance_indexes_test.dart`.

- [ ] **Step 7: Commit**

```bash
git add docs/design/specs lib/core/database test/core/database
git commit -m "feat(trips): add trip_equipment, gear packed for a trip (schema v248)"
```

---

### Task 2: TripEquipmentRepository and the deletes that call it

**Files:**
- Create: `lib/features/trips/data/repositories/trip_equipment_repository.dart`
- Modify: `lib/features/trips/data/repositories/trip_cylinder_repository.dart` (add `tripIdsForEquipment`)
- Modify: `lib/features/trips/data/repositories/trip_repository.dart` (`deleteTrip`, after `await TripCylinderRepository().deleteByTripId(id);`)
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`deleteEquipment`, after `await EquipmentShareRepository().deleteForEquipment(id);`)
- Modify: `lib/features/divers/data/repositories/diver_delete_steps.dart`
- Test: `test/features/trips/data/repositories/trip_equipment_repository_test.dart` (new)
- Modify: `test/features/divers/data/repositories/diver_delete_tombstones_test.dart` (seed and expect `trip_equipment`)
- Modify: `test/architecture/repository_tick_stream_test.dart` (the `ticks` map)

**Interfaces:**
- Consumes: Task 1's `TripEquipmentRow`, `TripEquipmentCompanion`.
- Produces:
  - `class TripEquipmentRepository` with `static const String entity = 'tripEquipment';`
  - `Stream<void> watchChanges()`
  - `Future<List<String>> equipmentIdsForTrip(String tripId)`
  - `Future<Set<String>> tripIdsForEquipment(String equipmentId)`
  - `Future<int> pack(String tripId, Iterable<String> equipmentIds)` (count added; skips pairs already packed)
  - `Future<void> unpack(String tripId, String equipmentId)`
  - `Future<void> deleteByTripId(String tripId)` and `Future<void> deleteForEquipment(String equipmentId)`, both inside the caller's transaction
  - `TripCylinderRepository.tripIdsForEquipment(String equipmentId) -> Future<Set<String>>`

- [ ] **Step 1: Write the failing tests**

`test/features/trips/data/repositories/trip_equipment_repository_test.dart`, using `setUpTestDatabase` and seeding one diver, two trips (`t1`, `t2`) and two items (`bcd`, `tank`) with their companions, then:

- `pack adds each pair once and marks it pending`: `pack('t1', ['bcd', 'tank'])` returns 2; `pack('t1', ['bcd'])` returns 0; `equipmentIdsForTrip('t1')` is `{'bcd', 'tank'}` as a set; `SyncRepository().getPendingRecords()` holds two records whose `entityType` is `tripEquipment`.
- `unpack removes the pair and tombstones it`: after `pack('t1', ['bcd'])` and `unpack('t1', 'bcd')`, `equipmentIdsForTrip('t1')` is empty and `SyncRepository().getAllDeletions()` holds one `tripEquipment` deletion.
- `tripIdsForEquipment lists the trips an item is packed for`: pack `bcd` for `t1` and `t2`; expect `{'t1', 't2'}`.
- `deleting a trip tombstones its packed rows`: pack `bcd` for `t1`; `TripRepository().deleteTrip('t1')`; no `trip_equipment` rows remain and one `tripEquipment` deletion is logged.
- `deleting an item tombstones its packed rows`: pack `bcd` for `t1` and `t2`; `EquipmentRepository().deleteEquipment('bcd')`; two `tripEquipment` deletions.
- `a slot links an item to its trip`: insert a `trip_cylinders` row for `t2` with `equipmentId: 'tank'` (see `trip_repository_cylinders_test.dart` for the companion); `TripCylinderRepository().tripIdsForEquipment('tank')` is `{'t2'}`.
- `the change tick fires on pack and unpack`: listen to `watchChanges()`, pack, and expect an event.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/trips/data/repositories/trip_equipment_repository_test.dart`
Expected: FAIL (the repository does not exist).

- [ ] **Step 3: The repository**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';

/// Gear packed for a trip (issue #2338): the `trip_equipment` links. A
/// parent-gated child of `trips`; writes never touch the trip or item rows
/// (#1769: a child change does not re-stamp its parent).
class TripEquipmentRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  static const String entity = 'tripEquipment';

  /// Emits when a link is written or removed.
  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.tripEquipment));

  Future<List<String>> equipmentIdsForTrip(String tripId) =>
      (_db.selectOnly(_db.tripEquipment)
            ..addColumns([_db.tripEquipment.equipmentId])
            ..where(_db.tripEquipment.tripId.equals(tripId)))
          .map((r) => r.read(_db.tripEquipment.equipmentId)!)
          .get();

  Future<Set<String>> tripIdsForEquipment(String equipmentId) async =>
      (await (_db.selectOnly(_db.tripEquipment)
                ..addColumns([_db.tripEquipment.tripId])
                ..where(_db.tripEquipment.equipmentId.equals(equipmentId)))
              .map((r) => r.read(_db.tripEquipment.tripId)!)
              .get())
          .toSet();

  /// Packs each of [equipmentIds] for [tripId]; a pair already packed is
  /// left alone. Returns how many were added.
  Future<int> pack(String tripId, Iterable<String> equipmentIds) async {
    final added = await _db.transaction(() async {
      final existing = (await equipmentIdsForTrip(tripId)).toSet();
      final now = DateTime.now().millisecondsSinceEpoch;
      final rows = [
        for (final id in equipmentIds.toSet().difference(existing))
          TripEquipmentCompanion.insert(
            id: _uuid.v4(),
            tripId: tripId,
            equipmentId: id,
            createdAt: now,
          ),
      ];
      if (rows.isEmpty) return 0;
      await _db.batch((b) => b.insertAll(_db.tripEquipment, rows));
      for (final r in rows) {
        await _syncRepository.markRecordPending(
          entityType: entity,
          recordId: r.id.value,
          localUpdatedAt: now,
        );
      }
      return rows.length;
    });
    if (added > 0) SyncEventBus.notifyLocalChange();
    return added;
  }

  /// Unpacks [equipmentId] from [tripId] and tombstones the link.
  Future<void> unpack(String tripId, String equipmentId) async {
    await _db.transaction(() async {
      final ids = await _idsWhere(
        _db.tripEquipment.tripId.equals(tripId) &
            _db.tripEquipment.equipmentId.equals(equipmentId),
      );
      await (_db.delete(_db.tripEquipment)..where(
            (t) => t.tripId.equals(tripId) & t.equipmentId.equals(equipmentId),
          ))
          .go();
      await _syncRepository.logDeletions(entityType: entity, recordIds: ids);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes and tombstones every link of [tripId], for a trip delete.
  /// Cascades write no tombstones, so the trip's delete calls this first.
  /// Runs inside the caller's transaction.
  Future<void> deleteByTripId(String tripId) async {
    final ids = await _idsWhere(_db.tripEquipment.tripId.equals(tripId));
    await (_db.delete(
      _db.tripEquipment,
    )..where((t) => t.tripId.equals(tripId))).go();
    await _syncRepository.logDeletions(entityType: entity, recordIds: ids);
  }

  /// As [deleteByTripId], for an item delete.
  Future<void> deleteForEquipment(String equipmentId) async {
    final ids = await _idsWhere(
      _db.tripEquipment.equipmentId.equals(equipmentId),
    );
    await (_db.delete(
      _db.tripEquipment,
    )..where((t) => t.equipmentId.equals(equipmentId))).go();
    await _syncRepository.logDeletions(entityType: entity, recordIds: ids);
  }

  Future<List<String>> _idsWhere(Expression<bool> where) =>
      (_db.selectOnly(_db.tripEquipment)
            ..addColumns([_db.tripEquipment.id])
            ..where(where))
          .map((r) => r.read(_db.tripEquipment.id)!)
          .get();
}
```

Add to `TripCylinderRepository`:

```dart
  /// The trips where [equipmentId] is a slot (issue #2338), for the
  /// passport's Trip card.
  Future<Set<String>> tripIdsForEquipment(String equipmentId) async =>
      (await (_db.selectOnly(_db.tripCylinders)
                ..addColumns([_db.tripCylinders.tripId])
                ..where(_db.tripCylinders.equipmentId.equals(equipmentId)))
              .map((r) => r.read(_db.tripCylinders.tripId)!)
              .get())
          .toSet();
```

In `deleteTrip`, after `await TripCylinderRepository().deleteByTripId(id);`:

```dart
        // Packed gear (issue #2338): deleted and tombstoned before the trip.
        await TripEquipmentRepository().deleteByTripId(id);
```

In `deleteEquipment`, after `await EquipmentShareRepository().deleteForEquipment(id);`:

```dart
        // Trip packing links (issue #2338), tombstoned like the shares.
        await TripEquipmentRepository().deleteForEquipment(id);
```

In `diver_delete_steps.dart`, in `diverTripAndSiteSteps` before the `trips` step:

```dart
  (table: 'trip_equipment', entityType: 'tripEquipment', where: _ofDiverTrips),
```

and in `diverGearSteps` before the `equipment_shares` step:

```dart
  (
    table: 'trip_equipment',
    entityType: 'tripEquipment',
    where: 'equipment_id IN ($_diverGear)',
  ),
```

- [ ] **Step 4: The hand-maintained lists**

- `diver_delete_tombstones_test.dart`: in the trip seeder, insert a `trip_equipment` row for the diver's trip and one of the diver's items, and add `('trip_equipment', 'tripEquipment', '<id>')` to its returned triples (next to `('trip_cylinders', 'tripCylinders', 'slot-a')`).
- `repository_tick_stream_test.dart`: add `'TripEquipmentRepository.watchChanges'` to the `ticks` map with a trigger that packs one item, following the `EquipmentShareRepository.watchChanges` entry.

- [ ] **Step 5: Run and commit**

Run: `flutter test test/features/trips test/features/equipment test/features/divers test/architecture`
Expected: PASS.

```bash
git add lib/features test/features test/architecture
git commit -m "feat(trips): pack and unpack gear for a trip, with tombstoned deletes"
```

---

### Task 3: Sync registration

**Files:**
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets`, next to `'tripCylinders'`)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` after `equipmentShares`; `entityHasUpdatedAt`; `parentRefs`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (every arm listed below)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables`)
- Modify: `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart` (`targets`)
- Test: `test/core/services/sync/trip_equipment_sync_test.dart` (new)

**Interfaces:**
- Consumes: Task 1's table; Task 2's `TripEquipmentRepository.entity` (`'tripEquipment'`).
- Produces: sync entity `tripEquipment`, a parent-gated child of `trips`.

- [ ] **Step 1: Write the failing tests**

`trip_equipment_sync_test.dart`, modelled on `equipment_sharing_sync_test.dart` (same setUp shape: one diver, one trip `t1`, one item `bcd`, and a `pack(String id)` helper inserting `TripEquipmentCompanion.insert(id: id, tripId: 't1', equipmentId: 'bcd', createdAt: 1)`):

- `a packed row round-trips through fetch and upsert`: pack `a`; `serializer.fetchRecord('tripEquipment', 'a')` is non-null; delete it; `serializer.upsertRecord('tripEquipment', fetched)`; the row is back.
- `a peer copy of a pair under another id converges on one row`: pack `b`; `upsertRecords('tripEquipment', [{...row a json with id 'a'}])` leaves exactly one row with id `a` (the lower id), as the shares test asserts.
- `a trips tombstone drops its packed rows`: pack `a`; `serializer.deleteRecord('trips', 't1')` (with foreign keys on, the cascade removes the row); no `trip_equipment` rows remain.
- `a delta export carries a pending row through the trip`: mark `a` pending with `SyncRepository().markRecordPending(entityType: 'tripEquipment', recordId: 'a', localUpdatedAt: 1)`; `exportData(...)` with an `hlcSince` later than every trip clock still contains `a` in `tripEquipment`.
- `registration`: `SyncDataSerializer.parentGatedChildEntities` contains `'tripEquipment'`; `SyncRepository.hlcTargets['tripEquipment']!.table == 'trip_equipment'`; `SyncService.entityHasUpdatedAt['tripEquipment'] == false`; `SyncService.parentRefs['tripEquipment']` names `tripId -> trips` and `equipmentId -> equipment`, both non-nullable. (Use the public or `@visibleForTesting` accessors `trip_cylinders_sync_test.dart` uses.)

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/services/sync/trip_equipment_sync_test.dart`
Expected: FAIL (unknown entity).

- [ ] **Step 3: Register every arm**

`sync_repository.dart` `hlcTargets`, after `'tripCylinders'`:

```dart
    'tripEquipment': (table: 'trip_equipment', pk: 'id'),
```

`sync_service.dart`:

- `mergeOrder`, right after the `equipmentShares` entry:

```dart
        // After both parents (trips and equipment), issue #2338.
        (
          type: 'tripEquipment',
          records: data.tripEquipment,
          hasUpdatedAt: false,
        ),
```

- `entityHasUpdatedAt`, next to `'equipmentShares': false,`: `'tripEquipment': false,`
- `parentRefs`, after the `equipmentShares` entry:

```dart
    'tripEquipment': [
      (field: 'tripId', parent: 'trips', nullable: false),
      (field: 'equipmentId', parent: 'equipment', nullable: false),
    ],
```

`sync_data_serializer.dart`, each next to its `equipmentShares` twin:

- `SyncData` field `final List<Map<String, dynamic>> tripEquipment;`, ctor `this.tripEquipment = const [],`, `toJson` `'tripEquipment': tripEquipment,`, `fromJson` `tripEquipment: _parseList(json['tripEquipment']),`.
- `_baseTables`: `(key: 'tripEquipment', table: _db.tripEquipment, blob: false, full: null),` at the position matching `toJson` order.
- `parentGatedChildEntities`: `'tripEquipment',`; `parentGatedTables`: `'tripEquipment': 'trip_equipment',`.
- export in `_buildSyncData`:

```dart
      tripEquipment: await _safeExport(
        'tripEquipment',
        () async => _withPendingChildren(
          'tripEquipment',
          await _exportTripEquipment(hlcSince),
          pendingChildren,
        ),
      ),
```

- `_exportTripEquipment`, after `_exportEquipmentShares`:

```dart
  /// Packed gear (v248, issue #2338), gated on the parent trip's clock like
  /// [_exportEquipmentTags] is on the item's. A changed link travels on its
  /// own pending mark, never by re-stamping the trip.
  Future<List<Map<String, dynamic>>> _exportTripEquipment(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final trips = await (_db.select(
        _db.trips,
      )..where((t) => t.hlc.isBiggerThanValue(hlcSince))).get();
      final tripIds = trips.map((t) => t.id).toSet();
      if (tripIds.isEmpty) return [];
      return _childRowsOf(
        tripIds,
        (chunk) => (_db.select(
          _db.tripEquipment,
        )..where((t) => t.tripId.isIn(chunk))).get(),
      );
    }
    final rows = await _db.select(_db.tripEquipment).get();
    return rows.map((r) => r.toJson()).toList();
  }
```

- `fetchRecord`: `case 'tripEquipment': final row = await (_db.select(_db.tripEquipment)..where((t) => t.id.equals(recordId))).getSingleOrNull(); return row?.toJson();`
- `_applyTripEquipmentRecord`, after `_applyEquipmentShareRecord`:

```dart
  /// Applies one incoming `trip_equipment` row (v248, issue #2338). The
  /// (trip, item) pair is unique: a peer's copy under another id is
  /// reconciled to the lower id and then skipped, as
  /// [_applyEquipmentShareRecord] does.
  Future<void> _applyTripEquipmentRecord(TripEquipmentRow record) async {
    await _reconcileJunctionIds(
      'trip_equipment',
      parentColumn: 'trip_id',
      childColumn: 'equipment_id',
      pairs: [
        (parent: record.tripId, child: record.equipmentId, id: record.id),
      ],
    );
    await _db
        .into(_db.tripEquipment)
        .insert(
          record,
          onConflict: DoNothing<$TripEquipmentTable, TripEquipmentRow>(
            target: const [],
          ),
        );
  }
```

- `upsertRecord`: `case 'tripEquipment': await _applyTripEquipmentRecord(TripEquipmentRow.fromJson(data)); return;`
- `upsertRecords`:

```dart
      case 'tripEquipment':
        // DoNothing: see [_applyTripEquipmentRecord].
        final packRows = _lowestIdPerPair(
          records.map((r) => TripEquipmentRow.fromJson(r)).toList(),
          (row) => (parent: row.tripId, child: row.equipmentId, id: row.id),
        );
        await _reconcileJunctionIds(
          'trip_equipment',
          parentColumn: 'trip_id',
          childColumn: 'equipment_id',
          pairs: [
            for (final row in packRows)
              (parent: row.tripId, child: row.equipmentId, id: row.id),
          ],
        );
        await _db.batch(
          (b) => b.insertAll(
            _db.tripEquipment,
            packRows,
            onConflict: DoNothing<$TripEquipmentTable, TripEquipmentRow>(
              target: const [],
            ),
          ),
        );
        return;
```

- `recordIdsFor`: `case 'tripEquipment': return plain(_db.tripEquipment, _db.tripEquipment.id);`
- `_syncTableFor`: `case 'tripEquipment': return _db.tripEquipment;`
- `deleteRecord`: `case 'tripEquipment': await (_db.delete(_db.tripEquipment)..where((t) => t.id.equals(recordId))).go(); return;`

`fetchRecords` and `parentGatedRecordId` need no arm (the parent-gated and default paths cover a uuid id).

- [ ] **Step 4: The hand-maintained lists**

- `sync_parent_refs_completeness_test.dart` `syncedTables`: `'trip_equipment': 'tripEquipment',`
- `sync_data_serializer_batch_coverage_test.dart` `targets`: `(type: 'tripEquipment', table: db.tripEquipment.actualTableName),` (seed a trip and an item the way the list's existing seeding does for its parents; follow the `equipmentShares` entry).

- [ ] **Step 5: Run and commit**

Run: `flutter test test/core/services/sync test/core/data`
Expected: PASS, including the structural guards (`sync_hlc_target_registration_test`, `child_hlc_test`, `pending_child_export_test`, `media_clock_guard_test`, both streaming parity tests, `sync_data_serializer_record_ids_test`).

```bash
git add lib/core test/core
git commit -m "feat(sync): sync packed gear as a parent-gated child of trips"
```

---

### Task 4: The providers

**Files:**
- Create: `lib/features/trips/presentation/providers/trip_equipment_providers.dart`
- Test: `test/features/trips/presentation/providers/trip_equipment_providers_test.dart` (new)
- Modify: `test/architecture/provider_tick_build_smoke_test.dart` (a case per provider)

**Interfaces:**
- Consumes: Task 2's repository and `TripCylinderRepository.tripIdsForEquipment`; existing `allTripsProvider`, `validatedCurrentDiverIdProvider`, `equipmentRepositoryProvider` (`getEquipmentByIds`, `visibleIdsAmong`), `tripCylinderRepositoryProvider`.
- Produces:
  - `final tripEquipmentRepositoryProvider = Provider<TripEquipmentRepository>(...)`
  - `final tripGearProvider = FutureProvider.family<List<EquipmentItem>, String>` (tripId; visible items, sorted by name)
  - `class PackedTrip { final Trip trip; final bool packed; final bool slot; }`
  - `final equipmentTripsProvider = FutureProvider.family<List<PackedTrip>, String>` (equipmentId; ranked)
  - `List<PackedTrip> rankPackedTrips(List<PackedTrip> trips, DateTime now)` (pure, testable)

- [ ] **Step 1: Write the failing tests**

- `rankPackedTrips` (pure): a trip in progress comes first; then upcoming by start date; then past trips, most recent end first. Build `Trip`s with `startDate`/`endDate` relative to a fixed `now = DateTime(2026, 10, 1)`.
- `tripGearProvider lists the trip's visible gear by name`: real test DB, diver `me` owning `bcd` and `tank`, packed for `t1`; with `validatedCurrentDiverIdProvider` overridden to `me`, expect names in order.
- `gear the diver cannot see is left off`: add `other`'s item `reg`, packed for `t1`; the provider for `me` does not include it.
- `equipmentTripsProvider unions packed links and slots`: `tank` packed for `t1`, and a `trip_cylinders` slot on `t2` with `equipmentId: 'tank'`; expect two `PackedTrip`s, `t1` with `packed: true`, `t2` with `slot: true, packed: false`.
- `a trip the diver cannot see is left off`: a slot on another diver's unshared trip does not appear (the provider intersects with `allTripsProvider`).

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/trips/presentation/providers/trip_equipment_providers_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

final tripEquipmentRepositoryProvider = Provider<TripEquipmentRepository>(
  (ref) => TripEquipmentRepository(),
);

/// The gear packed for a trip that the diver can see (owner or sharee),
/// by name (spec section 10.8).
final tripGearProvider = FutureProvider.family<List<EquipmentItem>, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(tripEquipmentRepositoryProvider);
  final equipment = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  ref.invalidateSelfWhen(equipment.watchEquipmentChanges());
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  var ids = await repository.equipmentIdsForTrip(tripId);
  if (diverId != null) {
    ids = (await equipment.visibleIdsAmong(ids, diverId)).toList();
  }
  final items = await equipment.getEquipmentByIds(ids);
  return [...items]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

/// A trip an item is on: packed through `trip_equipment`, a trip gas slot,
/// or both (decided 2026-09-29).
class PackedTrip {
  const PackedTrip({required this.trip, required this.packed, required this.slot});
  final Trip trip;
  final bool packed;
  final bool slot;
}

/// In progress first, then upcoming by start, then past by most recent end.
List<PackedTrip> rankPackedTrips(List<PackedTrip> trips, DateTime now) {
  int group(Trip t) => t.containsDate(now) ? 0 : (t.startsAfter(now) ? 1 : 2);
  return [...trips]..sort((a, b) {
      final ga = group(a.trip), gb = group(b.trip);
      if (ga != gb) return ga.compareTo(gb);
      return ga == 2
          ? b.trip.endDate.compareTo(a.trip.endDate)
          : a.trip.startDate.compareTo(b.trip.startDate);
    });
}

/// The trips [equipmentId] is on, among the trips the diver can see, ranked
/// for the passport's Trip card.
final equipmentTripsProvider = FutureProvider.family<List<PackedTrip>, String>((
  ref,
  equipmentId,
) async {
  final packs = ref.watch(tripEquipmentRepositoryProvider);
  final slots = ref.watch(tripCylinderRepositoryProvider);
  ref.invalidateSelfWhen(packs.watchChanges());
  ref.invalidateSelfWhen(slots.watchTripCylinderChanges());
  final trips = await ref.watch(allTripsProvider.future);
  final packed = await packs.tripIdsForEquipment(equipmentId);
  final slotted = await slots.tripIdsForEquipment(equipmentId);
  return rankPackedTrips([
    for (final trip in trips)
      if (packed.contains(trip.id) || slotted.contains(trip.id))
        PackedTrip(
          trip: trip,
          packed: packed.contains(trip.id),
          slot: slotted.contains(trip.id),
        ),
  ], DateTime.now());
});
```

- [ ] **Step 4: The smoke list, run and commit**

Add a case for `tripGearProvider` and `equipmentTripsProvider` to `provider_tick_build_smoke_test.dart`, following the `equipmentSharesProvider` case.

Run: `flutter test test/features/trips test/architecture`
Expected: PASS.

```bash
git add lib/features/trips test/features/trips test/architecture
git commit -m "feat(trips): providers for a trip's gear and an item's trips"
```

---

### Task 5: The passport Trip card

**Files:**
- Create: `lib/features/cylinder_passports/presentation/widgets/passport_trip_card.dart`
- Modify: `lib/features/cylinder_passports/presentation/pages/passport_page.dart` (after `PassportTagCard(...)` in the card column)
- Modify: all 11 ARBs
- Test: `test/features/cylinder_passports/presentation/widgets/passport_trip_card_test.dart` (new)
- Modify: `test/features/cylinder_passports/presentation/pages/passport_page_test.dart` (override `equipmentTripsProvider(id)` to `const []` in `pump`)

**Interfaces:**
- Consumes: Task 4's `equipmentTripsProvider`, `PackedTrip`, `tripEquipmentRepositoryProvider`; existing `TripPickerSheet`.
- Produces: `PassportTripCard({required String equipmentId})`.

New English strings (`passport_trip_*`):

| Key | English |
| --- | --- |
| `passport_trip_title` | Trips |
| `passport_trip_none` | Not packed for a trip |
| `passport_trip_packedFor` | Packed for {trip} (placeholder `trip`, String) |
| `passport_trip_more` | +{count} (placeholder `count`, int) |
| `passport_trip_assign` | Pack for a trip |
| `passport_trip_unassign` | Unpack from this trip |
| `passport_trip_onBoard` | On the trip's cylinder board |
| `passport_trip_failed` | Could not change the trip. Try again. |

- [ ] **Step 1: Write the failing tests**

Pump `PassportTripCard(equipmentId: 'tank')` in `testApp` with `getBaseOverrides()` and `equipmentTripsProvider('tank').overrideWith((ref) async => trips)`:

- `with no trips it says so and offers Pack for a trip`.
- `shows the first trip and +N for the rest`: three trips; the first chip reads `Packed for <first>`, a `+2` chip is present, the other names are not shown; tapping `+2` shows them all.
- `Unassign unpacks a packed trip`: a packed trip; tap the chip's delete icon (tooltip `passport_trip_unassign`); a fake `TripEquipmentRepository` (override `tripEquipmentRepositoryProvider`) records `unpack('t1', 'tank')`.
- `a slot-only trip shows without Unassign`: `PackedTrip(slot: true, packed: false)`; the chip has no delete icon and its tooltip is `passport_trip_onBoard`.
- `Pack for a trip packs the picked trip`: override `allTripsProvider` with one trip; tap `passport_trip_assign`; tap the trip in the picker; the fake records `pack('t1', ['tank'])`.
- `a failed unpack says so`: the fake throws; the snack bar shows `passport_trip_failed`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/cylinder_passports/presentation/widgets/passport_trip_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

A `ConsumerStatefulWidget` (it holds `_expanded`), in the passport card pattern (`Card` > `Padding(all: 16)` > `Column(start)` with a `titleMedium` title and `SizedBox(height: 8)`):

- `final trips = ref.watch(equipmentTripsProvider(widget.equipmentId)).value ?? const [];`
- Empty: `Text(l10n.passport_trip_none)`.
- Otherwise a `Wrap(spacing: 8, runSpacing: 8)` of chips for `_expanded ? trips : trips.take(1)`, each a `Chip(key: Key('passport-trip-${p.trip.id}'), avatar: Icon(p.packed ? Icons.luggage_outlined : Icons.propane_tank_outlined, size: 18), label: Text(l10n.passport_trip_packedFor(p.trip.name)), visualDensity: VisualDensity.compact, onDeleted: p.packed ? () => _unpack(p.trip) : null, deleteButtonTooltipMessage: l10n.passport_trip_unassign)`, wrapped in a `Tooltip(message: l10n.passport_trip_onBoard)` when `!p.packed`, and in an `InkWell` whose tap does `context.push('/trips/${p.trip.id}')`; plus, when not expanded and `trips.length > 1`, an `ActionChip(key: Key('passport-trip-more'), label: Text(l10n.passport_trip_more(trips.length - 1)), onPressed: () => setState(() => _expanded = true))`.
- Bottom-right `Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(key: Key('passport-trip-assign'), icon: Icon(Icons.add), label: Text(l10n.passport_trip_assign), onPressed: _assign))`.
- `_assign`: capture `messenger` and `l10n`; open `TripPickerSheet` in a `DraggableScrollableSheet` exactly as `dive_edit_page.dart`'s `_showTripPicker` does (selectedTrip null; `onCreateNewTrip` pops with nothing, since packing a brand-new trip starts from the trip page); on a pick, `await ref.read(tripEquipmentRepositoryProvider).pack(trip.id, [widget.equipmentId])` in a try; on error `_log.error` and `messenger.showSnackBar(SnackBar(content: Text(l10n.passport_trip_failed)))`.
- `_unpack(trip)`: the same try/catch around `unpack(trip.id, widget.equipmentId)`.
- `const _log = LoggerService('passportTripCard');`

Add it to the passport page after the Tag card:

```dart
              const SizedBox(height: 16),
              PassportTripCard(equipmentId: equipment.id),
```

Add the ARB keys (English above; translate for the other 10 locales, following each file's existing `passport_*` terms; `passport_trip_more` is `+{count}` everywhere).

- [ ] **Step 4: Run and commit**

Run: `flutter gen-l10n`, then `flutter test test/features/cylinder_passports test/l10n`
Expected: PASS.

```bash
git add lib test
git commit -m "feat(passports): a Trip card shows the trips a cylinder is packed for"
```

---

### Task 6: The trip page Gear card

**Files:**
- Create: `lib/features/trips/presentation/widgets/trip_gear_card.dart`
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart` (the four `TripCylindersCard(trip: trip),` lines, each followed by `TripGearCard(trip: trip),`)
- Modify: all 11 ARBs
- Test: `test/features/trips/presentation/widgets/trip_gear_card_test.dart` (new)

**Interfaces:**
- Consumes: Task 4's `tripGearProvider`, `tripEquipmentRepositoryProvider`; existing `EquipmentPickerSheet`.
- Produces: `TripGearCard({required Trip trip})`.

New English strings (`trips_gear_*`):

| Key | English |
| --- | --- |
| `trips_gear_title` | Gear |
| `trips_gear_none` | No gear packed yet |
| `trips_gear_add` | Add gear |
| `trips_gear_remove` | Unpack |
| `trips_gear_failed` | Could not change the gear. Try again. |

- [ ] **Step 1: Write the failing tests**

Pump `TripGearCard(trip: trip)` in `testApp` with `settingsProvider` overridden and `tripGearProvider('t1').overrideWith(...)`:

- `renders nothing while the gear is loading`: override with a `Completer` future that never completes; `find.byType(Card)` finds nothing.
- `an upcoming trip with no gear offers Add gear`.
- `a past trip with no gear shows nothing`.
- `lists the packed gear by name`.
- `Unpack removes the item`: a fake repository records `unpack('t1', 'bcd')` after tapping a chip's delete icon (tooltip `trips_gear_remove`).
- `Add gear packs the picked item`: override `activeEquipmentProvider` with one item; tap `trips_gear_add`; tap the item in `EquipmentPickerSheet`; the fake records `pack('t1', ['bcd'])`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/trips/presentation/widgets/trip_gear_card_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

Follow `TripCylindersCard`'s shell: `ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction)` with `static const double maxHeightFraction = 0.25;`, then `Card(margin: EdgeInsets.fromLTRB(16, 8, 16, 0), clipBehavior: Clip.antiAlias)`, then `SingleChildScrollView(padding: EdgeInsets.all(16))`:

- `final items = ref.watch(tripGearProvider(trip.id)).value;` `if (items == null || (items.isEmpty && !trip.isUpcoming)) return const SizedBox.shrink();`
- Header `Row [Icon(Icons.luggage_outlined, color: primary), SizedBox(width: 8), Expanded(Text(l10n.trips_gear_title, style: titleMedium)), TextButton(key: Key('trip-gear-add'), onPressed: _add, child: Text(l10n.trips_gear_add))]`.
- Empty: `Text(l10n.trips_gear_none)`.
- Otherwise `Wrap(spacing: 6, runSpacing: 6)` of `InputChip(key: Key('trip-gear-${item.id}'), label: Text(item.name), visualDensity: VisualDensity.compact, onDeleted: () => _remove(item), deleteButtonTooltipMessage: l10n.trips_gear_remove)`.
- `_add`: `showModalBottomSheet` + `DraggableScrollableSheet(initialChildSize: 0.7, minChildSize: 0.5, maxChildSize: 0.95, expand: false)` with `EquipmentPickerSheet(scrollController: ..., selectedEquipmentIds: {for (final i in items) i.id}, onEquipmentSelected: (item) { Navigator.of(sheetContext).pop(); _pack(item); })`, as `dive_edit_page.dart` does.
- `_pack` and `_remove` wrap the repository call in try/catch with `messenger.showSnackBar(SnackBar(content: Text(l10n.trips_gear_failed)))` and `_log.error`.

In `trip_detail_page.dart`, add `TripGearCard(trip: trip),` after each of the four `TripCylindersCard(trip: trip),` lines. Edit each with enough context to be unique (the following `Expanded(child: body)` or `Expanded(child: tabbedBody)`, and the embedded header for the embedded variants), and import the widget next to `trip_cylinders_card.dart`.

- [ ] **Step 4: Run and commit**

Run: `flutter gen-l10n`, then `flutter test test/features/trips test/l10n`
Expected: PASS, with `trip_detail_page_test.dart` and `trip_detail_checklist_test.dart` unchanged and green.

```bash
git add lib test
git commit -m "feat(trips): a Gear card on the trip page packs and unpacks gear"
```

---

## Final: whole-branch checks

- [ ] Re-check open PRs for a schema-version collision with 248; renumber everywhere (table comment, database.dart, rung, backstop, test name and pins) if taken.
- [ ] `dart format .`, `flutter analyze` (no issues, infos included), `flutter test test/architecture`, and the full suite once (`scripts/run_all_tests.sh`).
- [ ] The PR body: summary, `Closes #2338`, `Refs #2333`, screenshots of the passport Trip card (none, one, "+N" expanded, a slot-only chip) and the trip page Gear card (empty upcoming, with gear), light and dark, phone and desktop widths.
