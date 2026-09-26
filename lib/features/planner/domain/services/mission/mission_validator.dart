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
  for (final member in mission.team) {
    if (member.scooter.ratedSpeedMps <= 0 ||
        member.scooter.burnTimeSeconds <= 0) {
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
    // A leg shorter than an exit leg can be is no leg: its return would be
    // skipped while its outbound hold is built, leaving the two unmatched.
    if (leg.distanceM < kMinExitLegM) {
      issues.add(
        MissionIssue(
          type: MissionIssueType.legTooShort,
          severity: MissionIssueSeverity.blocking,
          legId: leg.id,
        ),
      );
    }
  }
  return issues;
}
