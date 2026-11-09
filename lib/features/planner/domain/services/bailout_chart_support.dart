import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/ascent/ascent_travel_spans.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/air_break_runs.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_gas_switches.dart';
import 'package:submersion/features/planner/domain/services/same_mix_share.dart';

/// Chart-only support for [BailoutOutcome]: the worst-case point's own
/// ceiling trace, its OC ascent stops unfolded, and its OC travel stretch by
/// stretch. Split out of bailout_solver.dart to keep that file under the
/// repo's size guideline. Every function here is pure, taking every input
/// explicitly, with no BailoutSolver instance state of its own.

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

  void sampleLeg(
    double startDepth,
    double endDepth,
    int durationSeconds, {
    BreathingConfig? breathing,
  }) {
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
        breathing ?? ascentBreathingAt((legStart + legEnd) / 2.0),
      );
      runtime += step;
      elapsed += step;
      trace.add((runtime, owesDeco(state) ? model.ceilingMeters(state) : 0.0));
    }
  }

  // A travel leg cut wherever the ascent changes gas, as PlanEngine's own
  // ceiling trace cuts it.
  void sampleTravel(double fromDepth, double toDepth, int seconds) {
    for (final span in straightAscentSpans(
      bailoutPlan,
      fromDepth: fromDepth,
      toDepth: toDepth,
      seconds: seconds,
    )) {
      sampleLeg(span.fromDepth, span.toDepth, span.seconds);
    }
  }

  for (final stop in points[worstIndex].schedule.stops) {
    final legSeconds = policy.ascentSeconds(
      fromDepth: depth,
      toDepth: stop.depthMeters,
      phase: phase,
    );
    sampleTravel(depth, stop.depthMeters, legSeconds);
    // A stop with air breaks is breathed in the scheduler's own runs, so the
    // ceiling falls as it did when the stop was timed.
    final breakGas = bailoutPlan.breakGasForDepth(stop.depthMeters);
    final airBreaks = policy.airBreaks;
    if (stop.airBreakSeconds > 0 && breakGas != null && airBreaks != null) {
      final onBreak = OpenCircuit(fO2: breakGas.fO2, fHe: breakGas.fHe);
      for (final run in airBreakRuns(stop.durationSeconds, airBreaks)) {
        sampleLeg(
          stop.depthMeters,
          stop.depthMeters,
          run.seconds,
          breathing: run.onBreak ? onBreak : null,
        );
      }
    } else if (stop.durationSeconds > 0) {
      sampleLeg(stop.depthMeters, stop.depthMeters, stop.durationSeconds);
    }
    depth = stop.depthMeters;
    phase = phase.afterStop(gasSwitchOnly: stop.isGasSwitchOnly);
  }
  if (depth > 0) {
    final legSeconds = policy.ascentSeconds(
      fromDepth: depth,
      toDepth: 0,
      phase: AscentPhase.surfacingAfter(phase),
    );
    sampleTravel(depth, 0, legSeconds);
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
  String? tankForGas(double fO2, double fHe) =>
      sameMixTanks(bailoutTanks, fO2: fO2, fHe: fHe).firstOrNull?.id;

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
    final tankId = tankForGas(fO2, gas.fHe);
    stops.add(
      PlanStop(
        depthMeters: stop.depthMeters,
        durationSeconds: stop.durationSeconds,
        airBreakSeconds: stop.airBreakSeconds,
        gasFO2: fO2,
        gasFHe: gas.fHe,
        tankId: tankId,
        airBreakTankId: airBreakTankIdFor(
          stop,
          plan: bailoutPlan,
          stopTankId: tankId,
          tankForGas: tankForGas,
        ),
        arrivalRuntimeSeconds: arrival,
        isGasSwitchOnly: stop.isGasSwitchOnly,
      ),
    );
    arrival += stop.durationSeconds;
    depth = stop.depthMeters;
    phase = phase.afterStop(gasSwitchOnly: stop.isGasSwitchOnly);
  }
  return stops;
}

/// [point]'s OC ascent travel, stretch by stretch, for the chart's gas-switch
/// flags (issue #4078): every leg, to each stop and to the surface, split
/// wherever [bailoutPlan] changes gas, from where each stretch starts.
///
/// The printed table folds the travel between stops into the stop it leads
/// to (#3138), so a gas picked up at its MOD between two stops has no line
/// of its own there; this places it where it is crossed. A stretch rounded to
/// no time is never breathed, and is left out. Walks the stops the way
/// [unfoldedOcStops] does, so the two line up on the chart.
List<PlanBreathingStretch> ocTravelStretches(
  BailoutPoint point, {
  required AscentGasPlan bailoutPlan,
  required SchedulePolicy policy,
  required List<DiveTank> bailoutTanks,
}) {
  final stretches = <PlanBreathingStretch>[];
  var time = point.runtimeSeconds;
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
      if (span.seconds > 0) {
        final gas = bailoutPlan.gasForDepth(span.fromDepth);
        final fO2 = 1.0 - gas.fN2 - gas.fHe;
        stretches.add((
          startSeconds: time,
          startDepthMeters: span.fromDepth,
          tankId: sameMixTanks(
            bailoutTanks,
            fO2: fO2,
            fHe: gas.fHe,
          ).firstOrNull?.id,
          fO2: fO2,
          fHe: gas.fHe,
        ));
      }
      time += span.seconds;
    }
    depth = toDepth;
  }

  for (final stop in point.schedule.stops) {
    travel(stop.depthMeters, phase);
    time += stop.durationSeconds;
    phase = phase.afterStop(gasSwitchOnly: stop.isGasSwitchOnly);
  }
  if (depth > 0) travel(0, AscentPhase.surfacingAfter(phase));
  return stretches;
}
