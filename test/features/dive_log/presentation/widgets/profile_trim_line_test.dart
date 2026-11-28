import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/utils/bidi_isolate.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_sample_lines.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';
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
      expect(sampleLineCurve(ProfileRightAxisMetric.trim, profile), [
        70.0,
        null,
        -13.0,
      ]);
    });

    test('is symmetric about flat', () {
      expect(sampleLineRange(ProfileRightAxisMetric.trim, profile), (
        min: -70.0,
        max: 70.0,
      ));
    });

    test('is null for a dive without trim', () {
      expect(
        sampleLineRange(ProfileRightAxisMetric.trim, const [
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

    test('isolates the signed angle in right-to-left text', () {
      // Unisolated, bidi reordering shows -13° as °13- in Arabic or Hebrew.
      expect(
        formatTrimDegrees(-13.0, direction: TextDirection.rtl),
        isolateForDirection('-13°', TextDirection.rtl),
      );
      expect(
        formatTrimDegrees(-13.0, direction: TextDirection.rtl),
        isNot('-13°'),
      );
      expect(formatTrimDegrees(5.0, direction: TextDirection.ltr), '+5°');
    });
  });

  test('a computer that starts logging trim late starts the line there, '
      'with no zero and no break before it', () {
    final profile = [
      for (var i = 0; i < 6; i++)
        DiveProfilePoint(
          timestamp: i * 30,
          depth: 5.0,
          trim: i < 3 ? null : -10.0 + i,
        ),
    ];
    final curve = sampleLineCurve(ProfileRightAxisMetric.trim, profile);
    final line = buildSampleLine(
      color: const Color(0xFF8D6E63),
      band: const MetricBand(top: 0, span: 10),
      curve: curve,
      range: sampleLineCurveRange(ProfileRightAxisMetric.trim, curve)!,
      profile: profile,
    );
    expect(line.spots.first.x, 90);
    expect(line.spots, hasLength(3));
    expect(line.spots.contains(FlSpot.nullSpot), isFalse);
  });
}
