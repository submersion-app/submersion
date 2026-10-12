import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Switches the chart between the live CCR plan and the worst-case bailout
/// picture: one chip per picture, the active one emphasized, same
/// selection style as the Base/+depth/+time contingency chips right next
/// to it. Hidden for an OC plan or a CCR plan with nothing to bail out to
/// (no bailout-role tank carried), same gate [planBailoutProvider] already
/// uses.
class ChartModeToggle extends ConsumerWidget {
  const ChartModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    if (state.mode != PlanMode.ccr) return const SizedBox.shrink();
    final bailout = ref.watch(planBailoutProvider);
    if (bailout == null) return const SizedBox.shrink();

    final mode = ref.watch(chartDisplayModeProvider);

    Widget chip(ChartDisplayMode value, String label) => InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ref.read(chartDisplayModeProvider.notifier).state = value,
      child: PlanChip(label: label, emphasized: mode == value),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(ChartDisplayMode.ccr, context.l10n.plannerCanvas_chartMode_ccr),
        const SizedBox(width: 6),
        chip(
          ChartDisplayMode.bailout,
          context.l10n.plannerCanvas_chartMode_bailout,
        ),
      ],
    );
  }
}
