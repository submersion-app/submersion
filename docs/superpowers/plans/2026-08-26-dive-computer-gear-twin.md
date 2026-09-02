# Dive Computer Gear Twin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A dive computer that downloaded a dive appears as a piece of equipment on that dive.

**Architecture:** A nullable `dive_computers.equipment_id` bridges the device registry to a real `equipment` row of type `computer` (its "gear twin"). The twin is created exactly once, at computer registration, at a deterministic UUID v5 id so a synced fleet converges on one row. A link-only service then attaches that twin to each dive at the non-interactive creation seams. A v175 migration backfills existing logbooks.

**Tech Stack:** Flutter, Dart, Drift ORM, SQLite, Riverpod, `uuid` package.

**Spec:** `docs/superpowers/specs/2026-08-26-dive-computer-gear-twin-design.md`

> **Schema number, after the fact:** the shipped claim is **v175**. The Goal,
> Architecture and Global Constraints above state that, because they describe
> what was built. The numbered task steps below still say v169, and are left
> that way deliberately: they record the instructions as they were executed,
> and rewriting snippets that were accurate when written would misrepresent
> the history. The code and the design doc are the authority on the shipped
> number.

## Global Constraints

- **Schema version is v175.** It moved twice: v168 to v169 when #1237 was renumbered onto v168 mid-implementation, then v169 to v175 when main was merged in on 2026-08-27 after #1322 (v170) and others landed. Do NOT pick a number from the open-PR diff scan alone; it cannot see unpushed renumbers or local-only worktree claims, so scan every worktree's `currentSchemaVersion` as well.
- **`minimumCompatibleSchemaVersion` stays at 160.** The rule at `database.dart:3211` says not to raise it for a new nullable column.
- **Never use em-dashes (U+2014)** in any output: code, comments, docs, commit messages. En-dashes as prose punctuation and spaced hyphens are equally forbidden. Use commas, colons, semicolons, or two sentences.
- **No emojis** in code, comments, or documentation.
- **TDD.** Write the failing test first, watch it fail, then implement.
- **Immutability.** Never mutate objects or arrays in place.
- **Run `dart format .`** from the repo root after completing any task.
- **Never pipe `flutter test` into `grep`.** The pipeline returns grep's exit status, so a failing suite reports success. Run the bare command.
- **Do not run two `flutter test` invocations at once.** Overlapping local runs produce phantom single-file failures.
- **All 11 locales** must be translated for any new string: `ar de en es fr he hu it nl pt zh` in `lib/l10n/arb/`.
- **Working directory** is `/Users/ericgriffin/repos/submersion-app/worktree-dive-computer-gear-twin` for every command.

---

## File Structure

**Create:**
- `lib/core/database/dive_computer_gear_identity.dart` (~85 lines) - pure Dart: the frozen namespace, the deterministic id, the candidate struct, the match rule. No database import, so both the repository and the migration can use it.
- `lib/core/database/dive_computer_gear_backfill.dart` (~140 lines) - the v169 two-pass backfill over a bare `DatabaseConnectionUser`.
- `lib/features/equipment/data/services/dive_computer_gear_resolver.dart` (~110 lines) - runtime find-or-create.
- `lib/features/equipment/data/services/dive_computer_gear_linker.dart` (~70 lines) - link-only, per dive.

**Modify:**
- `lib/core/database/database.dart` - column, scalar, ladder entry, onUpgrade step, assert helper, beforeOpen backstop.
- `lib/core/database/imported_computer_backfill.dart` - mint a twin where a computer row was genuinely inserted.
- `lib/core/services/sync/sync_service.dart` - `parentRefs` entry (required, see Task 2).
- `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` - resolver hook in `createComputer`, linker at the new-dive seam and the existing-dive tail.
- `lib/features/dive_import/data/services/uddf_entity_importer.dart`, `lib/features/dive_import/presentation/providers/dive_import_providers.dart`, `lib/features/import_wizard/data/adapters/healthkit_adapter.dart` - linker calls.
- `lib/core/buoyancy/gear_feature.dart` - `computer` cases.
- `lib/features/dive_log/presentation/pages/dive_computer_detail_page.dart` (exact path confirmed in Task 9) - linked gear row.
- `lib/l10n/arb/app_*.arb` - one new string, 11 locales.

**Two files rather than one for the identity/backfill split** because the migration runs against a bare `DatabaseConnectionUser` with no `DatabaseService`, exactly as `imported_computer_backfill.dart` does. The shared rule lives in the identity module so the runtime path and the migration cannot drift apart. This mirrors the `imported_computer_identity.dart` / `imported_computer_backfill.dart` pair added by #1297.

---

## Task 1: Gear twin identity module

Pure Dart, no database. Two consumers (the runtime resolver in Task 3, the migration in Task 6) must apply an identical rule.

**Files:**
- Create: `lib/core/database/dive_computer_gear_identity.dart`
- Test: `test/core/database/dive_computer_gear_identity_test.dart`

**Interfaces:**
- Consumes: `normalizeComputerIdentityPart(String?)` from `lib/core/database/imported_computer_identity.dart`.
- Produces:
  - `const String kDiveComputerGearNamespace`
  - `String diveComputerGearId(String computerId)`
  - `class GearTwinCandidate` with `final String id; final String? diverId; final String? brand; final String? model; final String? serialNumber;` and a `const` constructor taking `{required String id, String? diverId, String? brand, String? model, String? serialNumber}`
  - `GearTwinCandidate? matchGearTwin({required String? manufacturer, required String? model, required String? serialNumber, required String? diverId, required Iterable<GearTwinCandidate> candidates})`

- [ ] **Step 1: Write the failing test**

Create `test/core/database/dive_computer_gear_identity_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/dive_computer_gear_identity.dart';

GearTwinCandidate candidate(
  String id, {
  String? diverId,
  String? brand,
  String? model,
  String? serialNumber,
}) => GearTwinCandidate(
  id: id,
  diverId: diverId,
  brand: brand,
  model: model,
  serialNumber: serialNumber,
);

void main() {
  group('diveComputerGearId', () {
    test('is stable for the same computer id', () {
      expect(diveComputerGearId('comp-1'), diveComputerGearId('comp-1'));
    });

    test('differs between computers', () {
      expect(
        diveComputerGearId('comp-1'),
        isNot(diveComputerGearId('comp-2')),
      );
    });

    test('is a v5 uuid, so every device derives the same primary key', () {
      // Version nibble of a v5 uuid is the first character of group three.
      expect(diveComputerGearId('comp-1').split('-')[2][0], '5');
    });
  });

  group('matchGearTwin', () {
    test('matches on serial when the computer has one', () {
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: 'ABC123',
        diverId: 'd1',
        candidates: [
          candidate('gear-1', diverId: 'd1', serialNumber: 'abc123'),
          candidate('gear-2', diverId: 'd1', serialNumber: 'ZZZ999'),
        ],
      );
      expect(match?.id, 'gear-1');
    });

    test('falls back to brand and model when the serial is null', () {
      // libdivecomputer leaves the serial null for many devices (#1064), so a
      // serial-only rule would be dead for a large share of users.
      final match = matchGearTwin(
        manufacturer: '  SHEARWATER ',
        model: 'Perdix   2',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate('gear-1', diverId: 'd1', brand: 'Shearwater', model: 'Perdix 2'),
        ],
      );
      expect(match?.id, 'gear-1');
    });

    test('returns null when two candidates match, rather than guessing', () {
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate('gear-1', diverId: 'd1', brand: 'Shearwater', model: 'Perdix 2'),
          candidate('gear-2', diverId: 'd1', brand: 'Shearwater', model: 'Perdix 2'),
        ],
      );
      expect(match, isNull);
    });

    test('returns null when nothing matches', () {
      final match = matchGearTwin(
        manufacturer: 'Suunto',
        model: 'EON Core',
        serialNumber: null,
        diverId: 'd1',
        candidates: [
          candidate('gear-1', diverId: 'd1', brand: 'Shearwater', model: 'Perdix 2'),
        ],
      );
      expect(match, isNull);
    });

    test('never crosses diver scopes', () {
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: 'ABC123',
        diverId: 'd1',
        candidates: [
          candidate('gear-1', diverId: 'd2', serialNumber: 'ABC123'),
        ],
      );
      expect(match, isNull);
    });

    test('matches null-diver candidates to a null-diver computer', () {
      final match = matchGearTwin(
        manufacturer: 'Shearwater',
        model: 'Perdix 2',
        serialNumber: 'ABC123',
        diverId: null,
        candidates: [candidate('gear-1', serialNumber: 'ABC123')],
      );
      expect(match?.id, 'gear-1');
    });

    test('returns null when the computer has neither serial nor model', () {
      final match = matchGearTwin(
        manufacturer: null,
        model: null,
        serialNumber: null,
        diverId: 'd1',
        candidates: [candidate('gear-1', diverId: 'd1')],
      );
      expect(match, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/dive_computer_gear_identity_test.dart`
Expected: FAIL, compile error, `dive_computer_gear_identity.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/core/database/dive_computer_gear_identity.dart`:

```dart
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/imported_computer_identity.dart';

/// Namespace for deterministic gear-twin ids (v169).
///
/// Frozen: every device must derive the same equipment id for the same
/// registered computer, so changing this would fork one gear item into one per
/// device across a synced fleet.
const String kDiveComputerGearNamespace =
    '9f2b6c41-7d3e-4a58-9c0f-1e5a8d47b2c6';

/// The id of the equipment row representing [computerId] as gear.
///
/// Derived from the registry id, which is stable and synced, rather than from
/// model or serial text, which a user can rename. A minted row cannot use v4:
/// two devices registering the same computer would mint different primary keys
/// and duplicate instead of merging under sync upsert.
String diveComputerGearId(String computerId) => const Uuid().v5(
  kDiveComputerGearNamespace,
  'submersion:dive-computer-gear:$computerId',
);

/// An equipment row reduced to the fields the gear-twin match needs.
///
/// Lets the rule live in one place: the repository builds these from Drift
/// rows, the v169 migration backfill from raw rows.
class GearTwinCandidate {
  const GearTwinCandidate({
    required this.id,
    this.diverId,
    this.brand,
    this.model,
    this.serialNumber,
  });

  final String id;
  final String? diverId;
  final String? brand;
  final String? model;
  final String? serialNumber;
}

/// The existing gear item that already represents this computer, if exactly
/// one does.
///
/// Callers pass only candidates that are active equipment of type `computer`.
///
/// The serial is the strong signal, but libdivecomputer leaves it null for many
/// devices (#1064), so a serial-only rule would be dead for a large share of
/// users. With no serial the rule falls back to brand plus model.
///
/// Returns null when zero or several candidates match. Guessing between two
/// identical computers is worse than minting a second row: a wrong adoption
/// silently attaches one device's service history to another device's dives.
GearTwinCandidate? matchGearTwin({
  required String? manufacturer,
  required String? model,
  required String? serialNumber,
  required String? diverId,
  required Iterable<GearTwinCandidate> candidates,
}) {
  final wantDiver = normalizeComputerIdentityPart(diverId);
  final wantSerial = normalizeComputerIdentityPart(serialNumber);
  final wantBrand = normalizeComputerIdentityPart(manufacturer);
  final wantModel = normalizeComputerIdentityPart(model);

  // With no serial and no model there is no identity to match on, and every
  // blank-identity gear item would collide.
  if (wantSerial.isEmpty && wantModel.isEmpty) return null;

  final matches = candidates.where((c) {
    if (normalizeComputerIdentityPart(c.diverId) != wantDiver) return false;
    if (wantSerial.isNotEmpty) {
      return normalizeComputerIdentityPart(c.serialNumber) == wantSerial;
    }
    return normalizeComputerIdentityPart(c.brand) == wantBrand &&
        normalizeComputerIdentityPart(c.model) == wantModel;
  }).toList();

  return matches.length == 1 ? matches.first : null;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/database/dive_computer_gear_identity_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/database/dive_computer_gear_identity.dart test/core/database/dive_computer_gear_identity_test.dart
git commit -m "feat(equipment): deterministic gear-twin identity for dive computers"
```

---

## Task 2: Schema column, sync parent ref, and the v169 ladder rung

Column only. The backfill lands in Task 6, once the resolver exists.

**Files:**
- Modify: `lib/core/database/database.dart`
- Modify: `lib/core/services/sync/sync_service.dart` (`parentRefs`, near `:2042`)
- Test: `test/core/database/migration_v169_dive_computer_gear_test.dart`

**Interfaces:**
- Produces: the `dive_computers.equipment_id` column; `AppDatabase.currentSchemaVersion == 168`; `_assertDiveComputerEquipmentColumn()`.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/migration_v169_dive_computer_gear_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v169 adds `dive_computers.equipment_id`: the equipment row that represents a
/// registered computer as gear, so a downloaded dive lists the computer that
/// logged it alongside the rest of the diver's kit. Nullable with no default,
/// because a cleared value means the user deleted that gear item and it must
/// not come back.
NativeDatabase _dbAt168() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 168');
      rawDb.execute('''
        CREATE TABLE dive_computers (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          manufacturer TEXT,
          model TEXT,
          serial_number TEXT,
          dive_count INTEGER NOT NULL DEFAULT 0,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          notes TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute(
        "INSERT INTO dive_computers (id, name, created_at, updated_at) "
        "VALUES ('c1', 'My Perdix', 1, 1)",
      );
    },
  );
}

void main() {
  test('v169 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(169));
    expect(AppDatabase.migrationVersions, contains(169));
  });

  test('a fresh database has dive_computers.equipment_id', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_computers')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('equipment_id'));
  });

  test('the column is nullable and carries no default', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_computers')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'equipment_id',
    );
    // A non-null default would claim every registered computer already has a
    // gear item, and would resurrect one the user deleted.
    expect(column.read<int>('notnull'), 0);
    expect(column.read<String?>('dflt_value'), isNull);
  });

  test('a database at v168 gains the column and keeps its rows', () async {
    final db = AppDatabase(_dbAt168());
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT name, equipment_id FROM dive_computers WHERE id = 'c1'")
        .getSingle();
    expect(row.read<String>('name'), 'My Perdix');
    expect(row.read<String?>('equipment_id'), isNull);
  });

  test('a database stranded at a parallel-branch v169 gains the column via '
      'beforeOpen', () async {
    // Stamped AT 168 but without the column: the onUpgrade block never runs,
    // so only the beforeOpen backstop can add it.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 168');
        rawDb.execute('''
          CREATE TABLE dive_computers (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            manufacturer TEXT,
            model TEXT,
            serial_number TEXT,
            dive_count INTEGER NOT NULL DEFAULT 0,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_computers')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('equipment_id'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v169_dive_computer_gear_test.dart`
Expected: FAIL, `currentSchemaVersion` is 164 and `equipment_id` is absent.

- [ ] **Step 3: Add the column to the table class**

In `lib/core/database/database.dart`, inside `class DiveComputers extends Table`, immediately after the `hlc` column and before the `@override Set<Column> get primaryKey` block:

```dart
  /// The equipment row representing this device as gear, its "gear twin"
  /// (v169). Seeded once at registration, then owned by the user: renaming or
  /// retiring the gear item never writes back here, and renaming the computer
  /// never overwrites the gear name.
  ///
  /// Unlike [bluetoothAddress] this DOES synchronize, because equipment ids are
  /// fleet-stable and a peer holding a null here would dangle the reference.
  ///
  /// setNull rather than cascade: deleting the gear item leaves the device
  /// registered. The cleared column is also what makes that deletion permanent,
  /// because only a genuine computer insert ever mints a twin.
  TextColumn get equipmentId => text().nullable().references(
    Equipment,
    #id,
    onDelete: KeyAction.setNull,
  )();
```

- [ ] **Step 4: Bump the scalar and add the ladder entry**

Change `static const int currentSchemaVersion = 164;` to `= 168;`.

Leave `minimumCompatibleSchemaVersion` at 160: the rule beside it says not to raise it for a new nullable column.

Append to the end of the `migrationVersions` list, matching the surrounding comment style:

```dart
  // v169 (gear twins): dive_computers.equipment_id, the equipment row that
  // represents a registered computer as gear, so a downloaded dive lists the
  // computer that logged it alongside the rest of the diver's kit. The ladder
  // is monotonic and unique but NOT contiguous: 162 is permanently skipped and
  // 165 through 167 were claimed by parallel branches. Do not "fix" that.
  168,
```

- [ ] **Step 5: Add the assert helper**

Add near the other `_assert*Column` helpers in `lib/core/database/database.dart`:

```dart
  /// v169: dive_computers.equipment_id (gear twins). Idempotent; safe to call
  /// from both onUpgrade and the beforeOpen backstop. Nullable with no default,
  /// because a null means "this computer has no gear item", which is also what
  /// a user deleting the gear item leaves behind.
  Future<void> _assertDiveComputerEquipmentColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('dive_computers')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('equipment_id')) {
      await customStatement(
        'ALTER TABLE dive_computers ADD COLUMN equipment_id TEXT',
      );
    }
  }
```

- [ ] **Step 6: Add the onUpgrade rung**

At the end of the `onUpgrade` ladder, after the existing `if (from < 164)` block and its `reportProgress()` twin:

```dart
      if (from < 169) {
        await _assertDiveComputerEquipmentColumn();
      }
      if (from < 169) await reportProgress();
```

- [ ] **Step 7: Add the beforeOpen backstop**

Beside the other version backstops in `beforeOpen`:

```dart
        // v169 backstop: re-assert dive_computers.equipment_id (gear twins;
        // same parallel-branch version-collision self-heal). Column only:
        // backfillDiveComputerGearTwins is a full-table pass that belongs to
        // the ladder, and re-running it on every open would resurrect a gear
        // item the user deleted.
        await _assertDiveComputerEquipmentColumn();
```

- [ ] **Step 8: Register the sync parent ref**

This is REQUIRED, not optional. `sync_parent_refs_completeness_test.dart` guards `SyncService.parentRefs` against the live schema: an FK to a deletable parent that is not registered lets a peer's live child dangle against a locally deleted parent, failing the deferred-FK COMMIT with `SqliteException(787)` and aborting the entire sync.

In `lib/core/services/sync/sync_service.dart`, add to the `parentRefs` map:

```dart
    'diveComputers': [
      (field: 'equipmentId', parent: 'equipment', nullable: true),
    ],
```

No serializer change is needed: `diveComputers` round-trips through Drift's `row.toJson()` and `DiveComputer.fromJson`, so the new column flows automatically. The only hand-maintained exception is the `bluetoothAddress` strip, which does not apply here.

- [ ] **Step 9: Run both tests to verify they pass**

Run: `flutter test test/core/database/migration_v169_dive_computer_gear_test.dart`
Expected: PASS, 5 tests.

Run: `flutter test test/core/services/sync/sync_parent_refs_completeness_test.dart`
Expected: PASS.

- [ ] **Step 10: Regenerate Drift code, format, and commit**

```bash
dart run build_runner build --delete-conflicting-outputs
dart format .
git add lib/core/database/database.dart lib/core/database/database.g.dart lib/core/services/sync/sync_service.dart test/core/database/migration_v169_dive_computer_gear_test.dart
git commit -m "feat(db): add dive_computers.equipment_id gear-twin bridge at v169"
```

---

## Task 3: Gear twin resolver, wired into computer registration

**Files:**
- Create: `lib/features/equipment/data/services/dive_computer_gear_resolver.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (`createComputer`)
- Test: `test/features/equipment/data/services/dive_computer_gear_resolver_test.dart`

**Interfaces:**
- Consumes: `diveComputerGearId`, `GearTwinCandidate`, `matchGearTwin` from Task 1.
- Produces: `class DiveComputerGearResolver` with `Future<String?> resolveGearTwin(domain.DiveComputer computer)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/data/services/dive_computer_gear_resolver_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide DiveComputer;
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_resolver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveComputerGearResolver resolver;

  setUp(() async {
    db = await setUpTestDatabase();
    // Junction and equipment writes without full Diver fixtures.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    resolver = DiveComputerGearResolver();
  });
  tearDown(tearDownTestDatabase);

  DiveComputer computer({
    String id = 'c1',
    String? diverId = 'd1',
    String name = 'My Perdix',
    String? manufacturer = 'Shearwater',
    String? model = 'Perdix 2',
    String? serialNumber,
    String? equipmentId,
  }) => DiveComputer(
    id: id,
    diverId: diverId,
    name: name,
    manufacturer: manufacturer,
    model: model,
    serialNumber: serialNumber,
    equipmentId: equipmentId,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Future<void> insertGear(
    String id, {
    String? diverId = 'd1',
    String type = 'computer',
    String? brand,
    String? model,
    String? serialNumber,
    bool isActive = true,
  }) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            diverId: Value(diverId),
            name: id,
            type: type,
            brand: Value(brand),
            model: Value(model),
            serialNumber: Value(serialNumber),
            isActive: Value(isActive),
            createdAt: t,
            updatedAt: t,
          ),
        );
  }

  test('mints a twin at the deterministic id when nothing matches', () async {
    final id = await resolver.resolveGearTwin(computer());

    expect(id, diveComputerGearId('c1'));
    final row = await (db.select(
      db.equipment,
    )..where((t) => t.id.equals(id!))).getSingle();
    expect(row.type, 'computer');
    expect(row.name, 'My Perdix');
    expect(row.brand, 'Shearwater');
    expect(row.model, 'Perdix 2');
    // Seeded once, then owned by the user: service fields stay theirs to set.
    expect(row.purchaseDate, isNull);
    expect(row.serviceIntervalDays, isNull);
  });

  test('returns the stored link when its equipment row still exists', () async {
    await insertGear('hand-made');

    final id = await resolver.resolveGearTwin(
      computer(equipmentId: 'hand-made'),
    );

    expect(id, 'hand-made');
  });

  test('mints when the stored link points at a deleted row', () async {
    final id = await resolver.resolveGearTwin(computer(equipmentId: 'gone'));

    expect(id, diveComputerGearId('c1'));
  });

  test('adopts the row holding the derived id after a rename', () async {
    // The identity match reads the row's CURRENT text while the id derives
    // from the computer id, so renaming makes the match miss while the id
    // still collides. Without this branch the insert throws
    // SqliteException(1555) UNIQUE constraint failed.
    await insertGear(
      diveComputerGearId('c1'),
      brand: 'Totally',
      model: 'Renamed',
    );

    final id = await resolver.resolveGearTwin(computer());

    expect(id, diveComputerGearId('c1'));
    final count = await db.customSelect('SELECT COUNT(*) AS c FROM equipment').getSingle();
    expect(count.read<int>('c'), 1);
  });

  test('adopts an unambiguous hand-created gear item', () async {
    await insertGear('hand-made', brand: 'Shearwater', model: 'Perdix 2');

    final id = await resolver.resolveGearTwin(computer());

    expect(id, 'hand-made');
  });

  test('mints rather than guessing between two identical candidates', () async {
    await insertGear('one', brand: 'Shearwater', model: 'Perdix 2');
    await insertGear('two', brand: 'Shearwater', model: 'Perdix 2');

    final id = await resolver.resolveGearTwin(computer());

    expect(id, diveComputerGearId('c1'));
  });

  test('ignores retired gear and non-computer gear when matching', () async {
    await insertGear('retired', brand: 'Shearwater', model: 'Perdix 2', isActive: false);
    await insertGear('a-bcd', type: 'bcd', brand: 'Shearwater', model: 'Perdix 2');

    final id = await resolver.resolveGearTwin(computer());

    expect(id, diveComputerGearId('c1'));
  });

  test('is idempotent across repeated calls', () async {
    final first = await resolver.resolveGearTwin(computer());
    final second = await resolver.resolveGearTwin(computer());

    expect(first, second);
    final count = await db.customSelect('SELECT COUNT(*) AS c FROM equipment').getSingle();
    expect(count.read<int>('c'), 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/data/services/dive_computer_gear_resolver_test.dart`
Expected: FAIL, compile error, `dive_computer_gear_resolver.dart` does not exist and `DiveComputer` has no `equipmentId` field.

- [ ] **Step 3: Add `equipmentId` to the DiveComputer entity**

In `lib/features/dive_log/domain/entities/dive_computer.dart`, add the field, the constructor parameter, the `copyWith` parameter and assignment, and the `props` entry, matching how `serialNumber` is threaded through. The doc comment:

```dart
  /// The equipment row representing this device as gear (v169). Null when the
  /// user has deleted that gear item, which is permanent: only a genuine
  /// computer registration mints a twin.
  final String? equipmentId;
```

Also add `equipmentId: row.equipmentId` to `_mapRowToComputer` in `dive_computer_repository_impl.dart` so reads carry it.

- [ ] **Step 4: Write the resolver**

Create `lib/features/equipment/data/services/dive_computer_gear_resolver.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

/// Resolves the equipment row that represents a registered dive computer as
/// gear, creating one if the diver does not already have a suitable item.
///
/// Called only where a `dive_computers` row is genuinely created. That single
/// rule is what makes deleting a gear twin permanent: nothing else mints, so a
/// cleared `dive_computers.equipment_id` stays cleared.
class DiveComputerGearResolver {
  DiveComputerGearResolver({SyncRepository? syncRepository})
    : _syncRepository = syncRepository ?? SyncRepository();

  final SyncRepository _syncRepository;
  final _log = LoggerService.forClass(DiveComputerGearResolver);

  AppDatabase get _db => DatabaseService.instance.database;

  /// The equipment id representing [computer], minting one when needed.
  ///
  /// Resolution order, which is the design:
  ///   1. the stored link, when its equipment row still exists
  ///   2. the row already holding the derived id, which survives a rename
  ///   3. exactly one unambiguous identity match among active computer gear
  ///   4. mint at the derived id
  ///
  /// Returns null and logs on failure. A computer that fails to get a twin is
  /// still a correctly registered computer, so registration must not fail
  /// because gear seeding did.
  Future<String?> resolveGearTwin(domain.DiveComputer computer) async {
    try {
      final stored = computer.equipmentId;
      if (stored != null && stored.isNotEmpty) {
        final existing = await (_db.select(
          _db.equipment,
        )..where((t) => t.id.equals(stored))).getSingleOrNull();
        if (existing != null) return stored;
      }

      final derivedId = diveComputerGearId(computer.id);

      // Step 2. The identity match below reads each row's CURRENT text while
      // the id derives from the computer id, so a renamed gear item makes the
      // match miss while the id still collides. Adopt the row holding it
      // rather than letting the insert throw SqliteException(1555).
      final byDerivedId = await (_db.select(
        _db.equipment,
      )..where((t) => t.id.equals(derivedId))).getSingleOrNull();
      if (byDerivedId != null) return derivedId;

      final rows =
          await (_db.select(_db.equipment)
                ..where((t) => t.type.equals(EquipmentType.computer.name))
                ..where((t) => t.isActive.equals(true)))
              .get();
      final match = matchGearTwin(
        manufacturer: computer.manufacturer,
        model: computer.model,
        serialNumber: computer.serialNumber,
        diverId: computer.diverId,
        candidates: rows.map(
          (r) => GearTwinCandidate(
            id: r.id,
            diverId: r.diverId,
            brand: r.brand,
            model: r.model,
            serialNumber: r.serialNumber,
          ),
        ),
      );
      if (match != null) return match.id;

      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.equipment)
          .insertOnConflictUpdate(
            EquipmentCompanion.insert(
              id: derivedId,
              diverId: Value(computer.diverId),
              name: computer.name,
              type: EquipmentType.computer.name,
              brand: Value(computer.manufacturer),
              model: Value(computer.model),
              serialNumber: Value(computer.serialNumber),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: 'equipment',
        recordId: derivedId,
        localUpdatedAt: now,
      );
      return derivedId;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to resolve a gear twin for computer ${computer.id}',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/equipment/data/services/dive_computer_gear_resolver_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 6: Wire the resolver into `createComputer`**

In `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`, inside `createComputer`, immediately before the existing `_relinkOrphanedRows(...)` call:

```dart
      // Seed the gear twin once, here, because this is the only repository
      // path that genuinely inserts a registry row. Minting nowhere else is
      // what makes a user-deleted twin permanent.
      final twinId = await DiveComputerGearResolver().resolveGearTwin(computer);
      if (twinId != null) {
        await _db.customStatement(
          'UPDATE dive_computers SET equipment_id = ? WHERE id = ?',
          [twinId, computer.id],
        );
        await _syncRepository.markRecordPending(
          entityType: 'diveComputers',
          recordId: computer.id,
          localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }
```

Add the import:

```dart
import 'package:submersion/features/equipment/data/services/dive_computer_gear_resolver.dart';
```

- [ ] **Step 7: Run the dive computer repository tests**

Run: `flutter test test/features/dive_log/data/repositories/`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): seed a gear twin when a dive computer is registered"
```

---

## Task 4: The link-only linker and the four creation seams

**Files:**
- Create: `lib/features/equipment/data/services/dive_computer_gear_linker.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart` (the trio at the new-dive branch)
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart`
- Modify: `lib/features/dive_import/presentation/providers/dive_import_providers.dart`
- Modify: `lib/features/import_wizard/data/adapters/healthkit_adapter.dart`
- Test: `test/features/equipment/data/services/dive_computer_gear_linker_test.dart`

**Interfaces:**
- Consumes: `DiveComputerRepository.getComputerIdsForDive(String diveId)`, `DiveRepository.bulkAddEquipment(List<String>, List<String>)`.
- Produces: `class DiveComputerGearLinker` with `Future<bool> linkComputerGearForDive({required String diveId})`.

Note the signature takes no `diverId`. The twin is read off the computer row, and `_updateExistingDive` does not pass a `diverId` down to `importProfile`, so requiring one would block Task 5.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/data/services/dive_computer_gear_linker_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveComputerGearLinker linker;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    linker = DiveComputerGearLinker();
  });
  tearDown(tearDownTestDatabase);

  Future<void> insertGear(String id) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: id,
        name: id,
        type: 'computer',
        createdAt: t,
        updatedAt: t,
      ),
    );
  }

  Future<void> insertComputer(String id, {String? equipmentId}) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.diveComputers).insert(
      DiveComputersCompanion.insert(
        id: id,
        name: id,
        equipmentId: Value(equipmentId),
        createdAt: t,
        updatedAt: t,
      ),
    );
  }

  Future<void> linkSource(String diveId, String computerId) async {
    await db.customStatement(
      'INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, '
      'created_at) VALUES (?, ?, ?, 1, 1)',
      ['src-$computerId', diveId, computerId],
    );
  }

  Future<Set<String>> equipmentOn(String diveId) async {
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    return rows.map((r) => r.equipmentId).toSet();
  }

  test('attaches the gear twin of the computer that logged the dive', () async {
    await insertGear('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await linkSource('dive1', 'c1');

    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isTrue);
    expect(await equipmentOn('dive1'), {'gear-1'});
  });

  test('attaches every computer on a multi-source dive', () async {
    // dives.computer_id holds only the primary; a twin-computer diver must get
    // both, which is why the linker reads dive_data_sources.
    await insertGear('gear-1');
    await insertGear('gear-2');
    await insertComputer('c1', equipmentId: 'gear-1');
    await insertComputer('c2', equipmentId: 'gear-2');
    await linkSource('dive1', 'c1');
    await linkSource('dive1', 'c2');

    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isTrue);
    expect(await equipmentOn('dive1'), {'gear-1', 'gear-2'});
  });

  test('adds to existing equipment rather than replacing it', () async {
    // Unlike the defaulter, the linker is not gated on the dive being empty.
    await insertGear('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await linkSource('dive1', 'c1');
    await db.into(db.diveEquipment).insert(
      DiveEquipmentCompanion.insert(diveId: 'dive1', equipmentId: 'a-bcd'),
    );

    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isTrue);
    expect(await equipmentOn('dive1'), {'a-bcd', 'gear-1'});
  });

  test('never creates equipment for a computer whose twin was deleted', () async {
    await insertComputer('c1');
    await linkSource('dive1', 'c1');

    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isFalse);
    expect(await equipmentOn('dive1'), isEmpty);
    final count = await db.customSelect('SELECT COUNT(*) AS c FROM equipment').getSingle();
    expect(count.read<int>('c'), 0);
  });

  test('is a no-op for a dive with no registered computer', () async {
    expect(await linker.linkComputerGearForDive(diveId: 'dive1'), isFalse);
    expect(await equipmentOn('dive1'), isEmpty);
  });

  test('is idempotent', () async {
    await insertGear('gear-1');
    await insertComputer('c1', equipmentId: 'gear-1');
    await linkSource('dive1', 'c1');

    await linker.linkComputerGearForDive(diveId: 'dive1');
    await linker.linkComputerGearForDive(diveId: 'dive1');

    expect(await equipmentOn('dive1'), {'gear-1'});
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/data/services/dive_computer_gear_linker_test.dart`
Expected: FAIL, compile error, `dive_computer_gear_linker.dart` does not exist.

- [ ] **Step 3: Write the linker**

Create `lib/features/equipment/data/services/dive_computer_gear_linker.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

/// Attaches the gear twins of the dive computers that logged a dive.
///
/// Used by the non-interactive creation seams (dive-computer download, file
/// import), alongside [DiveEquipmentDefaulter], [ChecklistDiveLinker] and
/// [DiveAltitudeEnricher].
///
/// Link-only: it never creates an equipment row. Creation happens once, at
/// computer registration, so a twin the user deleted (which clears
/// `dive_computers.equipment_id`) simply produces no link and stays deleted.
class DiveComputerGearLinker {
  DiveComputerGearLinker({
    DiveComputerRepository? computerRepository,
    DiveRepository? diveRepository,
  }) : _computers = computerRepository ?? DiveComputerRepository(),
       _dives = diveRepository ?? DiveRepository();

  final DiveComputerRepository _computers;
  final DiveRepository _dives;

  AppDatabase get _db => DatabaseService.instance.database;

  /// Returns true when at least one twin was attached.
  ///
  /// MUST run after [DiveEquipmentDefaulter] at every seam: the defaulter bails
  /// when the dive already has any `dive_equipment` row, so linking first would
  /// silently suppress the diver's default and geofenced equipment sets.
  ///
  /// Unlike the defaulter this is NOT gated on the dive being empty: the
  /// computer belongs on the dive whether or not a set already applied.
  ///
  /// Best-effort: any failure is swallowed so equipment linking can never abort
  /// a download or import that has already persisted the dive.
  Future<bool> linkComputerGearForDive({required String diveId}) async {
    if (DatabaseService.instance.databaseOrNull == null) return false;
    try {
      // Reads dive_data_sources, not dives.computer_id, which holds only the
      // primary: a dive logged on two computers must list both.
      final computerIds = await _computers.getComputerIdsForDive(diveId);
      if (computerIds.isEmpty) return false;

      final rows = await (_db.select(
        _db.diveComputers,
      )..where((t) => t.id.isIn(computerIds))).get();
      final equipmentIds = rows
          .map((r) => r.equipmentId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (equipmentIds.isEmpty) return false;

      await _dives.bulkAddEquipment([diveId], equipmentIds);
      SyncEventBus.notifyLocalChange();
      return true;
    } catch (_) {
      // Best-effort: never let gear linking fail the dive operation.
      return false;
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/data/services/dive_computer_gear_linker_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Write the ordering regression test**

This is the trap the design exists to avoid. Create `test/features/equipment/data/services/gear_twin_defaulter_ordering_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide EquipmentSet;
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

import '../../../../helpers/test_database.dart';

/// The defaulter bails when the dive already has any dive_equipment row, so
/// running the gear linker FIRST would silently suppress the diver's default
/// and geofenced equipment sets. A downloaded dive must receive both.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['a-bcd', 'gear-1']) {
      await db.into(db.equipment).insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: id == 'gear-1' ? 'computer' : 'bcd',
          createdAt: t,
          updatedAt: t,
        ),
      );
    }
    await db.into(db.diveComputers).insert(
      DiveComputersCompanion.insert(
        id: 'c1',
        name: 'c1',
        equipmentId: const Value('gear-1'),
        createdAt: t,
        updatedAt: t,
      ),
    );
    await db.customStatement(
      "INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, "
      "created_at) VALUES ('s1', 'dive1', 'c1', 1, 1)",
    );
    final sets = EquipmentSetRepository();
    await sets.createSet(
      EquipmentSet(
        id: 'def',
        diverId: 'd1',
        name: 'def',
        equipmentIds: const ['a-bcd'],
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await sets.setAsDefault('def', diverId: 'd1');
  });
  tearDown(tearDownTestDatabase);

  test('defaulter first, then linker: the dive gets BOTH', () async {
    await DiveEquipmentDefaulter().applyDefaultEquipmentIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );
    await DiveComputerGearLinker().linkComputerGearForDive(diveId: 'dive1');

    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals('dive1'))).get();
    expect(rows.map((r) => r.equipmentId).toSet(), {'a-bcd', 'gear-1'});
  });

  test('linker first would suppress the default set, proving the order', () async {
    await DiveComputerGearLinker().linkComputerGearForDive(diveId: 'dive1');
    final applied = await DiveEquipmentDefaulter().applyDefaultEquipmentIfEmpty(
      diveId: 'dive1',
      diverId: 'd1',
      divePoints: const [],
    );

    expect(applied, isFalse);
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals('dive1'))).get();
    expect(rows.map((r) => r.equipmentId).toSet(), {'gear-1'});
  });
}
```

- [ ] **Step 6: Run the ordering test**

Run: `flutter test test/features/equipment/data/services/gear_twin_defaulter_ordering_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 7: Wire the linker into all four seams**

At each of the four sites, add the linker call **after** the `DiveEquipmentDefaulter` call and its siblings. Add the import
`import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';`
to each file.

In `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`, after the defaulter call in the new-dive branch:

```dart
        // After the defaulter, never before: the defaulter bails on a dive
        // that already has equipment, so linking first would suppress the
        // diver's default and geofenced sets.
        await DiveComputerGearLinker().linkComputerGearForDive(diveId: diveId);
```

In `lib/features/dive_import/data/services/uddf_entity_importer.dart`, `lib/features/dive_import/presentation/providers/dive_import_providers.dart`, and `lib/features/import_wizard/data/adapters/healthkit_adapter.dart`, after each `applyForImportedDive(...)` call:

```dart
      await DiveComputerGearLinker().linkComputerGearForDive(diveId: dive.id);
```

The HealthKit site is a deliberate no-op: an Apple Watch dive has no registry computer, so `getComputerIdsForDive` returns empty. It is included so the seam set stays uniform and a future HealthKit registry entry works without a code change.

- [ ] **Step 8: Run the affected suites**

Run: `flutter test test/features/dive_log/ test/features/dive_import/ test/features/equipment/`
Expected: PASS.

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): attach dive computer gear twins at the import seams"
```

---

## Task 5: Link on the replaceSource path

A re-download that replaces a source on an existing dive takes `importProfile`'s `isNewDive == false` branch, so the trio never runs. That computer did log that dive.

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_computer_repository_impl.dart`
- Test: `test/features/dive_log/data/repositories/replace_source_gear_link_test.dart`

**Interfaces:**
- Consumes: `DiveComputerGearLinker.linkComputerGearForDive` from Task 4.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/replace_source_gear_link_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// A replaceSource re-download matches an existing dive, so importProfile takes
/// the isNewDive == false branch and the creation-seam trio never runs. The
/// computer still logged the dive, so its gear twin belongs on it.
void main() {
  late AppDatabase db;
  late DiveComputerRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repo = DiveComputerRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.equipment).insert(
      EquipmentCompanion.insert(
        id: 'gear-1',
        name: 'gear-1',
        type: 'computer',
        createdAt: t,
        updatedAt: t,
      ),
    );
    await db.into(db.diveComputers).insert(
      DiveComputersCompanion.insert(
        id: 'c1',
        name: 'c1',
        equipmentId: const Value('gear-1'),
        createdAt: t,
        updatedAt: t,
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  test('re-importing onto an existing dive links the gear twin', () async {
    final start = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    // First import creates the dive.
    final diveId = await repo.importProfile(
      computerId: 'c1',
      profileStartTime: start,
      points: const [],
      durationSeconds: 1800,
      maxDepth: 30.0,
    );

    // Remove the link so the second pass has something to prove.
    await (db.delete(db.diveEquipment)..where((t) => t.diveId.equals(diveId))).go();
    await repo.clearSourceAndProfiles(diveId: diveId, computerId: 'c1');

    // Second import matches the same dive: the isNewDive == false branch.
    final again = await repo.importProfile(
      computerId: 'c1',
      profileStartTime: start,
      points: const [],
      durationSeconds: 1800,
      maxDepth: 30.0,
    );

    expect(again, diveId);
    final rows = await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(rows.map((r) => r.equipmentId).toSet(), contains('gear-1'));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/replace_source_gear_link_test.dart`
Expected: FAIL, the `dive_equipment` set is empty.

- [ ] **Step 3: Add the linker call to the existing-dive tail**

In `importProfile`, inside the existing `if (!isNewDive) { ... }` block that writes the gradient factors and marks the dive pending, after the `markRecordPending` call:

```dart
        // The data source row was re-created above, so the linker can see this
        // computer again. clearSourceAndProfiles deleted it on the way in.
        // Idempotent through insertOnConflictUpdate.
        await DiveComputerGearLinker().linkComputerGearForDive(diveId: diveId);
```

The import is already present from Task 4.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/replace_source_gear_link_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): link the gear twin when a dive source is replaced"
```

---

## Task 6: The v169 backfill

**Files:**
- Create: `lib/core/database/dive_computer_gear_backfill.dart`
- Modify: `lib/core/database/database.dart` (call it from the `if (from < 169)` block)
- Test: `test/core/database/dive_computer_gear_backfill_test.dart`

**Interfaces:**
- Consumes: `diveComputerGearId`, `GearTwinCandidate`, `matchGearTwin` from Task 1.
- Produces: `Future<void> backfillDiveComputerGearTwins(DatabaseConnectionUser db)`.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/dive_computer_gear_backfill_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';

/// The v169 backfill mints a gear twin per registered computer and links it to
/// every dive that computer logged. Fixture is stamped at 168 so the ladder
/// runs the real migration.
NativeDatabase _seeded() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 168');
      rawDb.execute('''
        CREATE TABLE dive_computers (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          manufacturer TEXT,
          model TEXT,
          serial_number TEXT,
          dive_count INTEGER NOT NULL DEFAULT 0,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          notes TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          computer_id TEXT,
          dive_date_time INTEGER NOT NULL DEFAULT 0
        )
      ''');
      rawDb.execute('''
        CREATE TABLE dive_data_sources (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          computer_id TEXT,
          is_primary INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT 0
        )
      ''');
      rawDb.execute('''
        CREATE TABLE dive_equipment (
          dive_id TEXT NOT NULL,
          equipment_id TEXT NOT NULL,
          PRIMARY KEY (dive_id, equipment_id)
        )
      ''');
      rawDb.execute('''
        CREATE TABLE equipment (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          brand TEXT,
          model TEXT,
          serial_number TEXT,
          status TEXT NOT NULL DEFAULT 'active',
          purchase_currency TEXT NOT NULL DEFAULT 'USD',
          notes TEXT NOT NULL DEFAULT '',
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      rawDb.execute(
        "INSERT INTO dive_computers (id, diver_id, name, manufacturer, model, "
        "created_at, updated_at) VALUES "
        "('c1', 'd1', 'My Perdix', 'Shearwater', 'Perdix 2', 1, 1)",
      );
      rawDb.execute(
        "INSERT INTO dive_computers (id, diver_id, name, manufacturer, model, "
        "created_at, updated_at) VALUES "
        "('c2', 'd1', 'My NERD', 'Shearwater', 'NERD 2', 1, 1)",
      );
      // dive1: primary c1 only. dive2: two sources, c1 primary and c2.
      rawDb.execute("INSERT INTO dives (id, diver_id, computer_id) VALUES ('dive1', 'd1', 'c1')");
      rawDb.execute("INSERT INTO dives (id, diver_id, computer_id) VALUES ('dive2', 'd1', 'c1')");
      rawDb.execute("INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, created_at) VALUES ('s1', 'dive1', 'c1', 1, 1)");
      rawDb.execute("INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, created_at) VALUES ('s2', 'dive2', 'c1', 1, 1)");
      rawDb.execute("INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, created_at) VALUES ('s3', 'dive2', 'c2', 0, 1)");
    },
  );
}

Future<Set<String>> _equipmentOn(AppDatabase db, String diveId) async {
  final rows = await db
      .customSelect("SELECT equipment_id FROM dive_equipment WHERE dive_id = '$diveId'")
      .get();
  return rows.map((r) => r.read<String>('equipment_id')).toSet();
}

void main() {
  test('mints a twin per computer and links its dives', () async {
    final db = AppDatabase(_seeded());
    addTearDown(db.close);

    final c1Twin = diveComputerGearId('c1');
    final c2Twin = diveComputerGearId('c2');

    final computers = await db
        .customSelect('SELECT id, equipment_id FROM dive_computers ORDER BY id')
        .get();
    expect(computers[0].read<String?>('equipment_id'), c1Twin);
    expect(computers[1].read<String?>('equipment_id'), c2Twin);

    expect(await _equipmentOn(db, 'dive1'), {c1Twin});
    // A multi-source dive gets BOTH computers: dives.computer_id holds only
    // the primary, so the union with dive_data_sources is what catches c2.
    expect(await _equipmentOn(db, 'dive2'), {c1Twin, c2Twin});
  });

  test('minted twins are computer-type gear carrying the device identity', () async {
    final db = AppDatabase(_seeded());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT name, type, brand, model FROM equipment WHERE id = '${diveComputerGearId('c1')}'",
        )
        .getSingle();
    expect(row.read<String>('type'), 'computer');
    expect(row.read<String>('name'), 'My Perdix');
    expect(row.read<String>('brand'), 'Shearwater');
    expect(row.read<String>('model'), 'Perdix 2');
  });

  test('is idempotent across a second open', () async {
    final native = _seeded();
    final first = AppDatabase(native);
    await first.customSelect('SELECT 1').get();
    await first.close();

    final db = AppDatabase(native);
    addTearDown(db.close);
    final count = await db.customSelect('SELECT COUNT(*) AS c FROM equipment').getSingle();
    expect(count.read<int>('c'), 2);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/dive_computer_gear_backfill_test.dart`
Expected: FAIL, `equipment_id` is null and `dive_equipment` is empty.

- [ ] **Step 3: Write the backfill**

Create `lib/core/database/dive_computer_gear_backfill.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/dive_computer_gear_identity.dart';

/// Seed a gear twin for every registered dive computer and link it to the
/// dives that computer logged (v169).
///
/// Ladder-only, never a beforeOpen backstop, for two independent reasons:
/// it is a full-table pass over every dive, and re-running it on every open
/// would resurrect a gear item the user deleted. That is the same rule
/// `_backfillLegacyServiceSchedules` and `_backfillBottomTimeFromProfile`
/// follow.
///
/// New rows land on a deterministic id ([diveComputerGearId]), so every device
/// in a synced fleet derives the same primary key and they converge under sync
/// upsert rather than duplicating.
Future<void> backfillDiveComputerGearTwins(DatabaseConnectionUser db) async {
  // PRAGMA-guarded like every other backfill helper: the ladder runs against
  // minimal fixtures and against databases caught mid-upgrade. PRAGMA
  // table_info returns empty for a missing table, so probing columns covers
  // both "table absent" and "column absent".
  Future<Set<String>> columnsOf(String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((c) => c.read<String>('name')).toSet();
  }

  final computerCols = await columnsOf('dive_computers');
  if (!computerCols.containsAll({
    'id',
    'diver_id',
    'name',
    'manufacturer',
    'model',
    'serial_number',
    'equipment_id',
  })) {
    return;
  }
  final equipmentCols = await columnsOf('equipment');
  if (!equipmentCols.containsAll({
    'id',
    'diver_id',
    'name',
    'type',
    'brand',
    'model',
    'serial_number',
    'is_active',
    'created_at',
    'updated_at',
  })) {
    return;
  }
  final junctionCols = await columnsOf('dive_equipment');
  if (!junctionCols.containsAll({'dive_id', 'equipment_id'})) return;

  // Pass 1: resolve a twin per computer. Bounded by device count, a handful of
  // rows, so no event-loop yield is needed here.
  final computers = await db
      .customSelect(
        'SELECT id, diver_id, name, manufacturer, model, serial_number '
        'FROM dive_computers WHERE equipment_id IS NULL ORDER BY id',
      )
      .get();

  for (final computer in computers) {
    final id = computer.read<String>('id');
    final diverId = computer.read<String?>('diver_id');
    final name = computer.read<String>('name');
    final manufacturer = computer.read<String?>('manufacturer');
    final model = computer.read<String?>('model');
    final serial = computer.read<String?>('serial_number');

    final derivedId = diveComputerGearId(id);

    // Adopt the row already holding the derived id before matching on text:
    // the match reads each row's CURRENT text while the id derives from the
    // computer id, so a renamed gear item makes the match miss while the id
    // still collides.
    final byDerivedId = await db
        .customSelect(
          'SELECT id FROM equipment WHERE id = ?',
          variables: [Variable<String>(derivedId)],
        )
        .getSingleOrNull();

    var twinId = byDerivedId?.read<String>('id');

    if (twinId == null) {
      final candidateRows = await db
          .customSelect(
            "SELECT id, diver_id, brand, model, serial_number FROM equipment "
            "WHERE type = 'computer' AND is_active = 1 ORDER BY updated_at DESC, id",
          )
          .get();
      twinId = matchGearTwin(
        manufacturer: manufacturer,
        model: model,
        serialNumber: serial,
        diverId: diverId,
        candidates: candidateRows.map(
          (r) => GearTwinCandidate(
            id: r.read<String>('id'),
            diverId: r.read<String?>('diver_id'),
            brand: r.read<String?>('brand'),
            model: r.read<String?>('model'),
            serialNumber: r.read<String?>('serial_number'),
          ),
        ),
      )?.id;
    }

    if (twinId == null) {
      twinId = derivedId;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT OR IGNORE INTO equipment '
        '(id, diver_id, name, type, brand, model, serial_number, status, '
        "purchase_currency, notes, is_active, created_at, updated_at) "
        "VALUES (?, ?, ?, 'computer', ?, ?, ?, 'active', 'USD', '', 1, ?, ?)",
        [twinId, diverId, name, manufacturer, model, serial, now, now],
      );
    }

    await db.customStatement(
      'UPDATE dive_computers SET equipment_id = ? WHERE id = ?',
      [twinId, id],
    );
  }

  // Pass 2: link the dives. Set-based, so it needs no per-dive loop and no
  // event-loop yield: a per-dive loop during a migration runs as one unbroken
  // microtask chain and freezes the progress spinner.
  //
  // dives.computer_id holds only the PRIMARY computer, so it is unioned with
  // dive_data_sources: a dive logged on two computers must list both.
  final diveCols = await columnsOf('dives');
  if (diveCols.contains('computer_id')) {
    await db.customStatement('''
      INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id)
      SELECT d.id, c.equipment_id
        FROM dives d
        JOIN dive_computers c ON c.id = d.computer_id
       WHERE c.equipment_id IS NOT NULL
    ''');
  }

  final sourceCols = await columnsOf('dive_data_sources');
  if (sourceCols.containsAll({'dive_id', 'computer_id'})) {
    await db.customStatement('''
      INSERT OR IGNORE INTO dive_equipment (dive_id, equipment_id)
      SELECT s.dive_id, c.equipment_id
        FROM dive_data_sources s
        JOIN dive_computers c ON c.id = s.computer_id
       WHERE c.equipment_id IS NOT NULL
    ''');
  }
}
```

- [ ] **Step 4: Call it from the ladder**

In `lib/core/database/database.dart`, add the import:

```dart
import 'package:submersion/core/database/dive_computer_gear_backfill.dart';
```

and extend the `if (from < 169)` block from Task 2 so it reads:

```dart
      if (from < 169) {
        await _assertDiveComputerEquipmentColumn();
        await backfillDiveComputerGearTwins(this);
      }
      if (from < 169) await reportProgress();
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/core/database/dive_computer_gear_backfill_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Re-run the v169 column test to confirm no regression**

Run: `flutter test test/core/database/migration_v169_dive_computer_gear_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(db): backfill dive computer gear twins at v169"
```

---

## Task 7: Mint a twin from the imported-computer self-heal

`imported_computer_backfill.dart` registers computers with a raw `INSERT OR IGNORE`, bypassing `createComputer` and therefore Task 3's hook. Mint there too, but only where the row was genuinely inserted, so a user-deleted twin cannot come back on the next app open.

**Files:**
- Modify: `lib/core/database/imported_computer_backfill.dart`
- Test: `test/core/database/imported_computer_gear_twin_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/database/imported_computer_gear_twin_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';

/// The #1288 self-heal registers computers named by file-imported dives with a
/// raw INSERT OR IGNORE, so it needs its own gear-twin mint. It must mint ONLY
/// where the computer row was genuinely inserted, or a user who deleted the
/// gear item would get it back on the next app open.
void main() {
  test('the heal mints a twin and does not re-mint a deleted one', () async {
    // Build the database, seed a file-imported dive, then reopen so beforeOpen
    // runs the heal against it.
    final native = NativeDatabase.memory();
    final first = AppDatabase(native);
    final t = DateTime.now().millisecondsSinceEpoch;
    await first.customStatement(
      "INSERT INTO dives (id, diver_id, dive_computer_model, dive_date_time, "
      "created_at, updated_at) VALUES ('dive1', 'd1', 'Perdix 2', 1, ?, ?)",
      [t, t],
    );
    await first.close();

    final second = AppDatabase(native);
    final registered = await second
        .customSelect('SELECT id, equipment_id FROM dive_computers')
        .get();
    expect(registered, hasLength(1));
    final computerId = registered.single.read<String>('id');
    final twinId = registered.single.read<String?>('equipment_id');
    expect(twinId, diveComputerGearId(computerId));

    // The user deletes the gear item. setNull clears the link.
    await second.customStatement('DELETE FROM equipment WHERE id = ?', [twinId]);
    await second.customStatement(
      'UPDATE dive_computers SET equipment_id = NULL WHERE id = ?',
      [computerId],
    );
    await second.close();

    // Reopen: the heal must NOT resurrect it, because the computer row already
    // exists and INSERT OR IGNORE changes nothing.
    final third = AppDatabase(native);
    addTearDown(third.close);
    final after = await third
        .customSelect('SELECT COUNT(*) AS c FROM equipment')
        .getSingle();
    expect(after.read<int>('c'), 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/imported_computer_gear_twin_test.dart`
Expected: FAIL, `equipment_id` is null after the heal registers the computer.

- [ ] **Step 3: Mint the twin where the insert actually inserted**

In `lib/core/database/imported_computer_backfill.dart`, add the import:

```dart
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
```

and immediately after the existing `INSERT OR IGNORE INTO dive_computers` statement, before the `candidates = await _candidates(db);` re-read:

```dart
      // Seed the gear twin, but ONLY when that insert actually inserted. If
      // INSERT OR IGNORE no-opped because the computer already exists, the
      // user may have deleted its gear item deliberately, and re-minting here
      // would resurrect it on every app open.
      final inserted = await db
          .customSelect('SELECT changes() AS changed')
          .getSingle();
      if (inserted.read<int>('changed') > 0) {
        final twinId = diveComputerGearId(computerId);
        await db.customStatement(
          'INSERT OR IGNORE INTO equipment '
          '(id, diver_id, name, type, brand, model, serial_number, status, '
          "purchase_currency, notes, is_active, created_at, updated_at) "
          "VALUES (?, ?, ?, 'computer', NULL, ?, ?, 'active', 'USD', '', 1, ?, ?)",
          [
            twinId,
            diverId,
            trimmedModel,
            trimmedModel,
            (trimmedSerial?.isEmpty ?? true) ? null : trimmedSerial,
            now,
            now,
          ],
        );
        await db.customStatement(
          'UPDATE dive_computers SET equipment_id = ? WHERE id = ?',
          [twinId, computerId],
        );
      }
```

Guard the whole block behind an `equipment_id` column probe at the top of `backfillImportedDiveComputers`, alongside the existing guards, so an old fixture without the v169 column skips it:

```dart
  final hasGearColumn = computerCols.contains('equipment_id');
```

and wrap the mint in `if (hasGearColumn) { ... }`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/database/imported_computer_gear_twin_test.dart`
Expected: PASS.

- [ ] **Step 5: Re-run the existing imported-computer suite**

Run: `flutter test test/core/database/`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(db): seed gear twins from the imported-computer self-heal"
```

---

## Task 8: Keep dive computers out of the buoyancy dry mass

**Files:**
- Modify: `lib/core/buoyancy/gear_feature.dart`
- Test: `test/core/buoyancy/gear_feature_test.dart` (add cases to the existing file; create it if absent)

- [ ] **Step 1: Write the failing test**

Add to `test/core/buoyancy/gear_feature_test.dart`:

```dart
  group('dive computers', () {
    test('contribute no dry mass', () {
      // Gear twins (v169) put a computer on every downloaded dive. The
      // _typeDryMass fallthrough of 0.5 kg would silently move every diver's
      // rig by that much per computer.
      final feature = GearFeature.fromEquipment(
        id: 'gear-1',
        type: EquipmentType.computer,
        name: 'Perdix 2',
      );
      expect(feature.dryMassKg, 0.0);
    });

    test('contribute no buoyancy prior', () {
      final feature = GearFeature.fromEquipment(
        id: 'gear-1',
        type: EquipmentType.computer,
        name: 'Perdix 2',
      );
      expect(feature.priorKg, 0.0);
    });

    test('still honour an explicit user dry weight', () {
      // A canister light or bulky console is real mass; the attribute path
      // stays live.
      final feature = GearFeature.fromEquipment(
        id: 'gear-1',
        type: EquipmentType.computer,
        name: 'Console',
        weightKg: 1.2,
      );
      expect(feature.dryMassKg, 1.2);
    });
  });
```

Add the imports the file needs if it is new:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/constants/enums.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/buoyancy/gear_feature_test.dart`
Expected: FAIL on the first case, `dryMassKg` is 0.5.

- [ ] **Step 3: Add the explicit cases**

In `lib/core/buoyancy/gear_feature.dart`:

```dart
  static double _typeDefault(EquipmentType type) => switch (type) {
    EquipmentType.wetsuit => 4.0,
    EquipmentType.drysuit => 10.0,
    EquipmentType.bcd => -0.5,
    EquipmentType.hood => 0.3,
    EquipmentType.gloves => 0.2,
    EquipmentType.boots => 0.4,
    // Stated rather than left to the fallthrough, which already returns 0.0:
    // gear twins (v169) make this a case readers will look for.
    EquipmentType.computer => 0.0,
    _ => 0.0,
  };

  static double _typeDryMass(EquipmentType type) => switch (type) {
    EquipmentType.wetsuit => 2.0,
    EquipmentType.drysuit => 3.0,
    EquipmentType.bcd => 3.5,
    // A wrist computer's dry mass is negligible against the rig, and gear
    // twins (v169) put one on every downloaded dive: the 0.5 kg fallthrough
    // would move every diver's buoyancy by that much per computer. An explicit
    // dry_weight_kg attribute still wins, so a bulky console can be modeled.
    EquipmentType.computer => 0.0,
    _ => 0.5,
  };
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/buoyancy/gear_feature_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the buoyancy and weight planner suites**

Run: `flutter test test/core/buoyancy/ test/features/weight_planner/`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "fix(buoyancy): dive computers contribute no dry mass"
```

---

## Task 9: Show the linked gear item on the dive computer detail page

The only place that explains where the new equipment came from.

**Files:**
- Modify: `lib/features/dive_computer/presentation/pages/device_detail_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` plus the 10 other locales
- Test: `test/features/dive_computer/presentation/pages/device_detail_page_gear_twin_test.dart`

**Interfaces:**
- Consumes: `equipmentItemProvider` (`FutureProvider.family<EquipmentItem?, String>`) from `lib/features/equipment/presentation/providers/equipment_providers.dart:167`; `DiveComputer.equipmentId` from Task 3.

The page's info card is built by a method with no `WidgetRef` in scope, so the row is a small private `ConsumerWidget` rather than another `_buildInfoRow` call.

- [ ] **Step 1: Add the string to the English ARB**

In `lib/l10n/arb/app_en.arb`:

```json
  "diveComputer_detail_linkedGear": "Gear item",
  "@diveComputer_detail_linkedGear": {
    "description": "Label for the equipment item that represents this dive computer in the diver's gear list"
  },
```

- [ ] **Step 2: Translate into all 10 remaining locales**

Add the same key to `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`. Do NOT copy the English string: translate it. Omit the `@` metadata block in non-template files, matching the existing convention in those files.

- [ ] **Step 3: Regenerate localizations**

```bash
flutter gen-l10n
```

- [ ] **Step 4: Write the failing widget test**

Create `test/features/dive_computer/presentation/pages/device_detail_page_gear_twin_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DiveComputer _computer({String? equipmentId}) => DiveComputer(
  id: 'comp-1',
  name: 'My Perdix',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
  equipmentId: equipmentId,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

EquipmentItem _gear() => EquipmentItem(
  id: 'gear-1',
  name: 'Perdix 2 (wrist)',
  type: EquipmentType.computer,
);

Widget _buildTestWidget({
  required DiveComputer computer,
  EquipmentItem? gear,
}) {
  final router = GoRouter(
    initialLocation: '/dive-computers/comp-1',
    routes: [
      GoRoute(
        path: '/dive-computers/:id',
        builder: (context, state) =>
            DeviceDetailPage(computerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (context, state) =>
            const Scaffold(body: Text('EQUIPMENT_DETAIL_PAGE')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      diveComputerNotifierProvider.overrideWith(
        (ref) => _MockDiveComputerNotifier(),
      ),
      diveComputerByIdProvider('comp-1').overrideWith((ref) async => computer),
      equipmentItemProvider('gear-1').overrideWith((ref) async => gear),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    ),
  );
}

void main() {
  testWidgets('shows the linked gear item', (tester) async {
    await tester.pumpWidget(
      _buildTestWidget(computer: _computer(equipmentId: 'gear-1'), gear: _gear()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perdix 2 (wrist)'), findsOneWidget);
  });

  testWidgets('taps through to the equipment detail page', (tester) async {
    await tester.pumpWidget(
      _buildTestWidget(computer: _computer(equipmentId: 'gear-1'), gear: _gear()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perdix 2 (wrist)'));
    await tester.pumpAndSettle();

    expect(find.text('EQUIPMENT_DETAIL_PAGE'), findsOneWidget);
  });

  testWidgets('shows no gear row when the twin was deleted', (tester) async {
    // A null equipmentId is what deleting the gear item leaves behind, and it
    // is permanent: nothing re-mints outside a genuine registration.
    await tester.pumpWidget(_buildTestWidget(computer: _computer()));
    await tester.pumpAndSettle();

    expect(find.text('Perdix 2 (wrist)'), findsNothing);
  });

  testWidgets('shows no gear row when the equipment row is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestWidget(computer: _computer(equipmentId: 'gear-1'), gear: null),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perdix 2 (wrist)'), findsNothing);
  });
}
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/features/dive_computer/presentation/pages/device_detail_page_gear_twin_test.dart`
Expected: FAIL, the gear name is not rendered.

- [ ] **Step 6: Add the row widget**

In `lib/features/dive_computer/presentation/pages/device_detail_page.dart`, add these imports:

```dart
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
```

and add the widget at the bottom of the file:

```dart
/// The equipment row representing this device as gear, its gear twin (v169).
///
/// Absent when the computer has no `equipmentId`, which is what deleting the
/// gear item leaves behind and is permanent by design: only a genuine
/// registration mints a twin.
class _LinkedGearRow extends ConsumerWidget {
  const _LinkedGearRow({required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = ref.watch(equipmentItemProvider(equipmentId)).valueOrNull;
    if (item == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => context.push('/equipment/$equipmentId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.diveComputer_detail_linkedGear,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name, style: theme.textTheme.bodyMedium),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Render it in the info card**

In the info card's `Column`, immediately after the connection `_buildInfoRow(...)` call:

```dart
            if (computer.equipmentId != null)
              _LinkedGearRow(equipmentId: computer.equipmentId!),
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/features/dive_computer/presentation/pages/device_detail_page_gear_twin_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 9: Run the existing device detail tests for regressions**

Run: `flutter test test/features/dive_computer/presentation/pages/`
Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(ui): show a dive computer's linked gear item on its detail page"
```

---

## Task 10: Whole-project verification

- [ ] **Step 1: Format the whole project**

```bash
dart format .
```

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: no issues. Infos are fatal in CI, so treat any output as a failure. Do not pipe this into `grep`.

- [ ] **Step 3: Verify the generated l10n hub is current**

```bash
flutter gen-l10n
git diff --stat lib/l10n/
```
Expected: no unstaged changes. CI regenerates codegen but never verifies it, so a stale hub only surfaces at runtime.

- [ ] **Step 4: Verify Drift codegen is current**

```bash
dart run build_runner build --delete-conflicting-outputs
git diff --stat lib/core/database/
```
Expected: no unstaged changes.

- [ ] **Step 5: Run the full test suite ONCE**

Run: `flutter test`
Expected: PASS.

One run is sufficient before opening a PR. Do not start a second run while this one is going: overlapping local runs produce phantom single-file failures. If a single file fails, re-run that file alone before believing it.

- [ ] **Step 6: Confirm the schema claim is still free**

```bash
for n in $(gh pr list --state open --json number --jq '.[].number'); do gh pr diff $n | grep -E '^\+\s*static const int currentSchemaVersion'; done
```
Expected: no other open PR claims 169. If one does, renumber, remembering the claim touches six places: the scalar, the `migrationVersions` entry, the assert helper docstring, the `if (from < N)` guard and its `reportProgress` twin, the `beforeOpen` backstop comment, and the migration test filename with its `greaterThanOrEqualTo` and `contains` assertions.

- [ ] **Step 7: Commit any formatting or codegen drift**

```bash
git add -A
git commit -m "chore: format and regenerate after gear twin work"
```

---

## Deviations from the spec, and why

Recorded so a reviewer comparing the two documents does not think something was missed.

1. **D9's serializer change is not in this plan, because there is nothing to change.** `diveComputers` round-trips through Drift's `row.toJson()` and `DiveComputer.fromJson`; there is no hand-maintained field list. The new column flows automatically. What the spec did not know it needed is the `parentRefs` entry in Task 2 Step 8, which is mandatory: without it `sync_parent_refs_completeness_test.dart` fails, and in production a peer's live computer whose gear item was deleted locally would dangle its FK and abort the whole sync at COMMIT.

2. **D2 uses a frozen namespace constant, not `Namespace.url.value`.** The closest sibling, `imported_computer_identity.dart`, declares `kImportedDiveComputerNamespace` as a literal UUID with a "frozen, changing this forks the fleet" comment. Task 1 follows that neighbour rather than the more distant `course_requirement_repository.dart` precedent the spec cited. The convergence property is identical.

3. **D10's `_typeDefault` case is documentation, not a behaviour change.** That switch already returns 0.0 for computers through its `_ => 0.0` fallthrough. Only `_typeDryMass` changes anything. The plan adds both but says which is which.

4. **The spec's "ladder audit: monotonic, unique, scalar equals max" test is not in this plan.** No such test exists in the repository; the only convention is the per-migration `expect(AppDatabase.migrationVersions, contains(N))`, which Task 2 follows. Adding a ladder audit would be a genuine improvement but is scope beyond this feature, and is listed as a follow-up below rather than smuggled in.

5. **`DiveComputerGearLinker.linkComputerGearForDive` takes no `diverId`.** The spec's sketch included one. It is unnecessary, because the twin is read off the computer row, and requiring it would block Task 5: `_updateExistingDive` does not pass a `diverId` down to `importProfile`.

## Follow-ups

- A ladder audit test asserting `migrationVersions` is monotonic and unique and that `currentSchemaVersion == migrationVersions.last`, explicitly NOT asserting contiguity (162 is permanently skipped, 165 through 167 were claimed by parallel branches).
- Release notes for three user-visible changes: new gear items appearing for registered computers, computers ranking in "Most Used Gear", and the 0.5 kg buoyancy shift for anyone who had already added a computer as gear by hand.
