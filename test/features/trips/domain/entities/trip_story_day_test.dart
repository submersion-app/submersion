import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
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

    test('totalRuntime falls back to bottom time when runtime is absent', () {
      // Hand-logged dives often carry only a bottom time. Dropping them from
      // the total would under-report the day more badly than the bug this
      // replaces, so bottom time remains the fallback -- mirroring the
      // COALESCE(runtime, bottom_time) the SQL aggregates use.
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

      expect(day.totalRuntime, const Duration(minutes: 80));
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
}
