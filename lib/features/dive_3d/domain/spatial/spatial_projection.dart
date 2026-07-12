import 'dart:math' as math;

import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// Maps a local east-north-up meter frame onto the scene box, preserving
/// horizontal aspect ratio (the larger horizontal span fills xSpan). X =
/// easting, Z = northing, Y = -depth.
class SpatialProjection {
  final double centerEast;
  final double centerNorth;
  final double eastSpan;
  final double northSpan;
  final double horizScale;
  final double maxDepth;

  SpatialProjection({
    required double minEast,
    required double maxEast,
    required double minNorth,
    required double maxNorth,
    required this.maxDepth,
  }) : centerEast = (minEast + maxEast) / 2,
       centerNorth = (minNorth + maxNorth) / 2,
       eastSpan = (maxEast - minEast).abs(),
       northSpan = (maxNorth - minNorth).abs(),
       horizScale =
           SceneBounds.xSpan /
           math.max(
             math.max((maxEast - minEast).abs(), (maxNorth - minNorth).abs()),
             1.0,
           );

  double xOf(double east) =>
      SceneBounds.xSpan / 2 + (east - centerEast) * horizScale;

  double zOf(double north) => (north - centerNorth) * horizScale;

  double yOf(double depth) =>
      maxDepth <= 0 ? 0 : -(depth / maxDepth) * SceneBounds.ySpan;

  /// Half-extent of the projected northing axis (for the scene Z range).
  double get zHalfExtent => (northSpan / 2) * horizScale;
}
