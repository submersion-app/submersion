import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';
import '../../../helpers/mock_providers.dart';
import '../../../support/fake_cloud_storage_provider.dart';

/// End-to-end proof that the changeset-log transport converges two devices
/// through the real merge. One in-memory database stands in for each device in
/// turn (the singleton is swapped), sharing one fake "cloud".
void main() {
  test('two devices converge via performSync', () async {
    final cloud = FakeCloudStorageProvider();

    // --- Device A: create a dive, then sync (publishes a base) ---
    await setUpTestDatabase();
    var svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'a1', diveNumber: 1),
    );
    final ra = await svc.performSync();
    expect(ra.status, SyncResultStatus.success);
    DatabaseService.instance.resetForTesting();

    // --- Device B: fresh DB, same cloud; sync should pull A's dive in ---
    await setUpTestDatabase();
    svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    final rb = await svc.performSync();
    expect(rb.status, SyncResultStatus.success);

    final row = await DatabaseService.instance.database
        .customSelect("SELECT id FROM dives WHERE id = 'a1'")
        .getSingleOrNull();
    expect(
      row,
      isNotNull,
      reason: "device B must receive device A's dive via changeset sync",
    );
  });
}
