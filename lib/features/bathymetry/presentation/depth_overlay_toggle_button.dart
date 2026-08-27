import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App-bar toggle for the 2D depth overlay. The flag lives on the synced
/// SeascapeAppearance, so the choice follows the diver across devices.
/// Enabling while the selected site's grid is known to be absent still
/// records the (global) preference but shows the standard no-bathymetry
/// notice; the layer simply stays away for that site.
class DepthOverlayToggleButton extends ConsumerWidget {
  final GeoPoint? siteLocation;

  const DepthOverlayToggleButton({super.key, required this.siteLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(
      settingsProvider.select((s) => s.seascapeAppearance),
    );
    final on = appearance.mapDepthOverlay;
    final colorScheme = Theme.of(context).colorScheme;
    final location = siteLocation;
    final gridAsync = location == null
        ? null
        : ref.watch(
            bathymetryGridProvider(BathymetryRepository.quantize(location)),
          );

    return Semantics(
      toggled: on,
      child: IconButton(
        icon: Icon(Icons.water, color: on ? colorScheme.primary : null),
        tooltip: on
            ? context.l10n.maps_depthOverlay_hide
            : context.l10n.maps_depthOverlay_show,
        onPressed: () {
          final turningOn = !on;
          ref
              .read(settingsProvider.notifier)
              .setSeascapeAppearance(
                appearance.copyWith(mapDepthOverlay: turningOn),
              );
          final gridKnownAbsent =
              gridAsync != null &&
              gridAsync.hasValue &&
              gridAsync.value == null;
          if (turningOn && gridKnownAbsent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.dive3d_seascape_noData)),
            );
          }
        },
      ),
    );
  }
}
