import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';

/// Panel for configuring dive plan settings (GF, SAC, site).
class PlanSettingsPanel extends ConsumerWidget {
  const PlanSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(divePlanNotifierProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.settings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Plan Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gradient factors row
            Row(
              children: [
                Expanded(
                  child: _GfSlider(
                    label: 'GF Low',
                    value: planState.gfLow,
                    onChanged: (value) {
                      ref
                          .read(divePlanNotifierProvider.notifier)
                          .updateGradientFactors(value, planState.gfHigh);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _GfSlider(
                    label: 'GF High',
                    value: planState.gfHigh,
                    onChanged: (value) {
                      ref
                          .read(divePlanNotifierProvider.notifier)
                          .updateGradientFactors(planState.gfLow, value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SAC rate
            Row(
              children: [
                const Text('SAC Rate:'),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: planState.sacRate,
                    min: 8,
                    max: 30,
                    divisions: 22,
                    label:
                        '${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol}/min',
                    onChanged: (value) {
                      ref
                          .read(divePlanNotifierProvider.notifier)
                          .updateSacRate(value);
                    },
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${planState.sacRate.toStringAsFixed(0)} ${units.volumeSymbol}/min',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
              child: Slider(
                value: value.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                label: '$value%',
                onChanged: (v) => onChanged(v.round()),
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
