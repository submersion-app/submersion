# Equipment Type-Specific Attributes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat `size`/`thickness`/`buoyancyKg`/`weightKg` equipment columns with a synced `equipment_attributes` key-value table driven by a Dart-side per-type catalog (all 18 types), plus user custom fields, stats filtering, and a dives-by-suit-thickness chart.

**Architecture:** One new HLC child table (`equipment_attributes`, modeled on `equipmentSetGeofences` sync-wise) holds curated and custom values; the per-type schema lives in `EquipmentAttributeCatalog` (pure Dart data, `CertificationLevelCatalog` pattern). `EquipmentItem` keeps `size`/`thickness`/`buoyancyKg`/`weightKg` as **getters derived from attributes** so consumers (weight planner, CSV) keep compiling. Curated rows use deterministic IDs (`attr_<equipmentId>_<attrKey>`) so independent device migrations converge.

**Tech Stack:** Flutter 3.x, Drift ORM, Riverpod, gen_l10n (11 ARB locales).

**Spec:** `docs/superpowers/specs/2026-07-16-equipment-attributes-design.md`

## Global Constraints

- **Schema version: verify before Task 1.** Run `grep -n "currentSchemaVersion = " lib/core/database/database.dart` and check the schema-ladder claims (main + open PRs #600/#601). This plan uses **v115** (main=v112 thickness, v113 reserved for PR #600 renumber, v114 = PR #601). If the ladder moved, substitute the next free number everywhere `115` appears.
- **Deviation from spec (deliberate):** `date`-kind attributes store unix **milliseconds** in `valueNum` (not seconds) — the whole codebase uses `millisecondsSinceEpoch`.
- Run `dart format .` before every commit (whole project, never a subset).
- Never pipe `flutter analyze` through `tail`/`head` in a way that masks its exit code.
- New user-visible strings go into `lib/l10n/arb/app_en.arb` **and all 10 other locales** (de, es, fr, it, nl, pt, he, hu, zh) in the same task, then run codegen.
- No emojis in code/comments/docs. Immutability always. No `print` in production code.
- After changing any Drift table: `dart run build_runner build --delete-conflicting-outputs`.
- Tests: run **specific files**, never the whole suite mid-task (too slow). The pre-push hook runs everything.
- Work happens in this worktree (`.claude/worktrees/equipment-attributes`, branch `worktree-equipment-attributes`). Commit after every task.
- Entity-type string for sync is `equipmentAttributes` everywhere (registries, `markRecordPending`, `logDeletion`).
- Canonical metric storage: `valueNum` is always mm/L/bar/kg/m; convert at the UI boundary only, via `UnitFormatter`.

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/database/database.dart` (modify) | `EquipmentAttributes` table, v115 migration, backstop |
| `lib/core/database/performance_indexes.dart` (modify) | canonical index DDL |
| `lib/core/services/sync/sync_data_serializer.dart` (modify) | 14 serializer touch-points |
| `lib/core/services/sync/sync_service.dart` (modify) | `mergeOrder`, `entityHasUpdatedAt`, `parentRefs` |
| `lib/core/data/repositories/sync_repository.dart` (modify) | `_hlcTargets` entry |
| `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (create) | kinds, dimensions, per-type defs, thickness parser |
| `lib/features/equipment/domain/entities/equipment_attribute.dart` (create) | `EquipmentAttribute` entity |
| `lib/features/equipment/domain/entities/equipment_item.dart` (modify) | attributes list + derived getters |
| `lib/features/equipment/data/repositories/equipment_repository_impl.dart` (modify) | attribute CRUD + hydration |
| `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart` (create) | key -> localized label resolver |
| `lib/features/equipment/presentation/utils/equipment_attribute_units.dart` (create) | dimension <-> UnitFormatter bridge |
| `lib/features/equipment/presentation/widgets/equipment_attribute_form_section.dart` (create) | per-type form inputs |
| `lib/features/equipment/presentation/widgets/equipment_custom_fields_section.dart` (create) | custom field rows |
| `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (modify) | swap legacy controllers for sections |
| `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (modify) | attributes card |
| `lib/features/dive_log/domain/models/dive_filter_state.dart` (modify) | attribute filter axis |
| `lib/features/statistics/data/dive_filter_sql.dart` (modify) | attribute EXISTS predicate |
| `lib/features/statistics/data/repositories/statistics_repository.dart` (modify) | `getDivesBySuitThickness` |
| `lib/features/statistics/presentation/providers/statistics_providers.dart` (modify) | chart provider |
| `lib/features/statistics/presentation/pages/statistics_progression_page.dart` (modify) | chart section |
| `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart` (modify) | suit-thickness filter section |
| `lib/core/services/export/csv/csv_export_service.dart` (modify) | Size/Thickness/Attributes columns |

---

### Task 1: Schema, migration v115, legacy-column copy

**Files:**
- Modify: `lib/core/database/database.dart` (table near line 729, after `Equipment`; helper near line 2416; onUpgrade block near line 5545; beforeOpen backstop near line 5577; `currentSchemaVersion` line 2208; `migrationVersions` list ending near line 2324)
- Modify: `lib/core/database/performance_indexes.dart` (append to `kPerformanceIndexes`)
- Modify: `lib/core/services/sync/sync_service.dart` (`parentRefs` map near line 1631 — needed NOW or `sync_parent_refs_completeness_test.dart` fails the moment the table exists)
- Modify: `test/core/database/equipment_set_geofence_schema_test.dart` (relax `== 112` tripwire)
- Test: `test/core/database/migration_v115_equipment_attributes_test.dart` (create)

**Interfaces:**
- Produces: Drift table `equipmentAttributes` with generated row class `EquipmentAttribute` — **NAME COLLISION WARNING:** the domain entity in Task 4 is also called `EquipmentAttribute`; the Drift class for table `EquipmentAttributes` will be named `EquipmentAttribute` by default. Avoid the clash by adding `@DataClassName('EquipmentAttributeRow')` to the table.
- Produces: columns `id, equipment_id, attr_key, is_custom, value_text, value_num, sort_order, created_at, updated_at, hlc`; UNIQUE(equipment_id, attr_key, is_custom).
- Produces: deterministic-ID convention `attr_<equipmentId>_<attrKey>` for curated rows (migration and Task 4 both rely on it).

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v115_equipment_attributes_test.dart`:

```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v115 creates equipment_attributes and copies legacy columns', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 112');
        rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE equipment (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            size TEXT,
            thickness TEXT,
            buoyancy_kg REAL,
            weight_kg REAL,
            status TEXT NOT NULL DEFAULT 'active',
            notes TEXT NOT NULL DEFAULT '',
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute('''
          INSERT INTO equipment
            (id, name, type, size, thickness, buoyancy_kg, weight_kg,
             created_at, updated_at)
          VALUES
            ('eq1', 'Suit', 'wetsuit', 'L', '5/4/3', 2.5, 3.0, 1000, 2000),
            ('eq2', 'Old suit', 'wetsuit', NULL, '6mm', NULL, NULL, 1000, 2000),
            ('eq3', 'Odd', 'wetsuit', NULL, 'thin', NULL, NULL, 1000, 2000),
            ('eq4', 'Reg', 'regulator', NULL, NULL, NULL, NULL, 1000, 2000)
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    Future<Map<String, dynamic>?> attr(String eqId, String key) async {
      final rows = await db
          .customSelect(
            'SELECT * FROM equipment_attributes '
            'WHERE equipment_id = ? AND attr_key = ?',
            variables: [Variable<String>(eqId), Variable<String>(key)],
          )
          .get();
      return rows.isEmpty ? null : rows.single.data;
    }

    // eq1: all four legacy columns copied, deterministic ids, parent timestamps.
    final size = await attr('eq1', 'size');
    expect(size, isNotNull);
    expect(size!['id'], 'attr_eq1_size');
    expect(size['value_text'], 'L');
    expect(size['created_at'], 1000);
    expect(size['updated_at'], 2000);
    expect(size['hlc'], isNull);

    final thick = await attr('eq1', 'thickness_mm');
    expect(thick!['value_text'], '5/4/3');
    expect(thick['value_num'], 5.0);

    expect((await attr('eq1', 'buoyancy_kg'))!['value_num'], 2.5);
    expect((await attr('eq1', 'dry_weight_kg'))!['value_num'], 3.0);

    // eq2: "6mm" parses to 6.0.
    final thick2 = await attr('eq2', 'thickness_mm');
    expect(thick2!['value_num'], 6.0);
    expect(thick2['value_text'], '6mm');

    // eq3: unparseable thickness keeps text, null number.
    final thick3 = await attr('eq3', 'thickness_mm');
    expect(thick3!['value_num'], isNull);
    expect(thick3['value_text'], 'thin');

    // eq4: no legacy values -> no rows.
    expect(await attr('eq4', 'size'), isNull);
    expect(await attr('eq4', 'thickness_mm'), isNull);

    // Indexes exist.
    final indexes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' "
          "AND name LIKE 'idx_equipment_attributes%'",
        )
        .get();
    final names = indexes.map((r) => r.read<String>('name')).toSet();
    expect(names, contains('idx_equipment_attributes_equipment_id'));
    expect(names, contains('idx_equipment_attributes_key_num'));
  });

  test('reopen (beforeOpen backstop) does not resurrect cleared values', () async {
    final dir = await Directory.systemTemp.createTemp('subm_v115_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/test.db';

    // Seed a pre-v115 file-backed schema directly with sqlite3 (a setup
    // callback would re-run on every open and reset user_version).
    final raw = sqlite3.open(path);
    raw.execute('PRAGMA user_version = 112');
    raw.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
    raw.execute('''
      CREATE TABLE equipment (
        id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
        type TEXT NOT NULL, size TEXT, thickness TEXT,
        buoyancy_kg REAL, weight_kg REAL,
        status TEXT NOT NULL DEFAULT 'active',
        notes TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT
      )
    ''');
    raw.execute(
      "INSERT INTO equipment (id, name, type, size, created_at, updated_at) "
      "VALUES ('eq1', 'Suit', 'wetsuit', 'L', 1000, 2000)",
    );
    raw.dispose();

    // First open runs the v115 migration and copies size -> attribute row.
    final db1 = AppDatabase(NativeDatabase(File(path)));
    final migrated = await db1
        .customSelect(
          "SELECT id FROM equipment_attributes WHERE id = 'attr_eq1_size'",
        )
        .get();
    expect(migrated, hasLength(1));

    // User clears the value, then the app restarts.
    await db1.customStatement(
      "DELETE FROM equipment_attributes WHERE id = 'attr_eq1_size'",
    );
    await db1.close();

    // Second open: onUpgrade is skipped (user_version is already 115); the
    // beforeOpen backstop must assert schema only and NOT re-copy data.
    final db2 = AppDatabase(NativeDatabase(File(path)));
    addTearDown(() => db2.close());
    final rows = await db2
        .customSelect(
          "SELECT id FROM equipment_attributes WHERE id = 'attr_eq1_size'",
        )
        .get();
    expect(rows, isEmpty);
  });

  test('v115 is the current schema version (exact-latest tripwire)', () {
    expect(AppDatabase.currentSchemaVersion, 115);
    expect(AppDatabase.migrationVersions, contains(115));
  });

  test('fresh database exposes equipment_attributes via Drift', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());
    expect(await db.select(db.equipmentAttributes).get(), isEmpty);
  });
}
```

Add `import 'package:drift/drift.dart' show Variable;` if the analyzer asks for it.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v115_equipment_attributes_test.dart`
Expected: FAIL — `equipmentAttributes` getter does not exist / no such table.

- [ ] **Step 3: Add the Drift table**

In `lib/core/database/database.dart`, directly after the `Equipment` class (line ~729):

```dart
/// Type-specific and user-defined attributes for equipment items (v115).
/// Curated rows (isCustom = false) use deterministic ids
/// `attr_<equipmentId>_<attrKey>` so independently migrated devices converge;
/// custom rows use random UUIDs. "Unset" is "no row" -- clearing a value
/// deletes the row and writes a tombstone.
@DataClassName('EquipmentAttributeRow')
class EquipmentAttributes extends Table {
  TextColumn get id => text()();
  TextColumn get equipmentId =>
      text().references(Equipment, #id, onDelete: KeyAction.cascade)();
  TextColumn get attrKey => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  TextColumn get valueText => text().nullable()();
  RealColumn get valueNum => real().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {equipmentId, attrKey, isCustom},
  ];
}
```

Add `EquipmentAttributes` to the `@DriftDatabase(tables: [...])` list (search for `EquipmentSetGeofences,` in that list and add `EquipmentAttributes,` after it).

- [ ] **Step 4: Add migration helpers**

Next to `_assertEquipmentThicknessColumn` (line ~2416):

```dart
  /// v115: equipment_attributes table + indexes. Idempotent so it is safe to
  /// call from both onUpgrade and the beforeOpen backstop. Deliberately does
  /// NOT copy legacy data -- see _migrateLegacyEquipmentColumnsToAttributes,
  /// which must run exactly once (re-running it on open would resurrect
  /// attribute rows the user has since cleared).
  Future<void> _assertEquipmentAttributesSchema() async {
    await createMigrator().createTable(equipmentAttributes);
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_equipment_attributes_equipment_id
      ON equipment_attributes(equipment_id)
    ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_equipment_attributes_key_num
      ON equipment_attributes(attr_key, value_num)
    ''');
  }

  /// v115 data copy: legacy equipment.size/thickness/buoyancy_kg/weight_kg
  /// into equipment_attributes rows. Deterministic ids and parent-row
  /// timestamps make the result byte-identical on every device that runs the
  /// migration, so no sync traffic is needed to converge; hlc stays NULL
  /// (LWW falls back to updated_at, same as pre-HLC equipment rows).
  /// INSERT OR IGNORE keeps a re-run harmless, but this is still only called
  /// from onUpgrade (never beforeOpen) to avoid resurrecting cleared values.
  Future<void> _migrateLegacyEquipmentColumnsToAttributes() async {
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_size', id, 'size', 0, TRIM(size), NULL,
             0, created_at, updated_at, NULL
      FROM equipment WHERE size IS NOT NULL AND TRIM(size) != ''
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_thickness_mm', id, 'thickness_mm', 0,
             TRIM(thickness),
             CASE WHEN TRIM(thickness) GLOB '[0-9]*'
                  THEN CAST(TRIM(thickness) AS REAL) ELSE NULL END,
             0, created_at, updated_at, NULL
      FROM equipment WHERE thickness IS NOT NULL AND TRIM(thickness) != ''
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_buoyancy_kg', id, 'buoyancy_kg', 0, NULL,
             buoyancy_kg, 0, created_at, updated_at, NULL
      FROM equipment WHERE buoyancy_kg IS NOT NULL
    ''');
    await customStatement('''
      INSERT OR IGNORE INTO equipment_attributes
        (id, equipment_id, attr_key, is_custom, value_text, value_num,
         sort_order, created_at, updated_at, hlc)
      SELECT 'attr_' || id || '_dry_weight_kg', id, 'dry_weight_kg', 0, NULL,
             weight_kg, 0, created_at, updated_at, NULL
      FROM equipment WHERE weight_kg IS NOT NULL
    ''');
  }
```

- [ ] **Step 5: Wire version, ladder, onUpgrade, backstop, indexes**

1. `static const int currentSchemaVersion = 115;` (line 2208).
2. Append `115,` to `migrationVersions` (list ends near line 2324).
3. In onUpgrade, after the `if (from < 112)` block (line ~5545):

```dart
        if (from < 115) {
          await _assertEquipmentAttributesSchema();
          await _migrateLegacyEquipmentColumnsToAttributes();
        }
        if (from < 115) await reportProgress();
```

4. In beforeOpen, after the v112 backstop (line ~5577):

```dart
        // v115 backstop: re-assert the equipment_attributes table (schema
        // only -- the legacy-column copy must NOT run here, it would
        // resurrect attribute rows the user has cleared).
        await _assertEquipmentAttributesSchema();
```

5. In `lib/core/database/performance_indexes.dart`, append to `kPerformanceIndexes`:

```dart
  (
    name: 'idx_equipment_attributes_equipment_id',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_equipment_attributes_equipment_id '
        'ON equipment_attributes(equipment_id)',
  ),
  (
    name: 'idx_equipment_attributes_key_num',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_equipment_attributes_key_num '
        'ON equipment_attributes(attr_key, value_num)',
  ),
```

6. In `lib/core/services/sync/sync_service.dart` `parentRefs` (line ~1631), after the `serviceRecords` entry:

```dart
      'equipmentAttributes': [
        (field: 'equipmentId', parent: 'equipment', nullable: false),
      ],
```

(The full sync wiring is Task 2 — this entry alone keeps `sync_parent_refs_completeness_test.dart` green once the table exists.)

7. In `lib/core/database/database.dart` `_hlcTables` (line ~2532), add `'equipment_attributes',` after `'equipment_sets',`.

8. Relax the superseded tripwire in `test/core/database/equipment_set_geofence_schema_test.dart` (lines 77-80):

```dart
  test('v112 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(112));
    expect(AppDatabase.migrationVersions, contains(112));
  });
```

- [ ] **Step 6: Codegen and run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/core/database/migration_v115_equipment_attributes_test.dart test/core/database/equipment_set_geofence_schema_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart`
Expected: ALL PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): equipment_attributes table + v115 migration with legacy column copy"
```

---

### Task 2: Sync wiring (serializer + service registries)

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (14 touch-points, all modeled on the existing `equipmentSetGeofences` cases — grep that string to find each site)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` ~line 963, `entityHasUpdatedAt` ~line 1578)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`_hlcTargets` map ~line 49)
- Test: `test/core/services/sync/equipment_attribute_sync_test.dart` (create)

**Interfaces:**
- Consumes: Drift table `equipmentAttributes` / row class `EquipmentAttributeRow` (Task 1).
- Produces: sync entity type string `'equipmentAttributes'` usable with `markRecordPending`, `logDeletion`, and the full serializer surface. Task 4's repository relies on this.

- [ ] **Step 1: Write the failing round-trip test**

Create `test/core/services/sync/equipment_attribute_sync_test.dart` (modeled on `equipment_set_geofence_sync_test.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  Map<String, dynamic> attrJson(String id) => {
    'id': id,
    'equipmentId': 'eq1',
    'attrKey': 'thickness_mm',
    'isCustom': false,
    'valueText': '5/4',
    'valueNum': 5.0,
    'sortOrder': 0,
    'createdAt': 1000,
    'updatedAt': 1000,
    'hlc': null,
  };

  test('equipmentAttributes round-trip through the serializer', () async {
    await serializer.upsertRecord('equipment', {
      'id': 'eq1',
      'name': 'Suit',
      'type': 'wetsuit',
      'status': 'active',
      'purchaseCurrency': 'USD',
      'notes': '',
      'isActive': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecord(
      'equipmentAttributes',
      attrJson('attr_eq1_thickness_mm'),
    );

    final row = await serializer.fetchRecord(
      'equipmentAttributes',
      'attr_eq1_thickness_mm',
    );
    expect(row, isNotNull);
    expect(row!['equipmentId'], 'eq1');
    expect(row['valueNum'], 5.0);
    expect(row['valueText'], '5/4');

    await serializer.deleteRecord(
      'equipmentAttributes',
      'attr_eq1_thickness_mm',
    );
    expect(
      await serializer.fetchRecord(
        'equipmentAttributes',
        'attr_eq1_thickness_mm',
      ),
      isNull,
    );
  });

  test('equipmentAttributes round-trip through batch fetch/upsert', () async {
    await serializer.upsertRecord('equipment', {
      'id': 'eq1',
      'name': 'Suit',
      'type': 'wetsuit',
      'status': 'active',
      'purchaseCurrency': 'USD',
      'notes': '',
      'isActive': true,
      'createdAt': 1000,
      'updatedAt': 1000,
    });
    await serializer.upsertRecords('equipmentAttributes', [
      attrJson('a1'),
      attrJson('a2'),
    ]);
    final fetched = await serializer.fetchRecords('equipmentAttributes', [
      'a1',
      'a2',
    ]);
    expect(fetched.keys, containsAll(['a1', 'a2']));

    final ids = await serializer.recordIdsFor('equipmentAttributes');
    expect(ids, containsAll(['a1', 'a2']));
  });
}
```

Note: `attrJson` reuses one id per test via the parameter — in the batch test pass distinct ids as shown (the UNIQUE(equipmentId, attrKey, isCustom) constraint means real code never writes two curated rows with the same key; for this serializer-level test relax by giving `a2` a different `attrKey`, e.g. copy the map and override `'attrKey': 'size'`).

- [ ] **Step 2: Run tests to verify failure**

Run: `flutter test test/core/services/sync/equipment_attribute_sync_test.dart`
Expected: FAIL — `upsertRecord` throws/falls through for unknown entity `equipmentAttributes`.

- [ ] **Step 3: Wire the serializer (14 sites)**

In `lib/core/services/sync/sync_data_serializer.dart`, add an `equipmentAttributes` case adjacent to each existing `equipmentSetGeofences` case:

1. Field decl (~line 225): `final List<Map<String, dynamic>> equipmentAttributes;`
2. Ctor default (~line 282): `this.equipmentAttributes = const [],`
3. `toJson()` (~line 340): `'equipmentAttributes': equipmentAttributes,`
4. `fromJson()` (~line 399): `equipmentAttributes: _parseList(json['equipmentAttributes']),`
5. Export-descriptor list (~line 595):

```dart
      (
        key: 'equipmentAttributes',
        table: _db.equipmentAttributes,
        blob: false,
        full: null,
      ),
```

6. `_safeExport` call (~line 1003):

```dart
        equipmentAttributes: await _safeExport(
          'equipmentAttributes',
          () => _exportEquipmentAttributes(hlcSince),
        ),
```

7. Export helper (next to `_exportEquipmentSetGeofences`, ~line 3546) — self-hlc filter:

```dart
  Future<List<Map<String, dynamic>>> _exportEquipmentAttributes(
    String? hlcSince,
  ) async {
    final query = _db.select(_db.equipmentAttributes);
    if (hlcSince != null) {
      query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
    }
    final rows = await query.get();
    return rows.map((r) => r.toJson()).toList();
  }
```

8. `fetchRecord` case (~line 1329):

```dart
      case 'equipmentAttributes':
        final row = await (_db.select(
          _db.equipmentAttributes,
        )..where((t) => t.id.equals(recordId))).getSingleOrNull();
        return row?.toJson();
```

9. `fetchRecords` case (~line 1626):

```dart
      case 'equipmentAttributes':
        final rows = await (_db.select(
          _db.equipmentAttributes,
        )..where((t) => t.id.isIn(idList))).get();
        return {for (final r in rows) r.id: r.toJson()};
```

10. `upsertRecord` case (~line 1868) — HLC entity, `.toCompanion(false)`:

```dart
      case 'equipmentAttributes':
        await _db
            .into(_db.equipmentAttributes)
            .insertOnConflictUpdate(
              EquipmentAttributeRow.fromJson(data).toCompanion(false),
            );
        return;
```

11. `upsertRecords` case (~line 2282):

```dart
      case 'equipmentAttributes':
        await _db.batch(
          (b) => b.insertAllOnConflictUpdate(
            _db.equipmentAttributes,
            records
                .map(
                  (r) => EquipmentAttributeRow.fromJson(r).toCompanion(false),
                )
                .toList(),
          ),
        );
        return;
```

12. `recordIdsFor` case (~line 2837): `case 'equipmentAttributes': return plain(_db.equipmentAttributes, _db.equipmentAttributes.id);`
13. `_syncTableFor` case (~line 3008): `case 'equipmentAttributes': return _db.equipmentAttributes;`
14. `deleteRecord` case (~line 3148):

```dart
      case 'equipmentAttributes':
        await (_db.delete(
          _db.equipmentAttributes,
        )..where((t) => t.id.equals(recordId))).go();
        return;
```

- [ ] **Step 4: Wire sync_service.dart and sync_repository.dart**

1. `mergeOrder` (~line 963), immediately after the `equipmentSetGeofences` entry (must apply after parent `equipment`):

```dart
          // Child of equipment; must apply after its parent so the
          // deferred-FK commit sees the equipment row.
          (
            type: 'equipmentAttributes',
            records: data.equipmentAttributes,
            hasUpdatedAt: true,
          ),
```

2. `entityHasUpdatedAt` (~line 1578): `'equipmentAttributes': true,`
3. (`parentRefs` entry already landed in Task 1.)
4. `sync_repository.dart` `_hlcTargets` (~line 49):

```dart
    'equipmentAttributes': (table: 'equipment_attributes', pk: 'id'),
```

- [ ] **Step 5: Run the new test plus structural tests**

Run: `flutter test test/core/services/sync/equipment_attribute_sync_test.dart test/core/services/sync/sync_data_serializer_record_ids_test.dart test/core/services/sync/sync_parent_refs_completeness_test.dart test/core/services/sync/sync_base_streaming_parity_test.dart test/core/services/sync/sync_data_serializer_batch_coverage_test.dart`
Expected: ALL PASS. If a structural test enumerates entities explicitly (rather than reflecting), add `equipmentAttributes` to its list following the pattern of its other entries.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "feat(sync): wire equipmentAttributes through serializer, merge order, and HLC registries"
```

---

### Task 3: Attribute catalog (kinds, dimensions, all 18 types, thickness parser)

**Files:**
- Create: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`
- Test: `test/features/equipment/domain/equipment_attribute_catalog_test.dart` (create)

**Interfaces:**
- Consumes: `EquipmentType` from `lib/core/constants/enums.dart`.
- Produces: `AttributeKind { text, number, thickness, choice, flag, date }`; `AttributeDimension { none, thicknessMm, volumeL, pressureBar, massKg, lengthM, depthM }`; `class EquipmentAttributeDef { String key; AttributeKind kind; AttributeDimension dimension; List<String> choiceKeys; }`; `EquipmentAttributeCatalog.attributesFor(EquipmentType) -> List<EquipmentAttributeDef>`; `EquipmentAttributeCatalog.defFor(String key) -> EquipmentAttributeDef?`; `double? parsePrimaryThickness(String text)`; key constants `EquipmentAttrKeys.size/.thicknessMm/.buoyancyKg/.dryWeightKg`.

- [ ] **Step 1: Write the failing catalog test**

Create `test/features/equipment/domain/equipment_attribute_catalog_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';

void main() {
  test('every equipment type resolves to a definition list', () {
    for (final type in EquipmentType.values) {
      final defs = EquipmentAttributeCatalog.attributesFor(type);
      // Universal attrs are always present.
      expect(
        defs.map((d) => d.key),
        containsAll(['buoyancy_kg', 'dry_weight_kg']),
        reason: '${type.name} missing universal attributes',
      );
      // No duplicate keys within a type.
      final keys = defs.map((d) => d.key).toList();
      expect(keys.toSet().length, keys.length,
          reason: '${type.name} has duplicate keys');
    }
  });

  test('type-specific expectations', () {
    List<String> keysFor(EquipmentType t) =>
        EquipmentAttributeCatalog.attributesFor(t).map((d) => d.key).toList();

    expect(keysFor(EquipmentType.wetsuit),
        containsAll(['size', 'thickness_mm', 'suit_style']));
    expect(
      keysFor(EquipmentType.tank),
      containsAll([
        'volume_l',
        'working_pressure_bar',
        'tank_material',
        'valve_type',
        'tank_identifier',
        'last_visual_inspection',
        'last_hydro_test',
      ]),
    );
    expect(keysFor(EquipmentType.other),
        unorderedEquals(['buoyancy_kg', 'dry_weight_kg']));
  });

  test('choice kinds always have at least two options', () {
    for (final type in EquipmentType.values) {
      for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
        if (def.kind == AttributeKind.choice) {
          expect(def.choiceKeys.length, greaterThanOrEqualTo(2),
              reason: '${def.key} has too few choices');
        } else {
          expect(def.choiceKeys, isEmpty,
              reason: '${def.key} is not a choice but has choiceKeys');
        }
      }
    }
  });

  test('number kinds carry a dimension where units apply', () {
    final expectDim = {
      'volume_l': AttributeDimension.volumeL,
      'working_pressure_bar': AttributeDimension.pressureBar,
      'lift_capacity_kg': AttributeDimension.massKg,
      'buoyancy_kg': AttributeDimension.massKg,
      'dry_weight_kg': AttributeDimension.massKg,
      'length_m': AttributeDimension.lengthM,
      'line_length_m': AttributeDimension.lengthM,
      'depth_rating_m': AttributeDimension.depthM,
      'thickness_mm': AttributeDimension.thicknessMm,
    };
    expectDim.forEach((key, dim) {
      expect(EquipmentAttributeCatalog.defFor(key)?.dimension, dim,
          reason: key);
    });
    // lumens is a dimensionless number.
    expect(EquipmentAttributeCatalog.defFor('lumens')?.dimension,
        AttributeDimension.none);
  });

  test('parsePrimaryThickness handles designations', () {
    expect(parsePrimaryThickness('5'), 5.0);
    expect(parsePrimaryThickness('5/4'), 5.0);
    expect(parsePrimaryThickness('7/5/3'), 7.0);
    expect(parsePrimaryThickness('6mm'), 6.0);
    expect(parsePrimaryThickness('2.5'), 2.5);
    expect(parsePrimaryThickness(' 5/4 '), 5.0);
    expect(parsePrimaryThickness('thin'), isNull);
    expect(parsePrimaryThickness(''), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: FAIL — file/classes do not exist.

- [ ] **Step 3: Implement the catalog**

Create `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`:

```dart
import '../../../../core/constants/enums.dart';

/// How an attribute value is entered, stored, and displayed.
/// Storage contract (equipment_attributes row):
/// - text:      valueText
/// - number:    valueNum in canonical metric (see AttributeDimension)
/// - thickness: valueText holds the designation as written ("5/4/3"),
///              valueNum holds the parsed primary (thickest) panel in mm
/// - choice:    valueText holds the stable option key (never a display string)
/// - flag:      valueNum 0/1
/// - date:      valueNum unix milliseconds
enum AttributeKind { text, number, thickness, choice, flag, date }

/// Unit dimension for number attributes; drives UnitFormatter conversion.
/// thicknessMm always displays in mm (industry convention in every market).
enum AttributeDimension {
  none,
  thicknessMm,
  volumeL,
  pressureBar,
  massKg,
  lengthM,
  depthM,
}

/// Stable attribute keys referenced from more than one file.
abstract final class EquipmentAttrKeys {
  static const size = 'size';
  static const thicknessMm = 'thickness_mm';
  static const buoyancyKg = 'buoyancy_kg';
  static const dryWeightKg = 'dry_weight_kg';
}

class EquipmentAttributeDef {
  /// Stable key, never translated ('thickness_mm'). L10n resolves labels via
  /// attrLabel_<key> and choice options via attrChoice_<key>_<option>.
  final String key;
  final AttributeKind kind;
  final AttributeDimension dimension;
  final List<String> choiceKeys;

  const EquipmentAttributeDef({
    required this.key,
    required this.kind,
    this.dimension = AttributeDimension.none,
    this.choiceKeys = const [],
  });
}

/// Data-driven per-type attribute schema (CertificationLevelCatalog pattern).
abstract final class EquipmentAttributeCatalog {
  /// Present for every equipment type (they replace the v104 columns).
  static const List<EquipmentAttributeDef> universal = [
    EquipmentAttributeDef(
      key: EquipmentAttrKeys.buoyancyKg,
      kind: AttributeKind.number,
      dimension: AttributeDimension.massKg,
    ),
    EquipmentAttributeDef(
      key: EquipmentAttrKeys.dryWeightKg,
      kind: AttributeKind.number,
      dimension: AttributeDimension.massKg,
    ),
  ];

  static const _size = EquipmentAttributeDef(
    key: EquipmentAttrKeys.size,
    kind: AttributeKind.text,
  );
  static const _thickness = EquipmentAttributeDef(
    key: EquipmentAttrKeys.thicknessMm,
    kind: AttributeKind.thickness,
    dimension: AttributeDimension.thicknessMm,
  );

  static const Map<EquipmentType, List<EquipmentAttributeDef>> _byType = {
    EquipmentType.wetsuit: [
      _size,
      _thickness,
      EquipmentAttributeDef(
        key: 'suit_style',
        kind: AttributeKind.choice,
        choiceKeys: ['full', 'shorty', 'two_piece', 'semi_dry'],
      ),
    ],
    EquipmentType.drysuit: [
      _size,
      EquipmentAttributeDef(
        key: 'shell_material',
        kind: AttributeKind.choice,
        choiceKeys: [
          'trilaminate',
          'neoprene',
          'crushed_neoprene',
          'vulcanized_rubber',
        ],
      ),
      EquipmentAttributeDef(
        key: 'seal_type',
        kind: AttributeKind.choice,
        choiceKeys: ['latex', 'silicone', 'neoprene'],
      ),
    ],
    EquipmentType.tank: [
      EquipmentAttributeDef(
        key: 'volume_l',
        kind: AttributeKind.number,
        dimension: AttributeDimension.volumeL,
      ),
      EquipmentAttributeDef(
        key: 'working_pressure_bar',
        kind: AttributeKind.number,
        dimension: AttributeDimension.pressureBar,
      ),
      EquipmentAttributeDef(
        key: 'tank_material',
        kind: AttributeKind.choice,
        choiceKeys: ['aluminum', 'steel', 'carbon_composite'],
      ),
      EquipmentAttributeDef(
        key: 'valve_type',
        kind: AttributeKind.choice,
        choiceKeys: ['din', 'yoke', 'convertible'],
      ),
      EquipmentAttributeDef(key: 'tank_identifier', kind: AttributeKind.text),
      EquipmentAttributeDef(
        key: 'last_visual_inspection',
        kind: AttributeKind.date,
      ),
      EquipmentAttributeDef(key: 'last_hydro_test', kind: AttributeKind.date),
    ],
    EquipmentType.regulator: [
      EquipmentAttributeDef(
        key: 'connection',
        kind: AttributeKind.choice,
        choiceKeys: ['din', 'yoke'],
      ),
      EquipmentAttributeDef(key: 'cold_water_rated', kind: AttributeKind.flag),
    ],
    EquipmentType.bcd: [
      _size,
      EquipmentAttributeDef(
        key: 'bcd_style',
        kind: AttributeKind.choice,
        choiceKeys: ['jacket', 'back_inflate', 'wing', 'sidemount'],
      ),
      EquipmentAttributeDef(
        key: 'lift_capacity_kg',
        kind: AttributeKind.number,
        dimension: AttributeDimension.massKg,
      ),
    ],
    EquipmentType.fins: [
      _size,
      EquipmentAttributeDef(
        key: 'heel_type',
        kind: AttributeKind.choice,
        choiceKeys: ['open_heel', 'full_foot'],
      ),
      EquipmentAttributeDef(
        key: 'blade_style',
        kind: AttributeKind.choice,
        choiceKeys: ['paddle', 'split', 'vented'],
      ),
    ],
    EquipmentType.computer: [
      EquipmentAttributeDef(
        key: 'mount',
        kind: AttributeKind.choice,
        choiceKeys: ['wrist', 'console', 'hud'],
      ),
      EquipmentAttributeDef(
        key: 'connectivity',
        kind: AttributeKind.choice,
        choiceKeys: ['ble', 'usb', 'infrared', 'none'],
      ),
    ],
    EquipmentType.mask: [
      EquipmentAttributeDef(
        key: 'lens_config',
        kind: AttributeKind.choice,
        choiceKeys: ['single', 'twin', 'frameless'],
      ),
      EquipmentAttributeDef(key: 'prescription', kind: AttributeKind.flag),
    ],
    EquipmentType.weights: [
      EquipmentAttributeDef(
        key: 'weight_style',
        kind: AttributeKind.choice,
        choiceKeys: ['belt', 'integrated', 'trim', 'ankle'],
      ),
    ],
    EquipmentType.light: [
      EquipmentAttributeDef(key: 'lumens', kind: AttributeKind.number),
      EquipmentAttributeDef(
        key: 'beam_type',
        kind: AttributeKind.choice,
        choiceKeys: ['spot', 'flood', 'adjustable'],
      ),
    ],
    EquipmentType.camera: [
      EquipmentAttributeDef(
        key: 'depth_rating_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.depthM,
      ),
    ],
    EquipmentType.smb: [
      EquipmentAttributeDef(
        key: 'smb_type',
        kind: AttributeKind.choice,
        choiceKeys: ['open', 'closed'],
      ),
      EquipmentAttributeDef(
        key: 'length_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.lengthM,
      ),
    ],
    EquipmentType.reel: [
      EquipmentAttributeDef(
        key: 'reel_type',
        kind: AttributeKind.choice,
        choiceKeys: ['spool', 'ratchet'],
      ),
      EquipmentAttributeDef(
        key: 'line_length_m',
        kind: AttributeKind.number,
        dimension: AttributeDimension.lengthM,
      ),
    ],
    EquipmentType.knife: [
      EquipmentAttributeDef(
        key: 'blade_material',
        kind: AttributeKind.choice,
        choiceKeys: ['stainless', 'titanium'],
      ),
      EquipmentAttributeDef(
        key: 'tip_type',
        kind: AttributeKind.choice,
        choiceKeys: ['pointed', 'blunt', 'line_cutter'],
      ),
    ],
    EquipmentType.hood: [_size, _thickness],
    EquipmentType.gloves: [
      _size,
      _thickness,
      EquipmentAttributeDef(
        key: 'glove_type',
        kind: AttributeKind.choice,
        choiceKeys: ['five_finger', 'mitt', 'dry'],
      ),
    ],
    EquipmentType.boots: [
      _size,
      _thickness,
      EquipmentAttributeDef(
        key: 'sole_type',
        kind: AttributeKind.choice,
        choiceKeys: ['hard', 'soft'],
      ),
    ],
    EquipmentType.other: [],
  };

  /// Curated attributes for [type]: type-specific first, then universal.
  static List<EquipmentAttributeDef> attributesFor(EquipmentType type) => [
    ...(_byType[type] ?? const []),
    ...universal,
  ];

  static final Map<String, EquipmentAttributeDef> _byKey = {
    for (final defs in _byType.values)
      for (final def in defs) def.key: def,
    for (final def in universal) def.key: def,
  };

  /// Definition for a curated key, or null for unknown/custom keys.
  static EquipmentAttributeDef? defFor(String key) => _byKey[key];
}

/// Parses the primary (thickest, written-first) panel from a thickness
/// designation: "5" -> 5, "5/4" -> 5, "7/5/3" -> 7, "6mm" -> 6, "thin" -> null.
double? parsePrimaryThickness(String text) {
  final match = RegExp(r'^\s*(\d+(?:\.\d+)?)').firstMatch(text);
  if (match == null) return null;
  return double.parse(match.group(1)!);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): attribute catalog for all 18 equipment types"
```

---

### Task 4: L10n keys (all 11 locales) + label resolver

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (+ `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_he.arb`, `app_hu.arb`, `app_zh.arb`)
- Create: `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart`
- Test: `test/features/equipment/presentation/equipment_attribute_l10n_test.dart` (create)

**Interfaces:**
- Consumes: `EquipmentAttributeCatalog`, `AttributeKind` (Task 3); generated `AppLocalizations` (import `package:submersion/l10n/arb/app_localizations.dart`).
- Produces: `String attributeLabel(AppLocalizations l10n, String key)` and `String attributeChoiceLabel(AppLocalizations l10n, String key, String option)`. Unknown keys return the raw key/option (that is what custom fields render).

- [ ] **Step 1: Write the failing resolver test**

Create `test/features/equipment/presentation/equipment_attribute_l10n_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('every catalog key has a localized label', () {
    for (final type in EquipmentType.values) {
      for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
        final label = attributeLabel(l10n, def.key);
        expect(label, isNotEmpty);
        expect(label, isNot(def.key),
            reason: 'attrLabel missing for ${def.key}');
      }
    }
  });

  test('every choice option has a localized label', () {
    for (final type in EquipmentType.values) {
      for (final def in EquipmentAttributeCatalog.attributesFor(type)) {
        for (final option in def.choiceKeys) {
          final label = attributeChoiceLabel(l10n, def.key, option);
          expect(label, isNotEmpty);
          expect(label, isNot(option),
              reason: 'attrChoice missing for ${def.key}/$option');
        }
      }
    }
  });

  test('unknown keys fall back to the raw key (custom fields)', () {
    expect(attributeLabel(l10n, 'my_custom_field'), 'my_custom_field');
    expect(attributeChoiceLabel(l10n, 'foo', 'bar'), 'bar');
  });
}
```

Add `import 'dart:ui' show Locale;` if the analyzer needs it.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/equipment_attribute_l10n_test.dart`
Expected: FAIL — resolver file does not exist.

- [ ] **Step 3: Add the English ARB entries**

Append to `lib/l10n/arb/app_en.arb` (before the closing `}`, keeping JSON valid — plain strings, no placeholders; unit symbols are appended programmatically by the form/display code):

```json
  "attrLabel_size": "Size",
  "attrLabel_thickness_mm": "Thickness (mm)",
  "attrLabel_suit_style": "Suit style",
  "attrLabel_shell_material": "Shell material",
  "attrLabel_seal_type": "Seal type",
  "attrLabel_volume_l": "Volume",
  "attrLabel_working_pressure_bar": "Working pressure",
  "attrLabel_tank_material": "Material",
  "attrLabel_valve_type": "Valve",
  "attrLabel_tank_identifier": "Identifier",
  "attrLabel_last_visual_inspection": "Last visual inspection",
  "attrLabel_last_hydro_test": "Last hydrostatic test",
  "attrLabel_connection": "Connection",
  "attrLabel_cold_water_rated": "Cold-water rated",
  "attrLabel_bcd_style": "Style",
  "attrLabel_lift_capacity_kg": "Lift capacity",
  "attrLabel_heel_type": "Heel",
  "attrLabel_blade_style": "Blade",
  "attrLabel_mount": "Mount",
  "attrLabel_connectivity": "Connectivity",
  "attrLabel_lens_config": "Lens",
  "attrLabel_prescription": "Prescription lenses",
  "attrLabel_weight_style": "Style",
  "attrLabel_lumens": "Lumens",
  "attrLabel_beam_type": "Beam",
  "attrLabel_depth_rating_m": "Depth rating",
  "attrLabel_smb_type": "Type",
  "attrLabel_length_m": "Length",
  "attrLabel_reel_type": "Type",
  "attrLabel_line_length_m": "Line length",
  "attrLabel_blade_material": "Blade material",
  "attrLabel_tip_type": "Tip",
  "attrLabel_glove_type": "Type",
  "attrLabel_sole_type": "Sole",
  "attrLabel_buoyancy_kg": "Buoyancy",
  "attrLabel_dry_weight_kg": "Dry weight",
  "attrChoice_suit_style_full": "Full suit",
  "attrChoice_suit_style_shorty": "Shorty",
  "attrChoice_suit_style_two_piece": "Two-piece",
  "attrChoice_suit_style_semi_dry": "Semi-dry",
  "attrChoice_shell_material_trilaminate": "Trilaminate",
  "attrChoice_shell_material_neoprene": "Neoprene",
  "attrChoice_shell_material_crushed_neoprene": "Crushed neoprene",
  "attrChoice_shell_material_vulcanized_rubber": "Vulcanized rubber",
  "attrChoice_seal_type_latex": "Latex",
  "attrChoice_seal_type_silicone": "Silicone",
  "attrChoice_seal_type_neoprene": "Neoprene",
  "attrChoice_tank_material_aluminum": "Aluminum",
  "attrChoice_tank_material_steel": "Steel",
  "attrChoice_tank_material_carbon_composite": "Carbon composite",
  "attrChoice_valve_type_din": "DIN",
  "attrChoice_valve_type_yoke": "Yoke",
  "attrChoice_valve_type_convertible": "Convertible",
  "attrChoice_connection_din": "DIN",
  "attrChoice_connection_yoke": "Yoke",
  "attrChoice_bcd_style_jacket": "Jacket",
  "attrChoice_bcd_style_back_inflate": "Back-inflate",
  "attrChoice_bcd_style_wing": "Wing",
  "attrChoice_bcd_style_sidemount": "Sidemount",
  "attrChoice_heel_type_open_heel": "Open heel",
  "attrChoice_heel_type_full_foot": "Full foot",
  "attrChoice_blade_style_paddle": "Paddle",
  "attrChoice_blade_style_split": "Split",
  "attrChoice_blade_style_vented": "Vented",
  "attrChoice_mount_wrist": "Wrist",
  "attrChoice_mount_console": "Console",
  "attrChoice_mount_hud": "HUD",
  "attrChoice_connectivity_ble": "Bluetooth (BLE)",
  "attrChoice_connectivity_usb": "USB",
  "attrChoice_connectivity_infrared": "Infrared",
  "attrChoice_connectivity_none": "None",
  "attrChoice_lens_config_single": "Single lens",
  "attrChoice_lens_config_twin": "Twin lens",
  "attrChoice_lens_config_frameless": "Frameless",
  "attrChoice_weight_style_belt": "Belt",
  "attrChoice_weight_style_integrated": "Integrated",
  "attrChoice_weight_style_trim": "Trim",
  "attrChoice_weight_style_ankle": "Ankle",
  "attrChoice_beam_type_spot": "Spot",
  "attrChoice_beam_type_flood": "Flood",
  "attrChoice_beam_type_adjustable": "Adjustable",
  "attrChoice_smb_type_open": "Open",
  "attrChoice_smb_type_closed": "Closed",
  "attrChoice_reel_type_spool": "Spool",
  "attrChoice_reel_type_ratchet": "Ratchet",
  "attrChoice_blade_material_stainless": "Stainless steel",
  "attrChoice_blade_material_titanium": "Titanium",
  "attrChoice_tip_type_pointed": "Pointed",
  "attrChoice_tip_type_blunt": "Blunt",
  "attrChoice_tip_type_line_cutter": "Line cutter",
  "attrChoice_glove_type_five_finger": "Five-finger",
  "attrChoice_glove_type_mitt": "Mitt",
  "attrChoice_glove_type_dry": "Dry",
  "attrChoice_sole_type_hard": "Hard sole",
  "attrChoice_sole_type_soft": "Soft sole"
```

- [ ] **Step 4: Translate into the 10 other locales**

Add the same 95 keys to each of `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_he.arb`, `app_hu.arb`, `app_zh.arb` with natural translations of the English values (translate the values yourself — you are capable; keep dive-industry terms conventional per language, e.g. German "DIN" stays "DIN", "Trilaminat", "Halbtrocken" for semi-dry; Chinese uses standard diving vocabulary). Keep the key names byte-identical.

Then run: `flutter gen-l10n`
Expected: no errors; `AppLocalizations` gains the new getters.

- [ ] **Step 5: Implement the resolver**

Create `lib/features/equipment/presentation/utils/equipment_attribute_l10n.dart`:

```dart
import '../../../../l10n/arb/app_localizations.dart';

/// Localized label for a curated attribute key. Custom-field keys (anything
/// not in the switch) fall back to the raw key, which IS the user's label.
String attributeLabel(AppLocalizations l10n, String key) => switch (key) {
  'size' => l10n.attrLabel_size,
  'thickness_mm' => l10n.attrLabel_thickness_mm,
  'suit_style' => l10n.attrLabel_suit_style,
  'shell_material' => l10n.attrLabel_shell_material,
  'seal_type' => l10n.attrLabel_seal_type,
  'volume_l' => l10n.attrLabel_volume_l,
  'working_pressure_bar' => l10n.attrLabel_working_pressure_bar,
  'tank_material' => l10n.attrLabel_tank_material,
  'valve_type' => l10n.attrLabel_valve_type,
  'tank_identifier' => l10n.attrLabel_tank_identifier,
  'last_visual_inspection' => l10n.attrLabel_last_visual_inspection,
  'last_hydro_test' => l10n.attrLabel_last_hydro_test,
  'connection' => l10n.attrLabel_connection,
  'cold_water_rated' => l10n.attrLabel_cold_water_rated,
  'bcd_style' => l10n.attrLabel_bcd_style,
  'lift_capacity_kg' => l10n.attrLabel_lift_capacity_kg,
  'heel_type' => l10n.attrLabel_heel_type,
  'blade_style' => l10n.attrLabel_blade_style,
  'mount' => l10n.attrLabel_mount,
  'connectivity' => l10n.attrLabel_connectivity,
  'lens_config' => l10n.attrLabel_lens_config,
  'prescription' => l10n.attrLabel_prescription,
  'weight_style' => l10n.attrLabel_weight_style,
  'lumens' => l10n.attrLabel_lumens,
  'beam_type' => l10n.attrLabel_beam_type,
  'depth_rating_m' => l10n.attrLabel_depth_rating_m,
  'smb_type' => l10n.attrLabel_smb_type,
  'length_m' => l10n.attrLabel_length_m,
  'reel_type' => l10n.attrLabel_reel_type,
  'line_length_m' => l10n.attrLabel_line_length_m,
  'blade_material' => l10n.attrLabel_blade_material,
  'tip_type' => l10n.attrLabel_tip_type,
  'glove_type' => l10n.attrLabel_glove_type,
  'sole_type' => l10n.attrLabel_sole_type,
  'buoyancy_kg' => l10n.attrLabel_buoyancy_kg,
  'dry_weight_kg' => l10n.attrLabel_dry_weight_kg,
  _ => key,
};

/// Localized label for a choice option. Unknown pairs fall back to the raw
/// option key.
String attributeChoiceLabel(
  AppLocalizations l10n,
  String key,
  String option,
) => switch ('${key}_$option') {
  'suit_style_full' => l10n.attrChoice_suit_style_full,
  'suit_style_shorty' => l10n.attrChoice_suit_style_shorty,
  'suit_style_two_piece' => l10n.attrChoice_suit_style_two_piece,
  'suit_style_semi_dry' => l10n.attrChoice_suit_style_semi_dry,
  'shell_material_trilaminate' => l10n.attrChoice_shell_material_trilaminate,
  'shell_material_neoprene' => l10n.attrChoice_shell_material_neoprene,
  'shell_material_crushed_neoprene' =>
    l10n.attrChoice_shell_material_crushed_neoprene,
  'shell_material_vulcanized_rubber' =>
    l10n.attrChoice_shell_material_vulcanized_rubber,
  'seal_type_latex' => l10n.attrChoice_seal_type_latex,
  'seal_type_silicone' => l10n.attrChoice_seal_type_silicone,
  'seal_type_neoprene' => l10n.attrChoice_seal_type_neoprene,
  'tank_material_aluminum' => l10n.attrChoice_tank_material_aluminum,
  'tank_material_steel' => l10n.attrChoice_tank_material_steel,
  'tank_material_carbon_composite' =>
    l10n.attrChoice_tank_material_carbon_composite,
  'valve_type_din' => l10n.attrChoice_valve_type_din,
  'valve_type_yoke' => l10n.attrChoice_valve_type_yoke,
  'valve_type_convertible' => l10n.attrChoice_valve_type_convertible,
  'connection_din' => l10n.attrChoice_connection_din,
  'connection_yoke' => l10n.attrChoice_connection_yoke,
  'bcd_style_jacket' => l10n.attrChoice_bcd_style_jacket,
  'bcd_style_back_inflate' => l10n.attrChoice_bcd_style_back_inflate,
  'bcd_style_wing' => l10n.attrChoice_bcd_style_wing,
  'bcd_style_sidemount' => l10n.attrChoice_bcd_style_sidemount,
  'heel_type_open_heel' => l10n.attrChoice_heel_type_open_heel,
  'heel_type_full_foot' => l10n.attrChoice_heel_type_full_foot,
  'blade_style_paddle' => l10n.attrChoice_blade_style_paddle,
  'blade_style_split' => l10n.attrChoice_blade_style_split,
  'blade_style_vented' => l10n.attrChoice_blade_style_vented,
  'mount_wrist' => l10n.attrChoice_mount_wrist,
  'mount_console' => l10n.attrChoice_mount_console,
  'mount_hud' => l10n.attrChoice_mount_hud,
  'connectivity_ble' => l10n.attrChoice_connectivity_ble,
  'connectivity_usb' => l10n.attrChoice_connectivity_usb,
  'connectivity_infrared' => l10n.attrChoice_connectivity_infrared,
  'connectivity_none' => l10n.attrChoice_connectivity_none,
  'lens_config_single' => l10n.attrChoice_lens_config_single,
  'lens_config_twin' => l10n.attrChoice_lens_config_twin,
  'lens_config_frameless' => l10n.attrChoice_lens_config_frameless,
  'weight_style_belt' => l10n.attrChoice_weight_style_belt,
  'weight_style_integrated' => l10n.attrChoice_weight_style_integrated,
  'weight_style_trim' => l10n.attrChoice_weight_style_trim,
  'weight_style_ankle' => l10n.attrChoice_weight_style_ankle,
  'beam_type_spot' => l10n.attrChoice_beam_type_spot,
  'beam_type_flood' => l10n.attrChoice_beam_type_flood,
  'beam_type_adjustable' => l10n.attrChoice_beam_type_adjustable,
  'smb_type_open' => l10n.attrChoice_smb_type_open,
  'smb_type_closed' => l10n.attrChoice_smb_type_closed,
  'reel_type_spool' => l10n.attrChoice_reel_type_spool,
  'reel_type_ratchet' => l10n.attrChoice_reel_type_ratchet,
  'blade_material_stainless' => l10n.attrChoice_blade_material_stainless,
  'blade_material_titanium' => l10n.attrChoice_blade_material_titanium,
  'tip_type_pointed' => l10n.attrChoice_tip_type_pointed,
  'tip_type_blunt' => l10n.attrChoice_tip_type_blunt,
  'tip_type_line_cutter' => l10n.attrChoice_tip_type_line_cutter,
  'glove_type_five_finger' => l10n.attrChoice_glove_type_five_finger,
  'glove_type_mitt' => l10n.attrChoice_glove_type_mitt,
  'glove_type_dry' => l10n.attrChoice_glove_type_dry,
  'sole_type_hard' => l10n.attrChoice_sole_type_hard,
  'sole_type_soft' => l10n.attrChoice_sole_type_soft,
  _ => option,
};
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/equipment/presentation/equipment_attribute_l10n_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): attribute labels in all 11 locales with resolver"
```

---

### Task 5: Domain entity, repository CRUD, derived getters, consumer switchover

This is the pivot task: `EquipmentItem` stops carrying `size`/`thickness`/`buoyancyKg`/`weightKg` as constructor fields and derives them from an `attributes` list instead, so every existing reader (weight planner, CSV export, detail page) keeps compiling unchanged while storage moves to the new table.

**Files:**
- Create: `lib/features/equipment/domain/entities/equipment_attribute.dart`
- Modify: `lib/features/equipment/domain/entities/equipment_item.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (minimal: keep existing controllers but route their values through `attributes` — the real form lands in Task 6)
- Modify: any test constructing `EquipmentItem(size: ..., thickness: ..., buoyancyKg: ..., weightKg: ...)` (find with `flutter analyze`)
- Test: `test/features/equipment/data/equipment_attribute_repository_test.dart` (create)

**Interfaces:**
- Consumes: table + sync entity `'equipmentAttributes'` (Tasks 1-2), `EquipmentAttrKeys` (Task 3).
- Produces:
  - `class EquipmentAttribute { String id, equipmentId, key; bool isCustom; String? valueText; double? valueNum; int sortOrder; }` with `factory EquipmentAttribute.curated({required String equipmentId, required String key, String? valueText, double? valueNum})` and `static String curatedId(String equipmentId, String key)`.
  - `EquipmentItem.attributes: List<EquipmentAttribute>` (ctor param, default `const []`), `String? attrText(String key)`, `double? attrNum(String key)`, and derived getters `size`, `thickness`, `buoyancyKg`, `weightKg`.
  - Repository: `Future<List<EquipmentAttribute>> getAttributesForEquipment(String equipmentId)`, `Future<Map<String, List<EquipmentAttribute>>> getAttributesForEquipmentIds(List<String> ids)`, `Future<void> saveAttributes(String equipmentId, List<EquipmentAttribute> desired)`.

- [ ] **Step 1: Write the failing repository test**

Create `test/features/equipment/data/equipment_attribute_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../helpers/test_database.dart';

void main() {
  late EquipmentRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  EquipmentItem suit({List<EquipmentAttribute> attributes = const []}) =>
      EquipmentItem(
        id: '',
        name: 'Suit',
        type: EquipmentType.wetsuit,
        attributes: attributes,
      );

  test('create persists attributes with deterministic curated ids', () async {
    final created = await repository.createEquipment(
      suit(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'thickness_mm',
            valueText: '5/4',
            valueNum: 5.0,
          ),
          const EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: 'Favorite color',
            isCustom: true,
            valueText: 'blue',
          ),
        ],
      ),
    );

    final loaded = await repository.getEquipmentById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.thickness, '5/4');
    expect(loaded.attrNum('thickness_mm'), 5.0);

    final thickness = loaded.attributes.firstWhere(
      (a) => a.key == 'thickness_mm',
    );
    expect(thickness.id, 'attr_${created.id}_thickness_mm');

    final custom = loaded.attributes.firstWhere((a) => a.isCustom);
    expect(custom.valueText, 'blue');
    expect(custom.id, isNotEmpty);
  });

  test('update diffs: changed values update, removed rows tombstone', () async {
    final created = await repository.createEquipment(
      suit(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'thickness_mm',
            valueText: '5',
            valueNum: 5.0,
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'size',
            valueText: 'L',
          ),
        ],
      ),
    );

    // Change thickness, drop size.
    await repository.updateEquipment(
      (await repository.getEquipmentById(created.id))!.copyWith(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: created.id,
            key: 'thickness_mm',
            valueText: '7',
            valueNum: 7.0,
          ),
        ],
      ),
    );

    final loaded = await repository.getEquipmentById(created.id);
    expect(loaded!.thickness, '7');
    expect(loaded.size, isNull);

    // Tombstone written for the cleared attribute.
    final db = DatabaseService.instance.database;
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log "
          "WHERE entity_type = 'equipmentAttributes'",
        )
        .get();
    expect(
      tombstones.map((r) => r.read<String>('record_id')),
      contains('attr_${created.id}_size'),
    );
  });

  test('getAllEquipment hydrates attributes in one batch', () async {
    await repository.createEquipment(
      suit(
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'thickness_mm',
            valueText: '3',
            valueNum: 3.0,
          ),
        ],
      ),
    );
    final all = await repository.getAllEquipment();
    expect(all.single.thickness, '3');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/data/equipment_attribute_repository_test.dart`
Expected: FAIL — `EquipmentAttribute` / `attributes` do not exist.

- [ ] **Step 3: Create the domain entity**

Create `lib/features/equipment/domain/entities/equipment_attribute.dart`:

```dart
import 'package:equatable/equatable.dart';

/// One attribute value on an equipment item. Curated attributes (isCustom =
/// false) have keys defined in EquipmentAttributeCatalog and deterministic
/// ids; custom fields carry the user's label in [key] and a random UUID id.
class EquipmentAttribute extends Equatable {
  final String id;
  final String equipmentId;
  final String key;
  final bool isCustom;
  final String? valueText;
  final double? valueNum;
  final int sortOrder;

  const EquipmentAttribute({
    required this.id,
    required this.equipmentId,
    required this.key,
    this.isCustom = false,
    this.valueText,
    this.valueNum,
    this.sortOrder = 0,
  });

  factory EquipmentAttribute.curated({
    required String equipmentId,
    required String key,
    String? valueText,
    double? valueNum,
  }) => EquipmentAttribute(
    id: curatedId(equipmentId, key),
    equipmentId: equipmentId,
    key: key,
    valueText: valueText,
    valueNum: valueNum,
  );

  /// Deterministic id for curated rows: identical on every device, so
  /// independently created/migrated rows converge under sync.
  static String curatedId(String equipmentId, String key) =>
      'attr_${equipmentId}_$key';

  bool get hasValue =>
      (valueText != null && valueText!.trim().isNotEmpty) || valueNum != null;

  EquipmentAttribute copyWith({
    String? id,
    String? equipmentId,
    String? key,
    bool? isCustom,
    String? valueText,
    double? valueNum,
    int? sortOrder,
    bool clearValueText = false,
    bool clearValueNum = false,
  }) => EquipmentAttribute(
    id: id ?? this.id,
    equipmentId: equipmentId ?? this.equipmentId,
    key: key ?? this.key,
    isCustom: isCustom ?? this.isCustom,
    valueText: clearValueText ? null : (valueText ?? this.valueText),
    valueNum: clearValueNum ? null : (valueNum ?? this.valueNum),
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  List<Object?> get props => [
    id,
    equipmentId,
    key,
    isCustom,
    valueText,
    valueNum,
    sortOrder,
  ];
}
```

- [ ] **Step 4: Rework EquipmentItem**

In `lib/features/equipment/domain/entities/equipment_item.dart`:

1. Remove the four fields and their ctor params: `size`, `thickness`, `buoyancyKg`, `weightKg`.
2. Add `final List<EquipmentAttribute> attributes;` with ctor param `this.attributes = const [],` and import the new entity plus `../constants/equipment_attribute_catalog.dart` (for `EquipmentAttrKeys`).
3. Add derived accessors:

```dart
  /// Curated attribute lookup helpers. Legacy field names are preserved as
  /// getters so existing consumers (weight planner, CSV export, detail page)
  /// read from the attribute store transparently.
  String? attrText(String key) {
    for (final a in attributes) {
      if (!a.isCustom && a.key == key) return a.valueText;
    }
    return null;
  }

  double? attrNum(String key) {
    for (final a in attributes) {
      if (!a.isCustom && a.key == key) return a.valueNum;
    }
    return null;
  }

  String? get size => attrText(EquipmentAttrKeys.size);
  String? get thickness => attrText(EquipmentAttrKeys.thicknessMm);
  double? get buoyancyKg => attrNum(EquipmentAttrKeys.buoyancyKg);
  double? get weightKg => attrNum(EquipmentAttrKeys.dryWeightKg);
```

4. In `copyWith`: remove the four params, add `List<EquipmentAttribute>? attributes` -> `attributes: attributes ?? this.attributes,`.
5. In `props`: remove the four entries, add `attributes`.

- [ ] **Step 5: Rework the repository**

In `lib/features/equipment/data/repositories/equipment_repository_impl.dart`:

1. Add attribute CRUD (import the entity; `EquipmentAttributeRow`/`EquipmentAttributesCompanion` come from database.dart):

```dart
  EquipmentAttribute _mapAttributeRow(EquipmentAttributeRow row) =>
      EquipmentAttribute(
        id: row.id,
        equipmentId: row.equipmentId,
        key: row.attrKey,
        isCustom: row.isCustom,
        valueText: row.valueText,
        valueNum: row.valueNum,
        sortOrder: row.sortOrder,
      );

  Future<List<EquipmentAttribute>> getAttributesForEquipment(
    String equipmentId,
  ) async {
    final rows =
        await (_db.select(_db.equipmentAttributes)
              ..where((t) => t.equipmentId.equals(equipmentId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return rows.map(_mapAttributeRow).toList();
  }

  Future<Map<String, List<EquipmentAttribute>>> getAttributesForEquipmentIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final rows =
        await (_db.select(_db.equipmentAttributes)
              ..where((t) => t.equipmentId.isIn(ids))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final byEquipment = <String, List<EquipmentAttribute>>{};
    for (final row in rows) {
      byEquipment.putIfAbsent(row.equipmentId, () => []).add(
        _mapAttributeRow(row),
      );
    }
    return byEquipment;
  }

  /// Writes the desired end state of [equipmentId]'s attributes: inserts and
  /// updates changed rows, deletes (with a tombstone) rows no longer present.
  /// Curated ids are normalized to the deterministic form here so callers
  /// building attributes before the equipment id exists still converge.
  Future<void> saveAttributes(
    String equipmentId,
    List<EquipmentAttribute> desired,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final normalized = desired.where((a) => a.hasValue).map((a) {
      if (a.isCustom) {
        return a.copyWith(
          equipmentId: equipmentId,
          id: a.id.isNotEmpty ? a.id : _uuid.v4(),
        );
      }
      return a.copyWith(
        equipmentId: equipmentId,
        id: EquipmentAttribute.curatedId(equipmentId, a.key),
      );
    }).toList();

    final existingRows = await (_db.select(
      _db.equipmentAttributes,
    )..where((t) => t.equipmentId.equals(equipmentId))).get();
    final existingById = {for (final r in existingRows) r.id: r};
    final desiredIds = normalized.map((a) => a.id).toSet();
    final pendingIds = <String>[];

    await _db.transaction(() async {
      for (final row in existingRows) {
        if (desiredIds.contains(row.id)) continue;
        await (_db.delete(
          _db.equipmentAttributes,
        )..where((t) => t.id.equals(row.id))).go();
        await _syncRepository.logDeletion(
          entityType: 'equipmentAttributes',
          recordId: row.id,
        );
      }

      for (final attr in normalized) {
        final existing = existingById[attr.id];
        final unchanged =
            existing != null &&
            existing.attrKey == attr.key &&
            existing.valueText == attr.valueText &&
            existing.valueNum == attr.valueNum &&
            existing.sortOrder == attr.sortOrder;
        if (unchanged) continue;

        await _db
            .into(_db.equipmentAttributes)
            .insertOnConflictUpdate(
              EquipmentAttributesCompanion(
                id: Value(attr.id),
                equipmentId: Value(equipmentId),
                attrKey: Value(attr.key),
                isCustom: Value(attr.isCustom),
                valueText: Value(attr.valueText),
                valueNum: Value(attr.valueNum),
                sortOrder: Value(attr.sortOrder),
                createdAt: Value(existing?.createdAt ?? now),
                updatedAt: Value(now),
              ),
            );
        pendingIds.add(attr.id);
      }
    });

    for (final id in pendingIds) {
      await _syncRepository.markRecordPending(
        entityType: 'equipmentAttributes',
        recordId: id,
        localUpdatedAt: now,
      );
    }
  }
```

2. In `createEquipment`: delete the `size:`, `thickness:`, `buoyancyKg:`, `weightKg:` lines from the companion; after the insert (before `markRecordPending` for the equipment row) add `await saveAttributes(id, equipment.attributes);` and change the return to `equipment.copyWith(id: id, attributes: await getAttributesForEquipment(id));`.
3. In `updateEquipment`: delete the same four companion lines; after the `.write(...)` add `await saveAttributes(equipment.id, equipment.attributes);`.
4. In `_mapRowToEquipment`: remove the four legacy mappings; add an `attributes` parameter: `EquipmentItem _mapRowToEquipment(EquipmentData row, {List<EquipmentAttribute> attributes = const []})` ending with `attributes: attributes,`.
5. In `getEquipmentById`: pass `attributes: await getAttributesForEquipment(id)`.
6. In `getAllEquipment` (and any other list read like `getEquipmentByStatus`): after fetching rows, batch-hydrate:

```dart
      final attrsById = await getAttributesForEquipmentIds(
        rows.map((r) => r.id).toList(),
      );
      return rows
          .map(
            (row) => _mapRowToEquipment(
              row,
              attributes: attrsById[row.id] ?? const [],
            ),
          )
          .toList();
```

7. In the raw-SQL `searchEquipment` mapper: remove the `size` mapping and hydrate the same way (collect ids, one `getAttributesForEquipmentIds` call, pass into the mapper).

- [ ] **Step 6: Patch the edit page minimally (temporary bridge until Task 6)**

In `equipment_edit_page.dart` `_saveEquipment`, replace the `size:`, `thickness:`, `buoyancyKg:`, `weightKg:` arguments with:

```dart
        attributes: [
          if (_sizeController.text.trim().isNotEmpty)
            EquipmentAttribute.curated(
              equipmentId: widget.equipmentId ?? '',
              key: EquipmentAttrKeys.size,
              valueText: _sizeController.text.trim(),
            ),
          if (_thicknessController.text.trim().isNotEmpty)
            EquipmentAttribute.curated(
              equipmentId: widget.equipmentId ?? '',
              key: EquipmentAttrKeys.thicknessMm,
              valueText: _thicknessController.text.trim(),
              valueNum: parsePrimaryThickness(_thicknessController.text),
            ),
          if (_buoyancyController.text.isNotEmpty &&
              _parseWeightToKg(_buoyancyController.text) != null)
            EquipmentAttribute.curated(
              equipmentId: widget.equipmentId ?? '',
              key: EquipmentAttrKeys.buoyancyKg,
              valueNum: _parseWeightToKg(_buoyancyController.text),
            ),
          if (_dryWeightController.text.isNotEmpty &&
              _parseWeightToKg(_dryWeightController.text) != null)
            EquipmentAttribute.curated(
              equipmentId: widget.equipmentId ?? '',
              key: EquipmentAttrKeys.dryWeightKg,
              valueNum: _parseWeightToKg(_dryWeightController.text),
            ),
          ...?_existingCustomAttributes,
        ],
```

Add a state field `List<EquipmentAttribute>? _existingCustomAttributes;` populated in the load path from `equipment.attributes.where((a) => a.isCustom)` so a Task 5 save does not wipe custom fields created later (it is empty until Task 6 ships the editor; keep it for forward-compatibility). The load path (`_populateFields` or equivalent) reads `equipment.size` / `equipment.thickness` / getters exactly as before — they still exist as derived getters.

- [ ] **Step 7: Fix the analyzer fallout**

Run: `flutter analyze`
Every error will be an `EquipmentItem(...)` construction passing the removed params (tests such as `test/features/equipment/data/equipment_buoyancy_fields_test.dart`, `test/features/equipment/presentation/equipment_edit_advanced_test.dart`, possibly seeds/fixtures). Fix each mechanically:

```dart
// BEFORE
EquipmentItem(id: '', name: 'X', type: EquipmentType.wetsuit,
    size: 'L', thickness: '5', buoyancyKg: 2.0, weightKg: 3.0)
// AFTER
EquipmentItem(id: '', name: 'X', type: EquipmentType.wetsuit,
    attributes: [
      EquipmentAttribute.curated(equipmentId: '', key: 'size', valueText: 'L'),
      EquipmentAttribute.curated(
          equipmentId: '', key: 'thickness_mm', valueText: '5', valueNum: 5.0),
      EquipmentAttribute.curated(
          equipmentId: '', key: 'buoyancy_kg', valueNum: 2.0),
      EquipmentAttribute.curated(
          equipmentId: '', key: 'dry_weight_kg', valueNum: 3.0),
    ])
```

Readers (`item.size`, `item.buoyancyKg`, weight planner `gearFeatureFor`, CSV) need NO change — the getters cover them.

- [ ] **Step 8: Run tests**

Run: `flutter test test/features/equipment/ test/core/services/sync/equipment_attribute_sync_test.dart`
Expected: ALL PASS (including the pre-existing equipment tests you touched in Step 7).

- [ ] **Step 9: Commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): attribute-backed EquipmentItem with diff-save repository"
```

---

### Task 6: Type-driven edit form (attribute section + custom fields section)

**Files:**
- Create: `lib/features/equipment/presentation/utils/equipment_attribute_units.dart`
- Create: `lib/features/equipment/presentation/widgets/equipment_attribute_form_section.dart`
- Create: `lib/features/equipment/presentation/widgets/equipment_custom_fields_section.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_edit_page.dart` (remove legacy size/thickness controllers + Row at lines ~299-324, remove buoyancy/dry-weight fields from `_buildAdvancedSection`, mount the two new sections)
- Modify: ARB files x11 (4 new keys)
- Test: `test/features/equipment/presentation/widgets/equipment_attribute_form_section_test.dart` (create)

**Interfaces:**
- Consumes: catalog + resolver + `EquipmentAttribute` (Tasks 3-5), `UnitFormatter` (`lib/core/utils/unit_formatter.dart`).
- Produces:
  - `equipment_attribute_units.dart`: `double attributeDisplayFromMetric(AttributeDimension d, UnitFormatter units, double metric)`, `double attributeMetricFromDisplay(AttributeDimension d, UnitFormatter units, double display)`, `String attributeUnitSymbol(AttributeDimension d, UnitFormatter units)`, `String formatAttributeValue(EquipmentAttribute attr, EquipmentAttributeDef? def, UnitFormatter units, AppLocalizations l10n)`.
  - `EquipmentAttributeFormSection({required EquipmentType type, required Map<String, EquipmentAttribute> values, required UnitFormatter units, required void Function(EquipmentAttribute) onChanged, required void Function(String key) onCleared})`.
  - `EquipmentCustomFieldsSection({required List<EquipmentAttribute> fields, required void Function(List<EquipmentAttribute>) onChanged})`.

- [ ] **Step 1: Add the 4 new ARB keys (all 11 locales) and regenerate**

`app_en.arb`:

```json
  "equipment_edit_customFieldsTitle": "Custom fields",
  "equipment_edit_addCustomField": "Add custom field",
  "attr_flagYes": "Yes",
  "attr_flagNo": "No"
```

Translate into the 10 other ARB files, then run `flutter gen-l10n`.

- [ ] **Step 2: Implement the unit bridge**

Create `lib/features/equipment/presentation/utils/equipment_attribute_units.dart`:

```dart
import '../../../../core/utils/unit_formatter.dart';
import '../../../../l10n/arb/app_localizations.dart';
import '../../domain/constants/equipment_attribute_catalog.dart';
import '../../domain/entities/equipment_attribute.dart';
import 'equipment_attribute_l10n.dart';

/// Canonical metric -> diver's display units. thicknessMm and none are
/// identity (mm is the industry convention in every market).
double attributeDisplayFromMetric(
  AttributeDimension d,
  UnitFormatter units,
  double metric,
) => switch (d) {
  AttributeDimension.massKg => units.convertWeight(metric),
  AttributeDimension.volumeL => units.convertVolume(metric),
  AttributeDimension.pressureBar => units.convertPressure(metric),
  AttributeDimension.lengthM ||
  AttributeDimension.depthM => units.convertDepth(metric),
  AttributeDimension.thicknessMm || AttributeDimension.none => metric,
};

/// Diver's display units -> canonical metric (storage).
double attributeMetricFromDisplay(
  AttributeDimension d,
  UnitFormatter units,
  double display,
) => switch (d) {
  AttributeDimension.massKg => units.weightToKg(display),
  AttributeDimension.volumeL => units.volumeToLiters(display),
  AttributeDimension.pressureBar => units.pressureToBar(display),
  AttributeDimension.lengthM ||
  AttributeDimension.depthM => units.depthToMeters(display),
  AttributeDimension.thicknessMm || AttributeDimension.none => display,
};

String attributeUnitSymbol(AttributeDimension d, UnitFormatter units) =>
    switch (d) {
      AttributeDimension.massKg => units.weightSymbol,
      AttributeDimension.volumeL => units.volumeSymbol,
      AttributeDimension.pressureBar => units.pressureSymbol,
      AttributeDimension.lengthM || AttributeDimension.depthM =>
        units.depthSymbol,
      AttributeDimension.thicknessMm => 'mm',
      AttributeDimension.none => '',
    };

/// Display string for a stored attribute value (detail page, CSV).
String formatAttributeValue(
  EquipmentAttribute attr,
  EquipmentAttributeDef? def,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  if (def == null) return attr.valueText ?? attr.valueNum?.toString() ?? '';
  switch (def.kind) {
    case AttributeKind.text:
      return attr.valueText ?? '';
    case AttributeKind.thickness:
      return attr.valueText == null ? '' : '${attr.valueText} mm';
    case AttributeKind.number:
      if (attr.valueNum == null) return '';
      final display = attributeDisplayFromMetric(
        def.dimension,
        units,
        attr.valueNum!,
      );
      final symbol = attributeUnitSymbol(def.dimension, units);
      final text = display == display.roundToDouble()
          ? display.toStringAsFixed(0)
          : display.toStringAsFixed(1);
      return symbol.isEmpty ? text : '$text $symbol';
    case AttributeKind.choice:
      return attr.valueText == null
          ? ''
          : attributeChoiceLabel(l10n, def.key, attr.valueText!);
    case AttributeKind.flag:
      return attr.valueNum == 1 ? l10n.attr_flagYes : l10n.attr_flagNo;
    case AttributeKind.date:
      return attr.valueNum == null
          ? ''
          : units.formatDate(
              DateTime.fromMillisecondsSinceEpoch(attr.valueNum!.toInt()),
            );
  }
}
```

(If `UnitFormatter` has no `formatDate`, check how `equipment_detail_page.dart` line ~581 formats `purchaseDate` and use the same call.)

- [ ] **Step 3: Write the failing widget test**

Create `test/features/equipment/presentation/widgets/equipment_attribute_form_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_attribute_form_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    required EquipmentType type,
    required Map<String, EquipmentAttribute> values,
    required void Function(EquipmentAttribute) onChanged,
    void Function(String)? onCleared,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: EquipmentAttributeFormSection(
              type: type,
              values: values,
              units: UnitFormatter(buildTestSettings()),
              onChanged: onChanged,
              onCleared: onCleared ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('wetsuit renders thickness field and emits parsed value', (
    tester,
  ) async {
    EquipmentAttribute? emitted;
    await pumpSection(
      tester,
      type: EquipmentType.wetsuit,
      values: const {},
      onChanged: (a) => emitted = a,
    );

    expect(find.text('Thickness (mm)'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('attr-field-thickness_mm')),
      '5/4',
    );
    expect(emitted, isNotNull);
    expect(emitted!.key, 'thickness_mm');
    expect(emitted!.valueText, '5/4');
    expect(emitted!.valueNum, 5.0);
  });

  testWidgets('tank renders no thickness but has valve choices', (
    tester,
  ) async {
    await pumpSection(
      tester,
      type: EquipmentType.tank,
      values: const {},
      onChanged: (_) {},
    );
    expect(find.text('Thickness (mm)'), findsNothing);
    expect(find.byKey(const ValueKey('attr-field-valve_type')), findsOneWidget);
  });

  testWidgets('flag toggles emit 0/1', (tester) async {
    EquipmentAttribute? emitted;
    await pumpSection(
      tester,
      type: EquipmentType.regulator,
      values: const {},
      onChanged: (a) => emitted = a,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('attr-field-cold_water_rated')),
    );
    await tester.tap(
      find.byKey(const ValueKey('attr-field-cold_water_rated')),
    );
    await tester.pump();
    expect(emitted!.valueNum, 1.0);
  });
}
```

If `mock_providers.dart` has no `buildTestSettings()`, use whatever existing helper other widget tests use to build a default settings object for `UnitFormatter` (grep `UnitFormatter(` in `test/` and copy that setup).

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_attribute_form_section_test.dart`
Expected: FAIL — widget does not exist.

- [ ] **Step 5: Implement the form section**

Create `lib/features/equipment/presentation/widgets/equipment_attribute_form_section.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../../l10n/l10n_extension.dart';
import '../../domain/constants/equipment_attribute_catalog.dart';
import '../../domain/entities/equipment_attribute.dart';
import '../utils/equipment_attribute_l10n.dart';
import '../utils/equipment_attribute_units.dart';

/// Renders one input per catalog definition for [type]. Values are keyed by
/// attrKey in [values]; edits emit whole EquipmentAttribute objects through
/// [onChanged]; emptied inputs call [onCleared] (unset = no row).
class EquipmentAttributeFormSection extends StatelessWidget {
  final EquipmentType type;
  final Map<String, EquipmentAttribute> values;
  final UnitFormatter units;
  final void Function(EquipmentAttribute) onChanged;
  final void Function(String key) onCleared;

  const EquipmentAttributeFormSection({
    super.key,
    required this.type,
    required this.values,
    required this.units,
    required this.onChanged,
    required this.onCleared,
  });

  EquipmentAttribute _base(String key) =>
      values[key] ?? EquipmentAttribute.curated(equipmentId: '', key: key);

  @override
  Widget build(BuildContext context) {
    final defs = EquipmentAttributeCatalog.attributesFor(type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final def in defs) ...[
          _buildField(context, def),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildField(BuildContext context, EquipmentAttributeDef def) {
    final label = attributeLabel(context.l10n, def.key);
    final fieldKey = ValueKey('attr-field-${def.key}');
    final current = values[def.key];

    switch (def.kind) {
      case AttributeKind.text:
        return TextFormField(
          key: fieldKey,
          initialValue: current?.valueText ?? '',
          decoration: InputDecoration(labelText: label),
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              onCleared(def.key);
            } else {
              onChanged(_base(def.key).copyWith(valueText: trimmed));
            }
          },
        );

      case AttributeKind.thickness:
        return TextFormField(
          key: fieldKey,
          initialValue: current?.valueText ?? '',
          decoration: InputDecoration(
            labelText: label,
            hintText: '5, 5/4, 7/5/3',
          ),
          validator: (text) {
            final t = text?.trim() ?? '';
            if (t.isEmpty) return null;
            return RegExp(r'^\d+(\.\d+)?(/\d+(\.\d+)?)*$').hasMatch(t)
                ? null
                : context.l10n.common_validation_invalid,
          },
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              onCleared(def.key);
            } else {
              onChanged(
                _base(def.key).copyWith(
                  valueText: trimmed,
                  valueNum: parsePrimaryThickness(trimmed),
                  clearValueNum: parsePrimaryThickness(trimmed) == null,
                ),
              );
            }
          },
        );

      case AttributeKind.number:
        final symbol = attributeUnitSymbol(def.dimension, units);
        return TextFormField(
          key: fieldKey,
          initialValue: current?.valueNum == null
              ? ''
              : attributeDisplayFromMetric(
                  def.dimension,
                  units,
                  current!.valueNum!,
                ).toString(),
          decoration: InputDecoration(
            labelText: symbol.isEmpty ? label : '$label ($symbol)',
          ),
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          onChanged: (text) {
            final parsed = double.tryParse(text.trim());
            if (parsed == null) {
              onCleared(def.key);
            } else {
              onChanged(
                _base(def.key).copyWith(
                  valueNum: attributeMetricFromDisplay(
                    def.dimension,
                    units,
                    parsed,
                  ),
                ),
              );
            }
          },
        );

      case AttributeKind.choice:
        return DropdownButtonFormField<String?>(
          key: fieldKey,
          initialValue: current?.valueText,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('--')),
            for (final option in def.choiceKeys)
              DropdownMenuItem(
                value: option,
                child: Text(
                  attributeChoiceLabel(context.l10n, def.key, option),
                ),
              ),
          ],
          onChanged: (option) {
            if (option == null) {
              onCleared(def.key);
            } else {
              onChanged(_base(def.key).copyWith(valueText: option));
            }
          },
        );

      case AttributeKind.flag:
        return SwitchListTile(
          key: fieldKey,
          title: Text(label),
          contentPadding: EdgeInsets.zero,
          value: current?.valueNum == 1,
          onChanged: (on) =>
              onChanged(_base(def.key).copyWith(valueNum: on ? 1.0 : 0.0)),
        );

      case AttributeKind.date:
        final date = current?.valueNum == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(current!.valueNum!.toInt());
        return InkWell(
          key: fieldKey,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(1970),
              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            );
            if (picked != null) {
              onChanged(
                _base(def.key).copyWith(
                  valueNum: picked.millisecondsSinceEpoch.toDouble(),
                ),
              );
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: date == null
                  ? const Icon(Icons.calendar_today)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => onCleared(def.key),
                    ),
            ),
            child: Text(date == null ? '--' : units.formatDate(date)),
          ),
        );
    }
  }
}
```

If `context.l10n.common_validation_invalid` does not exist, grep `common_validation` in `app_en.arb` and use the closest existing generic-invalid key; if none exists, add `"equipment_edit_invalidThickness": "Use 5, 5/4 or 7/5/3"` to all 11 ARB files instead.

- [ ] **Step 6: Implement the custom fields section**

Create `lib/features/equipment/presentation/widgets/equipment_custom_fields_section.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../l10n/l10n_extension.dart';
import '../../domain/entities/equipment_attribute.dart';

/// Editable list of user-defined attributes (label + value + delete),
/// mirroring the dive custom-fields editor.
class EquipmentCustomFieldsSection extends StatelessWidget {
  final List<EquipmentAttribute> fields;
  final void Function(List<EquipmentAttribute>) onChanged;

  const EquipmentCustomFieldsSection({
    super.key,
    required this.fields,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.equipment_edit_customFieldsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < fields.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    key: ValueKey('custom-key-$i'),
                    initialValue: fields[i].key,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_customFieldKey,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) => _update(
                      i,
                      fields[i].copyWith(key: text),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    key: ValueKey('custom-value-$i'),
                    initialValue: fields[i].valueText ?? '',
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_edit_customFieldValue,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (text) => _update(
                      i,
                      fields[i].copyWith(valueText: text),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  tooltip: context.l10n.common_action_delete,
                  onPressed: () => onChanged([
                    for (var j = 0; j < fields.length; j++)
                      if (j != i) fields[j],
                  ]),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => onChanged([
            ...fields,
            EquipmentAttribute(
              id: '',
              equipmentId: '',
              key: '',
              isCustom: true,
              sortOrder: fields.length,
            ),
          ]),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.equipment_edit_addCustomField),
        ),
      ],
    );
  }

  void _update(int index, EquipmentAttribute updated) => onChanged([
    for (var j = 0; j < fields.length; j++) j == index ? updated : fields[j],
  ]);
}
```

- [ ] **Step 7: Rewire the edit page**

In `equipment_edit_page.dart`:

1. Delete controllers `_sizeController`, `_thicknessController`, `_buoyancyController`, `_dryWeightController` (declarations, dispose calls, load-path population) and the Size+Thickness `Row` (~lines 299-324) and the buoyancy/dry-weight `TextFormField`s in `_buildAdvancedSection`.
2. Add state:

```dart
  final Map<String, EquipmentAttribute> _attrValues = {};
  List<EquipmentAttribute> _customFields = [];
```

3. In the load path (where the old controllers were populated), replace with:

```dart
    for (final attr in equipment.attributes) {
      if (attr.isCustom) {
        _customFields.add(attr);
      } else {
        _attrValues[attr.key] = attr;
      }
    }
    _customFields.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
```

4. Mount the section right after the status dropdown, keyed by type so a type switch rebuilds inputs:

```dart
          EquipmentAttributeFormSection(
            key: ValueKey('attrs-${_selectedType.name}'),
            type: _selectedType,
            values: _attrValues,
            units: UnitFormatter(ref.watch(settingsProvider)),
            onChanged: (attr) => setState(() {
              _attrValues[attr.key] = attr;
              _hasChanges = true;
            }),
            onCleared: (key) => setState(() {
              _attrValues.remove(key);
              _hasChanges = true;
            }),
          ),
```

5. Mount the custom section near the notes field:

```dart
          EquipmentCustomFieldsSection(
            fields: _customFields,
            onChanged: (fields) => setState(() {
              _customFields = fields;
              _hasChanges = true;
            }),
          ),
```

6. In `_saveEquipment`, replace the Task 5 bridge `attributes:` block with (this implements "type change drops out-of-catalog values at save"):

```dart
        attributes: [
          for (final def in EquipmentAttributeCatalog.attributesFor(
            _selectedType,
          ))
            if (_attrValues[def.key] case final attr? when attr.hasValue) attr,
          for (var i = 0; i < _customFields.length; i++)
            if (_customFields[i].key.trim().isNotEmpty &&
                _customFields[i].hasValue)
              _customFields[i].copyWith(sortOrder: i),
        ],
```

Remove the now-unused `_existingCustomAttributes` bridge field.

- [ ] **Step 8: Run tests**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_attribute_form_section_test.dart test/features/equipment/presentation/equipment_edit_advanced_test.dart test/features/equipment/`
Expected: ALL PASS. `equipment_edit_advanced_test.dart` exercises buoyancy fields that moved into the attribute section — update its finders to the new `ValueKey('attr-field-buoyancy_kg')` / `ValueKey('attr-field-dry_weight_kg')` fields; assertions against `repository.getEquipmentById(...).buoyancyKg` still hold via the derived getters.

- [ ] **Step 9: Commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): type-driven attribute form and custom fields editor"
```

---

### Task 7: Detail page attributes card

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (details card rows ~lines 545-593)
- Test: extend `test/features/equipment/presentation/pages/equipment_detail_page_test.dart`

**Interfaces:**
- Consumes: `formatAttributeValue`, `attributeLabel`, catalog (Tasks 3-6); `equipment.attributes` (Task 5).

- [ ] **Step 1: Write the failing test**

Add to `equipment_detail_page_test.dart` (follow the file's existing setup — real repository over `setUpTestDatabase`, pump wrapper with l10n delegates):

```dart
  testWidgets('detail page shows curated and custom attributes', (
    tester,
  ) async {
    final created = await repository.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Winter suit',
        type: EquipmentType.wetsuit,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'thickness_mm',
            valueText: '7/5',
            valueNum: 7.0,
          ),
          EquipmentAttribute.curated(
            equipmentId: '',
            key: 'suit_style',
            valueText: 'semi_dry',
          ),
          const EquipmentAttribute(
            id: '',
            equipmentId: '',
            key: 'Repair note',
            isCustom: true,
            valueText: 'patched left knee',
          ),
        ],
      ),
    );
    await pumpDetailPage(tester, created.id);

    expect(find.text('7/5 mm'), findsOneWidget);
    expect(find.text('Semi-dry'), findsOneWidget);
    expect(find.text('Repair note'), findsOneWidget);
    expect(find.text('patched left knee'), findsOneWidget);
  });
```

Use the file's existing pump helper name (grep for `pumpWidget` in the file); `ensureVisible`/`scrollUntilVisible` before asserting if the card sits below the fold.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/equipment/presentation/pages/equipment_detail_page_test.dart`
Expected: the new test FAILS (old rows only render size/thickness via getters, no choice/custom rows).

- [ ] **Step 3: Replace the legacy detail rows**

In `equipment_detail_page.dart`, delete the `if (equipment.size != null) _buildDetailRow(...)` and `if (equipment.thickness != null) _buildDetailRow(...)` blocks (lines ~560-573) and insert, in their place:

```dart
            for (final def in EquipmentAttributeCatalog.attributesFor(
              equipment.type,
            ))
              if (equipment.attributes.firstWhereOrNull(
                    (a) => !a.isCustom && a.key == def.key,
                  )
                  case final attr? when attr.hasValue)
                _buildDetailRow(
                  context,
                  attributeLabel(context.l10n, def.key),
                  formatAttributeValue(attr, def, units, context.l10n),
                ),
            for (final attr
                in equipment.attributes.where((a) => a.isCustom).toList()
                  ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
              if (attr.hasValue)
                _buildDetailRow(context, attr.key, attr.valueText ?? ''),
```

Add imports for the catalog, resolver, unit bridge, and `package:collection/collection.dart` (for `firstWhereOrNull`). The buoyancy/dry-weight rows elsewhere on the page read the derived getters and keep working; if the page has a dedicated buoyancy section that duplicates the two universal rows, delete the duplicate universal rows from THIS loop instead by skipping keys `buoyancy_kg`/`dry_weight_kg` — check visually which reads better and keep one occurrence only.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/equipment/presentation/pages/equipment_detail_page_test.dart`
Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(equipment): attribute rows on the equipment detail page"
```

---

### Task 8: Stats integration (filter axis + SQL predicate + suit-thickness chart + filter sheet)

**Files:**
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart`
- Modify: `lib/features/statistics/data/dive_filter_sql.dart`
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart`
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart`
- Modify: `lib/features/statistics/presentation/pages/statistics_progression_page.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_filter_sheet.dart`
- Modify: ARB files x11 (7 new keys)
- Test: `test/features/statistics/data/dive_filter_sql_attribute_test.dart` (create), `test/features/statistics/data/dives_by_suit_thickness_test.dart` (create)

**Interfaces:**
- Consumes: `equipment_attributes` table (Task 1), `buildFilteredDiveIdSubquery` record API `({String subquery, List<Object?> params})`.
- Produces: `DiveFilterState.equipmentAttrKey/equipmentAttrChoice/equipmentAttrMin/equipmentAttrMax`; `StatisticsRepository.getDivesBySuitThickness({String? diverId, DiveFilterState filter}) -> Future<List<({double mm, int count})>>`; provider `divesBySuitThicknessProvider`.

- [ ] **Step 1: Write the failing SQL predicate test**

Create `test/features/statistics/data/dive_filter_sql_attribute_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

void main() {
  test('attribute axis compiles to a dive_equipment join', () {
    final result = buildFilteredDiveIdSubquery(
      const DiveFilterState(
        equipmentAttrKey: 'thickness_mm',
        equipmentAttrMin: 5.0,
        equipmentAttrMax: 7.0,
      ),
    );
    expect(result.subquery, contains('dive_equipment'));
    expect(result.subquery, contains('equipment_attributes'));
    expect(result.subquery, contains('ea.attr_key = ?'));
    expect(result.subquery, contains('ea.value_num >= ?'));
    expect(result.subquery, contains('ea.value_num <= ?'));
    expect(result.params, ['thickness_mm', 5.0, 7.0]);
  });

  test('choice variant binds value_text', () {
    final result = buildFilteredDiveIdSubquery(
      const DiveFilterState(
        equipmentAttrKey: 'valve_type',
        equipmentAttrChoice: 'din',
      ),
    );
    expect(result.subquery, contains('ea.value_text = ?'));
    expect(result.params, ['valve_type', 'din']);
  });

  test('no attribute axis -> no attribute SQL', () {
    final result = buildFilteredDiveIdSubquery(const DiveFilterState());
    expect(result.subquery, isNot(contains('equipment_attributes')));
  });
}
```

- [ ] **Step 2: Write the failing chart-query test**

Create `test/features/statistics/data/dives_by_suit_thickness_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database/database_service.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  test('groups dives by linked suit primary thickness', () async {
    final db = DatabaseService.instance.database;
    // Seed minimal rows with raw SQL: 2 dives with a 5/4 suit, 1 with 3mm.
    await db.customStatement(
      "INSERT INTO dives (id, dive_number, dive_date_time, created_at, updated_at) "
      "VALUES ('d1', 1, 1000, 1, 1), ('d2', 2, 2000, 1, 1), ('d3', 3, 3000, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, status, purchase_currency, notes, "
      "is_active, created_at, updated_at) VALUES "
      "('s54', 'Suit 5/4', 'wetsuit', 'active', 'USD', '', 1, 1, 1), "
      "('s3', 'Suit 3', 'wetsuit', 'active', 'USD', '', 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO equipment_attributes (id, equipment_id, attr_key, is_custom, "
      "value_text, value_num, sort_order, created_at, updated_at) VALUES "
      "('a1', 's54', 'thickness_mm', 0, '5/4', 5.0, 0, 1, 1), "
      "('a2', 's3', 'thickness_mm', 0, '3', 3.0, 0, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES "
      "('d1', 's54'), ('d2', 's54'), ('d3', 's3')",
    );

    final result = await StatisticsRepository().getDivesBySuitThickness();
    expect(result, [(mm: 3.0, count: 1), (mm: 5.0, count: 2)]);
  });
}
```

If the `dives` insert violates NOT NULL columns in the real schema, extend the column list to satisfy them (check `PRAGMA table_info('dives')` failures in the test output and copy defaults from another statistics test that seeds dives — e.g. whatever `test/features/statistics/` already uses; prefer reusing an existing `createTestDive` helper via `DiveRepository` if one is convenient).

- [ ] **Step 3: Run tests to verify failure**

Run: `flutter test test/features/statistics/data/dive_filter_sql_attribute_test.dart test/features/statistics/data/dives_by_suit_thickness_test.dart`
Expected: FAIL — fields/method do not exist.

- [ ] **Step 4: Extend DiveFilterState**

In `dive_filter_state.dart` add the four fields, ctor params, and thread them through:

```dart
  // Equipment-attribute axis (curated keys only). key selects the attribute;
  // choice matches value_text; min/max bound value_num (canonical metric).
  final String? equipmentAttrKey;
  final String? equipmentAttrChoice;
  final double? equipmentAttrMin;
  final double? equipmentAttrMax;
```

- Ctor: `this.equipmentAttrKey, this.equipmentAttrChoice, this.equipmentAttrMin, this.equipmentAttrMax,`
- `hasActiveFilters`: add `|| equipmentAttrKey != null`
- `copyWith`: add the four params plus a `bool clearEquipmentAttr = false` that nulls all four (follow the file's existing `clearX` convention).
- `apply()`: like the existing `equipmentIds` axis, the in-memory fallback cannot see the equipment tables; add a comment `// equipmentAttr*: SQL-only axis (see buildFilteredDiveIdSubquery); the in-memory fallback ignores it, matching equipmentIds.` and skip it.

- [ ] **Step 5: Add the SQL predicate**

In `dive_filter_sql.dart`, after the `equipmentIds` block (~line 67):

```dart
  // Equipment attribute: dives linked to an equipment item whose curated
  // attribute matches. value_num bounds are canonical metric.
  if (filter.equipmentAttrKey != null) {
    final sub = StringBuffer(
      'id IN (SELECT de.dive_id FROM dive_equipment de '
      'JOIN equipment_attributes ea ON ea.equipment_id = de.equipment_id '
      'WHERE ea.attr_key = ? AND ea.is_custom = 0',
    );
    params.add(filter.equipmentAttrKey);
    if (filter.equipmentAttrChoice != null) {
      sub.write(' AND ea.value_text = ?');
      params.add(filter.equipmentAttrChoice);
    }
    if (filter.equipmentAttrMin != null) {
      sub.write(' AND ea.value_num >= ?');
      params.add(filter.equipmentAttrMin);
    }
    if (filter.equipmentAttrMax != null) {
      sub.write(' AND ea.value_num <= ?');
      params.add(filter.equipmentAttrMax);
    }
    sub.write(')');
    conditions.add(sub.toString());
  }
```

- [ ] **Step 6: Add the chart query, provider, and section**

1. `statistics_repository.dart` (next to `getDivesPerYear`, same error-handling shape):

```dart
  /// Dives grouped by the primary thickness of linked exposure suits
  /// (wetsuit/drysuit). COUNT(DISTINCT) so a dive with two suits of the same
  /// thickness counts once per bucket.
  Future<List<({double mm, int count})>> getDivesBySuitThickness({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        SELECT ea.value_num AS mm, COUNT(DISTINCT d.id) AS count
        FROM dives d
        JOIN dive_equipment de ON de.dive_id = d.id
        JOIN equipment e ON e.id = de.equipment_id
          AND e.type IN ('wetsuit', 'drysuit')
        JOIN equipment_attributes ea ON ea.equipment_id = e.id
          AND ea.attr_key = 'thickness_mm'
          AND ea.is_custom = 0
          AND ea.value_num IS NOT NULL
        WHERE 1=1 $diverFilter ${df.clause}
        GROUP BY ea.value_num
        ORDER BY ea.value_num
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        return (
          mm: row.read<double>('mm'),
          count: row.read<int>('count'),
        );
      }).toList();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dives by suit thickness',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
```

Note `_diveFilter(filter, alias: 'd')` — the clause helper aliases `d.id IN (...)`.

2. `statistics_providers.dart` (next to `divesPerYearProvider`):

```dart
final divesBySuitThicknessProvider =
    FutureProvider<List<({double mm, int count})>>((ref) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      return repository.getDivesBySuitThickness(
        diverId: currentDiverId,
        filter: filter,
      );
    });
```

3. `statistics_progression_page.dart`: add `_buildDivesBySuitThicknessSection` cloned from `_buildDivesPerYearSection` (lines 102-147) with: provider `divesBySuitThicknessProvider`, labels from the new l10n keys, and

```dart
          final chartData = data
              .map(
                (d) => (
                  label: d.mm == d.mm.roundToDouble()
                      ? '${d.mm.toStringAsFixed(0)}mm'
                      : '${d.mm}mm',
                  count: d.count,
                ),
              )
              .toList();
```

Mount it in the page's section list right after the dives-per-year section.

4. ARB keys (en shown; translate into all 10 other locales, then `flutter gen-l10n`):

```json
  "statistics_progression_divesBySuitThickness_title": "Dives by Suit Thickness",
  "statistics_progression_divesBySuitThickness_subtitle": "Exposure suit primary thickness across your dives",
  "statistics_progression_divesBySuitThickness_empty": "No dives with a suit thickness recorded",
  "statistics_progression_divesBySuitThickness_error": "Could not load suit thickness data",
  "diveLog_filter_sectionSuitThickness": "Suit thickness (mm)",
  "diveLog_filter_thicknessMin": "Min",
  "diveLog_filter_thicknessMax": "Max"
```

- [ ] **Step 7: Add the filter sheet section**

In `dive_filter_sheet.dart`:

1. State fields (~line 60): `double? _suitThicknessMin; double? _suitThicknessMax;`
2. Hydrate in `initState` (~line 88):

```dart
    final f = widget.ref.read(widget.filterProvider);
    if (f.equipmentAttrKey == 'thickness_mm') {
      _suitThicknessMin = f.equipmentAttrMin;
      _suitThicknessMax = f.equipmentAttrMax;
    }
```

3. Section widget (after the Tags section, following the file's Text-title + 24-gap pattern):

```dart
              Text(
                context.l10n.diveLog_filter_sectionSuitThickness,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _suitThicknessMin?.toStringAsFixed(0) ?? '',
                      decoration: InputDecoration(
                        labelText: context.l10n.diveLog_filter_thicknessMin,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(
                        () => _suitThicknessMin = double.tryParse(v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _suitThicknessMax?.toStringAsFixed(0) ?? '',
                      decoration: InputDecoration(
                        labelText: context.l10n.diveLog_filter_thicknessMax,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(
                        () => _suitThicknessMax = double.tryParse(v),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
```

4. In `_applyFilters` add:

```dart
      equipmentAttrKey:
          (_suitThicknessMin != null || _suitThicknessMax != null)
          ? 'thickness_mm'
          : null,
      equipmentAttrMin: _suitThicknessMin,
      equipmentAttrMax: _suitThicknessMax,
```

- [ ] **Step 8: Run tests**

Run: `flutter test test/features/statistics/data/dive_filter_sql_attribute_test.dart test/features/statistics/data/dives_by_suit_thickness_test.dart test/features/statistics/`
Expected: ALL PASS.

- [ ] **Step 9: Commit**

```bash
dart format .
git add -A
git commit -m "feat(stats): equipment attribute filter axis and dives-by-suit-thickness chart"
```

---

### Task 9: CSV export columns

**Files:**
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (`generateEquipmentCsvContent`, lines 239-279)
- Test: extend the existing CSV export test file (find with `grep -rln generateEquipmentCsvContent test/`; if none exists, create `test/core/services/export/equipment_csv_export_test.dart`)

**Interfaces:**
- Consumes: `EquipmentItem` derived getters + `attributes` (Task 5), `EquipmentAttrKeys` (Task 3).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  test('equipment CSV includes size, thickness, and extra attributes', () {
    final csv = CsvExportService().generateEquipmentCsvContent([
      EquipmentItem(
        id: 'e1',
        name: 'Suit',
        type: EquipmentType.wetsuit,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: 'size',
            valueText: 'L',
          ),
          EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: 'thickness_mm',
            valueText: '5/4',
            valueNum: 5.0,
          ),
          EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: 'suit_style',
            valueText: 'full',
          ),
          EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: 'buoyancy_kg',
            valueNum: 2.5,
          ),
        ],
      ),
    ]);

    final lines = csv.split('\n');
    expect(lines.first, contains('Size'));
    expect(lines.first, contains('Thickness'));
    expect(lines.first, contains('Attributes'));
    expect(lines[1], contains('L'));
    expect(lines[1], contains('5/4'));
    expect(lines[1], contains('suit_style=full'));
    expect(lines[1], contains('2.5'));
  });
}
```

(Adjust the service construction to match the file — if `CsvExportService` is accessed differently, copy the pattern from an existing CSV test.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test <the test file>`
Expected: FAIL — headers missing.

- [ ] **Step 3: Implement**

In `generateEquipmentCsvContent`: insert `'Size', 'Thickness',` into `headers` after `'Serial Number'`, and `'Attributes',` before `'Notes'`. In the row loop insert matching values:

```dart
        item.size ?? '',
        item.thickness ?? '',
```

and before the notes value:

```dart
        item.attributes
            .where(
              (a) =>
                  a.hasValue &&
                  !const {
                    EquipmentAttrKeys.size,
                    EquipmentAttrKeys.thicknessMm,
                    EquipmentAttrKeys.buoyancyKg,
                    EquipmentAttrKeys.dryWeightKg,
                  }.contains(a.key),
            )
            .map((a) => '${a.key}=${a.valueText ?? a.valueNum}')
            .join('; '),
```

(`Buoyancy (kg)` / `Dry Weight (kg)` columns keep working through the derived getters; the four dedicated-column keys are excluded from the combined column to avoid duplication.)

- [ ] **Step 4: Run tests, then commit**

Run: `flutter test <the test file>`
Expected: PASS.

```bash
dart format .
git add -A
git commit -m "feat(export): equipment attributes in CSV export"
```

---

### Task 10: Full verification sweep

**Files:** none new — verification only, plus any fixes it forces.

- [ ] **Step 1: Static checks**

Run: `dart format . && flutter analyze`
Expected: format changes nothing new; analyze reports "No issues found!". Fix anything reported.

- [ ] **Step 2: Run the affected test surface**

Run each (separately, to keep timeouts manageable):

```bash
flutter test test/core/database/
flutter test test/core/services/sync/
flutter test test/features/equipment/
flutter test test/features/statistics/
flutter test test/core/services/export/ 2>/dev/null || flutter test test/core/services/
```

Expected: ALL PASS.

- [ ] **Step 3: Spec cross-check**

Open `docs/superpowers/specs/2026-07-16-equipment-attributes-design.md` and verify each Goal maps to shipped code: (1) curated per-type form -> Task 6; (2) custom fields -> Tasks 5-6; (3) stats filter + chart -> Task 8; (4) legacy migration + frozen columns -> Tasks 1, 5; (5) sync semantics -> Tasks 1-2, 5. Confirm the schema-version number used matches the ladder reality at implementation time.

- [ ] **Step 4: Manual smoke (if a device/desktop is available)**

Run: `flutter run -d macos` (check no other `flutter run -d macos` session is active first). Create a wetsuit with thickness `5/4`, a tank with DIN valve + hydro date, add a custom field, link the suit to a dive, and confirm the statistics chart buckets it. This exercises the real v115 migration against the dev database — note the dev DB's schema version will be bumped for other branches.

- [ ] **Step 5: Commit any verification fixes**

```bash
dart format .
git add -A
git commit -m "test(equipment): verification sweep fixes for equipment attributes"
```

(Skip the commit if the sweep changed nothing.)
