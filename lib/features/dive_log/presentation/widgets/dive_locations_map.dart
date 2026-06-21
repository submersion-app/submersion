import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';

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
class DiveLocationsMap extends ConsumerStatefulWidget {
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
  ConsumerState<DiveLocationsMap> createState() => _DiveLocationsMapState();
}

class _DiveLocationsMapState extends ConsumerState<DiveLocationsMap> {
  late final MapController _fallbackController = MapController();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final points = <LatLng>[
      if (widget.entry != null)
        LatLng(widget.entry!.latitude, widget.entry!.longitude),
      if (widget.exit != null)
        LatLng(widget.exit!.latitude, widget.exit!.longitude),
      if (widget.site != null)
        LatLng(widget.site!.latitude, widget.site!.longitude),
    ];
    if (points.isEmpty) return const SizedBox.shrink();

    LatLng center;
    double zoom;
    CameraFit? fit;
    if (widget.initialCenter != null) {
      center = widget.initialCenter!;
      zoom = widget.initialZoom ?? 12.0;
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

    // Keys live on the marker child, never on the Marker itself. flutter_map
    // reuses Marker.key for every repeated world copy it renders at low zoom,
    // which would make those copies duplicate-keyed siblings in the
    // MarkerLayer's Stack ("Duplicate keys found"). Keying the child instead
    // keeps each copy isolated in its own Positioned while staying findable.
    final markers = <Marker>[
      if (widget.entry != null)
        Marker(
          point: LatLng(widget.entry!.latitude, widget.entry!.longitude),
          width: 28,
          height: 28,
          child: KeyedSubtree(
            key: const ValueKey('gps-entry-marker'),
            child: _mapPin(colorScheme, Icons.south, kGpsEntryColor),
          ),
        ),
      if (widget.exit != null)
        Marker(
          point: LatLng(widget.exit!.latitude, widget.exit!.longitude),
          width: 28,
          height: 28,
          child: KeyedSubtree(
            key: const ValueKey('gps-exit-marker'),
            child: _mapPin(colorScheme, Icons.north, kGpsExitColor),
          ),
        ),
      if (widget.site != null)
        Marker(
          point: LatLng(widget.site!.latitude, widget.site!.longitude),
          width: 32,
          height: 32,
          // Diver glyph, matching the dive-site marker on the Sites map
          // (site_map_content.dart) and the rest of the app's site/dive maps.
          child: KeyedSubtree(
            key: const ValueKey('gps-site-marker'),
            child: _mapPin(
              colorScheme,
              Icons.scuba_diving,
              colorScheme.primary,
            ),
          ),
        ),
    ];

    final tileLayer = TileLayer(
      urlTemplate: ref.watch(mapTileUrlProvider),
      userAgentPackageName: 'app.submersion',
      maxZoom: ref.watch(mapTileMaxZoomProvider),
      tileProvider: TileCacheService.instance.isInitialized
          ? TileCacheService.instance.getTileProvider()
          : null,
    );

    final polylineLayer = widget.entry != null && widget.exit != null
        ? PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  LatLng(widget.entry!.latitude, widget.entry!.longitude),
                  LatLng(widget.exit!.latitude, widget.exit!.longitude),
                ],
                strokeWidth: 3.0,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                pattern: const StrokePattern.dotted(),
              ),
            ],
          )
        : null;

    if (widget.interactive) {
      final effectiveController = widget.controller ?? _fallbackController;
      return MapInteractionDetector(
        mapController: effectiveController,
        builder: (context, interactionOptions) => FlutterMap(
          mapController: effectiveController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            initialCameraFit: fit,
            interactionOptions: interactionOptions,
          ),
          children: [
            tileLayer,
            ?polylineLayer,
            MarkerLayer(markers: markers),
            const MapAttribution(),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: widget.controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        initialCameraFit: fit,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        tileLayer,
        ?polylineLayer,
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
