import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_format.dart';

/// A compact dive row shown under an itinerary day: number, site, time,
/// runtime, max depth and water temperature.
class ItineraryDiveRow extends StatelessWidget {
  final Dive dive;
  final UnitFormatter units;

  const ItineraryDiveRow({super.key, required this.dive, required this.units});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat.Hm();
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final runtime = dive.runtime ?? dive.bottomTime;
    // Time, then time in the water, depth and water temperature, each only
    // when the dive logged it.
    final values = [
      // The entry time, which is also what files the dive under its day.
      timeFormat.format(dive.effectiveEntryTime),
      if (runtime != null) formatDayRuntime(runtime),
      if (dive.maxDepth != null) units.formatDepth(dive.maxDepth),
      if (dive.waterTemp != null)
        units.formatTemperature(dive.waterTemp, decimals: 0),
    ];

    return InkWell(
      onTap: () => context.push('/dives/${dive.id}'),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '#${dive.diveNumber ?? '-'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            // The site gets the full width; the values sit on a second line,
            // so four of them never squeeze the name away on a phone.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dive.site?.name ?? '-',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    values.join(' · '),
                    style: muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
