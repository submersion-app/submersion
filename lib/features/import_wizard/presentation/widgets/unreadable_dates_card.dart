import 'package:flutter/material.dart';

import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How many row numbers are listed before the rest are summarised as a count.
const _maxListedRows = 10;

/// Reports CSV rows that were not imported because their date could not be
/// read (issue #1828), with the spreadsheet rows to go and fix.
///
/// Unlike the "Not in the file" notices this is a problem with the import
/// itself: these dives are missing. It is styled with the theme's error
/// container so it is not mistaken for a footnote.
class UnreadableDatesCard extends StatelessWidget {
  /// A notice of kind [ImportNoticeKind.unreadableDates].
  final ImportNotice notice;

  const UnreadableDatesCard({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final foreground = theme.colorScheme.onErrorContainer;
    final rowsLine = _rowsLine(l10n, notice.rowNumbers);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.errorContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, size: 20, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.universalImport_summary_unreadableDatesTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.universalImport_summary_unreadableDatesBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.universalImport_summary_unreadableDatesCount(
                      notice.affectedDives,
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                    ),
                  ),
                  if (rowsLine != null)
                    Text(
                      rowsLine,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Rows 4, 9, 12", or the first few followed by how many more; null when
  /// the parser could not say which rows they were.
  static String? _rowsLine(AppLocalizations l10n, List<int> rows) {
    if (rows.isEmpty) return null;
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
}
