import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_paint_utils.dart';

void main() {
  test('dashedPath keeps roughly dash/(dash+gap) of the source length', () {
    final line = Path()
      ..moveTo(0, 0)
      ..lineTo(100, 0);
    final dashed = dashedPath(line, dash: 5, gap: 5);
    final total = dashed.computeMetrics().fold<double>(
      0,
      (sum, m) => sum + m.length,
    );
    expect(total, closeTo(50, 5.001));
  });

  test('layoutLabel produces a laid-out painter with nonzero size', () {
    final painter = layoutLabel(
      "21m 1'",
      const TextStyle(fontSize: 10),
      TextDirection.ltr,
    );
    expect(painter.width, greaterThan(0));
    expect(painter.height, greaterThan(0));
  });

  group('gasFlagRows (issue #4078)', () {
    test('flags far apart all sit on the top row', () {
      expect(
        gasFlagRows([
          (left: 0, right: 50),
          (left: 100, right: 150),
          (left: 200, right: 250),
        ]),
        [0, 0, 0],
      );
    });

    test('a flag that would print over the one before drops a row', () {
      expect(gasFlagRows([(left: 0, right: 50), (left: 30, right: 80)]), [
        0,
        1,
      ]);
    });

    test('a flag goes back up to the first row it clears', () {
      expect(
        gasFlagRows([
          (left: 0, right: 50),
          (left: 30, right: 80),
          (left: 60, right: 110),
          (left: 90, right: 140),
        ]),
        [0, 1, 0, 1],
      );
    });

    test('flags closer than the gap do not touch', () {
      expect(
        gasFlagRows([(left: 0, right: 50), (left: 52, right: 90)], gap: 4),
        [0, 1],
      );
    });

    test('a wide flag keeps its row taken past a narrower one after it', () {
      expect(
        gasFlagRows([
          (left: 0, right: 200),
          (left: 10, right: 40),
          (left: 60, right: 90),
        ]),
        [0, 1, 1],
      );
    });
  });
}
