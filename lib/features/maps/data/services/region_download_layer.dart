import 'package:flutter_map/flutter_map.dart';

/// A tile provider that holds no HTTP client, used only to describe a download.
///
/// FMTC copies the whole [TileLayer] to its download isolate. A layer built
/// without a provider gets flutter_map's `NetworkTileProvider`, which owns an
/// HTTP client, and that client is not sendable: `AppHttpOverrides` puts
/// `findProxy` and `connectionFactory` closures on every `HttpClient` (they
/// reach `ProxyController`, whose pending write future cannot be copied), and
/// on Windows each client also holds a native `SecurityContext`.
/// `Isolate.spawn` then throws "object is unsendable", the download never
/// starts, and the progress card sits at 0 / 0 tiles.
///
/// The download isolate only reads this provider's headers and tile URL, so a
/// provider with no client does the job and can be sent on every platform.
class DownloadTileProvider extends TileProvider {
  DownloadTileProvider();
}

/// The [TileLayer] handed to FMTC to describe [urlTemplate] for a region
/// download or a tile-count estimate.
///
/// `TileCacheService` builds its layers with this, so no caller can pass one
/// that cannot be sent to the download isolate.
TileLayer regionDownloadTileLayer({
  required String urlTemplate,
  required double maxZoom,
}) => TileLayer(
  urlTemplate: urlTemplate,
  userAgentPackageName: 'app.submersion',
  maxZoom: maxZoom,
  tileProvider: DownloadTileProvider(),
);
