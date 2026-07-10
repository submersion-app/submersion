import 'dart:io';

import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Test double: byte-map-backed store with one-shot failure injection.
class InMemoryMediaObjectStore implements MediaObjectStore {
  final Map<String, List<int>> objects = {};
  final Map<String, DateTime> modified = {};

  /// When set, the next operation throws it once and clears the field.
  Exception? failNextWith;

  void _maybeFail() {
    final e = failNextWith;
    if (e != null) {
      failNextWith = null;
      throw e;
    }
  }

  @override
  Future<StoreObjectInfo?> head(String key) async {
    _maybeFail();
    final bytes = objects[key];
    if (bytes == null) return null;
    return StoreObjectInfo(
      key: key,
      sizeBytes: bytes.length,
      lastModified: modified[key] ?? DateTime.now(),
    );
  }

  @override
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  }) async {
    _maybeFail();
    final bytes = await source.readAsBytes();
    objects[key] = bytes;
    modified[key] = DateTime.now();
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    _maybeFail();
    final bytes = objects[key];
    if (bytes == null) {
      throw MediaStoreException(
        'not found: $key',
        kind: MediaStoreErrorKind.notFound,
      );
    }
    await destination.writeAsBytes(bytes, flush: true);
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> delete(String key) async {
    _maybeFail();
    objects.remove(key);
    modified.remove(key);
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    _maybeFail();
    for (final entry in objects.entries) {
      if (entry.key.startsWith(keyPrefix)) {
        yield StoreObjectInfo(
          key: entry.key,
          sizeBytes: entry.value.length,
          lastModified: modified[entry.key] ?? DateTime.now(),
        );
      }
    }
  }
}
