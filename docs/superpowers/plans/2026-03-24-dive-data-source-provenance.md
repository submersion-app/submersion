# Dive Data Source Provenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track and display the origin of every dive's data, from manual entry to multi-computer consolidation, with field-level attribution badges and tap-to-view source switching.

**Architecture:** Extend the existing `DiveComputerData`/`DiveComputerReading` infrastructure with renames (to `DiveDataSources`/`DiveDataSource`), two new columns (`source_file_name`, `source_file_format`), and a computed attribution service. The UI replaces the conditional `DiveComputersSection` with an always-visible `DataSourcesSection`.

**Tech Stack:** Flutter 3.x, Drift ORM (SQLite), Riverpod, Material 3, go_router

**Spec:** `docs/superpowers/specs/2026-03-24-dive-data-source-provenance-design.md`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/features/dive_log/domain/entities/dive_data_source.dart` | Renamed entity (from `dive_computer_reading.dart`) + 2 new fields |
| `lib/features/dive_log/domain/services/field_attribution_service.dart` | Computed field-to-source mapping logic |
| `lib/features/dive_log/presentation/widgets/data_sources_section.dart` | Rewritten widget (from `dive_computers_section.dart`) — always visible, all scenarios |
| `lib/features/dive_log/presentation/widgets/field_attribution_badge.dart` | Inline source badge widget |
| `test/features/dive_log/domain/entities/dive_data_source_test.dart` | Entity tests (renamed) |
| `test/features/dive_log/domain/services/field_attribution_service_test.dart` | Attribution logic tests |
| `test/features/dive_log/presentation/widgets/data_sources_section_test.dart` | Widget tests for all scenarios |

### Modified Files

| File | Changes |
|------|---------|
| `lib/core/database/database.dart` | Rename `DiveComputerData` class → `DiveDataSources`, add 2 columns, add migration v54 |
| `lib/features/dive_log/domain/entities/dive.dart` | `wearableSource` → `importSource`, `wearableId` → `importId` |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Rename methods, update type refs, handle new columns |
| `lib/features/dive_log/presentation/providers/dive_providers.dart` | Rename providers |
| `lib/features/dive_log/presentation/pages/dive_detail_page.dart` | Wire new `DataSourcesSection`, tap-to-view state, badges |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Update `DiveComputerReading` → `DiveDataSource`, provider renames |
| `lib/features/universal_import/presentation/providers/universal_import_providers.dart` | Update `DiveComputerDataCompanion` → `DiveDataSourcesCompanion` |
| `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart` | Update `DiveComputerDataCompanion` → `DiveDataSourcesCompanion` |
| `lib/features/dive_import/domain/entities/imported_dive.dart` | Add `sourceFileName`, `sourceFileFormat` |
| `lib/features/dive_import/domain/services/imported_dive_converter.dart` | `wearableSource` → `importSource`, `wearableId` → `importId` |
| `lib/features/dive_import/data/services/uddf_parser_service.dart` | Return filename from parse |
| `lib/features/dive_import/data/services/fit_parser_service.dart` | Propagate filename/format |
| `lib/features/dive_import/data/services/healthkit_service.dart` | Set `sourceFileFormat: 'healthkit'` |
| `lib/features/dive_import/presentation/providers/uddf_import_providers.dart` | Pass filename through pipeline |
| `lib/features/settings/presentation/providers/settings_providers.dart` | Add `showDataSourceBadges` setting |
| Various test files | Update imports, type references, method names |

### Deleted Files

| File | Reason |
|------|--------|
| `lib/features/dive_log/domain/entities/dive_computer_reading.dart` | Replaced by `dive_data_source.dart` |
| `lib/features/dive_log/presentation/widgets/dive_computers_section.dart` | Replaced by `data_sources_section.dart` |
| `test/features/dive_log/domain/entities/dive_computer_reading_test.dart` | Replaced by `dive_data_source_test.dart` |

---

## Task 1: Rename Domain Entity (DiveComputerReading → DiveDataSource)

**Files:**
- Create: `lib/features/dive_log/domain/entities/dive_data_source.dart`
- Delete: `lib/features/dive_log/domain/entities/dive_computer_reading.dart`
- Create: `test/features/dive_log/domain/entities/dive_data_source_test.dart`
- Delete: `test/features/dive_log/domain/entities/dive_computer_reading_test.dart`

- [ ] **Step 1: Create the new DiveDataSource entity file**

Copy `lib/features/dive_log/domain/entities/dive_computer_reading.dart` to `lib/features/dive_log/domain/entities/dive_data_source.dart`. Apply these changes:

```dart
import 'package:equatable/equatable.dart';

class DiveDataSource extends Equatable {
  final String id;
  final String diveId;
  final String? computerId;
  final bool isPrimary;
  final String? computerModel;
  final String? computerSerial;
  final String? sourceFormat;
  final String? sourceFileName;     // NEW
  final String? sourceFileFormat;   // NEW
  final double? maxDepth;
  final double? avgDepth;
  final int? duration;
  final double? waterTemp;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final double? maxAscentRate;
  final double? maxDescentRate;
  final int? surfaceInterval;
  final double? cns;
  final double? otu;
  final String? decoAlgorithm;
  final int? gradientFactorLow;
  final int? gradientFactorHigh;
  final DateTime importedAt;
  final DateTime createdAt;

  const DiveDataSource({
    required this.id,
    required this.diveId,
    this.computerId,
    required this.isPrimary,
    this.computerModel,
    this.computerSerial,
    this.sourceFormat,
    this.sourceFileName,
    this.sourceFileFormat,
    this.maxDepth,
    this.avgDepth,
    this.duration,
    this.waterTemp,
    this.entryTime,
    this.exitTime,
    this.maxAscentRate,
    this.maxDescentRate,
    this.surfaceInterval,
    this.cns,
    this.otu,
    this.decoAlgorithm,
    this.gradientFactorLow,
    this.gradientFactorHigh,
    required this.importedAt,
    required this.createdAt,
  });

  /// Display name for the source (model name, or "Manual Entry", or "Unknown").
  String get displayName => computerModel ?? 'Unknown Source';

  DiveDataSource copyWith({
    String? id,
    String? diveId,
    String? computerId,
    bool? isPrimary,
    String? computerModel,
    String? computerSerial,
    String? sourceFormat,
    String? sourceFileName,
    String? sourceFileFormat,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
    DateTime? entryTime,
    DateTime? exitTime,
    double? maxAscentRate,
    double? maxDescentRate,
    int? surfaceInterval,
    double? cns,
    double? otu,
    String? decoAlgorithm,
    int? gradientFactorLow,
    int? gradientFactorHigh,
    DateTime? importedAt,
    DateTime? createdAt,
  }) {
    return DiveDataSource(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      computerId: computerId ?? this.computerId,
      isPrimary: isPrimary ?? this.isPrimary,
      computerModel: computerModel ?? this.computerModel,
      computerSerial: computerSerial ?? this.computerSerial,
      sourceFormat: sourceFormat ?? this.sourceFormat,
      sourceFileName: sourceFileName ?? this.sourceFileName,
      sourceFileFormat: sourceFileFormat ?? this.sourceFileFormat,
      maxDepth: maxDepth ?? this.maxDepth,
      avgDepth: avgDepth ?? this.avgDepth,
      duration: duration ?? this.duration,
      waterTemp: waterTemp ?? this.waterTemp,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      maxAscentRate: maxAscentRate ?? this.maxAscentRate,
      maxDescentRate: maxDescentRate ?? this.maxDescentRate,
      surfaceInterval: surfaceInterval ?? this.surfaceInterval,
      cns: cns ?? this.cns,
      otu: otu ?? this.otu,
      decoAlgorithm: decoAlgorithm ?? this.decoAlgorithm,
      gradientFactorLow: gradientFactorLow ?? this.gradientFactorLow,
      gradientFactorHigh: gradientFactorHigh ?? this.gradientFactorHigh,
      importedAt: importedAt ?? this.importedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id, diveId, computerId, isPrimary,
    computerModel, computerSerial, sourceFormat,
    sourceFileName, sourceFileFormat,
    maxDepth, avgDepth, duration, waterTemp,
    entryTime, exitTime,
    maxAscentRate, maxDescentRate,
    surfaceInterval, cns, otu,
    decoAlgorithm, gradientFactorLow, gradientFactorHigh,
    importedAt, createdAt,
  ];
}
```

- [ ] **Step 2: Create the renamed test file**

Copy `test/features/dive_log/domain/entities/dive_computer_reading_test.dart` to `test/features/dive_log/domain/entities/dive_data_source_test.dart`. Update all `DiveComputerReading` references to `DiveDataSource`. Add tests for the two new fields:

```dart
test('includes sourceFileName and sourceFileFormat in equality', () {
  final a = DiveDataSource(
    id: '1', diveId: 'd1', isPrimary: true,
    sourceFileName: 'dive.uddf', sourceFileFormat: 'uddf',
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final b = a.copyWith(sourceFileName: 'other.fit');
  expect(a, isNot(equals(b)));
});

test('copyWith preserves new fields when not overridden', () {
  final source = DiveDataSource(
    id: '1', diveId: 'd1', isPrimary: true,
    sourceFileName: 'dive.uddf', sourceFileFormat: 'uddf',
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final copy = source.copyWith(isPrimary: false);
  expect(copy.sourceFileName, 'dive.uddf');
  expect(copy.sourceFileFormat, 'uddf');
});
```

- [ ] **Step 3: Delete the old entity file**

```bash
rm lib/features/dive_log/domain/entities/dive_computer_reading.dart
rm test/features/dive_log/domain/entities/dive_computer_reading_test.dart
```

- [ ] **Step 4: Run the entity test**

Run: `flutter test test/features/dive_log/domain/entities/dive_data_source_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename DiveComputerReading to DiveDataSource, add sourceFileName/sourceFileFormat"
```

---

## Task 2: Rename Drift Table Class + Dive Entity Fields

**Files:**
- Modify: `lib/core/database/database.dart` (lines 218-222, 920-949, 1235)
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (lines 108-110, 196-197, 510-511, 595-596, 683-684)

- [ ] **Step 1: Rename Drift table class in database.dart**

In `lib/core/database/database.dart`:

1. Rename class `DiveComputerData` → `DiveDataSources` (line 920).
2. Add two new columns inside the class:
   ```dart
   TextColumn get sourceFileName => text().nullable()();
   TextColumn get sourceFileFormat => text().nullable()();
   ```
3. Rename `wearableSource` → `importSource` (line 219).
4. Rename `wearableId` → `importId` (line 221).
5. Update comments on lines 218 and 220 to remove "Wearable integration (v2.0)" phrasing.
6. Update the `@DriftDatabase` tables list reference from `DiveComputerData` to `DiveDataSources` (line ~1206 area).

- [ ] **Step 2: Rename fields on Dive entity**

In `lib/features/dive_log/domain/entities/dive.dart`:

1. Rename `wearableSource` → `importSource` (field declaration, constructor, copyWith, props).
2. Rename `wearableId` → `importId` (field declaration, constructor, copyWith, props).
3. Update comments from "Wearable integration" to "Import source tracking".

Search for all occurrences in the file: lines 108-110, 196-197, 510-511, 595-596, 683-684.

- [ ] **Step 3: Run code generation**

```bash
dart run build_runner build --delete-conflicting-outputs
```

This regenerates `database.g.dart` with new types: `DiveDataSourcesData`, `DiveDataSourcesCompanion`, and updated `Dive` companion with `importSource`/`importId`.

Expected: codegen succeeds (compilation errors in dependent files are expected at this point).

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: rename Drift DiveComputerData to DiveDataSources, Dive wearable fields to import fields"
```

---

## Task 3: Update Repository (Rename Methods + Type References)

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`

This is the largest file change. Every reference to the old names must be updated.

- [ ] **Step 1: Update all type references**

Replace throughout `dive_repository_impl.dart`:
- `DiveComputerReading` → `DiveDataSource` (import and all usages)
- `DiveComputerDataCompanion` → `DiveDataSourcesCompanion` (Drift-generated)
- `DiveComputerDataData` → `DiveDataSourcesData` (Drift-generated)
- `_db.diveComputerData` → `_db.diveDataSources` (table accessor)
- `wearableSource` → `importSource` (in companion constructors and row mappings)
- `wearableId` → `importId` (in companion constructors and row mappings)
- `_db.dives.wearableId` → `_db.dives.importId` (in queries like `getWearableIds`)

Key locations:
- Lines 606-607: `wearableSource`/`wearableId` in insert companion
- Lines 819-820: `wearableSource`/`wearableId` in update companion
- Lines 2082-2083, 2454-2455: `wearableSource`/`wearableId` in row mapping to Dive
- Lines 2468-2477: `getWearableIds()` method using `_db.dives.wearableId`
- Lines 3250-3268: `getComputerReadings()` method
- Lines 3252, 3293, 3305, 3320, etc.: `_db.diveComputerData` table references
- Lines 3338, 3397, 3463: `DiveComputerDataCompanion` constructors
- Lines 3746-3771: `_mapRowToReading()` method

- [ ] **Step 2: Rename methods**

- `getComputerReadings()` → `getDataSources()` (line 3250)
- `hasMultipleComputers()` → `hasMultipleDataSources()` (line 3271)
- `backfillPrimaryComputerReading()` → `backfillPrimaryDataSource()` (line 3316)
- `setPrimaryComputer()` → `setPrimaryDataSource()` (line 3674)
- `_mapRowToReading()` → `_mapRowToDataSource()` (line 3746)
- `getWearableIds()` → `getImportIds()` (line 2468)

Also update all internal call sites of these methods within the same file:
- Lines 3403, 3449: calls to `getComputerReadings` → `getDataSources`
- Lines 3405, 3451: calls to `backfillPrimaryComputerReading` → `backfillPrimaryDataSource`
- Line 3639: call to `setPrimaryComputer` → `setPrimaryDataSource`

- [ ] **Step 3: Update the row-to-entity mapping to include new fields**

In `_mapRowToDataSource()` (renamed from `_mapRowToReading`), add:

```dart
sourceFileName: row.sourceFileName,
sourceFileFormat: row.sourceFileFormat,
```

- [ ] **Step 4: Update import adapter and universal import providers**

In `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart`:

- Replace `DiveComputerDataCompanion` → `DiveDataSourcesCompanion`

In `lib/features/universal_import/presentation/providers/universal_import_providers.dart`:

- Replace `DiveComputerDataCompanion` → `DiveDataSourcesCompanion`

In `lib/features/dive_log/presentation/pages/dive_edit_page.dart`:

- Replace `DiveComputerReading` → `DiveDataSource` (import and type references)
- Replace `diveComputerReadingsProvider` → `diveDataSourcesProvider`

- [ ] **Step 5: Update the SQL string in hasMultipleDataSources**

Change the raw SQL from `'dive_computer_data'` to `'dive_data_sources'` (line ~3275):

```dart
'SELECT COUNT(*) as cnt FROM dive_data_sources WHERE dive_id = ?'
```

- [ ] **Step 6: Verify compilation**

```bash
flutter analyze
```

Expected: May still have errors in providers/UI files (fixed in next tasks).

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
  lib/features/import_wizard/data/adapters/dive_computer_adapter.dart \
  lib/features/universal_import/presentation/providers/universal_import_providers.dart \
  lib/features/dive_log/presentation/pages/dive_edit_page.dart
git commit -m "refactor: rename repository methods and types for data source provenance"
```

---

## Task 4: Update Providers

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart` (lines 794-812)

- [ ] **Step 1: Rename providers**

In `lib/features/dive_log/presentation/providers/dive_providers.dart`:

1. Update import from `dive_computer_reading.dart` to `dive_data_source.dart`.
2. Rename `diveComputerReadingsProvider` → `diveDataSourcesProvider`:
   ```dart
   final diveDataSourcesProvider =
       FutureProvider.family<List<DiveDataSource>, String>((ref, diveId) async {
     final repository = ref.watch(diveRepositoryProvider);
     return repository.getDataSources(diveId);
   });
   ```
3. Rename `isMultiComputerDiveProvider` → `isMultiDataSourceDiveProvider`:
   ```dart
   final isMultiDataSourceDiveProvider =
       FutureProvider.family<bool, String>((ref, diveId) async {
     final repository = ref.watch(diveRepositoryProvider);
     return repository.hasMultipleDataSources(diveId);
   });
   ```

- [ ] **Step 2: Verify compilation**

```bash
flutter analyze
```

Expected: Errors only in UI files that reference the old provider names (fixed in later tasks).

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/providers/dive_providers.dart
git commit -m "refactor: rename dive computer providers to data source providers"
```

---

## Task 5: Update Import Pipeline (ImportedDive + Converter + Rename Propagation)

**Files:**
- Modify: `lib/features/dive_import/domain/entities/imported_dive.dart`
- Modify: `lib/features/dive_import/domain/services/imported_dive_converter.dart`
- Modify: `lib/features/dive_import/data/services/uddf_parser_service.dart`
- Modify: `lib/features/dive_import/data/services/fit_parser_service.dart`
- Modify: `lib/features/dive_import/data/services/healthkit_service.dart`
- Modify: `lib/features/dive_import/presentation/providers/uddf_import_providers.dart`
- Modify: `lib/features/dive_import/presentation/providers/dive_import_providers.dart`
- Modify: `lib/features/dive_import/presentation/widgets/imported_dive_card.dart`
- Test: `test/features/dive_import/domain/services/imported_dive_converter_test.dart`

- [ ] **Step 1: Write failing test for new ImportedDive fields**

In `test/features/dive_import/domain/services/imported_dive_converter_test.dart`, add a test:

```dart
test('converter maps sourceFileName and sourceFileFormat to Dive', () {
  final importedDive = ImportedDive(
    sourceId: 'abc123',
    source: ImportSource.suunto,
    startTime: DateTime(2026, 3, 15, 10, 0),
    endTime: DateTime(2026, 3, 15, 11, 0),
    maxDepth: 28.3,
    profile: [],
    sourceFileName: 'Suunto_Export.uddf',
    sourceFileFormat: 'uddf',
  );
  final dive = const ImportedDiveConverter().convert(importedDive);
  expect(dive.importSource, 'suunto');
  expect(dive.importId, 'abc123');
  // sourceFileName/sourceFileFormat live on DiveDataSource, not Dive,
  // so they are not mapped here. Verify the Dive fields renamed correctly.
});
```

Run: `flutter test test/features/dive_import/domain/services/imported_dive_converter_test.dart`
Expected: FAIL (fields don't exist yet on ImportedDive)

- [ ] **Step 2: Add fields to ImportedDive entity**

In `lib/features/dive_import/domain/entities/imported_dive.dart`, add to `ImportedDive`:

```dart
final String? sourceFileName;
final String? sourceFileFormat;
```

Add to constructor (nullable, after `profile`):
```dart
this.sourceFileName,
this.sourceFileFormat,
```

Add to `props` list.

- [ ] **Step 3: Update ImportedDiveConverter**

In `lib/features/dive_import/domain/services/imported_dive_converter.dart`:

1. Rename `wearableSource:` → `importSource:` (line 40).
2. Rename `wearableId:` → `importId:` (line 41).
3. Update the doc comment on line 21.

- [ ] **Step 4: Update import providers for rename propagation**

In `lib/features/dive_import/presentation/providers/dive_import_providers.dart`:

- Update the method call `repository.getWearableIds()` → `repository.getImportIds()` (line ~247). This is production code, not a comment.
- Update comments referencing `wearableId` to `importId` (lines 235, 292).

In `lib/features/dive_import/presentation/widgets/imported_dive_card.dart`:

- Update any comments referencing `wearable_id` (line 261).

- [ ] **Step 5: Pass filename through UDDF parser**

In `lib/features/dive_import/data/services/uddf_parser_service.dart`, the `parseFile()` method receives `filePath`. Extract the filename and return it alongside the parse result. The result type (`UddfImportResult`) may need a `fileName` field, or the caller can extract it from the path. Check the actual return type and add appropriately.

In `lib/features/dive_import/presentation/providers/uddf_import_providers.dart` (line ~268-277), after extracting `filePath`, set the filename on the `ImportedDive` objects:

```dart
final fileName = filePath.split('/').last;
final extension = fileName.split('.').last.toLowerCase();
// Set on each ImportedDive in the result
```

- [ ] **Step 6: Pass filename through FIT parser**

In `lib/features/dive_import/data/services/fit_parser_service.dart`, the `parseFitFile()` method already has a `fileName` parameter (line 29). Set `sourceFileName` and `sourceFileFormat: 'fit'` on the returned `ImportedDive`.

- [ ] **Step 7: Set format for HealthKit imports**

In `lib/features/dive_import/data/services/healthkit_service.dart`, when constructing `ImportedDive` (line ~154), add:
```dart
sourceFileName: null,
sourceFileFormat: 'healthkit',
```

- [ ] **Step 8: Run the test**

Run: `flutter test test/features/dive_import/domain/services/imported_dive_converter_test.dart`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add sourceFileName/sourceFileFormat to ImportedDive, rename wearable fields in converter"
```

---

## Task 6: Database Migration

**Files:**
- Modify: `lib/core/database/database.dart` (migration section, lines ~2404-2436, and `currentSchemaVersion` line 1235)

- [ ] **Step 1: Bump schema version**

Change `currentSchemaVersion` from `53` to `54` (line 1235).

**Note:** Verify the actual current version before implementing — it may have advanced since spec authorship. Use the next available version number.

- [ ] **Step 2: Add migration block**

Add a new `if (from < 54)` block after the existing `if (from < 53)` block (before `beforeOpen`):

```dart
if (from < 54) {
  // Rename dive_computer_data table to dive_data_sources
  await customStatement(
    'ALTER TABLE dive_computer_data RENAME TO dive_data_sources',
  );
  // Add new provenance columns
  await customStatement(
    'ALTER TABLE dive_data_sources ADD COLUMN source_file_name TEXT',
  );
  await customStatement(
    'ALTER TABLE dive_data_sources ADD COLUMN source_file_format TEXT',
  );
  // Rename wearable columns on dives table
  await customStatement(
    'ALTER TABLE dives RENAME COLUMN wearable_source TO import_source',
  );
  await customStatement(
    'ALTER TABLE dives RENAME COLUMN wearable_id TO import_id',
  );
  // Recreate index with new table name
  await customStatement(
    'DROP INDEX IF EXISTS idx_dive_computer_data_dive_id',
  );
  await customStatement('''
    CREATE INDEX IF NOT EXISTS idx_dive_data_sources_dive_id
    ON dive_data_sources(dive_id)
  ''');
}
```

- [ ] **Step 3: Run codegen**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 4: Run all tests to verify migration doesn't break existing functionality**

```bash
flutter test
```

Expected: Existing tests should pass (after accounting for renames in test files — see Task 7).

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/database.dart
git commit -m "feat: add schema migration v54 — rename tables/columns, add provenance fields"
```

---

## Task 7: Update All Test Files for Renames

**Files:**
- Modify: `test/features/dive_log/data/repositories/dive_computer_data_repository_test.dart`
- Modify: `test/features/dive_log/data/repositories/dive_consolidation_test.dart`
- Modify: `test/features/dive_log/integration/multi_computer_integration_test.dart`
- Modify: `test/features/dive_import/domain/services/imported_dive_converter_test.dart`
- Modify: `test/features/dive_import/presentation/providers/dive_import_notifier_test.dart`
- Modify: `test/features/import_wizard/data/adapters/dive_computer_adapter_test.dart`
- Regenerate: All `.mocks.dart` files

- [ ] **Step 1: Safety grep for any remaining old name references**

Before making changes, grep the full codebase for all old names to catch any files not listed above:

```bash
grep -r "DiveComputerReading\|DiveComputerData\|diveComputerData\|wearableSource\|wearableId\|getComputerReadings\|hasMultipleComputers\|backfillPrimaryComputerReading\|diveComputerReadingsProvider\|isMultiComputerDiveProvider" lib/ test/ --include="*.dart" -l
```

Any files found that are NOT already handled in Tasks 1-6 or listed below must also be updated. Add them to this task before proceeding.

- [ ] **Step 2: Update test file references**

In all test files listed above (plus any discovered in Step 1):

1. Update imports from `dive_computer_reading.dart` to `dive_data_source.dart`.
2. Replace `DiveComputerReading` → `DiveDataSource` in type references and constructors.
3. Replace `DiveComputerDataCompanion` → `DiveDataSourcesCompanion`.
4. Replace `getComputerReadings` → `getDataSources` in method calls/verifications.
5. Replace `hasMultipleComputers` → `hasMultipleDataSources`.
6. Replace `backfillPrimaryComputerReading` → `backfillPrimaryDataSource`.
7. Replace `setPrimaryComputer` → `setPrimaryDataSource` (only in dive repository context, NOT in `SelectedComputerNotifier` which is about physical computer selection).
8. Replace `wearableSource` → `importSource`, `wearableId` → `importId` in test data.
9. Replace `diveComputerReadingsProvider` → `diveDataSourcesProvider`.
10. Replace `isMultiComputerDiveProvider` → `isMultiDataSourceDiveProvider`.

- [ ] **Step 3: Regenerate mock files**

```bash
dart run build_runner build --delete-conflicting-outputs
```

This regenerates all `.mocks.dart` files to use the new type names.

- [ ] **Step 4: Run full test suite**

```bash
flutter test
```

Expected: ALL PASS

- [ ] **Step 5: Run analyzer**

```bash
flutter analyze
```

Expected: No errors (warnings about unused imports in old UI files are OK — fixed in Task 8).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: update all tests for data source rename"
```

---

## Task 8: Add Settings Toggle

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Test: Existing settings tests (verify new key)

- [ ] **Step 1: Add settings key**

In `lib/features/settings/presentation/providers/settings_providers.dart`, add to `SettingsKeys`:

```dart
static const String showDataSourceBadges = 'show_data_source_badges';
```

- [ ] **Step 2: Add field to AppSettings**

Add to the `AppSettings` class:

```dart
/// Show field-level data source attribution badges on dive details
final bool showDataSourceBadges;
```

Add to the constructor with default `true`.

- [ ] **Step 3: Wire up loading and saving**

In the `SettingsNotifier` (or equivalent provider), add:
- Load: `prefs.getBool(SettingsKeys.showDataSourceBadges) ?? true`
- Save: `prefs.setBool(SettingsKeys.showDataSourceBadges, value)`

- [ ] **Step 4: Add toggle to settings UI**

Find the appropriate settings page section (Display or Dive Details) and add a `SwitchListTile`:

```dart
SwitchListTile(
  title: const Text('Show data source badges'),
  subtitle: const Text('Display source attribution on dive metrics'),
  value: settings.showDataSourceBadges,
  onChanged: (value) => notifier.setShowDataSourceBadges(value),
),
```

- [ ] **Step 5: Run tests**

```bash
flutter test
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add showDataSourceBadges setting toggle"
```

---

## Task 9: Build DataSourcesSection Widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/data_sources_section.dart`
- Delete: `lib/features/dive_log/presentation/widgets/dive_computers_section.dart`
- Create: `test/features/dive_log/presentation/widgets/data_sources_section_test.dart`

- [ ] **Step 1: Write failing widget test — manual entry scenario**

```dart
testWidgets('shows Manual Entry card when no data sources exist', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DataSourcesSection(
          dataSources: const [],
          diveCreatedAt: DateTime(2026, 3, 15),
          diveId: 'dive1',
          units: mockUnits,
        ),
      ),
    ),
  );

  expect(find.text('Data Source'), findsOneWidget);
  expect(find.text('Manual Entry'), findsOneWidget);
});
```

Run: `flutter test test/features/dive_log/presentation/widgets/data_sources_section_test.dart`
Expected: FAIL (class doesn't exist)

- [ ] **Step 2: Write failing test — single imported source**

```dart
testWidgets('shows single source card with details', (tester) async {
  final source = DiveDataSource(
    id: '1', diveId: 'd1', isPrimary: true,
    computerModel: 'Suunto EON Core', computerSerial: 'SN-483921',
    sourceFormat: 'suunto', sourceFileFormat: 'uddf',
    sourceFileName: 'Suunto_DM5_Export.uddf',
    maxDepth: 28.3, duration: 2535,
    importedAt: DateTime(2026, 3, 16), createdAt: DateTime(2026, 3, 16),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DataSourcesSection(
          dataSources: [source],
          diveCreatedAt: DateTime(2026, 3, 15),
          diveId: 'd1',
          units: mockUnits,
        ),
      ),
    ),
  );

  expect(find.text('Data Source'), findsOneWidget);
  expect(find.text('Suunto EON Core'), findsOneWidget);
  expect(find.text('Suunto_DM5_Export.uddf'), findsOneWidget);
});
```

- [ ] **Step 3: Write failing test — multi-source with primary/secondary badges**

```dart
testWidgets('shows Primary and Secondary badges for multi-source dive', (tester) async {
  final primary = DiveDataSource(
    id: '1', diveId: 'd1', isPrimary: true,
    computerModel: 'Shearwater Perdix',
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final secondary = DiveDataSource(
    id: '2', diveId: 'd1', isPrimary: false,
    computerModel: 'Apple Watch Ultra 2',
    sourceFileFormat: 'healthkit',
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DataSourcesSection(
          dataSources: [primary, secondary],
          diveCreatedAt: DateTime(2026, 3, 15),
          diveId: 'd1',
          units: mockUnits,
        ),
      ),
    ),
  );

  expect(find.text('Data Sources'), findsOneWidget); // plural
  expect(find.text('Primary'), findsOneWidget);
  expect(find.text('Secondary'), findsOneWidget);
});
```

- [ ] **Step 4: Implement DataSourcesSection widget**

Create `lib/features/dive_log/presentation/widgets/data_sources_section.dart`.

Key design points:
- **Always visible** (no `length < 2` guard like the old widget).
- Header: "Data Source" (singular) when 0-1 sources, "Data Sources" (plural) when 2+.
- When `dataSources` is empty: render manual entry card with `diveCreatedAt`.
- Each source card shows: icon, model name, badge (Primary/Secondary/Viewing), serial, firmware, entry/exit times, import date, format, filename, metrics row.
- Overflow menu with "Set as primary" (non-primary only) and "Unlink".
- Uses `CollapsibleSection` wrapper for consistency with other detail sections.
- Accepts callbacks: `onSetPrimary`, `onUnlink`, `onTapSource` (for tap-to-view).

- [ ] **Step 5: Delete old widget file**

```bash
rm lib/features/dive_log/presentation/widgets/dive_computers_section.dart
```

- [ ] **Step 6: Run widget tests**

```bash
flutter test test/features/dive_log/presentation/widgets/data_sources_section_test.dart
```

Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: build DataSourcesSection widget replacing DiveComputersSection"
```

---

## Task 10: Build Computed Attribution Service

**Files:**
- Create: `lib/features/dive_log/domain/services/field_attribution_service.dart`
- Create: `test/features/dive_log/domain/services/field_attribution_service_test.dart`

- [ ] **Step 1: Write failing test — single source returns empty map**

```dart
test('returns empty attribution for single-source dive', () {
  final source = DiveDataSource(
    id: '1', diveId: 'd1', isPrimary: true,
    computerModel: 'Perdix', maxDepth: 28.3,
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final result = FieldAttributionService.computeAttribution([source]);
  expect(result, isEmpty); // no badges for single source
});
```

Run: `flutter test test/features/dive_log/domain/services/field_attribution_service_test.dart`
Expected: FAIL

- [ ] **Step 2: Write failing test — multi-source returns per-field attribution**

```dart
test('attributes fields to primary source by default', () {
  final primary = DiveDataSource(
    id: '1', diveId: 'd1', isPrimary: true,
    computerModel: 'Perdix', maxDepth: 28.3, duration: 2535, waterTemp: 24,
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final secondary = DiveDataSource(
    id: '2', diveId: 'd1', isPrimary: false,
    computerModel: 'Apple Watch', maxDepth: 27.9, duration: 2518,
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final result = FieldAttributionService.computeAttribution(
    [primary, secondary],
  );
  expect(result['maxDepth'], 'Perdix');
  expect(result['duration'], 'Perdix');
});
```

- [ ] **Step 3: Write failing test — best-available heart rate**

```dart
test('attributes heart rate to source with HR data', () {
  final primary = DiveDataSource(
    id: '1', diveId: 'd1', isPrimary: true,
    computerModel: 'Perdix', sourceFormat: 'suunto',
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final secondary = DiveDataSource(
    id: '2', diveId: 'd1', isPrimary: false,
    computerModel: 'Apple Watch', sourceFormat: 'appleWatch',
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final result = FieldAttributionService.computeAttribution(
    [primary, secondary],
  );
  expect(result['heartRate'], 'Apple Watch');
});
```

- [ ] **Step 4: Write failing test — viewed source overrides attribution**

```dart
test('computeAttribution with viewedSourceId returns viewed source names', () {
  final primary = DiveDataSource(
    id: '1', diveId: 'd1', isPrimary: true,
    computerModel: 'Perdix', maxDepth: 28.3,
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final secondary = DiveDataSource(
    id: '2', diveId: 'd1', isPrimary: false,
    computerModel: 'Apple Watch', maxDepth: 27.9,
    importedAt: DateTime(2026), createdAt: DateTime(2026),
  );
  final result = FieldAttributionService.computeAttribution(
    [primary, secondary],
    viewedSourceId: '2',
  );
  expect(result['maxDepth'], 'Apple Watch');
});
```

- [ ] **Step 5: Implement FieldAttributionService**

Create `lib/features/dive_log/domain/services/field_attribution_service.dart`:

```dart
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';

/// Computes field-level attribution for multi-source dives.
///
/// Returns a Map<String, String> where keys are field names (e.g., 'maxDepth')
/// and values are the display name of the source that provided the value.
/// Returns empty map for single-source dives (badges not shown).
class FieldAttributionService {
  /// HR-capable source formats (wearables with heart rate sensors).
  static const _hrCapableSources = {'appleWatch', 'garmin'};

  /// GPS-capable source formats.
  static const _gpsCapableSources = {'appleWatch', 'garmin'};

  static Map<String, String> computeAttribution(
    List<DiveDataSource> sources, {
    String? viewedSourceId,
  }) {
    if (sources.length < 2) return {};

    final activeSource = viewedSourceId != null
        ? sources.firstWhere(
            (s) => s.id == viewedSourceId,
            orElse: () => sources.firstWhere((s) => s.isPrimary),
          )
        : sources.firstWhere(
            (s) => s.isPrimary,
            orElse: () => sources.first,
          );

    final attribution = <String, String>{};
    final name = activeSource.displayName;

    // Standard fields — attributed to active (primary or viewed) source
    if (activeSource.maxDepth != null) attribution['maxDepth'] = name;
    if (activeSource.avgDepth != null) attribution['avgDepth'] = name;
    if (activeSource.duration != null) attribution['duration'] = name;
    if (activeSource.waterTemp != null) attribution['waterTemp'] = name;
    if (activeSource.cns != null) attribution['cns'] = name;
    if (activeSource.otu != null) attribution['otu'] = name;
    if (activeSource.surfaceInterval != null) {
      attribution['surfaceInterval'] = name;
    }

    // Best-available: heart rate — prefer HR-capable source
    final hrSource = sources.firstWhere(
      (s) => _hrCapableSources.contains(s.sourceFormat),
      orElse: () => activeSource,
    );
    attribution['heartRate'] = hrSource.displayName;

    // Best-available: GPS — prefer GPS-capable source
    final gpsSource = sources.firstWhere(
      (s) => _gpsCapableSources.contains(s.sourceFormat),
      orElse: () => activeSource,
    );
    attribution['gps'] = gpsSource.displayName;

    return attribution;
  }
}
```

- [ ] **Step 6: Run attribution tests**

```bash
flutter test test/features/dive_log/domain/services/field_attribution_service_test.dart
```

Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add FieldAttributionService for computed field-to-source mapping"
```

---

## Task 11: Build Field Attribution Badge Widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/field_attribution_badge.dart`

- [ ] **Step 1: Implement FieldAttributionBadge widget**

A small inline widget that shows the source name in a styled chip:

```dart
import 'package:flutter/material.dart';

/// Inline badge showing which data source provided a metric value.
///
/// Only rendered when [sourceName] is non-null. Designed to sit at the
/// trailing edge of a metric row.
class FieldAttributionBadge extends StatelessWidget {
  final String? sourceName;

  const FieldAttributionBadge({super.key, this.sourceName});

  @override
  Widget build(BuildContext context) {
    if (sourceName == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        sourceName!,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontSize: 10,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/field_attribution_badge.dart
git commit -m "feat: add FieldAttributionBadge widget"
```

---

## Task 12: Integrate into Dive Detail Page

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

- [ ] **Step 1: Update imports**

Replace:
```dart
import 'package:submersion/features/dive_log/presentation/widgets/dive_computers_section.dart';
```
With:
```dart
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/field_attribution_badge.dart';
import 'package:submersion/features/dive_log/domain/services/field_attribution_service.dart';
```

- [ ] **Step 2: Add tap-to-view state**

Add a `ValueNotifier<String?>` for the currently viewed source ID:

```dart
final ValueNotifier<String?> _viewedSourceIdNotifier = ValueNotifier(null);
```

Dispose it in the state's `dispose()` method.

- [ ] **Step 3: Replace DiveComputersSection with DataSourcesSection**

In `_buildContent()` (around line 275), replace the `computerReadingsAsync.whenData` block:

```dart
// Old: conditional, only shown for 2+ readings
// New: always shown
ref.watch(diveDataSourcesProvider(dive.id)).when(
  data: (dataSources) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      DataSourcesSection(
        dataSources: dataSources,
        diveCreatedAt: dive.dateTime,
        diveId: dive.id,
        units: units,
        viewedSourceId: _viewedSourceIdNotifier.value,
        onSetPrimary: (readingId) => _onSetPrimaryDataSource(
          context, ref, diveId: dive.id, readingId: readingId,
        ),
        onUnlink: (readingId) => _onUnlinkDataSource(
          context, ref, diveId: dive.id, readingId: readingId,
        ),
        onTapSource: (sourceId) {
          setState(() {
            // Toggle: tap again to deselect
            if (_viewedSourceIdNotifier.value == sourceId) {
              _viewedSourceIdNotifier.value = null;
            } else {
              _viewedSourceIdNotifier.value = sourceId;
            }
          });
        },
      ),
    ],
  ),
  loading: () => const SizedBox.shrink(),
  error: (_, __) => const SizedBox.shrink(),
),
```

- [ ] **Step 4: Rename callback methods**

Rename the existing `_onSetPrimaryComputer` → `_onSetPrimaryDataSource` and `_onUnlinkComputer` → `_onUnlinkDataSource`. Update the repository calls inside them to use the new method names.

- [ ] **Step 5: Add field badges to dive metrics**

In the metrics display area, wrap each metric value with conditional `FieldAttributionBadge`:

```dart
// Compute attribution once
final dataSources = ref.watch(diveDataSourcesProvider(dive.id)).valueOrNull ?? [];
final attribution = FieldAttributionService.computeAttribution(
  dataSources,
  viewedSourceId: _viewedSourceIdNotifier.value,
);
final showBadges = settings.showDataSourceBadges && attribution.isNotEmpty;
```

Then for each metric cell, append:
```dart
if (showBadges)
  FieldAttributionBadge(sourceName: attribution['maxDepth']),
```

- [ ] **Step 6: Reset viewed source on page leave**

In the page's lifecycle, reset `_viewedSourceIdNotifier.value = null` when navigating away or when a new dive is loaded.

- [ ] **Step 7: Run full test suite**

```bash
flutter test
```

Expected: ALL PASS

- [ ] **Step 8: Run analyzer and formatter**

```bash
flutter analyze && dart format lib/ test/
```

Expected: Clean

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: integrate DataSourcesSection and field badges into dive detail page"
```

---

## Task 13: Final Verification

- [ ] **Step 1: Run full test suite**

```bash
flutter test
```

Expected: ALL PASS

- [ ] **Step 2: Run analyzer**

```bash
flutter analyze
```

Expected: No errors

- [ ] **Step 3: Format all code**

```bash
dart format lib/ test/
```

- [ ] **Step 4: Manual smoke test**

```bash
flutter run -d macos
```

Verify:
1. Open a manually entered dive → "Data Source" section shows "Manual Entry" card
2. Open an imported dive → card shows computer model, serial, import date, format, filename
3. Open a multi-source dive → multiple cards with Primary/Secondary badges
4. Tap a secondary card → metrics update, "Viewing" badge appears
5. Tap again → deselects, returns to primary
6. Settings → "Show data source badges" toggle works
7. Overflow menu → "Set as primary" and "Unlink" still work

- [ ] **Step 5: Commit any final fixes**

```bash
git add -A
git commit -m "chore: final cleanup for data source provenance feature"
```
