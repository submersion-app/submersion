import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

void main() {
  group('SpatialProjection.yOf', () {
    test('scales depth by horizScale, not independently to fill the scene '
        'height (regression: with the old formula, yOf(depth) always '
        'normalized whatever the max depth was to fill the full scene '
        'height -- -(depth / maxDepth) * SceneBounds.ySpan -- producing a '
        'huge, incidental vertical exaggeration for any real site, since '
        'horizontal spans run into the thousands of meters while typical '
        'max depths are tens of meters. Copilot review on #1767)', () {
      // A realistic, strongly asymmetric footprint: an 8 km horizontal
      // span (BathymetryResolver.defaultSpanMeters) against a 40 m max
      // depth, typical of a Swiss lake site.
      final proj = SpatialProjection(
        minEast: -4000,
        maxEast: 4000,
        minNorth: -4000,
        maxNorth: 4000,
        maxDepth: 40,
      );

      // horizScale = xSpan / 8000, independently confirmed here rather
      // than trusted, so this test still pins the right number even if
      // horizScale's own formula changes.
      const expectedHorizScale = SceneBounds.xSpan / 8000;
      expect(proj.horizScale, closeTo(expectedHorizScale, 1e-9));

      // The actual assertion: yOf uses that SAME factor.
      expect(proj.yOf(40), closeTo(-40 * expectedHorizScale, 1e-9));
      expect(proj.yOf(10), closeTo(-10 * expectedHorizScale, 1e-9));

      // And explicitly NOT the old, independently-normalized value: the
      // pre-fix formula would put the max depth at exactly -ySpan
      // regardless of the horizontal span.
      expect(proj.yOf(40), isNot(closeTo(-SceneBounds.ySpan, 1e-9)));
    });

    test('X/Y/Z share one real-world scale: a scene floor derived from '
        "yOf(maxDepth) is proportionally tiny next to the terrain's own "
        'horizontal half-extent for a realistic wide-span, shallow site, '
        'exactly the "true to scale" property the fix restores', () {
      final proj = SpatialProjection(
        minEast: -4000,
        maxEast: 4000,
        minNorth: -4000,
        maxNorth: 4000,
        maxDepth: 40,
      );

      final sceneFloor = proj.yOf(proj.maxDepth);
      final horizontalHalfExtent = proj.zHalfExtent;

      // 40 m of depth against an 8 km span is a ratio of exactly 1:200 --
      // the scene floor must reproduce that same ratio against the
      // horizontal half-extent (4000 m), not be pinned to a fixed
      // fraction of the scene box independent of it.
      expect(sceneFloor.abs() / horizontalHalfExtent, closeTo(40 / 4000, 1e-9));
    });
  });
}
