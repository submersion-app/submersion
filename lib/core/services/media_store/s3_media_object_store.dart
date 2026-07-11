import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

/// S3-backed media object store.
///
/// Wire keys are '$keyPrefix$key' -- S3ApiClient._target does NOT apply the
/// configured prefix, so this adapter must. Objects at or below
/// [partSizeBytes] use single-shot transfers; larger objects go through S3
/// multipart with per-part resume state (design spec section 8.2), and
/// downloads above [downloadChunkBytes] stream Range chunks to disk so
/// memory stays bounded for arbitrarily large media.
class S3MediaObjectStore implements MediaObjectStore {
  S3MediaObjectStore({
    required S3ApiClient client,
    required String keyPrefix,
    this.partSizeBytes = 8 * 1024 * 1024,
    this.downloadChunkBytes = 8 * 1024 * 1024,
  }) : _client = client,
       _keyPrefix = keyPrefix;

  final S3ApiClient _client;
  final String _keyPrefix;

  /// Multipart part size, and the single-shot/multipart threshold.
  final int partSizeBytes;

  /// Range-GET chunk size, and the whole-body/chunked download threshold.
  final int downloadChunkBytes;

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
    if (length <= partSizeBytes) {
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
        await _client.putObject(_wire(key), bytes, contentType: contentType);
        onProgress?.call(bytes.length, bytes.length);
      } on CloudStorageException catch (e) {
        throw _map('put', key, e);
      }
      return;
    }
    await _putMultipart(
      key,
      source,
      length,
      contentType: contentType,
      onProgress: onProgress,
      resumeStateJson: resumeStateJson,
      onResumeStateChanged: onResumeStateChanged,
    );
  }

  Future<void> _putMultipart(
    String key,
    File source,
    int length, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  }) async {
    final wireKey = _wire(key);
    try {
      var session = await _validateResume(wireKey, resumeStateJson);
      session ??= (
        uploadId: await _client.createMultipartUpload(
          wireKey,
          contentType: contentType,
        ),
        parts: <S3PartInfo>[],
      );
      final parts = [...session.parts];
      final totalParts = (length + partSizeBytes - 1) ~/ partSizeBytes;
      var bytesSent = parts.length * partSizeBytes;

      final raf = await source.open();
      try {
        for (var n = parts.length + 1; n <= totalParts; n++) {
          final offset = (n - 1) * partSizeBytes;
          await raf.setPosition(offset);
          final chunk = await raf.read(min(partSizeBytes, length - offset));
          final etag = await _client.uploadPart(
            wireKey,
            uploadId: session.uploadId,
            partNumber: n,
            bytes: chunk,
          );
          parts.add(S3PartInfo(partNumber: n, etag: etag));
          bytesSent = min(bytesSent + partSizeBytes, length);
          onResumeStateChanged?.call(_resumeToJson(session.uploadId, parts));
          onProgress?.call(bytesSent, length);
        }
      } finally {
        await raf.close();
      }

      await _client.completeMultipartUpload(
        wireKey,
        uploadId: session.uploadId,
        parts: parts,
      );
    } on CloudStorageException catch (e) {
      throw _map('put', key, e);
    } on FileSystemException catch (e) {
      throw MediaStoreException(
        'cannot read source for $key',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    }
  }

  /// Parses and server-verifies a previous attempt's resume state. Returns
  /// null (after a best-effort abort) when the state is absent, malformed,
  /// sized differently, or no longer matches the server's part list.
  Future<({String uploadId, List<S3PartInfo> parts})?> _validateResume(
    String wireKey,
    String? resumeStateJson,
  ) async {
    if (resumeStateJson == null) return null;
    String? uploadId;
    try {
      final decoded = jsonDecode(resumeStateJson);
      if (decoded is! Map<String, Object?>) return null;
      uploadId = decoded['uploadId'] as String?;
      final recordedPartSize = (decoded['partSizeBytes'] as num?)?.toInt();
      final rawParts = decoded['parts'];
      if (uploadId == null ||
          recordedPartSize != partSizeBytes ||
          rawParts is! List) {
        await _abortQuietly(wireKey, uploadId);
        return null;
      }
      final recorded = <S3PartInfo>[
        for (final raw in rawParts.cast<Map<String, Object?>>())
          S3PartInfo(
            partNumber: (raw['n'] as num).toInt(),
            etag: raw['etag'] as String,
          ),
      ];
      final serverParts = await _client.listParts(wireKey, uploadId: uploadId);
      final serverByNumber = {
        for (final part in serverParts) part.partNumber: part.etag,
      };
      final consistent = recorded.every(
        (part) => serverByNumber[part.partNumber] == part.etag,
      );
      if (!consistent) {
        await _abortQuietly(wireKey, uploadId);
        return null;
      }
      return (uploadId: uploadId, parts: recorded);
    } catch (_) {
      // Malformed or wrongly-typed JSON (persisted resume state is
      // untrusted; bad casts throw TypeError, an Error), unknown uploadId,
      // or listParts failure: the resume point is unusable; start over.
      await _abortQuietly(wireKey, uploadId);
      return null;
    }
  }

  Future<void> _abortQuietly(String wireKey, String? uploadId) async {
    if (uploadId == null) return;
    try {
      await _client.abortMultipartUpload(wireKey, uploadId: uploadId);
    } on Exception {
      // Best-effort: an unaborted stray session expires server-side.
    }
  }

  String _resumeToJson(String uploadId, List<S3PartInfo> parts) => jsonEncode({
    'uploadId': uploadId,
    'partSizeBytes': partSizeBytes,
    'parts': [
      for (final part in parts) {'n': part.partNumber, 'etag': part.etag},
    ],
  });

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    try {
      final info = await _client.headObject(_wire(key));
      if (info == null) {
        throw CloudStorageException('File not found in S3: $key');
      }
      final total = info.size;
      if (total == null || total <= downloadChunkBytes) {
        final bytes = await _client.getObject(_wire(key));
        await destination.writeAsBytes(bytes, flush: true);
        onProgress?.call(bytes.length, bytes.length);
        return;
      }
      final raf = await destination.open(mode: FileMode.write);
      try {
        var received = 0;
        while (received < total) {
          final end = min(received + downloadChunkBytes, total) - 1;
          final range = await _client.getObjectRange(
            _wire(key),
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
