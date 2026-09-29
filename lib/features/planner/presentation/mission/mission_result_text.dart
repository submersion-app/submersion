import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String missionFactorLabel(AppLocalizations l10n, MissionBindingFactor f) =>
    switch (f) {
      MissionBindingFactor.battery => l10n.plannerMission_factor_battery,
      MissionBindingFactor.ownGas => l10n.plannerMission_factor_ownGas,
      MissionBindingFactor.teamGas => l10n.plannerMission_factor_teamGas,
      MissionBindingFactor.exposure => l10n.plannerMission_factor_exposure,
      MissionBindingFactor.blockedByCurrent =>
        l10n.plannerMission_factor_blockedByCurrent,
      MissionBindingFactor.noFeasibleTow =>
        l10n.plannerMission_factor_noFeasibleTow,
      MissionBindingFactor.surfaceSwimLimit =>
        l10n.plannerMission_factor_surfaceSwimLimit,
      MissionBindingFactor.scenarioFailed =>
        l10n.plannerMission_factor_scenarioFailed,
    };

/// "Limited by Sam's Blacktip at T: battery reserve", or the unconstrained
/// sentence when no member binds anywhere on the route.
String missionConstraintText(
  AppLocalizations l10n,
  MissionOutcome outcome,
  DpvMission mission,
) {
  final c = outcome.constraint;
  if (c == null) return l10n.plannerMission_results_unconstrained;
  final member = mission.team.where((t) => t.id == c.memberId).firstOrNull;
  // An outcome computed before the latest edit can name a diver or waypoint
  // the mission no longer has; its replacement is on the way.
  if (member == null || c.waypointIndex >= mission.legs.length) {
    return l10n.plannerMission_results_computing;
  }
  final waypoint = missionLegName(l10n, mission.legs[c.waypointIndex]);
  final factor = missionFactorLabel(l10n, c.factor);
  final scooter = member.scooter.name.trim();
  // Placeholders are alphabetical: factor, name, (scooter,) waypoint.
  return scooter.isEmpty
      ? l10n.plannerMission_results_limitedByDiver(
          factor,
          member.displayName,
          waypoint,
        )
      : l10n.plannerMission_results_limitedBy(
          factor,
          member.displayName,
          scooter,
          waypoint,
        );
}

/// Whole minutes, rounded up: a planning time is never shown shorter than
/// it is.
int ceilMinutes(int seconds) => (seconds / 60).ceil();

/// A fraction as a whole percent, rounded up.
String ceilPercent(double fraction) => (fraction * 100).ceil().toString();

/// A turn pressure in the diver's unit, rounded up: turning early is safe.
String ceilPressure(UnitFormatter units, double bar) =>
    '${units.convertPressure(bar).ceil()} ${units.pressureSymbol}';

/// A distance in the depth unit, rounded up.
String ceilDistance(UnitFormatter units, double meters) =>
    '${units.convertDepth(meters).ceil()}${units.depthSymbol}';
