import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';

/// Simple toggle button for enabling/disabling heat map overlay.
class HeatMapToggleButton extends ConsumerWidget {
  const HeatMapToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(heatMapSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(
        settings.isVisible ? Icons.blur_on : Icons.blur_off,
        color: settings.isVisible ? colorScheme.primary : null,
      ),
      tooltip: settings.isVisible ? 'Hide Heat Map' : 'Show Heat Map',
      onPressed: () {
        ref.read(heatMapSettingsProvider.notifier).state = settings.copyWith(
          isVisible: !settings.isVisible,
        );
      },
    );
  }
}
