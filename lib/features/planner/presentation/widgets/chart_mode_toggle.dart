import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Switches the chart between the live CCR plan and the worst-case bailout
/// picture. Hidden for an OC plan or a CCR plan with nothing to bail out to
/// (no bailout-role tank carried), same gate [planBailoutProvider] already
/// uses. The button itself names the OTHER picture, not the current one --
/// tapping it moves forward, so it reads like every other mode switch in the
/// app (a Settings toggle shown as what tapping it turns ON, not what it
/// currently is).
class ChartModeToggle extends ConsumerWidget {
  const ChartModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    if (state.mode != PlanMode.ccr) return const SizedBox.shrink();
    final bailout = ref.watch(planBailoutProvider);
    if (bailout == null) return const SizedBox.shrink();

    final mode = ref.watch(chartDisplayModeProvider);
    final showingBailout = mode == ChartDisplayMode.bailout;
    final label = showingBailout
        ? context.l10n.plannerCanvas_chartMode_showCcr
        : context.l10n.plannerCanvas_chartMode_showBailout;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        ref.read(chartDisplayModeProvider.notifier).state = showingBailout
            ? ChartDisplayMode.ccr
            : ChartDisplayMode.bailout;
      },
      child: PlanChip(label: label, emphasized: showingBailout),
    );
  }
}
