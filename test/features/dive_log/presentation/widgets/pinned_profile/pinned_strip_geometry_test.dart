import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

void main() {
  // A 456 px card: it scrolls out over 456 - 56 = 400 px.
  Rect cardAt(double top) => Rect.fromLTWH(16, top, 368, 456);

  group('condenseProgress', () {
    test('is 0 until the card top reaches the viewport top', () {
      expect(condenseProgress(card: cardAt(120)), 0);
      expect(condenseProgress(card: cardAt(0)), 0);
    });

    test('starts as soon as the card top passes the viewport top', () {
      expect(condenseProgress(card: cardAt(-1)), greaterThan(0));
    });

    test('runs over the whole scroll-out, linearly', () {
      expect(condenseProgress(card: cardAt(-200)), closeTo(0.5, 1e-9));
    });

    test('is 1 once the card bottom reaches the strip', () {
      expect(condenseProgress(card: cardAt(-400)), 1);
      expect(condenseProgress(card: cardAt(-900)), 1);
    });
  });

  group('condenseRect', () {
    test('at the start is exactly the card', () {
      expect(condenseRect(card: cardAt(0), width: 400, t: 0), cardAt(0));
    });

    test('always covers all of the card still on screen', () {
      for (final top in [-50.0, -200.0, -350.0]) {
        final card = cardAt(top);
        final t = condenseProgress(card: card);
        final box = condenseRect(card: card, width: 400, t: t);
        final visible = Rect.fromLTRB(card.left, 0, card.right, card.bottom);
        expect(box.top, 0);
        expect(box.bottom, greaterThanOrEqualTo(visible.bottom));
        expect(box.left, lessThanOrEqualTo(visible.left));
        expect(box.right, greaterThanOrEqualTo(visible.right));
      }
    });

    test('widens to the full width as it condenses', () {
      final card = cardAt(-200);
      final box = condenseRect(card: card, width: 400, t: 0.5);
      expect(box.left, 8);
      expect(box.right, 392);
      expect(box.bottom, card.bottom);
    });

    test('at the end is the full-width strip', () {
      expect(
        condenseRect(card: cardAt(-400), width: 400, t: 1),
        const Rect.fromLTWH(0, 0, 400, kPinnedStripHeight),
      );
    });
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
