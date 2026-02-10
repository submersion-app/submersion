import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/value_transforms.dart';

/// Engine for mapping CSV columns to Submersion fields.
///
/// Provides built-in presets for known source apps and auto-mapping
/// for generic CSV files. Also suggests unit transforms based on
/// sample values and column name hints.
class FieldMappingEngine {
  const FieldMappingEngine();

  /// Get the preset mapping for a known source app, or null if none exists.
  FieldMapping? presetFor(SourceApp sourceApp) => switch (sourceApp) {
    SourceApp.macdive => _macDivePreset,
    SourceApp.divingLog => _divingLogPreset,
    SourceApp.diveMate => _diveMatePreset,
    SourceApp.subsurface => _subsurfaceCsvPreset,
    SourceApp.garminConnect => _garminConnectPreset,
    SourceApp.shearwater => _shearwaterPreset,
    SourceApp.submersion => _submersionPreset,
    _ => null,
  };

  /// Auto-generate a mapping from CSV headers.
  ///
  /// First tries the preset for [sourceApp] if provided. Falls back
  /// to generic keyword-based matching against known field names.
  FieldMapping autoMap(List<String> headers, {SourceApp? sourceApp}) {
    if (sourceApp != null) {
      final preset = presetFor(sourceApp);
      if (preset != null) {
        final matched = _filterToMatchingColumns(preset, headers);
        if (matched.columns.isNotEmpty) return matched;
      }
    }
    return _genericAutoMap(headers);
  }

  /// Suggest transforms for columns based on sample values.
  ///
  /// Inspects sample data to detect imperial units and suggests
  /// appropriate conversions (ft->m, F->C, psi->bar).
  List<ColumnMapping> suggestTransforms(
    List<ColumnMapping> mappings,
    List<String> headers,
    List<List<String>> sampleRows,
  ) {
    final result = <ColumnMapping>[];

    for (final mapping in mappings) {
      if (mapping.transform != null) {
        result.add(mapping);
        continue;
      }

      final colIdx = headers.indexWhere(
        (h) => h.toLowerCase().trim() == mapping.sourceColumn.toLowerCase(),
      );
      if (colIdx < 0) {
        result.add(mapping);
        continue;
      }

      final samples = sampleRows
          .where((row) => colIdx < row.length)
          .map((row) => row[colIdx])
          .toList();

      final suggested = _suggestTransformForField(
        mapping.targetField,
        mapping.sourceColumn,
        samples,
      );

      if (suggested != null) {
        result.add(
          ColumnMapping(
            sourceColumn: mapping.sourceColumn,
            targetField: mapping.targetField,
            transform: suggested,
            defaultValue: mapping.defaultValue,
          ),
        );
      } else {
        result.add(mapping);
      }
    }

    return result;
  }

  // ======================== Generic Auto-Map ========================

  FieldMapping _genericAutoMap(List<String> headers) {
    final columns = <ColumnMapping>[];
    for (final header in headers) {
      final lower = header.toLowerCase().trim();
      final target = _guessTargetField(lower);
      if (target != null) {
        columns.add(ColumnMapping(sourceColumn: header, targetField: target));
      }
    }
    return FieldMapping(
      name: 'Auto-detected',
      sourceApp: SourceApp.generic,
      columns: columns,
    );
  }

  String? _guessTargetField(String header) {
    if (_matchesDiveNumber(header)) return 'diveNumber';
    if (_matchesDate(header)) return 'date';
    if (_matchesTime(header)) return 'time';
    if (header.contains('max') && header.contains('depth')) return 'maxDepth';
    if (header.contains('avg') && header.contains('depth')) return 'avgDepth';
    if (_matchesDuration(header)) return 'duration';
    if (header.contains('water') && header.contains('temp')) return 'waterTemp';
    if (header.contains('air') && header.contains('temp')) return 'airTemp';
    if (header.contains('site') || header.contains('location')) {
      return 'siteName';
    }
    if (header.contains('buddy')) return 'buddy';
    if (header.contains('dive') && header.contains('master')) {
      return 'diveMaster';
    }
    if (header.contains('rating')) return 'rating';
    if (header.contains('note')) return 'notes';
    if (header.contains('visibility')) return 'visibility';
    if (header.contains('start') && header.contains('pressure')) {
      return 'startPressure';
    }
    if (header.contains('end') && header.contains('pressure')) {
      return 'endPressure';
    }
    if (header.contains('tank') && header.contains('volume')) {
      return 'tankVolume';
    }
    if (header.contains('o2') || header.contains('oxygen')) return 'o2Percent';
    return null;
  }

  bool _matchesDiveNumber(String h) =>
      h.contains('dive') && (h.contains('number') || h.contains('no'));

  bool _matchesDate(String h) =>
      h == 'date' || (h.contains('date') && !h.contains('time'));

  bool _matchesTime(String h) =>
      h == 'time' ||
      (h.contains('time') &&
          !h.contains('date') &&
          !h.contains('bottom') &&
          !h.contains('duration') &&
          !h.contains('surface') &&
          !h.contains('run'));

  bool _matchesDuration(String h) =>
      (h.contains('bottom') && h.contains('time')) ||
      h.contains('duration') ||
      h.contains('runtime');

  // ======================== Transform Suggestion ========================

  ValueTransform? _suggestTransformForField(
    String targetField,
    String sourceColumn,
    List<String> samples,
  ) {
    if (targetField == 'maxDepth' || targetField == 'avgDepth') {
      if (ValueTransformService.isLikelyFeet(samples, sourceColumn)) {
        return ValueTransform.feetToMeters;
      }
    } else if (targetField == 'waterTemp' || targetField == 'airTemp') {
      if (ValueTransformService.isLikelyFahrenheit(samples, sourceColumn)) {
        return ValueTransform.fahrenheitToCelsius;
      }
    } else if (targetField == 'startPressure' || targetField == 'endPressure') {
      if (ValueTransformService.isLikelyPsi(samples, sourceColumn)) {
        return ValueTransform.psiToBar;
      }
    }
    return null;
  }

  // ======================== Preset Filter ========================

  FieldMapping _filterToMatchingColumns(
    FieldMapping preset,
    List<String> headers,
  ) {
    final headerLower = headers.map((h) => h.toLowerCase().trim()).toSet();
    final matched = preset.columns
        .where(
          (col) => headerLower.contains(col.sourceColumn.toLowerCase().trim()),
        )
        .toList();
    return FieldMapping(
      name: '${preset.name} Auto',
      sourceApp: preset.sourceApp,
      columns: matched,
    );
  }

  // ======================== App Presets ========================

  static const _macDivePreset = FieldMapping(
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
  );

  static const _divingLogPreset = FieldMapping(
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
      ColumnMapping(
        sourceColumn: 'StartPressure',
        targetField: 'startPressure',
      ),
      ColumnMapping(sourceColumn: 'EndPressure', targetField: 'endPressure'),
    ],
  );

  static const _diveMatePreset = FieldMapping(
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
      ColumnMapping(
        sourceColumn: 'Water Temperature',
        targetField: 'waterTemp',
      ),
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
  );

  static const _subsurfaceCsvPreset = FieldMapping(
    name: 'Subsurface CSV',
    sourceApp: SourceApp.subsurface,
    columns: [
      ColumnMapping(sourceColumn: 'date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'time', targetField: 'time'),
      ColumnMapping(
        sourceColumn: 'duration',
        targetField: 'duration',
        transform: ValueTransform.hmsToSeconds,
      ),
      ColumnMapping(sourceColumn: 'maxdepth', targetField: 'maxDepth'),
      ColumnMapping(sourceColumn: 'avgdepth', targetField: 'avgDepth'),
      ColumnMapping(sourceColumn: 'airtemp', targetField: 'airTemp'),
      ColumnMapping(sourceColumn: 'watertemp', targetField: 'waterTemp'),
      ColumnMapping(sourceColumn: 'location', targetField: 'siteName'),
      ColumnMapping(sourceColumn: 'buddy', targetField: 'buddy'),
      ColumnMapping(sourceColumn: 'divemaster', targetField: 'diveMaster'),
      ColumnMapping(sourceColumn: 'notes', targetField: 'notes'),
      ColumnMapping(
        sourceColumn: 'rating',
        targetField: 'rating',
        transform: ValueTransform.ratingScale,
      ),
      ColumnMapping(
        sourceColumn: 'visibility',
        targetField: 'visibility',
        transform: ValueTransform.visibilityScale,
      ),
    ],
  );

  static const _garminConnectPreset = FieldMapping(
    name: 'Garmin Connect',
    sourceApp: SourceApp.garminConnect,
    columns: [
      ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
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
      ColumnMapping(
        sourceColumn: 'Water Temperature',
        targetField: 'waterTemp',
      ),
    ],
  );

  static const _shearwaterPreset = FieldMapping(
    name: 'Shearwater Cloud',
    sourceApp: SourceApp.shearwater,
    columns: [
      ColumnMapping(sourceColumn: 'Dive Number', targetField: 'diveNumber'),
      ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
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
  );

  static const _submersionPreset = FieldMapping(
    name: 'Submersion',
    sourceApp: SourceApp.submersion,
    columns: [
      ColumnMapping(sourceColumn: 'Dive Number', targetField: 'diveNumber'),
      ColumnMapping(sourceColumn: 'Date', targetField: 'date'),
      ColumnMapping(sourceColumn: 'Time', targetField: 'time'),
      ColumnMapping(sourceColumn: 'Site', targetField: 'siteName'),
      ColumnMapping(sourceColumn: 'Max Depth', targetField: 'maxDepth'),
      ColumnMapping(sourceColumn: 'Avg Depth', targetField: 'avgDepth'),
      ColumnMapping(sourceColumn: 'Bottom Time', targetField: 'duration'),
      ColumnMapping(sourceColumn: 'Water Temp', targetField: 'waterTemp'),
      ColumnMapping(sourceColumn: 'Air Temp', targetField: 'airTemp'),
      ColumnMapping(
        sourceColumn: 'Start Pressure',
        targetField: 'startPressure',
      ),
      ColumnMapping(sourceColumn: 'End Pressure', targetField: 'endPressure'),
      ColumnMapping(sourceColumn: 'Buddy', targetField: 'buddy'),
      ColumnMapping(sourceColumn: 'Notes', targetField: 'notes'),
      ColumnMapping(sourceColumn: 'Rating', targetField: 'rating'),
      ColumnMapping(
        sourceColumn: 'Visibility',
        targetField: 'visibility',
        transform: ValueTransform.visibilityScale,
      ),
    ],
  );
}
