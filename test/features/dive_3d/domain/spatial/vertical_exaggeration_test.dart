import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/vertical_exaggeration.dart';

void main() {
  group('computeVerticalExaggeration', () {
    test('a narrow, already-steep site gets no exaggeration', () {
      // 30 m deep against a 60 m-wide span is a 1:2 ratio, well above the
      // 0.35 default target: exaggerating it further would repeat the
      // #1767 failure of overstating narrow sites.
      final e = computeVerticalExaggeration(
        maxDepthMeters: 30,
        narrowSpanMeters: 60,
      );
      expect(e, 1.0);
    });

    test('a wide, shallow site gets exaggerated toward the target ratio', () {
      // 40 m deep against a 4000 m-wide span reads nearly flat at true
      // scale (1:100); exaggeration should bring it toward 0.35 * 4000,
      // i.e. roughly 10x -- but the 8x cap below kicks in first.
      final e = computeVerticalExaggeration(
        maxDepthMeters: 40,
        narrowSpanMeters: 4000,
      );
      expect(e, 8.0); // clamped at maxExaggeration
    });

    test('a moderately wide site lands between the floor and the cap', () {
      // 30 m deep, 300 m-wide footprint (the narrow-lake case from
      // #2141): natural ratio 0.1, target 0.35 -> 3.5x, comfortably
      // inside the default clamp range.
      final e = computeVerticalExaggeration(
        maxDepthMeters: 30,
        narrowSpanMeters: 300,
      );
      expect(e, closeTo(3.5, 1e-9));
    });

    test('a narrow span is floored at 1 meter, never divides by zero', () {
      expect(
        () => computeVerticalExaggeration(
          maxDepthMeters: 10,
          narrowSpanMeters: 0,
        ),
        returnsNormally,
      );
      final e = computeVerticalExaggeration(
        maxDepthMeters: 10,
        narrowSpanMeters: 0,
      );
      // Floored to 1 m, so the natural ratio is 10:1 -- already far
      // steeper than the target, so it gets no exaggeration.
      expect(e, 1.0);
    });

    test('zero depth never exaggerates', () {
      final e = computeVerticalExaggeration(
        maxDepthMeters: 0,
        narrowSpanMeters: 300,
      );
      expect(e, 1.0);
    });

    test('a custom target and cap are honored', () {
      final e = computeVerticalExaggeration(
        maxDepthMeters: 20,
        narrowSpanMeters: 400,
        targetDepthFraction: 0.5,
        maxExaggeration: 20,
      );
      // natural ratio 0.05, target 0.5 -> 10x, under the raised cap.
      expect(e, closeTo(10.0, 1e-9));
    });
  });

  // Copilot review: a stored per-site override reaches the projection
  // straight from settings, so a value that never came from the slider
  // (a corrupted row, or a future/foreign client writing through sync)
  // must not be applied verbatim.
  group('clampManualVerticalExaggeration', () {
    test('a value inside the slider range is returned unchanged', () {
      expect(clampManualVerticalExaggeration(3.5), 3.5);
      expect(
        clampManualVerticalExaggeration(minManualVerticalExaggeration),
        minManualVerticalExaggeration,
      );
      expect(
        clampManualVerticalExaggeration(maxManualVerticalExaggeration),
        maxManualVerticalExaggeration,
      );
    });

    test('a value below true scale is raised to the floor', () {
      // Below 1.0 the terrain would be FLATTER than reality, which no
      // slider position can produce and which reads as a bug, not a
      // preference.
      expect(
        clampManualVerticalExaggeration(0.2),
        minManualVerticalExaggeration,
      );
      expect(clampManualVerticalExaggeration(0), minManualVerticalExaggeration);
      expect(
        clampManualVerticalExaggeration(-4),
        minManualVerticalExaggeration,
      );
    });

    test('a value above the slider maximum is lowered to the cap', () {
      expect(
        clampManualVerticalExaggeration(100),
        maxManualVerticalExaggeration,
      );
      expect(
        clampManualVerticalExaggeration(double.infinity),
        maxManualVerticalExaggeration,
      );
    });

    test('a NaN falls back to true scale rather than propagating', () {
      // num.clamp passes NaN through (every comparison against NaN is
      // false), and depthScale multiplies EVERY vertex: one NaN factor
      // makes the whole mesh unrenderable rather than merely distorted.
      expect(
        clampManualVerticalExaggeration(double.nan),
        minManualVerticalExaggeration,
      );
    });
  });
}
