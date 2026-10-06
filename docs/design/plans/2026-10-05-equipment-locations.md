# Equipment Locations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in one session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver keep a list of named places and record where each piece of gear is, with history, bulk moves, a list filter, list grouping, a Manage page and CSV round trip.

**Architecture:** Two new synced tables: `equipment_locations` (a per-diver catalog, top-level sync entity) and `equipment_location_moves` (an append-only log, parent-gated child of `equipment`). An item's current location is its newest move, computed in SQL by one shared expression; nothing else stores it. UI reads it through Riverpod providers that self-invalidate on table ticks.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), go_router, the in-app query language (`lib/core/query`), ARB localization (11 locales).

**Spec:** `docs/design/specs/2026-10-05-equipment-locations-design.md`

## Global Constraints

- Schema version for this feature: **267** (`currentSchemaVersion = 267`), renumbered to **268** at merge time when main reached 264 and #3010 claimed 267. Claims as of 2026-10-05: 262 #2991/#2999, 264 #3010/#3009/#3005/#3007/#2999, 265 #3011, 266 #3001. Re-check open PR diffs before merging.
- Place kinds, stored by name: `storage`, `serviceShop`, `person`, `other`. Unknown names read as `other`.
- Current location ordering, everywhere (SQL and Dart): `moved_at DESC, created_at DESC, id DESC`.
- Status offer: Service shop offers In Service unless status is In Service, Retired or Sold; Person offers Loaned Out unless Loaned Out, Retired or Sold; Storage offers Active only from In Service, Loaned Out or Lost; Other and No location offer nothing.
- Parts offered on a move: transitive assembly components and installed children, excluding Retired and Sold, excluding items already being moved.
- A place referenced by any move can only be archived; only an unreferenced place can be deleted.
- Places are per diver (`diver_id`); no unique constraint on the name.
- Group-by-location is an Equipment-page-only setting under the app settings key `equipment_group_by_location` (`'true'`/`'false'`), separate from `EquipmentArrangement`.
- No em dashes or en dashes as punctuation in any code, comment, string or commit.
- No mention of Claude, Claude Code or Anthropic in any commit, comment or file.
- Every user-facing string goes in `app_en.arb` and all 10 other ARBs; run `flutter gen-l10n` last, after translations.
- Paths in tests via `p.join`; tests restore any global state they change.
- After adding files under `lib/`: run `test/architecture/` and `test/shared/`.
- `dart format .` before every commit.

## Review Focus

1. **Two moves with the same `moved_at`** (a bulk move then an immediate correction, or a backdated move landing on an existing timestamp): the newest-created one must win. Pinned in Task 4 (`ties on moved_at break by created_at`).
2. **Deleting the place an item is currently at, from another device** (sync delivers a move whose place is gone): the item must read "No location", not crash or vanish from lists. Pinned in Task 4 (`a move whose place was deleted reads as no location`).
3. **Moving an assembly whose part is already in the selection:** the part must be moved once, not twice, and not counted in the parts prompt. Pinned in Task 4 (`partsOf excludes the given ids and retired parts`).
4. **CSV re-import of a file onto gear already at that place:** no duplicate history entry. Pinned in Task 13 (`re-import onto an item already there writes no move`).
5. **Group by location with a place the diver has archived:** the heading still renders with the archived place's name. Pinned in Task 11 (`archived place still heads its items`).

---

## File Structure

**Create**
- `lib/features/equipment/domain/entities/equipment_location.dart`: `EquipmentLocationKind`, `EquipmentLocation`.
- `lib/features/equipment/domain/entities/equipment_location_move.dart`: `EquipmentLocationMove`, `compareMovesNewestFirst`.
- `lib/features/equipment/domain/services/location_status_offer.dart`: `offeredStatusAfterMove`.
- `lib/features/equipment/domain/services/equipment_location_arranger.dart`: `EquipmentLocationSection`, `arrangeEquipmentByLocation`.
- `lib/features/equipment/data/equipment_location_sql.dart`: the shared current-location SQL.
- `lib/core/database/tables/equipment_location_tables.dart`: the two Drift tables.
- `lib/core/database/migrations/helpers/equipment_location_migrations.dart`: v267 helper and grouped backstop.
- `lib/features/equipment/data/repositories/equipment_location_repository.dart`: places.
- `lib/features/equipment/data/repositories/equipment_location_move_repository.dart`: moves, current locations, parts.
- `lib/features/equipment/data/services/equipment_move_flow.dart`: move orchestration (parts prompt, status offer).
- `lib/features/divers/data/repositories/diver_location_retirement.dart`: `retireDiverEquipmentLocations`.
- `lib/features/equipment/presentation/providers/equipment_location_providers.dart`.
- `lib/features/equipment/presentation/utils/equipment_location_display.dart`: kind labels and icons.
- `lib/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart`: create/edit a place.
- `lib/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart`: pick a place.
- `lib/features/equipment/presentation/widgets/move_equipment_sheet.dart`: date, note, place; plus `showMoveEquipmentFlow`.
- `lib/features/equipment/presentation/widgets/equipment_location_card.dart`: detail page card and history.
- `lib/features/equipment/presentation/widgets/location_move_edit_dialog.dart`: edit or delete one move.
- `lib/features/equipment/presentation/widgets/equipment_location_filter_section.dart`.
- `lib/features/equipment/presentation/widgets/equipment_location_group_header.dart`.
- `lib/features/equipment/presentation/widgets/group_by_location_switch.dart`.
- `lib/features/equipment/presentation/widgets/equipment_location_field.dart`: create form picker.
- `lib/features/equipment/presentation/pages/equipment_location_list_page.dart`.
- `lib/features/equipment/presentation/pages/equipment_location_detail_page.dart`.
- `lib/features/dive_import/data/services/import_equipment_location_linker.dart`.
- Tests mirroring each under `test/`.

**Modify** (anchors given in each task): `database.dart`, `app_database_migrations.dart`, `rungs_v231_onward.dart`, `before_open.dart`, `sync_migrations.dart`, `performance_indexes.dart`, `sync_data_serializer.dart`, `sync_service.dart`, `sync_repository.dart`, `conflict_reference.dart`, `conflict_reference_labels.dart`, `equipment_repository_impl.dart`, `equipment_providers.dart`, `diver_delete_steps.dart`, `diver_repository.dart`, `equipment_filter_state.dart`, `equipment_filter_query.dart`, `equipment_query_entity.dart`, `query_label_lookup.dart`, `equipment_filter_sheet.dart`, `equipment_list_content.dart`, `equipment_sort_sheet_layout.dart`, `equipment_list_sort_sheet.dart`, `app_settings_repository.dart`, `equipment_detail_page.dart`, `equipment_edit_page.dart`, `app_router.dart`, `settings_page.dart`, CSV writer/service/export providers, CSV parser, `uddf_entity_importer.dart`, `universal_adapter.dart`, all 11 ARBs, plus the guard tests named in Tasks 2, 3 and 5.

---

### Task 1: Domain entities, ordering and the status offer

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_location.dart`
- Create: `lib/features/equipment/domain/entities/equipment_location_move.dart`
- Create: `lib/features/equipment/domain/services/location_status_offer.dart`
- Test: `test/features/equipment/domain/entities/equipment_location_test.dart`
- Test: `test/features/equipment/domain/services/location_status_offer_test.dart`

**Interfaces:**
- Produces:
  - `enum EquipmentLocationKind { storage, serviceShop, person, other }` with `static EquipmentLocationKind fromName(String? name)`.
  - `class EquipmentLocation` (`id`, `diverId`, `name`, `kind`, `notes`, `isArchived`, `createdAt`, `updatedAt`, `copyWith`).
  - `class EquipmentLocationMove` (`id`, `equipmentId`, `String? locationId`, `movedAt`, `note`, `createdAt`, `copyWith({..., bool clearLocation = false})`).
  - `int compareMovesNewestFirst(EquipmentLocationMove a, EquipmentLocationMove b)`.
  - `EquipmentStatus? offeredStatusAfterMove(EquipmentLocationKind? kind, EquipmentStatus current)`.

- [ ] **Step 1: Write the failing tests**

`test/features/equipment/domain/entities/equipment_location_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';

void main() {
  group('EquipmentLocationKind.fromName', () {
    test('reads every stored name', () {
      for (final kind in EquipmentLocationKind.values) {
        expect(EquipmentLocationKind.fromName(kind.name), kind);
      }
    });

    test('an unknown or missing name reads as other', () {
      expect(EquipmentLocationKind.fromName('vault'), EquipmentLocationKind.other);
      expect(EquipmentLocationKind.fromName(null), EquipmentLocationKind.other);
    });
  });

  group('compareMovesNewestFirst', () {
    EquipmentLocationMove move(String id, int movedAt, int createdAt) =>
        EquipmentLocationMove(
          id: id,
          equipmentId: 'e',
          locationId: 'l',
          movedAt: DateTime.fromMillisecondsSinceEpoch(movedAt),
          note: '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
        );

    test('orders by moved_at, then created_at, then id, newest first', () {
      final moves = [
        move('a', 100, 1),
        move('c', 200, 1),
        move('b', 200, 1),
        move('d', 200, 5),
      ]..sort(compareMovesNewestFirst);
      expect([for (final m in moves) m.id], ['d', 'c', 'b', 'a']);
    });
  });

  test('copyWith can clear the location', () {
    final m = EquipmentLocationMove(
      id: 'm',
      equipmentId: 'e',
      locationId: 'l',
      movedAt: DateTime(2026),
      note: '',
      createdAt: DateTime(2026),
    );
    expect(m.copyWith(clearLocation: true).locationId, isNull);
    expect(m.copyWith(note: 'x').locationId, 'l');
  });
}
```

`test/features/equipment/domain/services/location_status_offer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/location_status_offer.dart';

void main() {
  const s = EquipmentStatus.values;

  test('a service shop offers In Service except from In Service, Retired, Sold', () {
    for (final status in s) {
      final expected = {
        EquipmentStatus.inService,
        EquipmentStatus.retired,
        EquipmentStatus.sold,
      }.contains(status)
          ? null
          : EquipmentStatus.inService;
      expect(
        offeredStatusAfterMove(EquipmentLocationKind.serviceShop, status),
        expected,
        reason: status.name,
      );
    }
  });

  test('a person offers Loaned Out except from Loaned Out, Retired, Sold', () {
    for (final status in s) {
      final expected = {
        EquipmentStatus.loaned,
        EquipmentStatus.retired,
        EquipmentStatus.sold,
      }.contains(status)
          ? null
          : EquipmentStatus.loaned;
      expect(
        offeredStatusAfterMove(EquipmentLocationKind.person, status),
        expected,
        reason: status.name,
      );
    }
  });

  test('storage offers Active only from In Service, Loaned Out or Lost', () {
    for (final status in s) {
      final expected = {
        EquipmentStatus.inService,
        EquipmentStatus.loaned,
        EquipmentStatus.lost,
      }.contains(status)
          ? EquipmentStatus.active
          : null;
      expect(
        offeredStatusAfterMove(EquipmentLocationKind.storage, status),
        expected,
        reason: status.name,
      );
    }
  });

  test('other and no location offer nothing', () {
    for (final status in s) {
      expect(offeredStatusAfterMove(EquipmentLocationKind.other, status), isNull);
      expect(offeredStatusAfterMove(null, status), isNull);
    }
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/domain/entities/equipment_location_test.dart test/features/equipment/domain/services/location_status_offer_test.dart`
Expected: compile errors (the files under test do not exist).

- [ ] **Step 3: Implement**

`lib/features/equipment/domain/entities/equipment_location.dart`:

```dart
import 'package:equatable/equatable.dart';

/// What kind of place an [EquipmentLocation] is. Stored by [name]. The
/// order is the heading order when the Equipment page groups by location.
enum EquipmentLocationKind {
  storage,
  serviceShop,
  person,
  other;

  /// A name this build does not know (written by a newer peer), or none,
  /// reads as [other] rather than failing.
  static EquipmentLocationKind fromName(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return other;
  }
}

/// One of a diver's named places where gear can be: a shelf, a shop, a
/// friend. Archived places leave the picker but stay in history.
class EquipmentLocation extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final EquipmentLocationKind kind;
  final String notes;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EquipmentLocation({
    required this.id,
    this.diverId,
    required this.name,
    required this.kind,
    this.notes = '',
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  EquipmentLocation copyWith({
    String? id,
    String? diverId,
    String? name,
    EquipmentLocationKind? kind,
    String? notes,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EquipmentLocation(
    id: id ?? this.id,
    diverId: diverId ?? this.diverId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    notes: notes ?? this.notes,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    kind,
    notes,
    isArchived,
    createdAt,
    updatedAt,
  ];
}
```

`lib/features/equipment/domain/entities/equipment_location_move.dart`:

```dart
import 'package:equatable/equatable.dart';

/// One entry of an item's location log. A null [locationId] records that
/// the location was cleared. The item's current location is its newest
/// move by [compareMovesNewestFirst].
class EquipmentLocationMove extends Equatable {
  final String id;
  final String equipmentId;
  final String? locationId;
  final DateTime movedAt;
  final String note;
  final DateTime createdAt;

  const EquipmentLocationMove({
    required this.id,
    required this.equipmentId,
    required this.locationId,
    required this.movedAt,
    this.note = '',
    required this.createdAt,
  });

  EquipmentLocationMove copyWith({
    String? locationId,
    bool clearLocation = false,
    DateTime? movedAt,
    String? note,
  }) => EquipmentLocationMove(
    id: id,
    equipmentId: equipmentId,
    locationId: clearLocation ? null : (locationId ?? this.locationId),
    movedAt: movedAt ?? this.movedAt,
    note: note ?? this.note,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    locationId,
    movedAt,
    note,
    createdAt,
  ];
}

/// Newest first: moved_at, then created_at, then id, each descending. The
/// SQL in `equipment_location_sql.dart` orders the same way, so the history
/// a card shows and the location the list reads always agree.
int compareMovesNewestFirst(EquipmentLocationMove a, EquipmentLocationMove b) {
  final byMoved = b.movedAt.compareTo(a.movedAt);
  if (byMoved != 0) return byMoved;
  final byCreated = b.createdAt.compareTo(a.createdAt);
  if (byCreated != 0) return byCreated;
  return b.id.compareTo(a.id);
}
```

`lib/features/equipment/domain/services/location_status_offer.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

/// The status worth offering after an item moves to a place of [kind], or
/// null when the offer would change nothing useful. [kind] is null for a
/// move to "No location". The diver confirms every offer.
EquipmentStatus? offeredStatusAfterMove(
  EquipmentLocationKind? kind,
  EquipmentStatus current,
) {
  const terminal = {EquipmentStatus.retired, EquipmentStatus.sold};
  switch (kind) {
    case EquipmentLocationKind.serviceShop:
      if (current == EquipmentStatus.inService || terminal.contains(current)) {
        return null;
      }
      return EquipmentStatus.inService;
    case EquipmentLocationKind.person:
      if (current == EquipmentStatus.loaned || terminal.contains(current)) {
        return null;
      }
      return EquipmentStatus.loaned;
    case EquipmentLocationKind.storage:
      const away = {
        EquipmentStatus.inService,
        EquipmentStatus.loaned,
        EquipmentStatus.lost,
      };
      return away.contains(current) ? EquipmentStatus.active : null;
    case EquipmentLocationKind.other:
    case null:
      return null;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/domain/entities/equipment_location_test.dart test/features/equipment/domain/services/location_status_offer_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/domain test/features/equipment/domain
git add lib/features/equipment/domain/entities/equipment_location.dart lib/features/equipment/domain/entities/equipment_location_move.dart lib/features/equipment/domain/services/location_status_offer.dart test/features/equipment/domain/entities/equipment_location_test.dart test/features/equipment/domain/services/location_status_offer_test.dart
git commit -m "feat(equipment): location entities, move ordering and status offer"
```

---

### Task 2: Schema v267, migration and backstop

**Files:**
- Create: `lib/core/database/tables/equipment_location_tables.dart`
- Create: `lib/core/database/migrations/helpers/equipment_location_migrations.dart`
- Modify: `lib/core/database/database.dart` (imports near line 15 and 42, tables list near line 148, `currentSchemaVersion` line 235, `migrationVersions` tail near line 1093)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part list)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (append after the v263 rung)
- Modify: `lib/core/database/migrations/before_open.dart:172` (replace the v234 call)
- Modify: `lib/core/database/migrations/helpers/sync_migrations.dart:90` (`_assertChildHlcColumns` list)
- Modify: `lib/core/database/performance_indexes.dart` (after `idx_equipment_ownership_events_equipment`)
- Test: `test/core/database/migration_v267_equipment_locations_test.dart`

**Interfaces:**
- Produces: Drift tables `EquipmentLocations` (getter `equipmentLocations`, row `EquipmentLocationRow`, companion `EquipmentLocationsCompanion`) and `EquipmentLocationMoves` (getter `equipmentLocationMoves`, row `EquipmentLocationMoveRow`, companion `EquipmentLocationMovesCompanion`). SQL tables `equipment_locations`, `equipment_location_moves`.

- [ ] **Step 1: Write the failing migration test**

`test/core/database/migration_v267_equipment_locations_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v267: equipment locations and their move log.
void main() {
  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<Set<String>> indexesOf(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA index_list('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v267 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(267));
    expect(AppDatabase.migrationVersions, contains(267));
  });

  test('a fresh database has both tables and their indexes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columnsOf(db, 'equipment_locations'), {
      'id',
      'diver_id',
      'name',
      'kind',
      'notes',
      'is_archived',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(await columnsOf(db, 'equipment_location_moves'), {
      'id',
      'equipment_id',
      'location_id',
      'moved_at',
      'note',
      'created_at',
      'hlc',
    });
    expect(
      await indexesOf(db, 'equipment_location_moves'),
      containsAll([
        'idx_equipment_location_moves_equipment',
        'idx_equipment_location_moves_location',
      ]),
    );
  });

  test('the beforeOpen backstop recreates the tables when missing', () async {
    final raw = NativeDatabase.memory();
    var db = AppDatabase(raw);
    await db.customSelect('SELECT 1').get();
    await db.customStatement('DROP TABLE equipment_location_moves');
    await db.customStatement('DROP TABLE equipment_locations');
    await db.close();
    // A file at 267 that lacks the tables: reopen and let beforeOpen heal.
    db = AppDatabase(raw);
    addTearDown(db.close);
    expect(await columnsOf(db, 'equipment_locations'), contains('kind'));
    expect(await columnsOf(db, 'equipment_location_moves'), contains('moved_at'));
  });
}
```

Note for the executor: `NativeDatabase.memory()` does not survive `close()`. If the reopen case cannot reuse it, write the second test the way `migration_v234_equipment_sharing_test.dart` does: a `NativeDatabase.memory(setup: ...)` fixture that creates `divers` and `equipment` and sets `PRAGMA user_version = 267`, then open `AppDatabase` on it and assert the tables exist.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v267_equipment_locations_test.dart`
Expected: FAIL (no 267 in the ladder, tables missing).

- [ ] **Step 3: Add the tables**

`lib/core/database/tables/equipment_location_tables.dart`:

```dart
/// Equipment locations: a diver's named places and each item's move log.
library;

// Table classes are pure drift DSL. build_runner reads the column
// getter bodies to generate the `$<Table>Table` subclasses, whose
// fields override the getters, so the bodies never run and no test
// can cover them.
// coverage:ignore-file

import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';
import 'package:submersion/core/database/tables/equipment_tables.dart';

/// A diver's named places where gear can be (v267). No unique name: a
/// diver merge or a two-device race would otherwise fail; the Manage page
/// warns about a duplicate instead.
@DataClassName('EquipmentLocationRow')
class EquipmentLocations extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().nullable().references(Divers, #id)();
  TextColumn get name => text()();

  /// An `EquipmentLocationKind` name: storage, serviceShop, person, other.
  TextColumn get kind => text().withDefault(const Constant('other'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Each item's location log (v267). The newest move by moved_at, then
/// created_at, then id is where the item is now; a null location_id
/// records a cleared location. A parent-gated child of equipment in sync.
@DataClassName('EquipmentLocationMoveRow')
class EquipmentLocationMoves extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get locationId => text().nullable().references(
    EquipmentLocations,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get movedAt => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get createdAt => integer()();

  /// This child's own clock, stamped when it is marked pending
  /// (SyncDataSerializer.parentGatedChildEntities).
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

In `lib/core/database/database.dart`: add `import 'package:submersion/core/database/tables/equipment_location_tables.dart';` beside the `equipment_tables.dart` import (line 15), and `export 'package:submersion/core/database/tables/equipment_location_tables.dart';` beside its export (line 42). In the `@DriftDatabase(tables: [...])` list, add `EquipmentLocations, EquipmentLocationMoves,` right after `EquipmentOwnershipEvents,` (line 148). Set `static const int currentSchemaVersion = 267;` and append to `migrationVersions` after `263,`:

```dart
    // 267: equipment locations and their move log. 264-266 are held by
    // open branches (#3010, #3011, #3001).
    267,
```

- [ ] **Step 4: Add the helper part file and wire it**

`lib/core/database/migrations/helpers/equipment_location_migrations.dart`:

```dart
part of '../app_database_migrations.dart';

/// Equipment locations (v267).
extension EquipmentLocationMigrations on AppDatabase {
  /// Idempotent creation of `equipment_locations` and
  /// `equipment_location_moves`. Their indexes are in the canonical
  /// performance set, which beforeOpen asserts on every open. Skipped on a
  /// partial fixture without the parent tables, so its foreign keys never
  /// point nowhere. Safe from both the v267 rung and the beforeOpen
  /// backstop.
  Future<void> _assertEquipmentLocationSchema() async {
    for (final parent in const ['equipment', 'divers']) {
      final rows = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(parent)],
      ).get();
      if (rows.isEmpty) return;
    }
    await Migrator(this).createTable(equipmentLocations);
    await Migrator(this).createTable(equipmentLocationMoves);
  }

  /// The beforeOpen backstop for the equipment child schemas: v234's
  /// sharing tables and v267's location tables. Grouped so the backstop
  /// list in before_open.dart does not grow past its size cap.
  Future<void> _assertEquipmentSchemaBackstops() async {
    await _assertEquipmentSharingSchema();
    await _assertEquipmentLocationSchema();
  }
}
```

Note: `Migrator.createTable` issues `CREATE TABLE IF NOT EXISTS`, as the v234 helper relies on.

In `app_database_migrations.dart` add `part 'helpers/equipment_location_migrations.dart';` after `part 'helpers/equipment_condition_migrations.dart';`.

In `before_open.dart`, replace lines 169-172:

```dart
    // v234 and v267 backstops: the equipment sharing tables and share pair
    // index, and the equipment location tables (parallel-branch
    // version-collision self-heal; all idempotent).
    await _assertEquipmentSchemaBackstops();
```

Keep the file at or under its current 794 lines (this replacement is net zero lines; check with `wc -l`).

In `rungs_v231_onward.dart`, after the v263 block and its `reportProgress`:

```dart
    // v267: equipment locations and their move log. Re-asserted in
    // beforeOpen. 264-266 are held by open branches.
    if (from < 267) {
      await _assertEquipmentLocationSchema();
    }
    if (from < 267) await reportProgress();
```

In `sync_migrations.dart` `_assertChildHlcColumns`, add `'equipment_location_moves',` after `'equipment_ownership_events',`.

In `performance_indexes.dart`, after the `idx_equipment_ownership_events_equipment` entry:

```dart
  // An item's location history, newest first, and its current location
  // (v267).
  (
    name: 'idx_equipment_location_moves_equipment',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_equipment_location_moves_equipment '
        'ON equipment_location_moves(equipment_id, moved_at)',
  ),
  // "Is this place used anywhere", for archive versus delete (v267).
  (
    name: 'idx_equipment_location_moves_location',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_equipment_location_moves_location '
        'ON equipment_location_moves(location_id)',
  ),
```

- [ ] **Step 5: Regenerate and run the tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/core/database/migration_v267_equipment_locations_test.dart test/core/database/performance_indexes_test.dart test/core/database/database_table_libraries_test.dart`
Expected: PASS. If `performance_indexes_test` lists expected index names, add the two new names there.

- [ ] **Step 6: Run the whole database suite**

Run: `flutter test test/core/database > "$SCRATCH/db.log" 2>&1; tail -5 "$SCRATCH/db.log"` (where `$SCRATCH` is the session scratchpad)
Expected: all pass. Fix any test that pins the schema version or the table count by adding 267 / the two tables, following how v263 was added.

- [ ] **Step 7: Commit**

```bash
dart format lib/core/database test/core/database
git add lib/core/database test/core/database
git commit -m "feat(equipment): schema v267 for equipment locations and moves"
```

---

### Task 3: Sync registration

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (every `equipmentOwnershipEvents` and `csvPresets` anchor listed below)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` ~1672, `entityHasUpdatedAt` ~2604, `parentRefs` ~2872)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets` ~167)
- Modify: `lib/core/services/sync/conflict_reference.dart` (`_defaultTargets` ~109)
- Modify: `lib/features/settings/presentation/widgets/conflict_reference_labels.dart` (~74)
- Modify: `lib/l10n/arb/app_en.arb` (`settings_conflict_ref_equipmentLocation`)
- Modify tests: `test/core/services/sync/sync_parent_refs_completeness_test.dart`, `test/features/settings/presentation/widgets/conflict_reference_labels_test.dart`, and any serializer coverage test that enumerates entities (`sync_data_serializer_batch_coverage_test.dart`, `sync_serializer_fetch_record_test.dart`)
- Test: `test/core/services/sync/equipment_location_sync_test.dart`

**Interfaces:**
- Consumes: Task 2 tables.
- Produces: sync entity types `'equipmentLocations'` (top-level, `hasUpdatedAt: true`) and `'equipmentLocationMoves'` (parent-gated child, `hasUpdatedAt: false`).

- [ ] **Step 1: Write the failing round-trip test**

`test/core/services/sync/equipment_location_sync_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    const t = 1000;
    await db.into(db.divers).insert(
      DiversCompanion.insert(id: 'd', name: 'd', createdAt: t, updatedAt: t),
    );
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: 'reg',
        name: 'Reg',
        type: 'regulator',
        createdAt: t,
        updatedAt: t,
        diverId: const Value('d'),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('both entities round-trip through upsertRecord and fetchRecord', () async {
    await serializer.upsertRecord('equipmentLocations', {
      'id': 'loc',
      'diverId': 'd',
      'name': 'Garage',
      'kind': 'storage',
      'notes': '',
      'isArchived': false,
      'createdAt': 1,
      'updatedAt': 2,
      'hlc': null,
    });
    await serializer.upsertRecord('equipmentLocationMoves', {
      'id': 'mv',
      'equipmentId': 'reg',
      'locationId': 'loc',
      'movedAt': 5,
      'note': 'n',
      'createdAt': 6,
      'hlc': null,
    });
    final loc = await serializer.fetchRecord('equipmentLocations', 'loc');
    final mv = await serializer.fetchRecord('equipmentLocationMoves', 'mv');
    expect(loc?['name'], 'Garage');
    expect(mv?['locationId'], 'loc');
    expect(SyncDataSerializer.parentGatedChildEntities, contains('equipmentLocationMoves'));
    expect(
      SyncDataSerializer.parentGatedTables['equipmentLocationMoves'],
      'equipment_location_moves',
    );
  });

  test('a peer edit with a newer clock replaces the move', () async {
    final base = {
      'id': 'mv',
      'equipmentId': 'reg',
      'locationId': null,
      'movedAt': 5,
      'note': 'first',
      'createdAt': 6,
      'hlc': '0000000000001:0000:a',
    };
    await serializer.upsertRecord('equipmentLocationMoves', base);
    await serializer.upsertRecord('equipmentLocationMoves', {
      ...base,
      'note': 'second',
      'hlc': '0000000000002:0000:b',
    });
    final mv = await serializer.fetchRecord('equipmentLocationMoves', 'mv');
    expect(mv?['note'], 'second');
  });
}
```

Before writing this file, check how `test/core/services/sync/sync_serializer_fetch_record_test.dart` constructs the serializer and whether `upsertRecord`/`fetchRecord` take positional or named arguments; match those exactly.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/equipment_location_sync_test.dart`
Expected: FAIL (unknown entity type).

- [ ] **Step 3: Register both entities in the serializer**

In `sync_data_serializer.dart`, add each snippet after the matching `equipmentOwnershipEvents` line:

1. `SyncData` field (after line 356):
```dart
  final List<Map<String, dynamic>> equipmentLocations;
  final List<Map<String, dynamic>> equipmentLocationMoves;
```
2. Constructor (after line 461): `this.equipmentLocations = const [], this.equipmentLocationMoves = const [],`
3. `toJson` (after line 565): `'equipmentLocations': equipmentLocations, 'equipmentLocationMoves': equipmentLocationMoves,`
4. `fromJson` (after line 674):
```dart
      equipmentLocations: _parseList(json['equipmentLocations']),
      equipmentLocationMoves: _parseList(json['equipmentLocationMoves']),
```
5. `_baseTables` (after the ownership events record, line 1207):
```dart
    (
      key: 'equipmentLocations',
      table: _db.equipmentLocations,
      blob: false,
      full: null,
    ),
    (
      key: 'equipmentLocationMoves',
      table: _db.equipmentLocationMoves,
      blob: false,
      full: null,
    ),
```
6. `parentGatedChildEntities` (after line 1611): `'equipmentLocationMoves',`
7. `parentGatedTables` (after line 1838): `'equipmentLocationMoves': 'equipment_location_moves',`
8. `_buildSyncData` (after the ownership events export, line 2423):
```dart
      equipmentLocations: await _safeExport(
        'equipmentLocations',
        () => _exportEquipmentLocations(hlcSince),
      ),
      equipmentLocationMoves: await _safeExport(
        'equipmentLocationMoves',
        () async => _withPendingChildren(
          'equipmentLocationMoves',
          await _exportEquipmentLocationMoves(hlcSince),
          pendingChildren,
        ),
      ),
```
9. `fetchRecord` (after line 2987):
```dart
      case 'equipmentLocations':
        final row = await (_db.select(
          _db.equipmentLocations,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
      case 'equipmentLocationMoves':
        final row = await (_db.select(
          _db.equipmentLocationMoves,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```
10. `fetchRecords` (beside the `csvPresets` case, line 3504; moves are short-circuited by the parent-gated branch):
```dart
      case 'equipmentLocations':
        final rows = await (_db.select(
          _db.equipmentLocations,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```
11. `upsertRecord` (after line 4582):
```dart
      case 'equipmentLocations':
        await _db
            .into(_db.equipmentLocations)
            .insertOnConflictUpdate(
              EquipmentLocationRow.fromJson(
                _withTimestampDefaults(data),
              ).toCompanion(false),
            );
        return;
      case 'equipmentLocationMoves':
        await _db
            .into(_db.equipmentLocationMoves)
            .insertOnConflictUpdate(EquipmentLocationMoveRow.fromJson(data));
        return;
```
12. `upsertRecords` (after line 5825):
```dart
      case 'equipmentLocations':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipmentLocations,
            records
                .map(
                  (r) => EquipmentLocationRow.fromJson(
                    _withTimestampDefaults(r),
                  ).toCompanion(false),
                )
                .toList(),
          ),
        );
        return;
      case 'equipmentLocationMoves':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipmentLocationMoves,
            records.map((r) => EquipmentLocationMoveRow.fromJson(r)).toList(),
          ),
        );
        return;
```
13. `recordIdsFor` (after line 6362):
```dart
      case 'equipmentLocations':
        return plain(_db.equipmentLocations, _db.equipmentLocations.id);
      case 'equipmentLocationMoves':
        return plain(_db.equipmentLocationMoves, _db.equipmentLocationMoves.id);
```
14. `_syncTableFor` (after line 6767):
```dart
      case 'equipmentLocations':
        return _db.equipmentLocations;
      case 'equipmentLocationMoves':
        return _db.equipmentLocationMoves;
```
15. `deleteRecord` (after line 7261):
```dart
      case 'equipmentLocations':
        await (_db.delete(
          _db.equipmentLocations,
        )..where((t) => t.id.equals(recordId))).go();
        return;
      case 'equipmentLocationMoves':
        await (_db.delete(
          _db.equipmentLocationMoves,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```
16. Exporters (after `_exportEquipmentOwnershipEvents`, line 8738):
```dart
  Future<List<Map<String, dynamic>>> _exportEquipmentLocations(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.equipmentLocations);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }

  /// Equipment location moves (v267), gated on the parent item's clock like
  /// [_exportEquipmentOwnershipEvents]; a move edited on its own rides in
  /// through the pending children.
  Future<List<Map<String, dynamic>>> _exportEquipmentLocationMoves(
    String? hlcSince,
  ) async {
    if (hlcSince != null) {
      final itemIds = await _equipmentModifiedSince(hlcSince);
      if (itemIds.isEmpty) return [];
      return _childRowsOf(
        itemIds,
        (chunk) => (_db.select(
          _db.equipmentLocationMoves,
        )..where((t) => t.equipmentId.isIn(chunk))).get(),
      );
    }
    final rows = await _db.select(_db.equipmentLocationMoves).get();
    return rows.map((r) => r.toJson()).toList();
  }
```
17. `deleteAllRecords` (6486) needs no arm if its default falls through to `_syncTableFor`; confirm by reading the switch's `default`.

`_withTimestampDefaults` and `EquipmentLocationRow.fromJson(...).toCompanion(false)` mirror the `csvPresets` arms. If `EquipmentLocationRow.fromJson` rejects a missing `isArchived`, rely on `_withTimestampDefaults` only for timestamps and add the boolean default inline: `{'isArchived': false, ...data}`.

- [ ] **Step 4: Register in the sync service, repository and conflict references**

`sync_service.dart` `mergeOrder`, after the `equipmentOwnershipEvents` record:
```dart
          (
            type: 'equipmentLocations',
            records: data.equipmentLocations,
            hasUpdatedAt: true,
          ),
          // After equipment and the places they point at.
          (
            type: 'equipmentLocationMoves',
            records: data.equipmentLocationMoves,
            hasUpdatedAt: false,
          ),
```
`entityHasUpdatedAt`: add `'equipmentLocations': true,` and `'equipmentLocationMoves': false,` after `'equipmentOwnershipEvents': false,`.
`parentRefs`, after the ownership events entry:
```dart
    // v267: an item's location log. The place reference is cleared, not
    // skipped, when the place is gone: the move then reads "No location".
    'equipmentLocationMoves': [
      (field: 'equipmentId', parent: 'equipment', nullable: false),
      (field: 'locationId', parent: 'equipmentLocations', nullable: true),
    ],
```
`sync_repository.dart` `hlcTargets`, after the ownership events entry:
```dart
    'equipmentLocations': (table: 'equipment_locations', pk: 'id'),
    'equipmentLocationMoves': (table: 'equipment_location_moves', pk: 'id'),
```
`conflict_reference.dart` `_defaultTargets`: add `'locationId': 'equipmentLocations',` after `'serviceKindId': 'serviceKinds',`.
`conflict_reference_labels.dart`, after the `serviceKinds` arm:
```dart
    case 'equipmentLocations':
      return l10n.settings_conflict_ref_equipmentLocation;
```
`app_en.arb`, next to `settings_conflict_ref_serviceKind`:
```json
  "settings_conflict_ref_equipmentLocation": "Equipment location",
  "@settings_conflict_ref_equipmentLocation": {"description": "Names the kind of record a sync conflict field refers to: one of the diver's named places where gear is kept"},
```
Run `flutter gen-l10n` so the getter exists (translations come in Task 15).

- [ ] **Step 5: Update the guard tests' hand-kept maps**

- `sync_parent_refs_completeness_test.dart`: add `'equipment_locations': 'equipmentLocations',` and `'equipment_location_moves': 'equipmentLocationMoves',` to `syncedTables` (after `'equipment_ownership_events'`), and `'equipment_locations': 'equipmentLocations',` to `deletableParents`.
- `conflict_reference_labels_test.dart`: add `'equipmentLocations': ...` to `expected` in the same shape as `serviceKinds`.
- Any coverage test that lists entity types (`sync_data_serializer_batch_coverage_test.dart:157`, `sync_serializer_fetch_record_test.dart:119`): add both types beside `equipmentOwnershipEvents`, with fixture rows shaped like the round-trip test above.

- [ ] **Step 6: Run the sync suites**

Run: `flutter test test/core/services/sync test/core/data test/architecture/child_write_restamps_test.dart test/features/settings/presentation/widgets/conflict_reference_labels_test.dart > "$SCRATCH/sync.log" 2>&1; tail -30 "$SCRATCH/sync.log"`
Expected: all PASS. A failure naming a missing `case` or map entry means an arm above was missed; add it in the same shape as `equipmentOwnershipEvents` (moves) or `csvPresets` (places).

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/core lib/features/settings/presentation/widgets/conflict_reference_labels.dart lib/l10n test/core test/features/settings
git commit -m "feat(equipment): sync equipment locations and moves"
```

---

### Task 4: Repositories for places and moves

**Files:**
- Create: `lib/features/equipment/data/equipment_location_sql.dart`
- Create: `lib/features/equipment/data/repositories/equipment_location_repository.dart`
- Create: `lib/features/equipment/data/repositories/equipment_location_move_repository.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`deleteEquipment` ~621; new `setStatusForMany` after `retireEquipment` ~736)
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart` (`EquipmentListNotifier`, after `reactivateEquipment` ~562)
- Test: `test/features/equipment/data/repositories/equipment_location_repository_test.dart`
- Test: `test/features/equipment/data/repositories/equipment_location_move_repository_test.dart`

**Interfaces:**
- Consumes: Task 1 entities, Task 2 tables.
- Produces:
  - `String currentLocationIdSql(String equipmentIdExpr)` and `const String moveNewestFirstOrderSql`.
  - `EquipmentLocationRepository`: `static const entity = 'equipmentLocations'`; `Stream<void> watchChanges()`; `Future<List<EquipmentLocation>> getLocations({String? diverId})`; `Future<EquipmentLocation?> getLocation(String id)`; `Future<EquipmentLocation> createLocation({required String? diverId, required String name, required EquipmentLocationKind kind, String notes = ''})`; `Future<void> updateLocation(EquipmentLocation location)`; `Future<void> setArchived(String id, {required bool archived})`; `Future<bool> isInUse(String id)`; `Future<void> deleteLocation(String id)`; `Future<EquipmentLocation> findOrCreateByName({required String? diverId, required String name})`.
  - `EquipmentLocationMoveRepository`: `static const entity = 'equipmentLocationMoves'`; `Stream<void> watchChanges()` (moves and places); `Future<List<EquipmentLocationMove>> getMovesFor(String equipmentId)`; `Future<Map<String, String?>> getCurrentLocationIds()`; `Future<List<EquipmentLocationMove>> recordMoves({required Iterable<String> equipmentIds, required String? locationId, required DateTime movedAt, String note = ''})`; `Future<void> updateMove(EquipmentLocationMove move)`; `Future<void> deleteMove(String id)`; `Future<void> deleteForEquipment(String equipmentId)`; `Future<Map<String, EquipmentStatus>> partsOf(Iterable<String> equipmentIds)`.
  - `EquipmentRepository.setStatusForMany(Iterable<String> ids, EquipmentStatus status)` and `EquipmentListNotifier.setStatusForMany(...)`.

- [ ] **Step 1: Write the failing repository tests**

`test/features/equipment/data/repositories/equipment_location_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentLocationRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentLocationRepository();
    const t = 1;
    for (final id in ['me', 'other']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: t, updatedAt: t),
      );
    }
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: 'reg',
        name: 'Reg',
        type: 'regulator',
        createdAt: t,
        updatedAt: t,
        diverId: const Value('me'),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('create trims the name, stamps it pending and lists it', () async {
    final loc = await repo.createLocation(
      diverId: 'me',
      name: '  Garage bin 2 ',
      kind: EquipmentLocationKind.storage,
    );
    expect(loc.name, 'Garage bin 2');
    final pending = await db.select(db.syncRecords).get();
    expect(
      pending.where((r) => r.entityType == 'equipmentLocations' && r.recordId == loc.id),
      isNotEmpty,
    );
    expect((await repo.getLocations(diverId: 'me')).single.id, loc.id);
    expect(await repo.getLocations(diverId: 'other'), isEmpty);
  });

  test('an empty name is rejected', () async {
    expect(
      () => repo.createLocation(
        diverId: 'me',
        name: '   ',
        kind: EquipmentLocationKind.other,
      ),
      throwsArgumentError,
    );
  });

  test('a used place cannot be deleted, only archived', () async {
    final loc = await repo.createLocation(
      diverId: 'me',
      name: 'Shop',
      kind: EquipmentLocationKind.serviceShop,
    );
    await EquipmentLocationMoveRepository().recordMoves(
      equipmentIds: ['reg'],
      locationId: loc.id,
      movedAt: DateTime(2026, 9, 1),
    );
    expect(await repo.isInUse(loc.id), isTrue);
    expect(() => repo.deleteLocation(loc.id), throwsStateError);
    await repo.setArchived(loc.id, archived: true);
    expect((await repo.getLocation(loc.id))!.isArchived, isTrue);
  });

  test('an unused place deletes and tombstones', () async {
    final loc = await repo.createLocation(
      diverId: 'me',
      name: 'Car',
      kind: EquipmentLocationKind.other,
    );
    await repo.deleteLocation(loc.id);
    expect(await repo.getLocation(loc.id), isNull);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where((r) => r.entityType == 'equipmentLocations' && r.recordId == loc.id),
      isNotEmpty,
    );
  });

  test('findOrCreateByName matches case-insensitively, prefers active', () async {
    final archived = await repo.createLocation(
      diverId: 'me',
      name: 'Locker',
      kind: EquipmentLocationKind.storage,
    );
    await repo.setArchived(archived.id, archived: true);
    expect((await repo.findOrCreateByName(diverId: 'me', name: 'locker')).id, archived.id);
    final active = await repo.createLocation(
      diverId: 'me',
      name: 'LOCKER',
      kind: EquipmentLocationKind.storage,
    );
    expect((await repo.findOrCreateByName(diverId: 'me', name: 'Locker')).id, active.id);
    final created = await repo.findOrCreateByName(diverId: 'me', name: 'Boat');
    expect(created.kind, EquipmentLocationKind.other);
  });
}
```

Before writing, check the Drift getter for the pending-sync table (`grep -n "class .*Records\b\|syncRecords\|pendingRecords" lib/core/database/tables/*sync*`); the test reads it by that name.

`test/features/equipment/data/repositories/equipment_location_move_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentLocationMoveRepository moves;

  Future<void> item(String id, {String? parent, String status = 'active'}) =>
      db.into(db.equipment).insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: 1,
          updatedAt: 1,
          diverId: const Value('me'),
          parentEquipmentId: Value(parent),
          status: Value(status),
        ),
      );

  Future<void> place(String id) => db.into(db.equipmentLocations).insert(
    EquipmentLocationsCompanion.insert(
      id: id,
      name: id,
      createdAt: 1,
      updatedAt: 1,
      diverId: const Value('me'),
    ),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    moves = EquipmentLocationMoveRepository();
    await db.into(db.divers).insert(
      DiversCompanion.insert(id: 'me', name: 'me', createdAt: 1, updatedAt: 1),
    );
    await item('reg');
    await place('garage');
    await place('shop');
  });

  tearDown(tearDownTestDatabase);

  test('the newest move is the current location; backdating does not win', () async {
    await moves.recordMoves(equipmentIds: ['reg'], locationId: 'shop', movedAt: DateTime(2026, 9, 3));
    await moves.recordMoves(equipmentIds: ['reg'], locationId: 'garage', movedAt: DateTime(2026, 8, 1));
    expect(await moves.getCurrentLocationIds(), {'reg': 'shop'});
    expect([for (final m in await moves.getMovesFor('reg')) m.locationId], ['shop', 'garage']);
  });

  test('ties on moved_at break by created_at', () async {
    final at = DateTime(2026, 9, 3);
    await moves.recordMoves(equipmentIds: ['reg'], locationId: 'shop', movedAt: at);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await moves.recordMoves(equipmentIds: ['reg'], locationId: 'garage', movedAt: at);
    expect(await moves.getCurrentLocationIds(), {'reg': 'garage'});
  });

  test('a cleared move reads as no location; deleting it restores the prior', () async {
    await moves.recordMoves(equipmentIds: ['reg'], locationId: 'shop', movedAt: DateTime(2026, 9, 1));
    final cleared = await moves.recordMoves(equipmentIds: ['reg'], locationId: null, movedAt: DateTime(2026, 9, 2));
    expect(await moves.getCurrentLocationIds(), {'reg': null});
    await moves.deleteMove(cleared.single.id);
    expect(await moves.getCurrentLocationIds(), {'reg': 'shop'});
  });

  test('a move whose place was deleted reads as no location', () async {
    await moves.recordMoves(equipmentIds: ['reg'], locationId: 'shop', movedAt: DateTime(2026, 9, 1));
    await db.customStatement('PRAGMA foreign_keys = ON');
    await (db.delete(db.equipmentLocations)..where((t) => t.id.equals('shop'))).go();
    expect(await moves.getCurrentLocationIds(), {'reg': null});
  });

  test('updateMove recomputes and restamps; deleteForEquipment tombstones', () async {
    final m = (await moves.recordMoves(
      equipmentIds: ['reg'],
      locationId: 'shop',
      movedAt: DateTime(2026, 9, 1),
    )).single;
    await moves.updateMove(m.copyWith(locationId: 'garage', note: 'fixed'));
    expect(await moves.getCurrentLocationIds(), {'reg': 'garage'});
    expect((await moves.getMovesFor('reg')).single.note, 'fixed');
    await db.transaction(() => moves.deleteForEquipment('reg'));
    expect(await moves.getMovesFor('reg'), isEmpty);
    final tomb = await db.select(db.deletionLog).get();
    expect(tomb.where((r) => r.entityType == 'equipmentLocationMoves'), isNotEmpty);
  });

  test('partsOf excludes the given ids and retired parts', () async {
    await item('first', parent: null);
    await item('second', parent: null);
    await item('cell', parent: 'second');
    await item('oldCell', parent: 'second', status: 'retired');
    for (final c in ['first', 'second']) {
      await db.into(db.equipmentComponents).insert(
        EquipmentComponentsCompanion.insert(
          id: 'c-$c',
          parentEquipmentId: 'reg',
          componentEquipmentId: c,
          createdAt: 1,
          updatedAt: 1,
        ),
      );
    }
    expect(
      (await moves.partsOf(['reg'])).keys.toSet(),
      {'first', 'second', 'cell'},
    );
    expect(
      (await moves.partsOf(['reg', 'first'])).keys.toSet(),
      {'second', 'cell'},
    );
  });

  test('setStatusForMany writes status and keeps the items active', () async {
    await item('bcd');
    await EquipmentRepository().setStatusForMany(['reg', 'bcd'], EquipmentStatus.inService);
    final rows = await db.select(db.equipment).get();
    expect({for (final r in rows) r.id: r.status}, {'reg': 'inService', 'bcd': 'inService'});
    expect(rows.every((r) => r.isActive), isTrue);
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/equipment/data/repositories/equipment_location_repository_test.dart test/features/equipment/data/repositories/equipment_location_move_repository_test.dart`
Expected: compile errors.

- [ ] **Step 3: Implement the shared SQL**

`lib/features/equipment/data/equipment_location_sql.dart`:

```dart
/// The one ordering of an item's location log, newest first. Mirrors
/// `compareMovesNewestFirst`; every query that picks a current location
/// uses it, so the list, the filter and the detail card never disagree.
const String moveNewestFirstOrderSql =
    'moved_at DESC, created_at DESC, id DESC';

/// The current location id of the item whose id is [equipmentIdExpr] (a
/// column or placeholder expression), or NULL for no moves, a cleared
/// location, or a place since deleted.
String currentLocationIdSql(String equipmentIdExpr) =>
    '(SELECT m.location_id FROM equipment_location_moves m '
    'WHERE m.equipment_id = $equipmentIdExpr '
    'ORDER BY m.moved_at DESC, m.created_at DESC, m.id DESC LIMIT 1)';
```

- [ ] **Step 4: Implement `EquipmentLocationRepository`**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

/// CRUD for a diver's named places (v267). A place any move references can
/// only be archived, so history never loses a name.
class EquipmentLocationRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  static const String entity = 'equipmentLocations';

  Stream<void> watchChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.equipmentLocations));

  /// The diver's places plus any without a diver, by name; every place when
  /// [diverId] is null. Archived places included: callers filter.
  Future<List<EquipmentLocation>> getLocations({String? diverId}) async {
    final query = _db.select(_db.equipmentLocations);
    if (diverId != null) {
      query.where((t) => t.diverId.isNull() | t.diverId.equals(diverId));
    }
    final rows = await query.get();
    return sortedByText(rows, (r) => r.name).map(_toDomain).toList();
  }

  Future<EquipmentLocation?> getLocation(String id) async {
    final row = await (_db.select(
      _db.equipmentLocations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<EquipmentLocation> createLocation({
    required String? diverId,
    required String name,
    required EquipmentLocationKind kind,
    String notes = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'A place needs a name');
    }
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.equipmentLocations)
        .insert(
          EquipmentLocationsCompanion.insert(
            id: id,
            diverId: Value(diverId),
            name: trimmed,
            kind: Value(kind.name),
            notes: Value(notes.trim()),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    return (await getLocation(id))!;
  }

  Future<void> updateLocation(EquipmentLocation location) async {
    final trimmed = location.name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(location.name, 'name', 'A place needs a name');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.equipmentLocations,
    )..where((t) => t.id.equals(location.id))).write(
      EquipmentLocationsCompanion(
        name: Value(trimmed),
        kind: Value(location.kind.name),
        notes: Value(location.notes.trim()),
        isArchived: Value(location.isArchived),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: location.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> setArchived(String id, {required bool archived}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipmentLocations)..where((t) => t.id.equals(id)))
        .write(
          EquipmentLocationsCompanion(
            isArchived: Value(archived),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Whether any move, current or historical, names the place.
  Future<bool> isInUse(String id) async {
    final row = await (_db.selectOnly(_db.equipmentLocationMoves)
          ..addColumns([_db.equipmentLocationMoves.id])
          ..where(_db.equipmentLocationMoves.locationId.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Deletes a never-used place. A used one throws [StateError]: archive it.
  Future<void> deleteLocation(String id) async {
    await _db.transaction(() async {
      if (await isInUse(id)) {
        throw StateError('A place in use can only be archived');
      }
      await (_db.delete(
        _db.equipmentLocations,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entity, recordId: id);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// The diver's place named [name] ignoring case, an active one before an
  /// archived one; failing both, a new place of kind other. For imports.
  Future<EquipmentLocation> findOrCreateByName({
    required String? diverId,
    required String name,
  }) async {
    final wanted = name.trim().toLowerCase();
    final matches = [
      for (final l in await getLocations(diverId: diverId))
        if (l.name.toLowerCase() == wanted) l,
    ];
    final active = matches.where((l) => !l.isArchived);
    if (active.isNotEmpty) return active.first;
    if (matches.isNotEmpty) return matches.first;
    return createLocation(
      diverId: diverId,
      name: name,
      kind: EquipmentLocationKind.other,
    );
  }

  EquipmentLocation _toDomain(EquipmentLocationRow r) => EquipmentLocation(
    id: r.id,
    diverId: r.diverId,
    name: r.name,
    kind: EquipmentLocationKind.fromName(r.kind),
    notes: r.notes,
    isArchived: r.isArchived,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
  );
}
```

Note: `getLocations(diverId: null)` returns every place; `findOrCreateByName` with a null diver therefore matches across profiles, which is acceptable only for a diverless import. The importer always passes the active diver.

- [ ] **Step 5: Implement `EquipmentLocationMoveRepository`**

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/data/equipment_location_sql.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';

/// Each item's location log (v267). Writes never touch the `equipment` row
/// (#1769: a child change does not re-stamp its parent); each move carries
/// its own clock.
class EquipmentLocationMoveRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  static const _uuid = Uuid();

  static const String entity = 'equipmentLocationMoves';

  /// Moves and places: a renamed or deleted place changes what a current
  /// location reads as, so readers of either refresh on both.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.equipmentLocationMoves,
      _db.equipmentLocations,
    ]),
  );

  /// [equipmentId]'s moves, newest first.
  Future<List<EquipmentLocationMove>> getMovesFor(String equipmentId) async {
    final rows =
        await (_db.select(_db.equipmentLocationMoves)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.movedAt),
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.desc(t.id),
              ]))
            .get();
    return rows.map(_toDomain).toList();
  }

  /// Every item with at least one move, to its current location id (null
  /// when cleared or the place is gone). An item with no moves is absent.
  Future<Map<String, String?>> getCurrentLocationIds() async {
    final rows = await _db
        .customSelect(
          'SELECT e.id AS equipment_id, ${currentLocationIdSql('e.id')} '
          'AS location_id FROM equipment e WHERE EXISTS '
          '(SELECT 1 FROM equipment_location_moves x '
          'WHERE x.equipment_id = e.id)',
          readsFrom: {_db.equipment, _db.equipmentLocationMoves},
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('equipment_id'): r.read<String?>('location_id'),
    };
  }

  /// One move per item in [equipmentIds], all to [locationId] (null clears)
  /// at [movedAt]. Returns the moves written.
  Future<List<EquipmentLocationMove>> recordMoves({
    required Iterable<String> equipmentIds,
    required String? locationId,
    required DateTime movedAt,
    String note = '',
  }) async {
    final ids = equipmentIds.toSet().toList();
    if (ids.isEmpty) return const [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = [
      for (final equipmentId in ids)
        EquipmentLocationMovesCompanion.insert(
          id: _uuid.v4(),
          equipmentId: equipmentId,
          locationId: Value(locationId),
          movedAt: movedAt.millisecondsSinceEpoch,
          note: Value(note.trim()),
          createdAt: now,
        ),
    ];
    await _db.transaction(() async {
      await _db.batch((b) => b.insertAll(_db.equipmentLocationMoves, rows));
      for (final r in rows) {
        await _syncRepository.markRecordPending(
          entityType: entity,
          recordId: r.id.value,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
    return [
      for (final r in rows)
        EquipmentLocationMove(
          id: r.id.value,
          equipmentId: r.equipmentId.value,
          locationId: locationId,
          movedAt: movedAt,
          note: note.trim(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(now),
        ),
    ];
  }

  /// Rewrites one move's place, date and note, restamping its clock.
  Future<void> updateMove(EquipmentLocationMove move) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.equipmentLocationMoves,
    )..where((t) => t.id.equals(move.id))).write(
      EquipmentLocationMovesCompanion(
        locationId: Value(move.locationId),
        movedAt: Value(move.movedAt.millisecondsSinceEpoch),
        note: Value(move.note.trim()),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: entity,
      recordId: move.id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  Future<void> deleteMove(String id) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.equipmentLocationMoves,
      )..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entity, recordId: id);
    });
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes and tombstones [equipmentId]'s moves, for an item delete.
  /// Cascades write no tombstones. Runs inside the caller's transaction.
  Future<void> deleteForEquipment(String equipmentId) async {
    final ids =
        await (_db.selectOnly(_db.equipmentLocationMoves)
              ..addColumns([_db.equipmentLocationMoves.id])
              ..where(
                _db.equipmentLocationMoves.equipmentId.equals(equipmentId),
              ))
            .map((r) => r.read(_db.equipmentLocationMoves.id)!)
            .get();
    if (ids.isEmpty) return;
    await (_db.delete(
      _db.equipmentLocationMoves,
    )..where((t) => t.equipmentId.equals(equipmentId))).go();
    await _syncRepository.logDeletions(entityType: entity, recordIds: ids);
  }

  /// Every part of [equipmentIds], transitively: assembly components and
  /// installed children, to each part's status. Retired and sold parts are
  /// left out (they are not with the item), and so is anything in
  /// [equipmentIds] itself.
  Future<Map<String, EquipmentStatus>> partsOf(
    Iterable<String> equipmentIds,
  ) async {
    final selected = equipmentIds.toSet();
    final seen = <String>{...selected};
    final parts = <String, EquipmentStatus>{};
    var frontier = selected.toList();
    while (frontier.isNotEmpty) {
      final ph = List.filled(frontier.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT e.id AS id, e.status AS status FROM equipment e WHERE '
            'e.id IN (SELECT component_equipment_id FROM '
            'equipment_components WHERE parent_equipment_id IN ($ph)) '
            'OR e.parent_equipment_id IN ($ph)',
            variables: [
              for (final id in [...frontier, ...frontier])
                Variable<String>(id),
            ],
          )
          .get();
      final next = <String>[];
      for (final r in rows) {
        final id = r.read<String>('id');
        if (!seen.add(id)) continue;
        next.add(id);
        final status = EquipmentStatus.values.firstWhere(
          (s) => s.name == r.read<String>('status'),
          orElse: () => EquipmentStatus.active,
        );
        if (status == EquipmentStatus.retired ||
            status == EquipmentStatus.sold) {
          continue;
        }
        parts[id] = status;
      }
      frontier = next;
    }
    return parts;
  }

  EquipmentLocationMove _toDomain(EquipmentLocationMoveRow r) =>
      EquipmentLocationMove(
        id: r.id,
        equipmentId: r.equipmentId,
        locationId: r.locationId,
        movedAt: DateTime.fromMillisecondsSinceEpoch(r.movedAt),
        note: r.note,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
      );
}
```

Note: the `partsOf` frontier keeps walking through a retired part (`next.add` happens before the status check) so a live grandchild under a retired child is still found; only the retired part itself is left out. If a frontier can exceed SQLite's variable limit (it cannot at gear scale), chunk with `seriesIdChunks` as the share repository does.

- [ ] **Step 6: Wire item delete and bulk status**

In `equipment_repository_impl.dart` `deleteEquipment`, after `TripEquipmentRepository().deleteForEquipment(id)` (~621):
```dart
      await EquipmentLocationMoveRepository().deleteForEquipment(id);
```
After `retireEquipment`, add:
```dart
  /// Sets [status] on every item in [ids], for the status offer after a
  /// move. Only ever In Service, Loaned Out or Active, so the items stay
  /// active (#636 pairs is_active with retired and sold only).
  Future<void> setStatusForMany(
    Iterable<String> ids,
    EquipmentStatus status,
  ) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return;
    assert(
      status != EquipmentStatus.retired && status != EquipmentStatus.sold,
      'Retire through retireEquipment, which also clears is_active',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(_db.equipment)..where((t) => t.id.isIn(list))).write(
        EquipmentCompanion(
          status: Value(status.name),
          isActive: const Value(true),
          updatedAt: Value(now),
        ),
      );
      for (final id in list) {
        await _syncRepository.markRecordPending(
          entityType: 'equipment',
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
    SyncEventBus.notifyLocalChange();
  }
```
In `EquipmentListNotifier`, after `reactivateEquipment`:
```dart
  Future<void> setStatusForMany(List<String> ids, EquipmentStatus status) async {
    await _repository.setStatusForMany(ids, status);
    await refresh();
  }
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/equipment/data/repositories/equipment_location_repository_test.dart test/features/equipment/data/repositories/equipment_location_move_repository_test.dart test/features/equipment/data/repositories/equipment_delete_shares_test.dart`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/equipment test/features/equipment
git add lib/features/equipment/data test/features/equipment/data lib/features/equipment/presentation/providers/equipment_providers.dart
git commit -m "feat(equipment): repositories for places and moves"
```

---

### Task 5: Diver deletion keeps places other gear still uses

**Files:**
- Create: `lib/features/divers/data/repositories/diver_location_retirement.dart`
- Modify: `lib/features/divers/data/repositories/diver_delete_steps.dart` (`diverGearSteps`, before the `equipment` step ~197)
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (after `retireDiverServiceKinds` ~794)
- Modify: `test/features/divers/data/repositories/diver_delete_owned_tables_test.dart` (`_clearedByDelete` ~796)
- Test: `test/features/divers/data/repositories/diver_location_retirement_test.dart`

**Interfaces:**
- Consumes: Task 2 tables, Task 4 repositories (in the test).
- Produces: `Future<void> retireDiverEquipmentLocations(AppDatabase db, SyncRepository syncRepository, String diverId, {required int now})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_location_retirement.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['gone', 'heir']) {
      await db.into(db.divers).insert(
        DiversCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
      );
    }
    // Gear the deleted diver lent out and transferred earlier: now heir's.
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: 'reg',
        name: 'Reg',
        type: 'regulator',
        createdAt: 1,
        updatedAt: 1,
        diverId: const Value('heir'),
      ),
    );
    for (final id in ['used', 'unused']) {
      await db.into(db.equipmentLocations).insert(
        EquipmentLocationsCompanion.insert(
          id: id,
          name: id,
          createdAt: 1,
          updatedAt: 1,
          diverId: const Value('gone'),
        ),
      );
    }
    await db.into(db.equipmentLocationMoves).insert(
      EquipmentLocationMovesCompanion.insert(
        id: 'm',
        equipmentId: 'reg',
        locationId: const Value('used'),
        movedAt: 1,
        createdAt: 1,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('a place surviving gear uses moves to that gear\'s owner', () async {
    await db.transaction(
      () => retireDiverEquipmentLocations(db, SyncRepository(), 'gone', now: 9),
    );
    final rows = await db.select(db.equipmentLocations).get();
    expect({for (final r in rows) r.id: r.diverId}, {'used': 'heir'});
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where((t) => t.entityType == 'equipmentLocations').map((t) => t.recordId),
      ['unused'],
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/divers/data/repositories/diver_location_retirement_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement**

`lib/features/divers/data/repositories/diver_location_retirement.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_delete_steps.dart';

/// Deletes [diverId]'s equipment locations, except a place a move on
/// surviving gear still names: that one moves to the owner of the gear
/// behind its earliest such move, stamped and marked for sync, so the
/// history keeps its name on every device. Run inside the caller's
/// transaction, after the diver's own gear and its moves are deleted.
///
/// `equipment_location_moves.location_id` is SET NULL, so deleting a used
/// place would silently turn "it was at the shop" into "no location", and
/// the local SET NULL would never reach a peer.
Future<void> retireDiverEquipmentLocations(
  AppDatabase db,
  SyncRepository syncRepository,
  String diverId, {
  required int now,
}) async {
  final kept = await db
      .customSelect(
        'SELECT l.id AS id, (SELECT e.diver_id FROM equipment_location_moves m '
        'JOIN equipment e ON e.id = m.equipment_id WHERE m.location_id = l.id '
        'ORDER BY m.moved_at ASC, m.created_at ASC, m.id ASC LIMIT 1) AS heir '
        'FROM equipment_locations l WHERE l.diver_id = ? AND EXISTS '
        '(SELECT 1 FROM equipment_location_moves m WHERE m.location_id = l.id)',
        variables: [Variable.withString(diverId)],
      )
      .get();
  for (final r in kept) {
    final id = r.read<String>('id');
    await db.customStatement(
      'UPDATE equipment_locations SET diver_id = ?, updated_at = ? '
      'WHERE id = ?',
      [r.read<String?>('heir'), now, id],
    );
    await syncRepository.markRecordPending(
      entityType: 'equipmentLocations',
      recordId: id,
      localUpdatedAt: now,
    );
  }
  final deletedIds = await diverRowIds(
    db,
    'SELECT id FROM equipment_locations WHERE diver_id = ?',
    [diverId],
  );
  if (deletedIds.isEmpty) return;
  await db.customStatement(
    'DELETE FROM equipment_locations WHERE diver_id = ?',
    [diverId],
  );
  await syncRepository.logDeletions(
    entityType: 'equipmentLocations',
    recordIds: deletedIds,
  );
}
```

In `diver_delete_steps.dart` `diverGearSteps`, insert before the `equipment` step:
```dart
  // The location log of the diver's gear (v267). Moves on other profiles'
  // gear stay; their places are kept by retireDiverEquipmentLocations.
  (
    table: 'equipment_location_moves',
    entityType: 'equipmentLocationMoves',
    where: 'equipment_id IN ($_diverGear)',
  ),
```
In `diver_repository.dart`, after the `retireDiverServiceKinds(...)` call:
```dart
        // After the gear, so only surviving gear's moves keep a place.
        await retireDiverEquipmentLocations(
          _db,
          _syncRepository,
          id,
          now: DateTime.now().millisecondsSinceEpoch,
        );
```
In `diver_delete_owned_tables_test.dart`, add `'equipment_locations',` to `_clearedByDelete`.

- [ ] **Step 4: Run the diver suites**

Run: `flutter test test/features/divers > "$SCRATCH/divers.log" 2>&1; tail -20 "$SCRATCH/divers.log"`
Expected: all PASS, including `diver_merge_repository_test.dart` (places repoint through the schema-driven `diver_id` scan with no change).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/divers test/features/divers
git add lib/features/divers test/features/divers
git commit -m "feat(divers): keep equipment locations other gear still uses on diver delete"
```

---

### Task 6: Providers and the group-by-location setting

**Files:**
- Create: `lib/features/equipment/presentation/providers/equipment_location_providers.dart`
- Modify: `lib/features/settings/data/repositories/app_settings_repository.dart` (key constant near line 25; methods after `setNavAlwaysHideLabels` ~79)
- Test: `test/features/equipment/presentation/providers/equipment_location_providers_test.dart`

**Interfaces:**
- Consumes: Task 4 repositories; `validatedCurrentDiverIdProvider`, `appSettingsRepositoryProvider`.
- Produces:
  - `equipmentLocationRepositoryProvider`, `equipmentLocationMoveRepositoryProvider` (`Provider`).
  - `equipmentLocationsProvider`: `FutureProvider<List<EquipmentLocation>>`, the active diver's places, archived included.
  - `allEquipmentLocationsByIdProvider`: `FutureProvider<Map<String, EquipmentLocation>>`, every place.
  - `currentEquipmentLocationsProvider`: `FutureProvider<Map<String, EquipmentLocation>>`, item id to its current place; items with none are absent.
  - `equipmentLocationMovesProvider`: `FutureProvider.family<List<EquipmentLocationMove>, String>`.
  - `equipmentGroupByLocationProvider`: `FutureProvider<bool>`.
  - `AppSettingsRepository.getEquipmentGroupByLocation()` / `setEquipmentGroupByLocation(bool)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.into(db.divers).insert(
      DiversCompanion.insert(id: 'me', name: 'me', createdAt: 1, updatedAt: 1),
    );
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: 'reg',
        name: 'Reg',
        type: 'regulator',
        createdAt: 1,
        updatedAt: 1,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('currentEquipmentLocationsProvider joins moves to places', () async {
    final loc = await EquipmentLocationRepository().createLocation(
      diverId: 'me',
      name: 'Garage',
      kind: EquipmentLocationKind.storage,
    );
    await EquipmentLocationMoveRepository().recordMoves(
      equipmentIds: ['reg'],
      locationId: loc.id,
      movedAt: DateTime(2026),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final current = await container.read(currentEquipmentLocationsProvider.future);
    expect(current['reg']?.name, 'Garage');
  });

  test('group by location defaults off and round-trips', () async {
    final repo = AppSettingsRepository();
    expect(await repo.getEquipmentGroupByLocation(), isFalse);
    await repo.setEquipmentGroupByLocation(true);
    expect(await repo.getEquipmentGroupByLocation(), isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/equipment_location_providers_test.dart`
Expected: compile error.

- [ ] **Step 3: Implement the settings methods**

In `app_settings_repository.dart`, add `static const _equipmentGroupByLocationKey = 'equipment_group_by_location';` beside `_equipmentArrangementKey`, and after `setNavAlwaysHideLabels`:
```dart
  /// Whether the Equipment page groups its list under one heading per
  /// location. The Equipment page's own switch: the shared gear
  /// arrangement, which the dive surfaces also read, is untouched. False
  /// when unset or on a read error.
  Future<bool> getEquipmentGroupByLocation() async =>
      await getRawSetting(_equipmentGroupByLocationKey) == 'true';

  /// Rethrows so a failed save is visible.
  Future<void> setEquipmentGroupByLocation(bool value) =>
      setRawSetting(_equipmentGroupByLocationKey, value ? 'true' : 'false');
```

- [ ] **Step 4: Implement the providers**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final equipmentLocationRepositoryProvider =
    Provider<EquipmentLocationRepository>((ref) => EquipmentLocationRepository());

final equipmentLocationMoveRepositoryProvider =
    Provider<EquipmentLocationMoveRepository>(
      (ref) => EquipmentLocationMoveRepository(),
    );

/// The active diver's places, archived included (callers filter).
final equipmentLocationsProvider = FutureProvider<List<EquipmentLocation>>((
  ref,
) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repository = ref.watch(equipmentLocationRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getLocations(diverId: diverId);
});

/// Every place by id, whoever owns it: a shared or transferred item can sit
/// at another profile's place, and its name must still resolve.
final allEquipmentLocationsByIdProvider =
    FutureProvider<Map<String, EquipmentLocation>>((ref) async {
      final repository = ref.watch(equipmentLocationRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return {for (final l in await repository.getLocations()) l.id: l};
    });

/// Item id to its current place. Items with no moves, a cleared location or
/// a deleted place are absent.
final currentEquipmentLocationsProvider =
    FutureProvider<Map<String, EquipmentLocation>>((ref) async {
      final moves = ref.watch(equipmentLocationMoveRepositoryProvider);
      ref.invalidateSelfWhen(moves.watchChanges());
      final places = await ref.watch(allEquipmentLocationsByIdProvider.future);
      final current = await moves.getCurrentLocationIds();
      return {
        for (final entry in current.entries)
          if (places[entry.value] case final place?) entry.key: place,
      };
    });

/// One item's moves, newest first.
final equipmentLocationMovesProvider =
    FutureProvider.family<List<EquipmentLocationMove>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentLocationMoveRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getMovesFor(equipmentId);
    });

/// The Equipment page's group-by-location switch.
final equipmentGroupByLocationProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(appSettingsRepositoryProvider);
  ref.invalidateSelfWhen(repo.watchSettingsChanges());
  return repo.getEquipmentGroupByLocation();
});
```

Check the import path of `appSettingsRepositoryProvider` (`grep -rn "final appSettingsRepositoryProvider" lib`) and of `invalidateSelfWhen` (it comes with `core/providers/provider.dart` in the files read above).

- [ ] **Step 5: Run the test and the architecture guards**

Run: `flutter test test/features/equipment/presentation/providers/equipment_location_providers_test.dart test/architecture > "$SCRATCH/arch.log" 2>&1; tail -30 "$SCRATCH/arch.log"`
Expected: PASS. If `repository_tick_stream_test.dart` or `provider_tick_build_smoke_test.dart` asks for the new repositories or providers to be listed, add them in the shape the failure message names (the service-kind and share-event entries are the models).

- [ ] **Step 6: Commit**

```bash
dart format lib test
git add lib/features/equipment/presentation/providers/equipment_location_providers.dart lib/features/settings/data/repositories/app_settings_repository.dart test/features/equipment/presentation/providers test/architecture
git commit -m "feat(equipment): location providers and group-by-location setting"
```

---

### Task 7: Place editing and the place picker

**Files:**
- Create: `lib/features/equipment/presentation/utils/equipment_location_display.dart`
- Create: `lib/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart`
- Create: `lib/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/equipment/presentation/widgets/equipment_location_picker_sheet_test.dart`

**Interfaces:**
- Consumes: Task 6 providers.
- Produces:
  - `extension EquipmentLocationKindDisplay on EquipmentLocationKind { String localizedName(AppLocalizations l10n); IconData get icon; }`
  - `Future<EquipmentLocation?> showEquipmentLocationEditDialog(BuildContext context, WidgetRef ref, {EquipmentLocation? existing, String initialName = ''})`
  - `sealed class LocationPick` with `PlacePick(EquipmentLocation location)` and `NoLocationPick()`.
  - `Future<LocationPick?> showEquipmentLocationPickerSheet(BuildContext context, WidgetRef ref)` (null when dismissed).

- [ ] **Step 1: Add the English strings**

In `app_en.arb`, in the equipment group (anchor on a neighbouring `equipment_` key; every ARB is feature-grouped), add:

```json
  "equipment_location_kind_storage": "Storage",
  "@equipment_location_kind_storage": {"description": "Kind of place where gear is kept: a shelf, bin, locker or room"},
  "equipment_location_kind_serviceShop": "Service shop",
  "@equipment_location_kind_serviceShop": {"description": "Kind of place: a shop or technician servicing gear"},
  "equipment_location_kind_person": "Person",
  "@equipment_location_kind_person": {"description": "Kind of place: a person the gear is lent to"},
  "equipment_location_kind_other": "Other",
  "@equipment_location_kind_other": {"description": "Kind of place that is none of the others"},
  "equipment_location_noLocation": "No location",
  "@equipment_location_noLocation": {"description": "Choice and heading for gear with no recorded location"},
  "equipment_location_picker_title": "Choose a place",
  "@equipment_location_picker_title": {"description": "Title of the sheet that picks where gear is"},
  "equipment_location_picker_search": "Search places",
  "@equipment_location_picker_search": {"description": "Hint of the search field in the place picker"},
  "equipment_location_picker_newPlace": "New place",
  "@equipment_location_picker_newPlace": {"description": "Row in the place picker that creates a new place"},
  "equipment_locations_newTitle": "New place",
  "@equipment_locations_newTitle": {"description": "Title of the dialog creating a place where gear is kept"},
  "equipment_locations_editTitle": "Edit place",
  "@equipment_locations_editTitle": {"description": "Title of the dialog editing a place where gear is kept"},
  "equipment_locations_nameLabel": "Name",
  "@equipment_locations_nameLabel": {"description": "Label of a place's name field"},
  "equipment_locations_nameRequired": "Enter a name",
  "@equipment_locations_nameRequired": {"description": "Validation error when a place has no name"},
  "equipment_locations_duplicateWarning": "You already have a place with this name",
  "@equipment_locations_duplicateWarning": {"description": "Warning under a place name that matches another of the diver's places; saving is still allowed"},
  "equipment_locations_kindLabel": "Kind",
  "@equipment_locations_kindLabel": {"description": "Label of a place's kind selector"},
  "equipment_locations_notesLabel": "Notes",
  "@equipment_locations_notesLabel": {"description": "Label of a place's notes field"},
  "equipment_locations_notesHint": "Address, phone, locker number",
  "@equipment_locations_notesHint": {"description": "Hint of a place's notes field"},
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';

import '../../../../helpers/test_app.dart';

EquipmentLocation place(String id, String name, EquipmentLocationKind kind, {bool archived = false}) =>
    EquipmentLocation(
      id: id,
      name: name,
      kind: kind,
      isArchived: archived,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  testWidgets('lists active places by kind, filters by search, hides archived', (tester) async {
    LocationPick? picked;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          equipmentLocationsProvider.overrideWith(
            (ref) async => [
              place('g', 'Garage bin 2', EquipmentLocationKind.storage),
              place('j', "Joe's Scuba", EquipmentLocationKind.serviceShop),
              place('x', 'Old locker', EquipmentLocationKind.storage, archived: true),
            ],
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async =>
                picked = await showEquipmentLocationPickerSheet(context, ref),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Garage bin 2'), findsOneWidget);
    expect(find.text("Joe's Scuba"), findsOneWidget);
    expect(find.text('Old locker'), findsNothing);
    expect(find.text('No location'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'joe');
    await tester.pumpAndSettle();
    expect(find.text('Garage bin 2'), findsNothing);

    await tester.tap(find.text("Joe's Scuba"));
    await tester.pumpAndSettle();
    expect((picked as PlacePick).location.id, 'j');
  });

  testWidgets('No location returns NoLocationPick', (tester) async {
    LocationPick? picked;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [equipmentLocationsProvider.overrideWith((ref) async => [])],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async =>
                picked = await showEquipmentLocationPickerSheet(context, ref),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No location'));
    await tester.pumpAndSettle();
    expect(picked, isA<NoLocationPick>());
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_location_picker_sheet_test.dart`
Expected: compile error.

- [ ] **Step 4: Implement the display helpers**

`lib/features/equipment/presentation/utils/equipment_location_display.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

extension EquipmentLocationKindDisplay on EquipmentLocationKind {
  String localizedName(AppLocalizations l10n) => switch (this) {
    EquipmentLocationKind.storage => l10n.equipment_location_kind_storage,
    EquipmentLocationKind.serviceShop => l10n.equipment_location_kind_serviceShop,
    EquipmentLocationKind.person => l10n.equipment_location_kind_person,
    EquipmentLocationKind.other => l10n.equipment_location_kind_other,
  };

  IconData get icon => switch (this) {
    EquipmentLocationKind.storage => Icons.inventory_2_outlined,
    EquipmentLocationKind.serviceShop => Icons.build_outlined,
    EquipmentLocationKind.person => Icons.person_outline,
    EquipmentLocationKind.other => Icons.place_outlined,
  };
}
```

- [ ] **Step 5: Implement the edit dialog**

`lib/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Creates a place (no [existing]) or edits one. Returns the saved place, or
/// null when cancelled. [initialName] prefills a new place's name, as the
/// picker does from its search text.
Future<EquipmentLocation?> showEquipmentLocationEditDialog(
  BuildContext context,
  WidgetRef ref, {
  EquipmentLocation? existing,
  String initialName = '',
}) {
  return showDialog<EquipmentLocation>(
    context: context,
    builder: (_) => _EquipmentLocationEditDialog(
      existing: existing,
      initialName: initialName,
    ),
  );
}

class _EquipmentLocationEditDialog extends ConsumerStatefulWidget {
  const _EquipmentLocationEditDialog({this.existing, required this.initialName});

  final EquipmentLocation? existing;
  final String initialName;

  @override
  ConsumerState<_EquipmentLocationEditDialog> createState() =>
      _EquipmentLocationEditDialogState();
}

class _EquipmentLocationEditDialogState
    extends ConsumerState<_EquipmentLocationEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late EquipmentLocationKind _kind;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.existing?.name ?? widget.initialName.trim(),
    );
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
    _kind = widget.existing?.kind ?? EquipmentLocationKind.storage;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _isDuplicate(List<EquipmentLocation> places) {
    final wanted = _name.text.trim().toLowerCase();
    if (wanted.isEmpty) return false;
    return places.any(
      (p) => p.id != widget.existing?.id && p.name.toLowerCase() == wanted,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(equipmentLocationRepositoryProvider);
    try {
      final existing = widget.existing;
      final EquipmentLocation saved;
      if (existing == null) {
        saved = await repo.createLocation(
          diverId: await ref.read(validatedCurrentDiverIdProvider.future),
          name: _name.text,
          kind: _kind,
          notes: _notes.text,
        );
      } else {
        saved = existing.copyWith(
          name: _name.text.trim(),
          kind: _kind,
          notes: _notes.text.trim(),
        );
        await repo.updateLocation(saved);
      }
      if (mounted) Navigator.of(context).pop(saved);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final places = ref.watch(equipmentLocationsProvider).value ?? const [];
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? l10n.equipment_locations_newTitle
            : l10n.equipment_locations_editTitle,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('equipment_location_name'),
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.equipment_locations_nameLabel,
                  helperText: _isDuplicate(places)
                      ? l10n.equipment_locations_duplicateWarning
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => (v ?? '').trim().isEmpty
                    ? l10n.equipment_locations_nameRequired
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EquipmentLocationKind>(
                key: const ValueKey('equipment_location_kind'),
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: l10n.equipment_locations_kindLabel,
                ),
                items: [
                  for (final kind in EquipmentLocationKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Row(
                        children: [
                          Icon(kind.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(kind.localizedName(l10n)),
                        ],
                      ),
                    ),
                ],
                onChanged: (k) => setState(() => _kind = k ?? _kind),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.equipment_locations_notesLabel,
                  hintText: l10n.equipment_locations_notesHint,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          key: const ValueKey('equipment_location_save'),
          onPressed: _saving ? null : _save,
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
```

If the Flutter version in use names it `value:` rather than `initialValue:` on `DropdownButtonFormField`, match the neighbouring code (`grep -rn "DropdownButtonFormField" lib/features/equipment | head -3`).

- [ ] **Step 6: Implement the picker sheet**

`lib/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the place picker returned.
sealed class LocationPick {
  const LocationPick();
}

class PlacePick extends LocationPick {
  const PlacePick(this.location);
  final EquipmentLocation location;
}

class NoLocationPick extends LocationPick {
  const NoLocationPick();
}

/// Picks one of the diver's active places, "No location", or a place made
/// on the spot. Null when dismissed.
Future<LocationPick?> showEquipmentLocationPickerSheet(
  BuildContext context,
  WidgetRef ref,
) {
  return showModalBottomSheet<LocationPick>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.8,
      child: _EquipmentLocationPicker(),
    ),
  );
}

class _EquipmentLocationPicker extends ConsumerStatefulWidget {
  const _EquipmentLocationPicker();

  @override
  ConsumerState<_EquipmentLocationPicker> createState() =>
      _EquipmentLocationPickerState();
}

class _EquipmentLocationPickerState
    extends ConsumerState<_EquipmentLocationPicker> {
  String _search = '';

  Future<void> _createPlace() async {
    final created = await showEquipmentLocationEditDialog(
      context,
      ref,
      initialName: _search,
    );
    if (created != null && mounted) {
      Navigator.of(context).pop(PlacePick(created));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _search.trim().toLowerCase();
    final places = [
      for (final p in ref.watch(equipmentLocationsProvider).value ?? const <EquipmentLocation>[])
        if (!p.isArchived && (query.isEmpty || p.name.toLowerCase().contains(query))) p,
    ];
    return SafeArea(
      child: Column(
        children: [
          ListTile(
            title: Text(
              l10n.equipment_location_picker_title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.common_action_close,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.equipment_location_picker_search,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  key: const ValueKey('equipment_location_picker_new'),
                  leading: const Icon(Icons.add),
                  title: Text(l10n.equipment_location_picker_newPlace),
                  subtitle: query.isEmpty ? null : Text(_search.trim()),
                  onTap: _createPlace,
                ),
                ListTile(
                  key: const ValueKey('equipment_location_picker_none'),
                  leading: const Icon(Icons.location_off_outlined),
                  title: Text(l10n.equipment_location_noLocation),
                  onTap: () => Navigator.of(context).pop(const NoLocationPick()),
                ),
                const Divider(height: 1),
                for (final kind in EquipmentLocationKind.values)
                  ..._section(context, kind, [
                    for (final p in places)
                      if (p.kind == kind) p,
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    EquipmentLocationKind kind,
    List<EquipmentLocation> places,
  ) {
    if (places.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          kind.localizedName(context.l10n),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
      for (final p in places)
        ListTile(
          key: ValueKey('equipment_location_picker_${p.id}'),
          leading: Icon(kind.icon),
          title: Text(p.name),
          subtitle: p.notes.isEmpty ? null : Text(p.notes, maxLines: 1),
          onTap: () => Navigator.of(context).pop(PlacePick(p)),
        ),
    ];
  }
}
```

- [ ] **Step 7: Run the test**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_location_picker_sheet_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib/features/equipment/presentation lib/l10n test/features/equipment/presentation
git commit -m "feat(equipment): place editor and place picker"
```

---

### Task 8: The move flow (sheet, parts prompt, status offer)

**Files:**
- Create: `lib/features/equipment/data/services/equipment_move_flow.dart`
- Create: `lib/features/equipment/presentation/widgets/move_equipment_sheet.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/equipment/data/services/equipment_move_flow_test.dart`
- Test: `test/features/equipment/presentation/widgets/move_equipment_sheet_test.dart`

**Interfaces:**
- Consumes: Task 1 `offeredStatusAfterMove`, Task 4 `recordMoves`, `partsOf`, `setStatusForMany`, Task 7 picker.
- Produces:
  - `class EquipmentMoveFlow` with `Future<int> run({required List<EquipmentItem> items, required EquipmentLocation? target, required DateTime movedAt, String note = ''})` returning the number of items moved.
  - `class MoveDraft { final LocationPick pick; final DateTime movedAt; final String note; }`
  - `Future<MoveDraft?> showMoveEquipmentSheet(BuildContext context, WidgetRef ref, {required int itemCount})`.
  - `Future<int?> showMoveEquipmentFlow(BuildContext context, WidgetRef ref, {required List<EquipmentItem> items})`: the whole flow; null when cancelled.

- [ ] **Step 1: Add the English strings**

```json
  "equipment_location_move_title": "{count, plural, one{Move {count} item} other{Move {count} items}}",
  "@equipment_location_move_title": {"description": "Title of the sheet that moves gear to a place", "placeholders": {"count": {"type": "int"}}},
  "equipment_location_move_to": "To",
  "@equipment_location_move_to": {"description": "Label of the destination place in the move sheet"},
  "equipment_location_move_choose": "Choose a place",
  "@equipment_location_move_choose": {"description": "Shown in the move sheet before a destination is chosen"},
  "equipment_location_move_date": "Date",
  "@equipment_location_move_date": {"description": "Label of the move date in the move sheet"},
  "equipment_location_move_note": "Note",
  "@equipment_location_move_note": {"description": "Label of the optional note on a move"},
  "equipment_location_move_noteHint": "e.g. annual regulator service",
  "@equipment_location_move_noteHint": {"description": "Hint of the note field on a move"},
  "equipment_location_move_confirm": "Move",
  "@equipment_location_move_confirm": {"description": "Button that records the move"},
  "equipment_location_parts_title": "Move parts too?",
  "@equipment_location_parts_title": {"description": "Title of the prompt offering to move an assembly's parts with it"},
  "equipment_location_parts_body": "{count, plural, one{Also move its {count} part to the same place?} other{Also move its {count} parts to the same place?}}",
  "@equipment_location_parts_body": {"description": "Body of the parts prompt", "placeholders": {"count": {"type": "int"}}},
  "equipment_location_parts_yes": "Move parts",
  "@equipment_location_parts_yes": {"description": "Accepts moving the parts too"},
  "equipment_location_parts_no": "Just this",
  "@equipment_location_parts_no": {"description": "Declines moving the parts"},
  "equipment_location_status_title": "Update status?",
  "@equipment_location_status_title": {"description": "Title of the prompt offering a status change after a move"},
  "equipment_location_status_body": "{count, plural, one{Also mark {count} item as {status}?} other{Also mark {count} items as {status}?}}",
  "@equipment_location_status_body": {"description": "Body of the status offer; status is a status name such as In Service", "placeholders": {"count": {"type": "int"}, "status": {"type": "String"}}},
  "equipment_location_status_yes": "Update",
  "@equipment_location_status_yes": {"description": "Accepts the status change"},
  "equipment_location_status_no": "Keep status",
  "@equipment_location_status_no": {"description": "Declines the status change"},
  "equipment_location_moved": "{count, plural, one{Moved {count} item} other{Moved {count} items}}",
  "@equipment_location_moved": {"description": "Snackbar after a move", "placeholders": {"count": {"type": "int"}}},
```

Run `flutter gen-l10n`. Per the l10n memory, generated methods take placeholders in `@placeholders` map order: `equipment_location_status_body(int count, String status)`. Test the rendered text, not the argument order.

- [ ] **Step 2: Write the failing flow test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final shop = EquipmentLocation(
    id: 'shop',
    name: 'Shop',
    kind: EquipmentLocationKind.serviceShop,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  EquipmentItem item(String id, EquipmentStatus status) => EquipmentItem(
    id: id,
    name: id,
    type: EquipmentType.regulator,
    status: status,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db.into(db.divers).insert(
      DiversCompanion.insert(id: 'me', name: 'me', createdAt: 1, updatedAt: 1),
    );
    for (final id in ['reg', 'second', 'bcd']) {
      await db.into(db.equipment).insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: 1,
          updatedAt: 1,
          parentEquipmentId: Value(id == 'second' ? 'reg' : null),
        ),
      );
    }
    await db.into(db.equipmentLocations).insert(
      EquipmentLocationsCompanion.insert(
        id: 'shop',
        name: 'Shop',
        kind: const Value('serviceShop'),
        createdAt: 1,
        updatedAt: 1,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('asks about parts, moves them, and offers status for every eligible item', () async {
    int? partsAsked;
    (EquipmentStatus, int)? statusAsked;
    List<String>? statusIds;
    final flow = EquipmentMoveFlow(
      moves: EquipmentLocationMoveRepository(),
      askMoveParts: (n) async {
        partsAsked = n;
        return true;
      },
      askStatus: (status, n) async {
        statusAsked = (status, n);
        return true;
      },
      setStatus: (ids, status) async => statusIds = ids,
    );
    final moved = await flow.run(
      items: [item('reg', EquipmentStatus.active), item('bcd', EquipmentStatus.inService)],
      target: shop,
      movedAt: DateTime(2026, 9, 3),
    );
    expect(partsAsked, 1);
    expect(moved, 3);
    expect(await EquipmentLocationMoveRepository().getCurrentLocationIds(), {
      'reg': 'shop',
      'second': 'shop',
      'bcd': 'shop',
    });
    // bcd is already In Service, so only reg and its part are offered.
    expect(statusAsked, (EquipmentStatus.inService, 2));
    expect(statusIds, unorderedEquals(['reg', 'second']));
  });

  test('declining parts moves only the selection; no offer for no location', () async {
    var statusAsked = false;
    final flow = EquipmentMoveFlow(
      moves: EquipmentLocationMoveRepository(),
      askMoveParts: (_) async => false,
      askStatus: (_, _) async => statusAsked = true,
      setStatus: (_, _) async {},
    );
    final moved = await flow.run(
      items: [item('reg', EquipmentStatus.active)],
      target: null,
      movedAt: DateTime(2026, 9, 3),
    );
    expect(moved, 1);
    expect(await EquipmentLocationMoveRepository().getCurrentLocationIds(), {'reg': null});
    expect(statusAsked, isFalse);
  });
}
```

Check `EquipmentItem`'s required constructor fields (`sed -n 1,80p lib/features/equipment/domain/entities/equipment_item.dart`) and adjust the `item(...)` helper to supply them.

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/equipment/data/services/equipment_move_flow_test.dart`
Expected: compile error.

- [ ] **Step 4: Implement the flow**

`lib/features/equipment/data/services/equipment_move_flow.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/location_status_offer.dart';

/// Moves gear to a place and runs the two follow-up prompts: whether the
/// items' parts go too, then whether to change their status. The prompts
/// and the status write are injected, so this runs the same under a
/// widget and in a unit test.
class EquipmentMoveFlow {
  const EquipmentMoveFlow({
    required this.moves,
    required this.askMoveParts,
    required this.askStatus,
    required this.setStatus,
  });

  final EquipmentLocationMoveRepository moves;

  /// Asked only when the items have parts not already selected.
  final Future<bool> Function(int partCount) askMoveParts;

  /// Asked only when at least one moved item is eligible for [status].
  final Future<bool> Function(EquipmentStatus status, int itemCount) askStatus;

  final Future<void> Function(List<String> ids, EquipmentStatus status)
  setStatus;

  /// Returns how many items were moved, parts included.
  Future<int> run({
    required List<EquipmentItem> items,
    required EquipmentLocation? target,
    required DateTime movedAt,
    String note = '',
  }) async {
    if (items.isEmpty) return 0;
    final statuses = {for (final i in items) i.id: i.status};
    final parts = await moves.partsOf(statuses.keys);
    if (parts.isNotEmpty && await askMoveParts(parts.length)) {
      statuses.addAll(parts);
    }
    await moves.recordMoves(
      equipmentIds: statuses.keys,
      locationId: target?.id,
      movedAt: movedAt,
      note: note,
    );
    final kind = target?.kind;
    EquipmentStatus? offered;
    final eligible = <String>[];
    for (final entry in statuses.entries) {
      final status = offeredStatusAfterMove(kind, entry.value);
      if (status == null) continue;
      offered = status;
      eligible.add(entry.key);
    }
    if (offered != null && await askStatus(offered, eligible.length)) {
      await setStatus(eligible, offered);
    }
    return statuses.length;
  }
}
```

(For a given kind every eligible item maps to the same offered status, so `offered` is well defined.)

- [ ] **Step 5: Implement the sheet and the UI entry point**

`lib/features/equipment/presentation/widgets/move_equipment_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Where, when and why, as the move sheet returns it.
class MoveDraft {
  const MoveDraft({required this.pick, required this.movedAt, this.note = ''});
  final LocationPick pick;
  final DateTime movedAt;
  final String note;
}

/// Moves [items]: the sheet, then the parts and status prompts, then a
/// SnackBar. Returns how many items moved, or null when cancelled.
Future<int?> showMoveEquipmentFlow(
  BuildContext context,
  WidgetRef ref, {
  required List<EquipmentItem> items,
}) async {
  if (items.isEmpty) return null;
  final draft = await showMoveEquipmentSheet(context, ref, itemCount: items.length);
  if (draft == null || !context.mounted) return null;
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ref.read(equipmentListNotifierProvider.notifier);
  Future<bool> ask(String title, String body, String yes, String no) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(no),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(yes),
            ),
          ],
        ),
      ) ??
      false;
  final flow = EquipmentMoveFlow(
    moves: ref.read(equipmentLocationMoveRepositoryProvider),
    askMoveParts: (n) => ask(
      l10n.equipment_location_parts_title,
      l10n.equipment_location_parts_body(n),
      l10n.equipment_location_parts_yes,
      l10n.equipment_location_parts_no,
    ),
    askStatus: (status, n) => ask(
      l10n.equipment_location_status_title,
      l10n.equipment_location_status_body(n, status.localizedName(l10n)),
      l10n.equipment_location_status_yes,
      l10n.equipment_location_status_no,
    ),
    setStatus: notifier.setStatusForMany,
  );
  final moved = await flow.run(
    items: items,
    target: switch (draft.pick) {
      PlacePick(:final location) => location,
      NoLocationPick() => null,
    },
    movedAt: draft.movedAt,
    note: draft.note,
  );
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.equipment_location_moved(moved))),
  );
  return moved;
}

/// The move sheet: destination, date and note. Null when dismissed.
Future<MoveDraft?> showMoveEquipmentSheet(
  BuildContext context,
  WidgetRef ref, {
  required int itemCount,
}) {
  return showModalBottomSheet<MoveDraft>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MoveEquipmentSheet(itemCount: itemCount),
  );
}

class _MoveEquipmentSheet extends ConsumerStatefulWidget {
  const _MoveEquipmentSheet({required this.itemCount});
  final int itemCount;

  @override
  ConsumerState<_MoveEquipmentSheet> createState() => _MoveEquipmentSheetState();
}

class _MoveEquipmentSheetState extends ConsumerState<_MoveEquipmentSheet> {
  LocationPick? _pick;
  DateTime _day = DateTime.now();
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Today keeps the current time, so two moves today stay in order; an
  /// earlier day is recorded at local noon.
  DateTime get _movedAt {
    final now = DateTime.now();
    final isToday =
        _day.year == now.year && _day.month == now.month && _day.day == now.day;
    return isToday ? now : DateTime(_day.year, _day.month, _day.day, 12);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final pick = _pick;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.equipment_location_move_title(widget.itemCount),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const ValueKey('move_equipment_to'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(switch (pick) {
                PlacePick(:final location) => location.kind.icon,
                NoLocationPick() => Icons.location_off_outlined,
                null => Icons.place_outlined,
              }),
              title: Text(l10n.equipment_location_move_to),
              subtitle: Text(switch (pick) {
                PlacePick(:final location) => location.name,
                NoLocationPick() => l10n.equipment_location_noLocation,
                null => l10n.equipment_location_move_choose,
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showEquipmentLocationPickerSheet(context, ref);
                if (picked != null) setState(() => _pick = picked);
              },
            ),
            ListTile(
              key: const ValueKey('move_equipment_date'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(l10n.equipment_location_move_date),
              subtitle: Text(units.formatDate(_day)),
              onTap: () async {
                final picked = await showAppDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime(1970),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _day = picked);
              },
            ),
            TextField(
              key: const ValueKey('move_equipment_note'),
              controller: _note,
              decoration: InputDecoration(
                labelText: l10n.equipment_location_move_note,
                hintText: l10n.equipment_location_move_noteHint,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('move_equipment_confirm'),
              onPressed: pick == null
                  ? null
                  : () => Navigator.of(context).pop(
                      MoveDraft(pick: pick, movedAt: _movedAt, note: _note.text),
                    ),
              child: Text(l10n.equipment_location_move_confirm),
            ),
          ],
        ),
      ),
    );
  }
}
```

Check `EquipmentStatus.localizedName(l10n)` exists in `equipment_enum_display.dart` (`grep -n "extension.*EquipmentStatus" lib/features/equipment/presentation/utils/equipment_enum_display.dart`); use the name it defines.

- [ ] **Step 6: Write the sheet widget test**

`test/features/equipment/presentation/widgets/move_equipment_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('Move stays disabled until a place is chosen', (tester) async {
    MoveDraft? draft;
    final garage = EquipmentLocation(
      id: 'g',
      name: 'Garage',
      kind: EquipmentLocationKind.storage,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [equipmentLocationsProvider.overrideWith((ref) async => [garage])],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async =>
                draft = await showMoveEquipmentSheet(context, ref, itemCount: 2),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Move 2 items'), findsOneWidget);
    final confirm = find.byKey(const ValueKey('move_equipment_confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('move_equipment_to')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garage'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('move_equipment_note')), 'annual');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect((draft!.pick as PlacePick).location.id, 'g');
    expect(draft!.note, 'annual');
  });
}
```

If the sheet's date row reads `settingsProvider` and that needs a database, add the settings override the neighbouring equipment widget tests use (`grep -rln "settingsProvider.overrideWith" test/features/equipment | head -1`).

- [ ] **Step 7: Run both tests**

Run: `flutter test test/features/equipment/data/services/equipment_move_flow_test.dart test/features/equipment/presentation/widgets/move_equipment_sheet_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib/features/equipment lib/l10n test/features/equipment
git commit -m "feat(equipment): move flow with parts prompt and status offer"
```

---

### Task 9: Location card on the detail page, move history editing

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_location_card.dart`
- Create: `lib/features/equipment/presentation/widgets/location_move_edit_dialog.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (after `_buildDetailsSection(...)` and its `SizedBox`, ~215)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/equipment/presentation/widgets/equipment_location_card_test.dart`

**Interfaces:**
- Consumes: Task 6 providers, Task 8 `showMoveEquipmentFlow`, Task 7 picker.
- Produces: `EquipmentLocationCard({required EquipmentItem equipment})`; `Future<void> showLocationMoveEditDialog(BuildContext context, WidgetRef ref, EquipmentLocationMove move)`.

- [ ] **Step 1: Add the English strings**

```json
  "equipment_location_card_title": "Location",
  "@equipment_location_card_title": {"description": "Title of the card showing where an item is"},
  "equipment_location_none": "No location set",
  "@equipment_location_none": {"description": "Shown when an item has no recorded location"},
  "equipment_location_since": "Since {date}",
  "@equipment_location_since": {"description": "When the item arrived at its current place", "placeholders": {"date": {"type": "String"}}},
  "equipment_location_moveButton": "Move",
  "@equipment_location_moveButton": {"description": "Button on the location card that moves the item"},
  "equipment_location_showAll": "Show all",
  "@equipment_location_showAll": {"description": "Expands the location history to every move"},
  "equipment_location_history_cleared": "Location cleared",
  "@equipment_location_history_cleared": {"description": "A history entry recording that the location was cleared"},
  "equipment_location_editMove_title": "Edit move",
  "@equipment_location_editMove_title": {"description": "Title of the dialog editing one history entry"},
  "equipment_location_editMove_delete": "Delete move",
  "@equipment_location_editMove_delete": {"description": "Deletes one history entry"},
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_card.dart';

import '../../../../helpers/test_app.dart';

void main() {
  final reg = EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.regulator);
  EquipmentLocation place(String id, String name, {bool archived = false}) =>
      EquipmentLocation(
        id: id,
        name: name,
        kind: EquipmentLocationKind.serviceShop,
        isArchived: archived,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
  EquipmentLocationMove move(String id, String? loc, int day, {String note = ''}) =>
      EquipmentLocationMove(
        id: id,
        equipmentId: 'reg',
        locationId: loc,
        movedAt: DateTime(2026, 9, day),
        note: note,
        createdAt: DateTime(2026, 9, day),
      );

  Future<void> pump(WidgetTester tester, List<EquipmentLocationMove> moves) =>
      tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            equipmentLocationMovesProvider('reg').overrideWith((ref) async => moves),
            allEquipmentLocationsByIdProvider.overrideWith(
              (ref) async => {
                'shop': place('shop', "Joe's Scuba"),
                'old': place('old', 'Old locker', archived: true),
              },
            ),
          ],
          child: SingleChildScrollView(child: EquipmentLocationCard(equipment: reg)),
        ),
      );

  testWidgets('no moves reads No location set', (tester) async {
    await pump(tester, const []);
    await tester.pumpAndSettle();
    expect(find.text('No location set'), findsOneWidget);
  });

  testWidgets('shows the current place, its note and the history', (tester) async {
    await pump(tester, [
      move('b', 'shop', 3, note: 'annual'),
      move('a', 'old', 1),
    ]);
    await tester.pumpAndSettle();
    expect(find.text("Joe's Scuba"), findsWidgets);
    expect(find.text('annual'), findsWidgets);
    expect(find.text('Old locker'), findsOneWidget);
  });

  testWidgets('a cleared latest move reads No location set', (tester) async {
    await pump(tester, [move('b', null, 3), move('a', 'shop', 1)]);
    await tester.pumpAndSettle();
    expect(find.text('No location set'), findsOneWidget);
    expect(find.text('Location cleared'), findsOneWidget);
  });
}
```

Provide any settings override the card's date formatting needs, as in Task 8 Step 6.

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_location_card_test.dart`
Expected: compile error.

- [ ] **Step 4: Implement the move edit dialog**

`lib/features/equipment/presentation/widgets/location_move_edit_dialog.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Edits one history entry's place, date and note, or deletes it. The
/// current location recomputes from what is left.
Future<void> showLocationMoveEditDialog(
  BuildContext context,
  WidgetRef ref,
  EquipmentLocationMove move,
) => showDialog<void>(
  context: context,
  builder: (_) => _LocationMoveEditDialog(move: move),
);

class _LocationMoveEditDialog extends ConsumerStatefulWidget {
  const _LocationMoveEditDialog({required this.move});
  final EquipmentLocationMove move;

  @override
  ConsumerState<_LocationMoveEditDialog> createState() =>
      _LocationMoveEditDialogState();
}

class _LocationMoveEditDialogState
    extends ConsumerState<_LocationMoveEditDialog> {
  late String? _locationId = widget.move.locationId;
  late DateTime _movedAt = widget.move.movedAt;
  late final TextEditingController _note = TextEditingController(
    text: widget.move.note,
  );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final places = ref.watch(allEquipmentLocationsByIdProvider).value ?? const {};
    final repo = ref.read(equipmentLocationMoveRepositoryProvider);
    return AlertDialog(
      title: Text(l10n.equipment_location_editMove_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.equipment_location_move_to),
            subtitle: Text(
              places[_locationId]?.name ?? l10n.equipment_location_noLocation,
            ),
            onTap: () async {
              final picked = await showEquipmentLocationPickerSheet(context, ref);
              if (picked == null) return;
              setState(() => _locationId = switch (picked) {
                PlacePick(:final location) => location.id,
                NoLocationPick() => null,
              });
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.equipment_location_move_date),
            subtitle: Text(units.formatDate(_movedAt)),
            onTap: () async {
              final picked = await showAppDatePicker(
                context: context,
                initialDate: _movedAt,
                firstDate: DateTime(1970),
                lastDate: DateTime.now(),
              );
              if (picked == null) return;
              // Keep the time of day, so editing the date never reorders
              // two moves made on the same day.
              setState(
                () => _movedAt = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  _movedAt.hour,
                  _movedAt.minute,
                  _movedAt.second,
                ),
              );
            },
          ),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: l10n.equipment_location_move_note,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('location_move_delete'),
          onPressed: () async {
            await repo.deleteMove(widget.move.id);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(l10n.equipment_location_editMove_delete),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () async {
            await repo.updateMove(
              _locationId == null
                  ? widget.move.copyWith(
                      clearLocation: true,
                      movedAt: _movedAt,
                      note: _note.text,
                    )
                  : widget.move.copyWith(
                      locationId: _locationId,
                      movedAt: _movedAt,
                      note: _note.text,
                    ),
            );
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Implement the card**

`lib/features/equipment/presentation/widgets/equipment_location_card.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/location_move_edit_dialog.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where an item is now, a Move button, and its recent moves (the full log
/// behind "Show all"). Tapping a move edits or deletes it.
class EquipmentLocationCard extends ConsumerStatefulWidget {
  const EquipmentLocationCard({super.key, required this.equipment});

  final EquipmentItem equipment;

  @override
  ConsumerState<EquipmentLocationCard> createState() =>
      _EquipmentLocationCardState();
}

class _EquipmentLocationCardState extends ConsumerState<EquipmentLocationCard> {
  static const _recentCount = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final moves =
        ref.watch(equipmentLocationMovesProvider(widget.equipment.id)).value ??
        const <EquipmentLocationMove>[];
    final places =
        ref.watch(allEquipmentLocationsByIdProvider).value ??
        const <String, EquipmentLocation>{};
    final latest = moves.isEmpty ? null : moves.first;
    final current = latest == null ? null : places[latest.locationId];
    final shown = _showAll ? moves : moves.take(_recentCount).toList();

    return Card(
      key: const ValueKey('equipment_location_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.equipment_location_card_title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('equipment_location_move'),
                  icon: const Icon(Icons.move_down),
                  label: Text(l10n.equipment_location_moveButton),
                  onPressed: () => showMoveEquipmentFlow(
                    context,
                    ref,
                    items: [widget.equipment],
                  ),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(current?.kind.icon ?? Icons.location_off_outlined),
              title: Text(current?.name ?? l10n.equipment_location_none),
              subtitle: current == null
                  ? null
                  : Text(
                      [
                        l10n.equipment_location_since(
                          units.formatDate(latest!.movedAt),
                        ),
                        if (latest.note.isNotEmpty) latest.note,
                      ].join('\n'),
                    ),
            ),
            if (moves.isNotEmpty) const Divider(),
            for (final m in shown)
              ListTile(
                key: ValueKey('equipment_location_move_${m.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  places[m.locationId]?.kind.icon ?? Icons.location_off_outlined,
                  size: 20,
                ),
                title: Text(
                  places[m.locationId]?.name ??
                      l10n.equipment_location_history_cleared,
                ),
                subtitle: Text(
                  [units.formatDate(m.movedAt), if (m.note.isNotEmpty) m.note]
                      .join(' · '),
                ),
                onTap: () => showLocationMoveEditDialog(context, ref, m),
              ),
            if (!_showAll && moves.length > _recentCount)
              TextButton(
                onPressed: () => setState(() => _showAll = true),
                child: Text(l10n.equipment_location_showAll),
              ),
          ],
        ),
      ),
    );
  }
}
```

The separator `' · '` is a middle dot, not a dash. In the detail page, after `_buildDetailsSection(context, ref, equipment, units),` and its `const SizedBox(height: 24),` add:

```dart
          EquipmentLocationCard(equipment: equipment),
          const SizedBox(height: 24),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_location_card_test.dart test/features/equipment/presentation/pages > "$SCRATCH/detail.log" 2>&1; tail -20 "$SCRATCH/detail.log"`
Expected: PASS. Detail page tests that do not override the new providers may need `equipmentLocationMovesProvider` and `allEquipmentLocationsByIdProvider` overrides (empty) if they run without a database; add them where they fail.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/equipment lib/l10n test/features/equipment
git commit -m "feat(equipment): location card and move history on the detail page"
```

---

### Task 10: Create-form location, bulk move action

**Files:**
- Create: `lib/features/equipment/presentation/widgets/equipment_location_field.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (state field; after the Tags field ~568; `_saveEquipment` new-item branch ~1123)
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`_bulkActions`, after `editTags` ~538)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/equipment/presentation/widgets/equipment_location_field_test.dart`

**Interfaces:**
- Consumes: Task 7 picker, Task 8 flow, Task 4 `recordMoves`.
- Produces: `EquipmentLocationField({required EquipmentLocation? value, required ValueChanged<EquipmentLocation?> onChanged})`.

- [ ] **Step 1: Add the English strings**

```json
  "equipment_edit_locationLabel": "Location",
  "@equipment_edit_locationLabel": {"description": "Label of the optional place picker on the new equipment form"},
  "equipment_edit_locationNone": "Not set",
  "@equipment_edit_locationNone": {"description": "Shown in the new equipment form's location picker when none is chosen"},
  "equipment_location_bulkAction": "Move to location",
  "@equipment_location_bulkAction": {"description": "Bulk action moving the selected gear to a place"},
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing field test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_field.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('picking a place reports it; No location clears it', (tester) async {
    final garage = EquipmentLocation(
      id: 'g',
      name: 'Garage',
      kind: EquipmentLocationKind.storage,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    EquipmentLocation? value;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [equipmentLocationsProvider.overrideWith((ref) async => [garage])],
        child: StatefulBuilder(
          builder: (context, setState) => EquipmentLocationField(
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    expect(find.text('Not set'), findsOneWidget);
    await tester.tap(find.byType(EquipmentLocationField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garage'));
    await tester.pumpAndSettle();
    expect(value?.id, 'g');
    expect(find.text('Garage'), findsOneWidget);

    await tester.tap(find.byType(EquipmentLocationField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No location'));
    await tester.pumpAndSettle();
    expect(value, isNull);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_location_field_test.dart`
Expected: compile error.

- [ ] **Step 4: Implement the field**

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The new equipment form's optional place. Saving the item writes its
/// first move here; an existing item changes place only through Move, so
/// every change lands in its history.
class EquipmentLocationField extends ConsumerWidget {
  const EquipmentLocationField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final EquipmentLocation? value;
  final ValueChanged<EquipmentLocation?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () async {
        final picked = await showEquipmentLocationPickerSheet(context, ref);
        if (picked == null) return;
        onChanged(switch (picked) {
          PlacePick(:final location) => location,
          NoLocationPick() => null,
        });
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.equipment_edit_locationLabel,
          prefixIcon: Icon(value?.kind.icon ?? Icons.place_outlined),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(value?.name ?? l10n.equipment_edit_locationNone),
      ),
    );
  }
}
```

- [ ] **Step 5: Wire the form and the bulk action**

In `equipment_edit_page.dart` state, add `EquipmentLocation? _initialLocation;`. After the Tags field's `const SizedBox(height: 24),`:

```dart
          // Location (new items only): edits go through Move, so every
          // change lands in the item's history.
          if (!widget.isEditing) ...[
            EquipmentLocationField(
              value: _initialLocation,
              onChanged: (loc) => setState(() {
                _initialLocation = loc;
                _hasChanges = true;
              }),
            ),
            const SizedBox(height: 24),
          ],
```

In `_saveEquipment`'s new-item branch, after `savedId = newEquipment.id;`:

```dart
        final place = _initialLocation;
        if (place != null) {
          await ref
              .read(equipmentLocationMoveRepositoryProvider)
              .recordMoves(
                equipmentIds: [savedId],
                locationId: place.id,
                movedAt: DateTime.now(),
              );
        }
```

In `equipment_list_content.dart` `_bulkActions`, after the `editTags` action:

```dart
      BulkAction(
        id: 'moveToLocation',
        icon: Icons.move_down,
        label: context.l10n.equipment_location_bulkAction,
        onInvoke: () async {
          final ids = _selectedIds;
          final moved = await showMoveEquipmentFlow(
            context,
            ref,
            items: [
              for (final e in equipment)
                if (ids.contains(e.id)) e,
            ],
          );
          return moved == null
              ? BulkActionOutcome.cancelled
              : BulkActionOutcome.completed;
        },
      ),
```

Wrap the flow call in `try`/`catch` returning `BulkActionOutcome.failed` with an error SnackBar, matching how `printLabels` handles failure in the same list.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_location_field_test.dart test/features/equipment/presentation/pages/equipment_edit_page_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart > "$SCRATCH/form.log" 2>&1; tail -20 "$SCRATCH/form.log"`
Expected: PASS. A test pinning the exact bulk-action ids or count needs `moveToLocation` added. (Use `ls` to confirm the test file names first.)

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/features/equipment lib/l10n test/features/equipment
git commit -m "feat(equipment): location on the new item form and a bulk move action"
```

---

### Task 11: Location filter and group-by-location in the list

**Files:**
- Create: `lib/features/equipment/domain/services/equipment_location_arranger.dart`
- Create: `lib/features/equipment/presentation/widgets/equipment_location_filter_section.dart`
- Create: `lib/features/equipment/presentation/widgets/equipment_location_group_header.dart`
- Create: `lib/features/equipment/presentation/widgets/group_by_location_switch.dart`
- Modify: `lib/features/equipment/domain/models/equipment_filter_state.dart`
- Modify: `lib/features/equipment/query/equipment_filter_query.dart`
- Modify: `lib/features/equipment/query/equipment_query_entity.dart`
- Modify: `lib/features/query/presentation/query_label_lookup.dart` (~338)
- Modify: `lib/features/equipment/presentation/widgets/equipment_filter_sheet.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_sort_sheet_layout.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_sort_sheet.dart`
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/equipment/domain/services/equipment_location_arranger_test.dart`
- Test: `test/features/equipment/query/equipment_location_filter_test.dart`

**Interfaces:**
- Consumes: Task 4 `currentLocationIdSql`, Task 6 providers.
- Produces:
  - `EquipmentFilterState.locationIds` (`Set<String>`) and `.noLocation` (`bool`), with `copyWith(locationIds:, noLocation:, clearLocation:)`.
  - Query field `location` (`FieldType.id`).
  - `class EquipmentLocationSection { final EquipmentLocation? location; final List<EquipmentGroup> groups; int get itemCount; }`
  - `List<EquipmentLocationSection> arrangeEquipmentByLocation(List<EquipmentItem> items, EquipmentArrangement arrangement, {required Map<String, EquipmentLocation> locationOf, required String Function(EquipmentType) typeLabel, Comparator<EquipmentItem>? compareItems})`

- [ ] **Step 1: Add the English strings**

```json
  "equipment_filter_section_location": "Location",
  "@equipment_filter_section_location": {"description": "Heading of the location section in the equipment filter"},
  "equipment_arrange_groupByLocation": "Group by location",
  "@equipment_arrange_groupByLocation": {"description": "Switch on the Equipment page's sort sheet grouping the list under one heading per place"},
  "equipment_arrange_groupByLocationSubtitle": "One heading per place, on this page only",
  "@equipment_arrange_groupByLocationSubtitle": {"description": "Subtitle of the group by location switch"},
  "equipment_location_groupCount": "{count, plural, one{{count} item} other{{count} items}}",
  "@equipment_location_groupCount": {"description": "Item count beside a location heading and on the Locations page", "placeholders": {"count": {"type": "int"}}},
  "query_equipment_location": "Location",
  "@query_equipment_location": {"description": "Field label in the query builder: the place an item is now"},
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing arranger test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_location_arranger.dart';

void main() {
  EquipmentLocation place(String id, String name, EquipmentLocationKind kind, {bool archived = false}) =>
      EquipmentLocation(
        id: id,
        name: name,
        kind: kind,
        isArchived: archived,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
  EquipmentItem item(String id, EquipmentType type) =>
      EquipmentItem(id: id, name: id, type: type);

  final shop = place('shop', 'Shop', EquipmentLocationKind.serviceShop);
  final garage = place('garage', 'Garage', EquipmentLocationKind.storage);
  final attic = place('attic', 'Attic', EquipmentLocationKind.storage, archived: true);

  final items = [
    item('reg', EquipmentType.regulator),
    item('bcd', EquipmentType.bcd),
    item('fins', EquipmentType.fins),
    item('mask', EquipmentType.mask),
  ];
  final locationOf = {'reg': shop, 'bcd': garage, 'fins': attic};

  test('storage before service shop, names within a kind, no location last', () {
    final sections = arrangeEquipmentByLocation(
      items,
      EquipmentArrangement.defaults,
      locationOf: locationOf,
      typeLabel: (t) => t.name,
    );
    expect([for (final s in sections) s.location?.id], ['attic', 'garage', 'shop', null]);
    expect(sections.last.itemCount, 1);
  });

  test('archived place still heads its items', () {
    final sections = arrangeEquipmentByLocation(
      items,
      EquipmentArrangement.defaults,
      locationOf: locationOf,
      typeLabel: (t) => t.name,
    );
    expect(sections.first.location!.isArchived, isTrue);
    expect(sections.first.groups.expand((g) => g.items).single.id, 'fins');
  });

  test('type sub-groups inside a place follow the arrangement', () {
    final grouped = arrangeEquipmentByLocation(
      [item('a', EquipmentType.regulator), item('b', EquipmentType.bcd)],
      EquipmentArrangement.defaults,
      locationOf: {'a': garage, 'b': garage},
      typeLabel: (t) => t.name,
    );
    expect(grouped.single.groups.map((g) => g.type), [EquipmentType.bcd, EquipmentType.regulator]);
    final flat = arrangeEquipmentByLocation(
      [item('a', EquipmentType.regulator), item('b', EquipmentType.bcd)],
      EquipmentArrangement.defaults.copyWith(groupByType: false),
      locationOf: {'a': garage, 'b': garage},
      typeLabel: (t) => t.name,
    );
    expect(flat.single.groups.single.type, isNull);
  });
}
```

- [ ] **Step 3: Write the failing filter test**

`test/features/equipment/query/equipment_location_filter_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/query/equipment_filter_query.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['reg', 'bcd', 'fins']) {
      await db.into(db.equipment).insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: 1,
          updatedAt: 1,
        ),
      );
    }
    for (final id in ['shop', 'garage']) {
      await db.into(db.equipmentLocations).insert(
        EquipmentLocationsCompanion.insert(id: id, name: id, createdAt: 1, updatedAt: 1),
      );
    }
    Future<void> move(String id, String e, String? l, int at) =>
        db.into(db.equipmentLocationMoves).insert(
          EquipmentLocationMovesCompanion.insert(
            id: id,
            equipmentId: e,
            locationId: Value(l),
            movedAt: at,
            createdAt: at,
          ),
        );
    await move('1', 'reg', 'garage', 1);
    await move('2', 'reg', 'shop', 2);
    await move('3', 'bcd', 'garage', 1);
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids(EquipmentFilterState f) =>
      QueryIdSetRunner(db).ids(compileEquipmentFilter(f));

  test('filters by current place, not past ones', () async {
    expect(await ids(const EquipmentFilterState(locationIds: {'garage'})), {'bcd'});
    expect(await ids(const EquipmentFilterState(locationIds: {'shop'})), {'reg'});
  });

  test('No location matches items never moved, ORed with places', () async {
    expect(await ids(const EquipmentFilterState(noLocation: true)), {'fins'});
    expect(
      await ids(const EquipmentFilterState(locationIds: {'shop'}, noLocation: true)),
      {'reg', 'fins'},
    );
  });

  test('the field reads the moves table, so the list refreshes on a move', () {
    final compiled = compileEquipmentFilter(
      const EquipmentFilterState(locationIds: {'shop'}),
    );
    expect(compiled.tablesTouched, contains('equipment_location_moves'));
  });
}
```

- [ ] **Step 4: Run both to verify they fail**

Run: `flutter test test/features/equipment/domain/services/equipment_location_arranger_test.dart test/features/equipment/query/equipment_location_filter_test.dart`
Expected: compile errors.

- [ ] **Step 5: Implement the filter axis**

In `equipment_filter_state.dart`, add after `tagIds`:

```dart
  /// Current places, any-of (v267). Empty means no place narrowing.
  final Set<String> locationIds;

  /// Include items with no current location, ORed with [locationIds].
  final bool noLocation;
```

Constructor defaults `this.locationIds = const {}, this.noLocation = false,`. Add `locationIds.isNotEmpty || noLocation` to `hasActiveFilters`. `copyWith` gains `Set<String>? locationIds, bool? noLocation, bool clearLocation = false` with:

```dart
      locationIds: clearLocation ? const {} : (locationIds ?? this.locationIds),
      noLocation: clearLocation ? false : (noLocation ?? this.noLocation),
```

Add both to `==` (`setEquals(other.locationIds, locationIds) && other.noLocation == noLocation`), `hashCode` (`Object.hashAllUnordered(locationIds), noLocation`) and `toString`.

In `equipment_query_entity.dart`, import `equipment_location_sql.dart` and add to `fields` after `nextServiceDue`:

```dart
    // Where the item is now (v267): its newest move's place.
    QueryField(
      key: 'location',
      type: FieldType.id,
      sql: currentLocationIdSql('{r}.id'),
      emptySql: '${currentLocationIdSql('{r}.id')} IS NULL',
      labelKey: 'query_equipment_location',
      tables: const ['equipment_location_moves'],
    ),
```

In `query_label_lookup.dart`, beside `query_equipment_nextServiceDue`:

```dart
    case 'query_equipment_location':
      return l10n.query_equipment_location;
```

In `equipment_filter_query.dart` `toQuery()`, after the tags block:

```dart
    if (locationIds.isNotEmpty || noLocation) {
      final options = <QueryNode>[
        if (locationIds.isNotEmpty)
          c(
            'location',
            QueryOp.inList,
            ListValue([
              for (final id in locationIds.toList()..sort()) StringValue(id),
            ]),
          ),
        if (noLocation) c('location', QueryOp.isEmpty, null),
      ];
      parts.add(options.length == 1 ? options.single : OrNode(options));
    }
```

Run `test/features/equipment/query/` (the census test requires both new field names to appear in this file).

- [ ] **Step 6: Implement the filter sheet section**

`lib/features/equipment/presentation/widgets/equipment_location_filter_section.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The filter panel's place chips, any-of, plus "No location". Offers the
/// diver's active places and any already selected, so a filter on a place
/// since archived stays clearable.
class EquipmentLocationFilterSection extends ConsumerWidget {
  const EquipmentLocationFilterSection({
    super.key,
    required this.locationIds,
    required this.noLocation,
    required this.onChanged,
  });

  final Set<String> locationIds;
  final bool noLocation;
  final void Function(Set<String> locationIds, bool noLocation) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final places = [
      for (final p in ref.watch(equipmentLocationsProvider).value ?? const <EquipmentLocation>[])
        if (!p.isArchived || locationIds.contains(p.id)) p,
    ];
    if (places.isEmpty && !noLocation) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.equipment_filter_section_location,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in places)
                FilterChip(
                  key: ValueKey('equipment_filter_location_${p.id}'),
                  avatar: Icon(p.kind.icon, size: 16),
                  label: Text(p.name),
                  selected: locationIds.contains(p.id),
                  onSelected: (selected) => onChanged(
                    selected
                        ? {...locationIds, p.id}
                        : locationIds.where((id) => id != p.id).toSet(),
                    noLocation,
                  ),
                ),
              FilterChip(
                key: const ValueKey('equipment_filter_location_none'),
                avatar: const Icon(Icons.location_off_outlined, size: 16),
                label: Text(l10n.equipment_location_noLocation),
                selected: noLocation,
                onSelected: (selected) => onChanged(locationIds, selected),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

In `equipment_filter_sheet.dart`: add draft fields `Set<String> _locationIds = const {}; bool _noLocation = false;`, initialise them from `filter` in `initState`, clear them in `_clearAll`, pass them in `_applyFilters`, and add after `_buildTagSection(),`:

```dart
                        EquipmentLocationFilterSection(
                          locationIds: _locationIds,
                          noLocation: _noLocation,
                          onChanged: (ids, none) => setState(() {
                            _locationIds = ids;
                            _noLocation = none;
                          }),
                        ),
```

In `equipment_list_content.dart` `_buildActiveFiltersBar`, after the tag chips, add one chip when `filter.locationIds.isNotEmpty || filter.noLocation`, labelled `context.l10n.equipment_filter_section_location`, whose delete sets `filter.copyWith(clearLocation: true)`, using the same `_buildActiveFilterChip` helper as its neighbours.

- [ ] **Step 7: Implement the arranger**

`lib/features/equipment/domain/services/equipment_location_arranger.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';

/// One place's run of gear when the Equipment page groups by location.
/// [location] is null for the items with no location. [groups] are the
/// shared arrangement's type groups inside this place.
@immutable
class EquipmentLocationSection {
  final EquipmentLocation? location;
  final List<EquipmentGroup> groups;

  const EquipmentLocationSection({required this.location, required this.groups});

  int get itemCount => groups.fold(0, (sum, g) => sum + g.items.length);
}

/// Splits [items] by current place ([locationOf], item id to place; absent
/// means no location), then arranges each place's gear with
/// [arrangeEquipment] unchanged. Places come by kind (storage, service
/// shop, person, other), then by name, then id; "No location" last.
List<EquipmentLocationSection> arrangeEquipmentByLocation(
  List<EquipmentItem> items,
  EquipmentArrangement arrangement, {
  required Map<String, EquipmentLocation> locationOf,
  required String Function(EquipmentType) typeLabel,
  Comparator<EquipmentItem>? compareItems,
}) {
  if (items.isEmpty) return const [];
  final buckets = <String?, List<EquipmentItem>>{};
  final places = <String, EquipmentLocation>{};
  for (final item in items) {
    final place = locationOf[item.id];
    if (place != null) places[place.id] = place;
    buckets.putIfAbsent(place?.id, () => []).add(item);
  }
  final ordered = places.values.toList()
    ..sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
  EquipmentLocationSection section(EquipmentLocation? place) =>
      EquipmentLocationSection(
        location: place,
        groups: arrangeEquipment(
          buckets[place?.id]!,
          arrangement,
          typeLabel: typeLabel,
          compareItems: compareItems,
        ),
      );
  return [
    for (final place in ordered) section(place),
    if (buckets.containsKey(null)) section(null),
  ];
}
```

- [ ] **Step 8: Implement the heading, the switch and the list rendering**

`equipment_location_group_header.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A place's heading when the Equipment page groups by location: kind icon,
/// name ("No location" for null) and item count. A header for assistive
/// tech, like the type headings under it.
class EquipmentLocationGroupHeader extends StatelessWidget {
  EquipmentLocationGroupHeader({required this.location, required this.count})
    : super(key: ValueKey('equipment-location-header-${location?.id ?? 'none'}'));

  final EquipmentLocation? location;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Icon(
              location?.kind.icon ?? Icons.location_off_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                location?.name ?? l10n.equipment_location_noLocation,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              l10n.equipment_location_groupCount(count),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

`group_by_location_switch.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Equipment page's own grouping switch. Not part of the shared gear
/// arrangement: "where it is stored" says nothing about a dive.
class GroupByLocationSwitch extends ConsumerWidget {
  const GroupByLocationSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(equipmentGroupByLocationProvider).value ?? false;
    return SwitchListTile(
      key: const ValueKey('equipment_group_by_location'),
      value: on,
      onChanged: (value) => ref
          .read(appSettingsRepositoryProvider)
          .setEquipmentGroupByLocation(value),
      title: Text(l10n.equipment_arrange_groupByLocation),
      subtitle: Text(l10n.equipment_arrange_groupByLocationSubtitle),
    );
  }
}
```

In `equipment_sort_sheet_layout.dart`, add `this.pageGrouping` (`final Widget? pageGrouping;`, documented "Grouping only this page offers, above the shared controls") and render it inside the `if (showGrouping) ...[` block, before `const EquipmentGroupingControls()`:

```dart
                if (pageGrouping != null) ...[
                  pageGrouping!,
                  const Divider(height: 1),
                ],
```

In `equipment_list_sort_sheet.dart`, pass `pageGrouping: const GroupByLocationSwitch(),` to `EquipmentSortSheetLayout`.

In `equipment_list_content.dart`:
1. Add a row type beside the others:
```dart
class _EquipmentLocationHeadingRow extends _EquipmentListRow {
  const _EquipmentLocationHeadingRow(this.location, this.count);

  final EquipmentLocation? location;
  final int count;
}
```
and give `_EquipmentHeadingRow` an optional `final String? sectionKey;` (constructor `const _EquipmentHeadingRow(this.type, {this.sectionKey})`).
2. In `build`, after `arrangement` is chosen:
```dart
    final groupByLocation =
        _honoursArrangement(viewMode) &&
        (ref.watch(equipmentGroupByLocationProvider).value ?? false);
    final locationSections = groupByLocation
        ? arrangeEquipmentByLocation(
            equipmentAsync.value ?? const <EquipmentItem>[],
            arrangement,
            locationOf:
                ref.watch(currentEquipmentLocationsProvider).value ?? const {},
            typeLabel: (t) => t.localizedName(context.l10n),
            compareItems: compareItems,
          )
        : null;
    final visibleGroups = locationSections != null
        ? [for (final s in locationSections) ...s.groups]
        : arrangeEquipment(
            equipmentAsync.value ?? const <EquipmentItem>[],
            arrangement,
            typeLabel: (t) => t.localizedName(context.l10n),
            compareItems: compareItems,
          );
```
replacing the existing single `arrangeEquipment` call, and pass `locationSections` into `_buildEquipmentList` as a new named parameter `List<EquipmentLocationSection>? locationSections`.
3. In `_buildEquipmentList`, build rows:
```dart
    final rows = <_EquipmentListRow>[
      if (locationSections != null)
        for (final section in locationSections) ...[
          _EquipmentLocationHeadingRow(section.location, section.itemCount),
          for (final group in section.groups) ...[
            if (group.type != null)
              _EquipmentHeadingRow(
                group.type!,
                sectionKey: section.location?.id ?? 'none',
              ),
            for (final item in group.items) _EquipmentItemRow(item),
          ],
        ]
      else
        for (final group in groups) ...[
          if (group.type != null) _EquipmentHeadingRow(group.type!),
          for (final item in group.items) _EquipmentItemRow(item),
        ],
    ];
```
4. In the `itemBuilder` switch:
```dart
            case _EquipmentLocationHeadingRow(:final location, :final count):
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EquipmentLocationGroupHeader(
                  location: location,
                  count: count,
                ),
              );
            case _EquipmentHeadingRow(:final type, :final sectionKey):
              // Keyed by place and type: "Regulators" can head two places.
              return KeyedSubtree(
                key: ValueKey('equipment-type-${sectionKey ?? ''}-${type.name}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EquipmentGroupHeader(type: type),
                ),
              );
```
5. `_scrollToIndex`: count `_EquipmentLocationHeadingRow` as a heading (`row is _EquipmentHeadingRow || row is _EquipmentLocationHeadingRow`).
6. `_typeAxisOf`: take `groupByLocation` and return `(groupByLocation, <existing value>)`, so toggling the switch re-scrolls to the selected item; update its callers.

- [ ] **Step 9: Run the tests**

Run: `flutter test test/features/equipment/domain/services/equipment_location_arranger_test.dart test/features/equipment/query test/features/equipment/presentation/widgets > "$SCRATCH/list.log" 2>&1; tail -30 "$SCRATCH/list.log"`
Expected: PASS. Existing list tests that build without a database may need `currentEquipmentLocationsProvider` and `equipmentGroupByLocationProvider` overrides (`{}`, `false`).

- [ ] **Step 10: Commit**

```bash
dart format lib test
git add lib/features/equipment lib/features/query/presentation/query_label_lookup.dart lib/l10n test/features/equipment
git commit -m "feat(equipment): filter and group the equipment list by location"
```

---

### Task 12: Settings > Manage > Locations

**Files:**
- Create: `lib/features/equipment/presentation/pages/equipment_location_list_page.dart`
- Create: `lib/features/equipment/presentation/pages/equipment_location_detail_page.dart`
- Modify: `lib/core/router/app_router.dart` (beside the `service-types` route ~592, before the `:equipmentId` catch-all)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (after the Service types tile ~2527)
- Modify: `test/features/settings/presentation/pages/settings_page_test.dart` (stub routes ~1701)
- Modify: `lib/l10n/arb/app_en.arb`
- Test: `test/features/equipment/presentation/pages/equipment_location_list_page_test.dart`

**Interfaces:**
- Consumes: Task 6 providers, Task 7 edit dialog, `allEquipmentProvider`.
- Produces: routes `/equipment/locations` (`manageEquipmentLocations`) and `/equipment/locations/:locationId` (`equipmentLocationDetail`); `EquipmentLocationListPage`, `EquipmentLocationDetailPage({required String locationId})`.

- [ ] **Step 1: Add the English strings**

```json
  "settings_manage_locations": "Locations",
  "@settings_manage_locations": {"description": "Settings > Manage tile opening the list of places where gear is kept"},
  "settings_manage_locations_subtitle": "Where your gear is kept, serviced or lent",
  "@settings_manage_locations_subtitle": {"description": "Subtitle of the Locations tile in Settings > Manage"},
  "equipment_locations_title": "Locations",
  "@equipment_locations_title": {"description": "Title of the page listing places where gear is kept"},
  "equipment_locations_empty": "No places yet. Add one to start tracking where your gear is.",
  "@equipment_locations_empty": {"description": "Empty state of the Locations page"},
  "equipment_locations_add": "Add place",
  "@equipment_locations_add": {"description": "Button adding a place on the Locations page"},
  "equipment_locations_archivedSection": "Archived ({count})",
  "@equipment_locations_archivedSection": {"description": "Collapsed section of archived places", "placeholders": {"count": {"type": "int"}}},
  "equipment_locations_archive": "Archive",
  "@equipment_locations_archive": {"description": "Archives a place that history still names"},
  "equipment_locations_restore": "Restore",
  "@equipment_locations_restore": {"description": "Restores an archived place"},
  "equipment_locations_delete": "Delete",
  "@equipment_locations_delete": {"description": "Deletes a place no item has ever been at"},
  "equipment_locations_itemsHere": "Items here",
  "@equipment_locations_itemsHere": {"description": "Heading of the list of items currently at a place"},
  "equipment_locations_noItemsHere": "Nothing is here right now.",
  "@equipment_locations_noItemsHere": {"description": "Shown when no item is currently at a place"},
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing page test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/test_app.dart';

void main() {
  EquipmentLocation place(String id, String name, EquipmentLocationKind kind, {bool archived = false}) =>
      EquipmentLocation(
        id: id,
        name: name,
        kind: kind,
        isArchived: archived,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  testWidgets('groups by kind with counts; archived collapsed', (tester) async {
    final garage = place('g', 'Garage', EquipmentLocationKind.storage);
    final shop = place('s', 'Shop', EquipmentLocationKind.serviceShop);
    final attic = place('a', 'Attic', EquipmentLocationKind.storage, archived: true);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          equipmentLocationsProvider.overrideWith((ref) async => [attic, garage, shop]),
          currentEquipmentLocationsProvider.overrideWith(
            (ref) async => {'reg': garage, 'bcd': garage, 'fins': shop},
          ),
          allEquipmentProvider.overrideWith(
            (ref) async => [
              for (final id in ['reg', 'bcd', 'fins'])
                EquipmentItem(id: id, name: id, type: EquipmentType.regulator),
            ],
          ),
        ],
        child: const EquipmentLocationListPage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('Attic'), findsNothing);
    await tester.tap(find.text('Archived (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Attic'), findsOneWidget);
  });
}
```

Check `allEquipmentProvider`'s type (`grep -n "final allEquipmentProvider" lib/features/equipment/presentation/providers/equipment_providers.dart`) and match its override shape. Counts exclude retired and sold items.

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/pages/equipment_location_list_page_test.dart`
Expected: compile error.

- [ ] **Step 4: Implement the list page**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage > Locations: the diver's places by kind, with how many
/// items are at each now. Archived places sit in a collapsed section.
class EquipmentLocationListPage extends ConsumerWidget {
  const EquipmentLocationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final places = ref.watch(equipmentLocationsProvider).value ?? const <EquipmentLocation>[];
    final counts = locationItemCounts(ref);
    final active = [for (final p in places) if (!p.isArchived) p];
    final archived = [for (final p in places) if (p.isArchived) p];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.equipment_locations_title)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('equipment_locations_add'),
        icon: const Icon(Icons.add),
        label: Text(l10n.equipment_locations_add),
        onPressed: () => showEquipmentLocationEditDialog(context, ref),
      ),
      body: places.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.equipment_locations_empty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final kind in EquipmentLocationKind.values)
                  ..._kindSection(context, kind, [
                    for (final p in active)
                      if (p.kind == kind) p,
                  ], counts),
                if (archived.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      l10n.equipment_locations_archivedSection(archived.length),
                    ),
                    children: [
                      for (final p in archived) _placeTile(context, p, counts),
                    ],
                  ),
              ],
            ),
    );
  }

  List<Widget> _kindSection(
    BuildContext context,
    EquipmentLocationKind kind,
    List<EquipmentLocation> places,
    Map<String, int> counts,
  ) {
    if (places.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          kind.localizedName(context.l10n),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
      for (final p in places) _placeTile(context, p, counts),
    ];
  }

  Widget _placeTile(
    BuildContext context,
    EquipmentLocation place,
    Map<String, int> counts,
  ) {
    return ListTile(
      key: ValueKey('equipment_location_${place.id}'),
      leading: Icon(place.kind.icon),
      title: Text(place.name),
      subtitle: place.notes.isEmpty ? null : Text(place.notes, maxLines: 1),
      trailing: Text(context.l10n.equipment_location_groupCount(counts[place.id] ?? 0)),
      onTap: () => context.push('/equipment/locations/${place.id}'),
    );
  }
}

/// Items at each place now, retired and sold gear left out.
Map<String, int> locationItemCounts(WidgetRef ref) {
  final items = ref.watch(allEquipmentProvider).value ?? const [];
  final current = ref.watch(currentEquipmentLocationsProvider).value ?? const {};
  final counts = <String, int>{};
  for (final item in items) {
    if (item.status == EquipmentStatus.retired ||
        item.status == EquipmentStatus.sold) {
      continue;
    }
    final place = current[item.id];
    if (place != null) counts[place.id] = (counts[place.id] ?? 0) + 1;
  }
  return counts;
}
```

- [ ] **Step 5: Implement the detail page**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_location_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One place: its kind and notes, the items there now, and edit, archive,
/// restore and delete. Delete shows only for a place no move names.
class EquipmentLocationDetailPage extends ConsumerWidget {
  const EquipmentLocationDetailPage({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final place = (ref.watch(allEquipmentLocationsByIdProvider).value ?? const {})[locationId];
    if (place == null) {
      return Scaffold(appBar: AppBar());
    }
    final current = ref.watch(currentEquipmentLocationsProvider).value ?? const {};
    final items = [
      for (final item in ref.watch(allEquipmentProvider).value ?? const [])
        if (current[item.id]?.id == locationId &&
            item.status != EquipmentStatus.retired &&
            item.status != EquipmentStatus.sold)
          item,
    ];
    final repo = ref.read(equipmentLocationRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(place.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: l10n.equipment_locations_editTitle,
            onPressed: () =>
                showEquipmentLocationEditDialog(context, ref, existing: place),
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              switch (action) {
                case 'archive':
                  await repo.setArchived(place.id, archived: !place.isArchived);
                case 'delete':
                  await repo.deleteLocation(place.id);
                  if (context.mounted) context.pop();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  place.isArchived
                      ? l10n.equipment_locations_restore
                      : l10n.equipment_locations_archive,
                ),
              ),
              if (!(ref.watch(_inUseProvider(place.id)).value ?? true))
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.equipment_locations_delete),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(place.kind.icon),
            title: Text(place.kind.localizedName(l10n)),
            subtitle: place.notes.isEmpty ? null : Text(place.notes),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              l10n.equipment_locations_itemsHere,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.equipment_locations_noItemsHere),
            ),
          for (final item in items)
            ListTile(
              key: ValueKey('equipment_location_item_${item.id}'),
              title: Text(item.name),
              onTap: () => context.push('/equipment/${item.id}'),
            ),
        ],
      ),
    );
  }
}

final _inUseProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  id,
) async {
  final moves = ref.watch(equipmentLocationMoveRepositoryProvider);
  ref.invalidateSelfWhen(moves.watchChanges());
  return ref.watch(equipmentLocationRepositoryProvider).isInUse(id);
});
```

Before using `item.type.localizedName` or similar in the tiles, keep it to the name as above; the equipment list already shows rich tiles.

- [ ] **Step 6: Wire the route and the tile**

In `app_router.dart`, beside the `service-types` route (before the `:equipmentId` catch-all), add:

```dart
              GoRoute(
                path: 'locations',
                name: 'manageEquipmentLocations',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const EquipmentLocationListPage(),
                routes: [
                  GoRoute(
                    path: ':locationId',
                    name: 'equipmentLocationDetail',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => EquipmentLocationDetailPage(
                      locationId: state.pathParameters['locationId']!,
                    ),
                  ),
                ],
              ),
```

In `settings_page.dart`, after the Service types tile and its `Divider`:

```dart
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(context.l10n.settings_manage_locations),
                  subtitle: Text(
                    context.l10n.settings_manage_locations_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/equipment/locations'),
                ),
                const Divider(height: 1),
```

Add a stub `GoRoute(path: 'locations', ...)` to `settings_page_test.dart`'s router beside the `service-types` stub.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/equipment/presentation/pages/equipment_location_list_page_test.dart test/features/settings/presentation/pages/settings_page_test.dart test/core/router > "$SCRATCH/manage.log" 2>&1; tail -20 "$SCRATCH/manage.log"`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib test
git add lib/core/router lib/features/equipment lib/features/settings lib/l10n test/features
git commit -m "feat(equipment): Settings > Manage > Locations"
```

---

### Task 13: CSV export column and import

**Files:**
- Modify: `lib/core/services/export/csv/csv_equipment_writer.dart`
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (`exportEquipmentToCsv` ~83, `generateEquipmentCsvContent` ~217, `saveEquipmentCsvToFile` ~287)
- Modify: `lib/core/services/export/export_service.dart` (~107, ~146, ~188)
- Modify: `lib/features/settings/presentation/providers/export_providers.dart` (`exportEquipmentToCsv` ~299, `saveEquipmentCsvToFile` ~1251, new `_equipmentLocationNamesFor`)
- Modify: `lib/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart` (~167-186)
- Create: `lib/features/dive_import/data/services/import_equipment_location_linker.dart`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (repositories bag ~140; after the tag linker ~559)
- Modify: `lib/features/import_wizard/data/adapters/universal_adapter.dart` (~2052)
- Test: `test/core/services/export/csv/csv_equipment_writer_location_test.dart`
- Test: `test/features/dive_import/data/services/import_equipment_location_linker_test.dart`

**Interfaces:**
- Consumes: Task 4 `findOrCreateByName`, `recordMoves`, `getCurrentLocationIds`.
- Produces: `CsvEquipmentWriter.write(..., Map<String, String> locationNames = const {})`; item map key `'locationName'`; `ImportEquipmentLocationLinker({required EquipmentLocationRepository places, required EquipmentLocationMoveRepository moves})` with `Future<void> link({required List<Map<String, dynamic>> items, required Map<String, String> equipmentIdMapping, required String? diverId})`.

- [ ] **Step 1: Write the failing writer test**

```dart
import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  test('Location follows Tags and holds the current place name', () {
    final csv = CsvEquipmentWriter(CsvExportUnits.metric).write(
      [
        EquipmentItem(id: 'reg', name: 'Reg', type: EquipmentType.regulator),
        EquipmentItem(id: 'bcd', name: 'BCD', type: EquipmentType.bcd),
      ],
      locationNames: {'reg': '=Garage'},
    );
    final rows = const CsvToListConverter().convert(csv);
    final header = rows.first.cast<String>();
    final col = header.indexOf('Location');
    expect(col, header.indexOf('Tags') + 1);
    // Formula-looking names are neutralised like every free-text cell.
    expect(rows[1][col], isNot('=Garage'));
    expect(rows[2][col], '');
  });
}
```

- [ ] **Step 2: Write the failing linker test**

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/import_equipment_location_linker.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ImportEquipmentLocationLinker linker;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.into(db.divers).insert(
      DiversCompanion.insert(id: 'me', name: 'me', createdAt: 1, updatedAt: 1),
    );
    for (final id in ['reg', 'bcd']) {
      await db.into(db.equipment).insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          createdAt: 1,
          updatedAt: 1,
          diverId: const Value('me'),
        ),
      );
    }
    linker = ImportEquipmentLocationLinker(
      places: EquipmentLocationRepository(),
      moves: EquipmentLocationMoveRepository(),
    );
  });

  tearDown(tearDownTestDatabase);

  test('matches or creates the place and records one move', () async {
    await EquipmentLocationRepository().createLocation(
      diverId: 'me',
      name: 'Garage',
      kind: EquipmentLocationKind.storage,
    );
    await linker.link(
      items: [
        {'uddfId': 'a', 'name': 'reg', 'locationName': 'garage'},
        {'uddfId': 'b', 'name': 'bcd', 'locationName': 'Boat locker'},
      ],
      equipmentIdMapping: {'a': 'reg', 'b': 'bcd'},
      diverId: 'me',
    );
    final places = await EquipmentLocationRepository().getLocations(diverId: 'me');
    expect(places.map((p) => p.name), unorderedEquals(['Garage', 'Boat locker']));
    final current = await EquipmentLocationMoveRepository().getCurrentLocationIds();
    expect(current.keys, unorderedEquals(['reg', 'bcd']));
  });

  test('re-import onto an item already there writes no move', () async {
    final items = [
      {'uddfId': 'a', 'name': 'reg', 'locationName': 'Garage'},
    ];
    await linker.link(items: items, equipmentIdMapping: {'a': 'reg'}, diverId: 'me');
    await linker.link(items: items, equipmentIdMapping: {'a': 'reg'}, diverId: 'me');
    expect(await EquipmentLocationMoveRepository().getMovesFor('reg'), hasLength(1));
  });
}
```

- [ ] **Step 3: Run both to verify they fail**

Run: `flutter test test/core/services/export/csv/csv_equipment_writer_location_test.dart test/features/dive_import/data/services/import_equipment_location_linker_test.dart`
Expected: compile errors.

- [ ] **Step 4: Implement the export**

In `CsvEquipmentWriter.write`, add `Map<String, String> locationNames = const {},`; add `'Location',` after `'Tags',` in the header, and after the tags cell:

```dart
        sanitizeCsvField(locationNames[item.id]),
```

Thread `Map<String, String> locationNames = const {}` through `CsvExportService.exportEquipmentToCsv`, `generateEquipmentCsvContent`, `saveEquipmentCsvToFile`, and the three `ExportService` methods, passing it down exactly as `tagNames` is passed. In `export_providers.dart`, add beside `_equipmentTagNamesFor`:

```dart
  /// Each item's current place name, for the equipment CSV's Location
  /// column. Items with no location are absent.
  Future<Map<String, String>> _equipmentLocationNamesFor(
    List<EquipmentItem> equipment,
  ) async {
    final current = await _ref.read(currentEquipmentLocationsProvider.future);
    return {
      for (final item in equipment)
        if (current[item.id] case final place?) item.id: place.name,
    };
  }
```

and pass `locationNames: await _equipmentLocationNamesFor(equipment),` in both `exportEquipmentToCsv` and `saveEquipmentCsvToFile`.

- [ ] **Step 5: Implement the import**

In the CSV parser, after `final tagRefs = ...`:

```dart
      final locationName = table.text(row, 'Location');
```

and in the item map, after the `tagRefs` entry:

```dart
          if (locationName != null && locationName.trim().isNotEmpty)
            'locationName': locationName.trim(),
```

`lib/features/dive_import/data/services/import_equipment_location_linker.dart`:

```dart
import 'package:submersion/features/dive_import/data/services/import_equipment_tag_linker.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_move_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_location_repository.dart';

/// Records imported equipment's location (v267). Each item map's
/// `locationName` resolves to one of the diver's places by name, ignoring
/// case (an active place first, then an archived one), or a new place of
/// kind other; the item gets one move there, dated now. An item already at
/// that place gets none, so re-importing a file adds no history. Keyed like
/// [ImportEquipmentTagLinker].
class ImportEquipmentLocationLinker {
  const ImportEquipmentLocationLinker({required this.places, required this.moves});

  final EquipmentLocationRepository places;
  final EquipmentLocationMoveRepository moves;

  Future<void> link({
    required List<Map<String, dynamic>> items,
    required Map<String, String> equipmentIdMapping,
    required String? diverId,
  }) async {
    final idlessNameCounts =
        ImportEquipmentTagLinker.countIdlessEquipmentNames(items);
    final current = await moves.getCurrentLocationIds();
    final resolved = <String, String>{};
    final now = DateTime.now();
    for (final data in items) {
      final name = data['locationName'];
      if (name is! String || name.trim().isEmpty) continue;
      final uddfId = data['uddfId'] as String?;
      final itemName = data['name'] as String?;
      final key = uddfId ?? (idlessNameCounts[itemName] == 1 ? itemName : null);
      final equipmentId = key == null ? null : equipmentIdMapping[key];
      if (equipmentId == null) continue;
      final lower = name.trim().toLowerCase();
      final placeId = resolved[lower] ??=
          (await places.findOrCreateByName(diverId: diverId, name: name)).id;
      if (current[equipmentId] == placeId) continue;
      await moves.recordMoves(
        equipmentIds: [equipmentId],
        locationId: placeId,
        movedAt: now,
      );
      current[equipmentId] = placeId;
    }
  }
}
```

In `uddf_entity_importer.dart`, add to the repositories bag beside `equipmentTagRepository`:

```dart
  final EquipmentLocationRepository? equipmentLocationRepository;
  final EquipmentLocationMoveRepository? equipmentLocationMoveRepository;
```

(constructor parameters optional, defaulting to null), and after the tag linker block:

```dart
    // Equipment locations (v267), from the Submersion equipment CSV.
    final locationRepository = repositories.equipmentLocationRepository;
    final moveRepository = repositories.equipmentLocationMoveRepository;
    if (locationRepository != null && moveRepository != null) {
      await ImportEquipmentLocationLinker(
        places: locationRepository,
        moves: moveRepository,
      ).link(
        items: data.equipment,
        equipmentIdMapping: equipmentIdMapping,
        diverId: diverId,
      );
    }
```

In `universal_adapter.dart` beside `equipmentTagRepository: ref.read(equipmentTagRepositoryProvider),` add:

```dart
    equipmentLocationRepository: ref.read(equipmentLocationRepositoryProvider),
    equipmentLocationMoveRepository: ref.read(
      equipmentLocationMoveRepositoryProvider,
    ),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/core/services/export test/features/dive_import test/features/universal_import test/features/settings/presentation/providers > "$SCRATCH/csv.log" 2>&1; tail -30 "$SCRATCH/csv.log"`
Expected: PASS. A CSV test pinning the exact header list needs `'Location'` after `'Tags'`; a round-trip test that writes then parses the CSV should now carry `locationName`.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add lib/core/services/export lib/features test
git commit -m "feat(equipment): equipment CSV carries the current location both ways"
```

---

### Task 14: Translations

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

- [ ] **Step 1: List the new keys**

Run: `git diff origin/main -- lib/l10n/arb/app_en.arb | grep -E '^\+  "[a-z]' | grep -v '"@' | sed -E 's/^\+  "([^"]+)".*/\1/'`
Expected: every key added in Tasks 3 and 7 to 12.

- [ ] **Step 2: Translate into all 10 locales**

For each locale ARB, insert each key (and no `@` metadata, matching each locale file's convention; check one existing key in `app_de.arb` to confirm) beside the same neighbouring key used in `app_en.arb`. Keep ICU plural structure: `one{...}`/`other{...}` with the `{count}` placeholder in every branch (never a hardcoded digit: CLDR `one` covers 0 in fr and pt). Add the extra CLDR categories a locale needs (`ar`: zero, one, two, few, many, other; `he`: one, two, other where the existing ARB does; follow how `app_ar.arb` writes a neighbouring plural such as an existing `{count, plural, ...}` key).

- [ ] **Step 3: Generate and verify**

Run: `flutter gen-l10n`
Run: `grep -A1 "get equipment_location_card_title" lib/l10n/arb/app_localizations_de.dart`
Expected: the German text, not "Location".
Run: `git diff --numstat lib/l10n/arb/ | sort`
Expected: every locale ARB changed by the same number of added lines (an uneven count means a locale was missed).
Run: `flutter test test/l10n > "$SCRATCH/l10n.log" 2>&1; tail -10 "$SCRATCH/l10n.log"` (if `test/l10n` exists; it holds the ICU plural guards).
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n
git commit -m "i18n(equipment): translate equipment locations into all locales"
```

---

### Task 15: Whole-branch verification

- [ ] **Step 1: Format and analyze**

Run: `dart format . && flutter analyze > "$SCRATCH/analyze.log" 2>&1; tail -5 "$SCRATCH/analyze.log"`
Expected: `No issues found!` (infos are fatal in CI).

- [ ] **Step 2: Guards**

Run: `flutter test test/architecture test/shared > "$SCRATCH/guards.log" 2>&1; tail -10 "$SCRATCH/guards.log"`
Expected: PASS.

- [ ] **Step 3: Affected suites**

Run: `flutter test test/features/equipment test/features/divers test/core/database test/core/services/sync test/core/services/export test/features/dive_import test/features/settings > "$SCRATCH/affected.log" 2>&1; tail -10 "$SCRATCH/affected.log"`
Expected: PASS. Check `df -h /Volumes/fltmp` first if a run hangs.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A lib test
git commit -m "fix(equipment): address verification findings"
```

(Only if Steps 1 to 3 required changes; stage explicit paths, never sibling worktree files.)
