# Dive Custom Fields Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add freeform key:value custom fields to dive log entries with autocomplete, search, and full export/import support.

**Architecture:** New `DiveCustomFields` child table (one row per key:value pair per dive) following the existing `DiveWeights`/`DiveTags` pattern. Domain entity `DiveCustomField` added to the `Dive` aggregate. Batch-loaded in list views, individually loaded in detail views. Integrated into CSV, UDDF, and PDF export/import.

**Tech Stack:** Drift ORM, Riverpod, Flutter Material 3, xml package for UDDF, pdf package for PDF, csv package for CSV.

**Design Doc:** `docs/plans/2026-02-13-dive-custom-fields-design.md`

---

### Task 1: Domain Entity — DiveCustomField

**Files:**
- Create: `lib/features/dive_log/domain/entities/dive_custom_field.dart`
- Test: `test/features/dive_log/domain/entities/dive_custom_field_test.dart`

**Step 1: Write the failing test**

```dart
// test/features/dive_log/domain/entities/dive_custom_field_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';

void main() {
  group('DiveCustomField', () {
    test('constructs with required fields', () {
      const field = DiveCustomField(
        id: 'cf-1',
        key: 'camera_settings',
        value: 'f/8 ISO400',
      );

      expect(field.id, 'cf-1');
      expect(field.key, 'camera_settings');
      expect(field.value, 'f/8 ISO400');
      expect(field.sortOrder, 0);
    });

    test('defaults value to empty string', () {
      const field = DiveCustomField(id: 'cf-1', key: 'mood');
      expect(field.value, '');
    });

    test('copyWith creates new instance with updated fields', () {
      const original = DiveCustomField(
        id: 'cf-1',
        key: 'camera_settings',
        value: 'f/8 ISO400',
        sortOrder: 0,
      );

      final updated = original.copyWith(value: 'f/11 ISO200', sortOrder: 1);

      expect(updated.id, 'cf-1');
      expect(updated.key, 'camera_settings');
      expect(updated.value, 'f/11 ISO200');
      expect(updated.sortOrder, 1);
      expect(original.value, 'f/8 ISO400'); // original unchanged
    });

    test('equality based on all props', () {
      const a = DiveCustomField(id: 'cf-1', key: 'k', value: 'v');
      const b = DiveCustomField(id: 'cf-1', key: 'k', value: 'v');
      const c = DiveCustomField(id: 'cf-2', key: 'k', value: 'v');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_custom_field_test.dart`
Expected: FAIL — import not found

**Step 3: Write the entity**

```dart
// lib/features/dive_log/domain/entities/dive_custom_field.dart
import 'package:equatable/equatable.dart';

/// A user-defined key:value field attached to a dive log entry.
class DiveCustomField extends Equatable {
  final String id;
  final String key;
  final String value;
  final int sortOrder;

  const DiveCustomField({
    required this.id,
    required this.key,
    this.value = '',
    this.sortOrder = 0,
  });

  DiveCustomField copyWith({
    String? id,
    String? key,
    String? value,
    int? sortOrder,
  }) {
    return DiveCustomField(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [id, key, value, sortOrder];
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/dive_custom_field_test.dart`
Expected: PASS (4 tests)

**Step 5: Commit**

```
feat: add DiveCustomField domain entity
```

---

### Task 2: Add customFields to Dive Entity

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart`
- Test: `test/features/dive_log/domain/entities/dive_custom_field_test.dart` (extend)

**Step 1: Write the failing test**

Append to the existing test file:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

group('Dive.customFields', () {
  test('defaults to empty list', () {
    final dive = Dive(
      id: 'd-1',
      dateTime: DateTime(2024, 1, 15),
    );
    expect(dive.customFields, isEmpty);
  });

  test('copyWith preserves customFields', () {
    final dive = Dive(
      id: 'd-1',
      dateTime: DateTime(2024, 1, 15),
      customFields: const [
        DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ],
    );

    final updated = dive.copyWith(notes: 'updated');
    expect(updated.customFields.length, 1);
    expect(updated.customFields.first.key, 'mood');
  });

  test('copyWith replaces customFields', () {
    final dive = Dive(
      id: 'd-1',
      dateTime: DateTime(2024, 1, 15),
      customFields: const [
        DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ],
    );

    final updated = dive.copyWith(customFields: const []);
    expect(updated.customFields, isEmpty);
  });
});
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/dive_custom_field_test.dart`
Expected: FAIL — `customFields` not found on Dive

**Step 3: Add customFields to Dive entity**

In `lib/features/dive_log/domain/entities/dive.dart`:

1. Add import: `import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';`
2. Add field to class: `final List<DiveCustomField> customFields;`
3. Add to constructor: `this.customFields = const [],`
4. Add to `copyWith` parameter: `List<DiveCustomField>? customFields,`
5. Add to `copyWith` body: `customFields: customFields ?? this.customFields,`
6. Add to `props`: `customFields,`

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/dive_custom_field_test.dart`
Expected: PASS (7 tests)

**Step 5: Commit**

```
feat: add customFields list to Dive entity
```

---

### Task 3: Database Table & Migration

**Files:**
- Modify: `lib/core/database/database.dart`

**Step 1: Add the Drift table definition**

Add before the `// Sync Tables` comment in `database.dart`:

```dart
/// User-defined key:value fields per dive
class DiveCustomFields extends Table {
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get fieldKey => text()();
  TextColumn get fieldValue => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

**Step 2: Register the table in @DriftDatabase**

Add `DiveCustomFields,` to the `tables` list in the `@DriftDatabase` annotation (after `ScheduledNotifications`).

**Step 3: Bump schema version from 33 to 34**

Change: `int get schemaVersion => 34;`

**Step 4: Add migration**

Add inside `onUpgrade`, after the `if (from < 33)` block:

```dart
if (from < 34) {
  await customStatement('''
    CREATE TABLE IF NOT EXISTS dive_custom_fields (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
      field_key TEXT NOT NULL,
      field_value TEXT NOT NULL DEFAULT '',
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
  ''');
  await customStatement('''
    CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_dive_id
    ON dive_custom_fields(dive_id)
  ''');
  await customStatement('''
    CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_key
    ON dive_custom_fields(field_key)
  ''');
}
```

**Step 5: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated `database.g.dart` with `DiveCustomField` Drift classes

**Step 6: Verify build**

Run: `flutter analyze`
Expected: No issues

**Step 7: Commit**

```
feat: add dive_custom_fields table (schema v34)
```

---

### Task 4: DiveCustomField Repository

**Files:**
- Create: `lib/features/dive_log/data/repositories/dive_custom_field_repository.dart`
- Test: `test/features/dive_log/data/repositories/dive_custom_field_repository_test.dart`

**Step 1: Write failing tests**

```dart
// test/features/dive_log/data/repositories/dive_custom_field_repository_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_custom_field_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';

void main() {
  late AppDatabase db;
  late DiveCustomFieldRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DiveCustomFieldRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> createTestDive(String id, {String? diverId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.dives).insert(
      DivesCompanion(
        id: Value(id),
        diverId: Value(diverId),
        diveDateTime: Value(now),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  group('DiveCustomFieldRepository', () {
    test('getFieldsForDive returns empty list when no fields', () async {
      await createTestDive('d-1');
      final fields = await repository.getFieldsForDive('d-1');
      expect(fields, isEmpty);
    });

    test('replaceFieldsForDive inserts fields', () async {
      await createTestDive('d-1');
      final fields = [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great', sortOrder: 0),
        const DiveCustomField(id: 'cf-2', key: 'camera', value: 'GoPro', sortOrder: 1),
      ];

      await repository.replaceFieldsForDive('d-1', fields);
      final result = await repository.getFieldsForDive('d-1');

      expect(result.length, 2);
      expect(result[0].key, 'mood');
      expect(result[0].value, 'great');
      expect(result[1].key, 'camera');
    });

    test('replaceFieldsForDive replaces existing fields', () async {
      await createTestDive('d-1');
      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ]);

      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-2', key: 'camera', value: 'Sony'),
      ]);

      final result = await repository.getFieldsForDive('d-1');
      expect(result.length, 1);
      expect(result[0].key, 'camera');
    });

    test('getDistinctKeysForDiver returns unique keys across dives', () async {
      await createTestDive('d-1', diverId: 'diver-1');
      await createTestDive('d-2', diverId: 'diver-1');

      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
        const DiveCustomField(id: 'cf-2', key: 'camera', value: 'GoPro'),
      ]);
      await repository.replaceFieldsForDive('d-2', [
        const DiveCustomField(id: 'cf-3', key: 'mood', value: 'tired'),
        const DiveCustomField(id: 'cf-4', key: 'task', value: 'nav drill'),
      ]);

      final keys = await repository.getDistinctKeysForDiver('diver-1');
      expect(keys, containsAll(['mood', 'camera', 'task']));
      expect(keys.length, 3);
    });

    test('getDistinctKeysForDiver filters by diver', () async {
      await createTestDive('d-1', diverId: 'diver-1');
      await createTestDive('d-2', diverId: 'diver-2');

      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ]);
      await repository.replaceFieldsForDive('d-2', [
        const DiveCustomField(id: 'cf-2', key: 'secret', value: 'hidden'),
      ]);

      final keys = await repository.getDistinctKeysForDiver('diver-1');
      expect(keys, ['mood']);
      expect(keys, isNot(contains('secret')));
    });

    test('fields are deleted when parent dive is deleted', () async {
      await createTestDive('d-1');
      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ]);

      await (db.delete(db.dives)..where((d) => d.id.equals('d-1'))).go();
      final result = await repository.getFieldsForDive('d-1');
      expect(result, isEmpty);
    });

    test('getFieldsForDiveIds batch loads fields grouped by dive', () async {
      await createTestDive('d-1');
      await createTestDive('d-2');

      await repository.replaceFieldsForDive('d-1', [
        const DiveCustomField(id: 'cf-1', key: 'mood', value: 'great'),
      ]);
      await repository.replaceFieldsForDive('d-2', [
        const DiveCustomField(id: 'cf-2', key: 'task', value: 'nav'),
        const DiveCustomField(id: 'cf-3', key: 'camera', value: 'Sony'),
      ]);

      final result = await repository.getFieldsForDiveIds(['d-1', 'd-2']);
      expect(result['d-1']?.length, 1);
      expect(result['d-2']?.length, 2);
    });
  });
}
```

**Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_custom_field_repository_test.dart`
Expected: FAIL — import not found

**Step 3: Implement the repository**

```dart
// lib/features/dive_log/data/repositories/dive_custom_field_repository.dart
import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:uuid/uuid.dart';

class DiveCustomFieldRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  DiveCustomFieldRepository(this._db);

  Future<List<DiveCustomField>> getFieldsForDive(String diveId) async {
    final query = _db.select(_db.diveCustomFields)
      ..where((cf) => cf.diveId.equals(diveId))
      ..orderBy([(cf) => OrderingTerm.asc(cf.sortOrder)]);
    final rows = await query.get();
    return rows.map(_mapRowToField).toList();
  }

  Future<Map<String, List<DiveCustomField>>> getFieldsForDiveIds(
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return {};
    final rows = await (_db.select(_db.diveCustomFields)
          ..where((cf) => cf.diveId.isIn(diveIds))
          ..orderBy([(cf) => OrderingTerm.asc(cf.sortOrder)]))
        .get();

    final result = <String, List<DiveCustomField>>{};
    for (final row in rows) {
      result.putIfAbsent(row.diveId, () => []).add(_mapRowToField(row));
    }
    return result;
  }

  Future<void> replaceFieldsForDive(
    String diveId,
    List<DiveCustomField> fields,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(_db.diveCustomFields)
            ..where((cf) => cf.diveId.equals(diveId)))
          .go();

      final now = DateTime.now().millisecondsSinceEpoch;
      for (final field in fields) {
        final id = field.id.isNotEmpty ? field.id : _uuid.v4();
        await _db.into(_db.diveCustomFields).insert(
          DiveCustomFieldsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            fieldKey: Value(field.key),
            fieldValue: Value(field.value),
            sortOrder: Value(field.sortOrder),
            createdAt: Value(now),
          ),
        );
      }
    });
  }

  Future<List<String>> getDistinctKeysForDiver(String diverId) async {
    final result = await _db.customSelect(
      'SELECT DISTINCT cf.field_key FROM dive_custom_fields cf '
      'INNER JOIN dives d ON cf.dive_id = d.id '
      'WHERE d.diver_id = ? '
      'ORDER BY cf.field_key',
      variables: [Variable(diverId)],
    ).get();

    return result.map((row) => row.data['field_key'] as String).toList();
  }

  DiveCustomField _mapRowToField(DiveCustomFieldData row) {
    return DiveCustomField(
      id: row.id,
      key: row.fieldKey,
      value: row.fieldValue,
      sortOrder: row.sortOrder,
    );
  }
}
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_custom_field_repository_test.dart`
Expected: PASS (7 tests)

**Step 5: Commit**

```
feat: add DiveCustomFieldRepository with CRUD and batch loading
```

---

### Task 5: Integrate into DiveRepository

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`

**Step 1: Add imports and field**

At the top of `DiveRepository`, add:
- Import: `import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';`
- Import: `import 'package:submersion/features/dive_log/data/repositories/dive_custom_field_repository.dart';`
- Field: `late final DiveCustomFieldRepository _customFieldRepository;`
- In constructor or init: `_customFieldRepository = DiveCustomFieldRepository(_db);`

**Step 2: Add _loadCustomFieldsForDive helper**

Add near the existing `_loadWeightsForDive` method:

```dart
Future<List<DiveCustomField>> _loadCustomFieldsForDive(String diveId) async {
  try {
    return await _customFieldRepository.getFieldsForDive(diveId);
  } catch (e, stackTrace) {
    _log.error('Failed to load custom fields for dive: $diveId', e, stackTrace);
    return [];
  }
}
```

**Step 3: Add to _mapRowToDive (single dive detail loading)**

In `_mapRowToDive`, after loading weights, add:

```dart
final customFields = await _loadCustomFieldsForDive(row.id);
```

Then pass to the returned `Dive(...)`:

```dart
customFields: customFields,
```

**Step 4: Add to getAllDives batch loading**

In `getAllDives`, after the existing batch loads (tanks, equipment, tags, etc.), add:

```dart
final customFieldsByDive = await _customFieldRepository.getFieldsForDiveIds(diveIds);
```

Then pass to `_mapRowToDiveWithPreloadedData`:

```dart
customFields: customFieldsByDive[row.id] ?? [],
```

**Step 5: Update _mapRowToDiveWithPreloadedData signature**

Add parameter:

```dart
List<DiveCustomField> customFields = const [],
```

And include in the returned Dive:

```dart
customFields: customFields,
```

**Step 6: Add to createDive (save custom fields)**

In `createDive`, inside the batch insert section (after weights), add:

```dart
// Insert custom fields
for (final field in dive.customFields) {
  final fieldId = field.id.isNotEmpty ? field.id : _uuid.v4();
  batch.insert(
    _db.diveCustomFields,
    DiveCustomFieldsCompanion(
      id: Value(fieldId),
      diveId: Value(id),
      fieldKey: Value(field.key),
      fieldValue: Value(field.value),
      sortOrder: Value(field.sortOrder),
      createdAt: Value(now),
    ),
  );
}
```

**Step 7: Add to updateDive (replace custom fields)**

In `updateDive`, after the weight delete-and-reinsert block, add the same pattern:

```dart
// Update custom fields: delete and re-insert
final existingCustomFields = await (_db.select(_db.diveCustomFields)
    ..where((cf) => cf.diveId.equals(dive.id))).get();
await (_db.delete(_db.diveCustomFields)
    ..where((cf) => cf.diveId.equals(dive.id))).go();
for (final cf in existingCustomFields) {
  await _syncRepository.logDeletion(
    entityType: 'diveCustomFields',
    recordId: cf.id,
  );
}
for (final field in dive.customFields) {
  final fieldId = field.id.isNotEmpty ? field.id : _uuid.v4();
  await _db.into(_db.diveCustomFields).insert(
    DiveCustomFieldsCompanion(
      id: Value(fieldId),
      diveId: Value(dive.id),
      fieldKey: Value(field.key),
      fieldValue: Value(field.value),
      sortOrder: Value(field.sortOrder),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ),
  );
  await _syncRepository.markRecordPending(
    entityType: 'diveCustomFields',
    recordId: fieldId,
    localUpdatedAt: now,
  );
}
```

**Step 8: Verify build**

Run: `flutter analyze && flutter test`
Expected: No analysis issues, all existing tests pass

**Step 9: Commit**

```
feat: integrate custom fields into DiveRepository load/save
```

---

### Task 6: Riverpod Providers

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart`

**Step 1: Add the autocomplete provider**

Add imports:
```dart
import 'package:submersion/features/dive_log/data/repositories/dive_custom_field_repository.dart';
```

Add providers:

```dart
/// Custom field repository singleton
final diveCustomFieldRepositoryProvider = Provider<DiveCustomFieldRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DiveCustomFieldRepository(db);
});

/// Autocomplete suggestions: distinct keys this diver has used
final customFieldKeySuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  diverId,
) async {
  final repository = ref.watch(diveCustomFieldRepositoryProvider);
  return repository.getDistinctKeysForDiver(diverId);
});
```

**Step 2: Verify build**

Run: `flutter analyze`
Expected: No issues

**Step 3: Commit**

```
feat: add custom field Riverpod providers
```

---

### Task 7: Localization Keys

**Files:**
- Modify: `lib/l10n/app_en.arb` (and other locale files)

**Step 1: Add English ARB keys**

Add the following keys to `app_en.arb`:

```json
"diveLog_edit_section_customFields": "Custom Fields",
"diveLog_edit_addCustomField": "Add Field",
"diveLog_edit_customFieldKey": "Key",
"diveLog_edit_customFieldValue": "Value",
"diveLog_edit_customFieldKeyHint": "e.g., camera_settings",
"diveLog_edit_customFieldValueHint": "e.g., f/8 ISO400",
"diveLog_detail_section_customFields": "Custom Fields",
"diveLog_detail_customFieldCount": "{count, plural, =1{1 field} other{{count} fields}}",
"diveLog_search_customFieldKey": "Custom Field Key",
"diveLog_search_customFieldValue": "Value contains..."
```

**Step 2: Add corresponding keys to other ARB files** (es, fr, de, it, nl, pt, ar, he, hu)

Copy the keys with the English values as placeholders (to be translated later).

**Step 3: Run code generation**

Run: `flutter gen-l10n`
Expected: Generates updated localization delegates

**Step 4: Commit**

```
feat: add localization keys for custom fields
```

---

### Task 8: Dive Edit Page — Custom Fields Section

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Create: `lib/features/dive_log/presentation/widgets/custom_field_input_row.dart`

**Step 1: Create CustomFieldInputRow widget**

```dart
// lib/features/dive_log/presentation/widgets/custom_field_input_row.dart
import 'package:flutter/material.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';

class CustomFieldInputRow extends StatelessWidget {
  final DiveCustomField field;
  final List<String> keySuggestions;
  final ValueChanged<DiveCustomField> onChanged;
  final VoidCallback onDelete;

  const CustomFieldInputRow({
    super.key,
    required this.field,
    required this.keySuggestions,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.drag_handle, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: field.key),
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return keySuggestions;
                }
                return keySuggestions.where(
                  (s) => s.toLowerCase().contains(
                    textEditingValue.text.toLowerCase(),
                  ),
                );
              },
              onSelected: (value) {
                onChanged(field.copyWith(key: value));
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Key',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    onChanged(field.copyWith(key: value));
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: TextFormField(
              initialValue: field.value,
              decoration: const InputDecoration(
                labelText: 'Value',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                onChanged(field.copyWith(value: value));
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onDelete,
            tooltip: 'Remove field',
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Add state variable in dive_edit_page.dart**

In `_DiveEditPageState`, add:

```dart
List<DiveCustomField> _customFields = [];
```

**Step 3: Initialize in _loadDive**

In `_loadDive()`, after loading other fields, add:

```dart
_customFields = dive.customFields.toList();
```

**Step 4: Include in _saveDive**

When constructing the dive for save, include:

```dart
customFields: _customFields,
```

**Step 5: Add _buildCustomFieldsSection method**

Add the method and call it at the bottom of the ListView, after the tags section:

```dart
Widget _buildCustomFieldsSection() {
  final currentDiverId = ref.watch(currentDiverIdProvider);
  final suggestions = currentDiverId != null
      ? ref.watch(customFieldKeySuggestionsProvider(currentDiverId)).valueOrNull ?? []
      : <String>[];

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.diveLog_edit_section_customFields,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_customFields.isNotEmpty) const Divider(),
          ..._customFields.asMap().entries.map((entry) {
            final index = entry.key;
            final field = entry.value;
            return CustomFieldInputRow(
              key: ValueKey(field.id),
              field: field,
              keySuggestions: suggestions,
              onChanged: (updated) {
                setState(() {
                  _customFields[index] = updated;
                });
              },
              onDelete: () {
                setState(() {
                  _customFields.removeAt(index);
                });
              },
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _customFields.add(
                  DiveCustomField(
                    id: const Uuid().v4(),
                    key: '',
                    value: '',
                    sortOrder: _customFields.length,
                  ),
                );
              });
            },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.diveLog_edit_addCustomField),
          ),
        ],
      ),
    ),
  );
}
```

**Step 6: Verify build and manual test**

Run: `flutter analyze`
Then: `flutter run -d macos` and test adding/editing/saving custom fields on a dive.

**Step 7: Commit**

```
feat: add Custom Fields section to dive edit page
```

---

### Task 9: Dive Detail Page — Custom Fields Section

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

**Step 1: Add _buildCustomFieldsSection method**

```dart
Widget _buildCustomFieldsSection(BuildContext context, Dive dive) {
  if (dive.customFields.isEmpty) return const SizedBox.shrink();

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_detail_section_customFields,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                context.l10n.diveLog_detail_customFieldCount(
                  dive.customFields.length,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Divider(),
          ...dive.customFields.map(
            (field) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${field.key}:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      field.value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

**Step 2: Add section to the build method**

In `_buildContent`, after the tags section conditional block, add:

```dart
if (dive.customFields.isNotEmpty) ...[
  const SizedBox(height: 24),
  _buildCustomFieldsSection(context, dive),
],
```

**Step 3: Verify build and manual test**

Run: `flutter analyze`
Then: `flutter run -d macos` and verify custom fields display on dive detail.

**Step 4: Commit**

```
feat: add Custom Fields section to dive detail page
```

---

### Task 10: Search Integration

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (searchDives method)
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_search_page.dart`

**Step 1: Extend full-text search**

In `searchDives`, extend the WHERE clause to include custom fields via a subquery:

```dart
// In the searchDives method, add to the existing .where():
t.notes.contains(query) |
t.buddy.contains(query) |
t.diveMaster.contains(query)
```

Replace with a custom SQL approach or add an OR EXISTS subquery. The simplest way: after the initial query returns results, also query dive_custom_fields:

```dart
// After existing search query, also find dives with matching custom fields
final customFieldMatches = await _db.customSelect(
  'SELECT DISTINCT cf.dive_id FROM dive_custom_fields cf '
  'WHERE cf.field_key LIKE ? OR cf.field_value LIKE ?',
  variables: [Variable('%$query%'), Variable('%$query%')],
).get();
final customFieldDiveIds = customFieldMatches
    .map((r) => r.data['dive_id'] as String)
    .toSet();

// Merge with existing results (dedup by ID)
```

**Step 2: Add filter fields to DiveFilterState**

```dart
final String? customFieldKey;
final String? customFieldValue;
```

Add to constructor, copyWith, and clear logic.

**Step 3: Add custom field filter to _buildFilterWhereClauses**

```dart
if (filter.customFieldKey != null && filter.customFieldKey!.isNotEmpty) {
  final valueClauses = <String>[];
  valueClauses.add('cf.field_key = ?');
  args.add(Variable(filter.customFieldKey!));
  if (filter.customFieldValue != null && filter.customFieldValue!.isNotEmpty) {
    valueClauses.add('cf.field_value LIKE ?');
    args.add(Variable('%${filter.customFieldValue}%'));
  }
  clauses.add(
    'EXISTS (SELECT 1 FROM dive_custom_fields cf '
    'WHERE cf.dive_id = d.id AND ${valueClauses.join(' AND ')})',
  );
}
```

**Step 4: Add UI to dive_search_page.dart**

Add a "Custom Field" filter section with a key dropdown and value text field. Place after the existing tag filter section.

**Step 5: Verify build**

Run: `flutter analyze`

**Step 6: Commit**

```
feat: integrate custom fields into search and filtering
```

---

### Task 11: CSV Export

**Files:**
- Modify: `lib/core/services/export/csv/csv_export_service.dart`

**Step 1: Extend generateDivesCsvContent**

After collecting all dives, scan for distinct custom field keys across all dives:

```dart
// Collect all distinct custom field keys
final allCustomKeys = <String>{};
for (final dive in dives) {
  for (final field in dive.customFields) {
    allCustomKeys.add(field.key);
  }
}
final sortedCustomKeys = allCustomKeys.toList()..sort();

// Add custom: prefixed headers
for (final key in sortedCustomKeys) {
  headers.add('custom:$key');
}
```

When building each row, append custom field values:

```dart
for (final key in sortedCustomKeys) {
  final field = dive.customFields.where((f) => f.key == key).firstOrNull;
  row.add(sanitizeCsvField(field?.value ?? ''));
}
```

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```
feat: include custom fields in CSV export
```

---

### Task 12: CSV Import

**Files:**
- Modify: `lib/core/services/export/csv/csv_import_service.dart`

**Step 1: Detect custom: prefixed columns during import**

In the header parsing logic, detect columns with `custom:` prefix:

```dart
if (header.startsWith('custom:')) {
  final key = header.substring(7); // Remove 'custom:' prefix
  if (value.isNotEmpty) {
    final customFields = diveData.putIfAbsent('customFields', () => <Map<String, String>>[])
        as List<Map<String, String>>;
    customFields.add({'key': key, 'value': value});
  }
}
```

**Step 2: Handle custom fields in the import wizard conversion**

When converting imported CSV data to Dive entities, map the `customFields` list to `DiveCustomField` objects.

**Step 3: Verify build**

Run: `flutter analyze`

**Step 4: Commit**

```
feat: import custom fields from CSV with custom: prefix
```

---

### Task 13: UDDF Export

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart`

**Step 1: Add applicationdata element to dive export**

In the dive element builder, after `informationafterdive`, add:

```dart
if (dive.customFields.isNotEmpty) {
  builder.element('applicationdata', nest: () {
    builder.element('submersion', nest: () {
      for (final field in dive.customFields) {
        builder.element(
          'customfield',
          attributes: {'key': field.key},
          nest: field.value,
        );
      }
    });
  });
}
```

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```
feat: include custom fields in UDDF export via applicationdata
```

---

### Task 14: UDDF Import

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_import_service.dart`

**Step 1: Parse applicationdata in dive import**

In `_parseUddfDive`, after parsing other elements, add:

```dart
final appDataElement = diveElement.findElements('applicationdata').firstOrNull;
if (appDataElement != null) {
  final submersionElement = appDataElement.findElements('submersion').firstOrNull;
  if (submersionElement != null) {
    final customFields = <Map<String, String>>[];
    for (final cfElement in submersionElement.findElements('customfield')) {
      final key = cfElement.getAttribute('key');
      final value = cfElement.innerText;
      if (key != null && key.isNotEmpty) {
        customFields.add({'key': key, 'value': value});
      }
    }
    if (customFields.isNotEmpty) {
      diveData['customFields'] = customFields;
    }
  }
}
```

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```
feat: import custom fields from UDDF applicationdata element
```

---

### Task 15: PDF Export

**Files:**
- Modify: `lib/core/services/export/pdf/pdf_export_service.dart`

**Step 1: Add custom fields to _buildPdfDiveEntry**

After the notes section (and before signatures), add:

```dart
if (dive.customFields.isNotEmpty) ...[
  pw.SizedBox(height: 8),
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: dive.customFields.map((field) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${field.key}: ',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                field.value,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList(),
  ),
],
```

**Step 2: Verify build**

Run: `flutter analyze`

**Step 3: Commit**

```
feat: include custom fields in PDF export
```

---

### Task 16: Final Verification & Format

**Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass

**Step 2: Run analysis**

Run: `flutter analyze`
Expected: No issues

**Step 3: Format code**

Run: `dart format lib/ test/`
Expected: All files formatted

**Step 4: Manual smoke test**

Run: `flutter run -d macos`
Test:
- Create a dive with 2-3 custom fields
- Verify autocomplete suggests keys on second dive
- Verify custom fields display on detail page
- Verify search finds dives by custom field value
- Export a dive to CSV and verify custom: columns
- Export to PDF and verify custom fields render
- Export to UDDF and verify applicationdata element

**Step 5: Commit any final fixes**

```
chore: final verification and formatting for custom fields
```

---

## File Summary

| Action | File |
|--------|------|
| Create | `lib/features/dive_log/domain/entities/dive_custom_field.dart` |
| Create | `lib/features/dive_log/presentation/widgets/custom_field_input_row.dart` |
| Create | `lib/features/dive_log/data/repositories/dive_custom_field_repository.dart` |
| Create | `test/features/dive_log/domain/entities/dive_custom_field_test.dart` |
| Create | `test/features/dive_log/data/repositories/dive_custom_field_repository_test.dart` |
| Modify | `lib/features/dive_log/domain/entities/dive.dart` |
| Modify | `lib/core/database/database.dart` |
| Modify | `lib/features/dive_log/data/repositories/dive_repository_impl.dart` |
| Modify | `lib/features/dive_log/presentation/providers/dive_providers.dart` |
| Modify | `lib/features/dive_log/presentation/pages/dive_edit_page.dart` |
| Modify | `lib/features/dive_log/presentation/pages/dive_detail_page.dart` |
| Modify | `lib/features/dive_log/presentation/pages/dive_search_page.dart` |
| Modify | `lib/features/dive_log/domain/models/dive_filter_state.dart` |
| Modify | `lib/core/services/export/csv/csv_export_service.dart` |
| Modify | `lib/core/services/export/csv/csv_import_service.dart` |
| Modify | `lib/core/services/export/uddf/uddf_export_service.dart` |
| Modify | `lib/core/services/export/uddf/uddf_import_service.dart` |
| Modify | `lib/core/services/export/pdf/pdf_export_service.dart` |
| Modify | `lib/l10n/app_en.arb` (+ 9 other locale ARB files) |
