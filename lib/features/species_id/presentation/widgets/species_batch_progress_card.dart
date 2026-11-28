import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/species_id/domain/entities/dive_species_run_state.dart';
import 'package:submersion/features/species_id/presentation/providers/species_batch_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The progress of Find species over many dives (issue #5127): dives and
/// photos done, why it is paused, Resume and Cancel. Draws nothing while no
/// such run is going. Shown on Home and on the Species ID settings page.
class SpeciesBatchProgressCard extends ConsumerWidget {
  const SpeciesBatchProgressCard({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(speciesBatchProgressProvider);
    if (progress == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final batch = ref.read(speciesBatchRunProvider.notifier);
    final status = !progress.paused
        ? null
        : progress.pauseReason == DiveRunPause.tooHot
        ? l10n.speciesReview_pausedHot
        : l10n.speciesBatch_pausedBackground;
    return Card(
      key: const ValueKey('species_batch_progress'),
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.travel_explore_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.speciesBatch_progressTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.itemsTotal == 0 ? null : progress.fraction,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.speciesBatch_progress(
                progress.diveNumber,
                progress.diveCount,
                progress.itemsDone,
                progress.itemsTotal,
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (status != null)
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 4,
                children: [
                  if (progress.paused)
                    TextButton(
                      key: const ValueKey('species_batch_resume'),
                      onPressed: batch.resume,
                      child: Text(l10n.speciesReview_resume),
                    ),
                  TextButton(
                    key: const ValueKey('species_batch_cancel'),
                    onPressed: batch.cancel,
                    child: Text(l10n.common_action_cancel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
