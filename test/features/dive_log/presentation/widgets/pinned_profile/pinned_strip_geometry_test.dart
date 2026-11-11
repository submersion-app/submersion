import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';

void main() {
  group('condenseProgress', () {
    test('is 0 with the card bottom well below the strip', () {
      expect(condenseProgress(cardBottom: 500), 0);
      expect(
        condenseProgress(cardBottom: kPinnedStripHeight + kCondenseWindow),
        0,
      );
    });

    test('is 1 once the bottom passes the strip', () {
      expect(condenseProgress(cardBottom: kPinnedStripHeight), 1);
      expect(condenseProgress(cardBottom: -10), 1);
    });

    test('is linear in the window', () {
      expect(
        condenseProgress(cardBottom: kPinnedStripHeight + kCondenseWindow / 2),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('condenseRect', () {
    const card = Rect.fromLTRB(16, -200, 384, 150);

    test('at t=0 is the visible part of the card', () {
      expect(
        condenseRect(card: card, width: 400, t: 0),
        const Rect.fromLTRB(16, 0, 384, 150),
      );
    });

    test('at t=1 is the full-width strip', () {
      expect(
        condenseRect(card: card, width: 400, t: 1),
        const Rect.fromLTWH(0, 0, 400, kPinnedStripHeight),
      );
    });

    test('at t=0.5 is halfway, with the top clamped to 0', () {
      final r = condenseRect(card: card, width: 400, t: 0.5);
      expect(r.left, 8);
      expect(r.top, 0);
      expect(r.right, 392);
      expect(r.bottom, closeTo((150 + kPinnedStripHeight) / 2, 1e-9));
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
