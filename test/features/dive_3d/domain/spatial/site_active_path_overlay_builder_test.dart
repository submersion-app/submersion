import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_active_path_overlay_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

ReckonedPath _twoPointPath({
  PathProvenance provenance = PathProvenance.measured,
  String? sourceLabel,
}) => ReckonedPath(
  points: const [
    ReckonedPoint(east: 0, north: 0, depth: 0, timeSeconds: 0),
    ReckonedPoint(east: 10, north: 0, depth: 10, timeSeconds: 100),
  ],
  provenance: provenance,
  sourceLabel: sourceLabel,
  minEast: 0,
  maxEast: 10,
  minNorth: 0,
  maxNorth: 0,
  maxDepth: 10,
  durationSeconds: 100,
);

void main() {
  group('buildSiteActivePathOverlay', () {
    final projection = SpatialProjection(
      minEast: -50,
      maxEast: 50,
      minNorth: -50,
      maxNorth: 50,
      maxDepth: 20,
    );

    test('places the scrub path in the SITE projection, not its own', () {
      final overlay = buildSiteActivePathOverlay(
        path: _twoPointPath(sourceLabel: 'Seacraft ENC'),
        anchor: (east: 0.0, north: 0.0),
        projection: projection,
      );

      expect(overlay, isNotNull);
      final scrub = overlay!.scrubPath;
      expect(scrub.normalizedTimes, [0.0, 1.0]);
      // xOf/yOf/zOf of the SITE projection, not a projection fit to the
      // path alone -- this is the whole point of the builder.
      expect(scrub.xs[0], projection.xOf(0));
      expect(scrub.xs[1], projection.xOf(10));
      expect(scrub.ys[1], projection.yOf(10));
      expect(overlay.provenance, PathProvenance.measured);
      expect(overlay.pathSourceLabel, 'Seacraft ENC');
    });

    test('shifts by the anchor before projecting', () {
      final overlay = buildSiteActivePathOverlay(
        path: _twoPointPath(),
        anchor: (east: 100.0, north: 0.0),
        projection: projection,
      );

      expect(overlay!.scrubPath.xs[0], projection.xOf(100));
      expect(overlay.scrubPath.xs[1], projection.xOf(110));
    });

    test('returns null for a path with fewer than two points', () {
      const degenerate = ReckonedPath(
        points: [ReckonedPoint(east: 0, north: 0, depth: 0, timeSeconds: 0)],
        provenance: PathProvenance.deadReckoned,
        minEast: 0,
        maxEast: 0,
        minNorth: 0,
        maxNorth: 0,
        maxDepth: 0,
        durationSeconds: 0,
      );

      final overlay = buildSiteActivePathOverlay(
        path: degenerate,
        anchor: (east: 0.0, north: 0.0),
        projection: projection,
      );

      expect(overlay, isNull);
    });
  });
}
