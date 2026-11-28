import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/features/trim_calculator/presentation/widgets/trim_space.dart';

/// Where the trim figure's side space lands on the canvas (issue #5028).
///
/// The viewport is fixed, wide enough for every pose (arms reaching ahead
/// with a scooter, knees bent, the full tilt), so the figure keeps its size
/// and place while the diver poses it. The figure tilts about the float
/// point; each limb turns about its joint.
class TrimFigureGeometry {
  TrimFigureGeometry({
    required Rect box,
    required this.body,
    required this.pose,
    required double tiltDeg,
  }) : scale = math.min(
         box.width / viewport.width,
         box.height / viewport.height,
       ),
       _tilt = tiltDeg * math.pi / 180,
       floatPoint = trimSpaceOf(body.floatPoint, body) {
    _origin = Offset(
      box.left + (box.width - viewport.width * scale) / 2,
      box.top + (box.height - viewport.height * scale) / 2,
    );
  }

  static const Rect viewport = Rect.fromLTRB(-130, -40, 420, 240);

  /// Width over height, for sizing the box.
  static double get aspect => viewport.width / viewport.height;

  final TrimBody body;
  final TrimPose pose;
  final double scale;
  final double _tilt;
  final Offset floatPoint;
  late final Offset _origin;

  /// The side-space point [p] (already posed) on the canvas.
  Offset toCanvas(Offset p) {
    final d = p - floatPoint;
    final c = math.cos(_tilt);
    final s = math.sin(_tilt);
    final tilted =
        floatPoint + Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
    return _origin + (tilted - viewport.topLeft) * scale;
  }

  /// Where [spot] is on the posed, tilted figure.
  Offset anchorOf(TrimSpot spot) =>
      toCanvas(trimSpaceOf(spot.pointOn(body, pose), body));

  /// Where [e] is on the posed, tilted figure: its spot, slid along the body
  /// by its shift (a tank moved on its band).
  Offset anchorOfElement(TrimElement e) {
    final p = e.spot.pointOn(body, pose);
    return toCanvas(trimSpaceOf(TrimPoint(p.s + e.shiftM, p.z), body));
  }

  /// Moves [canvas] into tilted side space.
  void enter(Canvas canvas) {
    canvas.translate(_origin.dx, _origin.dy);
    canvas.scale(scale);
    canvas.translate(-viewport.left, -viewport.top);
    canvas.translate(floatPoint.dx, floatPoint.dy);
    canvas.rotate(_tilt);
    canvas.translate(-floatPoint.dx, -floatPoint.dy);
  }

  /// Turns [canvas] (in side space) for pieces of [segment].
  void enterSegment(Canvas canvas, TrimSegment segment) {
    switch (segment) {
      case TrimSegment.torso:
        return;
      case TrimSegment.arm || TrimSegment.farArm:
        _rotateAbout(canvas, kTrimShoulder, -body.segmentAngle(segment, pose));
      case TrimSegment.shin || TrimSegment.farShin:
        _rotateAbout(canvas, kTrimKnee, -body.segmentAngle(segment, pose));
      case TrimSegment.foot || TrimSegment.farFoot:
        final ankle = trimSpaceOf(body.ankle(pose), body);
        canvas.translate(ankle.dx - kTrimAnkle.dx, ankle.dy - kTrimAnkle.dy);
    }
  }

  void _rotateAbout(Canvas canvas, Offset pivot, double angle) {
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.translate(-pivot.dx, -pivot.dy);
  }

  /// The spot in [allowed] nearest the canvas point [p].
  TrimSpot nearestSpot(Offset p, Iterable<TrimSpot> allowed) {
    TrimSpot? best;
    var bestD = double.infinity;
    for (final spot in allowed) {
      final d = (anchorOf(spot) - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = spot;
      }
    }
    return best ?? TrimSpot.floatPoint;
  }
}
