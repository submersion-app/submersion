import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists iOS / macOS security-scoped bookmark blobs in the platform
/// keychain via flutter_secure_storage.
///
/// Blobs are namespaced under the `bookmark:` key prefix so they don't
/// collide with other secure-storage entries (e.g., network credentials,
/// connector tokens added in later phases).
///
/// Blobs are stored base64-encoded because flutter_secure_storage exposes
/// only a string API on its lowest common denominator.
///
/// Phase 2's `LocalFileResolver` reads from this service when resolving a
/// `MediaItem.bookmarkRef` on iOS / macOS; the resulting blob is passed to
/// `LocalMediaPlatform.resolveBookmark()` which actually starts the
/// security-scoped resource access.
class LocalBookmarkStorage {
  final FlutterSecureStorage _storage;

  LocalBookmarkStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static String _key(String bookmarkRef) => 'bookmark:$bookmarkRef';

  Future<void> write(String bookmarkRef, Uint8List blob) async {
    await _storage.write(key: _key(bookmarkRef), value: base64Encode(blob));
  }

  Future<Uint8List?> read(String bookmarkRef) async {
    final raw = await _storage.read(key: _key(bookmarkRef));
    if (raw == null) return null;
    return base64Decode(raw);
  }

  Future<void> delete(String bookmarkRef) async {
    await _storage.delete(key: _key(bookmarkRef));
  }
}
