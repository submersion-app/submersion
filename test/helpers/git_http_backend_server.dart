import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'git_cli.dart';

/// A loopback smart-HTTP Git server: stock `git http-backend` run as CGI for
/// every request, so the pure-Dart client is tested against real Git rather
/// than a fake of our own understanding of the protocol.
///
/// - [allowFilter]: whether upload-pack accepts `filter blob:none`.
/// - [protocolV2]: when false the `Git-Protocol` header is dropped, so the
///   server answers in protocol v0 as an older host would.
/// - [requireUser]/[requirePassword]: Basic auth required for every request,
///   except anonymous reads when [anonymousRead] is true (a public repo).
final class GitTestServer {
  GitTestServer._(
    this._server,
    this.reposRoot, {
    required this.allowFilter,
    required this.protocolV2,
    required this.requireUser,
    required this.requirePassword,
    required this.anonymousRead,
  });

  final HttpServer _server;
  final Directory reposRoot;
  final bool allowFilter;
  final bool protocolV2;
  final String? requireUser;
  final String? requirePassword;
  final bool anonymousRead;

  /// Requests served, in order, as `METHOD path?query`.
  final List<String> requests = [];

  /// Body sizes of the fetch (upload-pack POST) replies, in order.
  final List<int> fetchResponseBytes = [];

  /// Called with each request before it is served; return false to drop the
  /// connection without a reply (a lost response).
  bool Function(HttpRequest request)? beforeServe;

  /// Called after a request was served, before its response is closed.
  /// Return false to abort the response instead of completing it.
  bool Function(HttpRequest request)? afterServe;

  int _inFlight = 0;
  Completer<void>? _idle;

  /// Completes once no request is being served.
  Future<void> idle() {
    if (_inFlight == 0) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  /// The clone URL of repository [name].
  Uri repoUrl(String name) => baseUrl.replace(path: '/$name.git');

  /// Creates a bare repository `[name].git` whose HEAD names `main`. With
  /// [withMainCommit], `main` holds one commit with a `notes.txt` file.
  Future<Directory> createBareRepo(
    String name, {
    bool withMainCommit = false,
  }) async {
    final dir = Directory(p.join(reposRoot.path, '$name.git'))..createSync();
    await runGit(dir, ['init', '-q', '--bare', '-b', 'main', '.']);
    await runGit(dir, ['config', 'http.receivepack', 'true']);
    await runGit(dir, ['config', 'uploadpack.allowFilter', '$allowFilter']);
    await runGit(dir, ['config', 'uploadpack.allowAnySHA1InWant', 'true']);
    if (withMainCommit) {
      final blob = await runGit(dir, [
        'hash-object',
        '-w',
        '--stdin',
      ], stdin: 'my own notes\n');
      final tree = await runGit(dir, [
        'mktree',
      ], stdin: '100644 blob $blob\tnotes.txt\n');
      final commit = await runGit(dir, ['commit-tree', tree, '-m', 'mine']);
      await runGit(dir, ['update-ref', 'refs/heads/main', commit]);
    }
    return dir;
  }

  /// Makes every push to [repo] fail in its pre-receive hook, printing
  /// [message] to the pusher the way a host's policy check does.
  Future<void> refusePushes(Directory repo, String message) async {
    final hook = File(p.join(repo.path, 'hooks', 'pre-receive'));
    await hook.parent.create(recursive: true);
    final quoted = message.replaceAll("'", "'\\''");
    await hook.writeAsString("#!/bin/sh\necho '$quoted' >&2\nexit 1\n");
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', hook.path]);
    }
  }

  Future<void> close() async {
    await _server.close(force: true);
  }

  bool _authorized(HttpRequest request) {
    final user = requireUser;
    if (user == null) return true;
    final isRead =
        request.uri.queryParameters['service'] == 'git-upload-pack' ||
        request.uri.path.endsWith('/git-upload-pack');
    if (anonymousRead && isRead) return true;
    final header = request.headers.value(HttpHeaders.authorizationHeader);
    final expected =
        'Basic ${base64.encode(utf8.encode('$user:${requirePassword ?? ''}'))}';
    return header == expected;
  }

  Future<void> _serve(HttpRequest request) async {
    _inFlight++;
    try {
      await _serveCounted(request);
    } finally {
      if (--_inFlight == 0) {
        _idle?.complete();
        _idle = null;
      }
    }
  }

  Future<void> _serveCounted(HttpRequest request) async {
    requests.add('${request.method} ${request.uri}');
    if (beforeServe != null && !beforeServe!(request)) {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }
    if (!_authorized(request)) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.set(HttpHeaders.wwwAuthenticateHeader, 'Basic realm="git"');
      await request.response.close();
      return;
    }
    final body = BytesBuilder(copy: false);
    await for (final chunk in request) {
      body.add(chunk);
    }
    final bytes = body.takeBytes();
    final process = await Process.start(
      'git',
      ['http-backend'],
      environment: {
        ...fixedGitEnv,
        'GIT_PROJECT_ROOT': reposRoot.path,
        'GIT_HTTP_EXPORT_ALL': '1',
        'PATH_INFO': request.uri.path,
        'REQUEST_METHOD': request.method,
        'QUERY_STRING': request.uri.query,
        'CONTENT_TYPE': request.headers.contentType?.toString() ?? '',
        'CONTENT_LENGTH': '${bytes.length}',
        'REMOTE_USER': requireUser ?? 'tester',
        'REMOTE_ADDR': '127.0.0.1',
        if (protocolV2 && request.headers.value('git-protocol') != null)
          'GIT_PROTOCOL': request.headers.value('git-protocol')!,
      },
    );
    process.stdin.add(bytes);
    await process.stdin.close();
    final out = BytesBuilder(copy: false);
    final stderrText = process.stderr.transform(utf8.decoder).join();
    await for (final chunk in process.stdout) {
      out.add(chunk);
    }
    await process.exitCode;
    final err = await stderrText;
    final cgi = out.takeBytes();
    final split = _headerEnd(cgi);
    final headerText = ascii.decode(cgi.sublist(0, split.headerLength));
    final response = request.response;
    for (final line in const LineSplitter().convert(headerText)) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final name = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim();
      if (name.toLowerCase() == 'status') {
        response.statusCode = int.parse(value.split(' ').first);
      } else {
        response.headers.set(name, value);
      }
    }
    if (err.isNotEmpty) response.headers.set('x-git-stderr', err.trim());
    if (request.method == 'POST' &&
        request.uri.path.endsWith('/git-upload-pack')) {
      fetchResponseBytes.add(cgi.length - split.bodyStart);
    }
    response.add(cgi.sublist(split.bodyStart));
    if (afterServe != null && !afterServe!(request)) {
      final socket = await response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }
    await response.close();
  }

  static ({int headerLength, int bodyStart}) _headerEnd(Uint8List cgi) {
    for (var i = 0; i + 1 < cgi.length; i++) {
      if (cgi[i] == 10 && cgi[i + 1] == 10) {
        return (headerLength: i, bodyStart: i + 2);
      }
      if (i + 3 < cgi.length &&
          cgi[i] == 13 &&
          cgi[i + 1] == 10 &&
          cgi[i + 2] == 13 &&
          cgi[i + 3] == 10) {
        return (headerLength: i, bodyStart: i + 4);
      }
    }
    return (headerLength: cgi.length, bodyStart: cgi.length);
  }
}

/// Starts a [GitTestServer] for one test; it closes when the test ends.
Future<GitTestServer> startGitTestServer({
  bool allowFilter = true,
  bool protocolV2 = true,
  String? requireUser,
  String? requirePassword,
  bool anonymousRead = false,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final git = GitTestServer._(
    server,
    tempDirForTest('git_server_'),
    allowFilter: allowFilter,
    protocolV2: protocolV2,
    requireUser: requireUser,
    requirePassword: requirePassword,
    anonymousRead: anonymousRead,
  );
  server.listen((request) {
    unawaited(
      git._serve(request).catchError((Object e) {
        try {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('$e');
          return request.response.close();
        } catch (_) {
          return null;
        }
      }),
    );
  });
  addTearDown(git.close);
  return git;
}
