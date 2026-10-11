import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/network/proxy/app_http_overrides.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';

import '../../../../helpers/self_signed_tls.dart';

/// Real TLS on loopback under the app's global HttpOverrides, whose
/// connection factory opens the TLS socket itself (proxy support).
void main() {
  late SelfSignedTls tls;
  late HttpServer server;

  setUpAll(() async => tls = await SelfSignedTls.generate());

  setUp(() async {
    server = await tls.serve();
    addTearDown(() => server.close(force: true));
  });

  Future<T> underAppOverrides<T>(Future<T> Function() body) =>
      HttpOverrides.runWithHttpOverrides(
        body,
        AppHttpOverrides(
          currentProxy: () => const EffectiveProxy.direct(),
          fallbackContext: () => null,
        ),
      );

  WebDavConfig config({String? pin}) => WebDavConfig(
    preset: WebDavPreset.other,
    serverUrl: 'https://127.0.0.1:${server.port}/dav',
    username: 'alice',
    password: 'secret',
    pinnedCertSha256: pin,
  );

  test(
    'an untrusted self-signed certificate is reported with its fingerprint',
    () async {
      final error = await underAppOverrides(() async {
        final client = WebDavClient(config(), backoff: (_) => Duration.zero);
        try {
          await client.stat('');
          return null;
        } on WebDavUntrustedCertificateException catch (e) {
          return e;
        } finally {
          client.close();
        }
      });
      expect(error, isNotNull);
      expect(error!.certificate.sha256, hasLength(64));
      expect(error.certificate.port, server.port);
    },
  );

  test('a pinned certificate gets through the handshake', () async {
    final first = await underAppOverrides(() async {
      final client = WebDavClient(config(), backoff: (_) => Duration.zero);
      try {
        await client.stat('');
        return null;
      } on WebDavUntrustedCertificateException catch (e) {
        return e;
      } finally {
        client.close();
      }
    });
    final pin = first!.certificate.sha256;

    final after = await underAppOverrides(() async {
      final client = WebDavClient(
        config(pin: pin),
        backoff: (_) => Duration.zero,
      );
      try {
        await client.stat('');
        return null;
      } on WebDavException catch (e) {
        return e;
      } finally {
        client.close();
      }
    });
    // The loopback server is not WebDAV: reaching that verdict means TLS
    // completed with the pinned certificate.
    expect(after?.code, WebDavErrorCode.notWebDav);
  });
}
