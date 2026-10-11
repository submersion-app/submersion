import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/network/proxy/isolate_http_overrides.dart';
import 'package:submersion/core/network/proxy/proxy_routing.dart';

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
///
/// Those isolates also start without the app's `AppHttpOverrides` (statics
/// are per isolate), and FMTC builds each download thread's client before any
/// app code runs there (#3269). [getTileUrl] is the first app code to run in
/// them, so it installs the overrides, routed by [proxy]: that keeps the
/// Windows trust and the HTTP proxy for every tile request, and refuses a
/// SOCKS5 proxy the thread's client cannot use rather than going around it.
class DownloadTileProvider extends TileProvider {
  DownloadTileProvider({this.proxy = const EffectiveProxy.direct()});

  /// The proxy the download isolates route by, as it stood when the download
  /// started.
  final EffectiveProxy proxy;

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    ensureIsolateHttpOverrides(proxy);
    return super.getTileUrl(coordinates, options);
  }
}

/// The [TileLayer] handed to FMTC to describe [urlTemplate] for a region
/// download or a tile-count estimate.
///
/// `TileCacheService` builds its layers with this, so no caller can pass one
/// that cannot be sent to the download isolate. The download routes by
/// [proxy], by default the app's proxy at the moment the layer is built.
TileLayer regionDownloadTileLayer({
  required String urlTemplate,
  required double maxZoom,
  EffectiveProxy? proxy,
}) => TileLayer(
  urlTemplate: urlTemplate,
  userAgentPackageName: 'app.submersion',
  maxZoom: maxZoom,
  tileProvider: DownloadTileProvider(proxy: proxy ?? currentAppProxy()),
);

/// Whether [proxy] would send [urlTemplate]'s tiles through SOCKS5, which a
/// region download cannot use.
///
/// FMTC's download threads build their clients before app code runs there,
/// and dart:io can only route such a client through an HTTP proxy or
/// directly ([DownloadTileProvider]). Every tile would fail, so the download
/// dialog checks this first and says why instead (#3269). A SOCKS5 proxy that
/// bypasses the tile server does not block it.
bool socks5BlocksRegionDownload({
  required String urlTemplate,
  required EffectiveProxy proxy,
}) {
  if (proxy.kind != ProxyKind.socks5) return false;
  final layer = regionDownloadTileLayer(
    urlTemplate: urlTemplate,
    maxZoom: 1,
    proxy: proxy,
  );
  final sample = layer.tileProvider.getTileUrl(
    const TileCoordinates(0, 0, 0),
    layer,
  );
  final url = Uri.tryParse(sample);
  return url == null || defaultShouldProxy(url, proxy);
}
