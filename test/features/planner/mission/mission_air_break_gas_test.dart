import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
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

const _engine = PlanEngine(config: PlanEngineConfig(gasModel: GasModel.ideal));

/// One 360 m leg at 40 m at 0.2 m/s: 30 minutes out and 30 back, on a scooter
/// that outlasts the dive, so only gas can bind.
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
      sacBottom: 15,
      swimSpeedMps: .2,
      scooter: ScooterSpec(
        name: 'DPV',
        ratedSpeedMps: .2,
        burnTimeSeconds: 20000,
      ),
    ),
  ],
);

/// Back gas filled so a stop charged wholly to oxygen ends just above the
/// 50 bar reserve, and the same stop with its air break ends just below it.
domain.DivePlan _plan({required double backFillBar}) => domain.DivePlan(
  id: 'mission',
  name: 'Mission budget',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  gfLow: 30,
  gfHigh: 70,
  sacBottom: 15,
  sacDeco: 15,
  sacStressed: 15,
  problemSolvingMinutes: 0,
  reservePressure: 50,
  airBreaks: const AirBreakPolicy(),
  tanks: [
    DiveTank(
      id: 'back',
      gasMix: const GasMix(o2: 21),
      volume: 40,
      startPressure: backFillBar,
    ),
    const DiveTank(
      id: '50',
      gasMix: GasMix(o2: 50),
      volume: 7,
      startPressure: 230,
    ),
    const DiveTank(
      id: 'o2',
      gasMix: GasMix(o2: 100),
      volume: 7,
      startPressure: 200,
    ),
  ],
);

/// 12 minutes on oxygen at 6 m, 6 of them on the break cylinder when
/// [airBreakSeconds] says so.
PlanScheduleRow _stop({int airBreakSeconds = 0, String? airBreakTankId}) =>
    PlanScheduleRow(
      kind: PlanScheduleRowKind.stop,
      depthMeters: 6,
      durationSeconds: 720,
      runtimeSeconds: 720,
      gasFO2: 1,
      gasFHe: 0,
      tankId: 'o2',
      airBreakSeconds: airBreakSeconds,
      airBreakTankId: airBreakTankId,
    );

void main() {
  const missionEngine = MissionEngine(
    scenarios: MissionScenarioService(engine: _engine),
  );

  group('MemberGasService on a stop with an air break', () {
    const service = MemberGasService();
    const env = DiveEnvironment.standard;
    final stopBar = env.pressureAtDepth(6);

    test('splits the stop between its two cylinders', () {
      final liters = service.litersByTank(
        rows: [_stop(airBreakSeconds: 360, airBreakTankId: 'back')],
        environment: env,
        sacFor: (_) => 15,
      );
      expect(liters, {
        'o2': closeTo(6 * 15 * stopBar, 1e-6),
        'back': closeTo(6 * 15 * stopBar, 1e-6),
      });
    });

    test('charges the break at the rate in force on the row', () {
      final liters = service.litersByTank(
        rows: [_stop(airBreakSeconds: 120, airBreakTankId: 'back')],
        environment: env,
        sacFor: (_) => 10,
      );
      expect(liters['o2'], closeTo(10 * 10 * stopBar, 1e-6));
      expect(liters['back'], closeTo(2 * 10 * stopBar, 1e-6));
    });

    test('adds the break to what the break cylinder already gave', () {
      final liters = service.litersByTank(
        rows: [
          const PlanScheduleRow(
            kind: PlanScheduleRowKind.level,
            depthMeters: 6,
            durationSeconds: 60,
            runtimeSeconds: 60,
            gasFO2: 0.21,
            gasFHe: 0,
            tankId: 'back',
          ),
          _stop(airBreakSeconds: 360, airBreakTankId: 'back'),
        ],
        environment: env,
        sacFor: (_) => 15,
      );
      expect(liters['back'], closeTo(7 * 15 * stopBar, 1e-6));
    });

    test('keeps a break on the stop cylinder when none is named', () {
      final liters = service.litersByTank(
        rows: [_stop(airBreakSeconds: 360)],
        environment: env,
        sacFor: (_) => 15,
      );
      expect(liters, {'o2': closeTo(12 * 15 * stopBar, 1e-6)});
    });

    test('charges a stop with no break to one cylinder', () {
      final liters = service.litersByTank(
        rows: [_stop()],
        environment: env,
        sacFor: (_) => 15,
      );
      expect(liters, {'o2': closeTo(12 * 15 * stopBar, 1e-6)});
    });
  });

  group('a mission air break (issue #3928)', () {
    test('is charged to the break cylinder, as the plan engine charges it', () {
      final plan = _plan(backFillBar: 171);
      final result = missionEngine.compute(plan: plan, mission: _mission);
      final exact = _engine.compute(plan.copyWith(segments: result.segments));
      expect(
        exact.stops.fold<int>(0, (sum, stop) => sum + stop.airBreakSeconds),
        360,
      );

      final budget = const MemberGasService().litersByTank(
        rows: exact.schedule,
        environment: PlanEngine.environmentFor(plan),
        sacFor: (_) => 15,
      );

      final backUsed = exact.tankUsages
          .firstWhere((usage) => usage.tankId == 'back')
          .litersUsed;
      expect(budget['back'], closeTo(backUsed, 1e-6));
    });

    test('that takes the back gas under its reserve closes the waypoint', () {
      final plan = _plan(backFillBar: 171);
      final result = missionEngine.compute(plan: plan, mission: _mission);

      final waypoint = result.waypoints.single;
      expect(waypoint.members.single.swim.gasShortfallMemberIds, {'diver'});
      expect(waypoint.members.single.swim.feasible, isFalse);
      expect(waypoint.survivable, isFalse);
      expect(result.abandonmentIndex, isNull);
    });

    test('leaves the waypoint open when the fill covers the break', () {
      // 3 bar more back gas pays for the 2.93 bar the break costs.
      final plan = _plan(backFillBar: 174);
      final result = missionEngine.compute(plan: plan, mission: _mission);

      expect(result.waypoints.single.survivable, isTrue);
      expect(result.abandonmentIndex, 0);
    });
  });
}
