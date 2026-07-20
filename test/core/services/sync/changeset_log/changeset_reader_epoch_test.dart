import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

/// Epoch filtering keeps replaced-away data inert and reports peers that still
/// need to adopt the current library epoch.
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

  Future<void> spyApply(SyncPayload p) async => applied.add(p);

  Future<void> publishPeer(
    String peerId, {
    String? epochId,
    int? manifestUpdatedAt,
  }) async {
    await writer.publish(
      provider: provider,
      deviceId: peerId,
      folderId: folder,
      deletions: const [],
      epochId: epochId,
    );
    if (manifestUpdatedAt != null) {
      final manifestFile = (await provider.listFiles(
        folderId: folder,
        namePattern: ChangesetLogLayout.manifestName(peerId),
      )).single;
      final manifest =
          jsonDecode(utf8.decode(await provider.downloadFile(manifestFile.id)))
              as Map<String, dynamic>;
      manifest['updatedAt'] = manifestUpdatedAt;
      await provider.uploadFile(
        Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
        manifestFile.name,
        folderId: folder,
      );
    }
  }

  Future<ChangesetReadResult> pull({String? currentEpochId}) => reader.pull(
    provider: provider,
    selfDeviceId: 'reader-x',
    folderId: folder,
    apply: spyApply,
    applyBaseFile: spyApplyBaseFile(applied),
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
    expect(result.skippedPeerDeviceIds, {'peer-1'});
    expect(applied, isEmpty);
  });

  test('skips an unstamped peer and reports it', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer('peer-1'); // no epochId

    final result = await pull(currentEpochId: 'epoch-NEW');

    expect(result.peersProcessed, 0);
    expect(applied, isEmpty);
    expect(result.skippedPeerDeviceIds, {'peer-1'});
  });

  test('skips unstamped peers regardless of manifest timestamp', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer('peer-old', manifestUpdatedAt: 0);
    await publishPeer(
      'peer-recent',
      manifestUpdatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    final result = await pull(currentEpochId: 'epoch-NEW');

    expect(result.peersProcessed, 0);
    expect(result.skippedPeerDeviceIds, {'peer-old', 'peer-recent'});
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
