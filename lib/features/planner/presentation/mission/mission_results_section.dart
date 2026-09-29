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
    if (outcome.isBlocked) {
      final blocking = [
        for (final issue in outcome.issues)
          if (issue.severity == MissionIssueSeverity.blocking) issue,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The last outcome stands, but the diver is told the newest edit
        // could not be computed.
        if (result.hasError) failed,
        Text(
          missionConstraintText(l10n, outcome, mission),
          style: theme.textTheme.bodyMedium,
        ),
        Text(
          l10n.plannerMission_results_assumptions(
            ceilPercent(mission.batteryReserveFraction),
          ),
          style: theme.textTheme.bodySmall,
        ),
        Text(
          abandonment == null || abandonment >= mission.legs.length
              ? l10n.plannerMission_results_noAbandonment
              : l10n.plannerMission_results_abandonment(
                  missionLegName(l10n, mission.legs[abandonment]),
                ),
          style: theme.textTheme.bodySmall,
        ),
        for (final result in outcome.members)
          if (mission.team.where((t) => t.id == result.memberId).firstOrNull
              case final member?)
            MissionMemberResultCard(
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
