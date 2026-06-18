import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/stale_restore_detector.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

void main() {
  late FakeCloudStorageProvider provider;
  late ChangesetWriter writer;
  late StaleRestoreDetector detector;
  late String folder;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    final serializer = SyncDataSerializer();
    writer = ChangesetWriter(
      serializer,
      ChangesetCodec(serializer),
      PublishStateStore(db),
    );
    detector = StaleRestoreDetector(SyncRepository());
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
  });
  tearDown(() => tearDownTestDatabase());

  Future<void> publish() async {
    final deviceId = await SyncRepository().getDeviceId();
    await writer.publish(
      provider: provider,
      deviceId: deviceId,
      folderId: folder,
      deletions: const [],
    );
  }

  Future<bool> isStale() async {
    final deviceId = await SyncRepository().getDeviceId();
    return detector.isStaleRestore(
      provider: provider,
      deviceId: deviceId,
      folderId: folder,
    );
  }

  test('not stale right after publishing', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish();
    expect(await isStale(), isFalse);
  });

  test('not stale when nothing was ever published', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    expect(await isStale(), isFalse);
  });

  test(
    'stale when local data is rewound below the published watermark',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await publish();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
      );
      await publish(); // published watermark now == d2's hlc

      // Simulate a restore to an earlier state: drop the newest row so the local
      // HLC high-water falls below the published watermark.
      await DatabaseService.instance.database.customStatement(
        "DELETE FROM dives WHERE id = 'd2'",
      );
      expect(await isStale(), isTrue);
    },
  );
}
