import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';

/// Temporal position of a story day relative to "today" (date-only).
enum TripStoryDayKind { past, today, future }

/// One calendar day of a trip story: real dives when they exist, itinerary
/// metadata when it exists, or neither (a surface day).
class TripStoryDay extends Equatable {
  final DateTime date;
  final int dayNumber;
  final ItineraryDay? itineraryDay;
  final List<Dive> dives;
  final List<MediaItem> media;
  final List<Sighting> sightings;
  final TripStoryDayKind kind;

  const TripStoryDay({
    required this.date,
    required this.dayNumber,
    required this.kind,
    this.itineraryDay,
    this.dives = const [],
    this.media = const [],
    this.sightings = const [],
  });

  int get diveCount => dives.length;

  /// Total time in the water for the day.
  ///
  /// Runtime (surface to surface) is what divers add up when they talk about
  /// how long they were in the water, and it is what the rest of the app sums
  /// (`COALESCE(runtime, bottom_time)` in the statistics and dive-log
  /// queries). Bottom time stays as the fallback so hand-logged dives that
  /// only carry one still contribute.
  Duration get totalRuntime => dives.fold(
    Duration.zero,
    (sum, dive) => sum + (dive.runtime ?? dive.bottomTime ?? Duration.zero),
  );

  double? get maxDepth {
    double? max;
    for (final dive in dives) {
      final depth = dive.maxDepth;
      if (depth != null && (max == null || depth > max)) max = depth;
    }
    return max;
  }

  /// Unique site names in dive order (deduped by display name, for subtitles).
  List<String> get siteNames {
    final seen = <String>{};
    final names = <String>[];
    for (final dive in dives) {
      final name = dive.site?.name;
      if (name != null && seen.add(name)) names.add(name);
    }
    return names;
  }

  /// Distinct dive sites deduped by stable id (not display name), so two
  /// different sites that share a name still count as two -- matching the map
  /// geometry and the trip-level stat strip, which key on site id.
  int get siteCount {
    final ids = <String>{};
    for (final dive in dives) {
      final id = dive.site?.id;
      if (id != null) ids.add(id);
    }
    return ids.length;
  }

  /// Day-level weather summary, or null when no dive logged any weather.
  ///
  /// Each field is the first non-null value across the day's dives in dive
  /// order, so a morning dive that logged only air temperature and an
  /// afternoon dive that logged only sky conditions still combine into one
  /// complete summary.
  TripStoryDayWeather? get weather {
    double? airTemp;
    CloudCover? cloudCover;
    Precipitation? precipitation;
    for (final dive in dives) {
      airTemp ??= dive.airTemp;
      cloudCover ??= dive.cloudCover;
      precipitation ??= dive.precipitation;
    }
    if (airTemp == null && cloudCover == null && precipitation == null) {
      return null;
    }
    return TripStoryDayWeather(
      airTemp: airTemp,
      cloudCover: cloudCover,
      precipitation: precipitation,
    );
  }

  bool get hasContent =>
      dives.isNotEmpty || media.isNotEmpty || itineraryDay != null;

  /// A day with nothing to show: no dives, media, or itinerary entry, and not
  /// a planned (future) day. Still gets the standard sticky day header, labeled
  /// "Surface day" in place of a day type; only its card body is empty.
  bool get isSurface => !hasContent && kind != TripStoryDayKind.future;

  /// A dive-day itinerary row planned at 0 dives, with none logged: a rest
  /// day the diver planned, most often on the board's day strip, which writes
  /// a dive-day row for a day the itinerary lacks (#2658). Its stored type
  /// says "Dive Day" but the plan says otherwise, so the story labels it a
  /// surface day. Other day types keep their own label, and a dive logged
  /// anyway makes it a dive day after all.
  bool get isPlannedRest {
    final row = itineraryDay;
    return row != null &&
        row.dayType == DayType.diveDay &&
        row.plannedDives == 0 &&
        dives.isEmpty;
  }

  @override
  List<Object?> get props => [
    date,
    dayNumber,
    itineraryDay,
    dives,
    media,
    sightings,
    kind,
  ];
}

/// Compact weather summary for one story day, shown in the day header.
class TripStoryDayWeather extends Equatable {
  final double? airTemp; // celsius
  final CloudCover? cloudCover;
  final Precipitation? precipitation;

  const TripStoryDayWeather({
    this.airTemp,
    this.cloudCover,
    this.precipitation,
  });

  /// True when the day header's badge would actually draw something.
  ///
  /// [Precipitation.none] does not count, and that is the whole point of this
  /// getter. `WeatherMapper.mapPrecipitation` never returns null: a missing
  /// reading becomes `none`, so a dive whose weather lookup resolved nothing
  /// still stores `none`. `weatherIconFor` gives `none` no glyph of its own,
  /// so such a day renders as blank. Treating it as "this day has weather"
  /// would leave the day badge-free forever.
  bool get isRenderable =>
      airTemp != null ||
      cloudCover != null ||
      (precipitation != null && precipitation != Precipitation.none);

  @override
  List<Object?> get props => [airTemp, cloudCover, precipitation];
}

/// A mappable point contributed by a story day: an itinerary location, or
/// one dive at a site (one point per dive, so a pin can name a dive).
class TripStoryMapPoint extends Equatable {
  final double latitude;
  final double longitude;
  final int dayIndex;
  final String? siteId;
  final String label;

  /// The dive this point stands for; null for an itinerary location.
  final String? diveId;

  /// The number the day card shows for that dive (its logged number, else
  /// its position in the day), so the pin and the row read the same.
  final int? diveNumber;

  const TripStoryMapPoint({
    required this.latitude,
    required this.longitude,
    required this.dayIndex,
    required this.label,
    this.siteId,
    this.diveId,
    this.diveNumber,
  });

  bool get isDive => diveId != null;

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    dayIndex,
    siteId,
    label,
    diveId,
    diveNumber,
  ];
}

/// Precomputed map geometry for the whole story, in day order. The point
/// sequence doubles as the route polyline.
class TripStoryMapGeometry extends Equatable {
  final List<TripStoryMapPoint> points;

  const TripStoryMapGeometry({required this.points});

  bool get hasPoints => points.isNotEmpty;

  List<TripStoryMapPoint> pointsForDay(int dayIndex) =>
      points.where((p) => p.dayIndex == dayIndex).toList();

  /// The map point closest to [dayIndex], preserving route order when two
  /// points are equally distant.
  TripStoryMapPoint? nearestPointForDay(int dayIndex) {
    TripStoryMapPoint? nearest;
    int? nearestDistance;
    for (final point in points) {
      final distance = (point.dayIndex - dayIndex).abs();
      if (nearestDistance == null || distance < nearestDistance) {
        nearest = point;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  @override
  List<Object?> get props => [points];
}
