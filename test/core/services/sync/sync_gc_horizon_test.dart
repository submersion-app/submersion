import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';
import '../../../support/fake_cloud_storage_provider.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  const oldEnough = 40 * 24 * 60 * 60 * 1000; // past the 30-day floor

  Future<void> ageTombstone(String recordId) async {
    // Backdate the tombstone past the GC floor (logDeletion stamps "now").
    final cutoff = DateTime.now().millisecondsSinceEpoch - oldEnough;
    await DatabaseService.instance.database.customStatement(
      "UPDATE deletion_log SET deleted_at = $cutoff WHERE record_id = '$recordId'",
    );
  }

  Future<void> seedPeerManifestWithAck(
    FakeCloudStorageProvider cloud, {
    required String peerId,
    Map<String, String> applied = const {},
    int? updatedAt,
  }) async {
    final folder = await cloud.getOrCreateSyncFolder();
    final manifest = SyncManifest(
      deviceId: peerId,
      provider: cloud.providerId,
      headSeq: 1,
      appliedPeerHlc: applied,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    await cloud.uploadFile(
      manifest.toBytes(),
      ChangesetLogLayout.manifestName(peerId),
      folderId: folder,
    );
  }

  test('a live peer without an ack blocks tombstone GC', () async {
    final cloud = FakeCloudStorageProvider();
    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await DiveRepository().deleteDive('d1');
    await ageTombstone('d1');
    await seedPeerManifestWithAck(cloud, peerId: 'peer-1'); // no acks
    expect((await svc.performSync()).status, SyncResultStatus.success);
    final ids = (await SyncRepository().getAllDeletions()).map(
      (d) => d.recordId,
    );
    expect(ids, contains('d1'), reason: 'unacked tombstone must survive');
  });

  test(
    'acked-by-all-live-peers tombstone is GCd; stale peers ignored',
    () async {
      final cloud = FakeCloudStorageProvider();
      final svc = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await DiveRepository().deleteDive('d1');
      await ageTombstone('d1');
      final selfId = await SyncRepository().getDeviceId();
      // Live peer acks far ahead of the tombstone's HLC; a 13-month-stale
      // peer with no acks must not block.
      await seedPeerManifestWithAck(
        cloud,
        peerId: 'peer-live',
        applied: {selfId: '99999999999999:999999:zzz'},
      );
      await seedPeerManifestWithAck(
        cloud,
        peerId: 'peer-stale',
        updatedAt:
            DateTime.now().millisecondsSinceEpoch - 400 * 24 * 60 * 60 * 1000,
      );
      expect((await svc.performSync()).status, SyncResultStatus.success);
      final ids = (await SyncRepository().getAllDeletions()).map(
        (d) => d.recordId,
      );
      expect(ids, isNot(contains('d1')));
    },
  );

  test('single-device library GCs down to the floor only', () async {
    final cloud = FakeCloudStorageProvider();
    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'old', diveNumber: 1),
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'young', diveNumber: 2),
    );
    await DiveRepository().deleteDive('old');
    await DiveRepository().deleteDive('young');
    await ageTombstone('old'); // 'young' stays inside the 30-day floor
    expect((await svc.performSync()).status, SyncResultStatus.success);
    final ids = (await SyncRepository().getAllDeletions())
        .map((d) => d.recordId)
        .toSet();
    expect(ids, contains('young'));
    expect(ids, isNot(contains('old')));
  });
}
