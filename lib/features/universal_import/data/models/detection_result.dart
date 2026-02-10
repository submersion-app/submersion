import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Result of format detection on an imported file.
///
/// Contains the detected format, probable source app, confidence score,
/// and any warnings encountered during detection.
class DetectionResult extends Equatable {
  /// Detected file format.
  final ImportFormat format;

  /// Probable source application, if identifiable.
  final SourceApp? sourceApp;

  /// Confidence score from 0.0 (no idea) to 1.0 (certain).
  ///
  /// Thresholds:
  /// - >= 0.85: auto-proceed with confirmation
  /// - < 0.85: show result with manual override option
  final double confidence;

  /// For CSV files: suggested column-to-field mappings detected from headers.
  final Map<String, String>? suggestedMapping;

  /// Warnings encountered during detection (e.g., truncated file).
  final List<String> warnings;

  /// Raw CSV headers, if the file was detected as CSV.
  final List<String>? csvHeaders;

  const DetectionResult({
    required this.format,
    this.sourceApp,
    required this.confidence,
    this.suggestedMapping,
    this.warnings = const [],
    this.csvHeaders,
  });

  /// Whether the detection is confident enough to auto-proceed.
  bool get isHighConfidence => confidence >= 0.85;

  /// Whether the detected format has a parser implementation.
  bool get isFormatSupported => format.isSupported;

  /// A human-readable description of the detection result.
  String get description {
    if (sourceApp != null) {
      return 'Detected ${sourceApp!.displayName} ${format.displayName} file '
          '(${(confidence * 100).toStringAsFixed(0)}% confidence)';
    }
    return 'Detected ${format.displayName} file '
        '(${(confidence * 100).toStringAsFixed(0)}% confidence)';
  }

  @override
  List<Object?> get props => [
    format,
    sourceApp,
    confidence,
    suggestedMapping,
    warnings,
    csvHeaders,
  ];
}
