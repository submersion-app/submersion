import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/muted_observation_kinds_sheet.dart';
import 'package:submersion/features/insights/presentation/widgets/observation_card.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every observation for the current diver, ranked (#2381, spec 5.4). A
/// detail pane on desktop ([embedded]) and its own page on a phone.
class InsightsObservationsPage extends ConsumerWidget {
  final bool embedded;
  const InsightsObservationsPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final observations = ref.watch(observationsProvider);
    final filtered = ref.watch(
      insightsFilterProvider.select((f) => f.hasActiveFilters),
    );
    final mutedAction = IconButton(
      icon: const Icon(Icons.visibility_off_outlined),
      tooltip: l10n.insights_observations_mutedKinds,
      onPressed: () => showMutedObservationKinds(context),
    );
    final body = observations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => StatEmptyState(
        icon: Icons.error_outline,
        message: l10n.insights_observations_error,
        action: l10n.insights_records_retry,
        onAction: () => retryObservations(ref),
      ),
      data: (list) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (embedded)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.insights_observations_title,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                mutedAction,
              ],
            ),
          if (filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.insights_observations_filterNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (list.isEmpty)
            StatEmptyState(
              icon: Icons.insights_outlined,
              message: l10n.insights_observations_empty,
            ),
          for (final (i, o) in list.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            ObservationCard(observation: o),
          ],
        ],
      ),
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.insights_observations_title),
        actions: [mutedAction],
      ),
      body: body,
    );
  }
}
