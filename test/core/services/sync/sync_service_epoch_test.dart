import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Coverage for the library epoch protocol on SyncService (restore Replace
/// mode): marker IO, the performSync gate, replace execution, and adoption,
/// all on the per-device changeset-log transport (ssv1.* files).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;
  late LibraryEpochStore epochStore;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    epochStore = LibraryEpochStore(await SharedPreferences.getInstance());
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
    epochStore: epochStore,
  );

  /// Make a peer's changeset log discoverable under [peerDeviceId], optionally
  /// stamped with [epochId]. Use when a test needs the peer to merely EXIST
  /// (gating / wipe). For a peer whose DATA must be applied, use [seedPeerLog].
  Future<void> seedPeerFile({required String peerDeviceId, String? epochId}) =>
      seedPeerManifest(cloud, peerDeviceId, epochId: epochId);

  group('marker IO', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1,
      deviceId: 'd1',
    );

    test('read returns null when no marker exists', () async {
      final service = buildService();
      expect(await service.readLibraryEpochMarker(cloud), isNull);
    });

    test('write then read round-trips', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      final read = await service.readLibraryEpochMarker(cloud);
      expect(read?.epochId, 'e1');
    });

    test('marker file is invisible to changeset-log discovery', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      final files = await cloud.listFiles(
        namePattern: ChangesetLogLayout.prefix,
      );
      expect(files.where((f) => f.name == libraryEpochFileName), isEmpty);
    });

    test('corrupt marker throws (read failure, not absence)', () async {
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode('not json')),
        libraryEpochFileName,
      );
      final service = buildService();
      expect(
        () => service.readLibraryEpochMarker(cloud),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('executeLibraryReplace', () {
    const marker = LibraryEpochMarker(
      epochId: 'new-epoch',
      replacedAt: 1,
      deviceId: 'replacer',
    );

    test('wipes sync files, writes marker before wipe, publishes a stamped '
        'base, commits epoch', () async {
      // A local dive so the replace has a library to publish as the new base.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'keep-dive'),
      );
      // Seed a peer changeset log and a stray legacy file; both must be wiped.
      await seedPeerFile(peerDeviceId: 'peer-1');
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode('{"version":1}')),
        CloudStorageProviderMixin.canonicalSyncFileName,
      );
      await epochStore.setPendingReplace(marker);
      cloud.operationLog.clear();

      final service = buildService();
      final result = await service.executeLibraryReplace(marker);

      expect(result.isSuccess, isTrue);
      // Marker upload happens before any sync-file delete.
      final markerIdx = cloud.operationLog.indexWhere(
        (op) => op == 'upload:$libraryEpochFileName',
      );
      final firstDeleteIdx = cloud.operationLog.indexWhere(
        (op) => op.startsWith('delete:'),
      );
      expect(markerIdx, isNonNegative);
      expect(firstDeleteIdx, isNonNegative);
      expect(markerIdx, lessThan(firstDeleteIdx));

      // The peer's log and the legacy file are gone; our stamped base exists.
      expect(await hasPublishedLog(cloud, 'peer-1'), isFalse);
      expect(
        await cloud.fileExists(CloudStorageProviderMixin.canonicalSyncFileName),
        isFalse,
      );
      final deviceId = await SyncRepository().getDeviceId();
      expect((await ownManifest(cloud, deviceId))?.epochId, 'new-epoch');
      expect((await cloudBasePayload(cloud, deviceId))?.epochId, 'new-epoch');

      // Epoch committed to both anchors; intent cleared; lastSync set.
      expect(await SyncRepository().getLastAcceptedEpochId(), 'new-epoch');
      expect(epochStore.lastAcceptedEpochId, 'new-epoch');
      expect(epochStore.pendingReplace, isNull);
      expect(await SyncRepository().getLastSyncTime(), isNotNull);
    });

    test('upload failure keeps the pending intent for retry', () async {
      await epochStore.setPendingReplace(marker);
      cloud.failUploads = true;

      final service = buildService();
      final result = await service.executeLibraryReplace(marker);

      expect(result.isSuccess, isFalse);
      expect(epochStore.pendingReplace?.epochId, 'new-epoch');
      expect(await SyncRepository().getLastAcceptedEpochId(), isNull);
    });
  });

  group('performSync epoch gating', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1,
      deviceId: 'replacer',
    );

    test('pending intent executes the replace instead of merging', () async {
      await seedPeerFile(peerDeviceId: 'peer-1');
      await epochStore.setPendingReplace(marker);

      final result = await buildService().performSync();

      expect(result.isSuccess, isTrue);
      expect(epochStore.pendingReplace, isNull);
      expect(await SyncRepository().getLastAcceptedEpochId(), 'e1');
      // The peer log was wiped, not merged.
      expect(await hasPublishedLog(cloud, 'peer-1'), isFalse);
    });

    test(
      'no marker + no accepted epoch behaves as legacy (normal sync)',
      () async {
        final result = await buildService().performSync();
        expect(result.isSuccess, isTrue);
        expect(result.status, isNot(SyncResultStatus.awaitingAdoption));
      },
    );

    test(
      'marker matching accepted epoch proceeds and ignores stale-epoch data',
      () async {
        // A current-epoch peer carries fresh-dive; a stale (unstamped) peer
        // carries stale-dive. Only the current-epoch data may be merged.
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'fresh-dive', diveNumber: 1),
        );
        await seedPeerLog(cloud, 'fresh-peer', epochId: 'e1');
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'stale-dive', diveNumber: 2),
        );
        await seedPeerLog(cloud, 'stale-peer'); // no epoch -> stale

        final service = buildService();
        await service.writeLibraryEpochMarker(cloud, marker);
        await SyncRepository().setLastAcceptedEpochId('e1');
        await epochStore.setLastAccepted(marker);

        final result = await service.performSync();

        expect(result.isSuccess, isTrue);
        expect(
          await DiveRepository().getDiveById('fresh-dive'),
          isNotNull,
          reason: 'current-epoch peer data is merged',
        );
        expect(
          await DiveRepository().getDiveById('stale-dive'),
          isNull,
          reason: 'a stale-epoch peer is inert and must not leak back in',
        );
      },
    );

    test('marker mismatch halts before merge or upload', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      // This device never accepted e1.
      await seedPeerFile(peerDeviceId: 'peer-1', epochId: 'e1');
      cloud.operationLog.clear();

      final result = await service.performSync();

      expect(result.status, SyncResultStatus.awaitingAdoption);
      expect(result.replaceMarker?.epochId, 'e1');
      // No upload of our own file happened.
      expect(
        cloud.operationLog.where((op) => op.startsWith('upload:')),
        isEmpty,
      );
    });

    test('missing marker with accepted epoch self-heals the marker', () async {
      await SyncRepository().setLastAcceptedEpochId('e1');
      await epochStore.setLastAccepted(marker);

      final service = buildService();
      final result = await service.performSync();

      expect(result.isSuccess, isTrue);
      expect((await service.readLibraryEpochMarker(cloud))?.epochId, 'e1');
    });

    test('unreadable marker fails the sync closed', () async {
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode('not json')),
        libraryEpochFileName,
      );
      final result = await buildService().performSync();
      expect(result.status, SyncResultStatus.error);
    });
  });

  group('adoptReplacedLibrary', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1,
      deviceId: 'replacer',
    );

    test('aborts when a current-epoch replace is still uploading', () async {
      final service = buildService();
      // FRESH marker, no base landed yet: a replace in flight. Adopt must
      // wait, not wipe local to empty (and not mistake it for orphaned).
      await service.writeLibraryEpochMarker(
        cloud,
        LibraryEpochMarker(
          epochId: 'e1',
          replacedAt: DateTime.now().millisecondsSinceEpoch,
          deviceId: 'replacer',
        ),
      );
      final result = await service.adoptReplacedLibrary();
      expect(result.isSuccess, isFalse);
      expect(await SyncRepository().getLastAcceptedEpochId(), isNull);
    });

    test(
      'adopt re-establishes from local when the marked library is unreadable',
      () async {
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'mine-1'),
        );
        final service = buildService();
        await service.writeLibraryEpochMarker(
          cloud,
          const LibraryEpochMarker(
            epochId: 'stale',
            replacedAt: 1,
            deviceId: 'old',
          ),
        );
        // Only old-format data on the backend (a pre-changeset app version).
        await cloud.uploadFile(
          Uint8List.fromList(utf8.encode('{"version":1}')),
          '${CloudStorageProviderMixin.syncFilePrefix}old-device'
          '${CloudStorageProviderMixin.syncFileExtension}',
        );

        final result = await service.adoptReplacedLibrary();

        expect(result.isSuccess, isTrue);
        expect(await SyncRepository().getLastAcceptedEpochId(), 'stale');
        // The local library is retained (not wiped to match a missing cloud).
        expect(
          await SyncDataSerializer().fetchRecord('dives', 'mine-1'),
          isNotNull,
        );
      },
    );

    test(
      'applies the restored library wholesale and commits the epoch',
      () async {
        final serializer = SyncDataSerializer();

        // The replacer's current-epoch log carries 'cloud-dive'; after the
        // seed (which resets the DB) the local library holds only
        // 'local-only-dive'. Adoption must converge to the cloud library.
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'cloud-dive', maxDepth: 20),
        );
        await seedPeerLog(cloud, 'replacer', epochId: 'e1');
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'local-only-dive', maxDepth: 30),
        );

        final service = buildService();
        await service.writeLibraryEpochMarker(cloud, marker);

        final result = await service.adoptReplacedLibrary();

        expect(result.isSuccess, isTrue);
        expect(await SyncRepository().getLastAcceptedEpochId(), 'e1');
        expect(epochStore.lastAcceptedEpochId, 'e1');
        // Local-only row is gone; cloud row is present.
        expect(
          await serializer.fetchRecord('dives', 'local-only-dive'),
          isNull,
        );
        expect(await serializer.fetchRecord('dives', 'cloud-dive'), isNotNull);
      },
    );

    test(
      'adoption records peer cursors so the next sync does not re-pull the base',
      () async {
        // seedPeerLog publishes 'replacer' as a base at seq 1 (no changesets).
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'cloud-dive'),
        );
        await seedPeerLog(cloud, 'replacer', epochId: 'e1');
        final service = buildService();
        await service.writeLibraryEpochMarker(cloud, marker);

        await service.adoptReplacedLibrary();

        // resetSyncState wipes cursors; without recording what adopt applied,
        // the next sync cold-starts and re-downloads the whole adopted base.
        final cursor = await PeerCursorStore(
          DatabaseService.instance.database,
        ).get('replacer', cloud.providerId);
        expect(
          cursor,
          isNotNull,
          reason: 'adopt must record the replacer cursor',
        );
        expect(cursor!.lastSeqApplied, 1);
        expect(cursor.baseSeqApplied, 1);
      },
    );

    test('the sync after adoption does not re-apply the adopted base', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'cloud-dive'),
      );
      await seedPeerLog(cloud, 'replacer', epochId: 'e1');
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await service.adoptReplacedLibrary();

      // The cursor adopt recorded makes the follow-up pull skip 'replacer', so
      // nothing is re-applied. Without the fix this cold-started and re-pulled
      // the entire adopted base.
      final result = await service.performSync();
      expect(result.isSuccess, isTrue);
      expect(
        result.recordsSynced,
        0,
        reason: 'the base just adopted must not be re-pulled',
      );
    });

    test(
      'after adoption with no local changes, performSync defers the self-base '
      'publish',
      () async {
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'cloud-dive'),
        );
        await seedPeerLog(cloud, 'replacer', epochId: 'e1');
        final service = buildService();
        await service.writeLibraryEpochMarker(cloud, marker);
        await service.adoptReplacedLibrary();

        final result = await service.performSync();

        // The sync itself succeeds (guards against a vacuous pass from an early
        // error): our library == the adopted epoch (already published by
        // 'replacer') and we have no local changes, so re-uploading our own
        // full base would be pure redundancy -- the publish is deferred (no own
        // manifest is written).
        expect(result.isSuccess, isTrue);
        final deviceId = await SyncRepository().getDeviceId();
        expect(await hasPublishedLog(cloud, deviceId), isFalse);
      },
    );

    test('after adoption, a local change publishes a changeset against the '
        'adopted watermark -- NOT a redundant full base', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'cloud-dive'),
      );
      await seedPeerLog(cloud, 'replacer', epochId: 'e1');
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await service.adoptReplacedLibrary();

      // A local edit means we now have something of our own to contribute.
      // Publishing it as a full base would re-upload the whole adopted
      // library and force every peer to re-download it -- the post-#450
      // "changes don't show up until the base lands" unreliability. The
      // edit must go out as a small changeset instead.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'my-dive', maxDepth: 42),
      );
      await service.performSync();

      final deviceId = await SyncRepository().getDeviceId();
      expect(await hasPublishedLog(cloud, deviceId), isTrue);
      final manifest = await ownManifest(cloud, deviceId);
      expect(
        manifest!.baseSeq,
        isNull,
        reason:
            'the adopted library is already published by the peers; '
            'only the delta may be uploaded',
      );
      expect(manifest.headSeq, 1);
      expect(manifest.epochId, 'e1');

      final files = await cloud.listFiles(
        namePattern: ChangesetLogLayout.prefix,
      );
      expect(
        files.any(
          (f) =>
              ChangesetLogLayout.deviceIdOf(f.name) == deviceId &&
              ChangesetLogLayout.basePartOf(f.name) != null,
        ),
        isFalse,
        reason: 'no base part may be uploaded on the first post-adopt edit',
      );

      final csFile = files
          .where((f) => f.name == ChangesetLogLayout.changesetName(deviceId, 1))
          .single;
      final payload = ChangesetCodec(
        SyncDataSerializer(),
      ).decodeChangeset(await cloud.downloadFile(csFile.id));
      final diveIds = payload.data.dives.map((d) => d['id']).toSet();
      expect(diveIds.contains('my-dive'), isTrue);
      expect(
        diveIds.contains('cloud-dive'),
        isFalse,
        reason: 'adopted rows sit at or below the watermark',
      );
    });

    test('a deferred sync must not clear pending records that appeared after '
        'the deferral check (the lost-edit race)', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'cloud-dive'),
      );
      await seedPeerLog(cloud, 'replacer', epochId: 'e1');
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await service.adoptReplacedLibrary();

      // Emulate an edit landing between the deferral check and the
      // end-of-sync cleanup: the gate cannot see the pending row (the
      // blind repository reports zero), but the row is real in the DB.
      await SyncRepository().markRecordPending(
        entityType: 'dives',
        recordId: 'raced-dive',
        localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      final racedService = SyncService(
        syncRepository: _GateBlindSyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: cloud,
        epochStore: epochStore,
      );
      final result = await racedService.performSync();

      expect(result.isSuccess, isTrue);
      final deviceId = await SyncRepository().getDeviceId();
      expect(
        await hasPublishedLog(cloud, deviceId),
        isFalse,
        reason: 'the gate saw no changes, so the publish deferred',
      );
      expect(
        await SyncRepository().getPendingCount(),
        1,
        reason:
            'a sync that published nothing must not clear pending '
            'records -- wiping them makes the next sync defer again and '
            'the edit never publishes',
      );
    });

    test('adoption preserves device identity', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'cloud-dive'),
      );
      await seedPeerLog(cloud, 'replacer', epochId: 'e1');
      final repo = SyncRepository();
      final before = await repo.getDeviceId();
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await service.adoptReplacedLibrary();
      expect(await repo.getDeviceId(), before);
    });

    test('adoption is idempotent', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'cloud-dive'),
      );
      await seedPeerLog(cloud, 'replacer', epochId: 'e1');
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      final first = await service.adoptReplacedLibrary();
      final second = await service.adoptReplacedLibrary();
      expect(first.isSuccess, isTrue);
      expect(second.isSuccess, isTrue);
    });

    test('adopt surfaces an error when sync files cannot be listed', () async {
      // Fail the changeset-log listing that adoption depends on.
      final listFail = _SyncListFailCloud(ChangesetLogLayout.prefix);
      final service = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: listFail,
        epochStore: epochStore,
      );
      await service.writeLibraryEpochMarker(listFail, marker);

      final result = await service.adoptReplacedLibrary();

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Failed to adopt'));
      expect(await SyncRepository().getLastAcceptedEpochId(), isNull);
    });
  });

  group('failure tolerance', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1,
      deviceId: 'd1',
    );

    test('a failed marker self-heal does not block the sync attempt', () async {
      await SyncRepository().setLastAcceptedEpochId('e1');
      await epochStore.setLastAccepted(marker);
      cloud.failUploads = true; // self-heal rewrite (and any upload) fails

      final result = await buildService().performSync();

      // The gate proceeded as current-epoch; only the upload itself failed.
      expect(result.status, isNot(SyncResultStatus.awaitingAdoption));
    });

    test('a stale-epoch peer is tolerated and left inert', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      await SyncRepository().setLastAcceptedEpochId('e1');
      await epochStore.setLastAccepted(marker);
      await seedPeerFile(peerDeviceId: 'stale-peer'); // unstamped = stale

      final result = await service.performSync();

      expect(result.isSuccess, isTrue);
      // The reader skips a stale-epoch peer without deleting it; it simply
      // stays in the cloud, inert to every current-epoch device.
      expect(await hasPublishedLog(cloud, 'stale-peer'), isTrue);
    });

    test(
      'replace tolerates per-file delete failures during the wipe',
      () async {
        await seedPeerFile(peerDeviceId: 'peer-1');
        cloud.failDeletes = true;

        final result = await buildService().executeLibraryReplace(marker);

        expect(result.isSuccess, isTrue);
        expect(await SyncRepository().getLastAcceptedEpochId(), 'e1');
      },
    );

    test('replace tolerates a listing failure during the wipe', () async {
      // Fail only the LEGACY wipe listing; the changeset listing the publish
      // needs still works, so the replace completes.
      final listFail = _SyncListFailCloud(
        CloudStorageProviderMixin.syncFileStem,
      );
      final service = SyncService(
        syncRepository: SyncRepository(),
        serializer: SyncDataSerializer(),
        cloudProvider: listFail,
        epochStore: epochStore,
      );

      final result = await service.executeLibraryReplace(marker);

      expect(result.isSuccess, isTrue);
      expect(epochStore.lastAcceptedEpochId, 'e1');
    });

    test(
      'replace records the upload nonce when an initializer is wired',
      () async {
        final service = SyncService(
          syncRepository: SyncRepository(),
          serializer: SyncDataSerializer(),
          cloudProvider: cloud,
          syncInitializer: SyncInitializer(
            syncRepository: SyncRepository(),
            prefs: await SharedPreferences.getInstance(),
          ),
          epochStore: epochStore,
        );

        final result = await service.executeLibraryReplace(marker);

        expect(result.isSuccess, isTrue);
      },
    );
  });

  // The library epoch is committed per-device (lastAcceptedEpochId), but the
  // marker lives per-backend. These tests pin how a device that accepted an
  // epoch on one backend behaves when it first syncs against a DIFFERENT one
  // -- the interaction between backend switching (concern) and the epoch
  // protocol.
  group('epoch across a backend switch', () {
    const marker = LibraryEpochMarker(
      epochId: 'e1',
      replacedAt: 1,
      deviceId: 'replacer',
    );

    SyncService serviceFor(FakeCloudStorageProvider provider) => SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: provider,
      epochStore: epochStore,
    );

    test('a device carrying an accepted epoch self-heals the marker onto a '
        'fresh new backend and stamps its upload', () async {
      // The device accepted e1 (on the old backend) and switched to a new,
      // empty backend that carries no marker yet.
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'carried-dive'),
      );
      await SyncRepository().setLastAcceptedEpochId('e1');
      await epochStore.setLastAccepted(marker);
      final newBackend = FakeCloudStorageProvider(
        providerId: 'icloud',
        providerName: 'iCloud',
      );

      final result = await serviceFor(newBackend).performSync();

      expect(result.isSuccess, isTrue);
      expect(
        (await serviceFor(
          newBackend,
        ).readLibraryEpochMarker(newBackend))?.epochId,
        'e1',
        reason: 'the accepted epoch must be re-stamped onto the new backend',
      );
      final deviceId = await SyncRepository().getDeviceId();
      expect(
        (await cloudBasePayload(newBackend, deviceId))?.epochId,
        'e1',
        reason: 'our base published to the new backend is epoch-stamped',
      );
    });

    test('a conflicting epoch already on the new backend halts for adoption '
        'rather than merging across generations', () async {
      // The device accepted e1 on the old backend; the new backend was
      // independently replaced under e2 by some other device.
      await SyncRepository().setLastAcceptedEpochId('e1');
      await epochStore.setLastAccepted(marker);
      final newBackend = FakeCloudStorageProvider(
        providerId: 'icloud',
        providerName: 'iCloud',
      );
      await serviceFor(newBackend).writeLibraryEpochMarker(
        newBackend,
        const LibraryEpochMarker(
          epochId: 'e2',
          replacedAt: 2,
          deviceId: 'other',
        ),
      );
      // The other device actually published an e2 library, so this is a
      // genuine adoptable conflict (not an orphaned marker).
      await seedPeerManifest(newBackend, 'other-device', epochId: 'e2');
      newBackend.operationLog.clear();

      final result = await serviceFor(newBackend).performSync();

      expect(result.status, SyncResultStatus.awaitingAdoption);
      expect(result.replaceMarker?.epochId, 'e2');
      expect(
        newBackend.operationLog.where((op) => op.startsWith('upload:')),
        isEmpty,
        reason: 'no file may be uploaded into a not-yet-adopted epoch',
      );
    });
  });

  // Switching to a backend whose marked library cannot be read (an older
  // pre-changeset app's full-file data, or a replace whose base never landed)
  // must NOT brick sync in an un-adoptable awaiting-adoption loop. The device
  // re-establishes the backend from its own library instead.
  group('unreadable / orphaned epoch recovery', () {
    test('a backend whose marked library is old-format (no ssv1) is '
        're-established from the local library, not bricked', () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'mine-1'),
      );
      final service = buildService();
      await service.writeLibraryEpochMarker(
        cloud,
        const LibraryEpochMarker(
          epochId: 'stale',
          replacedAt: 1,
          deviceId: 'old',
        ),
      );
      // Only OLD full-file data on the backend (a pre-changeset app version).
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode('{"version":1}')),
        '${CloudStorageProviderMixin.syncFilePrefix}old-device'
        '${CloudStorageProviderMixin.syncFileExtension}',
      );

      final result = await service.performSync();

      expect(
        result.status,
        isNot(SyncResultStatus.awaitingAdoption),
        reason: 'an unreadable marked library must not brick sync',
      );
      expect(result.isSuccess, isTrue);
      expect(await SyncRepository().getLastAcceptedEpochId(), 'stale');
      final deviceId = await SyncRepository().getDeviceId();
      final base = await cloudBasePayload(cloud, deviceId);
      expect(base?.epochId, 'stale');
      expect(base?.data.dives.map((d) => d['id']), contains('mine-1'));
      // The old full-file data was discarded.
      expect(
        await cloud.listFiles(
          namePattern: CloudStorageProviderMixin.syncFileStem,
        ),
        isEmpty,
      );
    });

    test(
      'an ancient orphaned marker with no library is re-established',
      () async {
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'mine-1'),
        );
        final service = buildService();
        // Marker written long ago, no ssv1 base ever landed (the replacer died
        // mid-replace): orphaned, must recover rather than brick forever.
        await service.writeLibraryEpochMarker(
          cloud,
          const LibraryEpochMarker(
            epochId: 'orphan',
            replacedAt: 1,
            deviceId: 'dead',
          ),
        );

        final result = await service.performSync();

        expect(result.isSuccess, isTrue);
        expect(await SyncRepository().getLastAcceptedEpochId(), 'orphan');
      },
    );

    test(
      'a fresh marker with no library yet still halts (replace in flight)',
      () async {
        await DiveRepository().createDive(
          createTestDiveWithBottomTime(id: 'mine-1'),
        );
        final service = buildService();
        // Marker written just now, base upload still in progress: must wait for
        // adoption, not clobber the in-flight replace.
        await service.writeLibraryEpochMarker(
          cloud,
          LibraryEpochMarker(
            epochId: 'inflight',
            replacedAt: DateTime.now().millisecondsSinceEpoch,
            deviceId: 'replacer',
          ),
        );

        final result = await service.performSync();

        expect(result.status, SyncResultStatus.awaitingAdoption);
      },
    );
  });
}

/// Reports zero pending records to the publish-deferral gate while the real
/// rows stay in the DB -- emulating an edit that lands AFTER the gate check
/// but before the end-of-sync cleanup (the lost-edit race window).
class _GateBlindSyncRepository extends SyncRepository {
  @override
  Future<int> getPendingCount() async => 0;
}

/// Fails only the listing for [failPattern], leaving other listings (and
/// marker IO) working, to exercise the wipe/adopt listing-failure branches.
class _SyncListFailCloud extends FakeCloudStorageProvider {
  _SyncListFailCloud(this.failPattern);

  final String failPattern;

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) {
    if (namePattern == failPattern) {
      throw const CloudStorageException('list failed (test)');
    }
    return super.listFiles(folderId: folderId, namePattern: namePattern);
  }
}
