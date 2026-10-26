import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

/// The breathing mode in force for [segment] (its per-segment override, or
/// the plan's mode). Models mid-plan bailout.
domain.PlanMode modeFor(domain.DivePlan plan, PlanSegment? segment) =>
    segment?.diveModeOverride ?? plan.mode;

/// Suffix on the id of a flat leg [withDiluentSwitchTime] inserts before a
/// switching segment; no diver authored that leg.
const diluentSwitchStopIdSuffix = '__gasSwitchStop';

/// [segments] (already sorted, already rate-split if #3264 applies) with a
/// new flat leg inserted wherever the dive starts breathing a different
/// diluent than the one before it -- the authored-segment counterpart of
/// the floor the computed ascent's own invented stops get at a real OC
/// switch (#3225, #3263).
///
/// The stop is its own leg, at the depth the switching segment itself
/// starts from (where the previous leg left off), not folded into that
/// segment's own duration: a switching segment can be a rate-split travel
/// leg with its own rate already fixed by the configured descent/ascent
/// rate and the depth it covers (#3264), and stretching its duration in
/// place would silently dilute that rate into a slower blended descent
/// instead of the intended fast-travel-then-flat-stop shape (confirmed: a
/// 5-minute switch time halved the apparent descent rate for the rest of
/// the leg instead of showing as a stop).
///
/// The inserted leg breathes whichever of the two diluents carries more
/// total inert gas (the lower O2 fraction): the diver asked for the
/// decompression math to stay conservative through the switch even when
/// the more efficient gas might already be in use by then, so the stop is
/// costed on whichever gas is worse for that, not on a fixed "old" or
/// "new" convention.
///
/// Only a CCR segment (per-segment dive-mode override honoured) carrying an
/// explicit diluent tank can switch; nothing is added before the first
/// segment, which has no predecessor to switch from, and a non-diluent
/// segment in between (an OC bailout leg, say) does not reset which diluent
/// counts as "previous" -- the last one actually breathed still does.
///
/// [plan]'s tanks must already have their roles resolved (TankRoleResolver
/// applied) -- both PlanEngine.compute and BailoutSolver.solve do this
/// before calling here, so the authored phase and the bailout tissue
/// simulation it shares never disagree about how long a diluent switch
/// actually took.
///
/// [gasSwitchStopSeconds] is the caller's already-resolved value (issue
/// #3552): [plan]'s own value when set, else the diver's Settings default -
/// this function has no [PlanEngineConfig] to resolve it against itself.
List<PlanSegment> withDiluentSwitchTime(
  List<PlanSegment> segments,
  domain.DivePlan plan, {
  required int gasSwitchStopSeconds,
}) {
  if (gasSwitchStopSeconds <= 0) return segments;

  DiveTank? diluentTankFor(PlanSegment segment) {
    if (modeFor(plan, segment) != domain.PlanMode.ccr) return null;
    final tank = plan.tanks.where((t) => t.id == segment.tankId).firstOrNull;
    return tank?.role == TankRole.diluent ? tank : null;
  }

  final result = <PlanSegment>[];
  DiveTank? previousDiluent;
  var depth = 0.0;
  for (final segment in segments) {
    final diluent = diluentTankFor(segment);
    final isSwitch =
        previousDiluent != null &&
        diluent != null &&
        diluent.id != previousDiluent.id;
    if (isSwitch) {
      // Lower O2% carries more total inert gas (He + N2), the conservative
      // side to cost an ambiguous mid-switch stop on.
      final conservative = diluent.gasMix.o2 <= previousDiluent.gasMix.o2
          ? diluent
          : previousDiluent;
      result.add(
        PlanSegment(
          id: '${segment.id}$diluentSwitchStopIdSuffix',
          targetDepth: depth,
          durationSeconds: gasSwitchStopSeconds,
          tankId: conservative.id,
          gasMix: conservative.gasMix,
          diveModeOverride: segment.diveModeOverride,
          order: segment.order,
        ),
      );
    }
    result.add(segment);
    depth = segment.targetDepth;
    previousDiluent = diluent ?? previousDiluent;
  }
  return result;
}
