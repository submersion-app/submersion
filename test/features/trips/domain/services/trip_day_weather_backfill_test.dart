import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_day_weather.dart';
import 'package:submersion/features/trips/domain/entities/trip_story.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/trip_day_weather_backfill.dart';

void main() {
  Trip trip() => Trip(
    id: 'trip-1',
    name: 'Bonaire',
    startDate: DateTime(2026, 3, 8),
    endDate: DateTime(2026, 3, 14),
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );

  TripStory storyWith(
    List<TripStoryDay> days, {
    List<TripStoryMapPoint> points = const [],
  }) {
    return TripStory(
      trip: trip(),
      days: days,
      checklist: const TripStoryChecklistSummary(done: 0, total: 0),
      mapGeometry: TripStoryMapGeometry(points: points),
    );
  }

  Dive diveWith({
    double? airTemp,
    CloudCover? cloudCover,
    Precipitation? precipitation,
  }) => Dive(
    id: 'd1',
    dateTime: DateTime(2026, 3, 8, 9),
    airTemp: airTemp,
    cloudCover: cloudCover,
    precipitation: precipitation,
  );

  TripStoryDay day({
    required int index,
    TripStoryDayKind kind = TripStoryDayKind.past,
    List<Dive> dives = const [],
  }) {
    return TripStoryDay(
      date: DateTime(2026, 3, 8 + index),
      dayNumber: index + 1,
      kind: kind,
      dives: dives,
    );
  }

  TripStoryMapPoint pointFor(int dayIndex) => TripStoryMapPoint(
    latitude: 12.16,
    longitude: -68.28,
    dayIndex: dayIndex,
    label: 'Site',
  );

  TripDayWeather storedFor(DateTime date) => TripDayWeather(
    id: 'w1',
    tripId: 'trip-1',
    date: date,
    latitude: 12.16,
    longitude: -68.28,
    airTemp: 21,
    fetchedAt: DateTime(2026, 3, 9),
    createdAt: DateTime(2026, 3, 9),
    updatedAt: DateTime(2026, 3, 9),
  );

  group('TripDayWeatherBackfill.targetsFor', () {
    test('a past day with no dives and a nearby point is a target', () {
      final story = storyWith([day(index: 0)], points: [pointFor(0)]);

      final targets = TripDayWeatherBackfill.targetsFor(
        story: story,
        stored: const {},
      );

      expect(targets, hasLength(1));
      expect(targets.single.date, DateTime(2026, 3, 8));
      expect(targets.single.latitude, 12.16);
      expect(targets.single.longitude, -68.28);
      // Noon local reads as "the day's weather" far better than the API's
      // default midnight boundary.
      expect(targets.single.localNoon, DateTime(2026, 3, 8, 12));
    });

    test('a day whose dives carry weather is skipped', () {
      final story = storyWith(
        [
          day(index: 0, dives: [diveWith(airTemp: 26)]),
        ],
        points: [pointFor(0)],
      );

      expect(
        TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
        isEmpty,
      );
    });

    test('a dive-free itinerary day is a target, not just a surface day', () {
      // The day has dives with no weather at all, so nothing supplies it.
      final story = storyWith(
        [
          day(index: 0, dives: [diveWith()]),
        ],
        points: [pointFor(0)],
      );

      expect(
        TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
        hasLength(1),
      );
    });

    test('a future day is skipped', () {
      final story = storyWith(
        [day(index: 0, kind: TripStoryDayKind.future)],
        points: [pointFor(0)],
      );

      expect(
        TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
        isEmpty,
      );
    });

    test('today is not skipped', () {
      final story = storyWith(
        [day(index: 0, kind: TripStoryDayKind.today)],
        points: [pointFor(0)],
      );

      expect(
        TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
        hasLength(1),
      );
    });

    test('a day with a stored row is skipped', () {
      // Keyed the way the repository keys it. getForTrip returns a map keyed
      // by tripDayMillis, so keying this fixture any other way would assert a
      // contract production never offers: it would pass here and still refetch
      // every day on a real device.
      final story = storyWith([day(index: 0)], points: [pointFor(0)]);
      final stored = {
        tripDayMillis(DateTime(2026, 3, 8)): storedFor(DateTime(2026, 3, 8)),
      };

      expect(
        TripDayWeatherBackfill.targetsFor(story: story, stored: stored),
        isEmpty,
      );
    });

    test('the stored lookup is not the device local midnight', () {
      // The day key is UTC midnight so two devices converge on one row. A
      // lookup built from a local DateTime's epoch agrees with it only at
      // UTC+0, so on any other device every stored day reads as missing and
      // is refetched on every view, which is the whole thing this feature
      // exists to stop. Discriminating only off UTC; run with
      // TZ=America/New_York to see it bite.
      final story = storyWith([day(index: 0)], points: [pointFor(0)]);
      final localKey = DateTime(2026, 3, 8).millisecondsSinceEpoch;
      final utcKey = tripDayMillis(DateTime(2026, 3, 8));

      final stored = {utcKey: storedFor(DateTime(2026, 3, 8))};

      expect(
        TripDayWeatherBackfill.targetsFor(story: story, stored: stored),
        isEmpty,
        reason:
            'a row stored under the repository key must skip the day '
            '(local key $localKey vs day key $utcKey)',
      );
    });

    test('a day with no map point anywhere in the story is skipped', () {
      final story = storyWith([day(index: 0)]);

      expect(
        TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
        isEmpty,
      );
    });

    test('a day borrows the nearest day point when it has none of its own', () {
      // nearestPointForDay walks outward, so day 1 with a point only on day 0
      // is still a target, at day 0's coordinates.
      final story = storyWith(
        [
          day(index: 0, dives: [diveWith(airTemp: 26)]),
          day(index: 1),
        ],
        points: [pointFor(0)],
      );

      final targets = TripDayWeatherBackfill.targetsFor(
        story: story,
        stored: const {},
      );

      expect(targets, hasLength(1));
      expect(targets.single.date, DateTime(2026, 3, 9));
      expect(targets.single.latitude, 12.16);
    });

    test('targets come back in day order', () {
      final story = storyWith(
        [day(index: 0), day(index: 1), day(index: 2)],
        points: [pointFor(1)],
      );

      final targets = TripDayWeatherBackfill.targetsFor(
        story: story,
        stored: const {},
      );

      expect(targets.map((t) => t.date).toList(), [
        DateTime(2026, 3, 8),
        DateTime(2026, 3, 9),
        DateTime(2026, 3, 10),
      ]);
    });

    test(
      'a dive carrying only Precipitation.none does NOT count as weather',
      () {
        // WeatherMapper never returns null precipitation, so a dive whose
        // lookup resolved nothing still stores `none`. The header draws no
        // glyph for it, so treating it as "this day has weather" would skip the
        // backfill and leave the day permanently badge-free.
        final story = storyWith(
          [
            day(index: 0, dives: [diveWith(precipitation: Precipitation.none)]),
          ],
          points: [pointFor(0)],
        );

        expect(
          TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
          hasLength(1),
        );
      },
    );

    test('a dive carrying active precipitation DOES count as weather', () {
      final story = storyWith(
        [
          day(index: 0, dives: [diveWith(precipitation: Precipitation.rain)]),
        ],
        points: [pointFor(0)],
      );

      expect(
        TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
        isEmpty,
      );
    });

    test('a dive carrying only cloud cover counts as weather', () {
      final story = storyWith(
        [
          day(index: 0, dives: [diveWith(cloudCover: CloudCover.overcast)]),
        ],
        points: [pointFor(0)],
      );

      expect(
        TripDayWeatherBackfill.targetsFor(story: story, stored: const {}),
        isEmpty,
      );
    });

    test('a day date with a time component is normalized to midnight', () {
      // The story day's date should already be date-only, but a stored row is
      // keyed on midnight millis, so a stray time would never match and the
      // day would refetch forever.
      final story = storyWith(
        [
          TripStoryDay(
            date: DateTime(2026, 3, 8, 17, 30),
            dayNumber: 1,
            kind: TripStoryDayKind.past,
          ),
        ],
        points: [pointFor(0)],
      );

      final targets = TripDayWeatherBackfill.targetsFor(
        story: story,
        stored: const {},
      );

      expect(targets.single.date, DateTime(2026, 3, 8));
    });
  });
}
