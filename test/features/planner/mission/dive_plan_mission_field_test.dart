import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Mission field',
  gfLow: 40,
  gfHigh: 80,
  createdAt: DateTime(2026, 9, 18),
  updatedAt: DateTime(2026, 9, 18),
);

void main() {
  test('a plan has no mission by default', () {
    expect(_plan().mission, isNull);
  });

  test('copyWith sets and clears the mission', () {
    const mission = DpvMission(batteryReserveFraction: 0.5);
    final withMission = _plan().copyWith(mission: mission);
    expect(withMission.mission, mission);
    expect(withMission.copyWith(name: 'renamed').mission, mission);
    expect(withMission.copyWith(clearMission: true).mission, isNull);
  });

  test('the mission takes part in equality', () {
    const mission = DpvMission(batteryReserveFraction: 0.5);
    expect(_plan().copyWith(mission: mission), isNot(_plan()));
    expect(
      _plan().copyWith(mission: mission),
      _plan().copyWith(mission: mission),
    );
  });
}
