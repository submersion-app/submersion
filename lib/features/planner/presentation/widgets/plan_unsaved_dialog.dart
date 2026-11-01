import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// What to do with a plan that has unsaved changes.
enum UnsavedPlanChoice { save, discard, cancel }

/// Asks what to do with a plan that has unsaved changes (issue #3565), before
/// leaving the planner or replacing it with another. [isSeries] is whether it
/// saves as a series rather than a single dive. Dismissing it cancels.
Future<UnsavedPlanChoice> showUnsavedPlanDialog(
  BuildContext context, {
  required bool isSeries,
}) async {
  final choice = await showDialog<UnsavedPlanChoice>(
    context: context,
    builder: (dialogContext) {
      final l10n = dialogContext.l10n;
      void choose(UnsavedPlanChoice value) =>
          Navigator.pop(dialogContext, value);
      return AlertDialog(
        title: Text(
          isSeries
              ? l10n.plannerSeries_unsaved_title
              : l10n.plannerSeries_unsaved_titleDive,
        ),
        content: Text(
          isSeries
              ? l10n.plannerSeries_unsaved_body
              : l10n.plannerSeries_unsaved_bodyDive,
        ),
        actions: [
          TextButton(
            onPressed: () => choose(UnsavedPlanChoice.cancel),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => choose(UnsavedPlanChoice.discard),
            child: Text(l10n.plannerSeries_unsaved_discard),
          ),
          FilledButton(
            onPressed: () => choose(UnsavedPlanChoice.save),
            child: Text(l10n.common_action_save),
          ),
        ],
      );
    },
  );
  return choice ?? UnsavedPlanChoice.cancel;
}
