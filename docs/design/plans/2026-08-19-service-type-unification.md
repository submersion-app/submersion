# Service Type Unification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `ServiceKind` catalog the one thing called "service type", rename the colliding `ServiceType` enum to `ServiceCategory`, give the catalog a Settings > Manage entry, and prefill a record's category from its service type.

**Architecture:** The record dialog asks for one required thing (a catalog entry) and one optional secondary thing (a category prefilled from that entry). A new `service_kinds.default_category` column supplies the prefill through a pure resolver, mirroring the `defaultCost` resolver shipped in #1158. The enum rename reaches the sync wire key, so the compatibility floor rises and a normaliser accepts the old key from peers and backups written before the rename.

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod, go_router, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-08-19-service-type-unification-design.md`

## Global Constraints

- **Worktree:** all work happens in `.claude/worktrees/service-type-unification` on branch `worktree-service-type-unification`. Use worktree-absolute paths for every file operation; a main-tree absolute path edits the wrong checkout.
- **Schema version:** this plan claims **v160**. It was drafted against 158 and renumbered twice during implementation: 158 went to #1149 and 159 to #1177. When a version collides, the migration block, `migrationVersions`, the compatibility floor, the fixtures' `PRAGMA user_version`, the test filename and every docstring move together; missing the fixture is silent, because it skips the block it was written to exercise.
- **Compatibility floor:** `AppDatabase.minimumCompatibleSchemaVersion` was 137 and rises to **160** in Task 3. This is deliberate and holds every peer below 160 until it updates.
- **Localization:** every new or renamed key is added to **all 11** ARB files: `app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`. Regenerate with `flutter gen-l10n` and commit the regenerated `lib/l10n/arb/app_localizations*.dart`.
- **Writing style:** no em-dashes (U+2014) anywhere, including code comments, docstrings and commit messages. No en-dashes as prose punctuation. No emojis in code, comments or docs.
- **Formatting:** run `dart format lib/ test/` before every commit. `flutter analyze` must be clean; informational lints are fatal in CI.
- **Commits:** no `Co-Authored-By` trailer, no Claude Code session URL, no attribution line.
- **Migrations must self-guard** on table existence. Minimal migration fixtures ride the whole ladder from early versions and omit tables that did not exist yet.

## File Structure

| File | Responsibility | Task |
| --- | --- | --- |
| `lib/core/constants/enums.dart` | `ServiceCategory` enum (renamed from `ServiceType`) | 1 |
| `lib/features/equipment/domain/entities/service_record.dart` | Domain record, `serviceCategory` field | 1 |
| `lib/features/equipment/domain/entities/maintenance_history_filter.dart` | History filter, `serviceCategory` dimension | 1 |
| `lib/features/equipment/presentation/utils/service_category_label.dart` | Localized enum labels (renamed file) | 1 |
| `lib/core/database/database.dart` | Tables, v160 migration, floor constant, seed SQL | 2, 3 |
| `lib/core/services/sync/sync_data_serializer.dart` | Legacy wire-key normaliser at both apply chokepoints | 3 |
| `lib/features/equipment/domain/entities/service_kind.dart` | `defaultCategory` field | 2 |
| `lib/features/equipment/data/repositories/service_kind_repository.dart` | `defaultCategory` persistence | 2 |
| `lib/features/equipment/domain/services/default_service_cost_resolver.dart` | Adds `resolveDefaultServiceCategory` | 4 |
| `lib/features/equipment/presentation/pages/service_kind_list_page.dart` | Category editor in the catalog dialog | 5 |
| `lib/features/equipment/presentation/widgets/service_record_dialog.dart` | Reordered, relabelled, required picker, prefill | 6 |
| `lib/features/settings/presentation/pages/settings_page.dart` | Manage > Service types tile | 7 |
| `lib/core/services/export/excel/maintenance_excel_export_service.dart` | Header vocabulary | 8 |

Tasks 1 through 3 must run in order: Task 1 makes the code compile under the new name, Task 2 adds the v160 block, Task 3 extends that same block. Tasks 4 through 8 depend on 1 through 3 but not on each other.

---

### Task 1: Rename ServiceType to ServiceCategory in domain, UI, export and import

The database column, the Drift getter, and the sync wire key are deliberately **not** touched here. The repository keeps reading the Drift row's `serviceType` and maps it to the domain's `serviceCategory`. This keeps Task 1 a pure compile-level rename with no migration and no wire impact, so it can be reviewed on its own.

**Files:**
- Modify: `lib/core/constants/enums.dart:240-253`
- Modify: `lib/features/equipment/domain/entities/service_record.dart`
- Modify: `lib/features/equipment/domain/entities/maintenance_history_filter.dart`
- Create: `lib/features/equipment/presentation/utils/service_category_label.dart`
- Delete: `lib/features/equipment/presentation/utils/service_type_label.dart`
- Modify: `lib/features/equipment/data/repositories/service_record_repository.dart` (row mapping, including the raw-SQL read at line 312)
- Modify: `lib/features/equipment/presentation/widgets/service_record_dialog.dart`
- Modify: `lib/features/equipment/presentation/widgets/service_history_section.dart`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart`
- Modify: `lib/core/services/export/models/export_service_record.dart`
- Modify: `lib/core/services/export/excel/maintenance_excel_export_service.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart:1135`
- Modify: `lib/core/services/export/uddf/uddf_import_parsers.dart:835-841`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:522-524`
- Modify: `lib/features/universal_import/data/services/macdive_dive_mapper.dart:419`
- Modify: all 11 ARB files
- Test: `test/features/equipment/domain/entities/service_category_test.dart` (new)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `enum ServiceCategory` with the same ten values and the same `displayName` strings; `ServiceRecord.serviceCategory` of type `ServiceCategory`; `MaintenanceHistoryFilter.serviceCategory`; extension `ServiceCategoryL10n on ServiceCategory` with method `String label(AppLocalizations l10n)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/domain/entities/service_category_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

void main() {
  test('ServiceCategory keeps the ten values and their wire names', () {
    expect(ServiceCategory.values, hasLength(10));
    expect(
      ServiceCategory.values.map((c) => c.name).toList(),
      const [
        'annual',
        'repair',
        'inspection',
        'overhaul',
        'replacement',
        'cleaning',
        'calibration',
        'warranty',
        'recall',
        'other',
      ],
    );
  });

  test('displayName stays the English export label', () {
    expect(ServiceCategory.annual.displayName, 'Annual Service');
    expect(ServiceCategory.replacement.displayName, 'Part Replacement');
  });

  test('ServiceRecord exposes serviceCategory', () {
    final record = ServiceRecord.empty('equip-1');
    expect(record.serviceCategory, ServiceCategory.annual);

    final edited = record.copyWith(serviceCategory: ServiceCategory.repair);
    expect(edited.serviceCategory, ServiceCategory.repair);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/domain/entities/service_category_test.dart`
Expected: FAIL, compile error "Undefined name 'ServiceCategory'".

- [ ] **Step 3: Rename the enum**

In `lib/core/constants/enums.dart`, replace the `ServiceType` declaration with:

```dart
/// The category of work a maintenance record represents (what kind of job it
/// was), as distinct from the service type it fulfills, which is the
/// user-extensible ServiceKind catalog. Renamed from ServiceType in v160:
/// the catalog owns the words "service type" in the UI.
enum ServiceCategory {
  annual('Annual Service'),
  repair('Repair'),
  inspection('Inspection'),
  overhaul('Overhaul'),
  replacement('Part Replacement'),
  cleaning('Cleaning'),
  calibration('Calibration'),
  warranty('Warranty Service'),
  recall('Recall/Safety'),
  other('Other');

  final String displayName;
  const ServiceCategory(this.displayName);
}
```

- [ ] **Step 4: Rename the domain field**

In `lib/features/equipment/domain/entities/service_record.dart`, rename the field, the constructor parameter, the `copyWith` parameter and assignment, the `props` entry, and the `ServiceRecord.empty` seed:

```dart
  final ServiceCategory serviceCategory;
```

```dart
  const ServiceRecord({
    required this.id,
    required this.equipmentId,
    required this.serviceCategory,
    this.serviceKindId,
    // ... unchanged
  });
```

```dart
  ServiceRecord copyWith({
    String? id,
    String? equipmentId,
    ServiceCategory? serviceCategory,
    // ... unchanged
  }) {
    return ServiceRecord(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      serviceCategory: serviceCategory ?? this.serviceCategory,
      // ... unchanged
    );
  }
```

```dart
  factory ServiceRecord.empty(String equipmentId) {
    final now = DateTime.now();
    return ServiceRecord(
      id: '',
      equipmentId: equipmentId,
      serviceCategory: ServiceCategory.annual,
      serviceDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }
```

The `props` list entry `serviceType` becomes `serviceCategory`.

- [ ] **Step 5: Rename the filter dimension**

In `lib/features/equipment/domain/entities/maintenance_history_filter.dart`, rename the field, the constructor parameter, the `copyWith` parameter, the `props` entry, and both uses in `isActive` and `matches`:

```dart
  final String? serviceKindId;
  final ServiceCategory? serviceCategory;
  final int? year;
```

```dart
  bool get isActive =>
      serviceKindId != null || serviceCategory != null || year != null;
```

```dart
    if (serviceCategory != null && record.serviceCategory != serviceCategory) {
      return false;
    }
```

- [ ] **Step 6: Move the label extension**

Create `lib/features/equipment/presentation/utils/service_category_label.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for [ServiceCategory].
///
/// [ServiceCategory.displayName] stays hardcoded English on purpose: it is the
/// value written to spreadsheet exports, which are analysis targets rather
/// than UI surfaces. Only screens use this extension.
///
/// The switch is exhaustive rather than map-backed so that adding an enum
/// value is a compile error instead of a silent English fallback.
extension ServiceCategoryL10n on ServiceCategory {
  String label(AppLocalizations l10n) => switch (this) {
    ServiceCategory.annual => l10n.equipment_serviceCategory_annual,
    ServiceCategory.repair => l10n.equipment_serviceCategory_repair,
    ServiceCategory.inspection => l10n.equipment_serviceCategory_inspection,
    ServiceCategory.overhaul => l10n.equipment_serviceCategory_overhaul,
    ServiceCategory.replacement => l10n.equipment_serviceCategory_replacement,
    ServiceCategory.cleaning => l10n.equipment_serviceCategory_cleaning,
    ServiceCategory.calibration => l10n.equipment_serviceCategory_calibration,
    ServiceCategory.warranty => l10n.equipment_serviceCategory_warranty,
    ServiceCategory.recall => l10n.equipment_serviceCategory_recall,
    ServiceCategory.other => l10n.equipment_serviceCategory_other,
  };
}
```

Then delete `lib/features/equipment/presentation/utils/service_type_label.dart` and update its two importers (`service_record_dialog.dart`, `service_history_section.dart`) to the new path.

- [ ] **Step 7: Rename the ARB keys**

In each of the 11 ARB files, rename these keys, keeping each locale's existing translated values:

- `equipment_serviceType_annual` through `equipment_serviceType_other` become `equipment_serviceCategory_annual` through `equipment_serviceCategory_other` (ten keys).
- `equipment_serviceDialog_serviceTypeLabel` becomes `equipment_serviceDialog_categoryLabel`, and its **English value changes** from `"Service Type"` to `"Category"`. Translate the new value in the other ten locales (German "Kategorie", French "Catégorie", Spanish "Categoría", Italian "Categoria", Portuguese "Categoria", Dutch "Categorie", Hungarian "Kategória", Arabic "الفئة", Hebrew "קטגוריה", Chinese "类别").

- [ ] **Step 8: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/arb/app_localizations*.dart` regenerate with the new getter names and no errors.

- [ ] **Step 9: Rename every remaining reference**

Update these call sites. The Drift row's `serviceType` getter stays as it is, so the repository mapping becomes a rename across the two sides:

`lib/features/equipment/data/repositories/service_record_repository.dart`, typed row mapping:

```dart
      serviceCategory: _parseServiceCategory(row.serviceType),
```

and the raw-SQL mapping at line 312:

```dart
      serviceCategory: _parseServiceCategory(row.data['service_type'] as String),
```

Rename the private helper `_parseServiceType` to `_parseServiceCategory` and retype it to return `ServiceCategory`. Every companion that writes the column keeps writing `serviceType:` (the Drift name) from `record.serviceCategory`.

In the remaining files, rename the enum type, the field accesses, and the local variables:
`service_record_dialog.dart` (`_serviceType` becomes `_serviceCategory`), `service_history_section.dart`, `equipment_detail_page.dart` (including `_getServiceTypeIcon`, which becomes `_getServiceCategoryIcon` and takes a `ServiceCategory`), `export_service_record.dart`, `maintenance_excel_export_service.dart` (the `MaintenanceLogRow` field), `uddf_export_builders.dart:1135` (`record.serviceCategory.name`), `uddf_import_parsers.dart:835-841` (the parsed map key becomes `'serviceCategory'` and the enum becomes `enums.ServiceCategory.values`; the XML element name `'servicetype'` is NOT touched in this task), `uddf_entity_importer.dart:522-524` (reads `recordData['serviceCategory']`, falls back to `ServiceCategory.annual`), `macdive_dive_mapper.dart:419` (`'serviceCategory': ServiceCategory.annual.name`).

- [ ] **Step 10: Rename references in tests**

Run: `grep -rln "ServiceType\|serviceType" test/` and update every hit **except** those referring to the Drift row getter or the `service_type` SQL column, which are unchanged until Task 3.

- [ ] **Step 11: Run the new test**

Run: `flutter test test/features/equipment/domain/entities/service_category_test.dart`
Expected: PASS.

- [ ] **Step 12: Run analyze and the equipment suites**

Run: `dart format lib/ test/`
Run: `flutter analyze`
Expected: no issues.
Run: `flutter test test/features/equipment/ test/core/services/export/`
Expected: PASS.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "refactor(equipment): rename ServiceType to ServiceCategory

The ServiceKind catalog is what the UI calls a service type, so the
ten-value enum takes the name it always described: a category of work.
Database column, Drift getter and sync wire key are unchanged here."
```

---

### Task 2: Add service_kinds.default_category (schema v160, part A)

**Files:**
- Modify: `lib/core/database/database.dart` (`ServiceKinds` table around line 1175, `kSeedBuiltInServiceKindsSql` at 2267, `currentSchemaVersion` at 3119, `migrationVersions` list, `onUpgrade` after the `from < 158` block at 8364, `beforeOpen` backstops near 8420, new helper beside `_assertServiceCostColumns` at 4839)
- Modify: `lib/features/equipment/domain/entities/service_kind.dart`
- Modify: `lib/features/equipment/data/repositories/service_kind_repository.dart`
- Test: `test/core/database/migration_v160_service_category_test.dart` (new)

**Interfaces:**
- Consumes: `ServiceCategory` from Task 1.
- Produces: `ServiceKind.defaultCategory` of type `ServiceCategory?`, cleared through `copyWith` with the existing `_undefined` sentinel; SQL column `service_kinds.default_category` holding a `ServiceCategory.name` string.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v160_service_category_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A v157 service_kinds table carrying one custom kind and one built-in.
  NativeDatabase seededV157() => NativeDatabase.memory(
    setup: (db) {
      db.execute('PRAGMA user_version = 158');
      db.execute('''
        CREATE TABLE service_kinds (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          applicable_types TEXT NOT NULL DEFAULT '[]',
          default_interval_days INTEGER,
          default_interval_dives INTEGER,
          default_interval_hours REAL,
          default_cost REAL,
          default_currency TEXT,
          auto_attach INTEGER NOT NULL DEFAULT 0,
          is_built_in INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      db.execute(
        "INSERT INTO service_kinds (id, name, is_built_in, created_at, "
        "updated_at) VALUES ('hydro', 'Hydrostatic test', 1, 1, 1)",
      );
      db.execute(
        "INSERT INTO service_kinds (id, name, is_built_in, created_at, "
        "updated_at) VALUES ('disinfect', 'Disinfect', 0, 1, 1)",
      );
    },
  );

  test('v160 adds default_category and seeds built-ins only', () async {
    final db = AppDatabase(seededV157());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('service_kinds')")
        .get();
    final byName = {for (final c in cols) c.read<String>('name'): c};
    expect(byName.containsKey('default_category'), isTrue);
    expect(
      byName['default_category']!.read<String>('type').toUpperCase(),
      'TEXT',
    );

    final hydro = await db
        .customSelect(
          "SELECT default_category FROM service_kinds WHERE id = 'hydro'",
        )
        .getSingle();
    expect(hydro.read<String?>('default_category'), 'inspection');

    final custom = await db
        .customSelect(
          "SELECT default_category FROM service_kinds WHERE id = 'disinfect'",
        )
        .getSingle();
    expect(custom.read<String?>('default_category'), isNull);
  });

  test('v160 does not resurrect a built-in the diver deleted', () async {
    final native = NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA user_version = 158');
        db.execute('''
          CREATE TABLE service_kinds (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            applicable_types TEXT NOT NULL DEFAULT '[]',
            default_interval_days INTEGER,
            default_interval_dives INTEGER,
            default_interval_hours REAL,
            default_cost REAL,
            default_currency TEXT,
            auto_attach INTEGER NOT NULL DEFAULT 0,
            is_built_in INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final rows = await db
        .customSelect("SELECT id FROM service_kinds WHERE id = 'vip'")
        .get();
    expect(rows, isEmpty);
  });

  test('the helper no-ops when service_kinds is absent', () async {
    final native = NativeDatabase.memory(
      setup: (db) => db.execute('PRAGMA user_version = 158'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });

  test('migration list includes v160 and schema is at least 160', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(160));
    expect(AppDatabase.migrationVersions, contains(160));
  });
}
```

Note on the second test: `kSeedBuiltInServiceKindsSql` runs in `beforeOpen` and would normally seed `vip`, but this fixture's `service_kinds` table exists and is empty, so the assertion documents that the v160 category step is an `UPDATE` that adds no rows of its own. If the seed constant repopulates the table on open, adjust the assertion to check that the seeded `vip` row carries `default_category = 'inspection'` from the seed SQL rather than from the migration, and keep the intent: the migration itself inserts nothing.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v160_service_category_test.dart`
Expected: FAIL on the missing `default_category` column and on `currentSchemaVersion` being 157.

- [ ] **Step 3: Add the Drift column**

In `lib/core/database/database.dart`, inside `class ServiceKinds`, directly after `defaultCurrency`:

```dart
  /// v160: the category prefilled into a new service record logged against
  /// this service type. Nullable because a custom type has no opinion until
  /// the diver gives it one; a NOT NULL default would make every custom type
  /// silently claim "annual".
  TextColumn get defaultCategory => text().nullable()();
```

- [ ] **Step 4: Add the migration helper**

Beside `_assertServiceCostColumns` (around line 4839), add:

```dart
  /// v160: service_kinds.default_category, plus the built-in seeding.
  ///
  /// Self-guards on the table existing, because minimal migration fixtures
  /// ride the ladder from versions that predate service_kinds. The seeding is
  /// an UPDATE rather than an upsert so it cannot resurrect a built-in the
  /// diver deleted (the v109 rule).
  Future<void> _assertServiceCategoryColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('service_kinds')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('default_category')) {
      await customStatement(
        'ALTER TABLE service_kinds ADD COLUMN default_category TEXT',
      );
    }
    for (final entry in kBuiltInServiceKindCategories.entries) {
      await customStatement(
        'UPDATE service_kinds SET default_category = ? '
        'WHERE id = ? AND default_category IS NULL',
        [entry.value, entry.key],
      );
    }
  }
```

Above `kSeedBuiltInServiceKindsSql` (line 2267), add the mapping so the seed SQL and the migration cannot drift apart:

```dart
/// The category each built-in service type prefills, by stable slug id.
/// Consumed by both kSeedBuiltInServiceKindsSql (fresh installs) and the
/// v160 migration (existing installs).
const Map<String, String> kBuiltInServiceKindCategories = {
  'hydro': 'inspection',
  'vip': 'inspection',
  'bcd-inspection': 'inspection',
  'o2-clean': 'cleaning',
  'regulator-service': 'annual',
  'rebreather-annual': 'annual',
  'general-service': 'annual',
  'computer-battery': 'replacement',
  'transmitter-battery': 'replacement',
  'scrubber-repack': 'replacement',
  'o2-cell-replacement': 'replacement',
  'drysuit-seals': 'repair',
};
```

- [ ] **Step 5: Extend the seed SQL**

In `kSeedBuiltInServiceKindsSql`, add `default_category` to the column list and a category literal to each of the twelve `SELECT` rows, matching `kBuiltInServiceKindCategories` exactly. The column list becomes:

```sql
  INSERT OR IGNORE INTO service_kinds
    (id, diver_id, name, applicable_types, default_interval_days,
     default_interval_dives, default_interval_hours, auto_attach,
     default_category, is_built_in, created_at, updated_at)
  SELECT t.id, NULL, t.name, t.types, t.days, t.dives, t.hours, t.auto,
         t.category, 1, n.now_ms, n.now_ms
```

and each row gains a trailing category, for example:

```sql
    SELECT 'hydro' AS id, 'Hydrostatic test' AS name, '["tank"]' AS types,
           1825 AS days, NULL AS dives, NULL AS hours, 1 AS auto,
           'inspection' AS category
    UNION ALL SELECT 'vip', 'Visual inspection (VIP)', '["tank"]',
           365, NULL, NULL, 1, 'inspection'
```

- [ ] **Step 6: Wire the migration and the backstop**

Bump `currentSchemaVersion` to `160`. Append to `migrationVersions`:

```dart
    // v160 (service type unification): service_kinds.default_category, the
    // category prefilled when a maintenance record is logged.
    160,
```

In `onUpgrade`, after the `if (from < 159) await reportProgress();` line:

```dart
        if (from < 160) {
          await _assertServiceCategoryColumn();
        }
        if (from < 160) await reportProgress();
```

In `beforeOpen`, beside the `_assertServiceCostColumns()` backstop:

```dart
        // v160 backstop: re-assert service_kinds.default_category. A device
        // that reached 160 or higher through a parallel branch never enters
        // the `from < 160` block above.
        await _assertServiceCategoryColumn();
```

- [ ] **Step 7: Run the migration test**

Run: `flutter test test/core/database/migration_v160_service_category_test.dart`
Expected: PASS.

- [ ] **Step 8: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` regenerates with `defaultCategory` on `ServiceKindRow`.

- [ ] **Step 9: Add the entity field**

In `lib/features/equipment/domain/entities/service_kind.dart`, add the field, the constructor parameter, the sentinel `copyWith` handling, and the `props` entry:

```dart
  final ServiceCategory? defaultCategory;
```

```dart
    Object? defaultCategory = _undefined,
```

```dart
      defaultCategory: defaultCategory == _undefined
          ? this.defaultCategory
          : defaultCategory as ServiceCategory?,
```

Import `package:submersion/core/constants/enums.dart` is already present for `EquipmentType`.

- [ ] **Step 10: Persist it in the repository**

In `lib/features/equipment/data/repositories/service_kind_repository.dart`, add to both `ServiceKindsCompanion` literals (create around line 58, update around line 98):

```dart
            defaultCategory: Value(kind.defaultCategory?.name),
```

and to the row-to-entity mapping around line 153:

```dart
      defaultCategory: row.defaultCategory == null
          ? null
          : ServiceCategory.values.firstWhere(
              (c) => c.name == row.defaultCategory,
              orElse: () => ServiceCategory.other,
            ),
```

- [ ] **Step 11: Run the equipment suites**

Run: `dart format lib/ test/`
Run: `flutter analyze`
Run: `flutter test test/core/database/ test/features/equipment/`
Expected: PASS.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "feat(equipment): add default_category to service types (v160)

Each service type can now name the category a record logged against it
should prefill. Built-ins are seeded by slug; custom types start null."
```

---

### Task 3: Rename the column and the wire key, raise the compatibility floor (schema v160, part B)

This is the task with a cost to shipped users. It renames the SQL column and the sync wire key, raises `minimumCompatibleSchemaVersion` to 160, and adds the normaliser that lets payloads and backups written with the old key still apply.

**Files:**
- Modify: `lib/core/database/database.dart` (`ServiceRecords.serviceType` at line 1945, `minimumCompatibleSchemaVersion` at 3120, `_assertServiceCategoryColumn`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`upsertRecord` at 2368, `upsertRecords` at 2855)
- Modify: `lib/features/equipment/data/repositories/service_record_repository.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart`, `uddf_import_parsers.dart`
- Test: `test/core/services/sync/legacy_service_key_test.dart` (new)
- Test: `test/core/database/migration_v160_service_category_test.dart` (extend)
- Test: `test/core/services/sync/cross_version_roundtrip_test.dart` (extend)

**Interfaces:**
- Consumes: `ServiceCategory` (Task 1), the v160 migration block (Task 2).
- Produces: SQL column `service_records.service_category`; Drift getter `ServiceRecords.serviceCategory`; wire key `serviceCategory`; private `SyncDataSerializer._withRenamedKeys(String entityType, Map<String, dynamic> data)` applied at both apply chokepoints.

- [ ] **Step 1: Write the failing normaliser test**

Create `test/core/services/sync/legacy_service_key_test.dart`:

```dart
// A peer or backup written before v160 keys the maintenance category as
// 'serviceType'. The floor bump stops OLD readers applying OUR payloads, but
// the gate is one-directional: their payloads still arrive here, so the apply
// path has to accept the old spelling.
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpTestDatabase);
  tearDown(() => DatabaseService.instance.resetForTesting());

  Map<String, dynamic> baseRecord(String id) => {
    'id': id,
    'equipmentId': 'equip-1',
    'serviceKindId': null,
    'serviceDate': 1700000000000,
    'provider': null,
    'cost': null,
    'currency': 'USD',
    'nextServiceDue': null,
    'notes': '',
    'createdAt': 1700000000000,
    'updatedAt': 1700000000000,
    'hlc': null,
  };

  test('an old peer payload keyed serviceType applies', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecord('serviceRecords', {
      ...baseRecord('rec-old'),
      'serviceType': 'repair',
    });

    final row = await DatabaseService.instance.database
        .customSelect(
          "SELECT service_category FROM service_records WHERE id = 'rec-old'",
        )
        .getSingle();
    expect(row.read<String>('service_category'), 'repair');
  });

  test('a current payload keyed serviceCategory applies', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecord('serviceRecords', {
      ...baseRecord('rec-new'),
      'serviceCategory': 'inspection',
    });

    final row = await DatabaseService.instance.database
        .customSelect(
          "SELECT service_category FROM service_records WHERE id = 'rec-new'",
        )
        .getSingle();
    expect(row.read<String>('service_category'), 'inspection');
  });

  test('the batched path accepts the old key too', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecords('serviceRecords', [
      {...baseRecord('rec-batch'), 'serviceType': 'cleaning'},
    ]);

    final row = await DatabaseService.instance.database
        .customSelect(
          "SELECT service_category FROM service_records WHERE id = 'rec-batch'",
        )
        .getSingle();
    expect(row.read<String>('service_category'), 'cleaning');
  });

  test('a payload carrying both keys prefers the current spelling', () async {
    final serializer = SyncDataSerializer();
    await serializer.upsertRecord('serviceRecords', {
      ...baseRecord('rec-both'),
      'serviceType': 'repair',
      'serviceCategory': 'overhaul',
    });

    final row = await DatabaseService.instance.database
        .customSelect(
          "SELECT service_category FROM service_records WHERE id = 'rec-both'",
        )
        .getSingle();
    expect(row.read<String>('service_category'), 'overhaul');
  });
}
```

The test inserts a service record whose `equipmentId` has no matching equipment row. If the foreign key on `service_records.equipment_id` rejects that, seed an equipment row first with the helper the equipment repository tests use, rather than disabling foreign keys.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync/legacy_service_key_test.dart`
Expected: FAIL, "no such column: service_category".

- [ ] **Step 3: Rename the Drift column**

In `lib/core/database/database.dart`, in `class ServiceRecords`:

```dart
  /// v160: renamed from serviceType. The Drift getter name is also the sync
  /// wire key, so this rename raises minimumCompatibleSchemaVersion; see
  /// SyncDataSerializer._withRenamedKeys for the receiving-side tolerance.
  TextColumn get serviceCategory => text()();
```

- [ ] **Step 4: Extend the v160 migration with the rename**

Add to `_assertServiceCategoryColumn`, after the `service_kinds` work:

```dart
    final recordCols = await customSelect(
      "PRAGMA table_info('service_records')",
    ).get();
    if (recordCols.isEmpty) return;
    final recordNames = recordCols
        .map((c) => c.read<String>('name'))
        .toSet();
    if (recordNames.contains('service_type') &&
        !recordNames.contains('service_category')) {
      await customStatement(
        'ALTER TABLE service_records '
        'RENAME COLUMN service_type TO service_category',
      );
    }
```

`ALTER TABLE RENAME COLUMN` needs SQLite 3.25 or newer, which every supported platform ships.

- [ ] **Step 5: Raise the compatibility floor**

At `lib/core/database/database.dart:3140`:

```dart
  static const int minimumCompatibleSchemaVersion = 160;
```

Extend the doc comment with a line recording why:

```dart
  /// Raised 137 -> 160 by the service type unification: v160 renames the
  /// synced column service_records.service_type to service_category, which
  /// the rules below classify as breaking. Peers below 160 are held until
  /// they update.
```

- [ ] **Step 6: Add the normaliser**

In `lib/core/services/sync/sync_data_serializer.dart`, beside `_withSchemaDefaults` (line 5444):

```dart
  /// Wire keys this build renamed, as oldKey -> newKey per entity type.
  ///
  /// Payloads published by peers below schema 160, and backups written by
  /// them, spell the maintenance category 'serviceType'. The compatibility
  /// floor stops those peers applying OUR payloads, but the gate is
  /// one-directional (changeset_reader.dart compares the writer's floor to
  /// the reader's schema), so their payloads still arrive here and would hit
  /// a NOT NULL column with no key. Delete this once the floor moves past
  /// the last build that published the old spelling.
  static const Map<String, Map<String, String>> _renamedWireKeys = {
    'serviceRecords': {'serviceType': 'serviceCategory'},
  };

  Map<String, dynamic> _withRenamedKeys(
    String entityType,
    Map<String, dynamic> data,
  ) {
    final renames = _renamedWireKeys[entityType];
    if (renames == null) return data;
    Map<String, dynamic>? patched;
    for (final entry in renames.entries) {
      if (!data.containsKey(entry.key)) continue;
      // A payload carrying both keys came from a build that knows the new
      // name, so the new one wins and the stale alias is dropped.
      final map = patched ??= Map.of(data);
      final legacy = map.remove(entry.key);
      map.putIfAbsent(entry.value, () => legacy);
    }
    return patched ?? data;
  }
```

- [ ] **Step 7: Apply it at both chokepoints**

In `upsertRecord` (line 2368):

```dart
    data = _withSchemaDefaults(
      entityType,
      _withRenamedKeys(
        entityType,
        _withoutDeviceLocalFields(data, entityType: entityType),
      ),
    );
```

In `upsertRecords` (line 2855):

```dart
    records = records
        .map(
          (record) => _withSchemaDefaults(
            entityType,
            _withRenamedKeys(
              entityType,
              _withoutDeviceLocalFields(record, entityType: entityType),
            ),
          ),
        )
        .toList();
```

These two methods are the only paths that reach `ServiceRecord.fromJson`, so this covers incremental sync, the adopt path, and restore.

- [ ] **Step 8: Update the repository and UDDF element name**

In `service_record_repository.dart`, the raw-SQL read becomes `row.data['service_category'] as String`, the typed read becomes `row.serviceCategory`, and every companion writes `serviceCategory: Value(record.serviceCategory.name)`.

In `uddf_export_builders.dart`, the element name becomes `'servicecategory'`. In `uddf_import_parsers.dart`, accept both spellings permanently, because exported files live on disk with no version handshake:

```dart
    // Files exported before v160 spell this 'servicetype'. UDDF files have no
    // version handshake, so both spellings are read forever.
    final serviceCategory =
        getElementText(recordElement, 'servicecategory') ??
        getElementText(recordElement, 'servicetype');
    if (serviceCategory != null) {
      record['serviceCategory'] = parseEnumValue(
        serviceCategory,
        enums.ServiceCategory.values,
      );
    }
```

Pin both spellings with a test in `test/core/services/export/uddf/`, alongside the existing parser tests there:

```dart
  test('a service record reads either element spelling', () {
    for (final element in const ['servicetype', 'servicecategory']) {
      final xml = XmlDocument.parse(
        '<record id="service_r1">'
        '<equipmentref>equip_e1</equipmentref>'
        '<$element>overhaul</$element>'
        '<servicedate>2026-01-01T00:00:00.000</servicedate>'
        '</record>',
      ).rootElement;

      final record = parseServiceRecordElement(xml);

      expect(
        record['serviceCategory'],
        enums.ServiceCategory.overhaul,
        reason: '<$element> must parse',
      );
    }
  });
```

Use whatever the parser function is actually named in `uddf_import_parsers.dart`; the surrounding tests in that directory show how they call into it.

- [ ] **Step 9: Regenerate and run the new tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/core/services/sync/legacy_service_key_test.dart`
Expected: PASS.

- [ ] **Step 10: Extend the migration test**

Append to `test/core/database/migration_v160_service_category_test.dart`:

```dart
  test('v160 renames service_type to service_category, preserving values',
      () async {
    final native = NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA user_version = 158');
        db.execute('''
          CREATE TABLE service_records (
            id TEXT NOT NULL PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            service_type TEXT NOT NULL,
            service_kind_id TEXT,
            service_date INTEGER NOT NULL,
            provider TEXT,
            cost REAL,
            currency TEXT NOT NULL DEFAULT 'USD',
            next_service_due INTEGER,
            notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        db.execute(
          "INSERT INTO service_records (id, equipment_id, service_type, "
          "service_date, created_at, updated_at) "
          "VALUES ('r1', 'e1', 'overhaul', 1, 1, 1)",
        );
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final row = await db
        .customSelect('SELECT service_category FROM service_records')
        .getSingle();
    expect(row.read<String>('service_category'), 'overhaul');
  });

  test('the compatibility floor records the rename', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 160);
  });
```

- [ ] **Step 11: Extend the cross-version round-trip test**

That file's header comment instructs the next migration that raises the floor to extend it. Do two things.

First, update the header comment to record that the floor moved to 160 and why, keeping the existing `postV137DiveKeys` constant as the record of the previous boundary.

Second, add a group that drives an old-spelling service record through the real merge path rather than through `upsertRecord` directly, so the normaliser is proven where sync actually calls it:

```dart
  group('pre-160 peer publishing a service record (service type rename)', () {
    test('an old-key payload applies through the merge path', () async {
      final service = buildService();
      final record = {
        'id': 'rec-legacy',
        'equipmentId': 'e1',
        'serviceType': 'repair',
        'serviceKindId': null,
        'serviceDate': 1700000000000,
        'currency': 'USD',
        'notes': '',
        'createdAt': 1700000000000,
        'updatedAt': 1700000000000,
        'hlc': Hlc.now('peer-device').toString(),
      };

      await applyRemoteRecords(service, 'serviceRecords', [record]);

      final row = await DatabaseService.instance.database
          .customSelect(
            "SELECT service_category FROM service_records "
            "WHERE id = 'rec-legacy'",
          )
          .getSingle();
      expect(row.read<String>('service_category'), 'repair');
    });
  });
```

`applyRemoteRecords` stands for whatever this file already uses to push a peer payload through `performSync`; reuse that existing helper rather than adding one, and seed the `e1` equipment row first if the foreign key requires it.

- [ ] **Step 12: Run the full sync and database suites**

Run: `dart format lib/ test/`
Run: `flutter analyze`
Run: `flutter test test/core/services/sync/ test/core/database/`
Expected: PASS.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "feat(sync): rename service_type to service_category (v160)

The Drift getter name is the sync wire key, so this rename is breaking
under the #1089 rules and raises minimumCompatibleSchemaVersion to 160.
The gate is one-directional, so the apply path also accepts the old key
from peers and backups that have not updated."
```

---

### Task 4: Resolve the default category

**Files:**
- Modify: `lib/features/equipment/domain/services/default_service_cost_resolver.dart`
- Test: `test/features/equipment/domain/services/default_service_category_resolver_test.dart` (new)

**Interfaces:**
- Consumes: `ServiceKind.defaultCategory` (Task 2).
- Produces: `ServiceCategory? resolveDefaultServiceCategory({required String? serviceKindId, required List<ServiceKind> kinds})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/equipment/domain/services/default_service_category_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/services/default_service_cost_resolver.dart';

ServiceKind kind(String id, {ServiceCategory? category}) {
  final now = DateTime(2026, 1, 1);
  return ServiceKind(
    id: id,
    name: id,
    defaultCategory: category,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('returns the kind default', () {
    expect(
      resolveDefaultServiceCategory(
        serviceKindId: 'hydro',
        kinds: [kind('hydro', category: ServiceCategory.inspection)],
      ),
      ServiceCategory.inspection,
    );
  });

  test('returns null for a kind with no default', () {
    expect(
      resolveDefaultServiceCategory(
        serviceKindId: 'disinfect',
        kinds: [kind('disinfect')],
      ),
      isNull,
    );
  });

  test('returns null when no kind is selected', () {
    expect(
      resolveDefaultServiceCategory(
        serviceKindId: null,
        kinds: [kind('hydro', category: ServiceCategory.inspection)],
      ),
      isNull,
    );
  });

  test('returns null for an id absent from the catalog', () {
    expect(
      resolveDefaultServiceCategory(
        serviceKindId: 'deleted-kind',
        kinds: [kind('hydro', category: ServiceCategory.inspection)],
      ),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/equipment/domain/services/default_service_category_resolver_test.dart`
Expected: FAIL, "Undefined name 'resolveDefaultServiceCategory'".

- [ ] **Step 3: Implement the resolver**

Append to `lib/features/equipment/domain/services/default_service_cost_resolver.dart`:

```dart
/// Resolves the category to prefill when logging maintenance.
///
/// Unlike the price, this has no per-item level: a schedule carries no
/// category, because a category describes what kind of work a service type
/// is, which does not vary from one item to the next the way a shop's price
/// does. Returns null when nothing is selected, when the selected type has no
/// opinion, or when the id names a type no longer in the catalog.
ServiceCategory? resolveDefaultServiceCategory({
  required String? serviceKindId,
  required List<ServiceKind> kinds,
}) {
  if (serviceKindId == null) return null;
  for (final candidate in kinds) {
    if (candidate.id == serviceKindId) return candidate.defaultCategory;
  }
  return null;
}
```

Add `import 'package:submersion/core/constants/enums.dart';` at the top of the file.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/equipment/domain/services/default_service_category_resolver_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/
git add -A
git commit -m "feat(equipment): resolve a service type's default category"
```

---

### Task 5: Edit the category on a service type

**Files:**
- Modify: `lib/features/equipment/presentation/pages/service_kind_list_page.dart` (`_ServiceKindEditDialog` at line 284, the cost field around 401, the two save branches around 505-545, `_intervalSummary` around line 40)
- Modify: all 11 ARB files
- Test: `test/features/equipment/presentation/pages/service_kind_category_test.dart` (new)

**Interfaces:**
- Consumes: `ServiceKind.defaultCategory` (Task 2), `ServiceCategoryL10n.label` (Task 1).
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Add the ARB keys**

To all 11 files:

```json
  "equipment_serviceKinds_defaultCategoryLabel": "Default category",
  "equipment_serviceKinds_defaultCategoryNone": "No default",
```

Translate both in the ten non-English locales. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget test**

Create `test/features/equipment/presentation/pages/service_kind_category_test.dart`. Build the harness the same way `test/features/equipment/presentation/widgets/service_record_dialog_prefill_test.dart` does: `final overrides = await getBaseOverrides();` from `test/helpers/mock_providers.dart`, a `ProviderScope` overriding `serviceKindsProvider`, and a `MaterialApp` pinned to `const Locale('en')` with `AppLocalizations.localizationsDelegates` and `supportedLocales`, whose `home` is `const ServiceKindListPage()`. Then:

```dart
  testWidgets('the edit dialog offers a default category', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpServiceKindListPage(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('service-kind-default-category')), findsOne);
  });
```

The surface size matters: the dialog body is a scroll view, and an absence or presence assertion against an off-screen child false-passes.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/pages/service_kind_category_test.dart`
Expected: FAIL, no widget with that key.

- [ ] **Step 4: Add the dropdown**

In `_ServiceKindEditDialogState`, add the field beside the other controllers:

```dart
  ServiceCategory? _defaultCategory;
```

initialize it in `initState` from `k?.defaultCategory`, and add the dropdown after the default-currency field, following the full-width pattern the currency dropdown already uses:

```dart
                const SizedBox(height: 12),
                DropdownButtonFormField<ServiceCategory?>(
                  key: const Key('service-kind-default-category'),
                  initialValue: _defaultCategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText:
                        l10n.equipment_serviceKinds_defaultCategoryLabel,
                  ),
                  items: [
                    DropdownMenuItem<ServiceCategory?>(
                      value: null,
                      child: Text(
                        l10n.equipment_serviceKinds_defaultCategoryNone,
                      ),
                    ),
                    for (final category in ServiceCategory.values)
                      DropdownMenuItem<ServiceCategory?>(
                        value: category,
                        child: Text(category.label(l10n)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _defaultCategory = value),
                ),
```

Add the imports for `enums.dart` and `service_category_label.dart`.

- [ ] **Step 5: Persist it in both save branches**

Add `defaultCategory: _defaultCategory,` to the `ServiceKind(...)` literal in the create branch and in the update branch (both around lines 505-545). The update branch builds the entity directly rather than using `copyWith`, so a cleared category is written as null.

- [ ] **Step 6: Show it in the row summary**

Extend `_intervalSummary` so a kind with a category reads as, for example, "every 365 days · Inspection". Append the category label to `parts` when `kind.defaultCategory != null`, using the same `' · '` join.

- [ ] **Step 7: Run the test**

Run: `flutter test test/features/equipment/presentation/pages/service_kind_category_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib/ test/
flutter analyze
git add -A
git commit -m "feat(equipment): choose a default category per service type"
```

---

### Task 6: Rework the service record dialog

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/service_record_dialog.dart`
- Modify: all 11 ARB files
- Test: `test/features/equipment/presentation/widgets/service_record_dialog_category_test.dart` (new)

**Interfaces:**
- Consumes: `resolveDefaultServiceCategory` (Task 4), `ServiceCategoryL10n.label` (Task 1).
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Add the ARB keys**

To all 11 files, translated:

```json
  "equipment_serviceDialog_serviceTypeLabel": "Service type",
  "equipment_serviceDialog_serviceTypeHelper": "Logging this resets the clock for this service type",
  "equipment_serviceDialog_serviceTypeRequired": "Pick a service type",
  "equipment_serviceDialog_serviceTypeNotSet": "Not set",
  "equipment_serviceDialog_categoryHelper": "Used for filtering and export",
  "equipment_serviceDialog_manageServiceTypes": "Manage service types",
```

Note that `equipment_serviceDialog_serviceTypeLabel` is being reintroduced with a new meaning: Task 1 renamed the old key of that name to `equipment_serviceDialog_categoryLabel`, so this is a fresh key whose value now names the catalog. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget test**

Create `test/features/equipment/presentation/widgets/service_record_dialog_category_test.dart`. Copy the harness verbatim from `service_record_dialog_prefill_test.dart` in the same directory: it already builds `getBaseOverrides()`, overrides `serviceKindsProvider` and `serviceSchedulesForEquipmentProvider('e1')`, and pumps `ServiceRecordDialog` inside a `MaterialApp` pinned to `const Locale('en')` with `AppLocalizations.localizationsDelegates`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const serviceTypeKey = Key('service-record-service-type');
const categoryKey = Key('service-record-category');

void main() {
  final t0 = DateTime(2026, 1, 1);

  ServiceKind kind(String id, ServiceCategory? category) => ServiceKind(
    id: id,
    name: id,
    defaultCategory: category,
    createdAt: t0,
    updatedAt: t0,
  );

  ServiceCategory categoryValue(WidgetTester tester) => tester
      .widget<DropdownButtonFormField<ServiceCategory>>(
        find.byKey(categoryKey),
      )
      .initialValue!;

  Future<void> pumpDialog(
    WidgetTester tester, {
    String? serviceKindId,
    ServiceRecord? existingRecord,
    Future<void> Function(ServiceRecord)? onSave,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          serviceKindsProvider.overrideWith(
            (ref) async => [
              kind('hydro', ServiceCategory.inspection),
              kind('o2-clean', ServiceCategory.cleaning),
            ],
          ),
          serviceSchedulesForEquipmentProvider(
            'e1',
          ).overrideWith((ref) async => []),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ServiceRecordDialog(
              equipmentId: 'e1',
              serviceKindId: serviceKindId,
              existingRecord: existingRecord,
              onSave: onSave ?? (record) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickServiceType(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(serviceTypeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(id).last);
    await tester.pumpAndSettle();
  }

  testWidgets('picking a service type prefills its default category', (
    tester,
  ) async {
    await pumpDialog(tester);
    await pickServiceType(tester, 'hydro');

    expect(categoryValue(tester), ServiceCategory.inspection);
  });

  testWidgets('a category the diver chose survives changing the type', (
    tester,
  ) async {
    await pumpDialog(tester, serviceKindId: 'hydro');

    await tester.tap(find.byKey(categoryKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overhaul').last);
    await tester.pumpAndSettle();

    await pickServiceType(tester, 'o2-clean');

    expect(
      categoryValue(tester),
      ServiceCategory.overhaul,
      reason: 'the touched flag must block the o2-clean default',
    );
  });

  testWidgets('creating a record requires a service type', (tester) async {
    var saved = false;
    await pumpDialog(
      tester,
      serviceKindId: null,
      onSave: (_) async => saved = true,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a service type'), findsOneWidget);
    expect(saved, isFalse);
  });

  testWidgets('editing a record with no service type can still be saved', (
    tester,
  ) async {
    var saved = false;
    await pumpDialog(
      tester,
      existingRecord: ServiceRecord(
        id: 'r1',
        equipmentId: 'e1',
        serviceCategory: ServiceCategory.repair,
        serviceDate: t0,
        createdAt: t0,
        updatedAt: t0,
      ),
      onSave: (_) async => saved = true,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
  });
}
```

If the dialog's save button carries a different label in the current build, read it from the widget rather than guessing: the point of the assertion is that validation blocks the callback, not the button's wording.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/equipment/presentation/widgets/service_record_dialog_category_test.dart`
Expected: FAIL on the missing widget keys and on the absent validation.

- [ ] **Step 4: Add the category touched flag and prefill**

Beside `_costTouched` and `_currencyTouched`:

```dart
  /// Set as soon as the diver picks a category. Once set, the service type's
  /// default never writes over it again, including when the type changes and
  /// re-resolves.
  bool _categoryTouched = false;
```

Rename `_maybePrefillCost` to `_maybePrefillFromKind` and add the category branch, keeping the existing cost and currency logic untouched:

```dart
    if (!_categoryTouched) {
      final category = resolveDefaultServiceCategory(
        serviceKindId: _serviceKindId,
        kinds: kinds,
      );
      if (category != null && category != _serviceCategory) {
        _serviceCategory = category;
      }
    }
```

The guard chain is the same as the cost's: `if (isEditing) return;` at the top, so editing never re-prefills. Rename the call site in `build` too, where the method is invoked from inside the `serviceKindsProvider` / `serviceSchedulesForEquipmentProvider` data branch; the compiler catches this, but the method is called from a nested builder that is easy to skim past.

- [ ] **Step 5: Reorder and relabel the dropdowns**

Move the service-type (catalog) dropdown above the category dropdown. The catalog dropdown becomes:

```dart
                ref
                    .watch(serviceKindsProvider)
                    .maybeWhen(
                      data: (kinds) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String?>(
                            key: const Key('service-record-service-type'),
                            initialValue:
                                kinds.any((k) => k.id == _serviceKindId)
                                ? _serviceKindId
                                : null,
                            decoration: InputDecoration(
                              labelText: context
                                  .l10n
                                  .equipment_serviceDialog_serviceTypeLabel,
                              helperText: context
                                  .l10n
                                  .equipment_serviceDialog_serviceTypeHelper,
                              prefixIcon: const Icon(Icons.build),
                            ),
                            // Required when creating, optional when editing:
                            // forcing a pick on an existing record would
                            // attach a clock and move its anchor.
                            validator: (value) =>
                                !isEditing && value == null
                                ? context
                                      .l10n
                                      .equipment_serviceDialog_serviceTypeRequired
                                : null,
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  context
                                      .l10n
                                      .equipment_serviceDialog_serviceTypeNotSet,
                                ),
                              ),
                              for (final kind in kinds)
                                DropdownMenuItem<String?>(
                                  value: kind.id,
                                  child: Text(kind.name),
                                ),
                            ],
                            onChanged: (value) {
                              setState(() => _serviceKindId = value);
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
```

The category dropdown follows, keeping its existing structure with the new label, helper text, a key, and the touched flag:

```dart
                DropdownButtonFormField<ServiceCategory>(
                  key: const Key('service-record-category'),
                  initialValue: _serviceCategory,
                  decoration: InputDecoration(
                    labelText:
                        context.l10n.equipment_serviceDialog_categoryLabel,
                    helperText:
                        context.l10n.equipment_serviceDialog_categoryHelper,
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                  items: ServiceCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.label(context.l10n)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _categoryTouched = true;
                      setState(() => _serviceCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
```

- [ ] **Step 6: Add the manage link**

Directly under the catalog dropdown, inside the same `Column`:

```dart
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: () =>
                                  context.pushNamed('manageServiceTypes'),
                              child: Text(
                                context
                                    .l10n
                                    .equipment_serviceDialog_manageServiceTypes,
                              ),
                            ),
                          ),
```

Import `package:go_router/go_router.dart`. The route name `manageServiceTypes` already exists at `lib/core/router/app_router.dart:527`.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/equipment/presentation/widgets/`
Expected: PASS, including the pre-existing dialog tests.

- [ ] **Step 8: Commit**

```bash
dart format lib/ test/
flutter analyze
git add -A
git commit -m "feat(equipment): ask for one service type when logging service

The catalog picker leads the form and is required on new records; the
category follows it, prefilled from the chosen type and never
overwritten once the diver touches it."
```

---

### Task 7: Add the Settings > Manage entry

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (`_ManageSectionContent`, in the card that starts around line 2219)
- Modify: all 11 ARB files
- Test: `test/features/settings/manage_service_types_tile_test.dart` (new)

**Interfaces:**
- Consumes: the existing `manageServiceTypes` route.
- Produces: nothing.

- [ ] **Step 1: Add the ARB keys**

To all 11 files, translated:

```json
  "settings_manage_serviceTypes": "Service types",
  "settings_manage_serviceTypes_subtitle": "Maintenance tasks your gear needs, and how often",
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/features/settings/manage_service_types_tile_test.dart`. `test/features/settings/presentation/pages/settings_page_test.dart` already pumps the settings page and reaches the manage section; copy its setup, including how it selects the section, rather than inventing a new one. The test body:

```dart
  testWidgets('the manage section links to the service type catalog',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpManageSection(tester);

    expect(find.text('Service types'), findsOneWidget);
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/settings/manage_service_types_tile_test.dart`
Expected: FAIL, no such text.

- [ ] **Step 4: Add the tile**

Immediately after the Tank presets tile and its `Divider`, matching the surrounding pattern exactly:

```dart
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.build_circle_outlined),
                  title: Text(context.l10n.settings_manage_serviceTypes),
                  subtitle: Text(
                    context.l10n.settings_manage_serviceTypes_subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/equipment/service-types'),
                ),
```

- [ ] **Step 5: Run the test**

Run: `flutter test test/features/settings/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
dart format lib/ test/
flutter analyze
git add -A
git commit -m "feat(settings): manage service types from Settings > Manage"
```

---

### Task 8: Align the Excel export vocabulary

**Files:**
- Modify: `lib/core/services/export/excel/maintenance_excel_export_service.dart` (class docstring around line 28, header row around line 52)
- Test: `test/core/services/export/excel/maintenance_excel_export_service_test.dart` (extend the existing test)

**Interfaces:**
- Consumes: Task 1's rename.
- Produces: nothing.

- [ ] **Step 1: Update the failing assertion**

In the existing maintenance Excel test, change the expected header row so the third column reads `Service Type` instead of `Task`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/export/excel/maintenance_excel_export_service_test.dart`
Expected: FAIL, expected `Service Type` but found `Task`.

- [ ] **Step 3: Rename the header and the docstring**

The header list becomes:

```dart
    _writeRow(sheet, 0, const [
      'Equipment',
      'Equipment Type',
      'Service Type',
      'Category',
      'Date',
      'Provider',
      'Cost',
      'Currency',
      'Next Due',
      'Notes',
```

and the class docstring:

```dart
/// One row per service record, carrying both classifications the diver cares
/// about: the service type (which of my maintenance jobs) and the category
/// (what kind of work).
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/core/services/export/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/ test/
git add -A
git commit -m "refactor(export): name the maintenance log columns as the UI does"
```

---

## Final verification

- [ ] Run `dart format lib/ test/` and confirm no files change.
- [ ] Run `flutter analyze` and confirm zero issues, including informational lints.
- [ ] Run the full suite **twice**: `flutter test`. Do not pipe the output through `grep` or `tail`, because the pipeline's exit code hides the test runner's. Disjoint failure sets across the two runs indicate pre-existing flakes rather than a regression from this work; known flaky areas are the encrypted-backup tests, the recovery-code split, the security-settings recovery dialog, and the zip temp-dir tests.
- [ ] Restore a backup produced by a pre-160 build and confirm its service records land with their categories intact. The spec asks for this as an automated test; Task 3 covers the mechanism instead, by pinning both wire spellings at `upsertRecord` and `upsertRecords`, which are the only paths reaching `ServiceRecord.fromJson`. Verify the end-to-end path here at least once by hand.
- [ ] Confirm no other PR has claimed schema 160; renumber everything together if one has.
- [ ] Interactive macOS smoke: log a service record and confirm the type is required, the category prefills and stays put once changed; open Settings > Manage > Service types; set a default category on a custom type; confirm the history row title and the clock reset still behave.
- [ ] PR body must state the compatibility floor change in plain terms: peers below schema 160 are held until they update, which includes the App Store fleet during the review window. Also note the inherited #1144 gap, which leaves `default_category` on custom service types out of incremental sync to a second device.
