import 'package:submersion/features/universal_import/data/csv/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';
import 'package:submersion/features/universal_import/data/csv/presets/preset_registry.dart';

/// Stage 2: Detect which app produced the CSV by scoring headers against
/// known presets.
///
/// Wraps [PresetRegistry.detectPreset] and returns a [DetectionResult]
/// describing the best match, confidence score, and whether the matched
/// preset expects additional file roles (e.g. Subsurface dive profile).
class CsvDetector {
  const CsvDetector(this._registry);

  final PresetRegistry _registry;

  /// Runs detection on [parsedCsv] and returns a [DetectionResult].
  ///
  /// If one or more presets score above their match threshold the top-ranked
  /// match becomes the primary result. When no preset matches, a
  /// [DetectionResult] with null [DetectionResult.matchedPreset] and zero
  /// confidence is returned.
  DetectionResult detect(ParsedCsv parsedCsv) {
    final rankedMatches = _registry.detectPreset(parsedCsv.headers);

    if (rankedMatches.isEmpty) {
      return const DetectionResult();
    }

    final best = rankedMatches.first;
    final hasAdditionalFileRoles = best.preset.isMultiFile;

    return DetectionResult(
      matchedPreset: best.preset,
      sourceApp: best.preset.sourceApp,
      confidence: best.score,
      rankedMatches: rankedMatches,
      hasAdditionalFileRoles: hasAdditionalFileRoles,
    );
  }
}
