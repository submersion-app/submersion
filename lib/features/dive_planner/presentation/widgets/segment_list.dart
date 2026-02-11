import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_editor.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/simple_plan_dialog.dart';
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
                Text(
                  context.l10n.divePlanner_segmentList_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
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
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(divePlanNotifierProvider.notifier)
                      .reorderSegments(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final segment = planState.segments[index];
                  return _SegmentTile(
                    key: ValueKey(segment.id),
                    segment: segment,
                    units: units,
                    index: index,
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

    showDialog(
      context: context,
      builder: (context) => SegmentEditor(
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

    showDialog(
      context: context,
      builder: (context) => SegmentEditor(
        segment: segment,
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
  final PlanSegment segment;
  final UnitFormatter units;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SegmentTile({
    super.key,
    required this.segment,
    required this.units,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: _SegmentIcon(type: segment.type),
      title: Text(_formatDescription()),
      subtitle: Text(
        '${segment.durationFormatted} • ${segment.gasMix.name}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: context.l10n.divePlanner_segmentList_editSegment,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            tooltip: context.l10n.divePlanner_segmentList_deleteSegment,
            onPressed: onDelete,
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
        ],
      ),
    );
  }

  /// Format the segment description with proper unit settings.
  String _formatDescription() {
    final startDepth = units.formatDepth(segment.startDepth);
    final endDepth = units.formatDepth(segment.endDepth);
    final durationMin = segment.durationSeconds ~/ 60;

    switch (segment.type) {
      case SegmentType.descent:
        return 'Descent $startDepth → $endDepth';
      case SegmentType.bottom:
        return 'Bottom $startDepth for $durationMin min';
      case SegmentType.ascent:
        return 'Ascent $startDepth → $endDepth';
      case SegmentType.decoStop:
        return 'Deco $startDepth for $durationMin min';
      case SegmentType.gasSwitch:
        return 'Gas switch to ${segment.gasMix.name}';
      case SegmentType.safetyStop:
        return 'Safety stop $startDepth for $durationMin min';
    }
  }
}

class _SegmentIcon extends StatelessWidget {
  final SegmentType type;

  const _SegmentIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    Color color;

    switch (type) {
      case SegmentType.descent:
        icon = Icons.arrow_downward;
        color = Colors.blue;
        break;
      case SegmentType.bottom:
        icon = Icons.horizontal_rule;
        color = theme.colorScheme.primary;
        break;
      case SegmentType.ascent:
        icon = Icons.arrow_upward;
        color = Colors.green;
        break;
      case SegmentType.decoStop:
        icon = Icons.stop_circle;
        color = Colors.orange;
        break;
      case SegmentType.gasSwitch:
        icon = Icons.swap_horiz;
        color = Colors.purple;
        break;
      case SegmentType.safetyStop:
        icon = Icons.pause_circle;
        color = Colors.teal;
        break;
    }

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
