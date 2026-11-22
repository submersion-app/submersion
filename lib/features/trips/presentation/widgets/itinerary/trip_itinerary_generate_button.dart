import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_itinerary_sitting.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fills the itinerary from the trip's dates, typed for the trip
/// (ItineraryDay.generateForTrip). With no rows it reads "Generate
/// itinerary"; with some dates missing, "Fill in missing days"; with every
/// date covered it renders nothing. Only the missing dates are made, so a
/// day the diver already planned keeps its row.
class TripItineraryGenerateButton extends StatelessWidget {
  final Trip trip;
  final List<ItineraryDay> days;

  /// Takes the missing days: the trip page holds them in its sitting until
  /// Save (issue #4527).
  final ValueChanged<List<ItineraryDay>> hold;

  const TripItineraryGenerateButton({
    super.key,
    required this.trip,
    required this.days,
    required this.hold,
  });

  Set<DateTime> _covered() => {for (final d in days) tripDay(d.date)};

  /// Whether any trip date has no row: answered from the dates, so a
  /// rebuild does not build the rows themselves.
  bool _anyMissing() {
    final covered = _covered();
    return tripDaysBetween(
      trip.startDate,
      trip.endDate,
    ).any((d) => !covered.contains(d));
  }

  List<ItineraryDay> _missing() => missingItineraryDays(days, trip);

  @override
  Widget build(BuildContext context) {
    if (!_anyMissing()) return const SizedBox.shrink();
    final l10n = context.l10n;
    final label = days.isEmpty
        ? l10n.trips_story_generateItinerary
        : l10n.trips_itinerary_fillMissing;
    return OutlinedButton.icon(
      key: const Key('trip-itinerary-generate'),
      icon: const Icon(Icons.event_note, size: 18),
      label: Text(label),
      onPressed: () => hold(_missing()),
    );
  }
}
