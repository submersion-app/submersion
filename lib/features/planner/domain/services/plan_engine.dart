import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/ascent/ascent_travel_spans.dart';
import 'package:submersion/core/deco/ascent/ccr_loop_ascent_gas.dart';
import 'package:submersion/core/deco/ascent/loop_ascent_gas.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/deco_ppo2_limits.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/cns_calculation_method.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/utils/gas_compressibility.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/segment_phase.dart';
import 'package:submersion/features/planner/domain/services/air_break_runs.dart';
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';
import 'package:submersion/features/planner/domain/services/issue_onset.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/domain/services/segment_rate_split.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';
import 'package:submersion/features/planner/domain/services/tank_usage_order.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart'
    show kDefaultBatteryReserveFraction, kDefaultWalkSpeedMps;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/core/deco/scr_calculator.dart';

/// Thresholds and policy limits the engine evaluates plans against.
///
/// A value type: `planEngineConfigProvider` rebuilds it from Settings, and
/// equality is what keeps an unchanged config from rerunning every plan
/// engine consumer downstream (issue #2632).
class PlanEngineConfig extends Equatable {
  final double ppO2Working;
  final double ppO2Deco;

  /// Per-O2-band deco ppO2 limits and the explicit MOD for 100% O2 (issue
  /// #3580), the diver's Settings defaults layered with this plan's own
  /// overrides (see [resolvedFor]). Off by default: [ppO2Deco] alone keeps
  /// governing every deco gas until the diver turns one on. Use
  /// [decoLimits] to resolve a specific gas's limit; these raw fields exist
  /// so [copyWith]/[resolvedFor] can merge them the same way as every
  /// other field here.
  final bool ppO2DecoBandsEnabled;
  final double ppO2DecoBand1;
  final double ppO2DecoBand2;
  final double ppO2DecoBand3;
  final bool maxO2DepthEnabled;
  final double maxO2DepthMeters;

  /// Hypercapnia-bailout phase (issue #3743): an elevated RMV for
  /// [hypercapniaMinutes] at the start of an OC bailout, a multiplier on
  /// [sacBottom] (issue #3552's "a plan's own value always wins" diver
  /// default). Off by default. Resolved per plan through
  /// [hypercapniaEnabledFor]/[hypercapniaAmvFor]/[hypercapniaSecondsFor],
  /// not a plain `?? this.x` merge - matches [airBreaksFor]'s
  /// "explicit off wins" shape, since the per-plan override
  /// ([domain.DivePlan.hypercapniaAmv]) is an absolute rate, not a factor.
  final bool hypercapniaEnabled;
  final double hypercapniaFactor;
  final int hypercapniaMinutes;

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

  /// SCR diver metabolic O2 consumption (surface liters per minute), which
  /// sets the CMF loop's steady-state O2 fraction.
  final double scrVo2Lpm;

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
    this.ppO2DecoBandsEnabled = false,
    this.ppO2DecoBand1 = 1.6,
    this.ppO2DecoBand2 = 1.6,
    this.ppO2DecoBand3 = 1.6,
    this.maxO2DepthEnabled = false,
    this.maxO2DepthMeters = 6.0,
    this.hypercapniaEnabled = false,
    this.hypercapniaFactor = 4.0,
    this.hypercapniaMinutes = 5,
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
    this.scrVo2Lpm = ScrCalculator.defaultVo2,
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
    ppO2DecoBandsEnabled,
    ppO2DecoBand1,
    ppO2DecoBand2,
    ppO2DecoBand3,
    maxO2DepthEnabled,
    maxO2DepthMeters,
    hypercapniaEnabled,
    hypercapniaFactor,
    hypercapniaMinutes,
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
    scrVo2Lpm,
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
    bool? ppO2DecoBandsEnabled,
    double? ppO2DecoBand1,
    double? ppO2DecoBand2,
    double? ppO2DecoBand3,
    bool? maxO2DepthEnabled,
    double? maxO2DepthMeters,
    bool? hypercapniaEnabled,
    double? hypercapniaFactor,
    int? hypercapniaMinutes,
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
    double? scrVo2Lpm,
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
      ppO2DecoBandsEnabled: ppO2DecoBandsEnabled ?? this.ppO2DecoBandsEnabled,
      ppO2DecoBand1: ppO2DecoBand1 ?? this.ppO2DecoBand1,
      ppO2DecoBand2: ppO2DecoBand2 ?? this.ppO2DecoBand2,
      ppO2DecoBand3: ppO2DecoBand3 ?? this.ppO2DecoBand3,
      maxO2DepthEnabled: maxO2DepthEnabled ?? this.maxO2DepthEnabled,
      maxO2DepthMeters: maxO2DepthMeters ?? this.maxO2DepthMeters,
      hypercapniaEnabled: hypercapniaEnabled ?? this.hypercapniaEnabled,
      hypercapniaFactor: hypercapniaFactor ?? this.hypercapniaFactor,
      hypercapniaMinutes: hypercapniaMinutes ?? this.hypercapniaMinutes,
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
      scrVo2Lpm: scrVo2Lpm ?? this.scrVo2Lpm,
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
      ppO2DecoBand1: plan.ppO2DecoBand1,
      ppO2DecoBand2: plan.ppO2DecoBand2,
      ppO2DecoBand3: plan.ppO2DecoBand3,
      ppO2DecoBandsEnabled: resolveDecoLayerEnabled(
        settingsEnabled: ppO2DecoBandsEnabled,
        explicitlyOff: plan.ppO2DecoBandsExplicitlyOff,
        hasCustomValue: hasCustomDecoBands(
          plan.ppO2DecoBand1,
          plan.ppO2DecoBand2,
          plan.ppO2DecoBand3,
        ),
      ),
      maxO2DepthMeters: plan.maxO2DepthMeters,
      maxO2DepthEnabled: resolveDecoLayerEnabled(
        settingsEnabled: maxO2DepthEnabled,
        explicitlyOff: plan.maxO2DepthExplicitlyOff,
        hasCustomValue: plan.maxO2DepthMeters != null,
      ),
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

  /// This config's deco ppO2 limits as a [DecoPpO2Limits] (issue #3580),
  /// for [tank_mod.dart]'s MOD/switch-depth resolution. Call on a
  /// [resolvedFor] config so a plan's per-band overrides are already
  /// merged in.
  DecoPpO2Limits get decoLimits => DecoPpO2Limits(
    flat: ppO2Deco,
    bandsEnabled: ppO2DecoBandsEnabled,
    band1: ppO2DecoBand1,
    band2: ppO2DecoBand2,
    band3: ppO2DecoBand3,
    explicitO2DepthEnabled: maxO2DepthEnabled,
    explicitO2DepthMeters: maxO2DepthMeters,
  );

  /// The open-circuit ascent over [bailoutTanks], which must carry resolved
  /// roles and be at least one: each gas joins at its cylinder's MOD (issue
  /// #3567), the one the diver set or the default for a bailout of its mix.
  /// Call on a [resolvedFor] config, as [decoLimits] says.
  ///
  /// The one definition of what a loop plan can bail out on, shared by the
  /// bailout schedule and the plan's own issue about it (#3961), so the two
  /// never disagree about which gases reach which depth.
  OptimalOcAscentGas bailoutAscentGas(
    List<DiveTank> bailoutTanks,
    DiveEnvironment environment,
  ) => OptimalOcAscentGas(
    maxPpO2: ppO2Deco,
    gases: ascentGasesFor(
      bailoutTanks,
      bottomPpO2: ppO2Working,
      decoPpO2: decoLimits,
      environment: environment,
    ),
  );

  /// [plan]'s low (shallow) setpoint: its own value when set, else the
  /// diver's [ccrSetpointLow] (issue #2801).
  double setpointLowFor(domain.DivePlan plan) =>
      plan.setpointLow ?? ccrSetpointLow;

  /// The rate an open-circuit leg of [phase] is breathed at: bottom SAC while
  /// the dive is still working (descending, or level at depth), deco SAC once
  /// it is heading up (ascent legs and stops).
  double sacForPhase(SegmentPhase phase) => switch (phase) {
    SegmentPhase.descent || SegmentPhase.level => sacBottom,
    SegmentPhase.ascent || SegmentPhase.stop => sacDeco,
  };

  /// Surface liters a cylinder gives up over [minutes] at [ambientBar] on a
  /// [sac] rate, breathed in [mode] (issue #3972).
  ///
  /// A constant-mass-flow loop draws its injection rate, whatever the depth or
  /// the diver's ventilation. A passive loop replaces only the share of each
  /// breath it vents, as Subsurface's update_cylinder_pressure charges it.
  /// Everything else costs what open circuit does.
  double cylinderLiters(
    domain.PlanMode mode, {
    required double sac,
    required double minutes,
    required double ambientBar,
  }) => switch (mode) {
    domain.PlanMode.scr => scrInjectionRateLpm * minutes,
    domain.PlanMode.pscr => sac * minutes * ambientBar * pscrRatio / 1000.0,
    domain.PlanMode.oc || domain.PlanMode.ccr => sac * minutes * ambientBar,
  };

  /// Surface liters of [plan]'s problem-solving time at max depth, breathed in
  /// [mode] and shared with a buddy, except on a constant-mass-flow loop, whose
  /// draw no breathing rate changes; nothing when the plan sets none or never
  /// leaves the surface.
  double problemSolvingLiters(
    domain.DivePlan plan,
    DiveEnvironment environment, {
    required domain.PlanMode mode,
  }) {
    if (problemSolvingMinutes <= 0 || plan.maxDepth <= 0) return 0;
    return cylinderLiters(
      mode,
      sac: sacBottom * buddyFactor,
      minutes: problemSolvingMinutes.toDouble(),
      ambientBar: environment.pressureAtDepth(plan.maxDepth),
    );
  }

  /// [plan]'s stressed (bailout/rock-bottom) SAC: its own [sacStressed]
  /// override when set, else [sacBottom] (already resolved against this
  /// plan - call this on a [resolvedFor] config) times the diver's
  /// [sacStressedFactor] (issue #3552; was a hardcoded 2.5x of the plan's
  /// raw `sacBottom`, see [domain.DivePlan.sacStressedEffective]).
  double sacStressedFor(domain.DivePlan plan) =>
      plan.sacStressed ?? sacBottom * sacStressedFactor;

  /// Whether [plan]'s OC bailout uses a hypercapnia phase at all (issue
  /// #3743): true when either per-plan override
  /// ([domain.DivePlan.hypercapniaAmv]/[domain.DivePlan.hypercapniaMinutes])
  /// is set (an explicit "Custom" choice), else the diver's Settings
  /// [hypercapniaEnabled] toggle, unless
  /// [domain.DivePlan.hypercapniaExplicitlyOff] forces it off regardless -
  /// same "explicit off wins" shape as [airBreaksFor].
  bool hypercapniaEnabledFor(domain.DivePlan plan) {
    if (plan.hypercapniaExplicitlyOff) return false;
    if (plan.hypercapniaAmv != null || plan.hypercapniaMinutes != null) {
      return true;
    }
    return hypercapniaEnabled;
  }

  /// [plan]'s hypercapnia-bailout AMV in L/min, or null when
  /// [hypercapniaEnabledFor] is false: its own [domain.DivePlan.hypercapniaAmv]
  /// override when set, else [sacBottom] (already resolved against this
  /// plan - call this on a [resolvedFor] config) times the diver's
  /// [hypercapniaFactor] - same "absolute override, else a factor of
  /// bottom SAC" shape as [sacStressedFor].
  double? hypercapniaAmvFor(domain.DivePlan plan) {
    if (!hypercapniaEnabledFor(plan)) return null;
    return plan.hypercapniaAmv ?? sacBottom * hypercapniaFactor;
  }

  /// [plan]'s hypercapnia-bailout phase duration in seconds from the
  /// bailout instant, or null when [hypercapniaEnabledFor] is false.
  int? hypercapniaSecondsFor(domain.DivePlan plan) {
    if (!hypercapniaEnabledFor(plan)) return null;
    return (plan.hypercapniaMinutes ?? hypercapniaMinutes) * 60;
  }

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
      vo2: config.scrVo2Lpm,
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
/// constant-ppO2 setpoints (segments' gases are the diluent) and semi-closed
/// plans at their loop mix (segments' gases are the supply). Both loops' deco
/// schedules run on the loop via a [LoopAscentGas].
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
    // Deliberately the flat limits (issue #3580 scope cut, see
    // PlanCalculatorService's matching comment): O2ToxicityCalculator is a
    // general-purpose, widely shared utility, used here only for CNS/OTU
    // accumulation from a ppO2 in the plan's water, not for the deco ppO2
    // critical/warning PlanIssue check below, which IS band-aware
    // (config.decoLimits.ppO2For).
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
    final finalSegment = segments.isEmpty ? null : segments.last;
    final semiClosedLoop = isCcr
        ? null
        : _semiClosedLoopFor(plan, finalSegment, environment);
    // Named outright rather than matched on its mix: a carried bailout twin of
    // the supply gas must not take the ascent's gas charge or its table lines.
    final loopSupplyTankId = semiClosedLoop == null
        ? null
        : finalSegment?.tankId;
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
        : semiClosedLoop ?? _ascentPlanFor(plan.tanks, environment);

    var state = startState ?? model.initial();
    var runtime = 0;
    // A repetitive dive starts with the exposure earlier dives left behind.
    var cns = plan.startCns;
    var otu = plan.startOtu;
    // The same exposure, stretch by stretch, so an issue can name the
    // moment its total first reached the limit (#3738).
    final cnsSteps = <RuntimeIncrement>[];
    final otuSteps = <RuntimeIncrement>[];
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
      final fO2 = segment.gasMix.o2 / 100.0;
      // OC ppO2 is ambient x fraction in the plan's water, as the schedule
      // shows it (issue #3913); loop ppO2 is the inspired (setpoint/CMF)
      // value.
      final segmentMaxPpO2 = segmentIsLoop
          ? _breathingFor(
              plan,
              segment.gasMix,
              deeperEnd,
              segment: segment,
            ).inspiredAt(environment.pressureAtDepth(deeperEnd)).pO2
          : environment.pressureAtDepth(deeperEnd) * fO2;
      if (segmentMaxPpO2 > maxPpO2) maxPpO2 = segmentMaxPpO2;

      final avgPpO2 = segmentIsLoop
          ? breathing.inspiredAt(environment.pressureAtDepth(leg.avgDepth)).pO2
          : environment.pressureAtDepth(leg.avgDepth) * fO2;
      final legCns = o2Calc.calculateCnsForSegment(
        avgPpO2,
        segment.durationSeconds,
      );
      final legOtu = o2Calc.calculateOtuForSegment(
        avgPpO2,
        segment.durationSeconds,
      );
      cns += legCns;
      otu += legOtu;
      cnsSteps.add(
        RuntimeIncrement(
          startRuntime: startRuntime,
          durationSeconds: segment.durationSeconds,
          amount: legCns,
        ),
      );
      otuSteps.add(
        RuntimeIncrement(
          startRuntime: startRuntime,
          durationSeconds: segment.durationSeconds,
          amount: legOtu,
        ),
      );

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
    final stops = _mapStops(
      schedule,
      plan,
      ascentPlan,
      lastDepth,
      runtime,
      loopSupplyTankId,
    );
    final scheduleRows = _buildSchedule(
      legs,
      stops,
      plan,
      ascentPlan,
      lastDepth,
      runtime,
      environment,
      loopSupplyTankId,
    );

    // A separate, finely-sampled replay for the chart's ceiling curve.
    // It never feeds back into `state`/cns/otu/stops, so it cannot perturb
    // the numbers the rest of this method already computed and returned.
    // The same replay walks the authored legs at that resolution, so it is
    // also where a leg that takes the diver above the ceiling shows up, and
    // it ends at the surface, so its last state is the surfaced tissue.
    final (:trace, :breaches, :surfaced) = _ceilingTrace(
      model,
      plan,
      legs,
      stops,
      lastDepth,
      ascentPlan,
      startState ?? model.initial(),
    );

    void addExposure(int startRuntime, int seconds, double ppO2) {
      final stepCns = o2Calc.calculateCnsForSegment(ppO2, seconds);
      final stepOtu = o2Calc.calculateOtuForSegment(ppO2, seconds);
      cns += stepCns;
      otu += stepOtu;
      cnsSteps.add(
        RuntimeIncrement(
          startRuntime: startRuntime,
          durationSeconds: seconds,
          amount: stepCns,
        ),
      );
      otuSteps.add(
        RuntimeIncrement(
          startRuntime: startRuntime,
          durationSeconds: seconds,
          amount: stepOtu,
        ),
      );
    }

    // The computed ascent's travel counts as well, the same as an authored
    // ascent over the same depths: each span at its mean depth, on the gas in
    // force at its deeper end, which is the gas the deco model loaded it on.
    // A leg splits at a gas switch, so no span charges one gas for another's
    // stretch. The spans leave out the stops, so the clock jumps over each
    // one as the ascent passes it.
    var spanStart = runtime;
    var nextStop = 0;
    for (final span in ascentTravelSpans(
      policy,
      ascentPlan,
      fromDepth: lastDepth,
      stopDepths: [for (final stop in stops) stop.depthMeters],
    )) {
      while (nextStop < stops.length &&
          stops[nextStop].depthMeters >= span.fromDepth) {
        final stop = stops[nextStop++];
        spanStart = stop.arrivalRuntimeSeconds + stop.durationSeconds;
      }
      final avgDepth = (span.fromDepth + span.toDepth) / 2.0;
      final ppO2 = ascentPlan is LoopAscentGas
          ? ascentPlan.inspiredPpO2At(avgDepth)
          : environment.pressureAtDepth(avgDepth) *
                ascentPlan.gasForDepth(span.fromDepth).fO2;
      addExposure(spanStart, span.seconds, ppO2);
      spanStart += span.seconds;
    }

    // Decompression stops carry O2 exposure too — a long stop on a rich deco
    // gas is where CNS/OTU pile up — so accumulate them before issues and the
    // outcome are built. Each stop splits into its primary gas and, when air
    // breaks apply, the break gas for that portion. On a loop the stop's gas
    // is not what the diver inspires, so the loop answers for the ppO2.
    for (final stop in stops) {
      final stopPressure = environment.pressureAtDepth(stop.depthMeters);
      final primarySeconds = stop.durationSeconds - stop.airBreakSeconds;
      final primaryPpO2 = ascentPlan is LoopAscentGas
          ? ascentPlan.inspiredPpO2At(stop.depthMeters)
          : stopPressure * stop.gasFO2;
      addExposure(stop.arrivalRuntimeSeconds, primarySeconds, primaryPpO2);
      if (stop.airBreakSeconds > 0) {
        final breakGas = ascentPlan.breakGasForDepth(stop.depthMeters);
        final breakPpO2 = breakGas != null
            ? stopPressure * breakGas.fO2
            : primaryPpO2;
        addExposure(
          stop.arrivalRuntimeSeconds + primarySeconds,
          stop.airBreakSeconds,
          breakPpO2,
        );
      }
    }

    final (:usages, :draws) = isCcr
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
            loopSupplyTankId,
          );
    final tankUsages = usages;
    final issues = _computeIssues(
      plan,
      legs,
      segmentOutcomes,
      tankUsages,
      cns,
      otu,
      environment,
      breaches,
      ascentPlan,
      stops,
      onsets: (
        cnsSteps: cnsSteps,
        otuSteps: otuSteps,
        draws: draws,
        schedule: scheduleRows,
      ),
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
      surfacedTissue: surfaced,
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
  ///
  /// [surfaced] is the replay's tissue state at the end: the state on
  /// reaching the surface, stops and air breaks included.
  ({
    List<(int, double)> trace,
    Iterable<_CeilingBreach> breaches,
    BuhlmannState surfaced,
  })
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

    BreathingConfig breathing(AscentGas gas) =>
        OpenCircuit(fO2: 1.0 - gas.fN2 - gas.fHe, fHe: gas.fHe);

    BreathingConfig ascentBreathingAt(double depth) =>
        breathing(ascentPlan.gasForDepth(depth));

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
      // A stop with air breaks is breathed in the scheduler's own runs, so
      // the tissues come out as they did when it timed the stop.
      final breakGas = ascentPlan.breakGasForDepth(stop.depthMeters);
      final airBreaks = policy.airBreaks;
      if (stop.airBreakSeconds > 0 && breakGas != null && airBreaks != null) {
        final onBreak = breathing(breakGas);
        for (final run in airBreakRuns(stop.durationSeconds, airBreaks)) {
          sampleLeg(
            stop.depthMeters,
            stop.depthMeters,
            run.seconds,
            (_) => run.onBreak ? onBreak : ascentBreathingAt(stop.depthMeters),
          );
        }
      } else {
        sampleLeg(
          stop.depthMeters,
          stop.depthMeters,
          stop.durationSeconds,
          (_) => ascentBreathingAt(stop.depthMeters),
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
      sampleLeg(depth, 0, legSeconds, ascentBreathingAt);
    }

    return (
      trace: trace,
      breaches: breaches.values,
      surfaced: traceState as BuhlmannState,
    );
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

  /// CCR consumption: metabolic O2 for the time on the loop charged to the
  /// oxygen-supply tank, descent loop-fill diluent charged leg by leg to
  /// whichever diluent that leg actually breathes. When a per-segment
  /// override takes a leg off the loop, that leg breathes its own cylinder
  /// instead, at the SAC rates the open-circuit walk charges (#3898). A
  /// bailout tank that no such leg breathes consumes nothing here: the
  /// bailout solver sizes it.
  _TankUsageResult _computeCcrTankUsages(
    domain.DivePlan plan, {
    required List<ResolvedLeg> legs,
    required int totalRuntimeSeconds,
    required DiveEnvironment environment,
  }) {
    if (plan.tanks.isEmpty) return (usages: const [], draws: const {});
    final liters = <String, double>{for (final t in plan.tanks) t.id: 0.0};
    final draws = <String, List<RuntimeIncrement>>{
      for (final t in plan.tanks) t.id: [],
    };
    final offLoopLegs = [
      for (final leg in legs)
        if (modeFor(plan, leg.segment) != domain.PlanMode.ccr) leg,
    ];

    String? tankIdByRole(TankRole role) {
      for (final tank in plan.tanks) {
        if (tank.role == role) return tank.id;
      }
      return null;
    }

    final o2TankId = tankIdByRole(TankRole.oxygenSupply);
    if (o2TankId != null) {
      final offLoopSeconds = offLoopLegs.fold<int>(
        0,
        (sum, leg) => sum + leg.durationSeconds,
      );
      liters[o2TankId] =
          config.o2MetabolicRateLpm *
          ((totalRuntimeSeconds - offLoopSeconds) / 60.0);
      // A draw only while on the loop, so an off-loop leg leaves a gap and the
      // reserve is not marked early (#3738).
      void drawO2(int startRuntime, int seconds) => draws[o2TankId]!.add(
        RuntimeIncrement(
          startRuntime: startRuntime,
          durationSeconds: seconds,
          amount: config.o2MetabolicRateLpm * (seconds / 60.0),
        ),
      );
      var elapsed = 0;
      for (final leg in legs) {
        if (modeFor(plan, leg.segment) == domain.PlanMode.ccr) {
          drawO2(elapsed, leg.durationSeconds);
        }
        elapsed += leg.durationSeconds;
      }
      drawO2(elapsed, totalRuntimeSeconds - elapsed);
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
    var legStart = 0;
    for (final leg in legs) {
      if (modeFor(plan, leg.segment) == domain.PlanMode.ccr &&
          leg.endDepth > leg.startDepth &&
          liters.containsKey(leg.tankId)) {
        final fill =
            config.loopVolumeLiters *
            (environment.pressureAtDepth(leg.endDepth) -
                environment.pressureAtDepth(leg.startDepth));
        liters[leg.tankId] = (liters[leg.tankId] ?? 0) + fill;
        draws[leg.tankId]!.add(
          RuntimeIncrement(
            startRuntime: legStart,
            durationSeconds: leg.durationSeconds,
            amount: fill,
          ),
        );
      }
      legStart += leg.durationSeconds;
    }

    // Off the loop the diver breathes the cylinder itself. Like the
    // open-circuit walk, a leg naming a cylinder no longer on the plan falls
    // back to the first one: dropping it would report that gas as free.
    void charge(
      String tankId,
      double amount, {
      required int atRuntime,
      required int seconds,
    }) {
      final id = liters.containsKey(tankId) ? tankId : plan.tanks.first.id;
      liters[id] = (liters[id] ?? 0) + amount;
      draws[id]!.add(
        RuntimeIncrement(
          startRuntime: atRuntime,
          durationSeconds: seconds,
          amount: amount,
        ),
      );
    }

    legStart = 0;
    for (final leg in legs) {
      if (modeFor(plan, leg.segment) != domain.PlanMode.ccr) {
        charge(
          leg.tankId,
          _legLiters(plan, leg, environment),
          atRuntime: legStart,
          seconds: leg.durationSeconds,
        );
      }
      legStart += leg.durationSeconds;
    }

    // Only when the diver is off the loop at the bottom: a problem solved on
    // the loop draws nothing the plan charges by the minute.
    final bottomLeg = lastLegAtMaxDepth(plan, offLoopLegs);
    if (bottomLeg != null) {
      charge(
        bottomLeg.tankId,
        config.problemSolvingLiters(
          plan,
          environment,
          mode: _modeFor(plan, bottomLeg.segment),
        ),
        atRuntime: _bottomEndRuntime(plan, legs, bottomLeg),
        seconds: 0,
      );
    }

    final usages = [
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
                remaining != null &&
                used > 0 &&
                remaining < config.reservePressure,
          );
        }(),
    ];
    return (usages: usages, draws: draws);
  }

  /// Surface liters [leg] costs the cylinder it names, in its own breathing
  /// mode.
  double _legLiters(
    domain.DivePlan plan,
    ResolvedLeg leg,
    DiveEnvironment environment,
  ) => config.cylinderLiters(
    _modeFor(plan, leg.segment),
    sac: config.sacForPhase(leg.phase),
    minutes: leg.durationSeconds / 60.0,
    ambientBar: environment.pressureAtDepth(leg.avgDepth),
  );

  /// The last of [legs] at [plan]'s max depth, which is what problem-solving
  /// time is charged to, or null when none of them reaches it.
  static ResolvedLeg? lastLegAtMaxDepth(
    domain.DivePlan plan,
    Iterable<ResolvedLeg> legs,
  ) {
    ResolvedLeg? bottomLeg;
    for (final leg in legs) {
      if (leg.endDepth >= plan.maxDepth - 0.1 ||
          leg.startDepth >= plan.maxDepth - 0.1) {
        bottomLeg = leg;
      }
    }
    return bottomLeg;
  }

  /// The runtime the bottom ends at, given [bottomLeg], the last of [legs] at
  /// [plan]'s max depth: the end of that leg, or its start when it is the
  /// ascent leaving that depth. 0 without one.
  static int _bottomEndRuntime(
    domain.DivePlan plan,
    List<ResolvedLeg> legs,
    ResolvedLeg? bottomLeg,
  ) {
    var elapsed = 0;
    for (final leg in legs) {
      if (identical(leg, bottomLeg)) {
        return leg.endDepth >= plan.maxDepth - 0.1
            ? elapsed + leg.durationSeconds
            : elapsed;
      }
      elapsed += leg.durationSeconds;
    }
    return 0;
  }

  /// Consumption for every plan but CCR: bottom SAC while the dive is still
  /// working (descending, or level at depth), deco SAC once it is heading up
  /// (ascent legs and stops), depth pressure via the plan's environment,
  /// remaining pressure compressibility-corrected. A semi-closed leg turns
  /// that into what the loop draws (see [PlanEngineConfig.cylinderLiters]).
  _TankUsageResult _computeTankUsages(
    domain.DivePlan plan,
    List<ResolvedLeg> legs,
    List<PlanStop> stops,
    double lastDepth,
    DiveEnvironment environment,
    AscentGasPlan ascentPlan,
    String? loopSupplyTankId,
  ) {
    if (plan.tanks.isEmpty) return (usages: const [], draws: const {});
    final liters = <String, double>{for (final t in plan.tanks) t.id: 0.0};
    final draws = <String, List<RuntimeIncrement>>{
      for (final t in plan.tanks) t.id: [],
    };
    final fallbackTankId = plan.tanks.first.id;

    // [atRuntime] and [seconds] place the draw in the dive, so a cylinder's
    // reserve can be marked where it is first reached (#3738).
    void charge(
      String? tankId,
      double amount, {
      required int atRuntime,
      required int seconds,
    }) {
      final id = tankId != null && liters.containsKey(tankId)
          ? tankId
          : fallbackTankId;
      liters[id] = (liters[id] ?? 0) + amount;
      draws[id]!.add(
        RuntimeIncrement(
          startRuntime: atRuntime,
          durationSeconds: seconds,
          amount: amount,
        ),
      );
    }

    String? ascentTankFor(AscentGas gas) =>
        loopSupplyTankId ?? _tankForGas(plan.tanks, gas.fO2, gas.fHe);

    final ascentMode = loopSupplyTankId == null
        ? domain.PlanMode.oc
        : _modeFor(plan, legs.last.segment);
    double ascentLiters(int seconds, double ambientBar) =>
        config.cylinderLiters(
          ascentMode,
          sac: config.sacDeco,
          minutes: seconds / 60.0,
          ambientBar: ambientBar,
        );

    // Reads sacBottom/sacDeco/problemSolvingMinutes from [config] (issue
    // #3552), not [plan] directly: by this point [config] is already
    // resolvedFor this plan, so an unset field already carries the diver's
    // Settings default. sacFactor has no absolute global value of its own -
    // it always resolves through config.buddyFactor (see resolvedFor).
    var legStart = 0;
    for (final leg in legs) {
      charge(
        leg.tankId,
        _legLiters(plan, leg, environment),
        atRuntime: legStart,
        seconds: leg.durationSeconds,
      );
      legStart += leg.durationSeconds;
    }

    // Problem-solving time: extra N minutes at max depth on the working
    // gas, at bottom SAC x SAC factor, so the used/end figures include the
    // same bottom-hold term the gas-options row describes.
    // It is charged as one lump where the bottom ends: gas the diver must
    // still have in hand when leaving the bottom.
    final bottomLeg = lastLegAtMaxDepth(plan, legs);
    charge(
      bottomLeg?.tankId,
      config.problemSolvingLiters(
        plan,
        environment,
        mode: _modeFor(plan, bottomLeg?.segment),
      ),
      atRuntime: _bottomEndRuntime(plan, legs, bottomLeg),
      seconds: 0,
    );

    // Computed ascent: travel legs and stops on the deco SAC.
    final policy = _policyFor(plan);
    // Charges each sub-leg to the gas actually eligible across it, the one
    // the deco model and the exposure breathe there: the diver switches at
    // the stop, so a leg into a switch stop is still on the gas it left.
    void chargeSplitLeg(
      double from,
      double to,
      int seconds, {
      required int atRuntime,
    }) {
      var spanStart = atRuntime;
      for (final span in splitAscentLeg(
        ascentPlan,
        fromDepth: from,
        toDepth: to,
        seconds: seconds,
      )) {
        charge(
          ascentTankFor(ascentPlan.gasForDepth(span.fromDepth)),
          ascentLiters(
            span.seconds,
            environment.pressureAtDepth((span.fromDepth + span.toDepth) / 2.0),
          ),
          atRuntime: spanStart,
          seconds: span.seconds,
        );
        spanStart += span.seconds;
      }
    }

    var depth = lastDepth;
    var phase = AscentPhase.toFirstStop;
    for (final stop in stops) {
      final legSeconds = policy.ascentSeconds(
        fromDepth: depth,
        toDepth: stop.depthMeters,
        phase: phase,
      );
      // Mirrors _buildSchedule's own split (#3225), rather than lumping a
      // leg onto its stop's shallow gas. A switch at a gas's MOD lands at a
      // stop, but a depth the diver set can fall between two of them.
      chargeSplitLeg(
        depth,
        stop.depthMeters,
        legSeconds,
        atRuntime: stop.arrivalRuntimeSeconds - legSeconds,
      );
      final stopPressure = environment.pressureAtDepth(stop.depthMeters);
      final primarySeconds = stop.durationSeconds - stop.airBreakSeconds;
      charge(
        stop.tankId,
        ascentLiters(primarySeconds, stopPressure),
        atRuntime: stop.arrivalRuntimeSeconds,
        seconds: primarySeconds,
      );
      if (stop.airBreakSeconds > 0) {
        charge(
          stop.airBreakTankId,
          ascentLiters(stop.airBreakSeconds, stopPressure),
          atRuntime: stop.arrivalRuntimeSeconds + primarySeconds,
          seconds: stop.airBreakSeconds,
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
      chargeSplitLeg(
        depth,
        0,
        legSeconds,
        atRuntime: stops.isEmpty
            ? legStart
            : stops.last.arrivalRuntimeSeconds + stops.last.durationSeconds,
      );
    }

    final usages = [
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
          final minGas = _minGasFor(plan, tank, environment);
          final turn = _turnPressureFor(plan, tank, minGasBar: minGas.bar);
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
            turnPressureBar: turn.bar,
            minGasBar: minGas.bar,
            turnPressureGap: turn.gap,
            minGasGap: minGas.gap,
          );
        }(),
    ];
    return (usages: usages, draws: draws);
  }

  /// Turn pressure per the plan's rule; bottom tanks with a start pressure
  /// only. `usable = start - max(reserve, minGasBar)`; turn when the rule's
  /// fraction of the usable gas is consumed. Flooring at [minGasBar] (the
  /// cylinder's rock bottom, null where it does not apply) means no rule
  /// ever turns with less than the plan's own emergency exit needs (#3741);
  /// a rock bottom at or above the fill leaves nothing usable, so the turn
  /// is the fill itself.
  ///
  /// Reads the rule/fraction from [config] (issue #3552), not [plan]
  /// directly: by this point [config] is already resolvedFor this plan,
  /// so an unset plan field already carries the diver's Settings default.
  ///
  /// A back gas it cannot compute for carries the missing input as `gap`
  /// (#3603); any other cylinder gets neither. A missing rule comes first:
  /// a start pressure alone would still leave the turn blank.
  ({double? bar, PlanGasLimitGap? gap}) _turnPressureFor(
    domain.DivePlan plan,
    DiveTank tank, {
    required double? minGasBar,
  }) {
    if (tank.role != TankRole.backGas) return (bar: null, gap: null);
    final rule = config.turnPressureRuleFor(plan);
    if (rule == null || rule == domain.TurnPressureRule.off) {
      return (bar: null, gap: PlanGasLimitGap.noTurnRule);
    }
    final start = tank.startPressure;
    if (start == null) {
      return (bar: null, gap: PlanGasLimitGap.noStartPressure);
    }
    final floor = math.max(
      config.reservePressure,
      minGasBar ?? config.reservePressure,
    );
    final usable = (start - floor).clamp(0.0, start);
    final fraction = switch (rule) {
      domain.TurnPressureRule.off => 0.0, // unreachable, handled above
      domain.TurnPressureRule.allUsable => 1.0,
      domain.TurnPressureRule.halves => 0.5,
      domain.TurnPressureRule.thirds => 1.0 / 3.0,
      domain.TurnPressureRule.custom =>
        config.turnPressureFractionFor(plan) ?? 1.0 / 3.0,
    };
    // A plan file or a stored row can carry any custom fraction; outside
    // [0, 1] the turn would land under the floor or above the fill.
    return (bar: start - usable * fraction.clamp(0.0, 1.0), gap: null);
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
  ///
  /// A back gas it cannot compute for carries the missing input as `gap`
  /// (#3603). A loop plan, any other cylinder, or a plan with no depth yet
  /// gets neither: minimum gas does not apply there.
  ({double? bar, PlanGasLimitGap? gap}) _minGasFor(
    domain.DivePlan plan,
    DiveTank tank,
    DiveEnvironment environment,
  ) {
    final maxDepth = plan.maxDepth;
    if (plan.mode == domain.PlanMode.ccr ||
        tank.role != TankRole.backGas ||
        maxDepth <= 0) {
      return (bar: null, gap: null);
    }
    if (tank.startPressure == null) {
      return (bar: null, gap: PlanGasLimitGap.noStartPressure);
    }
    final volume = tank.volume ?? 11.0;
    if (volume <= 0) return (bar: null, gap: PlanGasLimitGap.noVolume);
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
    return (bar: liters / volume, gap: null);
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
    AscentGasPlan ascentPlan,
    List<PlanStop> stops, {
    required _IssueOnsets onsets,
  }) {
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

    // Built once per call, not per leg: the getter constructs a new object.
    final decoLimits = config.decoLimits;
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
      // The deco ceiling for THIS segment's own gas (issue #3580): its
      // band when bands are on, the ppO2 at the explicit depth for a gas
      // under that setting, otherwise the flat ppO2Deco, same as before.
      // Only used for display here - the breach check itself goes through
      // decoCeilingBreachedFor, which compares depth directly for an
      // explicit-depth gas instead of this ppO2.
      //
      // A loop segment's ppO2 follows the setpoint, not its diluent's O2
      // fraction, so those per-gas layers (OC deco gas limits) do not apply
      // there: it keeps the flat ppO2Deco, as before.
      final segmentIsLoop = _modeFor(plan, segment) != domain.PlanMode.oc;
      final segmentDecoPpO2 = segmentIsLoop
          ? config.ppO2Deco
          : decoCeilingPpO2For(
              segment.gasMix,
              decoLimits,
              environment: environment,
            );
      final decoCeilingBreached = segmentIsLoop
          ? outcome.maxPpO2 > config.ppO2Deco
          : decoCeilingBreachedFor(
              segment.gasMix,
              decoLimits,
              depthMeters: deeperEnd,
              actualPpO2: outcome.maxPpO2,
              environment: environment,
            );
      final workingLimitExceeded = segmentIsLoop
          ? outcome.maxPpO2 > config.ppO2Working
          : ppO2OverLimit(outcome.maxPpO2, config.ppO2Working);

      // Where on this leg a depth limit is first passed (#3738).
      int onset(bool Function(double depth) exceeds) => legOnsetRuntime(
        startRuntime: outcome.startRuntime,
        durationSeconds: outcome.endRuntime - outcome.startRuntime,
        startDepth: leg.startDepth,
        endDepth: leg.endDepth,
        exceeds: exceeds,
      );
      // The same ppO2 the leg's maxPpO2 was taken from, at any depth.
      double ppO2At(double depth) => segmentIsLoop
          ? _breathingFor(
              plan,
              segment.gasMix,
              depth,
              segment: segment,
            ).inspiredAt(environment.pressureAtDepth(depth)).pO2
          : environment.pressureAtDepth(depth) * fO2;
      double densityAt(double depth) => gasDensityGPerL(
        fO2: fO2,
        fHe: fHe,
        ambientPressureBar: environment.pressureAtDepth(depth),
      );

      // The same deco ceiling check as decoCeilingBreached, at any depth.
      bool decoCeilingBreachedAt(double depth) => segmentIsLoop
          ? ppO2At(depth) > config.ppO2Deco
          : decoCeilingBreachedFor(
              segment.gasMix,
              decoLimits,
              depthMeters: depth,
              actualPpO2: ppO2At(depth),
              environment: environment,
            );

      // The same working limit check as workingLimitExceeded, at any depth.
      bool workingLimitExceededAt(double depth) => segmentIsLoop
          ? ppO2At(depth) > config.ppO2Working
          : ppO2OverLimit(ppO2At(depth), config.ppO2Working);

      if (decoCeilingBreached) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.ppO2Critical,
            severity: PlanIssueSeverity.critical,
            message:
                'ppO2 ${outcome.maxPpO2.toStringAsFixed(2)} bar exceeds the '
                'deco limit',
            atRuntime: onset(decoCeilingBreachedAt),
            atDepth: deeperEnd,
            segmentId: segment.id,
            value: outcome.maxPpO2,
            threshold: segmentDecoPpO2,
          ),
        );
      } else if (workingLimitExceeded) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.ppO2High,
            severity: PlanIssueSeverity.warning,
            message:
                'ppO2 ${outcome.maxPpO2.toStringAsFixed(2)} bar exceeds the '
                'working limit',
            atRuntime: onset(workingLimitExceededAt),
            atDepth: deeperEnd,
            segmentId: segment.id,
            value: outcome.maxPpO2,
            threshold: config.ppO2Working,
          ),
        );
      }

      // Mode-aware: the CCR loop holds the setpoint, so hypoxia only fires
      // when the in-force setpoint itself is hypoxic. A segment off the loop
      // breathes its own gas, so its override decides.
      double inspiredO2At(double depth) => _breathingFor(
        plan,
        segment.gasMix,
        depth,
        segment: segment,
      ).inspiredAt(environment.pressureAtDepth(depth)).pO2;
      final inspiredO2 = inspiredO2At(shallowerEnd);
      if (inspiredO2 < _hypoxicPpO2) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.hypoxicGas,
            severity: PlanIssueSeverity.critical,
            message:
                'Gas is hypoxic at ${shallowerEnd.toStringAsFixed(0)} m '
                '(ppO2 ${inspiredO2.toStringAsFixed(2)} bar)',
            atRuntime: onset((d) => inspiredO2At(d) < _hypoxicPpO2),
            atDepth: shallowerEnd,
            segmentId: segment.id,
            value: inspiredO2,
            threshold: _hypoxicPpO2,
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
              atRuntime: onset(
                (d) =>
                    environment.pressureAtDepth(d) * fO2 >
                    config.ccrDiluentModPpO2,
              ),
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
            atRuntime: onset(
              (d) =>
                  segment.gasMix.end(d, o2Narcotic: config.o2Narcotic) >
                  config.endLimitMeters,
            ),
            atDepth: deeperEnd,
            segmentId: segment.id,
            value: end,
            threshold: config.endLimitMeters,
          ),
        );
      }

      final density = densityAt(deeperEnd);
      if (density > gasDensityCriticalGPerL) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.gasDensityCritical,
            severity: PlanIssueSeverity.critical,
            message:
                'Gas density ${density.toStringAsFixed(1)} g/L exceeds the '
                'hard limit',
            atRuntime: onset((d) => densityAt(d) > gasDensityCriticalGPerL),
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
            atRuntime: onset((d) => densityAt(d) > gasDensityWarnGPerL),
            atDepth: deeperEnd,
            segmentId: segment.id,
            value: density,
            threshold: gasDensityWarnGPerL,
          ),
        );
      }
    }

    // What the dive started with: the total less every stretch added to it.
    final cnsStart = onsets.cnsSteps.fold(cns, (sum, s) => sum - s.amount);
    final otuStart = onsets.otuSteps.fold(otu, (sum, s) => sum - s.amount);
    int? cnsOnset(double threshold) =>
        runtimeReaching(onsets.cnsSteps, threshold: threshold, start: cnsStart);

    if (cns >= 100) {
      issues.add(
        PlanIssue(
          type: PlanIssueType.cnsCritical,
          severity: PlanIssueSeverity.critical,
          message: 'CNS reaches ${cns.toStringAsFixed(0)}%',
          atRuntime: cnsOnset(100),
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
          atRuntime: cnsOnset(config.cnsWarningThreshold.toDouble()),
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
          atRuntime: runtimeReaching(
            onsets.otuSteps,
            threshold: config.otuLimit,
            start: otuStart,
          ),
          value: otu,
          threshold: config.otuLimit,
        ),
      );
    }

    for (final usage in tankUsages) {
      final remaining = usage.remainingPressure;
      if (remaining == null) continue;
      int? drawOnset(double pressureBar) =>
          _drawOnset(plan, usage, onsets.draws[usage.tankId], pressureBar);
      if (remaining <= 0) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.gasOut,
            severity: PlanIssueSeverity.critical,
            message: 'Tank runs out of gas',
            atRuntime: drawOnset(0),
            tankId: usage.tankId,
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
            atRuntime: drawOnset(config.reservePressure),
            tankId: usage.tankId,
            value: remaining,
            threshold: config.reservePressure,
          ),
        );
      }
      final minGas = usage.minGasBar;
      final start = usage.startPressure;
      // A fill at or under rock bottom always ends under it too, so the
      // no-usable-gas alert stands in for the ends-below-minimum one.
      if (minGas != null && start != null && minGas >= start) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.noUsableGas,
            severity: PlanIssueSeverity.alert,
            message:
                'Rock-bottom minimum of ${minGas.toStringAsFixed(0)} bar '
                'leaves no usable gas in a '
                '${start.toStringAsFixed(0)} bar fill',
            // No single moment: the fill is short before the dive starts.
            segmentId: usage.tankId,
            tankId: usage.tankId,
            value: minGas,
            threshold: start,
          ),
        );
      } else if (minGas != null && remaining > 0 && remaining < minGas) {
        issues.add(
          PlanIssue(
            type: PlanIssueType.minGasViolation,
            severity: PlanIssueSeverity.alert,
            message:
                'Tank ends below the rock-bottom minimum of '
                '${minGas.toStringAsFixed(0)} bar',
            atRuntime: drawOnset(minGas),
            tankId: usage.tankId,
            value: remaining,
            threshold: minGas,
          ),
        );
      }
    }

    final ascentHypoxia = _loopAscentHypoxia(
      ascentPlan,
      stops,
      legs.isEmpty ? 0.0 : legs.last.endDepth,
    );
    // The surface is usually already reported: the descent left it on the same
    // supply.
    if (ascentHypoxia != null &&
        !issues.any(
          (i) =>
              i.type == PlanIssueType.hypoxicGas &&
              i.atDepth == ascentHypoxia.atDepth,
        )) {
      issues.add(ascentHypoxia);
    }

    final inDeco = segmentOutcomes.any((s) => s.inDeco);
    // A loop deco dive stays on the loop, so what it must carry is a way off
    // it, not a richer gas to switch to. That holds for a loop plan whose
    // final leg is open circuit too: its tanks only ever resolve to bailout,
    // so a deco gas is an alert it could never clear.
    final isLoop =
        plan.mode != domain.PlanMode.oc || ascentPlan is LoopAscentGas;
    if (inDeco && !isLoop && !_hasDecoGas(plan)) {
      issues.add(
        const PlanIssue(
          type: PlanIssueType.ndlExceededNoDecoGas,
          severity: PlanIssueSeverity.alert,
          message:
              'Plan incurs decompression with no dedicated deco gas carried',
        ),
      );
    }
    // Any cylinder is a way off the loop unless it feeds it. TankRole.bailout
    // alone cannot answer that: on a semi-closed plan a supply the diver never
    // marked as diluent resolves to it, and an open-circuit plan ending on the
    // loop has no such role at all.
    final loopTankIds = {
      for (final leg in legs)
        if (_modeFor(plan, leg.segment) != domain.PlanMode.oc) leg.tankId,
    };
    final carriesBailout = plan.tanks.any(
      (t) =>
          !loopTankIds.contains(t.id) &&
          t.role != TankRole.diluent &&
          t.role != TankRole.oxygenSupply,
    );
    if (inDeco && isLoop && !carriesBailout) {
      issues.add(
        const PlanIssue(
          type: PlanIssueType.noBailoutCarried,
          severity: PlanIssueSeverity.alert,
          message: 'Decompression plan carries no bailout gas',
        ),
      );
    }
    final bailoutGasIssue = _bailoutGasIssue(plan, legs, environment);
    if (bailoutGasIssue != null) issues.add(bailoutGasIssue);

    issues.addAll(_modOverrideIssues(plan.tanks, environment, onsets.schedule));
    issues.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    return issues;
  }

  /// The loop can die anywhere, and carrying a bailout gas does not help
  /// where it may not be breathed (#3961), so this does not wait for deco as
  /// [PlanIssueType.noBailoutCarried] does: a no-stop dive needs a gas to
  /// leave on too. Eligibility runs from a gas's MOD to the surface, so
  /// [legs]' deepest point answers for every other failure depth.
  PlanIssue? _bailoutGasIssue(
    domain.DivePlan plan,
    List<ResolvedLeg> legs,
    DiveEnvironment environment,
  ) {
    if (plan.mode == domain.PlanMode.oc) return null;
    final bailoutTanks = plan.tanks
        .where((t) => t.role == TankRole.bailout)
        .toList();
    if (bailoutTanks.isEmpty) return null;
    final gases = config.bailoutAscentGas(bailoutTanks, environment);
    final deepest = legs.fold(0.0, (d, leg) => math.max(d, leg.deeperEnd));
    if (gases.coversDepth(deepest)) return null;
    return PlanIssue(
      type: PlanIssueType.noEligibleBailoutGas,
      severity: PlanIssueSeverity.alert,
      message:
          'No bailout gas reaches ${deepest.toStringAsFixed(1)} m: the '
          'deepest MOD carried is ${gases.deepestMod.toStringAsFixed(1)} m',
      atDepth: deepest,
      value: deepest,
      threshold: gases.deepestMod,
    );
  }

  /// The runtime at which [usage]'s cylinder first drops to [pressureBar],
  /// from its [draws]; null when the cylinder has no size or start pressure
  /// to measure from (#3738).
  int? _drawOnset(
    domain.DivePlan plan,
    PlanTankUsage usage,
    List<RuntimeIncrement>? draws,
    double pressureBar,
  ) {
    final total = usage.totalLiters;
    final tank = plan.tanks.where((t) => t.id == usage.tankId).firstOrNull;
    if (total == null || tank == null || draws == null) return null;
    final left = gasVolume(
      tankSizeLiters: tank.volume ?? 11.0,
      pressureBar: pressureBar,
      o2Percent: tank.gasMix.o2,
      hePercent: tank.gasMix.he,
      model: config.gasModel,
    );
    return runtimeReaching(draws, threshold: total - left);
  }

  /// Inspired ppO2 below this is not breathable.
  static const double _hypoxicPpO2 = 0.16;

  /// The deepest point a computed ascent on the loop stops being breathable,
  /// or null (issue #3896). The legs' own check cannot see this: a loop's ppO2
  /// drops as the diver shallows, so a final supply that is safe where it was
  /// authored can be hypoxic at the stops, on a gas the descent never breathed.
  /// Stops are in ascent order and ppO2 only falls on the way up, so the first
  /// hypoxic one is the deepest.
  PlanIssue? _loopAscentHypoxia(
    AscentGasPlan ascentPlan,
    List<PlanStop> stops,
    double lastDepth,
  ) {
    if (ascentPlan is! LoopAscentGas || lastDepth <= 0) return null;
    PlanIssue? issueAt(double depth, {int? runtime}) {
      final ppO2 = ascentPlan.inspiredPpO2At(depth);
      if (ppO2 >= _hypoxicPpO2) return null;
      return PlanIssue(
        type: PlanIssueType.hypoxicGas,
        severity: PlanIssueSeverity.critical,
        message:
            'Gas is hypoxic at ${depth.toStringAsFixed(0)} m '
            '(ppO2 ${ppO2.toStringAsFixed(2)} bar)',
        atRuntime: runtime,
        atDepth: depth,
        value: ppO2,
        threshold: _hypoxicPpO2,
      );
    }

    for (final stop in stops) {
      final issue = issueAt(
        stop.depthMeters,
        runtime: stop.arrivalRuntimeSeconds,
      );
      if (issue != null) return issue;
    }
    return issueAt(0);
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

  /// The semi-closed loop a computed ascent stays on, or null when the dive
  /// does not end on one (issue #3896).
  ///
  /// The final leg's mode decides, so a final leg the diver took off the loop
  /// on purpose keeps its open-circuit ascent, while the loop itself is built
  /// from that leg's own supply gas. Without a breathing-mode change the diver
  /// has no reason to leave the loop for the richer gas feeding it, nor for
  /// bailout gas carried in case the loop fails.
  SemiClosedLoopAscentGas? _semiClosedLoopFor(
    domain.DivePlan plan,
    PlanSegment? finalSegment,
    DiveEnvironment environment,
  ) {
    if (finalSegment == null) return null;
    final breathing = _breathingFor(
      plan,
      finalSegment.gasMix,
      0,
      segment: finalSegment,
    );
    return breathing is SemiClosedBreathing
        ? SemiClosedLoopAscentGas(
            environment: environment,
            breathing: breathing,
          )
        : null;
  }

  /// The semi-closed loop [compute] keeps an SCR plan on through its ascent
  /// (issue #3896), for the Dive Lab's synthesized remainder; null when the
  /// plan's final leg is not breathed on a semi-closed loop.
  AscentGasPlan? scrAscentPlanFor(domain.DivePlan plan) {
    final segments = List<PlanSegment>.from(plan.segments)
      ..sort((a, b) => a.order.compareTo(b.order));
    return PlanEngine(config: config.resolvedFor(plan))._semiClosedLoopFor(
      plan,
      segments.isEmpty ? null : segments.last,
      environmentFor(plan),
    );
  }

  /// The schedule policy [compute] derives for [plan], for code that
  /// retraces its schedule: the Dive Lab times its synthesized ascent with
  /// the same legs the engine scheduled. Resolves [config] against the plan
  /// first, as [compute] does, so a plan's own rates win and an unset one
  /// falls back to the diver's Settings.
  SchedulePolicy schedulePolicyFor(domain.DivePlan plan) =>
      PlanEngine(config: config.resolvedFor(plan))._policyFor(plan);

  /// The open-circuit ascent gas plan [compute] builds for [plan], with its
  /// config resolved, its cylinder roles resolved and its water applied, so
  /// the Dive Lab synthesizes the same gas switches the engine schedules.
  AscentGasPlan ocAscentPlanFor(domain.DivePlan plan) {
    final resolved = const TankRoleResolver().apply(plan);
    return PlanEngine(
      config: config.resolvedFor(plan),
    )._ascentPlanFor(resolved.tanks, environmentFor(resolved));
  }

  /// Each gas joins the ascent at its cylinder's MOD (issue #3567): the one
  /// the diver set, or the switch depth for its role's limit at this plan's
  /// limits, measured in [environment], the water the schedule's ppO2 is
  /// computed in (issue #3566, see [gasSwitchDepthMeters]).
  /// [tanks] carry resolved roles: [compute] applies TankRoleResolver first.
  AscentGasPlan _ascentPlanFor(
    List<DiveTank> tanks,
    DiveEnvironment environment,
  ) {
    if (tanks.isEmpty) {
      return FixedAscentGas(fN2: 0.7902);
    }
    return OptimalOcAscentGas(
      maxPpO2: config.ppO2Deco,
      gases: ascentGasesFor(
        tanks,
        bottomPpO2: config.ppO2Working,
        decoPpO2: config.decoLimits,
        environment: environment,
        diluentPpO2: config.ccrDiluentModPpO2,
      ),
    );
  }

  /// A MOD set by hand deeper than its cylinder's limit allows is the
  /// diver's call, and the plan uses it, but it is reported (issue #3567):
  /// critical above the deco limit, a warning above the bottom limit. The
  /// ppO2 is measured in [environment], as the schedule's is, so the issue
  /// agrees with the table line the gas is breathed on.
  List<PlanIssue> _modOverrideIssues(
    List<DiveTank> tanks,
    DiveEnvironment environment,
    List<PlanScheduleRow> schedule,
  ) {
    final issues = <PlanIssue>[];
    final decoLimits = config.decoLimits;
    for (final tank in tanks) {
      final check = modOverrideCheck(
        tank,
        bottomPpO2: config.ppO2Working,
        decoPpO2: decoLimits,
        diluentPpO2: config.ccrDiluentModPpO2,
        environment: environment,
      );
      if (check == null || !check.exceedsLimit) continue;
      // Critical when the override's ppO2 breaches the deco ceiling for a
      // gas of this O2% (issue #3580: per-band, or the ppO2 at the
      // explicit depth for a gas under that setting, not always the flat
      // ppO2Deco) -- even for a bottom-role tank, which can still breach
      // it on a sufficiently deep hand-set MOD. A bottom-role tank under
      // that ceiling is a warning (it already exceeded its own, lower,
      // bottom limit to get here at all). decoCeilingBreachedFor, not
      // check.limitPpO2: that is whatever limit THIS tank's own role
      // calls for (bottom or deco), not necessarily the deco ceiling. It is
      // the check an authored leg gets, so the same ppO2 is classified the
      // same way wherever it comes from (issue #3913).
      final isCritical = decoCeilingBreachedFor(
        tank.gasMix,
        decoLimits,
        depthMeters: tank.decoSwitchDepth!,
        actualPpO2: check.ppO2,
        environment: environment,
      );
      issues.add(
        PlanIssue(
          type: isCritical
              ? PlanIssueType.ppO2Critical
              : PlanIssueType.ppO2High,
          severity: isCritical
              ? PlanIssueSeverity.critical
              : PlanIssueSeverity.warning,
          message:
              'ppO2 ${check.ppO2.toStringAsFixed(2)} bar at the MOD set on '
              '${tank.name ?? tank.gasMix.name} exceeds its limit',
          // Where the diver first breathes it (#3738).
          atRuntime: schedule
              .where((row) => row.tankId == tank.id)
              .firstOrNull
              ?.startRuntimeSeconds,
          atDepth: tank.decoSwitchDepth,
          value: check.ppO2,
          threshold: check.limitPpO2,
        ),
      );
    }
    return issues;
  }

  List<PlanStop> _mapStops(
    DecoSchedule schedule,
    domain.DivePlan plan,
    AscentGasPlan ascentPlan,
    double fromDepth,
    int segmentsRuntime,
    String? loopSupplyTankId,
  ) {
    final stops = <PlanStop>[];
    final policy = _policyFor(plan);
    final isCcr = plan.mode == domain.PlanMode.ccr;
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
      // A loop's TRUE gas identity is always its diluent or supply gas.
      // LoopAscentGas.gasForDepth() instead returns a continuously drifting
      // pAlv-normalized fraction for the deco engine's own bookkeeping: using
      // that here fabricated an invented mix on every line even on a
      // single-diluent dive (a diver saw this directly: Tx 10/70 shown as
      // Tx 12/68, Tx 24/59, ... Tx 87/10). The valve feeds the same gas
      // regardless of depth: even once ambient pressure can no longer support
      // the setpoint and PO2 falls short of it, the loop is not somehow
      // switched onto a different cylinder; a diver confirmed this directly
      // after an earlier version showed "O2" at the shallowest stops, which
      // does not happen.
      final onLoop = ascentPlan is LoopAscentGas;
      final fO2 = onLoop ? ascentPlan.supplyFO2 : 1.0 - gas.fN2 - gas.fHe;
      final fHe = onLoop ? ascentPlan.supplyFHe : gas.fHe;
      final tankId =
          loopSupplyTankId ?? _tankForGas(plan.tanks, fO2, fHe, isCcr: isCcr);
      stops.add(
        PlanStop(
          depthMeters: stop.depthMeters,
          durationSeconds: stop.durationSeconds,
          airBreakSeconds: stop.airBreakSeconds,
          gasFO2: fO2,
          gasFHe: fHe,
          tankId: tankId,
          airBreakTankId: airBreakTankIdFor(
            stop,
            plan: ascentPlan,
            stopTankId: tankId,
            tankForGas: (breakFO2, breakFHe) =>
                _tankForGas(plan.tanks, breakFO2, breakFHe, isCcr: isCcr),
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
    String? loopSupplyTankId,
  ) {
    final rows = <PlanScheduleRow>[];
    final isCcr = plan.mode == domain.PlanMode.ccr;
    double? previousFO2;
    double? previousFHe;

    // The loop's real inspired ppO2 at a depth: on CCR always the setpoint
    // (clamped to alveolar pressure where the diluent can no longer dilute
    // enough), never ambient x a stored gas fraction. gasFO2/gasFHe on a
    // computed-ascent row are normalized against alveolar pressure
    // (LoopAscentGas: fN2 = pN2 / pAlv, and so on), not against raw
    // ambient pressure -- multiplying that fraction back by ambient
    // overstates ppO2 by a margin that *grows* as depth shrinks (ambient
    // and pAlv differ by a fixed ~0.063 bar water-vapour term, which is a
    // bigger fraction of a small ambient than a large one). A diver saw
    // this directly: PO2 drifting from 1.30 at depth up to 1.35 near the
    // surface on a dive with one constant 1.3 bar high setpoint. Asking the
    // loop model directly for the inspired pO2 is exact at every depth.
    double? loopPpO2At(double atDepth) {
      if (ascentPlan is! LoopAscentGas) return null;
      return ascentPlan.inspiredPpO2At(atDepth);
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
      String? airBreakTankId,
      // Set whenever the row's gas is a loop's, through loopPpO2At, rather
      // than ambient x fO2: the real inspired ppO2
      // (the CCR setpoint, clamped once the diluent can no longer dilute
      // enough, or a semi-closed loop's depleted mix), which ambient x fO2
      // does not reproduce for a loop mode: fO2 there is the carried gas's
      // own fraction, not the loop's, so it is never "ambient x fO2 = real
      // ppO2". Every OC row keeps the ambient x fO2 fallback, which is
      // correct for a real tank mix.
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
          airBreakTankId: airBreakTankId,
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
      if (ascentPlan is LoopAscentGas) {
        // The loop's displayed gas never changes mid-ascent (it stays on
        // the last segment's diluent or supply gas down to the surface), so
        // there is nothing to split here.
        add(
          kind: PlanScheduleRowKind.ascent,
          depth: to,
          duration: duration,
          runtime: arrival,
          fO2: ascentPlan.supplyFO2,
          fHe: ascentPlan.supplyFHe,
          tankId:
              loopSupplyTankId ??
              _tankForGas(
                plan.tanks,
                ascentPlan.supplyFO2,
                ascentPlan.supplyFHe,
                isCcr: isCcr,
              ),
          physicsDepth: from,
          ppO2Override: loopPpO2At(from),
        );
        return;
      }
      // OC: split at every gas-switch depth crossed, so each sub-leg prints
      // -- and is later charged in _computeTankUsages' matching split --
      // the gas actually eligible there, not only the one valid at the
      // deepest point (#3225). Between stops the table folds its travel into
      // the stop instead, so this only divides the long leg to the first
      // stop, or to the surface on an ascent with no stops.
      var legArrival = arrival - duration;
      for (final span in splitAscentLeg(
        ascentPlan,
        fromDepth: from,
        toDepth: to,
        seconds: duration,
      )) {
        legArrival += span.seconds;
        final gas = ascentPlan.gasForDepth(span.fromDepth);
        add(
          kind: PlanScheduleRowKind.ascent,
          depth: span.toDepth,
          duration: span.seconds,
          runtime: legArrival,
          fO2: gas.fO2,
          fHe: gas.fHe,
          tankId: _tankForGas(plan.tanks, gas.fO2, gas.fHe, isCcr: isCcr),
          physicsDepth: span.fromDepth,
        );
      }
    }

    var depth = lastDepth;
    var end = segmentsRuntime;
    var phase = AscentPhase.toFirstStop;
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final travel = stop.arrivalRuntimeSeconds - end;
      // The first travel leg (bottom phase to the first stop) stays its own
      // row, an informative transition. From the second stop on, a gas
      // switch at its MOD lands exactly at the stop it leads into
      // (AscentGasPlan's design: a switch-at-MOD never falls strictly
      // between two 3 m-spaced stops), so a travel-between-stops row would
      // nearly always repeat the previous line's gas, which is clutter, not
      // information. A switch depth the diver set can fall inside the leg:
      // the line stays folded, and _computeTankUsages and the exposure
      // spans still split it. Dropping it loses nothing: scheduleLines()
      // already derives each printed duration from consecutive runtimeSeconds, so
      // the travel time folds straight into the stop it leads to (#3138).
      if (i == 0 && travel > 0) {
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
        airBreakTankId: stop.airBreakTankId,
        ppO2Override: loopPpO2At(stop.depthMeters),
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
  /// bailout cylinder holding the diluent's mix could take the loop's stops,
  /// making the table name a cylinder the diver never breathed (#3131).
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

/// Tank consumption plus each cylinder's draws, the draws
/// placing its reserve and minimum gas in time (#3738).
typedef _TankUsageResult = ({
  List<PlanTankUsage> usages,
  Map<String, List<RuntimeIncrement>> draws,
});

/// What [PlanEngine._computeIssues] needs to place each issue in the dive
/// (#3738): the O2 exposure and gas draws stretch by stretch, and the
/// schedule a gas is first breathed on.
typedef _IssueOnsets = ({
  List<RuntimeIncrement> cnsSteps,
  List<RuntimeIncrement> otuSteps,
  Map<String, List<RuntimeIncrement>> draws,
  List<PlanScheduleRow> schedule,
});

/// The point on an authored leg where the diver was furthest above the deco
/// ceiling, found by the ceiling replay (#3354).
typedef _CeilingBreach = ({
  String segmentId,
  int runtimeSeconds,
  double depthMeters,
  double ceilingMeters,
});
