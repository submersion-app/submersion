import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import '../../../../core/constants/units.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/deco_calculator_providers.dart';

/// Slider for adjusting dive depth (0-60m / 0-200ft).
class DepthSlider extends ConsumerWidget {
  const DepthSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depth = ref.watch(calcDepthProvider); // Stored in meters
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Unit conversion
    final isMetric = settings.depthUnit == DepthUnit.meters;
    final depthSymbol = units.depthSymbol;
    final displayDepth = units.convertDepth(depth);
    const minDisplay = 0.0;
    final maxDisplay = units.convertDepth(60);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Depth',
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
                '${displayDepth.toStringAsFixed(0)} $depthSymbol',
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
            value: displayDepth,
            min: minDisplay,
            max: maxDisplay,
            divisions: isMetric ? 60 : 200,
            onChanged: (value) {
              // Convert back to meters for storage
              ref.read(calcDepthProvider.notifier).state = units.depthToMeters(
                value,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0$depthSymbol',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${maxDisplay.toStringAsFixed(0)}$depthSymbol',
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
}
