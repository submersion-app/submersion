import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/icons/mdi_icons.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_overview_tab.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Extended statistics card for liveaboard trips.
///
/// Displays additional metrics beyond the standard stats:
/// - Dives per day
/// - Dive days (unique dates with dives)
/// - Sea days (total trip duration)
/// - Sites visited (unique dive sites)
/// - Species seen (placeholder for future)
class TripEnhancedStats extends ConsumerWidget {
  final TripWithStats tripWithStats;

  const TripEnhancedStats({super.key, required this.tripWithStats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divesAsync = ref.watch(divesForTripProvider(tripWithStats.trip.id));
    final sitesAsync = ref.watch(
      tripSitesWithLocationsProvider(tripWithStats.trip.id),
    );

    return divesAsync.when(
      data: (dives) {
        final trip = tripWithStats.trip;
        final seaDays = trip.durationDays;
        final diveDays = _countDiveDays(dives);
        final divesPerDay = seaDays > 0
            ? (tripWithStats.diveCount / seaDays).toStringAsFixed(1)
            : '0.0';
        final sitesVisited = sitesAsync.when(
          data: (sites) => sites.length,
          loading: () => 0,
          error: (_, _) => 0,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.trips_detail_sectionTitle_dailyBreakdown,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                StatRow(
                  icon: Icons.calendar_today,
                  label: context.l10n.trips_detail_stat_seaDays,
                  value: seaDays.toString(),
                ),
                StatRow(
                  icon: Icons.scuba_diving,
                  label: context.l10n.trips_detail_stat_diveDays,
                  value: diveDays.toString(),
                ),
                StatRow(
                  icon: Icons.speed,
                  label: context.l10n.trips_detail_stat_divesPerDay,
                  value: divesPerDay,
                ),
                StatRow(
                  icon: Icons.place,
                  label: context.l10n.trips_detail_stat_sitesVisited,
                  value: sitesVisited.toString(),
                ),
                StatRow(
                  icon: MdiIcons.fish,
                  label: context.l10n.trips_detail_stat_speciesSeen,
                  value: _countSpecies(dives).toString(),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// Count the number of unique dates that have at least one dive.
  int _countDiveDays(List<Dive> dives) {
    final uniqueDates = <String>{};
    for (final dive in dives) {
      final dt = dive.dateTime;
      uniqueDates.add('${dt.year}-${dt.month}-${dt.day}');
    }
    return uniqueDates.length;
  }

  /// Count the number of unique species seen across all dives.
  int _countSpecies(List<Dive> dives) {
    final uniqueSpecies = <String>{};
    for (final dive in dives) {
      for (final sighting in dive.sightings) {
        uniqueSpecies.add(sighting.speciesId);
      }
    }
    return uniqueSpecies.length;
  }
}
