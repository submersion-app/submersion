import 'package:flutter/material.dart';

import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/best_mix/best_mix_formatting.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The recommended mix and its breakdown: ideal fraction, MOD, margin,
/// END (and, outside Rec, EAD), density, and why helium was added.
class BestMixResultCard extends ConsumerWidget {
  const BestMixResultCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final prefs = ref.watch(bestMixCalculatorNotifierProvider);
    final result = ref.watch(bestMixCalculatorResultProvider);
    final limits = ref.watch(bestMixCalculatorLimitsProvider);
    final inputs = prefs.inputsFor(prefs.mode);
    final recommended = result.recommended;
    final ppO2 = switch (prefs.mode) {
      BestMixMode.rec => inputs.recPpO2,
      BestMixMode.ocTec => limits.workingPpO2,
      BestMixMode.ccrTec =>
        prefs.ccrSource == CcrGasSource.diluent
            ? limits.flushPpO2
            : limits.workingPpO2,
    };

    return Semantics(
      label:
          'Recommended mix ${recommended.mix.name}, '
          'MOD ${units.formatDepthFloor(recommended.modMeters, decimals: 0)}',
      child: Card(
        color: colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                l10n.gasCalculators_bestMix_recommendedMix,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                recommended.mix.name,
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              bestMixBreakdownRow(
                context,
                l10n.gasCalculators_bestMix_idealLabel,
                '${result.idealO2Percent.toStringAsFixed(1)}%',
                onContainer: true,
              ),
              bestMixBreakdownRow(
                context,
                l10n.gasCalculators_bestMix_modLabel(ppO2.toStringAsFixed(1)),
                units.formatDepthFloor(recommended.modMeters, decimals: 0),
                onContainer: true,
              ),
              bestMixBreakdownRow(
                context,
                l10n.gasCalculators_bestMix_marginLabel,
                units.formatDepth(recommended.marginMeters, decimals: 0),
                onContainer: true,
              ),
              if (recommended.eadMeters != null)
                bestMixBreakdownRow(
                  context,
                  l10n.gasCalculators_bestMix_eadLabel,
                  units.formatDepth(recommended.eadMeters!, decimals: 0),
                  onContainer: true,
                ),
              bestMixBreakdownRow(
                context,
                l10n.gasCalculators_bestMix_endLabel,
                units.formatDepth(recommended.endMeters, decimals: 0),
                onContainer: true,
              ),
              bestMixBreakdownRow(
                context,
                l10n.gasCalculators_bestMix_densityLabel,
                '${recommended.densityGPerL.toStringAsFixed(1)} g/L',
                onContainer: true,
              ),
              if (recommended.mix.isTrimix) ...[
                const SizedBox(height: 8),
                Text(
                  switch (result.heliumDriver) {
                    HeliumDriver.density =>
                      l10n.gasCalculators_bestMix_heliumDensity,
                    HeliumDriver.both => l10n.gasCalculators_bestMix_heliumBoth,
                    HeliumDriver.endLimit || HeliumDriver.none =>
                      l10n.gasCalculators_bestMix_heliumAdded(
                        units.formatDepth(settings.endLimit, decimals: 0),
                      ),
                  },
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
              ],
              if (recommended.exceedsCriticalDensity)
                bestMixFlag(
                  context,
                  l10n.gasCalculators_bestMix_densityCritical(
                    gasDensityCriticalGPerL.toStringAsFixed(1),
                  ),
                  colorScheme.error,
                )
              else if (recommended.exceedsWarnDensity)
                bestMixFlag(
                  context,
                  l10n.gasCalculators_bestMix_densityWarn(
                    gasDensityWarnGPerL.toStringAsFixed(1),
                  ),
                  colorScheme.tertiary,
                ),
              const SizedBox(height: 12),
              Text(
                l10n.gasCalculators_planningCaveat,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
