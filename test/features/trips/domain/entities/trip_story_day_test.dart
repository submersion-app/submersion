import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

Dive _dive({
  required String id,
  required DateTime dateTime,
  Duration? bottomTime,
  Duration? runtime,
  double? maxDepth,
  DiveSite? site,
  double? airTemp,
  CloudCover? cloudCover,
  Precipitation? precipitation,
}) {
  return Dive(
    id: id,
    dateTime: dateTime,
    bottomTime: bottomTime,
    runtime: runtime,
    maxDepth: maxDepth,
    site: site,
    airTemp: airTemp,
    cloudCover: cloudCover,
    precipitation: precipitation,
  );
}

void main() {
  final date = DateTime(2026, 3, 8);
  const siteA = DiveSite(id: 'site-a', name: 'Blue Corner');
  const siteB = DiveSite(id: 'site-b', name: 'Jetty');

  group('TripStoryDay derived getters', () {
    test('aggregates dive count, runtime, and max depth', () {
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(
            id: 'd1',
            dateTime: DateTime(2026, 3, 8, 9),
            bottomTime: const Duration(minutes: 40),
            runtime: const Duration(minutes: 47),
            maxDepth: 28,
            site: siteA,
          ),
          _dive(
            id: 'd2',
            dateTime: DateTime(2026, 3, 8, 11),
            bottomTime: const Duration(minutes: 44),
            runtime: const Duration(minutes: 51),
            maxDepth: 24,
            site: siteA,
          ),
          _dive(id: 'd3', dateTime: DateTime(2026, 3, 8, 19), site: siteB),
        ],
      );

      expect(day.diveCount, 3);
      expect(day.totalRuntime, const Duration(minutes: 98));
      expect(day.maxDepth, 28);
      expect(day.siteNames, ['Blue Corner', 'Jetty']);
      expect(day.siteCount, 2);
      expect(day.hasContent, isTrue);
    });

    test('totalRuntime adds no time for a dive with only a bottom time', () {
      // Bottom time is derived from a depth threshold, so it is no runtime.
      // This mirrors the measured runtime the SQL aggregates use, which keeps
      // the day's rows adding up to the trip total (issue #3304).
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(
            id: 'd1',
            dateTime: DateTime(2026, 3, 8, 9),
            bottomTime: const Duration(minutes: 38),
          ),
          _dive(
            id: 'd2',
            dateTime: DateTime(2026, 3, 8, 11),
            runtime: const Duration(minutes: 42),
          ),
        ],
      );

      expect(day.totalRuntime, const Duration(minutes: 42));
    });

    test(
      'siteCount dedupes by id, so same-named distinct sites count twice',
      () {
        const twinA = DiveSite(id: 'site-1', name: 'Coral Garden');
        const twinB = DiveSite(id: 'site-2', name: 'Coral Garden'); // same name
        final day = TripStoryDay(
          date: date,
          dayNumber: 2,
          kind: TripStoryDayKind.past,
          dives: [
            _dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9), site: twinA),
            _dive(id: 'd2', dateTime: DateTime(2026, 3, 8, 11), site: twinB),
          ],
        );
        // Deduped by display name this collapses to one; by id it stays two,
        // matching the map geometry and the trip-level stat strip.
        expect(day.siteNames, ['Coral Garden']);
        expect(day.siteCount, 2);
      },
    );

    test('siteLocations lists each distinct site location once, in dive '
        'order, and skips sites with none', () {
      const marsaAlam = DiveSite(
        id: 'site-1',
        name: 'Elphinstone',
        city: 'Marsa Alam',
        region: 'Red Sea',
        country: 'Egypt',
      );
      const abuDabab = DiveSite(
        id: 'site-2',
        name: 'Abu Dabab',
        city: 'Marsa Alam',
        region: 'Red Sea',
        country: 'Egypt',
      );
      const unplaced = DiveSite(id: 'site-3', name: 'House Reef');
      const blank = DiveSite(id: 'site-4', name: 'Jetty', country: '  ');
      const quseir = DiveSite(
        id: 'site-5',
        name: 'Brothers',
        city: 'El Quseir',
        country: 'Egypt',
      );
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 7), site: marsaAlam),
          _dive(id: 'd2', dateTime: DateTime(2026, 3, 8, 9), site: unplaced),
          _dive(id: 'd3', dateTime: DateTime(2026, 3, 8, 11), site: abuDabab),
          _dive(id: 'd4', dateTime: DateTime(2026, 3, 8, 13), site: blank),
          _dive(id: 'd5', dateTime: DateTime(2026, 3, 8, 15), site: quseir),
          _dive(id: 'd6', dateTime: DateTime(2026, 3, 8, 17)),
        ],
      );

      expect(day.siteLocations, [
        'Marsa Alam · Red Sea, Egypt',
        'El Quseir · Egypt',
      ]);
    });

    test('siteLocations leaves out an area a finer location already names', () {
      const town = DiveSite(
        id: 'site-1',
        name: 'Elphinstone',
        city: 'Marsa Alam',
        region: 'Red Sea',
        country: 'Egypt',
      );
      const region = DiveSite(
        id: 'site-2',
        name: 'Daedalus',
        region: 'Red Sea',
        country: 'Egypt',
      );
      const country = DiveSite(
        id: 'site-3',
        name: 'Brothers',
        country: 'Egypt',
      );
      const elsewhere = DiveSite(
        id: 'site-4',
        name: 'Ras Mohammed',
        country: 'South Sinai Egypt',
      );
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 7), site: region),
          _dive(id: 'd2', dateTime: DateTime(2026, 3, 8, 9), site: country),
          _dive(id: 'd3', dateTime: DateTime(2026, 3, 8, 11), site: town),
          _dive(id: 'd4', dateTime: DateTime(2026, 3, 8, 13), site: elsewhere),
        ],
      );

      // "Egypt" is a whole part of the others; "South Sinai Egypt" only
      // ends with the same letters, so it stays.
      expect(day.siteLocations, [
        'Marsa Alam · Red Sea, Egypt',
        'South Sinai Egypt',
      ]);
    });

    test('siteLocations leaves out a town or a region alone that a fuller '
        'location names, and keeps one that differs', () {
      const full = DiveSite(
        id: 'site-1',
        name: 'Elphinstone',
        city: 'Marsa Alam',
        region: 'Red Sea',
        country: 'Egypt',
      );
      const townOnly = DiveSite(
        id: 'site-2',
        name: 'Abu Dabab',
        city: 'Marsa Alam',
      );
      const regionOnly = DiveSite(
        id: 'site-3',
        name: 'Daedalus',
        region: 'Red Sea',
      );
      const islandOnly = DiveSite(
        id: 'site-4',
        name: 'Zabargad',
        island: 'Zabargad',
      );
      const otherTown = DiveSite(
        id: 'site-5',
        name: 'Brothers',
        city: 'El Quseir',
        region: 'Red Sea',
        country: 'Egypt',
      );
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 7), site: townOnly),
          _dive(id: 'd2', dateTime: DateTime(2026, 3, 8, 9), site: regionOnly),
          _dive(id: 'd3', dateTime: DateTime(2026, 3, 8, 11), site: full),
          _dive(id: 'd4', dateTime: DateTime(2026, 3, 8, 13), site: islandOnly),
          _dive(id: 'd5', dateTime: DateTime(2026, 3, 8, 15), site: otherTown),
        ],
      );

      // "Red Sea" alone is in both full locations; each town is its own.
      expect(day.siteLocations, [
        'Marsa Alam · Red Sea, Egypt',
        'Zabargad',
        'El Quseir · Red Sea, Egypt',
      ]);
    });

    test('siteLocations reads one area typed in two cases as one', () {
      const saved = DiveSite(
        id: 'site-1',
        name: 'Elphinstone',
        region: 'Red Sea',
        country: 'Egypt',
      );
      const imported = DiveSite(
        id: 'site-2',
        name: 'Abu Dabab',
        region: 'Red sea',
        country: 'egypt',
      );
      const town = DiveSite(
        id: 'site-3',
        name: 'Marsa Shona',
        city: 'Marsa Alam',
        region: 'RED SEA',
        country: 'EGYPT',
      );
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 7), site: saved),
          _dive(id: 'd2', dateTime: DateTime(2026, 3, 8, 9), site: imported),
        ],
      );
      expect(day.siteLocations, ['Red Sea, Egypt']);

      final withTown = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 7), site: saved),
          _dive(id: 'd3', dateTime: DateTime(2026, 3, 8, 11), site: town),
        ],
      );
      expect(withTown.siteLocations, ['Marsa Alam · RED SEA, EGYPT']);
    });

    test('empty day has no content and null maxDepth', () {
      final day = TripStoryDay(
        date: date,
        dayNumber: 3,
        kind: TripStoryDayKind.future,
      );
      expect(day.diveCount, 0);
      expect(day.totalRuntime, Duration.zero);
      expect(day.maxDepth, isNull);
      expect(day.siteNames, isEmpty);
      expect(day.siteLocations, isEmpty);
      expect(day.hasContent, isFalse);
    });

    test('isSurface is true only for contentless non-future days', () {
      TripStoryDay make({
        TripStoryDayKind kind = TripStoryDayKind.past,
        List<Dive> dives = const [],
      }) => TripStoryDay(date: date, dayNumber: 1, kind: kind, dives: dives);

      expect(make().isSurface, isTrue);
      expect(make(kind: TripStoryDayKind.today).isSurface, isTrue);
      // Planned days render a chapter even without content.
      expect(make(kind: TripStoryDayKind.future).isSurface, isFalse);
      expect(
        make(
          dives: [_dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
        ).isSurface,
        isFalse,
      );
    });

    group('isPlannedRest', () {
      ItineraryDay row({DayType type = DayType.diveDay, int? planned}) =>
          ItineraryDay(
            id: 'itin-1',
            tripId: 'trip-1',
            dayNumber: 1,
            date: date,
            dayType: type,
            plannedDives: planned,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          );
      TripStoryDay make({
        ItineraryDay? itinerary,
        List<Dive> dives = const [],
        TripStoryDayKind kind = TripStoryDayKind.future,
      }) => TripStoryDay(
        date: date,
        dayNumber: 1,
        kind: kind,
        itineraryDay: itinerary,
        dives: dives,
      );

      test('a dive day planned at 0 dives is a planned rest (#2658)', () {
        expect(make(itinerary: row(planned: 0)).isPlannedRest, isTrue);
        expect(
          make(
            itinerary: row(planned: 0),
            kind: TripStoryDayKind.past,
          ).isPlannedRest,
          isTrue,
        );
      });

      test('a dive day with a derived or positive plan is not', () {
        expect(make(itinerary: row()).isPlannedRest, isFalse);
        expect(make(itinerary: row(planned: 2)).isPlannedRest, isFalse);
      });

      test('another day type planned at 0 keeps its own label', () {
        expect(
          make(itinerary: row(type: DayType.seaDay, planned: 0)).isPlannedRest,
          isFalse,
        );
      });

      test('dives logged on the day make it a dive day after all', () {
        expect(
          make(
            itinerary: row(planned: 0),
            kind: TripStoryDayKind.past,
            dives: [_dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
          ).isPlannedRest,
          isFalse,
        );
      });

      test('a day without an itinerary row is not', () {
        expect(make().isPlannedRest, isFalse);
      });
    });
  });

  group('weather summary', () {
    test('null when no dive carries any weather data', () {
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [_dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9))],
      );
      expect(day.weather, isNull);
    });

    test('null for a day with no dives', () {
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
      );
      expect(day.weather, isNull);
    });

    test('takes the first non-null value per field across dives', () {
      // Morning dive logged only air temperature, afternoon dive only cloud
      // cover and precipitation: the day summary combines all three.
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(id: 'd1', dateTime: DateTime(2026, 3, 8, 9), airTemp: 22),
          _dive(
            id: 'd2',
            dateTime: DateTime(2026, 3, 8, 14),
            airTemp: 27,
            cloudCover: CloudCover.partlyCloudy,
            precipitation: Precipitation.drizzle,
          ),
        ],
      );

      expect(
        day.weather,
        const TripStoryDayWeather(
          airTemp: 22,
          cloudCover: CloudCover.partlyCloudy,
          precipitation: Precipitation.drizzle,
        ),
      );
    });

    test('a single weather field is enough to produce a summary', () {
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(
            id: 'd1',
            dateTime: DateTime(2026, 3, 8, 9),
            cloudCover: CloudCover.overcast,
          ),
        ],
      );

      expect(
        day.weather,
        const TripStoryDayWeather(cloudCover: CloudCover.overcast),
      );
    });
  });

  group('TripStoryMapGeometry', () {
    test('pointsForDay filters by dayIndex', () {
      const geometry = TripStoryMapGeometry(
        points: [
          TripStoryMapPoint(latitude: 1, longitude: 2, dayIndex: 0, label: 'A'),
          TripStoryMapPoint(latitude: 3, longitude: 4, dayIndex: 1, label: 'B'),
        ],
      );
      expect(geometry.hasPoints, isTrue);
      expect(geometry.pointsForDay(1).single.label, 'B');
      expect(geometry.pointsForDay(9), isEmpty);
    });

    test('nearestPointForDay returns a point on the requested day', () {
      const geometry = TripStoryMapGeometry(
        points: [
          TripStoryMapPoint(latitude: 1, longitude: 2, dayIndex: 0, label: 'A'),
          TripStoryMapPoint(latitude: 3, longitude: 4, dayIndex: 2, label: 'B'),
        ],
      );

      expect(geometry.nearestPointForDay(2)?.label, 'B');
    });

    test('nearestPointForDay uses the closest point at trip boundaries', () {
      const geometry = TripStoryMapGeometry(
        points: [
          TripStoryMapPoint(
            latitude: 1,
            longitude: 2,
            dayIndex: 2,
            label: 'First',
          ),
          TripStoryMapPoint(
            latitude: 3,
            longitude: 4,
            dayIndex: 4,
            label: 'Last',
          ),
        ],
      );

      expect(geometry.nearestPointForDay(0)?.label, 'First');
      expect(geometry.nearestPointForDay(7)?.label, 'Last');
    });

    test('nearestPointForDay preserves route order for an equidistant tie', () {
      const geometry = TripStoryMapGeometry(
        points: [
          TripStoryMapPoint(
            latitude: 1,
            longitude: 2,
            dayIndex: 0,
            label: 'Prior',
          ),
          TripStoryMapPoint(
            latitude: 3,
            longitude: 4,
            dayIndex: 2,
            label: 'Next',
          ),
        ],
      );

      expect(geometry.nearestPointForDay(1)?.label, 'Prior');
    });

    test('nearestPointForDay returns null for empty geometry', () {
      const geometry = TripStoryMapGeometry(points: []);

      expect(geometry.nearestPointForDay(1), isNull);
    });

    test('empty geometry has no points', () {
      const geometry = TripStoryMapGeometry(points: []);
      expect(geometry.hasPoints, isFalse);
    });
  });

  group('value equality', () {
    test('TripStoryDay compares by value', () {
      final a = TripStoryDay(
        date: date,
        dayNumber: 1,
        kind: TripStoryDayKind.past,
      );
      final b = TripStoryDay(
        date: date,
        dayNumber: 1,
        kind: TripStoryDayKind.past,
      );
      final c = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('TripStoryMapPoint compares by value', () {
      // Non-const so equality falls through to props (const instances are
      // canonicalized and short-circuit via identical()).
      final lat = 1.0 + DateTime(2026).day - 1; // runtime value = 1.0
      final a = TripStoryMapPoint(
        latitude: lat,
        longitude: 2,
        dayIndex: 0,
        label: 'A',
      );
      final b = TripStoryMapPoint(
        latitude: lat,
        longitude: 2,
        dayIndex: 0,
        label: 'A',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('TripStoryMapGeometry compares by value', () {
      TripStoryMapPoint pt() => TripStoryMapPoint(
        latitude: 1.0 + DateTime(2026).day - 1,
        longitude: 2,
        dayIndex: 0,
        label: 'A',
      );
      final a = TripStoryMapGeometry(points: [pt()]);
      final b = TripStoryMapGeometry(points: [pt()]);
      expect(a, equals(b));
    });
  });

  group('dive-day helpers', () {
    final d1 = Dive(
      id: 'a',
      dateTime: DateTime(2026, 3, 8, 9),
      runtime: const Duration(minutes: 50),
      maxDepth: 18,
      airTemp: 29,
    );
    final d2 = Dive(
      id: 'b',
      dateTime: DateTime(2026, 3, 8, 14),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 24,
      cloudCover: CloudCover.partlyCloudy,
    );

    test('runtime sums measured runtimes, never a bottom time', () {
      expect(diveDayRuntime([d1, d2]), const Duration(minutes: 50));
      expect(diveDayRuntime(const []), Duration.zero);
    });

    test('max depth is the deepest dive, null without depths', () {
      expect(diveDayMaxDepth([d1, d2]), 24);
      expect(
        diveDayMaxDepth([Dive(id: 'c', dateTime: DateTime(2026))]),
        isNull,
      );
    });

    test('weather combines the first non-null field of each kind', () {
      final w = diveDayWeather([d1, d2])!;
      expect(w.airTemp, 29);
      expect(w.cloudCover, CloudCover.partlyCloudy);
      expect(diveDayWeather([Dive(id: 'c', dateTime: DateTime(2026))]), isNull);
    });

    test('resolve prefers renderable logged weather, else stored', () {
      const logged = TripStoryDayWeather(airTemp: 28);
      const blank = TripStoryDayWeather(precipitation: Precipitation.none);
      const stored = TripStoryDayWeather(airTemp: 31);
      expect(
        TripStoryDayWeather.resolve(logged: logged, stored: stored),
        logged,
      );
      expect(
        TripStoryDayWeather.resolve(logged: blank, stored: stored),
        stored,
      );
      expect(TripStoryDayWeather.resolve(logged: blank, stored: null), blank);
      expect(TripStoryDayWeather.resolve(logged: null, stored: null), isNull);
    });
  });
}
