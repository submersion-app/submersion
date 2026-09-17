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
/// grouped into one row.
///
/// Every info or warning must carry a code (the [ImportWarning] constructor
/// asserts it): the summary shows coded warnings only, so an uncoded one would
/// vanish without a trace. Use [diagnostic] to record something on purpose
/// without showing it.
enum ImportWarningCode {
  /// The source file recorded no tank pressure, so gas consumption and SAC
  /// cannot be derived. Not a defect in the file or the parser: several dive
  /// computers and vendor export apps simply do not write it.
  noTankPressure,

  /// A CSV row was not imported because its date could not be read. Unlike
  /// the other codes this is about a dive that is missing from the import, so
  /// the warning carries the row in [ImportWarning.sourceRow].
  unreadableDate,

  /// A dive in the file could not be read and was left out of the import.
  /// One warning per skipped dive.
  divesSkipped,

  /// A dive's profile data is missing from the file or could not be read, so
  /// the dive was imported without a depth profile. One warning per dive.
  profileUnreadable,

  /// MacDive stored a dive's profile in a form Submersion cannot decode; its
  /// XML export carries a readable copy. [ImportWarning.count] is the number
  /// of dives.
  macdiveProfileUndecodable,

  /// This platform could not decode a dive's computer data, so the dive was
  /// imported without a depth profile. [ImportWarning.count] is the number of
  /// dives.
  profileUndecodableOnPlatform,

  /// An auto-mapped CSV column was left out because an earlier column
  /// already fills the same field. [ImportWarning.names] holds the column.
  columnsNotImported,

  /// A CSV value could not be converted to its field's type and was left
  /// blank. One warning per value.
  valuesNotConverted,

  /// A photo reference had no file name, so it could not be linked. One
  /// warning per photo.
  photosSkipped,

  /// A MacDive XML file carries no certifications or equipment service
  /// records: MacDive leaves both out of its XML export.
  macdiveXmlOmitsCertsAndService,

  /// MacDive logbooks are saved searches rather than stored lists, so none
  /// were imported. [ImportWarning.names] lists the logbooks.
  macdiveLogbooksNotImported,

  /// Recorded for logs and tests only; deliberately never shown to the diver.
  diagnostic,
}

/// A warning or error encountered during import parsing or validation.
class ImportWarning extends Equatable {
  /// Severity of the warning.
  final ImportWarningSeverity severity;

  /// Stable identifier for warnings the UI localizes and groups. Null only for
  /// errors, whose message is shown verbatim as the reason a file failed.
  final ImportWarningCode? code;

  /// Human-readable description of the issue.
  final String message;

  /// Which entity type this warning applies to, if applicable.
  final ImportEntityType? entityType;

  /// Index of the affected item within its entity type list, if applicable.
  final int? itemIndex;

  /// Field name that caused the warning, if applicable.
  final String? field;

  /// The row in the source file the warning is about, numbered as a
  /// spreadsheet shows it (header = row 1), if the parser knows it.
  final int? sourceRow;

  /// How many items this one warning stands for, for parsers that aggregate
  /// ("12 dives had ...") rather than emitting one warning per item.
  final int count;

  /// Names the summary lists for this warning, such as divers or logbooks.
  final List<String> names;

  const ImportWarning({
    required this.severity,
    required this.message,
    this.code,
    this.entityType,
    this.itemIndex,
    this.field,
    this.sourceRow,
    this.count = 1,
    this.names = const [],
  }) : assert(
         severity == ImportWarningSeverity.error || code != null,
         'Info and warning ImportWarnings need a code, or the import summary '
         'drops them; use ImportWarningCode.diagnostic to record one on purpose '
         'without showing it.',
       );

  // Later fields are appended rather than placed alongside `severity` so the
  // existing positional expectations in the model's tests keep their meaning.
  @override
  List<Object?> get props => [
    severity,
    message,
    entityType,
    itemIndex,
    field,
    code,
    sourceRow,
    count,
    names,
  ];
}

/// Picks the warning that explains why a file produced nothing to import.
extension ImportFailureDetail on Iterable<ImportWarning> {
  /// The first error, else the first warning that is not a
  /// [ImportWarningCode.diagnostic]. Parsers may record diagnostics before the
  /// error that actually sank the file, and diagnostics are never meant to be
  /// shown. Null when nothing showable was recorded.
  ImportWarning? get failureDetail =>
      where((w) => w.severity == ImportWarningSeverity.error).firstOrNull ??
      where((w) => w.code != ImportWarningCode.diagnostic).firstOrNull;
}
