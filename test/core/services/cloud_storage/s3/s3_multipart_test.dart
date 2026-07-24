import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

import '../../../../helpers/fake_s3_server.dart';

void main() {
  late FakeS3Server server;
  late S3ApiClient client;

  S3ApiClient clientWith(http.Client http) => S3ApiClient(
    S3Config(
      endpoint: 'http://localhost:9000',
      bucket: 'test-bucket',
      prefix: '',
      accessKeyId: 'AK',
      secretAccessKey: 'SK',
    ),
    httpClient: http,
    retryDelay: const Duration(milliseconds: 1),
  );

  setUp(() {
    server = FakeS3Server();
    client = clientWith(server.client);
  });

  test('multipart create, upload, list, complete round-trips bytes', () async {
    final uploadId = await client.createMultipartUpload(
      'big.bin',
      contentType: 'application/octet-stream',
    );
    expect(uploadId, isNotEmpty);

    final part1 = Uint8List.fromList(List.filled(10, 1));
    final part2 = Uint8List.fromList(List.filled(6, 2));
    final etag1 = await client.uploadPart(
      'big.bin',
      uploadId: uploadId,
      partNumber: 1,
      bytes: part1,
    );
    final etag2 = await client.uploadPart(
      'big.bin',
      uploadId: uploadId,
      partNumber: 2,
      bytes: part2,
    );

    final listed = await client.listParts('big.bin', uploadId: uploadId);
    expect(listed.map((p) => p.partNumber).toList(), [1, 2]);
    expect(listed.map((p) => p.etag).toList(), [etag1, etag2]);

    await client.completeMultipartUpload(
      'big.bin',
      uploadId: uploadId,
      parts: [
        S3PartInfo(partNumber: 1, etag: etag1),
        S3PartInfo(partNumber: 2, etag: etag2),
      ],
    );
    expect(server.objects['big.bin'], [...part1, ...part2]);
  });

  test('abort discards the session and is idempotent', () async {
    final uploadId = await client.createMultipartUpload(
      'gone.bin',
      contentType: 'application/octet-stream',
    );
    await client.abortMultipartUpload('gone.bin', uploadId: uploadId);
    await client.abortMultipartUpload('gone.bin', uploadId: uploadId);
    expect(server.objects.containsKey('gone.bin'), isFalse);
  });

  test('getObjectRange returns the slice and the total length', () async {
    server.objects['r.bin'] = Uint8List.fromList(List.generate(100, (i) => i));
    final range = await client.getObjectRange(
      'r.bin',
      start: 10,
      endInclusive: 19,
    );
    expect(range.bytes, List.generate(10, (i) => i + 10));
    expect(range.totalLength, 100);
  });

  test('createMultipartUpload throws when the response omits the '
      'UploadId', () async {
    final c = clientWith(
      MockClient(
        (_) async => http.Response(
          '<?xml version="1.0"?><InitiateMultipartUploadResult>'
          '</InitiateMultipartUploadResult>',
          200,
        ),
      ),
    );
    await expectLater(
      c.createMultipartUpload('k', contentType: 'x'),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('uploadPart throws when S3 returns no ETag header', () async {
    final c = clientWith(MockClient((_) async => http.Response('', 200)));
    await expectLater(
      c.uploadPart(
        'k',
        uploadId: 'u1',
        partNumber: 1,
        bytes: Uint8List.fromList([1]),
      ),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('abortMultipartUpload surfaces a server error', () async {
    final c = clientWith(MockClient((_) async => http.Response('nope', 500)));
    await expectLater(
      c.abortMultipartUpload('k', uploadId: 'u1'),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('getObjectRange maps a 404 to a not-found error', () async {
    final c = clientWith(MockClient((_) async => http.Response('', 404)));
    await expectLater(
      c.getObjectRange('missing.bin', start: 0, endInclusive: 9),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('getObjectRange wraps a transport failure', () async {
    final c = clientWith(
      MockClient((_) async => throw http.ClientException('reset')),
    );
    await expectLater(
      c.getObjectRange('r.bin', start: 0, endInclusive: 9),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test(
    'listMultipartUploads returns live sessions with initiated times',
    () async {
      server.now = () => DateTime.utc(2026, 7, 1);
      final keep = await client.createMultipartUpload(
        'smv1/objects/aa/a.mp4',
        contentType: 'video/mp4',
      );
      final done = await client.createMultipartUpload(
        'smv1/objects/bb/b.mp4',
        contentType: 'video/mp4',
      );
      final etag = await client.uploadPart(
        'smv1/objects/bb/b.mp4',
        uploadId: done,
        partNumber: 1,
        bytes: Uint8List.fromList([1]),
      );
      await client.completeMultipartUpload(
        'smv1/objects/bb/b.mp4',
        uploadId: done,
        parts: [S3PartInfo(partNumber: 1, etag: etag)],
      );

      final uploads = await client.listMultipartUploads();
      expect(uploads.map((u) => u.uploadId), [keep]);
      expect(uploads.single.key, 'smv1/objects/aa/a.mp4');
      expect(uploads.single.initiated, DateTime.utc(2026, 7, 1));

      // Prefix filtering.
      expect(
        await client.listMultipartUploads(prefix: 'smv1/thumbs/'),
        isEmpty,
      );
    },
  );

  test('listMultipartUploads follows truncated pages via markers', () async {
    var calls = 0;
    final paged = clientWith(
      MockClient((request) async {
        calls++;
        if (calls == 1) {
          expect(
            request.url.queryParameters.containsKey('key-marker'),
            isFalse,
          );
          return http.Response(
            '<?xml version="1.0"?><ListMultipartUploadsResult>'
            '<IsTruncated>true</IsTruncated>'
            '<NextKeyMarker>k1</NextKeyMarker>'
            '<NextUploadIdMarker>u1</NextUploadIdMarker>'
            '<Upload><Key>a.bin</Key><UploadId>u1</UploadId>'
            '<Initiated>2026-07-01T00:00:00Z</Initiated></Upload>'
            '</ListMultipartUploadsResult>',
            200,
          );
        }
        expect(request.url.queryParameters['key-marker'], 'k1');
        expect(request.url.queryParameters['upload-id-marker'], 'u1');
        return http.Response(
          '<?xml version="1.0"?><ListMultipartUploadsResult>'
          '<IsTruncated>false</IsTruncated>'
          '<Upload><Key>b.bin</Key><UploadId>u2</UploadId>'
          '<Initiated>2026-07-02T00:00:00Z</Initiated></Upload>'
          '</ListMultipartUploadsResult>',
          200,
        );
      }),
    );
    final uploads = await paged.listMultipartUploads();
    expect(uploads.map((u) => u.uploadId), ['u1', 'u2']);
    expect(calls, 2);
  });

  test(
    'listMultipartUploads surfaces server errors and unreadable XML',
    () async {
      final erroring = clientWith(
        MockClient((_) async => http.Response('nope', 500)),
      );
      await expectLater(
        erroring.listMultipartUploads(),
        throwsA(isA<CloudStorageException>()),
      );

      final garbled = clientWith(
        MockClient((_) async => http.Response('not xml at all <', 200)),
      );
      await expectLater(
        garbled.listMultipartUploads(),
        throwsA(isA<CloudStorageException>()),
      );
    },
  );
}
