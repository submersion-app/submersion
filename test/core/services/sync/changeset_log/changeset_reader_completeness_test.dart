import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

/// Whether a pull reached each peer's published head. The storage cleanup
/// trusts a pull only when it did: a peer the reader stopped short of (a gap,
/// a corrupt changeset, an incomplete base) or a device with files but no
/// manifest yet may hold rows that reference media this device does not
/// know about.
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
  tearDown(() => tearDownTestDatabase());

  Future<String> publishAsPeer() async {
    final peerId = await SyncRepository().getDeviceId();
    await writer.publish(
      provider: provider,
      deviceId: peerId,
      folderId: folder,
      deletions: await SyncRepository().getAllDeletions(),
    );
    return peerId;
  }

  Future<ChangesetReadResult> pullAs(String selfDeviceId) => reader.pull(
    provider: provider,
    selfDeviceId: selfDeviceId,
    folderId: folder,
    apply: (p) async => applied.add(p),
    applyBaseFile: spyApplyBaseFile(applied),
  );

  Future<void> deleteNamed(String name) async {
    final files = await provider.listFiles(folderId: folder);
    await provider.deleteFile(files.firstWhere((f) => f.name == name).id);
  }

  test('a peer read to its head is complete', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishAsPeer();

    final result = await pullAs('reader-x');

    expect(result.incompletePeerDeviceIds, isEmpty);
    expect(result.unpublishedPeerDeviceIds, isEmpty);
  });

  test('a changeset gap marks the peer incomplete', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final peerId = await publishAsPeer(); // base @1
    await pullAs('reader-x');
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    await publishAsPeer(); // changeset @2
    await deleteNamed(ChangesetLogLayout.changesetName(peerId, 2));

    final result = await pullAs('reader-x');

    expect(result.incompletePeerDeviceIds, {peerId});
    expect(
      result.readFailedPeerDeviceIds,
      isEmpty,
      reason: 'a gap is not a read failure, which is why it went unnoticed',
    );
  });

  test('a missing base marks the peer incomplete', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final peerId = await publishAsPeer();
    final files = await provider.listFiles(folderId: folder);
    final basePart = files.firstWhere(
      (f) =>
          ChangesetLogLayout.deviceIdOf(f.name) == peerId &&
          f.name.contains('.base.'),
    );
    await provider.deleteFile(basePart.id);

    final result = await pullAs('reader-x');

    expect(result.incompletePeerDeviceIds, {peerId});
  });

  test('a device with files but no manifest is reported unpublished', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final peerId = await publishAsPeer();
    await deleteNamed(ChangesetLogLayout.manifestName(peerId));

    final result = await pullAs('reader-x');

    expect(result.unpublishedPeerDeviceIds, {peerId});
    expect(result.peerManifests, isEmpty);
  });
}
