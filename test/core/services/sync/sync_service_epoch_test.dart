import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Coverage for the library epoch protocol on SyncService (restore Replace
/// mode): marker IO, the performSync gate, replace execution, and adoption.
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

    test('marker file is invisible to sync-file discovery', () async {
      final service = buildService();
      await service.writeLibraryEpochMarker(cloud, marker);
      final files = await cloud.listFiles(
        namePattern: CloudStorageProviderMixin.syncFileStem,
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
}
