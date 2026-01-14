import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import '../providers/gas_calculators_providers.dart';

/// Rock Bottom calculator.
///
/// Calculates the minimum gas reserve needed for emergency ascent,
/// accounting for buddy breathing, stressed SAC rates, and safety stops.
class RockBottomCalculator extends ConsumerWidget {
  const RockBottomCalculator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depth = ref.watch(rockBottomDepthProvider);
    final ascentRate = ref.watch(rockBottomAscentRateProvider);
    final sac = ref.watch(rockBottomSacProvider);
    final buddySac = ref.watch(rockBottomBuddySacProvider);
    final tankSize = ref.watch(rockBottomTankSizeProvider);
    final includeSafetyStop = ref.watch(rockBottomSafetyStopProvider);
    final result = ref.watch(rockBottomResultProvider);
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
                    'Emergency Scenario',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Depth slider
                  _buildSliderSection(
                    context,
                    icon: Icons.arrow_downward,
                    label: 'Maximum Depth',
                    value: depth,
                    unit: 'm',
                    min: 10,
                    max: 50,
                    divisions: 40,
                    onChanged: (value) {
                      ref.read(rockBottomDepthProvider.notifier).state = value;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Ascent rate slider
                  _buildSliderSection(
                    context,
                    icon: Icons.arrow_upward,
                    label: 'Ascent Rate',
                    value: ascentRate,
                    unit: 'm/min',
                    min: 6,
                    max: 12,
                    divisions: 6,
                    onChanged: (value) {
                      ref.read(rockBottomAscentRateProvider.notifier).state =
                          value;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // SAC rates card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.air, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Stressed SAC Rates',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use higher SAC rates to account for stress during emergency',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Your SAC
                  _buildSliderSection(
                    context,
                    icon: Icons.person,
                    label: 'Your SAC',
                    value: sac,
                    unit: 'L/min',
                    min: 15,
                    max: 35,
                    divisions: 20,
                    onChanged: (value) {
                      ref.read(rockBottomSacProvider.notifier).state = value;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Buddy SAC
                  _buildSliderSection(
                    context,
                    icon: Icons.people,
                    label: 'Buddy SAC',
                    value: buddySac,
                    unit: 'L/min',
                    min: 15,
                    max: 40,
                    divisions: 25,
                    onChanged: (value) {
                      ref.read(rockBottomBuddySacProvider.notifier).state =
                          value;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tank & options card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include Safety Stop'),
                    subtitle: const Text('3 minutes at 5m'),
                    value: includeSafetyStop,
                    onChanged: (value) {
                      ref.read(rockBottomSafetyStopProvider.notifier).state =
                          value;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Result card
          Card(
            color: colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Minimum Reserve',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${result.totalBar.toStringAsFixed(0)} bar',
                    style: textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  Text(
                    '(${result.totalLiters.toStringAsFixed(0)} L)',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onErrorContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.onErrorContainer.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Turn the dive when reaching ${result.totalBar.toStringAsFixed(0)} bar remaining',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
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
                        Icons.list_alt,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Emergency Ascent Breakdown',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildBreakdownRow(
                    context,
                    'Combined stressed SAC',
                    '${(sac + buddySac).toStringAsFixed(0)} L/min',
                  ),
                  _buildBreakdownRow(
                    context,
                    'Ascent time to ${includeSafetyStop ? '5m' : 'surface'}',
                    '${((depth - (includeSafetyStop ? 5 : 0)) / ascentRate).toStringAsFixed(1)} min',
                  ),
                  _buildBreakdownRow(
                    context,
                    'Ascent gas required',
                    '${result.ascentGas.toStringAsFixed(0)} L',
                  ),
                  if (includeSafetyStop)
                    _buildBreakdownRow(
                      context,
                      'Safety stop gas (3 min @ 5m)',
                      '${result.safetyStopGas.toStringAsFixed(0)} L',
                    ),
                  const Divider(height: 24),
                  _buildBreakdownRow(
                    context,
                    'Total reserve needed',
                    '${result.totalLiters.toStringAsFixed(0)} L = '
                        '${result.totalBar.toStringAsFixed(0)} bar',
                    isHighlight: true,
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
                        'About Rock Bottom',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Rock bottom is the minimum gas reserve for an emergency ascent '
                    'while sharing air with your buddy.\n\n'
                    '• Uses stressed SAC rates (2-3x normal)\n'
                    '• Assumes both divers on one tank\n'
                    '• Includes safety stop when enabled\n\n'
                    'Always turn the dive BEFORE reaching rock bottom!',
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
        ref.read(rockBottomTankSizeProvider.notifier).state = size;
      },
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
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
