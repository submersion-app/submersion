import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/library_moved.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Coverage for the "library moved" marker IO and old-backend cleanup that
/// back the backend-switch concerns (invisible split-brain + orphaned data).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  const marker = LibraryMovedMarker(
    movedAt: 5,
    toProviderId: 'icloud',
    toProviderName: 'iCloud',
    deviceId: 'device-A',
  );

  group('moved marker IO', () {
    test('read returns null when no marker exists', () async {
      expect(await buildService().readLibraryMovedMarker(cloud), isNull);
    });

    test('write then read round-trips the destination', () async {
      final service = buildService();
      await service.writeLibraryMovedMarker(cloud, marker);
      final read = await service.readLibraryMovedMarker(cloud);
      expect(read?.toProviderId, 'icloud');
      expect(read?.deviceId, 'device-A');
    });

    test('marker file is invisible to sync-file discovery', () async {
      final service = buildService();
      await service.writeLibraryMovedMarker(cloud, marker);
      final files = await cloud.listFiles(
        namePattern: CloudStorageProviderMixin.syncFileStem,
      );
      expect(
        files.where((f) => f.name == libraryMovedFileName),
        isEmpty,
        reason:
            'the moved marker must not be mistaken for a peer sync file or it '
            'would be parsed as a payload and merged',
      );
    });

    test(
      'read is fail-open: a download error yields null, not an exception',
      () async {
        // Advisory marker -> an unreadable one must never fail a sync closed.
        cloud.seedFile(libraryMovedFileName, Uint8List.fromList([1, 2, 3]));
        cloud.failDownloads = true;
        expect(await buildService().readLibraryMovedMarker(cloud), isNull);
      },
    );

    test('read returns null on a corrupt (non-JSON) marker', () async {
      cloud.seedFile(
        libraryMovedFileName,
        Uint8List.fromList(utf8.encode('not json at all')),
      );
      expect(await buildService().readLibraryMovedMarker(cloud), isNull);
    });

    test('write is best-effort: an upload failure does not throw', () async {
      cloud.failUploads = true;
      await expectLater(
        buildService().writeLibraryMovedMarker(cloud, marker),
        completes,
      );
    });
  });

  group('cleanupOldBackend', () {
    test('deletes sync payload files but keeps the moved marker', () async {
      final service = buildService();
      // The old backend after a switch: orphaned device files plus the moved
      // marker the switching device left for stragglers.
      final serializer = SyncDataSerializer();
      final payload = await serializer.exportData(
        deviceId: 'device-A',
        lastSyncTimestamp: null,
        deletions: const [],
        uploadNonce: null,
      );
      await cloud.uploadFile(
        Uint8List.fromList(utf8.encode(serializer.serializePayload(payload))),
        '${CloudStorageProviderMixin.syncFilePrefix}device-A'
        '${CloudStorageProviderMixin.syncFileExtension}',
      );
      await service.writeLibraryMovedMarker(cloud, marker);

      await service.cleanupOldBackend(cloud);

      expect(
        await cloud.fileExists(
          '${CloudStorageProviderMixin.syncFilePrefix}device-A'
          '${CloudStorageProviderMixin.syncFileExtension}',
        ),
        isFalse,
        reason: 'the orphaned dive library is what cleanup exists to remove',
      );
      expect(
        await service.readLibraryMovedMarker(cloud),
        isNotNull,
        reason:
            'the moved marker is tiny, carries no dive data, and still serves '
            'any straggler that has not yet seen it -- keep it',
      );
    });

    test('is best-effort: a delete failure does not throw', () async {
      final service = buildService();
      await cloud.uploadFile(
        Uint8List.fromList([1, 2, 3]),
        '${CloudStorageProviderMixin.syncFilePrefix}device-A'
        '${CloudStorageProviderMixin.syncFileExtension}',
      );
      cloud.failDeletes = true;
      await expectLater(service.cleanupOldBackend(cloud), completes);
    });
  });
}
