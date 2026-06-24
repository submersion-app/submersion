import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:submersion/core/network/embedded_ca_bundle.dart';
import 'package:submersion/core/network/pem.dart';
import 'package:submersion/core/network/windows_root_store.dart';

SecurityContext? _cached;
bool _resolved = false;

/// The process-wide [SecurityContext] to use for outgoing HTTPS, or null to
/// signal "use the platform default".
///
/// Only Windows needs an override: its default trust store is not reliably
/// readable by Dart's BoringSSL, so we seed a context from a complete
/// embedded public-CA bundle merged with the live OS certificate store.
/// Every other platform already verifies correctly with the default
/// context, so this returns null there and callers keep using a plain
/// client. The result is computed once and cached -- reading the native
/// store is the only costly step and must not repeat per request.
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

/// Builds the Windows TLS trust context: the complete embedded public-CA
/// bundle ([fallbackBundlePem]) merged with the live OS roots returned by
/// [readNativeRoots].
///
/// The embedded bundle is installed unconditionally, not just when the native
/// read looks sparse. Windows materializes roots lazily, so a store read can
/// return many roots yet still omit a common one that an endpoint chains to --
/// this is what left tile.openstreetmap.org's GlobalSign root unverifiable
/// while providers on other roots worked. The OS store is then unioned on top
/// for enterprise/private roots the public bundle does not carry.
///
/// Returns null when no trust anchors could be added at all: a context with
/// an empty trust store would reject every TLS connection, which is strictly
/// worse than letting the caller fall back to the platform default.
///
/// Platform-agnostic and dependency-injected so the merge policy is testable
/// off Windows.
@visibleForTesting
SecurityContext? buildWindowsSecurityContext({
  required List<Uint8List> Function() readNativeRoots,
  required String fallbackBundlePem,
}) {
  List<Uint8List> nativeRoots;
  try {
    nativeRoots = readNativeRoots();
  } catch (_) {
    nativeRoots = const [];
  }

  final context = SecurityContext(withTrustedRoots: false);
  var trusted = 0;
  for (final pem in windowsTrustAnchorsPem(
    nativeRoots: nativeRoots,
    fallbackBundlePem: fallbackBundlePem,
  )) {
    try {
      context.setTrustedCertificatesBytes(utf8.encode(pem));
      trusted++;
    } catch (_) {
      // Skip a malformed, duplicate, or otherwise unusable anchor rather than
      // abandoning the whole set.
    }
  }

  return trusted > 0 ? context : null;
}

/// The ordered PEM trust anchors to install for Windows TLS: the full
/// embedded public-CA [fallbackBundlePem] first (whenever non-empty), then
/// each native OS root from [nativeRoots] armored to PEM.
///
/// Bundle-first is deliberate: it is installed into a fresh context in a
/// single call (no duplicates to collide with yet), and any native root that
/// duplicates a bundled one is then skipped by the caller instead of aborting
/// the store. Pure and synchronous so the merge policy can be unit-tested
/// without a Windows host.
@visibleForTesting
List<String> windowsTrustAnchorsPem({
  required List<Uint8List> nativeRoots,
  required String fallbackBundlePem,
}) {
  return [
    if (fallbackBundlePem.isNotEmpty) fallbackBundlePem,
    for (final der in nativeRoots) derToPem(der),
  ];
}
