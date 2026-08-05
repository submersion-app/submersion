import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/utils/unit_axis.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/best_mix.dart';
import 'package:submersion/features/gas_calculators/domain/gas_consumption.dart'
    show roundDownTo;
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';
import 'package:submersion/shared/widgets/forms/unit_slider.dart';

/// Best Mix calculator - finds the best breathing mix for a target depth.
///
/// Oxygen rounds DOWN to a whole percent so the recommended mix's own MOD is
/// at or beyond the target depth, and the MOD is always shown alongside it.
/// When the diver's END limit requires helium, the helium-free mix is shown
/// too so the trade-off is visible.
class BestMixCalculator extends ConsumerWidget {
  const BestMixCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depth = ref.watch(bestMixDepthProvider); // meters
    final ppO2 = ref.watch(bestMixPpO2Provider);
    final endLimit = ref.watch(bestMixEndLimitProvider);
    final result = ref.watch(bestMixResultProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final recommended = result.recommended;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Input card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.gasCalculators_bestMix_targetDive,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      UnitSlider(
                        icon: Icons.arrow_downward,
                        label: context.l10n.gasCalculators_bestMix_targetDepth,
                        value: depth,
                        axis: UnitAxis.targetDepth(units),
                        onChanged: (v) =>
                            ref.read(bestMixDepthProvider.notifier).state = v,
                      ),
                      const SizedBox(height: 24),

                      // ppO2 limit selector
                      Text(
                        context.l10n.gasCalculators_ppO2Limit,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final limit in [1.2, 1.4, 1.6])
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: limit != 1.6 ? 8 : 0,
                                ),
                                child: _buildPpO2Chip(
                                  context,
                                  ref,
                                  limit,
                                  ppO2 == limit,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildBreakdownRow(
                        context,
                        context.l10n.gasCalculators_bestMix_endLimitLabel,
                        units.formatDepth(endLimit, decimals: 0),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Result card
              Semantics(
                label:
                    'Recommended mix ${recommended.mix.name}, '
                    'MOD ${units.formatDepth(recommended.modMeters, decimals: 0)}',
                child: Card(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          context.l10n.gasCalculators_bestMix_recommendedMix,
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
                        _buildBreakdownRow(
                          context,
                          context.l10n.gasCalculators_bestMix_idealLabel,
                          '${result.idealO2Percent.toStringAsFixed(1)}%',
                          onContainer: true,
                        ),
                        _buildBreakdownRow(
                          context,
                          context.l10n.gasCalculators_bestMix_modLabel(
                            ppO2.toStringAsFixed(1),
                          ),
                          units.formatDepth(recommended.modMeters, decimals: 0),
                          onContainer: true,
                        ),
                        _buildBreakdownRow(
                          context,
                          context.l10n.gasCalculators_bestMix_marginLabel,
                          units.formatDepth(
                            recommended.marginMeters,
                            decimals: 0,
                          ),
                          onContainer: true,
                        ),
                        _buildBreakdownRow(
                          context,
                          context.l10n.gasCalculators_bestMix_endLabel,
                          units.formatDepth(recommended.endMeters, decimals: 0),
                          onContainer: true,
                        ),
                        _buildBreakdownRow(
                          context,
                          context.l10n.gasCalculators_bestMix_densityLabel,
                          '${recommended.densityGPerL.toStringAsFixed(1)} g/L',
                          onContainer: true,
                        ),
                        if (recommended.mix.isTrimix) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.gasCalculators_bestMix_heliumAdded(
                              units.formatDepth(endLimit, decimals: 0),
                            ),
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                        if (recommended.exceedsCriticalDensity)
                          _buildFlag(
                            context,
                            context.l10n.gasCalculators_bestMix_densityCritical(
                              gasDensityCriticalGPerL.toStringAsFixed(1),
                            ),
                            colorScheme.error,
                          )
                        else if (recommended.exceedsWarnDensity)
                          _buildFlag(
                            context,
                            context.l10n.gasCalculators_bestMix_densityWarn(
                              gasDensityWarnGPerL.toStringAsFixed(1),
                            ),
                            colorScheme.tertiary,
                          ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.gasCalculators_planningCaveat,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Helium-free alternative, shown only when helium was added.
              if (result.nitroxAlternative != null) ...[
                _buildAlternativeCard(
                  context,
                  units,
                  result.nitroxAlternative!,
                  ppO2,
                  endLimit,
                ),
                const SizedBox(height: 16),
              ],

              // Common mixes reference
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.list_alt,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.gasCalculators_bestMix_commonMixesRef,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (result.nearestStandardMix != null)
                        _buildBreakdownRow(
                          context,
                          context.l10n.gasCalculators_bestMix_nearestStandard,
                          result.nearestStandardMix!.name,
                          isHighlight: true,
                        ),
                      const SizedBox(height: 4),
                      _buildMixRow(context, 'Air', 21, ppO2, units),
                      _buildMixRow(context, 'EAN32', 32, ppO2, units),
                      _buildMixRow(context, 'EAN36', 36, ppO2, units),
                      _buildMixRow(context, 'EAN40', 40, ppO2, units),
                      _buildMixRow(context, 'EAN50', 50, ppO2, units),
                      _buildMixRow(context, 'Oxygen', 100, ppO2, units),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlternativeCard(
    BuildContext context,
    UnitFormatter units,
    MixAssessment alternative,
    double ppO2,
    double endLimit,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                  context.l10n.gasCalculators_bestMix_withoutHelium,
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
            _buildBreakdownRow(
              context,
              context.l10n.gasCalculators_bestMix_modLabel(
                ppO2.toStringAsFixed(1),
              ),
              units.formatDepth(alternative.modMeters, decimals: 0),
            ),
            _buildBreakdownRow(
              context,
              context.l10n.gasCalculators_bestMix_endLabel,
              units.formatDepth(alternative.endMeters, decimals: 0),
            ),
            _buildBreakdownRow(
              context,
              context.l10n.gasCalculators_bestMix_densityLabel,
              '${alternative.densityGPerL.toStringAsFixed(1)} g/L',
            ),
            if (alternative.exceedsEndLimit)
              _buildFlag(
                context,
                context.l10n.gasCalculators_bestMix_endExceeded(
                  units.formatDepth(endLimit, decimals: 0),
                ),
                colorScheme.tertiary,
              ),
            if (alternative.exceedsCriticalDensity)
              _buildFlag(
                context,
                context.l10n.gasCalculators_bestMix_densityCritical(
                  gasDensityCriticalGPerL.toStringAsFixed(1),
                ),
                colorScheme.error,
              )
            else if (alternative.exceedsWarnDensity)
              _buildFlag(
                context,
                context.l10n.gasCalculators_bestMix_densityWarn(
                  gasDensityWarnGPerL.toStringAsFixed(1),
                ),
                colorScheme.tertiary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlag(BuildContext context, String text, Color color) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPpO2Chip(
    BuildContext context,
    WidgetRef ref,
    double value,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      // ppO2 is a physics unit and stays in bar regardless of unit settings.
      label: Text('${value.toStringAsFixed(1)} bar'),
      selected: isSelected,
      onSelected: (_) {
        ref.read(bestMixPpO2Provider.notifier).state = value;
      },
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildMixRow(
    BuildContext context,
    String name,
    int o2,
    double ppO2Limit,
    UnitFormatter units,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // MOD rounds DOWN toward the shallower, safer limit.
    final modMeters = ((ppO2Limit / (o2 / 100)) - 1) * 10;
    final displayMod = roundDownTo(units.convertDepth(modMeters), 1);

    return Semantics(
      label:
          '$name, $o2% O2, MOD: ${displayMod.toStringAsFixed(0)}${units.depthSymbol}',
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
              'MOD: ${displayMod.toStringAsFixed(0)}${units.depthSymbol}',
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

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
    bool onContainer = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final labelColor = onContainer
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
        : (isHighlight ? colorScheme.primary : colorScheme.onSurfaceVariant);
    final valueColor = onContainer
        ? colorScheme.onPrimaryContainer
        : (isHighlight ? colorScheme.primary : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: labelColor,
                fontWeight: isHighlight ? FontWeight.w600 : null,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
