import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

void main() {
  const gas = GasMix(o2: 21);
  const tank = DiveTank(
    id: 't1',
    volume: 11.1,
    startPressure: 200,
    gasMix: gas,
  );
  final segments = [
    PlanSegment.bottom(
      id: 's1',
      depth: 30.0,
      durationMinutes: 20,
      tankId: 't1',
      gasMix: gas,
    ),
  ];

  DivePlanState state() => DivePlanState(
    id: 'p1',
    name: 'Reef dive',
    notes: 'Easy one',
    segments: segments,
    tanks: [tank],
    gfLow: 45,
    gfHigh: 85,
    sacRate: 17.0,
    reservePressure: 60.0,
    altitude: 300.0,
    surfaceInterval: const Duration(hours: 1),
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 5),
  );

  test('state -> plan -> state round-trips the shared fields', () {
    final plan = divePlanFromState(state());
    expect(plan.name, 'Reef dive');
    expect(plan.sacBottom, 17.0);
    expect(plan.gfLow, 45);
    expect(plan.altitude, 300.0);
    expect(plan.surfaceInterval, const Duration(hours: 1));

    final restored = stateFromDivePlan(plan);
    expect(restored.name, state().name);
    expect(restored.sacRate, state().sacRate);
    expect(restored.gfHigh, state().gfHigh);
    expect(restored.segments, state().segments);
    expect(restored.tanks, state().tanks);
    expect(restored.isDirty, isFalse);
  });

  test('existing plan preserves fields the legacy state does not carry', () {
    final existing = domain.DivePlan(
      id: 'p1',
      name: 'Old name',
      gfLow: 30,
      gfHigh: 70,
      mode: domain.PlanMode.ccr,
      waterType: WaterType.fresh,
      descentRate: 20.0,
      airBreaks: const AirBreakPolicy(),
      setpointHigh: 1.3,
      turnPressureRule: domain.TurnPressureRule.thirds,
      sourceDiveId: 'dive-9',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );

    final merged = divePlanFromState(state(), existing: existing);
    // State-owned fields come from the state (mode/setpoints joined that
    // set in Phase 4, contingency config in Phase 5: the state defaults to
    // OC / null setpoints / no turn rule)...
    expect(merged.name, 'Reef dive');
    expect(merged.gfLow, 45);
    expect(merged.sacBottom, 17.0);
    expect(merged.mode, domain.PlanMode.oc);
    expect(merged.setpointHigh, isNull);
    expect(merged.turnPressureRule, isNull);
    // ...while aggregate-only fields survive the cycle.
    expect(merged.waterType, WaterType.fresh);
    expect(merged.descentRate, 20.0);
    expect(merged.airBreaks, isNotNull);
    expect(merged.sourceDiveId, 'dive-9');
  });

  test('mode and setpoints round-trip through the state', () {
    final ccrState = state().copyWith(
      mode: domain.PlanMode.ccr,
      setpointLow: 0.7,
      setpointHigh: 1.4,
      setpointSwitchDepth: 12.0,
    );
    final plan = divePlanFromState(ccrState);
    expect(plan.mode, domain.PlanMode.ccr);
    expect(plan.setpointHigh, 1.4);
    expect(plan.setpointSwitchDepth, 12.0);

    final restored = stateFromDivePlan(plan);
    expect(restored.mode, domain.PlanMode.ccr);
    expect(restored.setpointLow, 0.7);
    expect(restored.setpointHigh, 1.4);
    expect(restored.setpointSwitchDepth, 12.0);
  });

  test('null state fields clear stale values from the existing plan', () {
    final existing = domain.DivePlan(
      id: 'p1',
      name: 'Old',
      gfLow: 30,
      gfHigh: 70,
      altitude: 2000.0,
      siteId: 'site-1',
      surfaceInterval: const Duration(hours: 3),
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
    final cleared = state().copyWith(
      clearAltitude: true,
      clearSiteId: true,
      clearSurfaceInterval: true,
    );
    final merged = divePlanFromState(cleared, existing: existing);
    expect(merged.altitude, isNull);
    expect(merged.siteId, isNull);
    expect(merged.surfaceInterval, isNull);
  });

  test('contingency config round-trips through the state', () {
    final configured = state().copyWith(
      deviationDepthDelta: 6.0,
      deviationTimeMinutes: 10,
      turnPressureRule: domain.TurnPressureRule.halves,
      turnPressureFraction: 0.4,
    );
    final plan = divePlanFromState(configured);
    expect(plan.deviationDepthDelta, 6.0);
    expect(plan.deviationTimeMinutes, 10);
    expect(plan.turnPressureRule, domain.TurnPressureRule.halves);
    expect(plan.turnPressureFraction, 0.4);

    final restored = stateFromDivePlan(plan);
    expect(restored.deviationDepthDelta, 6.0);
    expect(restored.turnPressureRule, domain.TurnPressureRule.halves);
  });
}
