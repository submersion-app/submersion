import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory S3 protocol fake for MockClient: single-shot object CRUD,
/// list-type=2 listing, multipart sessions (create/part/complete/abort/
/// listParts), and Range GETs. Exercises the real SigV4 signing path.
class FakeS3Server {
  FakeS3Server({this.bucket = 'test-bucket'});

  final String bucket;

  /// Wire key (including any configured prefix) -> completed object bytes.
  final Map<String, Uint8List> objects = {};

  final List<http.Request> captured = [];

  final Map<String, _MultipartSession> _sessions = {};
  int _uploadCounter = 0;

  /// Clock for multipart session Initiated stamps; settable so tests can
  /// create sessions "in the past" for stale-session reaping.
  DateTime Function() now = DateTime.now;

  /// Multipart sessions created but neither completed nor aborted.
  int get activeMultipartUploadCount => _sessions.length;

  /// Successful part uploads seen (across all sessions).
  int partUploadCount = 0;

  /// When set, part-upload PUTs are rejected with 500 once
  /// [partUploadCount] reaches this value, until the field is cleared.
  /// (Persistent, because S3ApiClient retries a 5xx once - a one-shot
  /// failure would be silently absorbed by the retry.)
  int? failAfterPartUploads;

  /// One-shot failure for any request (parity with the in-memory store).
  Exception? failNextWith;

  MockClient get client => MockClient(_handle);

  Future<http.Response> _handle(http.Request request) async {
    captured.add(request);
    final injected = failNextWith;
    if (injected != null) {
      failNextWith = null;
      throw injected;
    }
    final key = Uri.decodeComponent(
      request.url.path.replaceFirst('/$bucket/', ''),
    );
    final qp = request.url.queryParameters;
    switch (request.method) {
      case 'POST':
        if (qp.containsKey('uploads')) {
          _uploadCounter++;
          final id = 'upload-$_uploadCounter';
          _sessions[id] = _MultipartSession(key: key, initiated: now());
          return http.Response(
            '<?xml version="1.0"?><InitiateMultipartUploadResult>'
            '<UploadId>$id</UploadId></InitiateMultipartUploadResult>',
            200,
          );
        }
        if (qp.containsKey('uploadId')) {
          final session = _sessions.remove(qp['uploadId']);
          if (session == null) return http.Response('', 404);
          final ordered = session.parts.keys.toList()..sort();
          final builder = BytesBuilder();
          for (final n in ordered) {
            builder.add(session.parts[n]!);
          }
          objects[key] = builder.toBytes();
          return http.Response(
            '<?xml version="1.0"?><CompleteMultipartUploadResult>'
            '<Key>$key</Key></CompleteMultipartUploadResult>',
            200,
          );
        }
        return http.Response('', 400);
      case 'PUT':
        if (qp.containsKey('partNumber')) {
          final session = _sessions[qp['uploadId']];
          if (session == null) return http.Response('', 404);
          final limit = failAfterPartUploads;
          if (limit != null && partUploadCount >= limit) {
            return http.Response('', 500);
          }
          partUploadCount++;
          final n = int.parse(qp['partNumber']!);
          session.parts[n] = Uint8List.fromList(request.bodyBytes);
          return http.Response(
            '',
            200,
            headers: {'etag': '"part-$n-${request.bodyBytes.length}"'},
          );
        }
        objects[key] = Uint8List.fromList(request.bodyBytes);
        return http.Response('', 200);
      case 'HEAD':
        final body = objects[key];
        if (body == null) return http.Response('', 404);
        return http.Response(
          '',
          200,
          headers: {
            'content-length': '${body.length}',
            'last-modified': 'Thu, 09 Jul 2026 00:00:00 GMT',
          },
        );
      case 'GET':
        if (qp.containsKey('uploads')) {
          final prefixParam = qp['prefix'] ?? '';
          final entries = _sessions.entries
              .where((e) => e.value.key.startsWith(prefixParam))
              .map(
                (e) =>
                    '<Upload><Key>${e.value.key}</Key>'
                    '<UploadId>${e.key}</UploadId>'
                    '<Initiated>${e.value.initiated.toUtc().toIso8601String()}</Initiated>'
                    '</Upload>',
              )
              .join();
          return http.Response(
            '<?xml version="1.0"?><ListMultipartUploadsResult>'
            '<IsTruncated>false</IsTruncated>$entries'
            '</ListMultipartUploadsResult>',
            200,
          );
        }
        if (qp.containsKey('uploadId')) {
          final session = _sessions[qp['uploadId']];
          if (session == null) return http.Response('', 404);
          final ordered = session.parts.keys.toList()..sort();
          final parts = ordered
              .map(
                (n) =>
                    '<Part><PartNumber>$n</PartNumber>'
                    '<ETag>"part-$n-${session.parts[n]!.length}"</ETag>'
                    '<Size>${session.parts[n]!.length}</Size></Part>',
              )
              .join();
          return http.Response(
            '<?xml version="1.0"?><ListPartsResult>$parts</ListPartsResult>',
            200,
          );
        }
        if (qp.containsKey('list-type')) {
          final prefixParam = qp['prefix'] ?? '';
          final keys = objects.keys
              .where((k) => k.startsWith(prefixParam))
              .toList();
          final contents = keys
              .map(
                (k) =>
                    '<Contents><Key>$k</Key>'
                    '<LastModified>2026-07-09T00:00:00.000Z</LastModified>'
                    '<Size>${objects[k]!.length}</Size></Contents>',
              )
              .join();
          return http.Response(
            '<?xml version="1.0"?><ListBucketResult>'
            '<IsTruncated>false</IsTruncated>$contents'
            '</ListBucketResult>',
            200,
          );
        }
        final body = objects[key];
        if (body == null) return http.Response('', 404);
        final range = request.headers['range'];
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
      case 'DELETE':
        if (qp.containsKey('uploadId')) {
          _sessions.remove(qp['uploadId']);
          return http.Response('', 204);
        }
        objects.remove(key);
        return http.Response('', 204);
      default:
        return http.Response('', 500);
    }
  }
}

/// One in-flight multipart upload session.
class _MultipartSession {
  _MultipartSession({required this.key, required this.initiated});

  final String key;
  final DateTime initiated;
  final Map<int, Uint8List> parts = {};
}
