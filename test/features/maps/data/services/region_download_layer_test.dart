import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/features/maps/data/services/region_download_layer.dart';

void _noop(Object? _) {}

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
  });
}
