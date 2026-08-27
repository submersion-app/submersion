import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/app_security_context.dart';
import 'package:submersion/core/network/embedded_ca_bundle.dart';

void main() {
  group('appSecurityContext', () {
    test(
      'returns null on a non-Windows host so the platform default is used',
      () {
        expect(appSecurityContext(), isNull);
      },
      skip: Platform.isWindows ? 'builds a real context on Windows' : false,
    );

    test('is cached: repeated calls return the same value', () {
      expect(appSecurityContext(), same(appSecurityContext()));
    });
  });

  group('buildWindowsSecurityContext', () {
    test('returns null when no native roots and no fallback are available', () {
      final context = buildWindowsSecurityContext(
        readNativeRoots: () => const [],
        fallbackBundlePem: '',
      );

      expect(context, isNull);
    });

    test(
      'builds a context from the embedded fallback when native is empty',
      () {
        final context = buildWindowsSecurityContext(
          readNativeRoots: () => const [],
          fallbackBundlePem: embeddedCaBundlePem,
        );

        expect(context, isNotNull);
      },
    );

    test('falls back to the bundle when the native read throws', () {
      final context = buildWindowsSecurityContext(
        readNativeRoots: () => throw const _StoreReadFailure(),
        fallbackBundlePem: embeddedCaBundlePem,
      );

      expect(context, isNotNull);
    });

    test('ignores malformed native DER entries without throwing', () {
      // Junk bytes are not valid certificates; the builder must skip them
      // and still fall back to the bundle rather than propagating the error.
      final context = buildWindowsSecurityContext(
        readNativeRoots: () => [
          Uint8List.fromList([1, 2, 3, 4]),
        ],
        fallbackBundlePem: embeddedCaBundlePem,
      );

      expect(context, isNotNull);
    });

    test('ingests a valid native DER root without needing the fallback', () {
      // The success path: a real DER certificate is armored and added as a
      // trust anchor, so a context is built from native roots alone.
      final context = buildWindowsSecurityContext(
        readNativeRoots: () => [_firstEmbeddedCertDer()],
        fallbackBundlePem: '',
      );

      expect(context, isNotNull);
    });
  });

  group('windowsTrustAnchorsPem', () {
    test('always includes the public-CA bundle first, even with many native '
        'roots', () {
      // Regression: the embedded bundle used to be added only when fewer
      // than five native roots were read. A Windows store that returned
      // many roots but happened to omit one (e.g. GlobalSign Root CA - R3,
      // which tile.openstreetmap.org chains to) then left that endpoint
      // unverifiable while other providers worked.
      final manyNativeRoots = List.generate(
        20,
        (i) => Uint8List.fromList([i, i, i, i]),
      );

      final anchors = windowsTrustAnchorsPem(
        nativeRoots: manyNativeRoots,
        fallbackBundlePem: embeddedCaBundlePem,
      );

      expect(
        anchors.first,
        embeddedCaBundlePem,
        reason: 'the bundle must be installed first, into a fresh context',
      );
      expect(
        anchors.length,
        manyNativeRoots.length + 1,
        reason: 'the bundle is merged in addition to every native root',
      );
    });

    test('omits the bundle entry only when it is empty', () {
      expect(
        windowsTrustAnchorsPem(nativeRoots: const [], fallbackBundlePem: ''),
        isEmpty,
      );
    });

    test('armors each native DER root to PEM, after the bundle', () {
      final anchors = windowsTrustAnchorsPem(
        nativeRoots: [_firstEmbeddedCertDer()],
        fallbackBundlePem: embeddedCaBundlePem,
      );

      expect(anchors, hasLength(2));
      expect(anchors[0], embeddedCaBundlePem);
      expect(anchors[1], startsWith('-----BEGIN CERTIFICATE-----'));
    });
  });

  group('embeddedCaBundlePem', () {
    test('is a substantial, loadable public-CA set', () {
      // Guards against a regeneration from an incomplete or wrong source
      // (e.g. macOS /etc/ssl/cert.pem) that ships a near-empty bundle.
      final certCount = '-----BEGIN CERTIFICATE-----'
          .allMatches(embeddedCaBundlePem)
          .length;
      expect(
        certCount,
        greaterThanOrEqualTo(100),
        reason: 'a small bundle implies the wrong/incomplete CA source',
      );

      expect(
        () => SecurityContext(
          withTrustedRoots: false,
        ).setTrustedCertificatesBytes(utf8.encode(embeddedCaBundlePem)),
        returnsNormally,
        reason: 'the bundle must parse and load as PEM trust anchors',
      );
    });
  });
}

/// Decodes the first certificate of the embedded bundle back to DER bytes,
/// giving the tests a genuinely valid trust anchor to feed the native path.
Uint8List _firstEmbeddedCertDer() {
  const begin = '-----BEGIN CERTIFICATE-----';
  const end = '-----END CERTIFICATE-----';
  final start = embeddedCaBundlePem.indexOf(begin) + begin.length;
  final stop = embeddedCaBundlePem.indexOf(end);
  final base64Body = embeddedCaBundlePem
      .substring(start, stop)
      .replaceAll('\n', '')
      .trim();
  return base64.decode(base64Body);
}

class _StoreReadFailure implements Exception {
  const _StoreReadFailure();
}
