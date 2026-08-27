import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';

import '../../../helpers/fake_s3_server.dart';

/// An S3ApiClient whose every operation throws a fixed CloudStorageException,
/// so the adapter's error-mapping (_map) can be exercised for each verb.
class _ThrowingS3Client extends S3ApiClient {
  _ThrowingS3Client(this.error)
    : super(
        S3Config(
          endpoint: 'http://localhost:9000',
          bucket: 'test-bucket',
          accessKeyId: 'AK',
          secretAccessKey: 'SK',
        ),
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

  final CloudStorageException error;

  @override
  Future<S3ObjectInfo?> headObject(String key) async => throw error;
  @override
  Future<Uint8List> getObject(String key) async => throw error;
  @override
  Future<void> putObject(
    String key,
    Uint8List bytes, {
    String? contentType,
  }) async => throw error;
  @override
  Future<void> deleteObject(String key) async => throw error;
  @override
  Future<List<S3ObjectInfo>> listObjects({
    String prefix = '',
    int? maxKeys,
  }) async => throw error;
}

void main() {
  late Directory tmp;
  late FakeS3Server server;

  S3MediaObjectStore build({int? partSizeBytes, int? downloadChunkBytes}) {
    final config = S3Config(
      endpoint: 'http://localhost:9000',
      bucket: 'test-bucket',
      prefix: 'submersion-media/',
      accessKeyId: 'AKIA_TEST',
      secretAccessKey: 'secret',
    );
    return S3MediaObjectStore(
      client: S3ApiClient(
        config,
        httpClient: server.client,
        retryDelay: const Duration(milliseconds: 1),
      ),
      keyPrefix: config.prefix,
      partSizeBytes: partSizeBytes ?? 8 * 1024 * 1024,
      downloadChunkBytes: downloadChunkBytes ?? 8 * 1024 * 1024,
    );
  }

  setUp(() async {
    server = FakeS3Server();
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
    expect(server.objects.keys, ['submersion-media/smv1/objects/ab/abc.jpg']);
    expect(server.objects.values.single, [1, 2, 3]);
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
    expect(server.objects, isEmpty);
  });

  test('large putFile goes multipart, reports progress, and '
      'round-trips', () async {
    final store = build(
      partSizeBytes: 64 * 1024,
      downloadChunkBytes: 64 * 1024,
    );
    final bytes = List<int>.generate(200 * 1024, (i) => i % 251);
    final src = File('${tmp.path}/video.mp4')..writeAsBytesSync(bytes);

    final progress = <int>[];
    String? resumeJson;
    await store.putFile(
      'smv1/objects/aa/video.mp4',
      src,
      contentType: 'video/mp4',
      onProgress: (sent, total) => progress.add(sent),
      onResumeStateChanged: (json) => resumeJson = json,
    );

    expect(server.objects['submersion-media/smv1/objects/aa/video.mp4'], bytes);
    expect(server.partUploadCount, 4, reason: '200KiB / 64KiB = 4 parts');
    expect(progress.last, bytes.length);
    expect(resumeJson, contains('"uploadId"'));

    final dest = File('${tmp.path}/video.out');
    final getProgress = <int>[];
    await store.getFile(
      'smv1/objects/aa/video.mp4',
      dest,
      onProgress: (received, total) => getProgress.add(received),
    );
    expect(await dest.readAsBytes(), bytes);
    expect(getProgress.length, greaterThan(1), reason: 'chunked download');
    expect(getProgress.last, bytes.length);
  });

  test('kill-and-resume: a mid-upload failure resumes from the last '
      'acknowledged part without re-uploading it', () async {
    final store = build(partSizeBytes: 64 * 1024);
    final bytes = List<int>.generate(200 * 1024, (i) => (i * 3) % 251);
    final src = File('${tmp.path}/kr.mp4')..writeAsBytesSync(bytes);

    String? resumeJson;
    server.failAfterPartUploads = 2; // parts 1-2 succeed, part 3 dies
    await expectLater(
      store.putFile(
        'smv1/objects/aa/kr.mp4',
        src,
        contentType: 'video/mp4',
        onResumeStateChanged: (json) => resumeJson = json,
      ),
      throwsA(isA<MediaStoreException>()),
    );
    expect(resumeJson, isNotNull);
    final partsBefore = server.partUploadCount;
    expect(partsBefore, 2);

    // "Restart the app": a fresh store instance resumes from the JSON.
    server.failAfterPartUploads = null;
    final resumed = build(partSizeBytes: 64 * 1024);
    await resumed.putFile(
      'smv1/objects/aa/kr.mp4',
      src,
      contentType: 'video/mp4',
      resumeStateJson: resumeJson,
      onResumeStateChanged: (json) => resumeJson = json,
    );
    expect(server.objects['submersion-media/smv1/objects/aa/kr.mp4'], bytes);
    expect(
      server.partUploadCount - partsBefore,
      2,
      reason: 'only parts 3-4 upload on resume',
    );
  });

  test('a corrupted resume state (wrong-typed fields) restarts fresh '
      'instead of crashing', () async {
    final store = build(partSizeBytes: 64 * 1024);
    final bytes = List<int>.generate(130 * 1024, (i) => i % 197);
    final src = File('${tmp.path}/corrupt.mp4')..writeAsBytesSync(bytes);

    // partSizeBytes matches so validation reaches the parts cast; "n"
    // holding a string throws TypeError, which is an Error, not an
    // Exception. Persisted resume JSON is untrusted input and must never
    // escape putFile.
    await store.putFile(
      'smv1/objects/aa/corrupt.mp4',
      src,
      contentType: 'video/mp4',
      resumeStateJson:
          '{"uploadId":"upload-9","partSizeBytes":65536,'
          '"parts":[{"n":"one","etag":7}]}',
    );
    expect(
      server.objects['submersion-media/smv1/objects/aa/corrupt.mp4'],
      bytes,
    );
  });

  test('putFile forwards the content type on both upload paths', () async {
    final store = build(partSizeBytes: 64 * 1024);

    final small = File('${tmp.path}/small.jpg')..writeAsBytesSync([1, 2, 3]);
    await store.putFile(
      'smv1/objects/aa/small.jpg',
      small,
      contentType: 'image/jpeg',
    );
    final singleShot = server.captured.lastWhere(
      (r) =>
          r.method == 'PUT' && !r.url.queryParameters.containsKey('partNumber'),
    );
    expect(singleShot.headers['content-type'], 'image/jpeg');

    final big = File('${tmp.path}/big.mp4')
      ..writeAsBytesSync(List<int>.generate(130 * 1024, (i) => i % 251));
    await store.putFile(
      'smv1/objects/aa/big.mp4',
      big,
      contentType: 'video/mp4',
    );
    final initiate = server.captured.lastWhere(
      (r) => r.method == 'POST' && r.url.queryParameters.containsKey('uploads'),
    );
    expect(initiate.headers['content-type'], 'video/mp4');
  });

  test('a stale resume state (unknown uploadId) aborts and restarts '
      'fresh', () async {
    final store = build(partSizeBytes: 64 * 1024);
    final bytes = List<int>.generate(130 * 1024, (i) => i % 199);
    final src = File('${tmp.path}/stale.mp4')..writeAsBytesSync(bytes);

    await store.putFile(
      'smv1/objects/aa/stale.mp4',
      src,
      contentType: 'video/mp4',
      resumeStateJson:
          '{"uploadId":"upload-does-not-exist","partSizeBytes":65536,'
          '"parts":[{"n":1,"etag":"\\"bogus\\""}]}',
    );
    expect(server.objects['submersion-media/smv1/objects/aa/stale.mp4'], bytes);
  });

  S3MediaObjectStore throwingStore(CloudStorageException e) =>
      S3MediaObjectStore(
        client: _ThrowingS3Client(e),
        keyPrefix: 'submersion-media/',
      );

  test('client errors map to the retry taxonomy by message', () async {
    final cases = <String, MediaStoreErrorKind>{
      'Access denied to bucket': MediaStoreErrorKind.auth,
      'Could not reach S3 endpoint': MediaStoreErrorKind.transient,
      'S3 returned an unexpected 500': MediaStoreErrorKind.fatal,
    };
    for (final entry in cases.entries) {
      final store = throwingStore(CloudStorageException(entry.key));
      await expectLater(
        store.head('smv1/objects/aa/x.bin'),
        throwsA(
          isA<MediaStoreException>().having((e) => e.kind, 'kind', entry.value),
        ),
        reason: entry.key,
      );
    }
  });

  test('every verb wraps a client error as a MediaStoreException', () async {
    final store = throwingStore(
      const CloudStorageException('Access denied to bucket'),
    );
    final src = File('${tmp.path}/e.bin')..writeAsBytesSync([1]);
    await expectLater(
      store.putFile('smv1/objects/aa/e.bin', src, contentType: 'x'),
      throwsA(isA<MediaStoreException>()),
    );
    await expectLater(
      store.getFile('smv1/objects/aa/e.bin', File('${tmp.path}/o')),
      throwsA(isA<MediaStoreException>()),
    );
    await expectLater(
      store.delete('smv1/objects/aa/e.bin'),
      throwsA(isA<MediaStoreException>()),
    );
    await expectLater(
      store.list('smv1/objects/').toList(),
      throwsA(isA<MediaStoreException>()),
    );
  });

  test('a missing source file is a fatal MediaStoreException', () async {
    final store = build();
    await expectLater(
      store.putFile(
        'smv1/objects/aa/gone.bin',
        File('${tmp.path}/does-not-exist.bin'),
        contentType: 'application/octet-stream',
      ),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.fatal,
        ),
      ),
    );
  });
}
