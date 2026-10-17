import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/scenes/scene_dash.dart';

Path _line() => Path()
  ..moveTo(0, 0)
  ..lineTo(100, 0);

void main() {
  test('dashes a straight line into dash-and-gap pieces', () {
    final metrics = dashedPath(_line(), dash: 6, gap: 5).computeMetrics();
    final pieces = metrics.toList();

    expect(pieces, hasLength(10));
    expect(pieces.first.length, closeTo(6, 0.001));
    expect(pieces.first.getTangentForOffset(0)!.position.dx, 0);
  });

  test('a phase moves the dashes forward along the path', () {
    final shifted = dashedPath(
      _line(),
      dash: 6,
      gap: 5,
      phase: 3,
    ).computeMetrics().toList();

    expect(shifted.first.getTangentForOffset(0)!.position.dx, closeTo(3, 1e-6));
    expect(shifted.first.length, closeTo(6, 0.001));
  });

  test('a phase can bring the tail of a dash in at the start', () {
    final shifted = dashedPath(
      _line(),
      dash: 6,
      gap: 5,
      phase: 8,
    ).computeMetrics().toList();

    expect(shifted.first.getTangentForOffset(0)!.position.dx, 0);
    expect(shifted.first.length, closeTo(3, 0.001));
  });

  test('a phase wraps around the pattern', () {
    List<double> starts(double phase) =>
        dashedPath(_line(), dash: 6, gap: 5, phase: phase)
            .computeMetrics()
            .map((m) => m.getTangentForOffset(0)!.position.dx)
            .toList();

    expect(starts(14), starts(3));
    expect(starts(-8), starts(3));
  });
}
