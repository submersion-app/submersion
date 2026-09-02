import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction_options.dart';
import 'package:submersion/features/maps/presentation/widgets/submersion_tile_layer.dart';

/// The overview pane before any track exists (or when the date filter
/// leaves none): a world basemap with the notice floated over it.
///
/// A bare pane with one grey sentence was the original complaint about this
/// page; a map with nothing drawn on it at least reads as a map waiting for
/// tracks.
class GpsTrackEmptyMap extends ConsumerWidget {
  const GpsTrackEmptyMap({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(20, 0),
            initialZoom: 2,
            interactionOptions: rotatableMapInteraction,
          ),
          children: [submersionTileLayer(ref), const MapAttribution()],
        ),
        Center(
          child: Card(
            elevation: 4,
            color: theme.colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text(message, style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
      ],
    );
  }
}
