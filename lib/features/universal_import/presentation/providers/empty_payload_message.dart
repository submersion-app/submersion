import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// How many spreadsheet rows are named before the rest become a count.
const _maxListedRows = 5;

/// The text shown when a parsed file produced nothing to import.
///
/// A CSV whose every row was skipped for an unreadable date gets a summary:
/// how many rows, which ones, and where to look (the date mapping on the
/// step the user is on). The raw per-row warnings are English transformer
/// strings, and whichever came first used to be the whole message.
///
/// Anything else leads with a localized sentence and keeps the parser's own
/// warning as detail, since that text is what tells a user their file is
/// truncated or malformed. An error is preferred over an earlier note.
String emptyPayloadMessage(
  AppLocalizations l10n,
  List<ImportWarning> warnings,
) {
  final unreadable = [
    for (final warning in warnings)
      if (warning.code == ImportWarningCode.unreadableDate) warning,
  ];
  if (unreadable.isNotEmpty) {
    final rows = {for (final warning in unreadable) ?warning.sourceRow}.toList()
      ..sort();
    return [
      l10n.universalImport_error_unreadableDatesHeadline(unreadable.length),
      if (rows.isNotEmpty) _rowsLine(l10n, rows),
      l10n.universalImport_error_unreadableDatesHint,
    ].join('\n');
  }

  final detail =
      warnings
          .where((w) => w.severity == ImportWarningSeverity.error)
          .firstOrNull ??
      warnings.firstOrNull;
  return detail == null
      ? l10n.universalImport_error_noDataInFile
      : l10n.universalImport_error_noDataInFileWithDetails(detail.message);
}

/// "Rows 2, 3, 4", or the first few followed by how many more.
String _rowsLine(AppLocalizations l10n, List<int> rows) {
  if (rows.length <= _maxListedRows) {
    return l10n.universalImport_summary_unreadableDatesRows(
      rows.length,
      rows.join(', '),
    );
  }
  return l10n.universalImport_summary_unreadableDatesRowsMore(
    rows.length - _maxListedRows,
    rows.take(_maxListedRows).join(', '),
  );
}
