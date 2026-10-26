import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_camera.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_polyline_layer.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

/// Selection section shared by every Tracks surface that pairs the list
/// with the overview map, so a track picked on one stays picked on the
/// other. Holds a [TrackListItem.selectionKey].
const String kTracksSectionKey = 'tracks';

/// What the map's framing depends on: which tracks it frames, how many
/// points they have so far, the selection, and where each underwater track
/// is anchored, so a filter swapping in different tracks of the same size,
/// or a realigned track, is brought back into view.
String tracksMapFramingSignature({
  required List<TrackListItem> items,
  required int pointCount,
  required String? selectedKey,
}) {
  final anchors = [
    for (final item in items)
      if (item is UnderwaterTrackItem)
        '${item.id}@${item.track.anchorLatitude},${item.track.anchorLongitude}',
  ].join(';');
  final keys = [for (final item in items) item.selectionKey].join(',');
  return '$keys:$pointCount:$selectedKey:$anchors';
}

/// An anchored underwater track's drawn route as framing points, empty until
/// its points have loaded. Derived once per hydration rather than in the
/// map's build: the map rebuilds far more often than a track's points
/// change, and each derivation segments and corrects the whole recording.
final _underwaterFramingPointsProvider =
    Provider.family<List<GpsTrackPoint>, String>((ref, trackId) {
      final hydrated = ref.watch(navTrackByIdProvider(trackId)).value;
      if (hydrated == null) return const [];
      return [
        for (final geo in navTrackDrawnPoints(hydrated))
          GpsTrackPoint(
            timestamp: 0,
            latitude: geo.latitude,
            longitude: geo.longitude,
          ),
      ];
    });

/// Every given track on one map: GPS tracks as polylines (the selected one
/// on top), underwater tracks through their own layer.
class TracksOverviewMap extends ConsumerStatefulWidget {
  const TracksOverviewMap({
    super.key,
    required this.items,
    required this.selectedKey,
    required this.controller,
  });

  /// Mappable items only (tracksOverviewProvider).
  final List<TrackListItem> items;
  final String? selectedKey;
  final MapController controller;

  @override
  ConsumerState<TracksOverviewMap> createState() => _TracksOverviewMapState();
}

class _TracksOverviewMapState extends ConsumerState<TracksOverviewMap> {
  bool _mapReady = false;

  /// Signature of the framing currently applied, so a filter change or a
  /// late-arriving simplify re-frames but an unrelated rebuild does not.
  String? _framedOn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedKey = widget.selectedKey;

    final unselected = <Polyline<String>>[];
    Polyline<String>? selected;
    List<GpsTrackPoint>? selectedPoints;
    final allPoints = <GpsTrackPoint>[];
    final anchored = <UnderwaterTrackItem>[];

    // The dive site the selection belongs to, if any -- selecting one
    // underwater track frames every track at the same site, not just that
    // one (#3648), since a site with several tracks otherwise left all but
    // the selected one out of the visible extent.
    String? selectedSiteId;
    for (final item in widget.items) {
      if (item.selectionKey == selectedKey && item is UnderwaterTrackItem) {
        selectedSiteId = item.track.siteId;
      }
    }

    for (final item in widget.items) {
      final isSelected = item.selectionKey == selectedKey;
      switch (item) {
        case GpsTrackItem():
          final geometry =
              ref
                  .watch(
                    gpsTrackGeometryProvider((item.id, TrackLod.thumbnail)),
                  )
                  .value ??
              const <GpsTrackPoint>[];
          if (geometry.length >= 2) {
            allPoints.addAll(geometry);
            final line = Polyline<String>(
              points: [
                for (final p in geometry) LatLng(p.latitude, p.longitude),
              ],
              color: isSelected ? scheme.primary : scheme.outline,
              strokeWidth: isSelected ? 4.0 : 2.0,
              strokeCap: StrokeCap.round,
              hitValue: item.selectionKey,
            );
            if (isSelected) {
              selected = line;
              selectedPoints = geometry;
            } else {
              unselected.add(line);
            }
          }
        case UnderwaterTrackItem(:final track):
          final anchor = track.anchor;
          if (anchor != null) {
            anchored.add(item);
            // Framing reads the anchor alone for every track in the
            // library: hydrating every one of them just to frame the map
            // would cost a blob decode per track before anything is drawn.
            final anchorPoint = GpsTrackPoint(
              timestamp: 0,
              latitude: anchor.latitude,
              longitude: anchor.longitude,
            );
            allPoints.add(anchorPoint);
            final sameSite =
                selectedSiteId != null && track.siteId == selectedSiteId;
            if (isSelected || sameSite) {
              // The selected track (and any sibling at its site) is the
              // one case hydrating is cheap -- _HydratedUnderwaterPolyline
              // already pays for it below to draw the route, so framing
              // reuses the same provider rather than settling for the
              // anchor alone (which used to frame a long route's start
              // point with the rest cut off screen).
              final drawn = ref.watch(
                _underwaterFramingPointsProvider(item.id),
              );
              final framedPoints = drawn.length >= 2 ? drawn : [anchorPoint];
              selectedPoints = [...?selectedPoints, ...framedPoints];
              // Folded into the library's own point count too, so the
              // framing signature changes once a sibling's hydration lands
              // after the first (anchor-only) frame and the re-frame
              // effect below actually fires instead of leaving the first,
              // narrower framing in place.
              allPoints.addAll(framedPoints);
            }
          }
      }
    }

    // A selection frames that track alone; clearing it frames the library
    // again. Null while nothing can be framed yet.
    final camera = TrackCamera.forPoints(selectedPoints ?? allPoints);

    final signature = tracksMapFramingSignature(
      items: widget.items,
      pointCount: allPoints.length,
      selectedKey: selectedKey,
    );
    if (_mapReady && _framedOn != signature) {
      _framedOn = signature;
      if (camera != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) camera.applyTo(widget.controller);
        });
      }
    }

    return TrackpadZoomMap(
      controller: widget.controller,
      child: FlutterMap(
        mapController: widget.controller,
        options: MapOptions(
          onMapReady: () {
            _mapReady = true;
            _framedOn = signature;
            // Geometry that arrived between the first build and the map
            // becoming ready would otherwise never be framed.
            camera?.applyTo(widget.controller);
          },
          initialCameraFit: camera?.fit,
          initialCenter: camera?.center ?? const LatLng(20, 0),
          initialZoom: camera?.zoom ?? 2.0,
          // The zoom range and pole stop every other map has (#3664).
          minZoom: 2.0,
          maxZoom: 18.0,
          interactionOptions: rotatableMapInteraction,
          cameraConstraint: worldMapCameraConstraint,
        ),
        children: [
          submersionTileLayer(ref),
          if (unselected.isNotEmpty || selected != null)
            PolylineLayer<String>(
              // Selected drawn last so it sits above any track it overlaps.
              polylines: [...unselected, ?selected],
            ),
          for (final item in anchored)
            _HydratedUnderwaterPolyline(
              key: ValueKey(item.selectionKey),
              trackId: item.id,
            ),
          const MapAttribution(),
          Positioned(
            top: 8,
            right: 8,
            child: MapCornerControls(controller: widget.controller),
          ),
        ],
      ),
    );
  }
}

/// Hydrates one anchored underwater track's points before drawing it: the
/// list reads without points, so only tracks actually on the map pay for a
/// blob decode.
class _HydratedUnderwaterPolyline extends ConsumerWidget {
  const _HydratedUnderwaterPolyline({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydrated = ref.watch(navTrackByIdProvider(trackId)).value;
    if (hydrated == null) return const SizedBox.shrink();
    return NavTrackPolylineLayer(route: hydrated);
  }
}
