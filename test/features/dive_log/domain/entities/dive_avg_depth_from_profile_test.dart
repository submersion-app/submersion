import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  group('Dive.calculateAvgDepthFromProfile', () {
    Dive diveWith(List<DiveProfilePoint> profile) =>
        Dive(id: 'd', dateTime: DateTime(2024, 1, 1), profile: profile);

    test('weights the profile by elapsed time (#3891)', () {
      final dive = diveWith(const [
        DiveProfilePoint(timestamp: 0, depth: 10),
        DiveProfilePoint(timestamp: 60, depth: 10),
        DiveProfilePoint(timestamp: 120, depth: 30),
        DiveProfilePoint(timestamp: 600, depth: 30),
      ]);

      expect(dive.calculateAvgDepthFromProfile(), closeTo(27, 1e-9));
    });

    test('a single sample is its own average', () {
      final dive = diveWith(const [DiveProfilePoint(timestamp: 0, depth: 12)]);

      expect(dive.calculateAvgDepthFromProfile(), 12);
    });

    test('is null without a profile', () {
      expect(diveWith(const []).calculateAvgDepthFromProfile(), isNull);
    });

    test('is null for a profile that never leaves the surface', () {
      final dive = diveWith(const [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 60, depth: 0),
      ]);

      expect(dive.calculateAvgDepthFromProfile(), isNull);
    });
  });
}
