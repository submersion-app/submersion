import 'dart:math' as math;

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
import 'package:submersion/features/planner/domain/services/bailout_chart_support.dart';
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/segment_rate_split.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';
import 'package:submersion/features/planner/domain/services/tank_usage_order.dart';

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

  /// The CCR portion of [worstCaseRows] alone (one row per authored leg up
  /// to the worst-case instant, unfolded) -- the chart's Bailout toggle
  /// draws its profile from this plus [worstCase].schedule.stops, not from
  /// [worstCaseRows]: a stop after the first folds its own travel time into
  /// one table line (#3138's printing convention), which has no separate
  /// arrival point to draw and would render as a smooth diagonal instead of
  /// the flat-hold-then-climb steps every other stop shows.
  final List<PlanScheduleRow> ccrRows;

  /// The bailout-role cylinders [availableLiters] was summed from -- shown
  /// here rather than in the main per-tank gas list, since they carry no
  /// normal-loop consumption to chart there.
  final List<DiveTank> bailoutTanks;

  /// Per-cylinder consumption for the worst-case bailout schedule, read the
  /// same way the main per-tank gas list reads: used/end liters and
  /// pressure, one row per [bailoutTanks] entry. Sums to the same total as
  /// [BailoutPoint.litersRequired] for [worstCase].
  final List<PlanTankUsage> bailoutTankUsages;

  /// The worst-case point's own ceiling, sampled the same way
  /// [PlanOutcome.ceilingTrace] is: CCR up to the worst-case instant, then
  /// the OC ascent it was sized from -- the chart's Bailout toggle
  /// (#3130) draws this instead of the CCR ceiling, which tracks a
  /// different gas plan past the switch and would show a no-go band that
  /// disagrees with the bailout profile crossing it.
  final List<(int runtimeSeconds, double ceilingMeters)> ceilingTrace;

  /// The worst-case point's OC ascent stops, unfolded -- one entry per
  /// actual stop, each with its own arrival time and gas, unlike
  /// [worstCaseRows] where a stop after the first folds its own travel
  /// time into one printed table line (#3138's convention). The chart's
  /// Bailout toggle draws its profile from [ccrRows] plus this, not from
  /// [worstCaseRows]: a folded row has no separate arrival point to draw
  /// and would render as a smooth diagonal between stops instead of the
  /// flat-hold-then-climb steps every other stop shows.
  final List<PlanStop> ocStops;

  const BailoutOutcome({
    required this.points,
    required this.worstCase,
    required this.availableLiters,
    required this.worstCaseRows,
    required this.ccrRows,
    required this.bailoutTanks,
    required this.bailoutTankUsages,
    required this.ceilingTrace,
    required this.ocStops,
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

  /// Resolves this solver's [config] against [inputPlan]'s own gas-option
  /// overrides (ppO2Deco, o2Narcotic, bestMixEndMeters, sacFactor) before
  /// solving, the same way [PlanEngine.compute] does -- so a plan-specific
  /// override actually reaches the bailout picture instead of silently
  /// falling back to the diver's global settings every time (a diver
  /// confirmed this directly: the plan's own O2-narcotic choice changed
  /// the main table but never the bailout one).
  ///
  /// [startState] is the live plan's seeded tissues (a repetitive dive's
  /// residual loading); the loop walk starts from it, as the live plan does.
  BailoutOutcome? solve(domain.DivePlan inputPlan, {TissueState? startState}) {
    return BailoutSolver(
      config: config.resolvedFor(inputPlan),
    )._solveInternal(inputPlan, startState);
  }

  BailoutOutcome? _solveInternal(
    domain.DivePlan inputPlan,
    TissueState? startState,
  ) {
    // Same contract as PlanEngine.compute: the walk below runs on BuhlmannGf,
    // so a foreign seed fails here rather than on a cast mid-walk.
    if (startState != null && startState is! BuhlmannState) {
      throw ArgumentError.value(
        startState,
        'startState',
        'BailoutSolver only accepts a BuhlmannState tissue seed',
      );
    }
    if (inputPlan.mode != domain.PlanMode.ccr) return null;
    // Diluent is the diver's one explicit per-tank choice on a loop plan
    // (TankRoleResolver); every other open-circuit cylinder carried
    // defaults to bailout, so this is simply whatever the resolver left
    // over, never a separate derivation of its own.
    final plan = const TankRoleResolver().apply(inputPlan);
    final bailoutTanks = plan.tanks
        .where((t) => t.role == TankRole.bailout)
        .toList();
    if (bailoutTanks.isEmpty) return null;
    final segments = withDiluentSwitchTime(
      expandRateSplitSegments(
        List<PlanSegment>.from(plan.segments)
          ..sort((a, b) => a.order.compareTo(b.order)),
        plan,
      ),
      plan,
    );
    if (segments.isEmpty) return null;
    final legs = const SegmentChain().resolve(segments);

    final environment = DiveEnvironment.forConditions(
      altitudeMeters: plan.altitude,
      waterType: plan.waterType ?? WaterType.salt,
      salinityPpt: plan.salinityPpt,
    );
    // Same policy PlanEngine._policyFor builds: a bailout schedule computed
    // with a plainer policy than the plan it bails out of would size and
    // print stops the plan's own configured minimums and whole-minute
    // snapping never agreed to (caught by a Copilot review).
    final policy = SchedulePolicy(
      lastStopDepth: plan.lastStopDepth,
      ascentRate: plan.ascentRate,
      intermediateAscentRate: plan.intermediateAscentRate,
      shallowAscentRate: plan.shallowAscentRate,
      finalAscentRate: plan.finalAscentRate,
      descentRate: plan.descentRate,
      gasSwitchStopSeconds: plan.gasSwitchStopSeconds,
      snapStopsToWholeMinutes: true,
      airBreaks: plan.airBreaks,
      minStopSecondsByDepth: plan.stopMinimums,
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

    var state = startState ?? model.initial();
    var elapsed = 0;
    final points = <BailoutPoint>[];
    // Tissue state at each point, same index -- retained so the worst
    // case's own ceiling trace can continue from exactly where its bottom
    // phase left off instead of re-simulating it a second time.
    final states = <TissueState>[];

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
          // Same mode-aware breathing PlanEngine.compute replays authored
          // legs with: a segment can override to PlanMode.oc for a
          // mid-plan bailout leg, which must load open-circuit tissues
          // here too, not the loop's constant-ppO2 setpoint regardless of
          // the segment's own mode (caught by a Copilot review).
          breathingFor(
            plan,
            segment.gasMix,
            chunkAvg,
            config: config,
            segment: segment,
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
          states.add(state);
        }
      }
    }

    if (points.isEmpty) return null;
    var worstIndex = 0;
    for (var i = 1; i < points.length; i++) {
      if (points[i].litersRequired > points[worstIndex].litersRequired) {
        worstIndex = i;
      }
    }
    final worst = points[worstIndex];
    final ccrRows = _legRowsUpTo(worst, legs, plan, environment);
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
      ccrRows: ccrRows,
      worstCaseRows: [...ccrRows, ...ocSchedule.rows],
      ocStops: unfoldedOcStops(
        worst,
        bailoutPlan: bailoutPlan,
        policy: policy,
        bailoutTanks: bailoutTanks,
      ),
      ceilingTrace: worstCaseCeilingTrace(
        model: model,
        points: points,
        states: states,
        worstIndex: worstIndex,
        bailoutPlan: bailoutPlan,
        policy: policy,
      ),
      bailoutTanks: bailoutTanks,
      // Listed in the order the worst-case table breathes them, not the
      // order the diver happened to add the cylinders.
      bailoutTankUsages: orderUsagesByFirstUse([
        for (final tank in bailoutTanks)
          () {
            final used = ocSchedule.litersByTank[tank.id] ?? 0.0;
            final start = tank.startPressure;
            final total = start != null
                ? gasVolume(
                    tankSizeLiters: tank.volume ?? 11.0,
                    pressureBar: start,
                    o2Percent: tank.gasMix.o2,
                    hePercent: tank.gasMix.he,
                    model: config.gasModel,
                  )
                : null;
            // Negative once used exceeds total: the shortfall, priced as a
            // pressure the same way the surplus on an ordinary line is, not
            // floored to 0 as if the cylinder had exactly covered it (#3190).
            final remaining = start == null
                ? null
                : (total != null && used > total)
                ? -pressureHoldingVolume(
                    tankSizeLiters: tank.volume ?? 11.0,
                    litersRequired: used - total,
                    o2Percent: tank.gasMix.o2,
                    hePercent: tank.gasMix.he,
                    model: config.gasModel,
                  )
                : pressureAfterConsuming(
                    tankSizeLiters: tank.volume ?? 11.0,
                    startPressureBar: start,
                    litersConsumed: used,
                    o2Percent: tank.gasMix.o2,
                    hePercent: tank.gasMix.he,
                    model: config.gasModel,
                  );
            return PlanTankUsage(
              tankId: tank.id,
              litersUsed: used,
              totalLiters: total,
              remainingPressure: remaining,
              startPressure: start,
              percentUsed: start != null && start > 0
                  ? (start - (remaining ?? 0)) / start * 100.0
                  : 0.0,
              // Reuses reserveViolation's existing red-highlight treatment
              // to flag that this cylinder's own usage exceeds its own
              // capacity (#3190).
              reserveViolation: total != null && used > total,
            );
          }(),
      ], ocSchedule.rows),
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
          // Floored at 0 m, same as PlanEngine's END column: GasMix.end()
          // goes negative for a helium-rich mix at shallow depth.
          endMeters: math.max(
            0.0,
            GasMix(
              o2: fO2 * 100,
              he: fHe * 100,
            ).end(depth, o2Narcotic: config.o2Narcotic),
          ),
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
      // Same convention as PlanEngine._buildSchedule: a travel row picks
      // its gas at the leg's deeper end but displays the arrival depth, so
      // ppO2/END are computed where the gas was chosen -- the leg's maximum
      // on that gas -- and the two tables read alike.
      double? physicsDepth,
      // Overrides physicsDepth for END alone, used only for the final
      // surfacing leg: its ppO2 still reads the deeper end it leaves (the
      // row above's own ppO2), but its END must read the depth it actually
      // displays (0 m) -- there is no further stop downstream whose safety
      // margin the deeper-end reading would protect, and reading it at the
      // deeper end reintroduced the un-floored negative END this column
      // exists to avoid (#3137).
      double? endPhysicsDepth,
    }) {
      final lastFO2 = previousFO2;
      final lastFHe = previousFHe;
      final switched =
          lastFO2 == null ||
          lastFHe == null ||
          (fO2 - lastFO2).abs() > 0.0005 ||
          (fHe - lastFHe).abs() > 0.0005;
      final pDepth = physicsDepth ?? depth;
      final endDepth = endPhysicsDepth ?? pDepth;
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
          ppO2: environment.pressureAtDepth(pDepth) * fO2,
          // Floored at 0 m, same as PlanEngine's END column.
          endMeters: math.max(
            0.0,
            GasMix(
              o2: fO2 * 100,
              he: fHe * 100,
            ).end(endDepth, o2Narcotic: config.o2Narcotic),
          ),
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
        // Split at every gas-switch depth crossed, same as PlanEngine's own
        // first travel leg (#3225): a carried gas whose MOD falls strictly
        // between the bailout depth and the first stop would otherwise
        // never appear -- its whole usable window sits inside this one
        // leg, which used to be charged entirely to the gas valid at the
        // deepest point.
        final boundaries = travelLegBoundaries(
          bailoutPlan,
          fromDepth: depth,
          toDepth: stop.depthMeters,
        );
        final totalSpan = depth - stop.depthMeters;
        var legDepth = depth;
        var legRuntime = end;
        var remaining = travelSeconds;
        for (var j = 1; j < boundaries.length; j++) {
          final legTo = boundaries[j];
          final isLast = j == boundaries.length - 1;
          final legSeconds = isLast
              ? remaining
              : (travelSeconds * (legDepth - legTo) / totalSpan).round();
          remaining -= legSeconds;
          legRuntime += legSeconds;
          final gas = bailoutPlan.gasForDepth(legDepth);
          final fO2 = 1.0 - gas.fN2 - gas.fHe;
          add(
            kind: PlanScheduleRowKind.ascent,
            depth: legTo,
            duration: legSeconds,
            runtime: legRuntime,
            fO2: fO2,
            fHe: gas.fHe,
            physicsDepth: legDepth,
          );
          charge(
            tankForGas(fO2, gas.fHe),
            legSeconds.toDouble(),
            (legDepth + legTo) / 2.0,
          );
          legDepth = legTo;
        }
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
        // per AscentGasPlan's "switch lands at the stop" design. Charged at
        // the leg's own average depth, same as _ascentLiters: charging it
        // at the stop's (shallower) depth alone undercounted every
        // between-stops travel leg, so the per-tank total fell short of
        // the worst case's own litersRequired by the same margin on every
        // plan with more than one stop.
        charge(
          stopTankId,
          travelSeconds.toDouble(),
          (depth + stop.depthMeters) / 2.0,
        );
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
        physicsDepth: depth,
        endPhysicsDepth: 0,
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
