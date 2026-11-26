import 'package:submersion/core/buoyancy/trim/trim_body.dart';
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';

/// What an element is, for its chip, its colour and whether it adds lift.
enum TrimElementKind { lead, gear, tank, test, limb, lift }

/// One weight on the diver for the trim figure (issue #5028).
class TrimElement {
  const TrimElement({
    required this.id,
    required this.label,
    required this.kind,
    required this.sinkKg,
    required this.spot,
    this.lateral = TrimLateral.centre,
    this.itemId,
    this.weightType,
    this.pieceIds = const [],
    this.color = defaultColor,
    this.spotUnknown = false,
    this.movableTo,
  });

  /// Black, the gear figure's default for most gear.
  static const int defaultColor = 0xFF2A2A2E;

  final String id;
  final String label;
  final TrimElementKind kind;

  /// In-water weight: positive sinks, negative floats.
  final double sinkKg;
  final TrimSpot spot;
  final TrimLateral lateral;

  /// The equipment item this stands for, when it is gear.
  final String? itemId;

  /// A typed weight's placement, which names it when it has no label.
  final WeightType? weightType;

  /// The side-view artwork drawn for it; empty when it is drawn as a chip.
  final List<String> pieceIds;

  /// ARGB for its artwork's item colour, as the gear figure colours it.
  final int color;

  /// A weight with no known placement (mixed, or no type), drawn at the
  /// waist: its chip says so, so the verdict does not look surer than the
  /// log is.
  final bool spotUnknown;

  /// The spots it may be moved to in try-out; null for anywhere (lead and
  /// test items), empty when it stays put.
  final List<TrimSpot>? movableTo;

  TrimElement copyWith({TrimSpot? spot, TrimLateral? lateral}) => TrimElement(
    id: id,
    label: label,
    kind: kind,
    sinkKg: sinkKg,
    spot: spot ?? this.spot,
    lateral: lateral ?? this.lateral,
    itemId: itemId,
    weightType: weightType,
    pieceIds: pieceIds,
    color: color,
    spotUnknown: spotUnknown,
    movableTo: movableTo,
  );
}

enum TrimVerdict {
  level,
  slightlyFeetHeavy,
  feetHeavy,
  slightlyHeadHeavy,
  headHeavy,
}

enum RollVerdict { level, slightlyLeft, left, slightlyRight, right }

/// A pull smaller than this reads as level (kg·m about the float point).
/// Tuned with the reference rigs of the trim design (spec 7.5).
const double kLevelBandKgM = 0.72;

/// Up to this, "slightly"; beyond, heavy.
const double kSlightBandKgM = 1.40;

/// Roll has its own, tighter bands: a diver has no limbs to correct a roll
/// with, and a 2 lb (0.9 kg) difference between sides visibly rolls one
/// (research follow-up A, docs/design/findings/2026-11-26-scuba-trim-research.md).
const double kRollLevelBandKgM = 0.12;
const double kRollSlightBandKgM = 0.30;

/// How far the figure tilts per kg·m of pitch, capped at [kMaxTiltDeg].
const double kTiltDegPerKgM = 10;
const double kMaxTiltDeg = 20;

TrimVerdict verdictForPitch(double kgM) {
  final a = kgM.abs();
  if (a < kLevelBandKgM) return TrimVerdict.level;
  final heavy = a >= kSlightBandKgM;
  if (kgM > 0) {
    return heavy ? TrimVerdict.feetHeavy : TrimVerdict.slightlyFeetHeavy;
  }
  return heavy ? TrimVerdict.headHeavy : TrimVerdict.slightlyHeadHeavy;
}

RollVerdict verdictForRoll(double kgM) {
  final a = kgM.abs();
  if (a < kRollLevelBandKgM) return RollVerdict.level;
  final heavy = a >= kRollSlightBandKgM;
  if (kgM > 0) return heavy ? RollVerdict.right : RollVerdict.slightlyRight;
  return heavy ? RollVerdict.left : RollVerdict.slightlyLeft;
}

/// The diver's pitch and roll about the float point.
class TrimResult {
  const TrimResult({
    required this.pitchKgM,
    required this.rollKgM,
    required this.balancingLiftKg,
  });

  /// Positive is feet-heavy.
  final double pitchKgM;

  /// Positive rolls right.
  final double rollKgM;

  /// The lift that holds an overweighted diver neutral, acting at the BCD.
  final double balancingLiftKg;

  TrimVerdict get pitch => verdictForPitch(pitchKgM);
  RollVerdict get roll => verdictForRoll(rollKgM);

  /// How far the figure is drawn tipped, feet down positive.
  double get tiltDeg =>
      (pitchKgM * kTiltDegPerKgM).clamp(-kMaxTiltDeg, kMaxTiltDeg);
}

/// Sums every element's pull about [body]'s float point in [pose].
///
/// The forces must sum to zero for the moment not to depend on where it is
/// taken. The limbs from [body] count at their centres of mass, and the
/// suit's lift ([suitLiftKg], at this moment) is spread over the body by
/// [TrimBody.suitShares]: neoprene on the legs is what holds a wetsuit
/// diver's legs up. When the
/// diver is heavy ([modelNetKg] below zero, after any test items, which the
/// model never saw), the lift that holds them neutral acts at [liftSpot];
/// whatever is left over (the torso's own buoyancy, the suit, the model's
/// other terms) acts at the float point, with no moment.
TrimResult computeTrim({
  required TrimBody body,
  required TrimPose pose,
  required List<TrimElement> elements,
  required double modelNetKg,
  required TrimSpot liftSpot,
  double suitLiftKg = 0,
  bool shortySuit = false,
  double waterDensity = TrimBody.defaultWaterDensity,
}) {
  final float = body.floatPoint;
  var pitch = 0.0;
  var roll = 0.0;
  var extraSink = 0.0;
  for (final e in elements) {
    final p = e.spot.pointOn(body, pose);
    pitch += e.sinkKg * (p.s - float.s);
    if (e.spot.sided && e.lateral != TrimLateral.centre) {
      final side = e.lateral == TrimLateral.right ? 1.0 : -1.0;
      roll += e.sinkKg * side * e.spot.lateralM(body);
    }
    if (e.kind == TrimElementKind.test) extraSink += e.sinkKg;
  }
  for (final limb in body.limbMasses(pose, waterDensity: waterDensity)) {
    pitch += limb.inWaterKg * (limb.centre.s - float.s);
  }
  for (final (point, share) in body.suitShares(pose, shorty: shortySuit)) {
    pitch -= suitLiftKg * share * (point.s - float.s);
  }
  final lift = extraSink - modelNetKg;
  final liftKg = lift > 0 ? lift : 0.0;
  pitch -= liftKg * (liftSpot.pointOn(body, pose).s - float.s);
  return TrimResult(pitchKgM: pitch, rollKgM: roll, balancingLiftKg: liftKg);
}
