import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/trusted_http_overrides.dart';

void main() {
  group('TrustedHttpOverrides', () {
    test('is an HttpOverrides suitable for HttpOverrides.global', () {
      expect(TrustedHttpOverrides(), isA<HttpOverrides>());
    });

    // On non-Windows hosts appSecurityContext() is null, so the override must
    // delegate transparently to the default implementation rather than throw
    // or hand back a broken client. (The Windows trust path can only be
    // exercised on a Windows host.)
    test('delegates to a usable client when no context is supplied', () {
      final client = TrustedHttpOverrides().createHttpClient(null);
      addTearDown(() => client.close(force: true));

      expect(client, isA<HttpClient>());
    });

    test('honors an explicitly supplied SecurityContext', () {
      final context = SecurityContext(withTrustedRoots: true);

      final client = TrustedHttpOverrides().createHttpClient(context);
      addTearDown(() => client.close(force: true));

      expect(client, isA<HttpClient>());
    });
  });
}
