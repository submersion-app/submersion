import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_last_stop_selector.dart';
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
        Row(
          children: [
            Expanded(
              child: _GfSlider(
                label: context.l10n.divePlanner_label_gfLow,
                value: planState.gfLow,
                onChanged: (value) =>
                    notifier.updateGradientFactors(value, planState.gfHigh),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _GfSlider(
                label: context.l10n.divePlanner_label_gfHigh,
                value: planState.gfHigh,
                onChanged: (value) =>
                    notifier.updateGradientFactors(planState.gfLow, value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PlanLastStopSelector(
          value: planState.lastStopDepth,
          units: units,
          onChanged: notifier.updateLastStopDepth,
        ),
      ],
    );
  }
}

class _GfSlider extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _GfSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label: '$label: $value%',
                child: Slider(
                  value: value.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  label: '$value%',
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
            ),
            SizedBox(
              width: 45,
              child: Text(
                '$value%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
