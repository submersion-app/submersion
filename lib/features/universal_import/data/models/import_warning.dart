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

/// Stable identifiers for warnings the UI recognises.
///
/// [ImportWarning.message] is written in English by the parsers, which have no
/// [BuildContext]. A code lets the summary screen show a localized, actionable
/// explanation instead, and lets identical notices from a batch of files be
/// grouped into one row. Warnings without a code fall back to their message.
enum ImportWarningCode {
  /// The source file recorded no tank pressure, so gas consumption and SAC
  /// cannot be derived. Not a defect in the file or the parser: several dive
  /// computers and vendor export apps simply do not write it.
  noTankPressure,
}

/// A warning or error encountered during import parsing or validation.
class ImportWarning extends Equatable {
  /// Severity of the warning.
  final ImportWarningSeverity severity;

  /// Stable identifier for warnings the UI localizes and groups; null for
  /// one-off messages that are only ever shown verbatim.
  final ImportWarningCode? code;

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
    this.code,
    this.entityType,
    this.itemIndex,
    this.field,
  });

  // `code` is appended rather than placed alongside `severity` so the existing
  // positional expectations in the model's tests keep their meaning.
  @override
  List<Object?> get props => [
    severity,
    message,
    entityType,
    itemIndex,
    field,
    code,
  ];
}
