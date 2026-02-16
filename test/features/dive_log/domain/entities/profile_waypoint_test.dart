import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';

void main() {
  group('ProfileWaypoint', () {
    test('copyWith creates new instance with updated fields', () {
      const original = ProfileWaypoint(timestamp: 0, depth: 10.0);
      final updated = original.copyWith(depth: 20.0);
      expect(updated.depth, 20.0);
      expect(updated.timestamp, 0);
      expect(original.depth, 10.0); // immutable
    });

    test('copyWith preserves values when no arguments given', () {
      const original = ProfileWaypoint(timestamp: 120, depth: 30.0);
      final copy = original.copyWith();
      expect(copy, equals(original));
      expect(identical(copy, original), isFalse);
    });

    test('copyWith updates timestamp only', () {
      const original = ProfileWaypoint(timestamp: 60, depth: 18.0);
      final updated = original.copyWith(timestamp: 120);
      expect(updated.timestamp, 120);
      expect(updated.depth, 18.0);
    });

    test('two waypoints with same values are equal', () {
      const a = ProfileWaypoint(timestamp: 60, depth: 18.0);
      const b = ProfileWaypoint(timestamp: 60, depth: 18.0);
      expect(a, equals(b));
    });

    test('two waypoints with different values are not equal', () {
      const a = ProfileWaypoint(timestamp: 60, depth: 18.0);
      const b = ProfileWaypoint(timestamp: 60, depth: 20.0);
      expect(a, isNot(equals(b)));
    });

    test('props includes timestamp and depth', () {
      const w = ProfileWaypoint(timestamp: 90, depth: 12.5);
      expect(w.props, [90, 12.5]);
    });
  });
}
