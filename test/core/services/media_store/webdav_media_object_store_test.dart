import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/webdav_media_object_store.dart';

import '../../../helpers/fake_webdav_server.dart';

void main() {
  late FakeWebDavServer server;
  late WebDavMediaObjectStore store;
  late Directory tmp;

  WebDavMediaObjectStore build({
    WebDavPreset preset = WebDavPreset.other,
    String serverUrl = 'https://dav.test/dav',
  }) => WebDavMediaObjectStore(
    client: WebDavClient(
      WebDavConfig(
        preset: preset,
        serverUrl: serverUrl,
        username: 'alice',
        password: 'secret',
        folder: kDefaultWebDavMediaFolder,
        nextcloudUserId: 'alice',
      ),
      httpClient: server.client,
      backoff: (_) => Duration.zero,
    ),
  );

  setUp(() async {
    server = FakeWebDavServer();
    store = build();
    tmp = await Directory.systemTemp.createTemp('webdav_media_test');
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<File> fileWith(List<int> bytes) async {
    final f = File(p.join(tmp.path, 'src_${bytes.length}'));
    await f.writeAsBytes(bytes);
    return f;
  }

  test(
    'putFile creates nested collections and head reports the object',
    () async {
      await store.putFile(
        'smv1/objects/ab/abcd.jpg',
        await fileWith([1, 2, 3]),
        contentType: 'image/jpeg',
      );
      expect(server.files['/dav/Submersion Media/smv1/objects/ab/abcd.jpg'], [
        1,
        2,
        3,
      ]);
      final info = await store.head('smv1/objects/ab/abcd.jpg');
      expect(info!.key, 'smv1/objects/ab/abcd.jpg');
      expect(info.sizeBytes, 3);
      expect(await store.head('smv1/objects/ab/none.jpg'), isNull);
    },
  );

  test('getFile of a missing key is notFound', () async {
    await expectLater(
      store.getFile('smv1/objects/zz/none.jpg', File(p.join(tmp.path, 'out'))),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.notFound,
        ),
      ),
    );
  });

  test(
    'list filters by name prefix in a directory and recurses for a slash prefix',
    () async {
      server
        ..seedFile('/dav/Submersion Media/smv1/objects/ab/abcd.jpg', [1])
        ..seedFile('/dav/Submersion Media/smv1/objects/ab/abcd.png', [2])
        ..seedFile('/dav/Submersion Media/smv1/objects/ab/abzz.jpg', [3])
        ..seedFile('/dav/Submersion Media/smv1/thumbs/ab/abcd.jpg', [4]);
      final variants = await store
          .list('smv1/objects/ab/abcd.')
          .map((o) => o.key)
          .toList();
      expect(
        variants,
        unorderedEquals([
          'smv1/objects/ab/abcd.jpg',
          'smv1/objects/ab/abcd.png',
        ]),
      );
      final all = await store.list('smv1/').map((o) => o.key).toList();
      expect(all, hasLength(4));
    },
  );

  test('list under a directory that does not exist yields nothing', () async {
    expect(await store.list('smv1/objects/cd/cdef.').toList(), isEmpty);
  });

  test('delete is idempotent', () async {
    await store.delete('smv1/objects/ab/none.jpg');
  });

  test('errors map to media kinds', () {
    expect(
      mediaStoreKindFor(WebDavErrorCode.unauthorized),
      MediaStoreErrorKind.auth,
    );
    expect(
      mediaStoreKindFor(WebDavErrorCode.untrustedCertificate),
      MediaStoreErrorKind.auth,
    );
    expect(
      mediaStoreKindFor(WebDavErrorCode.notFound),
      MediaStoreErrorKind.notFound,
    );
    expect(
      mediaStoreKindFor(WebDavErrorCode.unreachable),
      MediaStoreErrorKind.transient,
    );
    expect(
      mediaStoreKindFor(WebDavErrorCode.server),
      MediaStoreErrorKind.transient,
    );
    expect(
      mediaStoreKindFor(WebDavErrorCode.tooLarge),
      MediaStoreErrorKind.fatal,
    );
  });

  test('a large Nextcloud upload is chunked and reports resume state', () async {
    server = FakeWebDavServer(
      seedCollections: const [
        '/remote.php/dav/files/alice',
        '/remote.php/dav/uploads/alice',
      ],
    );
    store = build(
      preset: WebDavPreset.nextcloud,
      serverUrl: 'https://dav.test',
    );
    final big = await fileWith(
      Uint8List(NextcloudChunkedUpload.chunkBytes + 1),
    );
    String? state;
    await store.putFile(
      'smv1/objects/ab/big.mp4',
      big,
      contentType: 'video/mp4',
      onResumeStateChanged: (s) => state = s,
    );
    expect(state, isNotNull);
    expect(
      server
          .files['/remote.php/dav/files/alice/Submersion Media/smv1/objects/ab/big.mp4']!
          .length,
      NextcloudChunkedUpload.chunkBytes + 1,
    );
    expect(
      await store.reapStaleUploadSessions(olderThan: DateTime.utc(2030)),
      0,
    );
  });

  test('non-Nextcloud stores have no sessions to reap', () async {
    expect(
      await store.reapStaleUploadSessions(olderThan: DateTime.utc(2030)),
      0,
    );
    await store.abandonResume('k', 'garbage');
  });

  test(
    'putFile into a new shard creates the folder first and sends the body once',
    () async {
      await store.putFile(
        'smv1/objects/cd/cdef.jpg',
        await fileWith([7, 7]),
        contentType: 'image/jpeg',
      );
      expect(server.count('PUT'), 1);
      expect(server.files['/dav/Submersion Media/smv1/objects/cd/cdef.jpg'], [
        7,
        7,
      ]);
    },
  );

  test(
    'a server that echoes paths in another case does not loop the walk',
    () async {
      server
        ..seedFile('/dav/Submersion Media/smv1/objects/ab/abcd.jpg', [1])
        ..hrefPath = ((p) =>
            p.replaceFirst('/dav/Submersion Media', '/dav/SUBMERSION MEDIA'))
        ..maxRequests = 100;
      final keys = await store
          .list('smv1/')
          .map((o) => o.key)
          .toList()
          .timeout(const Duration(seconds: 5));
      expect(keys, ['smv1/objects/ab/abcd.jpg']);
    },
  );
}
