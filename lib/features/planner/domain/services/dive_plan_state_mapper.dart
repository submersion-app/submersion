import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

/// Maps between the planner UI state ([DivePlanState]) and the persisted
/// [domain.DivePlan] aggregate.
///
/// The UI state carries a subset of the aggregate; [existing] preserves
/// fields the state does not know about (rates, water type, air breaks)
/// across an edit-save cycle so a plan touched by the UI does not lose
/// them. Mode, setpoints, contingency config, and dive links travel WITH
/// the state.
domain.DivePlan divePlanFromState(
  DivePlanState state, {
  domain.DivePlan? existing,
}) {
  final base =
      existing ??
      domain.DivePlan(
        id: state.id,
        name: state.name,
        gfLow: state.gfLow,
        gfHigh: state.gfHigh,
        createdAt: state.createdAt,
        updatedAt: state.updatedAt,
      );
  return base.copyWith(
    id: state.id,
    name: state.name,
    notes: state.notes,
    siteId: state.siteId,
    clearSiteId: state.siteId == null,
    altitude: state.altitude,
    clearAltitude: state.altitude == null,
    startDateTime: state.startDateTime,
    clearStartDateTime: state.startDateTime == null,
    mode: state.mode,
    setpointLow: state.setpointLow,
    clearSetpointLow: state.setpointLow == null,
    setpointHigh: state.setpointHigh,
    clearSetpointHigh: state.setpointHigh == null,
    setpointSwitchDepth: state.setpointSwitchDepth,
    clearSetpointSwitchDepth: state.setpointSwitchDepth == null,
    deviationDepthDelta: state.deviationDepthDelta,
    deviationTimeMinutes: state.deviationTimeMinutes,
    turnPressureRule: state.turnPressureRule,
    clearTurnPressureRule: state.turnPressureRule == null,
    turnPressureFraction: state.turnPressureFraction,
    clearTurnPressureFraction: state.turnPressureFraction == null,
    sourceDiveId: state.sourceDiveId,
    clearSourceDiveId: state.sourceDiveId == null,
    linkedDiveId: state.linkedDiveId,
    clearLinkedDiveId: state.linkedDiveId == null,
    gfLow: state.gfLow,
    gfHigh: state.gfHigh,
    sacBottom: state.sacRate,
    ascentRate: state.ascentRate,
    intermediateAscentRate: state.intermediateAscentRate,
    shallowAscentRate: state.shallowAscentRate,
    finalAscentRate: state.finalAscentRate,
    lastStopDepth: state.lastStopDepth,
    descentRate: state.descentRate,
    reservePressure: state.reservePressure,
    surfaceInterval: state.surfaceInterval,
    clearSurfaceInterval: state.surfaceInterval == null,
    segments: state.segments,
    tanks: state.tanks,
    equipmentIds: state.equipmentIds,
    plannedWeightKg: state.plannedWeightKg,
    plannedWeightPlacement: state.plannedWeightPlacement,
    clearPlannedWeight: state.plannedWeightKg == null,
    createdAt: state.createdAt,
    updatedAt: state.updatedAt,
  );
}

/// Restores the legacy planner state from a persisted plan.
///
/// Segments are sorted by `order` on the way in. The state's list order is
/// the planner's working order - the segment list renders it, the reorder
/// handler indexes into it, and `SegmentChain` chains it - so a plan whose
/// list arrives out of sequence (a `.subplan` file carries its own `order`
/// values alongside the array) would otherwise show and edit a different
/// profile from the one the engine computes, which sorts.
DivePlanState stateFromDivePlan(domain.DivePlan plan) {
  final segments = List<PlanSegment>.from(plan.segments)
    ..sort((a, b) => a.order.compareTo(b.order));
  return DivePlanState(
    id: plan.id,
    name: plan.name,
    notes: plan.notes,
    siteId: plan.siteId,
    altitude: plan.altitude,
    startDateTime: plan.startDateTime,
    mode: plan.mode,
    setpointLow: plan.setpointLow,
    setpointHigh: plan.setpointHigh,
    setpointSwitchDepth: plan.setpointSwitchDepth,
    deviationDepthDelta: plan.deviationDepthDelta,
    deviationTimeMinutes: plan.deviationTimeMinutes,
    turnPressureRule: plan.turnPressureRule,
    turnPressureFraction: plan.turnPressureFraction,
    sourceDiveId: plan.sourceDiveId,
    linkedDiveId: plan.linkedDiveId,
    gfLow: plan.gfLow,
    gfHigh: plan.gfHigh,
    sacRate: plan.sacBottom,
    ascentRate: plan.ascentRate,
    intermediateAscentRate: plan.intermediateAscentRate,
    shallowAscentRate: plan.shallowAscentRate,
    finalAscentRate: plan.finalAscentRate,
    lastStopDepth: plan.lastStopDepth,
    descentRate: plan.descentRate,
    reservePressure: plan.reservePressure,
    surfaceInterval: plan.surfaceInterval,
    segments: segments,
    tanks: plan.tanks,
    equipmentIds: plan.equipmentIds,
    plannedWeightKg: plan.plannedWeightKg,
    plannedWeightPlacement: plan.plannedWeightPlacement,
    isDirty: false,
    createdAt: plan.createdAt,
    updatedAt: plan.updatedAt,
  );
}
