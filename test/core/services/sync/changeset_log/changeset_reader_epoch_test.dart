import 'package:flutter_test/flutter_test.dart';
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

/// Epoch filtering: a peer whose manifest is stamped with a different library
/// epoch than ours is inert -- merging it would leak a replaced-away library
/// back in. Mirrors performSync's per-file stale-epoch filter (sync_service
/// line ~490): skip when `currentEpochId != null && peer.epochId != current`.
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

  Future<void> publishPeer(String peerId, {String? epochId}) async {
    await writer.publish(
      provider: provider,
      deviceId: peerId,
      folderId: folder,
      deletions: const [],
      epochId: epochId,
    );
  }

  Future<ChangesetReadResult> pull({String? currentEpochId}) => reader.pull(
    provider: provider,
    selfDeviceId: 'reader-x',
    folderId: folder,
    apply: spyApply,
    currentEpochId: currentEpochId,
  );

  test('applies a peer stamped with the current epoch', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer('peer-1', epochId: 'epoch-A');

    final result = await pull(currentEpochId: 'epoch-A');

    expect(result.peersProcessed, 1);
    expect(applied.single.data.dives.map((d) => d['id']), contains('d1'));
  });

  test('skips a peer stamped with a stale epoch', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer('peer-1', epochId: 'epoch-OLD');

    final result = await pull(currentEpochId: 'epoch-NEW');

    expect(result.peersProcessed, 0);
    expect(applied, isEmpty);
  });

  test('skips an unstamped peer once we are on an epoch', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer('peer-1'); // no epochId

    final result = await pull(currentEpochId: 'epoch-NEW');

    expect(result.peersProcessed, 0);
    expect(applied, isEmpty);
  });

  test('pre-epoch world (null currentEpochId) applies every peer', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer('peer-1'); // no epochId

    final result = await pull(); // currentEpochId omitted -> no filtering

    expect(result.peersProcessed, 1);
    expect(applied.single.data.dives.map((d) => d['id']), contains('d1'));
  });
}
