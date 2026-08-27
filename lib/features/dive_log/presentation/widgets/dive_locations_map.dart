import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/track_colorization.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_polyline_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';

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
    this.trackRuns,
    this.fitToTrack = false,
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

  /// Optional GPS surface track to draw beneath the markers.
  ///
  /// Null for every caller that predates GPS track rendering. Drawn first so
  /// the entry/exit/site pins stay on top.
  final List<TrackRun>? trackRuns;

  /// When true and [trackRuns] is non-empty, the camera fits the track's
  /// extent as well as the marker points.
  final bool fitToTrack;

  @override
  ConsumerState<DiveLocationsMap> createState() => _DiveLocationsMapState();
}

class _DiveLocationsMapState extends ConsumerState<DiveLocationsMap> {
  // Stable fallback used only when the caller does not supply a controller.
  // Derive the effective controller each build so a parent that rebuilds with a
  // different `controller` is always honored.
  final MapController _fallbackController = MapController();

  MapController get _effectiveController =>
      widget.controller ?? _fallbackController;

  bool _mapReady = false;

  /// The run list the camera is framed on, by identity.
  ///
  /// SurfaceGpsSection mounts this widget while trackForDiveProvider is still
  /// AsyncLoading, so the first layout sees trackRuns == null and latches a
  /// pin-only fit that saturates maxZoom 16 - a multi-km boat track then
  /// renders almost entirely offscreen, and the full-track chip could never
  /// move the camera, because initialCameraFit applies once.
  List<TrackRun>? _framedOn;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final exit = widget.exit;
    final site = widget.site;
    final interactive = widget.interactive;
    final initialCenter = widget.initialCenter;
    final initialZoom = widget.initialZoom;

    final colorScheme = Theme.of(context).colorScheme;

    final trackRuns = widget.trackRuns;
    final hasTrack = trackRuns != null && trackRuns.isNotEmpty;

    // Marker points only. The track's extent is folded into the bounds below
    // without materializing a LatLng per fix: these runs carry the FULL
    // decoded track, not a simplified LOD, so a boat day would allocate
    // ~20k objects on every build just to be handed to fromPoints and
    // discarded.
    final points = <LatLng>[
      if (entry != null) LatLng(entry.latitude, entry.longitude),
      if (exit != null) LatLng(exit.latitude, exit.longitude),
      if (site != null) LatLng(site.latitude, site.longitude),
    ];
    final fitTrack = hasTrack && widget.fitToTrack;
    if (points.isEmpty && !fitTrack) return const SizedBox.shrink();

    // Extent of everything the camera must cover, accumulated in place.
    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLon = double.infinity;
    var maxLon = double.negativeInfinity;
    var extentCount = 0;
    void extend(double lat, double lon) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
      extentCount++;
    }

    for (final p in points) {
      extend(p.latitude, p.longitude);
    }
    if (fitTrack) {
      for (final run in trackRuns) {
        for (final p in run.points) {
          extend(p.latitude, p.longitude);
        }
      }
    }
    if (extentCount == 0) return const SizedBox.shrink();

    final anchor = points.isNotEmpty ? points.first : LatLng(minLat, minLon);

    LatLng center;
    double zoom;
    CameraFit? fit;
    if (initialCenter != null) {
      center = initialCenter;
      zoom = initialZoom ?? 12.0;
    } else if (extentCount >= 2) {
      center = anchor;
      zoom = 13.0;
      fit = CameraFit.bounds(
        bounds: LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon)),
        padding: const EdgeInsets.all(48),
        // Entry/exit/site fixes are often within meters of each other; fitting
        // that tight bounds would zoom past the tile provider's max zoom and
        // leave the map blank. Cap at 16 so tiles stay visible with context.
        maxZoom: 16.0,
      );
    } else {
      center = anchor;
      zoom = 14.0;
    }

    // Keys live on the marker child, never on the Marker itself. flutter_map
    // reuses Marker.key for every repeated world copy it renders at low zoom,
    // which would make those copies duplicate-keyed siblings in the
    // MarkerLayer's Stack ("Duplicate keys found"). Keying the child instead
    // keeps each copy isolated in its own Positioned while staying findable.
    final markers = <Marker>[
      if (entry != null)
        Marker(
          point: LatLng(entry.latitude, entry.longitude),
          width: 28,
          height: 28,
          child: KeyedSubtree(
            key: const ValueKey('gps-entry-marker'),
            child: _mapPin(colorScheme, Icons.south, kGpsEntryColor),
          ),
        ),
      if (exit != null)
        Marker(
          point: LatLng(exit.latitude, exit.longitude),
          width: 28,
          height: 28,
          child: KeyedSubtree(
            key: const ValueKey('gps-exit-marker'),
            child: _mapPin(colorScheme, Icons.north, kGpsExitColor),
          ),
        ),
      if (site != null)
        Marker(
          point: LatLng(site.latitude, site.longitude),
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

    if (_mapReady && !identical(_framedOn, trackRuns)) {
      _framedOn = trackRuns;
      final target = fit;
      if (target != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _effectiveController.fitCamera(target);
        });
      }
    }

    return Stack(
      children: [
        TrackpadZoomMap(
          controller: _effectiveController,
          child: FlutterMap(
            mapController: _effectiveController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              onMapReady: () {
                _mapReady = true;
                _framedOn = trackRuns;
              },
              initialCameraFit: fit,
              interactionOptions: interactive
                  ? rotatableMapInteraction
                  : const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              submersionTileLayer(ref),
              // Drawn before the drift line and markers so the surface track
              // sits underneath both.
              if (hasTrack)
                GpsTrackPolylineLayer(
                  runs: trackRuns,
                  mode: TrackColorMode.uniform,
                  strokeWidth: 3.0,
                ),
              if (entry != null && exit != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(entry.latitude, entry.longitude),
                        LatLng(exit.latitude, exit.longitude),
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
          ),
        ),
        // Reset-to-north compass (only when the map accepts rotation gestures)
        if (interactive)
          Positioned(
            top: 16,
            right: 16,
            child: MapCompassButton(controller: _effectiveController),
          ),
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
