import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_fill_forecast_banner.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The story's cylinders line while a trip is under way (#2845): the full,
/// partial and empty counts and the fill forecast, opening the board. Shows
/// nothing before departure, after the trip, or with no slots.
class TripCylindersSummaryCard extends ConsumerWidget {
  final Trip trip;

  const TripCylindersSummaryCard({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Checked before any provider is watched, so a trip not under way
    // computes nothing.
    if (!trip.isInProgress) return const SizedBox.shrink();
    final states = ref.watch(tripCylinderStatesProvider(trip.id)).value;
    if (states == null || states.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final forecast = ref.watch(tripFillForecastProvider(trip.id)).value;
    final counts = tripCylinderCounts(states);
    final summary = l10n.trips_cylinders_summary(
      counts.full,
      counts.partial,
      counts.empty,
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('trip-cylinders-summary'),
        onTap: () => context.push('/trips/${trip.id}/cylinders'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(MdiIcons.divingScubaTank, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      counts.unknown == 0
                          ? summary
                          : '$summary · '
                                '${l10n.trips_cylinders_summaryUnfilled(counts.unknown)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (forecast != null) ...[
                      const SizedBox(height: 4),
                      TripFillForecastText(
                        key: const Key('trip-cylinders-forecast'),
                        forecast: forecast,
                        units: units,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
