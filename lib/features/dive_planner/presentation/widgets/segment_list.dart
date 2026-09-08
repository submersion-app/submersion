import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_editor.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
import 'package:submersion/features/planner/domain/entities/segment_phase.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Widget for displaying and managing plan segments.
class SegmentList extends ConsumerWidget {
  const SegmentList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    // Resolved once per build, not once per row. The state's list order is
    // the authoring order (stateFromDivePlan sorts, and the notifier keeps
    // `order` in step with the list), which is what SegmentChain chains.
    final legs = const SegmentChain().resolve(planState.segments);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.timeline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.divePlanner_segmentList_title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: context.l10n.divePlanner_segmentList_addSegment,
                  onPressed: () => _showAddSegmentDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (planState.segments.isEmpty)
              _EmptyState(
                onAddSimplePlan: () => _showSimplePlanDialog(context, ref),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: planState.segments.length,
                onReorderItem: (oldIndex, newIndex) {
                  ref
                      .read(divePlanNotifierProvider.notifier)
                      .reorderSegments(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final leg = legs[index];
                  final segment = leg.segment;
                  return _SegmentTile(
                    key: ValueKey(segment.id),
                    leg: leg,
                    // A gas switch is not a segment: it is this leg
                    // breathing a different tank than the one before it.
                    switchedGas:
                        index > 0 && legs[index - 1].tankId != leg.tankId,
                    units: units,
                    index: index,
                    selected:
                        ref.watch(selectedSegmentIdProvider) == segment.id,
                    onSelect: () =>
                        ref.read(selectedSegmentIdProvider.notifier).state =
                            segment.id,
                    onEdit: () => _showEditSegmentDialog(context, ref, segment),
                    onDelete: () => ref
                        .read(divePlanNotifierProvider.notifier)
                        .removeSegment(segment.id),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showAddSegmentDialog(BuildContext context, WidgetRef ref) {
    final planState = ref.read(divePlanNotifierProvider);
    final startDepth = planState.segments.isEmpty
        ? 0.0
        : planState.segments.last.targetDepth;

    showDialog(
      context: context,
      builder: (context) => SegmentEditor(
        startDepth: startDepth,
        availableTanks: planState.tanks,
        onSave: (segment) {
          ref.read(divePlanNotifierProvider.notifier).addSegment(segment);
        },
      ),
    );
  }

  void _showEditSegmentDialog(
    BuildContext context,
    WidgetRef ref,
    PlanSegment segment,
  ) {
    final planState = ref.read(divePlanNotifierProvider);
    // The edit dialog needs the same resolved start depth the profile gives
    // this segment; the old code passed none, so editing showed 0 m.
    final index = planState.segments.indexWhere((s) => s.id == segment.id);
    final startDepth = index > 0
        ? planState.segments[index - 1].targetDepth
        : 0.0;

    showDialog(
      context: context,
      builder: (context) => SegmentEditor(
        segment: segment,
        startDepth: startDepth,
        availableTanks: planState.tanks,
        onSave: (updated) {
          ref
              .read(divePlanNotifierProvider.notifier)
              .updateSegment(segment.id, updated);
        },
      ),
    );
  }

  void _showSimplePlanDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const SimplePlanDialog(),
    );
  }
}

class _SegmentTile extends StatelessWidget {
  final ResolvedLeg leg;
  final bool switchedGas;
  final UnitFormatter units;
  final int index;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SegmentTile({
    super.key,
    required this.leg,
    required this.switchedGas,
    required this.units,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  PlanSegment get segment => leg.segment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Edit/delete are pinned to the tile's top-right corner with a Positioned
    // overlay rather than laid out inside ListTile's title: ListTile centers
    // a custom title widget as one block, so a Row placed there drifted away
    // from the corner instead of landing flush against it. The overlay's
    // right inset matches contentPadding's, so the buttons align with the
    // trailing drag handle below them. The description reserves the same
    // width so it wraps around the buttons instead of under them.
    const compactButton = BoxConstraints.tightFor(width: 28, height: 28);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, size: 16),
          padding: EdgeInsets.zero,
          constraints: compactButton,
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.divePlanner_segmentList_editSegment,
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete, size: 16),
          padding: EdgeInsets.zero,
          constraints: compactButton,
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.divePlanner_segmentList_deleteSegment,
          onPressed: onDelete,
        ),
      ],
    );

    return Stack(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 8),
          horizontalTitleGap: 10,
          selected: selected,
          selectedTileColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.35,
          ),
          onTap: onSelect,
          leading: _SegmentIcon(phase: leg.phase),
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, size: 18),
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 64),
            child: Text(
              _formatDescription(context.l10n),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          subtitle: Text(
            _formatSubtitle(context.l10n),
            style: theme.textTheme.bodySmall,
          ),
        ),
        Positioned(top: 6, right: 8, child: actions),
      ],
    );
  }

  /// Duration, runtime and gas.
  ///
  /// Runtime is the slate's RT column: elapsed dive time at the end of this
  /// leg, so the diver can read off when they leave each depth without adding
  /// the durations up in their head. Ceiled to whole minutes to match the
  /// computed deco schedule's RT column.
  String _formatSubtitle(AppLocalizations l10n) {
    final runtime = (leg.runtimeSeconds / 60).ceil();
    final rt = '${l10n.plannerCanvas_table_runtime} $runtime\u2032';
    final gas = switchedGas
        ? l10n.divePlanner_segmentList_gasSwitch(segment.gasMix.name)
        : segment.gasMix.name;
    return '${segment.durationFormatted} • $rt • $gas';
  }

  /// Format the leg description with proper unit settings.
  ///
  /// Four cases, from the derived phase, where there used to be six from a
  /// declared type. A flat leg reads as the bottom or as a stop depending on
  /// where it sits in the profile, which is the chain's call.
  String _formatDescription(AppLocalizations l10n) {
    final startDepth = units.formatDepth(leg.startDepth);
    final endDepth = units.formatDepth(leg.endDepth);
    final durationMin = leg.durationSeconds ~/ 60;

    return switch (leg.phase) {
      SegmentPhase.descent => l10n.divePlanner_segmentList_descent(
        startDepth,
        endDepth,
      ),
      SegmentPhase.level => l10n.divePlanner_segmentList_bottom(
        endDepth,
        durationMin,
      ),
      SegmentPhase.ascent => l10n.divePlanner_segmentList_ascent(
        startDepth,
        endDepth,
      ),
      SegmentPhase.stop => l10n.divePlanner_segmentList_deco(
        endDepth,
        durationMin,
      ),
    };
  }
}

class _SegmentIcon extends StatelessWidget {
  final SegmentPhase phase;

  const _SegmentIcon({required this.phase});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (IconData icon, Color color) = switch (phase) {
      SegmentPhase.descent => (Icons.arrow_downward, Colors.blue),
      SegmentPhase.level => (Icons.horizontal_rule, theme.colorScheme.primary),
      SegmentPhase.ascent => (Icons.arrow_upward, Colors.green),
      SegmentPhase.stop => (Icons.stop_circle, Colors.orange),
    };

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.2),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddSimplePlan;

  const _EmptyState({required this.onAddSimplePlan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.scuba_diving,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.divePlanner_segmentList_emptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.divePlanner_segmentList_emptyMessage,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddSimplePlan,
              icon: const Icon(Icons.add_chart),
              label: Text(context.l10n.divePlanner_segmentList_quickPlan),
            ),
          ],
        ),
      ),
    );
  }
}
