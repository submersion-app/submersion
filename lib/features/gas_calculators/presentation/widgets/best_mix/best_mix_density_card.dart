import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix_calculator_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/gas_density_calculator.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_formatting.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The optional density-aware helium switch, plus temperature and water
/// type. Tec modes only; Rec never shows this card.
class BestMixDensityCard extends ConsumerWidget {
  const BestMixDensityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final prefs = ref.watch(bestMixCalculatorNotifierProvider);
    final notifier = ref.read(bestMixCalculatorNotifierProvider.notifier);
    final inputs = prefs.inputsFor(prefs.mode);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gasCalculators_bestMix_densityLabel,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.gasCalculators_bestMix_densityAware),
              value: inputs.densityAware,
              onChanged: notifier.setDensityAware,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 32,
              runSpacing: 16,
              children: [
                BestMixLabelled(
                  label: l10n.gasCalculators_density_temperature,
                  child: SegmentedButton<GasDensityTemperature>(
                    segments: [
                      for (final option in GasDensityTemperature.values)
                        ButtonSegment(
                          value: option,
                          label: Text(option.celsius.toStringAsFixed(0)),
                        ),
                    ],
                    selected: {prefs.temperature},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        notifier.setTemperature(selection.first),
                  ),
                ),
                BestMixLabelled(
                  label: l10n.decoCalculator_waterType,
                  child: SegmentedButton<WaterType>(
                    segments: [
                      for (final type
                          in BestMixCalculatorPreferences.waterTypes)
                        ButtonSegment(
                          value: type,
                          label: Text(type.localizedName(l10n)),
                        ),
                    ],
                    selected: {bestMixCalculatorWaterType(prefs, settings)},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        notifier.setWaterType(selection.first),
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
