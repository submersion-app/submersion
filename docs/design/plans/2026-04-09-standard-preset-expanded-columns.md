# Expanded Standard Table Preset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the built-in Standard table preset from 6 to 22 columns, grouped by category.

**Architecture:** Single-file change to `view_field_config.dart` — update two column lists (`defaultConfig()` and the `standard` variable in `builtInTablePresets()`) plus update existing tests.

**Tech Stack:** Flutter/Dart, Drift ORM (for persistence), Riverpod (state management)

---

### Task 1: Update tests for the new Standard preset column count

**Files:**
- Modify: `test/features/dive_log/domain/entities/view_field_config_test.dart:79-86` (defaultConfig test)
- Modify: `test/features/dive_log/domain/entities/view_field_config_test.dart:579-585` (Standard preset test)

- [ ] **Step 1: Update the `defaultConfig has expected columns` test**

Change the test at line 79 to verify 22 columns and spot-check the new category-grouped order:

```dart
    test('defaultConfig has expected columns', () {
      final config = TableViewConfig.defaultConfig();
      expect(config.columns.length, equals(22));
      expect(config.columns[0].field, equals(DiveField.diveNumber));
      expect(config.columns[0].isPinned, isTrue);
      expect(config.columns[1].field, equals(DiveField.siteName));
      expect(config.columns[1].isPinned, isTrue);
      // Core fields
      expect(config.columns[2].field, equals(DiveField.dateTime));
      expect(config.columns[3].field, equals(DiveField.diveTypeName));
      expect(config.columns[6].field, equals(DiveField.runtime));
      // Gas/Tank fields
      expect(config.columns[8].field, equals(DiveField.primaryGas));
      expect(config.columns[11].field, equals(DiveField.sacRate));
      // Environment fields
      expect(config.columns[12].field, equals(DiveField.waterTemp));
      // People fields
      expect(config.columns[16].field, equals(DiveField.buddy));
      // Metadata fields
      expect(config.columns[21].field, equals(DiveField.notes));
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });
```

- [ ] **Step 2: Update the `Standard preset has waterTemp column` test**

Expand to verify the Standard preset matches the new 22-column layout:

```dart
    test('Standard preset has 22 columns with category grouping', () {
      final presets = FieldPreset.builtInTablePresets();
      final standard = presets.firstWhere((p) => p.name == 'Standard');
      final config = TableViewConfig.fromJson(standard.configJson);
      expect(config.columns.length, equals(22));
      final fields = config.columns.map((c) => c.field).toList();
      // Verify key fields from each category are present
      expect(fields, contains(DiveField.waterTemp));
      expect(fields, contains(DiveField.primaryGas));
      expect(fields, contains(DiveField.buddy));
      expect(fields, contains(DiveField.ratingStars));
      expect(fields, contains(DiveField.notes));
      // Verify bottomTime was removed
      expect(fields, isNot(contains(DiveField.bottomTime)));
    });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/entities/view_field_config_test.dart`

Expected: Two test failures — `defaultConfig has expected columns` (expects 22, gets 6) and `Standard preset has 22 columns with category grouping` (expects 22, gets 6).

---

### Task 2: Update `defaultConfig()` and `builtInTablePresets()` Standard preset

**Files:**
- Modify: `lib/features/dive_log/domain/entities/view_field_config.dart:58-70` (defaultConfig)
- Modify: `lib/features/dive_log/domain/entities/view_field_config.dart:259-268` (standard preset)

- [ ] **Step 1: Replace `defaultConfig()` column list**

Replace lines 58-70 with:

```dart
  /// Default table configuration with 22 standard columns.
  factory TableViewConfig.defaultConfig() {
    return TableViewConfig(
      columns: [
        // Core
        TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        TableColumnConfig(field: DiveField.siteName, isPinned: true),
        TableColumnConfig(field: DiveField.dateTime),
        TableColumnConfig(field: DiveField.diveTypeName),
        TableColumnConfig(field: DiveField.maxDepth),
        TableColumnConfig(field: DiveField.avgDepth),
        TableColumnConfig(field: DiveField.runtime),
        TableColumnConfig(field: DiveField.surfaceInterval),
        // Gas/Tank
        TableColumnConfig(field: DiveField.primaryGas),
        TableColumnConfig(field: DiveField.startPressure),
        TableColumnConfig(field: DiveField.endPressure),
        TableColumnConfig(field: DiveField.sacRate),
        // Environment
        TableColumnConfig(field: DiveField.waterTemp),
        TableColumnConfig(field: DiveField.visibility),
        TableColumnConfig(field: DiveField.currentStrength),
        TableColumnConfig(field: DiveField.entryMethod),
        // People
        TableColumnConfig(field: DiveField.buddy),
        TableColumnConfig(field: DiveField.diveMaster),
        // Metadata
        TableColumnConfig(field: DiveField.tripName),
        TableColumnConfig(field: DiveField.ratingStars),
        TableColumnConfig(field: DiveField.tags),
        TableColumnConfig(field: DiveField.notes),
      ],
    );
  }
```

- [ ] **Step 2: Replace `builtInTablePresets()` standard variable**

Replace the `standard` variable at lines 259-268 with:

```dart
    final standard = TableViewConfig(
      columns: [
        // Core
        TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        TableColumnConfig(field: DiveField.siteName, isPinned: true),
        TableColumnConfig(field: DiveField.dateTime),
        TableColumnConfig(field: DiveField.diveTypeName),
        TableColumnConfig(field: DiveField.maxDepth),
        TableColumnConfig(field: DiveField.avgDepth),
        TableColumnConfig(field: DiveField.runtime),
        TableColumnConfig(field: DiveField.surfaceInterval),
        // Gas/Tank
        TableColumnConfig(field: DiveField.primaryGas),
        TableColumnConfig(field: DiveField.startPressure),
        TableColumnConfig(field: DiveField.endPressure),
        TableColumnConfig(field: DiveField.sacRate),
        // Environment
        TableColumnConfig(field: DiveField.waterTemp),
        TableColumnConfig(field: DiveField.visibility),
        TableColumnConfig(field: DiveField.currentStrength),
        TableColumnConfig(field: DiveField.entryMethod),
        // People
        TableColumnConfig(field: DiveField.buddy),
        TableColumnConfig(field: DiveField.diveMaster),
        // Metadata
        TableColumnConfig(field: DiveField.tripName),
        TableColumnConfig(field: DiveField.ratingStars),
        TableColumnConfig(field: DiveField.tags),
        TableColumnConfig(field: DiveField.notes),
      ],
    );
```

- [ ] **Step 3: Format code**

Run: `dart format lib/features/dive_log/domain/entities/view_field_config.dart`

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/entities/view_field_config_test.dart`

Expected: All tests pass.

- [ ] **Step 5: Run full analyze**

Run: `flutter analyze`

Expected: No issues found.

- [ ] **Step 6: Commit**

```
git add lib/features/dive_log/domain/entities/view_field_config.dart test/features/dive_log/domain/entities/view_field_config_test.dart
git commit -m "feat: expand Standard table preset from 6 to 22 columns

Add columns grouped by category: core dive data, gas/tank info,
environment conditions, people, and metadata. Remove bottomTime
(redundant with runtime)."
```
