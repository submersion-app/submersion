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
///
/// The resolved directory is created if absent (issue #554). On macOS
/// getTemporaryDirectory maps to the sandbox `Library/Caches/<bundleId>` dir,
/// which the OS may purge and does not guarantee exists; path_provider returns
/// the path without creating it. Opening a base-export temp file for write in a
/// missing dir threw `PathNotFoundException: Cannot open file ... No such file
/// or directory (errno = 2)`, crashing every macOS sync while iPhone/iPad --
/// which reliably have the dir -- were unaffected. `create(recursive: true)` is
/// idempotent and always permitted inside the app's own container.
Future<Directory> resolveSyncTempDir() async {
  try {
    final dir = await getTemporaryDirectory();
    await dir.create(recursive: true);
    return dir;
  } on MissingPluginException {
    return Directory.systemTemp;
  } on FlutterError catch (e) {
    // ONLY the "no test binding" case (a unit test that never called
    // TestWidgetsFlutterBinding.ensureInitialized, so ServicesBinding.instance
    // throws). Any other FlutterError is a real problem and must surface, not
    // silently fall back to /tmp.
    if (e.toString().contains('Binding has not yet been initialized')) {
      return Directory.systemTemp;
    }
    rethrow;
  }
}
