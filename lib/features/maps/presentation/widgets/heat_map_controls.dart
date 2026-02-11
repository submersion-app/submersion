import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Simple toggle button for enabling/disabling heat map overlay.
class HeatMapToggleButton extends ConsumerWidget {
  const HeatMapToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(heatMapSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: settings.isVisible
          ? context.l10n.maps_heatMap_overlayOn
          : context.l10n.maps_heatMap_overlayOff,
      toggled: settings.isVisible,
      child: IconButton(
        icon: Icon(
          settings.isVisible ? Icons.blur_on : Icons.blur_off,
          color: settings.isVisible ? colorScheme.primary : null,
        ),
        tooltip: settings.isVisible
            ? context.l10n.maps_heatMap_hide
            : context.l10n.maps_heatMap_show,
        onPressed: () {
          ref.read(heatMapSettingsProvider.notifier).state = settings.copyWith(
            isVisible: !settings.isVisible,
          );
        },
      ),
    );
  }
}
