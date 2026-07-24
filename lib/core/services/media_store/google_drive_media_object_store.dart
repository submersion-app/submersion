import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Google Drive-backed media object store (design spec section 8.2), raw
/// REST over an authenticated client. One folder in appDataFolder holds
/// every object; the file NAME is the full store key (Drive names allow
/// '/'). ALL uploads go through resumable sessions - one code path for
/// photos and videos - with resume via the `Content-Range: bytes */total`
/// probe. [chunkSizeBytes] must be a multiple of 256 KiB (Drive rule).
class GoogleDriveMediaObjectStore implements MediaObjectStore {
  GoogleDriveMediaObjectStore({
    required http.Client client,
    this.folderName = 'submersion-media',
    this.chunkSizeBytes = 8 * 1024 * 1024,
    String apiBase = 'https://www.googleapis.com',
  }) : _client = client,
       _apiBase = apiBase;

  final http.Client _client;
  final String folderName;
  final int chunkSizeBytes;
  final String _apiBase;

  String? _folderId;

  @override
  Future<StoreObjectInfo?> head(String key) async {
    final found = await _findByKey(key);
    if (found == null) return null;
    return StoreObjectInfo(
      key: key,
      sizeBytes: found.size,
      lastModified: found.modified ?? DateTime.now(),
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

    var sessionUri = _parseResume(resumeStateJson, length);
    var offset = 0;
    if (sessionUri != null) {
      final probed = await _probeSession(sessionUri, length);
      if (probed == null) {
        sessionUri = null; // stale session: start over
      } else if (probed == length) {
        onProgress?.call(length, length);
        return; // the previous attempt actually completed
      } else {
        offset = probed;
      }
    }
    sessionUri ??= await _startSession(key, contentType);
    if (offset == 0) {
      onResumeStateChanged?.call(_resumeToJson(sessionUri, length));
    }

    final raf = await source.open();
    try {
      while (offset < length) {
        await raf.setPosition(offset);
        final chunk = await raf.read(min(chunkSizeBytes, length - offset));
        final end = offset + chunk.length - 1;
        final response = await _send(
          http.Request('PUT', Uri.parse(sessionUri))
            ..headers['Content-Range'] = 'bytes $offset-$end/$length'
            ..bodyBytes = chunk,
        );
        if (response.statusCode != 308 &&
            response.statusCode != 200 &&
            response.statusCode != 201) {
          throw _forStatus('put', key, response);
        }
        offset += chunk.length;
        onResumeStateChanged?.call(_resumeToJson(sessionUri, length));
        onProgress?.call(offset, length);
      }
    } on FileSystemException catch (e) {
      throw MediaStoreException(
        'cannot read source for $key',
        kind: MediaStoreErrorKind.fatal,
        cause: e,
      );
    } finally {
      await raf.close();
    }
  }

  /// The server-confirmed byte count for a session, null when the session
  /// is stale, or the total when the upload already completed.
  Future<int?> _probeSession(String sessionUri, int total) async {
    final response = await _send(
      http.Request('PUT', Uri.parse(sessionUri))
        ..headers['Content-Range'] = 'bytes */$total',
    );
    if (response.statusCode == 200 || response.statusCode == 201) return total;
    if (response.statusCode != 308) return null;
    final range = response.headers['range'];
    if (range == null) return 0;
    final match = RegExp(r'bytes=0-(\d+)').firstMatch(range);
    return match == null ? 0 : int.parse(match.group(1)!) + 1;
  }

  Future<String> _startSession(String key, String contentType) async {
    final folderId = await _ensureFolder();
    // Content-addressed keys never change content; a leftover file for the
    // same key can only be interrupted garbage - replace it.
    final existing = await _findByKey(key);
    if (existing != null) await _deleteById(existing.id);

    final response = await _send(
      http.Request(
          'POST',
          Uri.parse('$_apiBase/upload/drive/v3/files?uploadType=resumable'),
        )
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..headers['X-Upload-Content-Type'] = contentType
        ..body = jsonEncode({
          'name': key,
          'parents': [folderId],
        }),
    );
    if (response.statusCode != 200) {
      throw _forStatus('start session for', key, response);
    }
    final location = response.headers['location'];
    if (location == null || location.isEmpty) {
      throw MediaStoreException(
        'Drive returned no session URI for $key',
        kind: MediaStoreErrorKind.fatal,
      );
    }
    return location;
  }

  String? _parseResume(String? json, int length) {
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, Object?>) return null;
      if ((decoded['totalBytes'] as num?)?.toInt() != length) return null;
      if ((decoded['chunkSizeBytes'] as num?)?.toInt() != chunkSizeBytes) {
        return null;
      }
      return decoded['sessionUri'] as String?;
    } on Exception {
      return null;
    }
  }

  String _resumeToJson(String sessionUri, int total) => jsonEncode({
    'sessionUri': sessionUri,
    'totalBytes': total,
    'chunkSizeBytes': chunkSizeBytes,
  });

  @override
  Future<void> getFile(
    String key,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    final found = await _findByKey(key);
    if (found == null) {
      throw MediaStoreException(
        'not found: $key',
        kind: MediaStoreErrorKind.notFound,
      );
    }
    final total = found.size;
    if (total == null || total <= chunkSizeBytes) {
      final response = await _send(
        http.Request(
          'GET',
          Uri.parse('$_apiBase/drive/v3/files/${found.id}?alt=media'),
        ),
      );
      if (response.statusCode != 200) {
        throw _forStatus('get', key, response);
      }
      await destination.writeAsBytes(response.bodyBytes, flush: true);
      onProgress?.call(response.bodyBytes.length, response.bodyBytes.length);
      return;
    }
    final raf = await destination.open(mode: FileMode.write);
    try {
      var received = 0;
      while (received < total) {
        final end = min(received + chunkSizeBytes, total) - 1;
        final response = await _send(
          http.Request(
            'GET',
            Uri.parse('$_apiBase/drive/v3/files/${found.id}?alt=media'),
          )..headers['Range'] = 'bytes=$received-$end',
        );
        if (response.statusCode != 206 && response.statusCode != 200) {
          throw _forStatus('get range of', key, response);
        }
        await raf.writeFrom(response.bodyBytes);
        received += response.bodyBytes.length;
        onProgress?.call(received, total);
      }
      await raf.flush();
    } finally {
      await raf.close();
    }
  }

  @override
  Future<void> delete(String key) async {
    final found = await _findByKey(key);
    if (found == null) return; // idempotent
    await _deleteById(found.id);
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

  Future<void> _deleteById(String id) async {
    final response = await _send(
      http.Request('DELETE', Uri.parse('$_apiBase/drive/v3/files/$id')),
    );
    if (response.statusCode != 204 &&
        response.statusCode != 200 &&
        response.statusCode != 404) {
      throw _forStatus('delete', id, response);
    }
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    final folderId = await _ensureFolder();
    final files = await _query("'$folderId' in parents and trashed = false");
    for (final file in files) {
      if (!file.name.startsWith(keyPrefix)) continue;
      yield StoreObjectInfo(
        key: file.name,
        sizeBytes: file.size,
        lastModified: file.modified ?? DateTime.now(),
      );
    }
  }

  Future<String> _ensureFolder() async {
    final cached = _folderId;
    if (cached != null) return cached;
    final query =
        "name = '$folderName' "
        "and mimeType = 'application/vnd.google-apps.folder' "
        "and 'appDataFolder' in parents and trashed = false";
    final found = await _query(query);
    if (found.isNotEmpty) {
      return _folderId = found.first.id;
    }
    final response = await _send(
      http.Request('POST', Uri.parse('$_apiBase/drive/v3/files'))
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..body = jsonEncode({
          'name': folderName,
          'mimeType': 'application/vnd.google-apps.folder',
          'parents': ['appDataFolder'],
        }),
    );
    if (response.statusCode != 200) {
      throw _forStatus('create folder for', folderName, response);
    }
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    return _folderId = decoded['id'] as String;
  }

  Future<_DriveFile?> _findByKey(String key) async {
    final folderId = await _ensureFolder();
    final escaped = key.replaceAll("'", r"\'");
    final files = await _query(
      "name = '$escaped' and '$folderId' in parents and trashed = false",
    );
    return files.isEmpty ? null : files.first;
  }

  Future<List<_DriveFile>> _query(String q) async {
    final uri = Uri.parse('$_apiBase/drive/v3/files').replace(
      queryParameters: {
        'spaces': 'appDataFolder',
        'q': q,
        'fields': 'files(id,name,modifiedTime,size)',
      },
    );
    final response = await _send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw _forStatus('query', q, response);
    }
    final decoded = jsonDecode(response.body) as Map<String, Object?>;
    final files = decoded['files'] as List<Object?>? ?? const [];
    return [
      for (final raw in files.cast<Map<String, Object?>>())
        _DriveFile(
          id: raw['id'] as String,
          name: raw['name'] as String,
          size: int.tryParse(raw['size'] as String? ?? ''),
          modified: DateTime.tryParse(raw['modifiedTime'] as String? ?? ''),
        ),
    ];
  }

  Future<http.Response> _send(http.Request request) async {
    try {
      return await http.Response.fromStream(await _client.send(request));
    } on Exception catch (e) {
      throw MediaStoreException(
        'Could not reach Google Drive',
        kind: MediaStoreErrorKind.transient,
        cause: e,
      );
    }
  }

  MediaStoreException _forStatus(
    String op,
    String subject,
    http.Response response,
  ) {
    final status = response.statusCode;
    final MediaStoreErrorKind kind;
    if (status == 401 || status == 403) {
      kind = MediaStoreErrorKind.auth;
    } else if (status == 404) {
      kind = MediaStoreErrorKind.notFound;
    } else if (status == 429 || status >= 500) {
      kind = MediaStoreErrorKind.transient;
    } else {
      kind = MediaStoreErrorKind.fatal;
    }
    return MediaStoreException(
      'Drive $op $subject failed (HTTP $status)',
      kind: kind,
    );
  }
}

class _DriveFile {
  const _DriveFile({
    required this.id,
    required this.name,
    this.size,
    this.modified,
  });

  final String id;
  final String name;
  final int? size;
  final DateTime? modified;
}
