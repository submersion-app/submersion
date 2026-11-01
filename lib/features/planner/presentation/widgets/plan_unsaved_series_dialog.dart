import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// What to do with a series that has unsaved changes.
enum UnsavedSeriesChoice { save, discard, cancel }

/// Asks what to do with a series that has unsaved changes (issue #3565),
/// before leaving the planner or replacing the plan. Dismissing it cancels.
Future<UnsavedSeriesChoice> showUnsavedSeriesDialog(
  BuildContext context,
) async {
  final choice = await showDialog<UnsavedSeriesChoice>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      void choose(UnsavedSeriesChoice value) =>
          Navigator.pop(dialogContext, value);
      return AlertDialog(
        title: Text(l10n.plannerSeries_unsaved_title),
        content: Text(l10n.plannerSeries_unsaved_body),
        actions: [
          TextButton(
            onPressed: () => choose(UnsavedSeriesChoice.cancel),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => choose(UnsavedSeriesChoice.discard),
            child: Text(l10n.plannerSeries_unsaved_discard),
          ),
          FilledButton(
            onPressed: () => choose(UnsavedSeriesChoice.save),
            child: Text(l10n.common_action_save),
          ),
        ],
      );
    },
  );
  return choice ?? UnsavedSeriesChoice.cancel;
}
