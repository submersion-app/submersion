import 'dart:io';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// S3-backed media object store (Phase 1: single-shot transfers).
///
/// Wire keys are '$keyPrefix$key' -- S3ApiClient._target does NOT apply the
/// configured prefix, so this adapter must. Whole-byte transfers are
/// acceptable for photos; Phase 3 replaces the internals with multipart +
/// Range streaming for video without changing the interface.
class S3MediaObjectStore implements MediaObjectStore {
  S3MediaObjectStore({required S3ApiClient client, required String keyPrefix})
    : _client = client,
      _keyPrefix = keyPrefix;

  final S3ApiClient _client;
  final String _keyPrefix;

  String _wire(String key) => '$_keyPrefix$key';

  @override
  Future<StoreObjectInfo?> head(String key) async {
    try {
      final info = await _client.headObject(_wire(key));
      if (info == null) return null;
      return StoreObjectInfo(
        key: key,
        sizeBytes: info.size,
        lastModified: info.lastModified,
      );
    } on CloudStorageException catch (e) {
      throw _map('head', key, e);
    }
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
    final Uint8List bytes;
    try {
      bytes = await source.readAsBytes();
    } on FileSystemException catch (e) {
      throw MediaStoreException(
        'cannot read source for $key',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    }
    try {
      await _client.putObject(_wire(key), bytes);
      onProgress?.call(bytes.length, bytes.length);
    } on CloudStorageException catch (e) {
      throw _map('put', key, e);
    }
  }

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    try {
      final bytes = await _client.getObject(_wire(key));
      await destination.writeAsBytes(bytes, flush: true);
      onProgress?.call(bytes.length, bytes.length);
    } on CloudStorageException catch (e) {
      throw _map('get', key, e);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _client.deleteObject(_wire(key));
    } on CloudStorageException catch (e) {
      throw _map('delete', key, e);
    }
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    final List<S3ObjectInfo> infos;
    try {
      infos = await _client.listObjects(prefix: _wire(keyPrefix));
    } on CloudStorageException catch (e) {
      throw _map('list', keyPrefix, e);
    }
    for (final info in infos) {
      yield StoreObjectInfo(
        key: info.key.startsWith(_keyPrefix)
            ? info.key.substring(_keyPrefix.length)
            : info.key,
        sizeBytes: info.size,
        lastModified: info.lastModified,
      );
    }
  }

  /// Classifies S3ApiClient's user-facing messages (see _throwFor and
  /// getObject in s3_api_client.dart) into the retry taxonomy.
  MediaStoreException _map(String op, String key, CloudStorageException e) {
    final message = e.message;
    final MediaStoreErrorKind kind;
    if (message.startsWith('File not found in S3')) {
      kind = MediaStoreErrorKind.notFound;
    } else if (message.contains('Access denied')) {
      kind = MediaStoreErrorKind.auth;
    } else if (message.contains('Could not reach')) {
      kind = MediaStoreErrorKind.transient;
    } else {
      kind = MediaStoreErrorKind.fatal;
    }
    return MediaStoreException(
      '$op $key failed: $message',
      kind: kind,
      cause: e,
    );
  }
}
