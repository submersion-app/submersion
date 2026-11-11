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

  group('zoomOutProgress', () {
    test(
      'runs with the squash and slide, done as the plot reaches the top',
      () {
        expect(zoomOutProgress(card: cardAt(10), plotAtTop: 150), 0);
        expect(zoomOutProgress(card: cardAt(-75), plotAtTop: 150), 0.5);
        expect(zoomOutProgress(card: cardAt(-150), plotAtTop: 150), 1);
        expect(zoomOutProgress(card: cardAt(-400), plotAtTop: 150), 1);
      },
    );

    test('is done at once when the plot starts at the top', () {
      expect(zoomOutProgress(card: cardAt(-1), plotAtTop: 0), 1);
    });
  });

  group('condenseFadeEnd', () {
    // Past the moment the plot reaches the top, the card slides its plot out
    // of view; the full chart must be gone by then, so no data leaves the
    // view, and the strip carries the line on.
    test('is where the plot reaches the top, as a share of the hand-over', () {
      // Starts 30 px in, plot at the top 150 px in, 456 - 30 - 56 = 370 px
      // of hand-over: the fade takes the first 120 of them.
      expect(
        condenseFadeEnd(start: 30, plotAtTop: 150, cardHeight: 456),
        closeTo(120 / 370, 1e-9),
      );
    });

    test('stays within the hand-over', () {
      expect(condenseFadeEnd(start: 30, plotAtTop: 20, cardHeight: 456), 0);
      expect(condenseFadeEnd(start: 30, plotAtTop: 900, cardHeight: 456), 1);
      expect(condenseFadeEnd(start: 30, plotAtTop: 150, cardHeight: 80), 1);
    });
  });

  test('the hand-over starts early in the card\'s motion', () {
    expect(kHandOverOverlap, lessThanOrEqualTo(0.25));
  });

  group('two-phase condense', () {
    const fadeEnd = 0.4;

    test('the background fades in first, while the shape holds still', () {
      expect(condenseBackgroundOpacity(0, fadeEnd: fadeEnd), 0);
      expect(condenseBackgroundOpacity(0.2, fadeEnd: fadeEnd), 0.5);
      expect(condenseBackgroundOpacity(fadeEnd, fadeEnd: fadeEnd), 1);
      expect(condenseMorphProgress(fadeEnd, fadeEnd: fadeEnd), 0);
    });

    test('the shape morphs only once the background is opaque', () {
      expect(condenseMorphProgress(0, fadeEnd: fadeEnd), 0);
      expect(condenseMorphProgress(1, fadeEnd: fadeEnd), 1);
      final mid = condenseMorphProgress(0.7, fadeEnd: fadeEnd);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));
    });

    test('a fade that takes no scroll is already done', () {
      expect(condenseBackgroundOpacity(0, fadeEnd: 0), 1);
      expect(condenseMorphProgress(0.5, fadeEnd: 0), closeTo(0.5, 1e-9));
    });

    test('a fade that takes the whole hand-over leaves no morph', () {
      expect(condenseMorphProgress(0.99, fadeEnd: 1), 0);
      expect(condenseMorphProgress(1, fadeEnd: 1), 1);
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

    test('keptInView moves a plot above the top down onto it', () {
      final above = chart.shift(const Offset(0, -130));
      final kept = above.keptInView();
      expect(kept.rect.top, 0);
      expect(kept.rect.height, above.rect.height);
      expect(kept.rect.left, above.rect.left);
      expect(kept.maxDepthMeters, 33);
      expect(chart.keptInView(), chart);
    });

    test('shift moves the rect and keeps the ranges', () {
      final moved = chart.shift(const Offset(-40, -100));
      expect(moved.project(0, 0), Offset.zero);
      expect(moved.maxSeconds, 3000);
    });
  });
}
