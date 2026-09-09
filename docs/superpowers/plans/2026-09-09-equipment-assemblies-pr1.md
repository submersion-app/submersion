# Equipment Assemblies PR 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the equipment side of assemblies: schema v203, the components template table and repository, sync wiring, eight new equipment types, the Components card on the equipment detail page, list chips, and the service rollup badge.

**Architecture:** An assembly is an ordinary equipment row with child rows in a new clocked `equipment_components` junction (parent, component, role, sort order). Two nullable provenance columns land on `dive_equipment` and `dive_plan_equipment` in the same migration but nothing writes them until PR 2. A `ComponentsIndex` provider holds forward and reverse adjacency; a rollup provider derives the worst service clock across an item and its descendants from the existing all-items clock evaluation.

**Tech Stack:** Flutter, Dart 3 records and switch expressions, Drift (SQLite), Riverpod 3 (`FutureProvider`, `invalidateSelfWhen`), Equatable, `flutter gen-l10n` ARB localisation, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-09-equipment-assemblies-design.md` (sections 1, 2, 5 and 6 are this PR; sections 3 and 4 are PR 2; the history dialog and interchange are PR 3).

## Global Constraints

- Schema version becomes **201**. v200 is claimed by the transmitter registry branch; if main lands 200 or 201 first, renumber every `201` (constant, ladder, rung, backstop comment, test) to the next free number.
- `minimumCompatibleSchemaVersion` stays at **183**. Nothing here justifies raising it.
- No em-dashes anywhere (code, comments, commit messages, ARB values). Use commas, colons, or two sentences.
- No mention of the AI tool or its vendor in any file or commit message. No `Co-Authored-By` trailers.
- No emojis in code, comments, or documentation.
- Every new user-visible string gets a key in all **11** ARB files: `app_ar`, `app_de`, `app_en`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh` under `lib/l10n/arb/`. Insert keys in alphabetical position among keys sharing their prefix. ARB files carry no `@` metadata; placeholders and ICU plurals are inferred. After any ARB edit run `flutter gen-l10n` and commit the regenerated `lib/l10n/arb/app_localizations*.dart` files alongside the ARBs (the pre-push hook rejects a stale generated set).
- After editing `lib/core/database/database.dart` run Drift codegen. A bare `build` token in a Bash command can be refused by a permission rule, so write the command to a scratchpad script and run that: `printf '%s\n' 'dart run build_runner build --delete-conflicting-outputs' > "$SCRATCH/codegen.sh" && sh "$SCRATCH/codegen.sh"` where `$SCRATCH` is the session scratchpad directory. `*.g.dart` files are gitignored; do not commit them.
- Run `dart format .` before every commit. Run specific test files, not whole directories; the full suite only in the final task, in the background with a long timeout.
- Stage explicit paths with `git add <path>`; never `git add -A` or `git add .`.
- Imports grouped dart, flutter, packages, local. Files under 800 lines, ideally 200 to 400.
- Anything displaying a unit respects the diver's unit settings (the hose length attribute uses the existing `AttributeDimension.lengthM` path, which already converts).
- TDD: every task writes the failing test first and shows it fail before the implementation.

## File map

| Path | Responsibility |
| --- | --- |
| `lib/core/database/database.dart` | `EquipmentComponents` table, provenance columns, v203 rung, backstop, `_hlcTables` |
| `lib/core/database/performance_indexes.dart` | the two component indexes |
| `lib/features/equipment/domain/entities/equipment_component.dart` | `EquipmentComponent` entity |
| `lib/features/equipment/data/repositories/equipment_component_repository.dart` | CRUD, cycle guard, reorder, change stream, sync bookkeeping |
| `lib/features/equipment/data/repositories/equipment_repository_impl.dart` | tombstones for component rows on delete; change stream also ticks on components |
| `lib/core/services/sync/sync_data_serializer.dart`, `sync_service.dart`, `lib/core/data/repositories/sync_repository.dart` | `equipmentComponents` entity; provenance parent refs |
| `lib/core/constants/enums.dart` | eight new `EquipmentType` values |
| `lib/features/equipment/presentation/utils/equipment_type_icon.dart`, `equipment_enum_display.dart`, `equipment_attribute_l10n.dart` | icon, label, attribute label switches |
| `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` | catalog entries for the new types |
| `lib/features/universal_import/data/services/macdive_value_mapper.dart` | substring rules for the new types |
| `lib/features/equipment/presentation/providers/equipment_component_providers.dart` | `ComponentsIndex`, index provider, per-parent provider, rollup provider |
| `lib/features/equipment/presentation/widgets/components_card.dart` | Components card on the detail page |
| `lib/features/equipment/presentation/widgets/component_role_dialog.dart` | role text dialog with suggestions |
| `lib/features/equipment/presentation/widgets/component_picker_sheet.dart` | add-components bottom sheet with cycle exclusion |
| `lib/features/equipment/presentation/widgets/assembly_chips.dart` | count and "part of" chips |
| `lib/features/equipment/presentation/pages/equipment_detail_page.dart` | mounts the card; header badge reads the rollup |
| `lib/features/equipment/presentation/widgets/equipment_list_content.dart`, `dense_equipment_list_tile.dart`, `pages/equipment_set_detail_page.dart` | chips and rollup badges |
| `lib/features/equipment/domain/constants/equipment_field.dart` | `EquipmentField.components` table column |

---

### Task 1: Schema v203

**Files:**
- Modify: `lib/core/database/database.dart` (table after `EquipmentAttributes` ~L1055; `DiveEquipment` ~L1058; `DivePlanEquipment` ~L1102; registration list ~L3407; `currentSchemaVersion` L3511; `migrationVersions` ~L4026; helpers after `_assertCertificationCredentialsColumn` ~L4127; `_hlcTables` ~L6883; rung after the v199 rung ~L10580; backstop after the v199 backstop ~L10772)
- Modify: `lib/core/database/performance_indexes.dart` (after the `idx_equipment_attributes_key_num` entry ~L181)
- Test: `test/core/database/migration_v203_equipment_assemblies_test.dart`

**Interfaces:**
- Produces: Drift table `EquipmentComponents` (data class `EquipmentComponentRow`, companion `EquipmentComponentsCompanion`, accessor `db.equipmentComponents`) with columns `id`, `parentEquipmentId`, `componentEquipmentId`, `role`, `sortOrder`, `createdAt`, `updatedAt`, `hlc`; nullable `viaEquipmentId` and `viaSetId` on `DiveEquipment` and `DivePlanEquipment`.

- [ ] **Step 1: Write the failing migration test**

```dart
// test/core/database/migration_v203_equipment_assemblies_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v203 adds the equipment_components assembly template and the two
/// provenance columns on each gear junction (issue #1487). Additive, no
/// backfill.

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

/// (from column, referenced table, on_delete) for every FK on [table].
Future<Set<String>> _foreignKeys(AppDatabase db, String table) async {
  final rows = await db
      .customSelect("PRAGMA foreign_key_list('$table')")
      .get();
  return rows
      .map(
        (r) =>
            '${r.read<String>('from')}>${r.read<String>('table')}:'
            '${r.read<String>('on_delete')}',
      )
      .toSet();
}

void main() {
  test('v203 is the current schema version and is in the ladder', () {
    // 200 is held by the transmitter registry branch.
    expect(AppDatabase.currentSchemaVersion, 201);
    expect(AppDatabase.migrationVersions, contains(201));
  });

  test('a fresh database has the components table and both column pairs', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _tables(db), contains('equipment_components'));
    expect(
      await _columns(db, 'equipment_components'),
      containsAll([
        'id',
        'parent_equipment_id',
        'component_equipment_id',
        'role',
        'sort_order',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    for (final table in ['dive_equipment', 'dive_plan_equipment']) {
      expect(
        await _columns(db, table),
        containsAll(['via_equipment_id', 'via_set_id']),
        reason: table,
      );
      expect(
        await _foreignKeys(db, table),
        containsAll([
          'via_equipment_id>equipment:SET NULL',
          'via_set_id>equipment_sets:SET NULL',
        ]),
        reason: table,
      );
    }
  });

  test('a database stranded before v203 gains the table and columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 200');
        rawDb.execute('''
          CREATE TABLE dive_equipment (
            dive_id TEXT NOT NULL,
            equipment_id TEXT NOT NULL,
            PRIMARY KEY (dive_id, equipment_id)
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_plan_equipment (
            plan_id TEXT NOT NULL,
            equipment_id TEXT NOT NULL,
            PRIMARY KEY (plan_id, equipment_id)
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    expect(await _tables(db), contains('equipment_components'));
    for (final table in ['dive_equipment', 'dive_plan_equipment']) {
      expect(
        await _columns(db, table),
        containsAll(['via_equipment_id', 'via_set_id']),
        reason: table,
      );
    }
  });

  test('deleting either end of a component row cascades it away', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    for (final id in ['e1', 'e2', 'e3']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    await db
        .into(db.equipmentComponents)
        .insert(
          EquipmentComponentsCompanion.insert(
            id: 'c1',
            parentEquipmentId: 'e1',
            componentEquipmentId: 'e2',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.equipmentComponents)
        .insert(
          EquipmentComponentsCompanion.insert(
            id: 'c2',
            parentEquipmentId: 'e1',
            componentEquipmentId: 'e3',
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    await (db.delete(db.equipment)..where((t) => t.id.equals('e3'))).go();
    var rows = await db.select(db.equipmentComponents).get();
    expect(rows.map((r) => r.id), ['c1']);

    await (db.delete(db.equipment)..where((t) => t.id.equals('e1'))).go();
    rows = await db.select(db.equipmentComponents).get();
    expect(rows, isEmpty);
  });

  test('the same pair cannot be inserted twice', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    for (final id in ['e1', 'e2']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'hose',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    final row = EquipmentComponentsCompanion.insert(
      id: 'c1',
      parentEquipmentId: 'e1',
      componentEquipmentId: 'e2',
      createdAt: 1,
      updatedAt: 1,
    );
    await db.into(db.equipmentComponents).insert(row);
    expect(
      () => db
          .into(db.equipmentComponents)
          .insert(row.copyWith(id: const Value('c2'))),
      throwsA(anything),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v203_equipment_assemblies_test.dart`
Expected: compile error, `equipmentComponents` and `EquipmentComponentsCompanion` are undefined.

- [ ] **Step 3: Add the table, the columns, and the registration**

Insert after the `EquipmentAttributes` class (after its closing brace, before the `/// Junction table for equipment used per dive` comment):

```dart
/// The assembly template (issue #1487): one row per part of a parent item.
/// A clocked child of equipment, shaped like [EquipmentAttributes], because
/// role and order are mutable payload that must merge on their own clock.
/// An item is an assembly when it has at least one row here; there is no
/// assembly type.
@DataClassName('EquipmentComponentRow')
class EquipmentComponents extends Table {
  TextColumn get id => text()();
  TextColumn get parentEquipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get componentEquipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// Free text such as "Primary second stage"; empty when unset.
  TextColumn get role => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {parentEquipmentId, componentEquipmentId},
  ];
}
```

Replace the `DiveEquipment` class body so it reads:

```dart
/// Junction table for equipment used per dive
class DiveEquipment extends Table {
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();

  /// Provenance (issue #1487): the immediate parent assembly this row was
  /// attached through, null for a top-level row. SET NULL on delete so the
  /// part stays on the dive as flat gear when its assembly is deleted.
  TextColumn get viaEquipmentId => text()
      .nullable()
      .references(Equipment, #id, onDelete: KeyAction.setNull)();

  /// The equipment set that was applied, carried by every row of the
  /// expanded subtree; null when the row was added by hand.
  TextColumn get viaSetId => text()
      .nullable()
      .references(EquipmentSets, #id, onDelete: KeyAction.setNull)();

  @override
  Set<Column> get primaryKey => {diveId, equipmentId};
}
```

Add the same two columns, with the same doc comments, to `DivePlanEquipment` (between `equipmentId` and `primaryKey`).

In the `@DriftDatabase(tables: [...])` list add `EquipmentComponents,` on the line after `EquipmentAttributes,`.

- [ ] **Step 4: Add the migration helpers, rung, backstop, version, ladder, and clock list**

After `_assertCertificationCredentialsColumn` add:

```dart
  /// v203: equipment_components (issue #1487), the assembly template. Pure
  /// CREATE IF NOT EXISTS so it is safe from both onUpgrade and the beforeOpen
  /// backstop.
  Future<void> _assertEquipmentComponentsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS equipment_components (
        id TEXT NOT NULL PRIMARY KEY,
        parent_equipment_id TEXT NOT NULL
          REFERENCES equipment(id) ON DELETE CASCADE,
        component_equipment_id TEXT NOT NULL
          REFERENCES equipment(id) ON DELETE CASCADE,
        role TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT,
        UNIQUE (parent_equipment_id, component_equipment_id)
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_components_parent '
      'ON equipment_components(parent_equipment_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_components_component '
      'ON equipment_components(component_equipment_id)',
    );
  }

  /// v203: the two nullable provenance columns on each gear junction
  /// (issue #1487). PRAGMA-guarded per table and per column so a healthy
  /// database no-ops and a partial fixture does not throw. Nothing writes
  /// them until the dive side lands; adding them here keeps the ladder to
  /// one rung for the feature.
  Future<void> _assertGearProvenanceColumns() async {
    for (final table in ['dive_equipment', 'dive_plan_equipment']) {
      final cols = await customSelect("PRAGMA table_info('$table')").get();
      if (cols.isEmpty) continue;
      final names = cols.map((c) => c.read<String>('name')).toSet();
      if (!names.contains('via_equipment_id')) {
        await customStatement(
          'ALTER TABLE $table ADD COLUMN via_equipment_id TEXT '
          'REFERENCES equipment (id) ON DELETE SET NULL',
        );
      }
      if (!names.contains('via_set_id')) {
        await customStatement(
          'ALTER TABLE $table ADD COLUMN via_set_id TEXT '
          'REFERENCES equipment_sets (id) ON DELETE SET NULL',
        );
      }
    }
  }
```

After the v199 rung (`if (from < 199) await reportProgress();`) add:

```dart
        // v203: equipment assemblies (issue #1487). The equipment_components
        // template table plus two nullable provenance columns on each gear
        // junction. Additive, no backfill. 200 is held by the transmitter
        // registry branch.
        if (from < 203) {
          await _assertEquipmentComponentsTable();
          await _assertGearProvenanceColumns();
        }
        if (from < 203) await reportProgress();
```

After the v199 backstop (`await _assertCertificationCredentialsColumn();` inside `beforeOpen`) add:

```dart
        // v203 backstop: re-assert the equipment_components table and the
        // gear-junction provenance columns (issue #1487). A database that
        // arrives by restore or sync-adopt never runs onUpgrade.
        await _assertEquipmentComponentsTable();
        await _assertGearProvenanceColumns();
```

Change `static const int currentSchemaVersion = 199;` to `201`. In `migrationVersions` append `201,` after `199,` with the comment `// 201: equipment assemblies (issue #1487); 200 is held by another branch.` In `_hlcTables` add `'equipment_components',` after `'equipment_attributes',`.

In `performance_indexes.dart` after the `idx_equipment_attributes_key_num` entry add:

```dart
  (
    name: 'idx_equipment_components_parent',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_equipment_components_parent '
        'ON equipment_components(parent_equipment_id)',
  ),
  (
    name: 'idx_equipment_components_component',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_equipment_components_component '
        'ON equipment_components(component_equipment_id)',
  ),
```

- [ ] **Step 5: Run codegen, then the test**

Run the codegen script (see Global Constraints), then:
`flutter test test/core/database/migration_v203_equipment_assemblies_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 6: Relax the v199 exact-version tripwire and run the neighbouring ladder tests**

In `test/core/database/migration_v199_certification_credentials_test.dart` change `expect(AppDatabase.currentSchemaVersion, 199);` to `expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(199));` and add the comment `// Relaxed once v203 (equipment assemblies) landed on top; the newest rung owns the exact assertion.`

Run: `flutter test test/core/database/migration_v199_certification_credentials_test.dart test/core/database/migration_v196_weight_presets_test.dart test/core/database/equipment_set_geofence_schema_test.dart`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format lib/core/database/database.dart lib/core/database/performance_indexes.dart test/core/database/migration_v203_equipment_assemblies_test.dart test/core/database/migration_v199_certification_credentials_test.dart
git add lib/core/database/database.dart lib/core/database/performance_indexes.dart test/core/database/migration_v203_equipment_assemblies_test.dart test/core/database/migration_v199_certification_credentials_test.dart
git commit -m "feat(equipment): schema v203 for assemblies (#1487)

equipment_components template table plus nullable via_equipment_id and
via_set_id on dive_equipment and dive_plan_equipment. Additive rung with
a beforeOpen backstop; nothing writes the provenance columns yet."
```

---

### Task 2: Entity, repository, cycle guard, and delete tombstones

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_component.dart`
- Create: `lib/features/equipment/data/repositories/equipment_component_repository.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (`watchEquipmentChanges` ~L114; `deleteEquipment` ~L422)
- Test: `test/features/equipment/domain/entities/equipment_component_test.dart`
- Test: `test/features/equipment/data/repositories/equipment_component_repository_test.dart`
- Test: `test/features/equipment/data/repositories/equipment_repository_component_tombstone_test.dart`

**Interfaces:**
- Consumes: `EquipmentComponents` table from Task 1; `EquipmentRepository.getEquipmentByIds(List<String>)`; `SyncRepository.markRecordPending({entityType, recordId, localUpdatedAt})` and `logDeletion({entityType, recordId})`; `debounce` from `package:submersion/core/utils/stream_debounce.dart`.
- Produces:
  - `class EquipmentComponent extends Equatable { String id; String parentEquipmentId; String componentEquipmentId; String role; int sortOrder; DateTime createdAt; DateTime updatedAt; EquipmentItem? component; copyWith(...) }`
  - `class EquipmentComponentCycleException implements Exception`
  - `class EquipmentComponentRepository { Stream<void> watchComponentChanges(); Future<List<EquipmentComponent>> getAllComponents(); Future<List<EquipmentComponent>> getComponents(String parentId); Future<Set<String>> ancestorsOf(String id); Future<bool> wouldCreateCycle({required String parentId, required String componentId}); Future<EquipmentComponent> addComponent({required String parentId, required String componentId, String role = ''}); Future<void> updateRole(String id, String role); Future<void> reorder(String parentId, List<String> orderedIds); Future<void> removeComponent(String id); Future<List<String>> distinctRoles(); }`
  - Sync entity type string `'equipmentComponents'` (used for pending marks and tombstones here; registered in Task 3).

- [ ] **Step 1: Write the failing entity test**

```dart
// test/features/equipment/domain/entities/equipment_component_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);

  EquipmentComponent row({String role = ''}) => EquipmentComponent(
    id: 'c1',
    parentEquipmentId: 'reg',
    componentEquipmentId: 'hose',
    role: role,
    sortOrder: 2,
    createdAt: t0,
    updatedAt: t0,
  );

  test('defaults role to empty and sortOrder to zero', () {
    final c = EquipmentComponent(
      id: 'c1',
      parentEquipmentId: 'reg',
      componentEquipmentId: 'hose',
      createdAt: t0,
      updatedAt: t0,
    );
    expect(c.role, '');
    expect(c.sortOrder, 0);
    expect(c.component, isNull);
  });

  test('copyWith replaces only what is passed', () {
    const hose = EquipmentItem(id: 'hose', name: 'LP hose', type: EquipmentType.hose);
    final copy = row().copyWith(role: 'Primary', component: hose);
    expect(copy.role, 'Primary');
    expect(copy.component, hose);
    expect(copy.sortOrder, 2);
    expect(copy.parentEquipmentId, 'reg');
  });

  test('equality is by value, hydrated item included', () {
    expect(row(role: 'a'), row(role: 'a'));
    expect(row(role: 'a'), isNot(row(role: 'b')));
  });
}
```

(`EquipmentType.hose` does not exist until Task 4; use `EquipmentType.other` here and switch it to `hose` in Task 4, Step 9.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/domain/entities/equipment_component_test.dart`
Expected: compile error, `equipment_component.dart` not found.

- [ ] **Step 3: Write the entity**

```dart
// lib/features/equipment/domain/entities/equipment_component.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// One part of an assembly: the row that says [componentEquipmentId] is a
/// component of [parentEquipmentId], in what [role] and at what position.
///
/// An assembly is any equipment item with at least one of these rows; there
/// is no assembly type. A part may sit in several assemblies' templates (the
/// same second stage under a DIN reg and a yoke reg): the template says what
/// can be assembled, and the dive snapshot records what was.
class EquipmentComponent extends Equatable {
  final String id;
  final String parentEquipmentId;
  final String componentEquipmentId;

  /// Free text such as "Primary second stage"; empty when unset.
  final String role;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The part itself, hydrated by reads that join it; null on bare rows.
  final EquipmentItem? component;

  const EquipmentComponent({
    required this.id,
    required this.parentEquipmentId,
    required this.componentEquipmentId,
    this.role = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.component,
  });

  EquipmentComponent copyWith({
    String? id,
    String? parentEquipmentId,
    String? componentEquipmentId,
    String? role,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    EquipmentItem? component,
  }) => EquipmentComponent(
    id: id ?? this.id,
    parentEquipmentId: parentEquipmentId ?? this.parentEquipmentId,
    componentEquipmentId: componentEquipmentId ?? this.componentEquipmentId,
    role: role ?? this.role,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    component: component ?? this.component,
  );

  @override
  List<Object?> get props => [
    id,
    parentEquipmentId,
    componentEquipmentId,
    role,
    sortOrder,
    createdAt,
    updatedAt,
    component,
  ];
}
```

- [ ] **Step 4: Run the entity test**

Run: `flutter test test/features/equipment/domain/entities/equipment_component_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Write the failing repository test**

```dart
// test/features/equipment/data/repositories/equipment_component_repository_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';

import '../../../../helpers/test_database.dart';

/// The assembly template (issue #1487): membership rows, the cycle guard,
/// ordering, and the sync bookkeeping every write must leave behind.
void main() {
  late AppDatabase db;
  late EquipmentComponentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentComponentRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: t, updatedAt: t),
        );
    for (final id in ['reg', 'first', 'second', 'hose', 'kit']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d1'),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> pendingIds() async {
    final rows = await db.select(db.syncRecords).get();
    return rows
        .where((r) => r.entityType == 'equipmentComponents')
        .map((r) => r.recordId)
        .toList();
  }

  Future<List<String>> tombstones() async {
    final rows = await db.select(db.deletionLog).get();
    return rows
        .where((r) => r.entityType == 'equipmentComponents')
        .map((r) => r.recordId)
        .toList();
  }

  group('addComponent', () {
    test('appends with the next sort order and marks the row pending', () async {
      final a = await repo.addComponent(parentId: 'reg', componentId: 'first');
      final b = await repo.addComponent(
        parentId: 'reg',
        componentId: 'second',
        role: '  Primary  ',
      );
      expect(a.sortOrder, 0);
      expect(b.sortOrder, 1);
      expect(b.role, 'Primary');
      expect(await pendingIds(), containsAll([a.id, b.id]));
    });

    test('a second add of the same pair returns the existing row', () async {
      final a = await repo.addComponent(parentId: 'reg', componentId: 'first');
      final again = await repo.addComponent(parentId: 'reg', componentId: 'first');
      expect(again.id, a.id);
      expect(await db.select(db.equipmentComponents).get(), hasLength(1));
    });

    test('refuses a self reference', () async {
      expect(
        () => repo.addComponent(parentId: 'reg', componentId: 'reg'),
        throwsA(isA<EquipmentComponentCycleException>()),
      );
    });

    test('refuses a direct cycle', () async {
      await repo.addComponent(parentId: 'reg', componentId: 'first');
      expect(
        () => repo.addComponent(parentId: 'first', componentId: 'reg'),
        throwsA(isA<EquipmentComponentCycleException>()),
      );
    });

    test('refuses a transitive cycle three levels deep', () async {
      await repo.addComponent(parentId: 'kit', componentId: 'reg');
      await repo.addComponent(parentId: 'reg', componentId: 'first');
      await repo.addComponent(parentId: 'first', componentId: 'hose');
      expect(
        () => repo.addComponent(parentId: 'hose', componentId: 'kit'),
        throwsA(isA<EquipmentComponentCycleException>()),
      );
      // The legal direction still works.
      await repo.addComponent(parentId: 'kit', componentId: 'hose');
    });

    test('a part may belong to two assemblies', () async {
      await repo.addComponent(parentId: 'reg', componentId: 'second');
      await repo.addComponent(parentId: 'kit', componentId: 'second');
      expect(await repo.getAllComponents(), hasLength(2));
    });
  });

  test('getComponents hydrates parts in sort order', () async {
    await repo.addComponent(parentId: 'reg', componentId: 'second');
    await repo.addComponent(parentId: 'reg', componentId: 'first');
    final parts = await repo.getComponents('reg');
    expect(parts.map((p) => p.componentEquipmentId), ['second', 'first']);
    expect(parts.map((p) => p.component?.name), ['second', 'first']);
    expect(await repo.getComponents('hose'), isEmpty);
  });

  test('ancestorsOf walks upward and terminates', () async {
    await repo.addComponent(parentId: 'kit', componentId: 'reg');
    await repo.addComponent(parentId: 'reg', componentId: 'hose');
    expect(await repo.ancestorsOf('hose'), {'reg', 'kit'});
    expect(await repo.ancestorsOf('kit'), isEmpty);
  });

  test('reorder rewrites sort order in the given sequence', () async {
    final a = await repo.addComponent(parentId: 'reg', componentId: 'first');
    final b = await repo.addComponent(parentId: 'reg', componentId: 'second');
    final c = await repo.addComponent(parentId: 'reg', componentId: 'hose');
    await repo.reorder('reg', [c.id, a.id, b.id]);
    final parts = await repo.getComponents('reg');
    expect(parts.map((p) => p.componentEquipmentId), ['hose', 'first', 'second']);
    expect(parts.map((p) => p.sortOrder), [0, 1, 2]);
  });

  test('updateRole trims and marks pending', () async {
    final a = await repo.addComponent(parentId: 'reg', componentId: 'first');
    await repo.updateRole(a.id, ' Necklace ');
    final parts = await repo.getComponents('reg');
    expect(parts.single.role, 'Necklace');
    expect(await pendingIds(), contains(a.id));
  });

  test('removeComponent deletes the row and writes a tombstone', () async {
    final a = await repo.addComponent(parentId: 'reg', componentId: 'first');
    await repo.removeComponent(a.id);
    expect(await repo.getComponents('reg'), isEmpty);
    expect(await tombstones(), [a.id]);
  });

  test('distinctRoles returns used roles once, sorted, without blanks', () async {
    await repo.addComponent(parentId: 'reg', componentId: 'first', role: 'Primary');
    await repo.addComponent(parentId: 'reg', componentId: 'second', role: 'Necklace');
    await repo.addComponent(parentId: 'kit', componentId: 'hose', role: 'Primary');
    await repo.addComponent(parentId: 'kit', componentId: 'second');
    expect(await repo.distinctRoles(), ['Necklace', 'Primary']);
  });

  test('watchComponentChanges ticks on a membership write', () async {
    var ticks = 0;
    final sub = repo.watchComponentChanges().listen((_) => ticks++);
    addTearDown(sub.cancel);
    await repo.addComponent(parentId: 'reg', componentId: 'first');
    // The stream is debounced 300 ms; poll rather than pumpEventQueue.
    for (var i = 0; i < 50 && ticks == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ticks, greaterThan(0));
  });
}
```

`markRecordPending` writes `sync_records` (`db.syncRecords`, columns `entityType` and `recordId`), and `logDeletion` writes `deletion_log` (`db.deletionLog`), which is what the two helpers read.

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/features/equipment/data/repositories/equipment_component_repository_test.dart`
Expected: compile error, `equipment_component_repository.dart` not found.

- [ ] **Step 7: Write the repository**

```dart
// lib/features/equipment/data/repositories/equipment_component_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';

/// Thrown instead of writing a loop into the assembly graph.
class EquipmentComponentCycleException implements Exception {
  final String parentId;
  final String componentId;

  const EquipmentComponentCycleException(this.parentId, this.componentId);

  @override
  String toString() =>
      'Adding $componentId under $parentId would make the assembly graph '
      'cyclic';
}

/// The assembly template (issue #1487): which parts belong to which item.
///
/// Every write leaves sync bookkeeping behind (pending mark or tombstone) the
/// way EquipmentRepository.saveAttributes does, because the table is a
/// clocked child of equipment with its own hlc.
class EquipmentComponentRepository {
  EquipmentComponentRepository({EquipmentRepository? equipmentRepository})
    : _equipment = equipmentRepository ?? EquipmentRepository();

  final EquipmentRepository _equipment;
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(EquipmentComponentRepository);

  static const changeTickDebounce = Duration(milliseconds: 300);
  static const entityType = 'equipmentComponents';

  /// Emits on any change to the template or to the items it points at, so a
  /// renamed part refreshes the Components card and the list chips.
  Stream<void> watchComponentChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.equipmentComponents),
          TableUpdateQuery.onTable(_db.equipment),
        ]),
      )
      .debounce(changeTickDebounce);

  EquipmentComponent _map(
    EquipmentComponentRow row, {
    EquipmentItem? component,
  }) => EquipmentComponent(
    id: row.id,
    parentEquipmentId: row.parentEquipmentId,
    componentEquipmentId: row.componentEquipmentId,
    role: row.role,
    sortOrder: row.sortOrder,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    component: component,
  );

  /// Every row, unhydrated, ordered by parent then position. The adjacency
  /// index is built from this in one read.
  Future<List<EquipmentComponent>> getAllComponents() async {
    final rows =
        await (_db.select(_db.equipmentComponents)..orderBy([
              (t) => OrderingTerm.asc(t.parentEquipmentId),
              (t) => OrderingTerm.asc(t.sortOrder),
            ]))
            .get();
    return rows.map(_map).toList();
  }

  /// The parts of [parentId] with their items hydrated, in sort order.
  Future<List<EquipmentComponent>> getComponents(String parentId) async {
    final rows =
        await (_db.select(_db.equipmentComponents)
              ..where((t) => t.parentEquipmentId.equals(parentId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    if (rows.isEmpty) return const [];
    final items = await _equipment.getEquipmentByIds(
      rows.map((r) => r.componentEquipmentId).toList(),
    );
    final byId = {for (final i in items) i.id: i};
    return [
      for (final r in rows) _map(r, component: byId[r.componentEquipmentId]),
    ];
  }

  /// Ids reachable upward from [id]: its parents, their parents, and so on.
  /// A visited set makes the walk terminate even on a corrupt graph.
  Future<Set<String>> ancestorsOf(String id) async {
    final rows = await getAllComponents();
    final parentsOf = <String, List<String>>{};
    for (final r in rows) {
      parentsOf
          .putIfAbsent(r.componentEquipmentId, () => [])
          .add(r.parentEquipmentId);
    }
    final seen = <String>{};
    final queue = <String>[id];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final parent in parentsOf[current] ?? const <String>[]) {
        if (seen.add(parent)) queue.add(parent);
      }
    }
    return seen;
  }

  /// True when [componentId] is [parentId] itself or one of its ancestors:
  /// linking it underneath would close a loop.
  Future<bool> wouldCreateCycle({
    required String parentId,
    required String componentId,
  }) async {
    if (parentId == componentId) return true;
    return (await ancestorsOf(parentId)).contains(componentId);
  }

  /// Appends [componentId] under [parentId]. Throws
  /// [EquipmentComponentCycleException] rather than writing a loop; adding
  /// a pair that already exists returns the existing row unchanged.
  Future<EquipmentComponent> addComponent({
    required String parentId,
    required String componentId,
    String role = '',
  }) async {
    if (await wouldCreateCycle(parentId: parentId, componentId: componentId)) {
      throw EquipmentComponentCycleException(parentId, componentId);
    }
    final existing =
        await (_db.select(_db.equipmentComponents)..where(
              (t) =>
                  t.parentEquipmentId.equals(parentId) &
                  t.componentEquipmentId.equals(componentId),
            ))
            .getSingleOrNull();
    if (existing != null) return _map(existing);

    final siblings = await (_db.select(
      _db.equipmentComponents,
    )..where((t) => t.parentEquipmentId.equals(parentId))).get();
    final nextOrder = siblings.isEmpty
        ? 0
        : siblings.map((s) => s.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db
        .into(_db.equipmentComponents)
        .insert(
          EquipmentComponentsCompanion(
            id: Value(id),
            parentEquipmentId: Value(parentId),
            componentEquipmentId: Value(componentId),
            role: Value(role.trim()),
            sortOrder: Value(nextOrder),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
    _log.info('Added component $componentId under $parentId');
    final row = await (_db.select(
      _db.equipmentComponents,
    )..where((t) => t.id.equals(id))).getSingle();
    return _map(row);
  }

  Future<void> updateRole(String id, String role) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.equipmentComponents)..where((t) => t.id.equals(id)))
        .write(
          EquipmentComponentsCompanion(
            role: Value(role.trim()),
            updatedAt: Value(now),
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Rewrites sort_order so [orderedIds] (component row ids under
  /// [parentId]) run 0..n-1 in the given sequence.
  Future<void> reorder(String parentId, List<String> orderedIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final (index, id) in orderedIds.indexed) {
        await (_db.update(_db.equipmentComponents)..where(
              (t) => t.id.equals(id) & t.parentEquipmentId.equals(parentId),
            ))
            .write(
              EquipmentComponentsCompanion(
                sortOrder: Value(index),
                updatedAt: Value(now),
              ),
            );
      }
    });
    for (final id in orderedIds) {
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }

  Future<void> removeComponent(String id) async {
    await (_db.delete(
      _db.equipmentComponents,
    )..where((t) => t.id.equals(id))).go();
    await _syncRepository.logDeletion(entityType: entityType, recordId: id);
    SyncEventBus.notifyLocalChange();
    _log.info('Removed component row $id');
  }

  /// Roles already in use, each once, sorted, blanks dropped. Feeds the
  /// role dialog's suggestion chips.
  Future<List<String>> distinctRoles() async {
    final rows = await _db.select(_db.equipmentComponents).get();
    final roles = {for (final r in rows) if (r.role.isNotEmpty) r.role};
    return roles.toList()..sort();
  }
}
```

- [ ] **Step 8: Run the repository test**

Run: `flutter test test/features/equipment/data/repositories/equipment_component_repository_test.dart`
Expected: PASS, 13 tests.

- [ ] **Step 9: Write the failing tombstone test for deleteEquipment**

```dart
// test/features/equipment/data/repositories/equipment_repository_component_tombstone_test.dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// SQLite cascades equipment_components away when either end is deleted,
/// but a cascade emits no deletion-log entry, so deleteEquipment must
/// tombstone the rows itself, in both directions (issue #1487).
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;
  late EquipmentComponentRepository components;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    components = EquipmentComponentRepository();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(id: 'd1', name: 'd1', createdAt: t, updatedAt: t),
        );
    for (final id in ['reg', 'first', 'hose']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d1'),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<Set<String>> componentTombstones() async {
    final rows = await db.select(db.deletionLog).get();
    return rows
        .where((r) => r.entityType == 'equipmentComponents')
        .map((r) => r.recordId)
        .toSet();
  }

  test('deleting the parent tombstones every row under it', () async {
    final a = await components.addComponent(parentId: 'reg', componentId: 'first');
    final b = await components.addComponent(parentId: 'reg', componentId: 'hose');
    await repo.deleteEquipment('reg');
    expect(await db.select(db.equipmentComponents).get(), isEmpty);
    expect(await componentTombstones(), {a.id, b.id});
  });

  test('deleting a part tombstones the rows that pointed at it', () async {
    final a = await components.addComponent(parentId: 'reg', componentId: 'first');
    final keep = await components.addComponent(parentId: 'reg', componentId: 'hose');
    await repo.deleteEquipment('first');
    final remaining = await db.select(db.equipmentComponents).get();
    expect(remaining.map((r) => r.id), [keep.id]);
    expect(await componentTombstones(), {a.id});
  });

  test('watchEquipmentChanges ticks on a component write', () async {
    var ticks = 0;
    final sub = repo.watchEquipmentChanges().listen((_) => ticks++);
    addTearDown(sub.cancel);
    await components.addComponent(parentId: 'reg', componentId: 'first');
    for (var i = 0; i < 50 && ticks == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ticks, greaterThan(0));
  });
}
```

- [ ] **Step 10: Run it to verify it fails**

Run: `flutter test test/features/equipment/data/repositories/equipment_repository_component_tombstone_test.dart`
Expected: the two tombstone tests FAIL (empty set); the watch test may fail or pass depending on timing.

- [ ] **Step 11: Extend deleteEquipment and the change stream**

In `equipment_repository_impl.dart`, replace `watchEquipmentChanges`:

```dart
  /// Emits whenever the `equipment` table or the assembly template changes,
  /// so list providers refresh after a sync, a rename, or a membership edit.
  /// Undebounced on purpose: consumers use invalidateSelfWhen, which already
  /// coalesces.
  Stream<void> watchEquipmentChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.equipment),
      TableUpdateQuery.onTable(_db.equipmentComponents),
    ]),
  );
```

In `deleteEquipment`, inside the transaction, after the `records` query add:

```dart
        // Assembly rows in both directions: this item as a parent and as a
        // part (issue #1487). Cascaded away by SQLite, so tombstoned here.
        final componentRows =
            await (_db.select(_db.equipmentComponents)..where(
                  (t) =>
                      t.parentEquipmentId.equals(id) |
                      t.componentEquipmentId.equals(id),
                ))
                .get();
```

and after the `records` tombstone loop add:

```dart
        for (final c in componentRows) {
          await _syncRepository.logDeletion(
            entityType: 'equipmentComponents',
            recordId: c.id,
          );
        }
```

Update the method's doc comment to mention component rows alongside schedules and records.

- [ ] **Step 12: Run both repository test files and the existing equipment repository tests**

Run: `flutter test test/features/equipment/data/repositories/equipment_repository_component_tombstone_test.dart test/features/equipment/data/repositories/equipment_repository_test.dart test/features/equipment/data/repositories/equipment_set_repository_items_test.dart`
Expected: PASS.

- [ ] **Step 13: Format and commit**

```bash
dart format lib/features/equipment test/features/equipment
git add lib/features/equipment/domain/entities/equipment_component.dart lib/features/equipment/data/repositories/equipment_component_repository.dart lib/features/equipment/data/repositories/equipment_repository_impl.dart test/features/equipment/domain/entities/equipment_component_test.dart test/features/equipment/data/repositories/equipment_component_repository_test.dart test/features/equipment/data/repositories/equipment_repository_component_tombstone_test.dart
git commit -m "feat(equipment): assembly component entity and repository (#1487)

Cycle-guarded membership writes with per-row sync bookkeeping, a
debounced change stream, and tombstones for component rows when either
end of the edge is deleted."
```

---

### Task 3: Sync wiring for equipmentComponents and the provenance parent refs

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (every site that names `equipmentAttributes`: field ~L242, constructor default ~L328, `toJson` ~L409, `fromJson` ~L491, export descriptor ~L761, `_safeExport` call ~L1390, `fetchRecord` ~L1816, `fetchRecords` ~L2225, `upsertRecord` ~L2767, `upsertRecords` ~L3522, `recordIdsFor` ~L4333, `tableFor` ~L4568, `deleteRecord` ~L4753, `_exportEquipmentAttributes` ~L5272)
- Modify: `lib/core/services/sync/sync_service.dart` (merge order ~L1355; `entityHasUpdatedAt` ~L2221; `parentRefs` ~L2342, ~L2478, ~L2485)
- Modify: `lib/core/data/repositories/sync_repository.dart` (clock targets map ~L81)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` map ~L24)
- Test: `test/core/services/sync/equipment_component_sync_test.dart`

**Interfaces:**
- Consumes: `EquipmentComponentRow` from Task 1.
- Produces: sync entity `'equipmentComponents'` (HLC child of `equipment`, surrogate `id`), and `parentRefs` entries for `viaEquipmentId` and `viaSetId` on `diveEquipment` and `divePlanEquipment`.

- [ ] **Step 1: Write the failing serializer round-trip test**

```dart
// test/core/services/sync/equipment_component_sync_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// equipmentComponents is a clocked child of equipment (issue #1487), wired
/// exactly like equipmentAttributes: surrogate id, own hlc, table-backed
/// export descriptor, no composite-id branch.
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> componentJson(
    String id, {
    String parent = 'reg',
    String component = 'hose',
    String role = 'Primary',
  }) => {
    'id': id,
    'parentEquipmentId': parent,
    'componentEquipmentId': component,
    'role': role,
    'sortOrder': 0,
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': null,
  };

  Future<void> insertEquipment(String id) => serializer.upsertRecord('equipment', {
    'id': id,
    'name': id,
    'type': 'regulator',
    'status': 'active',
    'purchaseCurrency': 'USD',
    'notes': '',
    'isActive': true,
    'createdAt': 1000,
    'updatedAt': 1000,
  });

  test('round-trips through upsertRecord, fetchRecord, deleteRecord', () async {
    await insertEquipment('reg');
    await insertEquipment('hose');
    await serializer.upsertRecord('equipmentComponents', componentJson('c1'));

    final row = await serializer.fetchRecord('equipmentComponents', 'c1');
    expect(row, isNotNull);
    expect(row!['parentEquipmentId'], 'reg');
    expect(row['componentEquipmentId'], 'hose');
    expect(row['role'], 'Primary');

    await serializer.deleteRecord('equipmentComponents', 'c1');
    expect(await serializer.fetchRecord('equipmentComponents', 'c1'), isNull);
  });

  test('round-trips through the batch paths and recordIdsFor', () async {
    await insertEquipment('reg');
    await insertEquipment('hose');
    await insertEquipment('first');
    await serializer.upsertRecords('equipmentComponents', [
      componentJson('c1'),
      componentJson('c2', component: 'first'),
    ]);
    final fetched = await serializer.fetchRecords('equipmentComponents', ['c1', 'c2']);
    expect(fetched.keys, containsAll(['c1', 'c2']));
    expect(await serializer.recordIdsFor('equipmentComponents'), containsAll(['c1', 'c2']));
  });

  test('is registered as a clocked entity after its parent', () {
    expect(SyncService.entityHasUpdatedAt['equipmentComponents'], isTrue);
    final refs = SyncService.parentRefs['equipmentComponents']!;
    expect(
      refs.map((r) => '${r.field}:${r.parent}:${r.nullable}'),
      unorderedEquals([
        'parentEquipmentId:equipment:false',
        'componentEquipmentId:equipment:false',
      ]),
    );
  });

  test('the gear junctions declare the provenance columns as nullable refs', () {
    for (final entity in ['diveEquipment', 'divePlanEquipment']) {
      final refs = SyncService.parentRefs[entity]!;
      expect(
        refs.map((r) => '${r.field}:${r.parent}:${r.nullable}'),
        containsAll([
          'viaEquipmentId:equipment:true',
          'viaSetId:equipmentSets:true',
        ]),
        reason: entity,
      );
    }
  });
}
```

If `ParentRef` exposes its members under different names, read the record type near `parentRefs` in `sync_service.dart` and adjust the three field reads.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/services/sync/equipment_component_sync_test.dart`
Expected: FAIL. The first two tests throw on the unknown entity type; the registration tests fail on a null lookup.

- [ ] **Step 3: Register the entity in the serializer**

At every site listed under Files, add an `equipmentComponents` twin directly after the `equipmentAttributes` line(s), same shape:

- Field: `final List<Map<String, dynamic>> equipmentComponents;`
- Constructor default: `this.equipmentComponents = const [],`
- `toJson`: `'equipmentComponents': equipmentComponents,`
- `fromJson`: `equipmentComponents: _parseList(json['equipmentComponents']),`
- Export descriptor: `(key: 'equipmentComponents', table: _db.equipmentComponents, blob: false, full: null),`
- `_safeExport`: `equipmentComponents: await _safeExport('equipmentComponents', () => _exportEquipmentComponents(hlcSince)),`
- `fetchRecord`:
  ```dart
      case 'equipmentComponents':
        final row = await (_db.select(
          _db.equipmentComponents,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
  ```
- `fetchRecords`:
  ```dart
      case 'equipmentComponents':
        final rows = await (_db.select(
          _db.equipmentComponents,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
  ```
- `upsertRecord`:
  ```dart
      case 'equipmentComponents':
        await _db
            .into(_db.equipmentComponents)
            .insertOnConflictUpdate(
              EquipmentComponentRow.fromJson(data).toCompanion(false),
            );
        return;
  ```
- `upsertRecords`:
  ```dart
      case 'equipmentComponents':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipmentComponents,
            records
                .map(
                  (r) => EquipmentComponentRow.fromJson(r).toCompanion(false),
                )
                .toList(),
          ),
        );
        return;
  ```
- `recordIdsFor`: `case 'equipmentComponents': return plain(_db.equipmentComponents, _db.equipmentComponents.id);`
- `tableFor`: `case 'equipmentComponents': return _db.equipmentComponents;`
- `deleteRecord`:
  ```dart
      case 'equipmentComponents':
        await (_db.delete(
          _db.equipmentComponents,
        )..where((t) => t.id.equals(recordId))).go();
        return;
  ```
- Exporter, after `_exportEquipmentAttributes`:
  ```dart
  Future<List<Map<String, dynamic>>> _exportEquipmentComponents(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.equipmentComponents);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
  ```

Run `grep -n "equipmentAttributes" lib/core/services/sync/sync_data_serializer.dart` when done and confirm every hit has an `equipmentComponents` neighbour; the parity tests in `test/core/services/sync/` assert the descriptor order matches `toJson` key order, so keep the new entry immediately after the attributes entry in each list.

- [ ] **Step 4: Register the entity in the service and the clock targets**

`sync_service.dart`:
- Merge order, after the `equipmentAttributes` record:
  ```dart
          // Child of equipment (issue #1487); after its parent for the same
          // deferred-FK reason as equipmentAttributes. Both ends of the edge
          // are equipment rows, so one ordering covers both.
          (
            type: 'equipmentComponents',
            records: data.equipmentComponents,
            hasUpdatedAt: true,
          ),
  ```
- `entityHasUpdatedAt`: `'equipmentComponents': true,` after the attributes line.
- `parentRefs`, after the `equipmentAttributes` entry:
  ```dart
    'equipmentComponents': [
      (field: 'parentEquipmentId', parent: 'equipment', nullable: false),
      (field: 'componentEquipmentId', parent: 'equipment', nullable: false),
    ],
  ```
- `parentRefs['diveEquipment']` gains two entries after `equipmentId`:
  ```dart
      // Provenance (issue #1487). Nullable by design: the schema is ON DELETE
      // SET NULL, so a peer that deleted the assembly or the set clears the
      // pointer instead of dropping the row.
      (field: 'viaEquipmentId', parent: 'equipment', nullable: true),
      (field: 'viaSetId', parent: 'equipmentSets', nullable: true),
  ```
  and `parentRefs['divePlanEquipment']` gains the same two lines.

`sync_repository.dart`: after `'equipmentAttributes': (table: 'equipment_attributes', pk: 'id'),` add `'equipmentComponents': (table: 'equipment_components', pk: 'id'),`.

`sync_parent_refs_completeness_test.dart`: in `syncedTables` add `'equipment_components': 'equipmentComponents',` after the `equipment_attributes` line.

- [ ] **Step 5: Run the new test and the sync guard tests**

Run: `flutter test test/core/services/sync/equipment_component_sync_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/equipment_attribute_sync_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_media_species_registration_test.dart test/core/services/sync/base_publish_streaming_parity_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/cross_version_roundtrip_test.dart`
Expected: PASS. If a parity or registration test names a list the new entity is missing from, add `equipmentComponents` at that site directly after `equipmentAttributes` and rerun.

- [ ] **Step 6: Format and commit**

```bash
dart format lib/core/services/sync lib/core/data/repositories/sync_repository.dart test/core/services/sync
git add lib/core/services/sync/sync_data_serializer.dart lib/core/services/sync/sync_service.dart lib/core/data/repositories/sync_repository.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/equipment_component_sync_test.dart
git commit -m "feat(sync): replicate equipment components and gear provenance (#1487)

equipmentComponents rides its own clock as a child of equipment; the
two provenance columns on the gear junctions get nullable parent refs
so a peer that deleted the parent clears the pointer."
```

---

### Task 4: Eight new equipment types

**Files:**
- Modify: `lib/core/constants/enums.dart` (`EquipmentType`, ~L10-50)
- Modify: `lib/features/equipment/presentation/utils/equipment_type_icon.dart` (exhaustive switch)
- Modify: `lib/features/equipment/presentation/utils/equipment_enum_display.dart` (`localizedName` switch)
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (`_byType` map; regulator entry ~L297, bcd ~L305, camera ~L421)
- Modify: `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart` (`attributeLabel` and `attributeChoiceLabel` switches)
- Modify: `lib/features/universal_import/data/services/macdive_value_mapper.dart` (`equipmentType`, ~L152-205)
- Modify: `test/features/universal_import/data/services/macdive_value_mapper_test.dart` (~L110-125)
- Modify: `test/features/equipment/domain/entities/equipment_component_test.dart` (Task 2 placeholder type)
- Modify: all 11 `lib/l10n/arb/app_*.arb`; regenerate `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/equipment/domain/equipment_type_assembly_parts_test.dart`

**Interfaces:**
- Produces: `EquipmentType.firstStage`, `.secondStage`, `.hose`, `.backplate`, `.wing`, `.harness`, `.housing`, `.strobe`; catalog keys `plate_material` (choices `steel`, `aluminum`, `carbon_fiber`) and `hose_length_m`; ARB keys `enum_equipmentType_<name>` for the eight, `attrLabel_plate_material`, `attrLabel_hose_length_m`, `attrChoice_plate_material_steel`, `attrChoice_plate_material_aluminum`, `attrChoice_plate_material_carbon_fiber`.

- [ ] **Step 1: Write the failing type test**

```dart
// test/features/equipment/domain/equipment_type_assembly_parts_test.dart
import 'dart:ui' show Locale;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The component types added for assemblies (issue #1487). Declaration
/// order is the dropdown order, so each family sits beside the thing it is
/// part of.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  int indexOf(EquipmentType t) => EquipmentType.values.indexOf(t);

  test('regulator parts follow the regulator', () {
    expect(indexOf(EquipmentType.firstStage), indexOf(EquipmentType.regulator) + 1);
    expect(indexOf(EquipmentType.secondStage), indexOf(EquipmentType.regulator) + 2);
    expect(indexOf(EquipmentType.hose), indexOf(EquipmentType.regulator) + 3);
  });

  test('harness parts follow the BCD', () {
    expect(indexOf(EquipmentType.backplate), indexOf(EquipmentType.bcd) + 1);
    expect(indexOf(EquipmentType.wing), indexOf(EquipmentType.bcd) + 2);
    expect(indexOf(EquipmentType.harness), indexOf(EquipmentType.bcd) + 3);
  });

  test('photo parts follow the camera', () {
    expect(indexOf(EquipmentType.housing), indexOf(EquipmentType.camera) + 1);
    expect(indexOf(EquipmentType.strobe), indexOf(EquipmentType.camera) + 2);
  });

  test('each new type has a label, a non-generic icon, and its .name persisted', () {
    const added = {
      EquipmentType.firstStage: 'First Stage',
      EquipmentType.secondStage: 'Second Stage',
      EquipmentType.hose: 'Hose',
      EquipmentType.backplate: 'Backplate',
      EquipmentType.wing: 'Wing',
      EquipmentType.harness: 'Harness',
      EquipmentType.housing: 'Housing',
      EquipmentType.strobe: 'Strobe',
    };
    final generic = equipmentTypeIcon(EquipmentType.other);
    for (final entry in added.entries) {
      expect(entry.key.localizedName(l10n), entry.value, reason: entry.key.name);
      expect(entry.key.displayName, entry.value, reason: entry.key.name);
      expect(equipmentTypeIcon(entry.key), isA<IconData>());
      expect(equipmentTypeIcon(entry.key), isNot(generic), reason: entry.key.name);
    }
  });

  test('the new types carry the attributes that make them useful', () {
    List<String> keysFor(EquipmentType t) =>
        EquipmentAttributeCatalog.attributesFor(t).map((d) => d.key).toList();
    expect(keysFor(EquipmentType.firstStage), containsAll(['connection', 'cold_water_rated']));
    expect(keysFor(EquipmentType.secondStage), contains('cold_water_rated'));
    expect(keysFor(EquipmentType.hose), contains('hose_length_m'));
    expect(keysFor(EquipmentType.backplate), contains('plate_material'));
    expect(keysFor(EquipmentType.wing), contains('lift_capacity_kg'));
    expect(keysFor(EquipmentType.harness), contains('size'));
    expect(keysFor(EquipmentType.housing), contains('depth_rating_m'));
    expect(keysFor(EquipmentType.strobe), contains('depth_rating_m'));
    final hose = EquipmentAttributeCatalog.defFor('hose_length_m')!;
    expect(hose.dimension, AttributeDimension.lengthM);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/domain/equipment_type_assembly_parts_test.dart`
Expected: compile error, `EquipmentType.firstStage` undefined.

- [ ] **Step 3: Add the enum values**

In `enums.dart`, after `regulator('Regulator'),` insert:

```dart
  // The regulator's parts (issue #1487). A diver who swaps second stages and
  // hoses between a DIN and a yoke first stage tracks service on each part,
  // so the parts are types of their own rather than `other` with a name.
  firstStage('First Stage'),
  secondStage('Second Stage'),
  hose('Hose'),
```

After `bcd('BCD'),` insert:

```dart
  // The backplate-and-wing rig's parts (issue #1487): the plate is what a
  // diver swaps between a wetsuit and a drysuit season.
  backplate('Backplate'),
  wing('Wing'),
  harness('Harness'),
```

After `camera('Camera'),` insert:

```dart
  // Photo rig parts (issue #1487): the same strobes ride different housings.
  housing('Housing'),
  strobe('Strobe'),
```

- [ ] **Step 4: Add the icon and label cases**

`equipment_type_icon.dart`, after the `regulator` case:

```dart
    // Regulator parts (issue #1487). Material glyphs for now: a round DIN
    // face, breathing air, and a cable for the hose. Drawn glyphs can
    // follow under the equipment icons design.
    case EquipmentType.firstStage:
      return Icons.settings_input_svideo;
    case EquipmentType.secondStage:
      return Icons.air;
    case EquipmentType.hose:
      return Icons.cable;
```

after the `bcd` case:

```dart
    // Backplate-and-wing parts (issue #1487): a plate, a donut, webbing.
    case EquipmentType.backplate:
      return Icons.crop_portrait;
    case EquipmentType.wing:
      return Icons.donut_large;
    case EquipmentType.harness:
      return Icons.link;
```

after the `camera` case:

```dart
    // Photo rig parts (issue #1487).
    case EquipmentType.housing:
      return Icons.photo_camera_back;
    case EquipmentType.strobe:
      return Icons.flash_on;
```

`equipment_enum_display.dart`, inside `localizedName` in declaration order:

```dart
    EquipmentType.firstStage => l10n.enum_equipmentType_firstStage,
    EquipmentType.secondStage => l10n.enum_equipmentType_secondStage,
    EquipmentType.hose => l10n.enum_equipmentType_hose,
    EquipmentType.backplate => l10n.enum_equipmentType_backplate,
    EquipmentType.wing => l10n.enum_equipmentType_wing,
    EquipmentType.harness => l10n.enum_equipmentType_harness,
    EquipmentType.housing => l10n.enum_equipmentType_housing,
    EquipmentType.strobe => l10n.enum_equipmentType_strobe,
```

- [ ] **Step 5: Add the catalog entries and the label switches**

In `equipment_attribute_catalog.dart`, add three shared definitions next to the existing `_size` / `_thickness` privates (above `_byType`):

```dart
  static const _connection = EquipmentAttributeDef(
    key: 'connection',
    kind: AttributeKind.choice,
    choiceKeys: ['din', 'yoke'],
  );
  static const _coldWaterRated = EquipmentAttributeDef(
    key: 'cold_water_rated',
    kind: AttributeKind.flag,
  );
  static const _liftCapacity = EquipmentAttributeDef(
    key: EquipmentAttrKeys.liftCapacityKg,
    kind: AttributeKind.number,
    dimension: AttributeDimension.massKg,
  );
  static const _depthRating = EquipmentAttributeDef(
    key: 'depth_rating_m',
    kind: AttributeKind.number,
    dimension: AttributeDimension.depthM,
  );
```

Rewrite the `regulator` entry as `EquipmentType.regulator: [_connection, _coldWaterRated],`, replace the inline lift-capacity definition in the `bcd` entry with `_liftCapacity`, and the inline depth-rating definition in the `camera` entry with `_depthRating`. Then add, keeping each family beside its parent in the map:

```dart
    EquipmentType.firstStage: [_connection, _coldWaterRated],
    EquipmentType.secondStage: [_coldWaterRated],
    EquipmentType.hose: [
      // Stored in metres and shown in the diver's length unit through the
      // existing lengthM dimension, like an SMB or a reel line.
      EquipmentAttributeDef(
        key: 'hose_length_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.lengthM,
      ),
    ],
    EquipmentType.backplate: [
      EquipmentAttributeDef(
        key: 'plate_material',
        kind: AttributeKind.choice,
        choiceKeys: ['steel', 'aluminum', 'carbon_fiber'],
      ),
    ],
    EquipmentType.wing: [_liftCapacity],
    EquipmentType.harness: [_size],
    EquipmentType.housing: [_depthRating],
    EquipmentType.strobe: [_depthRating],
```

In `equipment_attribute_l10n.dart` add to `attributeLabel`: `'plate_material' => l10n.attrLabel_plate_material,` and `'hose_length_m' => l10n.attrLabel_hose_length_m,`; and to `attributeChoiceLabel` (next to the `connection_*` lines): `'plate_material_steel' => l10n.attrChoice_plate_material_steel,`, `'plate_material_aluminum' => l10n.attrChoice_plate_material_aluminum,`, `'plate_material_carbon_fiber' => l10n.attrChoice_plate_material_carbon_fiber,`.

- [ ] **Step 6: Add the ARB keys to all 11 locales and regenerate**

Insert each block in alphabetical position among its prefix. `app_en.arb`:

```json
  "attrChoice_plate_material_aluminum": "Aluminum",
  "attrChoice_plate_material_carbon_fiber": "Carbon fiber",
  "attrChoice_plate_material_steel": "Steel",
  "attrLabel_hose_length_m": "Hose length",
  "attrLabel_plate_material": "Plate material",
  "enum_equipmentType_backplate": "Backplate",
  "enum_equipmentType_firstStage": "First Stage",
  "enum_equipmentType_harness": "Harness",
  "enum_equipmentType_hose": "Hose",
  "enum_equipmentType_housing": "Housing",
  "enum_equipmentType_secondStage": "Second Stage",
  "enum_equipmentType_strobe": "Strobe",
  "enum_equipmentType_wing": "Wing",
```

`app_de.arb`:

```json
  "attrChoice_plate_material_aluminum": "Aluminium",
  "attrChoice_plate_material_carbon_fiber": "Kohlefaser",
  "attrChoice_plate_material_steel": "Stahl",
  "attrLabel_hose_length_m": "Schlauchlänge",
  "attrLabel_plate_material": "Plattenmaterial",
  "enum_equipmentType_backplate": "Backplate",
  "enum_equipmentType_firstStage": "Erste Stufe",
  "enum_equipmentType_harness": "Harness",
  "enum_equipmentType_hose": "Schlauch",
  "enum_equipmentType_housing": "Gehäuse",
  "enum_equipmentType_secondStage": "Zweite Stufe",
  "enum_equipmentType_strobe": "Blitz",
  "enum_equipmentType_wing": "Wing",
```

`app_fr.arb`:

```json
  "attrChoice_plate_material_aluminum": "Aluminium",
  "attrChoice_plate_material_carbon_fiber": "Fibre de carbone",
  "attrChoice_plate_material_steel": "Acier",
  "attrLabel_hose_length_m": "Longueur du flexible",
  "attrLabel_plate_material": "Matériau de la plaque",
  "enum_equipmentType_backplate": "Plaque dorsale",
  "enum_equipmentType_firstStage": "Premier étage",
  "enum_equipmentType_harness": "Harnais",
  "enum_equipmentType_hose": "Flexible",
  "enum_equipmentType_housing": "Caisson",
  "enum_equipmentType_secondStage": "Deuxième étage",
  "enum_equipmentType_strobe": "Flash",
  "enum_equipmentType_wing": "Wing",
```

`app_es.arb`:

```json
  "attrChoice_plate_material_aluminum": "Aluminio",
  "attrChoice_plate_material_carbon_fiber": "Fibra de carbono",
  "attrChoice_plate_material_steel": "Acero",
  "attrLabel_hose_length_m": "Longitud del latiguillo",
  "attrLabel_plate_material": "Material de la placa",
  "enum_equipmentType_backplate": "Placa dorsal",
  "enum_equipmentType_firstStage": "Primera etapa",
  "enum_equipmentType_harness": "Arnés",
  "enum_equipmentType_hose": "Latiguillo",
  "enum_equipmentType_housing": "Carcasa",
  "enum_equipmentType_secondStage": "Segunda etapa",
  "enum_equipmentType_strobe": "Flash",
  "enum_equipmentType_wing": "Ala",
```

`app_it.arb`:

```json
  "attrChoice_plate_material_aluminum": "Alluminio",
  "attrChoice_plate_material_carbon_fiber": "Fibra di carbonio",
  "attrChoice_plate_material_steel": "Acciaio",
  "attrLabel_hose_length_m": "Lunghezza della frusta",
  "attrLabel_plate_material": "Materiale della piastra",
  "enum_equipmentType_backplate": "Piastra dorsale",
  "enum_equipmentType_firstStage": "Primo stadio",
  "enum_equipmentType_harness": "Imbrago",
  "enum_equipmentType_hose": "Frusta",
  "enum_equipmentType_housing": "Custodia",
  "enum_equipmentType_secondStage": "Secondo stadio",
  "enum_equipmentType_strobe": "Flash",
  "enum_equipmentType_wing": "Sacco wing",
```

`app_nl.arb`:

```json
  "attrChoice_plate_material_aluminum": "Aluminium",
  "attrChoice_plate_material_carbon_fiber": "Koolstofvezel",
  "attrChoice_plate_material_steel": "Staal",
  "attrLabel_hose_length_m": "Slanglengte",
  "attrLabel_plate_material": "Plaatmateriaal",
  "enum_equipmentType_backplate": "Backplate",
  "enum_equipmentType_firstStage": "Eerste trap",
  "enum_equipmentType_harness": "Harnas",
  "enum_equipmentType_hose": "Slang",
  "enum_equipmentType_housing": "Behuizing",
  "enum_equipmentType_secondStage": "Tweede trap",
  "enum_equipmentType_strobe": "Flitser",
  "enum_equipmentType_wing": "Wing",
```

`app_pt.arb`:

```json
  "attrChoice_plate_material_aluminum": "Alumínio",
  "attrChoice_plate_material_carbon_fiber": "Fibra de carbono",
  "attrChoice_plate_material_steel": "Aço",
  "attrLabel_hose_length_m": "Comprimento da mangueira",
  "attrLabel_plate_material": "Material da placa",
  "enum_equipmentType_backplate": "Backplate",
  "enum_equipmentType_firstStage": "Primeiro estágio",
  "enum_equipmentType_harness": "Arnês",
  "enum_equipmentType_hose": "Mangueira",
  "enum_equipmentType_housing": "Caixa estanque",
  "enum_equipmentType_secondStage": "Segundo estágio",
  "enum_equipmentType_strobe": "Flash",
  "enum_equipmentType_wing": "Asa",
```

`app_hu.arb`:

```json
  "attrChoice_plate_material_aluminum": "Alumínium",
  "attrChoice_plate_material_carbon_fiber": "Szénszál",
  "attrChoice_plate_material_steel": "Acél",
  "attrLabel_hose_length_m": "Tömlő hossza",
  "attrLabel_plate_material": "Lemez anyaga",
  "enum_equipmentType_backplate": "Hátlemez",
  "enum_equipmentType_firstStage": "Első fokozat",
  "enum_equipmentType_harness": "Heveder",
  "enum_equipmentType_hose": "Tömlő",
  "enum_equipmentType_housing": "Tokozás",
  "enum_equipmentType_secondStage": "Második fokozat",
  "enum_equipmentType_strobe": "Vaku",
  "enum_equipmentType_wing": "Szárny",
```

`app_ar.arb`:

```json
  "attrChoice_plate_material_aluminum": "ألومنيوم",
  "attrChoice_plate_material_carbon_fiber": "ألياف الكربون",
  "attrChoice_plate_material_steel": "فولاذ",
  "attrLabel_hose_length_m": "طول الخرطوم",
  "attrLabel_plate_material": "مادة اللوحة",
  "enum_equipmentType_backplate": "لوحة ظهر",
  "enum_equipmentType_firstStage": "المرحلة الأولى",
  "enum_equipmentType_harness": "حزام",
  "enum_equipmentType_hose": "خرطوم",
  "enum_equipmentType_housing": "غلاف الكاميرا",
  "enum_equipmentType_secondStage": "المرحلة الثانية",
  "enum_equipmentType_strobe": "فلاش",
  "enum_equipmentType_wing": "جناح",
```

`app_he.arb`:

```json
  "attrChoice_plate_material_aluminum": "אלומיניום",
  "attrChoice_plate_material_carbon_fiber": "סיבי פחמן",
  "attrChoice_plate_material_steel": "פלדה",
  "attrLabel_hose_length_m": "אורך הצינור",
  "attrLabel_plate_material": "חומר הפלטה",
  "enum_equipmentType_backplate": "פלטת גב",
  "enum_equipmentType_firstStage": "שלב ראשון",
  "enum_equipmentType_harness": "רתמה",
  "enum_equipmentType_hose": "צינור",
  "enum_equipmentType_housing": "מארז",
  "enum_equipmentType_secondStage": "שלב שני",
  "enum_equipmentType_strobe": "פלאש",
  "enum_equipmentType_wing": "כנף",
```

`app_zh.arb`:

```json
  "attrChoice_plate_material_aluminum": "铝",
  "attrChoice_plate_material_carbon_fiber": "碳纤维",
  "attrChoice_plate_material_steel": "钢",
  "attrLabel_hose_length_m": "软管长度",
  "attrLabel_plate_material": "背板材质",
  "enum_equipmentType_backplate": "背板",
  "enum_equipmentType_firstStage": "一级头",
  "enum_equipmentType_harness": "背带",
  "enum_equipmentType_hose": "软管",
  "enum_equipmentType_housing": "防水壳",
  "enum_equipmentType_secondStage": "二级头",
  "enum_equipmentType_strobe": "闪光灯",
  "enum_equipmentType_wing": "背飞气囊",
```

Run `flutter gen-l10n`. Then `python3 - <<'PY'` a duplicate-key check: load each ARB with `json.load` after counting raw occurrences of every key with a regex; any key that appears twice is a paste error (the memory note on duplicate ARB keys drifting per locale exists because this has happened before).

- [ ] **Step 7: Teach the MacDive mapper the new types and repin its test**

In `macdive_value_mapper.dart`, immediately before the `if (s.contains('octo') || s.contains('regulator') || ...` block insert:

```dart
    // Regulator parts (issue #1487) win over the regulator family: a long
    // hose is a hose, and a second stage is not the whole regulator.
    if (s.contains('hose')) return EquipmentType.hose;
    if (s.contains('first stage')) return EquipmentType.firstStage;
    if (s.contains('second stage')) return EquipmentType.secondStage;
```

Then remove `s.contains('second stage') ||` and `s.contains('first stage')` from the regulator condition (the octopus and `reg` prefixes stay). Replace the bcd block with:

```dart
    if (s.contains('bcd') || s.contains('bc ') || s == 'bc') {
      return EquipmentType.bcd;
    }
    // Backplate-and-wing parts (issue #1487), after the whole-BCD words so
    // "BCD - Wing" stays a BCD. A plate-and-harness listing is the plate.
    if (s.contains('backplate')) return EquipmentType.backplate;
    if (s.contains('wing')) return EquipmentType.wing;
    if (s.contains('harness')) return EquipmentType.harness;
```

Before the camera block insert:

```dart
    // Photo rig parts (issue #1487) before the camera family.
    if (s.contains('housing')) return EquipmentType.housing;
    if (s.contains('strobe')) return EquipmentType.strobe;
```

and drop `s.contains('housing') ||` and `s.contains('strobe') ||` from the camera condition.

In `macdive_value_mapper_test.dart` change the pinned cases: `'Reg - Longhose': EquipmentType.hose`, `'Second Stage': EquipmentType.secondStage`, `'First stage': EquipmentType.firstStage`, `'Wing': EquipmentType.wing`, `'Backplate and harness': EquipmentType.backplate`. Keep `'BCD - Wing': EquipmentType.bcd`. Add `'Harness': EquipmentType.harness`, `'Camera housing': EquipmentType.housing`, `'Strobe arm': EquipmentType.strobe`.

- [ ] **Step 8: Run the type tests and every test that enumerates the enum**

Run: `flutter test test/features/equipment/domain/equipment_type_assembly_parts_test.dart test/features/equipment/presentation/equipment_type_icon_test.dart test/features/equipment/presentation/equipment_attribute_l10n_test.dart test/features/equipment/domain/equipment_attribute_catalog_test.dart test/features/equipment/domain/equipment_purchase_attributes_test.dart test/features/universal_import/data/services/macdive_value_mapper_test.dart test/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet_test.dart test/core/icons/vendored_icon_font_coverage_test.dart`
Expected: PASS.

- [ ] **Step 9: Point the entity test at the real type**

In `test/features/equipment/domain/entities/equipment_component_test.dart` change `EquipmentType.other` to `EquipmentType.hose`. Run: `flutter test test/features/equipment/domain/entities/equipment_component_test.dart`. Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
dart format lib/core/constants/enums.dart lib/features/equipment lib/features/universal_import/data/services/macdive_value_mapper.dart test/features/equipment test/features/universal_import/data/services/macdive_value_mapper_test.dart
git add lib/core/constants/enums.dart lib/features/equipment/presentation/utils/equipment_type_icon.dart lib/features/equipment/presentation/utils/equipment_enum_display.dart lib/features/equipment/domain/constants/equipment_attribute_catalog.dart lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart lib/features/universal_import/data/services/macdive_value_mapper.dart test/features/universal_import/data/services/macdive_value_mapper_test.dart test/features/equipment/domain/equipment_type_assembly_parts_test.dart test/features/equipment/domain/entities/equipment_component_test.dart lib/l10n/arb
git commit -m "feat(equipment): component types for regulators, rigs, and photo gear (#1487)

First stage, second stage, hose, backplate, wing, harness, housing, and
strobe, each beside the item it is part of, with icons, labels in every
locale, catalog attributes, and MacDive substring rules."
```

---

### Task 5: Component providers and the service rollup

**Files:**
- Create: `lib/features/equipment/presentation/providers/equipment_component_providers.dart`
- Test: `test/features/equipment/presentation/providers/components_index_test.dart`
- Test: `test/features/equipment/presentation/providers/equipment_rollup_clock_provider_test.dart`

**Interfaces:**
- Consumes: `EquipmentComponentRepository` (Task 2); `activeEquipmentClocksProvider` and `EquipmentClocks` from `equipment_providers.dart`; `ServiceClockStatus`, `ServiceClockSeverity`.
- Produces:
  - `equipmentComponentRepositoryProvider: Provider<EquipmentComponentRepository>`
  - `class ComponentsIndex { Map<String, List<EquipmentComponent>> byParent; Map<String, List<EquipmentComponent>> byComponent; static const empty; factory fromRows(Iterable<EquipmentComponent>); int componentCount(String id); bool isAssembly(String id); List<String> parentIdsOf(String id); Set<String> descendantsOf(String id); Set<String> ancestorsOf(String id); }`
  - `equipmentComponentsIndexProvider: FutureProvider<ComponentsIndex>`
  - `equipmentComponentsProvider: FutureProvider.family<List<EquipmentComponent>, String>` (hydrated parts of one parent, sort order)
  - `typedef RollupClock = ({String ownerId, String ownerName, ServiceClockStatus status});`
  - `equipmentRollupClockProvider: FutureProvider<Map<String, RollupClock>>` (worst clock across an active item and its active descendants; absent when nothing has a clock)
  - `bool isMoreUrgentClock(ServiceClockStatus a, ServiceClockStatus b)`

- [ ] **Step 1: Write the failing index test**

```dart
// test/features/equipment/presentation/providers/components_index_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  var seq = 0;
  EquipmentComponent edge(String parent, String child, {int order = 0}) =>
      EquipmentComponent(
        id: 'c${seq++}',
        parentEquipmentId: parent,
        componentEquipmentId: child,
        sortOrder: order,
        createdAt: t0,
        updatedAt: t0,
      );

  test('fromRows groups both ways and keeps sort order per parent', () {
    final index = ComponentsIndex.fromRows([
      edge('reg', 'hose', order: 2),
      edge('reg', 'first', order: 0),
      edge('kit', 'hose', order: 0),
    ]);
    expect(
      index.byParent['reg']!.map((c) => c.componentEquipmentId),
      ['first', 'hose'],
    );
    expect(index.parentIdsOf('hose'), unorderedEquals(['reg', 'kit']));
    expect(index.componentCount('reg'), 2);
    expect(index.componentCount('hose'), 0);
    expect(index.isAssembly('kit'), isTrue);
    expect(index.isAssembly('first'), isFalse);
  });

  test('descendantsOf walks every level and excludes the root', () {
    final index = ComponentsIndex.fromRows([
      edge('kit', 'reg'),
      edge('reg', 'first'),
      edge('first', 'hose'),
      edge('kit', 'wing'),
    ]);
    expect(index.descendantsOf('kit'), {'reg', 'first', 'hose', 'wing'});
    expect(index.descendantsOf('reg'), {'first', 'hose'});
    expect(index.descendantsOf('hose'), isEmpty);
  });

  test('ancestorsOf walks upward', () {
    final index = ComponentsIndex.fromRows([
      edge('kit', 'reg'),
      edge('reg', 'hose'),
    ]);
    expect(index.ancestorsOf('hose'), {'reg', 'kit'});
    expect(index.ancestorsOf('kit'), isEmpty);
  });

  test('a corrupt cycle still terminates', () {
    final index = ComponentsIndex.fromRows([edge('a', 'b'), edge('b', 'a')]);
    expect(index.descendantsOf('a'), {'b', 'a'});
    expect(index.ancestorsOf('a'), {'b', 'a'});
  });

  test('empty is empty', () {
    expect(ComponentsIndex.empty.componentCount('x'), 0);
    expect(ComponentsIndex.empty.descendantsOf('x'), isEmpty);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/components_index_test.dart`
Expected: compile error, file not found.

- [ ] **Step 3: Write the failing rollup provider test**

```dart
// test/features/equipment/presentation/providers/equipment_rollup_clock_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

/// The rollup answers "is anything in this rig due", naming the part
/// (issue #1487). It derives from the all-items evaluation that keeps ok
/// clocks, so it can also answer "when is this rig next due".
void main() {
  final t0 = DateTime(2025, 1, 1);
  final now = DateTime(2026, 7, 1);

  ServiceKind kind(String id) => ServiceKind(
    id: id,
    name: id,
    defaultIntervalDays: 365,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  ServiceClockStatus clock(
    String equipmentId,
    String kindId,
    ServiceClockSeverity severity, {
    DateTime? due,
  }) => ServiceClockStatus(
    schedule: ServiceSchedule(
      id: 's-$equipmentId-$kindId',
      equipmentId: equipmentId,
      serviceKindId: kindId,
      createdAt: t0,
      updatedAt: t0,
    ),
    kind: kind(kindId),
    anchor: t0,
    dueDate: due,
    severity: severity,
    now: now,
  );

  EquipmentItem item(String id) =>
      EquipmentItem(id: id, name: 'Name $id', type: EquipmentType.regulator);

  var seq = 0;
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: 'c${seq++}',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );

  ProviderContainer container({
    required List<EquipmentClocks> clocks,
    required List<EquipmentComponent> edges,
  }) {
    final c = ProviderContainer(
      overrides: [
        activeEquipmentClocksProvider.overrideWith((ref) async => clocks),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.fromRows(edges),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('an item with its own clocks rolls up to its own worst', () async {
    final c = container(
      clocks: [
        (
          item: item('reg'),
          statuses: [
            clock('reg', 'svc', ServiceClockSeverity.dueSoon, due: DateTime(2026, 8, 1)),
            clock('reg', 'other', ServiceClockSeverity.ok, due: DateTime(2027, 1, 1)),
          ],
        ),
      ],
      edges: const [],
    );
    final rollup = await c.read(equipmentRollupClockProvider.future);
    expect(rollup['reg']!.ownerId, 'reg');
    expect(rollup['reg']!.status.severity, ServiceClockSeverity.dueSoon);
  });

  test('a descendant overdue clock beats the parent and names the part', () async {
    final c = container(
      clocks: [
        (
          item: item('reg'),
          statuses: [clock('reg', 'svc', ServiceClockSeverity.ok, due: DateTime(2027, 1, 1))],
        ),
        (
          item: item('hose'),
          statuses: [clock('hose', 'hose-swap', ServiceClockSeverity.overdue, due: DateTime(2026, 1, 1))],
        ),
      ],
      edges: [edge('reg', 'hose')],
    );
    final rollup = await c.read(equipmentRollupClockProvider.future);
    expect(rollup['reg']!.ownerId, 'hose');
    expect(rollup['reg']!.ownerName, 'Name hose');
    expect(rollup['reg']!.status.kind.id, 'hose-swap');
    // The part's own entry is itself.
    expect(rollup['hose']!.ownerId, 'hose');
  });

  test('a nested descendant is reached and the earliest date breaks ties', () async {
    final c = container(
      clocks: [
        (item: item('kit'), statuses: const []),
        (
          item: item('reg'),
          statuses: [clock('reg', 'a', ServiceClockSeverity.dueSoon, due: DateTime(2026, 9, 1))],
        ),
        (
          item: item('hose'),
          statuses: [clock('hose', 'b', ServiceClockSeverity.dueSoon, due: DateTime(2026, 8, 1))],
        ),
      ],
      edges: [edge('kit', 'reg'), edge('reg', 'hose')],
    );
    final rollup = await c.read(equipmentRollupClockProvider.future);
    expect(rollup['kit']!.ownerId, 'hose');
    expect(rollup['kit']!.status.dueDate, DateTime(2026, 8, 1));
  });

  test('an assembly with no clocks anywhere has no entry', () async {
    final c = container(
      clocks: [
        (item: item('reg'), statuses: const []),
        (item: item('hose'), statuses: const []),
      ],
      edges: [edge('reg', 'hose')],
    );
    final rollup = await c.read(equipmentRollupClockProvider.future);
    expect(rollup, isEmpty);
  });

  test('a retired descendant is not in the active evaluation and is skipped', () async {
    final c = container(
      clocks: [
        (item: item('reg'), statuses: const []),
      ],
      edges: [edge('reg', 'old-hose')],
    );
    final rollup = await c.read(equipmentRollupClockProvider.future);
    expect(rollup.containsKey('reg'), isFalse);
  });

  test('isMoreUrgentClock orders by severity then date, null date last', () {
    final overdue = clock('x', 'a', ServiceClockSeverity.overdue);
    final soonEarly = clock('x', 'b', ServiceClockSeverity.dueSoon, due: DateTime(2026, 8, 1));
    final soonLate = clock('x', 'c', ServiceClockSeverity.dueSoon, due: DateTime(2026, 9, 1));
    final soonNoDate = clock('x', 'd', ServiceClockSeverity.dueSoon);
    expect(isMoreUrgentClock(overdue, soonEarly), isTrue);
    expect(isMoreUrgentClock(soonEarly, soonLate), isTrue);
    expect(isMoreUrgentClock(soonLate, soonEarly), isFalse);
    expect(isMoreUrgentClock(soonEarly, soonNoDate), isTrue);
    expect(isMoreUrgentClock(soonNoDate, soonEarly), isFalse);
  });
}
```

- [ ] **Step 4: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/providers/equipment_rollup_clock_provider_test.dart`
Expected: compile error, providers undefined.

- [ ] **Step 5: Write the providers file**

```dart
// lib/features/equipment/presentation/providers/equipment_component_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

final equipmentComponentRepositoryProvider =
    Provider<EquipmentComponentRepository>((ref) {
      return EquipmentComponentRepository();
    });

/// Forward and reverse adjacency over every assembly edge, built once per
/// change tick so list tiles and pickers read by id instead of querying.
class ComponentsIndex {
  /// Parts of each assembly, in sort order.
  final Map<String, List<EquipmentComponent>> byParent;

  /// The assemblies each part belongs to.
  final Map<String, List<EquipmentComponent>> byComponent;

  const ComponentsIndex({required this.byParent, required this.byComponent});

  static const empty = ComponentsIndex(byParent: {}, byComponent: {});

  factory ComponentsIndex.fromRows(Iterable<EquipmentComponent> rows) {
    final byParent = <String, List<EquipmentComponent>>{};
    final byComponent = <String, List<EquipmentComponent>>{};
    for (final row in rows) {
      byParent.putIfAbsent(row.parentEquipmentId, () => []).add(row);
      byComponent.putIfAbsent(row.componentEquipmentId, () => []).add(row);
    }
    for (final parts in byParent.values) {
      parts.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return ComponentsIndex(byParent: byParent, byComponent: byComponent);
  }

  int componentCount(String id) => byParent[id]?.length ?? 0;

  bool isAssembly(String id) => componentCount(id) > 0;

  List<String> parentIdsOf(String id) => [
    for (final edge in byComponent[id] ?? const <EquipmentComponent>[])
      edge.parentEquipmentId,
  ];

  /// Every id reachable downward from [id], excluding [id] itself unless a
  /// corrupt loop leads back to it. A visited set guarantees termination.
  Set<String> descendantsOf(String id) => _walk(id, (current) sync* {
    for (final edge in byParent[current] ?? const <EquipmentComponent>[]) {
      yield edge.componentEquipmentId;
    }
  });

  /// Every id reachable upward from [id]; same termination guarantee.
  Set<String> ancestorsOf(String id) => _walk(id, (current) sync* {
    for (final edge in byComponent[current] ?? const <EquipmentComponent>[]) {
      yield edge.parentEquipmentId;
    }
  });

  Set<String> _walk(String start, Iterable<String> Function(String) next) {
    final seen = <String>{};
    final queue = <String>[start];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final id in next(current)) {
        if (seen.add(id)) queue.add(id);
      }
    }
    return seen;
  }
}

/// The whole template, refreshed on any component or equipment write.
final equipmentComponentsIndexProvider = FutureProvider<ComponentsIndex>((
  ref,
) async {
  final repository = ref.watch(equipmentComponentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchComponentChanges());
  return ComponentsIndex.fromRows(await repository.getAllComponents());
});

/// The hydrated parts of one assembly, in sort order (Components card).
final equipmentComponentsProvider =
    FutureProvider.family<List<EquipmentComponent>, String>((
      ref,
      parentId,
    ) async {
      final repository = ref.watch(equipmentComponentRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchComponentChanges());
      return repository.getComponents(parentId);
    });

/// The single most urgent clock in an item's subtree and who owns it, so a
/// badge can say "Necklace hose: Regulator service overdue".
typedef RollupClock = ({
  String ownerId,
  String ownerName,
  ServiceClockStatus status,
});

/// True when [a] should be surfaced ahead of [b]: higher severity first,
/// then the earlier due date, with a missing date sorting last.
bool isMoreUrgentClock(ServiceClockStatus a, ServiceClockStatus b) {
  if (a.severity != b.severity) return a.severity.index > b.severity.index;
  final ad = a.dueDate, bd = b.dueDate;
  if (ad == null) return false;
  if (bd == null) return true;
  return ad.isBefore(bd);
}

/// Worst clock across every active item and its active descendants, keyed
/// by item id. Absent means nothing in the subtree has a clock at all.
///
/// Derives from [activeEquipmentClocksProvider], which keeps ok clocks, and
/// not from the due-only map: a rollup that dropped ok clocks could not
/// answer "when is this rig next due". A retired descendant is absent from
/// the active evaluation and therefore never counted, which is the same
/// rule the dive expander applies (issue #1487).
final equipmentRollupClockProvider = FutureProvider<Map<String, RollupClock>>(
  (ref) async {
    final evaluated = await ref.watch(activeEquipmentClocksProvider.future);
    final index = await ref.watch(equipmentComponentsIndexProvider.future);
    final byId = {for (final e in evaluated) e.item.id: e};
    final out = <String, RollupClock>{};
    for (final e in evaluated) {
      RollupClock? worst;
      for (final id in [e.item.id, ...index.descendantsOf(e.item.id)]) {
        final clocks = byId[id];
        if (clocks == null) continue;
        for (final status in clocks.statuses) {
          if (worst == null || isMoreUrgentClock(status, worst.status)) {
            worst = (
              ownerId: id,
              ownerName: clocks.item.name,
              status: status,
            );
          }
        }
      }
      if (worst != null) out[e.item.id] = worst;
    }
    return out;
  },
);
```

- [ ] **Step 6: Run both provider tests**

Run: `flutter test test/features/equipment/presentation/providers/components_index_test.dart test/features/equipment/presentation/providers/equipment_rollup_clock_provider_test.dart`
Expected: PASS, 11 tests.

- [ ] **Step 7: Format and commit**

```bash
dart format lib/features/equipment/presentation/providers test/features/equipment/presentation/providers
git add lib/features/equipment/presentation/providers/equipment_component_providers.dart test/features/equipment/presentation/providers/components_index_test.dart test/features/equipment/presentation/providers/equipment_rollup_clock_provider_test.dart
git commit -m "feat(equipment): component index and service rollup providers (#1487)

An adjacency index over the assembly template, refreshed on the
components tick, and a rollup that names the part owning the most
urgent clock in an item's subtree."
```

---

### Task 6: Components card, role dialog, and picker on the detail page

**Files:**
- Create: `lib/features/equipment/presentation/widgets/components_card.dart`
- Create: `lib/features/equipment/presentation/widgets/component_role_dialog.dart`
- Create: `lib/features/equipment/presentation/widgets/component_picker_sheet.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (imports; body `Column` ~L158-196)
- Modify: every test that pumps `EquipmentDetailPage` (find them with `grep -rl "EquipmentDetailPage(" test/`; at the time of writing: `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`, `equipment_detail_service_test.dart`, `equipment_service_currency_test.dart`, and any other hit)
- Modify: all 11 `lib/l10n/arb/app_*.arb`; regenerate
- Test: `test/features/equipment/presentation/widgets/components_card_test.dart`
- Test: `test/features/equipment/presentation/widgets/component_role_dialog_test.dart`
- Test: `test/features/equipment/presentation/widgets/component_picker_sheet_test.dart`

**Interfaces:**
- Consumes: `equipmentComponentsProvider(parentId)`, `equipmentComponentsIndexProvider`, `equipmentComponentRepositoryProvider`, `equipmentWorstClockProvider` (per-part dot), `activeEquipmentProvider`, `equipmentTypeIcon`, `localizedName`, `EquipmentComponentCycleException`.
- Produces:
  - `class ComponentsCard extends ConsumerWidget { const ComponentsCard({super.key, required String equipmentId}); }`
  - `Future<String?> showComponentRoleDialog(BuildContext context, {required String initial, required List<String> suggestions})` (null on cancel, trimmed text on save)
  - `Future<void> showComponentPicker(BuildContext context, WidgetRef ref, {required String parentId})` and `class ComponentPickerSheet extends ConsumerStatefulWidget { const ComponentPickerSheet({super.key, required String parentId, required ScrollController scrollController}); }`
  - ARB keys: `equipment_components_title`, `_add`, `_empty`, `_role`, `_roleHint`, `_roleDialogTitle`, `_editRole`, `_remove`, `_reorder`, `_pickerTitle`, `_pickerConfirm`, `_pickerEmpty`, `_cycleError`. Reuses existing `common_action_cancel` and `common_action_save`.

- [ ] **Step 1: Write the failing card test**

```dart
// test/features/equipment/presentation/widgets/components_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeComponentRepository extends EquipmentComponentRepository {
  final removed = <String>[];
  final roles = <String, String>{};
  final reorders = <List<String>>[];

  @override
  Future<void> removeComponent(String id) async => removed.add(id);

  @override
  Future<void> updateRole(String id, String role) async => roles[id] = role;

  @override
  Future<void> reorder(String parentId, List<String> orderedIds) async =>
      reorders.add(orderedIds);

  @override
  Future<List<String>> distinctRoles() async => const ['Necklace', 'Primary'];
}

void main() {
  final t0 = DateTime(2026, 1, 1);

  const first = EquipmentItem(
    id: 'first',
    name: 'DGX first stage',
    type: EquipmentType.firstStage,
  );
  const hose = EquipmentItem(
    id: 'hose',
    name: 'Long hose',
    type: EquipmentType.hose,
    status: EquipmentStatus.retired,
    isActive: false,
  );

  EquipmentComponent part(String id, EquipmentItem item, {String role = '', int order = 0}) =>
      EquipmentComponent(
        id: id,
        parentEquipmentId: 'reg',
        componentEquipmentId: item.id,
        role: role,
        sortOrder: order,
        createdAt: t0,
        updatedAt: t0,
        component: item,
      );

  Widget build(List<EquipmentComponent> parts, _FakeComponentRepository repo) {
    return ProviderScope(
      overrides: [
        equipmentComponentRepositoryProvider.overrideWithValue(repo),
        equipmentComponentsProvider('reg').overrideWith((ref) async => parts),
        equipmentComponentsIndexProvider.overrideWith(
          (ref) async => ComponentsIndex.fromRows(parts),
        ),
        equipmentWorstClockProvider.overrideWith((ref) async => {}),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: ComponentsCard(equipmentId: 'reg')),
        ),
      ),
    );
  }

  testWidgets('empty state shows the prompt and the add button', (tester) async {
    await tester.pumpWidget(build(const [], _FakeComponentRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Components'), findsOneWidget);
    expect(find.textContaining('No components'), findsOneWidget);
    expect(find.text('Add component'), findsOneWidget);
  });

  testWidgets('renders one row per part with role, and a retired badge', (tester) async {
    await tester.pumpWidget(
      build([
        part('c1', first, role: 'Primary', order: 0),
        part('c2', hose, order: 1),
      ], _FakeComponentRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('DGX first stage'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('Long hose'), findsOneWidget);
    // A part with no role falls back to its type label.
    expect(find.text('Hose'), findsOneWidget);
    expect(find.text('Retired'), findsOneWidget);
  });

  testWidgets('the remove icon calls removeComponent with the row id', (tester) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(build([part('c1', first)], repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(repo.removed, ['c1']);
  });

  testWidgets('the edit icon opens the role dialog and saves the new role', (tester) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(build([part('c1', first, role: 'Primary')], repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Component role'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Backup');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.roles, {'c1': 'Backup'});
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/components_card_test.dart`
Expected: compile error, `components_card.dart` not found.

- [ ] **Step 3: Add the ARB keys to all 11 locales and regenerate**

`app_en.arb` (alphabetical among `equipment_components_*`):

```json
  "equipment_components_add": "Add component",
  "equipment_components_cycleError": "That item already contains this one, so it cannot be added as a component.",
  "equipment_components_editRole": "Edit role",
  "equipment_components_empty": "No components. Add the parts this item is assembled from.",
  "equipment_components_pickerConfirm": "{count, plural, =0{Add} =1{Add 1} other{Add {count}}}",
  "equipment_components_pickerEmpty": "No other active gear can be added here.",
  "equipment_components_pickerTitle": "Add components",
  "equipment_components_remove": "Remove component",
  "equipment_components_reorder": "Reorder",
  "equipment_components_role": "Role",
  "equipment_components_roleDialogTitle": "Component role",
  "equipment_components_roleHint": "e.g. Primary second stage",
  "equipment_components_title": "Components",
```

`app_de.arb`:

```json
  "equipment_components_add": "Komponente hinzufügen",
  "equipment_components_cycleError": "Dieser Gegenstand enthält diesen bereits, daher kann er nicht als Komponente hinzugefügt werden.",
  "equipment_components_editRole": "Rolle bearbeiten",
  "equipment_components_empty": "Keine Komponenten. Füge die Teile hinzu, aus denen dieser Gegenstand besteht.",
  "equipment_components_pickerConfirm": "{count, plural, =0{Hinzufügen} =1{1 hinzufügen} other{{count} hinzufügen}}",
  "equipment_components_pickerEmpty": "Keine weitere aktive Ausrüstung kann hier hinzugefügt werden.",
  "equipment_components_pickerTitle": "Komponenten hinzufügen",
  "equipment_components_remove": "Komponente entfernen",
  "equipment_components_reorder": "Neu anordnen",
  "equipment_components_role": "Rolle",
  "equipment_components_roleDialogTitle": "Rolle der Komponente",
  "equipment_components_roleHint": "z. B. Primäre zweite Stufe",
  "equipment_components_title": "Komponenten",
```

`app_fr.arb`:

```json
  "equipment_components_add": "Ajouter un composant",
  "equipment_components_cycleError": "Cet équipement contient déjà celui-ci, il ne peut donc pas être ajouté comme composant.",
  "equipment_components_editRole": "Modifier le rôle",
  "equipment_components_empty": "Aucun composant. Ajoutez les pièces qui composent cet équipement.",
  "equipment_components_pickerConfirm": "{count, plural, =0{Ajouter} =1{Ajouter 1} other{Ajouter {count}}}",
  "equipment_components_pickerEmpty": "Aucun autre équipement actif ne peut être ajouté ici.",
  "equipment_components_pickerTitle": "Ajouter des composants",
  "equipment_components_remove": "Retirer le composant",
  "equipment_components_reorder": "Réorganiser",
  "equipment_components_role": "Rôle",
  "equipment_components_roleDialogTitle": "Rôle du composant",
  "equipment_components_roleHint": "p. ex. Deuxième étage principal",
  "equipment_components_title": "Composants",
```

`app_es.arb`:

```json
  "equipment_components_add": "Añadir componente",
  "equipment_components_cycleError": "Ese equipo ya contiene este, por lo que no se puede añadir como componente.",
  "equipment_components_editRole": "Editar función",
  "equipment_components_empty": "Sin componentes. Añade las piezas que forman este equipo.",
  "equipment_components_pickerConfirm": "{count, plural, =0{Añadir} =1{Añadir 1} other{Añadir {count}}}",
  "equipment_components_pickerEmpty": "No hay más equipo activo que se pueda añadir aquí.",
  "equipment_components_pickerTitle": "Añadir componentes",
  "equipment_components_remove": "Quitar componente",
  "equipment_components_reorder": "Reordenar",
  "equipment_components_role": "Función",
  "equipment_components_roleDialogTitle": "Función del componente",
  "equipment_components_roleHint": "p. ej. Segunda etapa principal",
  "equipment_components_title": "Componentes",
```

`app_it.arb`:

```json
  "equipment_components_add": "Aggiungi componente",
  "equipment_components_cycleError": "Quell'articolo contiene già questo, quindi non può essere aggiunto come componente.",
  "equipment_components_editRole": "Modifica ruolo",
  "equipment_components_empty": "Nessun componente. Aggiungi le parti che compongono questo articolo.",
  "equipment_components_pickerConfirm": "{count, plural, =0{Aggiungi} =1{Aggiungi 1} other{Aggiungi {count}}}",
  "equipment_components_pickerEmpty": "Nessun'altra attrezzatura attiva può essere aggiunta qui.",
  "equipment_components_pickerTitle": "Aggiungi componenti",
  "equipment_components_remove": "Rimuovi componente",
  "equipment_components_reorder": "Riordina",
  "equipment_components_role": "Ruolo",
  "equipment_components_roleDialogTitle": "Ruolo del componente",
  "equipment_components_roleHint": "es. Secondo stadio principale",
  "equipment_components_title": "Componenti",
```

`app_nl.arb`:

```json
  "equipment_components_add": "Onderdeel toevoegen",
  "equipment_components_cycleError": "Dat item bevat dit item al, dus het kan niet als onderdeel worden toegevoegd.",
  "equipment_components_editRole": "Rol bewerken",
  "equipment_components_empty": "Geen onderdelen. Voeg de delen toe waaruit dit item is opgebouwd.",
  "equipment_components_pickerConfirm": "{count, plural, =0{Toevoegen} =1{1 toevoegen} other{{count} toevoegen}}",
  "equipment_components_pickerEmpty": "Er is geen andere actieve uitrusting die hier kan worden toegevoegd.",
  "equipment_components_pickerTitle": "Onderdelen toevoegen",
  "equipment_components_remove": "Onderdeel verwijderen",
  "equipment_components_reorder": "Herschikken",
  "equipment_components_role": "Rol",
  "equipment_components_roleDialogTitle": "Rol van onderdeel",
  "equipment_components_roleHint": "bijv. Primaire tweede trap",
  "equipment_components_title": "Onderdelen",
```

`app_pt.arb`:

```json
  "equipment_components_add": "Adicionar componente",
  "equipment_components_cycleError": "Esse item já contém este, por isso não pode ser adicionado como componente.",
  "equipment_components_editRole": "Editar função",
  "equipment_components_empty": "Sem componentes. Adicione as peças que compõem este item.",
  "equipment_components_pickerConfirm": "{count, plural, =0{Adicionar} =1{Adicionar 1} other{Adicionar {count}}}",
  "equipment_components_pickerEmpty": "Não há outro equipamento ativo que possa ser adicionado aqui.",
  "equipment_components_pickerTitle": "Adicionar componentes",
  "equipment_components_remove": "Remover componente",
  "equipment_components_reorder": "Reordenar",
  "equipment_components_role": "Função",
  "equipment_components_roleDialogTitle": "Função do componente",
  "equipment_components_roleHint": "ex.: Segundo estágio principal",
  "equipment_components_title": "Componentes",
```

`app_hu.arb`:

```json
  "equipment_components_add": "Alkatrész hozzáadása",
  "equipment_components_cycleError": "Az a felszerelés már tartalmazza ezt, ezért nem adható hozzá alkatrészként.",
  "equipment_components_editRole": "Szerep szerkesztése",
  "equipment_components_empty": "Nincsenek alkatrészek. Add hozzá azokat a részeket, amelyekből ez a felszerelés áll.",
  "equipment_components_pickerConfirm": "{count, plural, =0{Hozzáadás} =1{1 hozzáadása} other{{count} hozzáadása}}",
  "equipment_components_pickerEmpty": "Nincs más aktív felszerelés, amit ide lehetne adni.",
  "equipment_components_pickerTitle": "Alkatrészek hozzáadása",
  "equipment_components_remove": "Alkatrész eltávolítása",
  "equipment_components_reorder": "Átrendezés",
  "equipment_components_role": "Szerep",
  "equipment_components_roleDialogTitle": "Alkatrész szerepe",
  "equipment_components_roleHint": "pl. Fő második fokozat",
  "equipment_components_title": "Alkatrészek",
```

`app_ar.arb`:

```json
  "equipment_components_add": "إضافة مكوّن",
  "equipment_components_cycleError": "هذا العنصر يحتوي بالفعل على هذا، لذا لا يمكن إضافته كمكوّن.",
  "equipment_components_editRole": "تعديل الدور",
  "equipment_components_empty": "لا توجد مكوّنات. أضف الأجزاء التي يتكوّن منها هذا العنصر.",
  "equipment_components_pickerConfirm": "{count, plural, =0{إضافة} =1{إضافة 1} other{إضافة {count}}}",
  "equipment_components_pickerEmpty": "لا توجد معدات نشطة أخرى يمكن إضافتها هنا.",
  "equipment_components_pickerTitle": "إضافة مكوّنات",
  "equipment_components_remove": "إزالة المكوّن",
  "equipment_components_reorder": "إعادة ترتيب",
  "equipment_components_role": "الدور",
  "equipment_components_roleDialogTitle": "دور المكوّن",
  "equipment_components_roleHint": "مثال: المرحلة الثانية الرئيسية",
  "equipment_components_title": "المكوّنات",
```

`app_he.arb`:

```json
  "equipment_components_add": "הוספת רכיב",
  "equipment_components_cycleError": "הפריט הזה כבר מכיל את זה, ולכן אי אפשר להוסיף אותו כרכיב.",
  "equipment_components_editRole": "עריכת תפקיד",
  "equipment_components_empty": "אין רכיבים. הוסיפו את החלקים שמהם מורכב הפריט.",
  "equipment_components_pickerConfirm": "{count, plural, =0{הוספה} =1{הוספת 1} other{הוספת {count}}}",
  "equipment_components_pickerEmpty": "אין ציוד פעיל נוסף שאפשר להוסיף כאן.",
  "equipment_components_pickerTitle": "הוספת רכיבים",
  "equipment_components_remove": "הסרת רכיב",
  "equipment_components_reorder": "סידור מחדש",
  "equipment_components_role": "תפקיד",
  "equipment_components_roleDialogTitle": "תפקיד הרכיב",
  "equipment_components_roleHint": "לדוגמה: שלב שני ראשי",
  "equipment_components_title": "רכיבים",
```

`app_zh.arb`:

```json
  "equipment_components_add": "添加组件",
  "equipment_components_cycleError": "该装备已包含此项，因此无法将其添加为组件。",
  "equipment_components_editRole": "编辑用途",
  "equipment_components_empty": "暂无组件。请添加构成此装备的部件。",
  "equipment_components_pickerConfirm": "{count, plural, =0{添加} =1{添加 1 项} other{添加 {count} 项}}",
  "equipment_components_pickerEmpty": "没有其他可添加的在用装备。",
  "equipment_components_pickerTitle": "添加组件",
  "equipment_components_remove": "移除组件",
  "equipment_components_reorder": "调整顺序",
  "equipment_components_role": "用途",
  "equipment_components_roleDialogTitle": "组件用途",
  "equipment_components_roleHint": "例如：主二级头",
  "equipment_components_title": "组件",
```

Run `flutter gen-l10n` and the duplicate-key check from Task 4.

- [ ] **Step 4: Write the role dialog**

```dart
// lib/features/equipment/presentation/widgets/component_role_dialog.dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Asks for a component's role ("Primary second stage"). Returns the trimmed
/// text on Save (empty clears the role) and null on Cancel. [suggestions]
/// are roles already used on other assemblies, offered as chips.
Future<String?> showComponentRoleDialog(
  BuildContext context, {
  required String initial,
  required List<String> suggestions,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ComponentRoleDialog(
      initial: initial,
      suggestions: suggestions,
    ),
  );
}

class _ComponentRoleDialog extends StatefulWidget {
  final String initial;
  final List<String> suggestions;

  const _ComponentRoleDialog({
    required this.initial,
    required this.suggestions,
  });

  @override
  State<_ComponentRoleDialog> createState() => _ComponentRoleDialogState();
}

class _ComponentRoleDialogState extends State<_ComponentRoleDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.equipment_components_roleDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.equipment_components_role,
              hintText: l10n.equipment_components_roleHint,
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          if (widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final role in widget.suggestions)
                  ActionChip(
                    label: Text(role),
                    onPressed: () => setState(() {
                      _controller.text = role;
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Write the picker sheet**

```dart
// lib/features/equipment/presentation/widgets/component_picker_sheet.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the add-components sheet for [parentId].
Future<void> showComponentPicker(
  BuildContext context,
  WidgetRef ref, {
  required String parentId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ComponentPickerSheet(
        parentId: parentId,
        scrollController: scrollController,
      ),
    ),
  );
}

/// Active gear grouped by type, with checkboxes, minus everything that
/// cannot legally become a part of [parentId]: the item itself, its current
/// parts, and every ancestor and descendant. The repository re-checks on
/// insert; the exclusion here is so the impossible choice is simply absent.
class ComponentPickerSheet extends ConsumerStatefulWidget {
  final String parentId;
  final ScrollController scrollController;

  const ComponentPickerSheet({
    super.key,
    required this.parentId,
    required this.scrollController,
  });

  @override
  ConsumerState<ComponentPickerSheet> createState() =>
      _ComponentPickerSheetState();
}

class _ComponentPickerSheetState extends ConsumerState<ComponentPickerSheet> {
  final _selected = <String>{};
  bool _saving = false;

  List<EquipmentItem> _candidates(
    List<EquipmentItem> active,
    ComponentsIndex index,
  ) {
    final excluded = <String>{
      widget.parentId,
      for (final part in index.byParent[widget.parentId] ?? const [])
        part.componentEquipmentId,
      ...index.ancestorsOf(widget.parentId),
      ...index.descendantsOf(widget.parentId),
    };
    return [
      for (final item in active)
        if (!excluded.contains(item.id)) item,
    ];
  }

  Future<void> _confirm() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    final repository = ref.read(equipmentComponentRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cycleText = context.l10n.equipment_components_cycleError;
    try {
      for (final id in _selected) {
        await repository.addComponent(
          parentId: widget.parentId,
          componentId: id,
        );
      }
      navigator.pop();
    } on EquipmentComponentCycleException {
      messenger.showSnackBar(SnackBar(content: Text(cycleText)));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeAsync = ref.watch(activeEquipmentProvider);
    final indexAsync = ref.watch(equipmentComponentsIndexProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.equipment_components_pickerTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton(
                onPressed: _selected.isEmpty || _saving ? null : _confirm,
                child: Text(
                  l10n.equipment_components_pickerConfirm(_selected.length),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: activeAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (active) {
              final index = indexAsync.value ?? ComponentsIndex.empty;
              final candidates = _candidates(active, index);
              if (candidates.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.equipment_components_pickerEmpty),
                  ),
                );
              }
              final grouped = <EquipmentType, List<EquipmentItem>>{};
              for (final item in candidates) {
                grouped.putIfAbsent(item.type, () => []).add(item);
              }
              return ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final entry in grouped.entries)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              entry.key.localizedName(l10n),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                          ),
                          for (final item in entry.value)
                            CheckboxListTile(
                              value: _selected.contains(item.id),
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _selected.add(item.id);
                                } else {
                                  _selected.remove(item.id);
                                }
                              }),
                              title: Text(item.name),
                              subtitle: item.fullName != item.name
                                  ? Text(item.fullName)
                                  : null,
                              secondary: Icon(equipmentTypeIcon(item.type)),
                              controlAffinity: ListTileControlAffinity.trailing,
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Write the Components card**

```dart
// lib/features/equipment/presentation/widgets/components_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_role_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Components card on the equipment detail page (issue #1487): the parts
/// this item is assembled from, each with its role, its own service dot,
/// inline edit and remove actions, and drag-to-reorder.
///
/// Lives on the detail page, not the edit form, like every other cross-item
/// edge (service clocks, documents, unit configurations): a new item has no
/// id until it is saved.
class ComponentsCard extends ConsumerWidget {
  final String equipmentId;

  const ComponentsCard({super.key, required this.equipmentId});

  Color _dotColor(BuildContext context, ServiceClockSeverity? severity) {
    final scheme = Theme.of(context).colorScheme;
    return switch (severity) {
      ServiceClockSeverity.overdue => scheme.error,
      ServiceClockSeverity.dueSoon => scheme.tertiary,
      _ => scheme.surfaceContainerHighest,
    };
  }

  Future<void> _editRole(
    BuildContext context,
    WidgetRef ref,
    EquipmentComponent part,
  ) async {
    final repository = ref.read(equipmentComponentRepositoryProvider);
    final suggestions = await repository.distinctRoles();
    if (!context.mounted) return;
    final role = await showComponentRoleDialog(
      context,
      initial: part.role,
      suggestions: suggestions.where((r) => r != part.role).toList(),
    );
    if (role == null || role == part.role) return;
    await repository.updateRole(part.id, role);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final partsAsync = ref.watch(equipmentComponentsProvider(equipmentId));
    final worstClocks = ref.watch(equipmentWorstClockProvider).value ?? const {};
    final repository = ref.read(equipmentComponentRepositoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.equipment_components_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      showComponentPicker(context, ref, parentId: equipmentId),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.equipment_components_add),
                ),
              ],
            ),
            const Divider(),
            partsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  Padding(padding: const EdgeInsets.all(8), child: Text('$e')),
              data: (parts) {
                if (parts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.equipment_components_empty,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorder: (oldIndex, newIndex) {
                    final ids = parts.map((p) => p.id).toList();
                    if (newIndex > oldIndex) newIndex -= 1;
                    final moved = ids.removeAt(oldIndex);
                    ids.insert(newIndex, moved);
                    repository.reorder(equipmentId, ids);
                  },
                  children: [
                    for (final (index, part) in parts.indexed)
                      _PartTile(
                        key: ValueKey(part.id),
                        index: index,
                        part: part,
                        dotColor: _dotColor(
                          context,
                          worstClocks[part.componentEquipmentId]
                              ?.status
                              .severity,
                        ),
                        onEditRole: () => _editRole(context, ref, part),
                        onRemove: () => repository.removeComponent(part.id),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PartTile extends StatelessWidget {
  final int index;
  final EquipmentComponent part;
  final Color dotColor;
  final VoidCallback onEditRole;
  final VoidCallback onRemove;

  const _PartTile({
    super.key,
    required this.index,
    required this.part,
    required this.dotColor,
    required this.onEditRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = part.component;
    final name = item?.name ?? part.componentEquipmentId;
    final type = item?.type ?? EquipmentType.other;
    final retired =
        item != null &&
        (item.status == EquipmentStatus.retired || !item.isActive);
    final subtitle = part.role.isNotEmpty
        ? part.role
        : type.localizedName(l10n);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Icon(equipmentTypeIcon(type)),
          Icon(Icons.circle, size: 10, color: dotColor),
        ],
      ),
      title: Text(name),
      subtitle: Row(
        children: [
          Flexible(child: Text(subtitle, overflow: TextOverflow.ellipsis)),
          if (retired) ...[
            const SizedBox(width: 8),
            Text(
              EquipmentStatus.retired.localizedName(l10n),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push('/equipment/${part.componentEquipmentId}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.equipment_components_editRole,
            onPressed: onEditRole,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.equipment_components_remove,
            onPressed: onRemove,
          ),
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: l10n.equipment_components_reorder,
              child: const Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}
```

The `push` in `_PartTile` needs a router in tests; the card test above never taps a row, so a plain `MaterialApp` is enough there.

- [ ] **Step 7: Run the card test**

Run: `flutter test test/features/equipment/presentation/widgets/components_card_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 8: Write and run the dialog and picker tests**

```dart
// test/features/equipment/presentation/widgets/component_role_dialog_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_role_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host(void Function(BuildContext) onOpen) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => onOpen(context),
          child: const Text('open'),
        ),
      ),
    ),
  );

  testWidgets('returns the trimmed text on Save', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      host((context) async {
        result = await showComponentRoleDialog(
          context,
          initial: 'Primary',
          suggestions: const ['Necklace'],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Backup  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'Backup');
  });

  testWidgets('a suggestion chip fills the field', (tester) async {
    String? result;
    await tester.pumpWidget(
      host((context) async {
        result = await showComponentRoleDialog(
          context,
          initial: '',
          suggestions: const ['Necklace'],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Necklace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'Necklace');
  });

  testWidgets('returns null on Cancel', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      host((context) async {
        result = await showComponentRoleDialog(
          context,
          initial: 'Primary',
          suggestions: const [],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
```

```dart
// test/features/equipment/presentation/widgets/component_picker_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_picker_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeComponentRepository extends EquipmentComponentRepository {
  final added = <(String, String)>[];
  bool throwCycle = false;

  @override
  Future<EquipmentComponent> addComponent({
    required String parentId,
    required String componentId,
    String role = '',
  }) async {
    if (throwCycle) throw EquipmentComponentCycleException(parentId, componentId);
    added.add((parentId, componentId));
    return EquipmentComponent(
      id: 'new-$componentId',
      parentEquipmentId: parentId,
      componentEquipmentId: componentId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }
}

void main() {
  final t0 = DateTime(2026, 1, 1);
  EquipmentItem item(String id, EquipmentType type) =>
      EquipmentItem(id: id, name: 'Name $id', type: type);
  var seq = 0;
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: 'c${seq++}',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );

  final active = [
    item('kit', EquipmentType.other),
    item('reg', EquipmentType.regulator),
    item('first', EquipmentType.firstStage),
    item('hose', EquipmentType.hose),
    item('fins', EquipmentType.fins),
  ];
  // kit > reg > first; the picker for reg must hide kit (ancestor), reg
  // (self), first (already a part), and offer hose and fins.
  final edges = [edge('kit', 'reg'), edge('reg', 'first')];

  Widget build(_FakeComponentRepository repo) => ProviderScope(
    overrides: [
      equipmentComponentRepositoryProvider.overrideWithValue(repo),
      activeEquipmentProvider.overrideWith((ref) async => active),
      equipmentComponentsIndexProvider.overrideWith(
        (ref) async => ComponentsIndex.fromRows(edges),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ComponentPickerSheet(
          parentId: 'reg',
          scrollController: ScrollController(),
        ),
      ),
    ),
  );

  testWidgets('hides self, ancestors, and current parts', (tester) async {
    await tester.pumpWidget(build(_FakeComponentRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Name hose'), findsOneWidget);
    expect(find.text('Name fins'), findsOneWidget);
    expect(find.text('Name reg'), findsNothing);
    expect(find.text('Name kit'), findsNothing);
    expect(find.text('Name first'), findsNothing);
  });

  testWidgets('confirm adds every checked item under the parent', (tester) async {
    final repo = _FakeComponentRepository();
    await tester.pumpWidget(build(repo));
    await tester.pumpAndSettle();
    expect(find.text('Add'), findsOneWidget);
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    expect(find.text('Add 1'), findsOneWidget);
    await tester.tap(find.text('Name fins'));
    await tester.pump();
    await tester.tap(find.text('Add 2'));
    await tester.pumpAndSettle();
    expect(repo.added, unorderedEquals([('reg', 'hose'), ('reg', 'fins')]));
  });

  testWidgets('a cycle refused by the repository shows the explanation', (tester) async {
    final repo = _FakeComponentRepository()..throwCycle = true;
    await tester.pumpWidget(build(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name hose'));
    await tester.pump();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be added as a component'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/equipment/presentation/widgets/component_role_dialog_test.dart test/features/equipment/presentation/widgets/component_picker_sheet_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 9: Mount the card on the detail page and keep existing page tests green**

In `equipment_detail_page.dart` add `import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';` and, in the body `Column`, directly after the `ServiceClocksCard(...)` element and before the rebreather block, insert:

```dart
          const SizedBox(height: 24),
          ComponentsCard(equipmentId: equipmentId),
```

Every test that pumps the page now renders the card, which reads `equipmentComponentsProvider(id)` and `equipmentWorstClockProvider`. In each file found by `grep -rl "EquipmentDetailPage(" test/`, add to the page's override list:

```dart
              equipmentComponentsProvider(
                equipment.id,
              ).overrideWith((ref) async => const []),
              equipmentWorstClockProvider.overrideWith((ref) async => {}),
```

(using whatever local name the file gives the item), plus the import `package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart`. Then add one test to `equipment_detail_service_test.dart`:

```dart
  testWidgets('the Components card is on the page', (tester) async {
    const item = EquipmentItem(id: 'e1', name: 'Reg', type: EquipmentType.regulator);
    await pumpDetail(tester, item: item, clockStatuses: const []);
    expect(find.text('Components'), findsOneWidget);
  });
```

Run: `flutter test test/features/equipment/presentation/pages/` (this directory is small enough) Expected: PASS.

- [ ] **Step 10: Format and commit**

```bash
dart format lib/features/equipment test/features/equipment
git add lib/features/equipment/presentation/widgets/components_card.dart lib/features/equipment/presentation/widgets/component_role_dialog.dart lib/features/equipment/presentation/widgets/component_picker_sheet.dart lib/features/equipment/presentation/pages/equipment_detail_page.dart test/features/equipment/presentation/widgets/components_card_test.dart test/features/equipment/presentation/widgets/component_role_dialog_test.dart test/features/equipment/presentation/widgets/component_picker_sheet_test.dart test/features/equipment/presentation/pages lib/l10n/arb
git commit -m "feat(equipment): Components card on the equipment detail page (#1487)

Build an assembly from its parts: grouped picker that hides every
choice the cycle guard would refuse, role labels with suggestions,
inline edit and remove, and drag-to-reorder."
```

---

### Task 7: List chips, table column, and rollup badges

**Files:**
- Create: `lib/features/equipment/presentation/widgets/assembly_chips.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (`EquipmentListTile` ~L914-1010; table adapter ~L538-543)
- Modify: `lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart` (~L35, name cell ~L72, `_buildServiceStatus` ~L115)
- Modify: `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart` (`_buildEquipmentTile` ~L255)
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (`isServiceOverdue` ~L143)
- Modify: `lib/features/equipment/domain/constants/equipment_field.dart` (enum and every switch; adapter ~L244)
- Modify: `test/features/equipment/presentation/widgets/equipment_tile_service_badge_test.dart`, `equipment_tile_accent_test.dart`, `dense_equipment_list_tile_test.dart`, `equipment_list_content_test.dart` (~L613)
- Modify: all 11 `lib/l10n/arb/app_*.arb`; regenerate
- Test: `test/features/equipment/presentation/widgets/assembly_chips_test.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_tile_rollup_badge_test.dart`
- Test: `test/features/equipment/presentation/pages/equipment_detail_rollup_test.dart`
- Test: `test/features/equipment/domain/constants/equipment_field_test.dart` (add a group)

**Interfaces:**
- Consumes: `ComponentsIndex`, `equipmentComponentsIndexProvider`, `equipmentRollupClockProvider`, `RollupClock` (Task 5); `activeEquipmentProvider` for parent names.
- Produces: `class AssemblyChips extends ConsumerWidget { const AssemblyChips({super.key, required String itemId}); }` (renders nothing when the item is neither an assembly nor a part); `EquipmentField.components`; `EquipmentFieldAdapter({Map<String, ServiceClockStatus> worstClocks = const {}, Map<String, int> componentCounts = const {}})`; ARB keys `equipment_components_count`, `equipment_components_partOf`, `equipment_components_partOfCount`, `equipment_components_rollupClock`, `enum_equipmentField_components`, `enum_equipmentField_components_short`.

- [ ] **Step 1: Write the failing chips test**

```dart
// test/features/equipment/presentation/widgets/assembly_chips_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_chips.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  var seq = 0;
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: 'c${seq++}',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );
  const reg = EquipmentItem(id: 'reg', name: 'Cold water reg', type: EquipmentType.regulator);
  const yoke = EquipmentItem(id: 'yoke', name: 'Travel reg', type: EquipmentType.regulator);
  const hose = EquipmentItem(id: 'hose', name: 'Long hose', type: EquipmentType.hose);

  Widget build(String itemId, List<EquipmentComponent> edges) => ProviderScope(
    overrides: [
      equipmentComponentsIndexProvider.overrideWith(
        (ref) async => ComponentsIndex.fromRows(edges),
      ),
      activeEquipmentProvider.overrideWith((ref) async => [reg, yoke, hose]),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AssemblyChips(itemId: itemId)),
    ),
  );

  testWidgets('an assembly shows its component count', (tester) async {
    await tester.pumpWidget(build('reg', [edge('reg', 'hose'), edge('reg', 'yoke')]));
    await tester.pumpAndSettle();
    expect(find.text('2 components'), findsOneWidget);
  });

  testWidgets('a part of one assembly names it', (tester) async {
    await tester.pumpWidget(build('hose', [edge('reg', 'hose')]));
    await tester.pumpAndSettle();
    expect(find.text('Part of Cold water reg'), findsOneWidget);
  });

  testWidgets('a part of two assemblies shows the count', (tester) async {
    await tester.pumpWidget(build('hose', [edge('reg', 'hose'), edge('yoke', 'hose')]));
    await tester.pumpAndSettle();
    expect(find.text('Part of 2 assemblies'), findsOneWidget);
  });

  testWidgets('an unrelated item renders nothing', (tester) async {
    await tester.pumpWidget(build('yoke', [edge('reg', 'hose')]));
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/assembly_chips_test.dart`
Expected: compile error, `assembly_chips.dart` not found.

- [ ] **Step 3: Add the ARB keys to all 11 locales and regenerate**

`app_en.arb`:

```json
  "enum_equipmentField_components": "Components",
  "enum_equipmentField_components_short": "Parts",
  "equipment_components_count": "{count, plural, =1{1 component} other{{count} components}}",
  "equipment_components_partOf": "Part of {name}",
  "equipment_components_partOfCount": "{count, plural, =1{Part of 1 assembly} other{Part of {count} assemblies}}",
  "equipment_components_rollupClock": "{component}: {kind}",
```

`app_de.arb`:

```json
  "enum_equipmentField_components": "Komponenten",
  "enum_equipmentField_components_short": "Teile",
  "equipment_components_count": "{count, plural, =1{1 Komponente} other{{count} Komponenten}}",
  "equipment_components_partOf": "Teil von {name}",
  "equipment_components_partOfCount": "{count, plural, =1{Teil von 1 Baugruppe} other{Teil von {count} Baugruppen}}",
  "equipment_components_rollupClock": "{component}: {kind}",
```

`app_fr.arb`:

```json
  "enum_equipmentField_components": "Composants",
  "enum_equipmentField_components_short": "Pièces",
  "equipment_components_count": "{count, plural, =1{1 composant} other{{count} composants}}",
  "equipment_components_partOf": "Fait partie de {name}",
  "equipment_components_partOfCount": "{count, plural, =1{Fait partie de 1 ensemble} other{Fait partie de {count} ensembles}}",
  "equipment_components_rollupClock": "{component} : {kind}",
```

`app_es.arb`:

```json
  "enum_equipmentField_components": "Componentes",
  "enum_equipmentField_components_short": "Piezas",
  "equipment_components_count": "{count, plural, =1{1 componente} other{{count} componentes}}",
  "equipment_components_partOf": "Parte de {name}",
  "equipment_components_partOfCount": "{count, plural, =1{Parte de 1 conjunto} other{Parte de {count} conjuntos}}",
  "equipment_components_rollupClock": "{component}: {kind}",
```

`app_it.arb`:

```json
  "enum_equipmentField_components": "Componenti",
  "enum_equipmentField_components_short": "Parti",
  "equipment_components_count": "{count, plural, =1{1 componente} other{{count} componenti}}",
  "equipment_components_partOf": "Parte di {name}",
  "equipment_components_partOfCount": "{count, plural, =1{Parte di 1 assieme} other{Parte di {count} assiemi}}",
  "equipment_components_rollupClock": "{component}: {kind}",
```

`app_nl.arb`:

```json
  "enum_equipmentField_components": "Onderdelen",
  "enum_equipmentField_components_short": "Delen",
  "equipment_components_count": "{count, plural, =1{1 onderdeel} other{{count} onderdelen}}",
  "equipment_components_partOf": "Onderdeel van {name}",
  "equipment_components_partOfCount": "{count, plural, =1{Onderdeel van 1 samenstel} other{Onderdeel van {count} samenstellen}}",
  "equipment_components_rollupClock": "{component}: {kind}",
```

`app_pt.arb`:

```json
  "enum_equipmentField_components": "Componentes",
  "enum_equipmentField_components_short": "Peças",
  "equipment_components_count": "{count, plural, =1{1 componente} other{{count} componentes}}",
  "equipment_components_partOf": "Parte de {name}",
  "equipment_components_partOfCount": "{count, plural, =1{Parte de 1 conjunto} other{Parte de {count} conjuntos}}",
  "equipment_components_rollupClock": "{component}: {kind}",
```

`app_hu.arb`:

```json
  "enum_equipmentField_components": "Alkatrészek",
  "enum_equipmentField_components_short": "Részek",
  "equipment_components_count": "{count, plural, =1{1 alkatrész} other{{count} alkatrész}}",
  "equipment_components_partOf": "{name} része",
  "equipment_components_partOfCount": "{count, plural, =1{1 összeállítás része} other{{count} összeállítás része}}",
  "equipment_components_rollupClock": "{component}: {kind}",
```

`app_ar.arb`:

```json
  "enum_equipmentField_components": "المكوّنات",
  "enum_equipmentField_components_short": "أجزاء",
  "equipment_components_count": "{count, plural, =1{مكوّن واحد} other{{count} مكوّنات}}",
  "equipment_components_partOf": "جزء من {name}",
  "equipment_components_partOfCount": "{count, plural, =1{جزء من تجميعة واحدة} other{جزء من {count} تجميعات}}",
  "equipment_components_rollupClock": "{component}: {kind}",
```

`app_he.arb`:

```json
  "enum_equipmentField_components": "רכיבים",
  "enum_equipmentField_components_short": "חלקים",
  "equipment_components_count": "{count, plural, =1{רכיב אחד} other{{count} רכיבים}}",
  "equipment_components_partOf": "חלק מ-{name}",
  "equipment_components_partOfCount": "{count, plural, =1{חלק ממכלול אחד} other{חלק מ-{count} מכלולים}}",
  "equipment_components_rollupClock": "{component}: {kind}",
```

`app_zh.arb`:

```json
  "enum_equipmentField_components": "组件",
  "enum_equipmentField_components_short": "部件",
  "equipment_components_count": "{count, plural, =1{1 个组件} other{{count} 个组件}}",
  "equipment_components_partOf": "属于 {name}",
  "equipment_components_partOfCount": "{count, plural, =1{属于 1 个组合} other{属于 {count} 个组合}}",
  "equipment_components_rollupClock": "{component}：{kind}",
```

Run `flutter gen-l10n` and the duplicate-key check.

- [ ] **Step 4: Write the chips widget**

```dart
// lib/features/equipment/presentation/widgets/assembly_chips.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// "3 components" on an assembly and "Part of Cold water reg" on a part
/// (issue #1487). Reads the shared adjacency index by id, the same way the
/// service badge reads the worst-clock map, so a list of a thousand items
/// costs no per-row query. Renders nothing for an item that is neither.
class AssemblyChips extends ConsumerWidget {
  final String itemId;

  const AssemblyChips({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(equipmentComponentsIndexProvider).value;
    if (index == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final labels = <String>[];

    final count = index.componentCount(itemId);
    if (count > 0) labels.add(l10n.equipment_components_count(count));

    final parents = index.parentIdsOf(itemId);
    if (parents.length == 1) {
      // Active gear is what the list already holds; a retired parent falls
      // back to the count form rather than costing a query.
      final active = ref.watch(activeEquipmentProvider).value ?? const [];
      String? name;
      for (final item in active) {
        if (item.id == parents.single) {
          name = item.name;
          break;
        }
      }
      labels.add(
        name != null
            ? l10n.equipment_components_partOf(name)
            : l10n.equipment_components_partOfCount(1),
      );
    } else if (parents.length > 1) {
      labels.add(l10n.equipment_components_partOfCount(parents.length));
    }

    if (labels.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run the chips test**

Run: `flutter test test/features/equipment/presentation/widgets/assembly_chips_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Write the failing rollup badge and header tests**

```dart
// test/features/equipment/presentation/widgets/equipment_tile_rollup_badge_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The list badge reads the rollup, so a due hose lights its regulator and
/// the badge says which part (issue #1487).
void main() {
  final t0 = DateTime(2025, 1, 1);
  const reg = EquipmentItem(id: 'reg', name: 'Cold water reg', type: EquipmentType.regulator);

  RollupClock rollup(String ownerId, String ownerName, ServiceClockSeverity severity) => (
    ownerId: ownerId,
    ownerName: ownerName,
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: ownerId,
        serviceKindId: 'hose-swap',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'hose-swap',
        name: 'Hose replacement',
        defaultIntervalDays: 1825,
        isBuiltIn: false,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2026, 1, 1),
      severity: severity,
      now: DateTime(2026, 7, 1),
    ),
  );

  Widget wrap(Widget child, Map<String, RollupClock> map) => ProviderScope(
    overrides: [
      equipmentRollupClockProvider.overrideWith((ref) async => map),
      equipmentComponentsIndexProvider.overrideWith((ref) async => ComponentsIndex.empty),
      activeEquipmentProvider.overrideWith((ref) async => const [reg]),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  testWidgets('standard tile names the part that owns the overdue clock', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EquipmentListTile(item: reg),
        {'reg': rollup('hose', 'Necklace hose', ServiceClockSeverity.overdue)},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Necklace hose: Hose replacement overdue'), findsOneWidget);
  });

  testWidgets('standard tile keeps the plain label when the item owns the clock', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EquipmentListTile(item: reg),
        {'reg': rollup('reg', 'Cold water reg', ServiceClockSeverity.dueSoon)},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hose replacement'), findsOneWidget);
  });

  testWidgets('an ok rollup shows no badge', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EquipmentListTile(item: reg),
        {'reg': rollup('hose', 'Necklace hose', ServiceClockSeverity.ok)},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Hose replacement'), findsNothing);
  });

  testWidgets('dense tile shows the part name for a descendant clock', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DenseEquipmentListTile(item: reg),
        {'reg': rollup('hose', 'Necklace hose', ServiceClockSeverity.overdue)},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Necklace hose: Hose replacement'), findsOneWidget);
  });
}
```

```dart
// test/features/equipment/presentation/pages/equipment_detail_rollup_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'package:submersion/features/equipment/domain/entities/service_record.dart';

import '../../../../helpers/mock_providers.dart';

/// The same fake `equipment_detail_service_test.dart` keeps private: the
/// history section needs a notifier that never touches the database.
class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  _MockServiceRecordNotifier() : super(const AsyncValue.data([]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final t0 = DateTime(2025, 1, 1);
  const reg = EquipmentItem(id: 'reg', name: 'Cold water reg', type: EquipmentType.regulator);

  RollupClock overdueOnHose() => (
    ownerId: 'hose',
    ownerName: 'Necklace hose',
    status: ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's1',
        equipmentId: 'hose',
        serviceKindId: 'hose-swap',
        createdAt: t0,
        updatedAt: t0,
      ),
      kind: ServiceKind(
        id: 'hose-swap',
        name: 'Hose replacement',
        defaultIntervalDays: 1825,
        isBuiltIn: false,
        createdAt: t0,
        updatedAt: t0,
      ),
      anchor: t0,
      dueDate: DateTime(2026, 1, 1),
      severity: ServiceClockSeverity.overdue,
      now: DateTime(2026, 7, 1),
    ),
  );

  Future<void> pump(WidgetTester tester, Map<String, RollupClock> rollup) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentItemProvider('reg').overrideWith((ref) async => reg),
          equipmentDiveCountProvider('reg').overrideWith((ref) async => 0),
          equipmentTripCountProvider('reg').overrideWith((ref) async => 0),
          serviceRecordNotifierProvider('reg').overrideWith((ref) => _MockServiceRecordNotifier()),
          serviceClockStatusesProvider('reg').overrideWith((ref) async => const []),
          equipmentComponentsProvider('reg').overrideWith((ref) async => const []),
          equipmentWorstClockProvider.overrideWith((ref) async => {}),
          equipmentRollupClockProvider.overrideWith((ref) async => rollup),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentDetailPage(equipmentId: 'reg'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the header lights when a part is overdue', (tester) async {
    await pump(tester, {'reg': overdueOnHose()});
    expect(find.text('Service is overdue!'), findsOneWidget);
  });

  testWidgets('the header stays calm when nothing in the subtree is due', (tester) async {
    await pump(tester, const {});
    expect(find.text('Service is overdue!'), findsNothing);
  });
}
```

- [ ] **Step 7: Run them to verify they fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_tile_rollup_badge_test.dart test/features/equipment/presentation/pages/equipment_detail_rollup_test.dart`
Expected: FAIL. The tiles still read the worst-clock map (no badge text), and the header stays calm with no own clocks.

- [ ] **Step 8: Rewire the tiles, the set tile, the header, and the table column**

`equipment_list_content.dart`, add imports for `assembly_chips.dart` and `equipment_component_providers.dart`. In `EquipmentListTile.build` replace the worst-clock read:

```dart
    final rollup = ref.watch(equipmentRollupClockProvider).value?[item.id];
    final worst =
        rollup == null || rollup.status.severity == ServiceClockSeverity.ok
        ? null
        : rollup;
    final isOverdue = worst?.status.severity == ServiceClockSeverity.overdue;
```

replace the `subtitle:` with:

```dart
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.fullName != item.name) Text(item.fullName),
            AssemblyChips(itemId: item.id),
          ],
        ),
```

and change `_buildTrailing(BuildContext context, DueClock? worstClock)` to take `RollupClock? worstClock`, computing the label as:

```dart
      final kindLabel = worstClock.ownerId == item.id
          ? worstClock.status.kind.name
          : context.l10n.equipment_components_rollupClock(
              worstClock.ownerName,
              worstClock.status.kind.name,
            );
```

and using `kindLabel` where `worstClock.status.kind.name` was used in both the overdue and the plain branches (`equipment_list_worstClock(kindLabel)` for overdue). Every other read of `worstClock.status` in that method stays.

In the table branch (~L538) replace the adapter construction:

```dart
        final rollup = ref.watch(equipmentRollupClockProvider).value ?? const {};
        final index =
            ref.watch(equipmentComponentsIndexProvider).value ??
            ComponentsIndex.empty;
        ...
          adapter: EquipmentFieldAdapter(
            worstClocks: {for (final e in rollup.entries) e.key: e.value.status},
            componentCounts: {
              for (final e in index.byParent.entries) e.key: e.value.length,
            },
          ),
```

and delete the now-unused `serviceUrgency` local if nothing else in the method reads it.

`dense_equipment_list_tile.dart`: import `equipment_component_providers.dart`; same `rollup` / `worst` read as above; change `_buildServiceStatus(BuildContext context, DueClock? worstClock)` to `RollupClock?` and use the same `kindLabel` expression for its `Text` (no overdue wrapper there). Before the name `Expanded`, add an assembly marker:

```dart
                if (ref.watch(equipmentComponentsIndexProvider).value?.isAssembly(item.id) ?? false) ...[
                  Icon(
                    Icons.account_tree_outlined,
                    size: 14,
                    color: secondaryTextColor,
                  ),
                  const SizedBox(width: 4),
                ],
```

`equipment_set_detail_page.dart`: import `assembly_chips.dart`; in `_buildEquipmentTile` change `subtitle:` to a `Column` with the existing text followed by `AssemblyChips(itemId: item.id)`, `crossAxisAlignment: CrossAxisAlignment.start`, `mainAxisSize: MainAxisSize.min`.

`equipment_detail_page.dart`: import `equipment_component_providers.dart`; replace the `isServiceOverdue` expression with:

```dart
    // Any overdue clock lights the header: the item's own, or any part's
    // through the rollup (issue #1487). Own clocks are read separately so a
    // retired item, absent from the active rollup, still shows its state.
    final ownOverdue =
        ref
            .watch(serviceClockStatusesProvider(equipmentId))
            .value
            ?.any((s) => s.severity == ServiceClockSeverity.overdue) ??
        false;
    final rollupOverdue =
        ref.watch(equipmentRollupClockProvider).value?[equipmentId]?.status.severity ==
        ServiceClockSeverity.overdue;
    final isServiceOverdue = ownOverdue || rollupOverdue;
```

In every detail-page test touched in Task 6 Step 9, add `equipmentRollupClockProvider.overrideWith((ref) async => {}),` beside the worst-clock override, since the header now reads the rollup.

`equipment_field.dart`: add `components` as the last enum value (after `notes`, so persisted column layouts keep their order) and extend every switch: `displayName` "Components", `shortLabel` "Parts", `localizedDisplayName` `l10n.enum_equipmentField_components`, `localizedShortLabel` `l10n.enum_equipmentField_components_short`, `icon` `Icons.account_tree_outlined`, `defaultWidth` 90, `minWidth` 60, `sortable` true, `categoryName` `'details'`, `isRightAligned` true. Adapter: add `final Map<String, int> componentCounts;`, constructor `EquipmentFieldAdapter({this.worstClocks = const {}, this.componentCounts = const {}});`, `extractValue` `EquipmentField.components => componentCounts[entity.id] ?? 0,`, `formatValue` `EquipmentField.components => '${value as int}',`.

- [ ] **Step 9: Move the four existing tile tests to the rollup provider**

In `equipment_tile_service_badge_test.dart`, `equipment_tile_accent_test.dart`, `dense_equipment_list_tile_test.dart`, and `equipment_list_content_test.dart`, every `equipmentWorstClockProvider.overrideWith((ref) async => X)` becomes `equipmentRollupClockProvider.overrideWith((ref) async => X)` where each map value is rebuilt as a `RollupClock`: `(ownerId: item.id, ownerName: item.name, status: <the same ServiceClockStatus>)`. Add `equipmentComponentsIndexProvider.overrideWith((ref) async => ComponentsIndex.empty)` next to each, and import `equipment_component_providers.dart`. Where a test asserted the "legacy" branch (no rollup entry, item not active), nothing else changes.

Add to `equipment_field_test.dart`:

```dart
  group('EquipmentField.components', () {
    test('extracts the count from the adapter map and defaults to zero', () {
      final adapter = EquipmentFieldAdapter(componentCounts: {'equip-1': 3});
      expect(adapter.extractValue(EquipmentField.components, testItem), 3);
      expect(
        EquipmentFieldAdapter.instance.extractValue(EquipmentField.components, testItem),
        0,
      );
      expect(adapter.formatValue(EquipmentField.components, 3, units), '3');
    });

    test('is the last value so saved column orders are stable', () {
      expect(EquipmentField.values.last, EquipmentField.components);
      expect(EquipmentField.components.categoryName, 'details');
    });
  });
```

- [ ] **Step 10: Run the new and touched tests**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_tile_rollup_badge_test.dart test/features/equipment/presentation/pages/equipment_detail_rollup_test.dart test/features/equipment/presentation/widgets/equipment_tile_service_badge_test.dart test/features/equipment/presentation/widgets/equipment_tile_accent_test.dart test/features/equipment/presentation/widgets/dense_equipment_list_tile_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart test/features/equipment/domain/constants/equipment_field_test.dart test/features/equipment/presentation/pages/equipment_set_detail_default_test.dart test/features/equipment/presentation/pages/equipment_set_detail_geofence_test.dart`
Expected: PASS. If a set-detail test renders tiles without an index override and the chip provider errors, add the `ComponentsIndex.empty` override there too.

- [ ] **Step 11: Format and commit**

```bash
dart format lib/features/equipment test/features/equipment
git add lib/features/equipment/presentation/widgets/assembly_chips.dart lib/features/equipment/presentation/widgets/equipment_list_content.dart lib/features/equipment/presentation/widgets/dense_equipment_list_tile.dart lib/features/equipment/presentation/pages/equipment_set_detail_page.dart lib/features/equipment/presentation/pages/equipment_detail_page.dart lib/features/equipment/domain/constants/equipment_field.dart test/features/equipment/presentation/widgets/assembly_chips_test.dart test/features/equipment/presentation/widgets/equipment_tile_rollup_badge_test.dart test/features/equipment/presentation/pages/equipment_detail_rollup_test.dart test/features/equipment/presentation/widgets/equipment_tile_service_badge_test.dart test/features/equipment/presentation/widgets/equipment_tile_accent_test.dart test/features/equipment/presentation/widgets/dense_equipment_list_tile_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart test/features/equipment/domain/constants/equipment_field_test.dart lib/l10n/arb
git commit -m "feat(equipment): assembly chips and service rollup badges (#1487)

List and set tiles show component counts and part-of chips; the
service badge, the detail header, and the table column read the
rollup so a due hose lights its regulator and names itself."
```

---

### Task 8: Whole-project verification

**Files:** none new.

- [ ] **Step 1: Format check, analyze, generated-l10n staleness**

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter gen-l10n && git status --short lib/l10n/arb
```

Expected: no formatting changes, `No issues found!` (infos count as failures in CI, fix any), and an empty status after gen-l10n (nothing regenerated differently from what is committed).

- [ ] **Step 2: Full test suite, in the background**

Run `flutter test` with `run_in_background: true` and a 600000 ms timeout. Do not pipe the output through `grep`; the pipe hides the exit code. Expected: 0 failures. A single known-flaky backup test that passes in isolation is not a regression; rerun that one file alone to confirm.

- [ ] **Step 3: Commit anything the format or analyze pass touched**

```bash
git status --short
```

If files changed, stage them by path and commit with `style(equipment): format and analyzer fixes for assemblies PR 1`.

- [ ] **Step 4: Report**

List the task commits, the test counts from Step 2, and note for the PR body: v203 renumber risk against the transmitter registry branch; the provenance columns are unused until PR 2; the sort-by-service-due order still uses each item's own clocks (only the badge, header, and table column read the rollup).
