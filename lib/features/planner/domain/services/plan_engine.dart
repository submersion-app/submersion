import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
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

    final tankUsages = _computeTankUsages(
      plan,
      segments,
      stops,
      lastDepth,
      environment,
      ascentPlan,
    );
    final issues = _computeIssues(
      plan,
      segments,
      segmentOutcomes,
      tankUsages,
      cns,
      otu,
      environment,
    );

    return PlanOutcome(
      runtimeSeconds: runtime + schedule.ttsSeconds,
      maxDepth: maxDepth,
      ndlAtBottom: ndlAtBottom ?? 0,
      ttsAtBottom: ttsAtBottom ?? schedule.ttsSeconds,
      stops: stops,
      segmentOutcomes: segmentOutcomes,
      tankUsages: tankUsages,
      cnsEnd: cns,
      otuTotal: otu,
      issues: issues,
      endTissue: state as BuhlmannState,
      tissueTimeline: timeline,
    );
  }

  /// SAC-based consumption: bottom SAC on descent/bottom segments, deco SAC
  /// on everything shallower-bound (ascent legs, stops), depth pressure via
  /// the plan's environment, remaining pressure compressibility-corrected.
  List<PlanTankUsage> _computeTankUsages(
    domain.DivePlan plan,
    List<PlanSegment> segments,
    List<PlanStop> stops,
    double lastDepth,
    DiveEnvironment environment,
    AscentGasPlan ascentPlan,
  ) {
    if (plan.tanks.isEmpty) return const [];
    final liters = <String, double>{for (final t in plan.tanks) t.id: 0.0};
    final fallbackTankId = plan.tanks.first.id;

    void charge(String? tankId, double amount) {
      final id = tankId != null && liters.containsKey(tankId)
          ? tankId
          : fallbackTankId;
      liters[id] = (liters[id] ?? 0) + amount;
    }

    for (final segment in segments) {
      final sac =
          segment.type == SegmentType.bottom ||
              segment.type == SegmentType.descent
          ? plan.sacBottom
          : plan.sacDecoEffective;
      charge(
        segment.tankId,
        sac *
            (segment.durationSeconds / 60.0) *
            environment.pressureAtDepth(segment.avgDepth),
      );
    }

    // Computed ascent: travel legs and stops on the deco SAC.
    var depth = lastDepth;
    for (final stop in stops) {
      final legSeconds = ((depth - stop.depthMeters) / plan.ascentRate * 60)
          .round();
      final legAvg = (depth + stop.depthMeters) / 2.0;
      charge(
        stop.tankId,
        plan.sacDecoEffective *
            (legSeconds / 60.0) *
            environment.pressureAtDepth(legAvg),
      );
      charge(
        stop.tankId,
        plan.sacDecoEffective *
            (stop.durationSeconds / 60.0) *
            environment.pressureAtDepth(stop.depthMeters),
      );
      depth = stop.depthMeters;
    }
    if (depth > 0) {
      final legSeconds = (depth / plan.ascentRate * 60).round();
      final gas = ascentPlan.gasForDepth(depth);
      charge(
        _tankForGas(plan.tanks, 1.0 - gas.fN2 - gas.fHe, gas.fHe),
        plan.sacDecoEffective *
            (legSeconds / 60.0) *
            environment.pressureAtDepth(depth / 2.0),
      );
    }

    return [
      for (final tank in plan.tanks)
        () {
          final used = liters[tank.id] ?? 0.0;
          final start = tank.startPressure;
          final remaining = start != null
              ? pressureAfterConsuming(
                  tankSizeLiters: tank.volume ?? 11.0,
                  startPressureBar: start,
                  litersConsumed: used,
                  o2Percent: tank.gasMix.o2,
                  hePercent: tank.gasMix.he,
                )
              : null;
          return PlanTankUsage(
            tankId: tank.id,
            litersUsed: used,
            remainingPressure: remaining,
            percentUsed: start != null && start > 0
                ? (start - (remaining ?? 0)) / start * 100.0
                : 0.0,
            reserveViolation:
                remaining != null && remaining < plan.reservePressure,
          );
        }(),
    ];
  }

  List<PlanIssue> _computeIssues(
    domain.DivePlan plan,
    List<PlanSegment> segments,
    List<SegmentOutcome> segmentOutcomes,
    List<PlanTankUsage> tankUsages,
    double cns,
    double otu,
    DiveEnvironment environment,
  ) {
    final issues = <PlanIssue>[];

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final outcome = segmentOutcomes[i];
      final deeperEnd = segment.startDepth > segment.endDepth
          ? segment.startDepth
          : segment.endDepth;
      final shallowerEnd = segment.startDepth < segment.endDepth
          ? segment.startDepth
          : segment.endDepth;
      final fO2 = segment.gasMix.o2 / 100.0;
      final fHe = segment.gasMix.he / 100.0;

      if (outcome.maxPpO2 > config.ppO2Deco) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.ppO2Critical,
            severity: PlanIssueSeverity.critical,
            message:
                'ppO2 ${outcome.maxPpO2.toStringAsFixed(2)} bar exceeds the '
                'deco limit',
            atDepth: deeperEnd,
            segmentId: segment.id,
            value: outcome.maxPpO2,
            threshold: config.ppO2Deco,
          ),
        );
      } else if (outcome.maxPpO2 > config.ppO2Working) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.ppO2High,
            severity: PlanIssueSeverity.warning,
            message:
                'ppO2 ${outcome.maxPpO2.toStringAsFixed(2)} bar exceeds the '
                'working limit',
            atDepth: deeperEnd,
            segmentId: segment.id,
            value: outcome.maxPpO2,
            threshold: config.ppO2Working,
          ),
        );
      }

      final inspiredO2 = OpenCircuit(
        fO2: fO2,
        fHe: fHe,
      ).inspiredAt(environment.pressureAtDepth(shallowerEnd)).pO2;
      if (inspiredO2 < 0.16) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.hypoxicGas,
            severity: PlanIssueSeverity.critical,
            message:
                'Gas is hypoxic at ${shallowerEnd.toStringAsFixed(0)} m '
                '(ppO2 ${inspiredO2.toStringAsFixed(2)} bar)',
            atDepth: shallowerEnd,
            segmentId: segment.id,
            value: inspiredO2,
            threshold: 0.16,
          ),
        );
      }

      final end = segment.gasMix.end(deeperEnd, o2Narcotic: config.o2Narcotic);
      if (end > config.endLimitMeters) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.endExceeded,
            severity: PlanIssueSeverity.warning,
            message:
                'END ${end.toStringAsFixed(0)} m exceeds '
                '${config.endLimitMeters.toStringAsFixed(0)} m',
            atDepth: deeperEnd,
            segmentId: segment.id,
            value: end,
            threshold: config.endLimitMeters,
          ),
        );
      }

      final density = gasDensityGPerL(
        fO2: fO2,
        fHe: fHe,
        ambientPressureBar: environment.pressureAtDepth(deeperEnd),
      );
      if (density > gasDensityCriticalGPerL) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.gasDensityCritical,
            severity: PlanIssueSeverity.critical,
            message:
                'Gas density ${density.toStringAsFixed(1)} g/L exceeds the '
                'hard limit',
            atDepth: deeperEnd,
            segmentId: segment.id,
            value: density,
            threshold: gasDensityCriticalGPerL,
          ),
        );
      } else if (density > gasDensityWarnGPerL) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.gasDensityHigh,
            severity: PlanIssueSeverity.warning,
            message:
                'Gas density ${density.toStringAsFixed(1)} g/L exceeds the '
                'recommended limit',
            atDepth: deeperEnd,
            segmentId: segment.id,
            value: density,
            threshold: gasDensityWarnGPerL,
          ),
        );
      }
    }

    if (cns >= 100) {
      issues.add(
        PlanIssue(
          type: PlanIssueType.cnsCritical,
          severity: PlanIssueSeverity.critical,
          message: 'CNS reaches ${cns.toStringAsFixed(0)}%',
          value: cns,
          threshold: 100,
        ),
      );
    } else if (cns >= config.cnsWarningThreshold) {
      issues.add(
        PlanIssue(
          type: PlanIssueType.cnsWarning,
          severity: PlanIssueSeverity.warning,
          message: 'CNS reaches ${cns.toStringAsFixed(0)}%',
          value: cns,
          threshold: config.cnsWarningThreshold.toDouble(),
        ),
      );
    }
    if (otu > config.otuLimit) {
      issues.add(
        PlanIssue(
          type: PlanIssueType.otuHigh,
          severity: PlanIssueSeverity.warning,
          message: 'OTU ${otu.toStringAsFixed(0)} exceeds the daily guideline',
          value: otu,
          threshold: config.otuLimit,
        ),
      );
    }

    for (final usage in tankUsages) {
      final remaining = usage.remainingPressure;
      if (remaining == null) continue;
      if (remaining <= 0) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.gasOut,
            severity: PlanIssueSeverity.critical,
            message: 'Tank runs out of gas',
            segmentId: usage.tankId,
            value: remaining,
            threshold: 0,
          ),
        );
      } else if (usage.reserveViolation) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.gasReserveViolation,
            severity: PlanIssueSeverity.alert,
            message:
                'Tank ends below the '
                '${plan.reservePressure.toStringAsFixed(0)} bar reserve',
            segmentId: usage.tankId,
            value: remaining,
            threshold: plan.reservePressure,
          ),
        );
      }
    }

    final inDeco = segmentOutcomes.any((s) => s.inDeco);
    if (inDeco && !_hasDecoGas(plan)) {
      issues.add(
        const PlanIssue(
          type: PlanIssueType.ndlExceededNoDecoGas,
          severity: PlanIssueSeverity.alert,
          message:
              'Plan incurs decompression with no dedicated deco gas carried',
        ),
      );
    }

    issues.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return issues;
  }

  /// True when a deco/stage tank richer than the back gas is carried.
  bool _hasDecoGas(domain.DivePlan plan) {
    if (plan.tanks.isEmpty) return false;
    final backGas = plan.tanks
        .firstWhere(
          (t) => t.role == TankRole.backGas,
          orElse: () => plan.tanks.first,
        )
        .gasMix
        .o2;
    return plan.tanks.any(
      (t) =>
          (t.role == TankRole.deco || t.role == TankRole.stage) &&
          t.gasMix.o2 > backGas,
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
