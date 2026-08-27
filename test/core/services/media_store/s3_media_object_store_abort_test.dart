import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';

import '../../../helpers/fake_s3_server.dart';

void main() {
  late Directory tmp;
  late FakeS3Server server;

  S3MediaObjectStore build() {
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
      partSizeBytes: 64 * 1024,
      downloadChunkBytes: 64 * 1024,
    );
  }

  setUp(() async {
    server = FakeS3Server();
    tmp = await Directory.systemTemp.createTemp('s3_abort_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<File> bigSource() async {
    // Three 64 KiB parts.
    final f = File('${tmp.path}/src.mp4');
    await f.writeAsBytes(List.filled(3 * 64 * 1024, 7), flush: true);
    return f;
  }

  const key = 'smv1/objects/aa/aabb.mp4';

  test(
    'putFile without resume persistence aborts the session on failure',
    () async {
      final store = build();
      final src = await bigSource();
      server.failAfterPartUploads = 1;
      await expectLater(
        store.putFile(key, src, contentType: 'video/mp4'),
        throwsA(isA<MediaStoreException>()),
      );
      server.failAfterPartUploads = null;
      expect(server.activeMultipartUploadCount, 0);
    },
  );

  test(
    'putFile WITH resume persistence keeps the session for resume',
    () async {
      final store = build();
      final src = await bigSource();
      server.failAfterPartUploads = 1;
      String? resume;
      await expectLater(
        store.putFile(
          key,
          src,
          contentType: 'video/mp4',
          onResumeStateChanged: (json) => resume = json,
        ),
        throwsA(isA<MediaStoreException>()),
      );
      server.failAfterPartUploads = null;
      expect(server.activeMultipartUploadCount, 1);
      expect(resume, isNotNull);
    },
  );

  test('a session failing on its FIRST part is still abandonable', () async {
    // The persistence branch deliberately does not abort, trusting the
    // caller to abandon later - which is only possible if the caller was
    // ever told the uploadId. Emitting resume state at session creation
    // (not after part 1) is what makes that true in the likeliest
    // failure position of all.
    final store = build();
    final src = await bigSource();
    server.failAfterPartUploads = 0;
    String? resume;
    await expectLater(
      store.putFile(
        key,
        src,
        contentType: 'video/mp4',
        onResumeStateChanged: (json) => resume = json,
      ),
      throwsA(isA<MediaStoreException>()),
    );
    server.failAfterPartUploads = null;
    expect(server.activeMultipartUploadCount, 1);
    expect(resume, isNotNull, reason: 'uploadId must reach the caller');

    await store.abandonResume(key, resume);
    expect(server.activeMultipartUploadCount, 0);
  });

  test('a zero-part resume state resumes from part 1', () async {
    final store = build();
    final src = await bigSource();
    server.failAfterPartUploads = 0;
    String? resume;
    await expectLater(
      store.putFile(
        key,
        src,
        contentType: 'video/mp4',
        onResumeStateChanged: (json) => resume = json,
      ),
      throwsA(isA<MediaStoreException>()),
    );
    server.failAfterPartUploads = null;

    await store.putFile(
      key,
      src,
      contentType: 'video/mp4',
      resumeStateJson: resume,
      onResumeStateChanged: (json) => resume = json,
    );
    expect(server.activeMultipartUploadCount, 0);
    expect(server.objects.containsKey('submersion-media/$key'), isTrue);
  });

  test(
    'abandonResume aborts the recorded session and tolerates junk',
    () async {
      final store = build();
      final src = await bigSource();
      server.failAfterPartUploads = 1;
      String? resume;
      await expectLater(
        store.putFile(
          key,
          src,
          contentType: 'video/mp4',
          onResumeStateChanged: (json) => resume = json,
        ),
        throwsA(isA<MediaStoreException>()),
      );
      server.failAfterPartUploads = null;
      expect(server.activeMultipartUploadCount, 1);

      await store.abandonResume(key, resume);
      expect(server.activeMultipartUploadCount, 0);

      // Junk inputs are silently tolerated.
      await store.abandonResume(key, 'not json');
      await store.abandonResume(key, '{"noUploadId":true}');
      await store.abandonResume(key, null);
    },
  );

  test(
    'reapStaleUploadSessions aborts only stale sessions in this namespace',
    () async {
      final store = build();
      final config = S3Config(
        endpoint: 'http://localhost:9000',
        bucket: 'test-bucket',
        prefix: 'submersion-media/',
        accessKeyId: 'AKIA_TEST',
        secretAccessKey: 'secret',
      );
      final client = S3ApiClient(
        config,
        httpClient: server.client,
        retryDelay: const Duration(milliseconds: 1),
      );

      server.now = () => DateTime.utc(2026, 7, 1);
      await client.createMultipartUpload(
        'submersion-media/smv1/objects/aa/old.mp4',
        contentType: 'video/mp4',
      );
      server.now = () => DateTime.utc(2026, 7, 20);
      await client.createMultipartUpload(
        'submersion-media/smv1/objects/bb/fresh.mp4',
        contentType: 'video/mp4',
      );
      // A session outside this store's namespace must never be touched.
      server.now = () => DateTime.utc(2026, 7, 1);
      await client.createMultipartUpload(
        'unrelated/old.bin',
        contentType: 'application/octet-stream',
      );
      expect(server.activeMultipartUploadCount, 3);

      final n = await store.reapStaleUploadSessions(
        olderThan: DateTime.utc(2026, 7, 10),
      );
      expect(n, 1);
      expect(server.activeMultipartUploadCount, 2);
    },
  );

  test('reap maps a listing failure and swallows per-session abort '
      'failures', () async {
    final config = S3Config(
      endpoint: 'http://localhost:9000',
      bucket: 'test-bucket',
      prefix: 'submersion-media/',
      accessKeyId: 'AKIA_TEST',
      secretAccessKey: 'secret',
    );
    final listFails = S3MediaObjectStore(
      client: _ThrowingListClient(),
      keyPrefix: config.prefix,
    );
    await expectLater(
      listFails.reapStaleUploadSessions(olderThan: DateTime.utc(2026, 7, 10)),
      throwsA(isA<MediaStoreException>()),
    );

    final abortFails = S3MediaObjectStore(
      client: _AbortFailingClient(),
      keyPrefix: config.prefix,
    );
    // The stale session's abort throws; best-effort means count 0, no throw.
    expect(
      await abortFails.reapStaleUploadSessions(
        olderThan: DateTime.utc(2026, 7, 10),
      ),
      0,
    );
  });
}

class _ThrowingListClient extends Fake implements S3ApiClient {
  @override
  Future<List<S3MultipartUploadInfo>> listMultipartUploads({
    String prefix = '',
  }) async => throw const CloudStorageException('listing unavailable');
}

class _AbortFailingClient extends Fake implements S3ApiClient {
  @override
  Future<List<S3MultipartUploadInfo>> listMultipartUploads({
    String prefix = '',
  }) async => [
    S3MultipartUploadInfo(
      key: 'submersion-media/smv1/objects/aa/x.mp4',
      uploadId: 'u1',
      initiated: DateTime.utc(2026, 7, 1),
    ),
  ];

  @override
  Future<void> abortMultipartUpload(
    String key, {
    required String uploadId,
  }) async => throw const CloudStorageException('abort refused');
}
