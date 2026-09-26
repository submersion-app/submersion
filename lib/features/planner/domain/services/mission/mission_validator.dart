import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_geometry.dart';

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
  if (!reserve.isFinite || reserve < 0 || reserve > 1) {
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
    if (!(scooter.ratedSpeedMps > 0) ||
        scooter.burnTimeSeconds <= 0 ||
        !(scooter.towSpeedFactor > 0) ||
        !(scooter.towBurnFactor > 0)) {
      issues.add(
        MissionIssue(
          type: MissionIssueType.scooterUnspecified,
          severity: MissionIssueSeverity.blocking,
          memberId: member.id,
        ),
      );
    }
    if (member.sacBottom <= 0) {
      issues.add(
        MissionIssue(
          type: MissionIssueType.memberSacUnset,
          severity: MissionIssueSeverity.blocking,
          memberId: member.id,
        ),
      );
    }
    if (member.swimSpeedMps <= 0) {
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
    if ((mission.surfaceSwimLimitM ?? 0) < 0 || mission.walkSpeedMps < 0) {
      issues.add(
        const MissionIssue(
          type: MissionIssueType.openWaterInputInvalid,
          severity: MissionIssueSeverity.blocking,
        ),
      );
    }
    for (final leg in mission.legs) {
      final shore = leg.shoreExit;
      if (shore != null && (shore.surfaceSwimM < 0 || shore.walkM < 0)) {
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
    // Written as a negation so a distance that is not a number fails too.
    if (!(leg.distanceM >= kMinExitLegM)) {
      issues.add(
        MissionIssue(
          type: MissionIssueType.legTooShort,
          severity: MissionIssueSeverity.blocking,
          legId: leg.id,
        ),
      );
    }
    // Negative depth would put the profile above the surface.
    if (!(leg.depthM >= 0) || !leg.depthM.isFinite) {
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
