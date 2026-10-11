import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_time_scale.dart';
import 'package:submersion/features/insights/presentation/widgets/trend_break_band_painter.dart';

void main() {
  final b = TrendGapBreak(
    start: DateTime.utc(2018),
    end: DateTime.utc(2025),
    axisStart: 400,
    axisEnd: 430,
  );
  const plot = Rect.fromLTWH(50, 0, 500, 170);

  test('a visible break is placed in plot pixels', () {
    final bands = TrendBreakBandPainter.layout(
      breaks: [b],
      visibleMin: 0,
      visibleMax: 1000,
      plot: plot,
      labelOf: (_) => '7y',
    );
    expect(bands.single.left, 50 + 0.4 * 500);
    expect(bands.single.right, closeTo(50 + 0.43 * 500, 1e-9));
    expect(bands.single.label, '7y');
  });

  test('a break outside the window is dropped', () {
    expect(
      TrendBreakBandPainter.layout(
        breaks: [b],
        visibleMin: 500,
        visibleMax: 1000,
        plot: plot,
        labelOf: (_) => '7y',
      ),
      isEmpty,
    );
  });

  test('a break half in view is clipped to the plot', () {
    final bands = TrendBreakBandPainter.layout(
      breaks: [b],
      visibleMin: 410,
      visibleMax: 1000,
      plot: plot,
      labelOf: (_) => '7y',
    );
    expect(bands.single.left, plot.left);
  });
}
