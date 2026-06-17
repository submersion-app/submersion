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
