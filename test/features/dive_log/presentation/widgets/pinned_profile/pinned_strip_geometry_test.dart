import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

void main() {
  // A 456 px card, [top] px from the top of the viewport.
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

  // Issue #4579: the hand-over ran on until the card's bottom reached the
  // strip, a long stretch of mostly empty strip over the rest of the card,
  // and the cards below came into view before it settled. It ends as the
  // plot reaches the top, [end] px past the card's top.
  group('condenseProgress (the hand-over to the strip)', () {
    test('is 0 until it starts', () {
      expect(condenseProgress(card: cardAt(0), start: 30, end: 150), 0);
      expect(condenseProgress(card: cardAt(-30), start: 30, end: 150), 0);
    });

    test('runs linearly from its start to the plot reaching the top', () {
      expect(
        condenseProgress(card: cardAt(-90), start: 30, end: 150),
        closeTo(0.5, 1e-9),
      );
    });

    test('is 1 as the plot reaches the top, whatever is left of the card', () {
      expect(condenseProgress(card: cardAt(-150), start: 30, end: 150), 1);
      // Most of the 456 px card is still on screen, and it is settled.
      expect(cardAt(-150).bottom, greaterThan(300));
      expect(condenseProgress(card: cardAt(-900), start: 30, end: 150), 1);
    });

    test('is done at once when it has no scroll to run over', () {
      expect(condenseProgress(card: cardAt(-31), start: 30, end: 30), 1);
      expect(condenseProgress(card: cardAt(-10), start: 30, end: 30), 0);
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

  // The fade and the morph share the hand-over, so the strip is opaque with
  // room left to change shape before the plot reaches the top.
  test('the fade takes part of the hand-over, leaving the rest to morph', () {
    expect(kCondenseFadeEnd, inExclusiveRange(0, 1));
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

  // The strip's box moves from the chart's plot to its pinned place on the
  // morph, and the painter blends its line inside that box on the same
  // morph. Handed the plot as it stands, the line took the morph twice and
  // lagged the box's edges: a blank border around it (#4579).
  group('morphStartFor', () {
    test('the painter\'s blend of it is the line\'s place on the page', () {
      const start = PlotMapping(
        rect: Rect.fromLTWH(60, 20, 280, 48),
        minSeconds: 0,
        maxSeconds: 600,
        minDepthMeters: 0,
        maxDepthMeters: 18,
      );
      const end = Rect.fromLTWH(4, 4, 392, 64);
      for (final morph in [0.0, 0.3, 0.7, 0.95]) {
        final box = Rect.lerp(
          const Rect.fromLTWH(60, 20, 280, 48),
          const Rect.fromLTWH(4, 0, 392, 72),
          morph,
        )!;
        final own = Rect.fromLTWH(0, 4, box.width, 64);
        final handed = morphStartFor(
          start: start,
          end: end,
          box: box,
          own: own,
          morph: morph,
        );
        final drawn = Rect.lerp(handed.rect, own, morph)!;
        final wanted = Rect.lerp(start.rect, end, morph)!.shift(-box.topLeft);
        for (final (a, b) in [
          (drawn.left, wanted.left),
          (drawn.top, wanted.top),
          (drawn.right, wanted.right),
          (drawn.bottom, wanted.bottom),
        ]) {
          expect(a, closeTo(b, 1e-9), reason: 'morph $morph');
        }
        expect(handed.maxSeconds, 600);
        expect(handed.maxDepthMeters, 18);
      }
    });
  });
}
