import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

void main() {
  // A 456 px card. The squash takes the first kSquashRange px of its
  // scroll-out; the hand-over to the strip takes the remaining
  // 456 - kSquashRange - 56 px.
  Rect cardAt(double top) => Rect.fromLTWH(16, top, 368, 456);

  group('squashDepth', () {
    test('is 0 until the card top passes the viewport top', () {
      expect(squashDepth(card: cardAt(120)), 0);
      expect(squashDepth(card: cardAt(0)), 0);
    });

    test('follows the scroll, up to the squash range', () {
      expect(squashDepth(card: cardAt(-50)), 50);
      expect(squashDepth(card: cardAt(-400)), kSquashRange);
    });

    // The range is however much the chart's plot can lose and keep
    // kMinPlotHeight: measured, since axes and legends vary.
    test('takes the measured range', () {
      expect(squashDepth(card: cardAt(-400), range: 90), 90);
      expect(slideDepth(card: cardAt(-120), range: 90), 30);
    });

    // One motion, not two: the squash and the slide share the scroll in a
    // fixed ratio, finishing together as the plot reaches the top.
    test('with the plot below the top, squash and slide run together', () {
      // range 90, plot 60 px down: both finish 150 px in.
      const range = 90.0, plotTop = 60.0;
      final third = cardAt(-50);
      expect(
        squashDepth(card: third, range: range, plotTop: plotTop),
        closeTo(30, 1e-9),
      );
      expect(
        slideDepth(card: third, range: range, plotTop: plotTop),
        closeTo(20, 1e-9),
      );
      final done = cardAt(-150);
      expect(squashDepth(card: done, range: range, plotTop: plotTop), 90);
      expect(slideDepth(card: done, range: range, plotTop: plotTop), 60);
      // Past that, the card simply keeps leaving.
      expect(
        slideDepth(card: cardAt(-200), range: range, plotTop: plotTop),
        110,
      );
    });

    test('squashRangeFor leaves the plot at its minimum height', () {
      expect(squashRangeFor(restPlotHeight: 150), 150 - kMinPlotHeight);
      expect(squashRangeFor(restPlotHeight: 30), 0);
    });
  });

  group('condenseProgress (the hand-over to the strip)', () {
    test('is 0 while the card is still squashing', () {
      expect(condenseProgress(card: cardAt(0)), 0);
      expect(condenseProgress(card: cardAt(-kSquashRange)), 0);
    });

    test('runs over the rest of the scroll-out, linearly', () {
      expect(
        condenseProgress(
          card: cardAt(-(kSquashRange + (456 - kSquashRange - 56) / 2)),
        ),
        closeTo(0.5, 1e-9),
      );
    });

    test('is 1 once the card bottom reaches the strip', () {
      expect(condenseProgress(card: cardAt(-400)), 1);
      expect(condenseProgress(card: cardAt(-900)), 1);
    });

    // After the squash the card slides up until its plot reaches the top;
    // the hand-over starts there.
    test('can start later, once the plot reaches the top', () {
      const start = kSquashRange + 60;
      expect(condenseProgress(card: cardAt(-start), start: start), 0);
      // Halfway through the 456 - start - 56 px of hand-over.
      expect(
        condenseProgress(
          card: cardAt(-(start + (456 - start - 56) / 2)),
          start: start,
        ),
        closeTo(0.5, 1e-9),
      );
      expect(condenseProgress(card: cardAt(-400), start: start), 1);
    });
  });

  group('slideDepth', () {
    test('is 0 while the card squashes, then follows the scroll', () {
      expect(slideDepth(card: cardAt(-100)), 0);
      expect(slideDepth(card: cardAt(-(kSquashRange + 30))), 30);
    });
  });

  // The chart's axes, grid and other lines under the strip fade out as the
  // strip fades in; done too quickly, they vanish and leave a large blank
  // strip while its box is still big.
  test('the full chart still shows through well into the hand-over', () {
    expect(condenseBackgroundOpacity(0.3), lessThan(0.75));
    expect(condenseMorphProgress(0.3), 0);
  });

  test('the hand-over starts before the card has finished moving', () {
    expect(kHandOverOverlap, lessThanOrEqualTo(0.45));
  });

  group('two-phase condense', () {
    test('the background fades in first, while the shape holds still', () {
      expect(condenseBackgroundOpacity(0), 0);
      expect(condenseBackgroundOpacity(kCondenseFadePortion / 2), 0.5);
      expect(condenseBackgroundOpacity(kCondenseFadePortion), 1);
      expect(condenseMorphProgress(kCondenseFadePortion), 0);
    });

    test('the shape morphs only once the background is opaque', () {
      expect(condenseMorphProgress(0), 0);
      expect(condenseMorphProgress(1), 1);
      final mid = condenseMorphProgress((1 + kCondenseFadePortion) / 2);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
    });
  });

  group('PlotMapping', () {
    const chart = PlotMapping(
      rect: Rect.fromLTWH(40, 100, 300, 200),
      minSeconds: 0,
      maxSeconds: 3000,
      minDepthMeters: 0,
      maxDepthMeters: 33,
    );
    const strip = PlotMapping(
      rect: Rect.fromLTWH(0, 0, 400, 40),
      minSeconds: 0,
      maxSeconds: 2760,
      minDepthMeters: 0,
      maxDepthMeters: 30,
    );

    test('projects time to x and depth downward to y', () {
      expect(chart.project(0, 0), const Offset(40, 100));
      expect(chart.project(1500, 16.5), const Offset(190, 200));
      expect(chart.project(3000, 33), const Offset(340, 300));
    });

    test('lerp at 0 draws exactly where the chart draws', () {
      final at0 = PlotMapping.lerp(chart, strip, 0);
      for (final (s, d) in [(0, 0.0), (900, 28.0), (2760, 0.0)]) {
        expect(at0.project(s, d), chart.project(s, d));
      }
    });

    test('lerp at 1 draws exactly where the strip draws', () {
      final at1 = PlotMapping.lerp(chart, strip, 1);
      for (final (s, d) in [(0, 0.0), (900, 28.0), (2760, 0.0)]) {
        final a = at1.project(s, d);
        final b = strip.project(s, d);
        expect(a.dx, closeTo(b.dx, 1e-9));
        expect(a.dy, closeTo(b.dy, 1e-9));
      }
    });

    test('shift moves the rect and keeps the ranges', () {
      final moved = chart.shift(const Offset(-40, -100));
      expect(moved.project(0, 0), Offset.zero);
      expect(moved.maxSeconds, 3000);
    });
  });
}
