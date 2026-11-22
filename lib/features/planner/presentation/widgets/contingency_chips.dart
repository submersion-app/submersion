import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Contingency toggles for the chart: Base / +depth / +time / one chip per
/// losable cylinder. All but Base combine freely; Base clears them.
class ContingencyChips extends ConsumerWidget {
  const ContingencyChips({super.key, this.overlay = false});

  /// Compact single-row on-chart styling for the phone layout: a scrimmed
  /// horizontal strip instead of a wrapping row of bare chips.
  final bool overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    if (state.segments.isEmpty) return const SizedBox.shrink();
    final canLengthen = ref.watch(planCanLengthenProvider);
    final selection = ref.watch(contingencySelectionProvider);
    final losable = ref.watch(planLosableTanksProvider);
    final notifier = ref.read(contingencySelectionProvider.notifier);
    final units = ref.watch(unitFormatterProvider);

    // The plan's own deviation, else the diver's Settings default (#3552).
    final resolved = ref.watch(resolvedPlanEngineConfigProvider);
    final depthLabel =
        '+${units.formatDepth(resolved.deviationDepthDelta, decimals: 0)}';
    final timeLabel = '+${resolved.deviationTimeMinutes}′';

    // A lost id whose tank is gone or no longer losable has no chip, so it
    // must not keep Base dark either.
    final losableIds = {for (final t in losable) t.id};
    final lostOn = selection.lostTankIds.where(losableIds.contains).length;
    final anyOn = selection.deeper || selection.longer || lostOn > 0;
    // One more lost cylinder must still leave one to breathe.
    final canLoseAnother = state.tanks.length - lostOn > 1;

    Widget chip(String label, bool on, VoidCallback? onTap) => Semantics(
      selected: on,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: PlanChip(label: label, emphasized: on),
        ),
      ),
    );

    Widget lostChip(DiveTank tank) {
      final on = selection.lostTankIds.contains(tank.id);
      return chip(
        context.l10n.plannerCanvas_contingency_lostGas(tank.gasMix.name),
        on,
        on || canLoseAnother ? () => notifier.toggleLostGas(tank.id) : null,
      );
    }

    final chips = [
      chip(context.l10n.plannerCanvas_contingency_base, !anyOn, notifier.clear),
      chip(depthLabel, selection.deeper, notifier.toggleDeeper),
      if (canLengthen) chip(timeLabel, selection.longer, notifier.toggleLonger),
      for (final tank in losable) lostChip(tank),
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
