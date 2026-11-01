import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_engine.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _sac = 15.0;

// Cruise and swim speed match, and there is one member, so the swim exit from
// the turn is the planned return and team rates do not enter into it.
const _mission = DpvMission(
  legs: [
    MissionLeg(
      id: 'leg',
      order: 0,
      label: 'Turn',
      distanceM: 360,
      depthM: 40,
      headingDeg: 0,
    ),
  ],
  team: [
    MissionMember(
      id: 'diver',
      order: 0,
      displayName: 'Diver',
      sacBottom: _sac,
      swimSpeedMps: .2,
      scooter: ScooterSpec(
        name: 'DPV',
        ratedSpeedMps: .2,
        burnTimeSeconds: 20000,
      ),
    ),
  ],
);

domain.DivePlan _plan(List<DiveTank> tanks, {AirBreakPolicy? airBreaks}) =>
    domain.DivePlan(
      id: 'mission',
      name: 'Mission budget',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      gfLow: 30,
      gfHigh: 70,
      sacBottom: _sac,
      sacDeco: _sac,
      sacStressed: _sac,
      problemSolvingMinutes: 0,
      reservePressure: 50,
      airBreaks: airBreaks,
      tanks: tanks,
    );

void main() {
  const engine = PlanEngine(config: PlanEngineConfig(gasModel: GasModel.ideal));
  const missionEngine = MissionEngine(
    scenarios: MissionScenarioService(engine: engine),
  );

  const back = DiveTank(
    id: 'back',
    gasMix: GasMix(o2: 21),
    volume: 40,
    startPressure: 230,
  );
  const ean50 = DiveTank(
    id: '50',
    gasMix: GasMix(o2: 50),
    volume: 7,
    startPressure: 210,
  );
  const oxygen = DiveTank(
    id: 'o2',
    gasMix: GasMix(o2: 100),
    volume: 7,
    startPressure: 200,
  );

  PlanOutcome expectBudgetMatchesEngine(domain.DivePlan plan) {
    final mission = missionEngine.compute(plan: plan, mission: _mission);
    final outcome = engine.compute(plan.copyWith(segments: mission.segments));

    // The table folds time away: without it this proves nothing.
    expect(
      outcome.schedule.fold<int>(0, (sum, r) => sum + r.durationSeconds),
      lessThan(outcome.runtimeSeconds),
    );

    final budget = const MemberGasService().litersByTank(
      rows: outcome.schedule,
      environment: PlanEngine.environmentFor(plan),
      sacFor: (_) => _sac,
    );
    for (final usage in outcome.tankUsages) {
      expect(
        budget[usage.tankId] ?? 0.0,
        closeTo(usage.litersUsed, 1e-6),
        reason: usage.tankId,
      );
    }
    return outcome;
  }

  group('mission gas budget over travel between stops (#3927)', () {
    test('matches the plan engine on every cylinder', () {
      expectBudgetMatchesEngine(_plan(const [back, ean50, oxygen]));
    });

    test('follows a switch the diver set between two stops', () {
      final outcome = expectBudgetMatchesEngine(
        _plan([back, ean50.copyWith(role: TankRole.deco, decoSwitchDepth: 10)]),
      );

      final legs = outcome.schedule.map((r) => r.foldedTravel);
      expect(legs.map((leg) => leg.length), contains(greaterThan(1)));
    });

    test('keeps its match with air breaks on the same stops (#3928)', () {
      final outcome = expectBudgetMatchesEngine(
        _plan(const [back, ean50, oxygen], airBreaks: const AirBreakPolicy()),
      );

      expect(
        outcome.schedule.map((r) => r.airBreakSeconds),
        contains(isNonZero),
      );
    });

    test('an exit ending below reserve is not survivable', () {
      final plan = _plan(const [back, ean50, oxygen]);

      final result = missionEngine.compute(plan: plan, mission: _mission);

      final waypoint = result.waypoints.single;
      final swim = waypoint.members.single.swim;
      expect(swim.gasShortfallMemberIds, {'diver'});
      expect(swim.feasible, isFalse);
      expect(waypoint.survivable, isFalse);
      expect(result.abandonmentIndex, isNull);
    });
  });
}
