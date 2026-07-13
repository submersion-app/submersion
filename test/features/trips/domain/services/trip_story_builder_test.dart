import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_story_builder.dart';

Trip _trip({DateTime? start, DateTime? end}) {
  return Trip(
    id: 'trip-1',
    name: 'Bonaire',
    startDate: start ?? DateTime(2026, 3, 7),
    endDate: end ?? DateTime(2026, 3, 10),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

Dive _dive(
  String id,
  DateTime dateTime, {
  DiveSite? site,
  DateTime? entryTime,
}) {
  return Dive(id: id, dateTime: dateTime, entryTime: entryTime, site: site);
}

ItineraryDay _itin(int dayNumber, DateTime date, {String? port}) {
  return ItineraryDay(
    id: 'itin-$dayNumber',
    tripId: 'trip-1',
    dayNumber: dayNumber,
    date: date,
    dayType: DayType.diveDay,
    portName: port,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

TripChecklistItem _check(String id, {bool done = false, DateTime? due}) {
  return TripChecklistItem(
    id: id,
    tripId: 'trip-1',
    title: id,
    isDone: done,
    dueDate: due,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('buildTripStory day span', () {
    test('emits one day per calendar day of the trip range', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      expect(story.days.length, 4); // Mar 7,8,9,10
      expect(story.days.first.dayNumber, 1);
      expect(story.days.last.date, DateTime(2026, 3, 10));
    });

    test('extends span to cover dives outside nominal trip dates', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [_dive('d1', DateTime(2026, 3, 12, 10))],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      expect(story.days.length, 6); // Mar 7..12
      expect(story.days.last.dives, hasLength(1));
    });

    test('extends span to cover itinerary days outside nominal trip dates', () {
      // Itinerary day on Mar 12, after the trip's nominal end (Mar 10).
      final story = buildTripStory(
        trip: _trip(),
        dives: [],
        itineraryDays: [_itin(6, DateTime(2026, 3, 12), port: 'Sorong')],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      expect(story.days.length, 6); // Mar 7..12
      expect(story.days.last.date, DateTime(2026, 3, 12));
      expect(story.days.last.itineraryDay?.portName, 'Sorong');
    });
  });

  group('buildTripStory grouping', () {
    test('groups dives by calendar day, time-sorted within a day', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [
          _dive('late', DateTime(2026, 3, 8, 19)),
          _dive('early', DateTime(2026, 3, 8, 9)),
          _dive('other-day', DateTime(2026, 3, 9, 9)),
        ],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      final day2 = story.days[1]; // Mar 8
      expect(day2.dives.map((d) => d.id), ['early', 'late']);
      expect(story.days[2].dives.map((d) => d.id), ['other-day']);
    });

    test('attaches itinerary metadata, media, and sightings to the day', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [_dive('d1', DateTime(2026, 3, 8, 9))],
        itineraryDays: [_itin(2, DateTime(2026, 3, 8), port: 'Kralendijk')],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      expect(story.days[1].itineraryDay?.portName, 'Kralendijk');
    });

    test('buckets by effectiveEntryTime, not the legacy dateTime', () {
      // Legacy dateTime says Mar 7, but the corrected entryTime is Mar 8.
      final story = buildTripStory(
        trip: _trip(),
        dives: [
          _dive(
            'corrected',
            DateTime(2026, 3, 7, 23),
            entryTime: DateTime(2026, 3, 8, 0, 30),
          ),
        ],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      // Day index 1 == Mar 8 (trip starts Mar 7), where entryTime places it.
      expect(story.days[0].dives, isEmpty);
      expect(story.days[1].dives.single.id, 'corrected');
    });
  });

  group('buildTripStory kind derivation', () {
    test('past, today, and future kinds split on the injected today', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 3, 8, 15, 30), // mid-trip, time ignored
      );
      expect(story.days[0].kind, TripStoryDayKind.past);
      expect(story.days[1].kind, TripStoryDayKind.today);
      expect(story.days[2].kind, TripStoryDayKind.future);
      expect(story.todayIndex, 1);
    });

    test('fully future trip has null todayIndex and isEmpty when bare', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 1, 1),
      );
      expect(story.todayIndex, isNull);
      expect(story.isEmpty, isTrue);
      expect(story.days.every((d) => d.kind == TripStoryDayKind.future), true);
    });
  });

  group('buildTripStory checklist summary', () {
    test('computes done/total and next due (undone, dated, soonest first)', () {
      final story = buildTripStory(
        trip: _trip(),
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [
          _check('a', done: true),
          _check('b', due: DateTime(2026, 3, 1)),
          _check('c', due: DateTime(2026, 2, 1)),
          _check('d'),
        ],
        today: DateTime(2026, 1, 1),
      );
      expect(story.checklist.done, 1);
      expect(story.checklist.total, 4);
      expect(story.checklist.nextDue.map((i) => i.id), ['c', 'b']);
    });
  });

  group('buildTripStory map geometry', () {
    test('collects unique day site points and itinerary ports in order', () {
      const site = DiveSite(
        id: 'site-a',
        name: 'Blue Corner',
        location: GeoPoint(12.1, -68.2),
      );
      final story = buildTripStory(
        trip: _trip(),
        dives: [
          _dive('d1', DateTime(2026, 3, 8, 9), site: site),
          _dive('d2', DateTime(2026, 3, 8, 11), site: site), // same site
        ],
        itineraryDays: [
          ItineraryDay(
            id: 'itin-1',
            tripId: 'trip-1',
            dayNumber: 1,
            date: DateTime(2026, 3, 7),
            dayType: DayType.embark,
            portName: 'Kralendijk',
            latitude: 12.15,
            longitude: -68.27,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
        ],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
      );
      expect(story.mapGeometry.points, hasLength(2));
      expect(story.mapGeometry.points[0].label, 'Kralendijk');
      expect(story.mapGeometry.points[0].dayIndex, 0);
      expect(story.mapGeometry.points[1].siteId, 'site-a');
      expect(story.mapGeometry.points[1].dayIndex, 1);
    });

    test('includes liveaboard embark/disembark ports as route endpoints', () {
      // A liveaboard whose ports aren't duplicated onto itinerary days should
      // still contribute its embark (first day) and disembark (last day)
      // markers, the way the retired TripVoyageMap did.
      final story = buildTripStory(
        trip: _trip(), // Mar 7 - Mar 10, four days
        dives: [],
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
        liveaboardDetails: LiveaboardDetails(
          id: 'la-1',
          tripId: 'trip-1',
          vesselName: 'MV Explorer',
          embarkPort: 'Kralendijk',
          embarkLatitude: 12.15,
          embarkLongitude: -68.27,
          disembarkPort: 'Rincon',
          disembarkLatitude: 12.32,
          disembarkLongitude: -68.31,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      final points = story.mapGeometry.points;
      expect(points, hasLength(2));
      expect(points.first.label, 'Kralendijk');
      expect(points.first.dayIndex, 0); // embark opens the first day
      expect(points.last.label, 'Rincon');
      expect(points.last.dayIndex, 3); // disembark closes the last day
    });

    test('anchors liveaboard ports to trip start/end when the span extends', () {
      // A pre-trip dive pushes the span start (Mar 5) earlier than
      // trip.startDate (Mar 7). The embark/disembark pins must still land on the
      // trip's start/end days, not on day 0 / the last span day.
      final story = buildTripStory(
        trip: _trip(), // Mar 7 - Mar 10
        dives: [
          _dive('early', DateTime(2026, 3, 5, 9)),
        ], // no site, extends span
        itineraryDays: [],
        mediaByDiveId: {},
        sightingsByDiveId: {},
        checklistItems: [],
        today: DateTime(2026, 6, 1),
        liveaboardDetails: LiveaboardDetails(
          id: 'la-1',
          tripId: 'trip-1',
          vesselName: 'MV Explorer',
          embarkPort: 'Kralendijk',
          embarkLatitude: 12.15,
          embarkLongitude: -68.27,
          disembarkPort: 'Rincon',
          disembarkLatitude: 12.32,
          disembarkLongitude: -68.31,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
      // Span is Mar 5..Mar 10 (six days): embark (Mar 7) -> index 2,
      // disembark (Mar 10) -> index 5.
      final embark = story.mapGeometry.points.firstWhere(
        (p) => p.label == 'Kralendijk',
      );
      final disembark = story.mapGeometry.points.firstWhere(
        (p) => p.label == 'Rincon',
      );
      expect(embark.dayIndex, 2);
      expect(disembark.dayIndex, 5);
    });
  });
}
