import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_day_header.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The day docked at the start edge of the story band.
///
/// It is the compact form of the chapter heading that just scrolled under the
/// band, so it reuses [TripStoryDayHeader] rather than restating the badge,
/// date, subtitle and weather logic. Tapping it scrolls that chapter back into
/// view, mirroring what tapping one of the map's day pins already does.
class TripStoryDockedDay extends StatelessWidget {
  final TripStoryDay day;
  final TripStoryDayWeather? storedWeather;
  final VoidCallback? onTap;

  const TripStoryDockedDay({
    super.key,
    required this.day,
    this.storedWeather,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: context.l10n.trips_story_dockedDay_goToDay(day.dayNumber),
      // excludeSemantics drops the child's tree, which keeps the label to one
      // clean phrase but also discards the InkWell's tap action. Supplying it
      // here is what lets a screen reader press the button it announces.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: TripStoryDayHeader(
          day: day,
          storedWeather: storedWeather,
          compact: true,
        ),
      ),
    );
  }
}
