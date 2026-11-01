import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/ascent/ascent_travel_spans.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/entities/segment_phase.dart';
import 'package:submersion/features/planner/domain/services/air_break_runs.dart';
import 'package:submersion/features/planner/domain/services/bailout_chart_support.dart';
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/segment_rate_split.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/domain/services/setpoint_switch_split.dart';
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

/// Where a plan's carried bailout gases stop reaching it (issue #3961): the
/// deepest instant the loop could die at, past the MOD of every one of them.
/// Nothing is eligible there, so no ascent from it can be sized, and more of
/// the same gases cannot change that.
class BailoutGasGap {
  /// The deepest failure depth, which no carried bailout gas reaches.
  final double depthMeters;

  /// The deepest MOD among the carried bailout gases.
  final double deepestModMeters;

  const BailoutGasGap({
    required this.depthMeters,
    required this.deepestModMeters,
  });
}

/// Bailout demand sampled along a CCR plan, with the worst-case instant.
class BailoutOutcome {
  final List<BailoutPoint> points;
  final BailoutPoint worstCase;

  /// Surface liters left in bailout-role tanks at the worst-case instant
  /// (compressibility-corrected): what they carried, less what an authored
  /// off-loop segment, with any problem-solving time the plan charges it, had
  /// already breathed from them by then (#3898).
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

  /// The bailout-role cylinders [availableLiters] was summed from. They show
  /// here because they carry no normal-loop consumption; the main per-tank
  /// gas list includes a bailout cylinder only when an authored off-loop
  /// segment actually breathes it.
  final List<DiveTank> bailoutTanks;

  /// Per-cylinder consumption for the worst-case bailout schedule, read the
  /// same way the main per-tank gas list reads: used/end liters and
  /// pressure, one row per [bailoutTanks] entry. Sums to the same total as
  /// [BailoutPoint.litersRequired] for [worstCase], plus whatever an authored
  /// off-loop segment had already breathed from them by then, the same gas
  /// [availableLiters] leaves out.
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

  /// Null when a carried bailout gas is eligible at every sampled instant.
  /// When set, the figures above were worked out on a gas past its MOD: they
  /// have to answer something, but none of them may be shown as a bailout
  /// plan. It can be set with [worstCase] itself in range, since that instant
  /// is the one that needs the most liters, not the deepest.
  final BailoutGasGap? gasGap;

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
    this.gasGap,
  });

  /// Whether the carried bailout gas gets the diver out: every failure depth
  /// has an eligible gas, and there is enough of it.
  bool get sufficient =>
      gasGap == null && worstCase.litersRequired <= availableLiters;

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

/// Whether [plan] may have a bailout picture, cheaply enough to ask on every
/// edit: a section header or chart toggle can hold its place from this while
/// [BailoutSolver] computes the answer.
///
/// It is one way. False means [BailoutSolver.solve] returns null, but true
/// does not promise a result: a loop plan that never leaves the surface
/// passes here and solves to null, and predicting that takes the walk itself.
bool planMayHaveBailout(domain.DivePlan plan) {
  // Every loop mode (CCR, SCR, pSCR) gets the same bailout picture (issue
  // #3743): the bottom-phase tissue walk is already mode-aware (breathingFor)
  // and TankRoleResolver already derives bailout-role tanks generically for
  // any non-OC plan, so only this gate needs to widen.
  if (plan.mode == domain.PlanMode.oc) return false;
  if (plan.segments.isEmpty) return false;
  // Diluent is the diver's one explicit per-tank choice on a loop plan
  // (TankRoleResolver); every other open-circuit cylinder carried defaults to
  // bailout, so this is simply whatever the resolver left over, never a
  // separate derivation of its own.
  return const TankRoleResolver()
      .apply(plan)
      .tanks
      .any((t) => t.role == TankRole.bailout);
}

/// Answers "what if the loop dies HERE": walks the CCR plan's bottom phase,
/// and at bounded sample intervals computes the full open-circuit bailout
/// (schedule on the bailout gases, stressed SAC) from that instant. The
/// worst case, the instant the cylinders fall shortest once gas an authored
/// off-loop segment already spent counts, sizes the bailout cylinders.
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
    if (!planMayHaveBailout(inputPlan)) return null;
    final plan = const TankRoleResolver().apply(inputPlan);
    final bailoutTanks = plan.tanks
        .where((t) => t.role == TankRole.bailout)
        .toList();
    final segments = withDiluentSwitchTime(
      expandRateSplitSegments(
        List<PlanSegment>.from(plan.segments)
          ..sort((a, b) => a.order.compareTo(b.order)),
        plan,
        descentRate: config.descentRate,
        ascentRate: config.ascentRate,
      ),
      plan,
      gasSwitchStopSeconds: config.gasSwitchStopSeconds,
    );
    final legs = const SegmentChain().resolve(segments);

    // The live plan's own water: an altitude of 0 is unset there (1.0 bar
    // surface), not barometric sea level (issue #3566).
    final environment = PlanEngine.environmentFor(plan);
    // Same policy PlanEngine._policyFor builds: a bailout schedule computed
    // with a plainer policy than the plan it bails out of would size and
    // print stops the plan's own configured minimums and whole-minute
    // snapping never agreed to (caught by a Copilot review).
    //
    // Reads the Deco/Rates fields from [config] (issue #3552), not [plan]
    // directly: by this point [config] is already resolvedFor this plan
    // (see [solve]), so an unset plan field already carries the diver's
    // Settings default.
    final policy = SchedulePolicy(
      lastStopDepth: config.lastStopDepth,
      ascentRate: config.ascentRate,
      intermediateAscentRate: config.intermediateAscentRate,
      shallowAscentRate: config.shallowAscentRate,
      finalAscentRate: config.finalAscentRate,
      descentRate: config.descentRate,
      gasSwitchStopSeconds: config.gasSwitchStopSeconds,
      snapStopsToWholeMinutes: true,
      airBreaks: config.airBreaksFor(plan),
      minStopSecondsByDepth: plan.stopMinimums,
    );
    final model = BuhlmannGf(
      gfLow: config.gfLow / 100.0,
      gfHigh: config.gfHigh / 100.0,
      environment: environment,
      policy: policy,
    );
    final bailoutPlan = config.bailoutAscentGas(bailoutTanks, environment);

    final carriedLiters = bailoutTanks.fold<double>(
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

    // Resolved once per solve, not per sample: the hypercapnia phase (issue
    // #3743) is a plan-level choice, not something that varies by which
    // instant the loop is assumed to die at.
    final stressedAmv = config.sacStressedFor(plan);
    // Never below the stressed rate: the phase is layered over stressed SAC,
    // so a low factor or custom AMV must not shrink the bailout requirement
    // the diver would get with the phase off.
    final hypercapniaAmv = math.max(
      config.hypercapniaAmvFor(plan) ?? stressedAmv,
      stressedAmv,
    );
    final hypercapniaSeconds = config.hypercapniaSecondsFor(plan) ?? 0;

    var state = startState ?? model.initial();
    var elapsed = 0;
    final points = <BailoutPoint>[];
    // Tissue state at each point, same index -- retained so the worst
    // case's own ceiling trace can continue from exactly where its bottom
    // phase left off instead of re-simulating it a second time.
    final states = <TissueState>[];
    // Gas authored off-loop segments have breathed from each bailout cylinder
    // so far, and its snapshot at each point, same index. It is gone by the
    // time the loop dies at that point, charged as PlanEngine charges those
    // segments in the main plan (#3898), problem-solving time included so the
    // two rows for a cylinder agree.
    final spent = <String, double>{};
    final spentAtPoints = <Map<String, double>>[];
    double totalSpentAt(int index) =>
        spentAtPoints[index].values.fold(0.0, (sum, liters) => sum + liters);
    final bailoutTankIds = {for (final tank in bailoutTanks) tank.id};
    final planTankIds = {for (final tank in plan.tanks) tank.id};
    // PlanEngine's fallback for a leg naming a cylinder no longer on the plan.
    String chargedTankId(ResolvedLeg leg) =>
        planTankIds.contains(leg.tankId) ? leg.tankId : plan.tanks.first.id;
    bool isOffLoop(ResolvedLeg leg) => modeFor(plan, leg.segment) != plan.mode;
    final offLoopBottomLeg = PlanEngine.lastLegAtMaxDepth(
      plan,
      legs.where(isOffLoop),
    );

    for (final leg in legs) {
      final segment = leg.segment;
      final tankId = chargedTankId(leg);
      final offLoop = isOffLoop(leg) && bailoutTankIds.contains(tankId);
      if (offLoop && identical(leg, offLoopBottomLeg)) {
        spent[tankId] =
            (spent[tankId] ?? 0) +
            config.problemSolvingLiters(
              plan,
              environment,
              mode: modeFor(plan, segment),
            );
      }
      var covered = 0;
      while (covered < segment.durationSeconds) {
        final chunk = (segment.durationSeconds - covered) < sampleInterval
            ? segment.durationSeconds - covered
            : sampleInterval;
        double depthAt(int secondsIntoSegment) =>
            leg.startDepth +
            (leg.endDepth - leg.startDepth) *
                (secondsIntoSegment / segment.durationSeconds);
        final chunkEndDepth = depthAt(covered + chunk);
        final stretch = DecoSegment(
          startDepth: depthAt(covered),
          endDepth: chunkEndDepth,
          durationSeconds: chunk,
        );

        for (final piece in splitAtSetpointSwitch(plan, segment, stretch)) {
          state = model.applySegment(
            state,
            piece,
            // Same mode-aware breathing PlanEngine.compute replays authored
            // legs with: a segment can override to PlanMode.oc for a
            // mid-plan bailout leg, which must load open-circuit tissues
            // here too, not the loop's constant-ppO2 setpoint regardless of
            // the segment's own mode (caught by a Copilot review).
            breathingFor(
              plan,
              segment.gasMix,
              piece.avgDepth,
              config: config,
              segment: segment,
            ),
          );
        }
        covered += chunk;
        elapsed += chunk;
        if (offLoop) {
          spent[tankId] =
              (spent[tankId] ?? 0) +
              config.cylinderLiters(
                modeFor(plan, segment),
                sac: config.sacForPhase(leg.phase),
                minutes: chunk / 60.0,
                ambientBar: environment.pressureAtDepth(stretch.avgDepth),
              );
        }

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
                hypercapniaAmv: hypercapniaAmv,
                stressedAmv: stressedAmv,
                hypercapniaSeconds: hypercapniaSeconds,
                policy: policy,
                environment: environment,
              ),
              schedule: schedule,
            ),
          );
          states.add(state);
          spentAtPoints.add(Map.of(spent));
        }
      }
    }

    if (points.isEmpty) return null;
    var worstIndex = 0;
    var worstDemand = points.first.litersRequired + totalSpentAt(0);
    for (var i = 1; i < points.length; i++) {
      final demand = points[i].litersRequired + totalSpentAt(i);
      if (demand > worstDemand) {
        worstIndex = i;
        worstDemand = demand;
      }
    }
    final worst = points[worstIndex];
    final spentAtWorst = spentAtPoints[worstIndex];
    // Every point, not just the worst: that one needs the most liters, which
    // a long shallow hold can claim from a brief trip past every MOD. Legs
    // end on a sample, so the plan's deepest point is always among these.
    final deepestPoint = points
        .map((point) => point.depthMeters)
        .reduce(math.max);
    final ccrRows = _legRowsUpTo(worst, legs, plan, environment);
    final ocSchedule = _scheduleRowsFor(
      worst,
      bailoutTanks: bailoutTanks,
      bailoutPlan: bailoutPlan,
      policy: policy,
      environment: environment,
      hypercapniaAmv: hypercapniaAmv,
      stressedAmv: stressedAmv,
      hypercapniaSeconds: hypercapniaSeconds,
    );
    return BailoutOutcome(
      gasGap: bailoutPlan.coversDepth(deepestPoint)
          ? null
          : BailoutGasGap(
              depthMeters: deepestPoint,
              deepestModMeters: bailoutPlan.deepestMod,
            ),
      points: points,
      worstCase: worst,
      availableLiters: math.max(0.0, carriedLiters - totalSpentAt(worstIndex)),
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
            final used =
                (ocSchedule.litersByTank[tank.id] ?? 0.0) +
                (spentAtWorst[tank.id] ?? 0.0);
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
      // A loop leg's real inspired ppO2 comes from its own mode's breathing
      // model (the CCR setpoint, or the SCR/pSCR loop fraction), not
      // ambient x the supply gas's own fraction; an OC leg is ambient x
      // fO2. Same as PlanEngine's PO2 column (plan_engine.dart,
      // _buildSchedule's ppO2Override), so SCR/pSCR (issue #3743) read as
      // their own loop rather than as a CCR setpoint.
      final ambient = environment.pressureAtDepth(depth);
      final ppO2 = modeFor(plan, leg.segment) == domain.PlanMode.oc
          ? ambient * fO2
          : breathingFor(
              plan,
              leg.segment.gasMix,
              depth,
              config: config,
              segment: leg.segment,
            ).inspiredAt(ambient).pO2;
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
    required double hypercapniaAmv,
    required double stressedAmv,
    required int hypercapniaSeconds,
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

    // Same per-leg liters formula as _ascentLiters (a travel leg's linear
    // depth range, the stop's own depth across a stop, split at the
    // hypercapnia-phase boundary, issue #3743), just split by which tank
    // supplied it instead of summed into one total, so this adds up to the
    // worst-case total shown next to it, to within the whole-second rounding
    // of a leg split at a gas switch.
    void charge(
      String? tankId,
      double secondsSinceBailoutStart,
      double seconds,
      double fromDepth,
      double toDepth,
    ) {
      final id = tankId ?? '';
      litersByTank[id] =
          (litersByTank[id] ?? 0) +
          bailoutSpanLiters(
            startSecondsSinceBailout: secondsSinceBailoutStart,
            durationSeconds: seconds,
            fromDepth: fromDepth,
            toDepth: toDepth,
            hypercapniaAmv: hypercapniaAmv,
            stressedAmv: stressedAmv,
            hypercapniaSeconds: hypercapniaSeconds,
            environment: environment,
          );
    }

    void add({
      required PlanScheduleRowKind kind,
      required double depth,
      required int duration,
      required int runtime,
      required double fO2,
      required double fHe,
      int airBreakSeconds = 0,
      String? airBreakTankId,
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
          airBreakSeconds: airBreakSeconds,
          airBreakTankId: airBreakTankId,
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

    // Split at every gas-switch depth crossed, same as PlanEngine's own travel
    // legs (#3225): a carried gas whose MOD falls strictly between a leg's
    // ends would otherwise never appear, its whole usable window sitting
    // inside a leg charged entirely to the gas valid at the deepest point.
    // Each stretch is charged at its own average depth, same as _ascentLiters:
    // charging it at a stop's shallower depth alone undercounted every
    // between-stops leg, so the per-tank total fell short of the worst case's
    // own litersRequired on every plan with more than one stop. A leg into a
    // later stop prints no rows of its own: its time folds into the stop's
    // line (#3138), though it is still breathed on the gas it left.
    void addTravelLeg(
      double from,
      double to,
      int seconds,
      int startRuntime, {
      required bool printed,
    }) {
      var legStartRuntime = startRuntime;
      for (final span in splitAscentLeg(
        bailoutPlan,
        fromDepth: from,
        toDepth: to,
        seconds: seconds,
      )) {
        final gas = bailoutPlan.gasForDepth(span.fromDepth);
        if (printed) {
          add(
            kind: PlanScheduleRowKind.ascent,
            depth: span.toDepth,
            duration: span.seconds,
            runtime: legStartRuntime + span.seconds,
            fO2: gas.fO2,
            fHe: gas.fHe,
            physicsDepth: span.fromDepth,
            endPhysicsDepth: span.toDepth == 0 ? 0 : null,
          );
        }
        charge(
          tankForGas(gas.fO2, gas.fHe),
          (legStartRuntime - point.runtimeSeconds).toDouble(),
          span.seconds.toDouble(),
          span.fromDepth,
          span.toDepth,
        );
        legStartRuntime += span.seconds;
      }
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
      // This iteration's own absolute start, captured before `end` moves
      // past it below -- the base every charge() call in this iteration
      // measures its own secondsSinceBailoutStart from (issue #3743).
      final iterStartRuntime = end;
      if (travelSeconds > 0) {
        addTravelLeg(
          depth,
          stop.depthMeters,
          travelSeconds,
          iterStartRuntime,
          printed: i == 0,
        );
      }
      end += travelSeconds + stop.durationSeconds;
      final stopGas = bailoutPlan.gasForDepth(stop.depthMeters);
      final stopTankId = tankForGas(stopGas.fO2, stopGas.fHe);
      final breakTankId = airBreakTankIdFor(
        stop,
        plan: bailoutPlan,
        stopTankId: stopTankId,
        tankForGas: tankForGas,
      );
      add(
        kind: PlanScheduleRowKind.stop,
        depth: stop.depthMeters,
        duration: i == 0
            ? stop.durationSeconds
            : stop.durationSeconds + travelSeconds,
        runtime: end,
        fO2: stopGas.fO2,
        fHe: stopGas.fHe,
        airBreakSeconds: stop.airBreakSeconds,
        airBreakTankId: breakTankId,
      );
      // Run by run, in the scheduler's own order, because the hypercapnia
      // phase can end part way through a stop and the rate changes there.
      var runStart = (iterStartRuntime + travelSeconds - point.runtimeSeconds)
          .toDouble();
      final airBreaks = policy.airBreaks;
      final runs = breakTankId != null && airBreaks != null
          ? airBreakRuns(stop.durationSeconds, airBreaks)
          : [(onBreak: false, seconds: stop.durationSeconds)];
      for (final run in runs) {
        charge(
          run.onBreak ? breakTankId : stopTankId,
          runStart,
          run.seconds.toDouble(),
          stop.depthMeters,
          stop.depthMeters,
        );
        runStart += run.seconds;
      }
      depth = stop.depthMeters;
      phase = AscentPhase.betweenStops;
    }
    if (depth > 0) {
      final travelSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: 0,
        phase: AscentPhase.surfacingAfter(phase),
      );
      addTravelLeg(depth, 0, travelSeconds, end, printed: true);
    }
    return (rows: rows, litersByTank: litersByTank);
  }

  /// Stressed-SAC surface liters for an OC ascent: the travel legs at the
  /// rates [policy] defines, the stops themselves, and the final surfacing
  /// leg. Measuring the legs through the policy is what keeps the gas
  /// estimate honest about the slow final stretch, which is where a bailout
  /// spends a surprising share of its volume.
  ///
  /// [hypercapniaAmv]/[hypercapniaSeconds] (issue #3743) charge the elevated
  /// hypercapnia-phase rate for the first [hypercapniaSeconds] of the
  /// ascent, [stressedAmv] for the remainder; [hypercapniaSeconds] is 0 when
  /// the phase is off for this plan, which charges every leg at
  /// [stressedAmv] alone, same as before this feature existed.
  double _ascentLiters(
    DecoSchedule schedule, {
    required double fromDepth,
    required double hypercapniaAmv,
    required double stressedAmv,
    required int hypercapniaSeconds,
    required SchedulePolicy policy,
    required DiveEnvironment environment,
  }) {
    var liters = 0.0;
    var depth = fromDepth;
    var phase = AscentPhase.toFirstStop;
    var elapsed = 0.0;
    for (final stop in schedule.stops) {
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: stop.depthMeters,
        phase: phase,
      );
      liters += bailoutSpanLiters(
        startSecondsSinceBailout: elapsed,
        durationSeconds: legSeconds.toDouble(),
        fromDepth: depth,
        toDepth: stop.depthMeters,
        hypercapniaAmv: hypercapniaAmv,
        stressedAmv: stressedAmv,
        hypercapniaSeconds: hypercapniaSeconds,
        environment: environment,
      );
      elapsed += legSeconds;
      liters += bailoutSpanLiters(
        startSecondsSinceBailout: elapsed,
        durationSeconds: stop.durationSeconds.toDouble(),
        fromDepth: stop.depthMeters,
        toDepth: stop.depthMeters,
        hypercapniaAmv: hypercapniaAmv,
        stressedAmv: stressedAmv,
        hypercapniaSeconds: hypercapniaSeconds,
        environment: environment,
      );
      elapsed += stop.durationSeconds;
      depth = stop.depthMeters;
      phase = AscentPhase.betweenStops;
    }
    if (depth > 0) {
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: 0,
        phase: AscentPhase.surfacingAfter(phase),
      );
      liters += bailoutSpanLiters(
        startSecondsSinceBailout: elapsed,
        durationSeconds: legSeconds.toDouble(),
        fromDepth: depth,
        toDepth: 0,
        hypercapniaAmv: hypercapniaAmv,
        stressedAmv: stressedAmv,
        hypercapniaSeconds: hypercapniaSeconds,
        environment: environment,
      );
    }
    return liters;
  }
}

/// Surface liters for a span of [durationSeconds] starting
/// [startSecondsSinceBailout] after the bailout instant, split at the
/// hypercapnia-phase boundary (issue #3743): the portion before
/// [hypercapniaSeconds] charged at [hypercapniaAmv], the remainder at
/// [stressedAmv]. A span entirely on one side of the boundary is charged at
/// the span's mean depth, same as before this feature existed; that is
/// every span when [hypercapniaSeconds] is 0, i.e. the phase is off for
/// this plan.
///
/// The span runs linearly from [fromDepth] to [toDepth] (equal for a
/// stop), so each portion is charged at its OWN mean depth: on a travel
/// leg the hypercapnia portion is always the deeper start, and charging
/// it at the whole leg's midpoint would undercount the bailout gas.
double bailoutSpanLiters({
  required double startSecondsSinceBailout,
  required double durationSeconds,
  required double fromDepth,
  required double toDepth,
  required double hypercapniaAmv,
  required double stressedAmv,
  required int hypercapniaSeconds,
  required DiveEnvironment environment,
}) {
  if (durationSeconds <= 0) return 0.0;
  final endSeconds = startSecondsSinceBailout + durationSeconds;
  final hypercapniaPortion = hypercapniaSeconds <= startSecondsSinceBailout
      ? 0.0
      : math.min(endSeconds, hypercapniaSeconds.toDouble()) -
            startSecondsSinceBailout;
  final stressedPortion = durationSeconds - hypercapniaPortion;
  // Depth after [seconds] into the span.
  double depthAt(double seconds) =>
      fromDepth + (toDepth - fromDepth) * (seconds / durationSeconds);
  final hypercapniaLiters = hypercapniaPortion <= 0
      ? 0.0
      : hypercapniaAmv *
            (hypercapniaPortion / 60.0) *
            environment.pressureAtDepth(
              (fromDepth + depthAt(hypercapniaPortion)) / 2.0,
            );
  final stressedLiters = stressedPortion <= 0
      ? 0.0
      : stressedAmv *
            (stressedPortion / 60.0) *
            environment.pressureAtDepth(
              (depthAt(hypercapniaPortion) + toDepth) / 2.0,
            );
  return hypercapniaLiters + stressedLiters;
}
