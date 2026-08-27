import 'package:http/http.dart' as http;

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/terrain_imagery_service.dart';

/// Injectable so tests never hit tile servers.
final terrainImageryHttpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// The stitched terrain imagery for a quantized bathymetry cell and map
/// style, or null when the grid or any tile is unavailable. Session-cached
/// per key; a style change is a new key.
final terrainImageryProvider =
    FutureProvider.family<
      TerrainImagery?,
      ({double lat, double lon, MapStyle style})
    >((ref, key) async {
      final grid = await ref.watch(
        bathymetryGridProvider((lat: key.lat, lon: key.lon)).future,
      );
      if (grid == null) return null;
      final client = ref.watch(terrainImageryHttpClientProvider);
      return TerrainImageryService(client).fetch(grid: grid, style: key.style);
    });
