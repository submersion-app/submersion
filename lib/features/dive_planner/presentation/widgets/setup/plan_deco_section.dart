import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_air_breaks_control.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_last_stop_selector.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Deco settings for the Setup accordion: gradient factors and the last stop
/// depth; the deco-model radio (Buhlmann / VPM-B / Recreational) lands here
/// in later phases (spec G1/G2).
class PlanDecoSection extends ConsumerWidget {
  const PlanDecoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final notifier = ref.read(divePlanNotifierProvider.notifier);
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GfField(
          label: context.l10n.divePlanner_label_gfLow,
          value: planState.gfLow,
          hintValue: ref.watch(gfLowProvider),
          onChanged: (value) =>
              notifier.updateGradientFactors(value, planState.gfHigh),
        ),
        _GfField(
          label: context.l10n.divePlanner_label_gfHigh,
          value: planState.gfHigh,
          hintValue: ref.watch(gfHighProvider),
          onChanged: (value) =>
              notifier.updateGradientFactors(planState.gfLow, value),
        ),
        const SizedBox(height: 8),
        PlanLastStopSelector(
          value: planState.lastStopDepth,
          defaultValueMeters: ref.watch(lastStopDepthProvider),
          units: units,
          onChanged: notifier.updateLastStopDepth,
        ),
        const SizedBox(height: 8),
        PlanAirBreaksControl(
          policy: planState.airBreaks,
          explicitlyOff: planState.airBreaksExplicitlyOff,
          defaultPolicy: ref.watch(plannerAirBreakPolicyProvider),
          onChanged: (policy, {required explicitlyOff}) =>
              notifier.setAirBreaks(policy, explicitlyOff: explicitlyOff),
        ),
      ],
    );
  }
}

/// One gradient factor as a whole percentage, on the same two columns as
/// every other planner number box.
class _GfField extends StatelessWidget {
  const _GfField({
    required this.label,
    required this.value,
    required this.hintValue,
    required this.onChanged,
  });

  final String label;

  /// The plan's own override; null = follows [hintValue] (issue #3552).
  final int? value;

  /// The diver's Settings default, shown as the field's placeholder.
  final int hintValue;

  /// Receives the new override, or null when the field is cleared.
  final ValueChanged<int?> onChanged;

  // Buhlmann gradient factors are a percentage of the M-value line; below 10%
  // the schedule stops being divable and above 100% it is no longer a
  // gradient factor at all.
  static const _min = 10.0;
  static const _max = 100.0;

  @override
  Widget build(BuildContext context) {
    return PlanNumberField(
      label: label,
      value: value?.toDouble(),
      hintValue: hintValue.toDouble(),
      suffixText: '%',
      isInteger: true,
      min: _min,
      max: _max,
      semanticsLabel: '$label (${value ?? hintValue}%)',
      onChanged: (v) => onChanged(v?.round()),
    );
  }
}
