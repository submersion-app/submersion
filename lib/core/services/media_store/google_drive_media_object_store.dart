import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/media_store/media_object_store.dart';

/// Google Drive-backed media object store (design spec section 8.2), raw
/// REST over an authenticated client. One folder in appDataFolder holds
/// every object; the file NAME is the full store key (Drive names allow
/// '/'). ALL uploads go through resumable sessions - one code path for
/// photos and videos - with resume via the `Content-Range: bytes */total`
/// probe. [chunkSizeBytes] must be a multiple of 256 KiB (Drive rule).
class GoogleDriveMediaObjectStore implements MediaObjectStore {
  /// [clientSupplier] is asked for the authenticator's *current* client on
  /// every request. It must not be replaced by a captured client: the
  /// Google authenticators close and replace theirs on every re-auth
  /// (GoogleSignInAuthenticator._installClient / signOut /
  /// handleAuthFailure, DesktopOAuthAuthenticator._teardownClient), and
  /// the runtime holding this store outlives all of them, so a captured
  /// client goes dead at the first token refresh and every later transfer
  /// throws "Client is already closed". Null means no Google session is
  /// available right now.
  GoogleDriveMediaObjectStore({
    required Future<http.Client?> Function() clientSupplier,
    this.folderName = 'submersion-media',
    this.chunkSizeBytes = 8 * 1024 * 1024,
    String apiBase = 'https://www.googleapis.com',
  }) : _clientSupplier = clientSupplier,
       _apiBase = apiBase;

  /// For tests and any caller that owns the client's lifetime outright.
  /// Production callers must use the default constructor so the store
  /// follows re-auth.
  @visibleForTesting
  GoogleDriveMediaObjectStore.withClient(
    http.Client client, {
    String folderName = 'submersion-media',
    int chunkSizeBytes = 8 * 1024 * 1024,
    String apiBase = 'https://www.googleapis.com',
  }) : this(
         clientSupplier: () async => client,
         folderName: folderName,
         chunkSizeBytes: chunkSizeBytes,
         apiBase: apiBase,
       );

  final Future<http.Client?> Function() _clientSupplier;
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

  /// Drive's documented per-page maximum, requested explicitly so a large
  /// media folder needs as few round trips as possible.
  static const _queryPageSize = 1000;

  /// Every file matching [q], following Drive's `nextPageToken` to
  /// exhaustion.
  ///
  /// files.list serves one page at a time (100 results by default, 1000
  /// max) and reports the rest only through `nextPageToken`. A single call
  /// hid every media object past the cap from [list], and could return a
  /// short or empty first page for a name lookup -- which [_findByKey]
  /// would read as "absent" and re-upload.
  ///
  /// `nextPageToken` has to be named in `fields` alongside `files(...)`:
  /// the projection applies to the whole response, so asking only for
  /// `files(...)` strips the token and the loop would stop after one page.
  Future<List<_DriveFile>> _query(String q) async {
    final results = <_DriveFile>[];
    String? pageToken;
    do {
      final uri = Uri.parse('$_apiBase/drive/v3/files').replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': q,
          'pageSize': '$_queryPageSize',
          'pageToken': ?pageToken,
          'fields': 'nextPageToken,files(id,name,modifiedTime,size)',
        },
      );
      final response = await _send(http.Request('GET', uri));
      if (response.statusCode != 200) {
        throw _forStatus('query', q, response);
      }
      final decoded = jsonDecode(response.body) as Map<String, Object?>;
      final files = decoded['files'] as List<Object?>? ?? const [];
      for (final raw in files.cast<Map<String, Object?>>()) {
        results.add(
          _DriveFile(
            id: raw['id'] as String,
            name: raw['name'] as String,
            size: int.tryParse(raw['size'] as String? ?? ''),
            modified: DateTime.tryParse(raw['modifiedTime'] as String? ?? ''),
          ),
        );
      }
      // An empty token means the same thing as an absent one; treating it
      // as a real token would re-issue the first page forever.
      final next = decoded['nextPageToken'] as String?;
      pageToken = (next == null || next.isEmpty) ? null : next;
    } while (pageToken != null);
    return results;
  }

  Future<http.Response> _send(http.Request request) async {
    final client = await _resolveClient();
    try {
      return await http.Response.fromStream(await client.send(request));
    } on Exception catch (e) {
      throw MediaStoreException(
        'Could not reach Google Drive',
        kind: MediaStoreErrorKind.transient,
        cause: e,
      );
    }
  }

  /// The authenticator's client as of right now. Resolved per request so a
  /// re-auth that swapped the client is picked up transparently; see the
  /// constructor.
  Future<http.Client> _resolveClient() async {
    final http.Client? client;
    try {
      client = await _clientSupplier();
    } on Exception catch (e) {
      throw MediaStoreException(
        'Could not reach Google Drive',
        kind: MediaStoreErrorKind.transient,
        cause: e,
      );
    }
    if (client == null) {
      throw const MediaStoreException(
        'No Google Drive session; sign in again',
        kind: MediaStoreErrorKind.auth,
      );
    }
    return client;
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
