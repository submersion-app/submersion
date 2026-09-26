// Instances here are deliberately non-const: const instances canonicalise to
// a single instance, so == short-circuits on identity and the Equatable props
// under test are never evaluated.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

MissionLeg _leg() => MissionLeg(
  id: 'L1',
  order: 0,
  label: 'T',
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
);

void main() {
  test('a mission defaults to overhead, a 0.8 m/s walk and no swim limit', () {
    final mission = DpvMission();
    expect(mission.environment, MissionEnvironment.overhead);
    expect(mission.walkSpeedMps, 0.8);
    expect(kDefaultWalkSpeedMps, 0.8);
    expect(mission.surfaceSwimLimitM, isNull);
  });

  test('copyWith sets the open-water fields and clears the limit', () {
    final mission = DpvMission().copyWith(
      environment: MissionEnvironment.openWater,
      walkSpeedMps: 1.1,
      surfaceSwimLimitM: 250,
    );
    expect(mission.environment, MissionEnvironment.openWater);
    expect(mission.walkSpeedMps, 1.1);
    expect(mission.surfaceSwimLimitM, 250);
    expect(mission.copyWith().surfaceSwimLimitM, 250);
    expect(
      mission.copyWith(clearSurfaceSwimLimit: true).surfaceSwimLimitM,
      isNull,
    );
  });

  test('the open-water fields take part in equality', () {
    expect(
      DpvMission(environment: MissionEnvironment.openWater),
      isNot(DpvMission()),
    );
    expect(DpvMission(walkSpeedMps: 1.0), isNot(DpvMission()));
    expect(DpvMission(surfaceSwimLimitM: 100), isNot(DpvMission()));
    expect(
      DpvMission(surfaceSwimLimitM: 100),
      DpvMission(surfaceSwimLimitM: 100),
    );
  });

  test('a shore exit copies and compares by value', () {
    final shore = ShoreExit(surfaceSwimM: 120, walkM: 400);
    expect(shore, ShoreExit(surfaceSwimM: 120, walkM: 400));
    expect(shore.copyWith(walkM: 50), ShoreExit(surfaceSwimM: 120, walkM: 50));
    expect(
      shore.copyWith(surfaceSwimM: 10),
      ShoreExit(surfaceSwimM: 10, walkM: 400),
    );
    expect(shore.copyWith().hashCode, shore.hashCode);
  });

  test('a leg gains and loses a shore exit', () {
    final withShore = _leg().copyWith(
      shoreExit: ShoreExit(surfaceSwimM: 120, walkM: 400),
    );
    expect(withShore.shoreExit, ShoreExit(surfaceSwimM: 120, walkM: 400));
    expect(withShore, isNot(_leg()));
    expect(withShore.copyWith(label: 'X').shoreExit, isNotNull);
    expect(withShore.copyWith(clearShoreExit: true).shoreExit, isNull);
  });
}
