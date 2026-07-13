import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

/// Number of upcoming checklist items surfaced in the story hero.
const int _nextDueCount = 3;

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Compose the full trip story from already-loaded sources. Pure: no I/O,
/// no clock access ([today] is injected).
TripStory buildTripStory({
  required Trip trip,
  required List<Dive> dives,
  required List<ItineraryDay> itineraryDays,
  required Map<String, List<MediaItem>> mediaByDiveId,
  required Map<String, List<Sighting>> sightingsByDiveId,
  required List<TripChecklistItem> checklistItems,
  required DateTime today,
  LiveaboardDetails? liveaboardDetails,
}) {
  // Order, bucket, and span by effectiveEntryTime (entryTime ?? dateTime) so a
  // dive with a corrected/explicit entry time lands in the same day and order
  // as the rest of the app (DiveSummary.sortTimestamp, DayRhythmBar).
  final sortedDives = List<Dive>.of(dives)
    ..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));

  // Day span: trip range, extended to cover any dive or itinerary day outside
  // it (e.g. trip dates edited after the itinerary was generated) so their
  // content isn't silently dropped from the story.
  var start = _dateOnly(trip.startDate);
  var end = _dateOnly(trip.endDate);
  void includeDate(DateTime date) {
    final d = _dateOnly(date);
    if (d.isBefore(start)) start = d;
    if (d.isAfter(end)) end = d;
  }

  if (sortedDives.isNotEmpty) {
    includeDate(sortedDives.first.effectiveEntryTime);
    includeDate(sortedDives.last.effectiveEntryTime);
  }
  for (final day in itineraryDays) {
    includeDate(day.date);
  }
  // Round rather than truncate: a DST spring-forward inside the range makes
  // the hour delta 71, not 72, and integer division would drop a day (mirrors
  // ItineraryDay.generateForTrip).
  final totalDays = (end.difference(start).inHours / 24).round() + 1;

  final divesByDate = <DateTime, List<Dive>>{};
  for (final dive in sortedDives) {
    divesByDate
        .putIfAbsent(_dateOnly(dive.effectiveEntryTime), () => [])
        .add(dive);
  }
  final itineraryByDate = <DateTime, ItineraryDay>{
    for (final day in itineraryDays) _dateOnly(day.date): day,
  };

  final todayDate = _dateOnly(today);
  final days = <TripStoryDay>[];
  final mapPoints = <TripStoryMapPoint>[];

  // Liveaboard voyage endpoints anchor the route: embark opens the first day.
  // TripVoyageMap used these coordinates directly, so a liveaboard whose ports
  // aren't duplicated onto itinerary days would otherwise lose its endpoint
  // markers and that leg of the route.
  if (liveaboardDetails != null && liveaboardDetails.hasEmbarkCoordinates) {
    mapPoints.add(
      TripStoryMapPoint(
        latitude: liveaboardDetails.embarkLatitude!,
        longitude: liveaboardDetails.embarkLongitude!,
        dayIndex: 0,
        label: liveaboardDetails.embarkPort ?? '',
      ),
    );
  }

  for (var i = 0; i < totalDays; i++) {
    final date = DateTime(start.year, start.month, start.day + i);
    final dayDives = divesByDate[date] ?? const <Dive>[];
    final itineraryDay = itineraryByDate[date];

    final media = <MediaItem>[];
    final sightings = <Sighting>[];
    for (final dive in dayDives) {
      media.addAll(mediaByDiveId[dive.id] ?? const []);
      sightings.addAll(sightingsByDiveId[dive.id] ?? const []);
    }
    media.sort((a, b) => a.takenAt.compareTo(b.takenAt));

    final TripStoryDayKind kind;
    if (date.isBefore(todayDate)) {
      kind = TripStoryDayKind.past;
    } else if (date.isAfter(todayDate)) {
      kind = TripStoryDayKind.future;
    } else {
      kind = TripStoryDayKind.today;
    }

    days.add(
      TripStoryDay(
        date: date,
        dayNumber: i + 1,
        kind: kind,
        itineraryDay: itineraryDay,
        dives: dayDives,
        media: media,
        sightings: sightings,
      ),
    );

    // Map geometry: itinerary port first, then unique dive sites in order.
    if (itineraryDay != null && itineraryDay.hasCoordinates) {
      mapPoints.add(
        TripStoryMapPoint(
          latitude: itineraryDay.latitude!,
          longitude: itineraryDay.longitude!,
          dayIndex: i,
          label: itineraryDay.portName ?? '',
        ),
      );
    }
    final seenSiteIds = <String>{};
    for (final dive in dayDives) {
      final site = dive.site;
      final location = site?.location;
      if (site == null || location == null) continue;
      if (!seenSiteIds.add(site.id)) continue;
      mapPoints.add(
        TripStoryMapPoint(
          latitude: location.latitude,
          longitude: location.longitude,
          dayIndex: i,
          siteId: site.id,
          label: site.name,
        ),
      );
    }
  }

  // ...and disembark closes the last day, so the route ends at the port.
  if (liveaboardDetails != null && liveaboardDetails.hasDisembarkCoordinates) {
    mapPoints.add(
      TripStoryMapPoint(
        latitude: liveaboardDetails.disembarkLatitude!,
        longitude: liveaboardDetails.disembarkLongitude!,
        dayIndex: totalDays - 1,
        label: liveaboardDetails.disembarkPort ?? '',
      ),
    );
  }

  final done = checklistItems.where((i) => i.isDone).length;
  final nextDue =
      checklistItems.where((i) => !i.isDone && i.dueDate != null).toList()
        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

  return TripStory(
    trip: trip,
    days: days,
    checklist: TripStoryChecklistSummary(
      done: done,
      total: checklistItems.length,
      nextDue: nextDue.take(_nextDueCount).toList(),
    ),
    mapGeometry: TripStoryMapGeometry(points: mapPoints),
  );
}
