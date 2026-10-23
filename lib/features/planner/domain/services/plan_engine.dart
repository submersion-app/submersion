import 'dart:math' as math;

import 'package:equatable/equatable.dart';
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
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/domain/services/segment_rate_split.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';
import 'package:submersion/features/planner/domain/services/tank_usage_order.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart'
    show kDefaultBatteryReserveFraction, kDefaultWalkSpeedMps;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// Thresholds and policy limits the engine evaluates plans against.
///
/// A value type: `planEngineConfigProvider` rebuilds it from Settings, and
/// equality is what keeps an unchanged config from rerunning every plan
/// engine consumer downstream (issue #2632).
class PlanEngineConfig extends Equatable {
  final double ppO2Working;
  final double ppO2Deco;

  /// Diluent MOD limit: the ppO2 a CCR plan's diluent may reach on a flush,
  /// from the diver's "ppO2 limits CCR" Settings. Unlike [ppO2Working] and
  /// [ppO2Deco] (physiological toxicity limits that apply to whatever is
  /// actually being breathed), this only governs the diluent gas itself.
  final double ccrDiluentModPpO2;

  /// The diver's CCR setpoints from the "ppO2 limits CCR" Settings: the loop
  /// ppO2 a CCR plan, or a CCR segment of any plan, breathes wherever the
  /// plan's own [domain.DivePlan.setpointLow] / [domain.DivePlan.setpointHigh]
  /// is unset (issue #2801). The defaults are the spec values, the last
  /// resort for a caller with no Settings to hand.
  final double ccrSetpointLow;
  final double ccrSetpointHigh;

  final int cnsWarningThreshold;
  final bool o2Narcotic;

  /// END above which a segment raises [PlanIssueType.endExceeded]. Sourced
  /// from the diver's Settings END limit (issue #1499).
  final double endLimitMeters;

  /// END target for best-mix gas suggestions. Resolved from the plan's own
  /// Gas options ([domain.DivePlan.bestMixEndMeters]); it never moves the
  /// [endLimitMeters] warning.
  final double bestMixEndMeters;

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

  // Planner Setup-accordion global defaults (issue #3552). Resolved through
  // descentRateFor/ascentRateFor/etc below, the same shape as
  // setpointLowFor/setpointHighFor - a plan's own value always wins, these
  // apply only where the plan's field is null.
  final double descentRate;
  final double ascentRate;
  final double intermediateAscentRate;
  final double shallowAscentRate;
  final double finalAscentRate;
  final double lastStopDepth;
  final int gasSwitchStopSeconds;
  final double sacBottom;
  final double sacDeco;

  /// Multiplier on [sacBottom] for the stressed/bailout SAC rate (issue
  /// #3552) - resolved per plan through [sacStressedFor], not a plain
  /// config field read directly, since the plan's own [sacStressed]
  /// override is an absolute rate, not a factor.
  final double sacStressedFactor;
  final int problemSolvingMinutes;
  final double deviationDepthDelta;
  final int deviationTimeMinutes;

  /// The diver's default turn-pressure rule/fraction and air-break policy
  /// (issue #3552, follow-up to v304-306). Nullable, unlike the fields
  /// above: "no rule"/"no policy" is itself a legitimate default, matching
  /// today's behaviour for a diver who has not opted in to one. Resolved
  /// per plan through [turnPressureRuleFor]/[turnPressureFractionFor]/
  /// [airBreaksFor], not a plain `?? this.x` merge, because a plan's own
  /// `TurnPressureRule.off` / [domain.DivePlan.airBreaksExplicitlyOff] must
  /// win even though it resolves to the same "no tracking" outcome as an
  /// unset config.
  final domain.TurnPressureRule? turnPressureRule;
  final double? turnPressureFraction;
  final AirBreakPolicy? airBreakPolicy;

  /// Gradient factors (0-100) and tank reserve pressure (bar) - previously
  /// snapshot-on-create, now live-resolve like every other Setup field
  /// (issue #3552, follow-up to v304-307). Merged through the plain
  /// `?? this.x` [copyWith]/[resolvedFor] pattern, same as sacBottom/sacDeco:
  /// a plan's own value always wins, there is no "explicit off" concept to
  /// a gradient factor or a reserve margin.
  final int gfLow;
  final int gfHigh;
  final double reservePressure;

  /// The diver's DPV mission defaults (issue #3552): the fraction of
  /// scooter burn time kept in reserve, and the shore-exit walking speed in
  /// m/s. A mission's own value wins; MissionEngine.compute resolves an
  /// unset one against these before any mission service reads it.
  final double batteryReserveFraction;
  final double walkSpeedMps;

  const PlanEngineConfig({
    this.ppO2Working = 1.4,
    this.ppO2Deco = 1.6,
    this.ccrDiluentModPpO2 = 1.6,
    this.ccrSetpointLow = domain.DivePlan.specSetpointLow,
    this.ccrSetpointHigh = domain.DivePlan.specSetpointHigh,
    this.cnsWarningThreshold = 80,
    this.o2Narcotic = true,
    this.endLimitMeters = 30.0,
    this.bestMixEndMeters = 30.0,
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
    this.descentRate = 18.0,
    this.ascentRate = 9.0,
    this.intermediateAscentRate = 6.0,
    this.shallowAscentRate = 3.0,
    this.finalAscentRate = 1.0,
    this.lastStopDepth = 3.0,
    this.gasSwitchStopSeconds = 0,
    this.sacBottom = 15.0,
    this.sacDeco = 15.0,
    this.sacStressedFactor = 2.5,
    this.problemSolvingMinutes = 2,
    this.deviationDepthDelta = 5.0,
    this.deviationTimeMinutes = 5,
    this.turnPressureRule,
    this.turnPressureFraction,
    this.airBreakPolicy,
    this.gfLow = 50,
    this.gfHigh = 85,
    this.reservePressure = 50.0,
    this.batteryReserveFraction = kDefaultBatteryReserveFraction,
    this.walkSpeedMps = kDefaultWalkSpeedMps,
  });

  @override
  List<Object?> get props => [
    ppO2Working,
    ppO2Deco,
    ccrDiluentModPpO2,
    ccrSetpointLow,
    ccrSetpointHigh,
    cnsWarningThreshold,
    o2Narcotic,
    endLimitMeters,
    bestMixEndMeters,
    otuLimit,
    o2MetabolicRateLpm,
    loopVolumeLiters,
    buddyFactor,
    scrInjectionRateLpm,
    pscrO2ConsumptionMlMin,
    pscrSacMlMin,
    pscrRatio,
    cnsMethod,
    gasModel,
    descentRate,
    ascentRate,
    intermediateAscentRate,
    shallowAscentRate,
    finalAscentRate,
    lastStopDepth,
    gasSwitchStopSeconds,
    sacBottom,
    sacDeco,
    sacStressedFactor,
    problemSolvingMinutes,
    deviationDepthDelta,
    deviationTimeMinutes,
    turnPressureRule,
    turnPressureFraction,
    airBreakPolicy,
    gfLow,
    gfHigh,
    reservePressure,
    batteryReserveFraction,
    walkSpeedMps,
  ];

  PlanEngineConfig copyWith({
    double? ppO2Working,
    double? ppO2Deco,
    double? ccrDiluentModPpO2,
    double? ccrSetpointLow,
    double? ccrSetpointHigh,
    int? cnsWarningThreshold,
    bool? o2Narcotic,
    double? endLimitMeters,
    double? bestMixEndMeters,
    double? otuLimit,
    double? o2MetabolicRateLpm,
    double? loopVolumeLiters,
    double? buddyFactor,
    double? scrInjectionRateLpm,
    double? pscrO2ConsumptionMlMin,
    double? pscrSacMlMin,
    double? pscrRatio,
    CnsCalculationMethod? cnsMethod,
    GasModel? gasModel,
    double? descentRate,
    double? ascentRate,
    double? intermediateAscentRate,
    double? shallowAscentRate,
    double? finalAscentRate,
    double? lastStopDepth,
    int? gasSwitchStopSeconds,
    double? sacBottom,
    double? sacDeco,
    double? sacStressedFactor,
    int? problemSolvingMinutes,
    double? deviationDepthDelta,
    int? deviationTimeMinutes,
    domain.TurnPressureRule? turnPressureRule,
    bool clearTurnPressureRule = false,
    double? turnPressureFraction,
    bool clearTurnPressureFraction = false,
    AirBreakPolicy? airBreakPolicy,
    bool clearAirBreakPolicy = false,
    int? gfLow,
    int? gfHigh,
    double? reservePressure,
    double? batteryReserveFraction,
    double? walkSpeedMps,
  }) {
    return PlanEngineConfig(
      ppO2Working: ppO2Working ?? this.ppO2Working,
      ppO2Deco: ppO2Deco ?? this.ppO2Deco,
      ccrDiluentModPpO2: ccrDiluentModPpO2 ?? this.ccrDiluentModPpO2,
      ccrSetpointLow: ccrSetpointLow ?? this.ccrSetpointLow,
      ccrSetpointHigh: ccrSetpointHigh ?? this.ccrSetpointHigh,
      cnsWarningThreshold: cnsWarningThreshold ?? this.cnsWarningThreshold,
      o2Narcotic: o2Narcotic ?? this.o2Narcotic,
      endLimitMeters: endLimitMeters ?? this.endLimitMeters,
      bestMixEndMeters: bestMixEndMeters ?? this.bestMixEndMeters,
      otuLimit: otuLimit ?? this.otuLimit,
      o2MetabolicRateLpm: o2MetabolicRateLpm ?? this.o2MetabolicRateLpm,
      loopVolumeLiters: loopVolumeLiters ?? this.loopVolumeLiters,
      buddyFactor: buddyFactor ?? this.buddyFactor,
      scrInjectionRateLpm: scrInjectionRateLpm ?? this.scrInjectionRateLpm,
      pscrO2ConsumptionMlMin:
          pscrO2ConsumptionMlMin ?? this.pscrO2ConsumptionMlMin,
      pscrSacMlMin: pscrSacMlMin ?? this.pscrSacMlMin,
      pscrRatio: pscrRatio ?? this.pscrRatio,
      cnsMethod: cnsMethod ?? this.cnsMethod,
      gasModel: gasModel ?? this.gasModel,
      descentRate: descentRate ?? this.descentRate,
      ascentRate: ascentRate ?? this.ascentRate,
      intermediateAscentRate:
          intermediateAscentRate ?? this.intermediateAscentRate,
      shallowAscentRate: shallowAscentRate ?? this.shallowAscentRate,
      finalAscentRate: finalAscentRate ?? this.finalAscentRate,
      lastStopDepth: lastStopDepth ?? this.lastStopDepth,
      gasSwitchStopSeconds: gasSwitchStopSeconds ?? this.gasSwitchStopSeconds,
      sacBottom: sacBottom ?? this.sacBottom,
      sacDeco: sacDeco ?? this.sacDeco,
      sacStressedFactor: sacStressedFactor ?? this.sacStressedFactor,
      problemSolvingMinutes:
          problemSolvingMinutes ?? this.problemSolvingMinutes,
      deviationDepthDelta: deviationDepthDelta ?? this.deviationDepthDelta,
      deviationTimeMinutes: deviationTimeMinutes ?? this.deviationTimeMinutes,
      turnPressureRule: clearTurnPressureRule
          ? null
          : (turnPressureRule ?? this.turnPressureRule),
      turnPressureFraction: clearTurnPressureFraction
          ? null
          : (turnPressureFraction ?? this.turnPressureFraction),
      airBreakPolicy: clearAirBreakPolicy
          ? null
          : (airBreakPolicy ?? this.airBreakPolicy),
      gfLow: gfLow ?? this.gfLow,
      gfHigh: gfHigh ?? this.gfHigh,
      reservePressure: reservePressure ?? this.reservePressure,
      batteryReserveFraction:
          batteryReserveFraction ?? this.batteryReserveFraction,
      walkSpeedMps: walkSpeedMps ?? this.walkSpeedMps,
    );
  }

  /// Merges this app-wide config with [plan]'s per-plan gas-option
  /// overrides. A set plan value always wins; an unset (null) one falls back
  /// to this config unchanged. Every field, [endLimitMeters] (the diver's
  /// Settings END limit) included, carries over through [copyWith], so a
  /// field added later cannot silently fall back to its default here (issue
  /// #2640). `sacFactor`/`bestMixEndMeters` (-> [buddyFactor]/
  /// [bestMixEndMeters]) used to be plain defaulted `DivePlan` fields with
  /// no global source, always replacing the config's own value; since issue
  /// #3552 gave them one, a `null` plan value (now possible) resolves to
  /// the diver's Settings the same way every other field here already does.
  PlanEngineConfig resolvedFor(domain.DivePlan plan) {
    return copyWith(
      ppO2Working: plan.ppO2Bottom,
      ppO2Deco: plan.ppO2Deco,
      o2Narcotic: plan.o2Narcotic,
      bestMixEndMeters: plan.bestMixEndMeters,
      buddyFactor: plan.sacFactor,
      descentRate: plan.descentRate,
      ascentRate: plan.ascentRate,
      intermediateAscentRate: plan.intermediateAscentRate,
      shallowAscentRate: plan.shallowAscentRate,
      finalAscentRate: plan.finalAscentRate,
      lastStopDepth: plan.lastStopDepth,
      gasSwitchStopSeconds: plan.gasSwitchStopSeconds,
      sacBottom: plan.sacBottom,
      sacDeco: plan.sacDeco,
      problemSolvingMinutes: plan.problemSolvingMinutes,
      deviationDepthDelta: plan.deviationDepthDelta,
      deviationTimeMinutes: plan.deviationTimeMinutes,
      gfLow: plan.gfLow,
      gfHigh: plan.gfHigh,
      reservePressure: plan.reservePressure,
    );
  }

  /// [plan]'s low (shallow) setpoint: its own value when set, else the
  /// diver's [ccrSetpointLow] (issue #2801).
  double setpointLowFor(domain.DivePlan plan) =>
      plan.setpointLow ?? ccrSetpointLow;

  /// [plan]'s stressed (bailout/rock-bottom) SAC: its own [sacStressed]
  /// override when set, else [sacBottom] (already resolved against this
  /// plan - call this on a [resolvedFor] config) times the diver's
  /// [sacStressedFactor] (issue #3552; was a hardcoded 2.5x of the plan's
  /// raw `sacBottom`, see [domain.DivePlan.sacStressedEffective]).
  double sacStressedFor(domain.DivePlan plan) =>
      plan.sacStressed ?? sacBottom * sacStressedFactor;

  /// [plan]'s high (deep) setpoint: its own value when set, else the
  /// diver's [ccrSetpointHigh] (issue #2801).
  double setpointHighFor(domain.DivePlan plan) =>
      plan.setpointHigh ?? ccrSetpointHigh;

  /// [plan]'s turn-pressure rule: its own value when set, else the diver's
  /// Settings default (issue #3552), which may itself be null (no rule).
  /// Never merged through [copyWith]'s plain `?? this.x`: the plan's own
  /// [domain.TurnPressureRule.off] must win even when the config's default
  /// is already null, and the two look identical to `??`.
  domain.TurnPressureRule? turnPressureRuleFor(domain.DivePlan plan) =>
      plan.turnPressureRule ?? turnPressureRule;

  /// [plan]'s turn-pressure fraction, only meaningful when
  /// [turnPressureRuleFor] resolves to [domain.TurnPressureRule.custom].
  /// Taken from the same source as the rule: a plan that sets its own rule
  /// uses its own fraction (null = the 1/3 the Setup field shows), and a
  /// plan following the Settings rule uses the Settings fraction, never a
  /// leftover fraction from an earlier plan-level Custom.
  double? turnPressureFractionFor(domain.DivePlan plan) =>
      plan.turnPressureRule != null
      ? plan.turnPressureFraction
      : turnPressureFraction;

  /// [plan]'s air-break policy: `null` when [domain.DivePlan.airBreaksExplicitlyOff]
  /// is set (explicit "off", wins regardless of the diver's default), else
  /// the plan's own [domain.DivePlan.airBreaks] when set, else the diver's
  /// Settings default (issue #3552), which may itself be null (no breaks).
  AirBreakPolicy? airBreaksFor(domain.DivePlan plan) {
    if (plan.airBreaksExplicitlyOff) return null;
    return plan.airBreaks ?? airBreakPolicy;
  }
}

/// Setpoint in force at [depth]: the segment's per-segment override if set,
/// else the plan's depth-based (low/high) setpoint, with an unset plan
/// setpoint falling back to the diver's Settings in [config].
double setpointAt(
  domain.DivePlan plan,
  double depth, {
  required PlanEngineConfig config,
  PlanSegment? segment,
}) {
  final override = segment?.setpointBar;
  if (override != null) return override;
  return depth > plan.effectiveSetpointSwitchDepth
      ? config.setpointHighFor(plan)
      : config.setpointLowFor(plan);
}

/// Mode-aware breathing for [gas] at [depth]: the loop at the in-force
/// setpoint for CCR (gas = diluent), CMF loop for SCR, open circuit
/// otherwise. A per-segment [segment] override wins over the plan mode --
/// including a mid-plan [PlanMode.oc] bailout leg, an existing segment
/// contract (any other caller replaying a plan's tissue loading, such as
/// BailoutSolver's own bottom-phase sampling, must honour it the same way
/// PlanEngine.compute does, or the replay loads a loop's worth of gas for
/// a leg the diver actually breathed open circuit -- caught by a Copilot
/// review).
BreathingConfig breathingFor(
  domain.DivePlan plan,
  GasMix gas,
  double depth, {
  required PlanEngineConfig config,
  PlanSegment? segment,
}) {
  final mode = modeFor(plan, segment);
  if (mode == domain.PlanMode.ccr) {
    return ClosedCircuit(
      setpoint: setpointAt(plan, depth, config: config, segment: segment),
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

  /// The water and surface conditions [plan] is computed in. Shared with
  /// every caller that must charge gas at the same ambient pressure the
  /// deco schedule used (the DPV mission's per-diver gas, issue #2086).
  ///
  /// Altitude <= 0 is treated as unset (legacy 1.0 bar surface), matching
  /// the rest of the planner: a literal 0 must not switch to barometric
  /// sea-level pressure and subtly change the deco math.
  static DiveEnvironment environmentFor(domain.DivePlan plan) {
    return DiveEnvironment.forConditions(
      altitudeMeters: (plan.altitude ?? 0) > 0 ? plan.altitude : null,
      waterType: plan.waterType ?? WaterType.salt,
      salinityPpt: plan.salinityPpt,
    );
  }

  /// The breathing mode in force for [segment] (its per-segment override, or
  /// the plan's mode). Models mid-plan bailout.
  domain.PlanMode _modeFor(domain.DivePlan plan, PlanSegment? segment) =>
      modeFor(plan, segment);

  /// Mode-aware breathing for [gas] at [depth]: the loop at the in-force
  /// setpoint for CCR (gas = diluent), CMF loop for SCR, open circuit
  /// otherwise. A per-segment [segment] override wins over the plan mode.
  BreathingConfig _breathingFor(
    domain.DivePlan plan,
    GasMix gas,
    double depth, {
    PlanSegment? segment,
  }) => breathingFor(plan, gas, depth, config: config, segment: segment);

  /// Computes the schedule for [inputPlan], first resolving this engine's
  /// [config] against the plan's own gas-option overrides (ppO2Bottom,
  /// ppO2Deco, o2Narcotic, sacFactor, bestMixEndMeters) so every call site
  /// that constructs a `PlanEngine` picks those overrides up automatically.
  PlanOutcome compute(domain.DivePlan inputPlan, {TissueState? startState}) {
    final resolvedConfig = config.resolvedFor(inputPlan);
    return PlanEngine(
      config: resolvedConfig,
    )._computeInternal(inputPlan, startState: startState);
  }

  PlanOutcome _computeInternal(
    domain.DivePlan inputPlan, {
    TissueState? startState,
  }) {
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
    final environment = environmentFor(plan);
    final policy = _policyFor(plan);
    final model = BuhlmannGf(
      gfLow: config.gfLow / 100.0,
      gfHigh: config.gfHigh / 100.0,
      environment: environment,
      policy: policy,
    );
    final o2Calc = O2ToxicityCalculator(
      ppO2WarningThreshold: config.ppO2Working,
      ppO2CriticalThreshold: config.ppO2Deco,
      cnsWarningThreshold: config.cnsWarningThreshold,
      cnsMethod: config.cnsMethod,
    );

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
    // Waypoints carry only a target depth, so the profile they describe -
    // start depths, phases, rates - is resolved once here, and everything
    // downstream reads legs rather than segments.
    final legs = const SegmentChain().resolve(segments);
    // The final authored leg can itself be a mid-plan OC/bailout override
    // (modeFor), in which case its gasMix is the bailout mix, not a
    // diluent - fall back to the last leg still breathed on the loop.
    PlanSegment? lastLoopSegment;
    for (final segment in segments.reversed) {
      if (_modeFor(plan, segment) != domain.PlanMode.oc) {
        lastLoopSegment = segment;
        break;
      }
    }
    final ascentPlan = isCcr
        ? CcrLoopAscentGas(
            environment: environment,
            setpointLow: config.setpointLowFor(plan),
            setpointHigh: config.setpointHighFor(plan),
            switchDepth: plan.effectiveSetpointSwitchDepth,
            diluentFO2: lastLoopSegment == null
                ? 0.21
                : lastLoopSegment.gasMix.o2 / 100.0,
            diluentFHe: lastLoopSegment == null
                ? 0.0
                : lastLoopSegment.gasMix.he / 100.0,
          )
        : _ascentPlanFor(plan.tanks);

    var state = startState ?? model.initial();
    var runtime = 0;
    var cns = 0.0;
    var otu = 0.0;
    var maxPpO2 = 0.0;
    int? ndlAtBottom;
    var authoredDecoSeconds = 0;
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
      }
      if (leg.phase == SegmentPhase.stop) {
        authoredDecoSeconds += leg.durationSeconds;
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
      environment,
    );

    // A separate, finely-sampled replay purely for the chart's ceiling curve.
    // It never feeds back into `state`/cns/otu/stops, so it cannot perturb
    // the numbers the rest of this method already computed and returned.
    // The same replay walks the authored legs at that resolution, so it is
    // also where a leg that takes the diver above the ceiling shows up.
    final (:trace, :breaches) = _ceilingTrace(
      model,
      plan,
      legs,
      stops,
      lastDepth,
      ascentPlan,
      startState ?? model.initial(),
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
            legs: legs,
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
      breaches,
    );

    // The last table line's end, so the headline runtime can never
    // disagree with the table printed under it.
    final totalRuntime = scheduleRows.isEmpty
        ? runtime + schedule.ttsSeconds
        : scheduleRows.last.runtimeSeconds;
    // TTS is one thing only: the time from the end of the last authored
    // segment to the surface, exactly as the schedule below prints it -
    // travel to the first stop at the plan's ascent rate, every stop, the
    // travel between them and the final ascent. The authored segments are
    // what the diver has decided to do; TTS is what the model still owes
    // once they are done. It is never re-derived from the deepest leg or
    // from any guess about where "the bottom" ended, so it cannot disagree
    // with the table.
    final tts = totalRuntime - runtime;

    return PlanOutcome(
      runtimeSeconds: totalRuntime,
      maxDepth: maxDepth,
      ndlAtBottom: ndlAtBottom ?? 0,
      ttsAtBottom: tts,
      authoredDecoSeconds: authoredDecoSeconds,
      stops: stops,
      schedule: scheduleRows,
      segmentOutcomes: segmentOutcomes,
      // Listed in the order the table above breathes them, not the order
      // the diver happened to add the cylinders.
      tankUsages: orderUsagesByFirstUse(tankUsages, scheduleRows),
      cnsEnd: cns,
      otuTotal: otu,
      issues: issues,
      endTissue: state as BuhlmannState,
      tissueTimeline: timeline,
      ceilingTrace: trace,
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
  ///
  /// The replay starts from [initialState], the tissues the plan itself
  /// starts from, so a repetitive dive's residual loading shows on the chart
  /// just as it does in the stops.
  ///
  /// [breaches] holds, per authored segment, the sample with the deepest
  /// ceiling the diver was shallower than (#3354): the depth the plan needed
  /// them to stay at. Only authored legs that hold depth or go shallower are
  /// checked. The computed stops respect the ceiling by construction, and a
  /// descent only takes the diver deeper: when one starts above the ceiling
  /// (a repetitive dive begun while still owing deco), no edit to it could
  /// clear the breach.
  ({List<(int, double)> trace, Iterable<_CeilingBreach> breaches})
  _ceilingTrace(
    DecoModel model,
    domain.DivePlan plan,
    List<ResolvedLeg> legs,
    List<PlanStop> stops,
    double lastDepth,
    AscentGasPlan ascentPlan,
    TissueState initialState,
  ) {
    final trace = <(int, double)>[];
    // Keyed by the authored segment, so the legs one segment expands into
    // (a rate-split travel and hold) report as that one segment.
    final breaches = <String, _CeilingBreach>{};
    var traceState = initialState;
    var runtime = 0;

    void sampleLeg(
      double startDepth,
      double endDepth,
      int durationSeconds,
      BreathingConfig Function(double depth) breathingAt, {
      String? authoredSegmentId,
    }) {
      _CeilingBreach? worst;
      // An authored leg is walked at the scheduler's finer slice so a
      // breach inside one chart sample is still seen; the chart keeps its
      // own interval, which is a whole number of these slices.
      final stepSeconds = authoredSegmentId != null
          ? _ceilingBreachSampleSeconds
          : ceilingSampleSeconds;
      var elapsed = 0;
      while (elapsed < durationSeconds) {
        final remaining = durationSeconds - elapsed;
        final step = remaining < stepSeconds ? remaining : stepSeconds;
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
        final ceiling = owesDeco ? model.ceilingMeters(traceState) : 0.0;
        if (elapsed % ceilingSampleSeconds == 0 || elapsed == durationSeconds) {
          trace.add((runtime, ceiling));
        }
        // The scheduler's own test for leaving a stop: the ceiling may not be
        // above the diver at any point of the leg, arrival included
        // (BuhlmannAlgorithm._trialAscentClears). The tolerance only absorbs
        // float noise in the interpolated depth.
        if (authoredSegmentId != null &&
            ceiling > legEnd + _ceilingBreachToleranceMeters &&
            (worst == null || ceiling > worst.ceilingMeters)) {
          worst = (
            segmentId: authoredSegmentId,
            runtimeSeconds: runtime,
            depthMeters: legEnd,
            ceilingMeters: ceiling,
          );
        }
      }
      if (worst != null) {
        final previous = breaches[worst.segmentId];
        if (previous == null || worst.ceilingMeters > previous.ceilingMeters) {
          breaches[worst.segmentId] = worst;
        }
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
        authoredSegmentId: leg.endDepth > leg.startDepth
            ? null
            : _authoredSegmentId(segment.id),
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

    return (trace: trace, breaches: breaches.values);
  }

  /// The diver-authored segment a resolved leg came from, or null for a leg
  /// the engine inserted on its own (a diluent switch stop), which is never
  /// the leg to blame or edit.
  static String? _authoredSegmentId(String legId) {
    if (legId.endsWith(diluentSwitchStopIdSuffix)) return null;
    if (legId.endsWith(rateSplitHoldIdSuffix)) {
      return legId.substring(0, legId.length - rateSplitHoldIdSuffix.length);
    }
    return legId;
  }

  /// Slack allowed between the ceiling and the diver before an authored leg
  /// counts as a breach, in meters. Small enough to never hide a skipped
  /// stop; large enough to ignore rounding in the interpolated depth.
  static const _ceilingBreachToleranceMeters = 0.01;

  /// Slice an authored leg is checked at for a ceiling breach, in seconds:
  /// the scheduler's own trial-ascent slice
  /// (BuhlmannAlgorithm._trialAscentSliceSeconds), so the plan judges the
  /// diver's legs exactly as finely as it judges its own. Must divide
  /// [ceilingSampleSeconds] so the chart samples land where they always did.
  static const _ceilingBreachSampleSeconds = 10;

  /// CCR consumption: metabolic O2 over the whole runtime charged to the
  /// oxygen-supply tank, descent loop-fill diluent charged leg by leg to
  /// whichever diluent that leg actually breathes. Bailout tanks consume
  /// nothing in the main plan — they are sized by the bailout solver.
  List<PlanTankUsage> _computeCcrTankUsages(
    domain.DivePlan plan, {
    required List<ResolvedLeg> legs,
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

    // Loop-fill gas: as the diver goes deeper, the counterlung needs more
    // actual gas volume to hold the same breathing volume at the higher
    // ambient pressure. A dive can carry more than one diluent and switch
    // between them per segment (#3220, #3263); charging the whole dive's
    // fill to a single tank picked by role left every diluent past the
    // first reading a flat 0 L no matter how long it was actually
    // breathed (confirmed: a two-diluent profile showed 0 L on the first
    // diluent even after ten real minutes on it). Each leg is now charged
    // to its own tank instead, and only for the portion of the leg that
    // actually goes deeper -- a flat leg (including a rate-split leg's
    // hold half, #3264) or an ascent needs no extra fill -- and only while
    // the loop itself is running (a per-segment OC override breathes no
    // loop gas at all).
    for (final leg in legs) {
      if (modeFor(plan, leg.segment) == domain.PlanMode.ccr &&
          leg.endDepth > leg.startDepth &&
          liters.containsKey(leg.tankId)) {
        liters[leg.tankId] =
            (liters[leg.tankId] ?? 0) +
            config.loopVolumeLiters *
                (environment.pressureAtDepth(leg.endDepth) -
                    environment.pressureAtDepth(leg.startDepth));
      }
    }

    return [
      for (final tank in plan.tanks)
        () {
          final used = liters[tank.id] ?? 0.0;
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
            reserveViolation:
                tank.role != TankRole.bailout &&
                remaining != null &&
                used > 0 &&
                remaining < config.reservePressure,
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

    // Reads sacBottom/sacDeco/problemSolvingMinutes from [config] (issue
    // #3552), not [plan] directly: by this point [config] is already
    // resolvedFor this plan, so an unset field already carries the diver's
    // Settings default. sacFactor has no absolute global value of its own -
    // it always resolves through config.buddyFactor (see resolvedFor).
    for (final leg in legs) {
      final sac = switch (leg.phase) {
        SegmentPhase.descent || SegmentPhase.level => config.sacBottom,
        SegmentPhase.ascent || SegmentPhase.stop => config.sacDeco,
      };
      charge(
        leg.tankId,
        sac *
            (leg.durationSeconds / 60.0) *
            environment.pressureAtDepth(leg.avgDepth),
      );
    }

    // Problem-solving time: extra N minutes at max depth on the working
    // gas, at bottom SAC x SAC factor, so the used/end figures include the
    // same bottom-hold term the gas-options row describes.
    if (config.problemSolvingMinutes > 0 && plan.maxDepth > 0) {
      String? bottomTankId;
      for (final leg in legs) {
        if (leg.endDepth >= plan.maxDepth - 0.1 ||
            leg.startDepth >= plan.maxDepth - 0.1) {
          bottomTankId = leg.tankId;
        }
      }
      charge(
        bottomTankId,
        config.sacBottom *
            config.buddyFactor *
            config.problemSolvingMinutes *
            environment.pressureAtDepth(plan.maxDepth),
      );
    }

    // Computed ascent: travel legs and stops on the deco SAC.
    final policy = _policyFor(plan);
    var depth = lastDepth;
    var phase = AscentPhase.toFirstStop;
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: stop.depthMeters,
        phase: phase,
      );
      if (i == 0) {
        // Mirrors _buildSchedule's own split (#3225): charge each sub-leg
        // to the gas actually eligible across it, the same gases that leg's
        // table rows now show, rather than lumping the whole leg onto the
        // first stop's shallow gas the way every later inter-stop leg
        // safely can (a real switch there always lands exactly at the
        // stop it leads into).
        final boundaries = travelLegBoundaries(
          ascentPlan,
          fromDepth: depth,
          toDepth: stop.depthMeters,
        );
        final totalSpan = depth - stop.depthMeters;
        var legDepth = depth;
        var remaining = legSeconds;
        for (var j = 1; j < boundaries.length; j++) {
          final legTo = boundaries[j];
          final isLast = j == boundaries.length - 1;
          final subSeconds = isLast
              ? remaining
              : (legSeconds * (legDepth - legTo) / totalSpan).round();
          remaining -= subSeconds;
          final gas = ascentPlan.gasForDepth(legDepth);
          charge(
            _tankForGas(plan.tanks, 1.0 - gas.fN2 - gas.fHe, gas.fHe),
            config.sacDeco *
                (subSeconds / 60.0) *
                environment.pressureAtDepth((legDepth + legTo) / 2.0),
          );
          legDepth = legTo;
        }
      } else {
        final legAvg = (depth + stop.depthMeters) / 2.0;
        charge(
          stop.tankId,
          config.sacDeco *
              (legSeconds / 60.0) *
              environment.pressureAtDepth(legAvg),
        );
      }
      final stopPressure = environment.pressureAtDepth(stop.depthMeters);
      final primarySeconds = stop.durationSeconds - stop.airBreakSeconds;
      charge(
        stop.tankId,
        config.sacDeco * (primarySeconds / 60.0) * stopPressure,
      );
      if (stop.airBreakSeconds > 0) {
        final breakGas = ascentPlan.breakGasForDepth(stop.depthMeters);
        final breakTankId = breakGas != null
            ? _tankForGas(
                plan.tanks,
                1.0 - breakGas.fN2 - breakGas.fHe,
                breakGas.fHe,
              )
            : stop.tankId;
        charge(
          breakTankId,
          config.sacDeco * (stop.airBreakSeconds / 60.0) * stopPressure,
        );
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
      final gas = ascentPlan.gasForDepth(depth);
      charge(
        _tankForGas(plan.tanks, 1.0 - gas.fN2 - gas.fHe, gas.fHe),
        config.sacDeco *
            (legSeconds / 60.0) *
            environment.pressureAtDepth(depth / 2.0),
      );
    }

    return [
      for (final tank in plan.tanks)
        () {
          final used = liters[tank.id] ?? 0.0;
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
            reserveViolation:
                remaining != null && remaining < config.reservePressure,
            turnPressureBar: _turnPressureFor(plan, tank),
            minGasBar: _minGasFor(plan, tank, environment),
          );
        }(),
    ];
  }

  /// Turn pressure per the plan's rule; bottom tanks with a start pressure
  /// only. `usable = start - reserve`; turn when the rule's fraction of the
  /// usable gas is consumed.
  ///
  /// Reads the rule/fraction from [config] (issue #3552), not [plan]
  /// directly: by this point [config] is already resolvedFor this plan,
  /// so an unset plan field already carries the diver's Settings default.
  double? _turnPressureFor(domain.DivePlan plan, DiveTank tank) {
    final rule = config.turnPressureRuleFor(plan);
    final start = tank.startPressure;
    if (rule == null ||
        rule == domain.TurnPressureRule.off ||
        start == null ||
        tank.role != TankRole.backGas) {
      return null;
    }
    final usable = (start - config.reservePressure).clamp(0.0, start);
    final fraction = switch (rule) {
      domain.TurnPressureRule.off => 0.0, // unreachable, handled above
      domain.TurnPressureRule.allUsable => 1.0,
      domain.TurnPressureRule.halves => 0.5,
      domain.TurnPressureRule.thirds => 1.0 / 3.0,
      domain.TurnPressureRule.custom =>
        config.turnPressureFractionFor(plan) ?? 1.0 / 3.0,
    };
    return start - usable * fraction;
  }

  /// Rock-bottom minimum gas: a stressed, buddy-shared emergency exit from
  /// the plan's max depth — [domain.DivePlan.problemSolvingMinutes] at depth
  /// plus a direct ascent at the plan rate — expressed as bar on this tank
  /// (bottom tanks, OC only).
  ///
  /// The stressed rate is [domain.DivePlan.sacStressedEffective] (an
  /// explicit override, or bottom SAC x2.5 by default); [config]'s
  /// `buddyFactor` is resolved from the plan's own `sacFactor` by [compute]
  /// before this runs, so it always reflects that plan's Gas options.
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
    // config.sacStressedFor/sacBottom/problemSolvingMinutes (issue #3552):
    // config is already resolvedFor this plan at this point.
    final sac = config.sacStressedFor(plan) * config.buddyFactor;
    final ascentMinutes =
        _policyFor(
          plan,
        ).ascentTravelSeconds(fromDepth: maxDepth, stopDepths: const []) /
        60.0;
    final liters =
        sac *
            config.problemSolvingMinutes *
            environment.pressureAtDepth(maxDepth) +
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
    Iterable<_CeilingBreach> ceilingBreaches,
  ) {
    final issues = <PlanIssue>[];

    for (final breach in ceilingBreaches) {
      issues.add(
        PlanIssue(
          type: PlanIssueType.ceilingViolated,
          severity: PlanIssueSeverity.critical,
          message:
              'Diver at ${breach.depthMeters.toStringAsFixed(1)} m is above '
              'the ${breach.ceilingMeters.toStringAsFixed(1)} m deco ceiling',
          atRuntime: breach.runtimeSeconds,
          atDepth: breach.depthMeters,
          segmentId: breach.segmentId,
          value: breach.ceilingMeters,
          threshold: breach.depthMeters,
        ),
      );
    }

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

      // The diluent's own open-circuit ppO2, independent of the setpoint:
      // how deep it could still be used for a loop flush or a manual
      // diluent breath. Checked against the diver's Dil MOD, not the OC
      // toxicity limits: those govern what the loop delivers, not the
      // diluent itself.
      if (_modeFor(plan, segment) == domain.PlanMode.ccr) {
        final diluentPpO2 = environment.pressureAtDepth(deeperEnd) * fO2;
        if (diluentPpO2 > config.ccrDiluentModPpO2) {
          issues.add(
            PlanIssue(
              type: PlanIssueType.diluentModExceeded,
              severity: PlanIssueSeverity.warning,
              message:
                  'Diluent ppO2 ${diluentPpO2.toStringAsFixed(2)} bar '
                  'exceeds the Dil MOD limit at '
                  '${deeperEnd.toStringAsFixed(0)} m',
              atDepth: deeperEnd,
              segmentId: segment.id,
              value: diluentPpO2,
              threshold: config.ccrDiluentModPpO2,
            ),
          );
        }
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
                '${config.reservePressure.toStringAsFixed(0)} bar reserve',
            segmentId: usage.tankId,
            value: remaining,
            threshold: config.reservePressure,
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
  ///
  /// Reads the Deco/Rates/air-breaks fields from [config] (issue #3552),
  /// not [plan] directly, because by the time this runs [config] is
  /// already [PlanEngineConfig.resolvedFor] this plan - its own value
  /// where set, the diver's Settings otherwise. `plan` is still needed for
  /// [domain.DivePlan.stopMinimums], which has no global default.
  SchedulePolicy _policyFor(domain.DivePlan plan) => SchedulePolicy(
    lastStopDepth: config.lastStopDepth,
    ascentRate: config.ascentRate,
    intermediateAscentRate: config.intermediateAscentRate,
    shallowAscentRate: config.shallowAscentRate,
    finalAscentRate: config.finalAscentRate,
    descentRate: config.descentRate,
    gasSwitchStopSeconds: config.gasSwitchStopSeconds,
    // A plan is read against a watch: stops end on whole minutes.
    snapStopsToWholeMinutes: true,
    airBreaks: config.airBreaksFor(plan),
    minStopSecondsByDepth: plan.stopMinimums,
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
          tankId: _tankForGas(
            plan.tanks,
            fO2,
            gas.fHe,
            isCcr: plan.mode == domain.PlanMode.ccr,
          ),
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
    DiveEnvironment environment,
  ) {
    final rows = <PlanScheduleRow>[];
    final isCcr = plan.mode == domain.PlanMode.ccr;
    double? previousFO2;
    double? previousFHe;

    // The loop's real inspired ppO2 at a depth -- always the setpoint
    // (clamped to alveolar pressure where the diluent can no longer dilute
    // enough), never ambient x a stored gas fraction. gasFO2/gasFHe on a
    // computed-ascent row are normalized against alveolar pressure
    // (CcrLoopAscentGas: fN2 = pN2 / pAlv, and so on), not against raw
    // ambient pressure -- multiplying that fraction back by ambient
    // overstates ppO2 by a margin that *grows* as depth shrinks (ambient
    // and pAlv differ by a fixed ~0.063 bar water-vapour term, which is a
    // bigger fraction of a small ambient than a large one). A diver saw
    // this directly: PO2 drifting from 1.30 at depth up to 1.35 near the
    // surface on a dive with one constant 1.3 bar high setpoint. Asking the
    // loop model directly for the inspired pO2 is exact at every depth.
    double? ccrPpO2At(double atDepth) {
      if (!isCcr || ascentPlan is! CcrLoopAscentGas) return null;
      final loop = ascentPlan;
      return ClosedCircuit(
        setpoint: loop.setpointAt(atDepth),
        diluentFO2: loop.diluentFO2,
        diluentFHe: loop.diluentFHe,
      ).inspiredAt(environment.pressureAtDepth(atDepth)).pO2;
    }

    // The loop's TRUE gas identity, for display: always the diluent.
    // CcrLoopAscentGas.gasForDepth() instead returns a continuously
    // drifting pAlv-normalized fraction for the deco engine's own
    // bookkeeping -- using that for the Gas column fabricated an invented
    // mix on every line even on a single-diluent dive (a diver saw this
    // directly: Tx 10/70 shown as Tx 12/68, Tx 24/59, ... Tx 87/10). The
    // diluent valve feeds the same gas regardless of depth -- even once
    // ambient pressure can no longer support the setpoint and PO2 falls
    // short of it (ccrPpO2At reports that honestly), the loop is not
    // somehow switched onto a different cylinder; a diver confirmed this
    // directly after an earlier version of this function showed "O2" at
    // the shallowest stops, which does not happen.
    ({double fO2, double fHe})? ccrDisplayGasAt(double atDepth) {
      if (!isCcr || ascentPlan is! CcrLoopAscentGas) return null;
      final loop = ascentPlan;
      return (fO2: loop.diluentFO2, fHe: loop.diluentFHe);
    }

    void add({
      required PlanScheduleRowKind kind,
      required double depth,
      required int duration,
      required int runtime,
      required double fO2,
      required double fHe,
      required String? tankId,
      int airBreakSeconds = 0,
      // Set whenever the row's gas was resolved through ccrPpO2At/
      // ccrDisplayGasAt rather than ambient x fO2: the real inspired ppO2
      // (the CCR setpoint, clamped once the diluent can no longer dilute
      // enough), which ambient x fO2 does not reproduce for a loop mode --
      // fO2 there is either the carried gas's own fraction (an authored
      // leg) or CcrLoopAscentGas's pAlv-normalized fraction (a computed
      // row), neither of which is "ambient x fO2 = real ppO2". Every OC row
      // keeps the ambient x fO2 fallback, which is correct for a real tank
      // mix.
      double? ppO2Override,
      // The depth ppO2/END are computed at, when it differs from the row's
      // own displayed [depth]. A travel row -- OC or CCR -- determines its
      // gas at the leg's deeper end (ascentPlan.gasForDepth(from)) but
      // displays the shallower arrival depth, so the physics must use the
      // depth that determination actually came from: the leg's maximum
      // ppO2 and END on that gas, which is what a diver checks a travel
      // line for. The bailout table (BailoutSolver._scheduleRowsFor) follows
      // the same convention so the two tables read alike.
      double? physicsDepth,
    }) {
      final lastFO2 = previousFO2;
      final lastFHe = previousFHe;
      final switched =
          lastFO2 == null ||
          lastFHe == null ||
          (fO2 - lastFO2).abs() > _gasFractionEpsilon ||
          (fHe - lastFHe).abs() > _gasFractionEpsilon;
      final pDepth = physicsDepth ?? depth;
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
          ppO2: ppO2Override ?? environment.pressureAtDepth(pDepth) * fO2,
          // GasMix.end() goes negative once a helium-rich mix is shallower
          // than the depth at which it is as narcotic as air at the surface;
          // a negative depth is meaningless on a slate (a diver saw -6 m
          // printed at 3 m on a 7/70 diluent), so the floor is 0 m.
          endMeters: math.max(
            0.0,
            GasMix(
              o2: fO2 * 100,
              he: fHe * 100,
            ).end(pDepth, o2Narcotic: config.o2Narcotic),
          ),
        ),
      );
      previousFO2 = fO2;
      previousFHe = fHe;
    }

    for (final leg in legs) {
      final segment = leg.segment;
      final segmentIsLoop = _modeFor(plan, segment) != domain.PlanMode.oc;
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
        ppO2Override: segmentIsLoop
            ? _breathingFor(
                plan,
                leg.gasMix,
                leg.endDepth,
                segment: segment,
              ).inspiredAt(environment.pressureAtDepth(leg.endDepth)).pO2
            : null,
      );
    }

    void addTravel(double from, double to, int duration, int arrival) {
      final displayGas = ccrDisplayGasAt(from);
      if (displayGas != null) {
        // The loop's displayed gas never changes mid-ascent (it stays on
        // the last segment's diluent down to the surface), so there is
        // nothing to split here.
        add(
          kind: PlanScheduleRowKind.ascent,
          depth: to,
          duration: duration,
          runtime: arrival,
          fO2: displayGas.fO2,
          fHe: displayGas.fHe,
          tankId: _tankForGas(
            plan.tanks,
            displayGas.fO2,
            displayGas.fHe,
            isCcr: isCcr,
          ),
          physicsDepth: from,
          ppO2Override: ccrPpO2At(from),
        );
        return;
      }
      // OC: split at every gas-switch depth crossed, so each sub-leg prints
      // -- and is later charged in _computeTankUsages' matching split --
      // the gas actually eligible there, not only the one valid at the
      // deepest point (#3225). boundaries is just [from, to] on a regular
      // inter-stop leg, so this is a no-op split everywhere but the long
      // bottom-to-first-stop leg.
      final boundaries = travelLegBoundaries(
        ascentPlan,
        fromDepth: from,
        toDepth: to,
      );
      final totalSpan = from - to;
      var legDepth = from;
      var legArrival = arrival - duration;
      for (var i = 1; i < boundaries.length; i++) {
        final legTo = boundaries[i];
        final isLast = i == boundaries.length - 1;
        final legDuration = isLast
            ? arrival - legArrival
            : (duration * (legDepth - legTo) / totalSpan).round();
        legArrival += legDuration;
        final gas = ascentPlan.gasForDepth(legDepth);
        final fO2 = 1.0 - gas.fN2 - gas.fHe;
        final fHe = gas.fHe;
        add(
          kind: PlanScheduleRowKind.ascent,
          depth: legTo,
          duration: legDuration,
          runtime: legArrival,
          fO2: fO2,
          fHe: fHe,
          tankId: _tankForGas(plan.tanks, fO2, fHe, isCcr: isCcr),
          physicsDepth: legDepth,
        );
        legDepth = legTo;
      }
    }

    var depth = lastDepth;
    var end = segmentsRuntime;
    var phase = AscentPhase.toFirstStop;
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final travel = stop.arrivalRuntimeSeconds - end;
      // The first travel leg (bottom phase to the first stop) stays its own
      // row -- an informative transition. From the second stop on, a real
      // gas switch always lands exactly at the stop it leads into
      // (AscentGasPlan's design: a switch-at-MOD never falls strictly
      // between two 3 m-spaced stops), so a travel-between-stops row would
      // only ever repeat the previous line's gas -- clutter, not
      // information. Dropping it loses nothing: scheduleLines() already
      // derives each printed duration from consecutive runtimeSeconds, so
      // the travel time folds straight into the stop it leads to (#3138).
      if (i == 0 && travel > 0) {
        addTravel(depth, stop.depthMeters, travel, stop.arrivalRuntimeSeconds);
      }
      end = stop.arrivalRuntimeSeconds + stop.durationSeconds;
      final stopDisplayGas = ccrDisplayGasAt(stop.depthMeters);
      final stopFO2 = stopDisplayGas?.fO2 ?? stop.gasFO2;
      final stopFHe = stopDisplayGas?.fHe ?? stop.gasFHe;
      add(
        kind: PlanScheduleRowKind.stop,
        depth: stop.depthMeters,
        duration: stop.durationSeconds,
        runtime: end,
        fO2: stopFO2,
        fHe: stopFHe,
        tankId: stopDisplayGas != null
            ? _tankForGas(plan.tanks, stopFO2, stopFHe, isCcr: isCcr)
            : stop.tankId,
        airBreakSeconds: stop.airBreakSeconds,
        ppO2Override: ccrPpO2At(stop.depthMeters),
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
  ///
  /// On a loop plan the diver is never actually breathing a bailout tank
  /// unless they have bailed out, which this schedule does not model -- so a
  /// bailout mix must never be offered as a match. Without this filter, a
  /// dense OC bailout staging can coincidentally fall within tolerance of
  /// the loop's continuously-shifting inert fraction at almost any stop,
  /// making the gas column claim a switch that never happened (#3131).
  String? _tankForGas(
    List<DiveTank> tanks,
    double fO2,
    double fHe, {
    // Defaults false because _computeTankUsages, the only OC-side caller,
    // never carries a CCR plan (see the isCcr ? _computeCcrTankUsages(...) :
    // _computeTankUsages(...) split): every CCR-reachable call site below
    // sets this explicitly.
    bool isCcr = false,
  }) {
    DiveTank? match;
    for (final tank in tanks) {
      if (isCcr &&
          tank.role != TankRole.diluent &&
          tank.role != TankRole.oxygenSupply) {
        continue;
      }
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

/// The point on an authored leg where the diver was furthest above the deco
/// ceiling, found by the ceiling replay (#3354).
typedef _CeilingBreach = ({
  String segmentId,
  int runtimeSeconds,
  double depthMeters,
  double ceilingMeters,
});
