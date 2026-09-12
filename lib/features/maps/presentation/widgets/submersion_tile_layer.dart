import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';

/// The app's standard basemap layer: configured tile URL, the diver's max
/// zoom, and the offline cache when it has been initialized.
///
/// Extracted because several maps had grown byte-identical copies of this.
///
/// [tileDisplay] defaults to flutter_map's fade-in. A decorative map that
/// remounts often should pass [TileDisplay.instantaneous], because the fade
/// starts every tile at opacity 0 even when its image is already in memory.
TileLayer submersionTileLayer(
  WidgetRef ref, {
  double? maxZoomOverride,
  TileDisplay tileDisplay = const TileDisplay.fadeIn(),
}) {
  final urlTemplate = ref.watch(mapTileUrlProvider);
  return TileLayer(
    urlTemplate: urlTemplate,
    userAgentPackageName: 'app.submersion',
    maxZoom: maxZoomOverride ?? ref.watch(mapTileMaxZoomProvider),
    tileDisplay: tileDisplay,
    tileProvider: TileCacheService.instance.tileProviderFor(
      urlTemplate: urlTemplate,
    ),
  );
}
