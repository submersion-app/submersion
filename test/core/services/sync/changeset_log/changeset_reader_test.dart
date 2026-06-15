import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

/// The reader is exercised by publishing as the local (singleton) device, then
/// pulling as a *different* selfDeviceId so the published files read as a peer.
/// `apply` is a spy that records payloads, so we can assert fetch order and
/// cursor advance without a second database.
void main() {
  late FakeCloudStorageProvider provider;
  late ChangesetWriter writer;
  late ChangesetReader reader;
  late String folder;
  final applied = <SyncPayload>[];

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    final serializer = SyncDataSerializer();
    final codec = ChangesetCodec(serializer);
    writer = ChangesetWriter(
      serializer,
      codec,
      PublishStateStore(db),
      compactionByteRatio: 1000.0,
      compactionMaxChangesets: 1 << 30,
    );
    reader = ChangesetReader(codec, PeerCursorStore(db));
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
    applied.clear();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  Future<void> spyApply(SyncPayload p) async => applied.add(p);

  Future<String> publishAsPeer() async {
    final peerId = await SyncRepository().getDeviceId();
    final deletions = await SyncRepository().getAllDeletions();
    await writer.publish(
      provider: provider,
      deviceId: peerId,
      folderId: folder,
      deletions: deletions,
    );
    return peerId;
  }

  Future<ChangesetReadResult> pullAs(String selfDeviceId) => reader.pull(
    provider: provider,
    selfDeviceId: selfDeviceId,
    folderId: folder,
    apply: spyApply,
  );

  test(
    'cold-start pulls base then changesets, in order, and advances cursor',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      final peerId = await publishAsPeer(); // base @1 (d1)
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
      );
      await publishAsPeer(); // changeset @2 (d2)

      final result = await pullAs('reader-x');
      expect(result.peersProcessed, 1);
      expect(applied.length, 2);
      expect(applied.first.data.dives.map((d) => d['id']), contains('d1'));
      expect(applied.last.data.dives.map((d) => d['id']), contains('d2'));

      final cursor = await PeerCursorStore(
        DatabaseService.instance.database,
      ).get(peerId, provider.providerId);
      expect(cursor!.lastSeqApplied, 2);
    },
  );

  test('an up-to-date peer applies nothing on a second pull', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishAsPeer();
    await pullAs('reader-x');
    applied.clear();

    await pullAs('reader-x');
    expect(applied, isEmpty);
  });

  test('steady-state pulls only the new changeset', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishAsPeer(); // base @1
    await pullAs('reader-x'); // applies base, cursor=1
    applied.clear();

    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    await publishAsPeer(); // changeset @2
    await pullAs('reader-x');

    expect(applied.length, 1);
    expect(applied.single.data.dives.map((d) => d['id']), contains('d2'));
  });

  test('the device skips its own files', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final peerId = await publishAsPeer();

    final result = await pullAs(peerId); // pull AS the publisher
    expect(result.peersProcessed, 0);
    expect(applied, isEmpty);
  });
}
