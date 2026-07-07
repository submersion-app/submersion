import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path_provider/path_provider.dart';

/// Directory for streaming-sync temp files (base export + assembled base parts).
///
/// Prefers the app-container temp dir via path_provider. A sandboxed or
/// hardened-runtime macOS app is denied `Directory.systemTemp` (`/tmp`) ->
/// `PathAccessException` errno 1 (issue #509), so `/tmp` must never be used in
/// production.
///
/// Falls back to `systemTemp` ONLY when path_provider's plugin infrastructure
/// is absent -- a plain unit test with no mocked channel
/// ([MissingPluginException]) or no initialized test binding at all (the
/// [FlutterError] "Binding has not yet been initialized"). In tests `/tmp` is
/// writable, so this keeps them green without every one mocking path_provider.
/// Any OTHER failure (e.g. a real [PlatformException] from the native side) is
/// a genuine runtime problem and propagates, rather than silently
/// reintroducing the `/tmp` EPERM this fix exists to avoid. In production
/// getTemporaryDirectory resolves normally, so no fallback runs.
Future<Directory> resolveSyncTempDir() async {
  try {
    return await getTemporaryDirectory();
  } on MissingPluginException {
    return Directory.systemTemp;
  } on FlutterError {
    return Directory.systemTemp;
  }
}
