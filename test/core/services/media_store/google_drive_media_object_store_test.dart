import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/media_store/google_drive_media_object_store.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';

import '../../../helpers/fake_drive_server.dart';
import '../../../helpers/revocable_client.dart';
import 'media_object_store_contract.dart';

void main() {
  late Directory tmp;
  late FakeDriveServer server;

  GoogleDriveMediaObjectStore build({int? chunkSizeBytes}) {
    return GoogleDriveMediaObjectStore.withClient(
      server.client,
      chunkSizeBytes: chunkSizeBytes ?? 8 * 1024 * 1024,
      apiBase: 'https://fake.googleapis.test',
    );
  }

  setUp(() async {
    server = FakeDriveServer();
    tmp = await Directory.systemTemp.createTemp('gdrive_mos_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  runMediaObjectStoreContract('GoogleDriveMediaObjectStore', () async {
    server = FakeDriveServer();
    return build();
  });

  test('putFile stores the key as the file name in the media '
      'folder', () async {
    final store = build();
    final src = File('${tmp.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
    await store.putFile(
      'smv1/objects/ab/abc.jpg',
      src,
      contentType: 'image/jpeg',
    );
    expect(server.filesById.values.single.name, 'smv1/objects/ab/abc.jpg');
    expect(server.filesById.values.single.bytes, [1, 2, 3]);
    expect(server.foldersByName.keys, ['submersion-media']);
  });

  test('large putFile chunks through one session with progress and resume '
      'state', () async {
    const chunk = 256 * 1024;
    final store = build(chunkSizeBytes: chunk);
    final bytes = List<int>.generate(700 * 1024, (i) => i % 251);
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

    expect(server.filesById.values.single.bytes, bytes);
    expect(server.chunkPutCount, 3, reason: '700KiB / 256KiB = 3 chunks');
    expect(progress.last, bytes.length);
    expect(resumeJson, contains('"sessionUri"'));
  });

  test('kill-and-resume probes the session and uploads only the '
      'tail', () async {
    const chunk = 256 * 1024;
    final store = build(chunkSizeBytes: chunk);
    final bytes = List<int>.generate(700 * 1024, (i) => (i * 3) % 251);
    final src = File('${tmp.path}/kr.mp4')..writeAsBytesSync(bytes);

    String? resumeJson;
    server.failAfterChunkPuts = 2; // chunks 1-2 land, chunk 3 dies once
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
    final putsBefore = server.chunkPutCount;
    expect(putsBefore, 2);

    final resumed = build(chunkSizeBytes: chunk);
    await resumed.putFile(
      'smv1/objects/aa/kr.mp4',
      src,
      contentType: 'video/mp4',
      resumeStateJson: resumeJson,
    );
    expect(server.filesById.values.single.bytes, bytes);
    expect(
      server.chunkPutCount - putsBefore,
      1,
      reason: 'only chunk 3 uploads on resume',
    );
    final probes = server.captured.where(
      (r) =>
          r.method == 'PUT' &&
          (r.headers['Content-Range'] ?? '').startsWith('bytes */'),
    );
    expect(probes, isNotEmpty, reason: 'resume must probe the session');
  });

  test('stale session (404 probe) restarts fresh', () async {
    const chunk = 256 * 1024;
    final store = build(chunkSizeBytes: chunk);
    final bytes = List<int>.generate(300 * 1024, (i) => i % 199);
    final src = File('${tmp.path}/stale.mp4')..writeAsBytesSync(bytes);

    await store.putFile(
      'smv1/objects/aa/stale.mp4',
      src,
      contentType: 'video/mp4',
      resumeStateJson:
          '{"sessionUri":"https://fake.googleapis.test/fake-session/'
          'session-nope","totalBytes":${bytes.length},'
          '"chunkSizeBytes":$chunk}',
    );
    expect(server.filesById.values.single.bytes, bytes);
  });

  test('chunked getFile round-trips with progress', () async {
    const chunk = 256 * 1024;
    final store = build(chunkSizeBytes: chunk);
    final bytes = List<int>.generate(700 * 1024, (i) => (i * 7) % 251);
    // Seed via the adapter itself (also exercises folder reuse).
    final src = File('${tmp.path}/seed.bin')..writeAsBytesSync(bytes);
    await store.putFile(
      'smv1/objects/aa/big.bin',
      src,
      contentType: 'application/octet-stream',
    );

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

  test('head returns null for a missing key and metadata for an existing '
      'one', () async {
    final store = build();
    expect(await store.head('smv1/objects/aa/none.jpg'), isNull);
    final src = File('${tmp.path}/h.jpg')
      ..writeAsBytesSync(Uint8List.fromList([5, 5]));
    await store.putFile(
      'smv1/objects/aa/h.jpg',
      src,
      contentType: 'image/jpeg',
    );
    final info = await store.head('smv1/objects/aa/h.jpg');
    expect(info!.sizeBytes, 2);
  });

  test('a 5xx from Drive surfaces as MediaStoreException on every '
      'verb', () async {
    final store = GoogleDriveMediaObjectStore.withClient(
      MockClient(
        (_) async => http.Response('{"error":{"message":"boom"}}', 500),
      ),
      apiBase: 'https://fake.googleapis.test',
    );
    final src = File('${tmp.path}/x.bin')..writeAsBytesSync([1]);
    await expectLater(
      store.head('smv1/objects/aa/x.bin'),
      throwsA(isA<MediaStoreException>()),
    );
    await expectLater(
      store.putFile('smv1/objects/aa/x.bin', src, contentType: 'x'),
      throwsA(isA<MediaStoreException>()),
    );
    await expectLater(
      store.getFile('smv1/objects/aa/x.bin', File('${tmp.path}/o')),
      throwsA(isA<MediaStoreException>()),
    );
    await expectLater(
      store.delete('smv1/objects/aa/x.bin'),
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

  test('reapStaleUploadSessions is a self-expiry no-op', () async {
    expect(
      await build().reapStaleUploadSessions(olderThan: DateTime.utc(2026)),
      0,
    );
  });

  test('a re-auth that closes and replaces the client is followed on the '
      'next request', () async {
    var live = RevocableClient(server.client);
    final store = GoogleDriveMediaObjectStore(
      clientSupplier: () async => live,
      apiBase: 'https://fake.googleapis.test',
    );
    final src = File('${tmp.path}/reauth.jpg')..writeAsBytesSync([7, 7, 7]);
    await store.putFile(
      'smv1/objects/aa/before.jpg',
      src,
      contentType: 'image/jpeg',
    );

    // What the authenticator does on every re-auth (the 401 retry being
    // the routine trigger): close the published client, then publish a
    // fresh one for the same account.
    live.close();
    live = RevocableClient(server.client);

    await store.putFile(
      'smv1/objects/aa/after.jpg',
      src,
      contentType: 'image/jpeg',
    );

    expect(
      server.filesById.values.map((f) => f.name),
      containsAll(<String>[
        'smv1/objects/aa/before.jpg',
        'smv1/objects/aa/after.jpg',
      ]),
    );
  });

  test('a client closed with no replacement surfaces as a transient '
      'transport failure', () async {
    // The re-auth that never lands: the authenticator tore its client down
    // and no fresh one arrived. This is the exact shape of the bug the
    // supplier exists to prevent, so pin the symptom as well as the kind.
    final dead = RevocableClient(server.client)..close();
    final store = GoogleDriveMediaObjectStore(
      clientSupplier: () async => dead,
      apiBase: 'https://fake.googleapis.test',
    );
    await expectLater(
      store.head('smv1/objects/aa/x.jpg'),
      throwsA(
        isA<MediaStoreException>()
            .having((e) => e.kind, 'kind', MediaStoreErrorKind.transient)
            .having(
              (e) => (e.cause as http.ClientException).message,
              'cause',
              contains('Client is already closed'),
            ),
      ),
    );
  });

  test('a supplier that fails to produce a client is transient', () async {
    final store = GoogleDriveMediaObjectStore(
      clientSupplier: () async =>
          throw const CloudStorageException('silent auth exploded'),
      apiBase: 'https://fake.googleapis.test',
    );
    await expectLater(
      store.head('smv1/objects/aa/x.jpg'),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.transient,
        ),
      ),
    );
  });

  test('a supplier with no Google session fails as an auth error', () async {
    final store = GoogleDriveMediaObjectStore(
      clientSupplier: () async => null,
      apiBase: 'https://fake.googleapis.test',
    );
    await expectLater(
      store.head('smv1/objects/aa/x.jpg'),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.auth,
        ),
      ),
    );
  });
}
