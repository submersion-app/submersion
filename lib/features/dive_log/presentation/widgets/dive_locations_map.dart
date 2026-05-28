import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';

/// Marker colors for the GPS entry/exit fixes, matching the values the dive
/// detail header map has always used.
const Color kGpsEntryColor = Color(0xFF34C759);
const Color kGpsExitColor = Color(0xFFFF9F0A);

/// Renders a map of a dive's surface locations: the GPS entry fix, the GPS exit
/// fix, and the associated dive site. Reused by the dive detail header
/// (decorative, non-interactive), the Surface GPS section (inline, interactive),
/// and the fullscreen locations page.
///
/// This widget only draws a map. Clipboard, navigation, and row logic live in
/// the callers.
class DiveLocationsMap extends ConsumerWidget {
  const DiveLocationsMap({
    super.key,
    this.entry,
    this.exit,
    this.site,
    this.interactive = false,
    this.controller,
    this.initialCenter,
    this.initialZoom,
  });

  /// GPS entry fix.
  final GeoPoint? entry;

  /// GPS exit fix.
  final GeoPoint? exit;

  /// Associated dive site location.
  final GeoPoint? site;

  /// Whether the user can pan/zoom. False renders a static, decorative map.
  final bool interactive;

  /// Optional controller for programmatic recentering (tap-to-focus).
  final MapController? controller;

  /// When set, the camera uses this center/zoom verbatim instead of fitting all
  /// points. The header passes this to preserve its fixed zoom-12 look.
  final LatLng? initialCenter;
  final double? initialZoom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final points = <LatLng>[
      if (entry != null) LatLng(entry!.latitude, entry!.longitude),
      if (exit != null) LatLng(exit!.latitude, exit!.longitude),
      if (site != null) LatLng(site!.latitude, site!.longitude),
    ];
    if (points.isEmpty) return const SizedBox.shrink();

    LatLng center;
    double zoom;
    CameraFit? fit;
    if (initialCenter != null) {
      center = initialCenter!;
      zoom = initialZoom ?? 12.0;
    } else if (points.length >= 2) {
      center = points.first;
      zoom = 13.0;
      fit = CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
        // Entry/exit/site fixes are often within meters of each other; fitting
        // that tight bounds would zoom past the tile provider's max zoom and
        // leave the map blank. Cap at 16 so tiles stay visible with context.
        maxZoom: 16.0,
      );
    } else {
      center = points.first;
      zoom = 14.0;
    }

    final markers = <Marker>[
      if (entry != null)
        Marker(
          key: const ValueKey('gps-entry-marker'),
          point: LatLng(entry!.latitude, entry!.longitude),
          width: 28,
          height: 28,
          child: _mapPin(colorScheme, Icons.south, kGpsEntryColor),
        ),
      if (exit != null)
        Marker(
          key: const ValueKey('gps-exit-marker'),
          point: LatLng(exit!.latitude, exit!.longitude),
          width: 28,
          height: 28,
          child: _mapPin(colorScheme, Icons.north, kGpsExitColor),
        ),
      if (site != null)
        Marker(
          key: const ValueKey('gps-site-marker'),
          point: LatLng(site!.latitude, site!.longitude),
          width: 32,
          height: 32,
          // Diver glyph, matching the dive-site marker on the Sites map
          // (site_map_content.dart) and the rest of the app's site/dive maps.
          child: _mapPin(colorScheme, Icons.scuba_diving, colorScheme.primary),
        ),
    ];

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        initialCameraFit: fit,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
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
        if (entry != null && exit != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  LatLng(entry!.latitude, entry!.longitude),
                  LatLng(exit!.latitude, exit!.longitude),
                ],
                strokeWidth: 3.0,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                pattern: const StrokePattern.dotted(),
              ),
            ],
          ),
        MarkerLayer(markers: markers),
        const MapAttribution(),
      ],
    );
  }
}

Widget _mapPin(ColorScheme colorScheme, IconData icon, Color color) {
  return Container(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: colorScheme.onPrimary, width: 2),
    ),
    child: Center(child: Icon(icon, size: 14, color: colorScheme.onPrimary)),
  );
}
