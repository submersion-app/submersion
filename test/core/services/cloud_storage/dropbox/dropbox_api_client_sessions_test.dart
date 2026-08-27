import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';

import '../../../../helpers/fake_dropbox_server.dart';

void main() {
  late FakeDropboxServer server;
  late DropboxApiClient client;

  setUp(() {
    server = FakeDropboxServer();
    client = DropboxApiClient(
      getAccessToken: () async => server.bearerToken,
      onAccessTokenRejected: () {},
      httpClient: server.client,
    );
  });

  test('session start, append, finish assembles the file in order', () async {
    final sessionId = await client.uploadSessionStart(
      Uint8List.fromList(List.filled(8, 1)),
    );
    await client.uploadSessionAppend(
      sessionId: sessionId,
      offset: 8,
      chunk: Uint8List.fromList(List.filled(8, 2)),
    );
    final meta = await client.uploadSessionFinish(
      sessionId: sessionId,
      offset: 16,
      path: '/m/big.bin',
      lastChunk: Uint8List.fromList(List.filled(4, 3)),
    );
    expect(meta.pathLower, '/m/big.bin');
    expect(server.files['/m/big.bin'], [
      ...List.filled(8, 1),
      ...List.filled(8, 2),
      ...List.filled(4, 3),
    ]);
  });

  test('append with a wrong offset surfaces incorrect_offset', () async {
    final sessionId = await client.uploadSessionStart(
      Uint8List.fromList([1, 2]),
    );
    await expectLater(
      client.uploadSessionAppend(
        sessionId: sessionId,
        offset: 99,
        chunk: Uint8List.fromList([3]),
      ),
      throwsA(predicate((e) => e.toString().contains('incorrect_offset'))),
    );
  });

  test('downloadRange returns the slice and total', () async {
    server.files['/m/r.bin'] = Uint8List.fromList(List.generate(100, (i) => i));
    final range = await client.downloadRange(
      '/m/r.bin',
      start: 10,
      endInclusive: 19,
    );
    expect(range.bytes, List.generate(10, (i) => i + 10));
    expect(range.totalLength, 100);
  });

  test('recursive listFolder returns nested paths', () async {
    server.files['/m/smv1/objects/aa/x.bin'] = Uint8List.fromList([1]);
    server.files['/m/smv1/thumbs/aa/x.jpg'] = Uint8List.fromList([2]);
    server.files['/other.bin'] = Uint8List.fromList([3]);
    final entries = await client.listFolder(path: '/m/smv1', recursive: true);
    expect(entries.map((e) => e.pathLower).toSet(), {
      '/m/smv1/objects/aa/x.bin',
      '/m/smv1/thumbs/aa/x.jpg',
    });
  });
}
