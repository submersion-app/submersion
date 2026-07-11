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
}
