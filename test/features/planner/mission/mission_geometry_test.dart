import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';

const _l1 = MissionLeg(
  id: 'L1',
  order: 0,
  label: 'A',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);
const _l2 = MissionLeg(
  id: 'L2',
  order: 1,
  label: 'B',
  distanceM: 400,
  depthM: 30,
  headingDeg: 0,
);

void main() {
  group('positions', () {
    test('dead reckoning sums each leg along its heading', () {
      final points = waypointPositions(const [_l1, _l2]);
      expect(points[0].eastM, closeTo(300, 1e-9));
      expect(points[0].northM, closeTo(0, 1e-9));
      expect(points[1].eastM, closeTo(300, 1e-9));
      expect(points[1].northM, closeTo(400, 1e-9));
      expect(points[0].distanceHomeM, closeTo(300, 1e-9));
      expect(points[1].distanceHomeM, closeTo(500, 1e-9));
    });

    test('the bearing home points back to the entry', () {
      final points = waypointPositions(const [_l1, _l2]);
      expect(points[0].bearingHomeDeg, closeTo(270, 1e-9));
      expect(points[1].bearingHomeDeg, closeTo(216.8699, 1e-3));
      expect(
        const RoutePoint(eastM: 0, northM: -100).bearingHomeDeg,
        closeTo(0, 1e-9),
      );
      expect(
        const RoutePoint(eastM: -100, northM: 0).bearingHomeDeg,
        closeTo(90, 1e-9),
      );
    });

    test('every bearing home is in [0, 360)', () {
      for (final (east, north) in [
        (1.0, 1.0),
        (-1.0, 1.0),
        (-1.0, -1.0),
        (1.0, -1.0),
        (0.0, 5.0),
      ]) {
        final bearing = RoutePoint(eastM: east, northM: north).bearingHomeDeg;
        expect(bearing, greaterThanOrEqualTo(0));
        expect(bearing, lessThan(360));
      }
    });

    test('a heading outside 0 to 360 lands where its twin does', () {
      final a = waypointPositions([_l1.copyWith(headingDeg: 450)]).single;
      final b = waypointPositions([_l1]).single;
      expect(a.eastM, closeTo(b.eastM, 1e-9));
      expect(a.northM, closeTo(b.northM, 1e-9));
    });

    test('at the entry the distance is zero and the bearing is 0', () {
      const here = RoutePoint(eastM: 0, northM: 0);
      expect(here.distanceHomeM, 0);
      expect(here.bearingHomeDeg, 0);
    });
  });

  group('exit legs', () {
    const current = CurrentVector(speedMps: 0.1, setsTowardDeg: 180);

    test('retracing runs the legs back in reverse on their reciprocals', () {
      final mission = DpvMission(
        legs: [
          _l1,
          _l2.copyWith(current: current),
        ],
      );
      expect(retraceExitLegs(mission, 1), const [
        ExitLeg(
          id: 'L2',
          distanceM: 400,
          depthM: 30,
          headingDeg: 180,
          current: current,
        ),
        ExitLeg(id: 'L1', distanceM: 300, depthM: 20, headingDeg: 270),
      ]);
      expect(retraceExitLegs(mission, 0).map((e) => e.id), ['L1']);
    });

    test('an overhead exit retraces the route', () {
      const mission = DpvMission(legs: [_l1, _l2]);
      expect(exitLegsFor(mission, 1), retraceExitLegs(mission, 1));
    });

    test(
      'an open-water exit is one straight leg home at the waypoint depth',
      () {
        const mission = DpvMission(
          legs: [_l1, _l2],
          environment: MissionEnvironment.openWater,
          defaultCurrent: current,
        );
        final legs = exitLegsFor(mission, 1);
        expect(legs, hasLength(1));
        expect(legs.single.id, 'home');
        expect(legs.single.distanceM, closeTo(500, 1e-9));
        expect(legs.single.headingDeg, closeTo(216.8699, 1e-3));
        expect(legs.single.depthM, 30);
        expect(legs.single.current, current);
      },
    );

    test(
      'without a mission default the straight leg takes the waypoint leg current',
      () {
        final mission = DpvMission(
          legs: [
            _l1,
            _l2.copyWith(current: current),
          ],
          environment: MissionEnvironment.openWater,
        );
        expect(exitLegsFor(mission, 1).single.current, current);
        expect(exitLegsFor(mission, 0).single.current, isNull);
      },
    );

    test(
      'a waypoint leg with its own current wins over the mission default',
      () {
        const local = CurrentVector(speedMps: 0.4, setsTowardDeg: 90);
        final mission = DpvMission(
          legs: [
            _l1,
            _l2.copyWith(current: local),
          ],
          environment: MissionEnvironment.openWater,
          defaultCurrent: current,
        );
        expect(exitLegsFor(mission, 1).single.current, local);
      },
    );

    test('a route that ends at the entry has no open-water exit leg', () {
      const mission = DpvMission(
        legs: [
          MissionLeg(
            id: 'out',
            order: 0,
            label: 'A',
            distanceM: 200,
            depthM: 20,
            headingDeg: 0,
          ),
          MissionLeg(
            id: 'back',
            order: 1,
            label: 'B',
            distanceM: 200,
            depthM: 20,
            headingDeg: 180,
          ),
        ],
        environment: MissionEnvironment.openWater,
      );
      expect(exitLegsFor(mission, 1), isEmpty);
    });
  });
}
