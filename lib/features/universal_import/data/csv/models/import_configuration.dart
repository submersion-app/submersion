import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/field_mapping.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';

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
  /// Field mappings per file role (e.g., 'dive_list' -> mapping,
  /// 'dive_profile' -> mapping).
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
    this.entityTypesToImport = const {
      ImportEntityType.dives,
      ImportEntityType.sites,
    },
    this.preset,
    this.sourceApp,
  });

  /// Convenience: the primary file mapping (single-file imports).
  FieldMapping? get primaryMapping =>
      mappings['primary'] ?? mappings.values.firstOrNull;

  @override
  List<Object?> get props => [
    mappings,
    timeInterpretation,
    specificUtcOffset,
    entityTypesToImport,
    preset,
    sourceApp,
  ];
}
