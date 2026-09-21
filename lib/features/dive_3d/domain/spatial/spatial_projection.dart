import 'dart:math' as math;

import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// Maps a local east-north-up meter frame onto the scene box, preserving
/// horizontal aspect ratio (the larger horizontal span fills xSpan). X =
/// easting, Y = -depth, Z = SOUTHING.
///
/// Z runs south deliberately. SceneProjector is a right-handed camera
/// (x right, y up, z toward the viewer), and east x up = south, so only a
/// south-facing Z makes the scene right-handed too. Pointing Z north
/// instead renders every pose as a mirror image of the real seafloor,
/// which is exactly what issue #1093 reported.
class SpatialProjection {
  final double centerEast;
  final double centerNorth;
  final double eastSpan;
  final double northSpan;
  final double horizScale;
  final double maxDepth;

  /// Auto-computed per site (see [computeVerticalExaggeration]); 1.0
  /// keeps depth true to scale with the horizontal axes.
  final double verticalExaggeration;

  SpatialProjection({
    required double minEast,
    required double maxEast,
    required double minNorth,
    required double maxNorth,
    required this.maxDepth,
    this.verticalExaggeration = 1.0,
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

  double zOf(double north) => -(north - centerNorth) * horizScale;

  /// Inverses of [xOf] and [zOf], for lookups that start from a scene
  /// position and need the ground coordinate under it. [horizScale] is
  /// always positive (its divisor is floored at 1), so no guard is needed.
  double eastAt(double x) =>
      (x - SceneBounds.xSpan / 2) / horizScale + centerEast;

  double northAt(double z) => -z / horizScale + centerNorth;

  /// The depth axis's real-world-to-scene factor: [horizScale], the same
  /// meters-per-unit factor as the horizontal axes, times
  /// [verticalExaggeration]. Anything that lifts geometry a fixed
  /// real-world amount off the terrain (contour ribbons, wall highlights)
  /// must scale by this too, not by [horizScale] alone, so the lift stays
  /// proportional once a site is exaggerated.
  double get depthScale => horizScale * verticalExaggeration;

  /// Depth uses [depthScale] rather than independently stretching to fill
  /// a fixed scene height (issue: depth read as a near-vertical plunge
  /// regardless of how shallow the site actually was, because the old
  /// formula always normalized whatever the max depth was to fill the
  /// full scene height). With [verticalExaggeration] at its default of
  /// 1.0 this is genuinely true to scale; auto-computed exaggeration
  /// (issue #2141) scales depth further for sites that would otherwise
  /// read as flat.
  double yOf(double depth) => -depth * depthScale;

  /// Half-extent of the projected northing axis (for the scene Z range).
  double get zHalfExtent => (northSpan / 2) * horizScale;
}
