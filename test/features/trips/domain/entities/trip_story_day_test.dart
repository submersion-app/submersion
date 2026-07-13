import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';

Dive _dive({
  required String id,
  required DateTime dateTime,
  Duration? bottomTime,
  double? maxDepth,
  DiveSite? site,
}) {
  return Dive(
    id: id,
    dateTime: dateTime,
    bottomTime: bottomTime,
    maxDepth: maxDepth,
    site: site,
  );
}

void main() {
  final date = DateTime(2026, 3, 8);
  const siteA = DiveSite(id: 'site-a', name: 'Blue Corner');
  const siteB = DiveSite(id: 'site-b', name: 'Jetty');

  group('TripStoryDay derived getters', () {
    test('aggregates dive count, bottom time, and max depth', () {
      final day = TripStoryDay(
        date: date,
        dayNumber: 2,
        kind: TripStoryDayKind.past,
        dives: [
          _dive(
            id: 'd1',
            dateTime: DateTime(2026, 3, 8, 9),
            bottomTime: const Duration(minutes: 47),
            maxDepth: 28,
            site: siteA,
          ),
          _dive(
            id: 'd2',
            dateTime: DateTime(2026, 3, 8, 11),
            bottomTime: const Duration(minutes: 51),
            maxDepth: 24,
            site: siteA,
          ),
          _dive(id: 'd3', dateTime: DateTime(2026, 3, 8, 19), site: siteB),
        ],
      );

      expect(day.diveCount, 3);
      expect(day.totalBottomTime, const Duration(minutes: 98));
      expect(day.maxDepth, 28);
      expect(day.siteNames, ['Blue Corner', 'Jetty']);
      expect(day.hasContent, isTrue);
    });

    test('empty day has no content and null maxDepth', () {
      final day = TripStoryDay(
        date: date,
        dayNumber: 3,
        kind: TripStoryDayKind.future,
      );
      expect(day.diveCount, 0);
      expect(day.totalBottomTime, Duration.zero);
      expect(day.maxDepth, isNull);
      expect(day.siteNames, isEmpty);
      expect(day.hasContent, isFalse);
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
