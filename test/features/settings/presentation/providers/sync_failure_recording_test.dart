import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_failure_store.dart';
import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/domain/data_health/sync_health.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// The real SyncNotifier persists the outcome of each sync attempt for
/// Settings > Data health (issues #3390, #3394), so a failure is still shown
/// after a restart and a later success clears it.
class _RefusedSyncService extends Fake implements SyncService {
  @override
  void setProgressCallback(SyncProgressCallback? callback) {}

  @override
  Future<bool> isSyncAvailable() async => true;

  @override
  Future<SyncResult> performSync() async =>
      throw const CloudAccessRefusedException('refused');

  static const _refused = SyncResult(
    status: SyncResultStatus.authError,
    message: 'refused',
    accessRefused: true,
  );

  @override
  Future<SyncResult> adoptReplacedLibrary() async => _refused;

  @override
  Future<SyncResult> rebuildBackendFromThisDevice({
    SyncCleanupProgress? onProgress,
  }) async => _refused;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWithValue('en'),
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
      ],
    );
    addTearDown(container.dispose);
    container.read(syncStateProvider);
    await container.read(syncStateProvider.notifier).refreshState();
    return container;
  }

  test('a network failure is recorded for the active provider', () async {
    cloud.failLists = true;
    final container = await makeContainer();

    await container.read(syncStateProvider.notifier).performSync();

    final failure = SyncFailureStore(prefs).last;
    expect(failure, isNotNull);
    expect(failure!.kind, SyncFailureKind.network);
    expect(failure.providerId, cloud.providerId);
    expect(container.read(syncFailureProvider)?.kind, SyncFailureKind.network);
  });

  // An offline cold launch reads as signed out too, and that must not outlive
  // the outage: being signed out is read live from isAuthenticated, and only a
  // server's refusal is stored as a sign-in failure.
  test('no session here is not stored as a sign-in failure', () async {
    cloud.authenticated = false;
    final container = await makeContainer();

    await container.read(syncStateProvider.notifier).performSync();

    expect(SyncFailureStore(prefs).last?.kind, SyncFailureKind.network);
  });

  test('a refused cloud call is recorded as a sign-in failure', () async {
    cloud
      ..failLists = true
      ..readException = const CloudAccessRefusedException('refused');
    final container = await makeContainer();

    await container.read(syncStateProvider.notifier).performSync();

    expect(SyncFailureStore(prefs).last?.kind, SyncFailureKind.auth);
    expect(SyncFailureStore(prefs).last?.message, 'refused');
  });

  ProviderContainer refusedContainer() {
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWithValue('en'),
        sharedPreferencesProvider.overrideWithValue(prefs),
        cloudStorageProviderProvider.overrideWithValue(cloud),
        syncServiceProvider.overrideWithValue(_RefusedSyncService()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'a refusal thrown out of the sync service is a sign-in failure',
    () async {
      await refusedContainer().read(syncStateProvider.notifier).performSync();

      expect(SyncFailureStore(prefs).last?.kind, SyncFailureKind.auth);
    },
  );

  test('a refused adopt is recorded as a sign-in failure', () async {
    await refusedContainer()
        .read(syncStateProvider.notifier)
        .adoptReplacedLibrary();

    expect(SyncFailureStore(prefs).last?.kind, SyncFailureKind.auth);
  });

  test('a refused rebuild is recorded as a sign-in failure', () async {
    await refusedContainer()
        .read(syncStateProvider.notifier)
        .rebuildBackendFromThisDevice();

    expect(SyncFailureStore(prefs).last?.kind, SyncFailureKind.auth);
  });

  test('success clears a stored failure', () async {
    await SyncFailureStore(prefs).record(
      SyncFailureRecord(
        providerId: cloud.providerId,
        at: DateTime(2026, 10, 1),
        kind: SyncFailureKind.other,
        message: 'earlier',
      ),
    );
    final container = await makeContainer();
    expect(container.read(syncFailureProvider), isNotNull);

    await container.read(syncStateProvider.notifier).performSync();

    expect(SyncFailureStore(prefs).last, isNull);
    expect(container.read(syncFailureProvider), isNull);
  });

  test('success on one backend keeps a failure stored for another', () async {
    await SyncFailureStore(prefs).record(
      SyncFailureRecord(
        providerId: 'a-backend-switched-away-from',
        at: DateTime(2026, 10, 1),
        kind: SyncFailureKind.other,
        message: 'earlier',
      ),
    );
    final container = await makeContainer();

    await container.read(syncStateProvider.notifier).performSync();

    expect(
      SyncFailureStore(prefs).last?.providerId,
      'a-backend-switched-away-from',
    );
  });
}
