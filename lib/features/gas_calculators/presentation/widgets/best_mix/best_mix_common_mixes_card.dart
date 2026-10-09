import 'package:flutter/material.dart';

import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart'
    show BestMixMode, CcrGasSource;
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The nearest standard mix advisory and a reference table of common mixes
/// with their MOD at the active ppO2 limit.
class BestMixCommonMixesCard extends ConsumerWidget {
  const BestMixCommonMixesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final result = ref.watch(bestMixCalculatorResultProvider);
    final prefs = ref.watch(bestMixCalculatorNotifierProvider);
    final limits = ref.watch(bestMixCalculatorLimitsProvider);
    final ppO2 = switch (prefs.mode) {
      BestMixMode.rec => prefs.rec.recPpO2,
      BestMixMode.ocTec => limits.workingPpO2,
      BestMixMode.ccrTec =>
        prefs.ccrSource == CcrGasSource.diluent
            ? limits.flushPpO2
            : limits.workingPpO2,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.gasCalculators_bestMix_commonMixesRef,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (result.nearestStandardMix != null)
              _row(
                context,
                l10n.gasCalculators_bestMix_nearestStandard,
                result.nearestStandardMix!.name,
                isHighlight: true,
              ),
            const SizedBox(height: 4),
            _mixRow(context, l10n.gas_air_displayName, 21, ppO2, units),
            _mixRow(context, 'EAN32', 32, ppO2, units),
            _mixRow(context, 'EAN36', 36, ppO2, units),
            _mixRow(context, 'EAN40', 40, ppO2, units),
            _mixRow(context, 'EAN50', 50, ppO2, units),
            _mixRow(context, l10n.gas_oxygen_displayName, 100, ppO2, units),
          ],
        ),
      ),
    );
  }

  Widget _mixRow(
    BuildContext context,
    String name,
    int o2,
    double ppO2Limit,
    UnitFormatter units,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // MOD rounds DOWN toward the shallower, safer limit.
    final displayMod = units.formatDepthFloor(
      maxOperatingDepthMeters(o2 / 100, maxPpO2: ppO2Limit),
      decimals: 0,
    );

    return Semantics(
      label: '$name, $o2% O2, MOD: $displayMod',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                name,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$o2% O₂',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              'MOD: $displayMod',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = isHighlight ? colorScheme.primary : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: isHighlight ? FontWeight.w600 : null,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
