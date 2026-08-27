import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory Google Drive v3 fake for MockClient: file/folder queries,
/// resumable upload sessions with the `bytes */total` probe, Range
/// downloads. All files live in a single parent folder (the media
/// folder), matching the adapter's layout.
class FakeDriveServer {
  final Map<String, ({String name, Uint8List bytes})> filesById = {};
  final Map<String, String> foldersByName = {};
  final List<http.Request> captured = [];

  final Map<String, _Session> _sessions = {};
  int _counter = 0;

  /// Session PUTs that carried body bytes and were accepted.
  int chunkPutCount = 0;

  /// One-shot 500 on the chunk PUT that would take the count past this
  /// value (the adapter has no retry layer, so one shot works).
  int? failAfterChunkPuts;

  MockClient get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    captured.add(request);
    final path = request.url.path;
    if (path == '/drive/v3/files' && request.method == 'GET') {
      return _handleQuery(request);
    }
    if (path == '/drive/v3/files' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      _counter++;
      final id = 'folder-$_counter';
      foldersByName[body['name'] as String] = id;
      return http.Response(jsonEncode({'id': id}), 200);
    }
    if (path == '/upload/drive/v3/files' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, Object?>;
      _counter++;
      final sessionId = 'session-$_counter';
      _sessions[sessionId] = _Session(name: body['name'] as String);
      return http.Response(
        '',
        200,
        headers: {'location': '${request.url.origin}/fake-session/$sessionId'},
      );
    }
    if (path.startsWith('/fake-session/') && request.method == 'PUT') {
      return _handleSessionPut(request, path.split('/').last);
    }
    if (path.startsWith('/drive/v3/files/') && request.method == 'GET') {
      final id = path.split('/').last;
      final file = filesById[id];
      if (file == null) return http.Response('', 404);
      final range = request.headers['Range'] ?? request.headers['range'];
      if (range != null) {
        final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
        final start = int.parse(match.group(1)!);
        final end = int.parse(match.group(2)!).clamp(0, file.bytes.length - 1);
        return http.Response.bytes(
          file.bytes.sublist(start, end + 1),
          206,
          headers: {'content-range': 'bytes $start-$end/${file.bytes.length}'},
        );
      }
      return http.Response.bytes(file.bytes, 200);
    }
    if (path.startsWith('/drive/v3/files/') && request.method == 'DELETE') {
      filesById.remove(path.split('/').last);
      return http.Response('', 204);
    }
    return http.Response('{"error": {"message": "unknown $path"}}', 400);
  }

  http.Response _handleQuery(http.Request request) {
    final q = request.url.queryParameters['q'] ?? '';
    final nameMatch = RegExp(r"name = '([^']+)'").firstMatch(q);
    // File-lookup queries also contain the word 'folder' (in the parents
    // clause), so discriminate on the mimeType marker instead.
    final wantsFolder = q.contains('vnd.google-apps.folder');

    if (wantsFolder && nameMatch != null) {
      final id = foldersByName[nameMatch.group(1)];
      return http.Response(
        jsonEncode({
          'files': [
            if (id != null) {'id': id, 'name': nameMatch.group(1)},
          ],
        }),
        200,
      );
    }

    final entries = filesById.entries.where(
      (e) => nameMatch == null || e.value.name == nameMatch.group(1),
    );
    return http.Response(
      jsonEncode({
        'files': [
          for (final e in entries)
            {
              'id': e.key,
              'name': e.value.name,
              'modifiedTime': '2026-07-09T00:00:00.000Z',
              'size': '${e.value.bytes.length}',
            },
        ],
      }),
      200,
    );
  }

  http.Response _handleSessionPut(http.Request request, String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return http.Response('', 404);
    final contentRange =
        request.headers['Content-Range'] ?? request.headers['content-range']!;

    final probe = RegExp(r'bytes \*/(\d+)').firstMatch(contentRange);
    if (probe != null) {
      final stored = session.builder.length;
      if (stored == 0) return http.Response('', 308);
      return http.Response(
        '',
        308,
        headers: {'range': 'bytes=0-${stored - 1}'},
      );
    }

    final match = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange)!;
    final start = int.parse(match.group(1)!);
    final end = int.parse(match.group(2)!);
    final total = int.parse(match.group(3)!);
    if (start != session.builder.length) return http.Response('', 500);

    final limit = failAfterChunkPuts;
    if (limit != null && chunkPutCount >= limit) {
      failAfterChunkPuts = null;
      return http.Response('', 500);
    }
    chunkPutCount++;
    session.builder.add(request.bodyBytes);

    if (end + 1 == total) {
      _sessions.remove(sessionId);
      _counter++;
      final id = 'file-$_counter';
      filesById[id] = (name: session.name, bytes: session.builder.toBytes());
      return http.Response(jsonEncode({'id': id, 'name': session.name}), 200);
    }
    return http.Response(
      '',
      308,
      headers: {'range': 'bytes=0-${session.builder.length - 1}'},
    );
  }
}

class _Session {
  _Session({required this.name});
  final String name;
  final BytesBuilder builder = BytesBuilder();
}
