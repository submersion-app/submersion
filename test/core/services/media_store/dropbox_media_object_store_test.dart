import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/media_store/dropbox_media_object_store.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

import '../../../helpers/fake_dropbox_server.dart';
import 'media_object_store_contract.dart';

/// A DropboxApiClient whose verbs all throw, to drive the adapter's
/// error mapping.
class _ThrowingDropboxClient extends DropboxApiClient {
  _ThrowingDropboxClient(this.error)
    : super(
        getAccessToken: () async => 't',
        onAccessTokenRejected: () {},
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

  final CloudStorageException error;

  @override
  Future<DropboxFileMetadata?> getMetadata(String path) async => throw error;
  @override
  Future<DropboxFileMetadata> upload(String path, Uint8List data) async =>
      throw error;
  @override
  Future<Uint8List> download(String path) async => throw error;
  @override
  Future<void> delete(String path) async => throw error;
  @override
  Future<List<DropboxFileMetadata>> listFolder({
    String path = '',
    bool recursive = false,
  }) async => throw error;
}

void main() {
  late Directory tmp;
  late FakeDropboxServer server;

  DropboxMediaObjectStore build({int? chunkSizeBytes}) {
    return DropboxMediaObjectStore(
      client: DropboxApiClient(
        getAccessToken: () async => server.bearerToken,
        onAccessTokenRejected: () {},
        httpClient: server.client,
      ),
      chunkSizeBytes: chunkSizeBytes ?? 8 * 1024 * 1024,
    );
  }

  setUp(() async {
    server = FakeDropboxServer();
    tmp = await Directory.systemTemp.createTemp('dropbox_mos_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  runMediaObjectStoreContract('DropboxMediaObjectStore', () async {
    server = FakeDropboxServer();
    return build();
  });

  test('putFile maps the key under /submersion-media', () async {
    final store = build();
    final src = File('${tmp.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
    await store.putFile(
      'smv1/objects/ab/abc.jpg',
      src,
      contentType: 'image/jpeg',
    );
    expect(server.files['/submersion-media/smv1/objects/ab/abc.jpg'], [
      1,
      2,
      3,
    ]);
  });

  test('large putFile goes through a session with progress and resume '
      'state', () async {
    final store = build(chunkSizeBytes: 16 * 1024);
    final bytes = List<int>.generate(50 * 1024, (i) => i % 251);
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

    expect(server.files['/submersion-media/smv1/objects/aa/video.mp4'], bytes);
    expect(progress.last, bytes.length);
    expect(resumeJson, contains('"sessionId"'));
  });

  test('kill-and-resume appends only the remaining chunks', () async {
    final store = build(chunkSizeBytes: 16 * 1024);
    final bytes = List<int>.generate(64 * 1024, (i) => (i * 3) % 251);
    final src = File('${tmp.path}/kr.mp4')..writeAsBytesSync(bytes);

    String? resumeJson;
    // start stores chunk 1; the FIRST append (chunk 2) dies once.
    server.failAfterAppends = 0;
    await expectLater(
      store.putFile(
        'smv1/objects/aa/kr.mp4',
        src,
        contentType: 'video/mp4',
        onResumeStateChanged: (json) => resumeJson = json,
      ),
      throwsA(isA<MediaStoreException>()),
    );
    expect(resumeJson, contains('"offset":16384'));
    expect(server.sessionAppendCount, 0);

    final appendsBefore = server.sessionAppendCount;
    final resumed = build(chunkSizeBytes: 16 * 1024);
    await resumed.putFile(
      'smv1/objects/aa/kr.mp4',
      src,
      contentType: 'video/mp4',
      resumeStateJson: resumeJson,
    );
    expect(server.files['/submersion-media/smv1/objects/aa/kr.mp4'], bytes);
    // 64 KiB / 16 KiB = 4 chunks: chunk 1 in start, chunks 2-3 as appends,
    // chunk 4 in finish. Resume re-sends only chunks 2-3 as appends.
    expect(server.sessionAppendCount - appendsBefore, 2);
  });

  test('a stale resume state (unknown session) restarts fresh', () async {
    final store = build(chunkSizeBytes: 16 * 1024);
    final bytes = List<int>.generate(40 * 1024, (i) => i % 199);
    final src = File('${tmp.path}/stale.mp4')..writeAsBytesSync(bytes);

    await store.putFile(
      'smv1/objects/aa/stale.mp4',
      src,
      contentType: 'video/mp4',
      resumeStateJson:
          '{"sessionId":"session-nope","offset":16384,'
          '"chunkSizeBytes":16384}',
    );
    expect(server.files['/submersion-media/smv1/objects/aa/stale.mp4'], bytes);
  });

  test('chunked getFile round-trips with progress', () async {
    final store = build(chunkSizeBytes: 16 * 1024);
    final bytes = List<int>.generate(50 * 1024, (i) => (i * 7) % 251);
    server.files['/submersion-media/smv1/objects/aa/big.bin'] =
        Uint8List.fromList(bytes);

    final dest = File('${tmp.path}/big.out');
    final progress = <int>[];
    await store.getFile(
      'smv1/objects/aa/big.bin',
      dest,
      onProgress: (received, total) => progress.add(received),
    );
    expect(await dest.readAsBytes(), bytes);
    expect(progress.length, greaterThan(1));
    expect(progress.last, bytes.length);
  });

  DropboxMediaObjectStore throwingStore(CloudStorageException e) =>
      DropboxMediaObjectStore(client: _ThrowingDropboxClient(e));

  test('client errors on every verb surface as MediaStoreException', () async {
    final store = throwingStore(const CloudStorageException('Dropbox 503'));
    final src = File('${tmp.path}/e.bin')..writeAsBytesSync([1]);
    await expectLater(
      store.head('smv1/objects/aa/e.bin'),
      throwsA(isA<MediaStoreException>()),
    );
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
        File('${tmp.path}/nope.bin'),
        contentType: 'x',
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
