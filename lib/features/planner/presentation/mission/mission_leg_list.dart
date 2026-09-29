import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_validator.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_leg_editor.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The route of a DPV mission, in place of the segment list while a mission
/// is on: one row per leg, and below them the profile the legs generate.
class MissionLegList extends ConsumerWidget {
  const MissionLegList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    final mission = state.mission;
    if (mission == null) return const SizedBox.shrink();
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = MissionUnits(UnitFormatter(ref.watch(settingsProvider)));
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final openWater = mission.environment == MissionEnvironment.openWater;

    Future<void> edit(MissionLeg leg) async {
      final edited = await showMissionLegEditor(
        context,
        leg: leg,
        openWater: openWater,
        units: units,
      );
      if (edited != null) {
        notifier.updateMission(MissionEdits.updateLeg(mission, edited));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.plannerMission_route_title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: l10n.plannerMission_route_addLeg,
                  onPressed: () => notifier.updateMission(
                    MissionEdits.addLeg(mission, const Uuid().v4()),
                  ),
                ),
              ],
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mission.legs.length,
              onReorderItem: (oldIndex, newIndex) => notifier.updateMission(
                MissionEdits.reorderLegs(mission, oldIndex, newIndex),
              ),
              itemBuilder: (context, index) {
                final leg = mission.legs[index];
                return ListTile(
                  key: ValueKey(leg.id),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    missionLegName(l10n, leg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _legSubtitle(context, leg, mission, units),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => edit(leg),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    tooltip: l10n.plannerMission_route_deleteLeg,
                    onPressed: () => notifier.updateMission(
                      MissionEdits.removeLeg(mission, leg.id),
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            _GeneratedProfileStrip(
              segments: state.segments,
              units: units,
              reason: _blockingReason(context, state, mission),
            ),
          ],
        ),
      ),
    );
  }

  static String _legSubtitle(
    BuildContext context,
    MissionLeg leg,
    DpvMission mission,
    MissionUnits units,
  ) {
    final l10n = context.l10n;
    final lines = [
      l10n.plannerMission_route_legSummary(
        units.distance(leg.distanceM),
        units.distance(leg.depthM),
        units.heading(leg.headingDeg),
      ),
      if (leg.current != null)
        l10n.plannerMission_route_ownCurrent(
          units.speed(leg.current!.speedMps),
          units.heading(leg.current!.setsTowardDeg),
        ),
      if (leg.shoreExit != null)
        l10n.plannerMission_route_shoreExit(
          units.distance(leg.shoreExit!.surfaceSwimM),
          units.distance(leg.shoreExit!.walkM),
        ),
    ];
    return lines.join('\n');
  }

  /// The first blocking validation issue, as a sentence, or null.
  static String? _blockingReason(
    BuildContext context,
    DivePlanState state,
    DpvMission mission,
  ) {
    final issues = [
      ...validateMission(mission),
      ...validatePlanForMission(divePlanFromState(state)),
    ];
    for (final issue in issues) {
      if (issue.severity == MissionIssueSeverity.blocking) {
        return missionIssueText(context.l10n, issue, mission);
      }
    }
    return null;
  }
}

class _GeneratedProfileStrip extends StatelessWidget {
  const _GeneratedProfileStrip({
    required this.segments,
    required this.units,
    required this.reason,
  });

  final List<PlanSegment> segments;
  final MissionUnits units;

  /// Why there is no profile, or null when the mission generates one.
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (reason != null) {
      return Text(
        l10n.plannerMission_profile_none(reason!),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }
    // Read-only: the diver sees exactly what the engine is fed.
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        l10n.plannerMission_profile_title,
        style: theme.textTheme.bodyMedium,
      ),
      children: [
        for (final segment in segments)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${units.distance(segment.targetDepth)}, '
              '${(segment.durationSeconds / 60).ceil()} min',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
