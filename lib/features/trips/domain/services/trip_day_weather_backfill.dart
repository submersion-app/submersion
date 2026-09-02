import 'package:equatable/equatable.dart';

import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// One trip day that needs a weather lookup, with the coordinates to look it
/// up at.
class TripDayWeatherTarget extends Equatable {
  /// The day to look up, at local midnight.
  ///
  /// Local is right here and irrelevant to identity: [localNoon] reads the
  /// calendar fields to ask the archive for that day's noon at the dive site,
  /// and the storage key is derived separately by `tripDayMillis`, which
  /// takes the same calendar fields and pins them to UTC. Nothing keys a
  /// stored row off this instant.
  final DateTime date;
  final double latitude;
  final double longitude;

  const TripDayWeatherTarget({
    required this.date,
    required this.latitude,
    required this.longitude,
  });

  /// The hour to sample. Noon local reads as "the day's weather" far better
  /// than the archive's default midnight boundary, which straddles two days.
  DateTime get localNoon => DateTime(date.year, date.month, date.day, 12);

  @override
  List<Object?> get props => [date, latitude, longitude];
}

/// Decides which trip days need a weather lookup.
///
/// Pure by design: no database, no network, no clock. Every skip rule is a
/// plain condition over the built story and the rows already stored, which is
/// what makes each one directly testable.
class TripDayWeatherBackfill {
  const TripDayWeatherBackfill._();

  static List<TripDayWeatherTarget> targetsFor({
    required TripStory story,
    required Map<int, TripDayWeather> stored,
  }) {
    final targets = <TripDayWeatherTarget>[];

    for (var index = 0; index < story.days.length; index++) {
      final day = story.days[index];

      // A dive that logged weather is the better source: it is what the diver
      // recorded. Never override it with a fetched summary.
      //
      // Renderability, not mere presence, is the test. A dive whose weather
      // lookup resolved nothing still stores Precipitation.none, because
      // WeatherMapper never returns null precipitation, and that renders as a
      // blank badge. Skipping on presence alone would leave such a day
      // permanently badge-free.
      if (day.weather?.isRenderable ?? false) continue;

      // A historical archive has nothing for a day that has not happened.
      if (day.kind == TripStoryDayKind.future) continue;

      // Ask with the key the rows are actually stored under. getForTrip keys
      // by tripDayMillis, which is UTC midnight so two devices converge on one
      // row; a local DateTime's epoch agrees with that only at UTC+0. Building
      // the lookup from the local value instead made every stored day read as
      // missing on any other device and refetch on every view, which is the
      // thing this whole feature exists to stop.
      final date = DateTime(day.date.year, day.date.month, day.date.day);
      if (stored.containsKey(tripDayMillis(date))) continue;

      // nearestPointForDay walks outward from the day, so a dive-free day
      // between two dived days borrows the closer one's coordinates. A trip
      // with no mappable point anywhere has nowhere to ask.
      final point = story.mapGeometry.nearestPointForDay(index);
      if (point == null) continue;

      targets.add(
        TripDayWeatherTarget(
          date: date,
          latitude: point.latitude,
          longitude: point.longitude,
        ),
      );
    }

    return targets;
  }
}
