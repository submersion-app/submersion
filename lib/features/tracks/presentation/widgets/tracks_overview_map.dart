import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_camera.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_compass_button.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
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
            // Framing reads the anchor alone: hydrating every underwater
            // track's points just to frame the map would cost a blob decode
            // per track before anything is drawn.
            final point = GpsTrackPoint(
              timestamp: 0,
              latitude: anchor.latitude,
              longitude: anchor.longitude,
            );
            allPoints.add(point);
            if (isSelected) selectedPoints = [point];
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
          interactionOptions: rotatableMapInteraction,
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
          MapCompassButton(controller: widget.controller),
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
