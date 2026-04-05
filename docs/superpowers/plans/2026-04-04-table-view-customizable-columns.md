# Table View & Customizable Columns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a table view mode with selectable/sortable/resizable/reorderable columns, plus customizable field content for existing card views.

**Architecture:** A `DiveField` enum defines every possible column with metadata (label, icon, category, formatter, extractor). Per-view-mode configurations are stored in new Drift tables and managed by a `StateNotifier`. A custom `DiveTableView` widget handles pinned columns, horizontal scroll sync, and table interactions. Card views get configurable slot content. A settings page at `Settings > Appearance > Dive List > Column Configuration` provides full configuration UI.

**Tech Stack:** Flutter 3.x, Drift ORM, Riverpod (StateNotifier), linked_scroll_controller, go_router, Material 3

**Data loading note:** The table view needs fields beyond what `DiveSummary` provides (buddy, tanks, weights, gas, etc.). Table mode uses full `Dive` objects loaded via a dedicated provider. Card view slot customization is limited to `DiveSummary` fields (diveNumber, dateTime, siteName, maxDepth, bottomTime, runtime, waterTemp, rating, isFavorite, diveTypeId). Detailed card extra fields also use `DiveSummary` fields initially; extending `DiveSummary` with additional JOIN columns is a follow-up if users request more card fields.

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `lib/core/constants/dive_field.dart` | `DiveFieldCategory` + `DiveField` enums with all metadata |
| `lib/features/dive_log/domain/entities/view_field_config.dart` | `TableColumnConfig`, `TableViewConfig`, `CardViewConfig`, `CardSlotConfig`, `FieldPreset` domain classes |
| `lib/features/dive_log/data/repositories/view_config_repository.dart` | CRUD for view configs and presets (Drift) |
| `lib/features/dive_log/presentation/providers/view_config_providers.dart` | `ViewConfigNotifier` + providers for active configs |
| `lib/features/dive_log/presentation/widgets/dive_table_view.dart` | Main table widget with pinned columns and scroll sync |
| `lib/features/dive_log/presentation/widgets/table_header_cell.dart` | Header cell with sort indicator, resize handle, context menu |
| `lib/features/dive_log/presentation/widgets/table_column_picker.dart` | Bottom sheet / popover for toggling column visibility |
| `lib/features/settings/presentation/pages/column_config_page.dart` | Full column configuration settings page |
| `test/core/constants/dive_field_test.dart` | Tests for DiveField metadata, extractors, formatters |
| `test/features/dive_log/domain/entities/view_field_config_test.dart` | Tests for config classes, serialization, defaults |
| `test/features/dive_log/data/repositories/view_config_repository_test.dart` | Repository CRUD tests |
| `test/features/dive_log/presentation/providers/view_config_providers_test.dart` | Provider state management tests |
| `test/features/dive_log/presentation/widgets/dive_table_view_test.dart` | Table widget rendering tests |
| `test/features/dive_log/presentation/widgets/table_header_cell_test.dart` | Header cell interaction tests |

### Modified Files

| File | Changes |
|------|---------|
| `lib/core/constants/list_view_mode.dart` | Add `table` enum value |
| `lib/core/database/database.dart` | Add `view_configs` + `field_presets` tables, bump schema to 60 |
| `lib/shared/widgets/list_view_mode_toggle.dart` | Add table icon + label |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | Add `ListViewMode.table` branch, wire table view |
| `lib/features/dive_log/presentation/pages/dive_list_page.dart` | Full-width rendering for table mode (skip MasterDetailScaffold); add extra fields area to `DiveListTile` |
| `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart` | Accept slot config, render configurable fields |
| `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart` | Accept slot config, render configurable fields |
| `lib/features/settings/presentation/pages/appearance_page.dart` | Add "Column Configuration" ListTile under Dive Log section |
| `lib/core/router/app_router.dart` | Add `/settings/appearance/column-config` route |
| `pubspec.yaml` | Add `linked_scroll_controller` dependency |
| `lib/l10n/arb/app_en.arb` | Add all new l10n strings |

---

### Task 1: DiveField Enum & Metadata

**Files:**
- Create: `lib/core/constants/dive_field.dart`
- Test: `test/core/constants/dive_field_test.dart`

- [ ] **Step 1: Write tests for DiveField metadata**

```dart
// test/core/constants/dive_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';

void main() {
  group('DiveFieldCategory', () {
    test('every DiveField has a category', () {
      for (final field in DiveField.values) {
        expect(field.category, isA<DiveFieldCategory>(),
            reason: '${field.name} should have a category');
      }
    });
  });

  group('DiveField metadata', () {
    test('every field has a non-empty shortLabel', () {
      for (final field in DiveField.values) {
        expect(field.shortLabel.isNotEmpty, isTrue,
            reason: '${field.name} should have a shortLabel');
      }
    });

    test('every field has a positive defaultWidth', () {
      for (final field in DiveField.values) {
        expect(field.defaultWidth, greaterThan(0),
            reason: '${field.name} should have a positive defaultWidth');
      }
    });

    test('every field has minWidth <= defaultWidth', () {
      for (final field in DiveField.values) {
        expect(field.minWidth, lessThanOrEqualTo(field.defaultWidth),
            reason: '${field.name} minWidth should be <= defaultWidth');
      }
    });

    test('core fields are sortable', () {
      expect(DiveField.diveNumber.sortable, isTrue);
      expect(DiveField.dateTime.sortable, isTrue);
      expect(DiveField.maxDepth.sortable, isTrue);
      expect(DiveField.bottomTime.sortable, isTrue);
    });

    test('notes field is not sortable', () {
      expect(DiveField.notes.sortable, isFalse);
    });

    test('fields with icons return non-null IconData', () {
      expect(DiveField.maxDepth.icon, equals(Icons.arrow_downward));
      expect(DiveField.bottomTime.icon, equals(Icons.timer));
      expect(DiveField.waterTemp.icon, equals(Icons.thermostat));
    });

    test('fields without icons return null', () {
      expect(DiveField.sacRate.icon, isNull);
      expect(DiveField.gradientFactorLow.icon, isNull);
    });

    test('fieldsForCategory returns correct fields', () {
      final coreFields = DiveField.fieldsForCategory(DiveFieldCategory.core);
      expect(coreFields, contains(DiveField.diveNumber));
      expect(coreFields, contains(DiveField.dateTime));
      expect(coreFields, contains(DiveField.maxDepth));
      expect(coreFields, isNot(contains(DiveField.waterTemp)));
    });

    test('summaryFields returns only fields available on DiveSummary', () {
      final summaryFields = DiveField.summaryFields;
      expect(summaryFields, contains(DiveField.diveNumber));
      expect(summaryFields, contains(DiveField.maxDepth));
      expect(summaryFields, isNot(contains(DiveField.buddy)));
      expect(summaryFields, isNot(contains(DiveField.sacRate)));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/dive_field_test.dart`
Expected: FAIL — `dive_field.dart` does not exist yet.

- [ ] **Step 3: Create DiveFieldCategory and DiveField enums**

```dart
// lib/core/constants/dive_field.dart
import 'package:flutter/material.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// Groups dive fields for UI organization in column pickers.
enum DiveFieldCategory {
  core,
  environment,
  gas,
  tank,
  weight,
  equipment,
  deco,
  physiology,
  rebreather,
  people,
  location,
  trip,
  rating,
  metadata,
}

/// Every possible column/field for dive list views.
///
/// Each value carries metadata for rendering, sorting, and formatting.
/// Adding a new field requires only adding an enum value here — no widget
/// changes needed.
enum DiveField {
  // -- Core --
  diveNumber,
  dateTime,
  siteName,
  maxDepth,
  avgDepth,
  bottomTime,
  runtime,

  // -- Environment --
  waterTemp,
  airTemp,
  visibility,
  currentDirection,
  currentStrength,
  swellHeight,
  entryMethod,
  exitMethod,
  waterType,
  altitude,
  surfacePressure,

  // -- Gas --
  primaryGas,
  diluentGas,

  // -- Tank --
  tankCount,
  startPressure,
  endPressure,
  sacRate,
  gasConsumed,

  // -- Weight --
  totalWeight,

  // -- Equipment --
  diveComputerModel,

  // -- Deco --
  gradientFactorLow,
  gradientFactorHigh,
  decoAlgorithm,
  decoConservatism,

  // -- Physiology --
  cnsStart,
  cnsEnd,
  otu,

  // -- Rebreather --
  diveMode,
  setpointLow,
  setpointHigh,
  setpointDeco,

  // -- People --
  buddy,
  diveMaster,

  // -- Location --
  siteLocation,
  diveCenterName,
  siteLatitude,
  siteLongitude,

  // -- Trip --
  tripName,

  // -- Rating --
  ratingStars,
  isFavorite,

  // -- Metadata --
  notes,
  tags,
  importSource,
  diveTypeName,
  surfaceInterval,

  // -- Weather --
  windSpeed,
  cloudCover,
  precipitation,
  humidity,
  weatherDescription;

  /// Fields available on DiveSummary (for card view slot customization).
  static final Set<DiveField> summaryFields = {
    diveNumber,
    dateTime,
    siteName,
    siteLocation,
    maxDepth,
    bottomTime,
    runtime,
    waterTemp,
    ratingStars,
    isFavorite,
    diveTypeName,
    tags,
    siteLatitude,
    siteLongitude,
  };

  /// Returns all fields belonging to the given category.
  static List<DiveField> fieldsForCategory(DiveFieldCategory category) {
    return DiveField.values
        .where((f) => f.category == category)
        .toList();
  }
}

/// Metadata extension on DiveField.
extension DiveFieldMetadata on DiveField {
  /// Category for grouping in the column picker UI.
  DiveFieldCategory get category {
    return switch (this) {
      DiveField.diveNumber ||
      DiveField.dateTime ||
      DiveField.siteName ||
      DiveField.maxDepth ||
      DiveField.avgDepth ||
      DiveField.bottomTime ||
      DiveField.runtime =>
        DiveFieldCategory.core,
      DiveField.waterTemp ||
      DiveField.airTemp ||
      DiveField.visibility ||
      DiveField.currentDirection ||
      DiveField.currentStrength ||
      DiveField.swellHeight ||
      DiveField.entryMethod ||
      DiveField.exitMethod ||
      DiveField.waterType ||
      DiveField.altitude ||
      DiveField.surfacePressure =>
        DiveFieldCategory.environment,
      DiveField.primaryGas || DiveField.diluentGas => DiveFieldCategory.gas,
      DiveField.tankCount ||
      DiveField.startPressure ||
      DiveField.endPressure ||
      DiveField.sacRate ||
      DiveField.gasConsumed =>
        DiveFieldCategory.tank,
      DiveField.totalWeight => DiveFieldCategory.weight,
      DiveField.diveComputerModel => DiveFieldCategory.equipment,
      DiveField.gradientFactorLow ||
      DiveField.gradientFactorHigh ||
      DiveField.decoAlgorithm ||
      DiveField.decoConservatism =>
        DiveFieldCategory.deco,
      DiveField.cnsStart ||
      DiveField.cnsEnd ||
      DiveField.otu =>
        DiveFieldCategory.physiology,
      DiveField.diveMode ||
      DiveField.setpointLow ||
      DiveField.setpointHigh ||
      DiveField.setpointDeco =>
        DiveFieldCategory.rebreather,
      DiveField.buddy || DiveField.diveMaster => DiveFieldCategory.people,
      DiveField.siteLocation ||
      DiveField.diveCenterName ||
      DiveField.siteLatitude ||
      DiveField.siteLongitude =>
        DiveFieldCategory.location,
      DiveField.tripName => DiveFieldCategory.trip,
      DiveField.ratingStars || DiveField.isFavorite => DiveFieldCategory.rating,
      DiveField.notes ||
      DiveField.tags ||
      DiveField.importSource ||
      DiveField.diveTypeName ||
      DiveField.surfaceInterval =>
        DiveFieldCategory.metadata,
      DiveField.windSpeed ||
      DiveField.cloudCover ||
      DiveField.precipitation ||
      DiveField.humidity ||
      DiveField.weatherDescription =>
        DiveFieldCategory.environment,
    };
  }

  /// Abbreviated label for compact/dense card slots when no icon is available.
  String get shortLabel {
    return switch (this) {
      DiveField.diveNumber => '#',
      DiveField.dateTime => 'Date',
      DiveField.siteName => 'Site',
      DiveField.maxDepth => 'Depth',
      DiveField.avgDepth => 'Avg',
      DiveField.bottomTime => 'Time',
      DiveField.runtime => 'Run',
      DiveField.waterTemp => 'Temp',
      DiveField.airTemp => 'Air',
      DiveField.visibility => 'Vis',
      DiveField.currentDirection => 'CurDir',
      DiveField.currentStrength => 'CurStr',
      DiveField.swellHeight => 'Swell',
      DiveField.entryMethod => 'Entry',
      DiveField.exitMethod => 'Exit',
      DiveField.waterType => 'Water',
      DiveField.altitude => 'Alt',
      DiveField.surfacePressure => 'SfcP',
      DiveField.primaryGas => 'Gas',
      DiveField.diluentGas => 'Dil',
      DiveField.tankCount => 'Tanks',
      DiveField.startPressure => 'Start',
      DiveField.endPressure => 'End',
      DiveField.sacRate => 'SAC',
      DiveField.gasConsumed => 'Used',
      DiveField.totalWeight => 'Wt',
      DiveField.diveComputerModel => 'Comp',
      DiveField.gradientFactorLow => 'GFL',
      DiveField.gradientFactorHigh => 'GFH',
      DiveField.decoAlgorithm => 'Algo',
      DiveField.decoConservatism => 'Cons',
      DiveField.cnsStart => 'CNSi',
      DiveField.cnsEnd => 'CNSf',
      DiveField.otu => 'OTU',
      DiveField.diveMode => 'Mode',
      DiveField.setpointLow => 'SPLo',
      DiveField.setpointHigh => 'SPHi',
      DiveField.setpointDeco => 'SPDc',
      DiveField.buddy => 'Buddy',
      DiveField.diveMaster => 'DM',
      DiveField.siteLocation => 'Loc',
      DiveField.diveCenterName => 'Center',
      DiveField.siteLatitude => 'Lat',
      DiveField.siteLongitude => 'Lng',
      DiveField.tripName => 'Trip',
      DiveField.ratingStars => 'Rate',
      DiveField.isFavorite => 'Fav',
      DiveField.notes => 'Notes',
      DiveField.tags => 'Tags',
      DiveField.importSource => 'Src',
      DiveField.diveTypeName => 'Type',
      DiveField.surfaceInterval => 'SI',
      DiveField.windSpeed => 'Wind',
      DiveField.cloudCover => 'Cloud',
      DiveField.precipitation => 'Precip',
      DiveField.humidity => 'Humid',
      DiveField.weatherDescription => 'Wx',
    };
  }

  /// Material icon for compact/dense card slot display. Null triggers shortLabel fallback.
  IconData? get icon {
    return switch (this) {
      DiveField.diveNumber => Icons.tag,
      DiveField.dateTime => Icons.calendar_today,
      DiveField.maxDepth => Icons.arrow_downward,
      DiveField.avgDepth => Icons.vertical_align_center,
      DiveField.bottomTime => Icons.timer,
      DiveField.runtime => Icons.timer_outlined,
      DiveField.waterTemp => Icons.thermostat,
      DiveField.airTemp => Icons.thermostat_outlined,
      DiveField.visibility => Icons.visibility,
      DiveField.altitude => Icons.terrain,
      DiveField.buddy => Icons.person,
      DiveField.diveMaster => Icons.school,
      DiveField.ratingStars => Icons.star,
      DiveField.isFavorite => Icons.favorite,
      DiveField.totalWeight => Icons.fitness_center,
      DiveField.siteName => Icons.place,
      DiveField.siteLocation => Icons.map,
      DiveField.tripName => Icons.flight,
      DiveField.notes => Icons.notes,
      DiveField.tags => Icons.label,
      DiveField.diveMode => Icons.settings,
      DiveField.windSpeed => Icons.air,
      _ => null,
    };
  }

  /// Default column width in pixels for the table view.
  double get defaultWidth {
    return switch (this) {
      DiveField.diveNumber => 60,
      DiveField.dateTime => 140,
      DiveField.siteName => 160,
      DiveField.siteLocation => 140,
      DiveField.maxDepth || DiveField.avgDepth => 80,
      DiveField.bottomTime || DiveField.runtime => 80,
      DiveField.waterTemp || DiveField.airTemp => 70,
      DiveField.sacRate => 80,
      DiveField.totalWeight => 80,
      DiveField.primaryGas || DiveField.diluentGas => 90,
      DiveField.buddy || DiveField.diveMaster => 120,
      DiveField.notes => 200,
      DiveField.tags => 150,
      DiveField.tripName || DiveField.diveCenterName => 120,
      DiveField.ratingStars => 80,
      DiveField.surfaceInterval => 80,
      _ => 80,
    };
  }

  /// Minimum column width when user resizes.
  double get minWidth {
    return switch (this) {
      DiveField.diveNumber => 40,
      DiveField.siteName ||
      DiveField.siteLocation ||
      DiveField.notes ||
      DiveField.buddy ||
      DiveField.diveMaster =>
        80,
      DiveField.tags || DiveField.tripName || DiveField.diveCenterName => 80,
      _ => 50,
    };
  }

  /// Whether the table can sort by this field.
  bool get sortable {
    return switch (this) {
      DiveField.notes ||
      DiveField.tags ||
      DiveField.siteLatitude ||
      DiveField.siteLongitude =>
        false,
      _ => true,
    };
  }

  /// Extracts the raw value from a full Dive entity.
  dynamic extractFromDive(Dive dive) {
    return switch (this) {
      DiveField.diveNumber => dive.diveNumber,
      DiveField.dateTime => dive.dateTime,
      DiveField.siteName => dive.site?.name,
      DiveField.siteLocation => dive.site?.locationString,
      DiveField.maxDepth => dive.maxDepth,
      DiveField.avgDepth => dive.avgDepth,
      DiveField.bottomTime => dive.effectiveRuntime ?? dive.bottomTime,
      DiveField.runtime => dive.runtime,
      DiveField.waterTemp => dive.waterTemp,
      DiveField.airTemp => dive.airTemp,
      DiveField.visibility => dive.visibility?.name,
      DiveField.currentDirection => dive.currentDirection?.name,
      DiveField.currentStrength => dive.currentStrength?.name,
      DiveField.swellHeight => dive.swellHeight,
      DiveField.entryMethod => dive.entryMethod?.name,
      DiveField.exitMethod => dive.exitMethod?.name,
      DiveField.waterType => dive.waterType?.name,
      DiveField.altitude => dive.altitude,
      DiveField.surfacePressure => dive.surfacePressure,
      DiveField.primaryGas => dive.tanks.isNotEmpty
          ? dive.tanks.first.gasMix.name
          : null,
      DiveField.diluentGas => dive.diluentGas?.name,
      DiveField.tankCount => dive.tanks.length,
      DiveField.startPressure => dive.tanks.isNotEmpty
          ? dive.tanks.first.startPressure
          : null,
      DiveField.endPressure => dive.tanks.isNotEmpty
          ? dive.tanks.first.endPressure
          : null,
      DiveField.sacRate => _computeSacRate(dive),
      DiveField.gasConsumed => _computeGasConsumed(dive),
      DiveField.totalWeight => dive.totalWeight,
      DiveField.diveComputerModel => dive.diveComputerModel,
      DiveField.gradientFactorLow => dive.gradientFactorLow,
      DiveField.gradientFactorHigh => dive.gradientFactorHigh,
      DiveField.decoAlgorithm => dive.decoAlgorithm,
      DiveField.decoConservatism => dive.decoConservatism,
      DiveField.cnsStart => dive.cnsStart,
      DiveField.cnsEnd => dive.cnsEnd,
      DiveField.otu => dive.otu,
      DiveField.diveMode => dive.diveMode.name,
      DiveField.setpointLow => dive.setpointLow,
      DiveField.setpointHigh => dive.setpointHigh,
      DiveField.setpointDeco => dive.setpointDeco,
      DiveField.buddy => dive.buddy,
      DiveField.diveMaster => dive.diveMaster,
      DiveField.diveCenterName => dive.diveCenter?.name,
      DiveField.siteLatitude => dive.site?.location?.latitude,
      DiveField.siteLongitude => dive.site?.location?.longitude,
      DiveField.tripName => dive.trip?.name,
      DiveField.ratingStars => dive.rating,
      DiveField.isFavorite => dive.isFavorite,
      DiveField.notes => dive.notes,
      DiveField.tags => dive.tags.map((t) => t.name).join(', '),
      DiveField.importSource => dive.importSource,
      DiveField.diveTypeName => dive.diveType?.name ?? dive.diveTypeId,
      DiveField.surfaceInterval => dive.surfaceInterval,
      DiveField.windSpeed => dive.windSpeed,
      DiveField.cloudCover => dive.cloudCover?.name,
      DiveField.precipitation => dive.precipitation?.name,
      DiveField.humidity => dive.humidity,
      DiveField.weatherDescription => dive.weatherDescription,
    };
  }

  /// Extracts the raw value from a DiveSummary (card views).
  /// Returns null for fields not available on DiveSummary.
  dynamic extractFromSummary(DiveSummary summary) {
    return switch (this) {
      DiveField.diveNumber => summary.diveNumber,
      DiveField.dateTime => summary.dateTime,
      DiveField.siteName => summary.siteName,
      DiveField.siteLocation => summary.siteLocation,
      DiveField.maxDepth => summary.maxDepth,
      DiveField.bottomTime => summary.runtime ?? summary.bottomTime,
      DiveField.runtime => summary.runtime,
      DiveField.waterTemp => summary.waterTemp,
      DiveField.ratingStars => summary.rating,
      DiveField.isFavorite => summary.isFavorite,
      DiveField.diveTypeName => summary.diveTypeId,
      DiveField.tags => summary.tags.map((t) => t.name).join(', '),
      DiveField.siteLatitude => summary.siteLatitude,
      DiveField.siteLongitude => summary.siteLongitude,
      _ => null,
    };
  }

  /// Formats a raw value for display using unit settings.
  String formatValue(dynamic value, UnitFormatter units) {
    if (value == null) return '--';
    return switch (this) {
      DiveField.diveNumber => '#$value',
      DiveField.dateTime => units.formatDateTimeBullet(value as DateTime),
      DiveField.maxDepth ||
      DiveField.avgDepth ||
      DiveField.altitude ||
      DiveField.swellHeight =>
        units.formatDepth(value as double),
      DiveField.bottomTime || DiveField.runtime => _formatDuration(value),
      DiveField.waterTemp || DiveField.airTemp =>
        units.formatTemperature(value as double),
      DiveField.startPressure ||
      DiveField.endPressure ||
      DiveField.surfacePressure =>
        units.formatPressure(value as double),
      DiveField.totalWeight => units.formatWeight(value as double),
      DiveField.sacRate => '${(value as double).toStringAsFixed(1)} ${units.volumeSymbol}/min',
      DiveField.gasConsumed => '${(value as double).toStringAsFixed(0)} ${units.volumeSymbol}',
      DiveField.windSpeed => '${(value as double).toStringAsFixed(1)} m/s',
      DiveField.humidity => '${(value as double).toStringAsFixed(0)}%',
      DiveField.setpointLow ||
      DiveField.setpointHigh ||
      DiveField.setpointDeco =>
        '${(value as double).toStringAsFixed(2)} bar',
      DiveField.cnsStart ||
      DiveField.cnsEnd =>
        '${(value as double).toStringAsFixed(0)}%',
      DiveField.otu => (value as double).toStringAsFixed(0),
      DiveField.gradientFactorLow ||
      DiveField.gradientFactorHigh ||
      DiveField.decoConservatism =>
        '$value',
      DiveField.tankCount => '$value',
      DiveField.ratingStars => '$value/5',
      DiveField.isFavorite => (value as bool) ? 'Yes' : 'No',
      DiveField.surfaceInterval => _formatDuration(value),
      _ => '$value',
    };
  }
}

String _formatDuration(dynamic value) {
  if (value is Duration) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}min';
  }
  return '$value';
}

double? _computeSacRate(Dive dive) {
  if (dive.tanks.isEmpty) return null;
  final tank = dive.tanks.first;
  final start = tank.startPressure;
  final end = tank.endPressure;
  final vol = tank.volume;
  final avgDepth = dive.avgDepth;
  final runtime = dive.effectiveRuntime ?? dive.bottomTime;
  if (start == null || end == null || vol == null || avgDepth == null ||
      runtime == null || runtime.inMinutes == 0) {
    return null;
  }
  final pressureUsed = start - end;
  if (pressureUsed <= 0) return null;
  final ambientPressure = avgDepth / 10.0 + 1.0;
  return (pressureUsed * vol) / runtime.inMinutes / ambientPressure;
}

double? _computeGasConsumed(Dive dive) {
  if (dive.tanks.isEmpty) return null;
  final tank = dive.tanks.first;
  final start = tank.startPressure;
  final end = tank.endPressure;
  final vol = tank.volume;
  if (start == null || end == null || vol == null) return null;
  final pressureUsed = start - end;
  if (pressureUsed <= 0) return null;
  return pressureUsed * vol;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/constants/dive_field_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/constants/dive_field.dart test/core/constants/dive_field_test.dart
git commit -m "feat(columns): add DiveField enum with metadata for all dive entity fields (#56)"
```

---

### Task 2: Configuration Model Classes

**Files:**
- Create: `lib/features/dive_log/domain/entities/view_field_config.dart`
- Test: `test/features/dive_log/domain/entities/view_field_config_test.dart`

- [ ] **Step 1: Write tests for config classes**

```dart
// test/features/dive_log/domain/entities/view_field_config_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';

void main() {
  group('TableColumnConfig', () {
    test('creates with defaults', () {
      const config = TableColumnConfig(field: DiveField.maxDepth);
      expect(config.width, equals(DiveField.maxDepth.defaultWidth));
      expect(config.isPinned, isFalse);
    });

    test('serializes to and from JSON', () {
      const config = TableColumnConfig(
        field: DiveField.siteName,
        width: 200,
        isPinned: true,
      );
      final json = config.toJson();
      final restored = TableColumnConfig.fromJson(json);
      expect(restored.field, equals(DiveField.siteName));
      expect(restored.width, equals(200));
      expect(restored.isPinned, isTrue);
    });
  });

  group('TableViewConfig', () {
    test('defaultConfig has expected columns', () {
      final config = TableViewConfig.defaultConfig();
      expect(config.columns.length, greaterThanOrEqualTo(5));
      expect(config.columns.first.field, equals(DiveField.diveNumber));
      expect(config.columns.first.isPinned, isTrue);
      expect(config.sortField, isNull);
      expect(config.sortAscending, isTrue);
    });

    test('serializes round-trip', () {
      final config = TableViewConfig.defaultConfig().copyWith(
        sortField: DiveField.dateTime,
        sortAscending: false,
      );
      final json = jsonEncode(config.toJson());
      final restored = TableViewConfig.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(restored.columns.length, equals(config.columns.length));
      expect(restored.sortField, equals(DiveField.dateTime));
      expect(restored.sortAscending, isFalse);
    });
  });

  group('CardViewConfig', () {
    test('defaultCompactConfig has 4 slots', () {
      final config = CardViewConfig.defaultCompact();
      expect(config.slots.length, equals(4));
      expect(config.slots[0].slotId, equals('title'));
      expect(config.slots[0].field, equals(DiveField.siteName));
    });

    test('defaultDenseConfig has 4 slots', () {
      final config = CardViewConfig.defaultDense();
      expect(config.slots.length, equals(4));
    });

    test('defaultDetailedConfig has empty extraFields', () {
      final config = CardViewConfig.defaultDetailed();
      expect(config.extraFields, isEmpty);
    });

    test('serializes round-trip', () {
      final config = CardViewConfig.defaultCompact();
      final json = jsonEncode(config.toJson());
      final restored = CardViewConfig.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      expect(restored.slots.length, equals(config.slots.length));
      expect(restored.mode, equals(config.mode));
    });
  });

  group('FieldPreset', () {
    test('built-in presets exist', () {
      final presets = FieldPreset.builtInTablePresets();
      expect(presets.length, equals(3));
      expect(presets.map((p) => p.name), containsAll(['Standard', 'Technical', 'Planning']));
      expect(presets.every((p) => p.isBuiltIn), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/view_field_config_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement configuration model classes**

```dart
// lib/features/dive_log/domain/entities/view_field_config.dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';

/// Configuration for a single column in the table view.
class TableColumnConfig extends Equatable {
  final DiveField field;
  final double width;
  final bool isPinned;

  const TableColumnConfig({
    required this.field,
    double? width,
    this.isPinned = false,
  }) : width = width ?? 0; // 0 means use field.defaultWidth

  double get effectiveWidth => width > 0 ? width : field.defaultWidth;

  TableColumnConfig copyWith({
    DiveField? field,
    double? width,
    bool? isPinned,
  }) {
    return TableColumnConfig(
      field: field ?? this.field,
      width: width ?? this.width,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  Map<String, dynamic> toJson() => {
    'field': this.field.name,
    'width': width,
    'isPinned': isPinned,
  };

  factory TableColumnConfig.fromJson(Map<String, dynamic> json) {
    return TableColumnConfig(
      field: DiveField.values.firstWhere((f) => f.name == json['field']),
      width: (json['width'] as num?)?.toDouble(),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [field, width, isPinned];
}

/// Configuration for the table view mode.
class TableViewConfig extends Equatable {
  final List<TableColumnConfig> columns;
  final DiveField? sortField;
  final bool sortAscending;

  const TableViewConfig({
    required this.columns,
    this.sortField,
    this.sortAscending = true,
  });

  /// Default table configuration matching the "Standard" preset.
  factory TableViewConfig.defaultConfig() {
    return const TableViewConfig(
      columns: [
        TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
        TableColumnConfig(field: DiveField.siteName, isPinned: true),
        TableColumnConfig(field: DiveField.dateTime),
        TableColumnConfig(field: DiveField.maxDepth),
        TableColumnConfig(field: DiveField.bottomTime),
        TableColumnConfig(field: DiveField.waterTemp),
      ],
    );
  }

  TableViewConfig copyWith({
    List<TableColumnConfig>? columns,
    DiveField? sortField,
    bool? sortAscending,
    bool clearSortField = false,
  }) {
    return TableViewConfig(
      columns: columns ?? this.columns,
      sortField: clearSortField ? null : (sortField ?? this.sortField),
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  Map<String, dynamic> toJson() => {
    'columns': columns.map((c) => c.toJson()).toList(),
    'sortField': sortField?.name,
    'sortAscending': sortAscending,
  };

  factory TableViewConfig.fromJson(Map<String, dynamic> json) {
    return TableViewConfig(
      columns: (json['columns'] as List)
          .map((c) => TableColumnConfig.fromJson(c as Map<String, dynamic>))
          .toList(),
      sortField: json['sortField'] != null
          ? DiveField.values.firstWhere((f) => f.name == json['sortField'])
          : null,
      sortAscending: json['sortAscending'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [columns, sortField, sortAscending];
}

/// Configuration for a single slot in a card view.
class CardSlotConfig extends Equatable {
  final String slotId;
  final DiveField field;

  const CardSlotConfig({required this.slotId, required this.field});

  CardSlotConfig copyWith({String? slotId, DiveField? field}) {
    return CardSlotConfig(
      slotId: slotId ?? this.slotId,
      field: field ?? this.field,
    );
  }

  Map<String, dynamic> toJson() => {
    'slotId': slotId,
    'field': field.name,
  };

  factory CardSlotConfig.fromJson(Map<String, dynamic> json) {
    return CardSlotConfig(
      slotId: json['slotId'] as String,
      field: DiveField.values.firstWhere((f) => f.name == json['field']),
    );
  }

  @override
  List<Object?> get props => [slotId, field];
}

/// Configuration for a card-based view mode (detailed, compact, dense).
class CardViewConfig extends Equatable {
  final ListViewMode mode;
  final List<CardSlotConfig> slots;
  final List<DiveField> extraFields; // Detailed view only

  const CardViewConfig({
    required this.mode,
    this.slots = const [],
    this.extraFields = const [],
  });

  factory CardViewConfig.defaultCompact() {
    return const CardViewConfig(
      mode: ListViewMode.compact,
      slots: [
        CardSlotConfig(slotId: 'title', field: DiveField.siteName),
        CardSlotConfig(slotId: 'date', field: DiveField.dateTime),
        CardSlotConfig(slotId: 'stat1', field: DiveField.maxDepth),
        CardSlotConfig(slotId: 'stat2', field: DiveField.bottomTime),
      ],
    );
  }

  factory CardViewConfig.defaultDense() {
    return const CardViewConfig(
      mode: ListViewMode.dense,
      slots: [
        CardSlotConfig(slotId: 'slot1', field: DiveField.siteName),
        CardSlotConfig(slotId: 'slot2', field: DiveField.dateTime),
        CardSlotConfig(slotId: 'slot3', field: DiveField.maxDepth),
        CardSlotConfig(slotId: 'slot4', field: DiveField.bottomTime),
      ],
    );
  }

  factory CardViewConfig.defaultDetailed() {
    return const CardViewConfig(
      mode: ListViewMode.detailed,
      extraFields: [],
    );
  }

  CardViewConfig copyWith({
    ListViewMode? mode,
    List<CardSlotConfig>? slots,
    List<DiveField>? extraFields,
  }) {
    return CardViewConfig(
      mode: mode ?? this.mode,
      slots: slots ?? this.slots,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'slots': slots.map((s) => s.toJson()).toList(),
    'extraFields': extraFields.map((f) => f.name).toList(),
  };

  factory CardViewConfig.fromJson(Map<String, dynamic> json) {
    return CardViewConfig(
      mode: ListViewMode.fromName(json['mode'] as String),
      slots: (json['slots'] as List?)
              ?.map((s) => CardSlotConfig.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      extraFields: (json['extraFields'] as List?)
              ?.map((f) =>
                  DiveField.values.firstWhere((d) => d.name == f as String))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [mode, slots, extraFields];
}

/// A named preset for a view mode's field configuration.
class FieldPreset extends Equatable {
  final String id;
  final String name;
  final ListViewMode viewMode;
  final Map<String, dynamic> configJson;
  final bool isBuiltIn;

  const FieldPreset({
    required this.id,
    required this.name,
    required this.viewMode,
    required this.configJson,
    this.isBuiltIn = false,
  });

  /// Built-in table presets shipped with the app.
  static List<FieldPreset> builtInTablePresets() {
    return [
      FieldPreset(
        id: 'builtin-standard',
        name: 'Standard',
        viewMode: ListViewMode.table,
        isBuiltIn: true,
        configJson: const TableViewConfig(
          columns: [
            TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
            TableColumnConfig(field: DiveField.siteName, isPinned: true),
            TableColumnConfig(field: DiveField.dateTime),
            TableColumnConfig(field: DiveField.maxDepth),
            TableColumnConfig(field: DiveField.bottomTime),
            TableColumnConfig(field: DiveField.waterTemp),
          ],
        ).toJson(),
      ),
      FieldPreset(
        id: 'builtin-technical',
        name: 'Technical',
        viewMode: ListViewMode.table,
        isBuiltIn: true,
        configJson: const TableViewConfig(
          columns: [
            TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
            TableColumnConfig(field: DiveField.siteName, isPinned: true),
            TableColumnConfig(field: DiveField.dateTime),
            TableColumnConfig(field: DiveField.maxDepth),
            TableColumnConfig(field: DiveField.bottomTime),
            TableColumnConfig(field: DiveField.gradientFactorLow),
            TableColumnConfig(field: DiveField.gradientFactorHigh),
            TableColumnConfig(field: DiveField.decoAlgorithm),
            TableColumnConfig(field: DiveField.cnsEnd),
            TableColumnConfig(field: DiveField.primaryGas),
            TableColumnConfig(field: DiveField.sacRate),
          ],
        ).toJson(),
      ),
      FieldPreset(
        id: 'builtin-planning',
        name: 'Planning',
        viewMode: ListViewMode.table,
        isBuiltIn: true,
        configJson: const TableViewConfig(
          columns: [
            TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
            TableColumnConfig(field: DiveField.siteName, isPinned: true),
            TableColumnConfig(field: DiveField.dateTime),
            TableColumnConfig(field: DiveField.maxDepth),
            TableColumnConfig(field: DiveField.sacRate),
            TableColumnConfig(field: DiveField.totalWeight),
            TableColumnConfig(field: DiveField.waterType),
            TableColumnConfig(field: DiveField.tankCount),
            TableColumnConfig(field: DiveField.primaryGas),
          ],
        ).toJson(),
      ),
    ];
  }

  FieldPreset copyWith({
    String? id,
    String? name,
    ListViewMode? viewMode,
    Map<String, dynamic>? configJson,
    bool? isBuiltIn,
  }) {
    return FieldPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      viewMode: viewMode ?? this.viewMode,
      configJson: configJson ?? this.configJson,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  List<Object?> get props => [id, name, viewMode, configJson, isBuiltIn];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/domain/entities/view_field_config_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/view_field_config.dart test/features/dive_log/domain/entities/view_field_config_test.dart
git commit -m "feat(columns): add view config model classes with serialization and presets (#56)"
```

---

### Task 3: Database Schema & Migration

**Files:**
- Modify: `lib/core/database/database.dart` (add tables, bump schema)
- Modify: `lib/core/constants/list_view_mode.dart` (add `table` value)

- [ ] **Step 1: Add `table` to ListViewMode enum**

In `lib/core/constants/list_view_mode.dart`, add `table` after `dense`:

```dart
enum ListViewMode {
  detailed,
  compact,
  dense,
  table;

  static ListViewMode fromName(String name) {
    return ListViewMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ListViewMode.detailed,
    );
  }
}
```

- [ ] **Step 2: Add Drift table definitions to database.dart**

Add two new table classes before the `@DriftDatabase` annotation in `lib/core/database/database.dart`:

```dart
/// Stores the active view configuration per (diver, view_mode).
class ViewConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get viewMode => text()(); // 'table', 'detailed', 'compact', 'dense'
  TextColumn get configJson => text()(); // JSON-encoded config
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Named presets per (diver, view_mode).
class FieldPresets extends Table {
  TextColumn get id => text()();
  TextColumn get diverId => text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get viewMode => text()();
  TextColumn get name => text()();
  TextColumn get configJson => text()();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 3: Register tables in @DriftDatabase annotation**

Add `ViewConfigs` and `FieldPresets` to the `tables:` list in the `@DriftDatabase` annotation.

- [ ] **Step 4: Bump schema version and add migration**

Change `currentSchemaVersion` from 59 to 60. Add migration in `onUpgrade`:

```dart
if (from < 60) {
  await customStatement('''
    CREATE TABLE IF NOT EXISTS view_configs (
      id TEXT NOT NULL PRIMARY KEY,
      diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
      view_mode TEXT NOT NULL,
      config_json TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await customStatement('''
    CREATE TABLE IF NOT EXISTS field_presets (
      id TEXT NOT NULL PRIMARY KEY,
      diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
      view_mode TEXT NOT NULL,
      name TEXT NOT NULL,
      config_json TEXT NOT NULL,
      is_built_in INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
  ''');
  await customStatement(
    'CREATE INDEX IF NOT EXISTS idx_view_configs_diver ON view_configs(diver_id, view_mode)',
  );
  await customStatement(
    'CREATE INDEX IF NOT EXISTS idx_field_presets_diver ON field_presets(diver_id, view_mode)',
  );
}
```

- [ ] **Step 5: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Drift generates updated database classes.

- [ ] **Step 6: Run existing tests to verify no regressions**

Run: `flutter test test/core/`
Expected: All existing tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/list_view_mode.dart lib/core/database/database.dart lib/core/database/database.g.dart
git commit -m "feat(columns): add view_configs and field_presets tables, schema v60 (#56)"
```

---

### Task 4: View Config Repository

**Files:**
- Create: `lib/features/dive_log/data/repositories/view_config_repository.dart`
- Test: `test/features/dive_log/data/repositories/view_config_repository_test.dart`

- [ ] **Step 1: Write repository tests**

```dart
// test/features/dive_log/data/repositories/view_config_repository_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';

void main() {
  late AppDatabase db;
  late ViewConfigRepository repo;
  const testDiverId = 'test-diver-1';

  setUp(() async {
    db = AppDatabase.forTesting();
    repo = ViewConfigRepository(db);
    // Create test diver
    await db.into(db.divers).insert(DiversCompanion.insert(
      id: testDiverId,
      name: 'Test Diver',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  });

  tearDown(() async {
    await db.close();
  });

  group('ViewConfigRepository', () {
    test('getTableConfig returns default when no config saved', () async {
      final config = await repo.getTableConfig(testDiverId);
      expect(config.columns.length, greaterThanOrEqualTo(5));
      expect(config.columns.first.field, equals(DiveField.diveNumber));
    });

    test('saveTableConfig persists and retrieves', () async {
      final config = TableViewConfig.defaultConfig().copyWith(
        sortField: DiveField.maxDepth,
        sortAscending: false,
      );
      await repo.saveTableConfig(testDiverId, config);
      final loaded = await repo.getTableConfig(testDiverId);
      expect(loaded.sortField, equals(DiveField.maxDepth));
      expect(loaded.sortAscending, isFalse);
    });

    test('getCardConfig returns default for compact', () async {
      final config = await repo.getCardConfig(testDiverId, ListViewMode.compact);
      expect(config.slots.length, equals(4));
      expect(config.mode, equals(ListViewMode.compact));
    });

    test('saveCardConfig persists and retrieves', () async {
      final config = CardViewConfig.defaultCompact().copyWith(
        slots: [
          const CardSlotConfig(slotId: 'title', field: DiveField.buddy),
          const CardSlotConfig(slotId: 'date', field: DiveField.dateTime),
          const CardSlotConfig(slotId: 'stat1', field: DiveField.waterTemp),
          const CardSlotConfig(slotId: 'stat2', field: DiveField.ratingStars),
        ],
      );
      await repo.saveCardConfig(testDiverId, config);
      final loaded = await repo.getCardConfig(testDiverId, ListViewMode.compact);
      expect(loaded.slots[0].field, equals(DiveField.buddy));
    });

    test('getPresetsForMode returns built-in presets', () async {
      await repo.ensureBuiltInPresets(testDiverId);
      final presets = await repo.getPresetsForMode(testDiverId, ListViewMode.table);
      expect(presets.where((p) => p.isBuiltIn).length, equals(3));
    });

    test('savePreset creates user preset', () async {
      final config = TableViewConfig.defaultConfig();
      final preset = FieldPreset(
        id: 'user-1',
        name: 'My Config',
        viewMode: ListViewMode.table,
        configJson: config.toJson(),
      );
      await repo.savePreset(testDiverId, preset);
      final presets = await repo.getPresetsForMode(testDiverId, ListViewMode.table);
      expect(presets.any((p) => p.name == 'My Config'), isTrue);
    });

    test('deletePreset removes user preset but not built-in', () async {
      await repo.ensureBuiltInPresets(testDiverId);
      final presets = await repo.getPresetsForMode(testDiverId, ListViewMode.table);
      final builtIn = presets.firstWhere((p) => p.isBuiltIn);

      // Attempting to delete built-in should throw or no-op
      await repo.deletePreset(builtIn.id);
      final after = await repo.getPresetsForMode(testDiverId, ListViewMode.table);
      expect(after.where((p) => p.isBuiltIn).length, equals(3));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/view_config_repository_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement ViewConfigRepository**

```dart
// lib/features/dive_log/data/repositories/view_config_repository.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:uuid/uuid.dart';

class ViewConfigRepository {
  final AppDatabase _db;

  ViewConfigRepository(this._db);

  // -- Table Config --

  Future<TableViewConfig> getTableConfig(String diverId) async {
    final row = await (_db.select(_db.viewConfigs)
          ..where((t) =>
              t.diverId.equals(diverId) &
              t.viewMode.equals(ListViewMode.table.name)))
        .getSingleOrNull();

    if (row == null) return TableViewConfig.defaultConfig();

    return TableViewConfig.fromJson(
      jsonDecode(row.configJson) as Map<String, dynamic>,
    );
  }

  Future<void> saveTableConfig(String diverId, TableViewConfig config) async {
    final existing = await (_db.select(_db.viewConfigs)
          ..where((t) =>
              t.diverId.equals(diverId) &
              t.viewMode.equals(ListViewMode.table.name)))
        .getSingleOrNull();

    final now = DateTime.now().millisecondsSinceEpoch;

    if (existing != null) {
      await (_db.update(_db.viewConfigs)
            ..where((t) => t.id.equals(existing.id)))
          .write(ViewConfigsCompanion(
        configJson: Value(jsonEncode(config.toJson())),
        updatedAt: Value(now),
      ));
    } else {
      await _db.into(_db.viewConfigs).insert(ViewConfigsCompanion.insert(
        id: const Uuid().v4(),
        diverId: diverId,
        viewMode: ListViewMode.table.name,
        configJson: jsonEncode(config.toJson()),
        updatedAt: now,
      ));
    }
  }

  // -- Card Config --

  Future<CardViewConfig> getCardConfig(
    String diverId,
    ListViewMode mode,
  ) async {
    final row = await (_db.select(_db.viewConfigs)
          ..where((t) =>
              t.diverId.equals(diverId) & t.viewMode.equals(mode.name)))
        .getSingleOrNull();

    if (row == null) {
      return switch (mode) {
        ListViewMode.compact => CardViewConfig.defaultCompact(),
        ListViewMode.dense => CardViewConfig.defaultDense(),
        ListViewMode.detailed => CardViewConfig.defaultDetailed(),
        ListViewMode.table => CardViewConfig.defaultDetailed(), // Shouldn't happen
      };
    }

    return CardViewConfig.fromJson(
      jsonDecode(row.configJson) as Map<String, dynamic>,
    );
  }

  Future<void> saveCardConfig(String diverId, CardViewConfig config) async {
    final existing = await (_db.select(_db.viewConfigs)
          ..where((t) =>
              t.diverId.equals(diverId) &
              t.viewMode.equals(config.mode.name)))
        .getSingleOrNull();

    final now = DateTime.now().millisecondsSinceEpoch;

    if (existing != null) {
      await (_db.update(_db.viewConfigs)
            ..where((t) => t.id.equals(existing.id)))
          .write(ViewConfigsCompanion(
        configJson: Value(jsonEncode(config.toJson())),
        updatedAt: Value(now),
      ));
    } else {
      await _db.into(_db.viewConfigs).insert(ViewConfigsCompanion.insert(
        id: const Uuid().v4(),
        diverId: diverId,
        viewMode: config.mode.name,
        configJson: jsonEncode(config.toJson()),
        updatedAt: now,
      ));
    }
  }

  // -- Presets --

  Future<List<FieldPreset>> getPresetsForMode(
    String diverId,
    ListViewMode mode,
  ) async {
    final rows = await (_db.select(_db.fieldPresets)
          ..where((t) =>
              t.diverId.equals(diverId) & t.viewMode.equals(mode.name))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    return rows
        .map((r) => FieldPreset(
              id: r.id,
              name: r.name,
              viewMode: ListViewMode.fromName(r.viewMode),
              configJson:
                  jsonDecode(r.configJson) as Map<String, dynamic>,
              isBuiltIn: r.isBuiltIn,
            ))
        .toList();
  }

  Future<void> savePreset(String diverId, FieldPreset preset) async {
    await _db.into(_db.fieldPresets).insertOnConflictUpdate(
      FieldPresetsCompanion.insert(
        id: preset.id,
        diverId: diverId,
        viewMode: preset.viewMode.name,
        name: preset.name,
        configJson: jsonEncode(preset.configJson),
        isBuiltIn: Value(preset.isBuiltIn),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> deletePreset(String presetId) async {
    await (_db.delete(_db.fieldPresets)
          ..where((t) => t.id.equals(presetId) & t.isBuiltIn.equals(false)))
        .go();
  }

  /// Ensures built-in presets exist for this diver.
  Future<void> ensureBuiltInPresets(String diverId) async {
    final existing = await (_db.select(_db.fieldPresets)
          ..where(
              (t) => t.diverId.equals(diverId) & t.isBuiltIn.equals(true)))
        .get();

    if (existing.isNotEmpty) return;

    for (final preset in FieldPreset.builtInTablePresets()) {
      await savePreset(diverId, preset);
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/view_config_repository_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/view_config_repository.dart test/features/dive_log/data/repositories/view_config_repository_test.dart
git commit -m "feat(columns): add ViewConfigRepository for persisting view configs and presets (#56)"
```

---

### Task 5: View Config Providers

**Files:**
- Create: `lib/features/dive_log/presentation/providers/view_config_providers.dart`
- Test: `test/features/dive_log/presentation/providers/view_config_providers_test.dart`

- [ ] **Step 1: Write provider tests**

```dart
// test/features/dive_log/presentation/providers/view_config_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';

void main() {
  group('TableViewConfigNotifier', () {
    test('starts with default config', () {
      final notifier = TableViewConfigNotifier();
      expect(notifier.state.columns.length, greaterThanOrEqualTo(5));
      expect(notifier.state.columns.first.field, equals(DiveField.diveNumber));
    });

    test('toggleColumn adds a new column', () {
      final notifier = TableViewConfigNotifier();
      final initialCount = notifier.state.columns.length;
      notifier.toggleColumn(DiveField.buddy);
      expect(notifier.state.columns.length, equals(initialCount + 1));
      expect(notifier.state.columns.last.field, equals(DiveField.buddy));
    });

    test('toggleColumn removes an existing non-pinned column', () {
      final notifier = TableViewConfigNotifier();
      notifier.toggleColumn(DiveField.waterTemp);
      final withTemp = notifier.state.columns.length;
      notifier.toggleColumn(DiveField.waterTemp);
      expect(notifier.state.columns.length, equals(withTemp - 1));
    });

    test('setSortField updates sort state', () {
      final notifier = TableViewConfigNotifier();
      notifier.setSortField(DiveField.maxDepth);
      expect(notifier.state.sortField, equals(DiveField.maxDepth));
      expect(notifier.state.sortAscending, isTrue);

      // Toggle again reverses direction
      notifier.setSortField(DiveField.maxDepth);
      expect(notifier.state.sortAscending, isFalse);

      // Toggle a third time clears sort
      notifier.setSortField(DiveField.maxDepth);
      expect(notifier.state.sortField, isNull);
    });

    test('resizeColumn updates width', () {
      final notifier = TableViewConfigNotifier();
      notifier.resizeColumn(DiveField.siteName, 250);
      final col = notifier.state.columns.firstWhere(
        (c) => c.field == DiveField.siteName,
      );
      expect(col.width, equals(250));
    });

    test('resizeColumn enforces minWidth', () {
      final notifier = TableViewConfigNotifier();
      notifier.resizeColumn(DiveField.siteName, 10); // Below minWidth
      final col = notifier.state.columns.firstWhere(
        (c) => c.field == DiveField.siteName,
      );
      expect(col.width, equals(DiveField.siteName.minWidth));
    });

    test('reorderColumn moves column to new position', () {
      final notifier = TableViewConfigNotifier();
      final fields = notifier.state.columns.map((c) => c.field).toList();
      // Move last column to position 2
      notifier.reorderColumn(fields.length - 1, 2);
      expect(notifier.state.columns[2].field, equals(fields.last));
    });

    test('togglePin pins and unpins a column', () {
      final notifier = TableViewConfigNotifier();
      // dateTime is unpinned by default
      notifier.togglePin(DiveField.dateTime);
      final pinned = notifier.state.columns.firstWhere(
        (c) => c.field == DiveField.dateTime,
      );
      expect(pinned.isPinned, isTrue);

      notifier.togglePin(DiveField.dateTime);
      final unpinned = notifier.state.columns.firstWhere(
        (c) => c.field == DiveField.dateTime,
      );
      expect(unpinned.isPinned, isFalse);
    });

    test('applyPreset replaces config', () {
      final notifier = TableViewConfigNotifier();
      final preset = FieldPreset.builtInTablePresets()
          .firstWhere((p) => p.name == 'Technical');
      notifier.applyPreset(preset);
      expect(
        notifier.state.columns.any((c) => c.field == DiveField.gradientFactorLow),
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/view_config_providers_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement ViewConfig providers**

```dart
// lib/features/dive_log/presentation/providers/view_config_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';

// -- Repository provider --

final viewConfigRepositoryProvider = Provider<ViewConfigRepository>((ref) {
  return ViewConfigRepository(AppDatabase.instance);
});

// -- Table view config --

class TableViewConfigNotifier extends StateNotifier<TableViewConfig> {
  ViewConfigRepository? _repository;
  String? _diverId;
  Timer? _debounceTimer;

  TableViewConfigNotifier() : super(TableViewConfig.defaultConfig());

  void init(ViewConfigRepository repository, String diverId) {
    _repository = repository;
    _diverId = diverId;
    _load();
  }

  Future<void> _load() async {
    if (_repository == null || _diverId == null) return;
    state = await _repository!.getTableConfig(_diverId!);
  }

  void _save() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_repository != null && _diverId != null) {
        _repository!.saveTableConfig(_diverId!, state);
      }
    });
  }

  void toggleColumn(DiveField field) {
    final existing = state.columns.indexWhere((c) => c.field == field);
    if (existing >= 0) {
      // Don't remove pinned columns via toggle
      if (state.columns[existing].isPinned) return;
      final columns = [...state.columns]..removeAt(existing);
      state = state.copyWith(columns: columns);
    } else {
      final columns = [
        ...state.columns,
        TableColumnConfig(field: field),
      ];
      state = state.copyWith(columns: columns);
    }
    _save();
  }

  void setSortField(DiveField field) {
    if (state.sortField == field) {
      if (state.sortAscending) {
        state = state.copyWith(sortField: field, sortAscending: false);
      } else {
        state = state.copyWith(clearSortField: true, sortAscending: true);
      }
    } else {
      state = state.copyWith(sortField: field, sortAscending: true);
    }
    _save();
  }

  void resizeColumn(DiveField field, double width) {
    final clamped = width.clamp(field.minWidth, 600.0);
    final columns = state.columns.map((c) {
      if (c.field == field) return c.copyWith(width: clamped);
      return c;
    }).toList();
    state = state.copyWith(columns: columns);
    _save();
  }

  void reorderColumn(int oldIndex, int newIndex) {
    final columns = [...state.columns];
    if (newIndex > oldIndex) newIndex--;
    final item = columns.removeAt(oldIndex);
    columns.insert(newIndex, item);
    state = state.copyWith(columns: columns);
    _save();
  }

  void togglePin(DiveField field) {
    final columns = state.columns.map((c) {
      if (c.field == field) return c.copyWith(isPinned: !c.isPinned);
      return c;
    }).toList();
    state = state.copyWith(columns: columns);
    _save();
  }

  void applyPreset(FieldPreset preset) {
    state = TableViewConfig.fromJson(preset.configJson);
    _save();
  }

  void replaceConfig(TableViewConfig config) {
    state = config;
    _save();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final tableViewConfigProvider =
    StateNotifierProvider<TableViewConfigNotifier, TableViewConfig>((ref) {
  return TableViewConfigNotifier();
});

// -- Card view config --

class CardViewConfigNotifier extends StateNotifier<CardViewConfig> {
  ViewConfigRepository? _repository;
  String? _diverId;
  Timer? _debounceTimer;

  CardViewConfigNotifier(ListViewMode mode)
      : super(switch (mode) {
          ListViewMode.compact => CardViewConfig.defaultCompact(),
          ListViewMode.dense => CardViewConfig.defaultDense(),
          ListViewMode.detailed => CardViewConfig.defaultDetailed(),
          ListViewMode.table => CardViewConfig.defaultDetailed(),
        });

  void init(ViewConfigRepository repository, String diverId, ListViewMode mode) {
    _repository = repository;
    _diverId = diverId;
    _load(mode);
  }

  Future<void> _load(ListViewMode mode) async {
    if (_repository == null || _diverId == null) return;
    state = await _repository!.getCardConfig(_diverId!, mode);
  }

  void updateSlot(String slotId, DiveField field) {
    final slots = state.slots.map((s) {
      if (s.slotId == slotId) return s.copyWith(field: field);
      return s;
    }).toList();
    state = state.copyWith(slots: slots);
    _save();
  }

  void setExtraFields(List<DiveField> fields) {
    state = state.copyWith(extraFields: fields);
    _save();
  }

  void addExtraField(DiveField field) {
    if (state.extraFields.contains(field)) return;
    state = state.copyWith(extraFields: [...state.extraFields, field]);
    _save();
  }

  void removeExtraField(DiveField field) {
    state = state.copyWith(
      extraFields: state.extraFields.where((f) => f != field).toList(),
    );
    _save();
  }

  void reorderExtraFields(int oldIndex, int newIndex) {
    final fields = [...state.extraFields];
    if (newIndex > oldIndex) newIndex--;
    final item = fields.removeAt(oldIndex);
    fields.insert(newIndex, item);
    state = state.copyWith(extraFields: fields);
    _save();
  }

  void resetToDefault() {
    state = switch (state.mode) {
      ListViewMode.compact => CardViewConfig.defaultCompact(),
      ListViewMode.dense => CardViewConfig.defaultDense(),
      ListViewMode.detailed => CardViewConfig.defaultDetailed(),
      ListViewMode.table => CardViewConfig.defaultDetailed(),
    };
    _save();
  }

  void _save() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_repository != null && _diverId != null) {
        _repository!.saveCardConfig(_diverId!, state);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final compactCardConfigProvider =
    StateNotifierProvider<CardViewConfigNotifier, CardViewConfig>((ref) {
  return CardViewConfigNotifier(ListViewMode.compact);
});

final denseCardConfigProvider =
    StateNotifierProvider<CardViewConfigNotifier, CardViewConfig>((ref) {
  return CardViewConfigNotifier(ListViewMode.dense);
});

final detailedCardConfigProvider =
    StateNotifierProvider<CardViewConfigNotifier, CardViewConfig>((ref) {
  return CardViewConfigNotifier(ListViewMode.detailed);
});

// -- Presets --

final tablePresetsProvider =
    FutureProvider.family<List<FieldPreset>, String>((ref, diverId) async {
  final repo = ref.watch(viewConfigRepositoryProvider);
  await repo.ensureBuiltInPresets(diverId);
  return repo.getPresetsForMode(diverId, ListViewMode.table);
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/providers/view_config_providers_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/providers/view_config_providers.dart test/features/dive_log/presentation/providers/view_config_providers_test.dart
git commit -m "feat(columns): add view config providers with debounced persistence (#56)"
```

---

### Task 6: Add linked_scroll_controller Dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add dependency**

Run: `flutter pub add linked_scroll_controller`
Expected: Package added to pubspec.yaml and downloaded.

- [ ] **Step 2: Verify**

Run: `flutter pub get`
Expected: Clean resolution.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add linked_scroll_controller for table view scroll sync (#56)"
```

---

### Task 7: DiveTableView Widget (Core Rendering)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_table_view.dart`
- Create: `lib/features/dive_log/presentation/widgets/table_header_cell.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_table_view_test.dart`
- Test: `test/features/dive_log/presentation/widgets/table_header_cell_test.dart`

- [ ] **Step 1: Write table view rendering tests**

```dart
// test/features/dive_log/presentation/widgets/dive_table_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_table_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestTableConfigNotifier extends StateNotifier<TableViewConfig>
    implements TableViewConfigNotifier {
  _TestTableConfigNotifier()
      : super(TableViewConfig.defaultConfig());
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Dive _testDive({
  required String id,
  required int number,
  required String siteName,
  double? maxDepth,
  Duration? bottomTime,
}) {
  return Dive(
    id: id,
    diveNumber: number,
    dateTime: DateTime(2026, 3, 15, 10, 0),
    maxDepth: maxDepth,
    bottomTime: bottomTime,
    site: null, // Would need a DiveSite for siteName
    notes: '',
  );
}

void main() {
  group('DiveTableView', () {
    testWidgets('renders header row with column names', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            tableViewConfigProvider.overrideWith(
              (ref) => _TestTableConfigNotifier(),
            ),
          ],
          child: DiveTableView(
            dives: [
              _testDive(id: '1', number: 1, siteName: 'Blue Corner',
                  maxDepth: 30, bottomTime: const Duration(minutes: 45)),
            ],
            onDiveTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render header cells for default columns
      expect(find.text('#'), findsWidgets); // diveNumber shortLabel
    });

    testWidgets('renders one row per dive', (tester) async {
      final dives = List.generate(
        5,
        (i) => _testDive(
          id: 'dive-$i',
          number: i + 1,
          siteName: 'Site $i',
          maxDepth: 20.0 + i,
          bottomTime: Duration(minutes: 40 + i),
        ),
      );

      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            tableViewConfigProvider.overrideWith(
              (ref) => _TestTableConfigNotifier(),
            ),
          ],
          child: DiveTableView(dives: dives, onDiveTap: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Should show dive numbers
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#5'), findsOneWidget);
    });

    testWidgets('calls onDiveTap when row is tapped', (tester) async {
      String? tappedId;
      await tester.pumpWidget(
        testApp(
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            tableViewConfigProvider.overrideWith(
              (ref) => _TestTableConfigNotifier(),
            ),
          ],
          child: DiveTableView(
            dives: [
              _testDive(id: 'dive-1', number: 1, siteName: 'Blue Corner',
                  maxDepth: 30, bottomTime: const Duration(minutes: 45)),
            ],
            onDiveTap: (id) => tappedId = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('#1'));
      expect(tappedId, equals('dive-1'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_table_view_test.dart`
Expected: FAIL — files do not exist.

- [ ] **Step 3: Implement TableHeaderCell widget**

```dart
// lib/features/dive_log/presentation/widgets/table_header_cell.dart
import 'package:flutter/material.dart';
import 'package:submersion/core/constants/dive_field.dart';

/// A single header cell in the table view.
///
/// Displays the field's short label, sort indicator, and resize handle.
class TableHeaderCell extends StatelessWidget {
  final DiveField field;
  final double width;
  final bool isSorted;
  final bool sortAscending;
  final VoidCallback? onTap;
  final ValueChanged<double>? onResize;
  final bool showResizeHandle;

  const TableHeaderCell({
    super.key,
    required this.field,
    required this.width,
    this.isSorted = false,
    this.sortAscending = true,
    this.onTap,
    this.onResize,
    this.showResizeHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;
    final resizeHandleWidth = isDesktop ? 8.0 : 24.0;

    return SizedBox(
      width: width,
      height: 36,
      child: Stack(
        children: [
          // Main cell content
          InkWell(
            onTap: field.sortable ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      field.shortLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSorted
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSorted)
                    Icon(
                      sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
          // Resize handle on right edge
          if (showResizeHandle && onResize != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: resizeHandleWidth,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  onResize?.call(width + details.delta.dx);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: Center(
                    child: Container(
                      width: 1,
                      height: 16,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Implement DiveTableView widget**

```dart
// lib/features/dive_log/presentation/widgets/dive_table_view.dart
import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/table_header_cell.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Full-width data table for dive list with pinned columns and horizontal scroll.
class DiveTableView extends ConsumerStatefulWidget {
  final List<Dive> dives;
  final Map<String, Duration?> surfaceIntervals;
  final void Function(String diveId) onDiveTap;
  final void Function(String diveId)? onDiveLongPress;
  final Set<String> selectedIds;
  final bool isSelectionMode;

  const DiveTableView({
    super.key,
    required this.dives,
    this.surfaceIntervals = const {},
    required this.onDiveTap,
    this.onDiveLongPress,
    this.selectedIds = const {},
    this.isSelectionMode = false,
  });

  @override
  ConsumerState<DiveTableView> createState() => _DiveTableViewState();
}

class _DiveTableViewState extends ConsumerState<DiveTableView> {
  late LinkedScrollControllerGroup _horizontalGroup;
  late ScrollController _headerHorizontalController;
  late ScrollController _bodyHorizontalController;
  static const double _rowHeight = 38.0;

  @override
  void initState() {
    super.initState();
    _horizontalGroup = LinkedScrollControllerGroup();
    _headerHorizontalController = _horizontalGroup.addAndGet();
    _bodyHorizontalController = _horizontalGroup.addAndGet();
  }

  @override
  void dispose() {
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(tableViewConfigProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;

    final pinnedColumns =
        config.columns.where((c) => c.isPinned).toList();
    final scrollableColumns =
        config.columns.where((c) => !c.isPinned).toList();

    final pinnedWidth = pinnedColumns.fold<double>(
      0,
      (sum, c) => sum + c.effectiveWidth,
    );
    final scrollableWidth = scrollableColumns.fold<double>(
      0,
      (sum, c) => sum + c.effectiveWidth,
    );

    // Sort dives if a sort field is set
    final dives = _sortedDives(config, widget.dives);

    return Column(
      children: [
        // Header row
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Pinned headers
              SizedBox(
                width: pinnedWidth,
                child: Row(
                  children: pinnedColumns.map((col) {
                    return TableHeaderCell(
                      field: col.field,
                      width: col.effectiveWidth,
                      isSorted: config.sortField == col.field,
                      sortAscending: config.sortAscending,
                      onTap: () => ref
                          .read(tableViewConfigProvider.notifier)
                          .setSortField(col.field),
                      onResize: (newWidth) => ref
                          .read(tableViewConfigProvider.notifier)
                          .resizeColumn(col.field, newWidth),
                    );
                  }).toList(),
                ),
              ),
              // Scrollable headers
              Expanded(
                child: SingleChildScrollView(
                  controller: _headerHorizontalController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: scrollableColumns.map((col) {
                      return TableHeaderCell(
                        field: col.field,
                        width: col.effectiveWidth,
                        isSorted: config.sortField == col.field,
                        sortAscending: config.sortAscending,
                        onTap: () => ref
                            .read(tableViewConfigProvider.notifier)
                            .setSortField(col.field),
                        onResize: (newWidth) => ref
                            .read(tableViewConfigProvider.notifier)
                            .resizeColumn(col.field, newWidth),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Body rows
        Expanded(
          child: ListView.builder(
            itemCount: dives.length,
            itemExtent: _rowHeight,
            itemBuilder: (context, index) {
              final dive = dives[index];
              final isSelected = widget.selectedIds.contains(dive.id);
              final isEvenRow = index.isEven;

              return InkWell(
                onTap: () => widget.onDiveTap(dive.id),
                onLongPress: widget.onDiveLongPress != null
                    ? () => widget.onDiveLongPress!(dive.id)
                    : null,
                child: Container(
                  height: _rowHeight,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : (isEvenRow
                            ? Colors.transparent
                            : colorScheme.surfaceContainerLowest),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Pinned cells
                      SizedBox(
                        width: pinnedWidth,
                        child: Row(
                          children: pinnedColumns.map((col) {
                            return _buildCell(
                              col, dive, units, colorScheme,
                            );
                          }).toList(),
                        ),
                      ),
                      // Scrollable cells
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _bodyHorizontalController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: scrollableColumns.map((col) {
                              return _buildCell(
                                col, dive, units, colorScheme,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCell(
    TableColumnConfig col,
    Dive dive,
    UnitFormatter units,
    ColorScheme colorScheme,
  ) {
    final value = col.field.extractFromDive(dive);
    final formatted = col.field.formatValue(value, units);

    return SizedBox(
      width: col.effectiveWidth,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: _isNumericField(col.field)
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            formatted,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  bool _isNumericField(DiveField field) {
    return switch (field) {
      DiveField.diveNumber ||
      DiveField.maxDepth ||
      DiveField.avgDepth ||
      DiveField.bottomTime ||
      DiveField.runtime ||
      DiveField.waterTemp ||
      DiveField.airTemp ||
      DiveField.sacRate ||
      DiveField.gasConsumed ||
      DiveField.totalWeight ||
      DiveField.startPressure ||
      DiveField.endPressure ||
      DiveField.ratingStars ||
      DiveField.tankCount =>
        true,
      _ => false,
    };
  }

  List<Dive> _sortedDives(TableViewConfig config, List<Dive> dives) {
    if (config.sortField == null) return dives;

    final field = config.sortField!;
    final ascending = config.sortAscending;
    final sorted = [...dives];
    sorted.sort((a, b) {
      final va = field.extractFromDive(a);
      final vb = field.extractFromDive(b);
      if (va == null && vb == null) return 0;
      if (va == null) return ascending ? 1 : -1;
      if (vb == null) return ascending ? -1 : 1;
      final cmp = (va as Comparable).compareTo(vb as Comparable);
      return ascending ? cmp : -cmp;
    });
    return sorted;
  }
}
```

**Scroll architecture clarification:** The code above shows a simplified row-oriented layout. The actual implementation must use a **column-oriented layout** where:

1. The pinned section is a `Column` with its own `ListView.builder` (controller: `_pinnedVerticalController`)
2. The scrollable section is a `SingleChildScrollView` (horizontal, controller: `_horizontalController`) wrapping a `Column` with its own `ListView.builder` (controller: `_scrollableVerticalController`)
3. The two vertical controllers are synced via `NotificationListener<ScrollNotification>` — when one scrolls, call `jumpTo()` on the other

This avoids the problem of attaching one horizontal controller to many `SingleChildScrollView` widgets (which doesn't work). The `linked_scroll_controller` package is used for the horizontal sync between header and body (only 2 scrollables), while vertical sync uses `NotificationListener`. The implementer should restructure `build()` to use `Row([pinnedColumn, Expanded(horizontalScroll(scrollableColumn))])` instead of per-row horizontal scrolling.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_table_view_test.dart`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_table_view.dart lib/features/dive_log/presentation/widgets/table_header_cell.dart test/features/dive_log/presentation/widgets/dive_table_view_test.dart test/features/dive_log/presentation/widgets/table_header_cell_test.dart
git commit -m "feat(columns): add DiveTableView widget with pinned columns and scroll sync (#56)"
```

---

### Task 8: Integrate Table View into DiveListPage & DiveListContent

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Modify: `lib/shared/widgets/list_view_mode_toggle.dart`

- [ ] **Step 1: Update ListViewModeToggle with table icon**

In `lib/shared/widgets/list_view_mode_toggle.dart`, add `table` case to `_iconForMode()` and `_labelForMode()`:

```dart
// In _iconForMode / _iconForModeStatic:
ListViewMode.table => Icons.table_chart,

// In _labelForMode / _labelForModeStatic:
ListViewMode.table => 'Table',
```

Also add the table mode to the `menuItems()` method so it appears in popup menus.

- [ ] **Step 2: Update DiveListPage for full-width table mode on desktop**

In `lib/features/dive_log/presentation/pages/dive_list_page.dart`, modify the `build` method of `_DiveListPageState`. Before the existing `if (showMasterDetail)` check, add a check for table mode:

```dart
@override
Widget build(BuildContext context) {
  // ... existing filter listener ...

  final showMasterDetail = ResponsiveBreakpoints.isMasterDetail(context);
  final viewMode = ref.watch(diveListViewModeProvider);

  // Table mode: full-width on all screen sizes, no master-detail
  if (viewMode == ListViewMode.table) {
    return DiveListContent(
      showAppBar: true,
      floatingActionButton: fab,
      isMapViewActive: false,
    );
  }

  if (showMasterDetail) {
    // ... existing MasterDetailScaffold code ...
  }
  // ... rest of existing mobile code ...
}
```

This ensures table mode always renders full-width, bypassing `MasterDetailScaffold`.

- [ ] **Step 3: Update DiveListContent with table view branch**

In `lib/features/dive_log/presentation/widgets/dive_list_content.dart`, add the table case to the view mode switch in `_buildDiveList`. Around line 1209:

```dart
// In the switch statement:
ListViewMode.table => DiveTableView(
  dives: fullDives, // Need full Dive objects, see step 4
  onDiveTap: (id) => _handleItemTapById(id),
  onDiveLongPress: _isSelectionMode
      ? null
      : (id) => _enterSelectionMode(id),
  selectedIds: _selectedIds,
  isSelectionMode: _isSelectionMode,
),
```

- [ ] **Step 4: Add a provider for full Dive objects in table mode**

The existing paginated list uses `DiveSummary`. Table mode needs full `Dive` objects for field extraction (SAC, tanks, weights, etc.). Add a provider in `dive_providers.dart`:

```dart
/// Loads all dives as full Dive objects (for table view).
/// Applies the same filters as the paginated list. Sorting is handled
/// by the table widget itself via column header taps.
final allDivesForTableProvider = FutureProvider<List<Dive>>((ref) async {
  final diverId = ref.watch(currentDiverIdProvider);
  if (diverId == null) return [];
  final repo = ref.watch(diveRepositoryProvider);
  final filterState = ref.watch(diveFilterProvider);
  final allDives = await repo.getAllDives(diverId: diverId);
  // Apply filters (same logic as paginated list)
  return filterState.apply(allDives);
});

/// Pre-computed surface intervals for the table view.
/// Maps dive ID to the duration since the previous dive's exit.
final surfaceIntervalsProvider = Provider<Map<String, Duration?>>((ref) {
  final divesAsync = ref.watch(allDivesForTableProvider);
  return divesAsync.whenOrNull(data: (dives) {
    final sorted = [...dives]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final intervals = <String, Duration?>{};
    for (var i = 0; i < sorted.length; i++) {
      if (i == 0) {
        intervals[sorted[i].id] = null;
      } else {
        final prevExit = sorted[i - 1].exitTime ?? sorted[i - 1].dateTime;
        final thisEntry = sorted[i].entryTime ?? sorted[i].dateTime;
        intervals[sorted[i].id] = thisEntry.difference(prevExit);
      }
    }
    return intervals;
  }) ?? {};
});
```

In `DiveListContent`, when `viewMode == table`, watch `allDivesForTableProvider` instead of `paginatedDiveListProvider` and pass the `List<Dive>` to `DiveTableView`.

- [ ] **Step 5: Run existing dive list tests to verify no regressions**

Run: `flutter test test/features/dive_log/presentation/pages/dive_list_page_test.dart`
Expected: All existing tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/list_view_mode_toggle.dart lib/features/dive_log/presentation/pages/dive_list_page.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart lib/features/dive_log/presentation/providers/dive_providers.dart
git commit -m "feat(columns): integrate table view into dive list with full-width desktop layout (#56)"
```

---

### Task 9: Card View Customization — Detailed Tile Extra Fields

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (DiveListTile)

- [ ] **Step 1: Write test for extra fields rendering**

```dart
// Add to test/features/dive_log/presentation/pages/dive_list_page_test.dart
testWidgets('DiveListTile renders extra fields when configured', (tester) async {
  // Test that when detailedCardConfigProvider has extraFields,
  // the tile renders label:value pairs below the main content
  // This requires setting up a provider override with extra fields
});
```

- [ ] **Step 2: Add extra fields area to DiveListTile**

In `lib/features/dive_log/presentation/pages/dive_list_page.dart`, modify the `DiveListTile` widget's `build` method. After the tags section (around line 600+), add:

```dart
// Extra configurable fields area
if (extraFields.isNotEmpty) ...[
  const SizedBox(height: 4),
  Padding(
    padding: const EdgeInsets.only(left: 52),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final useOneColumn = constraints.maxWidth < 250;
        final crossAxisCount = useOneColumn ? 1 : 2;
        return Wrap(
          spacing: 16,
          runSpacing: 4,
          children: extraFields.map((field) {
            final value = field.extractFromSummary(summary);
            final formatted = field.formatValue(value, units);
            return SizedBox(
              width: useOneColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${field.shortLabel}: ',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      formatted,
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    ),
  ),
],
```

The `extraFields` list comes from watching `detailedCardConfigProvider`:

```dart
final detailedConfig = ref.watch(detailedCardConfigProvider);
final extraFields = detailedConfig.extraFields;
```

The `DiveListTile` also needs a `DiveSummary summary` parameter (or the existing fields) to extract values from.

- [ ] **Step 3: Run tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_list_page_test.dart`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_list_page.dart
git commit -m "feat(columns): add configurable extra fields area to detailed dive card (#56)"
```

---

### Task 10: Card View Customization — Compact & Dense Tiles

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart`

- [ ] **Step 1: Update CompactDiveListTile to accept slot config**

Add a `CardViewConfig?` parameter (or individual slot field parameters) to `CompactDiveListTile`. When provided, use the slot assignments to determine what data shows in each position:

```dart
// New parameters:
final DiveField titleField;    // Default: DiveField.siteName
final DiveField dateField;     // Default: DiveField.dateTime
final DiveField stat1Field;    // Default: DiveField.maxDepth
final DiveField stat2Field;    // Default: DiveField.bottomTime

// In the build method, for each slot:
// Instead of hardcoded `siteName ?? context.l10n.unknownSite`:
final titleValue = titleField.extractFromSummary(summary);
final titleFormatted = titleField == DiveField.siteName
    ? (titleValue as String? ?? context.l10n.unknownSite)
    : titleField.formatValue(titleValue, units);

// For stat slots, use icon-with-fallback pattern:
Widget _buildStatSlot(DiveField field, dynamic value, UnitFormatter units) {
  final formatted = field.formatValue(value, units);
  final icon = field.icon;
  if (icon != null) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: secondaryTextColor),
        const SizedBox(width: 4),
        Text(formatted, style: statTextStyle),
      ],
    );
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('${field.shortLabel}: ', style: labelTextStyle),
      Text(formatted, style: statTextStyle),
    ],
  );
}
```

- [ ] **Step 2: Update DenseDiveListTile similarly**

Same approach: accept slot field parameters, use `extractFromSummary` + `formatValue`, icon-with-fallback for display.

- [ ] **Step 3: Update DiveListContent to pass slot configs to tiles**

In `dive_list_content.dart`, where tiles are instantiated, read the card config provider and pass slot fields:

```dart
final compactConfig = ref.watch(compactCardConfigProvider);
final denseConfig = ref.watch(denseCardConfigProvider);

// In the switch:
ListViewMode.compact => CompactDiveListTile(
  // ... existing params ...
  titleField: compactConfig.slots.firstWhere((s) => s.slotId == 'title').field,
  dateField: compactConfig.slots.firstWhere((s) => s.slotId == 'date').field,
  stat1Field: compactConfig.slots.firstWhere((s) => s.slotId == 'stat1').field,
  stat2Field: compactConfig.slots.firstWhere((s) => s.slotId == 'stat2').field,
  summary: dive, // DiveSummary
),
```

- [ ] **Step 4: Run existing tile tests**

Run: `flutter test test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart test/features/dive_log/presentation/widgets/dense_dive_list_tile_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart lib/features/dive_log/presentation/widgets/dense_dive_list_tile.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart
git commit -m "feat(columns): add configurable slot fields to compact and dense card tiles (#56)"
```

---

### Task 11: Inline Column Picker (Table Gear Icon)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/table_column_picker.dart`

- [ ] **Step 1: Implement TableColumnPicker widget**

```dart
// lib/features/dive_log/presentation/widgets/table_column_picker.dart
import 'package:flutter/material.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';

/// Bottom sheet / popover for quickly toggling column visibility in the table view.
class TableColumnPicker extends ConsumerWidget {
  const TableColumnPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tableViewConfigProvider);
    final visibleFields = config.columns.map((c) => c.field).toSet();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Columns',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Field list grouped by category
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: DiveFieldCategory.values.map((category) {
                    final fields = DiveField.fieldsForCategory(category);
                    if (fields.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            category.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...fields.map((field) {
                          final isVisible = visibleFields.contains(field);
                          final isPinned = config.columns
                              .any((c) => c.field == field && c.isPinned);

                          return CheckboxListTile(
                            dense: true,
                            value: isVisible,
                            onChanged: isPinned
                                ? null // Don't allow hiding pinned columns
                                : (_) => ref
                                    .read(tableViewConfigProvider.notifier)
                                    .toggleColumn(field),
                            title: Text(
                              field.shortLabel,
                              style: const TextStyle(fontSize: 14),
                            ),
                            secondary: field.icon != null
                                ? Icon(field.icon, size: 18)
                                : null,
                          );
                        }),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shows the column picker as a bottom sheet.
void showTableColumnPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const TableColumnPicker(),
  );
}
```

- [ ] **Step 2: Add gear icon to DiveTableView**

In `dive_table_view.dart`, add a gear icon button in the header row (top-right). When tapped, call `showTableColumnPicker(context)`.

```dart
// In the header Row, add after the scrollable headers:
// A gear icon overlaid at the top-right
Positioned(
  right: 0,
  top: 0,
  child: Container(
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest,
    ),
    child: IconButton(
      icon: const Icon(Icons.settings, size: 18),
      tooltip: 'Configure columns',
      onPressed: () => showTableColumnPicker(context),
      visualDensity: VisualDensity.compact,
    ),
  ),
),
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/table_column_picker.dart lib/features/dive_log/presentation/widgets/dive_table_view.dart
git commit -m "feat(columns): add inline column picker with category-grouped field toggles (#56)"
```

---

### Task 12: Column Configuration Settings Page

**Files:**
- Create: `lib/features/settings/presentation/pages/column_config_page.dart`
- Modify: `lib/features/settings/presentation/pages/appearance_page.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Create ColumnConfigPage**

```dart
// lib/features/settings/presentation/pages/column_config_page.dart
import 'package:flutter/material.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';

class ColumnConfigPage extends ConsumerStatefulWidget {
  const ColumnConfigPage({super.key});

  @override
  ConsumerState<ColumnConfigPage> createState() => _ColumnConfigPageState();
}

class _ColumnConfigPageState extends ConsumerState<ColumnConfigPage> {
  ListViewMode _selectedMode = ListViewMode.table;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Column Configuration'),
      ),
      body: Column(
        children: [
          // View mode selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<ListViewMode>(
              value: _selectedMode,
              decoration: const InputDecoration(
                labelText: 'View Mode',
                border: OutlineInputBorder(),
              ),
              items: ListViewMode.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(mode.name[0].toUpperCase() + mode.name.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedMode = value);
              },
            ),
          ),
          const Divider(),
          // Mode-specific configuration
          Expanded(
            child: switch (_selectedMode) {
              ListViewMode.table => const _TableColumnConfigSection(),
              ListViewMode.detailed => const _DetailedCardConfigSection(),
              ListViewMode.compact => const _SlotCardConfigSection(
                mode: ListViewMode.compact,
              ),
              ListViewMode.dense => const _SlotCardConfigSection(
                mode: ListViewMode.dense,
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// Table mode: drag-to-reorder visible columns, add from available fields.
class _TableColumnConfigSection extends ConsumerWidget {
  const _TableColumnConfigSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(tableViewConfigProvider);
    final visibleFields = config.columns.map((c) => c.field).toSet();

    return ListView(
      children: [
        // Preset bar (future: add preset dropdown + save/load)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'VISIBLE COLUMNS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Reorderable list of visible columns
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: config.columns.length,
          onReorder: (oldIndex, newIndex) {
            ref
                .read(tableViewConfigProvider.notifier)
                .reorderColumn(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final col = config.columns[index];
            return ListTile(
              key: ValueKey(col.field),
              leading: const Icon(Icons.drag_handle),
              title: Text(col.field.shortLabel),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pin toggle
                  IconButton(
                    icon: Icon(
                      col.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 18,
                    ),
                    onPressed: () => ref
                        .read(tableViewConfigProvider.notifier)
                        .togglePin(col.field),
                  ),
                  // Remove
                  if (!col.isPinned)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () => ref
                          .read(tableViewConfigProvider.notifier)
                          .toggleColumn(col.field),
                    ),
                ],
              ),
            );
          },
        ),
        const Divider(),
        // Available (hidden) fields grouped by category
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'AVAILABLE FIELDS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...DiveFieldCategory.values.expand((category) {
          final fields = DiveField.fieldsForCategory(category)
              .where((f) => !visibleFields.contains(f))
              .toList();
          if (fields.isEmpty) return <Widget>[];

          return [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                category.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ...fields.map((field) => ListTile(
                  dense: true,
                  leading: field.icon != null
                      ? Icon(field.icon, size: 18)
                      : null,
                  title: Text(field.shortLabel),
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    onPressed: () => ref
                        .read(tableViewConfigProvider.notifier)
                        .toggleColumn(field),
                  ),
                )),
          ];
        }),
        const SizedBox(height: 16),
        // Reset button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            onPressed: () => ref
                .read(tableViewConfigProvider.notifier)
                .replaceConfig(TableViewConfig.defaultConfig()),
            child: const Text('Reset to Default'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Detailed card mode: extra fields drag-to-reorder list.
class _DetailedCardConfigSection extends ConsumerWidget {
  const _DetailedCardConfigSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(detailedCardConfigProvider);
    final availableFields = DiveField.summaryFields
        .where((f) => !config.extraFields.contains(f))
        .toList();

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'EXTRA FIELDS (shown below main card content)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        if (config.extraFields.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No extra fields configured. Add fields below to show additional data on the detailed card.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: config.extraFields.length,
          onReorder: (oldIndex, newIndex) {
            ref
                .read(detailedCardConfigProvider.notifier)
                .reorderExtraFields(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final field = config.extraFields[index];
            return ListTile(
              key: ValueKey(field),
              leading: const Icon(Icons.drag_handle),
              title: Text(field.shortLabel),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                onPressed: () => ref
                    .read(detailedCardConfigProvider.notifier)
                    .removeExtraField(field),
              ),
            );
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'AVAILABLE FIELDS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        ...availableFields.map((field) => ListTile(
              dense: true,
              leading: field.icon != null ? Icon(field.icon, size: 18) : null,
              title: Text(field.shortLabel),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                onPressed: () => ref
                    .read(detailedCardConfigProvider.notifier)
                    .addExtraField(field),
              ),
            )),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            onPressed: () => ref
                .read(detailedCardConfigProvider.notifier)
                .resetToDefault(),
            child: const Text('Reset to Default'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Compact/Dense card mode: slot assignment dropdowns.
class _SlotCardConfigSection extends ConsumerWidget {
  final ListViewMode mode;
  const _SlotCardConfigSection({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mode == ListViewMode.compact
        ? compactCardConfigProvider
        : denseCardConfigProvider;
    final config = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final availableFields = DiveField.summaryFields.toList();

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'SLOT ASSIGNMENTS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        ...config.slots.map((slot) => ListTile(
              title: Text(_slotDisplayName(slot.slotId)),
              trailing: DropdownButton<DiveField>(
                value: slot.field,
                underline: const SizedBox(),
                onChanged: (field) {
                  if (field != null) {
                    notifier.updateSlot(slot.slotId, field);
                  }
                },
                items: availableFields.map((f) {
                  return DropdownMenuItem(
                    value: f,
                    child: Text(f.shortLabel),
                  );
                }).toList(),
              ),
            )),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            onPressed: () => notifier.resetToDefault(),
            child: const Text('Reset to Default'),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  String _slotDisplayName(String slotId) {
    return switch (slotId) {
      'title' => 'Title',
      'date' => 'Date / Subtitle',
      'stat1' => 'Stat 1',
      'stat2' => 'Stat 2',
      'slot1' => 'Column 1',
      'slot2' => 'Column 2',
      'slot3' => 'Column 3',
      'slot4' => 'Column 4',
      _ => slotId,
    };
  }
}
```

- [ ] **Step 2: Add Column Configuration link to AppearancePage**

In `lib/features/settings/presentation/pages/appearance_page.dart`, add a new `ListTile` under the "Dive Log" section (after the map background toggle):

```dart
ListTile(
  leading: const Icon(Icons.view_column),
  title: const Text('Column Configuration'),
  subtitle: const Text('Customize fields shown in dive list views'),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push('/settings/appearance/column-config'),
),
```

- [ ] **Step 3: Add route in app_router.dart**

Under the `appearance` route's `routes:` list, add:

```dart
GoRoute(
  path: 'column-config',
  name: 'columnConfig',
  builder: (context, state) => const ColumnConfigPage(),
),
```

- [ ] **Step 4: Run the app manually to verify navigation**

Run: `flutter run -d macos`
Navigate: Settings > Appearance > Column Configuration. Verify the page loads and shows the view mode selector.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/pages/column_config_page.dart lib/features/settings/presentation/pages/appearance_page.dart lib/core/router/app_router.dart
git commit -m "feat(columns): add Column Configuration settings page with full field management (#56)"
```

---

### Task 13: Preset Management

**Files:**
- Modify: `lib/features/settings/presentation/pages/column_config_page.dart`
- Modify: `lib/features/dive_log/presentation/widgets/table_column_picker.dart`

- [ ] **Step 1: Add preset bar to table config section**

In the `_TableColumnConfigSection` widget in `column_config_page.dart`, add a preset bar above the visible columns list:

```dart
// Preset bar
Padding(
  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
  child: Row(
    children: [
      Expanded(
        child: _PresetDropdown(
          presets: presets,
          onSelected: (preset) => ref
              .read(tableViewConfigProvider.notifier)
              .applyPreset(preset),
        ),
      ),
      const SizedBox(width: 8),
      TextButton(
        onPressed: () => _showSavePresetDialog(context, ref),
        child: const Text('Save As'),
      ),
    ],
  ),
),
```

- [ ] **Step 2: Implement save/delete preset dialogs**

Add a method `_showSavePresetDialog` that shows a dialog asking for a name, then calls `repo.savePreset()` with the current config. Add delete functionality for non-built-in presets.

- [ ] **Step 3: Add preset dropdown to inline column picker**

In `table_column_picker.dart`, add a preset dropdown at the top of the picker, before the field list. When a preset is selected, apply it via `tableViewConfigProvider.notifier.applyPreset()`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/presentation/pages/column_config_page.dart lib/features/dive_log/presentation/widgets/table_column_picker.dart
git commit -m "feat(columns): add preset management with save, load, and delete (#56)"
```

---

### Task 14: L10n Strings & Final Polish

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (and other language files)
- Modify: Various files to use l10n strings

- [ ] **Step 1: Add English l10n strings**

Add all new strings to `lib/l10n/arb/app_en.arb`:

```json
"settings_appearance_columnConfig": "Column Configuration",
"settings_appearance_columnConfig_subtitle": "Customize fields shown in dive list views",
"columnConfig_title": "Column Configuration",
"columnConfig_viewMode": "View Mode",
"columnConfig_visibleColumns": "Visible Columns",
"columnConfig_availableFields": "Available Fields",
"columnConfig_extraFields": "Extra Fields",
"columnConfig_slotAssignments": "Slot Assignments",
"columnConfig_resetToDefault": "Reset to Default",
"columnConfig_presetSaveAs": "Save As",
"columnConfig_presetName": "Preset Name",
"columnConfig_presetSave": "Save",
"columnConfig_presetDelete": "Delete",
"columnConfig_columns": "Columns",
"columnConfig_done": "Done",
"diveField_category_core": "Core",
"diveField_category_environment": "Environment",
"diveField_category_gas": "Gas",
"diveField_category_tank": "Tank",
"diveField_category_weight": "Weight",
"diveField_category_equipment": "Equipment",
"diveField_category_deco": "Decompression",
"diveField_category_physiology": "Physiology",
"diveField_category_rebreather": "Rebreather",
"diveField_category_people": "People",
"diveField_category_location": "Location",
"diveField_category_trip": "Trip",
"diveField_category_rating": "Rating",
"diveField_category_metadata": "Metadata"
```

- [ ] **Step 2: Add strings to other language .arb files**

Add the same keys to all 10 other `.arb` files with the English values as placeholders (to be translated later).

- [ ] **Step 3: Run code generation**

Run: `flutter gen-l10n`
Expected: Localization classes regenerated.

- [ ] **Step 4: Replace hardcoded strings with l10n references**

Go through `column_config_page.dart`, `table_column_picker.dart`, and other new files and replace hardcoded English strings with `context.l10n.keyName` calls.

- [ ] **Step 5: Run dart format**

Run: `dart format lib/ test/`
Expected: All files formatted.

- [ ] **Step 6: Run full test suite**

Run: `flutter test`
Expected: All tests PASS.

- [ ] **Step 7: Run analyze**

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 8: Commit**

```bash
git add lib/l10n/ lib/features/settings/presentation/pages/column_config_page.dart lib/features/dive_log/presentation/widgets/table_column_picker.dart
git commit -m "feat(columns): add l10n strings and apply formatting polish (#56)"
```

---

## Summary

| Task | Description | Key Files |
|------|------------|-----------|
| 1 | DiveField enum + metadata | `lib/core/constants/dive_field.dart` |
| 2 | Config model classes | `lib/features/dive_log/domain/entities/view_field_config.dart` |
| 3 | DB schema + migration | `lib/core/database/database.dart`, `list_view_mode.dart` |
| 4 | View config repository | `lib/features/dive_log/data/repositories/view_config_repository.dart` |
| 5 | View config providers | `lib/features/dive_log/presentation/providers/view_config_providers.dart` |
| 6 | linked_scroll_controller dep | `pubspec.yaml` |
| 7 | DiveTableView widget | `lib/features/dive_log/presentation/widgets/dive_table_view.dart` |
| 8 | DiveListPage/Content integration | `dive_list_page.dart`, `dive_list_content.dart` |
| 9 | Detailed card extra fields | `dive_list_page.dart` (DiveListTile) |
| 10 | Compact + dense slot customization | `compact_dive_list_tile.dart`, `dense_dive_list_tile.dart` |
| 11 | Inline column picker | `table_column_picker.dart` |
| 12 | Column config settings page | `column_config_page.dart`, `appearance_page.dart`, `app_router.dart` |
| 13 | Preset management | `column_config_page.dart`, `table_column_picker.dart` |
| 14 | L10n + polish | `app_en.arb`, formatting pass |
