import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/ascent/ascent_travel_spans.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';

/// The CNS % [point]'s open-circuit ascent charges on its own (issue #4983),
/// as PlanEngine charges a computed ascent: each travel span at its mean
/// depth on the gas in force at its deeper end, each stop at its depth, an
/// air break on the break gas.
double bailoutAscentCns(
  BailoutPoint point, {
  required AscentGasPlan bailoutPlan,
  required SchedulePolicy policy,
  required DiveEnvironment environment,
  required O2ToxicityCalculator o2,
}) {
  var cns = 0.0;
  void charge(double depthMeters, double fO2, int seconds) {
    if (seconds <= 0) return;
    cns += o2.calculateCnsForSegment(
      environment.pressureAtDepth(depthMeters) * fO2,
      seconds,
    );
  }

  var depth = point.depthMeters;
  var phase = AscentPhase.toFirstStop;
  void travel(double toDepth, AscentPhase legPhase) {
    final seconds = policy.ascentSeconds(
      fromDepth: depth,
      toDepth: toDepth,
      phase: legPhase,
    );
    for (final span in splitAscentLeg(
      bailoutPlan,
      fromDepth: depth,
      toDepth: toDepth,
      seconds: seconds,
    )) {
      charge(
        (span.fromDepth + span.toDepth) / 2.0,
        bailoutPlan.gasForDepth(span.fromDepth).fO2,
        span.seconds,
      );
    }
    depth = toDepth;
  }

  for (final stop in point.schedule.stops) {
    travel(stop.depthMeters, phase);
    final stopFO2 = bailoutPlan.gasForDepth(stop.depthMeters).fO2;
    final breakGas = bailoutPlan.breakGasForDepth(stop.depthMeters);
    charge(
      stop.depthMeters,
      stopFO2,
      stop.durationSeconds - stop.airBreakSeconds,
    );
    charge(
      stop.depthMeters,
      breakGas == null ? stopFO2 : breakGas.fO2,
      stop.airBreakSeconds,
    );
    phase = phase.afterStop(gasSwitchOnly: stop.isGasSwitchOnly);
  }
  if (depth > 0) travel(0, AscentPhase.surfacingAfter(phase));
  return cns;
}
