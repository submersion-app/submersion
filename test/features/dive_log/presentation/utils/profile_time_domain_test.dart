import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/utils/profile_time_domain.dart';

List<DiveProfilePoint> _points(List<int> timestamps) => [
  for (final t in timestamps) DiveProfilePoint(timestamp: t, depth: 10),
];

void main() {
  group('profileTimeDomain (#4296)', () {
    test('starts at 0 when no sample is negative', () {
      expect(profileTimeDomain(_points([60, 120, 600])), (min: 0, max: 600));
    });

    test('starts at the earliest negative sample', () {
      expect(profileTimeDomain(_points([-600, 0, 2400])), (
        min: -600,
        max: 2400,
      ));
    });

    test('other series widen both ends', () {
      expect(
        profileTimeDomain(_points([0, 1200]), [
          _points([-900, 300]),
          _points([100, 1800]),
        ]),
        (min: -900, max: 1800),
      );
    });

    test('reads unsorted samples', () {
      expect(profileTimeDomain(_points([300, -60, 900, 0])), (
        min: -60,
        max: 900,
      ));
    });

    test('no samples is an empty axis at 0', () {
      expect(profileTimeDomain(const []), (min: 0, max: 0));
    });
  });
}
