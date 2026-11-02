import 'dart:math' as math;

import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

/// Below this distance between the dive's start and its farthest point, the
/// scale handle is not offered: a small movement would change the scale too
/// sharply to control. The stepper still works.
const double minScaleHandleDistanceMeters = 10;

/// The sample the scale handle sits on: the one in `start..end` farthest from
/// the sample at [start], or null when that is under
/// [minScaleHandleDistanceMeters].
///
/// Reads raw positions: neither rotation nor a uniform scale can change which
/// sample is farthest, so the index holds still for a whole drag.
int? scaleHandleIndex(
  List<NavTrackPoint> points, {
  required int start,
  required int end,
}) {
  if (points.isEmpty) return null;
  final pivot = points[start];
  var farthest = start;
  var farthestSquared = 0.0;
  for (var i = start + 1; i <= end; i++) {
    final dNorth = points[i].north - pivot.north;
    final dEast = points[i].east - pivot.east;
    final squared = dNorth * dNorth + dEast * dEast;
    if (squared > farthestSquared) {
      farthest = i;
      farthestSquared = squared;
    }
  }
  return math.sqrt(farthestSquared) >= minScaleHandleDistanceMeters
      ? farthest
      : null;
}

/// The scale a handle drag asks for: the scale held at the press, times how
/// much farther from the pivot the pointer now is than it was then.
///
/// A ratio from the press rather than per-frame steps, so a long drag cannot
/// drift. Clamped to the correction's range, which also keeps a pointer that
/// crosses the pivot from flipping the track, and rounded to 0.1%.
double scaleFromDrag({
  required double pressScale,
  required double pressDistance,
  required double currentDistance,
}) {
  if (pressDistance <= 0) return pressScale;
  final scale = (pressScale * currentDistance / pressDistance).clamp(
    NavTrackCorrection.minScaleFactor,
    NavTrackCorrection.maxScaleFactor,
  );
  return (scale * 1000).round() / 1000;
}
