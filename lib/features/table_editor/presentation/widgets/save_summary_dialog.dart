import 'package:flutter/material.dart';

import 'package:submersion/features/table_editor/domain/paste_planner.dart';
import 'package:submersion/features/table_editor/domain/save_summary.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver is told about one [skip] of a paste.
String pasteSkipLine(
  AppLocalizations l10n,
  PasteSkip skip, {
  required String Function(String fieldName) columnLabel,
}) => switch (skip.reason) {
  PasteSkipReason.readOnlyColumn => l10n.tableEditor_skip_readOnlyColumn(
    columnLabel(skip.detail),
  ),
  PasteSkipReason.unknownRow => l10n.tableEditor_skip_unknownRow(skip.detail),
  PasteSkipReason.hiddenRow => l10n.tableEditor_skip_hiddenRow(skip.detail),
  PasteSkipReason.ambiguousRow => l10n.tableEditor_skip_ambiguousRow(
    skip.detail,
  ),
  PasteSkipReason.readOnlyCell => l10n.tableEditor_skip_readOnlyCell(
    skip.detail,
  ),
  PasteSkipReason.unknownColumn => l10n.tableEditor_skip_unknownColumn(
    skip.detail,
  ),
  PasteSkipReason.truncated => l10n.tableEditor_skip_truncated(skip.count),
};

/// What Save all is about to do (#3422). Returns true to go ahead.
Future<bool> showSaveSummaryDialog(
  BuildContext context,
  SaveSummary summary, {
  required String Function(String fieldName) columnLabel,
}) async {
  final l10n = context.l10n;
  final lines = <String?>[
    l10n.tableEditor_summary_changed(summary.changed),
    if (summary.overwrites > 0)
      l10n.tableEditor_summary_overwrite(summary.overwrites),
    if (summary.needsAttention > 0)
      l10n.tableEditor_summary_attention(summary.needsAttention),
    if (summary.changedElsewhere > 0)
      l10n.tableEditor_summary_changedElsewhere(summary.changedElsewhere),
    switch (summary.matching) {
      null => null,
      PasteMatching.byNumber => l10n.tableEditor_summary_matching_number,
      PasteMatching.byName => l10n.tableEditor_summary_matching_name,
      PasteMatching.byPosition => l10n.tableEditor_summary_matching_position,
    },
    for (final s in summary.skipped)
      pasteSkipLine(l10n, s, columnLabel: columnLabel),
    ...summary.notes,
  ].nonNulls.toList();
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.tableEditor_summary_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(line),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: summary.changed == 0
              ? null
              : () => Navigator.of(context).pop(true),
          child: Text(l10n.tableEditor_saveAll),
        ),
      ],
    ),
  );
  return result == true;
}
