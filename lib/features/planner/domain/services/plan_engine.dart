import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// Thresholds and policy limits the engine evaluates plans against.
class PlanEngineConfig {
  final double ppO2Working;
  final double ppO2Deco;
  final int cnsWarningThreshold;
  final bool o2Narcotic;
  final double endLimitMeters;
  final double otuLimit;

  const PlanEngineConfig({
    this.ppO2Working = 1.4,
    this.ppO2Deco = 1.6,
    this.cnsWarningThreshold = 80,
    this.o2Narcotic = true,
    this.endLimitMeters = 30.0,
    this.otuLimit = 300.0,
  });
}

/// Turns a [domain.DivePlan] into a [PlanOutcome] on the Phase 1 engine
/// seams: DecoModel (BuhlmannGf), SchedulePolicy, BreathingConfig,
/// DiveEnvironment.
///
/// Phase 2 computes open-circuit plans; a `mode == ccr` plan is computed on
/// its OC gases and flagged (CCR schedules arrive in Phase 4).
class PlanEngine {
  final PlanEngineConfig config;

  const PlanEngine({this.config = const PlanEngineConfig()});

  PlanOutcome compute(domain.DivePlan plan, {TissueState? startState}) {
    final environment = DiveEnvironment.forConditions(
      altitudeMeters: plan.altitude,
      waterType: plan.waterType,
    );
    final policy = SchedulePolicy(
      lastStopDepth: plan.lastStopDepth,
      ascentRate: plan.ascentRate,
      gasSwitchStopSeconds: plan.gasSwitchStopSeconds,
      airBreaks: plan.airBreaks,
    );
    final model = BuhlmannGf(
      gfLow: plan.gfLow / 100.0,
      gfHigh: plan.gfHigh / 100.0,
      environment: environment,
      policy: policy,
    );
    final o2Calc = O2ToxicityCalculator(
      ppO2WarningThreshold: config.ppO2Working,
      ppO2CriticalThreshold: config.ppO2Deco,
      cnsWarningThreshold: config.cnsWarningThreshold,
    );

    final segments = List<PlanSegment>.from(plan.segments)
      ..sort((a, b) => a.order.compareTo(b.order));
    final ascentPlan = _ascentPlanFor(plan.tanks);

    var state = startState ?? model.initial();
    var runtime = 0;
    var cns = 0.0;
    var otu = 0.0;
    var maxPpO2 = 0.0;
    int? ndlAtBottom;
    int? ttsAtBottom;
    final maxDepth = plan.maxDepth;
    final segmentOutcomes = <SegmentOutcome>[];
    final timeline = <(int, BuhlmannState)>[];

    for (final segment in segments) {
      final startRuntime = runtime;
      final breathing = OpenCircuit(
        fO2: segment.gasMix.o2 / 100.0,
        fHe: segment.gasMix.he / 100.0,
      );

      state = model.applySegment(
        state,
        DecoSegment(
          startDepth: segment.startDepth,
          endDepth: segment.endDepth,
          durationSeconds: segment.durationSeconds,
        ),
        breathing,
      );
      runtime += segment.durationSeconds;
      timeline.add((runtime, state as BuhlmannState));

      final deeperEnd = segment.startDepth > segment.endDepth
          ? segment.startDepth
          : segment.endDepth;
      final segmentMaxPpO2 = O2ToxicityCalculator.calculatePpO2(
        deeperEnd,
        segment.gasMix.o2 / 100.0,
      );
      if (segmentMaxPpO2 > maxPpO2) maxPpO2 = segmentMaxPpO2;

      final avgPpO2 = O2ToxicityCalculator.calculatePpO2(
        segment.avgDepth,
        segment.gasMix.o2 / 100.0,
      );
      cns += o2Calc.calculateCnsForSegment(avgPpO2, segment.durationSeconds);
      otu += o2Calc.calculateOtuForSegment(avgPpO2, segment.durationSeconds);

      final ndl = model.ndlSeconds(
        state,
        depthMeters: segment.endDepth,
        breathing: breathing,
      );
      final ceiling = model.ceilingMeters(
        state,
        currentDepth: segment.endDepth,
      );
      final tts = segment.endDepth > 0
          ? model
                .schedule(
                  state,
                  currentDepth: segment.endDepth,
                  gases: ascentPlan,
                )
                .ttsSeconds
          : 0;

      if (segment.type == SegmentType.bottom ||
          segment.endDepth >= maxDepth - 0.1) {
        ndlAtBottom = ndl;
        ttsAtBottom = tts;
      }

      segmentOutcomes.add(
        SegmentOutcome(
          segmentId: segment.id,
          startRuntime: startRuntime,
          endRuntime: runtime,
          ndlAtEnd: ndl,
          ceilingAtEnd: ceiling,
          ttsAtEnd: tts,
          cns: cns,
          otu: otu,
          maxPpO2: segmentMaxPpO2,
        ),
      );
    }

    // Computed ascent from the last user depth.
    final lastDepth = segments.isEmpty ? 0.0 : segments.last.endDepth;
    final schedule = lastDepth > 0
        ? model.schedule(state, currentDepth: lastDepth, gases: ascentPlan)
        : const DecoSchedule(stops: [], ttsSeconds: 0);
    final stops = _mapStops(schedule, plan, ascentPlan, lastDepth, runtime);

    return PlanOutcome(
      runtimeSeconds: runtime + schedule.ttsSeconds,
      maxDepth: maxDepth,
      ndlAtBottom: ndlAtBottom ?? 0,
      ttsAtBottom: ttsAtBottom ?? schedule.ttsSeconds,
      stops: stops,
      segmentOutcomes: segmentOutcomes,
      tankUsages: const [],
      cnsEnd: cns,
      otuTotal: otu,
      issues: const [],
      endTissue: state as BuhlmannState,
      tissueTimeline: timeline,
    );
  }

  AscentGasPlan _ascentPlanFor(List<DiveTank> tanks) {
    if (tanks.isEmpty) {
      return FixedAscentGas(fN2: 0.7902);
    }
    return OptimalOcAscentGas(
      maxPpO2: config.ppO2Deco,
      gases: [
        for (final tank in tanks)
          AvailableGas(
            fN2: (100.0 - tank.gasMix.o2 - tank.gasMix.he) / 100.0,
            fHe: tank.gasMix.he / 100.0,
            maxPpO2Mod: O2ToxicityCalculator.calculateMod(
              tank.gasMix.o2 / 100.0,
              maxPpO2: config.ppO2Deco,
            ),
          ),
      ],
    );
  }

  List<PlanStop> _mapStops(
    DecoSchedule schedule,
    domain.DivePlan plan,
    AscentGasPlan ascentPlan,
    double fromDepth,
    int segmentsRuntime,
  ) {
    final stops = <PlanStop>[];
    var arrival = segmentsRuntime;
    var depth = fromDepth;
    for (final stop in schedule.stops) {
      arrival += ((depth - stop.depthMeters) / plan.ascentRate * 60).round();
      final gas = ascentPlan.gasForDepth(stop.depthMeters);
      final fO2 = 1.0 - gas.fN2 - gas.fHe;
      stops.add(
        PlanStop(
          depthMeters: stop.depthMeters,
          durationSeconds: stop.durationSeconds,
          airBreakSeconds: stop.airBreakSeconds,
          gasFO2: fO2,
          gasFHe: gas.fHe,
          tankId: _tankForGas(plan.tanks, fO2, gas.fHe),
          arrivalRuntimeSeconds: arrival,
        ),
      );
      arrival += stop.durationSeconds;
      depth = stop.depthMeters;
    }
    return stops;
  }

  /// The carried tank whose mix matches the stop gas (deco/stage roles win
  /// ties so the back gas is not charged for deco stops it did not supply).
  String? _tankForGas(List<DiveTank> tanks, double fO2, double fHe) {
    DiveTank? match;
    for (final tank in tanks) {
      final tankFO2 = tank.gasMix.o2 / 100.0;
      final tankFHe = tank.gasMix.he / 100.0;
      if ((tankFO2 - fO2).abs() < 0.005 && (tankFHe - fHe).abs() < 0.005) {
        final isDeco =
            tank.role == TankRole.deco || tank.role == TankRole.stage;
        if (match == null ||
            (isDeco &&
                match.role != TankRole.deco &&
                match.role != TankRole.stage)) {
          match = tank;
        }
      }
    }
    return match?.id;
  }
}
