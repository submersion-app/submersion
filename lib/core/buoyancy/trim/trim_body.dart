import 'dart:math' as math;

import 'package:submersion/core/buoyancy/buoyancy_physics.dart';
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';

/// A point on the prone diver, in metres, in the body frame (issue #5028).
///
/// [s] runs along the body from the crown toward the feet in the straight
/// pose; [z] runs toward the back, which is up when the diver lies level.
class TrimPoint {
  const TrimPoint(this.s, this.z);

  final double s;
  final double z;

  TrimPoint operator +(TrimPoint o) => TrimPoint(s + o.s, z + o.z);

  TrimPoint scaled(double k) => TrimPoint(s * k, z * k);

  @override
  String toString() => 'TrimPoint($s, $z)';
}

/// The parts of the figure that move together. The torso carries the head
/// and the thighs (the hip does not bend); the far limbs mirror the near
/// ones.
enum TrimSegment { torso, arm, shin, foot, farArm, farShin, farFoot }

/// One limb part's in-water weight at its centre of mass.
class TrimLimbMass {
  const TrimLimbMass({
    required this.segment,
    required this.centre,
    required this.inWaterKg,
  });

  final TrimSegment segment;
  final TrimPoint centre;

  /// Positive sinks.
  final double inWaterKg;
}

/// Body proportions and limb masses for one diver, from the standard
/// anthropometric tables (Winter, Biomechanics and Motor Control of Human
/// Movement, 4th ed., table 4.1: segment lengths as fractions of height,
/// segment masses as fractions of body mass, centres of mass as fractions of
/// segment length from the proximal joint; densities after Dempster).
class TrimBody {
  factory TrimBody({double? heightCm, double? bodyMassKg, DiverSex? sex}) =>
      TrimBody._(
        (heightCm ?? defaultHeightCm) / 100,
        bodyMassKg ?? BuoyancyPhysics.defaultBodyMassKg,
        sex,
      );

  TrimBody._(this.heightM, this.massKg, this.sex);

  /// The height used when the diver has none on file.
  static const double defaultHeightCm = 175;

  /// Salt water, as the model's reference rigs are tuned in.
  static const double defaultWaterDensity = 1.025;

  // Distances from the crown, as fractions of height (Winter fig. 4.1:
  // shoulder 0.818 H, greater trochanter 0.530 H, knee 0.285 H and ankle
  // 0.039 H above the floor).
  static const double _shoulderFromCrown = 0.182;
  static const double _hipFromCrown = 0.470;
  static const double _kneeFromCrown = 0.715;
  static const double _shinLength = 0.246;
  static const double _footLength = 0.152;
  static const double _upperArmLength = 0.186;
  static const double _forearmLength = 0.146;
  static const double _handLength = 0.108;

  /// Shoulder to wrist, as a fraction of height.
  static const double wristFromShoulder = _upperArmLength + _forearmLength;

  /// Where along the torso, from the shoulder (0) to the hip (1), the diver
  /// floats from: the bare body's measured centre of buoyancy, 0.385 of
  /// height from the crown (Watanabe et al., 9 men, streamline; McLean and
  /// Hinrichs 1998), spec section 14 D.
  static const double kFloatPointTorsoFraction = 0.705;

  /// The measured distance from the centre of mass to the centre of
  /// buoyancy of a bare body lying level, lungs at neutral buoyancy
  /// (Watanabe et al. 2014: 1.93 cm men, 1.36 cm women; their mean when sex
  /// is not on file). Body mass times it is the body's measured feet-down
  /// torque (Pendergast et al. 1977 found 1.44 and 0.70 kg m).
  static double measuredCobOffsetM(DiverSex? sex) => switch (sex) {
    DiverSex.male => 0.0193,
    DiverSex.female => 0.0136,
    null => 0.0165,
  };

  /// The skin each part of a suit covers (Lund-Browder adult chart, no
  /// hood, gloves or boots): torso 42%, arms 17%, thighs 23.5%, shins 17%.
  /// A shorty covers the torso, the upper arms and the upper thighs.
  static const _fullSuit = (
    torso: 0.42,
    arms: 0.17,
    thighs: 0.235,
    shins: 0.17,
  );
  static const _shortySuit = (
    torso: 0.42,
    arms: 0.07,
    thighs: 0.12,
    shins: 0.0,
  );

  // Mass fraction, centre of mass from the proximal joint (fraction of the
  // segment's length), density in kg/L.
  static const _upperArm = (mass: 0.028, com: 0.436, density: 1.07);
  static const _forearm = (mass: 0.016, com: 0.430, density: 1.13);
  static const _hand = (mass: 0.006, com: 0.506, density: 1.16);
  static const _thigh = (mass: 0.100, com: 0.433, density: 1.05);
  static const _shank = (mass: 0.0465, com: 0.433, density: 1.09);
  static const _foot = (mass: 0.0145, com: 0.500, density: 1.10);

  final double heightM;
  final double massKg;

  /// Null when the diver's profile does not say.
  final DiverSex? sex;

  /// The head and torso's own feet-down pull, as a couple: what the measured
  /// body torque leaves once the limbs (counted in [limbMasses]) are taken
  /// out, in the pose and water it was measured in (streamline: arms
  /// overhead, legs straight, fresh water).
  late final double torsoCoupleKgM = () {
    final streamline = TrimPose(armReach: 1, kneeBendDeg: 0);
    final float = floatPoint.s;
    var limbs = 0.0;
    for (final l in limbMasses(streamline, waterDensity: 1.0)) {
      limbs += l.inWaterKg * (l.centre.s - float);
    }
    return massKg * measuredCobOffsetM(sex) - limbs;
  }();

  TrimPoint get shoulder => TrimPoint(_shoulderFromCrown * heightM, 0);
  TrimPoint get hip => TrimPoint(_hipFromCrown * heightM, 0);
  TrimPoint get knee => TrimPoint(_kneeFromCrown * heightM, 0);

  TrimPoint get floatPoint => TrimPoint(
    shoulder.s + kFloatPointTorsoFraction * (hip.s - shoulder.s),
    0,
  );

  /// The absolute angle of [segment] in the body frame, radians,
  /// counterclockwise from +s toward +z.
  double segmentAngle(TrimSegment segment, TrimPose pose) => switch (segment) {
    TrimSegment.torso || TrimSegment.foot || TrimSegment.farFoot => 0,
    // Reach 0 points the arm at the feet, 0.5 straight down, 1 ahead.
    TrimSegment.arm || TrimSegment.farArm => -pose.armReach * math.pi,
    TrimSegment.shin || TrimSegment.farShin => pose.kneeBendDeg * math.pi / 180,
  };

  TrimPoint _along(TrimPoint from, double angle, double lengthFraction) =>
      from +
      TrimPoint(
        math.cos(angle) * lengthFraction * heightM,
        math.sin(angle) * lengthFraction * heightM,
      );

  TrimPoint ankle(TrimPose pose) =>
      _along(knee, segmentAngle(TrimSegment.shin, pose), _shinLength);

  /// The middle of the hand, where hand-held gear sits.
  TrimPoint hand(TrimPose pose) => _along(
    shoulder,
    segmentAngle(TrimSegment.arm, pose),
    _upperArmLength + _forearmLength + _handLength / 2,
  );

  /// A point [fraction] of the way along a limb segment from its joint.
  TrimPoint alongArm(TrimPose pose, double fractionOfHeight) =>
      _along(shoulder, segmentAngle(TrimSegment.arm, pose), fractionOfHeight);

  TrimPoint alongShin(TrimPose pose, double fractionOfShin) => _along(
    knee,
    segmentAngle(TrimSegment.shin, pose),
    _shinLength * fractionOfShin,
  );

  TrimPoint alongFoot(TrimPose pose, double fractionOfFoot) =>
      _along(ankle(pose), 0, _footLength * fractionOfFoot);

  double _inWater(
    ({double mass, double com, double density}) part,
    double waterDensity,
  ) => part.mass * massKg * (1 - waterDensity / part.density);

  /// Every limb part's in-water weight at its centre of mass, both sides.
  List<TrimLimbMass> limbMasses(
    TrimPose pose, {
    double waterDensity = defaultWaterDensity,
  }) {
    final arm = <(TrimPoint, double)>[
      (
        alongArm(pose, _upperArm.com * _upperArmLength),
        _inWater(_upperArm, waterDensity),
      ),
      (
        alongArm(pose, _upperArmLength + _forearm.com * _forearmLength),
        _inWater(_forearm, waterDensity),
      ),
      (
        alongArm(
          pose,
          _upperArmLength + _forearmLength + _hand.com * _handLength,
        ),
        _inWater(_hand, waterDensity),
      ),
    ];
    final thigh = (
      hip + TrimPoint(_thigh.com * (knee.s - hip.s), 0),
      _inWater(_thigh, waterDensity),
    );
    final shin = (alongShin(pose, _shank.com), _inWater(_shank, waterDensity));
    final foot = (alongFoot(pose, _foot.com), _inWater(_foot, waterDensity));
    return [
      for (final side in const [
        (TrimSegment.arm, TrimSegment.shin, TrimSegment.foot),
        (TrimSegment.farArm, TrimSegment.farShin, TrimSegment.farFoot),
      ]) ...[
        for (final (centre, kg) in arm)
          TrimLimbMass(segment: side.$1, centre: centre, inWaterKg: kg),
        TrimLimbMass(
          segment: TrimSegment.torso,
          centre: thigh.$1,
          inWaterKg: thigh.$2,
        ),
        TrimLimbMass(segment: side.$2, centre: shin.$1, inWaterKg: shin.$2),
        TrimLimbMass(segment: side.$3, centre: foot.$1, inWaterKg: foot.$2),
      ],
    ];
  }

  /// Where a suit's lift acts and the share at each place, both sides: each
  /// part's skin coverage times its neoprene thickness, normalised.
  /// [panelsMm] reads as a suit is labelled: the first panel is the torso,
  /// the second the legs, the third the arms, a missing one taking the last
  /// given; none means an even thickness.
  List<(TrimPoint, double)> suitShares(
    TrimPose pose, {
    bool shorty = false,
    List<double> panelsMm = const [],
  }) {
    final cover = shorty ? _shortySuit : _fullSuit;
    double panel(int i) => panelsMm.isEmpty
        ? 1
        : panelsMm[i < panelsMm.length ? i : panelsMm.length - 1];
    final torso = cover.torso * panel(0);
    final arms = cover.arms * panel(2);
    final thighs = cover.thighs * panel(1);
    final shins = cover.shins * panel(1);
    final total = torso + arms + thighs + shins;
    final armAt = shorty
        ? alongArm(pose, _upperArmLength / 2)
        : alongArm(pose, (_upperArmLength + _forearmLength) / 2);
    return [
      (floatPoint, torso / total),
      (armAt, arms / total),
      (hip + TrimPoint((knee.s - hip.s) / 2, 0), thighs / total),
      if (shins > 0) (alongShin(pose, 0.5), shins / total),
    ];
  }
}
