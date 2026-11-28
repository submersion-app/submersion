import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_avelo_lines.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_trim_line.dart';

/// Issue #5098: the trim line's axis and wording.
void main() {
  group('trimAxisHalfRange', () {
    test('a nearly flat dive keeps at least 10 degrees each way', () {
      expect(trimAxisHalfRange([-3.0, 0.0, 2.5]), 10.0);
    });

    test('rounds the largest angle up to the next 5 degrees', () {
      expect(trimAxisHalfRange([-13.0, 4.0]), 15.0);
      expect(trimAxisHalfRange([12.0, -21.0]), 25.0);
    });

    test('an angle near vertical reaches 90', () {
      expect(trimAxisHalfRange([87.0, -76.0]), 90.0);
      expect(trimAxisHalfRange([90.0]), 90.0);
    });
  });

  group('the trim curve and range', () {
    const profile = [
      DiveProfilePoint(timestamp: 0, depth: 1.0, trim: 70.0),
      DiveProfilePoint(timestamp: 30, depth: 9.0),
      DiveProfilePoint(timestamp: 60, depth: 12.0, trim: -13.0),
    ];

    test('reads the logged angle, null where none', () {
      expect(aveloCurve(ProfileRightAxisMetric.trim, profile), [
        70.0,
        null,
        -13.0,
      ]);
    });

    test('is symmetric about flat', () {
      expect(aveloLineRange(ProfileRightAxisMetric.trim, profile), (
        min: -70.0,
        max: 70.0,
      ));
    });

    test('is null for a dive without trim', () {
      expect(
        aveloLineRange(ProfileRightAxisMetric.trim, const [
          DiveProfilePoint(timestamp: 0, depth: 1.0),
        ]),
        isNull,
      );
    });
  });

  group('formatTrimDegrees', () {
    test('whole degrees with a sign either side of flat', () {
      expect(formatTrimDegrees(-13.0), '-13°');
      expect(formatTrimDegrees(5.0), '+5°');
      expect(formatTrimDegrees(0.0), '0°');
      expect(formatTrimDegrees(-0.4), '0°');
    });
  });
}
