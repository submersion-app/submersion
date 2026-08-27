import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive.calculateBottomTimeFromProfile', () {
    test('multilevel dive counts the shallow tail as bottom time', () {
      // 29 m for ~10 min, then a 40 min tail at 15.2 m: the old 85%
      // heuristic returned 540 s; the multilevel-correct value is 3060 s
      // (surface departure at t=0 to the start of the final ascent).
      final dive = Dive(
        id: 'bt-multilevel',
        dateTime: DateTime(2024, 1, 1),
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 0.0),
          DiveProfilePoint(timestamp: 60, depth: 29.0),
          DiveProfilePoint(timestamp: 600, depth: 29.0),
          DiveProfilePoint(timestamp: 660, depth: 15.2),
          DiveProfilePoint(timestamp: 3060, depth: 15.2),
          DiveProfilePoint(timestamp: 3120, depth: 5.0),
          DiveProfilePoint(timestamp: 3300, depth: 5.0),
          DiveProfilePoint(timestamp: 3600, depth: 0.0),
        ],
      );
      expect(
        dive.calculateBottomTimeFromProfile(),
        const Duration(seconds: 3060),
      );
    });

    test('returns null without profile data', () {
      final dive = Dive(id: 'bt-empty', dateTime: DateTime(2024, 1, 1));
      expect(dive.calculateBottomTimeFromProfile(), isNull);
    });
  });
}
