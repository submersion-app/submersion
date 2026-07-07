import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Directory for streaming-sync temp files (base export + assembled base parts).
///
/// Prefers the app-container temp dir via path_provider. A sandboxed or
/// hardened-runtime macOS app is denied `Directory.systemTemp` (`/tmp`) ->
/// `PathAccessException` errno 1 (issue #509), so `/tmp` must never be used in
/// production. Falls back to `systemTemp` ONLY when path_provider is
/// unavailable -- e.g. a plain unit test with no mocked plugin channel -- where
/// `/tmp` is writable, so the fallback keeps such tests green without every one
/// of them mocking path_provider. In production getTemporaryDirectory always
/// resolves, so the fallback never runs there.
Future<Directory> resolveSyncTempDir() async {
  try {
    return await getTemporaryDirectory();
  } catch (_) {
    return Directory.systemTemp;
  }
}
