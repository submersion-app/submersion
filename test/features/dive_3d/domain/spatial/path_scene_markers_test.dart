import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/spatial/path_scene_markers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

const _points = [
  ReckonedPoint(east: 0, north: 0, depth: 2, timeSeconds: 0),
  ReckonedPoint(east: 10, north: 5, depth: 20, timeSeconds: 60),
  ReckonedPoint(east: 20, north: 15, depth: 34, timeSeconds: 120),
  ReckonedPoint(east: 25, north: 20, depth: 5, timeSeconds: 180),
];

ReckonedPath _path({List<PathMarker> markers = const []}) => ReckonedPath(
  points: _points,
  provenance: PathProvenance.measured,
  minEast: 0,
  maxEast: 25,
  minNorth: 0,
  maxNorth: 20,
  maxDepth: 34,
  durationSeconds: 180,
  markers: markers,
);

/// A route's device markers in the 3D terrain views (issue #4231).
void main() {
  final projection = SpatialProjection(
    minEast: -5,
    maxEast: 30,
    minNorth: -5,
    maxNorth: 25,
    maxDepth: 40,
  );

  group('pathSceneMarkers', () {
    test('puts each marker on its own sample of the ribbon', () {
      final markers = pathSceneMarkers(
        _path(markers: const [PathMarker(pointIndex: 2, label: '1')]),
        projection,
      );

      final marker = markers.single;
      expect(marker.kind, SceneMarkerKind.bookmark);
      expect(marker.label, '1');
      expect(marker.refId, isNull);
      expect(marker.x, projection.xOf(20));
      expect(marker.z, projection.zOf(15));
      // Floats just above the line at its depth.
      expect(marker.y, greaterThan(projection.yOf(34)));
      expect(marker.timestampSeconds, 120);
    });

    test('leaves out a marker that points past the samples', () {
      final markers = pathSceneMarkers(
        _path(
          markers: const [
            PathMarker(pointIndex: 1, label: '1'),
            PathMarker(pointIndex: 9, label: '2'),
            PathMarker(pointIndex: -1, label: '3'),
          ],
        ),
        projection,
      );

      expect(markers.map((m) => m.label), ['1']);
    });

    test('a path without markers gives none', () {
      expect(pathSceneMarkers(_path(), projection), isEmpty);
    });
  });

  test('offsetting a path into a shared frame keeps its markers', () {
    const markers = [PathMarker(pointIndex: 2, label: '1')];

    final moved = offsetReckonedPath(_path(markers: markers), (
      east: 100,
      north: -50,
    ));

    expect(moved.markers, markers);
    expect(moved.points[2].east, 120);
  });

  test('the dive and track terrain view shows the route\'s markers', () {
    final scene = const SpatialGeometryService().build(
      _path(markers: const [PathMarker(pointIndex: 2, label: '1')]),
    );

    expect(
      scene.markers.where((m) => m.kind == SceneMarkerKind.bookmark),
      hasLength(1),
    );
    expect(scene.markers.single.label, '1');
  });
}
