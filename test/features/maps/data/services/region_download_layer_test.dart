import 'dart:io';
import 'dart:isolate';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/features/maps/data/services/region_download_layer.dart';

void _noop(Object? _) {}

/// What a fresh isolate's early-built client would be told to use for a tile
/// request, after [layer]'s provider has resolved one tile URL there.
///
/// Top-level so the closure sent to the isolate captures only [layer].
Future<String> _proxyForEarlyClient(TileLayer layer) => Isolate.run(() {
  // FMTC's download thread builds its client first, then asks the provider.
  final client = HttpClient();
  final url = layer.tileProvider.getTileUrl(
    const TileCoordinates(1, 2, 3),
    layer,
  );
  client.close(force: true);
  return HttpClient.findProxyFromEnvironment(Uri.parse(url));
});

void main() {
  const url = 'https://example.test/{z}/{x}/{y}.png';

  group('regionDownloadTileLayer', () {
    test('keeps the url template and max zoom it was given', () {
      final layer = regionDownloadTileLayer(urlTemplate: url, maxZoom: 16);

      expect(layer.urlTemplate, url);
      expect(layer.maxZoom, 16);
    });

    test('still sends a User-Agent in the provider headers', () {
      final layer = regionDownloadTileLayer(urlTemplate: url, maxZoom: 16);

      // FMTC copies these headers onto every tile request it makes.
      expect(
        layer.tileProvider.headers['User-Agent'],
        contains('app.submersion'),
      );
    });

    test(
      'the layer can be sent to an isolate under AppHttpOverrides',
      () async {
        // FMTC copies the layer to its download isolate with Isolate.spawn. The
        // overrides put proxy closures (and, as the fallback context here does
        // on Windows, a native SecurityContext) on every HttpClient, which
        // makes a layer with the default network provider unsendable.
        final overrides = AppHttpOverrides(
          currentProxy: () => const EffectiveProxy.direct(),
          fallbackContext: () => SecurityContext(withTrustedRoots: true),
        );

        await HttpOverrides.runWithHttpOverrides(() async {
          final layer = regionDownloadTileLayer(urlTemplate: url, maxZoom: 16);
          final isolate = await Isolate.spawn(_noop, layer);
          isolate.kill();
        }, overrides);
      },
    );

    test('resolving a tile URL in a download isolate routes that isolate '
        'through the proxy it was built with', () async {
      final layer = regionDownloadTileLayer(
        urlTemplate: url,
        maxZoom: 16,
        proxy: const EffectiveProxy(
          kind: ProxyKind.http,
          host: 'proxy.example.test',
          port: 3128,
          source: ProxySource.manual,
        ),
      );

      expect(
        await _proxyForEarlyClient(layer),
        'PROXY proxy.example.test:3128',
      );
    });

    test('defaults to the proxy the app routes by when it is built', () async {
      final overrides = AppHttpOverrides(
        currentProxy: () => const EffectiveProxy(
          kind: ProxyKind.http,
          host: 'app.example.test',
          port: 8080,
          source: ProxySource.manual,
        ),
        fallbackContext: () => null,
      );

      final layer = HttpOverrides.runWithHttpOverrides(
        () => regionDownloadTileLayer(urlTemplate: url, maxZoom: 16),
        overrides,
      );

      expect(await _proxyForEarlyClient(layer), 'PROXY app.example.test:8080');
    });

    test('defaults to a direct connection without the app overrides', () async {
      final layer = regionDownloadTileLayer(urlTemplate: url, maxZoom: 16);

      expect(await _proxyForEarlyClient(layer), 'DIRECT');
    });
  });
  group('socks5BlocksRegionDownload', () {
    const osm = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    EffectiveProxy proxyOf(ProxyKind kind, {List<String> bypass = const []}) =>
        EffectiveProxy(
          kind: kind,
          host: 'proxy.example.test',
          port: 1080,
          bypass: bypass,
          source: ProxySource.manual,
        );

    test('a SOCKS5 proxy the tiles would go through blocks the download', () {
      expect(
        socks5BlocksRegionDownload(
          urlTemplate: osm,
          proxy: proxyOf(ProxyKind.socks5),
        ),
        isTrue,
      );
    });

    test('a template with a subdomain placeholder is checked too', () {
      expect(
        socks5BlocksRegionDownload(
          urlTemplate: 'https://{s}.tile.example.test/{z}/{x}/{y}.png',
          proxy: proxyOf(ProxyKind.socks5),
        ),
        isTrue,
      );
    });

    test('an HTTP proxy does not block it', () {
      expect(
        socks5BlocksRegionDownload(
          urlTemplate: osm,
          proxy: proxyOf(ProxyKind.http),
        ),
        isFalse,
      );
    });

    test('no proxy does not block it', () {
      expect(
        socks5BlocksRegionDownload(
          urlTemplate: osm,
          proxy: const EffectiveProxy.direct(),
        ),
        isFalse,
      );
    });

    test('a SOCKS5 proxy that bypasses the tile server does not block it', () {
      expect(
        socks5BlocksRegionDownload(
          urlTemplate: osm,
          proxy: proxyOf(
            ProxyKind.socks5,
            bypass: const ['tile.openstreetmap.org'],
          ),
        ),
        isFalse,
      );
    });
  });
}
