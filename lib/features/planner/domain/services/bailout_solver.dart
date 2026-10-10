import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/segment_phase.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';

/// The open-circuit bailout picture at one instant of a CCR plan.
class BailoutPoint {
  final int runtimeSeconds;
  final double depthMeters;
  final int ttsSeconds;
  final double litersRequired;

  /// The full OC schedule this point was sized from -- retained so the
  /// worst-case point can show its stops and gas switches, not just the
  /// totals (#3137).
  final DecoSchedule schedule;

  const BailoutPoint({
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.ttsSeconds,
    required this.litersRequired,
    required this.schedule,
  });
}

/// Bailout demand sampled along a CCR plan, with the worst-case instant.
class BailoutOutcome {
  final List<BailoutPoint> points;
  final BailoutPoint worstCase;

  /// Surface liters actually carried in bailout-role tanks
  /// (compressibility-corrected).
  final double availableLiters;

  /// The worst-case point's OC schedule, as printable table lines: every
  /// stop on whichever bailout gas is eligible there, the travel leg to the
  /// first stop its own line, later stops folding their travel time in
  /// (#3138's convention, kept consistent here).
  final List<PlanScheduleRow> worstCaseRows;

  /// The bailout-role cylinders [availableLiters] was summed from -- shown
  /// here rather than in the main per-tank gas list, since they carry no
  /// normal-loop consumption to chart there.
  final List<DiveTank> bailoutTanks;

  /// Per-cylinder consumption for the worst-case bailout schedule, read the
  /// same way the main per-tank gas list reads: used/end liters and
  /// pressure, one row per [bailoutTanks] entry. Sums to the same total as
  /// [BailoutPoint.litersRequired] for [worstCase].
  final List<PlanTankUsage> bailoutTankUsages;

  const BailoutOutcome({
    required this.points,
    required this.worstCase,
    required this.availableLiters,
    required this.worstCaseRows,
    required this.bailoutTanks,
    required this.bailoutTankUsages,
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

  BailoutOutcome? solve(domain.DivePlan inputPlan) {
    if (inputPlan.mode != domain.PlanMode.ccr) return null;
    // Which cylinders are bailout is partly derived (any open-circuit gas
    // carried on a loop dive) and partly the diver's explicit override.
    final plan = const TankRoleResolver().apply(inputPlan);
    final bailoutTanks = plan.tanks
        .where((t) => t.role == TankRole.bailout)
        .toList();
    if (bailoutTanks.isEmpty) return null;
    final segments = List<PlanSegment>.from(plan.segments)
      ..sort((a, b) => a.order.compareTo(b.order));
    if (segments.isEmpty) return null;
    final legs = const SegmentChain().resolve(segments);

    final environment = DiveEnvironment.forConditions(
      altitudeMeters: plan.altitude,
      waterType: plan.waterType ?? WaterType.salt,
      salinityPpt: plan.salinityPpt,
    );
    final policy = SchedulePolicy(
      lastStopDepth: plan.lastStopDepth,
      ascentRate: plan.ascentRate,
      intermediateAscentRate: plan.intermediateAscentRate,
      shallowAscentRate: plan.shallowAscentRate,
      finalAscentRate: plan.finalAscentRate,
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

    for (final leg in legs) {
      final segment = leg.segment;
      var covered = 0;
      while (covered < segment.durationSeconds) {
        final chunk = (segment.durationSeconds - covered) < sampleInterval
            ? segment.durationSeconds - covered
            : sampleInterval;
        double depthAt(int secondsIntoSegment) =>
            leg.startDepth +
            (leg.endDepth - leg.startDepth) *
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
                policy: policy,
                environment: environment,
              ),
              schedule: schedule,
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
    final ocSchedule = _scheduleRowsFor(
      worst,
      bailoutTanks: bailoutTanks,
      bailoutPlan: bailoutPlan,
      policy: policy,
      environment: environment,
      sac: plan.sacStressedEffective,
    );
    return BailoutOutcome(
      points: points,
      worstCase: worst,
      availableLiters: availableLiters,
      worstCaseRows: [
        ..._legRowsUpTo(worst, legs, plan, environment),
        ...ocSchedule.rows,
      ],
      bailoutTanks: bailoutTanks,
      bailoutTankUsages: [
        for (final tank in bailoutTanks)
          () {
            final used = ocSchedule.litersByTank[tank.id] ?? 0.0;
            final start = tank.startPressure;
            final remaining = start != null
                ? pressureAfterConsuming(
                    tankSizeLiters: tank.volume ?? 11.0,
                    startPressureBar: start,
                    litersConsumed: used,
                    o2Percent: tank.gasMix.o2,
                    hePercent: tank.gasMix.he,
                    model: config.gasModel,
                  )
                : null;
            final total = start != null
                ? gasVolume(
                    tankSizeLiters: tank.volume ?? 11.0,
                    pressureBar: start,
                    o2Percent: tank.gasMix.o2,
                    hePercent: tank.gasMix.he,
                    model: config.gasModel,
                  )
                : null;
            return PlanTankUsage(
              tankId: tank.id,
              litersUsed: used,
              totalLiters: total,
              remainingPressure: remaining,
              startPressure: start,
              percentUsed: start != null && start > 0
                  ? (start - (remaining ?? 0)) / start * 100.0
                  : 0.0,
              // pressureAfterConsuming floors a cylinder at 0 bar rather
              // than going negative, so a cylinder actually asked for more
              // than it holds reads identically to one that happened to end
              // up exactly empty. Reusing reserveViolation's existing
              // red-highlight treatment is the one visible difference
              // between the two (#3190).
              reserveViolation: total != null && used > total,
            );
          }(),
      ],
    );
  }

  /// The authored descent/bottom-phase lines up to (and including, cut off
  /// mid-leg if needed) [point] -- so the bailout schedule reads as the
  /// whole dive, not just the OC tail, matching how the main CCR table
  /// always shows the authored legs first.
  List<PlanScheduleRow> _legRowsUpTo(
    BailoutPoint point,
    List<ResolvedLeg> legs,
    domain.DivePlan plan,
    DiveEnvironment environment,
  ) {
    final rows = <PlanScheduleRow>[];
    double? previousFO2;
    double? previousFHe;

    void add(ResolvedLeg leg, {required int duration, required double depth}) {
      final fO2 = leg.segment.gasMix.o2 / 100.0;
      final fHe = leg.segment.gasMix.he / 100.0;
      final switched =
          previousFO2 == null ||
          previousFHe == null ||
          (fO2 - previousFO2!).abs() > 0.0005 ||
          (fHe - previousFHe!).abs() > 0.0005;
      // The loop's real inspired ppO2 is the setpoint, not ambient x the
      // diluent's own fraction -- same reasoning as PlanEngine's PO2 column
      // (plan_engine.dart, _buildSchedule's ppO2Override).
      final setpoint = depth > plan.effectiveSetpointSwitchDepth
          ? plan.effectiveSetpointHigh
          : plan.effectiveSetpointLow;
      final ppO2 = ClosedCircuit(
        setpoint: setpoint,
        diluentFO2: fO2,
        diluentFHe: fHe,
      ).inspiredAt(environment.pressureAtDepth(depth)).pO2;
      rows.add(
        PlanScheduleRow(
          kind: switch (leg.phase) {
            SegmentPhase.descent => PlanScheduleRowKind.descent,
            SegmentPhase.level => PlanScheduleRowKind.level,
            SegmentPhase.ascent => PlanScheduleRowKind.ascent,
            SegmentPhase.stop => PlanScheduleRowKind.stop,
          },
          depthMeters: depth,
          durationSeconds: duration,
          runtimeSeconds: leg.runtimeSeconds < point.runtimeSeconds
              ? leg.runtimeSeconds
              : point.runtimeSeconds,
          gasFO2: fO2,
          gasFHe: fHe,
          tankId: leg.tankId,
          gasSwitch: switched,
          ppO2: ppO2,
          endMeters: GasMix(
            o2: fO2 * 100,
            he: fHe * 100,
          ).end(depth, o2Narcotic: config.o2Narcotic),
        ),
      );
      previousFO2 = fO2;
      previousFHe = fHe;
    }

    for (final leg in legs) {
      final legStart = leg.runtimeSeconds - leg.durationSeconds;
      if (legStart >= point.runtimeSeconds) break;
      if (leg.runtimeSeconds <= point.runtimeSeconds) {
        add(leg, duration: leg.durationSeconds, depth: leg.endDepth);
      } else {
        // This leg straddles the bailout instant: cut it off exactly there,
        // at the point's own depth (constant through a hold, the only
        // realistic case for the worst case -- see BailoutSolver's own
        // doc comment on why it walks the bottom phase).
        add(
          leg,
          duration: point.runtimeSeconds - legStart,
          depth: point.depthMeters,
        );
      }
    }
    return rows;
  }

  /// The worst-case point's schedule as printable table lines: every stop
  /// on whichever bailout gas is eligible there (switching at its own MOD,
  /// same as [AscentGasPlan] anywhere else), travel to the first stop its
  /// own line, later stops folding their travel time in -- mirrors
  /// PlanEngine's own schedule-building (`_buildSchedule`) closely enough
  /// to read the same way, but is self-contained: a bailout point starts
  /// mid-dive with no authored legs or PlanEngine instance of its own.
  ({List<PlanScheduleRow> rows, Map<String, double> litersByTank})
  _scheduleRowsFor(
    BailoutPoint point, {
    required List<DiveTank> bailoutTanks,
    required AscentGasPlan bailoutPlan,
    required SchedulePolicy policy,
    required DiveEnvironment environment,
    required double sac,
  }) {
    final rows = <PlanScheduleRow>[];
    final litersByTank = <String, double>{};
    double? previousFO2;
    double? previousFHe;

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

    // Same per-leg liters formula as _ascentLiters (average depth across a
    // travel leg, the stop's own depth across a stop), just split by which
    // tank supplied it instead of summed into one total -- so this always
    // adds up to exactly the same worst-case total shown next to it.
    void charge(String? tankId, double seconds, double atDepth) {
      final id = tankId ?? '';
      litersByTank[id] =
          (litersByTank[id] ?? 0) +
          sac * (seconds / 60.0) * environment.pressureAtDepth(atDepth);
    }

    void add({
      required PlanScheduleRowKind kind,
      required double depth,
      required int duration,
      required int runtime,
      required double fO2,
      required double fHe,
    }) {
      final lastFO2 = previousFO2;
      final lastFHe = previousFHe;
      final switched =
          lastFO2 == null ||
          lastFHe == null ||
          (fO2 - lastFO2).abs() > 0.0005 ||
          (fHe - lastFHe).abs() > 0.0005;
      rows.add(
        PlanScheduleRow(
          kind: kind,
          depthMeters: depth,
          durationSeconds: duration,
          runtimeSeconds: runtime,
          gasFO2: fO2,
          gasFHe: fHe,
          tankId: tankForGas(fO2, fHe),
          gasSwitch: switched,
          ppO2: environment.pressureAtDepth(depth) * fO2,
          endMeters: GasMix(
            o2: fO2 * 100,
            he: fHe * 100,
          ).end(depth, o2Narcotic: config.o2Narcotic),
        ),
      );
      previousFO2 = fO2;
      previousFHe = fHe;
    }

    var depth = point.depthMeters;
    // Absolute dive time, continuing from the authored legs printed before
    // this (_legRowsUpTo) rather than restarting at 0, so RT reads
    // continuously across the whole table.
    var end = point.runtimeSeconds;
    var phase = AscentPhase.toFirstStop;
    final stops = point.schedule.stops;
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final travelSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: stop.depthMeters,
        phase: phase,
      );
      if (i == 0 && travelSeconds > 0) {
        final gas = bailoutPlan.gasForDepth(depth);
        final fO2 = 1.0 - gas.fN2 - gas.fHe;
        add(
          kind: PlanScheduleRowKind.ascent,
          depth: stop.depthMeters,
          duration: travelSeconds,
          runtime: end + travelSeconds,
          fO2: fO2,
          fHe: gas.fHe,
        );
        charge(
          tankForGas(fO2, gas.fHe),
          travelSeconds.toDouble(),
          (depth + stop.depthMeters) / 2.0,
        );
      }
      end += travelSeconds + stop.durationSeconds;
      final stopGas = bailoutPlan.gasForDepth(stop.depthMeters);
      final stopFO2 = 1.0 - stopGas.fN2 - stopGas.fHe;
      add(
        kind: PlanScheduleRowKind.stop,
        depth: stop.depthMeters,
        duration: i == 0
            ? stop.durationSeconds
            : stop.durationSeconds + travelSeconds,
        runtime: end,
        fO2: stopFO2,
        fHe: stopGas.fHe,
      );
      final stopTankId = tankForGas(stopFO2, stopGas.fHe);
      if (i > 0) {
        // The merged-in travel time (#3138) breathes whatever gas carried
        // the diver INTO this stop -- the same gas the stop itself is on,
        // per AscentGasPlan's "switch lands at the stop" design.
        charge(stopTankId, travelSeconds.toDouble(), stop.depthMeters);
      }
      charge(stopTankId, stop.durationSeconds.toDouble(), stop.depthMeters);
      depth = stop.depthMeters;
      phase = AscentPhase.betweenStops;
    }
    if (depth > 0) {
      final travelSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: 0,
        phase: AscentPhase.surfacingAfter(phase),
      );
      end += travelSeconds;
      final gas = bailoutPlan.gasForDepth(depth);
      final fO2 = 1.0 - gas.fN2 - gas.fHe;
      add(
        kind: PlanScheduleRowKind.ascent,
        depth: 0,
        duration: travelSeconds,
        runtime: end,
        fO2: fO2,
        fHe: gas.fHe,
      );
      charge(tankForGas(fO2, gas.fHe), travelSeconds.toDouble(), depth / 2.0);
    }
    return (rows: rows, litersByTank: litersByTank);
  }

  /// Stressed-SAC surface liters for an OC ascent: the travel legs at the
  /// rates [policy] defines, the stops themselves, and the final surfacing
  /// leg. Measuring the legs through the policy is what keeps the gas
  /// estimate honest about the slow final stretch, which is where a bailout
  /// spends a surprising share of its volume.
  double _ascentLiters(
    DecoSchedule schedule, {
    required double fromDepth,
    required double sac,
    required SchedulePolicy policy,
    required DiveEnvironment environment,
  }) {
    var liters = 0.0;
    var depth = fromDepth;
    var phase = AscentPhase.toFirstStop;
    for (final stop in schedule.stops) {
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: stop.depthMeters,
        phase: phase,
      );
      liters +=
          sac *
          (legSeconds / 60.0) *
          environment.pressureAtDepth((depth + stop.depthMeters) / 2.0);
      liters +=
          sac *
          (stop.durationSeconds / 60.0) *
          environment.pressureAtDepth(stop.depthMeters);
      depth = stop.depthMeters;
      phase = AscentPhase.betweenStops;
    }
    if (depth > 0) {
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: 0,
        phase: AscentPhase.surfacingAfter(phase),
      );
      liters +=
          sac * (legSeconds / 60.0) * environment.pressureAtDepth(depth / 2.0);
    }
    return liters;
  }
}
