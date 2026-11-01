import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The line under a trip's dates that says where the trip stands: "Day N of
/// M" while it is under way, "N days until departure" while it is ahead, and
/// nothing once it is over. Shared by the story's hero card and the Prepare
/// overview's header so the two never disagree.
String? tripProgressLine(BuildContext context, TripStory story) {
  final trip = story.trip;
  if (trip.isInProgress) {
    return context.l10n.trips_story_dayOfTrip(
      (story.todayIndex ?? 0) + 1,
      story.days.length,
    );
  }
  if (trip.isUpcoming) {
    return context.l10n.trips_story_daysUntil(trip.daysUntilStart);
  }
  return null;
}
