import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Selector for the ghosted contingency: Base / +depth / +time / both.
/// Hidden when the plan has no segments; the two time chips are hidden while
/// the plan has no bottom to lengthen.
class ContingencyChips extends ConsumerWidget {
  const ContingencyChips({super.key, this.overlay = false});

  /// Compact single-row on-chart styling for the phone layout: a scrimmed
  /// horizontal strip instead of a wrapping row of bare chips.
  final bool overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canLengthen = ref.watch(planCanLengthenProvider);
    final rawSelected = ref.watch(selectedDeviationProvider);
    // SelectedDeviationNotifier drops a time selection once the plan loses
    // its bottom; until it has, that selection reads as Base here rather
    // than as no chip at all.
    final staleTimeSelection =
        !canLengthen && rawSelected != null && rawSelected != 'deeper';
    final state = ref.watch(divePlanNotifierProvider);
    if (state.segments.isEmpty) return const SizedBox.shrink();
    final selected = staleTimeSelection ? null : rawSelected;
    final units = ref.watch(unitFormatterProvider);

    // The plan's own deviation, else the diver's Settings default (#3552).
    final resolved = ref.watch(resolvedPlanEngineConfigProvider);
    final depthLabel =
        '+${units.formatDepth(resolved.deviationDepthDelta, decimals: 0)}';
    final timeLabel = '+${resolved.deviationTimeMinutes}′';

    void select(String? key) {
      ref.read(selectedDeviationProvider.notifier).select(key);
      // Only one contingency ghost can be on the chart at a time.
      if (key != null) {
        ref.read(selectedLostGasTankIdProvider.notifier).state = null;
      }
    }

    Widget chip(String? key, String label) => InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => select(key),
      child: PlanChip(label: label, emphasized: selected == key),
    );

    final chips = [
      chip(null, context.l10n.plannerCanvas_contingency_base),
      chip('deeper', depthLabel),
      if (canLengthen) ...[
        chip('longer', timeLabel),
        chip('both', '$depthLabel $timeLabel'),
      ],
    ];

    if (!overlay) {
      return Wrap(spacing: 6, runSpacing: 6, children: chips);
    }

    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < chips.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              chips[i],
            ],
          ],
        ),
      ),
    );
  }
}
