import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/services/value_transforms.dart';

/// Maps CSV columns to Submersion fields with optional value transforms.
///
/// Used by the field mapping step to show the user how source columns
/// will be mapped, and by CsvImportParser to apply the mapping during parsing.
class FieldMapping extends Equatable {
  /// Display name for this mapping (e.g., "MacDive Default").
  final String name;

  /// Source application this mapping is designed for.
  final SourceApp? sourceApp;

  /// Individual column mappings.
  final List<ColumnMapping> columns;

  const FieldMapping({
    required this.name,
    this.sourceApp,
    required this.columns,
  });

  /// Look up the target field for a given source column name.
  ColumnMapping? mappingForColumn(String sourceColumn) {
    final lower = sourceColumn.toLowerCase().trim();
    for (final col in columns) {
      if (col.sourceColumn.toLowerCase().trim() == lower) {
        return col;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [name, sourceApp, columns];
}

/// Maps a single CSV column to a Submersion field.
class ColumnMapping extends Equatable {
  /// CSV header name (matched case-insensitively).
  final String sourceColumn;

  /// Submersion field name (e.g., "maxDepth", "waterTemp").
  final String targetField;

  /// Optional transform to apply to the value during import.
  final ValueTransform? transform;

  /// Default value to use if the source column is empty.
  final String? defaultValue;

  const ColumnMapping({
    required this.sourceColumn,
    required this.targetField,
    this.transform,
    this.defaultValue,
  });

  @override
  List<Object?> get props => [
    sourceColumn,
    targetField,
    transform,
    defaultValue,
  ];
}
