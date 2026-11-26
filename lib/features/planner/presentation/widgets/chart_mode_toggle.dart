import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Turns the chart's Bailout view on and off: one chip, emphasized while on,
/// the same as the contingency chips beside it (#5018). Off is the plan
/// itself, so it needs no chip of its own. Hidden for an OC plan or a loop
/// plan with nothing to bail out to (no bailout-role tank carried), from
/// [planMayHaveBailoutProvider], which holds the chip in place while
/// [planBailoutProvider] computes. Also hidden when no carried bailout gas
/// reaches the plan, which leaves no valid ascent to show (#3961), unless the
/// chart is already on it. Every loop mode (CCR, SCR, pSCR) shares this
/// toggle (issue #3743): the bailout picture is computed for any of them, not
/// CCR alone.
class ChartModeToggle extends ConsumerWidget {
  const ChartModeToggle({super.key, this.overlay = false});

  /// On the phone chart: on a scrim of its own, apart from the contingency
  /// strip, which it does not combine with.
  final bool overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    if (!ref.watch(planMayHaveBailoutProvider)) return const SizedBox.shrink();
    final bailout = planResultView(ref.watch(planBailoutProvider), state.id);
    if (bailout.isFinishedEmpty) return const SizedBox.shrink();

    final on = ref.watch(chartDisplayModeProvider) == ChartDisplayMode.bailout;
    // A diver already in Bailout view keeps the chip: the selection survives
    // an edit, and it is the only way back to the plan. A failed run keeps
    // its last value, which says nothing about the plan as it is now.
    if (bailout.status != PlanResultStatus.failed &&
        bailout.value?.gasGap != null &&
        !on) {
      return const SizedBox.shrink();
    }

    final chip = Semantics(
      selected: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ref.read(chartDisplayModeProvider.notifier).state = on
            ? ChartDisplayMode.ccr
            : ChartDisplayMode.bailout,
        child: PlanChip(
          label: context.l10n.plannerCanvas_chartMode_bailout,
          emphasized: on,
        ),
      ),
    );

    if (!overlay) return chip;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: chip,
    );
  }
}
