import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/domain/map_utils.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Interactive map widget showing the voyage route for a liveaboard trip.
///
/// Displays:
/// - Embark port marker (green, from liveaboard details)
/// - Dive site markers (blue, from trip sites)
/// - Disembark port marker (red, from liveaboard details)
/// - Polyline connecting all points in chronological order
class TripVoyageMap extends ConsumerWidget {
  final String tripId;

  const TripVoyageMap({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(liveaboardDetailsProvider(tripId));
    final sitesAsync = ref.watch(tripSitesWithLocationsProvider(tripId));

    return detailsAsync.when(
      data: (details) => sitesAsync.when(
        data: (sites) {
          final allPoints = _buildRoutePoints(details, sites);
          if (allPoints.isEmpty) return const SizedBox.shrink();

          final markers = _buildMarkers(context, details, sites);
          final bounds = LatLngBounds.fromPoints(allPoints);
          final center = bounds.center;
          final zoom = calculateZoomForBounds(allPoints, bounds);

          return Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    context.l10n.trips_detail_sectionTitle_voyageMap,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 250,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: zoom,
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
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: allPoints,
                            strokeWidth: 3.0,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.7),
                            pattern: const StrokePattern.dotted(),
                          ),
                        ],
                      ),
                      MarkerLayer(markers: markers),
                      const MapAttribution(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
      ),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  /// Build the ordered list of route points: embark -> dive sites -> disembark.
  List<LatLng> _buildRoutePoints(
    LiveaboardDetails? details,
    List<DiveSite> sites,
  ) {
    final points = <LatLng>[];

    // Embark port
    if (details != null && details.hasEmbarkCoordinates) {
      points.add(LatLng(details.embarkLatitude!, details.embarkLongitude!));
    }

    // Dive sites (already deduplicated by the provider)
    for (final site in sites) {
      if (site.location != null) {
        points.add(LatLng(site.location!.latitude, site.location!.longitude));
      }
    }

    // Disembark port
    if (details != null && details.hasDisembarkCoordinates) {
      points.add(
        LatLng(details.disembarkLatitude!, details.disembarkLongitude!),
      );
    }

    return points;
  }

  /// Build markers for embark port, dive sites, and disembark port.
  List<Marker> _buildMarkers(
    BuildContext context,
    LiveaboardDetails? details,
    List<DiveSite> sites,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final markers = <Marker>[];

    // Embark marker (green)
    if (details != null && details.hasEmbarkCoordinates) {
      markers.add(
        Marker(
          point: LatLng(details.embarkLatitude!, details.embarkLongitude!),
          width: 36,
          height: 36,
          child: _PortMarker(color: Colors.green.shade700, icon: Icons.login),
        ),
      );
    }

    // Dive site markers (primary color)
    for (final site in sites) {
      if (site.location != null) {
        markers.add(
          Marker(
            point: LatLng(site.location!.latitude, site.location!.longitude),
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.onPrimary, width: 2),
              ),
              child: Center(
                child: Icon(
                  Icons.scuba_diving,
                  size: 16,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Disembark marker (red)
    if (details != null && details.hasDisembarkCoordinates) {
      markers.add(
        Marker(
          point: LatLng(
            details.disembarkLatitude!,
            details.disembarkLongitude!,
          ),
          width: 36,
          height: 36,
          child: _PortMarker(color: Colors.red.shade700, icon: Icons.logout),
        ),
      );
    }

    return markers;
  }
}

/// Port marker widget for embark/disembark points on the voyage map.
class _PortMarker extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _PortMarker({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Center(child: Icon(icon, size: 18, color: Colors.white)),
    );
  }
}
