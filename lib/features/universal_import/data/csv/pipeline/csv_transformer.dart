import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/models/transformed_rows.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/time_resolver.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/unit_detector.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/value_converter.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// Stage 4: Transform raw CSV rows into typed field maps.
///
/// Applies field mappings, time resolution, unit detection, and type coercion
/// to produce [TransformedRows] from [ParsedCsv] data.
class CsvTransformer {
  final TimeResolver _timeResolver;
  final UnitDetector _unitDetector;
  final ValueConverter _valueConverter;
  final ValueTransformService _transformService;

  CsvTransformer({
    TimeResolver? timeResolver,
    UnitDetector? unitDetector,
    ValueConverter? valueConverter,
    ValueTransformService? transformService,
  }) : _timeResolver = timeResolver ?? const TimeResolver(),
       _unitDetector = unitDetector ?? const UnitDetector(),
       _valueConverter = valueConverter ?? const ValueConverter(),
       _transformService = transformService ?? const ValueTransformService();

  /// Transform [csv] rows using the field mapping for [fileRole] from [config].
  ///
  /// Returns [TransformedRows] with typed values and accumulated warnings.
  /// Rows without a valid dateTime are skipped with a warning.
  TransformedRows transform(
    ParsedCsv csv,
    ImportConfiguration config, {
    String fileRole = 'primary',
  }) {
    final warnings = <ImportWarning>[];

    // Step 1: Get the FieldMapping for the given fileRole.
    final mapping = config.mappings[fileRole];
    if (mapping == null) {
      return TransformedRows(
        rows: const [],
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.warning,
            message: 'No field mapping found for file role "$fileRole"',
          ),
        ],
        fileRole: fileRole,
      );
    }

    // Step 2: Build column index: header name (lowercase) -> column index.
    final columnIndex = <String, int>{};
    for (var i = 0; i < csv.headers.length; i++) {
      columnIndex[csv.headers[i].toLowerCase().trim()] = i;
    }

    // Step 3: Detect units from headers using UnitDetector.
    final headerUnits = <String, ColumnUnitDetection>{};
    for (final header in csv.headers) {
      final detection = _unitDetector.parseHeaderUnit(header);
      if (detection != null) {
        headerUnits[header.toLowerCase().trim()] = detection;
      }
    }

    // Step 4: First pass - map columns to target fields for each row.
    final mappedRows = <Map<String, dynamic>>[];
    for (var rowIdx = 0; rowIdx < csv.rows.length; rowIdx++) {
      final row = csv.rows[rowIdx];
      final mapped = <String, dynamic>{};

      for (final col in mapping.columns) {
        final colIdx = columnIndex[col.sourceColumn.toLowerCase().trim()];
        if (colIdx == null || colIdx >= row.length) continue;

        final rawValue = row[colIdx].trim();

        // Use default if value is empty.
        if (rawValue.isEmpty) {
          if (col.defaultValue != null) {
            mapped[col.targetField] = _coerceDefault(
              col.targetField,
              col.defaultValue!,
              col.transform,
            );
          }
          continue;
        }

        // Apply explicit transform if specified.
        if (col.transform != null) {
          final transformed = _applyTransform(
            col.transform!,
            rawValue,
            col.targetField,
            rowIdx,
            warnings,
          );
          if (transformed != null) {
            mapped[col.targetField] = transformed;
          }
          continue;
        }

        // No explicit transform: infer type based on target field and apply
        // unit conversion if the header indicated an imperial unit.
        final typed = _inferType(
          col.targetField,
          rawValue,
          col.sourceColumn.toLowerCase().trim(),
          headerUnits,
        );
        if (typed != null) {
          mapped[col.targetField] = typed;
        }
      }

      mappedRows.add(mapped);
    }

    // Step 5: Pre-pass for informal time tokens using TimeResolver.
    // Only apply to rows that have a 'date' key (separate date/time columns).
    // Rows with a combined 'dateTime' string or no date info are left alone.
    final rowsWithDateField = <int>{};
    for (var i = 0; i < mappedRows.length; i++) {
      if (mappedRows[i].containsKey('date')) {
        rowsWithDateField.add(i);
      }
    }

    // Extract only the rows with date fields for informal time resolution.
    final dateRows = rowsWithDateField.map((i) => mappedRows[i]).toList();
    final resolvedDateRows = _timeResolver.resolveInformalTimes(dateRows);

    // Merge resolved rows back into their original positions.
    var resolvedIdx = 0;
    final resolvedRows = mappedRows.indexed.map((entry) {
      final (i, row) = entry;
      if (rowsWithDateField.contains(i)) {
        return resolvedDateRows[resolvedIdx++];
      }
      return row;
    }).toList();

    // Step 6: Second pass - combine date+time into dateTime for each row.
    final validRows = <Map<String, dynamic>>[];
    for (var i = 0; i < resolvedRows.length; i++) {
      final row = resolvedRows[i];

      // If resolveInformalTimes already set dateTime as a DateTime, use it.
      if (row['dateTime'] is DateTime) {
        final result = Map<String, dynamic>.from(row)
          ..['importVersion'] = 2
          ..remove('date')
          ..remove('time')
          ..remove('_informalTime');
        validRows.add(result);
        continue;
      }

      // Try to combine date + time or parse a dateTime string.
      final dateTime = _timeResolver.combineDateTime(
        dateStr: row['date'] as String?,
        timeStr: row['time'] as String?,
        dateTimeStr: row['dateTime'] as String?,
        interpretation: config.timeInterpretation,
        specificOffset: config.specificUtcOffset,
      );

      if (dateTime == null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.warning,
            message: 'Row ${i + 1}: could not resolve dateTime, skipping',
            itemIndex: i,
          ),
        );
        continue;
      }

      final result = Map<String, dynamic>.from(row)
        ..['dateTime'] = dateTime
        ..['importVersion'] = 2
        ..remove('date')
        ..remove('time')
        ..remove('_informalTime');
      validRows.add(result);
    }

    return TransformedRows(
      rows: validRows,
      warnings: warnings,
      fileRole: fileRole,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Apply a [ValueTransform] to [rawValue] and return the typed result.
  dynamic _applyTransform(
    ValueTransform transform,
    String rawValue,
    String targetField,
    int rowIdx,
    List<ImportWarning> warnings,
  ) {
    final result = _transformService.applyTransform(transform, rawValue);
    if (result == null) {
      warnings.add(
        ImportWarning(
          severity: ImportWarningSeverity.info,
          message:
              'Row ${rowIdx + 1}: failed to apply ${transform.name} '
              'to "$rawValue" for field $targetField',
          field: targetField,
          itemIndex: rowIdx,
        ),
      );
    }
    return result;
  }

  /// Infer the typed value for a target field from a raw string.
  ///
  /// Also applies unit conversion if the header's bracketed unit was detected
  /// as imperial.
  dynamic _inferType(
    String targetField,
    String rawValue,
    String sourceColumnLower,
    Map<String, ColumnUnitDetection> headerUnits,
  ) {
    final lower = targetField.toLowerCase();

    // Integer fields.
    if (lower == 'divenumber' || lower == 'divenum') {
      return _valueConverter.parseInt(rawValue);
    }

    // Duration fields: try to infer format.
    if (lower == 'duration') {
      return _inferDuration(rawValue);
    }

    // Numeric (double) fields that may need unit conversion.
    if (_isDoubleField(lower)) {
      final parsed = _valueConverter.parseDouble(rawValue);
      if (parsed == null) return null;

      // Check if the source header has an imperial unit that needs conversion.
      final unitInfo = headerUnits[sourceColumnLower];
      if (unitInfo != null && unitInfo.needsConversion) {
        return _valueConverter.convertUnit(parsed, unitInfo.detected);
      }
      return parsed;
    }

    // Rating field.
    if (lower == 'rating') {
      return _valueConverter.normalizeRating(rawValue);
    }

    // Visibility field.
    if (lower == 'visibility') {
      return _valueConverter.parseVisibility(rawValue);
    }

    // Dive type field.
    if (lower == 'divetype') {
      return _valueConverter.parseDiveType(rawValue);
    }

    // Date and time fields are kept as strings for the time-resolution pass.
    if (lower == 'date' || lower == 'time' || lower == 'datetime') {
      return rawValue;
    }

    // Default: keep as string.
    return rawValue;
  }

  /// Infer a Duration from a raw string value.
  ///
  /// If the value contains colons, parse as H:MM:SS / M:SS.
  /// Otherwise, try as decimal minutes.
  Duration? _inferDuration(String rawValue) {
    if (rawValue.contains(':')) {
      return _valueConverter.parseDuration(rawValue, DurationFormat.hms);
    }
    return _valueConverter.parseDuration(rawValue, DurationFormat.minutes);
  }

  /// Coerce a default value string for a given target field.
  dynamic _coerceDefault(
    String targetField,
    String defaultValue,
    ValueTransform? transform,
  ) {
    // If there is a transform, apply it to the default value.
    if (transform != null) {
      return _transformService.applyTransform(transform, defaultValue);
    }

    // Otherwise, infer type from target field.
    final lower = targetField.toLowerCase();
    if (lower == 'divenumber' || lower == 'divenum') {
      return _valueConverter.parseInt(defaultValue);
    }
    if (_isDoubleField(lower)) {
      return _valueConverter.parseDouble(defaultValue);
    }
    if (lower == 'rating') {
      return _valueConverter.normalizeRating(defaultValue);
    }
    return defaultValue;
  }

  /// Returns true if the target field is expected to hold a double value.
  ///
  /// Strips a trailing `_N` suffix (e.g. `startpressure_1`) before matching
  /// so that numbered tank fields are correctly identified.
  bool _isDoubleField(String lowerField) {
    final base = _stripNumberSuffix(lowerField);
    return base == 'maxdepth' ||
        base == 'avgdepth' ||
        base == 'watertemp' ||
        base == 'airtemp' ||
        base == 'startpressure' ||
        base == 'endpressure' ||
        base == 'weight' ||
        base == 'sac' ||
        base == 'tankvolume' ||
        base == 'sampledepth' ||
        base == 'sampletemperature' ||
        base == 'samplepressure';
  }

  static final _numberSuffix = RegExp(r'_\d+$');

  /// Strip a trailing `_N` suffix from a field name.
  String _stripNumberSuffix(String field) {
    return field.replaceFirst(_numberSuffix, '');
  }
}
