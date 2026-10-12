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

  test('a length label near an edge stays inside the chart', () {
    // A 40px label centred 5px from the right edge of a 600px chart.
    expect(TrendBreakBandPainter.labelLeft(595, 40, 600), 560);
    expect(TrendBreakBandPainter.labelLeft(5, 40, 600), 0);
    expect(TrendBreakBandPainter.labelLeft(300, 40, 600), 280);
  });

  group('shouldRepaint', () {
    TrendBreakBandPainter painter({
      List<TrendBreakBand>? bands,
      Rect rect = plot,
      Color hatch = Colors.grey,
      Color fill = Colors.white,
      TextStyle style = const TextStyle(fontSize: 12),
      TextDirection direction = TextDirection.ltr,
    }) => TrendBreakBandPainter(
      bands: bands ?? const [(left: 10, right: 20, label: '7y')],
      plot: rect,
      hatch: hatch,
      fill: fill,
      labelStyle: style,
      textDirection: direction,
    );

    const same = [(left: 10.0, right: 20.0, label: '7y')];

    test('an identical painter does not repaint', () {
      expect(painter(bands: same).shouldRepaint(painter(bands: same)), isFalse);
    });

    test('any changed input repaints', () {
      final base = painter(bands: same);
      expect(painter(bands: const []).shouldRepaint(base), isTrue);
      expect(painter(bands: same, rect: Rect.zero).shouldRepaint(base), isTrue);
      expect(
        painter(bands: same, hatch: Colors.red).shouldRepaint(base),
        isTrue,
      );
      expect(
        painter(bands: same, fill: Colors.black).shouldRepaint(base),
        isTrue,
      );
      expect(
        painter(
          bands: same,
          style: const TextStyle(fontSize: 14),
        ).shouldRepaint(base),
        isTrue,
      );
      expect(
        painter(bands: same, direction: TextDirection.rtl).shouldRepaint(base),
        isTrue,
      );
    });
  });
}
