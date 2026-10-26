import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/deferred_write_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// A provider that, like Git, defers deletes and keeps history.
class _HistoryKeepingCloud extends FakeCloudStorageProvider
    implements DeferredWriteProvider, HistoryResettable {
  final calls = <String>[];
  final flushTimeouts = <Duration?>[];
  bool failFlush = false;
  bool failSyncFolder = false;

  @override
  Future<void> flush({Duration? timeout}) async {
    calls.add('flush');
    flushTimeouts.add(timeout);
    if (failFlush) throw StateError('flush failed');
  }

  @override
  Future<void> resetHistoryNow() async => calls.add('reset');

  @override
  Future<String> getOrCreateSyncFolder() async {
    if (failSyncFolder) throw StateError('backend went away');
    return super.getOrCreateSyncFolder();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _HistoryKeepingCloud cloud;
  late SyncRepository repository;
  late SyncInitializer initializer;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    cloud = _HistoryKeepingCloud();
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

  test('a sync run flushes deferred writes once, even when it fails', () async {
    cloud.failSyncFolder = true;
    try {
      await buildService().performSync();
    } on Object {
      // Failing is the point; what matters is the flush below.
    }
    expect(cloud.calls.where((c) => c == 'flush'), hasLength(1));
  });

  test('cleaning up an old backend pushes its deletes, then resets', () async {
    final folder = await cloud.getOrCreateSyncFolder();
    await cloud.uploadFile(
      Uint8List.fromList([1]),
      'ssv1.dev-1.cs.000000000001.json',
      folderId: folder,
    );
    await buildService().cleanupOldBackend(cloud);
    expect(cloud.calls, ['flush', 'reset']);
  });

  test('a full sync wipe resets history', () async {
    await buildService().wipeAllSyncData(cloud);
    expect(cloud.calls, contains('reset'));
  });

  test('a delete sweep whose flush fails is reported incomplete', () async {
    final folder = await cloud.getOrCreateSyncFolder();
    for (var i = 1; i <= 2; i++) {
      await cloud.uploadFile(
        Uint8List.fromList([i]),
        'ssv1.dev-1.cs.00000000000$i.json',
        folderId: folder,
      );
    }
    cloud.failFlush = true;
    final outcome = await buildService().deleteDeviceSyncFile('dev-1');
    expect(outcome.isComplete, isFalse);
    expect(outcome.failed, 2);
    expect(outcome.deleted, 0);
  });

  test('a delete sweep times only its own push, not the wait for it', () async {
    final folder = await cloud.getOrCreateSyncFolder();
    await cloud.uploadFile(
      Uint8List.fromList([1]),
      'ssv1.dev-1.cs.000000000001.json',
      folderId: folder,
    );
    await buildService().deleteDeviceSyncFile('dev-1');
    // Handed to the provider, which starts the clock once its push starts.
    expect(cloud.flushTimeouts, [const Duration(seconds: 20)]);
  });
}
