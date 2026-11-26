import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_placement.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';

/// A change that would bring the diver closer to level (spec section 14 B).
enum TrimFixKind {
  /// Carry [TrimFix.kg] less lead: the wing holds that much at the stop.
  lessLead,

  /// Slide the back-mounted tank [TrimFix.metres] along its band (toward
  /// the feet when positive).
  tankHeight,

  /// Fins of about [TrimFix.kg] a pair.
  lighterFins,
  heavierFins,

  /// Move [TrimFix.kg] of lead from [TrimFix.from] to [TrimFix.to].
  moveLead,

  /// Move [TrimFix.kg] of lead from the [TrimFix.fromSide] side to the
  /// other.
  moveAcross,
}

/// One fix and where it leaves the diver.
class TrimFix {
  const TrimFix({
    required this.kind,
    required this.result,
    this.kg,
    this.metres,
    this.from,
    this.to,
    this.fromSide,
  });

  final TrimFixKind kind;
  final TrimResult result;
  final double? kg;
  final double? metres;
  final TrimSpot? from;
  final TrimSpot? to;
  final TrimLateral? fromSide;
}

/// The wing holds at least this much at the stop before carrying less lead
/// is offered: a little either way is ordinary.
const double kTrimOverweightKg = 1.5;

/// How much lead a move may shift, at most.
const double kTrimMaxLeadMoveKg = 2;

/// Up to [max] fixes for [scene] in [pose], in the order instructors try
/// them: total lead, tank height, fins, then moving lead; a roll is fixed by
/// moving lead across. Each one improves on [scene]; an empty list means
/// the diver is level and steady, or nothing offered helps. Lead moves in
/// steps of [leadStepKg] (0.5 kg, or a pound for a diver who weighs in
/// pounds).
List<TrimFix> suggestTrimFixes(
  TrimScene scene,
  TrimPose pose, {
  double leadStepKg = 0.5,
  int max = 3,
}) {
  final now = scene.trimIn(pose);
  final pitchFixes = now.pitch == TrimVerdict.level
      ? const <TrimFix>[]
      : [
          ?_lessLead(scene, pose, now, leadStepKg),
          ?_tankHeight(scene, pose, now),
          ?_fins(scene, pose, now),
          ?_moveLead(scene, pose, now, leadStepKg),
        ];
  final roll = now.roll == RollVerdict.level
      ? null
      : _moveAcross(scene, pose, now, leadStepKg);
  return [...pitchFixes.take(roll == null ? max : max - 1), ?roll];
}

/// Whether [after] is better than [now] on pitch without rolling more.
bool _improvesPitch(TrimResult now, TrimResult after) =>
    after.pitchKgM.abs() < now.pitchKgM.abs() - 0.05 &&
    after.rollKgM.abs() <= now.rollKgM.abs() + 1e-9;

List<double> _steps(double stepKg, double upTo) => [
  for (var k = 1; k * stepKg <= upTo + 1e-9; k++) k * stepKg,
];

Iterable<TrimElement> _lead(TrimScene s) =>
    s.elements.where((e) => e.kind == TrimElementKind.lead && e.sinkKg > 0);

/// The lead in [s], grouped by spot, the spot furthest toward the feet
/// first (toward the head first when [headFirst]).
List<List<TrimElement>> _leadBySpot(
  TrimScene s,
  TrimPose pose, {
  bool headFirst = false,
}) {
  final groups = <TrimSpot, List<TrimElement>>{};
  for (final e in _lead(s)) {
    (groups[e.spot] ??= []).add(e);
  }
  double at(TrimSpot spot) => spot.pointOn(s.body, pose).s;
  final spots = groups.keys.toList()
    ..sort(
      (a, b) => headFirst ? at(a).compareTo(at(b)) : at(b).compareTo(at(a)),
    );
  return [for (final spot in spots) groups[spot]!];
}

/// [kg] taken off [group] in proportion to what each piece weighs, so lead
/// split between left and right pockets comes off both sides alike.
Map<String, double> _takeFrom(List<TrimElement> group, double kg) {
  final total = group.fold(0.0, (sum, e) => sum + e.sinkKg);
  return {for (final e in group) e.id: kg * e.sinkKg / total};
}

double _groupKg(List<TrimElement> group) =>
    group.fold(0.0, (sum, e) => sum + e.sinkKg);

TrimFix? _lessLead(
  TrimScene scene,
  TrimPose pose,
  TrimResult now,
  double stepKg,
) {
  // What the wing holds at the stop, test items included.
  final lift = now.balancingLiftKg;
  final lead = _lead(scene).toList();
  final total = lead.fold(0.0, (sum, e) => sum + e.sinkKg);
  if (lift < kTrimOverweightKg || total <= 0) return null;
  final drop = ((lift.clamp(0, total)) / stepKg).floorToDouble() * stepKg;
  if (drop <= 0) return null;
  // Lead comes off the lowest spot first: the belt before the trim
  // pockets.
  final take = <String, double>{};
  var left = drop;
  for (final group in _leadBySpot(scene, pose)) {
    if (left <= 1e-9) break;
    final t = _groupKg(group) < left ? _groupKg(group) : left;
    take.addAll(_takeFrom(group, t));
    left -= t;
  }
  final after = scene
      .copyWith(
        elements: [
          for (final e in scene.elements)
            if (take[e.id] case final t?)
              e.copyWith(sinkKg: e.sinkKg - t)
            else
              e,
        ],
        modelNetKg: scene.modelNetKg + drop,
      )
      .trimIn(pose);
  return _improvesPitch(now, after)
      ? TrimFix(kind: TrimFixKind.lessLead, result: after, kg: drop)
      : null;
}

TrimFix? _tankHeight(TrimScene scene, TrimPose pose, TrimResult now) {
  bool back(TrimElement e) =>
      e.kind == TrimElementKind.tank && e.spot == TrimSpot.backTank;
  if (!scene.elements.any(back)) return null;
  TrimFix? best;
  for (final m in const [0.05, -0.05, 0.10, -0.10]) {
    final after = scene
        .copyWith(
          elements: [
            for (final e in scene.elements)
              back(e) ? e.copyWith(shiftM: e.shiftM + m) : e,
          ],
        )
        .trimIn(pose);
    if (!_improvesPitch(now, after)) continue;
    final fix = TrimFix(kind: TrimFixKind.tankHeight, result: after, metres: m);
    // The smallest slide that levels the diver, else the one that helps
    // most.
    if (after.pitch == TrimVerdict.level) return fix;
    if (best == null || after.pitchKgM.abs() < best.result.pitchKgM.abs()) {
      best = fix;
    }
  }
  return best;
}

TrimFix? _fins(TrimScene scene, TrimPose pose, TrimResult now) {
  final fins = scene.elements
      .where((e) => e.kind == TrimElementKind.gear && e.spot == TrimSpot.fins)
      .firstOrNull;
  if (fins == null) return null;
  final feetHeavy = now.pitchKgM > 0;
  final target = feetHeavy ? kSplitFinSinkKg : kVentedFinSinkKg;
  if (feetHeavy ? fins.sinkKg <= target + 0.1 : fins.sinkKg >= target - 0.1) {
    return null;
  }
  final after = scene
      .copyWith(
        elements: [
          for (final e in scene.elements)
            identical(e, fins) ? e.copyWith(sinkKg: target) : e,
        ],
      )
      .trimIn(pose);
  return _improvesPitch(now, after)
      ? TrimFix(
          kind: feetHeavy ? TrimFixKind.lighterFins : TrimFixKind.heavierFins,
          result: after,
          kg: target,
        )
      : null;
}

TrimFix? _moveLead(
  TrimScene scene,
  TrimPose pose,
  TrimResult now,
  double stepKg,
) {
  final feetHeavy = now.pitchKgM > 0;
  final to = feetHeavy ? TrimSpot.trimPockets : TrimSpot.hipPockets;
  final float = scene.body.floatPoint.s;
  final toS = to.pointOn(scene.body, pose).s - float;
  // The lead at the spot furthest out on the heavy end, beyond the target.
  final source = _leadBySpot(scene, pose, headFirst: !feetHeavy).where((g) {
    final at = g.first.spot.pointOn(scene.body, pose).s - float;
    return g.first.spot != to && (feetHeavy ? at > toS : at < toS);
  }).firstOrNull;
  if (source == null) return null;
  final available = _groupKg(source);
  TrimFix? best;
  for (final kg in _steps(
    stepKg,
    available < kTrimMaxLeadMoveKg ? available : kTrimMaxLeadMoveKg,
  )) {
    final take = _takeFrom(source, kg);
    final after = scene
        .copyWith(
          elements: [
            for (final e in scene.elements)
              if (take[e.id] case final t?)
                e.copyWith(sinkKg: e.sinkKg - t)
              else
                e,
            TrimElement(
              id: 'fix:moved',
              label: '',
              kind: TrimElementKind.lead,
              sinkKg: kg,
              spot: to,
            ),
          ],
        )
        .trimIn(pose);
    if (!_improvesPitch(now, after)) continue;
    final fix = TrimFix(
      kind: TrimFixKind.moveLead,
      result: after,
      kg: kg,
      from: source.first.spot,
      to: to,
    );
    if (after.pitch == TrimVerdict.level) return fix;
    if (best == null || after.pitchKgM.abs() < best.result.pitchKgM.abs()) {
      best = fix;
    }
  }
  return best;
}

TrimFix? _moveAcross(
  TrimScene scene,
  TrimPose pose,
  TrimResult now,
  double stepKg,
) {
  final heavy = now.rollKgM > 0 ? TrimLateral.right : TrimLateral.left;
  final other = heavy == TrimLateral.right
      ? TrimLateral.left
      : TrimLateral.right;
  final source = _lead(scene)
      .where((e) => e.spot.sided && e.lateral == heavy)
      .fold<TrimElement?>(
        null,
        (best, e) => best == null || e.sinkKg > best.sinkKg ? e : best,
      );
  if (source == null) return null;
  TrimFix? best;
  for (final kg in _steps(stepKg, source.sinkKg)) {
    final after = scene
        .copyWith(
          elements: [
            for (final e in scene.elements)
              identical(e, source) ? e.copyWith(sinkKg: e.sinkKg - kg) : e,
            TrimElement(
              id: 'fix:across',
              label: '',
              kind: TrimElementKind.lead,
              sinkKg: kg,
              spot: source.spot,
              lateral: other,
            ),
          ],
        )
        .trimIn(pose);
    if (after.rollKgM.abs() >= now.rollKgM.abs() - 1e-9) continue;
    final fix = TrimFix(
      kind: TrimFixKind.moveAcross,
      result: after,
      kg: kg,
      from: source.spot,
      fromSide: heavy,
    );
    if (after.roll == RollVerdict.level) return fix;
    best = fix;
  }
  return best;
}
