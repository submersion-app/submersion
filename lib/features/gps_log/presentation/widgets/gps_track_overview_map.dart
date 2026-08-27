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

/// Selection section shared by every surface that pairs a track list with
/// the overview map, so a track picked on one is still picked on the other.
const String kGpsTrackSectionKey = 'gps-tracks';

/// Every given track on one map, the selected one drawn on top.
///
/// Extracted from the overview map page so the GPS log page can host the same
/// map beside its list at desktop width without a second copy of the framing
/// logic.
class GpsTrackOverviewMap extends ConsumerStatefulWidget {
  const GpsTrackOverviewMap({
    super.key,
    required this.tracks,
    required this.selectedId,
    required this.controller,
  });

  final List<GpsTrack> tracks;
  final String? selectedId;
  final MapController controller;

  @override
  ConsumerState<GpsTrackOverviewMap> createState() =>
      _GpsTrackOverviewMapState();
}

class _GpsTrackOverviewMapState extends ConsumerState<GpsTrackOverviewMap> {
  bool _mapReady = false;

  /// Signature of the framing currently applied, so a filter change or a
  /// late-arriving simplify re-frames but an unrelated rebuild does not.
  String? _framedOn;

  List<GpsTrack> get tracks => widget.tracks;
  String? get selectedId => widget.selectedId;
  MapController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Unselected tracks are muted and drawn first; the selected one is drawn
    // last with a thicker stroke so it sits on top of any it overlaps.
    final unselected = <Polyline<String>>[];
    Polyline<String>? selected;
    List<GpsTrackPoint>? selectedPoints;
    final allPoints = <GpsTrackPoint>[];

    for (final track in tracks) {
      final geometry =
          ref
              .watch(gpsTrackGeometryProvider((track.id, TrackLod.thumbnail)))
              .value ??
          const <GpsTrackPoint>[];
      if (geometry.length < 2) continue;
      allPoints.addAll(geometry);

      final line = Polyline<String>(
        points: [for (final p in geometry) LatLng(p.latitude, p.longitude)],
        color: track.id == selectedId ? scheme.primary : scheme.outline,
        strokeWidth: track.id == selectedId ? 4.0 : 2.0,
        strokeCap: StrokeCap.round,
        hitValue: track.id,
      );
      if (track.id == selectedId) {
        selected = line;
        selectedPoints = geometry;
      } else {
        unselected.add(line);
      }
    }

    // A selection frames that track alone; clearing it frames the library
    // again. Same idea as the site map animating to the picked site.
    //
    // Null while nothing can be framed yet: a cold cache is still decoding
    // and simplifying every track, or no track has two fixes. The basemap
    // stays mounted at a world view rather than the pane going blank, and
    // the framing below catches up when geometry lands.
    final camera = TrackCamera.forPoints(selectedPoints ?? allPoints);

    // Re-frame when the visible set changes: the date filter narrowing, a
    // selection promoting a track, or a per-track simplify finishing. A
    // FutureProvider reload keeps its previous value, so the map never
    // unmounts and initialCameraFit would never apply again.
    final signature = '${tracks.length}:${allPoints.length}:$selectedId';
    if (_mapReady && _framedOn != signature) {
      _framedOn = signature;
      if (camera != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) camera.applyTo(controller);
        });
      }
    }

    return TrackpadZoomMap(
      controller: controller,
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          onMapReady: () {
            _mapReady = true;
            _framedOn = signature;
            // Geometry that arrived between the first build and the map
            // becoming ready would otherwise never be framed: the signature
            // path above only fires while _mapReady is already true.
            camera?.applyTo(controller);
          },
          initialCameraFit: camera?.fit,
          initialCenter: camera?.center ?? const LatLng(20, 0),
          initialZoom: camera?.zoom ?? 2.0,
          interactionOptions: rotatableMapInteraction,
        ),
        children: [
          submersionTileLayer(ref),
          PolylineLayer<String>(
            // Selected drawn last so it sits above any track it overlaps.
            polylines: [...unselected, ?selected],
          ),
          const MapAttribution(),
          MapCompassButton(controller: controller),
        ],
      ),
    );
  }
}
