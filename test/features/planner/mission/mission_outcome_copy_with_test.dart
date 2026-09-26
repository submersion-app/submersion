// Instances here are deliberately non-const: const instances canonicalise to
// a single instance, so == short-circuits on identity and the Equatable props
// under test are never evaluated.
// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/exit_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';

ExitOutcome _exit() => ExitOutcome(
  mode: MissionExitMode.surface,
  towerId: 'a',
  feasible: true,
  exitBottomSeconds: 0,
  ttsSeconds: 240,
  exitLitersByMember: {'a': 300.0},
  surfaceSeconds: 875,
  surfaceSwimM: 100,
  walkM: 300,
  viaShore: true,
);

MemberWaypointOutcome _memberAt() => MemberWaypointOutcome(
  memberId: 'a',
  gasRemainingBar: 180,
  swim: _exit(),
  tow: _exit(),
  surface: _exit(),
  survivable: true,
);

void main() {
  test('ExitLeg copies each field and can clear its current', () {
    final leg = ExitLeg(
      id: 'home',
      distanceM: 500,
      depthM: 20,
      headingDeg: 216.87,
      current: CurrentVector(speedMps: 0.1, setsTowardDeg: 0),
    );
    expect(leg.copyWith(), leg);
    expect(leg.copyWith(distanceM: 10).distanceM, 10);
    expect(leg.copyWith(depthM: 5).depthM, 5);
    expect(leg.copyWith(headingDeg: 90).headingDeg, 90);
    expect(leg.copyWith(id: 'x').id, 'x');
    expect(leg.copyWith(clearCurrent: true).current, isNull);
  });

  test('MissionIssue copies and clears its optional fields', () {
    final issue = MissionIssue(
      type: MissionIssueType.untraversableLeg,
      severity: MissionIssueSeverity.blocking,
      legId: 'L1',
      memberId: 'a',
      outbound: true,
    );
    expect(issue.copyWith(), issue);
    expect(
      issue.copyWith(severity: MissionIssueSeverity.warning).severity,
      MissionIssueSeverity.warning,
    );
    final cleared = issue.copyWith(
      clearLegId: true,
      clearMemberId: true,
      clearOutbound: true,
    );
    expect(cleared.legId, isNull);
    expect(cleared.memberId, isNull);
    expect(cleared.outbound, isNull);
  });

  test('LegOutcome copies each field', () {
    final leg = LegOutcome(
      legId: 'L1',
      outboundSpeedMps: 0.5,
      returnSpeedMps: 0.4,
      outboundSeconds: 600,
      returnSeconds: 750,
    );
    expect(leg.copyWith(), leg);
    expect(leg.copyWith(returnSeconds: 1).returnSeconds, 1);
    expect(leg.copyWith(outboundSpeedMps: 0.9).outboundSpeedMps, 0.9);
  });

  test('ExitOutcome copies and clears its optional fields', () {
    expect(_exit().copyWith(), _exit());
    expect(_exit().copyWith(feasible: false).feasible, isFalse);
    expect(_exit().copyWith(surfaceSeconds: 1).surfaceSeconds, 1);
    final cleared = _exit().copyWith(
      clearTowerId: true,
      clearSurfaceSwimM: true,
      clearWalkM: true,
    );
    expect(cleared.towerId, isNull);
    expect(cleared.surfaceSwimM, isNull);
    expect(cleared.walkM, isNull);
  });

  test('MemberWaypointOutcome copies and clears its optional fields', () {
    expect(_memberAt().copyWith(), _memberAt());
    expect(_memberAt().copyWith(survivable: false).survivable, isFalse);
    final cleared = _memberAt().copyWith(
      clearGasRemainingBar: true,
      clearTow: true,
      clearSurface: true,
    );
    expect(cleared.gasRemainingBar, isNull);
    expect(cleared.tow, isNull);
    expect(cleared.surface, isNull);
  });

  test('WaypointOutcome copies and clears the safe-surface time', () {
    final waypoint = WaypointOutcome(
      index: 0,
      legId: 'L1',
      cumulativeDistanceM: 300,
      arrivalRuntimeSeconds: 667,
      directDistanceHomeM: 300,
      safeSurfaceSeconds: 900,
      members: [_memberAt()],
      survivable: true,
    );
    expect(waypoint.copyWith(), waypoint);
    expect(waypoint.copyWith(index: 2).index, 2);
    expect(
      waypoint.copyWith(clearSafeSurfaceSeconds: true).safeSurfaceSeconds,
      isNull,
    );
  });

  test('MemberOutcome copies and clears its optional fields', () {
    final member = MemberOutcome(
      memberId: 'a',
      batteryRoundTripFraction: 0.4,
      setsCruiseSpeed: true,
      bindingFactor: MissionBindingFactor.battery,
      bindingWaypointIndex: 1,
      turnPressureBar: 120,
    );
    expect(member.copyWith(), member);
    expect(member.copyWith(setsCruiseSpeed: false).setsCruiseSpeed, isFalse);
    final cleared = member.copyWith(
      clearBindingFactor: true,
      clearBindingWaypointIndex: true,
      clearTurnPressureBar: true,
    );
    expect(cleared.bindingFactor, isNull);
    expect(cleared.bindingWaypointIndex, isNull);
    expect(cleared.turnPressureBar, isNull);
  });

  test('MissionConstraint copies each field', () {
    final constraint = MissionConstraint(
      memberId: 'a',
      factor: MissionBindingFactor.ownGas,
      waypointIndex: 1,
    );
    expect(constraint.copyWith(), constraint);
    expect(constraint.copyWith(waypointIndex: 3).waypointIndex, 3);
  });

  test('MissionOutcome copies and clears its optional fields', () {
    final outcome = MissionOutcome(
      segments: const [],
      cruiseSpeedMps: 0.5,
      legs: const [],
      waypoints: const [],
      members: const [],
      abandonmentIndex: 1,
      constraint: MissionConstraint(
        memberId: 'a',
        factor: MissionBindingFactor.ownGas,
        waypointIndex: 1,
      ),
      issues: const [],
    );
    expect(outcome.copyWith(), outcome);
    expect(outcome.copyWith(cruiseSpeedMps: 0.7).cruiseSpeedMps, 0.7);
    final cleared = outcome.copyWith(
      clearAbandonmentIndex: true,
      clearConstraint: true,
    );
    expect(cleared.abandonmentIndex, isNull);
    expect(cleared.constraint, isNull);
  });
}
