import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_sparkline.dart';

void main() {
  test('downsamples to at most targetCount, keeping bucket max depth', () {
    final profile = List.generate(
      400,
      (i) => DiveProfilePoint(timestamp: i * 10, depth: i == 200 ? 30.0 : 10.0),
    );
    final points = sparklinePoints(profile, targetCount: 40);
    expect(points.length, lessThanOrEqualTo(40));
    // The 30m spike must survive downsampling (bucket max, normalized to 1).
    expect(
      points.map((p) => p.depth).reduce((a, b) => a > b ? a : b),
      closeTo(1.0, 1e-9),
    );
    expect(points.first.t, 0.0);
    expect(points.last.t, 1.0);
  });

  test('short profiles pass through unchanged in count', () {
    final profile = [
      const DiveProfilePoint(timestamp: 0, depth: 0),
      const DiveProfilePoint(timestamp: 60, depth: 18),
      const DiveProfilePoint(timestamp: 120, depth: 0),
    ];
    expect(sparklinePoints(profile).length, 3);
  });

  test('empty and single-point profiles return empty', () {
    expect(sparklinePoints(const []), isEmpty);
    expect(
      sparklinePoints(const [DiveProfilePoint(timestamp: 0, depth: 5)]),
      isEmpty,
    );
  });
}
