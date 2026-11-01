import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Switches the chart between the live loop plan and the worst-case bailout
/// picture: one chip per picture, the active one emphasized, same
/// selection style as the Base/+depth/+time contingency chips right next
/// to it. Hidden for an OC plan or a loop plan with nothing to bail out
/// to (no bailout-role tank carried), from [planMayHaveBailoutProvider], which
/// holds the chips in place while [planBailoutProvider] computes. Also hidden
/// when no carried bailout gas reaches the plan, which leaves no valid ascent
/// to show (#3961), unless the chart is already on it. Every loop mode (CCR,
/// SCR, pSCR) shares this toggle (issue #3743): the bailout picture is
/// computed for any of them, not CCR alone.
class ChartModeToggle extends ConsumerWidget {
  const ChartModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    if (!ref.watch(planMayHaveBailoutProvider)) return const SizedBox.shrink();
    final bailout = planResultView(ref.watch(planBailoutProvider), state.id);
    if (bailout.isFinishedEmpty) return const SizedBox.shrink();

    final mode = ref.watch(chartDisplayModeProvider);
    // A diver already in Bailout view keeps the chips: the selection survives
    // an edit, and they are the only way back to the loop view. A failed run
    // keeps its last value, which says nothing about the plan as it is now.
    if (bailout.status != PlanResultStatus.failed &&
        bailout.value?.gasGap != null &&
        mode != ChartDisplayMode.bailout) {
      return const SizedBox.shrink();
    }

    Widget chip(ChartDisplayMode value, String label) => InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ref.read(chartDisplayModeProvider.notifier).state = value,
      child: PlanChip(label: label, emphasized: mode == value),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(
          ChartDisplayMode.ccr,
          // pSCR is a semi-closed loop too, so it reads as SCR here.
          state.mode == PlanMode.ccr
              ? context.l10n.plannerCanvas_chartMode_ccr
              : context.l10n.plannerCanvas_chartMode_scr,
        ),
        const SizedBox(width: 6),
        chip(
          ChartDisplayMode.bailout,
          context.l10n.plannerCanvas_chartMode_bailout,
        ),
      ],
    );
  }
}
