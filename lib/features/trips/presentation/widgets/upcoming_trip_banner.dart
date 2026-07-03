import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Countdown + checklist progress line shown on upcoming trip tiles.
class UpcomingTripBanner extends ConsumerWidget {
  final Trip trip;

  const UpcomingTripBanner({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(tripChecklistProgressProvider(trip.id));
    final progress = progressAsync.value;

    final countdown = trip.isInProgress
        ? context.l10n.trips_list_inProgress
        : context.l10n.trips_list_countdown(trip.daysUntilStart);

    return Row(
      children: [
        Icon(Icons.schedule, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          countdown,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (progress != null && progress.total > 0) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.checklists_progress(progress.done, progress.total),
              style: theme.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
