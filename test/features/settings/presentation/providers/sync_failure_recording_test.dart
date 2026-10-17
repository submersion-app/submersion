import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_failure_store.dart';
import 'package:submersion/features/settings/domain/data_health/sync_health.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

/// The real SyncNotifier persists the outcome of each sync attempt for
/// Settings > Data health (issues #3390, #3394), so a failure is still shown
/// after a restart and a later success clears it.
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

  test('a sign-in failure is recorded as other', () async {
    cloud.authenticated = false;
    final container = await makeContainer();

    await container.read(syncStateProvider.notifier).performSync();

    expect(SyncFailureStore(prefs).last?.kind, SyncFailureKind.other);
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
