import 'package:flutter/material.dart';

import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/loop_flow_summary.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The plan's own constant mass flow loop (issue #4660): the supply injection
/// rate and the diver's VO2, in the diver's volume unit per minute.
///
/// Like the CCR setpoints, an empty box follows the diver's Settings default,
/// shown as its hint, and a typed value overrides it for this plan only. A
/// loop check under the boxes shows the loop O2 those values give.
class ScrSettingsSection extends ConsumerWidget {
  const ScrSettingsSection({super.key});

  // Below this width the two fields no longer fit their label without
  // truncating it, so they stack instead (as CcrSettingsSection does).
  static const double _narrowBreakpoint = 360;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = ref.watch(unitFormatterProvider);
    // The diver's defaults for the hints, and what the plan resolves to (its
    // own value, else the default) for the loop line, as the engine reads it.
    final diver = ref.watch(planEngineConfigProvider);
    final plan = planForEngine(state);
    final resolved = diver.resolvedFor(plan);
    final defaultRate = diver.scrInjectionRateLpm;
    final defaultVo2 = diver.scrVo2Lpm;

    double? shown(double? liters) =>
        liters == null ? null : units.convertRmv(liters);
    double? stored(double? entered) =>
        entered == null ? null : units.volumeToLiters(entered);

    final fields = [
      PlanNumberField(
        label: context.l10n.plannerCanvas_scr_injectionRate,
        value: shown(state.scrInjectionRate),
        hintValue: units.convertRmv(defaultRate),
        suffixText: units.rmvSymbol,
        decimals: units.loopFlowDecimals,
        min: units.convertRmv(ScrCalculator.minLoopFlowLpm),
        onChanged: (v) => notifier.updateLoopFlow(
          scrInjectionRate: stored(v),
          clearScrInjectionRate: v == null,
        ),
      ),
      PlanNumberField(
        label: context.l10n.plannerCanvas_scr_vo2,
        value: shown(state.scrVo2),
        hintValue: units.convertRmv(defaultVo2),
        suffixText: units.rmvSymbol,
        // A fourth cuft/min place would not fit the shared number box.
        decimals: units.loopFlowDecimals,
        min: units.convertRmv(ScrCalculator.minLoopFlowLpm),
        onChanged: (v) =>
            notifier.updateLoopFlow(scrVo2: stored(v), clearScrVo2: v == null),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < _narrowBreakpoint) {
                return Column(
                  children: [
                    for (final (index, f) in fields.indexed) ...[
                      if (index > 0) const SizedBox(height: 8),
                      f,
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (final (index, f) in fields.indexed) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(child: f),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          LoopFlowSummary(
            injectionRateLpm: resolved.scrInjectionRateLpm,
            vo2Lpm: resolved.scrVo2Lpm,
            supply: loopSupplyGas(plan),
          ),
        ],
      ),
    );
  }
}
