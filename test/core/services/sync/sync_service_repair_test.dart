import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// Issue #509: the comprehensive local Repair. resetSyncState already clears
/// the DB-side sync state; Repair adds the one thing it misses -- the
/// SharedPreferences epoch markers -- plus a sweep of leftover base temp files.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LibraryEpochStore epochStore;
  late FakeCloudStorageProvider cloud;
  late Directory fakeAppTemp;

  setUpAll(() async {
    fakeAppTemp = await Directory.systemTemp.createTemp('repair_app_temp_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async =>
              call.method == 'getTemporaryDirectory' ? fakeAppTemp.path : null,
        );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (fakeAppTemp.existsSync()) await fakeAppTemp.delete(recursive: true);
  });

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

  test(
    'repairLocalSyncState clears the epoch store and leftover base temp files',
    () async {
      const marker = LibraryEpochMarker(
        epochId: 'e1',
        replacedAt: 1,
        deviceId: 'd1',
      );
      await epochStore.setLastAccepted(marker);
      await epochStore.setPendingReplace(marker);
      final leftover = File('${fakeAppTemp.path}/ssv1_base_dev_0.abc.json');
      await leftover.writeAsString('stale');
      // An unrelated temp file (the dir is shared) must be left untouched.
      final unrelated = File('${fakeAppTemp.path}/user_photo.jpg');
      await unrelated.writeAsString('keep');

      await buildService().repairLocalSyncState();

      expect(epochStore.lastAcceptedMarker, isNull);
      expect(epochStore.pendingReplace, isNull);
      expect(leftover.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
    },
  );

  test(
    'rebuildBackendFromThisDevice re-establishes the epoch from local library',
    () async {
      final service = buildService();
      const marker = LibraryEpochMarker(
        epochId: 'e-stuck',
        replacedAt: 1,
        deviceId: 'offline-device',
      );
      // The offline device published the epoch marker but no base; a stale peer
      // log lingers in the folder.
      await service.writeLibraryEpochMarker(cloud, marker);
      cloud.seedFile(
        'ssv1.offline-device.manifest.json',
        Uint8List.fromList('m'.codeUnits),
      );

      final result = await service.rebuildBackendFromThisDevice();

      expect(result.status, SyncResultStatus.success);
      // The stuck sync files are wiped so this device can republish...
      expect(cloud.bytesOf('ssv1.offline-device.manifest.json'), isNull);
      // ...and this device now accepts the epoch (its next sync publishes base).
      expect(epochStore.lastAcceptedMarker?.epochId, 'e-stuck');
    },
  );

  test('rebuildBackendFromThisDevice errors when no marker exists', () async {
    final result = await buildService().rebuildBackendFromThisDevice();
    expect(result.status, SyncResultStatus.error);
  });
}
