import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/utils/buoyancy_curve.dart';

void main() {
  TwinSample sample(int t, double net) =>
      TwinSample(timestamp: t, depthM: 10, suitKg: 0, tanksKg: 0, netKg: net);

  List<DiveProfilePoint> drawn(List<int> ts) => [
    for (final t in ts) DiveProfilePoint(timestamp: t, depth: 10),
  ];

  test('matching timestamps carry the net buoyancy, by index', () {
    final curve = alignBuoyancyCurve(drawn([0, 10, 20]), [
      sample(0, -1.0),
      sample(10, -2.0),
      sample(20, 0.5),
    ]);
    expect(curve, [-1.0, -2.0, 0.5]);
  });

  test('unmatched timestamps become null', () {
    final curve = alignBuoyancyCurve(drawn([0, 10, 20]), [
      sample(0, -1.0),
      sample(20, 0.5),
    ]);
    expect(curve, [-1.0, null, 0.5]);
  });

  test(
    'extra model samples are ignored and length follows the drawn series',
    () {
      final curve = alignBuoyancyCurve(drawn([5]), [
        sample(0, -1.0),
        sample(5, -3.0),
        sample(9, 2.0),
      ]);
      expect(curve, [-3.0]);
    },
  );
}
