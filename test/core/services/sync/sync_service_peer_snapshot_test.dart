import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/peer_sync_snapshot.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// The peer sync snapshot a sync leaves for the storage cleanup. It must be
/// trusted only after a sync that reached its clean end: a sync that halts,
/// fails or cannot even authenticate leaves this device not caught up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;
  late LibraryEpochStore epochStore;
  late PeerSyncSnapshotStore snapshots;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    epochStore = LibraryEpochStore(prefs);
    snapshots = PeerSyncSnapshotStore(prefs);
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  SyncService buildService({
    PeerSyncSnapshotStore? peerSnapshots,
    SyncRepository? syncRepository,
  }) => SyncService(
    syncRepository: syncRepository ?? SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
    epochStore: epochStore,
    peerSnapshots: peerSnapshots ?? snapshots,
  );

  /// A caught-up snapshot from an earlier, clean sync.
  Future<void> seedCaughtUp() => snapshots.write(
    PeerSyncSnapshot(
      takenAt: DateTime(2026, 10, 1),
      caughtUp: true,
      providerId: cloud.providerId,
      peers: const [],
    ),
  );

  test('a clean sync records a caught-up snapshot for this backend', () async {
    final result = await buildService().performSync();

    expect(result.isSuccess, isTrue);
    final snapshot = snapshots.read()!;
    expect(snapshot.caughtUp, isTrue);
    expect(snapshot.providerId, cloud.providerId);
  });

  test('the snapshot time comes from before this sync published', () async {
    // A restore that lands while a sync is still publishing must find the
    // snapshot older than its marker: the pull happened before the restore.
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );

    await buildService().performSync();

    final deviceId = await SyncRepository().getDeviceId();
    final files = await cloud.listFiles(
      namePattern: ChangesetLogLayout.listPattern,
    );
    final ownManifest = SyncManifest.fromBytes(
      await cloud.downloadFile(
        files
            .firstWhere(
              (f) => f.name == ChangesetLogLayout.manifestName(deviceId),
            )
            .id,
      ),
    );
    expect(
      snapshots.read()!.takenAt.millisecondsSinceEpoch,
      lessThanOrEqualTo(ownManifest.updatedAt),
    );
  });

  test(
    'a halt for adoption leaves the storage cleanup not caught up',
    () async {
      const marker = LibraryEpochMarker(
        epochId: 'e1',
        replacedAt: 1,
        deviceId: 'replacer',
      );
      await seedCaughtUp();
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await seedPeerManifest(cloud, 'peer-1', epochId: 'e1');

      final result = await service.performSync();

      expect(result.status, SyncResultStatus.awaitingAdoption);
      // Rows a replacing device adds after the replace never arrive here while
      // this device waits, so the cleanup must not trust the old snapshot.
      expect(snapshots.read()!.caughtUp, isFalse);
    },
  );

  test('an authentication failure leaves the cleanup not caught up', () async {
    // A revoked token stops every pull; the media store may keep working.
    await seedCaughtUp();
    cloud.authenticated = false;

    final result = await buildService().performSync();

    expect(result.status, SyncResultStatus.authError);
    expect(snapshots.read()!.caughtUp, isFalse);
  });

  test('a sync whose publish fails still records its clean pull', () async {
    // Caught up describes the pull: this device holds every peer row. A
    // full cloud makes every publish fail, and the cleanup is what frees
    // space; tying the snapshot to the publish deadlocked the two.
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    cloud.failUploads = true;

    final result = await buildService().performSync();

    expect(result.isSuccess, isFalse);
    expect(snapshots.read()!.caughtUp, isTrue);
  });

  test('a sync whose cleanup fails still records its clean pull', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );

    final result = await buildService(
      syncRepository: _FailingCleanupRepository(),
    ).performSync();

    expect(result.isSuccess, isFalse);
    expect(snapshots.read()!.caughtUp, isTrue);
  });

  test('a sync that cannot reset the snapshot does not run', () async {
    final service = buildService(
      peerSnapshots: _ThrowingSnapshots(await SharedPreferences.getInstance()),
    );
    cloud.operationLog.clear();

    final result = await service.performSync();

    expect(result.isSuccess, isFalse);
    expect(cloud.operationLog.where((op) => op.startsWith('upload:')), isEmpty);
  });
}

/// A repository whose post-publish bookkeeping fails.
class _FailingCleanupRepository extends SyncRepository {
  @override
  Future<void> clearPendingRecords({int? markedBefore}) async =>
      throw StateError('disk full');
}

/// A snapshot store whose fail-closed reset cannot be written.
class _ThrowingSnapshots extends PeerSyncSnapshotStore {
  _ThrowingSnapshots(super.prefs);

  @override
  Future<void> markNotCaughtUp() async =>
      throw StateError('prefs write failed');
}
