import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Countdown + checklist progress line shown on upcoming trip tiles, plus a
/// service-alert line when gear falls due before the trip ends.
class UpcomingTripBanner extends ConsumerWidget {
  final Trip trip;

  const UpcomingTripBanner({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(tripChecklistProgressProvider(trip.id));
    final progress = progressAsync.value;
    final serviceAlerts =
        ref.watch(tripServiceAlertsProvider(trip.id)).value ?? const [];

    final countdown = trip.isInProgress
        ? context.l10n.trips_list_inProgress
        : context.l10n.trips_list_countdown(trip.daysUntilStart);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                  context.l10n.checklists_progress(
                    progress.done,
                    progress.total,
                  ),
                  style: theme.textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        if (serviceAlerts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(Icons.build, size: 14, color: theme.colorScheme.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    // Per-clock alerts collapse to distinct items for the
                    // "N items" phrasing.
                    context.l10n.trips_serviceAlert_count(
                      serviceAlerts.map((a) => a.item.id).toSet().length,
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
