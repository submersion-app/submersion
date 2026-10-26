// Issue #3482 phase 5: after a replace and join, ordinary sync carries on.
// The device does not download the library again, does not publish the dives
// it replaced, does not look like first contact (which would raise the
// Combine question), and what it logs afterwards reaches the other devices.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_cloud_storage_provider.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  Future<bool> hasDive(String id) async =>
      (await DatabaseService.instance.database
          .customSelect("SELECT id FROM dives WHERE id = '$id'")
          .getSingleOrNull()) !=
      null;

  SyncService serviceOn(FakeCloudStorageProvider cloud) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  test('the next syncs hand the device over to the library', () async {
    final cloud = FakeCloudStorageProvider();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'lib-1', diveNumber: 1),
    );
    await seedPeerLog(cloud, 'peer-1');

    // This device, with its own dive and an account the library lacks.
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'mine-1', diveNumber: 7),
    );
    await ConnectedAccountsRepository().create(
      kind: AccountKind.s3,
      label: 'dives @ minio',
      id: 'acct-mine',
    );
    final svc = serviceOn(cloud);
    await svc.applyReplaceJoin((await svc.prepareReplaceJoin()).prepared!);

    // Not first contact: the Combine gate (SyncNotifier.firstSyncMergeInfo)
    // asks only while this account has no last sync time, and the
    // established mark is a later, separate step that may be lost.
    expect(
      await SyncRepository().getLastSyncTime(forProvider: cloud.providerId),
      isNotNull,
    );

    expect((await svc.performSync()).status, isNot(SyncResultStatus.error));
    expect(await hasDive('lib-1'), isTrue);
    expect(await hasDive('mine-1'), isFalse);
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'after-1', diveNumber: 8),
    );
    expect((await svc.performSync()).status, isNot(SyncResultStatus.error));

    // Another device joining the library now sees what this device kept
    // and logged afterwards, and none of what it replaced.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    expect(
      (await serviceOn(cloud).performSync()).status,
      isNot(SyncResultStatus.error),
    );
    expect(await hasDive('lib-1'), isTrue);
    expect(await hasDive('after-1'), isTrue);
    expect(await hasDive('mine-1'), isFalse);
    expect(
      (await ConnectedAccountsRepository().getById('acct-mine'))?.label,
      'dives @ minio',
    );
  });
}
