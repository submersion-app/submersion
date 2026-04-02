import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/csv/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_parser.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_pipeline.dart';
import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parser for CSV dive log files from any source application.
///
/// Thin adapter that delegates to [CsvPipeline] for all parsing logic while
/// maintaining the [ImportParser] interface expected by the universal import
/// wizard.
///
/// Flow:
/// 1. Parse raw CSV bytes via the pipeline's Parse stage.
/// 2. Detect the source app via the pipeline's Detect stage.
/// 3. Build an [ImportConfiguration] from the detected preset, a custom
///    mapping, or auto-mapped keyword matching.
/// 4. Execute the pipeline (Transform + Correlate) to produce the final
///    [ImportPayload].
class CsvImportParser implements ImportParser {
  final CsvPipeline _pipeline;

  /// Optional user-customized field mapping. If null, auto-detection is used.
  final FieldMapping? customMapping;

  CsvImportParser({this.customMapping, CsvPipeline? pipeline})
    : _pipeline = pipeline ?? CsvPipeline();

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.csv];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
    FieldMapping? customMappingOverride,
    Uint8List? profileFileBytes,
    TimeInterpretation timeInterpretation = TimeInterpretation.localWallClock,
    Duration? specificUtcOffset,
  }) async {
    // Stage 1: Parse.
    final ParsedCsv parsedCsv;
    try {
      parsedCsv = _pipeline.parse(fileBytes);
    } on CsvParseException catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: e.message,
          ),
        ],
      );
    }

    // Stage 2: Detect.
    final detection = _pipeline.detect(parsedCsv);

    // Resolve which mapping to use: explicit override > constructor
    // customMapping > detected preset > auto-mapped from headers.
    final resolvedMapping = customMappingOverride ?? customMapping;

    // Stage 3: Build ImportConfiguration.
    final config = _buildConfiguration(
      parsedCsv: parsedCsv,
      detection: detection,
      resolvedMapping: resolvedMapping,
      options: options,
      timeInterpretation: timeInterpretation,
      specificUtcOffset: specificUtcOffset,
    );

    // Parse optional profile CSV if provided.
    ParsedCsv? profileCsv;
    if (profileFileBytes != null) {
      try {
        profileCsv = _pipeline.parse(profileFileBytes);
      } on CsvParseException {
        // Profile parse failure is non-fatal; proceed without profile data.
      }
    }

    // Stages 4-5: Transform + Correlate.
    return _pipeline.execute(
      primaryCsv: parsedCsv,
      profileCsv: profileCsv,
      config: config,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Build an [ImportConfiguration] from the resolved mapping source.
  ///
  /// Priority order:
  /// 1. Explicit custom mapping (user-provided).
  /// 2. Detected preset from pipeline Detect stage.
  /// 3. Auto-mapped from CSV headers using keyword matching.
  ImportConfiguration _buildConfiguration({
    required ParsedCsv parsedCsv,
    required DetectionResult detection,
    required FieldMapping? resolvedMapping,
    required ImportOptions? options,
    required TimeInterpretation timeInterpretation,
    required Duration? specificUtcOffset,
  }) {
    // Case 1: User provided a custom mapping.
    // Preserve entity types from the detected preset so buddies, tags, etc.
    // are still extracted even when the user customizes column mappings.
    if (resolvedMapping != null) {
      return ImportConfiguration(
        mappings: {'primary': resolvedMapping},
        entityTypesToImport:
            detection.matchedPreset?.supportedEntities ??
            const {ImportEntityType.dives, ImportEntityType.sites},
        timeInterpretation: timeInterpretation,
        specificUtcOffset: specificUtcOffset,
        sourceApp: options?.sourceApp,
      );
    }

    // Case 2: Pipeline detected a known preset.
    if (detection.isDetected && detection.matchedPreset != null) {
      final preset = detection.matchedPreset!;
      return ImportConfiguration(
        mappings: preset.mappings,
        entityTypesToImport: preset.supportedEntities,
        sourceApp: preset.sourceApp ?? options?.sourceApp,
        preset: preset,
        timeInterpretation: timeInterpretation,
        specificUtcOffset: specificUtcOffset,
      );
    }

    // Case 3: No preset detected. Auto-map from headers using keywords.
    final autoMapping = _autoMapFromHeaders(parsedCsv.headers);
    return ImportConfiguration(
      mappings: {'primary': autoMapping},
      timeInterpretation: timeInterpretation,
      specificUtcOffset: specificUtcOffset,
      sourceApp: options?.sourceApp,
    );
  }

  /// Build a [FieldMapping] from CSV headers using keyword matching.
  ///
  /// Scans each header for known patterns and maps it to the corresponding
  /// Submersion target field.
  FieldMapping _autoMapFromHeaders(List<String> headers) {
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

  /// Match a lowercase header to a target field using keyword patterns.
  String? _guessTargetField(String header) {
    // Dive number.
    if (header.contains('dive') &&
        (header.contains('number') || header.contains('no'))) {
      return 'diveNumber';
    }
    // Combined dateTime.
    if (header.contains('date') && header.contains('time')) return 'dateTime';
    // Date (not containing 'time').
    if (_isDateOnly(header)) return 'date';
    // Time (not containing 'date', not duration/bottom/surface/run).
    if (_isTimeOnly(header)) return 'time';
    // Depth fields.
    if (header.contains('max') && header.contains('depth')) return 'maxDepth';
    if (header.contains('avg') && header.contains('depth')) return 'avgDepth';
    // Duration.
    if (_isDuration(header)) return 'duration';
    // Temperature.
    if (header.contains('water') && header.contains('temp')) return 'waterTemp';
    if (header.contains('air') && header.contains('temp')) return 'airTemp';
    // Site/location.
    if (header.contains('site') || header.contains('location')) {
      return 'siteName';
    }
    // People.
    if (header.contains('buddy')) return 'buddy';
    if (header.contains('dive') && header.contains('master')) {
      return 'diveMaster';
    }
    if (header == 'divemaster') return 'diveMaster';
    // Rating.
    if (header.contains('rating')) return 'rating';
    // Notes.
    if (header.contains('note')) return 'notes';
    // Visibility.
    if (header.contains('visibility')) return 'visibility';
    // Pressure.
    if (header.contains('start') && header.contains('pressure')) {
      return 'startPressure';
    }
    if (header.contains('end') && header.contains('pressure')) {
      return 'endPressure';
    }
    // Tank.
    if (header.contains('tank') && header.contains('volume')) {
      return 'tankVolume';
    }
    // Gas.
    if (header.contains('o2') || header.contains('oxygen')) return 'o2Percent';
    // Computer info.
    if (header.contains('computer')) return 'computer';
    if (header.contains('serial')) return 'serialNumber';
    if (header.contains('firmware')) return 'firmware';
    // Gear.
    if (header.contains('suit')) return 'suit';
    if (header.contains('weight')) return 'weight';
    // Tags.
    if (header.contains('tag')) return 'tags';
    // GPS.
    if (header.contains('gps')) return 'gps';
    // Weather.
    if (header.contains('wind') && header.contains('speed')) return 'windSpeed';
    if (header.contains('wind') && header.contains('dir')) {
      return 'windDirection';
    }
    if (header.contains('cloud')) return 'cloudCover';
    if (header.contains('precip')) return 'precipitation';
    if (header.contains('humid')) return 'humidity';
    if (header.contains('weather') && header.contains('desc')) {
      return 'weatherDescription';
    }
    return null;
  }

  bool _isDateOnly(String h) =>
      h == 'date' || (h.contains('date') && !h.contains('time'));

  bool _isTimeOnly(String h) =>
      h == 'time' ||
      (h.contains('time') &&
          !h.contains('date') &&
          !h.contains('bottom') &&
          !h.contains('duration') &&
          !h.contains('surface') &&
          !h.contains('run'));

  bool _isDuration(String h) =>
      (h.contains('bottom') && h.contains('time')) ||
      h.contains('duration') ||
      h.contains('runtime');
}
