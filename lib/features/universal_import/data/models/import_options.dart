import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Configuration options for an import operation.
class ImportOptions extends Equatable {
  /// Tag to apply to all imported items (e.g., "MacDive Import 2026-02-09").
  /// Null means no tag will be applied.
  final String? batchTag;

  /// The detected/confirmed source app.
  final SourceApp sourceApp;

  /// The detected/confirmed format.
  final ImportFormat format;

  const ImportOptions({
    this.batchTag,
    required this.sourceApp,
    required this.format,
  });

  /// Generate a default batch tag from the source app and current date.
  static String defaultTag(SourceApp sourceApp) {
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return '${sourceApp.displayName} Import $date';
  }

  @override
  List<Object?> get props => [batchTag, sourceApp, format];
}
