import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What just changed on the template, for the dialog's wording.
enum AssemblyHistoryChange { added, removed, replaced }

/// The diver's answer: keep past dives as they were, or rewrite them too.
enum AssemblyHistoryChoice { futureOnly, alsoPast }

/// Asks whether a template change should also be applied to the past dives
/// that carry the assembly (issue #1487, "swap with history"). Callers skip
/// it when [pastDiveCount] is zero. Returns null when dismissed.
Future<AssemblyHistoryChoice?> showAssemblyHistoryDialog(
  BuildContext context, {
  required int pastDiveCount,
  required AssemblyHistoryChange change,
}) {
  final l10n = context.l10n;
  final ask = switch (change) {
    AssemblyHistoryChange.added => l10n.equipment_components_historyAskAdded,
    AssemblyHistoryChange.removed =>
      l10n.equipment_components_historyAskRemoved,
    AssemblyHistoryChange.replaced =>
      l10n.equipment_components_historyAskReplaced,
  };
  return showDialog<AssemblyHistoryChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.equipment_components_historyTitle),
      // Two complete sentences in every locale, joined with a space rather
      // than a third key.
      content: Text(
        '${l10n.equipment_components_historyOnDives(pastDiveCount)} $ask',
      ),
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
/// on. Null means the diver backed out and nothing should change.
Future<AssemblyHistoryChoice?> askAssemblyHistory(
  BuildContext context,
  WidgetRef ref, {
  required String assemblyId,
  required AssemblyHistoryChange change,
}) async {
  final count = await ref
      .read(equipmentRepositoryProvider)
      .getDiveCountForEquipment(assemblyId);
  if (count == 0) return AssemblyHistoryChoice.futureOnly;
  if (!context.mounted) return null;
  return showAssemblyHistoryDialog(
    context,
    pastDiveCount: count,
    change: change,
  );
}
