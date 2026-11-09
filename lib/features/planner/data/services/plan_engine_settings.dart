import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show AppSettings, plannerAirBreakPolicyOf;

/// The [PlanEngineConfig] a diver's [settings] give: the planner's deco,
/// gas and rate settings, without the plan's own overrides, which
/// [PlanEngineConfig.resolvedFor] applies.
///
/// The planner reads the active diver's through `planEngineConfigProvider`;
/// anything planning for another diver, such as an agent naming one, reads
/// that diver's settings and calls this, so both resolve them the same way.
PlanEngineConfig planEngineConfigFromSettings(AppSettings settings) {
  return PlanEngineConfig(
    ppO2Working: settings.ppO2MaxWorking,
    ppO2Deco: settings.ppO2MaxDeco,
    ppO2DecoBandsEnabled: settings.ppO2DecoBandsEnabled,
    ppO2DecoBand1: settings.ppO2DecoBand1,
    ppO2DecoBand2: settings.ppO2DecoBand2,
    ppO2DecoBand3: settings.ppO2DecoBand3,
    maxO2DepthEnabled: settings.maxO2DepthEnabled,
    maxO2DepthMeters: settings.maxO2DepthMeters,
    hypercapniaEnabled: settings.plannerHypercapniaEnabled,
    hypercapniaFactor: settings.plannerHypercapniaFactor,
    hypercapniaMinutes: settings.plannerHypercapniaMinutes,
    ccrDiluentModPpO2: settings.ccrDiluentModPpO2,
    ccrSetpointLow: settings.ccrSetpointLow,
    ccrSetpointHigh: settings.ccrSetpointHigh,
    cnsWarningThreshold: settings.cnsWarningThreshold,
    o2Narcotic: settings.o2Narcotic,
    endLimitMeters: settings.endLimit,
    pscrRatio: settings.pscrRatio,
    cnsMethod: settings.cnsCalculationMethod,
    gasModel: settings.gasModel,
    descentRate: settings.plannerDescentRate,
    ascentRate: settings.plannerAscentRate,
    intermediateAscentRate: settings.plannerIntermediateAscentRate,
    shallowAscentRate: settings.plannerShallowAscentRate,
    finalAscentRate: settings.plannerFinalAscentRate,
    lastStopDepth: settings.lastStopDepth,
    gasSwitchStopSeconds: settings.plannerGasSwitchStopSeconds,
    sacBottom: settings.plannerSacBottom,
    sacDeco: settings.plannerSacDeco,
    sacStressedFactor: settings.plannerSacStressedFactor,
    problemSolvingMinutes: settings.plannerProblemSolvingMinutes,
    buddyFactor: settings.plannerBuddyFactor,
    bestMixEndMeters: settings.plannerBestMixEndMeters,
    deviationDepthDelta: settings.plannerDeviationDepthDelta,
    deviationTimeMinutes: settings.plannerDeviationTimeMinutes,
    turnPressureRule: settings.plannerTurnPressureRule,
    turnPressureFraction: settings.plannerTurnPressureFraction,
    airBreakPolicy: plannerAirBreakPolicyOf(settings),
    gfLow: settings.gfLow,
    gfHigh: settings.gfHigh,
    reservePressure: settings.plannerReservePressure,
    batteryReserveFraction: settings.plannerBatteryReserveFraction,
    walkSpeedMps: settings.plannerWalkSpeedMps,
  );
}
