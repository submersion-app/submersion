import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

import '../../../../helpers/fake_s3_server.dart';

void main() {
  late FakeS3Server server;
  late S3ApiClient client;

  setUp(() {
    server = FakeS3Server();
    client = S3ApiClient(
      S3Config(
        endpoint: 'http://localhost:9000',
        bucket: 'test-bucket',
        prefix: '',
        accessKeyId: 'AK',
        secretAccessKey: 'SK',
      ),
      httpClient: server.client,
      retryDelay: const Duration(milliseconds: 1),
    );
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
}
