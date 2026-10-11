import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/webdav/nextcloud_chunked_upload.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';

import '../../../../helpers/fake_webdav_server.dart';

void main() {
  const files = '/remote.php/dav/files/alice';
  const uploads = '/remote.php/dav/uploads/alice';
  late FakeWebDavServer server;
  late WebDavClient client;
  late Directory tmp;
  late File source;
  const size = NextcloudChunkedUpload.chunkBytes * 2 + 123;

  setUp(() async {
    server = FakeWebDavServer(seedCollections: const [files, uploads]);
    client = WebDavClient(
      WebDavConfig(
        preset: WebDavPreset.nextcloud,
        serverUrl: 'https://dav.test',
        username: 'alice',
        password: 'secret',
        nextcloudUserId: 'alice',
      ),
      httpClient: server.client,
      backoff: (_) => Duration.zero,
    );
    tmp = await Directory.systemTemp.createTemp('nc_chunk_test');
    source = File(p.join(tmp.path, 'video.mp4'));
    await source.writeAsBytes(List<int>.generate(size, (i) => i % 253));
  });

  tearDown(() async {
    client.close();
    await tmp.delete(recursive: true);
  });

  NextcloudChunkedUpload uploader() =>
      NextcloudChunkedUpload(client, newTransferId: () => 'submersion-t1');

  test('applies only to Nextcloud files above the threshold', () {
    expect(NextcloudChunkedUpload.appliesTo(client, size), isTrue);
    expect(NextcloudChunkedUpload.appliesTo(client, 1024), isFalse);
    client.chunkingUnsupported = true;
    expect(NextcloudChunkedUpload.appliesTo(client, size), isFalse);
  });

  test('uploads three chunks and assembles them at the destination', () async {
    String? state;
    expect(
      await uploader().upload(
        'Submersion/a/video.mp4',
        source,
        onResumeStateChanged: (s) => state = s,
      ),
      isTrue,
    );
    expect(
      server.files['$files/Submersion/a/video.mp4'],
      await source.readAsBytes(),
    );
    expect(
      server.collections.any((c) => c.startsWith('$uploads/submersion-')),
      isFalse,
    );
    expect(state, contains('submersion-t1'));
    final puts = server.captured.where((r) => r.method == 'PUT').toList();
    expect(puts.map((r) => r.url.pathSegments.last), [
      '00001',
      '00002',
      '00003',
    ]);
    expect(puts.first.headers['oc-total-length'], '$size');
  });

  test('resume skips chunks already on the server', () async {
    const first = NextcloudChunkedUpload.chunkBytes;
    server
      ..seedCollection('$uploads/submersion-t1')
      ..seedFile(
        '$uploads/submersion-t1/00001',
        (await source.readAsBytes()).sublist(0, first),
      );
    final state = NextcloudChunkState(
      transferId: 'submersion-t1',
      chunkSize: first,
      total: size,
      dest: client.uriFor('Submersion/video.mp4').toString(),
    );
    await uploader().upload(
      'Submersion/video.mp4',
      source,
      resumeStateJson: state.toJsonString(),
    );
    final puts = server.captured
        .where((r) => r.method == 'PUT')
        .map((r) => r.url.pathSegments.last);
    expect(puts, ['00002', '00003']);
    expect(server.files['$files/Submersion/video.mp4']!.length, size);
  });

  test('an expired upload directory restarts from the first chunk', () async {
    final state = NextcloudChunkState(
      transferId: 'submersion-gone',
      chunkSize: NextcloudChunkedUpload.chunkBytes,
      total: size,
      dest: client.uriFor('Submersion/video.mp4').toString(),
    );
    await uploader().upload(
      'Submersion/video.mp4',
      source,
      resumeStateJson: state.toJsonString(),
    );
    expect(server.captured.where((r) => r.method == 'PUT'), hasLength(3));
  });

  test('a server without chunking falls back', () async {
    server.chunkingEnabled = false;
    expect(await uploader().upload('Submersion/video.mp4', source), isFalse);
    expect(client.chunkingUnsupported, isTrue);
  });

  test(
    'a MOVE whose reply was lost counts as done when the file is complete',
    () async {
      server.moveFailsAfterApplying = true;
      expect(await uploader().upload('Submersion/video.mp4', source), isTrue);
      expect(server.files['$files/Submersion/video.mp4']!.length, size);
    },
  );

  test(
    'abandon deletes the upload directory and reapStale removes old ones',
    () async {
      server.seedCollection('$uploads/submersion-old');
      server.modified['$uploads/submersion-old'] = DateTime.utc(2026, 1, 1);
      server.seedCollection('$uploads/other-app');
      server.modified['$uploads/other-app'] = DateTime.utc(2026, 1, 1);
      server.seedCollection('$uploads/submersion-new');

      expect(await uploader().reapStale(DateTime.utc(2026, 6, 1)), 1);
      expect(server.collections, isNot(contains('$uploads/submersion-old')));
      expect(server.collections, contains('$uploads/other-app'));

      const state = NextcloudChunkState(
        transferId: 'submersion-new',
        chunkSize: 1,
        total: 1,
        dest: 'x',
      );
      await uploader().abandon(state.toJsonString());
      expect(server.collections, isNot(contains('$uploads/submersion-new')));
      await uploader().abandon('not json');
      await uploader().abandon(null);
    },
  );

  test(
    'a MOVE that stays locked while Nextcloud assembles still succeeds',
    () async {
      server.moveLockedResponses = 10;
      final upload = NextcloudChunkedUpload(
        client,
        newTransferId: () => 'submersion-t1',
        pollDelay: Duration.zero,
      );
      expect(await upload.upload('Submersion/video.mp4', source), isTrue);
      expect(server.files['$files/Submersion/video.mp4']!.length, size);
    },
  );

  test(
    'resume with an expired directory but a complete destination does not re-upload',
    () async {
      server.seedFile(
        '$files/Submersion/video.mp4',
        await source.readAsBytes(),
      );
      final state = NextcloudChunkState(
        transferId: 'submersion-gone',
        chunkSize: NextcloudChunkedUpload.chunkBytes,
        total: size,
        dest: client.uriFor('Submersion/video.mp4').toString(),
      );
      expect(
        await uploader().upload(
          'Submersion/video.mp4',
          source,
          resumeStateJson: state.toJsonString(),
        ),
        isTrue,
      );
      expect(server.captured.where((r) => r.method == 'PUT'), isEmpty);
    },
  );

  test('the assembly MOVE gets a deadline that grows with the file', () {
    expect(
      NextcloudChunkedUpload.moveDeadline(1024),
      const Duration(minutes: 10),
    );
    expect(
      NextcloudChunkedUpload.moveDeadline(10 << 30),
      greaterThan(const Duration(minutes: 30)),
    );
  });
}
