import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// The open-circuit bailout picture at one instant of a CCR plan.
class BailoutPoint {
  final int runtimeSeconds;
  final double depthMeters;
  final int ttsSeconds;
  final double litersRequired;

  const BailoutPoint({
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.ttsSeconds,
    required this.litersRequired,
  });
}

/// Bailout demand sampled along a CCR plan, with the worst-case instant.
class BailoutOutcome {
  final List<BailoutPoint> points;
  final BailoutPoint worstCase;

  /// Surface liters actually carried in bailout-role tanks
  /// (compressibility-corrected).
  final double availableLiters;

  const BailoutOutcome({
    required this.points,
    required this.worstCase,
    required this.availableLiters,
  });

  bool get sufficient => worstCase.litersRequired <= availableLiters;

  /// The sampled point closest in runtime to [runtimeSeconds].
  BailoutPoint nearest(double runtimeSeconds) {
    var best = points.first;
    var bestDelta = (best.runtimeSeconds - runtimeSeconds).abs();
    for (final point in points) {
      final delta = (point.runtimeSeconds - runtimeSeconds).abs();
      if (delta < bestDelta) {
        best = point;
        bestDelta = delta;
      }
    }
    return best;
  }
}

/// Answers "what if the loop dies HERE": walks the CCR plan's bottom phase,
/// and at bounded sample intervals computes the full open-circuit bailout
/// (schedule on the bailout gases, stressed SAC) from that instant. The
/// worst case sizes the bailout cylinders.
class BailoutSolver {
  final PlanEngineConfig config;

  const BailoutSolver({this.config = const PlanEngineConfig()});

  BailoutOutcome? solve(domain.DivePlan plan) {
    if (plan.mode != domain.PlanMode.ccr) return null;
    final bailoutTanks = plan.tanks
        .where((t) => t.role == TankRole.bailout)
        .toList();
    if (bailoutTanks.isEmpty) return null;
    final segments = List<PlanSegment>.from(plan.segments)
      ..sort((a, b) => a.order.compareTo(b.order));
    if (segments.isEmpty) return null;

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
    final bailoutPlan = OptimalOcAscentGas(
      maxPpO2: config.ppO2Deco,
      gases: [
        for (final tank in bailoutTanks)
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

    final availableLiters = bailoutTanks.fold<double>(
      0,
      (sum, tank) =>
          sum +
          gasVolume(
            tankSizeLiters: tank.volume ?? 11.0,
            pressureBar: tank.startPressure ?? 0,
            o2Percent: tank.gasMix.o2,
            hePercent: tank.gasMix.he,
            model: config.gasModel,
          ),
    );

    final totalSeconds = segments.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final sampleInterval = totalSeconds > 60 * 40 ? totalSeconds ~/ 40 : 60;

    var state = model.initial();
    var elapsed = 0;
    final points = <BailoutPoint>[];

    for (final segment in segments) {
      var covered = 0;
      while (covered < segment.durationSeconds) {
        final chunk = (segment.durationSeconds - covered) < sampleInterval
            ? segment.durationSeconds - covered
            : sampleInterval;
        double depthAt(int secondsIntoSegment) =>
            segment.startDepth +
            (segment.endDepth - segment.startDepth) *
                (secondsIntoSegment / segment.durationSeconds);
        final chunkStartDepth = depthAt(covered);
        final chunkEndDepth = depthAt(covered + chunk);
        final chunkAvg = (chunkStartDepth + chunkEndDepth) / 2.0;

        state = model.applySegment(
          state,
          DecoSegment(
            startDepth: chunkStartDepth,
            endDepth: chunkEndDepth,
            durationSeconds: chunk,
          ),
          ClosedCircuit(
            setpoint: chunkAvg > plan.effectiveSetpointSwitchDepth
                ? plan.effectiveSetpointHigh
                : plan.effectiveSetpointLow,
            diluentFO2: segment.gasMix.o2 / 100.0,
            diluentFHe: segment.gasMix.he / 100.0,
          ),
        );
        covered += chunk;
        elapsed += chunk;

        if (chunkEndDepth > 0) {
          final schedule = model.schedule(
            state,
            currentDepth: chunkEndDepth,
            gases: bailoutPlan,
          );
          points.add(
            BailoutPoint(
              runtimeSeconds: elapsed,
              depthMeters: chunkEndDepth,
              ttsSeconds: schedule.ttsSeconds,
              litersRequired: _ascentLiters(
                schedule,
                fromDepth: chunkEndDepth,
                sac: plan.sacStressedEffective,
                ascentRate: plan.ascentRate,
                environment: environment,
              ),
            ),
          );
        }
      }
    }

    if (points.isEmpty) return null;
    var worst = points.first;
    for (final point in points) {
      if (point.litersRequired > worst.litersRequired) worst = point;
    }
    return BailoutOutcome(
      points: points,
      worstCase: worst,
      availableLiters: availableLiters,
    );
  }

  /// Stressed-SAC surface liters for an OC ascent: travel legs at
  /// [ascentRate], the stops themselves, and the final surfacing leg.
  double _ascentLiters(
    DecoSchedule schedule, {
    required double fromDepth,
    required double sac,
    required double ascentRate,
    required DiveEnvironment environment,
  }) {
    var liters = 0.0;
    var depth = fromDepth;
    for (final stop in schedule.stops) {
      final legSeconds = ((depth - stop.depthMeters) / ascentRate * 60).round();
      liters +=
          sac *
          (legSeconds / 60.0) *
          environment.pressureAtDepth((depth + stop.depthMeters) / 2.0);
      liters +=
          sac *
          (stop.durationSeconds / 60.0) *
          environment.pressureAtDepth(stop.depthMeters);
      depth = stop.depthMeters;
    }
    if (depth > 0) {
      final legSeconds = (depth / ascentRate * 60).round();
      liters +=
          sac * (legSeconds / 60.0) * environment.pressureAtDepth(depth / 2.0);
    }
    return liters;
  }
}
