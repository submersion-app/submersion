import 'package:flutter/widgets.dart';

import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';
import 'package:submersion/features/trips/presentation/helpers/day_type_l10n.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The words that say what kind of day [day] was and where: "Surface day" or
/// the shown day type, then the port, then the names of the sites dived.
///
/// Each part is trimmed and blanks are dropped before a caller joins them:
/// the itinerary edit sheet normalizes an empty port to null, but sync and
/// import payloads write the nullable column directly, and a site name is
/// equally free to be blank. Joining either verbatim would render a doubled
/// separator.
///
/// A surface day has no itinerary and no dives by definition, so it owns the
/// first slot outright, where an itinerary day leads with its day type
/// ("Dive Day", "Travel Day"). A dive day planned at 0 dives reads the same
/// way: its stored type contradicts the plan. A rest day with a dive logged
/// reads as a dive day (#2875).
List<String> tripDaySubtitleParts(BuildContext context, TripStoryDay day) {
  final itinerary = day.itineraryDay;
  final surfaceLabel = day.isSurface || day.isPlannedRest;
  return <String>[
    if (surfaceLabel) context.l10n.trips_story_surfaceDay,
    if (itinerary != null && !surfaceLabel)
      shownDayType(
        itinerary,
        hasDives: day.dives.isNotEmpty,
      ).localizedName(context),
    if (itinerary?.portName != null) itinerary!.portName!,
    ...day.siteNames,
  ].map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
}
