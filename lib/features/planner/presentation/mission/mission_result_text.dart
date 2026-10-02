import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
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
/// sentence when no member binds anywhere on the route. Null when [outcome]
/// predates the latest edit and names a diver or leg the mission no longer
/// has; the caller says a newer result is coming, or nothing if it failed.
String? missionConstraintText(
  AppLocalizations l10n,
  MissionOutcome outcome,
  DpvMission mission,
) {
  final c = outcome.constraint;
  if (c == null) return l10n.plannerMission_results_unconstrained;
  final member = mission.team.where((t) => t.id == c.memberId).firstOrNull;
  // An outcome computed before the latest edit can name a diver or waypoint
  // the mission no longer has; its replacement is on the way.
  final leg = missionLegAt(outcome, mission, c.waypointIndex);
  if (member == null || leg == null) return null;
  final waypoint = missionLegName(l10n, leg);
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

/// The current mission's leg at [outcome]'s waypoint [index], matched by the
/// leg id the outcome recorded, or null when that leg is gone. An outcome
/// stays on screen while a newer edit computes, so an index read straight
/// into the mission's legs would name the wrong leg after a reorder or a
/// removal.
MissionLeg? missionLegAt(
  MissionOutcome outcome,
  DpvMission mission,
  int? index,
) {
  if (index == null) return null;
  final legId = outcome.waypoints
      .where((w) => w.index == index)
      .firstOrNull
      ?.legId;
  return mission.legs.where((l) => l.id == legId).firstOrNull;
}

/// A fraction as a whole percent, rounded up. The small offset keeps binary
/// noise (0.55 * 100 is 55.00000000000001) from adding a percent.
String ceilPercent(double fraction) =>
    (fraction * 100 - 1e-9).ceil().toString();

/// True when [m]'s failure here is unknown rather than unsurvivable: no
/// exit works, and at least one exit's computation threw, so the water, gas
/// and battery were never judged.
bool scenarioUnknown(MemberWaypointOutcome m) =>
    !m.survivable &&
    (m.swim.failed || (m.tow?.failed ?? false) || (m.surface?.failed ?? false));

/// A computed speed over the ground in the diver's unit, rounded down: a
/// plan never shows the team moving faster than it does. The small offset
/// keeps binary noise from taking a whole unit off.
String floorSpeed(MissionUnits units, double mps) =>
    '${(units.speedDisplay(mps) + 1e-9).floor()} ${units.speedSymbol}';

/// A percent the diver set, shown as they set it: the battery reserve is an
/// input, and rounding it up would overstate what is kept back.
String settingPercent(double fraction) => (fraction * 100).round().toString();

/// A turn pressure in the diver's unit, rounded up: turning early is safe.
/// The small offset keeps binary noise on an exact figure from adding a
/// unit, as in [ceilPercent].
String ceilPressure(UnitFormatter units, double bar) =>
    '${(units.convertPressure(bar) - 1e-9).ceil()} ${units.pressureSymbol}';

/// A distance in the depth unit, rounded up, with the same noise guard.
String ceilDistance(UnitFormatter units, double meters) =>
    '${(units.convertDepth(meters) - 1e-9).ceil()}${units.depthSymbol}';
