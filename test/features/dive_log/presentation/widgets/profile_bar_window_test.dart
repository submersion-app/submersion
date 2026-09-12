import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_bar_window.dart';

LineChartBarData _bar(List<double> xs) =>
    LineChartBarData(spots: [for (final x in xs) FlSpot(x, x * 2)]);

List<double> _xs(LineChartBarData bar) => [
  for (final s in bar.spots) s.isNull() ? double.nan : s.x,
];

void main() {
  group('windowBars', () {
    final ramp = _bar([for (var i = 0; i <= 100; i++) i.toDouble()]);

    test('keeps the window plus two real neighbours on each side', () {
      final w = windowBars([ramp], minX: 40, maxX: 50, chartMinY: -1000);

      expect(_xs(w.bars.single), [for (var i = 38; i <= 52; i++) i.toDouble()]);
      expect(w.offsets, [38]);
    });

    test('maps a windowed spot index back to its source index', () {
      final w = windowBars([ramp], minX: 40, maxX: 50, chartMinY: -1000);

      expect(w.sourceSpotIndex(0, 0), 38);
      expect(w.sourceSpotIndex(0, 5), 43);
      expect(ramp.spots[w.sourceSpotIndex(0, 5)], w.bars.single.spots[5]);
    });

    test('keeps the samples bracketing a window that falls between them', () {
      // Sparse samples: nothing lies inside [12, 18], but the segment from
      // 10 to 20 still crosses the whole window and must stay drawn.
      final sparse = _bar([0, 10, 20, 30, 40]);

      final w = windowBars([sparse], minX: 12, maxX: 18, chartMinY: -1000);

      expect(_xs(w.bars.single), [0, 10, 20, 30]);
      expect(w.offsets, [0]);
    });

    test('does not count gap spots as neighbours', () {
      final gappy = LineChartBarData(
        spots: const [
          FlSpot(0, 0),
          FlSpot(1, 1),
          FlSpot.nullSpot,
          FlSpot(2, 2),
          FlSpot.nullSpot,
          FlSpot(5, 5),
          FlSpot(6, 6),
          FlSpot(7, 7),
          FlSpot(8, 8),
          FlSpot(9, 9),
        ],
      );

      final w = windowBars([gappy], minX: 5, maxX: 6, chartMinY: -1000);

      // Two real samples before the window (1 and 2) are kept even though a
      // gap sits between them; the gaps travel along unchanged.
      expect(w.offsets, [1]);
      expect(w.bars.single.spots.first, const FlSpot(1, 1));
      expect(w.bars.single.spots.last, const FlSpot(8, 8));
    });

    test('leaves a bar that is not ordered by x untouched', () {
      // A shape that doubles back in x (a closed band) cannot be trimmed by
      // cutting a prefix and suffix without changing its outline.
      final band = _bar([0, 10, 20, 30, 20, 10, 0]);

      final w = windowBars([band], minX: 12, maxX: 18, chartMinY: -1000);

      expect(identical(w.bars.single, band), isTrue);
      expect(w.offsets, [0]);
    });

    test('returns a bar that already fits the window as the same instance', () {
      final w = windowBars([ramp], minX: -10, maxX: 200, chartMinY: -1000);

      expect(identical(w.bars.single, ramp), isTrue);
      expect(w.offsets, [0]);
    });

    test('keeps the tail of a bar that ends before the window', () {
      final early = _bar([0, 1, 2, 3, 4]);

      final w = windowBars([early], minX: 50, maxX: 60, chartMinY: -1000);

      expect(_xs(w.bars.single), [3, 4]);
      expect(w.offsets, [3]);
    });

    test('passes an empty bar through', () {
      final empty = LineChartBarData(spots: const []);

      final w = windowBars([empty], minX: 0, maxX: 1, chartMinY: -1000);

      expect(identical(w.bars.single, empty), isTrue);
      expect(w.offsets, [0]);
    });

    test('windows every bar independently and preserves bar order', () {
      final a = _bar([for (var i = 0; i <= 100; i++) i.toDouble()]);
      final b = _bar([for (var i = 0; i <= 100; i += 10) i.toDouble()]);

      final w = windowBars([a, b], minX: 40, maxX: 50, chartMinY: -1000);

      expect(w.bars, hasLength(2));
      expect(w.offsets, [38, 2]);
      expect(_xs(w.bars[1]), [20, 30, 40, 50, 60, 70]);
    });
  });

  group('windowBars straight spans', () {
    // A straight, dot-less series can be cut exactly: its segments crossing
    // the window edges are clipped to them, so even a two-point span over
    // the whole dive (the O2 cell rug) stays about one window wide.
    LineChartBarData straight(List<FlSpot> spots) =>
        LineChartBarData(spots: spots, dotData: const FlDotData(show: false));

    test('clips a two-point span that brackets the window to its edges', () {
      final rug = straight(const [FlSpot(0, 7), FlSpot(100, 7)]);

      final w = windowBars([rug], minX: 40, maxX: 50, chartMinY: -1000);

      expect(w.bars.single.spots, const [FlSpot(40, 7), FlSpot(50, 7)]);
      expect(w.offsets, [0]);
    });

    test('clips the segments crossing each edge on their own line', () {
      final line = straight([
        for (var i = 0; i <= 100; i += 10) FlSpot(i.toDouble(), i * 2.0),
      ]);

      final w = windowBars([line], minX: 42, maxX: 58, chartMinY: -1000);

      final spots = w.bars.single.spots;
      expect(spots.first.x, 42);
      expect(spots.first.y, closeTo(84, 1e-9));
      expect(spots[1], const FlSpot(50, 100));
      expect(spots.last.x, 58);
      expect(spots.last.y, closeTo(116, 1e-9));
      expect(spots, hasLength(3));
      expect(w.offsets, [4]);
    });

    test('keeps a neighbour whose segment is broken by a gap', () {
      final gappy = straight(const [
        FlSpot(0, 0),
        FlSpot(30, 30),
        FlSpot.nullSpot,
        FlSpot(45, 45),
        FlSpot(60, 60),
      ]);

      final w = windowBars([gappy], minX: 40, maxX: 50, chartMinY: -1000);

      // No line joins 30 to 45, so 30 must not be dragged to the edge.
      expect(w.bars.single.spots.first, const FlSpot(30, 30));
      expect(w.bars.single.spots.last, const FlSpot(50, 50));
    });

    test('leaves points alone on a series that draws its dots', () {
      final dotted = LineChartBarData(
        spots: const [FlSpot(0, 7), FlSpot(100, 7)],
      );

      final w = windowBars([dotted], minX: 40, maxX: 50, chartMinY: -1000);

      expect(identical(w.bars.single, dotted), isTrue);
    });

    test('leaves points alone on a curved series', () {
      final curved = LineChartBarData(
        spots: const [FlSpot(0, 7), FlSpot(100, 7)],
        isCurved: true,
        dotData: const FlDotData(show: false),
      );

      final w = windowBars([curved], minX: 40, maxX: 50, chartMinY: -1000);

      expect(identical(w.bars.single, curved), isTrue);
    });
  });

  group('windowBars fill gradient', () {
    // fl_chart sizes a below-area gradient to the bar's own bounds: its most
    // left/right spots across, and from its topmost spot down to the chart's
    // minY. Cutting the bar moves those bounds, so the gradient is remapped to
    // keep every colour at the same place on the chart.
    LineChartBarData filled(List<FlSpot> spots) => LineChartBarData(
      spots: spots,
      belowBarData: BarAreaData(
        show: true,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x0D0000FF), Color(0x4D0000FF)],
        ),
      ),
    );

    // Depth is plotted negative: y 0 is the surface, -50 the deepest sample.
    final dive = filled([
      for (var i = 0; i <= 100; i++)
        FlSpot(i.toDouble(), i <= 50 ? -i.toDouble() : -(100 - i).toDouble()),
    ]);

    test('keeps the gradient on the same depths after a cut', () {
      // Window 38..42 keeps spots 36..44: topmost y is -36, not 0.
      final w = windowBars([dive], minX: 38, maxX: 42, chartMinY: -60);

      final g = w.bars.single.belowBarData.gradient! as LinearGradient;
      final begin = g.begin as Alignment;
      final end = g.end as Alignment;
      // Source rect runs y 0 (top) to -60 (bottom); the cut rect runs -36 to
      // -60. y 0 sits 36 above the cut top on a 24-tall rect: 2*36/24 = 3
      // half-heights above its top edge.
      expect(begin.y, closeTo(-4, 1e-9));
      expect(end.y, closeTo(1, 1e-9));
      // Both ends stay in one column, so the gradient stays vertical.
      expect(begin.x, closeTo(end.x, 1e-9));
      expect(g.colors, (dive.belowBarData.gradient! as LinearGradient).colors);
    });

    test('leaves the gradient alone when the bar is not cut', () {
      final w = windowBars([dive], minX: -10, maxX: 200, chartMinY: -60);

      expect(identical(w.bars.single, dive), isTrue);
    });

    test('leaves a solid-colour fill alone', () {
      final solid = LineChartBarData(
        spots: [for (var i = 0; i <= 100; i++) FlSpot(i.toDouble(), -1)],
        belowBarData: BarAreaData(show: true, color: const Color(0xFF0000FF)),
      );

      final w = windowBars([solid], minX: 40, maxX: 50, chartMinY: -60);

      expect(w.bars.single.belowBarData.gradient, isNull);
      expect(w.bars.single.belowBarData.color, const Color(0xFF0000FF));
    });
  });

  group('snappedBarWindow', () {
    test('contains the requested window', () {
      final s = snappedBarWindow(minX: 13.3, width: 10);

      expect(s.minX, lessThanOrEqualTo(13.3));
      expect(s.maxX, greaterThanOrEqualTo(23.3));
    });

    test('grows the window by at most a quarter of its width', () {
      final s = snappedBarWindow(minX: 13.3, width: 10);

      expect(s.maxX - s.minX, lessThanOrEqualTo(10 * 1.25 + 1e-9));
    });

    test('is stable while a pan stays inside one eighth-window step', () {
      // Width 10 -> step 1.25; both windows start inside [12.5, 13.75).
      final a = snappedBarWindow(minX: 12.6, width: 10);
      final b = snappedBarWindow(minX: 13.7, width: 10);

      expect(b.minX, a.minX);
    });

    test('moves once a pan crosses an eighth-window step', () {
      final a = snappedBarWindow(minX: 12.6, width: 10);
      final b = snappedBarWindow(minX: 13.8, width: 10);

      expect(b.minX, greaterThan(a.minX));
    });
  });
}
