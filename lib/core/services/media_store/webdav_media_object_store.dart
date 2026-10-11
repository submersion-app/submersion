import 'dart:io';

import 'package:submersion/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Retry classification for WebDAV failures in the media queue.
MediaStoreErrorKind mediaStoreKindFor(WebDavErrorCode code) => switch (code) {
  WebDavErrorCode.unauthorized ||
  WebDavErrorCode.forbidden ||
  WebDavErrorCode.untrustedCertificate => MediaStoreErrorKind.auth,
  WebDavErrorCode.notFound => MediaStoreErrorKind.notFound,
  WebDavErrorCode.unreachable ||
  WebDavErrorCode.server ||
  WebDavErrorCode.locked => MediaStoreErrorKind.transient,
  WebDavErrorCode.invalidConfig ||
  WebDavErrorCode.notWebDav ||
  WebDavErrorCode.redirected ||
  WebDavErrorCode.conflict ||
  WebDavErrorCode.tooLarge ||
  WebDavErrorCode.insufficientStorage ||
  WebDavErrorCode.unexpected => MediaStoreErrorKind.fatal,
};

/// Media store on a WebDAV server. Store keys (`smv1/objects/ab/<hash>.jpg`)
/// live under the configured folder. WebDAV needs real collections, so
/// parents are created on demand (the client caches them), and listing
/// walks with Depth 1 because `Depth: infinity` is often disabled.
class WebDavMediaObjectStore implements MediaObjectStore {
  WebDavMediaObjectStore({required WebDavClient client}) : _client = client;

  final WebDavClient _client;

  String get _root => _client.config.folder;
  String _path(String key) => key.isEmpty ? _root : '$_root/$key';
  String _keyOf(String path) => path.substring(_root.length + 1);

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on WebDavException catch (e) {
      throw MediaStoreException(
        e.message,
        kind: mediaStoreKindFor(e.code),
        cause: e,
      );
    } on FileSystemException catch (e) {
      throw MediaStoreException(
        'Could not access the local file',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    }
  }

  bool get _chunks => _client.config.preset.supportsNextcloudChunking;

  @override
  Future<StoreObjectInfo?> head(String key) => _guard(() async {
    final entry = await _client.stat(_path(key));
    if (entry == null || entry.isCollection) return null;
    return StoreObjectInfo(
      key: key,
      sizeBytes: entry.sizeBytes,
      lastModified: entry.lastModified,
    );
  });

  @override
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  }) => _guard(() async {
    final path = _path(key);
    final length = await source.length();
    if (NextcloudChunkedUpload.appliesTo(_client, length)) {
      final done = await NextcloudChunkedUpload(_client).upload(
        path,
        source,
        resumeStateJson: resumeStateJson,
        onResumeStateChanged: onResumeStateChanged,
        onProgress: onProgress,
      );
      if (done) return;
    }
    // Create the shard folder first (cached per client). Relying on the
    // 409 retry would send the whole body twice into every new shard, and a
    // server that answers 409 mid-body and closes the socket surfaces as a
    // transport error, never as the 409 the retry needs.
    await _client.ensureCollection(WebDavClient.parentOf(path));
    await _client.putFile(
      path,
      source,
      contentType: contentType,
      onProgress: onProgress,
    );
  });

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) => _guard(
    () => _client.getToFile(_path(key), destination, onProgress: onProgress),
  );

  @override
  Future<void> delete(String key) => _guard(() => _client.delete(_path(key)));

  @override
  Future<void> abandonResume(String key, String? resumeStateJson) async {
    if (!_chunks) return;
    await NextcloudChunkedUpload(_client).abandon(resumeStateJson);
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    final slash = keyPrefix.lastIndexOf('/');
    final dir = slash < 0 ? '' : keyPrefix.substring(0, slash);
    final namePrefix = keyPrefix.substring(slash + 1);
    yield* _walk(dir, namePrefix, recursive: namePrefix.isEmpty);
  }

  Stream<StoreObjectInfo> _walk(
    String dir,
    String namePrefix, {
    required bool recursive,
  }) async* {
    final List<WebDavEntry> children;
    try {
      children = await _guard(() => _client.listChildren(_path(dir)));
    } on MediaStoreException catch (e) {
      if (e.kind == MediaStoreErrorKind.notFound) return;
      rethrow;
    }
    for (final entry in children) {
      if (entry.isCollection) {
        if (recursive) yield* _walk(_keyOf(entry.path), '', recursive: true);
      } else if (entry.name.startsWith(namePrefix)) {
        yield StoreObjectInfo(
          key: _keyOf(entry.path),
          sizeBytes: entry.sizeBytes,
          lastModified: entry.lastModified,
        );
      }
    }
  }

  @override
  Future<int> reapStaleUploadSessions({required DateTime olderThan}) async {
    if (!_chunks) return 0;
    return _guard(() => NextcloudChunkedUpload(_client).reapStale(olderThan));
  }
}
