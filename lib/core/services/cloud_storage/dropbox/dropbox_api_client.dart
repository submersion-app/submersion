import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

/// Account labels from /users/get_current_account.
class DropboxAccount {
  const DropboxAccount({this.email, this.displayName});

  final String? email;
  final String? displayName;
}

/// The subset of Dropbox file metadata the sync layer needs.
class DropboxFileMetadata {
  const DropboxFileMetadata({
    required this.pathLower,
    required this.name,
    required this.serverModified,
    this.size,
  });

  /// Dropbox's canonical lower-cased path; used as the provider fileId.
  final String pathLower;
  final String name;
  final DateTime serverModified;
  final int? size;

  factory DropboxFileMetadata.fromJson(Map<String, Object?> json) =>
      DropboxFileMetadata(
        pathLower: json['path_lower'] as String,
        name: json['name'] as String,
        serverModified: DateTime.parse(json['server_modified'] as String),
        size: json['size'] as int?,
      );
}

/// Thin client for the Dropbox HTTP API v2 (RPC + content endpoints).
///
/// Auth is delegated to callbacks so this class stays a pure HTTP mapper:
/// [getAccessToken] supplies a bearer token (refreshing as needed) and
/// [onAccessTokenRejected] is invoked when Dropbox answers 401 so the
/// owner can invalidate its cache; the request is then retried once.
///
/// Error policy (spec section "Data layout, error handling, edge cases"):
/// - 401 twice   -> auth CloudStorageException ("Reconnect Dropbox").
/// - 429         -> wait Retry-After (default 1 s) and retry once.
/// - not_found   -> null/success where the caller expects absence
///                  (getMetadata, delete); download throws.
/// - insufficient_space -> distinct user-facing message.
/// - anything else non-2xx, and transport errors -> wrapped generic.
class DropboxApiClient {
  DropboxApiClient({
    required Future<String> Function() getAccessToken,
    required void Function() onAccessTokenRejected,
    http.Client? httpClient,
    this.chunkedUploadThresholdBytes = 150 * 1024 * 1024,
    this.uploadChunkBytes = 8 * 1024 * 1024,
    Future<void> Function(Duration)? wait,
  }) : _getAccessToken = getAccessToken,
       _onAccessTokenRejected = onAccessTokenRejected,
       _http = httpClient ?? http.Client(),
       _wait = wait ?? ((d) => Future<void>.delayed(d));

  static final Uri _apiBase = Uri.parse('https://api.dropboxapi.com');
  static final Uri _contentBase = Uri.parse('https://content.dropboxapi.com');

  /// Dropbox's /files/upload hard limit is 150 MB; larger payloads must go
  /// through upload sessions. Injectable so tests exercise the session
  /// path with tiny payloads.
  final int chunkedUploadThresholdBytes;

  /// Session chunk size; Dropbox recommends a multiple of 4 MB.
  final int uploadChunkBytes;

  final Future<String> Function() _getAccessToken;
  final void Function() _onAccessTokenRejected;
  final http.Client _http;
  final Future<void> Function(Duration) _wait;

  Future<DropboxFileMetadata> upload(String path, Uint8List data) async {
    if (data.length > chunkedUploadThresholdBytes) {
      return _uploadChunked(path, data);
    }
    final response = await _send(
      () => _contentRequest(
        '/2/files/upload',
        arg: {'path': path, 'mode': 'overwrite', 'mute': true},
        body: data,
      ),
    );
    // _send only returns null under notFoundIsNull, which is not set here.
    return DropboxFileMetadata.fromJson(_decodeMap(response!));
  }

  Future<Uint8List> download(String path) async {
    final response = await _send(
      () => _contentRequest('/2/files/download', arg: {'path': path}),
      notFoundMessage: 'File not found in Dropbox: $path',
    );
    return response!.bodyBytes;
  }

  /// Metadata for [path], or null when it does not exist.
  Future<DropboxFileMetadata?> getMetadata(String path) async {
    final response = await _send(
      () => _rpcRequest('/2/files/get_metadata', {'path': path}),
      notFoundIsNull: true,
    );
    if (response == null) return null;
    return DropboxFileMetadata.fromJson(_decodeMap(response));
  }

  /// All files directly in [path] ('' is the app-folder root), following
  /// pagination cursors to exhaustion. Folders are omitted.
  Future<List<DropboxFileMetadata>> listFolder({String path = ''}) async {
    final entries = <DropboxFileMetadata>[];
    var response = await _send(
      () => _rpcRequest('/2/files/list_folder', {
        'path': path,
        'recursive': false,
      }),
    );
    while (true) {
      final decoded = _decodeMap(response!);
      for (final entry in decoded['entries'] as List<Object?>) {
        final map = entry as Map<String, Object?>;
        if (map['.tag'] == 'file') {
          entries.add(DropboxFileMetadata.fromJson(map));
        }
      }
      if (decoded['has_more'] != true) return entries;
      final cursor = decoded['cursor'] as String;
      response = await _send(
        () => _rpcRequest('/2/files/list_folder/continue', {'cursor': cursor}),
      );
    }
  }

  /// Deletes [path]. A missing file is success: delete is idempotent for
  /// the sync layer (matching S3 semantics).
  Future<void> delete(String path) async {
    await _send(
      () => _rpcRequest('/2/files/delete_v2', {'path': path}),
      notFoundIsNull: true,
    );
  }

  Future<DropboxAccount> getCurrentAccount() async {
    final response = await _send(
      () => _rpcRequest('/2/users/get_current_account', null),
    );
    final decoded = _decodeMap(response!);
    final name = decoded['name'];
    return DropboxAccount(
      email: decoded['email'] as String?,
      displayName: name is Map<String, Object?>
          ? name['display_name'] as String?
          : null,
    );
  }

  void close() => _http.close();

  Future<DropboxFileMetadata> _uploadChunked(
    String path,
    Uint8List data,
  ) async {
    final first = Uint8List.sublistView(data, 0, uploadChunkBytes);
    final startResponse = await _send(
      () => _contentRequest(
        '/2/files/upload_session/start',
        arg: {'close': false},
        body: first,
      ),
    );
    final sessionId = _decodeMap(startResponse!)['session_id'] as String;

    var offset = first.length;
    // Append full chunks, leaving at least one byte for finish (Dropbox
    // accepts an empty finish body, but a non-empty one avoids a
    // zero-length edge case).
    while (data.length - offset > uploadChunkBytes) {
      final chunk = Uint8List.sublistView(
        data,
        offset,
        offset + uploadChunkBytes,
      );
      final sendOffset = offset;
      await _send(
        () => _contentRequest(
          '/2/files/upload_session/append_v2',
          arg: {
            'cursor': {'session_id': sessionId, 'offset': sendOffset},
            'close': false,
          },
          body: chunk,
        ),
      );
      offset += chunk.length;
    }

    final rest = Uint8List.sublistView(data, offset);
    final finishOffset = offset;
    final finishResponse = await _send(
      () => _contentRequest(
        '/2/files/upload_session/finish',
        arg: {
          'cursor': {'session_id': sessionId, 'offset': finishOffset},
          'commit': {'path': path, 'mode': 'overwrite', 'mute': true},
        },
        body: rest,
      ),
    );
    return DropboxFileMetadata.fromJson(_decodeMap(finishResponse!));
  }

  http.Request _rpcRequest(String path, Map<String, Object?>? body) {
    final request = http.Request('POST', _apiBase.replace(path: path))
      ..headers['Content-Type'] = 'application/json'
      ..body = body == null ? 'null' : jsonEncode(body);
    return request;
  }

  http.Request _contentRequest(
    String path, {
    required Map<String, Object?> arg,
    Uint8List? body,
  }) {
    final request = http.Request('POST', _contentBase.replace(path: path))
      ..headers['Dropbox-API-Arg'] = jsonEncode(arg)
      ..headers['Content-Type'] = 'application/octet-stream'
      ..bodyBytes = body ?? Uint8List(0);
    return request;
  }

  /// Sends [build]'s request with a bearer token, applying the 401 and 429
  /// retry policy. Returns null (instead of throwing) for Dropbox
  /// not_found errors when [notFoundIsNull] is set.
  Future<http.Response?> _send(
    http.Request Function() build, {
    bool notFoundIsNull = false,
    String? notFoundMessage,
  }) async {
    var authRetried = false;
    var rateRetried = false;
    while (true) {
      final token = await _getAccessToken();
      final request = build()..headers['Authorization'] = 'Bearer $token';
      final http.Response response;
      try {
        response = await http.Response.fromStream(await _http.send(request));
      } on Exception catch (e, st) {
        throw CloudStorageException('Could not reach Dropbox', e, st);
      }

      if (response.statusCode == 401) {
        _onAccessTokenRejected();
        if (!authRetried) {
          authRetried = true;
          continue;
        }
        throw CloudStorageException(
          'Dropbox authorization expired. Reconnect Dropbox in the Cloud '
          'Sync settings.',
          _bodySummary(response),
        );
      }

      if (response.statusCode == 429) {
        if (!rateRetried) {
          rateRetried = true;
          final seconds =
              int.tryParse(response.headers['retry-after'] ?? '') ?? 1;
          await _wait(Duration(seconds: seconds));
          continue;
        }
        throw CloudStorageException(
          'Dropbox rate limit exceeded. Try again shortly.',
          _bodySummary(response),
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }

      final summary = _errorSummary(response);
      if (summary.contains('not_found')) {
        if (notFoundIsNull) return null;
        throw CloudStorageException(
          notFoundMessage ?? 'Dropbox file not found',
          summary,
        );
      }
      if (summary.contains('insufficient_space')) {
        throw CloudStorageException(
          'Dropbox is out of storage space. Free up space in your Dropbox '
          'account.',
          summary,
        );
      }
      throw CloudStorageException(
        'Dropbox request failed (${response.statusCode})',
        summary,
      );
    }
  }

  Map<String, Object?> _decodeMap(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const CloudStorageException('Unexpected response from Dropbox');
    }
    return decoded;
  }

  /// Dropbox errors are JSON with an error_summary; fall back to the raw
  /// (truncated) body for non-JSON responses.
  static String _errorSummary(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?> &&
          decoded['error_summary'] is String) {
        return decoded['error_summary'] as String;
      }
    } on FormatException {
      // fall through
    }
    return _bodySummary(response);
  }

  static String _bodySummary(http.Response response) {
    final body = response.body;
    return body.length <= 200 ? body : body.substring(0, 200);
  }
}
