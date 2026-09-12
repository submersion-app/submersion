import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

void main() {
  group('NavTrackPoint equality', () {
    test('two points with identical fields are equal', () {
      const a = NavTrackPoint(
        timestamp: 100,
        north: 1,
        east: 2,
        depth: 3,
        course: 90,
        pitch: 1,
        roll: 2,
        distance: 5,
        speed: 0.5,
        temperature: 18,
        batteryVolts: 3.8,
      );
      const b = NavTrackPoint(
        timestamp: 100,
        north: 1,
        east: 2,
        depth: 3,
        course: 90,
        pitch: 1,
        roll: 2,
        distance: 5,
        speed: 0.5,
        temperature: 18,
        batteryVolts: 3.8,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('points differing in one nullable field are not equal', () {
      const a = NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 0);
      const b = NavTrackPoint(
        timestamp: 0,
        north: 0,
        east: 0,
        depth: 0,
        batteryVolts: 3.8,
      );
      expect(a, isNot(b));
    });

    test('every optional field defaults to null', () {
      const point = NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 0);
      expect(point.course, isNull);
      expect(point.pitch, isNull);
      expect(point.roll, isNull);
      expect(point.distance, isNull);
      expect(point.speed, isNull);
      expect(point.temperature, isNull);
      expect(point.batteryVolts, isNull);
    });
  });
}
