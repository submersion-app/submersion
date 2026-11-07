import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What just changed on the template, for the dialog's wording: a part of
/// an assembly, or the members of an equipment set (issue #4283).
enum AssemblyHistoryChange { added, removed, replaced, setMembers }

/// The diver's answer: keep past dives as they were, or rewrite them too.
enum AssemblyHistoryChoice { futureOnly, alsoPast }

/// Asks whether a template change should also be applied to the logged
/// dives that carry the template (issue #1487, "swap with history"; issue
/// #4283 for sets). Callers skip it when [pastDiveCount] is zero. Returns
/// null when dismissed.
Future<AssemblyHistoryChoice?> showAssemblyHistoryDialog(
  BuildContext context, {
  required int pastDiveCount,
  required AssemblyHistoryChange change,
}) {
  final l10n = context.l10n;
  final onDives = change == AssemblyHistoryChange.setMembers
      ? l10n.equipment_setEdit_historyOnDives(pastDiveCount)
      : l10n.equipment_components_historyOnDives(pastDiveCount);
  final ask = switch (change) {
    AssemblyHistoryChange.added => l10n.equipment_components_historyAskAdded,
    AssemblyHistoryChange.removed =>
      l10n.equipment_components_historyAskRemoved,
    AssemblyHistoryChange.replaced =>
      l10n.equipment_components_historyAskReplaced,
    AssemblyHistoryChange.setMembers => l10n.equipment_setEdit_historyAsk,
  };
  return showDialog<AssemblyHistoryChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.equipment_components_historyTitle),
      // Two complete sentences in every locale, joined with a space rather
      // than a third key.
      content: Text('$onDives $ask'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(AssemblyHistoryChoice.alsoPast),
          child: Text(l10n.equipment_components_historyAlsoPast(pastDiveCount)),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(AssemblyHistoryChoice.futureOnly),
          child: Text(l10n.equipment_components_historyFutureOnly),
        ),
      ],
    ),
  );
}

/// Asks the swap-with-history question when [assemblyId] is on at least one
/// logged dive; with none there is nothing to ask and the answer is from now
/// on. Null means the diver backed out and nothing should change. The count
/// names the logged dives a rewrite visits, so the number and the result
/// agree.
Future<AssemblyHistoryChoice?> askAssemblyHistory(
  BuildContext context,
  WidgetRef ref, {
  required String assemblyId,
  required AssemblyHistoryChange change,
}) async {
  final count = await ref
      .read(diveRepositoryProvider)
      .countLoggedDivesWithAssembly(assemblyId);
  if (count == 0) return AssemblyHistoryChoice.futureOnly;
  if (!context.mounted) return null;
  return showAssemblyHistoryDialog(
    context,
    pastDiveCount: count,
    change: change,
  );
}

/// The same question for a change to the members of set [setId].
Future<AssemblyHistoryChoice?> askSetHistory(
  BuildContext context,
  WidgetRef ref, {
  required String setId,
}) async {
  final count = await ref
      .read(diveRepositoryProvider)
      .countLoggedDivesWithSet(setId);
  if (count == 0) return AssemblyHistoryChoice.futureOnly;
  if (!context.mounted) return null;
  return showAssemblyHistoryDialog(
    context,
    pastDiveCount: count,
    change: AssemblyHistoryChange.setMembers,
  );
}
