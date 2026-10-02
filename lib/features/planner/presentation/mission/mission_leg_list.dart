import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_leg_editor.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/features/planner/presentation/providers/mission_issues_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The route of a DPV mission, in place of the segment list while a mission
/// is on: one row per leg, and below them the profile the legs generate.
class MissionLegList extends ConsumerWidget {
  const MissionLegList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only what the card shows or checks: the route, the profile it
    // generated, and the plan fields the plan check reads (mode, tanks).
    final (mission, segments) = ref.watch(
      divePlanNotifierProvider.select((s) => (s.mission, s.segments)),
    );
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
        notifier.editMission((m) => MissionEdits.updateLeg(m, edited));
      }
    }

    // A new leg is added on Save, so an unfinished one never blanks the
    // profile of a route that works.
    Future<void> addLeg() async {
      final draft = MissionEdits.addLeg(mission, const Uuid().v4()).legs.last;
      final added = await showMissionLegEditor(
        context,
        leg: draft,
        openWater: openWater,
        units: units,
      );
      if (added == null) return;
      notifier.editMission(
        (m) => MissionEdits.updateLeg(MissionEdits.addLeg(m, added.id), added),
      );
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
                  onPressed: addLeg,
                ),
              ],
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mission.legs.length,
              // The default desktop handle is drawn over the row's trailing
              // edge, on top of the delete button; this row places its own.
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) => notifier.editMission(
                (m) => MissionEdits.reorderLegs(m, oldIndex, newIndex),
              ),
              itemBuilder: (context, index) {
                final leg = mission.legs[index];
                // Long-press drags the row on touch; the handle drags it
                // anywhere.
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(leg.id),
                  index: index,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      missionLegName(l10n, leg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Up to three lines (summary, own current, shore exit),
                    // all shown.
                    subtitle: Text(_legSubtitle(context, leg, mission, units)),
                    onTap: () => edit(leg),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          tooltip: l10n.plannerMission_route_deleteLeg,
                          onPressed: () => notifier.editMission(
                            (m) => MissionEdits.removeLeg(m, leg.id),
                          ),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle, size: 18),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            _GeneratedProfileStrip(
              segments: segments,
              units: units,
              issues: [
                for (final issue in ref.watch(missionBlockingIssuesProvider))
                  missionIssueText(l10n, issue, mission),
              ],
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
      // Generated l10n methods take placeholders in alphabetical order, not
      // sentence order: depth, distance, heading.
      l10n.plannerMission_route_legSummary(
        units.distance(leg.depthM),
        units.distance(leg.distanceM),
        units.heading(leg.headingDeg),
      ),
      if (leg.current != null)
        l10n.plannerMission_route_ownCurrent(
          units.heading(leg.current!.setsTowardDeg),
          units.speed(leg.current!.speedMps),
        ),
      if (leg.shoreExit != null)
        l10n.plannerMission_route_shoreExit(
          units.distance(leg.shoreExit!.surfaceSwimM),
          units.distance(leg.shoreExit!.walkM),
        ),
    ];
    return lines.join('\n');
  }
}

class _GeneratedProfileStrip extends StatelessWidget {
  const _GeneratedProfileStrip({
    required this.segments,
    required this.units,
    required this.issues,
  });

  final List<PlanSegment> segments;
  final MissionUnits units;

  /// Blocking issues as sentences. With no profile the first says why; with
  /// one (a plan-level issue, or a later leg the current blocks) each is a
  /// note under it.
  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final noteStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );
    if (segments.isEmpty && issues.isNotEmpty) {
      return Text(
        l10n.plannerMission_profile_none(issues.first),
        style: noteStyle,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Read-only: the diver sees exactly what the engine is fed.
        ExpansionTile(
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
                  l10n.plannerMission_profile_segment(
                    units.distance(segment.targetDepth),
                    (segment.durationSeconds / 60).ceil().toString(),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
        for (final issue in issues) Text(issue, style: noteStyle),
      ],
    );
  }
}
