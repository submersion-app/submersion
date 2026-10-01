import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_leg_table.dart';
import 'package:submersion/features/planner/presentation/mission/mission_member_result_card.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/planner/presentation/mission/mission_waypoint_list.dart';
import 'package:submersion/features/planner/presentation/providers/mission_outcome_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "Mission" results: the constraint sentence and its assumptions, a
/// card per diver, the waypoints and the legs. While the first result is
/// computing it says so; a blocked mission lists why.
class MissionResultsSection extends ConsumerWidget {
  const MissionResultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref.watch(
      divePlanNotifierProvider.select((s) => s.mission),
    );
    if (mission == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    // Keep showing the last outcome while a newer edit computes; a new
    // result replaces it when it lands. An engine error is said, never left
    // looking like a computation that does not end.
    final result = ref.watch(missionOutcomeProvider);
    final outcome = result.value;
    final failed = Text(
      l10n.plannerMission_results_failed,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
    if (outcome == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: result.hasError
            ? failed
            : Text(
                l10n.plannerMission_results_computing,
                style: theme.textTheme.bodySmall,
              ),
      );
    }
    // The last outcome stands, but the diver is told the newest edit could
    // not be computed, or that a newer result is on the way.
    final status = result.hasError
        ? failed
        : result.isLoading
        ? Text(
            l10n.plannerMission_results_computing,
            style: theme.textTheme.bodySmall,
          )
        : null;
    if (outcome.isBlocked) {
      final blocking = [
        for (final issue in outcome.issues)
          if (issue.severity == MissionIssueSeverity.blocking) issue,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?status,
          Text(l10n.plannerMission_results_blocked),
          for (final issue in blocking)
            Text(
              missionIssueText(l10n, issue, mission),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      );
    }
    final abandonment = outcome.abandonmentIndex;
    final abandonmentLeg = missionLegAt(outcome, mission, abandonment);
    // What a line this outcome can no longer fill says: that a newer result
    // is coming, or nothing once it failed (the line above says so).
    final staleText = result.hasError
        ? null
        : l10n.plannerMission_results_computing;
    final constraint =
        missionConstraintText(l10n, outcome, mission) ?? staleText;
    final abandonmentText =
        // No survivable waypoint because its scenarios could not be
        // computed is unknown, not a verdict about the water.
        abandonment == null &&
            outcome.waypoints.isNotEmpty &&
            outcome.waypoints.first.members.any(scenarioUnknown)
        ? l10n.plannerMission_results_abandonmentUnknown
        : abandonment == null
        ? l10n.plannerMission_results_noAbandonment
        // A leg removed since this outcome.
        : abandonmentLeg == null
        ? staleText
        : l10n.plannerMission_results_abandonment(
            missionLegName(l10n, abandonmentLeg),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?status,
        if (constraint != null)
          Text(constraint, style: theme.textTheme.bodyMedium),
        Text(
          l10n.plannerMission_results_assumptions(
            settingPercent(mission.batteryReserveFraction),
          ),
          style: theme.textTheme.bodySmall,
        ),
        if (abandonmentText != null)
          Text(abandonmentText, style: theme.textTheme.bodySmall),
        // Warnings and notes: a scenario that could not be computed, a
        // scooter whose equipment item is gone. A warning raised once per
        // failed scenario reads the same each time, so each sentence shows
        // once.
        for (final note in {
          for (final issue in outcome.issues)
            if (issue.severity != MissionIssueSeverity.blocking)
              missionIssueText(l10n, issue, mission),
        })
          Text(note, style: theme.textTheme.bodySmall),
        for (final result in outcome.members)
          if (mission.team.where((t) => t.id == result.memberId).firstOrNull
              case final member?)
            MissionMemberResultCard(
              outcome: outcome,
              staleText: staleText,
              member: member,
              result: result,
              mission: mission,
              units: units,
            ),
        const SizedBox(height: 12),
        PlanSectionHeader(l10n.plannerMission_results_waypoints),
        MissionWaypointList(outcome: outcome, mission: mission, units: units),
        const SizedBox(height: 12),
        PlanSectionHeader(l10n.plannerMission_results_legs),
        MissionLegTable(
          outcome: outcome,
          mission: mission,
          units: MissionUnits(units),
        ),
      ],
    );
  }
}
