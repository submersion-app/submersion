import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;
  late SyncRepository repository;
  late SyncInitializer initializer;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    cloud = FakeCloudStorageProvider();
    repository = SyncRepository();
    initializer = SyncInitializer(
      syncRepository: repository,
      prefs: await SharedPreferences.getInstance(),
    );
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  SyncService buildService() => SyncService(
    syncRepository: repository,
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
    syncInitializer: initializer,
  );

  /// Build a current-format payload carrying [diveId], as if authored by
  /// another install. Leaves the local DB empty (create -> export -> delete ->
  /// reset) so the seeded log reads as foreign rather than as our own data.
  Future<SyncPayload> craftPayloadWithDive(
    String deviceId,
    String diveId,
  ) async {
    final diveRepo = DiveRepository();
    await diveRepo.createDive(createTestDiveWithBottomTime(id: diveId));
    final payload = await SyncDataSerializer().exportChangeset(
      deviceId: deviceId,
      hlcWatermark: null,
      deletions: const [],
    );
    await diveRepo.deleteDive(diveId);
    await repository.resetSyncState();
    return payload;
  }

  group('uploadNonce envelope round trip', () {
    test('serializes and parses the nonce; absent key reads as null', () {
      final serializer = SyncDataSerializer();
      const payload = SyncPayload(
        version: syncFormatVersion,
        exportedAt: 1,
        deviceId: 'd',
        checksum: 'c',
        data: SyncData(),
        deletions: {},
        uploadNonce: 'nonce-1',
      );

      final parsed = serializer.deserializePayload(
        serializer.serializePayload(payload),
      );
      expect(parsed.uploadNonce, 'nonce-1');

      final legacy = serializer.deserializePayload(
        jsonEncode({
          'version': 2,
          'exportedAt': 1,
          'deviceId': 'd',
          'checksum': 'c',
          'data': const SyncData().toJson(),
          'deletions': <String, dynamic>{},
        }),
      );
      expect(legacy.uploadNonce, isNull);
    });
  });

  group('twin detection', () {
    test(
      'adopts a fresh identity when own manifest carries a foreign nonce',
      () async {
        final deviceId = await repository.getDeviceId();
        // A whole-container clone copies the nonce ring along with the DB, so
        // a real twin scenario always has prior nonces of our own on record.
        // (An EMPTY ring reads as lost prefs, not as a twin -- see the
        // dedicated test below.)
        await initializer.recordUploadNonce(
          'minted-before-the-clone',
          cloud.providerId,
        );
        final twinPayload = await craftPayloadWithDive(deviceId, 'twin-dive-1');
        await seedPeerBaseFromPayload(
          cloud,
          deviceId,
          twinPayload,
          uploadNonce: 'minted-by-the-other-twin',
        );

        final result = await buildService().performSync();

        expect(result.isSuccess, isTrue);
        expect(result.adoptedFreshIdentity, isTrue);
        final newId = await repository.getDeviceId();
        expect(newId, isNot(deviceId), reason: 'the twins must be split');
        expect(
          await DiveRepository().getDiveById('twin-dive-1'),
          isNotNull,
          reason:
              'the shared log now counts as a peer and is merged in the '
              'same pass, converging the twins immediately',
        );
        expect(
          await hasPublishedLog(cloud, newId),
          isTrue,
          reason: 'the sync continues under the new identity',
        );
        expect(
          await hasPublishedLog(cloud, deviceId),
          isTrue,
          reason:
              'the old log is the OTHER twin\'s livelihood -- not ours '
              'to delete',
        );
      },
    );

    test('leaves identity alone when the nonce is one we minted', () async {
      final deviceId = await repository.getDeviceId();
      await initializer.recordUploadNonce('our-own-nonce', cloud.providerId);
      await seedPeerManifest(cloud, deviceId, uploadNonce: 'our-own-nonce');

      final result = await buildService().performSync();

      expect(result.adoptedFreshIdentity, isFalse);
      expect(await repository.getDeviceId(), deviceId);
    });

    test('treats a nonce-less own manifest as a pre-upgrade upload', () async {
      final deviceId = await repository.getDeviceId();
      await seedPeerManifest(cloud, deviceId);

      final result = await buildService().performSync();

      expect(
        result.adoptedFreshIdentity,
        isFalse,
        reason:
            'a nonce-less manifest was written by an older build of THIS '
            'device; flagging it would false-positive every upgrader',
      );
      expect(await repository.getDeviceId(), deviceId);
    });

    test('records its own nonce after each upload', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-nonce'),
      );
      await buildService().performSync();

      final deviceId = await repository.getDeviceId();
      final manifest = await ownManifest(cloud, deviceId);
      expect(manifest, isNotNull);
      expect(manifest!.uploadNonce, isNotNull);
      expect(
        initializer.isForeignUploadNonce(
          manifest.uploadNonce,
          cloud.providerId,
        ),
        isFalse,
        reason: 'our own upload must never read as foreign on the next sync',
      );
    });

    test(
      'does not adopt when an own-named manifest embeds a different device id',
      () async {
        final deviceId = await repository.getDeviceId();
        // A manifest AT our filename whose body names another device is
        // mislabeled, not evidence that someone is using OUR identity.
        final folder = await cloud.getOrCreateSyncFolder();
        final mislabeled = SyncManifest(
          deviceId: 'someone-else-entirely',
          provider: cloud.providerId,
          baseSeq: 1,
          basePartCount: 0,
          baseBytes: 0,
          headSeq: 1,
          uploadNonce: 'foreign-nonce',
          updatedAt: 0,
        );
        await cloud.uploadFile(
          mislabeled.toBytes(),
          ChangesetLogLayout.manifestName(deviceId),
          folderId: folder,
        );

        final result = await buildService().performSync();

        expect(
          result.adoptedFreshIdentity,
          isFalse,
          reason:
              'a mislabeled manifest is not evidence that someone is using '
              'OUR identity; adoption requires the embedded id to match ours',
        );
        expect(await repository.getDeviceId(), deviceId);
      },
    );

    test('a failed upload does not poison the nonce ring', () async {
      // Sync 1 publishes a base and records nonce N1 in the manifest + ring.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-ring-1', diveNumber: 1),
      );
      final service = buildService();
      final first = await service.performSync();
      expect(first.isSuccess, isTrue);

      // Sync 2 has a NEW change to publish, but the upload fails outright: its
      // speculative nonce must be removed again, leaving N1 in the ring.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-ring-2', diveNumber: 2),
      );
      cloud.failUploads = true;
      final second = await service.performSync();
      expect(second.isSuccess, isFalse);

      // Sync 3 sees the own manifest still carrying N1 (the failed upload never
      // replaced it). N1 must still be recognized as ours -- no false twin.
      cloud.failUploads = false;
      final deviceIdBefore = await repository.getDeviceId();
      final third = await service.performSync();

      expect(third.adoptedFreshIdentity, isFalse);
      expect(await repository.getDeviceId(), deviceIdBefore);
    });

    test('a timed-out upload that landed keeps its nonce recorded', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-timeout-1', diveNumber: 1),
      );
      final service = buildService();
      expect((await service.performSync()).isSuccess, isTrue);

      // Sync 2: a NEW change whose PUT lands server-side but the response is
      // lost. The speculative nonce must STAY recorded -- removing it would
      // make a later own upload read as a foreign twin.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-timeout-2', diveNumber: 2),
      );
      cloud.timeoutUploadsAfterWrite = true;
      final second = await service.performSync();
      expect(second.isSuccess, isFalse);

      cloud.timeoutUploadsAfterWrite = false;
      final deviceIdBefore = await repository.getDeviceId();
      final third = await service.performSync();

      expect(
        third.adoptedFreshIdentity,
        isFalse,
        reason:
            'the nonce of an indeterminate upload must survive the failure '
            'path; only definite failures un-record it',
      );
      expect(await repository.getDeviceId(), deviceIdBefore);
    });

    test('idle syncs do not rot the nonce ring into a false twin', () async {
      // Sync 1 publishes a base; its nonce is the one the cloud manifest will
      // keep carrying through every following idle sync.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-idle-base'),
      );
      final service = buildService();
      expect((await service.performSync()).isSuccess, isTrue);
      final deviceId = await repository.getDeviceId();

      // More idle syncs than the ring holds entries. Each publishes nothing,
      // so the manifest keeps the base upload's nonce; none of them may keep
      // its speculative ring slot, or that live nonce would be evicted and
      // the device would read its own manifest as a foreign twin (#733) --
      // minting a fresh identity and re-uploading a full base every few
      // idle syncs, forever.
      for (var i = 1; i <= 9; i++) {
        final result = await service.performSync();
        expect(result.isSuccess, isTrue, reason: 'idle sync $i');
        expect(
          result.adoptedFreshIdentity,
          isFalse,
          reason: 'idle sync $i must not split this device as a twin',
        );
      }
      expect(await repository.getDeviceId(), deviceId);
    });

    test('a heartbeat rewrite gives its speculative ring slot back', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-heartbeat'),
      );
      final service = buildService();
      expect((await service.performSync()).isSuccess, isTrue);
      final deviceId = await repository.getDeviceId();
      final published = await ownManifest(cloud, deviceId);
      expect(published, isNotNull);

      // Age the manifest past the heartbeat threshold so the next idle sync
      // rewrites it -- deliberately preserving the OLD nonce (a heartbeat is
      // not an upload event). The heartbeat sync's speculative nonce never
      // reaches the cloud, so it must be un-recorded again.
      final folder = await cloud.getOrCreateSyncFolder();
      final aged = SyncManifest(
        deviceId: published!.deviceId,
        provider: published.provider,
        baseSeq: published.baseSeq,
        basePartCount: published.basePartCount,
        baseBytes: published.baseBytes,
        baseChecksum: published.baseChecksum,
        basePartChecksums: published.basePartChecksums,
        headSeq: published.headSeq,
        publishedHlcHigh: published.publishedHlcHigh,
        epochId: published.epochId,
        uploadNonce: published.uploadNonce,
        appliedPeerHlc: published.appliedPeerHlc,
        updatedAt: 0,
      );
      await cloud.uploadFile(
        aged.toBytes(),
        ChangesetLogLayout.manifestName(deviceId),
        folderId: folder,
      );

      final result = await service.performSync();
      expect(result.isSuccess, isTrue);
      expect(result.adoptedFreshIdentity, isFalse);

      final prefs = await SharedPreferences.getInstance();
      final ring = prefs.getStringList(
        'sync_upload_nonces_${cloud.providerId}',
      );
      expect(
        ring,
        [published.uploadNonce],
        reason:
            'the heartbeat preserved the previous nonce in the manifest, so '
            'its own speculative nonce must not stay in the ring',
      );
    });

    test('a lost nonce ring reads as lost prefs, not as a twin', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd-prefs-loss'),
      );
      expect((await buildService().performSync()).isSuccess, isTrue);
      final deviceId = await repository.getDeviceId();

      // Simulate SharedPreferences loss while the database (and with it the
      // device id) survives: reinstall keeping the DB, a DB-only restore, or
      // the OS clearing app prefs. The manifest's nonce is now unknown, but
      // an EMPTY ring is evidence of lost prefs, not of a twin.
      SharedPreferences.setMockInitialValues({});
      final freshInitializer = SyncInitializer(
        syncRepository: repository,
        prefs: await SharedPreferences.getInstance(),
      );
      final service = SyncService(
        syncRepository: repository,
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
        syncInitializer: freshInitializer,
      );

      final result = await service.performSync();
      expect(result.isSuccess, isTrue);
      expect(
        result.adoptedFreshIdentity,
        isFalse,
        reason:
            'an empty ring means this install has no upload record at all; '
            'adopting here would mint a new identity (and re-upload a full '
            'base) after every prefs loss',
      );
      expect(await repository.getDeviceId(), deviceId);
    });

    test('the nonce ring keeps the newest entries per provider', () async {
      for (var i = 0; i < 9; i++) {
        await initializer.recordUploadNonce('nonce-$i', 'fake');
      }

      expect(
        initializer.isForeignUploadNonce('nonce-0', 'fake'),
        isTrue,
        reason: 'the oldest entry is evicted once the ring is full',
      );
      expect(initializer.isForeignUploadNonce('nonce-8', 'fake'), isFalse);
      expect(initializer.isForeignUploadNonce('nonce-1', 'fake'), isFalse);
      await initializer.recordUploadNonce('other-nonce', 'other-provider');
      expect(
        initializer.isForeignUploadNonce('nonce-8', 'other-provider'),
        isTrue,
        reason: 'rings are isolated per provider',
      );
    });
  });
}
