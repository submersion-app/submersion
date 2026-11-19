import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_avelo_lines.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';

/// Issue #4664: the three Avelo lines, read straight from the profile.
void main() {
  const profile = [
    DiveProfilePoint(
      timestamp: 0,
      depth: 0.0,
      aveloBuoyancy: -0.5,
      aveloGasRemaining: 100,
    ),
    DiveProfilePoint(timestamp: 10, depth: 5.0, computerRmv: 10.0),
    DiveProfilePoint(
      timestamp: 20,
      depth: 9.0,
      aveloBuoyancy: 1.5,
      aveloGasRemaining: 50,
      computerRmv: 20.0,
    ),
  ];

  test('each curve reads its own field, null where the sample has none', () {
    expect(aveloCurve(ProfileRightAxisMetric.aveloBuoyancy, profile), [
      -0.5,
      null,
      1.5,
    ]);
    expect(aveloCurve(ProfileRightAxisMetric.aveloGasRemaining, profile), [
      100.0,
      null,
      50.0,
    ]);
    expect(aveloCurve(ProfileRightAxisMetric.computerRmv, profile), [
      null,
      10.0,
      20.0,
    ]);
  });

  test('gas remaining spans 0 to 100, RMV 0 to 120% of its peak', () {
    expect(aveloLineRange(ProfileRightAxisMetric.aveloGasRemaining, profile), (
      min: 0.0,
      max: 100.0,
    ));
    expect(aveloLineRange(ProfileRightAxisMetric.computerRmv, profile), (
      min: 0.0,
      max: 24.0,
    ));
  });

  test('the buoyancy range spans neutral', () {
    final range = aveloLineRange(
      ProfileRightAxisMetric.aveloBuoyancy,
      profile,
    )!;
    expect(range.min, lessThan(-0.5));
    expect(range.max, greaterThan(1.5));
  });

  test('a dive without the value has no range', () {
    const plain = [
      DiveProfilePoint(timestamp: 0, depth: 3.0),
      DiveProfilePoint(timestamp: 10, depth: 5.0),
    ];
    for (final m in aveloLineMetrics) {
      expect(aveloLineRange(m, plain), isNull, reason: '$m');
    }
  });

  test('the line breaks at a sample without a value', () {
    const band = MetricBand(top: 0, span: 100);
    final line = buildAveloLine(
      color: Colors.blue,
      band: band,
      curve: aveloCurve(ProfileRightAxisMetric.aveloGasRemaining, profile),
      range: (min: 0.0, max: 100.0),
      profile: profile,
    );
    expect(line.spots, hasLength(3));
    expect(line.spots[1], FlSpot.nullSpot);
    expect(line.spots[0].x, 0);
    expect(line.spots[2].x, 20);
    // Full at the top of the band, half at its middle (y is negated depth).
    expect(line.spots[0].y, closeTo(-band.mapNormalized(1.0), 1e-9));
    expect(line.spots[2].y, closeTo(-band.mapNormalized(0.5), 1e-9));
  });

  test('decimated indices break only across blanks, not dropped values', () {
    const points = [
      DiveProfilePoint(timestamp: 0, depth: 5.0, aveloGasRemaining: 90),
      DiveProfilePoint(timestamp: 10, depth: 5.0, aveloGasRemaining: 89),
      DiveProfilePoint(timestamp: 20, depth: 5.0, aveloGasRemaining: 88),
      DiveProfilePoint(timestamp: 30, depth: 5.0),
      DiveProfilePoint(timestamp: 40, depth: 5.0, aveloGasRemaining: 86),
    ];
    final line = buildAveloLine(
      color: Colors.green,
      band: const MetricBand(top: 0, span: 100),
      curve: aveloCurve(ProfileRightAxisMetric.aveloGasRemaining, points),
      range: (min: 0.0, max: 100.0),
      profile: points,
      // Sample 1 was decimated away; sample 3 is a blank.
      indices: const [0, 2, 4],
    );
    expect(line.spots.map((s) => s == FlSpot.nullSpot ? null : s.x), [
      0,
      20,
      null,
      40,
    ]);
  });
}
