import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Chart-only support for [BailoutOutcome]: the worst-case point's own
/// ceiling trace and its OC ascent stops, unfolded. Split out of
/// bailout_solver.dart to keep that file under the repo's size guideline --
/// both functions are pure, taking every input explicitly, with no
/// BailoutSolver instance state of their own.

/// The worst-case point's own ceiling trace: the bottom-phase samples
/// already computed up to it (reusing [states], not re-simulating the
/// bottom phase a second time), then the OC ascent it was sized from,
/// continuing from exactly the tissue state the bottom phase left off at --
/// the bailout picture's counterpart to PlanEngine._ceilingTrace, sampled
/// at [points]' own (coarser) interval for the bottom phase and at
/// PlanEngine.ceilingSampleSeconds for the ascent, same as the main
/// chart's own ceiling trace.
List<(int, double)> worstCaseCeilingTrace({
  required DecoModel model,
  required List<BailoutPoint> points,
  required List<TissueState> states,
  required int worstIndex,
  required AscentGasPlan bailoutPlan,
  required SchedulePolicy policy,
}) {
  bool owesDeco(TissueState state) => model.surfaceCeilingMeters(state) > 0;

  final trace = <(int, double)>[
    for (var i = 0; i <= worstIndex; i++)
      (
        points[i].runtimeSeconds,
        owesDeco(states[i]) ? model.ceilingMeters(states[i]) : 0.0,
      ),
  ];

  BreathingConfig ascentBreathingAt(double depth) {
    final gas = bailoutPlan.gasForDepth(depth);
    return OpenCircuit(fO2: 1.0 - gas.fN2 - gas.fHe, fHe: gas.fHe);
  }

  var state = states[worstIndex];
  var runtime = points[worstIndex].runtimeSeconds;
  var depth = points[worstIndex].depthMeters;
  var phase = AscentPhase.toFirstStop;

  void sampleLeg(double startDepth, double endDepth, int durationSeconds) {
    var elapsed = 0;
    while (elapsed < durationSeconds) {
      final remaining = durationSeconds - elapsed;
      final step = remaining < PlanEngine.ceilingSampleSeconds
          ? remaining
          : PlanEngine.ceilingSampleSeconds;
      final legStart =
          startDepth + (endDepth - startDepth) * (elapsed / durationSeconds);
      final legEnd =
          startDepth +
          (endDepth - startDepth) * ((elapsed + step) / durationSeconds);
      state = model.applySegment(
        state,
        DecoSegment(
          startDepth: legStart,
          endDepth: legEnd,
          durationSeconds: step,
        ),
        ascentBreathingAt((legStart + legEnd) / 2.0),
      );
      runtime += step;
      elapsed += step;
      trace.add((runtime, owesDeco(state) ? model.ceilingMeters(state) : 0.0));
    }
  }

  for (final stop in points[worstIndex].schedule.stops) {
    final legSeconds = policy.ascentSeconds(
      fromDepth: depth,
      toDepth: stop.depthMeters,
      phase: phase,
    );
    if (legSeconds > 0) sampleLeg(depth, stop.depthMeters, legSeconds);
    if (stop.durationSeconds > 0) {
      sampleLeg(stop.depthMeters, stop.depthMeters, stop.durationSeconds);
    }
    depth = stop.depthMeters;
    phase = AscentPhase.betweenStops;
  }
  if (depth > 0) {
    final legSeconds = policy.ascentSeconds(
      fromDepth: depth,
      toDepth: 0,
      phase: AscentPhase.surfacingAfter(phase),
    );
    if (legSeconds > 0) sampleLeg(depth, 0, legSeconds);
  }

  return trace;
}

/// [point]'s OC ascent stops, unfolded -- one [PlanStop] per actual stop,
/// its own arrival time and gas, mirroring PlanEngine._mapStops but driven
/// by [bailoutPlan] since a bailout point starts mid-dive with no
/// PlanEngine instance of its own. Does not split the first travel leg at
/// crossed gas-switch depths the way BailoutSolver._scheduleRowsFor does
/// for the printed table (#3225): the chart only needs the stop shape
/// right, not an extra marker partway down an already-straight travel
/// line.
List<PlanStop> unfoldedOcStops(
  BailoutPoint point, {
  required AscentGasPlan bailoutPlan,
  required SchedulePolicy policy,
  required List<DiveTank> bailoutTanks,
}) {
  String? tankForGas(double fO2, double fHe) {
    for (final tank in bailoutTanks) {
      final tankFO2 = tank.gasMix.o2 / 100.0;
      final tankFHe = tank.gasMix.he / 100.0;
      if ((tankFO2 - fO2).abs() < 0.005 && (tankFHe - fHe).abs() < 0.005) {
        return tank.id;
      }
    }
    return null;
  }

  final stops = <PlanStop>[];
  var arrival = point.runtimeSeconds;
  var depth = point.depthMeters;
  var phase = AscentPhase.toFirstStop;
  for (final stop in point.schedule.stops) {
    arrival += policy.ascentSeconds(
      fromDepth: depth,
      toDepth: stop.depthMeters,
      phase: phase,
    );
    final gas = bailoutPlan.gasForDepth(stop.depthMeters);
    final fO2 = 1.0 - gas.fN2 - gas.fHe;
    stops.add(
      PlanStop(
        depthMeters: stop.depthMeters,
        durationSeconds: stop.durationSeconds,
        airBreakSeconds: stop.airBreakSeconds,
        gasFO2: fO2,
        gasFHe: gas.fHe,
        tankId: tankForGas(fO2, gas.fHe),
        arrivalRuntimeSeconds: arrival,
      ),
    );
    arrival += stop.durationSeconds;
    depth = stop.depthMeters;
    phase = AscentPhase.betweenStops;
  }
  return stops;
}
