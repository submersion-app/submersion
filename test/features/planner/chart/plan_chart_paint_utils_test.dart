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

    test('past the last row a flag shares the row that frees up first', () {
      expect(
        gasFlagRows([
          (left: 0, right: 100),
          (left: 10, right: 60),
          (left: 20, right: 70),
        ], maxRows: 2),
        [0, 1, 1],
      );
    });
  });

  group('gasFlagPills (issue #4078)', () {
    const plot = Rect.fromLTWH(40, 10, 400, 300);
    const pill = Size(50, 16);

    test('a pill sits just right of its stem, on its row', () {
      final rects = gasFlagPills(
        xs: const [100, 120],
        sizes: const [pill, pill],
        plot: plot,
      );

      expect(rects[0], const Rect.fromLTWH(104, 14, 50, 16));
      expect(rects[1], const Rect.fromLTWH(124, 34, 50, 16));
    });

    test('a switch near the end of the dive stays inside the plot', () {
      final rects = gasFlagPills(
        xs: const [430],
        sizes: const [pill],
        plot: plot,
      );

      expect(rects.single.right, plot.right);
    });

    test('a run of switches never goes past the last row', () {
      final rects = gasFlagPills(
        xs: const [100, 105, 110, 115, 120],
        sizes: const [pill, pill, pill, pill, pill],
        plot: plot,
        maxRows: 3,
      );

      expect(rects.map((r) => r.top).toSet(), {14.0, 34.0, 54.0});
    });

    test('a short plot keeps fewer rows', () {
      final rects = gasFlagPills(
        xs: const [100, 105, 110],
        sizes: const [pill, pill, pill],
        plot: const Rect.fromLTWH(40, 10, 400, 80),
      );

      // 30 % of 80 px holds one 20 px row.
      expect(rects.map((r) => r.top).toSet(), {14.0});
    });
  });

  test('gasFlagRows keeps one row however few it is allowed', () {
    expect(
      gasFlagRows([(left: 0, right: 50), (left: 10, right: 60)], maxRows: 0),
      [0, 0],
    );
  });
}
