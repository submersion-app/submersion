import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// A constant mass flow (CMF) loop whose flow cannot sustain it (issue
/// #4660), one [PlanIssueType.scrFlowTooLow] per supply cylinder.
///
/// [ScrCalculator.calculateCmfSteadyStateFo2] has no steady state when the
/// injection rate is at or below VO2, or when the flow carries less O2 than
/// the diver uses (rate x supply FO2 below VO2). The engine's `Scr` model then
/// falls back to breathing the supply mix, which reads as a healthy ppO2 to
/// every hypoxia check, so this is the only thing that flags it.
///
/// [config] is the plan-resolved config: its rate and VO2 are the plan's own
/// or the diver's defaults. Only legs breathed on the CMF loop are judged; an
/// open-circuit bailout leg breathes its cylinder, not a loop.
Iterable<PlanIssue> scrFlowIssues(
  domain.DivePlan plan,
  PlanEngineConfig config,
) sync* {
  final rate = config.scrInjectionRateLpm;
  final vo2 = config.scrVo2Lpm;
  final seen = <String>{};
  for (final segment in plan.segments) {
    if (modeFor(plan, segment) != domain.PlanMode.scr) continue;
    if (!seen.add(segment.tankId)) continue;
    final supplyO2Percent = segment.gasMix.o2;
    final loop = ScrCalculator.calculateCmfSteadyStateFo2(
      injectionRateLpm: rate,
      supplyO2Percent: supplyO2Percent,
      vo2: vo2,
    );
    if (loop != null) continue;
    final supplyFO2 = supplyO2Percent / 100.0;
    // The least flow with a steady state: above VO2, and enough O2 in the
    // flow to cover it. Below 100% O2 the second bound is the larger.
    final needed = supplyFO2 > 0 ? vo2 / supplyFO2 : double.infinity;
    yield PlanIssue(
      type: PlanIssueType.scrFlowTooLow,
      severity: PlanIssueSeverity.critical,
      // The engine's own wording, in surface litres a minute; the planner
      // shows the localized, unit-aware text from plan_issue_text.dart.
      message:
          'SCR injection rate ${rate.toStringAsFixed(1)} cannot sustain the '
          'loop at VO2 ${vo2.toStringAsFixed(2)}: it needs more than '
          '${needed.toStringAsFixed(1)} (surface litres a minute)',
      tankId: segment.tankId,
      gasMix: segment.gasMix,
      value: rate,
      threshold: needed > vo2 ? needed : vo2,
    );
  }
}
