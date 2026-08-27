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
}
