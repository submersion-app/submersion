import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Dropbox-backed media object store (design spec section 8.2).
///
/// Dropbox is path-native: store keys map to
/// `'$rootPath/[key]'` inside the app folder. Keys are lowercase by
/// construction (hex hashes and fixed literals), so Dropbox's lower-cased
/// path_lower round-trips them safely. Objects above [chunkSizeBytes] go
/// through upload sessions with resume state {sessionId, offset}; resume
/// validation is optimistic - a session error on resume restarts fresh
/// (Dropbox has no ListParts equivalent).
class DropboxMediaObjectStore implements MediaObjectStore {
  DropboxMediaObjectStore({
    required DropboxApiClient client,
    this.rootPath = '/submersion-media',
    this.chunkSizeBytes = 8 * 1024 * 1024,
  }) : _client = client;

  final DropboxApiClient _client;
  final String rootPath;

  /// Session chunk size, and the single-shot/session threshold.
  final int chunkSizeBytes;

  String _path(String key) => '$rootPath/$key';

  String _key(String pathLower) => pathLower.startsWith('$rootPath/')
      ? pathLower.substring(rootPath.length + 1)
      : pathLower;

  @override
  Future<StoreObjectInfo?> head(String key) async {
    try {
      final meta = await _client.getMetadata(_path(key));
      if (meta == null) return null;
      return StoreObjectInfo(
        key: key,
        sizeBytes: meta.size,
        lastModified: meta.serverModified,
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
    final int length;
    try {
      length = await source.length();
    } on FileSystemException catch (e) {
      throw MediaStoreException(
        'cannot read source for $key',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    }
    if (length <= chunkSizeBytes) {
      try {
        await _client.upload(_path(key), await source.readAsBytes());
        onProgress?.call(length, length);
      } on CloudStorageException catch (e) {
        throw _map('put', key, e);
      } on FileSystemException catch (e) {
        throw MediaStoreException(
          'cannot read source for $key',
          kind: MediaStoreErrorKind.fatal,
          cause: e,
        );
      }
      return;
    }
    await _putSession(
      key,
      source,
      length,
      onProgress: onProgress,
      resumeStateJson: resumeStateJson,
      onResumeStateChanged: onResumeStateChanged,
    );
  }

  Future<void> _putSession(
    String key,
    File source,
    int length, {
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  }) async {
    final resume = _parseResume(resumeStateJson);
    final resuming = resume != null;
    try {
      String sessionId;
      int offset;
      final raf = await source.open();
      try {
        if (resume != null) {
          sessionId = resume.sessionId;
          offset = resume.offset;
        } else {
          final first = await raf.read(min(chunkSizeBytes, length));
          sessionId = await _client.uploadSessionStart(first);
          offset = first.length;
          onResumeStateChanged?.call(_resumeToJson(sessionId, offset));
          onProgress?.call(offset, length);
        }

        while (offset < length) {
          await raf.setPosition(offset);
          final remaining = length - offset;
          final isLast = remaining <= chunkSizeBytes;
          final chunk = await raf.read(min(chunkSizeBytes, remaining));
          if (isLast) {
            await _client.uploadSessionFinish(
              sessionId: sessionId,
              offset: offset,
              path: _path(key),
              lastChunk: chunk,
            );
            offset += chunk.length;
            onProgress?.call(offset, length);
          } else {
            await _client.uploadSessionAppend(
              sessionId: sessionId,
              offset: offset,
              chunk: chunk,
            );
            offset += chunk.length;
            onResumeStateChanged?.call(_resumeToJson(sessionId, offset));
            onProgress?.call(offset, length);
          }
        }
      } finally {
        await raf.close();
      }
    } on CloudStorageException catch (e) {
      final text = e.toString();
      final staleSession =
          resuming &&
          (text.contains('incorrect_offset') || text.contains('not_found'));
      if (staleSession) {
        // The recorded session is unusable; start over from scratch.
        return _putSession(
          key,
          source,
          length,
          onProgress: onProgress,
          onResumeStateChanged: onResumeStateChanged,
        );
      }
      throw _map('put', key, e);
    } on FileSystemException catch (e) {
      throw MediaStoreException(
        'cannot read source for $key',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    }
  }

  ({String sessionId, int offset})? _parseResume(String? json) {
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) return null;
      final sessionId = decoded['sessionId'] as String?;
      final offset = (decoded['offset'] as num?)?.toInt();
      final recordedChunk = (decoded['chunkSizeBytes'] as num?)?.toInt();
      if (sessionId == null || offset == null) return null;
      if (recordedChunk != chunkSizeBytes) return null;
      return (sessionId: sessionId, offset: offset);
    } on Exception {
      return null;
    }
  }

  String _resumeToJson(String sessionId, int offset) => jsonEncode({
    'sessionId': sessionId,
    'offset': offset,
    'chunkSizeBytes': chunkSizeBytes,
  });

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    try {
      final meta = await _client.getMetadata(_path(key));
      if (meta == null) {
        throw MediaStoreException(
          'not found: $key',
          kind: MediaStoreErrorKind.notFound,
        );
      }
      final total = meta.size;
      if (total == null || total <= chunkSizeBytes) {
        final bytes = await _client.download(_path(key));
        await destination.writeAsBytes(bytes, flush: true);
        onProgress?.call(bytes.length, bytes.length);
        return;
      }
      final raf = await destination.open(mode: FileMode.write);
      try {
        var received = 0;
        while (received < total) {
          final end = min(received + chunkSizeBytes, total) - 1;
          final range = await _client.downloadRange(
            _path(key),
            start: received,
            endInclusive: end,
          );
          await raf.writeFrom(range.bytes);
          received += range.bytes.length;
          onProgress?.call(received, total);
        }
        await raf.flush();
      } finally {
        await raf.close();
      }
    } on CloudStorageException catch (e) {
      throw _map('get', key, e);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _client.delete(_path(key));
    } on CloudStorageException catch (e) {
      throw _map('delete', key, e);
    }
  }

  @override
  Future<void> abandonResume(String key, String? resumeStateJson) async {
    // Upload sessions expire server-side; nothing to abort.
  }

  @override
  Future<int> reapStaleUploadSessions({required DateTime olderThan}) async {
    // Upload sessions expire server-side; nothing to reap.
    return 0;
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    final List<DropboxFileMetadata> entries;
    try {
      entries = await _client.listFolder(path: rootPath, recursive: true);
    } on CloudStorageException catch (e) {
      throw _map('list', keyPrefix, e);
    }
    for (final meta in entries) {
      final key = _key(meta.pathLower);
      if (!key.startsWith(keyPrefix)) continue;
      yield StoreObjectInfo(
        key: key,
        sizeBytes: meta.size,
        lastModified: meta.serverModified,
      );
    }
  }

  /// Classifies DropboxApiClient's user-facing messages into the retry
  /// taxonomy (see the client's _send error policy).
  MediaStoreException _map(String op, String key, CloudStorageException e) {
    final message = e.message;
    final MediaStoreErrorKind kind;
    if (message.contains('not found')) {
      kind = MediaStoreErrorKind.notFound;
    } else if (message.contains('authorization expired')) {
      kind = MediaStoreErrorKind.auth;
    } else if (message.contains('Could not reach') ||
        message.contains('rate limit')) {
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
