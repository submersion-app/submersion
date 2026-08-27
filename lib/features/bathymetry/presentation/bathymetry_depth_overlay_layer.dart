import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_overlay_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The 2D depth overlay as a FlutterMap layer: the site's bathymetry as a
/// translucent ramp + contours, gated on the synced appearance flag.
/// Renders nothing while the flag is off, [location] is null, the grid is
/// absent, or the image is still rendering. One widget serves every map
/// host so bounds, caching, and gating cannot drift apart.
class BathymetryDepthOverlayLayer extends ConsumerWidget {
  final GeoPoint? location;

  const BathymetryDepthOverlayLayer({super.key, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(
      settingsProvider.select((s) => s.seascapeAppearance.mapDepthOverlay),
    );
    final where = location;
    if (!on || where == null) return const SizedBox.shrink();
    final overlayAsync = ref.watch(
      bathymetryOverlayProvider(BathymetryRepository.quantize(where)),
    );
    final overlay = overlayAsync.valueOrNull;
    if (overlay == null) return const SizedBox.shrink();
    return OverlayImageLayer(
      overlayImages: [
        OverlayImage(
          bounds: overlay.bounds,
          // The provider hands back the identical bytes instance per
          // (grid, appearance), so this MemoryImage hits the ImageCache.
          imageProvider: MemoryImage(overlay.pngBytes),
        ),
      ],
    );
  }
}
