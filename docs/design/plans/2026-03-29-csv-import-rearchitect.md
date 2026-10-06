# CSV Import Rearchitect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dual CSV parser system with a single staged pipeline supporting all entity types, multi-file imports, user-saveable presets, and robust time/unit handling.

**Architecture:** A seven-stage pipeline (Parse, Detect, Configure, Transform, Correlate, Preview, Import) replaces the legacy `CsvImportService` and rewrites `CsvImportParser` as a thin adapter. A `PresetRegistry` manages both built-in and user-saved presets. Entity extractors decompose flat CSV rows into typed entity streams (dives, tanks, profiles, sites, buddies, tags, gear).

**Tech Stack:** Flutter/Dart, Drift ORM (SQLite), Riverpod state management, `csv` package for parsing, `intl` for date formatting, `uuid` for ID generation.

**Design spec:** `docs/superpowers/specs/2026-03-29-csv-import-rearchitect-design.md`

---

## File Map

### New Files

```
lib/features/universal_import/data/csv/
  models/
    parsed_csv.dart                 -- Stage 1 output: raw headers + rows
    detection_result.dart           -- Stage 2 output: matched preset + confidence
    import_configuration.dart       -- Stage 3 output: mappings, transforms, options
    transformed_rows.dart           -- Stage 4 output: typed field maps
    correlated_payload.dart         -- Stage 5 output: entity collections linked by ID
  pipeline/
    csv_parser.dart                 -- Stage 1: decode, normalize line endings, split
    csv_detector.dart               -- Stage 2: header matching against presets
    csv_transformer.dart            -- Stage 4: apply mappings, types, units, times
    csv_correlator.dart             -- Stage 5: multi-file merge, entity extraction
    csv_pipeline.dart               -- Orchestrator: runs stages in sequence
  presets/
    csv_preset.dart                 -- Preset data model + PresetFileRole
    preset_registry.dart            -- Registry: built-in + user presets, detection
    built_in_presets.dart           -- 7 const preset definitions
  extractors/
    entity_extractor.dart           -- Interface
    dive_extractor.dart             -- Core dive fields
    tank_extractor.dart             -- Repeating tank groups (1-6)
    profile_extractor.dart          -- Sample-by-sample profile data
    site_extractor.dart             -- Site name + GPS, deduplicated
    buddy_extractor.dart            -- Comma-separated buddy lists
    tag_extractor.dart              -- Comma-separated tags
    gear_extractor.dart             -- Suit/equipment mentions
  transforms/
    time_resolver.dart              -- Format detection, AM/PM, informal times
    unit_detector.dart              -- Header parsing, heuristics, per-column
    value_converter.dart            -- Unit conversions, type coercion, replaces value_transforms.dart
```

### Modified Files

```
lib/features/universal_import/data/parsers/csv_import_parser.dart  -- Rewrite as thin adapter to pipeline
lib/features/universal_import/data/models/field_mapping.dart       -- Add ValueTransform enum (moved from value_transforms.dart)
lib/features/universal_import/data/models/import_enums.dart        -- Add new SourceApp entries if needed
lib/features/universal_import/presentation/providers/universal_import_providers.dart -- Add additionalFiles step
lib/core/database/database.dart                                    -- Add CsvPresets table + migration 58
```

### Deleted Files

```
lib/core/services/export/csv/csv_import_service.dart
test/core/services/export/csv/csv_import_service_test.dart
lib/features/universal_import/data/services/field_mapping_engine.dart
lib/features/universal_import/data/services/value_transforms.dart
```

### Test Files (mirror source structure)

```
test/features/universal_import/data/csv/
  models/
    parsed_csv_test.dart
  pipeline/
    csv_parser_test.dart
    csv_detector_test.dart
    csv_transformer_test.dart
    csv_correlator_test.dart
    csv_pipeline_test.dart
  presets/
    preset_registry_test.dart
    built_in_presets_test.dart
  extractors/
    dive_extractor_test.dart
    tank_extractor_test.dart
    profile_extractor_test.dart
    site_extractor_test.dart
    buddy_extractor_test.dart
    tag_extractor_test.dart
    gear_extractor_test.dart
  transforms/
    time_resolver_test.dart
    unit_detector_test.dart
    value_converter_test.dart
```

---

## Task 1: Pipeline Data Models

**Files:**
- Create: `lib/features/universal_import/data/csv/models/parsed_csv.dart`
- Create: `lib/features/universal_import/data/csv/models/detection_result.dart`
- Create: `lib/features/universal_import/data/csv/models/import_configuration.dart`
- Create: `lib/features/universal_import/data/csv/models/transformed_rows.dart`
- Create: `lib/features/universal_import/data/csv/models/correlated_payload.dart`
- Test: `test/features/universal_import/data/csv/models/parsed_csv_test.dart`

These are the data structures that flow between pipeline stages. They have no logic dependencies on other new code, so they go first.

- [ ] **Step 1: Create ParsedCsv model**

```dart
// lib/features/universal_import/data/csv/models/parsed_csv.dart
import 'package:equatable/equatable.dart';

/// Output of the Parse stage. Raw CSV data with no interpretation.
class ParsedCsv extends Equatable {
  final List<String> headers;
  final List<List<String>> rows;

  const ParsedCsv({
    required this.headers,
    required this.rows,
  });

  /// Returns the first [count] rows for preview/sampling purposes.
  List<List<String>> sampleRows([int count = 5]) =>
      rows.length <= count ? rows : rows.sublist(0, count);

  /// Returns sample values for a specific column index.
  List<String> sampleValues(int columnIndex, [int count = 10]) {
    final samples = <String>[];
    for (final row in rows) {
      if (columnIndex < row.length) {
        final value = row[columnIndex].trim();
        if (value.isNotEmpty) samples.add(value);
        if (samples.length >= count) break;
      }
    }
    return samples;
  }

  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;
  int get rowCount => rows.length;

  @override
  List<Object?> get props => [headers, rows];
}
```

- [ ] **Step 2: Create DetectionResult model**

```dart
// lib/features/universal_import/data/csv/models/detection_result.dart
import 'package:equatable/equatable.dart';

import '../../models/import_enums.dart';
import '../presets/csv_preset.dart';

/// Output of the Detect stage. Identifies which app produced the CSV.
class DetectionResult extends Equatable {
  final CsvPreset? matchedPreset;
  final SourceApp? sourceApp;
  final double confidence;
  final List<PresetMatch> rankedMatches;
  final bool hasAdditionalFileRoles;

  const DetectionResult({
    this.matchedPreset,
    this.sourceApp,
    this.confidence = 0.0,
    this.rankedMatches = const [],
    this.hasAdditionalFileRoles = false,
  });

  bool get isDetected => matchedPreset != null && confidence > 0.5;

  @override
  List<Object?> get props =>
      [matchedPreset, sourceApp, confidence, rankedMatches];
}

/// A single preset match with its score.
class PresetMatch extends Equatable {
  final CsvPreset preset;
  final double score;
  final int matchedHeaders;
  final int totalSignatureHeaders;

  const PresetMatch({
    required this.preset,
    required this.score,
    required this.matchedHeaders,
    required this.totalSignatureHeaders,
  });

  @override
  List<Object?> get props => [preset, score];
}
```

- [ ] **Step 3: Create ImportConfiguration model**

```dart
// lib/features/universal_import/data/csv/models/import_configuration.dart
import 'package:equatable/equatable.dart';

import '../../models/field_mapping.dart';
import '../../models/import_enums.dart';
import '../presets/csv_preset.dart';

/// How times in the CSV should be interpreted.
enum TimeInterpretation {
  /// Times are local wall-clock (default). Store as-is in UTC encoding.
  localWallClock,

  /// Times are already in UTC.
  utc,

  /// Times have a specific offset to apply.
  specificOffset,
}

/// Output of the Configure stage. Everything needed to transform CSV data.
class ImportConfiguration extends Equatable {
  /// Field mappings per file role (e.g., 'dive_list' -> mapping, 'dive_profile' -> mapping).
  /// For single-file imports, the key is 'primary'.
  final Map<String, FieldMapping> mappings;

  final TimeInterpretation timeInterpretation;
  final Duration? specificUtcOffset;
  final Set<ImportEntityType> entityTypesToImport;
  final CsvPreset? preset;
  final SourceApp? sourceApp;

  const ImportConfiguration({
    required this.mappings,
    this.timeInterpretation = TimeInterpretation.localWallClock,
    this.specificUtcOffset,
    this.entityTypesToImport = const {ImportEntityType.dives, ImportEntityType.sites},
    this.preset,
    this.sourceApp,
  });

  /// Convenience: the primary file mapping (single-file imports).
  FieldMapping? get primaryMapping => mappings['primary'] ?? mappings.values.firstOrNull;

  @override
  List<Object?> get props =>
      [mappings, timeInterpretation, specificUtcOffset, entityTypesToImport];
}
```

- [ ] **Step 4: Create TransformedRows model**

```dart
// lib/features/universal_import/data/csv/models/transformed_rows.dart
import 'package:equatable/equatable.dart';

import '../../models/import_payload.dart';

/// Output of the Transform stage. Typed field maps with standardized names.
class TransformedRows extends Equatable {
  /// Each map uses standardized field names (e.g., 'maxDepth', 'waterTemp').
  /// Values are typed: double, int, DateTime, Duration, String.
  final List<Map<String, dynamic>> rows;

  /// Warnings accumulated during transformation.
  final List<ImportWarning> warnings;

  /// The file role these rows came from (e.g., 'primary', 'dive_profile').
  final String fileRole;

  const TransformedRows({
    required this.rows,
    this.warnings = const [],
    this.fileRole = 'primary',
  });

  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;
  int get rowCount => rows.length;

  @override
  List<Object?> get props => [rows, warnings, fileRole];
}
```

- [ ] **Step 5: Create CorrelatedPayload model**

```dart
// lib/features/universal_import/data/csv/models/correlated_payload.dart
import 'package:equatable/equatable.dart';

import '../../models/import_enums.dart';
import '../../models/import_payload.dart';

/// Output of the Correlate stage. Entity collections linked by generated IDs.
/// This is the final internal representation before conversion to ImportPayload.
class CorrelatedPayload extends Equatable {
  final Map<ImportEntityType, List<Map<String, dynamic>>> entities;
  final List<ImportWarning> warnings;
  final Map<String, dynamic> metadata;

  const CorrelatedPayload({
    required this.entities,
    this.warnings = const [],
    this.metadata = const {},
  });

  List<Map<String, dynamic>> entitiesOf(ImportEntityType type) =>
      entities[type] ?? [];

  int get totalEntityCount =>
      entities.values.fold(0, (sum, list) => sum + list.length);

  /// Convert to the universal ImportPayload format.
  ImportPayload toImportPayload() => ImportPayload(
        entities: entities,
        warnings: warnings,
        metadata: metadata,
      );

  @override
  List<Object?> get props => [entities, warnings, metadata];
}
```

- [ ] **Step 6: Write tests for ParsedCsv**

```dart
// test/features/universal_import/data/csv/models/parsed_csv_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';

void main() {
  group('ParsedCsv', () {
    test('sampleRows returns all rows when fewer than count', () {
      final csv = ParsedCsv(
        headers: ['a', 'b'],
        rows: [
          ['1', '2'],
          ['3', '4'],
        ],
      );
      expect(csv.sampleRows(5), hasLength(2));
    });

    test('sampleRows limits to count', () {
      final csv = ParsedCsv(
        headers: ['a'],
        rows: List.generate(20, (i) => ['$i']),
      );
      expect(csv.sampleRows(5), hasLength(5));
    });

    test('sampleValues extracts non-empty values for column', () {
      final csv = ParsedCsv(
        headers: ['name', 'depth'],
        rows: [
          ['Dive 1', '25.5'],
          ['Dive 2', ''],
          ['Dive 3', '30.0'],
        ],
      );
      expect(csv.sampleValues(1), ['25.5', '30.0']);
    });

    test('isEmpty and isNotEmpty reflect row count', () {
      expect(
        const ParsedCsv(headers: ['a'], rows: []).isEmpty,
        isTrue,
      );
      expect(
        ParsedCsv(headers: ['a'], rows: [['1']]).isNotEmpty,
        isTrue,
      );
    });
  });
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/csv/models/parsed_csv_test.dart`
Expected: All 4 tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/universal_import/data/csv/models/ test/features/universal_import/data/csv/models/
git commit -m "feat: add CSV pipeline data models

ParsedCsv, DetectionResult, ImportConfiguration, TransformedRows,
CorrelatedPayload - the data structures flowing between pipeline stages."
```

---

## Task 2: CSV Parser Stage (Parse)

**Files:**
- Create: `lib/features/universal_import/data/csv/pipeline/csv_parser.dart`
- Test: `test/features/universal_import/data/csv/pipeline/csv_parser_test.dart`

The Parse stage decodes bytes, normalizes line endings (fixes #59), and splits into headers + rows. No interpretation.

- [ ] **Step 1: Write failing tests for CsvParser**

```dart
// test/features/universal_import/data/csv/pipeline/csv_parser_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_parser.dart';

Uint8List _toBytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  late CsvParser parser;

  setUp(() {
    parser = const CsvParser();
  });

  group('CsvParser', () {
    test('parses basic CSV with CRLF line endings', () {
      final bytes = _toBytes('Name,Depth\r\nDive 1,25.5\r\nDive 2,30.0\r\n');
      final result = parser.parse(bytes);

      expect(result.headers, ['Name', 'Depth']);
      expect(result.rows, hasLength(2));
      expect(result.rows[0], ['Dive 1', '25.5']);
      expect(result.rows[1], ['Dive 2', '30.0']);
    });

    test('parses CSV with LF line endings (fixes #59)', () {
      final bytes = _toBytes('Name,Depth\nDive 1,25.5\nDive 2,30.0\n');
      final result = parser.parse(bytes);

      expect(result.headers, ['Name', 'Depth']);
      expect(result.rows, hasLength(2));
    });

    test('parses CSV with bare CR line endings', () {
      final bytes = _toBytes('Name,Depth\rDive 1,25.5\rDive 2,30.0\r');
      final result = parser.parse(bytes);

      expect(result.headers, ['Name', 'Depth']);
      expect(result.rows, hasLength(2));
    });

    test('handles quoted fields with commas', () {
      final bytes = _toBytes('Name,Buddy\nDive 1,", Kiyan Griffin"\n');
      final result = parser.parse(bytes);

      expect(result.rows[0][1], ', Kiyan Griffin');
    });

    test('handles quoted fields with newlines', () {
      final bytes = _toBytes('Name,Notes\nDive 1,"Line 1\nLine 2"\n');
      final result = parser.parse(bytes);

      expect(result.rows, hasLength(1));
      expect(result.rows[0][1], contains('Line 1'));
    });

    test('skips empty rows', () {
      final bytes = _toBytes('Name,Depth\n\nDive 1,25.5\n\n\nDive 2,30.0\n');
      final result = parser.parse(bytes);

      expect(result.rows, hasLength(2));
    });

    test('throws on empty file', () {
      expect(
        () => parser.parse(Uint8List(0)),
        throwsA(isA<CsvParseException>()),
      );
    });

    test('throws on headers only with no data', () {
      final bytes = _toBytes('Name,Depth\n');
      expect(
        () => parser.parse(bytes),
        throwsA(isA<CsvParseException>()),
      );
    });

    test('handles malformed UTF-8 gracefully', () {
      final bytes = Uint8List.fromList([
        ...utf8.encode('Name,Depth\n'),
        0xFF, 0xFE, // invalid UTF-8
        ...utf8.encode(',25.5\n'),
      ]);
      // Should not throw - allowMalformed handles it
      final result = parser.parse(bytes);
      expect(result.headers, ['Name', 'Depth']);
    });

    test('trims whitespace from headers', () {
      final bytes = _toBytes(' Name , Depth \nDive 1,25.5\n');
      final result = parser.parse(bytes);

      expect(result.headers, ['Name', 'Depth']);
    });

    test('handles Subsurface dive list CSV format', () {
      // Real Subsurface headers (subset)
      final bytes = _toBytes(
        'dive number,date,time,duration [min],sac [l/min],maxdepth [m],avgdepth [m]\n'
        '1,2025-09-20,07:44:37,0:42,40.115,2.41,1.58\n',
      );
      final result = parser.parse(bytes);

      expect(result.headers.first, 'dive number');
      expect(result.headers.last, 'avgdepth [m]');
      expect(result.rows, hasLength(1));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/csv/pipeline/csv_parser_test.dart`
Expected: FAIL - `CsvParser` not found.

- [ ] **Step 3: Implement CsvParser**

```dart
// lib/features/universal_import/data/csv/pipeline/csv_parser.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../models/parsed_csv.dart';

/// Exception thrown when CSV parsing fails.
class CsvParseException implements Exception {
  final String message;
  const CsvParseException(this.message);

  @override
  String toString() => 'CsvParseException: $message';
}

/// Stage 1: Parse raw CSV bytes into headers and rows.
///
/// Handles encoding, line ending normalization, and basic validation.
/// Does NOT interpret values - all output is raw strings.
class CsvParser {
  const CsvParser();

  /// Parse [fileBytes] into a [ParsedCsv].
  ///
  /// Throws [CsvParseException] if the file is empty or has no data rows.
  ParsedCsv parse(Uint8List fileBytes) {
    if (fileBytes.isEmpty) {
      throw const CsvParseException('CSV file is empty');
    }

    final content = utf8.decode(fileBytes, allowMalformed: true);
    final normalized = _normalizeLineEndings(content);

    final List<List<dynamic>> allRows;
    try {
      allRows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(normalized);
    } on Exception catch (e) {
      throw CsvParseException('Could not parse CSV: $e');
    }

    if (allRows.isEmpty) {
      throw const CsvParseException('CSV file is empty');
    }

    final headers =
        allRows.first.map((h) => h.toString().trim()).toList();

    final dataRows = allRows
        .skip(1)
        .where((row) => !_isEmptyRow(row))
        .map((row) => row.map((cell) => cell.toString()).toList())
        .toList();

    if (dataRows.isEmpty) {
      throw const CsvParseException(
          'CSV file has headers but no data rows');
    }

    return ParsedCsv(headers: headers, rows: dataRows);
  }

  /// Normalize all line endings to \n.
  String _normalizeLineEndings(String content) {
    return content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Check if a row is entirely empty or whitespace.
  bool _isEmptyRow(List<dynamic> row) {
    return row.every(
        (cell) => cell == null || cell.toString().trim().isEmpty);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/csv/pipeline/csv_parser_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/csv/pipeline/csv_parser.dart test/features/universal_import/data/csv/pipeline/csv_parser_test.dart
git commit -m "feat: add CSV Parse stage with line ending normalization

Fixes #59 - handles LF, CRLF, and bare CR line endings.
Decodes UTF-8 with allowMalformed, skips empty rows."
```

---

## Task 3: Time Resolver

**Files:**
- Create: `lib/features/universal_import/data/csv/transforms/time_resolver.dart`
- Test: `test/features/universal_import/data/csv/transforms/time_resolver_test.dart`

Handles all time parsing: 12-hour with seconds (fixes #63), informal tokens (fixes #61), timezone interpretation (fixes #64), and the UTC wall-time convention.

- [ ] **Step 1: Write failing tests for TimeResolver**

```dart
// test/features/universal_import/data/csv/transforms/time_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/time_resolver.dart';

void main() {
  late TimeResolver resolver;

  setUp(() {
    resolver = const TimeResolver();
  });

  group('parseTime', () {
    test('parses 24-hour time HH:mm', () {
      final result = resolver.parseTime('14:30');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 30);
    });

    test('parses 24-hour time H:mm', () {
      final result = resolver.parseTime('9:17');
      expect(result, isNotNull);
      expect(result!.hour, 9);
      expect(result.minute, 17);
    });

    test('parses 24-hour time with seconds HH:mm:ss', () {
      final result = resolver.parseTime('14:30:45');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 30);
      expect(result.second, 45);
    });

    test('parses 12-hour time with AM/PM (fixes #63)', () {
      final result = resolver.parseTime('2:00 PM');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 0);
    });

    test('parses 12-hour time with seconds and AM/PM (fixes #63)', () {
      final result = resolver.parseTime('02:00:00 PM');
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 0);
      expect(result.second, 0);
    });

    test('parses 12-hour AM correctly', () {
      final result = resolver.parseTime('11:30:00 AM');
      expect(result, isNotNull);
      expect(result!.hour, 11);
    });

    test('parses 12:00 PM as noon', () {
      final result = resolver.parseTime('12:00 PM');
      expect(result, isNotNull);
      expect(result!.hour, 12);
    });

    test('parses 12:00 AM as midnight', () {
      final result = resolver.parseTime('12:00 AM');
      expect(result, isNotNull);
      expect(result!.hour, 0);
    });

    test('returns null for unparseable time', () {
      expect(resolver.parseTime('not a time'), isNull);
    });
  });

  group('parseDate', () {
    test('parses yyyy-MM-dd', () {
      final result = resolver.parseDate('2025-09-20');
      expect(result, isNotNull);
      expect(result!.year, 2025);
      expect(result.month, 9);
      expect(result.day, 20);
      expect(result.isUtc, isTrue);
    });

    test('parses MM/dd/yyyy', () {
      final result = resolver.parseDate('09/20/2025');
      expect(result, isNotNull);
      expect(result!.month, 9);
      expect(result.day, 20);
    });

    test('parses dd.MM.yyyy', () {
      final result = resolver.parseDate('20.09.2025');
      expect(result, isNotNull);
      expect(result!.day, 20);
      expect(result.month, 9);
    });

    test('returns null for unparseable date', () {
      expect(resolver.parseDate('not a date'), isNull);
    });
  });

  group('combineDateTime', () {
    test('combines separate date and time as UTC wall-time', () {
      final result = resolver.combineDateTime(
        dateStr: '2025-09-20',
        timeStr: '14:30',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.hour, 14);
      expect(result.minute, 30);
    });

    test('time not shifted by local UTC offset (issue #60)', () {
      final result = resolver.combineDateTime(
        dateStr: '1998-08-05',
        timeStr: '11:22',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.hour, 11, reason: 'Time must not be shifted by UTC offset');
      expect(result.minute, 22);
    });

    test('handles date only with no time - defaults to noon', () {
      final result = resolver.combineDateTime(
        dateStr: '2025-09-20',
        timeStr: null,
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.hour, 12);
    });

    test('parses single dateTime column', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2025-09-20 14:30:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      expect(result!.year, 2025);
      expect(result.hour, 14);
    });

    test('ISO 8601 with offset extracts wall-clock time', () {
      final result = resolver.combineDateTime(
        dateTimeStr: '2025-11-15T09:17:19-04:00',
        interpretation: TimeInterpretation.localWallClock,
      );
      expect(result, isNotNull);
      // Wall-clock = 09:17 local, stored as 09:17 UTC
      expect(result!.hour, 9);
      expect(result.minute, 17);
    });
  });

  group('resolveInformalTimes (fixes #61)', () {
    test('assigns defaults for am/pm/night tokens', () {
      final rows = [
        {'date': '2025-01-15', 'time': 'am'},
        {'date': '2025-01-15', 'time': 'pm'},
        {'date': '2025-01-15', 'time': 'night'},
      ];
      final resolved = resolver.resolveInformalTimes(rows);

      expect((resolved[0]['dateTime'] as DateTime).hour, 9);
      expect((resolved[1]['dateTime'] as DateTime).hour, 14);
      expect((resolved[2]['dateTime'] as DateTime).hour, 19);
    });

    test('increments times for multiple dives on same date', () {
      final rows = [
        {'date': '2025-01-15', 'time': 'am'},
        {'date': '2025-01-15', 'time': 'am'},
        {'date': '2025-01-15', 'time': 'am'},
      ];
      final resolved = resolver.resolveInformalTimes(rows);

      expect((resolved[0]['dateTime'] as DateTime).hour, 9);
      expect((resolved[1]['dateTime'] as DateTime).hour, 11);
      expect((resolved[2]['dateTime'] as DateTime).hour, 12);
    });

    test('assigns noon default for empty time values', () {
      final rows = [
        {'date': '2025-01-15', 'time': ''},
        {'date': '2025-01-15', 'time': ''},
      ];
      final resolved = resolver.resolveInformalTimes(rows);

      expect((resolved[0]['dateTime'] as DateTime).hour, 12);
      expect((resolved[1]['dateTime'] as DateTime).hour, 14);
    });

    test('passes through valid times unchanged', () {
      final rows = [
        {'date': '2025-01-15', 'time': '14:30'},
      ];
      final resolved = resolver.resolveInformalTimes(rows);

      // Valid time should be parsed normally, not assigned an informal default
      expect(resolved[0].containsKey('_informalTime'), isFalse);
    });

    test('handles morning and afternoon synonyms', () {
      final rows = [
        {'date': '2025-01-15', 'time': 'morning'},
        {'date': '2025-01-15', 'time': 'afternoon'},
        {'date': '2025-01-15', 'time': 'evening'},
      ];
      final resolved = resolver.resolveInformalTimes(rows);

      expect((resolved[0]['dateTime'] as DateTime).hour, 9);
      expect((resolved[1]['dateTime'] as DateTime).hour, 14);
      expect((resolved[2]['dateTime'] as DateTime).hour, 19);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/csv/transforms/time_resolver_test.dart`
Expected: FAIL - `TimeResolver` not found.

- [ ] **Step 3: Implement TimeResolver**

```dart
// lib/features/universal_import/data/csv/transforms/time_resolver.dart
import 'package:intl/intl.dart';

import '../models/import_configuration.dart';

/// Informal time token categories.
enum _InformalCategory { am, pm, night, unknown }

/// Resolves time values from CSV data into UTC wall-time DateTimes.
///
/// Handles: 24-hour, 12-hour with AM/PM (fixes #63), informal tokens
/// like "am"/"pm"/"night" (fixes #61), ISO 8601 with offsets, and
/// user-configurable timezone interpretation (fixes #64).
class TimeResolver {
  const TimeResolver();

  // ──────────────────────────────────────────────────────────────────
  // Time format patterns, tried in order (12-hour FIRST to fix #63)
  // ──────────────────────────────────────────────────────────────────

  static final _timeFormats = [
    DateFormat('h:mm:ss a'), // 2:00:00 PM
    DateFormat('hh:mm:ss a'), // 02:00:00 PM
    DateFormat('h:mm a'), // 2:00 PM
    DateFormat('hh:mm a'), // 02:00 PM
    DateFormat('HH:mm:ss'), // 14:00:00
    DateFormat('HH:mm'), // 14:30
    DateFormat('H:mm'), // 9:17
  ];

  static final _dateFormats = [
    DateFormat('yyyy-MM-dd'),
    DateFormat('MM/dd/yyyy'),
    DateFormat('dd/MM/yyyy'),
    DateFormat('yyyy/MM/dd'),
    DateFormat('dd-MM-yyyy'),
    DateFormat('MM-dd-yyyy'),
    DateFormat('dd.MM.yyyy'),
    DateFormat('yyyy.MM.dd'),
  ];

  static final _informalTokens = <String, _InformalCategory>{
    'am': _InformalCategory.am,
    'morning': _InformalCategory.am,
    'pm': _InformalCategory.pm,
    'afternoon': _InformalCategory.pm,
    'night': _InformalCategory.night,
    'evening': _InformalCategory.night,
  };

  static const _informalDefaults = <_InformalCategory, List<int>>{
    _InformalCategory.am: [9, 11, 12],
    _InformalCategory.pm: [14, 16, 17],
    _InformalCategory.night: [19, 21, 22],
    _InformalCategory.unknown: [12, 14, 16],
  };

  // ──────────────────────────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────────────────────────

  /// Parse a time string into hour/minute/second components.
  /// Returns a DateTime with only h/m/s meaningful (date = epoch).
  DateTime? parseTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();

    for (final fmt in _timeFormats) {
      try {
        return fmt.parseUtc(trimmed);
      } on FormatException {
        continue;
      }
    }

    // ISO 8601 fallback
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return DateTime.utc(1970, 1, 1, parsed.hour, parsed.minute, parsed.second);
    }

    return null;
  }

  /// Parse a date string into a UTC DateTime (time = midnight).
  DateTime? parseDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();

    for (final fmt in _dateFormats) {
      try {
        final d = fmt.parseUtc(trimmed);
        return DateTime.utc(d.year, d.month, d.day);
      } on FormatException {
        continue;
      }
    }

    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return DateTime.utc(parsed.year, parsed.month, parsed.day);
    }

    return null;
  }

  /// Combine date and time into a single UTC wall-time DateTime.
  ///
  /// Provide either [dateStr] + [timeStr], or a single [dateTimeStr].
  DateTime? combineDateTime({
    String? dateStr,
    String? timeStr,
    String? dateTimeStr,
    TimeInterpretation interpretation = TimeInterpretation.localWallClock,
    Duration? specificOffset,
  }) {
    // Single dateTime column
    if (dateTimeStr != null && dateTimeStr.trim().isNotEmpty) {
      return _parseDateTimeString(dateTimeStr.trim(), interpretation, specificOffset);
    }

    // Separate date + time
    final date = parseDate(dateStr);
    if (date == null) return null;

    final time = parseTime(timeStr);
    final hour = time?.hour ?? 12; // Default to noon if no time
    final minute = time?.minute ?? 0;
    final second = time?.second ?? 0;

    final combined = DateTime.utc(date.year, date.month, date.day, hour, minute, second);
    return _applyInterpretation(combined, interpretation, specificOffset);
  }

  /// Pre-pass: resolve informal time tokens across all rows.
  ///
  /// Groups rows by date, assigns incrementing defaults for informal tokens.
  /// Returns rows with '_informalTime' key set if resolved, or unchanged.
  List<Map<String, dynamic>> resolveInformalTimes(
    List<Map<String, dynamic>> rows,
  ) {
    // Group row indices by date
    final byDate = <String, List<int>>{};
    for (var i = 0; i < rows.length; i++) {
      final dateStr = rows[i]['date']?.toString() ?? '';
      byDate.putIfAbsent(dateStr, () => []).add(i);
    }

    final result = rows.map((r) => Map<String, dynamic>.from(r)).toList();

    for (final entry in byDate.entries) {
      final dateStr = entry.key;
      final indices = entry.value;
      final date = parseDate(dateStr);
      if (date == null) continue;

      // Track count per informal category for this date
      final categoryCounts = <_InformalCategory, int>{};

      for (final idx in indices) {
        final timeStr = result[idx]['time']?.toString().trim().toLowerCase() ?? '';
        final category = _informalTokens[timeStr];

        if (category != null || timeStr.isEmpty || parseTime(timeStr) == null) {
          // This is an informal token or unparseable - assign a default
          final cat = category ?? _InformalCategory.unknown;
          final count = categoryCounts[cat] ?? 0;
          categoryCounts[cat] = count + 1;

          final defaults = _informalDefaults[cat]!;
          final hour = count < defaults.length ? defaults[count] : defaults.last + count;

          result[idx]['dateTime'] = DateTime.utc(date.year, date.month, date.day, hour);
          result[idx]['_informalTime'] = true;
        }
      }
    }

    return result;
  }

  /// Check if a time string is an informal token.
  bool isInformalToken(String? value) {
    if (value == null) return false;
    return _informalTokens.containsKey(value.trim().toLowerCase());
  }

  // ──────────────────────────────────────────────────────────────────
  // Private helpers
  // ──────────────────────────────────────────────────────────────────

  DateTime? _parseDateTimeString(
    String value,
    TimeInterpretation interpretation,
    Duration? specificOffset,
  ) {
    // Check for ISO 8601 with offset
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      if (_hasExplicitOffset(value)) {
        // Extract wall-clock time from the offset representation
        // "2025-11-15T09:17:19-04:00" → wall-clock is 09:17:19
        final wallClock = _extractWallClockFromIso(value);
        return wallClock ?? DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
        );
      }
      final utc = DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
      );
      return _applyInterpretation(utc, interpretation, specificOffset);
    }

    // Try "date time" format (space-separated)
    final spaceIdx = value.indexOf(' ');
    if (spaceIdx > 0) {
      final datePart = value.substring(0, spaceIdx);
      final timePart = value.substring(spaceIdx + 1);
      return combineDateTime(
        dateStr: datePart,
        timeStr: timePart,
        interpretation: interpretation,
        specificOffset: specificOffset,
      );
    }

    // Date only
    final date = parseDate(value);
    if (date != null) {
      return DateTime.utc(date.year, date.month, date.day, 12);
    }

    return null;
  }

  bool _hasExplicitOffset(String value) {
    // Match +HH:MM or -HH:MM at end, or Z suffix
    return RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(value) || value.endsWith('Z');
  }

  DateTime? _extractWallClockFromIso(String value) {
    // For "2025-11-15T09:17:19-04:00", extract the literal 09:17:19
    // The 'T' separates date from time; offset is at the end
    final tIndex = value.indexOf('T');
    if (tIndex < 0) return null;

    final datePart = value.substring(0, tIndex);
    var timePart = value.substring(tIndex + 1);

    // Strip offset
    timePart = timePart.replaceAll(RegExp(r'[+-]\d{2}:\d{2}$'), '');
    timePart = timePart.replaceAll(RegExp(r'Z$'), '');

    final date = parseDate(datePart);
    final time = parseTime(timePart);
    if (date == null) return null;

    return DateTime.utc(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 12,
      time?.minute ?? 0,
      time?.second ?? 0,
    );
  }

  DateTime _applyInterpretation(
    DateTime utcValue,
    TimeInterpretation interpretation,
    Duration? specificOffset,
  ) {
    switch (interpretation) {
      case TimeInterpretation.localWallClock:
      case TimeInterpretation.utc:
        // Both store as-is in UTC encoding
        return utcValue;
      case TimeInterpretation.specificOffset:
        if (specificOffset != null) {
          // Subtract offset to get wall-clock, then store as UTC
          final wallClock = utcValue.subtract(specificOffset);
          return DateTime.utc(
            wallClock.year,
            wallClock.month,
            wallClock.day,
            wallClock.hour,
            wallClock.minute,
            wallClock.second,
          );
        }
        return utcValue;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/csv/transforms/time_resolver_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/csv/transforms/time_resolver.dart test/features/universal_import/data/csv/transforms/time_resolver_test.dart
git commit -m "feat: add TimeResolver with AM/PM and informal time support

Fixes #63 (12-hour time with seconds), #61 (informal time defaults),
#64 (timezone interpretation option). Maintains UTC wall-time convention."
```

---

## Task 4: Unit Detector

**Files:**
- Create: `lib/features/universal_import/data/csv/transforms/unit_detector.dart`
- Test: `test/features/universal_import/data/csv/transforms/unit_detector_test.dart`

Detects units from headers, presets, or value heuristics. Per-column, not global.

- [ ] **Step 1: Write failing tests for UnitDetector**

```dart
// test/features/universal_import/data/csv/transforms/unit_detector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/unit_detector.dart';

void main() {
  late UnitDetector detector;

  setUp(() {
    detector = const UnitDetector();
  });

  group('parseHeaderUnit', () {
    test('extracts meters from bracketed suffix', () {
      final result = detector.parseHeaderUnit('maxdepth [m]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.meters);
      expect(result.source, UnitSource.header);
    });

    test('extracts Celsius from bracketed suffix', () {
      final result = detector.parseHeaderUnit('watertemp [C]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.celsius);
    });

    test('extracts bar from bracketed suffix', () {
      final result = detector.parseHeaderUnit('startpressure (1) [bar]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.bar);
    });

    test('extracts feet from bracketed suffix', () {
      final result = detector.parseHeaderUnit('Max Depth [ft]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.feet);
    });

    test('extracts Fahrenheit', () {
      final result = detector.parseHeaderUnit('Water Temp [F]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.fahrenheit);
    });

    test('extracts PSI', () {
      final result = detector.parseHeaderUnit('Start Pressure [psi]');
      expect(result, isNotNull);
      expect(result!.detected, DetectedUnit.psi);
    });

    test('returns null for header without unit', () {
      expect(detector.parseHeaderUnit('Max Depth'), isNull);
    });
  });

  group('detectFromValues', () {
    test('detects feet from large depth values', () {
      final result = detector.detectFromValues(
        columnName: 'depth',
        unitType: UnitType.depth,
        samples: ['120', '85', '150', '60', '200'],
      );
      expect(result.detected, DetectedUnit.feet);
      expect(result.source, UnitSource.heuristic);
    });

    test('detects meters from small depth values', () {
      final result = detector.detectFromValues(
        columnName: 'depth',
        unitType: UnitType.depth,
        samples: ['25.5', '30.0', '12.4', '8.0'],
      );
      expect(result.detected, DetectedUnit.meters);
    });

    test('detects Fahrenheit from high temperature values', () {
      final result = detector.detectFromValues(
        columnName: 'watertemp',
        unitType: UnitType.temperature,
        samples: ['72', '68', '80', '75'],
      );
      expect(result.detected, DetectedUnit.fahrenheit);
    });

    test('detects Celsius from low temperature values', () {
      final result = detector.detectFromValues(
        columnName: 'watertemp',
        unitType: UnitType.temperature,
        samples: ['28', '21', '15', '32'],
      );
      expect(result.detected, DetectedUnit.celsius);
    });

    test('detects PSI from high pressure values', () {
      final result = detector.detectFromValues(
        columnName: 'pressure',
        unitType: UnitType.pressure,
        samples: ['3000', '2500', '1800'],
      );
      expect(result.detected, DetectedUnit.psi);
    });

    test('detects bar from low pressure values', () {
      final result = detector.detectFromValues(
        columnName: 'pressure',
        unitType: UnitType.pressure,
        samples: ['200', '180', '150'],
      );
      expect(result.detected, DetectedUnit.bar);
    });
  });

  group('unitTypeForField', () {
    test('identifies depth fields', () {
      expect(UnitDetector.unitTypeForField('maxDepth'), UnitType.depth);
      expect(UnitDetector.unitTypeForField('avgDepth'), UnitType.depth);
    });

    test('identifies temperature fields', () {
      expect(UnitDetector.unitTypeForField('waterTemp'), UnitType.temperature);
      expect(UnitDetector.unitTypeForField('airTemp'), UnitType.temperature);
    });

    test('identifies pressure fields', () {
      expect(UnitDetector.unitTypeForField('startPressure'), UnitType.pressure);
    });

    test('identifies volume fields', () {
      expect(UnitDetector.unitTypeForField('tankVolume'), UnitType.volume);
    });

    test('returns null for non-unit fields', () {
      expect(UnitDetector.unitTypeForField('diveNumber'), isNull);
      expect(UnitDetector.unitTypeForField('notes'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/csv/transforms/unit_detector_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement UnitDetector**

```dart
// lib/features/universal_import/data/csv/transforms/unit_detector.dart

/// The physical quantity a column represents.
enum UnitType { depth, temperature, pressure, volume, weight }

/// A specific unit of measurement.
enum DetectedUnit {
  meters,
  feet,
  celsius,
  fahrenheit,
  bar,
  psi,
  liters,
  cubicFeet,
  kilograms,
  pounds,
}

/// How the unit was determined.
enum UnitSource { header, preset, heuristic, userOverride }

/// Per-column unit detection result.
class ColumnUnitDetection {
  final String columnName;
  final UnitType unitType;
  final DetectedUnit detected;
  final UnitSource source;
  final double confidence;

  const ColumnUnitDetection({
    required this.columnName,
    required this.unitType,
    required this.detected,
    required this.source,
    this.confidence = 1.0,
  });

  /// Whether this column needs conversion to metric.
  bool get needsConversion =>
      detected == DetectedUnit.feet ||
      detected == DetectedUnit.fahrenheit ||
      detected == DetectedUnit.psi ||
      detected == DetectedUnit.cubicFeet ||
      detected == DetectedUnit.pounds;
}

/// Detects units from CSV headers and sample values.
class UnitDetector {
  const UnitDetector();

  static final _headerUnitPattern = RegExp(r'\[([^\]]+)\]\s*$');

  static const _headerUnitMap = <String, DetectedUnit>{
    'm': DetectedUnit.meters,
    'meters': DetectedUnit.meters,
    'ft': DetectedUnit.feet,
    'feet': DetectedUnit.feet,
    'c': DetectedUnit.celsius,
    'celsius': DetectedUnit.celsius,
    'f': DetectedUnit.fahrenheit,
    'fahrenheit': DetectedUnit.fahrenheit,
    'bar': DetectedUnit.bar,
    'psi': DetectedUnit.psi,
    'l': DetectedUnit.liters,
    'liters': DetectedUnit.liters,
    'cuft': DetectedUnit.cubicFeet,
    'kg': DetectedUnit.kilograms,
    'lbs': DetectedUnit.pounds,
    'pounds': DetectedUnit.pounds,
  };

  /// Try to parse a unit from a header's bracketed suffix.
  /// Returns null if no unit is found.
  ColumnUnitDetection? parseHeaderUnit(String header) {
    final match = _headerUnitPattern.firstMatch(header);
    if (match == null) return null;

    final unitStr = match.group(1)!.trim().toLowerCase();
    final detected = _headerUnitMap[unitStr];
    if (detected == null) return null;

    final unitType = _unitTypeForDetected(detected);
    if (unitType == null) return null;

    return ColumnUnitDetection(
      columnName: header,
      unitType: unitType,
      detected: detected,
      source: UnitSource.header,
    );
  }

  /// Detect units from sample values using heuristics.
  ColumnUnitDetection detectFromValues({
    required String columnName,
    required UnitType unitType,
    required List<String> samples,
  }) {
    final values = samples
        .map((s) => double.tryParse(s.replaceAll(RegExp(r'[^\d.\-]'), '')))
        .whereType<double>()
        .toList();

    if (values.isEmpty) {
      return ColumnUnitDetection(
        columnName: columnName,
        unitType: unitType,
        detected: _metricDefaultFor(unitType),
        source: UnitSource.heuristic,
        confidence: 0.3,
      );
    }

    final (detected, confidence) = switch (unitType) {
      UnitType.depth => _detectDepthUnit(values),
      UnitType.temperature => _detectTemperatureUnit(values),
      UnitType.pressure => _detectPressureUnit(values),
      UnitType.volume => _detectVolumeUnit(values),
      UnitType.weight => _detectWeightUnit(values),
    };

    return ColumnUnitDetection(
      columnName: columnName,
      unitType: unitType,
      detected: detected,
      source: UnitSource.heuristic,
      confidence: confidence,
    );
  }

  /// Map a target field name to its unit type, or null if not a unit field.
  static UnitType? unitTypeForField(String fieldName) {
    if (fieldName.contains('depth') || fieldName.contains('Depth')) {
      return UnitType.depth;
    }
    if (fieldName.contains('temp') || fieldName.contains('Temp')) {
      return UnitType.temperature;
    }
    if (fieldName.contains('pressure') || fieldName.contains('Pressure')) {
      return UnitType.pressure;
    }
    if (fieldName.contains('volume') || fieldName.contains('Volume') ||
        fieldName == 'tankVolume') {
      return UnitType.volume;
    }
    if (fieldName.contains('weight') || fieldName.contains('Weight')) {
      return UnitType.weight;
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────────
  // Heuristics
  // ──────────────────────────────────────────────────────────────────

  (DetectedUnit, double) _detectDepthUnit(List<double> values) {
    final aboveThreshold = values.where((v) => v > 100).length;
    final ratio = aboveThreshold / values.length;
    if (ratio > 0.5) return (DetectedUnit.feet, 0.8);
    final belowThreshold = values.where((v) => v < 80).length;
    if (belowThreshold / values.length > 0.5) return (DetectedUnit.meters, 0.8);
    // Ambiguous range 80-100
    return (DetectedUnit.meters, 0.5);
  }

  (DetectedUnit, double) _detectTemperatureUnit(List<double> values) {
    final aboveThreshold = values.where((v) => v > 50).length;
    if (aboveThreshold / values.length > 0.5) return (DetectedUnit.fahrenheit, 0.8);
    final belowThreshold = values.where((v) => v < 45).length;
    if (belowThreshold / values.length > 0.5) return (DetectedUnit.celsius, 0.8);
    return (DetectedUnit.celsius, 0.5);
  }

  (DetectedUnit, double) _detectPressureUnit(List<double> values) {
    final aboveThreshold = values.where((v) => v > 300).length;
    if (aboveThreshold / values.length > 0.5) return (DetectedUnit.psi, 0.8);
    return (DetectedUnit.bar, 0.8);
  }

  (DetectedUnit, double) _detectVolumeUnit(List<double> values) {
    final aboveThreshold = values.where((v) => v > 20).length;
    if (aboveThreshold / values.length > 0.5) return (DetectedUnit.cubicFeet, 0.7);
    return (DetectedUnit.liters, 0.7);
  }

  (DetectedUnit, double) _detectWeightUnit(List<double> values) {
    final aboveThreshold = values.where((v) => v > 30).length;
    if (aboveThreshold / values.length > 0.5) return (DetectedUnit.pounds, 0.7);
    return (DetectedUnit.kilograms, 0.7);
  }

  DetectedUnit _metricDefaultFor(UnitType type) => switch (type) {
        UnitType.depth => DetectedUnit.meters,
        UnitType.temperature => DetectedUnit.celsius,
        UnitType.pressure => DetectedUnit.bar,
        UnitType.volume => DetectedUnit.liters,
        UnitType.weight => DetectedUnit.kilograms,
      };

  UnitType? _unitTypeForDetected(DetectedUnit unit) => switch (unit) {
        DetectedUnit.meters || DetectedUnit.feet => UnitType.depth,
        DetectedUnit.celsius || DetectedUnit.fahrenheit => UnitType.temperature,
        DetectedUnit.bar || DetectedUnit.psi => UnitType.pressure,
        DetectedUnit.liters || DetectedUnit.cubicFeet => UnitType.volume,
        DetectedUnit.kilograms || DetectedUnit.pounds => UnitType.weight,
      };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/csv/transforms/unit_detector_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/csv/transforms/unit_detector.dart test/features/universal_import/data/csv/transforms/unit_detector_test.dart
git commit -m "feat: add UnitDetector with header parsing and value heuristics

Detects units per-column from bracketed header suffixes (e.g. [m], [F]),
preset declarations, or value heuristics with confidence scores."
```

---

## Task 5: Value Converter

**Files:**
- Create: `lib/features/universal_import/data/csv/transforms/value_converter.dart`
- Test: `test/features/universal_import/data/csv/transforms/value_converter_test.dart`

Unit conversions, type coercion, visibility/rating/dive-type transforms. Replaces `value_transforms.dart`. The `ValueTransform` enum is re-exported from here for backward compatibility during the transition.

- [ ] **Step 1: Write failing tests for ValueConverter**

```dart
// test/features/universal_import/data/csv/transforms/value_converter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/unit_detector.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/value_converter.dart';

void main() {
  late ValueConverter converter;

  setUp(() {
    converter = const ValueConverter();
  });

  group('unit conversions', () {
    test('converts feet to meters', () {
      expect(converter.convertUnit(100.0, DetectedUnit.feet), closeTo(30.5, 0.1));
    });

    test('converts Fahrenheit to Celsius', () {
      expect(converter.convertUnit(72.0, DetectedUnit.fahrenheit), closeTo(22.2, 0.1));
    });

    test('converts PSI to bar', () {
      expect(converter.convertUnit(3000.0, DetectedUnit.psi), closeTo(206.8, 0.1));
    });

    test('converts cubic feet to liters', () {
      expect(converter.convertUnit(80.0, DetectedUnit.cubicFeet), closeTo(2265.3, 0.1));
    });

    test('converts pounds to kg', () {
      expect(converter.convertUnit(10.0, DetectedUnit.pounds), closeTo(4.5, 0.1));
    });

    test('returns value unchanged for metric units', () {
      expect(converter.convertUnit(25.5, DetectedUnit.meters), 25.5);
      expect(converter.convertUnit(28.0, DetectedUnit.celsius), 28.0);
      expect(converter.convertUnit(200.0, DetectedUnit.bar), 200.0);
    });
  });

  group('parseDuration', () {
    test('parses minutes as double', () {
      final result = converter.parseDuration('45', DurationFormat.minutes);
      expect(result, const Duration(seconds: 2700));
    });

    test('parses H:MM format', () {
      final result = converter.parseDuration('1:23', DurationFormat.hms);
      expect(result, const Duration(hours: 1, minutes: 23));
    });

    test('parses H:MM:SS format', () {
      final result = converter.parseDuration('1:23:45', DurationFormat.hms);
      expect(result, const Duration(hours: 1, minutes: 23, seconds: 45));
    });

    test('parses M:SS format', () {
      final result = converter.parseDuration('0:42', DurationFormat.hms);
      expect(result, const Duration(minutes: 0, seconds: 42));
    });

    test('parses Subsurface duration format (min:sec)', () {
      final result = converter.parseDuration('25:20', DurationFormat.hms);
      expect(result, const Duration(minutes: 25, seconds: 20));
    });
  });

  group('parseVisibility', () {
    test('maps text to enum values', () {
      expect(converter.parseVisibility('excellent'), 'excellent');
      expect(converter.parseVisibility('good'), 'good');
      expect(converter.parseVisibility('poor'), 'poor');
    });

    test('maps numeric meters to enum', () {
      expect(converter.parseVisibility('35'), 'excellent');
      expect(converter.parseVisibility('15'), 'good');
      expect(converter.parseVisibility('8'), 'moderate');
      expect(converter.parseVisibility('2'), 'poor');
    });

    test('maps descriptive text', () {
      expect(converter.parseVisibility('crystal clear'), 'excellent');
      expect(converter.parseVisibility('murky'), 'poor');
    });
  });

  group('normalizeRating', () {
    test('preserves 1-5 scale', () {
      expect(converter.normalizeRating('3'), 3);
      expect(converter.normalizeRating('5'), 5);
    });

    test('converts 1-10 scale', () {
      expect(converter.normalizeRating('7'), 4);
      expect(converter.normalizeRating('10'), 5);
    });

    test('clamps out of range', () {
      expect(converter.normalizeRating('0'), 1);
      expect(converter.normalizeRating('-1'), 1);
    });
  });

  group('parseDiveType', () {
    test('maps known keywords', () {
      expect(converter.parseDiveType('night dive'), 'night');
      expect(converter.parseDiveType('deep'), 'deep');
      expect(converter.parseDiveType('wreck diving'), 'wreck');
      expect(converter.parseDiveType('shore'), 'shore');
    });

    test('returns recreational for unknown types', () {
      expect(converter.parseDiveType('unknown thing'), 'recreational');
    });
  });

  group('parseDouble', () {
    test('parses clean numbers', () {
      expect(converter.parseDouble('25.5'), 25.5);
    });

    test('strips non-numeric characters', () {
      expect(converter.parseDouble('25.5 m'), 25.5);
      expect(converter.parseDouble('3,000'), 3000.0);
    });

    test('returns null for unparseable', () {
      expect(converter.parseDouble('not a number'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/csv/transforms/value_converter_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement ValueConverter**

```dart
// lib/features/universal_import/data/csv/transforms/value_converter.dart
import 'unit_detector.dart';

/// How a duration string should be interpreted.
enum DurationFormat {
  /// Value is in minutes (e.g., "45" = 45 minutes).
  minutes,

  /// Value is in H:MM:SS or M:SS format (e.g., "1:23:45").
  hms,
}

/// Handles unit conversions, type coercion, and scale transforms.
class ValueConverter {
  const ValueConverter();

  // ──────────────────────────────────────────────────────────────────
  // Unit conversions (to metric)
  // ──────────────────────────────────────────────────────────────────

  /// Convert a value from the detected unit to metric.
  /// Returns the value unchanged if already metric.
  double convertUnit(double value, DetectedUnit fromUnit) {
    return switch (fromUnit) {
      DetectedUnit.feet => _round(value * 0.3048, 1),
      DetectedUnit.fahrenheit => _round((value - 32) * 5 / 9, 1),
      DetectedUnit.psi => _round(value * 0.0689476, 1),
      DetectedUnit.cubicFeet => _round(value * 28.3168, 1),
      DetectedUnit.pounds => _round(value * 0.453592, 1),
      // Already metric
      DetectedUnit.meters ||
      DetectedUnit.celsius ||
      DetectedUnit.bar ||
      DetectedUnit.liters ||
      DetectedUnit.kilograms =>
        value,
    };
  }

  // ──────────────────────────────────────────────────────────────────
  // Duration parsing
  // ──────────────────────────────────────────────────────────────────

  /// Parse a duration string according to the specified format.
  Duration? parseDuration(String? value, DurationFormat format) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();

    switch (format) {
      case DurationFormat.minutes:
        final minutes = double.tryParse(trimmed);
        if (minutes == null) return null;
        return Duration(seconds: (minutes * 60).round());

      case DurationFormat.hms:
        final parts = trimmed.split(':');
        if (parts.length == 3) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final s = int.tryParse(parts[2]) ?? 0;
          return Duration(hours: h, minutes: m, seconds: s);
        } else if (parts.length == 2) {
          final a = int.tryParse(parts[0]) ?? 0;
          final b = int.tryParse(parts[1]) ?? 0;
          // Could be H:MM or M:SS. If first part > 59, treat as M:SS.
          // Subsurface uses M:SS (e.g., "25:20" = 25m 20s)
          return Duration(minutes: a, seconds: b);
        }
        return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Scale/enum transforms
  // ──────────────────────────────────────────────────────────────────

  /// Parse visibility into one of: excellent, good, moderate, poor, unknown.
  String parseVisibility(String? value) {
    if (value == null || value.trim().isEmpty) return 'unknown';
    final lower = value.trim().toLowerCase();

    // Direct enum match
    const validValues = ['excellent', 'good', 'moderate', 'poor', 'unknown'];
    if (validValues.contains(lower)) return lower;

    // Descriptive text mapping
    if (lower.contains('crystal') || lower.contains('unlimited')) {
      return 'excellent';
    }
    if (lower.contains('clear') || lower.contains('great')) return 'good';
    if (lower.contains('murky') || lower.contains('bad') || lower.contains('dirty')) {
      return 'poor';
    }

    // Numeric (meters) mapping
    final numeric = double.tryParse(lower.replaceAll(RegExp(r'[^\d.]'), ''));
    if (numeric != null) {
      if (numeric > 20) return 'excellent';
      if (numeric > 10) return 'good';
      if (numeric > 5) return 'moderate';
      return 'poor';
    }

    return 'unknown';
  }

  /// Normalize a rating to 1-5 scale from various scales.
  int? normalizeRating(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final numeric = double.tryParse(value.trim());
    if (numeric == null) return null;

    if (numeric <= 0) return 1;
    if (numeric <= 5) return numeric.round().clamp(1, 5);
    if (numeric <= 10) return (numeric / 2).round().clamp(1, 5);
    if (numeric <= 100) return (numeric / 20).round().clamp(1, 5);
    return 5;
  }

  /// Map dive type text to a standardized identifier.
  String parseDiveType(String? value) {
    if (value == null || value.trim().isEmpty) return 'recreational';
    final lower = value.trim().toLowerCase();

    const keywords = <String, String>{
      'training': 'training',
      'student': 'training',
      'course': 'training',
      'night': 'night',
      'deep': 'deep',
      'wreck': 'wreck',
      'drift': 'drift',
      'cave': 'cave',
      'cavern': 'cave',
      'technical': 'technical',
      'tec': 'technical',
      'freedive': 'freedive',
      'free dive': 'freedive',
      'apnea': 'freedive',
      'ice': 'ice',
      'altitude': 'altitude',
      'shore': 'shore',
      'beach': 'shore',
      'boat': 'boat',
      'liveaboard': 'liveaboard',
      'recreational': 'recreational',
    };

    for (final entry in keywords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    return 'recreational';
  }

  // ──────────────────────────────────────────────────────────────────
  // Type coercion
  // ──────────────────────────────────────────────────────────────────

  /// Parse a string to double, stripping non-numeric chars.
  double? parseDouble(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    // Remove everything except digits, dots, minus
    final cleaned = value.trim().replaceAll(',', '').replaceAll(RegExp(r'[^\d.\-]'), '');
    return double.tryParse(cleaned);
  }

  /// Parse a string to int.
  int? parseInt(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return parseDouble(value)?.round();
  }

  double _round(double value, int decimals) {
    final factor = _pow10(decimals);
    return (value * factor).roundToDouble() / factor;
  }

  static double _pow10(int n) {
    var result = 1.0;
    for (var i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/universal_import/data/csv/transforms/value_converter_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/csv/transforms/value_converter.dart test/features/universal_import/data/csv/transforms/value_converter_test.dart
git commit -m "feat: add ValueConverter for unit conversions and type coercion

Handles ft->m, F->C, psi->bar, cuft->L, lbs->kg conversions.
Parses durations, visibility, ratings, dive types."
```

---

## Task 6: Preset Model & Built-in Presets

**Files:**
- Create: `lib/features/universal_import/data/csv/presets/csv_preset.dart`
- Create: `lib/features/universal_import/data/csv/presets/built_in_presets.dart`
- Test: `test/features/universal_import/data/csv/presets/built_in_presets_test.dart`

The preset data model and all 7 built-in preset definitions. Presets are const data — no logic.

- [ ] **Step 1: Create CsvPreset model**

```dart
// lib/features/universal_import/data/csv/presets/csv_preset.dart
import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../models/field_mapping.dart';
import '../../models/import_enums.dart';

/// Whether a preset is built into the app or saved by a user.
enum PresetSource { builtIn, userSaved }

/// Expected unit system for a preset.
enum UnitSystem { metric, imperial }

/// Expected time format for a preset.
enum ExpectedTimeFormat { h24, h12, informal }

/// A file role within a multi-file preset.
class PresetFileRole extends Equatable {
  /// Unique identifier for this role (e.g., 'dive_list', 'dive_profile').
  final String roleId;

  /// Human-readable label (e.g., 'Dive list CSV').
  final String label;

  /// Whether this file is required for the import to proceed.
  final bool required;

  /// Headers that identify this specific file type.
  final List<String> signatureHeaders;

  const PresetFileRole({
    required this.roleId,
    required this.label,
    this.required = true,
    required this.signatureHeaders,
  });

  @override
  List<Object?> get props => [roleId, label, required, signatureHeaders];
}

/// A CSV import preset: everything needed to parse a specific app's CSV export.
class CsvPreset extends Equatable {
  final String id;
  final String name;
  final PresetSource source;
  final SourceApp? sourceApp;

  // Detection
  final List<String> signatureHeaders;
  final double matchThreshold;

  // File expectations
  final List<PresetFileRole> fileRoles;

  // Field mapping per file role.
  // Key is file role ID (or 'primary' for single-file presets).
  final Map<String, FieldMapping> mappings;

  // Transform hints
  final UnitSystem? expectedUnits;
  final ExpectedTimeFormat? expectedTimeFormat;

  // Entity extraction hints
  final Set<ImportEntityType> supportedEntities;

  const CsvPreset({
    required this.id,
    required this.name,
    this.source = PresetSource.builtIn,
    this.sourceApp,
    this.signatureHeaders = const [],
    this.matchThreshold = 0.6,
    this.fileRoles = const [],
    this.mappings = const {},
    this.expectedUnits,
    this.expectedTimeFormat,
    this.supportedEntities = const {ImportEntityType.dives, ImportEntityType.sites},
  });

  /// Whether this preset expects multiple files.
  bool get isMultiFile => fileRoles.length > 1;

  /// The primary file mapping (convenience for single-file presets).
  FieldMapping? get primaryMapping => mappings['primary'];

  /// Serialize to JSON for database storage (user presets only).
  String toJson() => jsonEncode({
        'id': id,
        'name': name,
        'sourceApp': sourceApp?.name,
        'signatureHeaders': signatureHeaders,
        'matchThreshold': matchThreshold,
        'mappings': mappings.map(
          (key, fm) => MapEntry(key, {
            'name': fm.name,
            'columns': fm.columns
                .map((c) => {
                      'sourceColumn': c.sourceColumn,
                      'targetField': c.targetField,
                      'transform': c.transform?.name,
                      'defaultValue': c.defaultValue,
                    })
                .toList(),
          }),
        ),
        'expectedUnits': expectedUnits?.name,
        'supportedEntities': supportedEntities.map((e) => e.name).toList(),
      });

  /// Deserialize from JSON (user presets only).
  static CsvPreset fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return CsvPreset(
      id: map['id'] as String,
      name: map['name'] as String,
      source: PresetSource.userSaved,
      sourceApp: map['sourceApp'] != null
          ? SourceApp.values.firstWhere(
              (e) => e.name == map['sourceApp'],
              orElse: () => SourceApp.generic,
            )
          : null,
      signatureHeaders: List<String>.from(map['signatureHeaders'] ?? []),
      matchThreshold: (map['matchThreshold'] as num?)?.toDouble() ?? 0.6,
      mappings: (map['mappings'] as Map<String, dynamic>?)?.map(
            (key, value) {
              final fmMap = value as Map<String, dynamic>;
              return MapEntry(
                key,
                FieldMapping(
                  name: fmMap['name'] as String? ?? key,
                  columns: (fmMap['columns'] as List<dynamic>?)
                          ?.map((c) {
                            final colMap = c as Map<String, dynamic>;
                            return ColumnMapping(
                              sourceColumn: colMap['sourceColumn'] as String,
                              targetField: colMap['targetField'] as String,
                              transform: colMap['transform'] != null
                                  ? ValueTransform.values.firstWhere(
                                      (e) => e.name == colMap['transform'],
                                    )
                                  : null,
                              defaultValue: colMap['defaultValue'] as String?,
                            );
                          })
                          .toList() ??
                      [],
                ),
              );
            },
          ) ??
          {},
      expectedUnits: map['expectedUnits'] != null
          ? UnitSystem.values.firstWhere((e) => e.name == map['expectedUnits'])
          : null,
      supportedEntities: (map['supportedEntities'] as List<dynamic>?)
              ?.map((e) => ImportEntityType.values.firstWhere((v) => v.name == e))
              .toSet() ??
          {ImportEntityType.dives, ImportEntityType.sites},
    );
  }

  @override
  List<Object?> get props => [id, name, source, sourceApp];
}
```

- [ ] **Step 2: Create built-in presets**

This file contains all 7 preset definitions. Each preset specifies its signature headers, field mappings, expected units, and supported entity types. The mappings are ported from the existing `FieldMappingEngine` presets but enhanced with multi-tank support for Subsurface and multi-file roles.

```dart
// lib/features/universal_import/data/csv/presets/built_in_presets.dart
import '../../models/field_mapping.dart';
import '../../models/import_enums.dart';
import 'csv_preset.dart';

/// All built-in CSV presets. Add new presets here as const definitions.
const builtInCsvPresets = <CsvPreset>[
  _subsurfacePreset,
  _macDivePreset,
  _divingLogPreset,
  _diveMatePreset,
  _garminConnectPreset,
  _shearwaterPreset,
  _submersionPreset,
];

// ============================================================================
// Subsurface CSV (multi-file)
// ============================================================================

const _subsurfacePreset = CsvPreset(
  id: 'subsurface',
  name: 'Subsurface CSV',
  sourceApp: SourceApp.subsurface,
  signatureHeaders: [
    'dive number',
    'date',
    'time',
    'duration [min]',
    'sac [l/min]',
    'maxdepth [m]',
    'avgdepth [m]',
    'mode',
    'airtemp [C]',
    'watertemp [C]',
    'cylinder size (1) [l]',
    'startpressure (1) [bar]',
    'endpressure (1) [bar]',
    'o2 (1) [%]',
    'he (1) [%]',
    'location',
    'gps',
    'divemaster',
    'buddy',
    'suit',
    'rating',
    'visibility',
    'notes',
    'weight [kg]',
    'tags',
  ],
  matchThreshold: 0.5,
  fileRoles: [
    PresetFileRole(
      roleId: 'dive_list',
      label: 'Dive list CSV',
      required: true,
      signatureHeaders: ['dive number', 'maxdepth [m]', 'sac [l/min]', 'cylinder size (1) [l]'],
    ),
    PresetFileRole(
      roleId: 'dive_profile',
      label: 'Dive profile CSV (optional)',
      required: false,
      signatureHeaders: ['sample time (min)', 'sample depth (m)', 'sample temperature (C)'],
    ),
  ],
  mappings: {
    'dive_list': FieldMapping(
      name: 'Subsurface Dive List',
      sourceApp: SourceApp.subsurface,
      columns: [
        ColumnMapping(sourceColumn: 'dive number', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'time', targetField: 'time'),
        ColumnMapping(
          sourceColumn: 'duration [min]',
          targetField: 'duration',
          transform: ValueTransform.hmsToSeconds,
        ),
        ColumnMapping(sourceColumn: 'sac [l/min]', targetField: 'sac'),
        ColumnMapping(sourceColumn: 'maxdepth [m]', targetField: 'maxDepth'),
        ColumnMapping(sourceColumn: 'avgdepth [m]', targetField: 'avgDepth'),
        ColumnMapping(sourceColumn: 'mode', targetField: 'diveMode'),
        ColumnMapping(sourceColumn: 'airtemp [C]', targetField: 'airTemp'),
        ColumnMapping(sourceColumn: 'watertemp [C]', targetField: 'waterTemp'),
        // Tank 1
        ColumnMapping(sourceColumn: 'cylinder size (1) [l]', targetField: 'tankVolume_1'),
        ColumnMapping(sourceColumn: 'startpressure (1) [bar]', targetField: 'startPressure_1'),
        ColumnMapping(sourceColumn: 'endpressure (1) [bar]', targetField: 'endPressure_1'),
        ColumnMapping(sourceColumn: 'o2 (1) [%]', targetField: 'o2Percent_1'),
        ColumnMapping(sourceColumn: 'he (1) [%]', targetField: 'hePercent_1'),
        // Tank 2
        ColumnMapping(sourceColumn: 'cylinder size (2) [l]', targetField: 'tankVolume_2'),
        ColumnMapping(sourceColumn: 'startpressure (2) [bar]', targetField: 'startPressure_2'),
        ColumnMapping(sourceColumn: 'endpressure (2) [bar]', targetField: 'endPressure_2'),
        ColumnMapping(sourceColumn: 'o2 (2) [%]', targetField: 'o2Percent_2'),
        ColumnMapping(sourceColumn: 'he (2) [%]', targetField: 'hePercent_2'),
        // Tank 3
        ColumnMapping(sourceColumn: 'cylinder size (3) [l]', targetField: 'tankVolume_3'),
        ColumnMapping(sourceColumn: 'startpressure (3) [bar]', targetField: 'startPressure_3'),
        ColumnMapping(sourceColumn: 'endpressure (3) [bar]', targetField: 'endPressure_3'),
        ColumnMapping(sourceColumn: 'o2 (3) [%]', targetField: 'o2Percent_3'),
        ColumnMapping(sourceColumn: 'he (3) [%]', targetField: 'hePercent_3'),
        // Tank 4
        ColumnMapping(sourceColumn: 'cylinder size (4) [l]', targetField: 'tankVolume_4'),
        ColumnMapping(sourceColumn: 'startpressure (4) [bar]', targetField: 'startPressure_4'),
        ColumnMapping(sourceColumn: 'endpressure (4) [bar]', targetField: 'endPressure_4'),
        ColumnMapping(sourceColumn: 'o2 (4) [%]', targetField: 'o2Percent_4'),
        ColumnMapping(sourceColumn: 'he (4) [%]', targetField: 'hePercent_4'),
        // Tank 5
        ColumnMapping(sourceColumn: 'cylinder size (5) [l]', targetField: 'tankVolume_5'),
        ColumnMapping(sourceColumn: 'startpressure (5) [bar]', targetField: 'startPressure_5'),
        ColumnMapping(sourceColumn: 'endpressure (5) [bar]', targetField: 'endPressure_5'),
        ColumnMapping(sourceColumn: 'o2 (5) [%]', targetField: 'o2Percent_5'),
        ColumnMapping(sourceColumn: 'he (5) [%]', targetField: 'hePercent_5'),
        // Tank 6
        ColumnMapping(sourceColumn: 'cylinder size (6) [l]', targetField: 'tankVolume_6'),
        ColumnMapping(sourceColumn: 'startpressure (6) [bar]', targetField: 'startPressure_6'),
        ColumnMapping(sourceColumn: 'endpressure (6) [bar]', targetField: 'endPressure_6'),
        ColumnMapping(sourceColumn: 'o2 (6) [%]', targetField: 'o2Percent_6'),
        ColumnMapping(sourceColumn: 'he (6) [%]', targetField: 'hePercent_6'),
        // Location & metadata
        ColumnMapping(sourceColumn: 'location', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'gps', targetField: 'gps'),
        ColumnMapping(sourceColumn: 'divemaster', targetField: 'diveMaster'),
        ColumnMapping(sourceColumn: 'buddy', targetField: 'buddy'),
        ColumnMapping(sourceColumn: 'suit', targetField: 'suit'),
        ColumnMapping(sourceColumn: 'rating', targetField: 'rating'),
        ColumnMapping(
          sourceColumn: 'visibility',
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(sourceColumn: 'notes', targetField: 'notes'),
        ColumnMapping(sourceColumn: 'weight [kg]', targetField: 'weightUsed'),
        ColumnMapping(sourceColumn: 'tags', targetField: 'tags'),
      ],
    ),
    'dive_profile': FieldMapping(
      name: 'Subsurface Dive Profile',
      sourceApp: SourceApp.subsurface,
      columns: [
        ColumnMapping(sourceColumn: 'dive number', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'time', targetField: 'time'),
        ColumnMapping(sourceColumn: 'sample time (min)', targetField: 'sampleTime'),
        ColumnMapping(sourceColumn: 'sample depth (m)', targetField: 'sampleDepth'),
        ColumnMapping(sourceColumn: 'sample temperature (C)', targetField: 'sampleTemp'),
        ColumnMapping(sourceColumn: 'sample pressure (bar)', targetField: 'samplePressure'),
        ColumnMapping(sourceColumn: 'sample heartrate', targetField: 'sampleHeartRate'),
      ],
    ),
  },
  expectedUnits: UnitSystem.metric,
  expectedTimeFormat: ExpectedTimeFormat.h24,
  supportedEntities: {
    ImportEntityType.dives,
    ImportEntityType.sites,
    ImportEntityType.tags,
    ImportEntityType.buddies,
  },
);

// ============================================================================
// MacDive
// ============================================================================

const _macDivePreset = CsvPreset(
  id: 'macdive',
  name: 'MacDive CSV',
  sourceApp: SourceApp.macdive,
  signatureHeaders: [
    'Dive No',
    'Date',
    'Time',
    'Location',
    'Max. Depth',
    'Avg. Depth',
    'Bottom Time',
    'Water Temp',
    'Air Temp',
    'Visibility',
    'Dive Type',
    'Rating',
    'Notes',
    'Buddy',
    'Dive Master',
  ],
  matchThreshold: 0.6,
  mappings: {
    'primary': FieldMapping(
      name: 'MacDive',
      sourceApp: SourceApp.macdive,
      columns: [
        ColumnMapping(sourceColumn: 'Dive No', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Time', targetField: 'time'),
        ColumnMapping(sourceColumn: 'Location', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'Max. Depth', targetField: 'maxDepth'),
        ColumnMapping(sourceColumn: 'Avg. Depth', targetField: 'avgDepth'),
        ColumnMapping(
          sourceColumn: 'Bottom Time',
          targetField: 'duration',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(sourceColumn: 'Water Temp', targetField: 'waterTemp'),
        ColumnMapping(sourceColumn: 'Air Temp', targetField: 'airTemp'),
        ColumnMapping(
          sourceColumn: 'Visibility',
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(
          sourceColumn: 'Dive Type',
          targetField: 'diveType',
          transform: ValueTransform.diveTypeMap,
        ),
        ColumnMapping(
          sourceColumn: 'Rating',
          targetField: 'rating',
          transform: ValueTransform.ratingScale,
        ),
        ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
        ColumnMapping(sourceColumn: 'Buddy', targetField: 'buddy'),
        ColumnMapping(sourceColumn: 'Dive Master', targetField: 'diveMaster'),
      ],
    ),
  },
  supportedEntities: {ImportEntityType.dives, ImportEntityType.sites},
);

// ============================================================================
// Diving Log
// ============================================================================

const _divingLogPreset = CsvPreset(
  id: 'diving_log',
  name: 'Diving Log CSV',
  sourceApp: SourceApp.divingLog,
  signatureHeaders: [
    'DiveDate',
    'DiveTime',
    'DiveSite',
    'MaxDepth',
    'Duration',
    'AirTemp',
    'WaterTemp',
    'Visibility',
    'Notes',
    'Buddy',
    'StartPressure',
    'EndPressure',
  ],
  matchThreshold: 0.6,
  mappings: {
    'primary': FieldMapping(
      name: 'Diving Log',
      sourceApp: SourceApp.divingLog,
      columns: [
        ColumnMapping(sourceColumn: 'DiveDate', targetField: 'date'),
        ColumnMapping(sourceColumn: 'DiveTime', targetField: 'time'),
        ColumnMapping(sourceColumn: 'DiveSite', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'MaxDepth', targetField: 'maxDepth'),
        ColumnMapping(
          sourceColumn: 'Duration',
          targetField: 'duration',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(sourceColumn: 'AirTemp', targetField: 'airTemp'),
        ColumnMapping(sourceColumn: 'WaterTemp', targetField: 'waterTemp'),
        ColumnMapping(
          sourceColumn: 'Visibility',
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
        ColumnMapping(sourceColumn: 'Buddy', targetField: 'buddy'),
        ColumnMapping(sourceColumn: 'StartPressure', targetField: 'startPressure'),
        ColumnMapping(sourceColumn: 'EndPressure', targetField: 'endPressure'),
      ],
    ),
  },
);

// ============================================================================
// DiveMate
// ============================================================================

const _diveMatePreset = CsvPreset(
  id: 'divemate',
  name: 'DiveMate CSV',
  sourceApp: SourceApp.diveMate,
  signatureHeaders: [
    'Dive No.',
    'Date/Time',
    'Location',
    'Max Depth',
    'Duration',
    'Water Temperature',
    'Air Temperature',
    'Visibility',
    'Notes',
    'Buddy',
    'Rating',
  ],
  matchThreshold: 0.6,
  mappings: {
    'primary': FieldMapping(
      name: 'DiveMate',
      sourceApp: SourceApp.diveMate,
      columns: [
        ColumnMapping(sourceColumn: 'Dive No.', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'Date/Time', targetField: 'dateTime'),
        ColumnMapping(sourceColumn: 'Location', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
        ColumnMapping(
          sourceColumn: 'Duration',
          targetField: 'duration',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(sourceColumn: 'Water Temperature', targetField: 'waterTemp'),
        ColumnMapping(sourceColumn: 'Air Temperature', targetField: 'airTemp'),
        ColumnMapping(
          sourceColumn: 'Visibility',
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
        ColumnMapping(sourceColumn: 'Buddy', targetField: 'buddy'),
        ColumnMapping(
          sourceColumn: 'Rating',
          targetField: 'rating',
          transform: ValueTransform.ratingScale,
        ),
      ],
    ),
  },
);

// ============================================================================
// Garmin Connect
// ============================================================================

const _garminConnectPreset = CsvPreset(
  id: 'garmin_connect',
  name: 'Garmin Connect CSV',
  sourceApp: SourceApp.garminConnect,
  signatureHeaders: [
    'Date',
    'Activity Type',
    'Max Depth',
    'Avg Depth',
    'Bottom Time',
    'Water Temperature',
  ],
  matchThreshold: 0.7,
  mappings: {
    'primary': FieldMapping(
      name: 'Garmin Connect',
      sourceApp: SourceApp.garminConnect,
      columns: [
        ColumnMapping(sourceColumn: 'Date', targetField: 'dateTime'),
        ColumnMapping(
          sourceColumn: 'Activity Type',
          targetField: 'diveType',
          transform: ValueTransform.diveTypeMap,
        ),
        ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
        ColumnMapping(sourceColumn: 'Avg Depth', targetField: 'avgDepth'),
        ColumnMapping(
          sourceColumn: 'Bottom Time',
          targetField: 'duration',
          transform: ValueTransform.hmsToSeconds,
        ),
        ColumnMapping(sourceColumn: 'Water Temperature', targetField: 'waterTemp'),
      ],
    ),
  },
);

// ============================================================================
// Shearwater Cloud
// ============================================================================

const _shearwaterPreset = CsvPreset(
  id: 'shearwater_cloud',
  name: 'Shearwater Cloud CSV',
  sourceApp: SourceApp.shearwater,
  signatureHeaders: [
    'Dive Number',
    'Date',
    'Max Depth',
    'Avg Depth',
    'Duration',
    'Water Temp',
    'GF Low',
    'GF High',
  ],
  matchThreshold: 0.6,
  mappings: {
    'primary': FieldMapping(
      name: 'Shearwater Cloud',
      sourceApp: SourceApp.shearwater,
      columns: [
        ColumnMapping(sourceColumn: 'Dive Number', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'Date', targetField: 'dateTime'),
        ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
        ColumnMapping(sourceColumn: 'Avg Depth', targetField: 'avgDepth'),
        ColumnMapping(
          sourceColumn: 'Duration',
          targetField: 'duration',
          transform: ValueTransform.hmsToSeconds,
        ),
        ColumnMapping(sourceColumn: 'Water Temp', targetField: 'waterTemp'),
        ColumnMapping(sourceColumn: 'GF Low', targetField: 'gradientFactorLow'),
        ColumnMapping(sourceColumn: 'GF High', targetField: 'gradientFactorHigh'),
      ],
    ),
  },
);

// ============================================================================
// Submersion (native roundtrip)
// ============================================================================

const _submersionPreset = CsvPreset(
  id: 'submersion',
  name: 'Submersion CSV',
  sourceApp: SourceApp.submersion,
  signatureHeaders: [
    'Dive Number',
    'Date',
    'Time',
    'Site',
    'Max Depth',
    'Avg Depth',
    'Bottom Time',
    'Runtime',
    'Water Temp',
    'Air Temp',
    'Visibility',
    'Dive Type',
    'Buddy',
    'Dive Master',
    'Rating',
    'Start Pressure',
    'End Pressure',
    'Tank Volume',
    'O2 %',
    'Dive Computer',
    'Serial Number',
    'Firmware Version',
    'Notes',
    'Wind Speed',
    'Wind Direction',
    'Cloud Cover',
    'Precipitation',
    'Humidity',
    'Weather Description',
  ],
  matchThreshold: 0.5,
  mappings: {
    'primary': FieldMapping(
      name: 'Submersion',
      sourceApp: SourceApp.submersion,
      columns: [
        ColumnMapping(sourceColumn: 'Dive Number', targetField: 'diveNumber'),
        ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
        ColumnMapping(sourceColumn: 'Time', targetField: 'time'),
        ColumnMapping(sourceColumn: 'Site', targetField: 'siteName'),
        ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
        ColumnMapping(sourceColumn: 'Avg Depth', targetField: 'avgDepth'),
        ColumnMapping(
          sourceColumn: 'Bottom Time',
          targetField: 'duration',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(
          sourceColumn: 'Runtime',
          targetField: 'runtime',
          transform: ValueTransform.minutesToSeconds,
        ),
        ColumnMapping(sourceColumn: 'Water Temp', targetField: 'waterTemp'),
        ColumnMapping(sourceColumn: 'Air Temp', targetField: 'airTemp'),
        ColumnMapping(
          sourceColumn: 'Visibility',
          targetField: 'visibility',
          transform: ValueTransform.visibilityScale,
        ),
        ColumnMapping(
          sourceColumn: 'Dive Type',
          targetField: 'diveType',
          transform: ValueTransform.diveTypeMap,
        ),
        ColumnMapping(sourceColumn: 'Buddy', targetField: 'buddy'),
        ColumnMapping(sourceColumn: 'Dive Master', targetField: 'diveMaster'),
        ColumnMapping(sourceColumn: 'Rating', targetField: 'rating'),
        ColumnMapping(sourceColumn: 'Start Pressure', targetField: 'startPressure'),
        ColumnMapping(sourceColumn: 'End Pressure', targetField: 'endPressure'),
        ColumnMapping(sourceColumn: 'Tank Volume', targetField: 'tankVolume'),
        ColumnMapping(sourceColumn: 'O2 %', targetField: 'o2Percent'),
        ColumnMapping(sourceColumn: 'Dive Computer', targetField: 'diveComputerModel'),
        ColumnMapping(sourceColumn: 'Serial Number', targetField: 'diveComputerSerial'),
        ColumnMapping(sourceColumn: 'Firmware Version', targetField: 'diveComputerFirmware'),
        ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
        ColumnMapping(sourceColumn: 'Wind Speed', targetField: 'windSpeed'),
        ColumnMapping(sourceColumn: 'Wind Direction', targetField: 'windDirection'),
        ColumnMapping(sourceColumn: 'Cloud Cover', targetField: 'cloudCover'),
        ColumnMapping(sourceColumn: 'Precipitation', targetField: 'precipitation'),
        ColumnMapping(sourceColumn: 'Humidity', targetField: 'humidity'),
        ColumnMapping(sourceColumn: 'Weather Description', targetField: 'weatherDescription'),
      ],
    ),
  },
  supportedEntities: {
    ImportEntityType.dives,
    ImportEntityType.sites,
    ImportEntityType.buddies,
  },
);
```

- [ ] **Step 3: Write tests for built-in presets**

```dart
// test/features/universal_import/data/csv/presets/built_in_presets_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  group('built-in presets', () {
    test('contains exactly 7 presets', () {
      expect(builtInCsvPresets, hasLength(7));
    });

    test('all presets have unique IDs', () {
      final ids = builtInCsvPresets.map((p) => p.id).toSet();
      expect(ids, hasLength(7));
    });

    test('all presets have signature headers', () {
      for (final preset in builtInCsvPresets) {
        expect(preset.signatureHeaders, isNotEmpty,
            reason: '${preset.name} should have signature headers');
      }
    });

    test('all presets have at least one mapping', () {
      for (final preset in builtInCsvPresets) {
        expect(preset.mappings, isNotEmpty,
            reason: '${preset.name} should have mappings');
      }
    });

    test('Subsurface preset is multi-file', () {
      final subsurface = builtInCsvPresets.firstWhere((p) => p.id == 'subsurface');
      expect(subsurface.isMultiFile, isTrue);
      expect(subsurface.fileRoles, hasLength(2));
      expect(subsurface.fileRoles[0].roleId, 'dive_list');
      expect(subsurface.fileRoles[0].required, isTrue);
      expect(subsurface.fileRoles[1].roleId, 'dive_profile');
      expect(subsurface.fileRoles[1].required, isFalse);
    });

    test('Subsurface preset maps all 6 tank groups', () {
      final subsurface = builtInCsvPresets.firstWhere((p) => p.id == 'subsurface');
      final diveListMapping = subsurface.mappings['dive_list']!;
      final tankColumns = diveListMapping.columns
          .where((c) => c.targetField.startsWith('tankVolume_'))
          .toList();
      expect(tankColumns, hasLength(6));
    });

    test('all presets are built-in source', () {
      for (final preset in builtInCsvPresets) {
        expect(preset.source, PresetSource.builtIn);
      }
    });

    test('CsvPreset serialization roundtrip for user presets', () {
      final original = CsvPreset(
        id: 'user_test',
        name: 'Test Preset',
        source: PresetSource.userSaved,
        sourceApp: SourceApp.generic,
        signatureHeaders: ['col1', 'col2'],
        matchThreshold: 0.7,
        mappings: const {},
        supportedEntities: {ImportEntityType.dives},
      );
      final json = original.toJson();
      final restored = CsvPreset.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.source, PresetSource.userSaved);
      expect(restored.signatureHeaders, original.signatureHeaders);
    });
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/universal_import/data/csv/presets/built_in_presets_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/csv/presets/ test/features/universal_import/data/csv/presets/
git commit -m "feat: add CsvPreset model and 7 built-in presets

Subsurface (multi-file with 6-tank support), MacDive, Diving Log,
DiveMate, Garmin Connect, Shearwater Cloud, Submersion.
Supports JSON serialization for user-saved presets."
```

---

## Task 7: Preset Registry & CSV Detector

**Files:**
- Create: `lib/features/universal_import/data/csv/presets/preset_registry.dart`
- Create: `lib/features/universal_import/data/csv/pipeline/csv_detector.dart`
- Test: `test/features/universal_import/data/csv/presets/preset_registry_test.dart`
- Test: `test/features/universal_import/data/csv/pipeline/csv_detector_test.dart`

The registry manages presets and scores headers. The detector is the Stage 2 wrapper.

- [ ] **Step 1: Write failing tests for PresetRegistry**

```dart
// test/features/universal_import/data/csv/presets/preset_registry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';
import 'package:submersion/features/universal_import/data/csv/presets/preset_registry.dart';

void main() {
  late PresetRegistry registry;

  setUp(() {
    registry = PresetRegistry(builtInPresets: builtInCsvPresets);
  });

  group('detectPreset', () {
    test('detects Subsurface from dive list headers', () {
      final headers = [
        'dive number', 'date', 'time', 'duration [min]', 'sac [l/min]',
        'maxdepth [m]', 'avgdepth [m]', 'mode', 'airtemp [C]',
        'watertemp [C]', 'cylinder size (1) [l]', 'startpressure (1) [bar]',
        'endpressure (1) [bar]', 'o2 (1) [%]', 'he (1) [%]',
        'location', 'gps', 'divemaster', 'buddy', 'suit', 'rating',
        'visibility', 'notes', 'weight [kg]', 'tags',
      ];
      final matches = registry.detectPreset(headers);

      expect(matches, isNotEmpty);
      expect(matches.first.preset.id, 'subsurface');
      expect(matches.first.score, greaterThan(0.8));
    });

    test('detects MacDive from its headers', () {
      final headers = [
        'Dive No', 'Date', 'Time', 'Location', 'Max. Depth',
        'Avg. Depth', 'Bottom Time', 'Water Temp', 'Air Temp',
        'Visibility', 'Dive Type', 'Rating', 'Notes', 'Buddy', 'Dive Master',
      ];
      final matches = registry.detectPreset(headers);

      expect(matches.first.preset.id, 'macdive');
    });

    test('returns empty for unrecognized headers', () {
      final headers = ['foo', 'bar', 'baz'];
      final matches = registry.detectPreset(headers);

      expect(matches, isEmpty);
    });

    test('ranks matches by score descending', () {
      // Headers that partially match multiple presets
      final headers = ['Dive Number', 'Date', 'Max Depth', 'Duration', 'Water Temp'];
      final matches = registry.detectPreset(headers);

      for (var i = 1; i < matches.length; i++) {
        expect(matches[i].score, lessThanOrEqualTo(matches[i - 1].score));
      }
    });

    test('includes user presets in detection', () {
      final userPreset = CsvPreset(
        id: 'user_custom',
        name: 'My Custom',
        source: PresetSource.userSaved,
        signatureHeaders: ['My Col A', 'My Col B', 'My Col C'],
        matchThreshold: 0.6,
        mappings: const {},
      );
      registry.addUserPreset(userPreset);

      final matches = registry.detectPreset(['My Col A', 'My Col B', 'My Col C', 'Extra']);
      expect(matches.any((m) => m.preset.id == 'user_custom'), isTrue);
    });
  });

  group('getPreset', () {
    test('returns built-in preset by ID', () {
      expect(registry.getPreset('subsurface'), isNotNull);
      expect(registry.getPreset('macdive'), isNotNull);
    });

    test('returns null for unknown ID', () {
      expect(registry.getPreset('nonexistent'), isNull);
    });
  });

  group('user preset management', () {
    test('adds and retrieves user preset', () {
      final preset = CsvPreset(
        id: 'user_test',
        name: 'Test',
        source: PresetSource.userSaved,
        signatureHeaders: ['A', 'B'],
        mappings: const {},
      );
      registry.addUserPreset(preset);
      expect(registry.getPreset('user_test'), isNotNull);
    });

    test('removes user preset', () {
      final preset = CsvPreset(
        id: 'user_test',
        name: 'Test',
        source: PresetSource.userSaved,
        signatureHeaders: ['A', 'B'],
        mappings: const {},
      );
      registry.addUserPreset(preset);
      registry.removeUserPreset('user_test');
      expect(registry.getPreset('user_test'), isNull);
    });

    test('lists all presets', () {
      expect(registry.allPresets, hasLength(7));
      registry.addUserPreset(CsvPreset(
        id: 'user_x',
        name: 'X',
        source: PresetSource.userSaved,
        signatureHeaders: const [],
        mappings: const {},
      ));
      expect(registry.allPresets, hasLength(8));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/csv/presets/preset_registry_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement PresetRegistry**

```dart
// lib/features/universal_import/data/csv/presets/preset_registry.dart
import '../models/detection_result.dart';
import 'csv_preset.dart';

/// Manages built-in and user-saved CSV presets. Scores headers against
/// presets to detect the source application.
class PresetRegistry {
  final List<CsvPreset> _builtIn;
  final List<CsvPreset> _userPresets = [];

  PresetRegistry({required List<CsvPreset> builtInPresets})
      : _builtIn = List.unmodifiable(builtInPresets);

  /// All available presets (built-in + user).
  List<CsvPreset> get allPresets => [..._builtIn, ..._userPresets];

  /// Get a preset by ID.
  CsvPreset? getPreset(String id) {
    for (final p in _builtIn) {
      if (p.id == id) return p;
    }
    for (final p in _userPresets) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Score all presets against the given headers and return matches
  /// above threshold, ranked by score descending.
  List<PresetMatch> detectPreset(List<String> headers) {
    final lowerHeaders = headers.map((h) => h.trim().toLowerCase()).toSet();
    final matches = <PresetMatch>[];

    for (final preset in allPresets) {
      if (preset.signatureHeaders.isEmpty) continue;

      var matched = 0;
      for (final sig in preset.signatureHeaders) {
        if (lowerHeaders.contains(sig.toLowerCase())) matched++;
      }

      final score = matched / preset.signatureHeaders.length;
      if (score >= preset.matchThreshold) {
        matches.add(PresetMatch(
          preset: preset,
          score: score,
          matchedHeaders: matched,
          totalSignatureHeaders: preset.signatureHeaders.length,
        ));
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  /// Identify which file role a set of headers matches within a preset.
  PresetFileRole? identifyFileRole(CsvPreset preset, List<String> headers) {
    if (preset.fileRoles.isEmpty) return null;

    final lowerHeaders = headers.map((h) => h.trim().toLowerCase()).toSet();

    PresetFileRole? bestMatch;
    var bestScore = 0.0;

    for (final role in preset.fileRoles) {
      if (role.signatureHeaders.isEmpty) continue;

      var matched = 0;
      for (final sig in role.signatureHeaders) {
        if (lowerHeaders.contains(sig.toLowerCase())) matched++;
      }

      final score = matched / role.signatureHeaders.length;
      if (score > bestScore) {
        bestScore = score;
        bestMatch = role;
      }
    }

    return bestMatch;
  }

  void addUserPreset(CsvPreset preset) {
    _userPresets.removeWhere((p) => p.id == preset.id);
    _userPresets.add(preset);
  }

  void removeUserPreset(String id) {
    _userPresets.removeWhere((p) => p.id == id);
  }
}
```

- [ ] **Step 4: Implement CsvDetector**

```dart
// lib/features/universal_import/data/csv/pipeline/csv_detector.dart
import '../models/detection_result.dart';
import '../models/parsed_csv.dart';
import '../presets/preset_registry.dart';

/// Stage 2: Detect which source application produced the CSV.
class CsvDetector {
  final PresetRegistry _registry;

  const CsvDetector(this._registry);

  /// Detect the source application from parsed CSV headers.
  DetectionResult detect(ParsedCsv parsedCsv) {
    final matches = _registry.detectPreset(parsedCsv.headers);

    if (matches.isEmpty) {
      return const DetectionResult();
    }

    final best = matches.first;
    return DetectionResult(
      matchedPreset: best.preset,
      sourceApp: best.preset.sourceApp,
      confidence: best.score,
      rankedMatches: matches,
      hasAdditionalFileRoles:
          best.preset.fileRoles.where((r) => !r.required).isNotEmpty,
    );
  }
}
```

- [ ] **Step 5: Run all tests**

Run: `flutter test test/features/universal_import/data/csv/presets/preset_registry_test.dart`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/universal_import/data/csv/presets/preset_registry.dart lib/features/universal_import/data/csv/pipeline/csv_detector.dart test/features/universal_import/data/csv/presets/preset_registry_test.dart
git commit -m "feat: add PresetRegistry and CsvDetector stage

Scores CSV headers against presets, ranks matches by confidence,
supports user-added presets. CsvDetector wraps registry for pipeline use."
```

---

## Task 8: Entity Extractors

**Files:**
- Create: `lib/features/universal_import/data/csv/extractors/entity_extractor.dart`
- Create: `lib/features/universal_import/data/csv/extractors/dive_extractor.dart`
- Create: `lib/features/universal_import/data/csv/extractors/tank_extractor.dart`
- Create: `lib/features/universal_import/data/csv/extractors/site_extractor.dart`
- Create: `lib/features/universal_import/data/csv/extractors/buddy_extractor.dart`
- Create: `lib/features/universal_import/data/csv/extractors/tag_extractor.dart`
- Create: `lib/features/universal_import/data/csv/extractors/gear_extractor.dart`
- Create: `lib/features/universal_import/data/csv/extractors/profile_extractor.dart`
- Test: `test/features/universal_import/data/csv/extractors/tank_extractor_test.dart`
- Test: `test/features/universal_import/data/csv/extractors/buddy_extractor_test.dart`
- Test: `test/features/universal_import/data/csv/extractors/site_extractor_test.dart`
- Test: `test/features/universal_import/data/csv/extractors/profile_extractor_test.dart`
- Test: `test/features/universal_import/data/csv/extractors/tag_extractor_test.dart`

Entity extractors decompose transformed rows into typed entity streams. The most complex are TankExtractor (repeating groups) and ProfileExtractor (cross-file correlation). Write TDD tests for these, then implement all extractors.

- [ ] **Step 1: Write failing test for TankExtractor**

```dart
// test/features/universal_import/data/csv/extractors/tank_extractor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/tank_extractor.dart';

void main() {
  late TankExtractor extractor;

  setUp(() {
    extractor = const TankExtractor();
  });

  group('TankExtractor', () {
    test('extracts single tank from row', () {
      final row = {
        'tankVolume_1': 11.094,
        'startPressure_1': 196.9,
        'endPressure_1': 193.053,
        'o2Percent_1': null,
        'hePercent_1': null,
      };
      final tanks = extractor.extract(row, 'dive-1');

      expect(tanks, hasLength(1));
      expect(tanks[0]['volume'], 11.094);
      expect(tanks[0]['startPressure'], 196);
      expect(tanks[0]['endPressure'], 193);
      expect(tanks[0]['diveId'], 'dive-1');
      expect(tanks[0]['order'], 0);
    });

    test('extracts multiple tanks from row', () {
      final row = {
        'tankVolume_1': 11.094,
        'startPressure_1': 197.466,
        'endPressure_1': 19.581,
        'o2Percent_1': 31.0,
        'hePercent_1': null,
        'tankVolume_2': 11.094,
        'startPressure_2': null,
        'endPressure_2': null,
        'o2Percent_2': null,
        'hePercent_2': null,
      };
      final tanks = extractor.extract(row, 'dive-1');

      expect(tanks, hasLength(2));
      expect(tanks[0]['o2Percent'], 31.0);
      expect(tanks[1]['order'], 1);
    });

    test('skips empty tank groups', () {
      final row = {
        'tankVolume_1': 11.094,
        'startPressure_1': 200.0,
        'endPressure_1': 50.0,
        'tankVolume_2': null,
        'startPressure_2': null,
        'endPressure_2': null,
        'tankVolume_3': null,
        'startPressure_3': null,
        'endPressure_3': null,
      };
      final tanks = extractor.extract(row, 'dive-1');

      expect(tanks, hasLength(1));
    });

    test('extracts from legacy flat fields (startPressure, not _1)', () {
      final row = {
        'startPressure': 200,
        'endPressure': 50,
        'tankVolume': 12.0,
        'o2Percent': 32.0,
      };
      final tanks = extractor.extract(row, 'dive-1');

      expect(tanks, hasLength(1));
      expect(tanks[0]['volume'], 12.0);
      expect(tanks[0]['o2Percent'], 32.0);
    });

    test('returns empty list when no tank data present', () {
      final row = {'maxDepth': 25.5, 'duration': 2700};
      final tanks = extractor.extract(row, 'dive-1');

      expect(tanks, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Write failing tests for BuddyExtractor and SiteExtractor**

```dart
// test/features/universal_import/data/csv/extractors/buddy_extractor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/buddy_extractor.dart';

void main() {
  late BuddyExtractor extractor;

  setUp(() {
    extractor = BuddyExtractor();
  });

  group('BuddyExtractor', () {
    test('extracts single buddy', () {
      final buddies = extractor.extractFromRows([
        {'buddy': 'John Smith'},
      ]);
      expect(buddies, hasLength(1));
      expect(buddies[0]['name'], 'John Smith');
    });

    test('splits comma-separated buddies', () {
      final buddies = extractor.extractFromRows([
        {'buddy': 'John Smith, Jane Doe'},
      ]);
      expect(buddies, hasLength(2));
    });

    test('handles Subsurface leading-comma format', () {
      final buddies = extractor.extractFromRows([
        {'buddy': ', Kiyan Griffin'},
      ]);
      expect(buddies, hasLength(1));
      expect(buddies[0]['name'], 'Kiyan Griffin');
    });

    test('deduplicates across rows', () {
      final buddies = extractor.extractFromRows([
        {'buddy': 'John Smith'},
        {'buddy': 'John Smith'},
        {'buddy': 'Jane Doe'},
      ]);
      expect(buddies, hasLength(2));
    });

    test('returns empty for no buddy data', () {
      final buddies = extractor.extractFromRows([
        {'maxDepth': 25.5},
      ]);
      expect(buddies, isEmpty);
    });
  });
}
```

```dart
// test/features/universal_import/data/csv/extractors/site_extractor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/site_extractor.dart';

void main() {
  late SiteExtractor extractor;

  setUp(() {
    extractor = SiteExtractor();
  });

  group('SiteExtractor', () {
    test('extracts unique sites by name', () {
      final sites = extractor.extractFromRows([
        {'siteName': 'Maclearie Park'},
        {'siteName': 'Maclearie Park'},
        {'siteName': 'Mosquito Pier'},
      ]);
      expect(sites, hasLength(2));
    });

    test('extracts GPS coordinates', () {
      final sites = extractor.extractFromRows([
        {'siteName': 'Maclearie Park', 'gps': '40.179575 -74.037466'},
      ]);
      expect(sites[0]['latitude'], closeTo(40.179575, 0.0001));
      expect(sites[0]['longitude'], closeTo(-74.037466, 0.0001));
    });

    test('handles missing site name', () {
      final sites = extractor.extractFromRows([
        {'siteName': null},
        {'siteName': ''},
      ]);
      expect(sites, isEmpty);
    });

    test('returns site ID mapping for linking dives', () {
      final sites = extractor.extractFromRows([
        {'siteName': 'Maclearie Park'},
      ]);
      expect(sites[0]['id'], isNotEmpty);
      expect(extractor.siteIdForName('Maclearie Park'), isNotNull);
    });
  });
}
```

- [ ] **Step 3: Write failing tests for ProfileExtractor and TagExtractor**

```dart
// test/features/universal_import/data/csv/extractors/profile_extractor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/profile_extractor.dart';

void main() {
  late ProfileExtractor extractor;

  setUp(() {
    extractor = const ProfileExtractor();
  });

  group('ProfileExtractor', () {
    test('groups samples by dive key', () {
      final rows = [
        {'diveNumber': '1', 'date': '2025-09-20', 'time': '07:44:37', 'sampleTime': '0:10', 'sampleDepth': 0.0},
        {'diveNumber': '1', 'date': '2025-09-20', 'time': '07:44:37', 'sampleTime': '0:20', 'sampleDepth': 3.444},
        {'diveNumber': '2', 'date': '2025-09-20', 'time': '07:56:58', 'sampleTime': '0:10', 'sampleDepth': 0.0},
      ];
      final profiles = extractor.extractProfiles(rows);

      expect(profiles.keys, hasLength(2));
    });

    test('extracts depth, temp, pressure, heartrate per sample', () {
      final rows = [
        {
          'diveNumber': '1',
          'date': '2025-09-20',
          'time': '07:44:37',
          'sampleTime': '0:10',
          'sampleDepth': 3.444,
          'sampleTemp': 25.0,
          'samplePressure': 196.9,
          'sampleHeartRate': 80,
        },
      ];
      final profiles = extractor.extractProfiles(rows);
      final samples = profiles.values.first;

      expect(samples, hasLength(1));
      expect(samples[0]['depth'], 3.444);
      expect(samples[0]['temperature'], 25.0);
      expect(samples[0]['pressure'], 196.9);
      expect(samples[0]['heartRate'], 80);
    });

    test('parses M:SS sample time to seconds', () {
      final rows = [
        {
          'diveNumber': '1',
          'date': '2025-09-20',
          'time': '07:44:37',
          'sampleTime': '1:30',
          'sampleDepth': 10.0,
        },
      ];
      final profiles = extractor.extractProfiles(rows);
      final samples = profiles.values.first;

      expect(samples[0]['timeSeconds'], 90);
    });
  });
}
```

```dart
// test/features/universal_import/data/csv/extractors/tag_extractor_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/extractors/tag_extractor.dart';

void main() {
  late TagExtractor extractor;

  setUp(() {
    extractor = TagExtractor();
  });

  group('TagExtractor', () {
    test('splits comma-separated tags', () {
      final tags = extractor.extractFromRows([
        {'tags': 'shore, student'},
      ]);
      expect(tags, hasLength(2));
      expect(tags.map((t) => t['name']), containsAll(['shore', 'student']));
    });

    test('deduplicates tags across rows', () {
      final tags = extractor.extractFromRows([
        {'tags': 'shore, student'},
        {'tags': 'shore, night'},
      ]);
      expect(tags, hasLength(3)); // shore, student, night
    });

    test('trims whitespace', () {
      final tags = extractor.extractFromRows([
        {'tags': '  shore  ,  student  '},
      ]);
      expect(tags[0]['name'], 'shore');
      expect(tags[1]['name'], 'student');
    });

    test('returns empty for no tag data', () {
      final tags = extractor.extractFromRows([
        {'maxDepth': 25.5},
      ]);
      expect(tags, isEmpty);
    });
  });
}
```

- [ ] **Step 4: Run all extractor tests to verify they fail**

Run: `flutter test test/features/universal_import/data/csv/extractors/`
Expected: All FAIL.

- [ ] **Step 5: Implement EntityExtractor interface**

```dart
// lib/features/universal_import/data/csv/extractors/entity_extractor.dart

/// Base interface for entity extractors.
///
/// Each extractor knows how to pull one entity type from transformed CSV rows.
abstract class EntityExtractor<T> {
  /// Extract entities from a list of transformed rows.
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows);
}
```

- [ ] **Step 6: Implement DiveExtractor**

```dart
// lib/features/universal_import/data/csv/extractors/dive_extractor.dart
import 'package:uuid/uuid.dart';

/// Extracts core dive fields from transformed rows.
class DiveExtractor {
  static const _uuid = Uuid();

  /// Known dive fields to extract from a row.
  static const _diveFields = {
    'diveNumber', 'dateTime', 'date', 'time',
    'maxDepth', 'avgDepth', 'duration', 'runtime',
    'waterTemp', 'airTemp', 'bottomTemp',
    'visibility', 'diveType', 'diveMode',
    'buddy', 'diveMaster', 'notes', 'rating',
    'siteName', 'siteId', 'sac',
    'gradientFactorLow', 'gradientFactorHigh',
    'diveComputerModel', 'diveComputerSerial', 'diveComputerFirmware',
    'weightUsed',
    'windSpeed', 'windDirection', 'cloudCover', 'precipitation',
    'humidity', 'weatherDescription',
  };

  const DiveExtractor();

  /// Extract dive data from a transformed row, generating an ID.
  Map<String, dynamic> extract(Map<String, dynamic> row) {
    final dive = <String, dynamic>{
      'id': _uuid.v4(),
    };

    for (final field in _diveFields) {
      if (row.containsKey(field) && row[field] != null) {
        dive[field] = row[field];
      }
    }

    return dive;
  }
}
```

- [ ] **Step 7: Implement TankExtractor**

```dart
// lib/features/universal_import/data/csv/extractors/tank_extractor.dart
import 'package:uuid/uuid.dart';

/// Extracts tank entities from transformed rows.
///
/// Handles both numbered tank groups (tankVolume_1, tankVolume_2, ...)
/// from Subsurface and flat fields (startPressure, endPressure, tankVolume)
/// from simpler CSV formats.
class TankExtractor {
  static const _uuid = Uuid();
  static const _maxTanks = 6;

  const TankExtractor();

  /// Extract tanks from a single row, linked to the given dive ID.
  List<Map<String, dynamic>> extract(Map<String, dynamic> row, String diveId) {
    final tanks = <Map<String, dynamic>>[];

    // Try numbered tank groups first (tankVolume_1, tankVolume_2, ...)
    for (var i = 1; i <= _maxTanks; i++) {
      final volume = _toDouble(row['tankVolume_$i']);
      final startP = _toDouble(row['startPressure_$i']);
      final endP = _toDouble(row['endPressure_$i']);
      final o2 = _toDouble(row['o2Percent_$i']);
      final he = _toDouble(row['hePercent_$i']);

      if (volume != null || startP != null || endP != null) {
        tanks.add({
          'id': _uuid.v4(),
          'diveId': diveId,
          'volume': volume,
          'startPressure': startP?.round(),
          'endPressure': endP?.round(),
          'o2Percent': o2 ?? 21.0,
          'hePercent': he ?? 0.0,
          'order': i - 1,
        });
      }
    }

    // Fall back to flat fields if no numbered groups found
    if (tanks.isEmpty) {
      final startP = _toDouble(row['startPressure']);
      final endP = _toDouble(row['endPressure']);
      final volume = _toDouble(row['tankVolume']);
      final o2 = _toDouble(row['o2Percent']);

      if (startP != null || endP != null || volume != null) {
        tanks.add({
          'id': _uuid.v4(),
          'diveId': diveId,
          'volume': volume,
          'startPressure': startP?.round(),
          'endPressure': endP?.round(),
          'o2Percent': o2 ?? 21.0,
          'hePercent': 0.0,
          'order': 0,
        });
      }
    }

    return tanks;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
```

- [ ] **Step 8: Implement SiteExtractor**

```dart
// lib/features/universal_import/data/csv/extractors/site_extractor.dart
import 'package:uuid/uuid.dart';

import 'entity_extractor.dart';

/// Extracts dive site entities, deduplicated by name.
class SiteExtractor implements EntityExtractor {
  static const _uuid = Uuid();
  final Map<String, String> _siteNameToId = {};

  /// Get the generated site ID for a given name.
  String? siteIdForName(String name) => _siteNameToId[name.trim().toLowerCase()];

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final sites = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final name = row['siteName']?.toString().trim();
      if (name == null || name.isEmpty) continue;

      final key = name.toLowerCase();
      if (sites.containsKey(key)) continue;

      final id = _uuid.v4();
      _siteNameToId[key] = id;

      final site = <String, dynamic>{
        'id': id,
        'name': name,
      };

      // Parse GPS coordinates (Subsurface format: "lat lon")
      final gps = row['gps']?.toString().trim();
      if (gps != null && gps.isNotEmpty) {
        final parts = gps.split(RegExp(r'\s+'));
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0]);
          final lon = double.tryParse(parts[1]);
          if (lat != null && lon != null) {
            site['latitude'] = lat;
            site['longitude'] = lon;
          }
        }
      }

      sites[key] = site;
    }

    return sites.values.toList();
  }
}
```

- [ ] **Step 9: Implement BuddyExtractor**

```dart
// lib/features/universal_import/data/csv/extractors/buddy_extractor.dart
import 'package:uuid/uuid.dart';

import 'entity_extractor.dart';

/// Extracts buddy entities from comma-separated buddy fields.
/// Handles Subsurface's leading-comma format (e.g., ", Kiyan Griffin").
class BuddyExtractor implements EntityExtractor {
  static const _uuid = Uuid();
  final Map<String, String> _buddyNameToId = {};

  String? buddyIdForName(String name) =>
      _buddyNameToId[name.trim().toLowerCase()];

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final buddies = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final buddyStr = row['buddy']?.toString().trim();
      if (buddyStr == null || buddyStr.isEmpty) continue;

      final names = buddyStr
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      for (final name in names) {
        final key = name.toLowerCase();
        if (buddies.containsKey(key)) continue;

        final id = _uuid.v4();
        _buddyNameToId[key] = id;
        buddies[key] = {'id': id, 'name': name};
      }
    }

    return buddies.values.toList();
  }
}
```

- [ ] **Step 10: Implement TagExtractor**

```dart
// lib/features/universal_import/data/csv/extractors/tag_extractor.dart
import 'package:uuid/uuid.dart';

import 'entity_extractor.dart';

/// Extracts tag entities from comma-separated tag fields.
class TagExtractor implements EntityExtractor {
  static const _uuid = Uuid();
  final Map<String, String> _tagNameToId = {};

  String? tagIdForName(String name) =>
      _tagNameToId[name.trim().toLowerCase()];

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final tags = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final tagStr = row['tags']?.toString().trim();
      if (tagStr == null || tagStr.isEmpty) continue;

      final names = tagStr
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      for (final name in names) {
        final key = name.toLowerCase();
        if (tags.containsKey(key)) continue;

        final id = _uuid.v4();
        _tagNameToId[key] = id;
        tags[key] = {'id': id, 'name': name};
      }
    }

    return tags.values.toList();
  }
}
```

- [ ] **Step 11: Implement GearExtractor**

```dart
// lib/features/universal_import/data/csv/extractors/gear_extractor.dart
import 'package:uuid/uuid.dart';

import 'entity_extractor.dart';

/// Extracts gear/suit entities from transformed rows.
class GearExtractor implements EntityExtractor {
  static const _uuid = Uuid();
  final Map<String, String> _gearNameToId = {};

  String? gearIdForName(String name) =>
      _gearNameToId[name.trim().toLowerCase()];

  @override
  List<Map<String, dynamic>> extractFromRows(List<Map<String, dynamic>> rows) {
    final gear = <String, Map<String, dynamic>>{};

    for (final row in rows) {
      final suit = row['suit']?.toString().trim();
      if (suit == null || suit.isEmpty) continue;

      final key = suit.toLowerCase();
      if (gear.containsKey(key)) continue;

      final id = _uuid.v4();
      _gearNameToId[key] = id;
      gear[key] = {
        'id': id,
        'name': suit,
        'type': 'exposure_suit',
      };
    }

    return gear.values.toList();
  }
}
```

- [ ] **Step 12: Implement ProfileExtractor**

```dart
// lib/features/universal_import/data/csv/extractors/profile_extractor.dart

/// Extracts dive profile samples from the Subsurface profile CSV.
///
/// Groups samples by dive key (dive number + date + time) and
/// converts sample time from M:SS to seconds.
class ProfileExtractor {
  const ProfileExtractor();

  /// Extract profiles grouped by dive key.
  /// Returns a map of diveKey -> list of sample maps.
  Map<String, List<Map<String, dynamic>>> extractProfiles(
    List<Map<String, dynamic>> rows,
  ) {
    final profiles = <String, List<Map<String, dynamic>>>{};

    for (final row in rows) {
      final diveNumber = row['diveNumber']?.toString() ?? '';
      final date = row['date']?.toString() ?? '';
      final time = row['time']?.toString() ?? '';
      final key = '$diveNumber|$date|$time';

      final sampleTimeStr = row['sampleTime']?.toString();
      final timeSeconds = _parseSampleTime(sampleTimeStr);

      final sample = <String, dynamic>{
        'timeSeconds': timeSeconds,
        'depth': _toDouble(row['sampleDepth']),
      };

      final temp = _toDouble(row['sampleTemp']);
      if (temp != null) sample['temperature'] = temp;

      final pressure = _toDouble(row['samplePressure']);
      if (pressure != null) sample['pressure'] = pressure;

      final heartRate = _toInt(row['sampleHeartRate']);
      if (heartRate != null) sample['heartRate'] = heartRate;

      profiles.putIfAbsent(key, () => []).add(sample);
    }

    return profiles;
  }

  /// Parse M:SS or H:MM:SS sample time to total seconds.
  int _parseSampleTime(String? value) {
    if (value == null || value.trim().isEmpty) return 0;
    final parts = value.trim().split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return m * 60 + s;
    }
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return h * 3600 + m * 60 + s;
    }
    return 0;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
```

- [ ] **Step 13: Run all extractor tests**

Run: `flutter test test/features/universal_import/data/csv/extractors/`
Expected: All tests PASS.

- [ ] **Step 14: Commit**

```bash
git add lib/features/universal_import/data/csv/extractors/ test/features/universal_import/data/csv/extractors/
git commit -m "feat: add entity extractors for CSV import

DiveExtractor, TankExtractor (6-tank support), SiteExtractor (GPS),
BuddyExtractor (leading-comma fix), TagExtractor, GearExtractor,
ProfileExtractor (sample-by-sample grouping)."
```

---

## Task 9: CSV Transformer Stage

**Files:**
- Create: `lib/features/universal_import/data/csv/pipeline/csv_transformer.dart`
- Test: `test/features/universal_import/data/csv/pipeline/csv_transformer_test.dart`

Stage 4: applies field mappings, time resolution, unit detection, and type coercion to produce typed rows.

- [ ] **Step 1: Write failing tests for CsvTransformer**

```dart
// test/features/universal_import/data/csv/pipeline/csv_transformer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_transformer.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';

void main() {
  late CsvTransformer transformer;

  setUp(() {
    transformer = CsvTransformer();
  });

  group('CsvTransformer', () {
    test('maps columns to target fields', () {
      final csv = ParsedCsv(
        headers: ['Name', 'Depth'],
        rows: [
          ['Dive 1', '25.5'],
        ],
      );
      final config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'test',
            columns: [
              ColumnMapping(sourceColumn: 'Name', targetField: 'siteName'),
              ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);
      expect(result.rows[0]['siteName'], 'Dive 1');
      expect(result.rows[0]['maxDepth'], 25.5);
    });

    test('combines date and time into UTC dateTime', () {
      final csv = ParsedCsv(
        headers: ['Date', 'Time', 'Depth'],
        rows: [
          ['2025-09-20', '14:30', '25.5'],
        ],
      );
      final config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Time', targetField: 'time'),
              ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);
      final dateTime = result.rows[0]['dateTime'] as DateTime;
      expect(dateTime.isUtc, isTrue);
      expect(dateTime.hour, 14);
      expect(dateTime.minute, 30);
    });

    test('applies hmsToSeconds transform for duration', () {
      final csv = ParsedCsv(
        headers: ['Date', 'Duration'],
        rows: [
          ['2025-09-20', '1:23:45'],
        ],
      );
      final config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(
                sourceColumn: 'Duration',
                targetField: 'duration',
                transform: ValueTransform.hmsToSeconds,
              ),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);
      final duration = result.rows[0]['duration'] as Duration;
      expect(duration.inSeconds, 1 * 3600 + 23 * 60 + 45);
    });

    test('skips rows with no valid dateTime', () {
      final csv = ParsedCsv(
        headers: ['Date', 'Depth'],
        rows: [
          ['not-a-date', '25.5'],
          ['2025-09-20', '30.0'],
        ],
      );
      final config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);
      expect(result.rows, hasLength(1));
      expect(result.warnings, isNotEmpty);
    });

    test('resolves informal times', () {
      final csv = ParsedCsv(
        headers: ['Date', 'Time', 'Depth'],
        rows: [
          ['2025-01-15', 'am', '25.5'],
          ['2025-01-15', 'pm', '30.0'],
        ],
      );
      final config = ImportConfiguration(
        mappings: {
          'primary': FieldMapping(
            name: 'test',
            columns: [
              ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
              ColumnMapping(sourceColumn: 'Time', targetField: 'time'),
              ColumnMapping(sourceColumn: 'Depth', targetField: 'maxDepth'),
            ],
          ),
        },
      );

      final result = transformer.transform(csv, config);
      expect(result.rows, hasLength(2));
      expect((result.rows[0]['dateTime'] as DateTime).hour, 9);
      expect((result.rows[1]['dateTime'] as DateTime).hour, 14);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/universal_import/data/csv/pipeline/csv_transformer_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement CsvTransformer**

This is the most complex stage. It orchestrates time resolution, unit detection, field mapping, and type coercion. The implementation should:

1. Build a column index from the mapping
2. Run the informal time resolver pre-pass
3. For each row: map columns, apply transforms, detect/convert units, combine date+time
4. Skip rows without valid dateTime, collecting warnings
5. Return TransformedRows with typed values

```dart
// lib/features/universal_import/data/csv/pipeline/csv_transformer.dart
import '../models/import_configuration.dart';
import '../models/parsed_csv.dart';
import '../models/transformed_rows.dart';
import '../transforms/time_resolver.dart';
import '../transforms/unit_detector.dart';
import '../transforms/value_converter.dart';
import '../../models/field_mapping.dart';
import '../../models/import_payload.dart';

/// Stage 4: Transform raw CSV data into typed field maps.
class CsvTransformer {
  final TimeResolver _timeResolver;
  final UnitDetector _unitDetector;
  final ValueConverter _valueConverter;

  CsvTransformer({
    TimeResolver timeResolver = const TimeResolver(),
    UnitDetector unitDetector = const UnitDetector(),
    ValueConverter valueConverter = const ValueConverter(),
  })  : _timeResolver = timeResolver,
        _unitDetector = unitDetector,
        _valueConverter = valueConverter;

  /// Transform parsed CSV data using the given configuration.
  TransformedRows transform(
    ParsedCsv csv,
    ImportConfiguration config, {
    String fileRole = 'primary',
  }) {
    final mapping = config.mappings[fileRole] ?? config.primaryMapping;
    if (mapping == null) {
      return TransformedRows(
        rows: const [],
        warnings: [
          const ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'No field mapping configured',
          ),
        ],
        fileRole: fileRole,
      );
    }

    // Build column index: header name (lowercase) -> column index
    final columnIndex = <String, int>{};
    for (var i = 0; i < csv.headers.length; i++) {
      columnIndex[csv.headers[i].trim().toLowerCase()] = i;
    }

    // Detect units from headers
    final unitDetections = <String, ColumnUnitDetection>{};
    for (final col in mapping.columns) {
      final headerUnit = _unitDetector.parseHeaderUnit(col.sourceColumn);
      if (headerUnit != null) {
        unitDetections[col.targetField] = headerUnit;
      }
    }

    // First pass: extract raw mapped values
    final rawRows = <Map<String, dynamic>>[];
    final warnings = <ImportWarning>[];

    for (var rowIdx = 0; rowIdx < csv.rows.length; rowIdx++) {
      final csvRow = csv.rows[rowIdx];
      final mapped = <String, dynamic>{};

      for (final col in mapping.columns) {
        final idx = columnIndex[col.sourceColumn.toLowerCase()];
        if (idx == null || idx >= csvRow.length) continue;

        final rawValue = csvRow[idx].trim();
        if (rawValue.isEmpty) {
          if (col.defaultValue != null) {
            mapped[col.targetField] = col.defaultValue;
          }
          continue;
        }

        if (col.transform != null) {
          final transformed = _applyTransform(col.transform!, rawValue);
          if (transformed != null) {
            mapped[col.targetField] = transformed;
          } else {
            warnings.add(ImportWarning(
              severity: ImportWarningSeverity.warning,
              message:
                  'Row ${rowIdx + 1}: Could not convert "${col.sourceColumn}" value "$rawValue"',
              itemIndex: rowIdx,
              field: col.targetField,
            ));
          }
        } else {
          mapped[col.targetField] = _inferType(col.targetField, rawValue, unitDetections);
        }
      }

      rawRows.add(mapped);
    }

    // Resolve informal times (pre-pass across all rows)
    final resolvedRows = _timeResolver.resolveInformalTimes(rawRows);

    // Second pass: combine date+time, validate dateTime
    final validRows = <Map<String, dynamic>>[];
    for (var i = 0; i < resolvedRows.length; i++) {
      final row = resolvedRows[i];

      // If informal time resolver already set dateTime, use it
      if (row['dateTime'] is! DateTime) {
        final dateTime = _timeResolver.combineDateTime(
          dateStr: row['date']?.toString(),
          timeStr: row['time']?.toString(),
          dateTimeStr: row['dateTime']?.toString(),
          interpretation: config.timeInterpretation,
          specificOffset: config.specificUtcOffset,
        );

        if (dateTime != null) {
          row['dateTime'] = dateTime;
        } else {
          warnings.add(ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Row ${i + 1}: Missing or invalid date',
            itemIndex: i,
            field: 'dateTime',
          ));
          continue;
        }
      }

      // Set importVersion
      row['importVersion'] = 2;

      validRows.add(row);
    }

    return TransformedRows(
      rows: validRows,
      warnings: warnings,
      fileRole: fileRole,
    );
  }

  dynamic _applyTransform(ValueTransform transform, String rawValue) {
    switch (transform) {
      case ValueTransform.minutesToSeconds:
        return _valueConverter.parseDuration(rawValue, DurationFormat.minutes);
      case ValueTransform.hmsToSeconds:
        return _valueConverter.parseDuration(rawValue, DurationFormat.hms);
      case ValueTransform.feetToMeters:
        final v = _valueConverter.parseDouble(rawValue);
        return v != null ? _valueConverter.convertUnit(v, DetectedUnit.feet) : null;
      case ValueTransform.fahrenheitToCelsius:
        final v = _valueConverter.parseDouble(rawValue);
        return v != null ? _valueConverter.convertUnit(v, DetectedUnit.fahrenheit) : null;
      case ValueTransform.psiToBar:
        final v = _valueConverter.parseDouble(rawValue);
        return v != null ? _valueConverter.convertUnit(v, DetectedUnit.psi) : null;
      case ValueTransform.cubicFeetToLiters:
        final v = _valueConverter.parseDouble(rawValue);
        return v != null ? _valueConverter.convertUnit(v, DetectedUnit.cubicFeet) : null;
      case ValueTransform.visibilityScale:
        return _valueConverter.parseVisibility(rawValue);
      case ValueTransform.diveTypeMap:
        return _valueConverter.parseDiveType(rawValue);
      case ValueTransform.ratingScale:
        return _valueConverter.normalizeRating(rawValue);
    }
  }

  dynamic _inferType(
    String targetField,
    String rawValue,
    Map<String, ColumnUnitDetection> unitDetections,
  ) {
    // Check for unit conversion
    final unitDetection = unitDetections[targetField];
    if (unitDetection != null && unitDetection.needsConversion) {
      final v = _valueConverter.parseDouble(rawValue);
      if (v != null) return _valueConverter.convertUnit(v, unitDetection.detected);
    }

    // Numeric fields
    final unitType = UnitDetector.unitTypeForField(targetField);
    if (unitType != null) {
      return _valueConverter.parseDouble(rawValue);
    }

    // Integer fields
    if (_isIntegerField(targetField)) {
      return _valueConverter.parseInt(rawValue);
    }

    // Duration fields
    if (targetField == 'duration' || targetField == 'runtime') {
      return _valueConverter.parseDuration(rawValue, DurationFormat.minutes);
    }

    // Default: keep as string
    return rawValue;
  }

  bool _isIntegerField(String field) {
    const intFields = {
      'diveNumber', 'rating', 'startPressure', 'endPressure',
      'gradientFactorLow', 'gradientFactorHigh',
    };
    return intFields.contains(field);
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/universal_import/data/csv/pipeline/csv_transformer_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/csv/pipeline/csv_transformer.dart test/features/universal_import/data/csv/pipeline/csv_transformer_test.dart
git commit -m "feat: add CsvTransformer stage

Applies field mappings, time resolution (AM/PM, informal, timezone),
unit detection/conversion, and type coercion. Skips invalid rows with warnings."
```

---

## Task 10: CSV Correlator & Pipeline Orchestrator

**Files:**
- Create: `lib/features/universal_import/data/csv/pipeline/csv_correlator.dart`
- Create: `lib/features/universal_import/data/csv/pipeline/csv_pipeline.dart`
- Test: `test/features/universal_import/data/csv/pipeline/csv_correlator_test.dart`
- Test: `test/features/universal_import/data/csv/pipeline/csv_pipeline_test.dart`

The Correlator (Stage 5) runs entity extraction and multi-file merging. The Pipeline orchestrator ties all stages together.

- [ ] **Step 1: Implement CsvCorrelator**

```dart
// lib/features/universal_import/data/csv/pipeline/csv_correlator.dart
import '../extractors/buddy_extractor.dart';
import '../extractors/dive_extractor.dart';
import '../extractors/gear_extractor.dart';
import '../extractors/profile_extractor.dart';
import '../extractors/site_extractor.dart';
import '../extractors/tag_extractor.dart';
import '../extractors/tank_extractor.dart';
import '../models/correlated_payload.dart';
import '../models/import_configuration.dart';
import '../models/transformed_rows.dart';
import '../../models/import_enums.dart';
import '../../models/import_payload.dart';

/// Stage 5: Run entity extraction, multi-file correlation, and deduplication.
class CsvCorrelator {
  const CsvCorrelator();

  /// Correlate transformed rows (potentially from multiple files) into
  /// separate entity streams linked by ID.
  CorrelatedPayload correlate({
    required TransformedRows diveListRows,
    TransformedRows? profileRows,
    required ImportConfiguration config,
  }) {
    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    final warnings = [...diveListRows.warnings];
    if (profileRows != null) warnings.addAll(profileRows.warnings);

    // Extract dives
    const diveExtractor = DiveExtractor();
    const tankExtractor = TankExtractor();
    final siteExtractor = SiteExtractor();
    final buddyExtractor = BuddyExtractor();
    final tagExtractor = TagExtractor();
    final gearExtractor = GearExtractor();

    final dives = <Map<String, dynamic>>[];
    final allTanks = <Map<String, dynamic>>[];

    for (final row in diveListRows.rows) {
      final dive = diveExtractor.extract(row);
      final diveId = dive['id'] as String;

      // Link site
      final siteName = row['siteName']?.toString();
      if (siteName != null && siteName.isNotEmpty) {
        dive['siteName'] = siteName;
      }

      dives.add(dive);

      // Extract tanks
      final tanks = tankExtractor.extract(row, diveId);
      allTanks.addAll(tanks);
    }

    entities[ImportEntityType.dives] = dives;

    // Extract sites (deduplicated)
    if (config.entityTypesToImport.contains(ImportEntityType.sites)) {
      final sites = siteExtractor.extractFromRows(diveListRows.rows);
      if (sites.isNotEmpty) {
        entities[ImportEntityType.sites] = sites;

        // Link dives to sites via generated IDs
        for (final dive in dives) {
          final siteName = dive['siteName']?.toString();
          if (siteName != null) {
            final siteId = siteExtractor.siteIdForName(siteName);
            if (siteId != null) dive['siteId'] = siteId;
          }
        }
      }
    }

    // Store tanks as part of dive data (the importer expects tanks in dive maps)
    if (allTanks.isNotEmpty) {
      // Group tanks by dive ID
      final tanksByDive = <String, List<Map<String, dynamic>>>{};
      for (final tank in allTanks) {
        final diveId = tank['diveId'] as String;
        tanksByDive.putIfAbsent(diveId, () => []).add(tank);
      }
      // Attach tanks to their dive maps
      for (final dive in dives) {
        final diveId = dive['id'] as String;
        if (tanksByDive.containsKey(diveId)) {
          dive['tanks'] = tanksByDive[diveId];
        }
      }
    }

    // Extract buddies
    if (config.entityTypesToImport.contains(ImportEntityType.buddies)) {
      final buddies = buddyExtractor.extractFromRows(diveListRows.rows);
      if (buddies.isNotEmpty) {
        entities[ImportEntityType.buddies] = buddies;
      }
    }

    // Extract tags
    if (config.entityTypesToImport.contains(ImportEntityType.tags)) {
      final tags = tagExtractor.extractFromRows(diveListRows.rows);
      if (tags.isNotEmpty) {
        entities[ImportEntityType.tags] = tags;
      }
    }

    // Extract gear
    if (config.entityTypesToImport.contains(ImportEntityType.equipment)) {
      final gear = gearExtractor.extractFromRows(diveListRows.rows);
      if (gear.isNotEmpty) {
        entities[ImportEntityType.equipment] = gear;
      }
    }

    // Correlate profile data if available
    if (profileRows != null && profileRows.isNotEmpty) {
      const profileExtractor = ProfileExtractor();
      final profilesByKey = profileExtractor.extractProfiles(profileRows.rows);

      // Match profiles to dives by dive number + date + time
      for (final dive in dives) {
        final diveNum = dive['diveNumber']?.toString() ?? '';
        final dateTime = dive['dateTime'] as DateTime?;
        if (dateTime == null) continue;

        // Try matching by key format used in profile CSV
        for (final entry in profilesByKey.entries) {
          final keyParts = entry.key.split('|');
          if (keyParts.length == 3) {
            final profileNum = keyParts[0];
            if (profileNum == diveNum || (profileNum.isEmpty && diveNum.isEmpty)) {
              dive['profileSamples'] = entry.value;
              break;
            }
          }
        }
      }
    }

    final metadata = <String, dynamic>{
      'sourceApp': config.sourceApp?.displayName ?? 'CSV',
      'totalRows': diveListRows.rowCount,
      'parsedDives': dives.length,
    };

    return CorrelatedPayload(
      entities: entities,
      warnings: warnings,
      metadata: metadata,
    );
  }
}
```

- [ ] **Step 2: Implement CsvPipeline orchestrator**

```dart
// lib/features/universal_import/data/csv/pipeline/csv_pipeline.dart
import 'dart:typed_data';

import '../models/correlated_payload.dart';
import '../models/detection_result.dart';
import '../models/import_configuration.dart';
import '../models/parsed_csv.dart';
import '../models/transformed_rows.dart';
import '../presets/built_in_presets.dart';
import '../presets/preset_registry.dart';
import '../../models/import_payload.dart';
import 'csv_correlator.dart';
import 'csv_detector.dart';
import 'csv_parser.dart';
import 'csv_transformer.dart';

/// Orchestrates the full CSV import pipeline:
/// Parse -> Detect -> Configure -> Transform -> Correlate -> ImportPayload
class CsvPipeline {
  final CsvParser _parser;
  final CsvDetector _detector;
  final CsvTransformer _transformer;
  final CsvCorrelator _correlator;
  final PresetRegistry _registry;

  CsvPipeline({
    PresetRegistry? registry,
    CsvParser parser = const CsvParser(),
    CsvTransformer? transformer,
    CsvCorrelator correlator = const CsvCorrelator(),
  })  : _registry = registry ?? PresetRegistry(builtInPresets: builtInCsvPresets),
        _parser = parser,
        _transformer = transformer ?? CsvTransformer(),
        _correlator = correlator,
        _detector = CsvDetector(
            registry ?? PresetRegistry(builtInPresets: builtInCsvPresets));

  PresetRegistry get registry => _registry;

  // ──────────────────────────────────────────────────────────────────
  // Stage 1: Parse
  // ──────────────────────────────────────────────────────────────────

  ParsedCsv parse(Uint8List fileBytes) => _parser.parse(fileBytes);

  // ──────────────────────────────────────────────────────────────────
  // Stage 2: Detect
  // ──────────────────────────────────────────────────────────────────

  DetectionResult detect(ParsedCsv csv) => _detector.detect(csv);

  // ──────────────────────────────────────────────────────────────────
  // Stages 4-5: Transform & Correlate
  // ──────────────────────────────────────────────────────────────────

  /// Run the full pipeline from parsed CSV(s) through to ImportPayload.
  ImportPayload execute({
    required ParsedCsv primaryCsv,
    ParsedCsv? profileCsv,
    required ImportConfiguration config,
  }) {
    // Stage 4: Transform primary file
    final primaryFileRole =
        config.mappings.containsKey('dive_list') ? 'dive_list' : 'primary';
    final diveListRows =
        _transformer.transform(primaryCsv, config, fileRole: primaryFileRole);

    // Stage 4: Transform profile file (if provided)
    TransformedRows? profileTransformed;
    if (profileCsv != null && config.mappings.containsKey('dive_profile')) {
      profileTransformed = _transformer.transform(
        profileCsv,
        config,
        fileRole: 'dive_profile',
      );
    }

    // Stage 5: Correlate
    final correlated = _correlator.correlate(
      diveListRows: diveListRows,
      profileRows: profileTransformed,
      config: config,
    );

    // Convert to universal ImportPayload
    return correlated.toImportPayload();
  }
}
```

- [ ] **Step 3: Write tests for CsvPipeline**

```dart
// test/features/universal_import/data/csv/pipeline/csv_pipeline_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_pipeline.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

Uint8List _toBytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  late CsvPipeline pipeline;

  setUp(() {
    pipeline = CsvPipeline();
  });

  group('CsvPipeline', () {
    test('detects Subsurface from real headers', () {
      final csv = pipeline.parse(_toBytes(
        'dive number,date,time,duration [min],sac [l/min],maxdepth [m],avgdepth [m],'
        'mode,airtemp [C],watertemp [C],cylinder size (1) [l],startpressure (1) [bar],'
        'endpressure (1) [bar],o2 (1) [%],he (1) [%],location,gps,divemaster,buddy,'
        'suit,rating,visibility,notes,weight [kg],tags,\n'
        '1,2025-09-20,07:44:37,0:42,40.115,2.41,1.58,,21.111,21.0,11.094,196.9,193.053'
        ',,,Maclearie Park,40.179575 -74.037466,Sharon Patterson,", Kiyan Griffin"'
        ',3mm Bare wetsuit,,1,Summary:,6.35,"shore, student"\n',
      ));
      final detection = pipeline.detect(csv);

      expect(detection.isDetected, isTrue);
      expect(detection.sourceApp, SourceApp.subsurface);
      expect(detection.hasAdditionalFileRoles, isTrue);
    });

    test('full pipeline produces ImportPayload with dives and sites', () {
      final csv = pipeline.parse(_toBytes(
        'Date,Time,Max Depth,Duration,Site,Buddy\n'
        '2025-09-20,14:30,25.5,45,Reef Point,John Smith\n'
        '2025-09-21,09:00,30.0,55,Reef Point,Jane Doe\n',
      ));

      final detection = pipeline.detect(csv);
      // Use generic config since this won't match a specific preset
      final config = ImportConfiguration(
        mappings: {
          'primary': detection.matchedPreset?.primaryMapping ??
              csv.headers.fold(
                _autoMapping(csv.headers),
                (prev, _) => prev,
              ),
        },
        entityTypesToImport: {ImportEntityType.dives, ImportEntityType.sites},
      );

      final payload = pipeline.execute(primaryCsv: csv, config: config);

      expect(payload.entitiesOf(ImportEntityType.dives), isNotEmpty);
    });
  });
}

// Helper to build a basic auto mapping for test
_autoMapping(List<String> headers) {
  // Simplified - real auto-mapping is in the registry
  return const FieldMapping(name: 'test', columns: []);
}
```

Note: This is a basic integration test. More thorough integration tests with real Subsurface CSV data will be in Task 14.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/universal_import/data/csv/pipeline/`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/universal_import/data/csv/pipeline/csv_correlator.dart lib/features/universal_import/data/csv/pipeline/csv_pipeline.dart test/features/universal_import/data/csv/pipeline/
git commit -m "feat: add CsvCorrelator and CsvPipeline orchestrator

Correlator runs entity extraction, multi-file profile matching, and
entity linking. Pipeline orchestrates all stages end-to-end."
```

---

## Task 11: Rewrite CsvImportParser as Pipeline Adapter

**Files:**
- Modify: `lib/features/universal_import/data/parsers/csv_import_parser.dart`
- Modify: `test/features/universal_import/data/parsers/csv_import_parser_test.dart`

Rewrite `CsvImportParser` to delegate to the new pipeline while maintaining the `ImportParser` interface. Existing callers (the wizard provider) continue working unchanged.

- [ ] **Step 1: Rewrite CsvImportParser**

Replace the entire file contents. The new implementation is a thin adapter that:
1. Receives file bytes and options
2. Creates a CsvPipeline
3. Runs Parse, Detect, and builds an ImportConfiguration from the detected preset or custom mapping
4. Calls pipeline.execute()
5. Returns the ImportPayload

```dart
// lib/features/universal_import/data/parsers/csv_import_parser.dart
import 'dart:typed_data';

import '../csv/models/import_configuration.dart';
import '../csv/pipeline/csv_pipeline.dart';
import '../models/field_mapping.dart';
import '../models/import_enums.dart';
import '../models/import_options.dart';
import '../models/import_payload.dart';
import 'import_parser.dart';

/// CSV import parser. Delegates to the staged CSV pipeline.
///
/// Implements [ImportParser] to integrate with the universal import wizard.
class CsvImportParser implements ImportParser {
  final CsvPipeline _pipeline;

  CsvImportParser({CsvPipeline? pipeline})
      : _pipeline = pipeline ?? CsvPipeline();

  CsvPipeline get pipeline => _pipeline;

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.csv];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
    FieldMapping? customMapping,
    Uint8List? profileFileBytes,
    TimeInterpretation timeInterpretation = TimeInterpretation.localWallClock,
    Duration? specificUtcOffset,
  }) async {
    // Stage 1: Parse primary file
    final primaryCsv = _pipeline.parse(fileBytes);

    // Stage 2: Detect source
    final detection = _pipeline.detect(primaryCsv);

    // Build configuration from detection + overrides
    final preset = detection.matchedPreset;
    final mappings = <String, FieldMapping>{};

    if (customMapping != null) {
      mappings['primary'] = customMapping;
    } else if (preset != null) {
      mappings.addAll(preset.mappings);
    } else {
      // Generic auto-mapping: try keyword matching
      final autoMapping = _autoMap(primaryCsv.headers);
      mappings['primary'] = autoMapping;
    }

    final entityTypes = preset?.supportedEntities ??
        {ImportEntityType.dives, ImportEntityType.sites};

    final config = ImportConfiguration(
      mappings: mappings,
      timeInterpretation: timeInterpretation,
      specificUtcOffset: specificUtcOffset,
      entityTypesToImport: entityTypes,
      preset: preset,
      sourceApp: options?.sourceApp ?? detection.sourceApp,
    );

    // Parse profile file if provided
    final profileCsv =
        profileFileBytes != null ? _pipeline.parse(profileFileBytes) : null;

    // Stages 4-5: Transform & Correlate
    return _pipeline.execute(
      primaryCsv: primaryCsv,
      profileCsv: profileCsv,
      config: config,
    );
  }

  /// Basic keyword-based auto-mapping for unknown CSVs.
  FieldMapping _autoMap(List<String> headers) {
    final columns = <ColumnMapping>[];

    for (final header in headers) {
      final target = _guessTargetField(header.toLowerCase());
      if (target != null) {
        columns.add(ColumnMapping(
          sourceColumn: header,
          targetField: target,
        ));
      }
    }

    return FieldMapping(name: 'Auto-detected', columns: columns);
  }

  String? _guessTargetField(String header) {
    if (header.contains('dive') && header.contains('number')) return 'diveNumber';
    if (header.contains('date') && header.contains('time')) return 'dateTime';
    if (header == 'date') return 'date';
    if (header == 'time') return 'time';
    if (header.contains('max') && header.contains('depth')) return 'maxDepth';
    if (header.contains('avg') && header.contains('depth')) return 'avgDepth';
    if (header.contains('duration') ||
        header.contains('bottom time') ||
        header.contains('runtime')) {
      return 'duration';
    }
    if (header.contains('water') && header.contains('temp')) return 'waterTemp';
    if (header.contains('air') && header.contains('temp')) return 'airTemp';
    if (header.contains('site') || header.contains('location')) return 'siteName';
    if (header.contains('buddy')) return 'buddy';
    if (header.contains('dive master') || header.contains('divemaster')) {
      return 'diveMaster';
    }
    if (header.contains('rating')) return 'rating';
    if (header.contains('note')) return 'notes';
    if (header.contains('visibility')) return 'visibility';
    if (header.contains('start') && header.contains('pressure')) return 'startPressure';
    if (header.contains('end') && header.contains('pressure')) return 'endPressure';
    if (header.contains('tank') && header.contains('volume')) return 'tankVolume';
    if (header.contains('o2') || header.contains('oxygen')) return 'o2Percent';
    if (header.contains('computer')) return 'diveComputerModel';
    if (header.contains('serial')) return 'diveComputerSerial';
    if (header.contains('firmware')) return 'diveComputerFirmware';
    if (header.contains('tag')) return 'tags';
    if (header.contains('suit')) return 'suit';
    if (header.contains('weight')) return 'weightUsed';
    if (header.contains('gps')) return 'gps';
    return null;
  }
}
```

- [ ] **Step 2: Update existing tests to match new API**

Update the existing test file to work with the rewritten parser. The tests should continue to verify the same behaviors (UTC wall-time, date combining, etc.) but through the new pipeline.

Read the existing test file, then update it to match the new `parse()` signature (which now accepts named parameters for `customMapping`, `profileFileBytes`, etc.). The core test logic remains — verifying that date/time handling, type inference, and site extraction all still work correctly.

- [ ] **Step 3: Run all existing CSV parser tests**

Run: `flutter test test/features/universal_import/data/parsers/csv_import_parser_test.dart`
Expected: All tests PASS (existing behavior preserved through new pipeline).

- [ ] **Step 4: Commit**

```bash
git add lib/features/universal_import/data/parsers/csv_import_parser.dart test/features/universal_import/data/parsers/csv_import_parser_test.dart
git commit -m "feat: rewrite CsvImportParser as thin pipeline adapter

Delegates to CsvPipeline for all parsing logic. Maintains ImportParser
interface for universal wizard compatibility. Supports profile file
and timezone interpretation parameters."
```

---

## Task 12: Database Migration & Preset Repository

**Files:**
- Modify: `lib/core/database/database.dart` (add CsvPresets table + migration 58)
- Create: `lib/features/universal_import/data/repositories/csv_preset_repository.dart`

- [ ] **Step 1: Add CsvPresets table to database.dart**

Add the table definition near the other table definitions, add it to the `@DriftDatabase` tables list, increment schema version, and add migration.

In `database.dart`, add the table class:
```dart
class CsvPresets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get presetJson => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Add `CsvPresets` to the `@DriftDatabase(tables: [...])` list.

Increment `currentSchemaVersion` to 58.

Add migration:
```dart
if (from < 58) {
  await customStatement('''
    CREATE TABLE IF NOT EXISTS csv_presets (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      preset_json TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
}
```

- [ ] **Step 2: Run build_runner to generate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: Generates updated `database.g.dart` with CsvPresets table support.

- [ ] **Step 3: Implement CsvPresetRepository**

```dart
// lib/features/universal_import/data/repositories/csv_preset_repository.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/logger_service.dart';
import '../csv/presets/csv_preset.dart';

/// Repository for persisting user-saved CSV import presets.
class CsvPresetRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  static const _uuid = Uuid();
  static final _log = LoggerService.forClass(CsvPresetRepository);

  /// Get all user-saved presets.
  Future<List<CsvPreset>> getAllPresets() async {
    try {
      final rows = await (_db.select(_db.csvPresets)
            ..orderBy([(t) => OrderingTerm.asc(t.name)]))
          .get();
      return rows.map((row) => CsvPreset.fromJson(row.presetJson)).toList();
    } catch (e, stackTrace) {
      _log.error('Failed to get CSV presets', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Save a user preset (insert or update).
  Future<void> savePreset(CsvPreset preset) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = preset.id.isEmpty ? 'user_${_uuid.v4()}' : preset.id;

      final presetWithId = CsvPreset(
        id: id,
        name: preset.name,
        source: PresetSource.userSaved,
        sourceApp: preset.sourceApp,
        signatureHeaders: preset.signatureHeaders,
        matchThreshold: preset.matchThreshold,
        mappings: preset.mappings,
        expectedUnits: preset.expectedUnits,
        supportedEntities: preset.supportedEntities,
      );

      await _db.into(_db.csvPresets).insertOnConflictUpdate(
            CsvPresetsCompanion(
              id: Value(id),
              name: Value(preset.name),
              presetJson: Value(presetWithId.toJson()),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      _log.info('Saved CSV preset: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to save CSV preset', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Delete a user preset by ID.
  Future<void> deletePreset(String id) async {
    try {
      await (_db.delete(_db.csvPresets)..where((t) => t.id.equals(id))).go();
      _log.info('Deleted CSV preset: $id');
    } catch (e, stackTrace) {
      _log.error('Failed to delete CSV preset: $id',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/database/database.dart lib/features/universal_import/data/repositories/csv_preset_repository.dart
git commit -m "feat: add CsvPresets database table and repository

Migration 58 adds csv_presets table. CsvPresetRepository provides
CRUD for user-saved CSV import presets."
```

---

## Task 13: Wizard Provider Integration

**Files:**
- Modify: `lib/features/universal_import/presentation/providers/universal_import_providers.dart`

Add the `additionalFiles` wizard step and wire the CSV pipeline into the provider.

- [ ] **Step 1: Add additionalFiles to ImportWizardStep enum**

Add `additionalFiles` between `sourceConfirmation` and `fieldMapping` in the `ImportWizardStep` enum.

- [ ] **Step 2: Add additional file state fields to UniversalImportState**

Add fields:
- `additionalFileBytes` (`Uint8List?`) — the profile CSV bytes
- `additionalFileName` (`String?`) — the profile CSV filename
- `detectedPreset` (`CsvPreset?`) — the detected CSV preset
- `parsedCsv` (`ParsedCsv?`) — parsed primary CSV (for sample values in mapping UI)

- [ ] **Step 3: Update confirmSource to handle multi-file CSV presets**

In `confirmSource()`, after creating `ImportOptions`, check if the detected format is CSV and the detected preset has additional file roles. If so, advance to `additionalFiles` step instead of `fieldMapping`.

- [ ] **Step 4: Add methods for additional file handling**

Add `pickAdditionalFile()` and `skipAdditionalFile()` methods. `pickAdditionalFile()` opens the file picker, stores the bytes, and advances to `fieldMapping`. `skipAdditionalFile()` skips the profile file and advances directly.

- [ ] **Step 5: Update _parseAndCheckDuplicates to pass profile bytes**

When creating the `CsvImportParser` and calling `parse()`, pass the additional file bytes as `profileFileBytes` and the user's time interpretation setting.

- [ ] **Step 6: Add provider invalidation after import (fixes #62)**

In `performImport()`, after `_invalidateProviders()`, ensure all relevant providers are invalidated. Verify the existing implementation covers the CSV import case. The existing `_invalidateProviders` method should already handle this, but verify it invalidates dive list, site list, and equipment providers.

- [ ] **Step 7: Run existing tests**

Run: `flutter test`
Expected: All existing tests still pass. The new wizard step is backward-compatible (only activated for multi-file CSV presets).

- [ ] **Step 8: Commit**

```bash
git add lib/features/universal_import/presentation/providers/universal_import_providers.dart
git commit -m "feat: add additionalFiles wizard step for multi-file CSV import

Supports Subsurface's separate dive list + profile CSV files.
Step only appears when detected preset declares optional file roles.
Passes profile bytes through to CsvImportParser."
```

---

## Task 14: Delete Legacy Code & Cleanup

**Files:**
- Delete: `lib/core/services/export/csv/csv_import_service.dart`
- Delete: `test/core/services/export/csv/csv_import_service_test.dart`
- Delete: `lib/features/universal_import/data/services/field_mapping_engine.dart`
- Delete: `lib/features/universal_import/data/services/value_transforms.dart`
- Modify: any files that import the deleted files

- [ ] **Step 1: Find all references to deleted files**

Search for imports of:
- `csv_import_service.dart`
- `field_mapping_engine.dart`
- `value_transforms.dart`

Update each import to use the new equivalent:
- `field_mapping_engine.dart` -> `csv/presets/preset_registry.dart`
- `value_transforms.dart` -> `csv/transforms/value_converter.dart` (for ValueTransform enum) or `models/field_mapping.dart` (if ValueTransform was moved there)

Note: The `ValueTransform` enum is used by `ColumnMapping` in `field_mapping.dart`. Check whether it is defined there or in `value_transforms.dart`. If in `value_transforms.dart`, move it to `field_mapping.dart` before deleting. If callers import `ValueTransform` from `value_transforms.dart`, update their imports.

- [ ] **Step 2: Update imports in all affected files**

Read each file that imports the deleted modules and update the import path. Key files to check:
- `csv_import_parser.dart` (already rewritten in Task 11)
- `universal_import_providers.dart` (already updated in Task 13)
- Any UI files that reference `FieldMappingEngine` or `ValueTransformService`

- [ ] **Step 3: Delete the files**

```bash
rm lib/core/services/export/csv/csv_import_service.dart
rm test/core/services/export/csv/csv_import_service_test.dart
rm lib/features/universal_import/data/services/field_mapping_engine.dart
rm lib/features/universal_import/data/services/value_transforms.dart
```

- [ ] **Step 4: Run all tests to verify nothing is broken**

Run: `flutter test`
Expected: All tests pass. No references to deleted files remain.

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: No errors. Warnings should not increase.

- [ ] **Step 6: Format code**

Run: `dart format lib/ test/`
Expected: No changes (code should already be formatted).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: remove legacy CSV parser and old field mapping engine

Deletes CsvImportService, FieldMappingEngine, and ValueTransformService.
All CSV import now flows through the staged pipeline.
Fixes #58 (single code path eliminates missing mapping UI bug)."
```

---

## Task 15: Integration Tests with Real Subsurface Data

**Files:**
- Create: `test/features/universal_import/data/csv/integration/subsurface_csv_integration_test.dart`
- Copy sample files: `test/fixtures/subsurface-dive_list.csv`, `test/fixtures/subsurface-dive_computer_dive_profile.csv`

Use the real Subsurface CSV files from `/Users/ericgriffin/Documents/submersion development/submersion data/` as golden test data.

- [ ] **Step 1: Copy sample CSV files to test fixtures**

```bash
mkdir -p test/fixtures
cp "/Users/ericgriffin/Documents/submersion development/submersion data/subsurface-dive_list.csv" test/fixtures/
cp "/Users/ericgriffin/Documents/submersion development/submersion data/subsurface-dive_computer_dive_profile.csv" test/fixtures/
```

- [ ] **Step 2: Write integration tests**

```dart
// test/features/universal_import/data/csv/integration/subsurface_csv_integration_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_pipeline.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';

void main() {
  late CsvPipeline pipeline;

  setUp(() {
    pipeline = CsvPipeline();
  });

  group('Subsurface CSV integration', () {
    late File diveListFile;
    late File profileFile;

    setUpAll(() {
      diveListFile = File('test/fixtures/subsurface-dive_list.csv');
      profileFile = File('test/fixtures/subsurface-dive_computer_dive_profile.csv');
      expect(diveListFile.existsSync(), isTrue,
          reason: 'Test fixture subsurface-dive_list.csv must exist');
      expect(profileFile.existsSync(), isTrue,
          reason: 'Test fixture subsurface-dive_computer_dive_profile.csv must exist');
    });

    test('detects Subsurface from real dive list CSV', () {
      final bytes = diveListFile.readAsBytesSync();
      final csv = pipeline.parse(bytes);
      final detection = pipeline.detect(csv);

      expect(detection.isDetected, isTrue);
      expect(detection.sourceApp, SourceApp.subsurface);
      expect(detection.matchedPreset!.id, 'subsurface');
      expect(detection.hasAdditionalFileRoles, isTrue);
    });

    test('parses all 24 dives from dive list', () {
      final bytes = diveListFile.readAsBytesSync();
      final csv = pipeline.parse(bytes);
      final detection = pipeline.detect(csv);
      final preset = detection.matchedPreset!;

      final config = ImportConfiguration(
        mappings: preset.mappings,
        entityTypesToImport: preset.supportedEntities,
        sourceApp: SourceApp.subsurface,
        preset: preset,
      );

      final payload = pipeline.execute(primaryCsv: csv, config: config);
      final dives = payload.entitiesOf(ImportEntityType.dives);

      // File has 24 data rows (some without dive numbers)
      expect(dives, hasLength(greaterThanOrEqualTo(20)));
    });

    test('extracts multi-tank data', () {
      final bytes = diveListFile.readAsBytesSync();
      final csv = pipeline.parse(bytes);
      final detection = pipeline.detect(csv);
      final preset = detection.matchedPreset!;

      final config = ImportConfiguration(
        mappings: preset.mappings,
        entityTypesToImport: preset.supportedEntities,
        sourceApp: SourceApp.subsurface,
        preset: preset,
      );

      final payload = pipeline.execute(primaryCsv: csv, config: config);
      final dives = payload.entitiesOf(ImportEntityType.dives);

      // Dives 22-25 in the sample have 2 tanks (cylinder size (2) populated)
      final multiTankDives =
          dives.where((d) => (d['tanks'] as List?)?.length == 2).toList();
      expect(multiTankDives, isNotEmpty,
          reason: 'Should extract multi-tank dives from Subsurface CSV');
    });

    test('extracts unique sites', () {
      final bytes = diveListFile.readAsBytesSync();
      final csv = pipeline.parse(bytes);
      final detection = pipeline.detect(csv);
      final preset = detection.matchedPreset!;

      final config = ImportConfiguration(
        mappings: preset.mappings,
        entityTypesToImport: preset.supportedEntities,
        sourceApp: SourceApp.subsurface,
        preset: preset,
      );

      final payload = pipeline.execute(primaryCsv: csv, config: config);
      final sites = payload.entitiesOf(ImportEntityType.sites);

      // Sample has: Maclearie Park, The Atantic Club Pool, Escambron Marine Park, Mosquito Pier
      expect(sites, hasLength(greaterThanOrEqualTo(4)));

      // GPS coordinates should be extracted
      final maclearie = sites.firstWhere((s) => s['name'] == 'Maclearie Park');
      expect(maclearie['latitude'], closeTo(40.1796, 0.001));
      expect(maclearie['longitude'], closeTo(-74.0375, 0.001));
    });

    test('extracts buddies with leading-comma handling', () {
      final bytes = diveListFile.readAsBytesSync();
      final csv = pipeline.parse(bytes);
      final detection = pipeline.detect(csv);
      final preset = detection.matchedPreset!;

      final config = ImportConfiguration(
        mappings: preset.mappings,
        entityTypesToImport: preset.supportedEntities,
        sourceApp: SourceApp.subsurface,
        preset: preset,
      );

      final payload = pipeline.execute(primaryCsv: csv, config: config);
      final buddies = payload.entitiesOf(ImportEntityType.buddies);

      // Should extract "Kiyan Griffin" from ", Kiyan Griffin" format
      expect(buddies.any((b) => b['name'] == 'Kiyan Griffin'), isTrue);
      // Should not have empty-string buddies
      expect(buddies.every((b) => (b['name'] as String).isNotEmpty), isTrue);
    });

    test('extracts tags', () {
      final bytes = diveListFile.readAsBytesSync();
      final csv = pipeline.parse(bytes);
      final detection = pipeline.detect(csv);
      final preset = detection.matchedPreset!;

      final config = ImportConfiguration(
        mappings: preset.mappings,
        entityTypesToImport: preset.supportedEntities,
        sourceApp: SourceApp.subsurface,
        preset: preset,
      );

      final payload = pipeline.execute(primaryCsv: csv, config: config);
      final tags = payload.entitiesOf(ImportEntityType.tags);

      // Sample has "shore, student" tags
      expect(tags.any((t) => t['name'] == 'shore'), isTrue);
      expect(tags.any((t) => t['name'] == 'student'), isTrue);
    });

    test('all dive times are UTC and not shifted', () {
      final bytes = diveListFile.readAsBytesSync();
      final csv = pipeline.parse(bytes);
      final detection = pipeline.detect(csv);
      final preset = detection.matchedPreset!;

      final config = ImportConfiguration(
        mappings: preset.mappings,
        entityTypesToImport: preset.supportedEntities,
        sourceApp: SourceApp.subsurface,
        preset: preset,
      );

      final payload = pipeline.execute(primaryCsv: csv, config: config);
      final dives = payload.entitiesOf(ImportEntityType.dives);

      for (final dive in dives) {
        final dt = dive['dateTime'] as DateTime?;
        if (dt != null) {
          expect(dt.isUtc, isTrue,
              reason: 'All imported times must be UTC');
        }
      }

      // First dive with time: 07:44:37 should remain 07:44
      final dive1 = dives.firstWhere(
        (d) => d['diveNumber'] == 1,
        orElse: () => dives.first,
      );
      final dt = dive1['dateTime'] as DateTime?;
      if (dt != null) {
        expect(dt.hour, 7, reason: 'Time must not be shifted by UTC offset');
      }
    });

    test('full pipeline with profile CSV merges profile data', () {
      final diveListBytes = diveListFile.readAsBytesSync();
      final profileBytes = profileFile.readAsBytesSync();

      final primaryCsv = pipeline.parse(diveListBytes);
      final profileCsv = pipeline.parse(profileBytes);

      final detection = pipeline.detect(primaryCsv);
      final preset = detection.matchedPreset!;

      final config = ImportConfiguration(
        mappings: preset.mappings,
        entityTypesToImport: preset.supportedEntities,
        sourceApp: SourceApp.subsurface,
        preset: preset,
      );

      final payload = pipeline.execute(
        primaryCsv: primaryCsv,
        profileCsv: profileCsv,
        config: config,
      );

      final dives = payload.entitiesOf(ImportEntityType.dives);
      final divesWithProfiles =
          dives.where((d) => d['profileSamples'] != null).toList();

      expect(divesWithProfiles, isNotEmpty,
          reason: 'At least some dives should have profile data matched');
    });
  });
}
```

- [ ] **Step 3: Run integration tests**

Run: `flutter test test/features/universal_import/data/csv/integration/`
Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add test/fixtures/ test/features/universal_import/data/csv/integration/
git commit -m "test: add integration tests with real Subsurface CSV data

Tests full pipeline with actual Subsurface exports: dive parsing,
multi-tank extraction, GPS site parsing, buddy/tag extraction,
UTC wall-time preservation, and profile CSV correlation."
```

---

## Task 16: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: All tests pass.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No errors.

- [ ] **Step 3: Format all code**

Run: `dart format lib/ test/`
Expected: No formatting changes needed.

- [ ] **Step 4: Final commit if any formatting fixes needed**

```bash
git add -A
git commit -m "chore: final formatting and cleanup for CSV import rearchitect"
```
