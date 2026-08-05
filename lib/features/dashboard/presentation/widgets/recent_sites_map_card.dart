import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Mini map with pins for the sites of the most recent dives.
class RecentSitesMapCard extends ConsumerStatefulWidget {
  const RecentSitesMapCard({super.key});

  @override
  ConsumerState<RecentSitesMapCard> createState() => _RecentSitesMapCardState();
}

class _RecentSitesMapCardState extends ConsumerState<RecentSitesMapCard> {
  final MapController _controller = MapController();

  @override
  Widget build(BuildContext context) {
    final pinsAsync = ref.watch(recentSitesProvider);
    final pins = pinsAsync.valueOrNull ?? const [];
    if (pins.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final points = [for (final p in pins) LatLng(p.latitude, p.longitude)];
    final fit = points.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(40),
            maxZoom: 12,
          )
        : null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.dashboard_recentSites_title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_full, size: 16),
                  onPressed: () => context.go('/sites'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: TrackpadZoomMap(
                  controller: _controller,
                  child: FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: points.first,
                      initialZoom: 11,
                      initialCameraFit: fit,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: ref.watch(mapTileUrlProvider),
                        userAgentPackageName: 'app.submersion',
                        maxZoom: ref.watch(mapTileMaxZoomProvider),
                        tileProvider: TileCacheService.instance.isInitialized
                            ? TileCacheService.instance.getTileProvider()
                            : null,
                      ),
                      MarkerLayer(
                        markers: [
                          for (final p in pins)
                            Marker(
                              point: LatLng(p.latitude, p.longitude),
                              width: 34,
                              height: 34,
                              child: Tooltip(
                                message: p.siteName ?? '',
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.place,
                                      size: 16,
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const MapAttribution(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
