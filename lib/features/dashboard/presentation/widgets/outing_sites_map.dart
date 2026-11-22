import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/domain/home_outings.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';

/// A still map of an outing's dive sites, a pin for each, for the cover of
/// an outing card with no photo. Built like the dive details header's map:
/// the app's tile layer, the diver pin, no interaction, a camera that never
/// moves after it is placed.
class OutingSitesMap extends ConsumerWidget {
  /// At least one site.
  final List<OutingSite> sites;

  const OutingSitesMap({required this.sites, super.key});

  /// The zoom for a single site, the dive details header's.
  static const double singleSiteZoom = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final points = [for (final s in sites) LatLng(s.latitude, s.longitude)];
    if (points.isEmpty) return const SizedBox.shrink();
    return FlutterMap(
      options: MapOptions(
        initialCenter: points.first,
        initialZoom: singleSiteZoom,
        // Several sites: fit them all, no closer than a single site shows,
        // with room at the bottom for the fade into the card.
        initialCameraFit: points.length > 1
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.fromLTRB(36, 30, 36, 52),
                maxZoom: singleSiteZoom,
              )
            : null,
        backgroundColor: scheme.primaryContainer,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        // The camera never moves, so tiles may show at once (see the dive
        // details header's map for why a moving camera must fade them in).
        submersionTileLayer(
          ref,
          tileDisplay: const TileDisplay.instantaneous(),
        ),
        MarkerLayer(
          markers: [
            for (final p in points)
              Marker(
                point: p,
                width: 22,
                height: 22,
                child: _SitePin(color: scheme.primary, ring: scheme.onPrimary),
              ),
          ],
        ),
        const MapAttribution(),
      ],
    );
  }
}

/// The diver pin the app's site maps use, a little smaller for a card.
class _SitePin extends StatelessWidget {
  final Color color;
  final Color ring;

  const _SitePin({required this.color, required this.ring});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: ring, width: 2),
    ),
    child: Center(child: Icon(Icons.scuba_diving, size: 11, color: ring)),
  );
}
