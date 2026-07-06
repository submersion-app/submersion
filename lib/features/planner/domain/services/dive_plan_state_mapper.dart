import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

/// Maps between the legacy planner UI state ([DivePlanState]) and the
/// persisted [domain.DivePlan] aggregate.
///
/// The legacy state carries a subset of the aggregate; [existing] preserves
/// fields the state does not know about (mode, rates, CCR/contingency
/// config, water type, dive links) across an edit-save cycle so a plan
/// touched by the old UI does not lose them.
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
