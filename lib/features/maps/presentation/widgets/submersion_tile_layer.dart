import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';

/// The app's standard basemap layer: configured tile URL, the diver's max
/// zoom, and the offline cache when it has been initialized.
///
/// Extracted because several maps had grown byte-identical copies of this.
TileLayer submersionTileLayer(WidgetRef ref, {double? maxZoomOverride}) {
  return TileLayer(
    urlTemplate: ref.watch(mapTileUrlProvider),
    userAgentPackageName: 'app.submersion',
    maxZoom: maxZoomOverride ?? ref.watch(mapTileMaxZoomProvider),
    tileProvider: TileCacheService.instance.isInitialized
        ? TileCacheService.instance.getTileProvider()
        : null,
  );
}
