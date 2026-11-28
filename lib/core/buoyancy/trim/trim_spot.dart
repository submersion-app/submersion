import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';

/// Which side of the diver an element sits on, for roll.
enum TrimLateral { centre, left, right }

/// The places on the diver where weight is carried (issue #5028).
///
/// Torso spots are fractions of height along the body ([_s]) and toward the
/// back ([_z]); limb spots ride their segment and move with the pose. A
/// sided spot has a lateral offset ([_lateral], fraction of height) that a
/// left or right element takes; a centred spot ignores the side.
enum TrimSpot {
  head(TrimSegment.torso, 0.06, 0.02),
  mouth(TrimSegment.torso, 0.10, -0.04),
  chest(TrimSegment.torso, 0.27, -0.07),
  chestClip(TrimSegment.torso, 0.24, -0.06, lateral: 0.08),
  upperBack(TrimSegment.torso, 0.16, 0.14),
  backTank(TrimSegment.torso, 0.33, 0.12),
  // Wing gas centres at mid-back, ahead of the float point.
  wing(TrimSegment.torso, 0.31, 0.09),
  trimPockets(TrimSegment.torso, 0.25, 0.09, lateral: 0.05),
  backplate(TrimSegment.torso, 0.30, 0.07),
  buttDRing(TrimSegment.torso, 0.47, 0.06),
  // Belt pockets sit toward the hips, so a belt weight can take a side.
  waist(TrimSegment.torso, 0.43, -0.05, lateral: 0.08),
  hipPockets(TrimSegment.torso, 0.45, -0.02, lateral: 0.10),
  sidemount(TrimSegment.torso, 0.38, -0.02, lateral: 0.13),
  stageClip(TrimSegment.torso, 0.36, -0.08, lateral: 0.12),
  console(TrimSegment.torso, 0.31, -0.08, lateral: 0.07),
  thigh(TrimSegment.torso, 0.59, -0.03, lateral: 0.06),
  calf(TrimSegment.shin, 0.5, 0, lateral: 0.06),
  ankles(TrimSegment.shin, 0.95, 0, lateral: 0.05),
  feet(TrimSegment.foot, 0.5, 0),
  fins(TrimSegment.foot, 1.6, 0),
  hand(TrimSegment.arm, 0, 0, lateral: 0.11),
  wrist(TrimSegment.arm, 0, 0, lateral: 0.11),
  cameraArm(TrimSegment.arm, 0, 0, lateral: 0.11),
  floatPoint(TrimSegment.torso, 0, 0);

  const TrimSpot(this.segment, this._s, this._z, {double lateral = 0})
    : _lateral = lateral;

  final TrimSegment segment;

  /// Torso spots: fraction of height from the crown. Shin and foot spots:
  /// fraction of that segment's length from its joint (a fin's blade
  /// reaches past the toes).
  final double _s;
  final double _z;
  final double _lateral;

  /// Whether a left or right element here sits off the centre line.
  bool get sided => _lateral > 0;

  /// The lateral offset, metres, of a sided element here.
  double lateralM(TrimBody body) => _lateral * body.heightM;

  /// Where this spot is on [body] in [pose].
  TrimPoint pointOn(TrimBody body, TrimPose pose) => switch (this) {
    floatPoint => body.floatPoint,
    hand || cameraArm => body.hand(pose),
    wrist => body.alongArm(pose, TrimBody.wristFromShoulder),
    calf || ankles => body.alongShin(pose, _s),
    feet || fins => body.alongFoot(pose, _s),
    _ => TrimPoint(_s * body.heightM, _z * body.heightM),
  };
}
