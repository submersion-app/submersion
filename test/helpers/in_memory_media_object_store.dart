import 'dart:io';

import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Test double: byte-map-backed store with one-shot failure injection.
class InMemoryMediaObjectStore implements MediaObjectStore {
  final Map<String, List<int>> objects = {};
  final Map<String, DateTime> modified = {};

  /// When set, the next operation throws it once and clears the field.
  Exception? failNextWith;

  /// When set, the next delete throws it once and clears the field. Unlike
  /// [failNextWith] this targets delete specifically, so a test can fail a
  /// best-effort GC delete without tripping the preceding putFile/head.
  Exception? failDeleteWith;

  /// When set, putFile fires onResumeStateChanged with this JSON once per
  /// call (pipeline wiring tests).
  String? emitResumeState;

  /// When set, the next getFile writes these bytes to the destination and
  /// then throws (models a chunked download dying mid-transfer, which
  /// leaves a partial file behind).
  List<int>? partialGetThenFail;

  /// The resumeStateJson the last putFile call received.
  String? lastResumeStateJsonIn;

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
    lastResumeStateJsonIn = resumeStateJson;
    final bytes = await source.readAsBytes();
    objects[key] = bytes;
    modified[key] = DateTime.now();
    final emit = emitResumeState;
    if (emit != null) onResumeStateChanged?.call(emit);
    onProgress?.call(bytes.length, bytes.length);
  }

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    _maybeFail();
    final partial = partialGetThenFail;
    if (partial != null) {
      partialGetThenFail = null;
      await destination.writeAsBytes(partial, flush: true);
      throw const MediaStoreException(
        'connection lost mid-download',
        kind: MediaStoreErrorKind.transient,
      );
    }
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
    final e = failDeleteWith;
    if (e != null) {
      failDeleteWith = null;
      throw e;
    }
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
