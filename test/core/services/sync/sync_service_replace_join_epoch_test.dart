// Issue #3482 phase 5 review: replace and join takes on the joined
// library's epoch (or its absence) and nothing of the epoch this device
// held before, its kept accounts publish even when the library's clocks ran
// ahead of this device's, and an encrypted library opens once the key is
// held.

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_cloud_storage_provider.dart';

/// Refuses the accepted-epoch write, as a full prefs store would.
class _StuckEpochStore extends LibraryEpochStore {
  _StuckEpochStore(super.prefs);

  @override
  Future<void> setLastAccepted(LibraryEpochMarker? marker) async =>
      throw StateError('prefs unavailable');
}

void main() {
  late LibraryEpochStore epochStore;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    epochStore = LibraryEpochStore(await SharedPreferences.getInstance());
  });
  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<bool> hasDive(String id) async =>
      (await DatabaseService.instance.database
          .customSelect("SELECT id FROM dives WHERE id = '$id'")
          .getSingleOrNull()) !=
      null;

  SyncService serviceOn(CloudStorageProvider cloud) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
    epochStore: epochStore,
  );

  LibraryEpochMarker epoch(String id) =>
      LibraryEpochMarker(epochId: id, replacedAt: 1, deviceId: 'somewhere');

  Future<void> libraryDive() => DiveRepository().createDive(
    createTestDiveWithBottomTime(id: 'lib-1', diveNumber: 1),
  );

  Future<void> thisDevicesAccount() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'mine-1', diveNumber: 7),
    );
    await ConnectedAccountsRepository().create(
      kind: AccountKind.s3,
      label: 'dives @ minio',
      id: 'acct-mine',
    );
  }

  test('an epoch held from another library is dropped, not written into '
      'this one', () async {
    final cloud = FakeCloudStorageProvider();
    await libraryDive();
    await seedPeerLog(cloud, 'peer-1');
    await thisDevicesAccount();
    await SyncRepository().setLastAcceptedEpochId('X');
    await epochStore.setLastAccepted(epoch('X'));
    await epochStore.setPendingReplace(epoch('Y'));
    final svc = serviceOn(cloud);

    await svc.applyReplaceJoin((await svc.prepareReplaceJoin()).prepared!);

    expect(await SyncRepository().getLastAcceptedEpochId(), isNull);
    expect(epochStore.lastAcceptedMarker, isNull);
    expect(epochStore.pendingReplace, isNull);
    await svc.performSync();
    expect(
      await svc.readLibraryEpochMarker(cloud),
      isNull,
      reason: 'the joined library stays without an epoch marker',
    );
  });

  test('the joined library\'s epoch is accepted', () async {
    final cloud = FakeCloudStorageProvider();
    await libraryDive();
    await seedPeerLog(cloud, 'peer-1', epochId: 'e1');
    final svc = serviceOn(cloud);
    await svc.writeLibraryEpochMarker(cloud, epoch('e1'));
    await thisDevicesAccount();

    await svc.applyReplaceJoin((await svc.prepareReplaceJoin()).prepared!);

    expect(await hasDive('lib-1'), isTrue);
    expect(await SyncRepository().getLastAcceptedEpochId(), 'e1');
    expect(epochStore.lastAcceptedMarker?.epochId, 'e1');
  });

  test('a library whose replacement is still uploading waits', () async {
    final cloud = FakeCloudStorageProvider();
    await libraryDive();
    await seedPeerLog(cloud, 'peer-1', epochId: 'e0');
    final svc = serviceOn(cloud);
    await svc.writeLibraryEpochMarker(cloud, epoch('e1'));
    await thisDevicesAccount();

    final step = await svc.prepareReplaceJoin();

    expect(step.refused!.outcome, ReplaceJoinOutcome.stillUploading);
    expect(await hasDive('mine-1'), isTrue);
  });

  test('kept accounts publish when the library\'s clocks ran ahead', () async {
    final cloud = FakeCloudStorageProvider();
    final ahead = DateTime.now()
        .add(const Duration(days: 2))
        .millisecondsSinceEpoch;
    SyncClock.instance.reset();
    SyncClock.instance.configure(nodeId: 'peer-1', now: () => ahead);
    await libraryDive();
    await seedPeerLog(cloud, 'peer-1');
    SyncClock.instance.reset();
    await thisDevicesAccount();
    final svc = serviceOn(cloud);

    await svc.applyReplaceJoin((await svc.prepareReplaceJoin()).prepared!);
    await svc.performSync();

    await tearDownTestDatabase();
    await setUpTestDatabase();
    SyncClock.instance.reset();
    await serviceOn(cloud).performSync();
    expect(await hasDive('lib-1'), isTrue);
    expect(await ConnectedAccountsRepository().getById('acct-mine'), isNotNull);
  });

  group('an encrypted library', () {
    final key = SecretKey(List<int>.generate(32, (i) => i));
    const keyId = '8f14e45f-ceea-467f-ab37-a10a8d5f4c11';

    Future<FakeCloudStorageProvider> encryptedLibrary() async {
      final cloud = FakeCloudStorageProvider();
      await libraryDive();
      await seedPeerLog(
        EncryptingCloudStorageProvider(
          cloud,
          dataKey: key,
          libraryKeyId: keyId,
        ),
        'peer-1',
      );
      await thisDevicesAccount();
      return cloud;
    }

    test(
      'asks for the passphrase without the key, and opens with it',
      () async {
        final cloud = await encryptedLibrary();

        final locked = await serviceOn(cloud).prepareReplaceJoin();
        expect(locked.refused!.outcome, ReplaceJoinOutcome.needsPassphrase);
        expect(await hasDive('mine-1'), isTrue);

        final unlocked = serviceOn(
          EncryptingCloudStorageProvider(
            cloud,
            dataKey: key,
            libraryKeyId: keyId,
          ),
        );
        final step = await unlocked.prepareReplaceJoin();
        expect(step.refused, isNull);
        await unlocked.applyReplaceJoin(step.prepared!);
        expect(await hasDive('lib-1'), isTrue);
        expect(await hasDive('mine-1'), isFalse);
      },
    );

    test('asks for the passphrase when another key is held', () async {
      final cloud = await encryptedLibrary();
      final otherKey = EncryptingCloudStorageProvider(
        cloud,
        dataKey: SecretKey(List<int>.generate(32, (i) => 255 - i)),
        libraryKeyId: '2c1f0a6e-0000-4000-8000-000000000001',
      );

      final step = await serviceOn(otherKey).prepareReplaceJoin();

      expect(step.refused!.outcome, ReplaceJoinOutcome.needsPassphrase);
    });
  });

  // Copilot review: the two mirror writes are independent; a failed first
  // one must not leave the pending replace to run on the next launch.
  test(
    'a failed accepted-epoch write still clears the pending replace',
    () async {
      final cloud = FakeCloudStorageProvider();
      await libraryDive();
      await seedPeerLog(cloud, 'peer-1');
      await thisDevicesAccount();
      final stuck = _StuckEpochStore(await SharedPreferences.getInstance());
      await stuck.setPendingReplace(epoch('Y'));
      final svc = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
        epochStore: stuck,
      );

      final result = await svc.applyReplaceJoin(
        (await svc.prepareReplaceJoin()).prepared!,
      );

      expect(result.outcome, ReplaceJoinOutcome.replaced);
      expect(stuck.pendingReplace, isNull);
    },
  );
}
