import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
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
///
/// The page that asked may be rebuilt as another while the confirmation
/// counts (the window resized to another layout, a phone turned): the
/// providers and the messenger are taken from [context] up front, never
/// through a widget's ref after the wait.
Future<BulkActionOutcome> findSpeciesInDives(
  BuildContext context,
  List<String> diveIds,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  if (container.read(speciesBatchRunProvider)?.isActive ?? false) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.speciesBatch_alreadyRunning)),
    );
    return BulkActionOutcome.cancelled;
  }
  final planner = container.read(speciesBatchPlannerProvider);
  final choice = await showDialog<SpeciesBatchChoice>(
    context: context,
    builder: (_) => SpeciesBatchConfirmDialog(
      plans: planner.plan(diveIds),
      diveCount: diveIds.length,
    ),
  );
  if (choice == null) return BulkActionOutcome.cancelled;
  final started = container
      .read(speciesBatchRunProvider.notifier)
      .start(choice.plan, onDeviceOnly: choice.onDeviceOnly);
  if (!started) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.speciesBatch_alreadyRunning)),
    );
    return BulkActionOutcome.cancelled;
  }
  return BulkActionOutcome.completed;
}

/// Find species over every dive of the current diver with a photo or video.
/// A logbook that cannot be read (another one being opened, say) is logged
/// and told as a failed count, never left as an unhandled error.
Future<void> findSpeciesInLogbook(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  final List<String> ids;
  try {
    final diverId = await container.read(
      validatedCurrentDiverIdProvider.future,
    );
    ids = await container
        .read(diveMediaBatchRepositoryProvider)
        .diveIdsWithMedia(diverId: diverId);
  } on Object catch (e, st) {
    _log.error(
      'Could not read the dives to find species in',
      error: e,
      stackTrace: st,
    );
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.speciesBatch_countFailed)),
    );
    return;
  }
  if (!context.mounted) return;
  await findSpeciesInDives(context, ids);
}

const _log = LoggerService('FindSpeciesBatchFlow');

/// "Find species" for the dive list's selection bar (issue #5127). Shown
/// only where a run can look at anything ([speciesBatchAvailableProvider]).
BulkAction findSpeciesBulkAction(
  BuildContext context, {
  required Set<String> Function() selected,
}) => BulkAction(
  id: 'find_species',
  icon: Icons.travel_explore_outlined,
  label: context.l10n.speciesBatch_findInDives,
  onInvoke: () => findSpeciesInDives(context, selected().toList()),
);
