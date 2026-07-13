import 'package:equatable/equatable.dart';

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

  Duration get totalBottomTime => dives.fold(
    Duration.zero,
    (sum, dive) => sum + (dive.bottomTime ?? Duration.zero),
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

  bool get hasContent =>
      dives.isNotEmpty || media.isNotEmpty || itineraryDay != null;

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

/// A mappable point contributed by a story day (dive site or itinerary port).
class TripStoryMapPoint extends Equatable {
  final double latitude;
  final double longitude;
  final int dayIndex;
  final String? siteId;
  final String label;

  const TripStoryMapPoint({
    required this.latitude,
    required this.longitude,
    required this.dayIndex,
    required this.label,
    this.siteId,
  });

  @override
  List<Object?> get props => [latitude, longitude, dayIndex, siteId, label];
}

/// Precomputed map geometry for the whole story, in day order. The point
/// sequence doubles as the route polyline.
class TripStoryMapGeometry extends Equatable {
  final List<TripStoryMapPoint> points;

  const TripStoryMapGeometry({required this.points});

  bool get hasPoints => points.isNotEmpty;

  List<TripStoryMapPoint> pointsForDay(int dayIndex) =>
      points.where((p) => p.dayIndex == dayIndex).toList();

  @override
  List<Object?> get props => [points];
}
