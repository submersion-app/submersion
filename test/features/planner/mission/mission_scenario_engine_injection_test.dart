import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_scenario_service.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Counts the plans it is asked to compute, so a test can prove that the
/// engine a caller injects (carrying the diver's ppO2, END and gas-model
/// settings) is the one every exit scenario actually runs on.
class _CountingEngine extends PlanEngine {
  _CountingEngine();

  int calls = 0;

  @override
  PlanOutcome compute(domain.DivePlan inputPlan, {TissueState? startState}) {
    calls++;
    return super.compute(inputPlan, startState: startState);
  }
}

const _air = GasMix(o2: 21);

domain.DivePlan _plan() => domain.DivePlan(
  id: 'plan-1',
  name: 'Injection',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [
    DiveTank(
      id: 'back',
      volume: 40,
      startPressure: 230,
      gasMix: _air,
      role: TankRole.backGas,
    ),
  ],
  createdAt: DateTime(2026, 9, 25),
  updatedAt: DateTime(2026, 9, 25),
);

MissionMember _member(String id, int order) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  scooter: ScooterSpec(
    name: 'S-$id',
    ratedSpeedMps: 0.5,
    burnTimeSeconds: 7200,
  ),
);

DpvMission _mission(MissionEnvironment environment) => DpvMission(
  legs: const [
    MissionLeg(
      id: 'L1',
      order: 0,
      label: 'T',
      distanceM: 200,
      depthM: 20,
      headingDeg: 0,
    ),
  ],
  team: [_member('a', 0), _member('b', 1)],
  environment: environment,
);

void main() {
  test('a swim or tow exit runs on the injected engine', () {
    final engine = _CountingEngine();
    MissionScenarioService(engine: engine).evaluate(
      plan: _plan(),
      mission: _mission(MissionEnvironment.overhead),
      waypointIndex: 0,
      failedMemberId: 'b',
      mode: MissionExitMode.swim,
    );
    expect(engine.calls, greaterThan(0));
  });

  test('the surface exit runs on the injected engine', () {
    final engine = _CountingEngine();
    MissionScenarioService(engine: engine).evaluateSurface(
      plan: _plan(),
      mission: _mission(MissionEnvironment.openWater),
      waypointIndex: 0,
    );
    expect(engine.calls, greaterThan(0));
  });

  test('the overhead safe-surface time runs on the injected engine', () {
    final engine = _CountingEngine();
    MissionScenarioService(engine: engine).overheadSafeSurfaceSeconds(
      plan: _plan(),
      mission: _mission(MissionEnvironment.overhead),
      waypointIndex: 0,
    );
    expect(engine.calls, greaterThan(0));
  });
}
