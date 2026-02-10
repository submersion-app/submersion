import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/field_mapping_engine.dart';
import 'package:submersion/features/universal_import/data/services/value_transforms.dart';

/// Parser for CSV dive log files from any source application.
///
/// Uses [FieldMappingEngine] to match CSV columns to Submersion fields,
/// applying preset mappings for known apps (MacDive, Diving Log, etc.)
/// or generic keyword-based matching for unrecognized CSVs.
///
/// Produces an [ImportPayload] containing dives and optionally sites
/// (extracted from unique site name values).
class CsvImportParser implements ImportParser {
  final FieldMappingEngine _mappingEngine;
  final ValueTransformService _transforms;

  /// Optional user-customized field mapping. If null, auto-detection is used.
  final FieldMapping? customMapping;

  const CsvImportParser({
    this.customMapping,
    FieldMappingEngine mappingEngine = const FieldMappingEngine(),
    ValueTransformService transforms = const ValueTransformService(),
  }) : _mappingEngine = mappingEngine,
       _transforms = transforms;

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.csv];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final rawContent = utf8.decode(fileBytes, allowMalformed: true);
    // Normalize line endings: \r\n → \n, then \r → \n.
    // The csv package defaults to \r\n; normalizing ensures both Unix
    // and Windows line endings are handled consistently.
    final content = rawContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    List<List<dynamic>> rows;
    try {
      rows = const CsvToListConverter(eol: '\n').convert(content);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Could not parse CSV: $e',
          ),
        ],
      );
    }

    if (rows.isEmpty) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'CSV file is empty',
          ),
        ],
      );
    }

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final dataRows = rows.skip(1).toList();

    if (dataRows.isEmpty) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'CSV file has headers but no data rows',
          ),
        ],
      );
    }

    final mapping =
        customMapping ??
        _mappingEngine.autoMap(headers, sourceApp: options?.sourceApp);

    final columnIndices = _buildColumnIndex(mapping, headers);
    final dives = <Map<String, dynamic>>[];
    final siteNames = <String>{};
    final warnings = <ImportWarning>[];

    for (var rowIdx = 0; rowIdx < dataRows.length; rowIdx++) {
      final row = dataRows[rowIdx];
      if (_isEmptyRow(row)) continue;

      final diveData = _parseRow(row, columnIndices, warnings, dives.length);
      _combineDateAndTime(diveData);

      final siteName = diveData['siteName'] as String?;
      if (siteName != null && siteName.isNotEmpty) {
        siteNames.add(siteName);
      }

      if (!_hasValidDateTime(diveData)) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Row ${rowIdx + 2}: Missing or invalid date',
            entityType: ImportEntityType.dives,
            itemIndex: dives.length,
            field: 'dateTime',
          ),
        );
        continue;
      }

      dives.add(diveData);
    }

    final entities = <ImportEntityType, List<Map<String, dynamic>>>{};
    if (dives.isNotEmpty) {
      entities[ImportEntityType.dives] = dives;
    }
    if (siteNames.isNotEmpty) {
      entities[ImportEntityType.sites] = siteNames
          .map((name) => <String, dynamic>{'name': name})
          .toList();
    }

    if (dives.isEmpty) {
      warnings.add(
        const ImportWarning(
          severity: ImportWarningSeverity.error,
          message: 'No valid dives could be parsed from the CSV file',
        ),
      );
    }

    return ImportPayload(
      entities: entities,
      warnings: warnings,
      metadata: {
        'sourceApp': options?.sourceApp.displayName ?? 'CSV',
        'totalRows': dataRows.length,
        'parsedDives': dives.length,
        'mappingName': mapping.name,
      },
    );
  }

  // ======================== Row Parsing ========================

  Map<int, ColumnMapping> _buildColumnIndex(
    FieldMapping mapping,
    List<String> headers,
  ) {
    final headerLower = headers.map((h) => h.toLowerCase().trim()).toList();
    final indices = <int, ColumnMapping>{};
    for (final col in mapping.columns) {
      final idx = headerLower.indexOf(col.sourceColumn.toLowerCase().trim());
      if (idx >= 0) {
        indices[idx] = col;
      }
    }
    return indices;
  }

  Map<String, dynamic> _parseRow(
    List<dynamic> row,
    Map<int, ColumnMapping> columnIndices,
    List<ImportWarning> warnings,
    int diveIndex,
  ) {
    final diveData = <String, dynamic>{};

    for (final entry in columnIndices.entries) {
      final idx = entry.key;
      final col = entry.value;
      if (idx >= row.length) continue;

      final rawValue = row[idx]?.toString().trim() ?? '';
      if (rawValue.isEmpty) {
        if (col.defaultValue != null) {
          diveData[col.targetField] = col.defaultValue;
        }
        continue;
      }

      if (col.transform != null) {
        final transformed = _transforms.applyTransform(
          col.transform!,
          rawValue,
        );
        if (transformed != null) {
          diveData[col.targetField] = transformed;
        } else {
          warnings.add(
            ImportWarning(
              severity: ImportWarningSeverity.warning,
              message:
                  'Could not convert "${col.sourceColumn}" value "$rawValue"',
              entityType: ImportEntityType.dives,
              itemIndex: diveIndex,
              field: col.targetField,
            ),
          );
        }
      } else {
        diveData[col.targetField] = _inferTypedValue(col.targetField, rawValue);
      }
    }

    return diveData;
  }

  // ======================== Date/Time Combining ========================

  void _combineDateAndTime(Map<String, dynamic> diveData) {
    if (diveData.containsKey('date') && diveData['date'] is DateTime) {
      DateTime dateTime = diveData['date'] as DateTime;
      if (diveData.containsKey('time') && diveData['time'] is DateTime) {
        final time = diveData['time'] as DateTime;
        dateTime = DateTime(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          time.hour,
          time.minute,
          time.second,
        );
      }
      diveData['dateTime'] = dateTime;
      diveData.remove('date');
      diveData.remove('time');
    } else if (diveData.containsKey('dateTime') &&
        diveData['dateTime'] is! DateTime) {
      final parsed = _transforms.parseDate(diveData['dateTime'].toString());
      if (parsed != null) {
        diveData['dateTime'] = parsed;
      }
    }
  }

  // ======================== Type Inference ========================

  dynamic _inferTypedValue(String targetField, String rawValue) {
    return switch (targetField) {
      'diveNumber' => int.tryParse(rawValue),
      'date' || 'dateTime' => _transforms.parseDate(rawValue),
      'time' => _transforms.parseTime(rawValue),
      'maxDepth' ||
      'avgDepth' ||
      'waterTemp' ||
      'airTemp' ||
      'bottomTemp' ||
      'tankVolume' ||
      'o2Percent' ||
      'weightUsed' => double.tryParse(
        rawValue.replaceAll(RegExp(r'[^\d.-]'), ''),
      ),
      'duration' || 'runtime' => _parseDuration(rawValue),
      'startPressure' ||
      'endPressure' => int.tryParse(rawValue.replaceAll(RegExp(r'[^\d]'), '')),
      'rating' => int.tryParse(rawValue),
      _ => rawValue,
    };
  }

  Duration? _parseDuration(String value) {
    final minutes = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), ''));
    if (minutes != null) return Duration(minutes: minutes);
    return _transforms.hmsToSeconds(value);
  }

  // ======================== Helpers ========================

  bool _isEmptyRow(List<dynamic> row) =>
      row.isEmpty || row.every((c) => c == null || c.toString().isEmpty);

  bool _hasValidDateTime(Map<String, dynamic> data) =>
      data.containsKey('dateTime') && data['dateTime'] is DateTime;
}
