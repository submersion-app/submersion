import 'package:collection/collection.dart';

import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';

export 'package:submersion/features/planner/domain/entities/plan_setting_group.dart';

const _equality = DeepCollectionEquality();

/// The settings of [group] in [state], for comparing two dives.
List<Object?> _values(PlanSettingGroup group, DivePlanState state) =>
    switch (group) {
      PlanSettingGroup.deco => [
        state.gfLow,
        state.gfHigh,
        state.airBreaks,
        state.airBreaksExplicitlyOff,
      ],
      PlanSettingGroup.rates => [
        state.descentRate,
        state.ascentRate,
        state.intermediateAscentRate,
        state.shallowAscentRate,
        state.finalAscentRate,
        state.lastStopDepth,
      ],
      PlanSettingGroup.gas => [
        state.sacRate,
        state.sacDeco,
        state.sacStressed,
        state.sacFactor,
        state.reservePressure,
        state.problemSolvingMinutes,
        state.gasSwitchStopSeconds,
        state.ppO2Bottom,
        state.ppO2Deco,
        state.ppO2DecoBand1,
        state.ppO2DecoBand2,
        state.ppO2DecoBand3,
        state.ppO2DecoBandsExplicitlyOff,
        state.maxO2DepthMeters,
        state.maxO2DepthExplicitlyOff,
        state.hypercapniaAmv,
        state.hypercapniaMinutes,
        state.hypercapniaExplicitlyOff,
        state.bestMixEndMeters,
        state.o2Narcotic,
      ],
      PlanSettingGroup.environment => [
        state.altitude,
        state.waterType,
        state.salinityPpt,
      ],
      PlanSettingGroup.contingencies => [
        state.deviationDepthDelta,
        state.deviationTimeMinutes,
        state.turnPressureRule,
        state.turnPressureFraction,
      ],
    };

/// Whether [a] and [b] agree on every setting of [group].
bool sameGroup(PlanSettingGroup group, DivePlanState a, DivePlanState b) =>
    _equality.equals(_values(group, a), _values(group, b));

/// The groups whose settings differ between [before] and [after].
Set<PlanSettingGroup> changedGroups(
  DivePlanState before,
  DivePlanState after,
) => {
  for (final group in PlanSettingGroup.values)
    if (!sameGroup(group, before, after)) group,
};

/// [to] with the settings of [group] taken from [from], everything else as
/// it was. A value [from] leaves to the diver's default is cleared in [to]
/// too. [to] itself comes back when it already matches.
DivePlanState applyGroup(
  PlanSettingGroup group, {
  required DivePlanState from,
  required DivePlanState to,
}) {
  if (sameGroup(group, from, to)) return to;
  final changed = switch (group) {
    PlanSettingGroup.deco => to.copyWith(
      gfLow: from.gfLow,
      clearGfLow: from.gfLow == null,
      gfHigh: from.gfHigh,
      clearGfHigh: from.gfHigh == null,
      airBreaks: from.airBreaks,
      clearAirBreaks: from.airBreaks == null,
      airBreaksExplicitlyOff: from.airBreaksExplicitlyOff,
    ),
    PlanSettingGroup.rates => to.copyWith(
      descentRate: from.descentRate,
      clearDescentRate: from.descentRate == null,
      ascentRate: from.ascentRate,
      clearAscentRate: from.ascentRate == null,
      intermediateAscentRate: from.intermediateAscentRate,
      clearIntermediateAscentRate: from.intermediateAscentRate == null,
      shallowAscentRate: from.shallowAscentRate,
      clearShallowAscentRate: from.shallowAscentRate == null,
      finalAscentRate: from.finalAscentRate,
      clearFinalAscentRate: from.finalAscentRate == null,
      lastStopDepth: from.lastStopDepth,
      clearLastStopDepth: from.lastStopDepth == null,
    ),
    PlanSettingGroup.gas => to.copyWith(
      sacRate: from.sacRate,
      clearSacRate: from.sacRate == null,
      sacDeco: from.sacDeco,
      clearSacDeco: from.sacDeco == null,
      sacStressed: from.sacStressed,
      clearSacStressed: from.sacStressed == null,
      sacFactor: from.sacFactor,
      clearSacFactor: from.sacFactor == null,
      reservePressure: from.reservePressure,
      clearReservePressure: from.reservePressure == null,
      problemSolvingMinutes: from.problemSolvingMinutes,
      clearProblemSolvingMinutes: from.problemSolvingMinutes == null,
      gasSwitchStopSeconds: from.gasSwitchStopSeconds,
      clearGasSwitchStopSeconds: from.gasSwitchStopSeconds == null,
      ppO2Bottom: from.ppO2Bottom,
      clearPpO2Bottom: from.ppO2Bottom == null,
      ppO2Deco: from.ppO2Deco,
      clearPpO2Deco: from.ppO2Deco == null,
      ppO2DecoBand1: from.ppO2DecoBand1,
      clearPpO2DecoBand1: from.ppO2DecoBand1 == null,
      ppO2DecoBand2: from.ppO2DecoBand2,
      clearPpO2DecoBand2: from.ppO2DecoBand2 == null,
      ppO2DecoBand3: from.ppO2DecoBand3,
      clearPpO2DecoBand3: from.ppO2DecoBand3 == null,
      ppO2DecoBandsExplicitlyOff: from.ppO2DecoBandsExplicitlyOff,
      maxO2DepthMeters: from.maxO2DepthMeters,
      clearMaxO2DepthMeters: from.maxO2DepthMeters == null,
      maxO2DepthExplicitlyOff: from.maxO2DepthExplicitlyOff,
      hypercapniaAmv: from.hypercapniaAmv,
      clearHypercapniaAmv: from.hypercapniaAmv == null,
      hypercapniaMinutes: from.hypercapniaMinutes,
      clearHypercapniaMinutes: from.hypercapniaMinutes == null,
      hypercapniaExplicitlyOff: from.hypercapniaExplicitlyOff,
      bestMixEndMeters: from.bestMixEndMeters,
      clearBestMixEndMeters: from.bestMixEndMeters == null,
      o2Narcotic: from.o2Narcotic,
      clearO2Narcotic: from.o2Narcotic == null,
    ),
    PlanSettingGroup.environment => to.copyWith(
      altitude: from.altitude,
      clearAltitude: from.altitude == null,
      waterType: from.waterType,
      clearWaterType: from.waterType == null,
      salinityPpt: from.salinityPpt,
      clearSalinityPpt: from.salinityPpt == null,
    ),
    // The turn rule and its fraction clear together, so clear both before
    // taking the source's.
    PlanSettingGroup.contingencies =>
      to
          .copyWith(
            deviationDepthDelta: from.deviationDepthDelta,
            clearDeviationDepthDelta: from.deviationDepthDelta == null,
            deviationTimeMinutes: from.deviationTimeMinutes,
            clearDeviationTimeMinutes: from.deviationTimeMinutes == null,
            clearTurnPressureRule: true,
          )
          .copyWith(
            turnPressureRule: from.turnPressureRule,
            turnPressureFraction: from.turnPressureFraction,
          ),
  };
  return changed.copyWith(isDirty: true, updatedAt: DateTime.now());
}
