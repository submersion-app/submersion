import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_flight_countdown_card.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_cylinders_summary_card.dart';

/// The cards that matter while a trip is under way: what is left in the
/// cylinders, and how long until the no-fly window before the flight home.
///
/// Two pages of the story show them, today's and the whole trip's, so the
/// no-fly countdown is on the page a trip under way opens on and with the
/// rest of the trip-wide things as well. Each card still hides itself as it
/// always has: the cylinders card outside the trip's dates or with no slots,
/// the countdown once the flight has departed.
class TripUnderWayCards extends StatelessWidget {
  const TripUnderWayCards({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TripCylindersSummaryCard(trip: trip),
        if (trip.returnFlightAt != null && trip.isInProgress)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TripFlightCountdownCard(tripId: trip.id),
          ),
      ],
    );
  }
}
