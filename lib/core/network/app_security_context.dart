import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/embedded_ca_bundle.dart';
import 'package:submersion/core/network/pem.dart';
import 'package:submersion/core/network/windows_root_store.dart';

/// Below this many successfully-trusted native roots we assume the store
/// read effectively failed (FFI error, empty/locked store) and add the
/// embedded fallback bundle so TLS can still verify public CAs.
const int _minNativeRoots = 5;

SecurityContext? _cached;
bool _resolved = false;

/// The process-wide [SecurityContext] to use for outgoing HTTPS, or null to
/// signal "use the platform default".
///
/// Only Windows needs an override: its default trust store is not reliably
/// readable by Dart's BoringSSL, so we seed a context from the OS
/// certificate store (with an embedded fallback). Every other platform
/// already verifies correctly with the default context, so this returns
/// null there and callers keep using a plain client. The result is computed
/// once and cached -- reading the native store is the only costly step and
/// must not repeat per request.
SecurityContext? appSecurityContext() {
  if (_resolved) return _cached;
  _resolved = true;
  if (!Platform.isWindows) {
    _cached = null;
    return _cached;
  }
  // Windows-only: the native store read + context build cannot run on the
  // non-Windows CI host, so it is excluded from coverage. The pure builder
  // it delegates to (buildWindowsSecurityContext) is covered directly.
  // coverage:ignore-start
  _cached = buildWindowsSecurityContext(
    readNativeRoots: readWindowsRootCertificates,
    fallbackBundlePem: embeddedCaBundlePem,
  );
  return _cached;
  // coverage:ignore-end
}

/// Builds a Windows trust context from [readNativeRoots] DER certificates,
/// adding [fallbackBundlePem] when too few native roots are usable.
///
/// Returns null when no trust anchors could be added at all: a context with
/// an empty trust store would reject every TLS connection, which is strictly
/// worse than letting the caller fall back to the platform default.
///
/// Platform-agnostic and dependency-injected so the fallback decision is
/// testable off Windows.
@visibleForTesting
SecurityContext? buildWindowsSecurityContext({
  required List<Uint8List> Function() readNativeRoots,
  required String fallbackBundlePem,
}) {
  final context = SecurityContext(withTrustedRoots: false);
  var trusted = 0;

  List<Uint8List> nativeRoots;
  try {
    nativeRoots = readNativeRoots();
  } catch (_) {
    nativeRoots = const [];
  }
  for (final der in nativeRoots) {
    try {
      context.setTrustedCertificatesBytes(utf8.encode(derToPem(der)));
      trusted++;
    } catch (_) {
      // Skip one malformed entry rather than abandoning the whole store.
    }
  }

  if (trusted < _minNativeRoots && fallbackBundlePem.isNotEmpty) {
    try {
      context.setTrustedCertificatesBytes(utf8.encode(fallbackBundlePem));
      trusted++;
    } catch (_) {
      // Fallback unusable; fall through to the empty-store guard below.
    }
  }

  return trusted > 0 ? context : null;
}
