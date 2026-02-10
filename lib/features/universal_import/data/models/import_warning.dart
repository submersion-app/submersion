import 'package:equatable/equatable.dart';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// Severity level for import warnings.
enum ImportWarningSeverity {
  /// Informational: missing optional field, unmapped column.
  info,

  /// Warning: possible duplicate, date out of range.
  warning,

  /// Error: missing required field, invalid value. Item excluded from import.
  error,
}

/// A warning or error encountered during import parsing or validation.
class ImportWarning extends Equatable {
  /// Severity of the warning.
  final ImportWarningSeverity severity;

  /// Human-readable description of the issue.
  final String message;

  /// Which entity type this warning applies to, if applicable.
  final ImportEntityType? entityType;

  /// Index of the affected item within its entity type list, if applicable.
  final int? itemIndex;

  /// Field name that caused the warning, if applicable.
  final String? field;

  const ImportWarning({
    required this.severity,
    required this.message,
    this.entityType,
    this.itemIndex,
    this.field,
  });

  @override
  List<Object?> get props => [severity, message, entityType, itemIndex, field];
}
