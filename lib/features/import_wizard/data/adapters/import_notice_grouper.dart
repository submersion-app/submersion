import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// Folds parser warnings into one summary row per kind.
///
/// `PayloadMerger` concatenates each file's warnings, so a batch of twenty
/// files that all lack tank pressure arrives as twenty identical entries.
///
/// Only coded warnings are grouped: uncoded ones are one-off English strings
/// with no localized wording for the summary to show. Errors are excluded too,
/// since those either failed their file outright (already reported per file) or
/// surface as the run's error message.
///
/// Each file contributes one warning per affected dive, so the count of
/// warnings is the count of affected dives. It is clamped to [importedDives] so
/// that consolidating or skipping duplicates can never leave a notice claiming
/// more dives than the run actually imported. A run that imported nothing gets
/// no notices at all -- there is no dive for them to explain.
List<ImportNotice> groupImportNotices(
  List<ImportWarning> warnings,
  int importedDives,
) {
  if (importedDives <= 0) return const [];

  final counts = <ImportNoticeKind, int>{};
  for (final warning in warnings) {
    if (warning.severity == ImportWarningSeverity.error) continue;
    final kind = _kindFor(warning.code);
    if (kind == null) continue;
    counts[kind] = (counts[kind] ?? 0) + 1;
  }

  return [
    for (final entry in counts.entries)
      ImportNotice(
        kind: entry.key,
        affectedDives: entry.value > importedDives
            ? importedDives
            : entry.value,
      ),
  ];
}

ImportNoticeKind? _kindFor(ImportWarningCode? code) => switch (code) {
  ImportWarningCode.noTankPressure => ImportNoticeKind.noTankPressure,
  null => null,
};
