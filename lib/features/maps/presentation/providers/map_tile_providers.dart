import 'package:submersion/core/constants/map_tile_config.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Provides the current tile URL template based on the selected map style.
final mapTileUrlProvider = Provider<String>((ref) {
  final mapStyle = ref.watch(settingsProvider.select((s) => s.mapStyle));
  return MapTileConfig.urlTemplate(mapStyle);
});

/// Provides the maximum zoom level for the selected map style.
final mapTileMaxZoomProvider = Provider<double>((ref) {
  final mapStyle = ref.watch(settingsProvider.select((s) => s.mapStyle));
  return MapTileConfig.maxZoom(mapStyle).toDouble();
});

/// Provides the attribution string for the selected map style.
final mapTileAttributionProvider = Provider<String>((ref) {
  final mapStyle = ref.watch(settingsProvider.select((s) => s.mapStyle));
  return MapTileConfig.attribution(mapStyle);
});
