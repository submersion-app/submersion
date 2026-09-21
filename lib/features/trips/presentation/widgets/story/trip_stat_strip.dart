import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Horizontal trip-level stat strip.
///
/// Ordinary story content, not chrome: it sits under the band at the top of
/// the story and scrolls away with the hero, so the trip's totals cost screen
/// space only while the diver is at the top of the page.
class TripStatStrip extends ConsumerWidget {
  final TripWithStats stats;

  /// Distinct dive sites visited across the trip (0 hides the tile).
  final int siteCount;

  const TripStatStrip({super.key, required this.stats, this.siteCount = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final entries = <(String, String)>[
      (l10n.trips_detail_stat_totalDives, '${stats.diveCount}'),
      (l10n.trips_detail_stat_totalRuntime, stats.formattedRuntime),
      if (stats.maxDepth != null)
        (l10n.trips_detail_stat_maxDepth, units.formatDepth(stats.maxDepth)),
      if (siteCount > 0) (l10n.trips_detail_stat_sitesVisited, '$siteCount'),
    ];

    return Container(
      // One tonal step above the page surface: welds the strip to the band
      // above it so the two read as a single trip-summary region.
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (final (label, value) in entries)
            Expanded(
              child: Semantics(
                label: '$label: $value',
                child: Column(
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
