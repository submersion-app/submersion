import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

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

  /// Craft a current-format payload file with an explicit upload nonce.
  Uint8List craftFile(
    String deviceId, {
    List<Map<String, dynamic>> dives = const [],
    String? uploadNonce,
  }) {
    final data = SyncData(dives: dives);
    final checksum = sha256
        .convert(utf8.encode(jsonEncode(data.toJson())))
        .toString();
    final payload = SyncPayload(
      version: syncFormatVersion,
      exportedAt: 1700000000000,
      deviceId: deviceId,
      checksum: checksum,
      data: data,
      deletions: const {},
      uploadNonce: uploadNonce,
    );
    return Uint8List.fromList(
      utf8.encode(SyncDataSerializer().serializePayload(payload)),
    );
  }

  /// A valid dive JSON map (as produced by export) with the given id.
  Future<Map<String, dynamic>> validDiveMap(String id) async {
    final diveRepo = DiveRepository();
    await diveRepo.createDive(createTestDiveWithBottomTime(id: id));
    final exported = await SyncDataSerializer().exportData(
      deviceId: 'seed',
      deletions: const [],
    );
    final map = exported.data.dives.firstWhere((d) => d['id'] == id);
    await diveRepo.deleteDive(id);
    await SyncRepository().resetSyncState();
    return map;
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
      'adopts a fresh identity when own file carries a foreign nonce',
      () async {
        final deviceId = await repository.getDeviceId();
        final twinDive = await validDiveMap('twin-dive-1');
        cloud.seedFile(
          'submersion_sync_$deviceId.json',
          craftFile(
            deviceId,
            dives: [twinDive],
            uploadNonce: 'minted-by-the-other-twin',
          ),
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
              'the shared file now counts as a peer and is merged in the '
              'same pass, converging the twins immediately',
        );
        expect(
          await cloud.fileExists('submersion_sync_$newId.json'),
          isTrue,
          reason: 'the sync continues under the new identity',
        );
        expect(
          await cloud.fileExists('submersion_sync_$deviceId.json'),
          isTrue,
          reason:
              'the old file is the OTHER twin\'s livelihood -- not ours '
              'to delete',
        );
      },
    );

    test('leaves identity alone when the nonce is one we minted', () async {
      final deviceId = await repository.getDeviceId();
      await initializer.recordUploadNonce('our-own-nonce', cloud.providerId);
      cloud.seedFile(
        'submersion_sync_$deviceId.json',
        craftFile(deviceId, uploadNonce: 'our-own-nonce'),
      );

      final result = await buildService().performSync();

      expect(result.adoptedFreshIdentity, isFalse);
      expect(await repository.getDeviceId(), deviceId);
    });

    test('treats a nonce-less own file as a pre-upgrade upload', () async {
      final deviceId = await repository.getDeviceId();
      cloud.seedFile(
        'submersion_sync_$deviceId.json',
        craftFile(deviceId, uploadNonce: null),
      );

      final result = await buildService().performSync();

      expect(
        result.adoptedFreshIdentity,
        isFalse,
        reason:
            'a nonce-less file was written by an older build of THIS '
            'device; flagging it would false-positive every upgrader',
      );
      expect(await repository.getDeviceId(), deviceId);
    });

    test('records its own nonce after each upload', () async {
      await buildService().performSync();

      final deviceId = await repository.getDeviceId();
      final uploaded = cloud.bytesOf('submersion_sync_$deviceId.json');
      expect(uploaded, isNotNull);
      final payload = SyncDataSerializer().deserializePayload(
        utf8.decode(uploaded!),
      );
      expect(payload.uploadNonce, isNotNull);
      expect(
        initializer.isForeignUploadNonce(payload.uploadNonce, cloud.providerId),
        isFalse,
        reason: 'our own upload must never read as foreign on the next sync',
      );
    });

    test(
      'does not adopt when an own-named file embeds a different device id',
      () async {
        final deviceId = await repository.getDeviceId();
        cloud.seedFile(
          'submersion_sync_$deviceId.json',
          craftFile('someone-else-entirely', uploadNonce: 'foreign-nonce'),
        );

        final result = await buildService().performSync();

        expect(
          result.adoptedFreshIdentity,
          isFalse,
          reason:
              'a mislabeled file is not evidence that someone is using OUR '
              'identity; adoption requires the embedded id to match ours',
        );
        expect(await repository.getDeviceId(), deviceId);
      },
    );

    test('a failed upload does not poison the nonce ring', () async {
      // Sync 1 succeeds and records nonce N1 (embedded in the own file).
      final service = buildService();
      final first = await service.performSync();
      expect(first.isSuccess, isTrue);

      // Sync 2's upload fails outright: its speculative nonce must be
      // removed again, leaving N1 in the ring.
      cloud.failUploads = true;
      final second = await service.performSync();
      expect(second.isSuccess, isFalse);

      // Sync 3 sees the own file still carrying N1 (the failed upload never
      // replaced it). N1 must still be recognized as ours.
      cloud.failUploads = false;
      final deviceIdBefore = await repository.getDeviceId();
      final third = await service.performSync();

      expect(third.adoptedFreshIdentity, isFalse);
      expect(await repository.getDeviceId(), deviceIdBefore);
    });

    test('a timed-out upload that landed keeps its nonce recorded', () async {
      // Sync 1 succeeds normally.
      final service = buildService();
      expect((await service.performSync()).isSuccess, isTrue);

      // Sync 2: the PUT lands server-side but the response is lost. The
      // speculative nonce must STAY recorded -- the cloud file now carries
      // it, and removing it would make our own upload read as a foreign
      // twin on the next sync.
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
      expect(
        initializer.isForeignUploadNonce('nonce-8', 'other-provider'),
        isTrue,
        reason: 'rings are isolated per provider',
      );
    });
  });
}
