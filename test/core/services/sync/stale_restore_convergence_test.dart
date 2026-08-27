import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/stale_restore_detector.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';
import '../../../support/fake_cloud_storage_provider.dart';

/// Issue #997: a device whose own cloud manifest claims a higher HLC than it
/// still holds re-ran the stale-restore cold-start on EVERY sync, wiping all
/// peer cursors each time and re-downloading every peer's full base. The
/// recovery has to make the over-claiming manifest honest so it converges after
/// one sync instead of looping forever.
void main() {
  late FakeCloudStorageProvider cloud;
  late SyncService svc;
  late StaleRestoreDetector detector;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    detector = StaleRestoreDetector(SyncRepository());
  });
  tearDown(() => tearDownTestDatabase());

  Future<bool> isStale() async => detector.isStaleRestore(
    provider: cloud,
    deviceId: await SyncRepository().getDeviceId(),
    folderId: await cloud.getOrCreateSyncFolder(),
  );

  test('one sync clears the stale-restore condition', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    expect((await svc.performSync()).status, SyncResultStatus.success);

    // Rewind past the published watermark, the way a database restore would:
    // raw delete, so no tombstone is left behind.
    await DatabaseService.instance.database.customStatement(
      "DELETE FROM dives WHERE id = 'd2'",
    );
    expect(
      await isStale(),
      isTrue,
      reason: 'precondition: the rewind must be detected',
    );

    expect((await svc.performSync()).status, SyncResultStatus.success);

    expect(
      await isStale(),
      isFalse,
      reason:
          'the recovery sync must republish an honest watermark; otherwise '
          'every later sync re-fires the cold-start and re-pulls every peer',
    );
  });

  test(
    'the recovery sync does not re-pull the peer it already holds',
    () async {
      // --- Device A: publish a base, then a changeset on top of it ---
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'a1', diveNumber: 1),
      );
      expect((await svc.performSync()).status, SyncResultStatus.success);
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'a2', diveNumber: 2),
      );
      expect((await svc.performSync()).status, SyncResultStatus.success);
      await tearDownTestDatabase();

      // --- Device B: cold-start from A, then publish something of its own ---
      await setUpTestDatabase();
      svc = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
      );
      detector = StaleRestoreDetector(SyncRepository());
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'b1', diveNumber: 3),
      );
      expect((await svc.performSync()).status, SyncResultStatus.success);
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'b2', diveNumber: 4),
      );
      expect((await svc.performSync()).status, SyncResultStatus.success);

      // B is rewound below its own published watermark.
      await DatabaseService.instance.database.customStatement(
        "DELETE FROM dives WHERE id = 'b2'",
      );
      expect(await isStale(), isTrue);

      // First sync after the rewind: the cold-start legitimately re-pulls A.
      cloud.resetDownloadLog();
      expect((await svc.performSync()).status, SyncResultStatus.success);

      // Second sync: nothing changed anywhere, so A's base must not move again.
      cloud.resetDownloadLog();
      expect((await svc.performSync()).status, SyncResultStatus.success);
      expect(
        cloud.downloadedNames.where((n) => n.contains('.base.')),
        isEmpty,
        reason:
            'a settled sync must not re-download any peer base -- that is the '
            '#997 "sync takes forever and never finishes" symptom',
      );
    },
  );
}
