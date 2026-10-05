import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/observation_card.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Up to three observations at the top of the Insights landing (#2381).
/// Takes no space at all while loading or when there is nothing to say;
/// [padding] applies only when it shows something.
class ObservationsStrip extends ConsumerWidget {
  final EdgeInsetsGeometry padding;

  const ObservationsStrip({super.key, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final strip = ref.watch(observationStripProvider);
    final filtered = ref.watch(
      insightsFilterProvider.select((f) => f.hasActiveFilters),
    );
    return strip.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => Padding(
        padding: padding,
        child: StatEmptyState(
          icon: Icons.error_outline,
          message: l10n.insights_observations_error,
          action: l10n.insights_records_retry,
          onAction: () => retryObservations(ref),
        ),
      ),
      data: (observations) {
        if (observations.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.insights_observations_title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => openObservationsPage(context),
                    child: Text(l10n.insights_observations_seeAll),
                  ),
                ],
              ),
              if (filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.insights_observations_filterNote,
                    key: const Key('observations-filter-note'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final (i, o) in observations.indexed) ...[
                if (i > 0) const SizedBox(height: 8),
                ObservationCard(observation: o),
              ],
            ],
          ),
        );
      },
    );
  }
}
