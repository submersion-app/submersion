import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';

/// Controls for adjusting heat map display settings.
class HeatMapControls extends ConsumerWidget {
  const HeatMapControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(heatMapSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with visibility toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Heat Map Settings',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Switch(
                  value: settings.isVisible,
                  onChanged: (value) {
                    ref.read(heatMapSettingsProvider.notifier).state = settings
                        .copyWith(isVisible: value);
                  },
                ),
              ],
            ),

            // Only show sliders if heat map is visible
            if (settings.isVisible) ...[
              const SizedBox(height: 16),

              // Opacity slider
              Row(
                children: [
                  Icon(Icons.opacity, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Opacity'),
                  Expanded(
                    child: Slider(
                      value: settings.opacity,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: '${(settings.opacity * 100).round()}%',
                      onChanged: (value) {
                        ref.read(heatMapSettingsProvider.notifier).state =
                            settings.copyWith(opacity: value);
                      },
                    ),
                  ),
                ],
              ),

              // Radius/spread slider
              Row(
                children: [
                  Icon(Icons.blur_on, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Spread'),
                  Expanded(
                    child: Slider(
                      value: settings.radius,
                      min: 15,
                      max: 60,
                      divisions: 9,
                      label: '${settings.radius.round()}',
                      onChanged: (value) {
                        ref.read(heatMapSettingsProvider.notifier).state =
                            settings.copyWith(radius: value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
