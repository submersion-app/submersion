import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/ascent/ccr_loop_ascent_gas.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/segment_phase.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';
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

  /// CCR metabolic O2 consumption (surface liters per minute).
  final double o2MetabolicRateLpm;

  /// CCR loop + counterlung volume, for descent diluent consumption.
  final double loopVolumeLiters;

  /// Rock-bottom sizing: how many divers share the emergency ascent.
  final double buddyFactor;

  /// SCR supply injection rate (surface liters per minute) for the CMF loop.
  final double scrInjectionRateLpm;

  /// pSCR metabolic O2 consumption in surface mL/min (Subsurface
  /// `o2consumption`, default 720).
  final double pscrO2ConsumptionMlMin;

  /// pSCR bottom surface air consumption in mL/min (Subsurface `bottomsac`,
  /// default 20000).
  final double pscrSacMlMin;

  /// pSCR ratio (Subsurface `pscr_ratio`, default 100). Larger dumps/adds more
  /// fresh gas and shrinks the inspired-O2 drop.
  final double pscrRatio;

  /// Algorithm used to convert ppO2 exposure into CNS %/min.
  final CnsCalculationMethod cnsMethod;

  /// Equation of state used to convert cylinder pressure to gas volume.
  ///
  /// Shared by [PlanEngine] and [BailoutSolver] so a plan's gas budget and its
  /// bailout check never disagree about how much gas a cylinder holds. Sourced
  /// from `gasModelProvider` (issue #828).
  final GasModel gasModel;

  const PlanEngineConfig({
    this.ppO2Working = 1.4,
    this.ppO2Deco = 1.6,
    this.cnsWarningThreshold = 80,
    this.o2Narcotic = true,
    this.endLimitMeters = 30.0,
    this.otuLimit = 300.0,
    this.o2MetabolicRateLpm = 1.0,
    this.loopVolumeLiters = 6.0,
    this.buddyFactor = 2.0,
    this.scrInjectionRateLpm = 12.0,
    this.pscrO2ConsumptionMlMin = 720.0,
    this.pscrSacMlMin = 20000.0,
    this.pscrRatio = 100.0,
    this.cnsMethod = CnsCalculationMethod.shearwater,
    this.gasModel = GasModel.real,
  });
}

/// Turns a [domain.DivePlan] into a [PlanOutcome] on the Phase 1 engine
/// seams: DecoModel (BuhlmannGf), SchedulePolicy, BreathingConfig,
/// DiveEnvironment.
///
/// Open-circuit plans breathe their segment gases; CCR plans load at the
/// constant-ppO2 setpoints (segments' gases are the diluent) and their deco
/// schedules run on the loop via [CcrLoopAscentGas].
class PlanEngine {
  final PlanEngineConfig config;

  const PlanEngine({this.config = const PlanEngineConfig()});

  /// The breathing mode in force for [segment] (its per-segment override, or
  /// the plan's mode). Models mid-plan bailout.
  domain.PlanMode _modeFor(domain.DivePlan plan, PlanSegment? segment) =>
      segment?.diveModeOverride ?? plan.mode;

  /// Setpoint in force at [depth]: the segment's per-segment override if set,
  /// else the plan's depth-based (low/high) setpoint.
  double _setpointAt(
    domain.DivePlan plan,
    double depth, {
    PlanSegment? segment,
  }) {
    final override = segment?.setpointBar;
    if (override != null) return override;
    return depth > plan.effectiveSetpointSwitchDepth
        ? plan.effectiveSetpointHigh
        : plan.effectiveSetpointLow;
  }

  /// Mode-aware breathing for [gas] at [depth]: the loop at the in-force
  /// setpoint for CCR (gas = diluent), CMF loop for SCR, open circuit
  /// otherwise. A per-segment [segment] override wins over the plan mode.
  BreathingConfig _breathingFor(
    domain.DivePlan plan,
    GasMix gas,
    double depth, {
    PlanSegment? segment,
  }) {
    final mode = _modeFor(plan, segment);
    if (mode == domain.PlanMode.ccr) {
      return ClosedCircuit(
        setpoint: _setpointAt(plan, depth, segment: segment),
        diluentFO2: gas.o2 / 100.0,
        diluentFHe: gas.he / 100.0,
      );
    }
    if (mode == domain.PlanMode.scr) {
      // CMF semi-closed loop: the segment gas is the supply, and the loop
      // fraction is the validated steady-state CMF calculation.
      return Scr(
        supplyFO2: gas.o2 / 100.0,
        supplyFHe: gas.he / 100.0,
        injectionRateLpm: config.scrInjectionRateLpm,
      );
    }
    if (mode == domain.PlanMode.pscr) {
      // Passive-addition semi-closed loop (Subsurface pscr_o2 model): the
      // inspired O2 is the supply ppO2 minus a fixed metabolic drop.
      return PassiveScr(
        supplyFO2: gas.o2 / 100.0,
        supplyFHe: gas.he / 100.0,
        o2ConsumptionMlMin: config.pscrO2ConsumptionMlMin,
        sacMlMin: config.pscrSacMlMin,
        pscrRatio: config.pscrRatio,
      );
    }
    return OpenCircuit(fO2: gas.o2 / 100.0, fHe: gas.he / 100.0);
  }

  PlanOutcome compute(domain.DivePlan inputPlan, {TissueState? startState}) {
    // Cylinder roles are derived from the mixes and the segments that breathe
    // them rather than declared by the diver, so resolve them before any of
    // the role-dependent maths below (turn pressure, rock bottom, deco-gas
    // attribution, CCR O2/diluent). Applied to a local copy: the stored role
    // stays the diver's raw bailout override.
    final plan = const TankRoleResolver().apply(inputPlan);
    // The engine hard-codes BuhlmannGf and casts state back to BuhlmannState;
    // reject a foreign seed up front so misuse fails predictably instead of
    // crashing mid-computation on an opaque cast.
    if (startState != null && startState is! BuhlmannState) {
      throw ArgumentError.value(
        startState,
        'startState',
        'PlanEngine only accepts a BuhlmannState tissue seed',
      );
    }
    final isCcr = plan.mode == domain.PlanMode.ccr;
    final environment = DiveEnvironment.forConditions(
      // Altitude <= 0 is treated as unset (legacy 1.0 bar surface), matching
      // the rest of the planner — a literal 0 must not switch to barometric
      // sea-level pressure and subtly change the deco math.
      altitudeMeters: (plan.altitude ?? 0) > 0 ? plan.altitude : null,
      waterType: plan.waterType,
    );
    final policy = _policyFor(plan);
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
      cnsMethod: config.cnsMethod,
    );

    final segments = List<PlanSegment>.from(plan.segments)
      ..sort((a, b) => a.order.compareTo(b.order));
    // Waypoints carry only a target depth, so the profile they describe -
    // start depths, phases, rates - is resolved once here, and everything
    // downstream reads legs rather than segments.
    final legs = const SegmentChain().resolve(segments);
    final ascentPlan = isCcr
        ? CcrLoopAscentGas(
            environment: environment,
            setpointLow: plan.effectiveSetpointLow,
            setpointHigh: plan.effectiveSetpointHigh,
            switchDepth: plan.effectiveSetpointSwitchDepth,
            diluentFO2: segments.isEmpty
                ? 0.21
                : segments.last.gasMix.o2 / 100.0,
            diluentFHe: segments.isEmpty
                ? 0.0
                : segments.last.gasMix.he / 100.0,
          )
        : _ascentPlanFor(plan.tanks);

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

    for (final leg in legs) {
      final segment = leg.segment;
      final startRuntime = runtime;
      final breathing = _breathingFor(
        plan,
        segment.gasMix,
        leg.avgDepth,
        segment: segment,
      );
      // The segment's effective breathing mode is loop-based (CCR/SCR) unless
      // OC - drives the ppO2 convention below.
      final segmentIsLoop = _modeFor(plan, segment) != domain.PlanMode.oc;

      state = model.applySegment(
        state,
        DecoSegment(
          startDepth: leg.startDepth,
          endDepth: leg.endDepth,
          durationSeconds: segment.durationSeconds,
        ),
        breathing,
      );
      runtime += segment.durationSeconds;
      timeline.add((runtime, state as BuhlmannState));

      final deeperEnd = leg.deeperEnd;
      // OC ppO2 keeps the legacy ambient x fraction convention; loop ppO2 is
      // the inspired (setpoint/CMF) value.
      final segmentMaxPpO2 = segmentIsLoop
          ? _breathingFor(
              plan,
              segment.gasMix,
              deeperEnd,
              segment: segment,
            ).inspiredAt(environment.pressureAtDepth(deeperEnd)).pO2
          : O2ToxicityCalculator.calculatePpO2(
              deeperEnd,
              segment.gasMix.o2 / 100.0,
            );
      if (segmentMaxPpO2 > maxPpO2) maxPpO2 = segmentMaxPpO2;

      final avgPpO2 = segmentIsLoop
          ? breathing.inspiredAt(environment.pressureAtDepth(leg.avgDepth)).pO2
          : O2ToxicityCalculator.calculatePpO2(
              leg.avgDepth,
              segment.gasMix.o2 / 100.0,
            );
      cns += o2Calc.calculateCnsForSegment(avgPpO2, segment.durationSeconds);
      otu += o2Calc.calculateOtuForSegment(avgPpO2, segment.durationSeconds);

      final ndl = model.ndlSeconds(
        state,
        depthMeters: leg.endDepth,
        breathing: _breathingFor(
          plan,
          segment.gasMix,
          leg.endDepth,
          segment: segment,
        ),
      );
      // Only report a ceiling once deco is actually owed, the same gate
      // getDecoStatus applies for dive details: a GF ceiling exists from the
      // moment supersaturation crosses the GF-low line, well before a direct
      // ascent stops being allowed.
      final ceiling = ndl < 0 ? model.ceilingMeters(state) : 0.0;
      final tts = leg.endDepth > 0
          ? model
                .schedule(state, currentDepth: leg.endDepth, gases: ascentPlan)
                .ttsSeconds
          : 0;

      // The deepest leg is the bottom. The old condition also tested for a
      // declared bottom type, which this depth test already subsumed.
      if (leg.endDepth >= maxDepth - 0.1) {
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
    final lastDepth = legs.isEmpty ? 0.0 : legs.last.endDepth;
    final schedule = lastDepth > 0
        ? model.schedule(state, currentDepth: lastDepth, gases: ascentPlan)
        : const DecoSchedule(stops: [], ttsSeconds: 0);
    final stops = _mapStops(schedule, plan, ascentPlan, lastDepth, runtime);
    final scheduleRows = _buildSchedule(
      legs,
      stops,
      plan,
      ascentPlan,
      lastDepth,
      runtime,
    );

    // A separate, finely-sampled replay purely for the chart's ceiling curve.
    // It never feeds back into `state`/cns/otu/stops, so it cannot perturb
    // the numbers the rest of this method already computed and returned.
    final ceilingTrace = _ceilingTrace(
      model,
      plan,
      legs,
      stops,
      lastDepth,
      ascentPlan,
    );

    // Decompression stops carry O2 exposure too — a long stop on a rich deco
    // gas is where CNS/OTU pile up — so accumulate them before issues and the
    // outcome are built. Each stop splits into its primary gas and, when air
    // breaks apply, the break gas for that portion. On CCR the loop holds a
    // constant ppO2; CcrLoopAscentGas expresses that as effective fractions
    // where ambient x gasFO2 reproduces the setpoint, so the same formula is
    // correct in both modes.
    for (final stop in stops) {
      final stopPressure = environment.pressureAtDepth(stop.depthMeters);
      final primarySeconds = stop.durationSeconds - stop.airBreakSeconds;
      final primaryPpO2 = stopPressure * stop.gasFO2;
      cns += o2Calc.calculateCnsForSegment(primaryPpO2, primarySeconds);
      otu += o2Calc.calculateOtuForSegment(primaryPpO2, primarySeconds);
      if (stop.airBreakSeconds > 0) {
        final breakGas = ascentPlan.breakGasForDepth(stop.depthMeters);
        final breakFO2 = breakGas != null
            ? 1.0 - breakGas.fN2 - breakGas.fHe
            : stop.gasFO2;
        final breakPpO2 = stopPressure * breakFO2;
        cns += o2Calc.calculateCnsForSegment(breakPpO2, stop.airBreakSeconds);
        otu += o2Calc.calculateOtuForSegment(breakPpO2, stop.airBreakSeconds);
      }
    }

    final tankUsages = isCcr
        ? _computeCcrTankUsages(
            plan,
            totalRuntimeSeconds: runtime + schedule.ttsSeconds,
            environment: environment,
          )
        : _computeTankUsages(
            plan,
            legs,
            stops,
            lastDepth,
            environment,
            ascentPlan,
          );
    final issues = _computeIssues(
      plan,
      legs,
      segmentOutcomes,
      tankUsages,
      cns,
      otu,
      environment,
    );

    return PlanOutcome(
      // The last table line's end, so the headline runtime can never
      // disagree with the table printed under it.
      runtimeSeconds: scheduleRows.isEmpty
          ? runtime + schedule.ttsSeconds
          : scheduleRows.last.runtimeSeconds,
      maxDepth: maxDepth,
      ndlAtBottom: ndlAtBottom ?? 0,
      ttsAtBottom: ttsAtBottom ?? schedule.ttsSeconds,
      stops: stops,
      schedule: scheduleRows,
      segmentOutcomes: segmentOutcomes,
      tankUsages: tankUsages,
      cnsEnd: cns,
      otuTotal: otu,
      issues: issues,
      endTissue: state as BuhlmannState,
      tissueTimeline: timeline,
      ceilingTrace: ceilingTrace,
    );
  }

  /// Sampling interval for [PlanOutcome.ceilingTrace], in seconds. Fine
  /// enough that the chart draws a smooth curve, coarse enough that even
  /// a long technical plan stays a few hundred samples.
  static const ceilingSampleSeconds = 30;

  /// Replays the dive (user segments, then the computed travel legs and
  /// stops) on a scratch tissue state, sampling the ceiling every
  /// [ceilingSampleSeconds] so the chart can draw the real shape of a deco
  /// obligation: it climbs from 0 as tissues load, then eases back to 0 as
  /// each stop clears — never a flat plateau pinned to a stop's own depth.
  List<(int, double)> _ceilingTrace(
    DecoModel model,
    domain.DivePlan plan,
    List<ResolvedLeg> legs,
    List<PlanStop> stops,
    double lastDepth,
    AscentGasPlan ascentPlan,
  ) {
    final trace = <(int, double)>[];
    var traceState = model.initial();
    var runtime = 0;

    void sampleLeg(
      double startDepth,
      double endDepth,
      int durationSeconds,
      BreathingConfig Function(double depth) breathingAt,
    ) {
      var elapsed = 0;
      while (elapsed < durationSeconds) {
        final remaining = durationSeconds - elapsed;
        final step = remaining < ceilingSampleSeconds
            ? remaining
            : ceilingSampleSeconds;
        final legStart =
            startDepth + (endDepth - startDepth) * (elapsed / durationSeconds);
        final legEnd =
            startDepth +
            (endDepth - startDepth) * ((elapsed + step) / durationSeconds);
        traceState = model.applySegment(
          traceState,
          DecoSegment(
            startDepth: legStart,
            endDepth: legEnd,
            durationSeconds: step,
          ),
          breathingAt((legStart + legEnd) / 2.0),
        );
        runtime += step;
        elapsed += step;
        // A ceiling only constrains the diver once deco is actually owed.
        // Against the surface target the gradient factor is GF-high, so a
        // zero there means a direct ascent is allowed and there is nothing to
        // draw. Without this gate the curve plotted the GF-low deep-stop
        // target from the moment supersaturation crossed the GF-low line,
        // which put a 7.5 m ceiling on a dive whose schedule was a single
        // 3 m stop. getDecoStatus applies the same gate for dive details
        // (buhlmann_algorithm.dart, "only calculate ceiling/stops when
        // actually in deco").
        final owesDeco = model.surfaceCeilingMeters(traceState) > 0;
        trace.add((runtime, owesDeco ? model.ceilingMeters(traceState) : 0.0));
      }
    }

    BreathingConfig ascentBreathingAt(double depth) {
      final gas = ascentPlan.gasForDepth(depth);
      return OpenCircuit(fO2: 1.0 - gas.fN2 - gas.fHe, fHe: gas.fHe);
    }

    for (final leg in legs) {
      final segment = leg.segment;
      sampleLeg(
        leg.startDepth,
        leg.endDepth,
        leg.durationSeconds,
        (depth) => _breathingFor(plan, segment.gasMix, depth, segment: segment),
      );
    }

    final policy = _policyFor(plan);
    var depth = lastDepth;
    var phase = AscentPhase.toFirstStop;
    for (final stop in stops) {
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: stop.depthMeters,
        phase: phase,
      );
      sampleLeg(depth, stop.depthMeters, legSeconds, ascentBreathingAt);
      sampleLeg(
        stop.depthMeters,
        stop.depthMeters,
        stop.durationSeconds,
        (_) => ascentBreathingAt(stop.depthMeters),
      );
      depth = stop.depthMeters;
      phase = AscentPhase.betweenStops;
    }
    if (depth > 0) {
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: 0,
        phase: AscentPhase.surfacingAfter(phase),
      );
      sampleLeg(depth, 0, legSeconds, ascentBreathingAt);
    }

    return trace;
  }

  /// CCR consumption: metabolic O2 over the whole runtime charged to the
  /// oxygen-supply tank, descent loop-fill diluent charged to the diluent
  /// tank (else the first segment's tank). Bailout tanks consume nothing in
  /// the main plan — they are sized by the bailout solver.
  List<PlanTankUsage> _computeCcrTankUsages(
    domain.DivePlan plan, {
    required int totalRuntimeSeconds,
    required DiveEnvironment environment,
  }) {
    if (plan.tanks.isEmpty) return const [];
    final liters = <String, double>{for (final t in plan.tanks) t.id: 0.0};

    String? tankIdByRole(TankRole role) {
      for (final tank in plan.tanks) {
        if (tank.role == role) return tank.id;
      }
      return null;
    }

    final o2TankId = tankIdByRole(TankRole.oxygenSupply);
    if (o2TankId != null) {
      liters[o2TankId] =
          config.o2MetabolicRateLpm * (totalRuntimeSeconds / 60.0);
    }

    final diluentTankId =
        tankIdByRole(TankRole.diluent) ??
        (plan.segments.isNotEmpty &&
                liters.containsKey(plan.segments.first.tankId)
            ? plan.segments.first.tankId
            : null);
    if (diluentTankId != null) {
      liters[diluentTankId] =
          (liters[diluentTankId] ?? 0) +
          config.loopVolumeLiters *
              (environment.pressureAtDepth(plan.maxDepth) -
                  environment.surfacePressureBar);
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
                  model: config.gasModel,
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
                tank.role != TankRole.bailout &&
                remaining != null &&
                used > 0 &&
                remaining < plan.reservePressure,
          );
        }(),
    ];
  }

  /// SAC-based consumption: bottom SAC while the dive is still working
  /// (descending, or level at depth), deco SAC once it is heading up (ascent
  /// legs and stops), depth pressure via the plan's environment, remaining
  /// pressure compressibility-corrected.
  List<PlanTankUsage> _computeTankUsages(
    domain.DivePlan plan,
    List<ResolvedLeg> legs,
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

    for (final leg in legs) {
      final sac = switch (leg.phase) {
        SegmentPhase.descent || SegmentPhase.level => plan.sacBottom,
        SegmentPhase.ascent || SegmentPhase.stop => plan.sacDecoEffective,
      };
      charge(
        leg.tankId,
        sac *
            (leg.durationSeconds / 60.0) *
            environment.pressureAtDepth(leg.avgDepth),
      );
    }

    // Computed ascent: travel legs and stops on the deco SAC.
    final policy = _policyFor(plan);
    var depth = lastDepth;
    var phase = AscentPhase.toFirstStop;
    for (final stop in stops) {
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: stop.depthMeters,
        phase: phase,
      );
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
      phase = AscentPhase.betweenStops;
    }
    if (depth > 0) {
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: 0,
        phase: AscentPhase.surfacingAfter(phase),
      );
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
                  model: config.gasModel,
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
            turnPressureBar: _turnPressureFor(plan, tank),
            minGasBar: _minGasFor(plan, tank, environment),
          );
        }(),
    ];
  }

  /// Turn pressure per the plan's rule; bottom tanks with a start pressure
  /// only. `usable = start - reserve`; turn when the rule's fraction of the
  /// usable gas is consumed.
  double? _turnPressureFor(domain.DivePlan plan, DiveTank tank) {
    final rule = plan.turnPressureRule;
    final start = tank.startPressure;
    if (rule == null || start == null || tank.role != TankRole.backGas) {
      return null;
    }
    final usable = (start - plan.reservePressure).clamp(0.0, start);
    final fraction = switch (rule) {
      domain.TurnPressureRule.allUsable => 1.0,
      domain.TurnPressureRule.halves => 0.5,
      domain.TurnPressureRule.thirds => 1.0 / 3.0,
      domain.TurnPressureRule.custom => plan.turnPressureFraction ?? 1.0 / 3.0,
    };
    return start - usable * fraction;
  }

  /// Rock-bottom minimum gas: a stressed, buddy-shared emergency exit from
  /// the plan's max depth — one minute at depth plus a direct ascent at the
  /// plan rate — expressed as bar on this tank (bottom tanks, OC only).
  double? _minGasFor(
    domain.DivePlan plan,
    DiveTank tank,
    DiveEnvironment environment,
  ) {
    if (plan.mode == domain.PlanMode.ccr) return null;
    if (tank.role != TankRole.backGas || tank.startPressure == null) {
      return null;
    }
    final maxDepth = plan.maxDepth;
    if (maxDepth <= 0) return null;
    final sac = plan.sacStressedEffective * config.buddyFactor;
    final ascentMinutes =
        _policyFor(
          plan,
        ).ascentTravelSeconds(fromDepth: maxDepth, stopDepths: const []) /
        60.0;
    final liters =
        sac * environment.pressureAtDepth(maxDepth) +
        sac * ascentMinutes * environment.pressureAtDepth(maxDepth / 2.0);
    final volume = tank.volume ?? 11.0;
    return volume > 0 ? liters / volume : null;
  }

  List<PlanIssue> _computeIssues(
    domain.DivePlan plan,
    List<ResolvedLeg> legs,
    List<SegmentOutcome> segmentOutcomes,
    List<PlanTankUsage> tankUsages,
    double cns,
    double otu,
    DiveEnvironment environment,
  ) {
    final issues = <PlanIssue>[];

    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final segment = leg.segment;
      final outcome = segmentOutcomes[i];
      final deeperEnd = leg.deeperEnd;
      final shallowerEnd = leg.startDepth < leg.endDepth
          ? leg.startDepth
          : leg.endDepth;
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

      // Mode-aware: the CCR loop holds the setpoint, so hypoxia only fires
      // when the in-force setpoint itself is hypoxic.
      final inspiredO2 = _breathingFor(
        plan,
        segment.gasMix,
        shallowerEnd,
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
      final minGas = usage.minGasBar;
      if (minGas != null && remaining > 0 && remaining < minGas) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.minGasViolation,
            severity: PlanIssueSeverity.alert,
            message:
                'Tank ends below the rock-bottom minimum of '
                '${minGas.toStringAsFixed(0)} bar',
            segmentId: usage.tankId,
            value: remaining,
            threshold: minGas,
          ),
        );
      }
    }

    final inDeco = segmentOutcomes.any((s) => s.inDeco);
    final isCcr = plan.mode == domain.PlanMode.ccr;
    if (inDeco && !isCcr && !_hasDecoGas(plan)) {
      issues.add(
        const PlanIssue(
          type: PlanIssueType.ndlExceededNoDecoGas,
          severity: PlanIssueSeverity.alert,
          message:
              'Plan incurs decompression with no dedicated deco gas carried',
        ),
      );
    }
    if (inDeco && isCcr && !plan.tanks.any((t) => t.role == TankRole.bailout)) {
      issues.add(
        const PlanIssue(
          type: PlanIssueType.noBailoutCarried,
          severity: PlanIssueSeverity.alert,
          message: 'CCR decompression plan carries no bailout gas',
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

  /// The schedule policy a plan describes.
  ///
  /// Derived rather than passed around: the ascent legs of a computed
  /// schedule are measured in several places (profile sampling, gas charging,
  /// stop runtimes, rock-bottom), and every one of them has to agree with the
  /// legs the deco model actually loaded. One derivation from the plan keeps
  /// them from drifting apart.
  SchedulePolicy _policyFor(domain.DivePlan plan) => SchedulePolicy(
    lastStopDepth: plan.lastStopDepth,
    ascentRate: plan.ascentRate,
    intermediateAscentRate: plan.intermediateAscentRate,
    shallowAscentRate: plan.shallowAscentRate,
    finalAscentRate: plan.finalAscentRate,
    descentRate: plan.descentRate,
    gasSwitchStopSeconds: plan.gasSwitchStopSeconds,
    // A plan is read against a watch: stops end on whole minutes.
    snapStopsToWholeMinutes: true,
    airBreaks: plan.airBreaks,
  );

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
    final policy = _policyFor(plan);
    var arrival = segmentsRuntime;
    var depth = fromDepth;
    var phase = AscentPhase.toFirstStop;
    for (final stop in schedule.stops) {
      arrival += policy.ascentSeconds(
        fromDepth: depth,
        toDepth: stop.depthMeters,
        phase: phase,
      );
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
      phase = AscentPhase.betweenStops;
    }
    return stops;
  }

  /// Two gas fractions closer than this are the same gas for the purpose of
  /// marking a switch on the table.
  static const double _gasFractionEpsilon = 0.0005;

  /// The dive as table lines: the authored legs, then the computed ascent as
  /// alternating travel legs and stops, ending with the leg to the surface.
  ///
  /// Travel durations are read off the stops' arrival times rather than
  /// recomputed, so a line can never disagree with the stop it leads to. A
  /// travel leg breathes the gas eligible where it starts: the diver switches
  /// at the stop, and the table marks the switch on the stop's line, the way
  /// a slate does.
  List<PlanScheduleRow> _buildSchedule(
    List<ResolvedLeg> legs,
    List<PlanStop> stops,
    domain.DivePlan plan,
    AscentGasPlan ascentPlan,
    double lastDepth,
    int segmentsRuntime,
  ) {
    final rows = <PlanScheduleRow>[];
    double? previousFO2;
    double? previousFHe;

    void add({
      required PlanScheduleRowKind kind,
      required double depth,
      required int duration,
      required int runtime,
      required double fO2,
      required double fHe,
      required String? tankId,
      int airBreakSeconds = 0,
    }) {
      final lastFO2 = previousFO2;
      final lastFHe = previousFHe;
      final switched =
          lastFO2 == null ||
          lastFHe == null ||
          (fO2 - lastFO2).abs() > _gasFractionEpsilon ||
          (fHe - lastFHe).abs() > _gasFractionEpsilon;
      rows.add(
        PlanScheduleRow(
          kind: kind,
          depthMeters: depth,
          durationSeconds: duration,
          runtimeSeconds: runtime,
          gasFO2: fO2,
          gasFHe: fHe,
          tankId: tankId,
          gasSwitch: switched,
          airBreakSeconds: airBreakSeconds,
        ),
      );
      previousFO2 = fO2;
      previousFHe = fHe;
    }

    for (final leg in legs) {
      add(
        kind: switch (leg.phase) {
          SegmentPhase.descent => PlanScheduleRowKind.descent,
          SegmentPhase.level => PlanScheduleRowKind.level,
          SegmentPhase.ascent => PlanScheduleRowKind.ascent,
          SegmentPhase.stop => PlanScheduleRowKind.stop,
        },
        depth: leg.endDepth,
        duration: leg.durationSeconds,
        runtime: leg.runtimeSeconds,
        fO2: leg.gasMix.o2 / 100.0,
        fHe: leg.gasMix.he / 100.0,
        tankId: leg.tankId,
      );
    }

    void addTravel(double from, double to, int duration, int arrival) {
      final gas = ascentPlan.gasForDepth(from);
      final fO2 = 1.0 - gas.fN2 - gas.fHe;
      add(
        kind: PlanScheduleRowKind.ascent,
        depth: to,
        duration: duration,
        runtime: arrival,
        fO2: fO2,
        fHe: gas.fHe,
        tankId: _tankForGas(plan.tanks, fO2, gas.fHe),
      );
    }

    var depth = lastDepth;
    var end = segmentsRuntime;
    var phase = AscentPhase.toFirstStop;
    for (final stop in stops) {
      final travel = stop.arrivalRuntimeSeconds - end;
      if (travel > 0) {
        addTravel(depth, stop.depthMeters, travel, stop.arrivalRuntimeSeconds);
      }
      end = stop.arrivalRuntimeSeconds + stop.durationSeconds;
      add(
        kind: PlanScheduleRowKind.stop,
        depth: stop.depthMeters,
        duration: stop.durationSeconds,
        runtime: end,
        fO2: stop.gasFO2,
        fHe: stop.gasFHe,
        tankId: stop.tankId,
        airBreakSeconds: stop.airBreakSeconds,
      );
      depth = stop.depthMeters;
      phase = AscentPhase.betweenStops;
    }
    if (depth > 0) {
      final travel = _policyFor(plan).ascentSeconds(
        fromDepth: depth,
        toDepth: 0,
        phase: AscentPhase.surfacingAfter(phase),
      );
      addTravel(depth, 0, travel, end + travel);
    }
    return rows;
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
