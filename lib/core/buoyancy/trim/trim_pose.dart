/// How the diver holds their arms and legs for the trim figure (issue
/// #5028). Pose moves the weight of the limbs and of anything on them, so it
/// changes trim without changing what is carried.
class TrimPose {
  /// The pose clamped into range: [armReach] 0 to 1, [kneeBendDeg] 0 to 90.
  factory TrimPose({required double armReach, required double kneeBendDeg}) =>
      TrimPose._(armReach.clamp(0.0, 1.0), kneeBendDeg.clamp(0.0, 90.0));

  const TrimPose._(this.armReach, this.kneeBendDeg);

  /// The classic horizontal trim position: hands together under the chest,
  /// knees bent so the fins sit up behind.
  static const TrimPose standard = TrimPose._(0.5, 90);

  /// 0 is arms along the sides, 0.5 hands hanging under the chest, 1 arms
  /// straight out ahead.
  final double armReach;

  /// 0 is legs straight, 90 is shins pointing straight up behind.
  final double kneeBendDeg;

  TrimPose copyWith({double? armReach, double? kneeBendDeg}) => TrimPose(
    armReach: armReach ?? this.armReach,
    kneeBendDeg: kneeBendDeg ?? this.kneeBendDeg,
  );

  @override
  bool operator ==(Object other) =>
      other is TrimPose &&
      other.armReach == armReach &&
      other.kneeBendDeg == kneeBendDeg;

  @override
  int get hashCode => Object.hash(armReach, kneeBendDeg);
}
