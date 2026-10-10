import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart'
    show environmentFor;
import 'package:submersion/features/gas_calculators/domain/standard_gas_mix.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/best_mix_calculator_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How many catalog entries show before "Show all" (issue #3117).
const int _collapsedMixCount = 6;

/// The nearest standard mix advisory, and a reference table of catalog
/// entries (issue #3117) whose MOD (and, for a trimix, END) cover the
/// target depth, nearest fit first. Collapsed to six by default, with a
/// toggle to show every covering entry.
class BestMixCommonMixesCard extends ConsumerStatefulWidget {
  const BestMixCommonMixesCard({super.key});

  @override
  ConsumerState<BestMixCommonMixesCard> createState() =>
      _BestMixCommonMixesCardState();
}

class _BestMixCommonMixesCardState
    extends ConsumerState<BestMixCommonMixesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final result = ref.watch(bestMixCalculatorResultProvider);
    final inputs = ref.watch(bestMixCalculatorInputsProvider);
    final environment = environmentFor(inputs);
    final mixes = result.standardMixes;
    final shown = _expanded ? mixes : mixes.take(_collapsedMixCount).toList();

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
                _displayName(l10n, result.nearestStandardMix!),
                isHighlight: true,
              ),
            const SizedBox(height: 4),
            for (final mix in shown)
              _mixRow(context, mix, units, result.limitPpO2, environment),
            if (mixes.length > _collapsedMixCount)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded
                        ? l10n.gasCalculators_bestMix_showFewerMixes
                        : l10n.gasCalculators_bestMix_showAllMixes(
                            mixes.length,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mixRow(
    BuildContext context,
    StandardGasMix mix,
    UnitFormatter units,
    double ppO2Limit,
    DiveEnvironment? environment,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = _displayName(context.l10n, mix);

    // MOD rounds DOWN toward the shallower, safer limit. Same ambient
    // model as `coveringStandardMixes` used to decide this entry covers
    // the target depth, so the displayed MOD never disagrees with it.
    final displayMod = units.formatDepthFloor(
      maxOperatingDepthMeters(
        mix.o2Percent / 100,
        maxPpO2: ppO2Limit,
        environment: environment,
      ),
      decimals: 0,
    );
    final composition = mix.isTrimix
        ? '${mix.o2Percent.toStringAsFixed(0)}% O₂ / '
              '${mix.hePercent.toStringAsFixed(0)}% He'
        : '${mix.o2Percent.toStringAsFixed(0)}% O₂';

    return Semantics(
      label: '$name, $composition, MOD: $displayMod',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                name,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                composition,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
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

  /// Air and oxygen in the diver's language, as the table showed them
  /// before the catalog; every other entry's name is a formula.
  String _displayName(AppLocalizations l10n, StandardGasMix mix) {
    if (mix.isTrimix) return mix.name;
    if (mix.o2Percent == 21) return l10n.gas_air_displayName;
    if (mix.o2Percent == 100) return l10n.gas_oxygen_displayName;
    return mix.name;
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
