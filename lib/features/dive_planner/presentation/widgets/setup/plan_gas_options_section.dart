import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
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
          hintValue: units.convertRmv(15),
          suffixText: units.rmvSymbol,
          // Same precision as Bottom RMV: 2 decimals for cuft/min (#1823).
          decimals: units.rmvDecimals,
          onChanged: (value) => notifier.updateGasOptions(
            sacDeco: value != null ? units.volumeToLiters(value) : null,
            clearSacDeco: value == null,
          ),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_sacFactor,
          value: state.sacFactor,
          hintValue: 2.0,
          suffixText: '×',
          decimals: 1,
          onChanged: (value) =>
              notifier.updateGasOptions(sacFactor: value ?? 2.0),
        ),
        PlanNumberField(
          label: context.l10n.divePlanner_gasOptions_problemSolvingMinutes,
          value: state.problemSolvingMinutes.toDouble(),
          hintValue: 2,
          suffixText: context.l10n.divePlanner_label_minutesUnit,
          isInteger: true,
          onChanged: (value) => notifier.updateGasOptions(
            problemSolvingMinutes: (value ?? 2).round(),
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
          value: units.convertDepth(state.bestMixEndMeters),
          hintValue: units.convertDepth(30.0),
          suffixText: units.depthSymbol,
          decimals: 0,
          onChanged: (value) => notifier.updateGasOptions(
            bestMixEndMeters: units.depthToMeters(
              value ?? units.convertDepth(30.0),
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.divePlanner_gasOptions_o2Narcotic),
          value: state.o2Narcotic ?? settings.o2Narcotic,
          onChanged: (value) => notifier.updateGasOptions(o2Narcotic: value),
        ),
      ],
    );
  }
}
