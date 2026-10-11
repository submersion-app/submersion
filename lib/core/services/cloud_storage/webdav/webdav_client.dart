import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_multistatus.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart'
    show TransferProgressCallback;

/// A file or collection under the DAV root.
class WebDavEntry {
  const WebDavEntry({
    required this.path,
    required this.isCollection,
    required this.lastModified,
    this.sizeBytes,
  });

  /// Relative to the DAV root: `''` for the root, otherwise `a/b.json`.
  final String path;
  final bool isCollection;
  final int? sizeBytes;
  final DateTime lastModified;

  String get name => path.isEmpty ? '' : path.split('/').last;
}

/// Minimal WebDAV client: the verbs the sync provider and media store need,
/// with retry, redirect reporting, certificate pinning and streaming.
///
/// Paths are relative to [WebDavConfig.davRoot] and use `/` as the
/// separator; they are percent-encoded segment by segment. Every request
/// carries Basic auth in a header, never in the URL, and never follows a
/// redirect: `package:http` follows them only for GET and HEAD, so a
/// redirecting server would otherwise fail differently per verb.
class WebDavClient {
  WebDavClient(
    this.config, {
    http.Client? httpClient,
    CertificateTrustRecorder? trustRecorder,
    int maxAttempts = 6,
    Duration Function(int attempt)? backoff,
  }) : _trust = trustRecorder ?? CertificateTrustRecorder.forConfig(config),
       _maxAttempts = maxAttempts,
       _backoff = backoff ?? _defaultBackoff {
    _http = httpClient ?? createWebDavHttpClient(_trust);
  }

  final WebDavConfig config;
  final CertificateTrustRecorder _trust;
  final int _maxAttempts;
  final Duration Function(int attempt) _backoff;
  late final http.Client _http;
  final Set<String> _knownCollections = {};

  /// Set once the server refuses Nextcloud chunking; later large uploads go
  /// straight to a single PUT.
  bool chunkingUnsupported = false;

  static final Random _random = Random();

  static Duration _defaultBackoff(int attempt) {
    final base = min(250 * (1 << attempt), 8000);
    return Duration(milliseconds: base + _random.nextInt(base ~/ 2 + 1));
  }

  String get _authorization =>
      'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';

  static List<String> _segments(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  /// `a/b/c` gives `a/b`; a top-level path gives `''`.
  static String parentOf(String path) {
    final segments = _segments(path);
    return segments.isEmpty
        ? ''
        : segments.sublist(0, segments.length - 1).join('/');
  }

  /// Decoded segments of the DAV root. `Uri.pathSegments` is decoded, and
  /// `Uri.replace(pathSegments:)` encodes, so building from the raw `path`
  /// would double-encode a root like `files/alice%40example.com/`.
  List<String> get _rootSegments =>
      config.davRoot.pathSegments.where((s) => s.isNotEmpty).toList();

  Uri uriFor(String path, {bool collection = false}) {
    final segments = [..._rootSegments, ..._segments(path)];
    return config.davRoot.replace(
      pathSegments: [...segments, if (collection) ''],
    );
  }

  /// Sends one request with retry. Statuses in [accept] are returned to the
  /// caller instead of raising; every other non-2xx raises a
  /// [WebDavException]. The caller must consume or drain the body.
  Future<http.StreamedResponse> request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Uint8List? bytes,
    Set<int> accept = const {},
    bool isRoot = false,
  }) => _send(
    method,
    uri,
    headers: headers,
    bytes: bytes,
    accept: accept,
    isRoot: isRoot,
  );

  Future<http.StreamedResponse> _send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Uint8List? bytes,
    Stream<List<int>> Function()? stream,
    int? streamLength,
    Set<int> accept = const {},
    bool isRoot = false,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final http.BaseRequest request;
      if (stream != null) {
        final streamed = http.StreamedRequest(method, uri)
          ..contentLength = streamLength;
        stream().listen(
          streamed.sink.add,
          onError: streamed.sink.addError,
          onDone: streamed.sink.close,
          cancelOnError: true,
        );
        request = streamed;
      } else {
        final plain = http.Request(method, uri);
        if (bytes != null) plain.bodyBytes = bytes;
        request = plain;
      }
      request
        ..followRedirects = false
        ..headers.addAll(headers)
        ..headers['authorization'] = _authorization;

      final http.StreamedResponse response;
      try {
        response = await _http.send(request);
      } on Object catch (e) {
        if (e is! IOException &&
            e is! http.ClientException &&
            e is! TimeoutException) {
          rethrow;
        }
        final rejected = _trust.takeRejected();
        if (rejected != null) {
          throw WebDavUntrustedCertificateException(
            rejected,
            pinnedSha256: config.pinnedCertSha256,
            cause: e,
          );
        }
        if (attempt + 1 >= _maxAttempts) {
          throw WebDavException(
            'Could not reach ${config.host}.',
            code: WebDavErrorCode.unreachable,
            cause: e,
          );
        }
        await Future<void>.delayed(_backoff(attempt));
        continue;
      }

      final status = response.statusCode;
      if ((status >= 200 && status < 300) || accept.contains(status)) {
        return response;
      }
      if (_isRetryable(status) && attempt + 1 < _maxAttempts) {
        await response.stream.drain<void>();
        await Future<void>.delayed(_backoff(attempt));
        continue;
      }
      final excerpt = await _excerpt(response);
      throw WebDavException.fromStatus(
        status,
        method: method,
        uri: uri,
        location: response.headers['location'],
        bodyExcerpt: excerpt,
        sizeBytes: bytes?.length ?? streamLength,
        isRoot: isRoot,
      );
    }
  }

  static bool _isRetryable(int status) =>
      status == 429 || status == 423 || (status >= 500 && status != 507);

  static Future<String> _excerpt(http.StreamedResponse response) async {
    try {
      final body = await response.stream.bytesToString();
      return body.length <= 1000 ? body : body.substring(0, 1000);
    } catch (_) {
      return '';
    }
  }

  Future<List<DavResource>> propfindRaw(
    Uri uri,
    int depth, {
    bool isRoot = false,
  }) async {
    final response = await _send(
      'PROPFIND',
      uri,
      headers: {
        'depth': '$depth',
        'content-type': 'application/xml; charset=utf-8',
      },
      bytes: utf8.encode(kPropfindBody),
      isRoot: isRoot,
    );
    final body = await response.stream.bytesToString();
    if (response.statusCode != 207) throw _notWebDav(uri);
    try {
      return parseMultistatus(body);
    } on FormatException catch (e) {
      throw _notWebDav(uri, e);
    }
  }

  WebDavException _notWebDav(Uri uri, [Object? cause]) => WebDavException(
    'This address is not a WebDAV endpoint.',
    code: WebDavErrorCode.notWebDav,
    cause: cause ?? 'PROPFIND ${uri.path} did not answer 207 Multi-Status',
  );

  WebDavEntry? _toEntry(DavResource resource) {
    final root = _rootSegments;
    final segs = resource.pathSegments;
    if (segs.length < root.length) return null;
    for (var i = 0; i < root.length; i++) {
      if (segs[i] != root[i]) return null;
    }
    return WebDavEntry(
      path: segs.sublist(root.length).join('/'),
      isCollection: resource.isCollection,
      sizeBytes: resource.contentLength,
      lastModified:
          resource.lastModified ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// The entry at [path], or null when absent. The root itself (`''`)
  /// raises instead: a missing root means the address is wrong.
  Future<WebDavEntry?> stat(String path) async {
    final normalized = _segments(path).join('/');
    final isRoot = normalized.isEmpty;
    try {
      final resources = await propfindRaw(
        uriFor(normalized, collection: isRoot),
        0,
        isRoot: isRoot,
      );
      return resources.map(_toEntry).nonNulls.firstOrNull;
    } on WebDavException catch (e) {
      if (!isRoot && e.code == WebDavErrorCode.notFound) return null;
      rethrow;
    }
  }

  /// Direct children of the collection at [path]. Raises notFound when the
  /// collection is absent.
  Future<List<WebDavEntry>> listChildren(String path) async {
    final normalized = _segments(path).join('/');
    final resources = await propfindRaw(
      uriFor(normalized, collection: true),
      1,
      isRoot: normalized.isEmpty,
    );
    return resources
        .map(_toEntry)
        .nonNulls
        .where((e) => e.path != normalized)
        .toList();
  }

  Future<Uint8List> getBytes(String path) async {
    final response = await _send('GET', uriFor(path));
    return response.stream.toBytes();
  }

  /// Streams [path] into [destination]; a partial file is deleted on
  /// failure so callers never see a truncated download.
  Future<void> getToFile(
    String path,
    File destination, {
    TransferProgressCallback? onProgress,
  }) async {
    IOSink? sink;
    try {
      final response = await _send('GET', uriFor(path));
      final total = response.contentLength;
      sink = destination.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
      await sink.close();
      sink = null;
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {
        // The original error is the one that matters.
      }
      try {
        if (await destination.exists()) await destination.delete();
      } catch (_) {
        // Best-effort cleanup of a partial download.
      }
      rethrow;
    }
  }

  Future<void> putBytes(
    String path,
    Uint8List data, {
    String contentType = 'application/octet-stream',
  }) => _putWithParentRetry(path, () async {
    final response = await _send(
      'PUT',
      uriFor(path),
      headers: {'content-type': contentType},
      bytes: data,
    );
    await response.stream.drain<void>();
  });

  /// Streams [source] up in one PUT with an explicit Content-Length, so the
  /// whole file is never in memory.
  Future<void> putFile(
    String path,
    File source, {
    String contentType = 'application/octet-stream',
    TransferProgressCallback? onProgress,
  }) async {
    final length = await source.length();
    Stream<List<int>> body() {
      var sent = 0;
      return source.openRead().map((chunk) {
        sent += chunk.length;
        onProgress?.call(sent, length);
        return chunk;
      });
    }

    await _putWithParentRetry(path, () async {
      final response = await _send(
        'PUT',
        uriFor(path),
        headers: {'content-type': contentType},
        stream: body,
        streamLength: length,
      );
      await response.stream.drain<void>();
    });
  }

  /// A PUT into a missing collection answers 409; create the parents and
  /// try once more.
  Future<void> _putWithParentRetry(
    String path,
    Future<void> Function() put,
  ) async {
    try {
      await put();
    } on WebDavException catch (e) {
      if (e.code != WebDavErrorCode.conflict) rethrow;
      final parent = parentOf(path);
      _knownCollections.removeWhere(
        (c) =>
            c == parent || parent.startsWith('$c/') || c.startsWith('$parent/'),
      );
      await ensureCollection(parent);
      await put();
    }
  }

  /// Idempotent: an absent path counts as deleted.
  Future<void> delete(String path) async {
    final response = await _send('DELETE', uriFor(path), accept: const {404});
    await response.stream.drain<void>();
    _knownCollections.removeWhere((c) => c == path || c.startsWith('$path/'));
  }

  /// Creates every missing level of [path]. Results are cached for the
  /// client's life; 405 (already exists) counts as success.
  Future<void> ensureCollection(String path) async {
    final normalized = _segments(path).join('/');
    if (normalized.isEmpty || _knownCollections.contains(normalized)) return;
    final response = await _send(
      'MKCOL',
      uriFor(normalized, collection: true),
      accept: const {405, 409},
    );
    await response.stream.drain<void>();
    if (response.statusCode == 409) {
      await ensureCollection(parentOf(normalized));
      final retry = await _send(
        'MKCOL',
        uriFor(normalized, collection: true),
        accept: const {405},
      );
      await retry.stream.drain<void>();
    }
    _knownCollections.add(normalized);
  }

  /// The Nextcloud user id from `current-user-principal`, or null when the
  /// preset does not use the Nextcloud layout or the server does not say.
  Future<String?> resolveNextcloudUserId() async {
    final uri = config.principalProbeUri;
    if (uri == null) return null;
    final response = await _send(
      'PROPFIND',
      uri,
      headers: {'depth': '0', 'content-type': 'application/xml; charset=utf-8'},
      bytes: utf8.encode(kPrincipalPropfindBody),
      accept: const {404},
    );
    final body = await response.stream.bytesToString();
    if (response.statusCode != 207) return null;
    return parseCurrentUserPrincipalId(body);
  }

  void close() => _http.close();
}
