import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import '../providers/gas_calculators_providers.dart';

/// Gas Consumption calculator.
///
/// Calculates how much gas will be used during a dive based on
/// depth, time, SAC rate, and tank size.
class GasConsumptionCalculator extends ConsumerWidget {
  const GasConsumptionCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depth = ref.watch(consumptionDepthProvider);
    final time = ref.watch(consumptionTimeProvider);
    final sac = ref.watch(consumptionSacProvider);
    final tankSize = ref.watch(consumptionTankSizeProvider);
    final result = ref.watch(consumptionResultProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
                    'Dive Parameters',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Depth slider
                  _buildSliderSection(
                    context,
                    icon: Icons.arrow_downward,
                    label: 'Average Depth',
                    value: depth,
                    unit: 'm',
                    min: 5,
                    max: 50,
                    divisions: 45,
                    onChanged: (value) {
                      ref.read(consumptionDepthProvider.notifier).state = value;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Time slider
                  _buildSliderSection(
                    context,
                    icon: Icons.timer,
                    label: 'Dive Time',
                    value: time.toDouble(),
                    unit: 'min',
                    min: 5,
                    max: 90,
                    divisions: 85,
                    onChanged: (value) {
                      ref.read(consumptionTimeProvider.notifier).state = value
                          .toInt();
                    },
                  ),
                  const SizedBox(height: 20),

                  // SAC rate slider
                  _buildSliderSection(
                    context,
                    icon: Icons.air,
                    label: 'SAC Rate',
                    value: sac,
                    unit: 'L/min',
                    min: 8,
                    max: 30,
                    divisions: 22,
                    onChanged: (value) {
                      ref.read(consumptionSacProvider.notifier).state = value;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Tank size selector
                  Text(
                    'Tank Size',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final size in [10.0, 12.0, 15.0, 18.0])
                        _buildTankChip(context, ref, size, tankSize == size),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Results card
          Card(
            color: result.exceedsTank
                ? colorScheme.errorContainer
                : colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Gas Consumption',
                    style: textTheme.titleMedium?.copyWith(
                      color: result.exceedsTank
                          ? colorScheme.onErrorContainer
                          : colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildResultColumn(
                        context,
                        label: 'Volume',
                        value: result.liters.toStringAsFixed(0),
                        unit: 'L',
                        isError: result.exceedsTank,
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color:
                            (result.exceedsTank
                                    ? colorScheme.onErrorContainer
                                    : colorScheme.onPrimaryContainer)
                                .withValues(alpha: 0.3),
                      ),
                      _buildResultColumn(
                        context,
                        label: 'Pressure',
                        value: result.bar.toStringAsFixed(0),
                        unit: 'bar',
                        isError: result.exceedsTank,
                      ),
                    ],
                  ),
                  if (result.exceedsTank) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Consumption exceeds a 200 bar fill! '
                              'Reduce dive time or depth.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
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
          const SizedBox(height: 16),

          // Breakdown card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calculate,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Calculation Breakdown',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdownRow(
                    context,
                    'Ambient pressure at ${depth.toStringAsFixed(0)}m',
                    '${((depth / 10) + 1).toStringAsFixed(2)} ATM',
                  ),
                  _buildBreakdownRow(
                    context,
                    'Gas consumption at depth',
                    '${(sac * ((depth / 10) + 1)).toStringAsFixed(1)} L/min',
                  ),
                  _buildBreakdownRow(
                    context,
                    'Total gas for $time minutes',
                    '${result.liters.toStringAsFixed(0)} L',
                  ),
                  _buildBreakdownRow(
                    context,
                    'Tank capacity (${tankSize.toStringAsFixed(0)}L @ 200 bar)',
                    '${(tankSize * 200).toStringAsFixed(0)} L',
                  ),
                  const Divider(height: 24),
                  _buildBreakdownRow(
                    context,
                    'Remaining gas',
                    '${((tankSize * 200) - result.liters).toStringAsFixed(0)} L '
                        '(${(200 - result.bar).toStringAsFixed(0)} bar)',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSection(
    BuildContext context, {
    required IconData icon,
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
                Icon(icon, size: 20, color: colorScheme.primary),
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
                '${value.toStringAsFixed(0)} $unit',
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
      ],
    );
  }

  Widget _buildTankChip(
    BuildContext context,
    WidgetRef ref,
    double size,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text('${size.toStringAsFixed(0)}L'),
      selected: isSelected,
      onSelected: (_) {
        ref.read(consumptionTankSizeProvider.notifier).state = size;
      },
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }

  Widget _buildResultColumn(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required bool isError,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textColor = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;

    return Column(
      children: [
        Text(
          value,
          style: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          unit,
          style: textTheme.titleMedium?.copyWith(
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(
    BuildContext context,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: isHighlight
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isHighlight ? FontWeight.w600 : null,
              ),
            ),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: isHighlight ? colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
