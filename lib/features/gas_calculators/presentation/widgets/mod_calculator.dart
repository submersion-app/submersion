import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_calculators_providers.dart';

/// Maximum Operating Depth (MOD) calculator.
///
/// Calculates the maximum safe depth for a given gas mix based on ppO2 limits.
class ModCalculator extends ConsumerWidget {
  const ModCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o2 = ref.watch(modO2Provider);
    final ppO2 = ref.watch(modPpO2Provider);
    final mod = ref.watch(modResultProvider); // MOD in meters
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Convert MOD to user's preferred unit
    final isMetric = settings.depthUnit == DepthUnit.meters;
    final displayMod = units.convertDepth(mod);
    final primaryUnit = units.depthSymbol;
    // Secondary unit (the other system)
    final secondaryMod = isMetric ? mod * 3.28084 : mod;
    final secondaryUnit = isMetric ? 'ft' : 'm';

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
                        'Input Parameters',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // O2 percentage slider
                      _buildSliderSection(
                        context,
                        label: 'Oxygen (O₂)',
                        value: o2,
                        unit: '%',
                        min: 21,
                        max: 100,
                        divisions: 79,
                        onChanged: (value) {
                          ref.read(modO2Provider.notifier).state = value;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ppO2 limit selector
                      Text(
                        'ppO₂ Limit',
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
                      const SizedBox(height: 8),
                      Text(
                        _getPpO2Description(ppO2),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Result card
              Card(
                color: colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Maximum Operating Depth',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${displayMod.toStringAsFixed(1)} $primaryUnit',
                        style: textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        '(${secondaryMod.toStringAsFixed(0)} $secondaryUnit)',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Warning thresholds stay in meters (internal calculation)
                      Icon(
                        mod < 10
                            ? Icons.warning
                            : mod < 30
                            ? Icons.info
                            : Icons.check_circle,
                        size: 32,
                        color: mod < 10
                            ? Colors.orange
                            : mod < 30
                            ? colorScheme.onPrimaryContainer
                            : Colors.green,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'About MOD',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'MOD is the deepest you can safely dive on a specific gas mix '
                        'without exceeding oxygen toxicity limits.\n\n'
                        '• 1.4 bar ppO₂: Recommended working limit\n'
                        '• 1.6 bar ppO₂: Maximum deco/emergency limit\n\n'
                        'Higher O₂ = shallower MOD = longer NDL\n'
                        'Lower O₂ = deeper MOD = shorter NDL',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
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

  Widget _buildSliderSection(
    BuildContext context, {
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.air, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${value.toStringAsFixed(0)}$unit',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest,
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${min.toStringAsFixed(0)}$unit',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${max.toStringAsFixed(0)}$unit',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
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
      label: Text('${value.toStringAsFixed(1)} bar'),
      selected: isSelected,
      onSelected: (_) {
        ref.read(modPpO2Provider.notifier).state = value;
      },
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }

  String _getPpO2Description(double ppO2) {
    if (ppO2 <= 1.2) {
      return 'Conservative limit for extended bottom time';
    } else if (ppO2 <= 1.4) {
      return 'Standard working limit for recreational diving';
    } else {
      return 'Maximum limit for decompression stops only';
    }
  }
}
