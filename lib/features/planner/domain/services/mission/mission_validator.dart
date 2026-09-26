import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';

/// A real, finite number above zero. NaN fails every comparison, so a plain
/// `<= 0` check would let it through into gas maths where every comparison
/// is false and an exit reads feasible.
bool _isPositive(double v) => v.isFinite && v > 0;

/// A real, finite number of zero or more.
bool _isNonNegative(double v) => v.isFinite && v >= 0;

/// Everything that makes a mission impossible to compute, or its answer
/// meaningless, found before any scenario runs (issue #2086).
List<MissionIssue> validateMission(DpvMission mission) {
  final issues = <MissionIssue>[];
  if (mission.team.isEmpty) {
    issues.add(
      const MissionIssue(
        type: MissionIssueType.emptyTeam,
        severity: MissionIssueSeverity.blocking,
      ),
    );
  }
  if (mission.legs.isEmpty) {
    issues.add(
      const MissionIssue(
        type: MissionIssueType.emptyRoute,
        severity: MissionIssueSeverity.blocking,
      ),
    );
  }
  // Burn must be allowed and reserved within the battery: a negative reserve
  // would let a scooter run past its rated burn time.
  final reserve = mission.batteryReserveFraction;
  if (!_isNonNegative(reserve) || reserve > 1) {
    issues.add(
      const MissionIssue(
        type: MissionIssueType.batteryReserveInvalid,
        severity: MissionIssueSeverity.blocking,
      ),
    );
  }
  for (final member in mission.team) {
    final scooter = member.scooter;
    // A tow factor of zero or less would charge a tow no burn, or give it no
    // speed; either makes a tow read possible when it is not.
    if (!_isPositive(scooter.ratedSpeedMps) ||
        scooter.burnTimeSeconds <= 0 ||
        !_isPositive(scooter.towSpeedFactor) ||
        !_isPositive(scooter.towBurnFactor)) {
      issues.add(
        MissionIssue(
          type: MissionIssueType.scooterUnspecified,
          severity: MissionIssueSeverity.blocking,
          memberId: member.id,
        ),
      );
    }
    if (!_isPositive(member.sacBottom)) {
      issues.add(
        MissionIssue(
          type: MissionIssueType.memberSacUnset,
          severity: MissionIssueSeverity.blocking,
          memberId: member.id,
        ),
      );
    }
    if (!_isPositive(member.swimSpeedMps)) {
      issues.add(
        MissionIssue(
          type: MissionIssueType.memberSwimSpeedUnset,
          severity: MissionIssueSeverity.blocking,
          memberId: member.id,
        ),
      );
    }
  }
  if (mission.environment == MissionEnvironment.openWater) {
    // A negative distance would always pass the swim limit and win as the
    // fastest route, reporting an exit that does not exist.
    final limit = mission.surfaceSwimLimitM;
    if ((limit != null && !_isNonNegative(limit)) ||
        !_isNonNegative(mission.walkSpeedMps)) {
      issues.add(
        const MissionIssue(
          type: MissionIssueType.openWaterInputInvalid,
          severity: MissionIssueSeverity.blocking,
        ),
      );
    }
    for (final leg in mission.legs) {
      final shore = leg.shoreExit;
      if (shore != null &&
          (!_isNonNegative(shore.surfaceSwimM) ||
              !_isNonNegative(shore.walkM))) {
        issues.add(
          MissionIssue(
            type: MissionIssueType.openWaterInputInvalid,
            severity: MissionIssueSeverity.blocking,
            legId: leg.id,
          ),
        );
      }
    }
  }
  for (final leg in mission.legs) {
    // A leg shorter than the shortest exit leg is not a leg: its return
    // would be skipped while its outbound hold is built, leaving the two
    // unmatched.
    if (!leg.distanceM.isFinite || !(leg.distanceM >= kMinExitLegM)) {
      issues.add(
        MissionIssue(
          type: MissionIssueType.legTooShort,
          severity: MissionIssueSeverity.blocking,
          legId: leg.id,
        ),
      );
    }
    // Negative depth would put the profile above the surface.
    if (!_isNonNegative(leg.depthM)) {
      issues.add(
        MissionIssue(
          type: MissionIssueType.legDepthInvalid,
          severity: MissionIssueSeverity.blocking,
          legId: leg.id,
        ),
      );
    }
  }
  return issues;
}

/// What the plan under a mission must provide for its exits to be judged.
///
/// Version 1 plans open circuit only: a rebreather's loop gas is not tied to
/// a carried cylinder, so its exit gas could not be charged. Every cylinder
/// needs a volume and a fill pressure, or no exit's gas can be proven safe.
List<MissionIssue> validatePlanForMission(domain.DivePlan plan) {
  return [
    if (plan.mode != domain.PlanMode.oc)
      const MissionIssue(
        type: MissionIssueType.unsupportedMode,
        severity: MissionIssueSeverity.blocking,
      ),
    if (plan.tanks.any((t) => t.volume == null || t.startPressure == null))
      const MissionIssue(
        type: MissionIssueType.tankBudgetUnknown,
        severity: MissionIssueSeverity.blocking,
      ),
  ];
}
