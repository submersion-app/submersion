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
      // Last: a real cause found for a teammate wins the tie.
      MissionBindingFactor.scenarioFailed,
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

  test('a failed exit knows no time', () {
    const failed = ExitOutcome.failed(mode: MissionExitMode.tow, towerId: 'c');
    expect(failed.failed, isTrue);
    expect(failed.feasible, isFalse);
    expect(failed.towerId, 'c');
    expect(failed.exitLitersByMember, isEmpty);
    expect(failed.knownExitSeconds, isNull);
    expect(failed.knownTtsSeconds, isNull);
  });

  test('a computed exit reports its own times as known', () {
    final surface = _surface();
    expect(surface.knownExitSeconds, surface.exitSeconds);
    expect(surface.knownTtsSeconds, surface.ttsSeconds);
  });

  test('a blocked underwater exit knows no time either', () {
    // ExitPathResult.blocked reports zeros: no way out was travelled.
    const blocked = ExitOutcome(
      mode: MissionExitMode.swim,
      feasible: false,
      exitBottomSeconds: 0,
      ttsSeconds: 0,
      exitLitersByMember: {},
      blockedByCurrent: true,
    );
    expect(blocked.knownExitSeconds, isNull);
    expect(blocked.knownTtsSeconds, isNull);
  });

  test('a blocked surface exit still knows its ascent in place', () {
    // No surface route home, but the ascent where the diver is was run.
    const blocked = ExitOutcome(
      mode: MissionExitMode.surface,
      feasible: false,
      exitBottomSeconds: 0,
      ttsSeconds: 300,
      exitLitersByMember: {},
      blockedByCurrent: true,
    );
    expect(blocked.knownExitSeconds, isNull);
    expect(blocked.knownTtsSeconds, 300);
  });
}
