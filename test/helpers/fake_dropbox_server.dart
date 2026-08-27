import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory Dropbox API v2 fake for MockClient: content + RPC endpoints,
/// upload sessions, Range downloads. Dropbox errors are HTTP 409 with an
/// error_summary JSON body; the client keys off the summary text.
class FakeDropboxServer {
  /// Absolute app-folder paths ('/x/y.jpg') -> bytes.
  final Map<String, Uint8List> files = {};

  final List<http.Request> captured = [];

  final Map<String, BytesBuilder> _sessions = {};
  int _sessionCounter = 0;

  /// Successful append_v2 writes.
  int sessionAppendCount = 0;

  /// One-shot 500 on the append_v2 that would take the count to this
  /// value + 1 (DropboxApiClient does not retry 5xx, so one shot works).
  int? failAfterAppends;

  String bearerToken = 'test-token';

  MockClient get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    captured.add(request);
    if (request.headers['Authorization'] != 'Bearer $bearerToken') {
      return http.Response('{"error_summary": "invalid_access_token/.."}', 401);
    }
    final path = request.url.path;
    switch (path) {
      case '/2/files/upload':
        final arg = _arg(request);
        final target = arg['path'] as String;
        files[target] = Uint8List.fromList(request.bodyBytes);
        return http.Response(jsonEncode(_metadata(target)), 200);
      case '/2/files/download':
        final target = _arg(request)['path'] as String;
        final body = files[target];
        if (body == null) return _notFound();
        final range = request.headers['Range'] ?? request.headers['range'];
        if (range != null) {
          final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
          final start = int.parse(match.group(1)!);
          final end = int.parse(match.group(2)!).clamp(0, body.length - 1);
          return http.Response.bytes(
            body.sublist(start, end + 1),
            206,
            headers: {'content-range': 'bytes $start-$end/${body.length}'},
          );
        }
        return http.Response.bytes(body, 200);
      case '/2/files/get_metadata':
        final target = _body(request)['path'] as String;
        if (!files.containsKey(target)) return _notFound();
        return http.Response(jsonEncode(_metadata(target)), 200);
      case '/2/files/list_folder':
        final body = _body(request);
        final folder = body['path'] as String;
        final recursive = body['recursive'] == true;
        final prefix = folder.isEmpty ? '/' : '$folder/';
        final entries = files.keys.where((k) => k.startsWith(prefix)).where((
          k,
        ) {
          if (recursive) return true;
          return !k.substring(prefix.length).contains('/');
        });
        return http.Response(
          jsonEncode({
            'entries': [for (final k in entries) _metadata(k)],
            'has_more': false,
          }),
          200,
        );
      case '/2/files/delete_v2':
        files.remove(_body(request)['path'] as String);
        return http.Response('{}', 200);
      case '/2/users/get_current_account':
        return http.Response(
          jsonEncode({
            'email': 'diver@example.com',
            'name': {'display_name': 'Test Diver'},
          }),
          200,
        );
      case '/2/files/upload_session/start':
        _sessionCounter++;
        final id = 'session-$_sessionCounter';
        _sessions[id] = BytesBuilder()..add(request.bodyBytes);
        return http.Response(jsonEncode({'session_id': id}), 200);
      case '/2/files/upload_session/append_v2':
        final arg = _arg(request);
        final cursor = arg['cursor'] as Map<String, Object?>;
        final session = _sessions[cursor['session_id']];
        if (session == null) {
          return http.Response(
            '{"error_summary": "lookup_failed/not_found/.."}',
            409,
          );
        }
        if (cursor['offset'] != session.length) {
          return http.Response(
            '{"error_summary": "lookup_failed/incorrect_offset/.."}',
            409,
          );
        }
        final limit = failAfterAppends;
        if (limit != null && sessionAppendCount >= limit) {
          failAfterAppends = null;
          return http.Response('', 500);
        }
        sessionAppendCount++;
        session.add(request.bodyBytes);
        return http.Response('{}', 200);
      case '/2/files/upload_session/finish':
        final arg = _arg(request);
        final cursor = arg['cursor'] as Map<String, Object?>;
        final commit = arg['commit'] as Map<String, Object?>;
        final session = _sessions.remove(cursor['session_id']);
        if (session == null) {
          return http.Response(
            '{"error_summary": "lookup_failed/not_found/.."}',
            409,
          );
        }
        if (cursor['offset'] != session.length) {
          return http.Response(
            '{"error_summary": "lookup_failed/incorrect_offset/.."}',
            409,
          );
        }
        session.add(request.bodyBytes);
        final target = commit['path'] as String;
        files[target] = session.toBytes();
        return http.Response(jsonEncode(_metadata(target)), 200);
      default:
        return http.Response(
          '{"error_summary": "unknown_endpoint/$path"}',
          400,
        );
    }
  }

  Map<String, Object?> _arg(http.Request request) =>
      jsonDecode(request.headers['Dropbox-API-Arg']!) as Map<String, Object?>;

  Map<String, Object?> _body(http.Request request) =>
      jsonDecode(request.body) as Map<String, Object?>;

  Map<String, Object?> _metadata(String path) => {
    '.tag': 'file',
    'path_lower': path,
    'name': path.split('/').last,
    'server_modified': '2026-07-09T00:00:00Z',
    'size': files[path]?.length ?? 0,
  };

  http.Response _notFound() =>
      http.Response('{"error_summary": "path/not_found/.."}', 409);
}
