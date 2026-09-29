import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A leg's name as the canvas shows it: its waypoint label, or "Leg n".
String missionLegName(AppLocalizations l10n, MissionLeg leg) =>
    leg.label.trim().isEmpty
    ? l10n.plannerMission_route_unnamedLeg(leg.order + 1)
    : leg.label;

/// One sentence for [issue], naming the diver or leg it carries by id.
String missionIssueText(
  AppLocalizations l10n,
  MissionIssue issue,
  DpvMission mission,
) {
  String member() {
    for (final t in mission.team) {
      if (t.id == issue.memberId) return t.displayName;
    }
    return '';
  }

  String leg() {
    for (final l in mission.legs) {
      if (l.id == issue.legId) return missionLegName(l10n, l);
    }
    return '';
  }

  return switch (issue.type) {
    MissionIssueType.emptyTeam => l10n.plannerMission_issue_emptyTeam,
    MissionIssueType.emptyRoute => l10n.plannerMission_issue_emptyRoute,
    MissionIssueType.scooterUnspecified =>
      l10n.plannerMission_issue_scooterUnspecified(member()),
    MissionIssueType.memberSacUnset => l10n.plannerMission_issue_memberSacUnset(
      member(),
    ),
    MissionIssueType.memberSwimSpeedUnset =>
      l10n.plannerMission_issue_memberSwimSpeedUnset(member()),
    MissionIssueType.speedBelowHeadwayFloor =>
      l10n.plannerMission_issue_speedBelowHeadwayFloor(member()),
    MissionIssueType.openWaterInputInvalid =>
      l10n.plannerMission_issue_openWaterInputInvalid,
    MissionIssueType.legTooShort => l10n.plannerMission_issue_legTooShort(
      leg(),
    ),
    MissionIssueType.planHasNoTank => l10n.plannerMission_issue_planHasNoTank,
    MissionIssueType.tankBudgetUnknown =>
      l10n.plannerMission_issue_tankBudgetUnknown,
    MissionIssueType.unsupportedMode =>
      l10n.plannerMission_issue_unsupportedMode,
    MissionIssueType.planNotDiveable =>
      l10n.plannerMission_issue_planNotDiveable,
    MissionIssueType.batteryReserveInvalid =>
      l10n.plannerMission_issue_batteryReserveInvalid,
    MissionIssueType.legDepthInvalid =>
      l10n.plannerMission_issue_legDepthInvalid(leg()),
    MissionIssueType.untraversableLeg =>
      l10n.plannerMission_issue_untraversableLeg(leg()),
    MissionIssueType.scenarioFailed => l10n.plannerMission_issue_scenarioFailed,
  };
}
