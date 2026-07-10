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

  final Map<String, Map<int, Uint8List>> _sessions = {};
  int _uploadCounter = 0;

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
          _sessions[id] = {};
          return http.Response(
            '<?xml version="1.0"?><InitiateMultipartUploadResult>'
            '<UploadId>$id</UploadId></InitiateMultipartUploadResult>',
            200,
          );
        }
        if (qp.containsKey('uploadId')) {
          final session = _sessions.remove(qp['uploadId']);
          if (session == null) return http.Response('', 404);
          final ordered = session.keys.toList()..sort();
          final builder = BytesBuilder();
          for (final n in ordered) {
            builder.add(session[n]!);
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
          session[n] = Uint8List.fromList(request.bodyBytes);
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
        if (qp.containsKey('uploadId')) {
          final session = _sessions[qp['uploadId']];
          if (session == null) return http.Response('', 404);
          final ordered = session.keys.toList()..sort();
          final parts = ordered
              .map(
                (n) =>
                    '<Part><PartNumber>$n</PartNumber>'
                    '<ETag>"part-$n-${session[n]!.length}"</ETag>'
                    '<Size>${session[n]!.length}</Size></Part>',
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
