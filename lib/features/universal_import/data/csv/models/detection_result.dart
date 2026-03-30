import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';

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
  List<Object?> get props => [
    matchedPreset,
    sourceApp,
    confidence,
    rankedMatches,
    hasAdditionalFileRoles,
  ];
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
  List<Object?> get props => [
    preset,
    score,
    matchedHeaders,
    totalSignatureHeaders,
  ];
}
