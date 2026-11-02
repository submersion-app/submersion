import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';

/// Visible attribution for the current map tile source.
///
/// Rendered as a child of [FlutterMap] so that OpenStreetMap, OpenTopoMap,
/// and Esri tile usage policies are met (each requires visible attribution).
/// Reacts to [mapTileAttributionProvider] so the displayed text updates when
/// the user switches map style in settings.
class MapAttribution extends ConsumerWidget {
  /// How far above the map's bottom edge the attribution sits, for a map
  /// whose bottom is covered.
  final double bottomInset;

  const MapAttribution({super.key, this.bottomInset = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attribution = ref.watch(mapTileAttributionProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: RichAttributionWidget(
        attributions: [TextSourceAttribution(attribution)],
        showFlutterMapAttribution: false,
      ),
    );
  }
}
