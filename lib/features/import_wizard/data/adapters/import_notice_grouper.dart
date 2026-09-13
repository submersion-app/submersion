import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// Folds parser warnings into one summary row per kind.
///
/// `PayloadMerger` concatenates each file's warnings, so a batch of twenty
/// files that all lack tank pressure arrives as twenty identical entries.
///
/// Errors are excluded, since those either failed their file outright (already
/// reported per file) or surface as the run's error message. So are
/// [ImportWarningCode.diagnostic] warnings, which are recorded on purpose
/// without being shown.
///
/// A warning stands for [ImportWarning.count] items (one, unless its parser
/// aggregated), and a kind's count is the sum over its warnings. Kinds that
/// count imported dives are clamped to [importedDives], so that consolidating
/// or skipping duplicates can never leave a notice claiming more dives than
/// the run actually imported. A run that imported nothing gets only the kinds
/// that report dives missing from the import
/// ([ImportNoticeKind.reportsMissingDives]); the rest have no dive to explain.
///
/// Names (divers, logbooks) from several files are merged without repeats, in
/// the order first seen. Rows skipped for an unreadable date list their
/// spreadsheet rows in order. Notices come out in [ImportNoticeKind] order,
/// data loss first.
List<ImportNotice> groupImportNotices(
  List<ImportWarning> warnings,
  int importedDives,
) {
  final counts = <ImportNoticeKind, int>{};
  final names = <ImportNoticeKind, Set<String>>{};
  final rows = <int>{};
  for (final warning in warnings) {
    if (warning.severity == ImportWarningSeverity.error) continue;
    final kind = _kindFor(warning.code);
    if (kind == null) continue;
    if (importedDives <= 0 && !kind.reportsMissingDives) continue;
    counts[kind] = (counts[kind] ?? 0) + warning.count;
    (names[kind] ??= <String>{}).addAll(warning.names);
    final row = warning.sourceRow;
    if (kind == ImportNoticeKind.unreadableDates && row != null) rows.add(row);
  }

  final kinds = counts.keys.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return [
    for (final kind in kinds)
      ImportNotice(
        kind: kind,
        count: kind.countsImportedDives && counts[kind]! > importedDives
            ? importedDives
            : counts[kind]!,
        names: List.unmodifiable(names[kind]!),
        rowNumbers: kind == ImportNoticeKind.unreadableDates
            ? List.unmodifiable(rows.toList()..sort())
            : const [],
      ),
  ];
}

ImportNoticeKind? _kindFor(ImportWarningCode? code) => switch (code) {
  ImportWarningCode.noTankPressure => ImportNoticeKind.noTankPressure,
  ImportWarningCode.unreadableDate => ImportNoticeKind.unreadableDates,
  ImportWarningCode.divesSkipped => ImportNoticeKind.divesSkipped,
  ImportWarningCode.multipleDivers => ImportNoticeKind.multipleDivers,
  ImportWarningCode.profileUnreadable => ImportNoticeKind.profileUnreadable,
  ImportWarningCode.macdiveProfileUndecodable =>
    ImportNoticeKind.macdiveProfileUndecodable,
  ImportWarningCode.profileUndecodableOnPlatform =>
    ImportNoticeKind.profileUndecodableOnPlatform,
  ImportWarningCode.columnsNotImported => ImportNoticeKind.columnsNotImported,
  ImportWarningCode.valuesNotConverted => ImportNoticeKind.valuesNotConverted,
  ImportWarningCode.photosSkipped => ImportNoticeKind.photosSkipped,
  ImportWarningCode.macdiveXmlOmitsCertsAndService =>
    ImportNoticeKind.macdiveXmlOmitsCertsAndService,
  ImportWarningCode.macdiveLogbooksNotImported =>
    ImportNoticeKind.macdiveLogbooksNotImported,
  ImportWarningCode.diagnostic || null => null,
};
