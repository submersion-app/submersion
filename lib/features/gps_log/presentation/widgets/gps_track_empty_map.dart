import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_corner_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/maps/presentation/widgets/world_copies.dart';

/// The overview pane before any track exists (or when the date filter
/// leaves none): a world basemap with the notice floated over it.
///
/// A bare pane with one grey sentence was the original complaint about this
/// page; a map with nothing drawn on it at least reads as a map waiting for
/// tracks.
class GpsTrackEmptyMap extends ConsumerStatefulWidget {
  const GpsTrackEmptyMap({super.key, required this.message});

  final String message;

  @override
  ConsumerState<GpsTrackEmptyMap> createState() => _GpsTrackEmptyMapState();
}

class _GpsTrackEmptyMapState extends ConsumerState<GpsTrackEmptyMap> {
  /// Owned here because [TrackpadZoomMap] and the corner controls drive
  /// the camera through it.
  final MapController _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Zooms and scrolls like the map it stands in for (#3664).
        TrackpadZoomMap(
          controller: _controller,
          child: FlutterMap(
            mapController: _controller,
            options: const MapOptions(
              initialCenter: LatLng(20, 0),
              initialZoom: 2,
              minZoom: 2.0,
              maxZoom: 18.0,
              interactionOptions: rotatableMapInteraction,
              cameraConstraint: worldMapCameraConstraint,
            ),
            children: [
              submersionTileLayer(ref),
              const MapAttribution(),
              // It can rotate, so it needs the compass that resets north.
              Positioned(
                top: 8,
                right: 8,
                child: MapCornerControls(controller: _controller),
              ),
            ],
          ),
        ),
        Center(
          child: Card(
            elevation: 4,
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text(widget.message, style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
      ],
    );
  }
}
