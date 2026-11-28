import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_batch_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_batch_confirm_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

/// Find species over [diveIds] (issue #5127): counts them in the
/// confirmation, then starts the run, which carries on when the diver
/// leaves the page. One flow for the selection, a trip and the logbook.
///
/// Returns [BulkActionOutcome.completed] once the run started, so the dive
/// list leaves selection mode; backing out keeps the selection.
Future<BulkActionOutcome> findSpeciesInDives(
  BuildContext context,
  WidgetRef ref,
  List<String> diveIds,
) async {
  final batch = ref.read(speciesBatchRunProvider);
  if (batch?.isActive ?? false) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.speciesBatch_alreadyRunning)),
    );
    return BulkActionOutcome.cancelled;
  }
  final planner = ref.read(speciesBatchPlannerProvider);
  final choice = await showDialog<SpeciesBatchChoice>(
    context: context,
    builder: (_) => SpeciesBatchConfirmDialog(
      plans: planner.plan(diveIds),
      diveCount: diveIds.length,
    ),
  );
  if (choice == null) return BulkActionOutcome.cancelled;
  final started = ref
      .read(speciesBatchRunProvider.notifier)
      .start(choice.plan, onDeviceOnly: choice.onDeviceOnly);
  if (!started && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.speciesBatch_alreadyRunning)),
    );
    return BulkActionOutcome.cancelled;
  }
  return BulkActionOutcome.completed;
}

/// Find species over every dive of the current diver with a photo or video.
Future<void> findSpeciesInLogbook(BuildContext context, WidgetRef ref) async {
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final ids = await ref
      .read(diveMediaBatchRepositoryProvider)
      .diveIdsWithMedia(diverId: diverId);
  if (!context.mounted) return;
  await findSpeciesInDives(context, ref, ids);
}

/// "Find species" for the dive list's selection bar (issue #5127). Shown
/// only where a run can look at anything ([speciesBatchAvailableProvider]).
BulkAction findSpeciesBulkAction(
  BuildContext context,
  WidgetRef ref, {
  required Set<String> Function() selected,
}) => BulkAction(
  id: 'find_species',
  icon: Icons.travel_explore_outlined,
  label: context.l10n.speciesBatch_findInDives,
  onInvoke: () => findSpeciesInDives(context, ref, selected().toList()),
);
