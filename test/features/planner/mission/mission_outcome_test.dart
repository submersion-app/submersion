import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';

void main() {
  test('MissionOutcome.empty carries only the issues it was given', () {
    const issue = MissionIssue(
      type: MissionIssueType.emptyTeam,
      severity: MissionIssueSeverity.blocking,
    );
    const outcome = MissionOutcome.empty(issues: [issue]);
    expect(outcome.issues, [issue]);
    expect(outcome.segments, isEmpty);
    expect(outcome.legs, isEmpty);
    expect(outcome.waypoints, isEmpty);
    expect(outcome.members, isEmpty);
    expect(outcome.abandonmentIndex, isNull);
    expect(outcome.constraint, isNull);
    expect(outcome.cruiseSpeedMps, 0);
    expect(outcome.isBlocked, isTrue);
  });

  test('isBlocked is false when no issue is blocking', () {
    const outcome = MissionOutcome.empty(
      issues: [
        MissionIssue(
          type: MissionIssueType.memberSacUnset,
          severity: MissionIssueSeverity.warning,
          memberId: 'm1',
        ),
      ],
    );
    expect(outcome.isBlocked, isFalse);
  });

  test('ExitOutcome exposes the exit runtime as bottom plus tts', () {
    const exit = ExitOutcome(
      mode: MissionExitMode.tow,
      towerId: 'm2',
      feasible: true,
      exitBottomSeconds: 1200,
      ttsSeconds: 300,
      exitLitersByMember: {'m1': 900.0, 'm2': 600.0},
    );
    expect(exit.exitSeconds, 1500);
    expect(exit.gasShortfallMemberIds, isEmpty);
    expect(exit.batteryShortfallMemberIds, isEmpty);
    expect(exit.blockedByCurrent, isFalse);
  });

  test('value equality holds for nested outcomes', () {
    const a = MemberWaypointOutcome(
      memberId: 'm1',
      gasRemainingBar: 120,
      swim: ExitOutcome(
        mode: MissionExitMode.swim,
        feasible: false,
        exitBottomSeconds: 3000,
        ttsSeconds: 200,
        exitLitersByMember: {'m1': 2000.0},
        gasShortfallMemberIds: {'m1'},
      ),
      survivable: false,
    );
    const b = MemberWaypointOutcome(
      memberId: 'm1',
      gasRemainingBar: 120,
      swim: ExitOutcome(
        mode: MissionExitMode.swim,
        feasible: false,
        exitBottomSeconds: 3000,
        ttsSeconds: 200,
        exitLitersByMember: {'m1': 2000.0},
        gasShortfallMemberIds: {'m1'},
      ),
      survivable: false,
    );
    expect(a, b);
    expect(a.tow, isNull);
  });
}
