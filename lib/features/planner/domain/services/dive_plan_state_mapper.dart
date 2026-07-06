import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
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
    reservePressure: state.reservePressure,
    surfaceInterval: state.surfaceInterval,
    clearSurfaceInterval: state.surfaceInterval == null,
    segments: state.segments,
    tanks: state.tanks,
    createdAt: state.createdAt,
    updatedAt: state.updatedAt,
  );
}

/// Restores the legacy planner state from a persisted plan.
DivePlanState stateFromDivePlan(domain.DivePlan plan) {
  return DivePlanState(
    id: plan.id,
    name: plan.name,
    notes: plan.notes,
    siteId: plan.siteId,
    altitude: plan.altitude,
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
    reservePressure: plan.reservePressure,
    surfaceInterval: plan.surfaceInterval,
    segments: plan.segments,
    tanks: plan.tanks,
    isDirty: false,
    createdAt: plan.createdAt,
    updatedAt: plan.updatedAt,
  );
}
