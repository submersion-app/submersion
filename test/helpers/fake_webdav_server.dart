import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory WebDAV server for MockClient: PROPFIND (Depth 0 and 1),
/// GET, PUT, DELETE, MKCOL and MOVE over a tree of decoded absolute paths,
/// Basic auth, and chunked uploads (v2) under `remote.php/dav/uploads/`
/// (`MOVE <uploadDir>/.file` assembles the numbered chunks).
class FakeWebDavServer {
  FakeWebDavServer({
    this.origin = 'https://dav.test',
    this.username = 'alice',
    this.password = 'secret',
    Iterable<String> seedCollections = const ['/dav'],
  }) {
    seedCollection('/');
    seedCollections.forEach(seedCollection);
  }

  final String origin;
  final String username;
  final String password;

  /// Decoded absolute path (`/dav/Submersion/a b.json`) to bytes.
  final Map<String, Uint8List> files = {};
  final Set<String> collections = {};
  final Map<String, DateTime> modified = {};
  final List<http.Request> captured = [];

  DateTime Function() now = () => DateTime.utc(2026, 10, 9, 10);

  /// Write hrefs as full URLs instead of absolute paths.
  bool absoluteHrefs = false;

  /// Answer the next requests with these statuses, one per request.
  final List<int> forcedStatuses = [];
  Map<String, String> forcedHeaders = const {};

  /// Throw [throwNext] for the next [throwCount] requests.
  Object? throwNext;
  int throwCount = 0;

  /// PUT bodies above this many bytes answer 413.
  int? maxPutBytes;

  /// False makes MKCOL under `/remote.php/dav/uploads` answer 501.
  bool chunkingEnabled = true;

  /// The status MKCOL under `/remote.php/dav/uploads` answers while
  /// [chunkingEnabled] is false.
  int chunkingRefusedStatus = 501;

  /// The next chunk-assembly MOVE applies, then fails in transit.
  bool moveFailsAfterApplying = false;

  /// Chunk-assembly MOVEs answer 423 Locked this many times; the first of
  /// them still assembles the file (the server finishing in the background).
  int moveLockedResponses = 0;

  /// Rewrites each href's decoded path before it is encoded, to mimic a
  /// server that reports paths in its own canonical form (case-insensitive
  /// servers echo the stored case, not the requested one).
  String Function(String path)? hrefPath;

  /// After this many requests every request answers 500, so a runaway
  /// client loop fails a test instead of hanging it.
  int? maxRequests;

  /// Every request with this method answers this status (persistently).
  final Map<String, int> methodStatuses = {};

  MockClient get client => MockClient(_handle);

  int count(String method) => captured.where((r) => r.method == method).length;

  void seedCollection(String path) {
    var p = _norm(path);
    while (true) {
      collections.add(p);
      modified[p] = now();
      if (p == '/') return;
      p = _parent(p);
    }
  }

  void seedFile(String path, List<int> bytes) {
    final p = _norm(path);
    seedCollection(_parent(p));
    files[p] = Uint8List.fromList(bytes);
    modified[p] = now();
  }

  static String _norm(String path) =>
      '/${path.split('/').where((s) => s.isNotEmpty).join('/')}';

  static String _pathOf(Uri uri) =>
      '/${uri.pathSegments.where((s) => s.isNotEmpty).join('/')}';

  static String _parent(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? '/' : path.substring(0, i);
  }

  Future<http.Response> _handle(http.Request request) async {
    captured.add(request);
    final budget = maxRequests;
    if (budget != null && captured.length > budget) {
      return http.Response('request budget exhausted', 500);
    }
    if (throwCount > 0) {
      throwCount--;
      throw throwNext!;
    }
    final methodStatus = methodStatuses[request.method];
    if (methodStatus != null) return http.Response('', methodStatus);
    if (forcedStatuses.isNotEmpty) {
      return http.Response(
        'forced',
        forcedStatuses.removeAt(0),
        headers: forcedHeaders,
      );
    }
    final expected =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    if (request.headers['authorization'] != expected) {
      return http.Response('', 401);
    }
    final path = _pathOf(request.url);
    return switch (request.method) {
      'PROPFIND' => _propfind(request, path),
      'GET' =>
        files.containsKey(path)
            ? http.Response.bytes(files[path]!, 200)
            : http.Response('', 404),
      'PUT' => _put(path, request.bodyBytes),
      'DELETE' => _delete(path),
      'MKCOL' => _mkcol(path),
      'MOVE' => _move(request, path),
      _ => http.Response('', 405),
    };
  }

  http.Response _propfind(http.Request request, String path) {
    if (!collections.contains(path) && !files.containsKey(path)) {
      return http.Response('', 404);
    }
    final depth = request.headers['depth'];
    final entries = [
      path,
      if (depth == '1' && collections.contains(path)) ..._childrenOf(path),
    ];
    return http.Response(
      _multistatus(entries),
      207,
      headers: {'content-type': 'application/xml; charset=utf-8'},
    );
  }

  Iterable<String> _childrenOf(String path) => [
    ...collections.where((c) => c != path && c != '/' && _parent(c) == path),
    ...files.keys.where((f) => _parent(f) == path),
  ];

  String _multistatus(List<String> paths) {
    final buffer = StringBuffer('<d:multistatus xmlns:d="DAV:">');
    for (final p in paths) {
      final isCol = collections.contains(p);
      final segs = p.split('/').where((s) => s.isNotEmpty).toList();
      final shown = hrefPath == null
          ? segs
          : hrefPath!(p).split('/').where((x) => x.isNotEmpty).toList();
      var href = '/${Uri(pathSegments: shown).path}';
      if (isCol && href != '/') href = '$href/';
      if (absoluteHrefs) href = '$origin$href';
      buffer
        ..write('<d:response><d:href>$href</d:href><d:propstat><d:prop>')
        ..write(
          isCol
              ? '<d:resourcetype><d:collection/></d:resourcetype>'
              : '<d:resourcetype/>',
        )
        ..write(
          isCol
              ? ''
              : '<d:getcontentlength>${files[p]!.length}</d:getcontentlength>',
        )
        ..write(
          '<d:getlastmodified>${HttpDate.format(modified[p] ?? now())}</d:getlastmodified>',
        )
        ..write(
          '</d:prop><d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>',
        );
    }
    buffer.write('</d:multistatus>');
    return buffer.toString();
  }

  http.Response _put(String path, Uint8List bytes) {
    if (collections.contains(path)) return http.Response('', 405);
    if (!collections.contains(_parent(path))) return http.Response('', 409);
    final limit = maxPutBytes;
    if (limit != null && bytes.length > limit) return http.Response('', 413);
    final existed = files.containsKey(path);
    files[path] = bytes;
    modified[path] = now();
    return http.Response('', existed ? 204 : 201);
  }

  http.Response _delete(String path) {
    if (files.remove(path) != null) return http.Response('', 204);
    if (!collections.contains(path)) return http.Response('', 404);
    _removeTree(path);
    return http.Response('', 204);
  }

  void _removeTree(String path) {
    collections.removeWhere((c) => c == path || c.startsWith('$path/'));
    files.removeWhere((f, _) => f.startsWith('$path/'));
  }

  http.Response _mkcol(String path) {
    if (!chunkingEnabled && path.startsWith('/remote.php/dav/uploads/')) {
      return http.Response('', chunkingRefusedStatus);
    }
    if (collections.contains(path) || files.containsKey(path)) {
      return http.Response('', 405);
    }
    if (!collections.contains(_parent(path))) return http.Response('', 409);
    collections.add(path);
    modified[path] = now();
    return http.Response('', 201);
  }

  http.Response _move(http.Request request, String path) {
    final destination = request.headers['destination'];
    if (destination == null) return http.Response('', 400);
    final destPath = _pathOf(Uri.parse(destination));
    if (!collections.contains(_parent(destPath))) return http.Response('', 409);
    if (path.endsWith('/.file')) {
      final dir = _parent(path);
      if (moveLockedResponses > 0 && !collections.contains(dir)) {
        moveLockedResponses--;
        return http.Response('', 423);
      }
      if (!collections.contains(dir)) return http.Response('', 404);
      final chunkNames = files.keys.where((f) => _parent(f) == dir).toList()
        ..sort();
      final builder = BytesBuilder(copy: false);
      for (final name in chunkNames) {
        builder.add(files[name]!);
      }
      files[destPath] = builder.takeBytes();
      modified[destPath] = now();
      _removeTree(dir);
      if (moveLockedResponses > 0) {
        moveLockedResponses--;
        return http.Response('', 423);
      }
      if (moveFailsAfterApplying) {
        moveFailsAfterApplying = false;
        throw http.ClientException('connection reset after MOVE');
      }
      return http.Response('', 201);
    }
    final bytes = files.remove(path);
    if (bytes == null) return http.Response('', 404);
    files[destPath] = bytes;
    modified[destPath] = now();
    return http.Response('', 201);
  }
}
