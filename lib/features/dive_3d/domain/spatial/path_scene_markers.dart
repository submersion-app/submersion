import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';

/// Lifts a marker's label above the ribbon it sits on, like the dive
/// scene's own markers (`MarkerLayout`).
const double _markerFloat = 0.4;

/// [path]'s device markers as scene markers on the ribbon, at the sample
/// each one belongs to (issue #4231).
///
/// [path] is the path as drawn, already shifted into the scene's frame, and
/// [projection] the one its ribbon was built with, so a marker sits exactly
/// on the line. A marker pointing past the path's samples is left out.
List<SceneMarker> pathSceneMarkers(
  ReckonedPath path,
  SpatialProjection projection,
) => [
  for (final marker in path.markers)
    if (marker.pointIndex >= 0 && marker.pointIndex < path.points.length)
      _sceneMarker(path.points[marker.pointIndex], marker.label, projection),
];

SceneMarker _sceneMarker(
  ReckonedPoint point,
  String label,
  SpatialProjection projection,
) => SceneMarker(
  kind: SceneMarkerKind.bookmark,
  refId: null,
  label: label,
  x: projection.xOf(point.east),
  y: projection.yOf(point.depth) + _markerFloat,
  z: projection.zOf(point.north),
  timestampSeconds: point.timeSeconds.round(),
);
