import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/csv/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/csv/models/import_configuration.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_correlator.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_detector.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_parser.dart';
import 'package:submersion/features/universal_import/data/csv/pipeline/csv_transformer.dart';
import 'package:submersion/features/universal_import/data/csv/presets/built_in_presets.dart';
import 'package:submersion/features/universal_import/data/csv/presets/preset_registry.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// Orchestrates the full CSV import pipeline: Parse -> Detect -> Transform
/// -> Correlate.
///
/// Each stage is independently injectable for testing. By default, the
/// pipeline ships with the built-in preset registry and default stage
/// implementations.
class CsvPipeline {
  factory CsvPipeline({
    PresetRegistry? registry,
    CsvParser? parser,
    CsvTransformer? transformer,
    CsvCorrelator? correlator,
  }) {
    final resolvedRegistry =
        registry ?? PresetRegistry(builtInPresets: builtInCsvPresets);
    return CsvPipeline._(
      registry: resolvedRegistry,
      parser: parser ?? const CsvParser(),
      detector: CsvDetector(resolvedRegistry),
      transformer: transformer ?? CsvTransformer(),
      correlator: correlator ?? const CsvCorrelator(),
    );
  }

  CsvPipeline._({
    required PresetRegistry registry,
    required CsvParser parser,
    required CsvDetector detector,
    required CsvTransformer transformer,
    required CsvCorrelator correlator,
  }) : _registry = registry,
       _parser = parser,
       _detector = detector,
       _transformer = transformer,
       _correlator = correlator;

  final PresetRegistry _registry;
  final CsvParser _parser;
  final CsvDetector _detector;
  final CsvTransformer _transformer;
  final CsvCorrelator _correlator;

  /// The preset registry used by this pipeline.
  PresetRegistry get registry => _registry;

  // ---------------------------------------------------------------------------
  // Stage 1: Parse
  // ---------------------------------------------------------------------------

  /// Parse raw CSV bytes into a [ParsedCsv].
  ///
  /// Throws [CsvParseException] if the file is empty or malformed.
  ParsedCsv parse(Uint8List fileBytes) => _parser.parse(fileBytes);

  // ---------------------------------------------------------------------------
  // Stage 2: Detect
  // ---------------------------------------------------------------------------

  /// Score [csv] headers against all known presets and return the best match.
  DetectionResult detect(ParsedCsv csv) => _detector.detect(csv);

  // ---------------------------------------------------------------------------
  // Stages 4-5: Execute (Transform + Correlate)
  // ---------------------------------------------------------------------------

  /// Transform and correlate [primaryCsv] (and optional [profileCsv]) using
  /// [config] to produce an [ImportPayload].
  ///
  /// File role resolution:
  /// - If [config.mappings] contains the key 'dive_list', the primary CSV is
  ///   treated as the dive list file ('dive_list' role).
  /// - Otherwise, 'primary' is used as the file role.
  ///
  /// Profile CSV:
  /// - When [profileCsv] is provided and [config.mappings] contains
  ///   'dive_profile', the profile CSV is transformed with that mapping and
  ///   profiles are matched to dives by dive number / date / time.
  ImportPayload execute({
    required ParsedCsv primaryCsv,
    ParsedCsv? profileCsv,
    required ImportConfiguration config,
  }) {
    // Determine the file role for the primary CSV.
    final primaryRole = config.mappings.containsKey('dive_list')
        ? 'dive_list'
        : 'primary';

    // Transform the primary CSV.
    final diveListRows = _transformer.transform(
      primaryCsv,
      config,
      fileRole: primaryRole,
    );

    // Transform the profile CSV if provided and a mapping exists.
    final profileRows =
        (profileCsv != null && config.mappings.containsKey('dive_profile'))
        ? _transformer.transform(profileCsv, config, fileRole: 'dive_profile')
        : null;

    // Correlate all extracted entities.
    final correlated = _correlator.correlate(
      diveListRows: diveListRows,
      profileRows: profileRows,
      config: config,
    );

    return correlated.toImportPayload();
  }
}
