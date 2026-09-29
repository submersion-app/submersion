import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One block per waypoint: where it is, when the team arrives, the time to
/// a safe surface, and for each diver whether a scooter failure there still
/// leaves a way out, with the exits that work and how long they take.
///
/// Blocks, not a table: a column per diver does not fit a phone.
class MissionWaypointList extends StatelessWidget {
  const MissionWaypointList({
    super.key,
    required this.outcome,
    required this.mission,
    required this.units,
  });

  final MissionOutcome outcome;
  final DpvMission mission;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final openWater = mission.environment == MissionEnvironment.openWater;
    // An outcome from before the latest edit can name a diver or waypoint
    // the mission no longer has; such rows are skipped until it is replaced.
    String? name(String memberId) =>
        mission.team.where((t) => t.id == memberId).firstOrNull?.displayName;

    String exits(MemberWaypointOutcome m) {
      final parts = <String>[
        if (m.swim.feasible)
          l10n.plannerMission_results_swim(
            ceilMinutes(m.swim.knownExitSeconds!).toString(),
          ),
        if (m.tow == null)
          l10n.plannerMission_results_noBuddy
        else if (m.tow!.feasible)
          // Placeholders are alphabetical: minutes, name.
          l10n.plannerMission_results_tow(
            ceilMinutes(m.tow!.knownExitSeconds!).toString(),
            name(m.tow!.towerId!) ?? '',
          ),
        if (m.surface != null && m.surface!.feasible)
          (m.surface!.viaShore
              ? l10n.plannerMission_results_surfaceViaShore
              : l10n.plannerMission_results_surface)(
            ceilMinutes(m.surface!.knownExitSeconds!).toString(),
          ),
      ];
      return parts.join(', ');
    }

    // A scenario whose computation threw is unknown, not the water's
    // verdict: it reads as not computed, never as no way out.
    String status(MemberWaypointOutcome m) {
      if (m.survivable) return l10n.plannerMission_results_survives;
      final failed =
          m.swim.failed ||
          (m.tow?.failed ?? false) ||
          (m.surface?.failed ?? false);
      return failed
          ? l10n.plannerMission_results_notComputed
          : l10n.plannerMission_results_cannotGetOut;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in outcome.waypoints)
          if (w.index < mission.legs.length)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    missionLegName(l10n, mission.legs[w.index]),
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.plannerMission_results_waypointLine(
                      ceilDistance(units, w.cumulativeDistanceM),
                      ceilMinutes(w.arrivalRuntimeSeconds).toString(),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (w.safeSurfaceSeconds != null)
                    Text(
                      l10n.plannerMission_results_safeSurface(
                        ceilMinutes(w.safeSurfaceSeconds!).toString(),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  if (openWater)
                    Text(
                      l10n.plannerMission_results_home(
                        ceilDistance(units, w.directDistanceHomeM),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  for (final m in w.members)
                    if (name(m.memberId) case final memberName?)
                      Text(
                        '$memberName: '
                        '${status(m)}'
                        '${exits(m).isEmpty ? '' : ' (${exits(m)})'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: m.survivable ? null : theme.colorScheme.error,
                        ),
                      ),
                ],
              ),
            ),
      ],
    );
  }
}
