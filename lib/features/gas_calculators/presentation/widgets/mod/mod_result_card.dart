import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/gas_limits.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/mod_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The headline MOD, rounded down, and the limits that go with it: the
/// contingency or deco MOD, the hypoxic minimum depth and the MND.
class ModResultCard extends ConsumerWidget {
  const ModResultCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final onContainer = colorScheme.onPrimaryContainer;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final result = ref.watch(modCalculatorResultProvider);
    final endLimit = settings.endLimit;

    // The headline and its other-unit echo are both floored, so neither can
    // read deeper than the gas may be taken.
    final isMetric = settings.depthUnit == DepthUnit.meters;
    final headline = formatFixedForDisplay(
      floorToFractionDigits(units.convertDepth(result.modMeters), 1),
      1,
    );
    final otherUnit = isMetric
        ? '${floorToFractionDigits(result.modMeters * 3.28084, 0).toStringAsFixed(0)} ft'
        : '${floorToFractionDigits(result.modMeters, 0).toStringAsFixed(0)} m';

    final title = result.mode == ModCalculatorMode.ccrTec
        ? l10n.gasCalculators_mod_diluentMod
        : l10n.gasCalculators_mod_maximumOperatingDepth;

    final rows = <(String, String)>[
      if (result.secondaryModMeters != null)
        (
          result.mode == ModCalculatorMode.rec
              ? l10n.gasCalculators_mod_contingencyMod(
                  formatFixedForDisplay(result.secondaryPpO2!, 2),
                )
              : l10n.gasCalculators_mod_decoMod(
                  formatFixedForDisplay(result.secondaryPpO2!, 2),
                ),
          units.formatDepthFloor(result.secondaryModMeters),
        ),
      if (result.minDepthMeters != null)
        (
          l10n.gasCalculators_mod_minDepth(
            formatFixedForDisplay(
              ref.watch(modCalculatorNotifierProvider).minPpO2,
              2,
            ),
          ),
          result.minDepthMeters! > 0
              // A minimum depth errs deep: rounded up, never shallower.
              ? units.formatDepth(
                  _ceilToTenth(result.minDepthMeters!, units),
                  decimals: 1,
                )
              : l10n.gasCalculators_mod_fromSurface,
        ),
      if (result.mode != ModCalculatorMode.rec)
        (
          l10n.gasCalculators_mod_mnd(units.formatDepth(endLimit, decimals: 0)),
          result.mndMeters == null
              ? l10n.gasCalculators_mod_noNarcoticLimit
              : units.formatDepthFloor(result.mndMeters),
        ),
    ];

    return Semantics(
      label: l10n.gasCalculators_mod_semanticsLabel(
        headline,
        units.depthSymbol,
        formatFixedForDisplay(result.modPpO2, 2),
        formatFixedForDisplay(result.o2Percent, 0),
      ),
      child: Card(
        color: colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              ExcludeSemantics(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: onContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '$headline ${units.depthSymbol}',
                      style: textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: onContainer,
                      ),
                    ),
                    Text(
                      '($otherUnit)',
                      style: textTheme.titleMedium?.copyWith(
                        color: onContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: textTheme.bodyMedium?.copyWith(
                              color: onContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          value,
                          style: textTheme.titleSmall?.copyWith(
                            color: onContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// [meters] rounded UP to a tenth of the display unit, returned in meters.
  static double _ceilToTenth(double meters, UnitFormatter units) {
    final display = units.convertDepth(meters);
    final ceiled = -floorToFractionDigits(-display, 1);
    return units.depthToMeters(ceiled);
  }
}
