import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';

void main() {
  late Directory tmp;
  final captured = <http.Request>[];
  final remote = <String, Uint8List>{}; // wire key -> bytes

  S3MediaObjectStore build({String prefix = 'submersion-media/'}) {
    final config = S3Config(
      endpoint: 'http://localhost:9000',
      bucket: 'test-bucket',
      prefix: prefix,
      accessKeyId: 'AKIA_TEST',
      secretAccessKey: 'secret',
    );
    final client = S3ApiClient(
      config,
      httpClient: MockClient((request) async {
        captured.add(request);
        // Path-style addressing: /test-bucket/<key>
        final key = Uri.decodeComponent(
          request.url.path.replaceFirst('/test-bucket/', ''),
        );
        switch (request.method) {
          case 'PUT':
            remote[key] = Uint8List.fromList(request.bodyBytes);
            return http.Response('', 200);
          case 'HEAD':
            final body = remote[key];
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
            if (request.url.queryParameters.containsKey('list-type')) {
              final prefixParam = request.url.queryParameters['prefix'] ?? '';
              final keys = remote.keys
                  .where((k) => k.startsWith(prefixParam))
                  .toList();
              final contents = keys
                  .map(
                    (k) =>
                        '<Contents><Key>$k</Key>'
                        '<LastModified>2026-07-09T00:00:00.000Z</LastModified>'
                        '<Size>${remote[k]!.length}</Size></Contents>',
                  )
                  .join();
              return http.Response(
                '<?xml version="1.0"?><ListBucketResult>'
                '<IsTruncated>false</IsTruncated>$contents'
                '</ListBucketResult>',
                200,
              );
            }
            final body = remote[key];
            if (body == null) return http.Response('', 404);
            return http.Response.bytes(body, 200);
          case 'DELETE':
            remote.remove(key);
            return http.Response('', 204);
          default:
            return http.Response('', 500);
        }
      }),
    );
    return S3MediaObjectStore(client: client, keyPrefix: config.prefix);
  }

  setUp(() async {
    captured.clear();
    remote.clear();
    tmp = await Directory.systemTemp.createTemp('s3_mos_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  test('putFile composes prefixed key and uploads bytes', () async {
    final store = build();
    final src = File('${tmp.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
    await store.putFile(
      'smv1/objects/ab/abc.jpg',
      src,
      contentType: 'image/jpeg',
    );
    expect(remote.keys, ['submersion-media/smv1/objects/ab/abc.jpg']);
    expect(remote.values.single, [1, 2, 3]);
  });

  test('head returns size and null for missing; getFile round-trips and '
      'maps 404 to notFound', () async {
    final store = build();
    final src = File('${tmp.path}/b.bin')..writeAsBytesSync([9, 9]);
    await store.putFile(
      'smv1/objects/aa/k.bin',
      src,
      contentType: 'application/octet-stream',
    );

    final info = await store.head('smv1/objects/aa/k.bin');
    expect(info!.sizeBytes, 2);
    expect(info.key, 'smv1/objects/aa/k.bin');
    expect(await store.head('smv1/objects/aa/missing.bin'), isNull);

    final dest = File('${tmp.path}/out.bin');
    await store.getFile('smv1/objects/aa/k.bin', dest);
    expect(await dest.readAsBytes(), [9, 9]);

    await expectLater(
      store.getFile('smv1/objects/aa/missing.bin', File('${tmp.path}/x')),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.notFound,
        ),
      ),
    );
  });

  test('list strips the configured prefix from returned keys', () async {
    final store = build();
    final src = File('${tmp.path}/c.bin')..writeAsBytesSync([7]);
    await store.putFile(
      'smv1/objects/aa/x.bin',
      src,
      contentType: 'application/octet-stream',
    );
    final keys = await store.list('smv1/objects/').map((o) => o.key).toList();
    expect(keys, ['smv1/objects/aa/x.bin']);
  });

  test('delete is idempotent through the client', () async {
    final store = build();
    await store.delete('smv1/objects/aa/gone.bin');
    await store.delete('smv1/objects/aa/gone.bin');
    expect(remote, isEmpty);
  });
}
