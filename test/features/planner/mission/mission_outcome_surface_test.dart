// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';

ExitOutcome _surface({bool viaShore = true}) => ExitOutcome(
  mode: MissionExitMode.surface,
  feasible: true,
  exitBottomSeconds: 0,
  ttsSeconds: 240,
  exitLitersByMember: {'a': 300.0},
  surfaceSeconds: 875,
  surfaceSwimM: 100,
  walkM: 300,
  viaShore: viaShore,
);

void main() {
  test('the binding reasons are in tie-break order', () {
    expect(MissionBindingFactor.values, [
      MissionBindingFactor.battery,
      MissionBindingFactor.ownGas,
      MissionBindingFactor.teamGas,
      MissionBindingFactor.exposure,
      MissionBindingFactor.blockedByCurrent,
      MissionBindingFactor.noFeasibleTow,
      MissionBindingFactor.surfaceSwimLimit,
    ]);
  });

  test('a surface exit counts its surface time in the exit time', () {
    expect(_surface().exitSeconds, 240 + 875);
  });

  test('an underwater exit has no surface part', () {
    final swim = ExitOutcome(
      mode: MissionExitMode.swim,
      feasible: true,
      exitBottomSeconds: 1500,
      ttsSeconds: 300,
      exitLitersByMember: {'a': 1200.0},
    );
    expect(swim.surfaceSeconds, 0);
    expect(swim.surfaceSwimM, isNull);
    expect(swim.walkM, isNull);
    expect(swim.viaShore, isFalse);
    expect(swim.surfaceLimitExceeded, isFalse);
    expect(swim.exitSeconds, 1800);
  });

  test('the surface fields take part in equality', () {
    expect(_surface(), _surface());
    expect(_surface(viaShore: false), isNot(_surface()));
  });

  test('a member outcome carries the surface exit', () {
    MemberWaypointOutcome member(ExitOutcome? surface) => MemberWaypointOutcome(
      memberId: 'a',
      gasRemainingBar: 180,
      swim: ExitOutcome(
        mode: MissionExitMode.swim,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: 0,
        exitLitersByMember: {},
        blockedByCurrent: true,
      ),
      surface: surface,
      survivable: surface != null,
    );
    expect(member(null).surface, isNull);
    expect(member(_surface()).surface, _surface());
    expect(member(_surface()), isNot(member(null)));
  });
}
