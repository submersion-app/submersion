# Dive Custom Fields Design

> **Date:** 2026-02-13
> **Status:** Approved
> **Approach:** Separate `DiveCustomFields` child table (Approach 1)

## Overview

Add optional freeform key:value entries to dive log entries. Divers can attach arbitrary metadata to any dive (e.g., `camera_settings: f/8 ISO400`, `instructor_feedback: excellent buoyancy`). Previously-used keys are offered as autocomplete suggestions. Custom fields are searchable, filterable, and included in all export/import formats.

## Requirements

- Freeform user-defined keys and values (no predefined pick-lists)
- Autocomplete suggestions for previously-used keys per diver
- Dedicated "Custom Fields" section at the bottom of dive edit and detail pages
- Full export support: CSV, PDF, UDDF
- Full import support: CSV (custom: prefix), UDDF (applicationdata element)
- Searchable via full-text search and Advanced Search filters

## Database Schema

### New Table: `dive_custom_fields` (schema v34)

```sql
CREATE TABLE dive_custom_fields (
  id TEXT NOT NULL PRIMARY KEY,
  dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
  field_key TEXT NOT NULL,
  field_value TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_dive_custom_fields_dive_id ON dive_custom_fields(dive_id);
CREATE INDEX idx_dive_custom_fields_key ON dive_custom_fields(field_key);
```

### Drift Table Definition

```dart
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

## Domain Entity

```dart
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

  DiveCustomField copyWith({String? id, String? key, String? value, int? sortOrder});

  @override
  List<Object?> get props => [id, key, value, sortOrder];
}
```

The `Dive` entity gains: `final List<DiveCustomField> customFields;` (defaults to `const []`).

## Repository

### DiveCustomFieldRepository

```dart
class DiveCustomFieldRepository {
  final AppDatabase _db;

  Future<DiveCustomField> createField(String diveId, String key, String value, int sortOrder);
  Future<void> updateField(DiveCustomField field);
  Future<void> deleteField(String fieldId);
  Future<List<DiveCustomField>> getFieldsForDive(String diveId);
  Future<void> replaceFieldsForDive(String diveId, List<DiveCustomField> fields);
  Future<List<String>> getDistinctKeysForDiver(String diverId);
  Future<List<String>> findDiveIdsWithKey(String diverId, String key);
  Future<List<String>> findDiveIdsWithKeyValue(String diverId, String key, String value);
}
```

### DiveRepository Integration

- **Single load** (`getDiveById`): Query custom fields and attach to Dive
- **Batch load** (`getAllDives`): Preload via `WHERE dive_id IN (...)`, group by diveId (same pattern as tanks, weights, tags)

### Riverpod Providers

```dart
final diveCustomFieldRepositoryProvider = Provider<DiveCustomFieldRepository>(...);

final customFieldKeySuggestionsProvider = FutureProvider.family<List<String>, String>(
  (ref, diverId) => ref.read(diveCustomFieldRepositoryProvider).getDistinctKeysForDiver(diverId),
);
```

## UI Design

### Dive Edit Page

- "Custom Fields" section at the bottom of the form
- "+ Add Field" button in section header
- Each entry: two text fields (Key ~40% width, Value ~60%) + delete icon
- Key field uses `Autocomplete` widget with suggestions from `customFieldKeySuggestionsProvider`
- Value field is a plain `TextFormField`
- Rows are reorderable via drag handle for `sortOrder`
- When empty: just the "+ Add Field" button

### Dive Detail Page

- "Custom Fields" section at bottom, hidden when empty
- Renders as key: value list inside a Card
- Keys in slightly bolder/dimmer style, values in normal text

## Search Integration

- **Full-text search**: Extend dive search query with LEFT JOIN on `dive_custom_fields` to search `field_key` and `field_value`
- **Advanced Search**: New optional "Custom Field" filter with key dropdown (from `getDistinctKeysForDiver`) and value text field

## Export/Import

### CSV Export

- Custom fields as additional columns with `custom:` prefix (e.g., `custom:camera_settings`)
- Full set of distinct keys collected across all exported dives
- Empty cells for dives missing a particular key

### CSV Import

- Columns with `custom:` prefix are imported as custom fields
- Universal import wizard field mapping gets "Custom Field" target option

### PDF Export

- Key:value list after Notes section, only when custom fields exist

### UDDF Export/Import

- Uses UDDF `<applicationdata>` extension point:
  ```xml
  <applicationdata>
    <submersion>
      <customfield key="camera_settings">f/8 ISO400</customfield>
    </submersion>
  </applicationdata>
  ```

## Alternatives Considered

1. **JSON column on Dives table** -- Rejected: poor searchability, doesn't follow codebase patterns, messy import/export
2. **Reuse Settings table** -- Rejected: abuses table purpose, no CASCADE delete, breaks domain model
