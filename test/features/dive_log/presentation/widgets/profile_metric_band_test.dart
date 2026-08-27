import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_band.dart';

void main() {
  group('MetricBand', () {
    test('full band spans the whole depth axis', () {
      const band = MetricBand(top: 0, span: 40);

      expect(band.map(0, 0, 100), 40); // minimum sits at the bottom
      expect(band.map(100, 0, 100), 0); // maximum sits at the top
      expect(band.map(50, 0, 100), 20); // midpoint in the middle
    });

    test('an offset band keeps every mapped value inside itself', () {
      // The visible window when zoomed 2x and panned to the deeper half.
      const band = MetricBand(top: 20, span: 20);

      for (var v = 0.0; v <= 100; v += 5) {
        final depth = band.map(v, 0, 100);
        expect(depth, greaterThanOrEqualTo(band.top));
        expect(depth, lessThanOrEqualTo(band.top + band.span));
      }
      expect(band.map(100, 0, 100), 20); // top edge of the band, not 0
      expect(band.map(0, 0, 100), 40);
    });

    test('a zero-width value range collapses to the band midpoint', () {
      // A constant series would otherwise compute (v - min) / 0 = NaN, which
      // crashes fl_chart's tooltip painter. See flat-tank-pressure-nan-offset.
      const band = MetricBand(top: 10, span: 20);

      final depth = band.map(5, 5, 5);
      expect(depth, 20);
      expect(depth.isNaN, isFalse);
    });

    test('mapNormalized places 1 at the top edge and 0 at the bottom', () {
      const band = MetricBand(top: 12, span: 30);

      expect(band.mapNormalized(1), 12);
      expect(band.mapNormalized(0), 42);
      expect(band.mapNormalized(0.5), 27);
    });

    test('unmap inverts map so axis labels match the line', () {
      const band = MetricBand(top: 8, span: 24);

      for (final value in [0.0, 0.21, 1.0, 1.6, 2.0]) {
        final depth = band.map(value, 0, 2);
        expect(band.unmap(depth, 0, 2), closeTo(value, 1e-9));
      }
    });

    test('a zero-height band stays finite', () {
      // A profile that never leaves the surface gives a depth axis of zero
      // height. A NaN escaping here would reach fl_chart's painter.
      final band = MetricBand.full(0);

      expect(band.span, 0);
      expect(band.map(1.5, 0, 2), 0);
      expect(band.map(1.5, 0, 2).isNaN, isFalse);
      expect(band.mapNormalized(0.5).isNaN, isFalse);
      expect(band.unmap(0, 0, 2), 0);
      expect(band.unmap(0, 0, 2).isNaN, isFalse);
    });

    test('equal bands share a hash code', () {
      const a = MetricBand(top: 4, span: 16);
      const b = MetricBand(top: 4, span: 16);
      const different = MetricBand(top: 4, span: 8);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(different));
    });

    test('cache keys agree for equal bands and differ for unequal ones', () {
      // The chart folds cacheKey into its bar-cache signatures. Equal bands
      // must agree or the cache would rebuild every frame; unequal bands must
      // differ or the cache would serve stale bars - the off-screen-metric bug
      // again, through the cache. Unlike a hash this admits no collisions, so
      // the inequality is a real guarantee and not a probabilistic one.
      const a = MetricBand(top: 4, span: 16);
      const b = MetricBand(top: 4, span: 16);

      expect(a.cacheKey, b.cacheKey);
      expect(a.cacheKey, isNot(const MetricBand(top: 4, span: 8).cacheKey));
      expect(a.cacheKey, isNot(const MetricBand(top: 8, span: 16).cacheKey));
      // Neither field may be swallowed by the separator.
      expect(
        const MetricBand(top: 1, span: 23).cacheKey,
        isNot(const MetricBand(top: 12, span: 3).cacheKey),
      );
    });

    test('MetricBand.full starts at the surface', () {
      final band = MetricBand.full(40);

      expect(band.top, 0);
      expect(band.span, 40);
      expect(band.map(1, 0, 1), 0);
    });
  });
}
