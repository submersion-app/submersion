import 'package:flutter/material.dart';

import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_formatting.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The helium-free alternative, shown only when helium was added to the
/// recommendation, so the trade-off stays visible rather than implied.
class BestMixAlternativeCard extends ConsumerWidget {
  const BestMixAlternativeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(bestMixCalculatorResultProvider);
    final alternative = result.nitroxAlternative;
    if (alternative == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ppO2 = result.limitPpO2;
    final endLimitMeters = ref
        .watch(bestMixCalculatorInputsProvider)
        .endLimitMeters;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.gasCalculators_bestMix_withoutHelium,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  alternative.mix.name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            bestMixBreakdownRow(
              context,
              l10n.gasCalculators_bestMix_modLabel(ppO2.toStringAsFixed(1)),
              units.formatDepthFloor(alternative.modMeters, decimals: 0),
            ),
            bestMixBreakdownRow(
              context,
              l10n.gasCalculators_bestMix_endLabel,
              units.formatDepth(alternative.endMeters, decimals: 0),
            ),
            bestMixBreakdownRow(
              context,
              l10n.gasCalculators_bestMix_densityLabel,
              '${alternative.densityGPerL.toStringAsFixed(1)} g/L',
            ),
            if (alternative.exceedsEndLimit)
              bestMixFlag(
                context,
                l10n.gasCalculators_bestMix_endExceeded(
                  units.formatDepth(endLimitMeters, decimals: 0),
                ),
                colorScheme.tertiary,
              ),
            if (alternative.exceedsCriticalDensity)
              bestMixFlag(
                context,
                l10n.gasCalculators_bestMix_densityCritical(
                  gasDensityCriticalGPerL.toStringAsFixed(1),
                ),
                colorScheme.error,
              )
            else if (alternative.exceedsWarnDensity)
              bestMixFlag(
                context,
                l10n.gasCalculators_bestMix_densityWarn(
                  gasDensityWarnGPerL.toStringAsFixed(1),
                ),
                colorScheme.tertiary,
              ),
          ],
        ),
      ),
    );
  }
}
