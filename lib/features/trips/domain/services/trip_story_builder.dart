import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_dive_days.dart';

/// Number of upcoming checklist items surfaced in the story hero.
const int _nextDueCount = 3;

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Pure. The itinerary rows the trip story shows. A row outside the trip
/// that carries nothing but a plan has no content to keep, so it is not part
/// of the story. updateTrip prunes such rows, but dates that change by sync,
/// import or an older build never run it, and a day planned on one device
/// while another shortened the trip reaches the shortening device only after
/// its prune (#2663).
List<ItineraryDay> tripStoryItinerary(
  Trip trip,
  List<ItineraryDay> itineraryDays,
) => [
  for (final day in itineraryDays)
    if (trip.containsDate(day.date) || !isBarePlanDay(day)) day,
];

/// Pure. The first and last calendar day of the trip story: the trip range,
/// extended to cover any dive or story itinerary day ([tripStoryItinerary])
/// outside it (e.g. trip dates edited after the itinerary was generated) so
/// their content isn't silently dropped from the story. The story numbers its
/// days from `start`, and the itinerary numbers its rows the same way
/// (numberItineraryDays).
({DateTime start, DateTime end}) tripStoryDaySpan({
  required Trip trip,
  required List<Dive> dives,
  required List<ItineraryDay> itineraryDays,
}) {
  var start = _dateOnly(trip.startDate);
  var end = _dateOnly(trip.endDate);
  void includeDate(DateTime date) {
    final d = _dateOnly(date);
    if (d.isBefore(start)) start = d;
    if (d.isAfter(end)) end = d;
  }

  // By effectiveEntryTime, as the story buckets its dives.
  for (final dive in dives) {
    includeDate(dive.effectiveEntryTime);
  }
  for (final day in tripStoryItinerary(trip, itineraryDays)) {
    includeDate(day.date);
  }
  return (start: start, end: end);
}

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

  final storyItinerary = tripStoryItinerary(trip, itineraryDays);
  final (:start, :end) = tripStoryDaySpan(
    trip: trip,
    dives: sortedDives,
    itineraryDays: itineraryDays,
  );
  // Round rather than truncate: a DST spring-forward inside the range makes
  // the hour delta 71, not 72, and integer division would drop a day (mirrors
  // ItineraryDay.generateForTrip).
  final totalDays = (end.difference(start).inHours / 24).round() + 1;

  // Calendar-day offset of a date from the (possibly extended) span start, using
  // the same DST-safe rounding as totalDays. `start` is final here, so this maps
  // a date onto its day-loop index even when the span was extended earlier/later
  // than the nominal trip dates.
  int dayIndexOf(DateTime date) =>
      (_dateOnly(date).difference(start).inHours / 24).round();

  final divesByDate = <DateTime, List<Dive>>{};
  for (final dive in sortedDives) {
    divesByDate
        .putIfAbsent(_dateOnly(dive.effectiveEntryTime), () => [])
        .add(dive);
  }
  final itineraryByDate = <DateTime, ItineraryDay>{
    for (final day in storyItinerary) _dateOnly(day.date): day,
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
        // Anchor to the trip's start day, not day 0: a pre-trip dive can push
        // the span start earlier than trip.startDate.
        dayIndex: dayIndexOf(trip.startDate),
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

    // Map geometry: itinerary location first, then one point per dive.
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
    // One point per dive with a located site, numbered as the day card
    // numbers its rows, so a pin on the day map names one dive.
    for (final (index, dive) in dayDives.indexed) {
      final site = dive.site;
      final location = site?.location;
      if (site == null || location == null) continue;
      mapPoints.add(
        TripStoryMapPoint(
          latitude: location.latitude,
          longitude: location.longitude,
          dayIndex: i,
          siteId: site.id,
          label: site.name,
          diveId: dive.id,
          diveNumber: dive.diveNumber ?? index + 1,
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
        // Anchor to the trip's end day, not the last span day: a late itinerary
        // day can push the span end past trip.endDate.
        dayIndex: dayIndexOf(trip.endDate),
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
