import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Subsurface-style "Gas options" for the Setup accordion's gas tab: Deco
/// SAC, SAC factor, problem solving time, bottom/deco ppO2 ceilings, best-mix
/// END, and the O2-narcotic switch - all per-plan, sitting alongside the
/// existing Bottom SAC and reserve controls in [PlanGasSection].
///
/// Each ppO2/O2-narcotic field is a nullable override of the app-wide
/// setting: an empty field (or, for the switch, no explicit choice) falls
/// back to the diver's global default, shown as the field's placeholder.
class PlanGasOptionsSection extends ConsumerWidget {
  const PlanGasOptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(divePlanNotifierProvider);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final globalPpO2Working = ref.watch(ppO2MaxWorkingProvider);
    final globalPpO2Deco = ref.watch(ppO2MaxDecoProvider);
    // Typed so `??` does not infer the watch as nullable.
    final double bottomRmv =
        state.sacRate ?? ref.watch(plannerSacBottomProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          context.l10n.divePlanner_gasOptions_title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_sacDeco,
          value: state.sacDeco != null
              ? units.convertRmv(state.sacDeco!)
              : null,
          hintValue: units.convertRmv(ref.watch(plannerSacDecoProvider)),
          suffixText: units.rmvSymbol,
          // Same precision as Bottom RMV: 2 decimals for cuft/min (#1823).
          decimals: units.rmvDecimals,
          onChanged: (value) => notifier.updateGasOptions(
            sacDeco: value != null ? units.volumeToLiters(value) : null,
            clearSacDeco: value == null,
          ),
        ),
        PlanNumberField(
          // An absolute rate, matching what the plan stores (sacStressed):
          // a typed factor stored as an absolute value would drift from
          // what the diver typed as soon as bottom RMV changed. Unset, it
          // follows bottom RMV times the diver's Settings stressed factor,
          // which the hint shows resolved (issue #3552).
          label: context.l10n.divePlanner_gasOptions_sacStressed,
          value: state.sacStressed != null
              ? units.convertRmv(state.sacStressed!)
              : null,
          hintValue: units.convertRmv(
            bottomRmv * ref.watch(plannerSacStressedFactorProvider),
          ),
          suffixText: units.rmvSymbol,
          decimals: units.rmvDecimals,
          onChanged: (value) => notifier.updateGasOptions(
            sacStressed: value != null ? units.volumeToLiters(value) : null,
            clearSacStressed: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_sacFactor,
          value: state.sacFactor,
          hintValue: ref.watch(plannerBuddyFactorProvider),
          suffixText: '×',
          decimals: 1,
          onChanged: (value) => notifier.updateGasOptions(
            sacFactor: value,
            clearSacFactor: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_problemSolvingMinutes,
          value: state.problemSolvingMinutes?.toDouble(),
          hintValue: ref.watch(plannerProblemSolvingMinutesProvider).toDouble(),
          suffixText: context.l10n.divePlanner_label_minutesUnit,
          isInteger: true,
          onChanged: (value) => notifier.updateGasOptions(
            problemSolvingMinutes: value?.round(),
            clearProblemSolvingMinutes: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_gasSwitchStopSeconds,
          value: state.gasSwitchStopSeconds != null
              ? (state.gasSwitchStopSeconds! / 60).roundToDouble()
              : null,
          hintValue: (ref.watch(plannerGasSwitchStopSecondsProvider) / 60)
              .roundToDouble(),
          suffixText: context.l10n.divePlanner_label_minutesUnit,
          isInteger: true,
          onChanged: (value) => notifier.updateGasOptions(
            gasSwitchStopSeconds: value != null ? (value * 60).round() : null,
            clearGasSwitchStopSeconds: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_ppO2Bottom,
          value: state.ppO2Bottom,
          hintValue: globalPpO2Working,
          suffixText: 'bar',
          decimals: 2,
          onChanged: (value) => notifier.updateGasOptions(
            ppO2Bottom: value,
            clearPpO2Bottom: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_ppO2Deco,
          value: state.ppO2Deco,
          hintValue: globalPpO2Deco,
          suffixText: 'bar',
          decimals: 2,
          onChanged: (value) => notifier.updateGasOptions(
            ppO2Deco: value,
            clearPpO2Deco: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_bestMixEnd,
          value: state.bestMixEndMeters != null
              ? units.convertDepth(state.bestMixEndMeters!)
              : null,
          hintValue: units.convertDepth(
            ref.watch(plannerBestMixEndMetersProvider),
          ),
          suffixText: units.depthSymbol,
          decimals: 0,
          onChanged: (value) => notifier.updateGasOptions(
            bestMixEndMeters: value != null ? units.depthToMeters(value) : null,
            clearBestMixEndMeters: value == null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.divePlanner_gasOptions_o2Narcotic),
              const SizedBox(height: 6),
              // A Wrap of chips, not a SegmentedButton: see
              // PlanLastStopSelector's matching fix for the full reasoning.
              // Unlike a SegmentedButton, a Wrap can show the Default chip's
              // resolved value without risking it pushing another chip out
              // of view - a chip that does not fit just starts the next
              // line.
              PlanChoiceWrap<bool?>(
                options: [
                  (
                    null,
                    context.l10n.divePlanner_label_defaultWithValue(
                      settings.o2Narcotic
                          ? context.l10n.divePlanner_label_on
                          : context.l10n.divePlanner_label_off,
                    ),
                  ),
                  (true, context.l10n.divePlanner_label_on),
                  (false, context.l10n.divePlanner_label_off),
                ],
                selected: state.o2Narcotic,
                onChanged: (value) => notifier.updateGasOptions(
                  o2Narcotic: value,
                  clearO2Narcotic: value == null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
