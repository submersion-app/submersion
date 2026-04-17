import 'package:submersion/core/constants/map_style.dart';

/// Centralized configuration for map tile providers.
class MapTileConfig {
  MapTileConfig._();

  /// Returns the tile URL template for the given [style].
  static String urlTemplate(MapStyle style) {
    return switch (style) {
      MapStyle.openStreetMap =>
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      MapStyle.openTopoMap => 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
      MapStyle.esriSatellite =>
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    };
  }

  /// Returns the maximum zoom level supported by the given [style].
  static int maxZoom(MapStyle style) {
    return switch (style) {
      MapStyle.openStreetMap => 19,
      MapStyle.openTopoMap => 17,
      MapStyle.esriSatellite => 18,
    };
  }

  /// Returns a concrete tile URL for the given [style], zoom, x, and y indices.
  static String tileUrl(MapStyle style, int z, int x, int y) {
    return switch (style) {
      MapStyle.openStreetMap => 'https://tile.openstreetmap.org/$z/$x/$y.png',
      MapStyle.openTopoMap => 'https://tile.opentopomap.org/$z/$x/$y.png',
      MapStyle.esriSatellite =>
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$z/$y/$x',
    };
  }

  /// Returns the attribution string for the given [style].
  static String attribution(MapStyle style) {
    return switch (style) {
      MapStyle.openStreetMap => '\u00a9 OpenStreetMap contributors',
      MapStyle.openTopoMap =>
        '\u00a9 OpenStreetMap contributors, SRTM | Style: \u00a9 OpenTopoMap (CC-BY-SA)',
      MapStyle.esriSatellite => '\u00a9 Esri, Maxar, Earthstar Geographics',
    };
  }
}
