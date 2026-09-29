import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';

domain.DivePlan _plan({DpvMission? mission}) => domain.DivePlan(
  id: 'plan-1',
  name: 'State mission',
  gfLow: 40,
  gfHigh: 80,
  mission: mission,
  createdAt: DateTime(2026, 9, 19),
  updatedAt: DateTime(2026, 9, 19),
);

void main() {
  const mission = DpvMission(batteryReserveFraction: 0.5);

  test('the mission travels from the plan into the state and back', () {
    final state = stateFromDivePlan(_plan(mission: mission));
    expect(state.mission, mission);
    expect(divePlanFromState(state).mission, mission);
  });

  test('a state without a mission clears it from the existing plan', () {
    final existing = _plan(mission: mission);
    final state = stateFromDivePlan(existing).copyWith(clearMission: true);
    expect(state.mission, isNull);
    expect(divePlanFromState(state, existing: existing).mission, isNull);
  });

  test('the mission takes part in state equality', () {
    final a = stateFromDivePlan(_plan());
    expect(a.copyWith(mission: mission), isNot(a));
    expect(a.copyWith(mission: mission).copyWith(clearMission: true), a);
  });
}
