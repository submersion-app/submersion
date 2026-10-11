import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

/// The breathing mode in force for [segment] (its per-segment override, or
/// the plan's mode). Models mid-plan bailout.
domain.PlanMode modeFor(domain.DivePlan plan, PlanSegment? segment) =>
    segment?.diveModeOverride ?? plan.mode;

/// [segments] (already sorted) with the configured gas-switch time added to
/// whichever segment starts the dive breathing a different diluent than the
/// one before it -- the authored-segment counterpart of the floor the
/// computed ascent's own invented stops get at a real OC switch (#3225,
/// #3263). The extra time lands entirely inside that segment, at the depth
/// it begins and on the diluent it already breathes, rather than being
/// split out as a leg of its own.
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
List<PlanSegment> withDiluentSwitchTime(
  List<PlanSegment> segments,
  domain.DivePlan plan,
) {
  if (plan.gasSwitchStopSeconds <= 0) return segments;

  String? diluentTankIdFor(PlanSegment segment) {
    if (modeFor(plan, segment) != domain.PlanMode.ccr) return null;
    final tank = plan.tanks.where((t) => t.id == segment.tankId).firstOrNull;
    return tank?.role == TankRole.diluent ? tank!.id : null;
  }

  final result = <PlanSegment>[];
  String? previousDiluentId;
  for (final segment in segments) {
    final diluentId = diluentTankIdFor(segment);
    final isSwitch =
        previousDiluentId != null &&
        diluentId != null &&
        diluentId != previousDiluentId;
    result.add(
      isSwitch
          ? segment.copyWith(
              durationSeconds:
                  segment.durationSeconds + plan.gasSwitchStopSeconds,
            )
          : segment,
    );
    previousDiluentId = diluentId ?? previousDiluentId;
  }
  return result;
}
