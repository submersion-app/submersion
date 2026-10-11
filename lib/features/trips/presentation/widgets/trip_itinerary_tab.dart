import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/itinerary_day_card.dart';
import 'package:submersion/features/trips/presentation/widgets/itinerary/trip_itinerary_generate_button.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Itinerary tab showing the day-by-day timeline of a trip, any type
/// (#2845): Generate fills the dates, each day opens its edit sheet.
///
/// Groups dives by date under each itinerary day. Each day row is tappable
/// to edit day type, port name, and notes via a bottom sheet.
class TripItineraryTab extends ConsumerWidget {
  final String tripId;

  const TripItineraryTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(numberedItineraryDaysProvider(tripId));
    final divesAsync = ref.watch(divesForTripProvider(tripId));
    // The trip types the days Generate writes and labels the sheet's place
    // field; a trip that is gone shows the list without the button.
    final trip = ref.watch(tripByIdProvider(tripId)).value;

    // Keep the list on a reload: the numbered itinerary rebuilds whenever
    // the itinerary, the trip or its dives change (an edit-sheet save among
    // them), and `when` shows its loading branch on a reload by default,
    // which would swap the list for a spinner and lose the scroll position.
    return daysAsync.when(
      skipLoadingOnReload: true,
      data: (days) => divesAsync.when(
        data: (dives) => _buildTimeline(context, ref, days, dives, trip),
        loading: () => const Center(child: CircularProgressIndicator()),
        // The repositories log the failure; the diver gets a plain line.
        error: (_, _) =>
            Center(child: Text(context.l10n.trips_itinerary_error_loading)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          Center(child: Text(context.l10n.trips_itinerary_error_loading)),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    WidgetRef ref,
    List<ItineraryDay> days,
    List<Dive> dives,
    Trip? trip,
  ) {
    if (days.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.trips_itinerary_empty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (trip != null) ...[
                const SizedBox(height: 16),
                TripItineraryGenerateButton(trip: trip, days: days),
              ],
            ],
          ),
        ),
      );
    }

    // Group dives by date (year-month-day key)
    final divesByDate = <String, List<Dive>>{};
    for (final dive in dives) {
      final key = _dateKey(dive.dateTime);
      divesByDate.putIfAbsent(key, () => []).add(dive);
    }

    // Sort each group by time (creating sorted copies to avoid mutation)
    final sortedDivesByDate = divesByDate.map(
      (key, group) => MapEntry(
        key,
        List<Dive>.of(group)..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
      ),
    );

    // The fill-in button renders nothing once every date has a row.
    final header = trip == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TripItineraryGenerateButton(trip: trip, days: days),
            ),
          );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length + (header == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (header != null) {
          if (index == 0) return header;
          index -= 1;
        }
        final day = days[index];
        final dayDives = sortedDivesByDate[_dateKey(day.date)] ?? [];
        return ItineraryDayCard(
          day: day,
          dives: dayDives,
          tripId: tripId,
          isLiveaboard: trip?.isLiveaboard ?? false,
        );
      },
    );
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}
