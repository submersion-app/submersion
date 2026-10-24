import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/settings/domain/data_health/media_health.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/sync/sync_failure_store.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/sync_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('backupHealthProvider', () {
    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isSyncEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('backup health follows backupSettings', () async {
      final backup = BackupPreferences(prefs);
      await backup.setEnabled(true);
      await backup.setCloudBackupEnabled(true);
      await backup.setLastBackupTime(
        DateTime.now().subtract(const Duration(hours: 2)),
      );

      expect(container().read(backupHealthProvider).level, HealthLevel.healthy);

      await backup.setLastScheduledFailure(DateTime.now(), 'disk full');
      final h = container().read(backupHealthProvider);
      expect(
        (h.level, h.reason),
        (HealthLevel.failing, HealthReason.backupFailed),
      );
    });
  });

  group('syncHealthProvider', () {
    late FakeCloudStorageProvider cloud;

    setUp(() async {
      await setUpTestDatabase();
      cloud = FakeCloudStorageProvider();
      // Off by default, which the model rightly flags; these tests are about
      // the failure record.
      await SyncPreferences(prefs).setAutoSyncEnabled(true);
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    Future<ProviderContainer> container() async {
      final c = ProviderContainer(
        overrides: [
          localeProvider.overrideWithValue('en'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(cloud),
          selectedCloudProviderTypeProvider.overrideWith(
            (ref) => CloudProviderType.dropbox,
          ),
          isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      c.read(syncStateProvider);
      await c.read(syncStateProvider.notifier).refreshState();
      return c;
    }

    Future<void> storeFailure(String providerId) =>
        SyncFailureStore(prefs).record(
          SyncFailureRecord(
            providerId: providerId,
            at: DateTime.now(),
            kind: SyncFailureKind.other,
            message: 'boom',
          ),
        );

    test('sync health uses the active provider id', () async {
      await storeFailure(cloud.providerId);

      final h = (await container()).read(syncHealthProvider);

      expect(
        (h.level, h.reason),
        (HealthLevel.failing, HealthReason.syncFailed),
      );
    });

    test('a failure stored for another provider is ignored', () async {
      await storeFailure('some-other-backend');

      final h = (await container()).read(syncHealthProvider);

      expect(h.reason, HealthReason.syncNeverSynced);
    });
  });

  group('sharedLibrariesHealthProvider', () {
    const membership = SharedLibraryMembership(
      id: 'm',
      diverId: 'diver',
      libraryId: 'lib-1',
      memberId: 'member-1',
      displayName: 'Me',
      libraryName: 'Club Sites',
      backendKind: 'webdav',
    );

    SharedLibrary library(SharedLibraryRoles roles) => SharedLibrary(
      id: 'lib-1',
      name: 'Club Sites',
      connectedAccountId: 'acct',
      prefix: 'p',
      readOnlyDetected: true,
      roles: roles,
    );

    Future<FeatureHealth> healthFor(SharedLibraryRoles roles) async {
      final c = ProviderContainer(
        overrides: [
          sharedLibrariesProvider.overrideWith(
            (ref) => Stream.value([library(roles)]),
          ),
          currentMembershipProvider.overrideWith(
            (ref, libraryId) async => membership,
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(sharedLibrariesHealthProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(libraryHealthInputsProvider.future);
      return c.read(sharedLibrariesHealthProvider);
    }

    test('library health resolves the member role: editor is held', () async {
      final h = await healthFor(
        const SharedLibraryRoles(editors: {'member-1'}),
      );
      expect(h.reason, HealthReason.librariesEditsHeld);
    });

    test(
      'library health resolves the member role: reader is healthy',
      () async {
        final h = await healthFor(const SharedLibraryRoles());
        expect(h.level, HealthLevel.healthy);
      },
    );
  });

  group('countMediaSetupItems', () {
    PendingSetupItem item(SetupItemKind kind) =>
        PendingSetupItem(kind: kind, key: kind.name, label: 'x', route: '/x');
    PendingSetupItem signIn(
      Set<AccountUsageKind> usages, {
      String route = '/x',
      bool dismissed = false,
    }) => PendingSetupItem(
      kind: SetupItemKind.accountSignIn,
      key: 'account_${usages.map((u) => u.name).join()}',
      label: 'x',
      route: route,
      usages: usages,
      dismissed: dismissed,
    );

    test('media health counts only media setup items', () {
      expect(
        countMediaSetupItems([
          item(SetupItemKind.mediaStoreAttach),
          item(SetupItemKind.mediaStoreReconnect),
          signIn({AccountUsageKind.mediaStorage}),
          signIn({AccountUsageKind.lightroom}),
          signIn({AccountUsageKind.databaseSync}),
        ]),
        4,
      );
    });

    // Issue #3482 review: one account can drive sync and the photo copies;
    // its sign-in routes to the Sync page, yet the photo uploads stop too.
    test('a sign-in for an account sync and the photo copies share counts '
        'against photos', () {
      expect(
        countMediaSetupItems([
          signIn({
            AccountUsageKind.databaseSync,
            AccountUsageKind.mediaStorage,
          }, route: '/settings/cloud-sync'),
        ]),
        1,
      );
    });

    test('a dismissed sign-in does not count against photos', () {
      expect(
        countMediaSetupItems([
          signIn({AccountUsageKind.mediaStorage}, dismissed: true),
        ]),
        0,
      );
    });
  });

  group('mediaHealthInputsProvider', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test(
      'never builds the media runtime, even with a store attached',
      () async {
        await MediaStoreAttachState(
          prefs: prefs,
        ).setAttached('store-1', providerType: CloudProviderType.s3);
        var runtimeAsked = false;
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaStoreAttachStateProvider.overrideWithValue(
              MediaStoreAttachState(prefs: prefs),
            ),
            pendingSetupItemsProvider.overrideWith((ref) async => const []),
            lightroomDeviceStatusProvider.overrideWith(
              (ref) async => LightroomDeviceStatus.notConnected,
            ),
            mediaTransferSummaryProvider.overrideWith(
              (ref) => Stream.value(
                const MediaTransferSummary(
                  waiting: 1,
                  waitingReason: 'offline',
                ),
              ),
            ),
            // Building this awaits mediaStoreRuntimeProvider: a keychain read,
            // a store build and a queue drain. Settings > Data must not.
            mediaTransfersSuspendedProvider.overrideWith((ref) {
              runtimeAsked = true;
              return Stream.value(false);
            }),
          ],
        );
        addTearDown(c.dispose);
        final sub = c.listen(mediaHealthInputsProvider, (_, _) {});
        addTearDown(sub.close);
        await c.read(mediaTransferSummaryProvider.future);

        final inputs = await c.read(mediaHealthInputsProvider.future);

        expect(runtimeAsked, isFalse);
        expect(inputs.storeAttachedHere, isTrue);
        expect(inputs.transfersWaitingWithReason, isTrue);
      },
    );
  });

  group('media Lightroom input', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    Future<MediaHealthInputs> inputsFor(LightroomDeviceStatus status) async {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaStoreAttachStateProvider.overrideWithValue(
            MediaStoreAttachState(prefs: prefs),
          ),
          pendingSetupItemsProvider.overrideWith((ref) async => const []),
          lightroomDeviceStatusProvider.overrideWith((ref) async => status),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(mediaHealthInputsProvider, (_, _) {});
      addTearDown(sub.close);
      return c.read(mediaHealthInputsProvider.future);
    }

    test('only a Lightroom signed in on this device counts', () async {
      expect(
        (await inputsFor(LightroomDeviceStatus.connected)).lightroomConnected,
        isTrue,
      );
      expect(
        (await inputsFor(LightroomDeviceStatus.needsSignIn)).lightroomConnected,
        isFalse,
      );
    });
  });

  test('dataHealthProvider orders the four features', () {
    FeatureHealth h(DataFeature f) => FeatureHealth(
      feature: f,
      level: HealthLevel.healthy,
      reason: HealthReason.ok,
    );
    final c = ProviderContainer(
      overrides: [
        backupHealthProvider.overrideWithValue(h(DataFeature.backup)),
        syncHealthProvider.overrideWithValue(h(DataFeature.sync)),
        sharedLibrariesHealthProvider.overrideWithValue(
          h(DataFeature.sharedLibraries),
        ),
        mediaHealthProvider.overrideWithValue(h(DataFeature.media)),
      ],
    );
    addTearDown(c.dispose);

    expect(c.read(dataHealthProvider).map((e) => e.feature), [
      DataFeature.backup,
      DataFeature.sync,
      DataFeature.sharedLibraries,
      DataFeature.media,
    ]);
  });
}
