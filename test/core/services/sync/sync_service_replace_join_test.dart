// Issue #3482 phase 5: replace and join. A device that already holds dives
// replaces its library with the one in its sync account: the account's
// library is read first and nothing changes unless it can be applied, then
// one transaction swaps the library, keeping this device's accounts, sync
// identity and chosen sync account.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/core/services/sync/crypto/sync_envelope.dart';
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

  Future<Set<String>> rosterIds() async => {
    for (final a in await ConnectedAccountsRepository().getAll()) a.id,
  };

  SyncService serviceOn(FakeCloudStorageProvider cloud) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  /// The account's library: published by 'peer-1', holding 'lib-1' and one
  /// roster row. Leaves the local database empty, as a new device sees it.
  Future<FakeCloudStorageProvider> libraryInAccount() async {
    final cloud = FakeCloudStorageProvider();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'lib-1', diveNumber: 1),
    );
    await ConnectedAccountsRepository().create(
      kind: AccountKind.dropbox,
      label: 'Dropbox',
      id: 'acct-lib',
    );
    await seedPeerLog(cloud, 'peer-1');
    return cloud;
  }

  /// This device's own library: one dive and an account the library has
  /// not seen, with that account chosen for sync.
  Future<void> thisDevicesLibrary() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'mine-1', diveNumber: 7),
    );
    await ConnectedAccountsRepository().create(
      kind: AccountKind.s3,
      label: 'dives @ minio',
      id: 'acct-mine',
    );
    // The metadata row exists before the account is written to it.
    await SyncRepository().getDeviceId();
    await SyncRepository().setSyncAccount(
      accountId: 'acct-mine',
      providerType: CloudProviderType.s3,
    );
    expect(await SyncRepository().getSyncAccountId(), 'acct-mine');
  }

  test('replaces the library and keeps this device\'s accounts and '
      'identity', () async {
    final cloud = await libraryInAccount();
    await thisDevicesLibrary();
    final deviceId = await SyncRepository().getDeviceId();
    final svc = serviceOn(cloud);

    final step = await svc.prepareReplaceJoin();
    expect(step.refused, isNull);
    final result = await svc.applyReplaceJoin(step.prepared!);

    expect(result.outcome, ReplaceJoinOutcome.replaced);
    expect(await hasDive('lib-1'), isTrue, reason: 'the library arrived');
    expect(await hasDive('mine-1'), isFalse, reason: 'replaced, not merged');
    expect(await rosterIds(), {'acct-lib', 'acct-mine'});
    expect(await SyncRepository().getDeviceId(), deviceId);
    expect(await SyncRepository().getSyncAccountId(), 'acct-mine');
  });

  test('only the kept account waits to sync afterwards', () async {
    final cloud = await libraryInAccount();
    await thisDevicesLibrary();
    final svc = serviceOn(cloud);

    await svc.applyReplaceJoin((await svc.prepareReplaceJoin()).prepared!);

    final pending = await SyncRepository().getPendingRecords();
    expect(
      [for (final r in pending) '${r.entityType}/${r.recordId}'],
      ['connectedAccounts/acct-mine'],
    );
  });

  test('an account with no library is refused and nothing changes', () async {
    final cloud = FakeCloudStorageProvider();
    await thisDevicesLibrary();

    final step = await serviceOn(cloud).prepareReplaceJoin();

    expect(step.prepared, isNull);
    expect(step.refused!.outcome, ReplaceJoinOutcome.noLibrary);
    expect(await hasDive('mine-1'), isTrue);
  });

  test('a library published from a newer schema is refused', () async {
    final cloud = await libraryInAccount();
    await restampPeerSchemaVersion(
      cloud,
      'peer-1',
      schemaVersion: AppDatabase.currentSchemaVersion + 1,
    );
    await thisDevicesLibrary();

    final step = await serviceOn(cloud).prepareReplaceJoin();

    expect(step.refused!.outcome, ReplaceJoinOutcome.newerSchema);
    expect(step.refused!.newerSchemaPeerNames.keys, contains('peer-1'));
    expect(await hasDive('mine-1'), isTrue);
    expect(await hasDive('lib-1'), isFalse);
  });

  test('an encrypted library this device cannot open asks for the '
      'passphrase', () async {
    final cloud = FakeCloudStorageProvider();
    final folder = await cloud.getOrCreateSyncFolder();
    final name = ChangesetLogLayout.manifestName('peer-1');
    await cloud.uploadFile(
      await SyncEnvelope.seal(
        plaintext: Uint8List.fromList(utf8.encode('{}')),
        dataKey: SecretKey(List<int>.generate(32, (i) => i)),
        libraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
        filename: name,
      ),
      name,
      folderId: folder,
    );
    await thisDevicesLibrary();

    final step = await serviceOn(cloud).prepareReplaceJoin();

    expect(step.refused!.outcome, ReplaceJoinOutcome.needsPassphrase);
    expect(await hasDive('mine-1'), isTrue);
  });

  // Review: a readable manifest listed first must not hide a sealed one
  // after it; the collector would skip the sealed device and the replace
  // would drop every dive only it published.
  test('a sealed manifest behind a readable one still asks for the '
      'passphrase', () async {
    final cloud = await libraryInAccount();
    final folder = await cloud.getOrCreateSyncFolder();
    final name = ChangesetLogLayout.manifestName('peer-2');
    await cloud.uploadFile(
      await SyncEnvelope.seal(
        plaintext: Uint8List.fromList(utf8.encode('{}')),
        dataKey: SecretKey(List<int>.generate(32, (i) => i)),
        libraryKeyId: '8f14e45f-ceea-467f-ab37-a10a8d5f4c11',
        filename: name,
      ),
      name,
      folderId: folder,
    );
    await thisDevicesLibrary();

    final step = await serviceOn(cloud).prepareReplaceJoin();

    expect(step.refused?.outcome, ReplaceJoinOutcome.needsPassphrase);
    expect(await hasDive('mine-1'), isTrue);
  });

  // Review: the completeness check reuses the manifests the locked check
  // read, rather than downloading each one a third time.
  test('each device\'s manifest is read twice at most', () async {
    final cloud = await libraryInAccount();
    await thisDevicesLibrary();
    cloud.resetDownloadLog();

    final step = await serviceOn(cloud).prepareReplaceJoin();
    await step.prepared!.dispose();

    final manifest = ChangesetLogLayout.manifestName('peer-1');
    expect(
      cloud.downloadedNames.where((n) => n == manifest).length,
      2,
      reason: 'once to check it, once by the collector',
    );
  });

  // Review: leaving this device's own log out would drop, on this device
  // alone, dives its peers already merged, splitting the fleet.
  test('dives this device already published belong to the library', () async {
    final cloud = await libraryInAccount();
    await thisDevicesLibrary();
    final svc = serviceOn(cloud);
    // An earlier Combine published this device's dives to the account.
    await svc.performSync();

    await svc.applyReplaceJoin((await svc.prepareReplaceJoin()).prepared!);

    expect(await hasDive('lib-1'), isTrue);
    expect(await hasDive('mine-1'), isTrue);
  });

  test('a retired device\'s lingering log is not applied', () async {
    final cloud = await libraryInAccount();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'gone-1', diveNumber: 3),
    );
    await seedPeerLog(cloud, 'peer-old');
    await cloud.uploadFile(
      const RetirementMarker(deviceId: 'peer-old', retiredAt: 1).toBytes(),
      ChangesetLogLayout.retiredMarkerName('peer-old'),
      folderId: await cloud.getOrCreateSyncFolder(),
    );
    await thisDevicesLibrary();
    final svc = serviceOn(cloud);

    await svc.applyReplaceJoin((await svc.prepareReplaceJoin()).prepared!);

    expect(await hasDive('lib-1'), isTrue);
    expect(await hasDive('gone-1'), isFalse);
  });

  // Copilot review: a replace is destructive, so a library one of whose
  // devices has not finished uploading its copy waits rather than applying
  // what has arrived.
  test('a library missing part of a device\'s copy waits', () async {
    final cloud = await libraryInAccount();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'lib-2', diveNumber: 2),
    );
    await seedPeerLog(cloud, 'peer-2');
    final folder = await cloud.getOrCreateSyncFolder();
    final parts =
        (await cloud.listFiles(
          folderId: folder,
          namePattern: ChangesetLogLayout.prefix,
        )).where(
          (f) => f.name.startsWith(
            ChangesetLogLayout.basePartName(
              'peer-2',
              1,
              0,
            ).replaceAll(RegExp(r'\.p\d+$'), ''),
          ),
        );
    expect(parts, isNotEmpty);
    for (final f in parts) {
      await cloud.deleteFile(f.id);
    }
    await thisDevicesLibrary();

    final step = await serviceOn(cloud).prepareReplaceJoin();

    expect(step.refused?.outcome, ReplaceJoinOutcome.stillUploading);
    expect(await hasDive('mine-1'), isTrue);
  });

  test('a failure inside the apply leaves the device as it was', () async {
    final cloud = await libraryInAccount();
    await thisDevicesLibrary();
    final svc = serviceOn(cloud);
    final pendingBefore = (await SyncRepository().getPendingRecords()).length;

    await expectLater(
      svc.applyReplaceJoin(
        (await svc.prepareReplaceJoin()).prepared!,
        afterApplyForTest: () => throw StateError('interrupted'),
      ),
      throwsStateError,
    );

    expect(await hasDive('mine-1'), isTrue);
    expect(await hasDive('lib-1'), isFalse);
    expect(await rosterIds(), {'acct-mine'});
    expect((await SyncRepository().getPendingRecords()).length, pendingBefore);
    expect(
      await PeerCursorStore(
        DatabaseService.instance.database,
      ).allForProvider(cloud.providerId),
      isEmpty,
      reason: 'no cursor recorded for the library',
    );
    expect(
      await SyncRepository().getLastSyncTime(forProvider: cloud.providerId),
      isNull,
    );
  });
}
