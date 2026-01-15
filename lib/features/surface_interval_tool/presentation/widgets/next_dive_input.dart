import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';

/// Input card for the second (planned) dive parameters.
/// Allows setting depth and time for the planned repetitive dive.
class NextDiveInput extends ConsumerWidget {
  const NextDiveInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final depth = ref.watch(siSecondDiveDepthProvider);
    final time = ref.watch(siSecondDiveTimeProvider);

    // Convert depth for display
    final displayDepth = units.convertDepth(depth);
    final maxDisplayDepth = units.convertDepth(60.0);
    final depthSymbol = units.depthSymbol;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.looks_two,
                    color: colorScheme.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Second Dive',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '(Air)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Depth Slider
            _buildSliderRow(
              context: context,
              label: 'Depth',
              icon: Icons.arrow_downward,
              value: '${displayDepth.toStringAsFixed(0)} $depthSymbol',
              slider: Slider(
                value: depth,
                min: 6,
                max: 60,
                divisions: 54,
                onChanged: (value) {
                  ref.read(siSecondDiveDepthProvider.notifier).state = value;
                },
              ),
              minLabel:
                  '${units.convertDepth(6).toStringAsFixed(0)} $depthSymbol',
              maxLabel: '${maxDisplayDepth.toStringAsFixed(0)} $depthSymbol',
            ),
            const SizedBox(height: 16),

            // Time Slider
            _buildSliderRow(
              context: context,
              label: 'Time',
              icon: Icons.timer,
              value: '$time min',
              slider: Slider(
                value: time.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                onChanged: (value) {
                  ref.read(siSecondDiveTimeProvider.notifier).state = value
                      .round();
                },
              ),
              minLabel: '5 min',
              maxLabel: '120 min',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String value,
    required Slider slider,
    required String minLabel,
    required String maxLabel,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.bodyMedium),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        slider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: theme.textTheme.bodySmall),
              Text(maxLabel, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
