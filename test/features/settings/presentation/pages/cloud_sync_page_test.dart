import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType, SyncRepository;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_moved.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/core/services/sync/sync_service.dart'
    show ConflictResolution, SyncService;
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/pages/cloud_sync_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show sharedPreferencesProvider;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_providers.dart';

/// In-memory [S3CredentialsStore] for testing -- no FlutterSecureStorage.
class _MemoryCredentialsStore implements S3CredentialsStore {
  S3Config? stored;

  @override
  Future<S3Config?> load() async => stored;

  @override
  Future<void> save(S3Config config) async => stored = config;

  @override
  Future<void> clear() async => stored = null;
}

/// Minimal [SyncRepository] subclass that avoids touching the database.
/// Only the three methods called by [SyncNotifier.refreshState] need to
/// be overridden; everything else is unreachable under the test harness.
class _FakeSyncRepository extends SyncRepository {
  int signOutCalls = 0;

  @override
  Future<DateTime?> getLastSyncTime({String? forProvider}) async => null;

  @override
  Future<int> getPendingCount() async => 0;

  @override
  Future<int> getConflictCount() async => 0;

  @override
  Future<void> setCloudProvider(CloudProviderType? provider) async {
    signOutCalls++;
  }

  @override
  Future<void> setRemoteFileId(String? fileId) async {}
}

/// Minimal [SyncService] subclass that avoids real I/O.
class _FakeSyncService extends SyncService {
  bool signOutCalled = false;

  _FakeSyncService(_FakeSyncRepository repo)
    : super(
        syncRepository: repo,
        serializer: SyncDataSerializer(),
        cloudProvider: null,
      );

  @override
  Future<bool> isSyncAvailable() async => false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

/// No-op database adapter so [_FakeBackupService] never touches a real DB.
class _NoopBackupAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {}

  @override
  Future<void> restore(String backupPath) async {}

  @override
  Future<String> get databasePath async => '/noop';

  @override
  AppDatabase get database => throw UnimplementedError();
}

/// Fake [BackupService] recording safety-backup calls from the adopt flow.
class _FakeBackupService extends BackupService {
  int performBackupCalls = 0;

  _FakeBackupService(BackupPreferences prefs)
    : super(dbAdapter: _NoopBackupAdapter(), preferences: prefs);

  @override
  Future<BackupRecord> performBackup({bool isAutomatic = false}) async {
    performBackupCalls++;
    return BackupRecord(
      id: 'fake-safety',
      filename: 'fake.db',
      timestamp: DateTime(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
    );
  }
}

/// Fake [SyncNotifier] that holds an arbitrary [SyncState] and records calls to
/// the mutating methods the page invokes, without touching the database.
class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier(super.state);

  int performSyncCalls = 0;
  int refreshStateCalls = 0;
  int resetSyncStateCalls = 0;
  int signOutCalls = 0;
  int adoptCalls = 0;
  int acknowledgeMovedCalls = 0;
  int checkLibraryMovedCalls = 0;
  int cleanupOldBackendDataCalls = 0;
  int dismissOldBackendCleanupCalls = 0;
  int recordBackendDepartureCalls = 0;

  /// Set to non-null to simulate first-contact conditions in widget tests.
  FirstSyncMergeInfo? firstSyncInfo;

  /// Set to non-null to simulate a replaced cloud library awaiting adoption.
  LibraryEpochMarker? replaceInfo;

  @override
  Future<void> performSync({bool auto = false}) async => performSyncCalls++;

  @override
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async => firstSyncInfo;

  @override
  Future<LibraryEpochMarker?> libraryReplaceInfo() async => replaceInfo;

  @override
  Future<void> adoptReplacedLibrary() async {
    adoptCalls++;
  }

  @override
  Future<void> acknowledgeMoved() async => acknowledgeMovedCalls++;

  @override
  Future<void> checkLibraryMoved() async => checkLibraryMovedCalls++;

  @override
  Future<void> cleanupOldBackendData() async => cleanupOldBackendDataCalls++;

  @override
  Future<void> dismissOldBackendCleanup() async =>
      dismissOldBackendCleanupCalls++;

  @override
  Future<void> recordBackendDeparture({
    required CloudStorageProvider oldProvider,
    required String toProviderId,
    String? toProviderName,
  }) async => recordBackendDepartureCalls++;

  @override
  Future<void> refreshState() async => refreshStateCalls++;

  @override
  Future<void> resetSyncState() async => resetSyncStateCalls++;

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<void> resolveConflict(
    String entityType,
    String recordId,
    ConflictResolution resolution,
  ) async {}
}

/// Cloud provider whose [authenticate] always throws, to exercise the
/// connection-failure branch of `_selectProvider`.
class _ThrowingCloudStorageProvider extends FakeCloudStorageProvider {
  @override
  Future<void> authenticate() async {
    throw const CloudStorageException('auth denied');
  }
}

/// Fake [SyncBehaviorNotifier] holding fixed settings and recording setter
/// invocations, so the behavior switches can be rendered and toggled without
/// SharedPreferences.
class _FakeSyncBehaviorNotifier extends StateNotifier<SyncBehaviorSettings>
    implements SyncBehaviorNotifier {
  _FakeSyncBehaviorNotifier(super.state);

  @override
  Future<void> setAutoSyncEnabled(bool value) async =>
      state = state.copyWith(autoSyncEnabled: value);

  @override
  Future<void> setSyncOnLaunch(bool value) async =>
      state = state.copyWith(syncOnLaunch: value);

  @override
  Future<void> setSyncOnResume(bool value) async =>
      state = state.copyWith(syncOnResume: value);
}

/// Fake [DiverMergeRepository] that records merge/undo calls and returns an
/// empty snapshot, so the merge flow can run without a database.
class _FakeDiverMergeRepository implements DiverMergeRepository {
  int mergeCalls = 0;
  int undoCalls = 0;
  bool throwOnMerge = false;

  @override
  Future<DiverMergeSnapshot> mergeDivers({
    required String keeperId,
    required String duplicateId,
  }) async {
    mergeCalls++;
    if (throwOnMerge) {
      throw StateError('merge boom');
    }
    return DiverMergeSnapshot(
      keeperId: keeperId,
      duplicateId: duplicateId,
      duplicateDiver: const {},
      repointedRows: const [],
      deletedSingletonRows: const [],
    );
  }

  @override
  Future<void> undoMerge(DiverMergeSnapshot snapshot) async => undoCalls++;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final fixedNow = DateTime(2026, 6, 7, 12, 0);

  Diver makeDiver({
    required String id,
    required String name,
    bool isDefault = false,
    DateTime? createdAt,
  }) {
    return Diver(
      id: id,
      name: name,
      isDefault: isDefault,
      createdAt: createdAt ?? fixedNow,
      updatedAt: createdAt ?? fixedNow,
    );
  }

  /// Build a [DuplicateDiverGroup] with one keeper and [duplicateCount]
  /// duplicates that share [name].
  DuplicateDiverGroup makeGroup({
    String name = 'Alice',
    int duplicateCount = 1,
  }) {
    final keeper = makeDiver(id: 'keeper', name: name, isDefault: true);
    final duplicates = List.generate(
      duplicateCount,
      (i) => makeDiver(id: 'dup-$i', name: name),
    );
    return DuplicateDiverGroup(keeper: keeper, duplicates: duplicates);
  }

  /// Pump [CloudSyncPage] with controllable overrides. Returns the fake sync
  /// notifier and fake merge repository so tests can assert on recorded calls.
  ///
  /// [s3Config] controls what [s3ConfigProvider] resolves to. Defaults to
  /// null (unconfigured) so tests that do not care about S3 exercise the
  /// intended unconfigured state rather than hitting FlutterSecureStorage.
  Future<
    ({
      _FakeSyncNotifier sync,
      _FakeDiverMergeRepository merge,
      _FakeBackupService backup,
    })
  >
  pumpPage(
    WidgetTester tester, {
    SyncState syncState = const SyncState(),
    CloudProviderType? selectedProvider,
    bool customFolderMode = false,
    List<DuplicateDiverGroup> duplicateGroups = const [],
    bool cloudProviderNull = false,
    CloudStorageProvider? cloudProvider,
    bool mergeThrows = false,
    bool settle = true,
    S3Config? s3Config,
    SyncBehaviorSettings behavior = const SyncBehaviorSettings(
      autoSyncEnabled: false,
      syncOnLaunch: false,
      syncOnResume: false,
    ),
    ICloudAvailability iCloudAvailability = ICloudAvailability.available,
    bool applePlatform = true,
  }) async {
    final base = await getBaseOverrides();
    final fakeSync = _FakeSyncNotifier(syncState);
    final fakeMerge = _FakeDiverMergeRepository()..throwOnMerge = mergeThrows;
    final fakeBackup = _FakeBackupService(
      BackupPreferences(await SharedPreferences.getInstance()),
    );

    await tester.binding.setSurfaceSize(const Size(500, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          syncStateProvider.overrideWith((ref) => fakeSync),
          syncBehaviorProvider.overrideWith(
            (ref) => _FakeSyncBehaviorNotifier(behavior),
          ),
          selectedCloudProviderTypeProvider.overrideWith(
            (ref) => selectedProvider,
          ),
          iCloudAvailabilityProvider.overrideWith(
            (ref) async => iCloudAvailability,
          ),
          isApplePlatformProvider.overrideWithValue(applePlatform),
          isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(
            customFolderMode,
          ),
          duplicateDiverGroupsProvider.overrideWith(
            (ref) async => duplicateGroups,
          ),
          allDiversProvider.overrideWith((ref) async => const <Diver>[]),
          diverMergeRepositoryProvider.overrideWithValue(fakeMerge),
          cloudStorageProviderProvider.overrideWithValue(
            cloudProviderNull
                ? null
                : (cloudProvider ?? FakeCloudStorageProvider()),
          ),
          conflictsProvider.overrideWith((ref) async => const []),
          // The adopt flow's safety backup must never construct the real
          // BackupService (it would touch the DatabaseService singleton).
          backupServiceProvider.overrideWithValue(fakeBackup),
          // Override s3ConfigProvider so existing tests never hit
          // FlutterSecureStorage; individual tests can supply a config.
          s3ConfigProvider.overrideWith((ref) async => s3Config),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CloudSyncPage(),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // Indeterminate progress indicators never settle; pump fixed frames so
      // the async overrides resolve without awaiting an infinite animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    return (sync: fakeSync, merge: fakeMerge, backup: fakeBackup);
  }

  group('CloudSyncPage - iCloud availability', () {
    ListTile iCloudTile(WidgetTester tester) => tester.widget<ListTile>(
      find.ancestor(of: find.text('iCloud'), matching: find.byType(ListTile)),
    );

    testWidgets('disables the iCloud tile when the build is unsupported', (
      tester,
    ) async {
      await pumpPage(
        tester,
        iCloudAvailability: ICloudAvailability.unsupported,
      );

      expect(iCloudTile(tester).enabled, isFalse);
    });

    testWidgets('enables the iCloud tile when available', (tester) async {
      await pumpPage(tester, iCloudAvailability: ICloudAvailability.available);

      expect(iCloudTile(tester).enabled, isTrue);
    });

    testWidgets('shows the build-specific subtitle when unsupported', (
      tester,
    ) async {
      await pumpPage(
        tester,
        iCloudAvailability: ICloudAvailability.unsupported,
      );

      expect(
        find.text(
          'Not available in this build — use S3 or the App Store version',
        ),
        findsOneWidget,
      );
    });

    testWidgets('disables with the platform subtitle on non-Apple platforms', (
      tester,
    ) async {
      await pumpPage(
        tester,
        applePlatform: false,
        iCloudAvailability: ICloudAvailability.unsupported,
      );

      expect(iCloudTile(tester).enabled, isFalse);
      expect(find.text('Not available on this platform'), findsOneWidget);
    });

    testWidgets('iCloud connection failure shows the signed-out message', (
      tester,
    ) async {
      await pumpPage(
        tester,
        iCloudAvailability: ICloudAvailability.signedOut,
        cloudProvider: _ThrowingCloudStorageProvider(),
      );

      await tester.tap(find.text('iCloud'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'iCloud is not available. Please sign in to iCloud in your '
          'device settings.',
        ),
        findsOneWidget,
      );
    });
  });

  group('connectionErrorMessage', () {
    final l10n = AppLocalizationsEn();

    test('iCloud unsupported maps to the unsupported message', () {
      expect(
        connectionErrorMessage(
          l10n,
          CloudProviderType.icloud,
          ICloudAvailability.unsupported,
          'iCloud',
          'err',
        ),
        l10n.settings_cloudSync_error_icloudUnsupported,
      );
    });

    test('iCloud signedOut maps to the signed-out message', () {
      expect(
        connectionErrorMessage(
          l10n,
          CloudProviderType.icloud,
          ICloudAvailability.signedOut,
          'iCloud',
          'err',
        ),
        l10n.settings_cloudSync_error_icloudSignedOut,
      );
    });

    test('iCloud unknown maps to the unknown message', () {
      expect(
        connectionErrorMessage(
          l10n,
          CloudProviderType.icloud,
          ICloudAvailability.unknown,
          'iCloud',
          'err',
        ),
        l10n.settings_cloudSync_error_icloudUnknown,
      );
    });

    test('iCloud null availability maps to the unknown message', () {
      expect(
        connectionErrorMessage(
          l10n,
          CloudProviderType.icloud,
          null,
          'iCloud',
          'err',
        ),
        l10n.settings_cloudSync_error_icloudUnknown,
      );
    });

    test('available iCloud falls back to the generic message', () {
      expect(
        connectionErrorMessage(
          l10n,
          CloudProviderType.icloud,
          ICloudAvailability.available,
          'iCloud',
          'boom',
        ),
        l10n.settings_cloudSync_provider_connectionFailed('iCloud', 'boom'),
      );
    });

    test('non-iCloud provider uses the generic message', () {
      expect(
        connectionErrorMessage(l10n, CloudProviderType.s3, null, 'S3', 'boom'),
        l10n.settings_cloudSync_provider_connectionFailed('S3', 'boom'),
      );
    });
  });

  group('CloudSyncPage - base render', () {
    testWidgets('renders app bar, provider tiles, and sections', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('Cloud Sync'), findsOneWidget);
      // Provider section header and provider tiles. Google Drive is hidden
      // until its integration is fully implemented.
      expect(find.text('Cloud Provider'), findsOneWidget);
      expect(find.text('iCloud'), findsOneWidget);
      expect(find.text('Google Drive'), findsNothing);
      // Behavior section.
      expect(find.text('Sync Behavior'), findsOneWidget);
      expect(find.text('Auto Sync'), findsOneWidget);
      expect(find.text('Sync on Launch'), findsOneWidget);
      expect(find.text('Sync on Resume'), findsOneWidget);
      // Advanced section.
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('Reset Sync State'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      // Sync Now action present; no provider selected => hint shown + disabled.
      expect(find.text('Sync Now'), findsOneWidget);
      expect(
        find.text('Select a cloud provider to enable sync'),
        findsOneWidget,
      );
    });

    testWidgets('does not show custom folder banner when not custom mode', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('Cloud Sync Disabled'), findsNothing);
    });

    testWidgets('does not show duplicate divers banner when no duplicates', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('Duplicate diver profiles'), findsNothing);
    });
  });

  group('CloudSyncPage - custom folder banner', () {
    testWidgets('shows banner and disables behavior switches in custom mode', (
      tester,
    ) async {
      await pumpPage(tester, customFolderMode: true);

      expect(find.text('Cloud Sync Disabled'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text('Storage Settings'), findsOneWidget);

      // All three behavior switches are disabled (onChanged null).
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches.length, 3);
      for (final s in switches) {
        expect(s.onChanged, isNull);
      }
    });

    testWidgets('tapping Storage Settings pushes the storage route', (
      tester,
    ) async {
      final base = await getBaseOverrides();
      await tester.binding.setSurfaceSize(const Size(500, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/settings/cloud',
        routes: [
          GoRoute(
            path: '/settings/cloud',
            builder: (context, state) => const CloudSyncPage(),
          ),
          GoRoute(
            path: '/settings/storage',
            builder: (context, state) =>
                const Scaffold(body: Text('STORAGE_PAGE')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            syncStateProvider.overrideWith(
              (ref) => _FakeSyncNotifier(const SyncState()),
            ),
            syncBehaviorProvider.overrideWith(
              (ref) => _FakeSyncBehaviorNotifier(
                const SyncBehaviorSettings(
                  autoSyncEnabled: false,
                  syncOnLaunch: false,
                  syncOnResume: false,
                ),
              ),
            ),
            selectedCloudProviderTypeProvider.overrideWith((ref) => null),
            isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(true),
            duplicateDiverGroupsProvider.overrideWith((ref) async => const []),
            allDiversProvider.overrideWith((ref) async => const <Diver>[]),
            cloudStorageProviderProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Storage Settings'));
      await tester.pumpAndSettle();
      expect(find.text('STORAGE_PAGE'), findsOneWidget);
    });
  });

  group('CloudSyncPage - status card states', () {
    testWidgets('idle status shows ready title and cloud icon', (tester) async {
      await pumpPage(tester, syncState: const SyncState());
      expect(find.text('Ready to sync'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
    });

    testWidgets('syncing status with progress shows progress indicator', (
      tester,
    ) async {
      await pumpPage(
        tester,
        settle: false,
        syncState: const SyncState(
          status: SyncStatus.syncing,
          progress: 0.5,
          message: 'Working...',
        ),
      );
      expect(find.text('Syncing...'), findsWidgets);
      expect(find.text('Working...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('success status shows cloud_done icon', (tester) async {
      await pumpPage(
        tester,
        syncState: const SyncState(status: SyncStatus.success),
      );
      expect(find.text('Sync complete'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done), findsOneWidget);
    });

    testWidgets('error status shows cloud_off icon', (tester) async {
      await pumpPage(
        tester,
        syncState: const SyncState(status: SyncStatus.error),
      );
      expect(find.text('Sync error'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('hasConflicts status shows warning icon and title', (
      tester,
    ) async {
      await pumpPage(
        tester,
        syncState: const SyncState(status: SyncStatus.hasConflicts),
      );
      expect(find.text('Conflicts detected'), findsOneWidget);
      // Warning icons appear both in the status card and the conflicts section
      // header when conflicts > 0; here conflicts == 0 so only the status icon.
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('shows pending changes singular', (tester) async {
      await pumpPage(tester, syncState: const SyncState(pendingChanges: 1));
      expect(find.text('1 pending change'), findsOneWidget);
    });

    testWidgets('shows pending changes plural', (tester) async {
      await pumpPage(tester, syncState: const SyncState(pendingChanges: 3));
      expect(find.text('3 pending changes'), findsOneWidget);
    });
  });

  group('CloudSyncPage - last synced formatting', () {
    testWidgets('shows "Just now" for very recent sync', (tester) async {
      await pumpPage(
        tester,
        syncState: SyncState(
          lastSync: DateTime.now().subtract(const Duration(seconds: 10)),
        ),
      );
      expect(find.text('Last synced: Just now'), findsOneWidget);
    });

    testWidgets('shows minutes ago', (tester) async {
      await pumpPage(
        tester,
        syncState: SyncState(
          lastSync: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      );
      expect(find.text('Last synced: 5 minutes ago'), findsOneWidget);
    });

    testWidgets('shows singular minute ago', (tester) async {
      await pumpPage(
        tester,
        syncState: SyncState(
          lastSync: DateTime.now().subtract(
            const Duration(minutes: 1, seconds: 5),
          ),
        ),
      );
      expect(find.text('Last synced: 1 minute ago'), findsOneWidget);
    });

    testWidgets('shows hours ago', (tester) async {
      await pumpPage(
        tester,
        syncState: SyncState(
          lastSync: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      );
      expect(find.text('Last synced: 3 hours ago'), findsOneWidget);
    });

    testWidgets('shows days ago', (tester) async {
      await pumpPage(
        tester,
        syncState: SyncState(
          lastSync: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      expect(find.text('Last synced: 2 days ago'), findsOneWidget);
    });

    testWidgets('shows formatted date for >7 days', (tester) async {
      final old = DateTime.now().subtract(const Duration(days: 30));
      await pumpPage(tester, syncState: SyncState(lastSync: old));
      // Formatted via DateFormat.yMMMd(); assert the prefix and that none of
      // the relative phrasings are present.
      expect(find.textContaining('Last synced:'), findsOneWidget);
      expect(find.textContaining('ago'), findsNothing);
    });
  });

  group('CloudSyncPage - provider selection', () {
    // The tap-to-select flow now only runs through the iCloud tile, which
    // is disabled off-Apple, so the tap tests are skipped on the Linux CI
    // runner. They still run on macOS (developer machines + pre-push).
    final tapUnavailable = !(Platform.isIOS || Platform.isMacOS);

    testWidgets('selected provider shows connected check icon', (tester) async {
      await pumpPage(tester, selectedProvider: CloudProviderType.icloud);
      // The trailing check_circle marks the selected provider.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      // With a provider selected the hint disappears.
      expect(find.text('Select a cloud provider to enable sync'), findsNothing);
    });

    testWidgets(
      'persisted googledrive selection reads as no provider since the tile is hidden',
      (tester) async {
        // SyncRepository.getCloudProvider() falls back to googledrive when
        // the stored enum name does not match, and getLastProvider() returns
        // a previously persisted googledrive choice verbatim. With the tile
        // removed, the UI must treat that as "no provider" so Sync Now is
        // disabled and the select-provider hint stays visible. Otherwise the
        // user sees no selected tile but a green Sync Now -- inconsistent.
        await pumpPage(tester, selectedProvider: CloudProviderType.googledrive);

        // No tile shows the connected check icon (googledrive tile is hidden).
        expect(find.byIcon(Icons.check_circle), findsNothing);
        // Sync Now is disabled and the hint is shown.
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Sync Now'),
        );
        expect(button.onPressed, isNull);
        expect(
          find.text('Select a cloud provider to enable sync'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping the iCloud tile authenticates and shows snackbar',
      (tester) async {
        final handles = await pumpPage(tester);

        await tester.tap(find.text('iCloud'));
        await tester.pumpAndSettle();

        // Fake provider authenticates successfully -> success snackbar +
        // refreshState() on the sync notifier.
        expect(find.text('Connected to Fake'), findsOneWidget);
        expect(handles.sync.refreshStateCalls, greaterThan(0));
      },
      skip: tapUnavailable,
    );

    testWidgets('null cloud provider shows initialize-failed snackbar', (
      tester,
    ) async {
      await pumpPage(tester, cloudProviderNull: true);

      await tester.tap(find.text('iCloud'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to initialize icloud provider'), findsOneWidget);
    }, skip: tapUnavailable);

    testWidgets(
      'authentication failure shows connection-failed snackbar',
      (tester) async {
        await pumpPage(tester, cloudProvider: _ThrowingCloudStorageProvider());

        await tester.tap(find.text('iCloud'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Fake connection failed:'), findsOneWidget);
      },
      skip: tapUnavailable,
    );
  });

  group('CloudSyncPage - sync actions', () {
    // The iCloud provider tile is only actionable on Apple platforms
    // (isAvailable: Platform.isIOS || Platform.isMacOS), so tests that switch
    // backends by tapping it cannot run on the Linux test runner, where its
    // ListTile is disabled and tapping it never opens the switch dialog.
    final tapUnavailable = !(Platform.isIOS || Platform.isMacOS);

    testWidgets('Sync Now is enabled with provider and triggers performSync', (
      tester,
    ) async {
      final handles = await pumpPage(
        tester,
        selectedProvider: CloudProviderType.icloud,
      );

      // Hint gone, button enabled.
      expect(find.text('Select a cloud provider to enable sync'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Sync Now'));
      await tester.pumpAndSettle();
      expect(handles.sync.performSyncCalls, 1);
    });

    testWidgets('Sync Now is disabled while syncing', (tester) async {
      final handles = await pumpPage(
        tester,
        settle: false,
        selectedProvider: CloudProviderType.icloud,
        syncState: const SyncState(status: SyncStatus.syncing),
      );

      // Button label reflects syncing state and tap is a no-op.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Syncing...'),
      );
      expect(button.onPressed, isNull);
      expect(handles.sync.performSyncCalls, 0);
    });

    testWidgets(
      'Sync Now shows the merge dialog on first contact and syncs only after confirm',
      (tester) async {
        final handles = await pumpPage(
          tester,
          selectedProvider: CloudProviderType.icloud,
        );
        // Configure first-contact info after pump so it's ready when tapped.
        handles.sync.firstSyncInfo = const FirstSyncMergeInfo(
          peerFileCount: 2,
          localDiveCount: 31,
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Sync Now'));
        await tester.pumpAndSettle();

        // Dialog should be visible and no sync yet.
        expect(find.text('Combine Libraries?'), findsOneWidget);
        expect(handles.sync.performSyncCalls, 0);

        // Confirm triggers performSync.
        await tester.tap(find.text('Merge and Sync'));
        await tester.pumpAndSettle();
        expect(handles.sync.performSyncCalls, 1);
      },
    );

    testWidgets('cancelling the merge dialog does not sync', (tester) async {
      final handles = await pumpPage(
        tester,
        selectedProvider: CloudProviderType.icloud,
      );
      handles.sync.firstSyncInfo = const FirstSyncMergeInfo(
        peerFileCount: 2,
        localDiveCount: 31,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Sync Now'));
      await tester.pumpAndSettle();

      expect(find.text('Combine Libraries?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(handles.sync.performSyncCalls, 0);
    });

    testWidgets('shows the first-sync banner while confirmation is pending', (
      tester,
    ) async {
      await pumpPage(
        tester,
        selectedProvider: CloudProviderType.icloud,
        syncState: const SyncState(firstSyncAwaitingConfirmation: true),
      );

      expect(find.textContaining('First sync is waiting'), findsOneWidget);
    });

    testWidgets('shows the replace banner while adoption is pending', (
      tester,
    ) async {
      await pumpPage(
        tester,
        selectedProvider: CloudProviderType.icloud,
        syncState: const SyncState(
          replaceAwaitingAdoption: true,
          replaceMarker: LibraryEpochMarker(
            epochId: 'e1',
            replacedAt: 1,
            deviceId: 'd1',
            deviceName: 'Eric Mac',
          ),
        ),
      );

      expect(
        find.textContaining('library was replaced from a backup'),
        findsOneWidget,
      );
      expect(find.textContaining('Eric Mac'), findsOneWidget);
    });

    testWidgets('shows the library-moved banner and Dismiss acknowledges it', (
      tester,
    ) async {
      final handles = await pumpPage(
        tester,
        selectedProvider: CloudProviderType.s3,
        syncState: const SyncState(
          movedMarker: LibraryMovedMarker(
            movedAt: 1,
            toProviderId: 'icloud',
            toProviderName: 'iCloud',
            deviceId: 'd1',
            deviceName: 'Eric Mac',
          ),
        ),
      );

      expect(find.textContaining('moved this library to'), findsOneWidget);
      expect(find.textContaining('Eric Mac'), findsOneWidget);
      expect(handles.sync.acknowledgeMovedCalls, 0);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(handles.sync.acknowledgeMovedCalls, 1);
    });

    testWidgets('shows the old-backend cleanup offer; Delete and Keep call '
        'the matching notifier actions', (tester) async {
      final handles = await pumpPage(
        tester,
        selectedProvider: CloudProviderType.icloud,
        syncState: const SyncState(cleanupOldBackendProviderId: 's3'),
      );

      expect(
        find.textContaining('Old sync data is still stored'),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete old data'));
      await tester.pumpAndSettle();
      expect(handles.sync.cleanupOldBackendDataCalls, 1);
      expect(handles.sync.dismissOldBackendCleanupCalls, 0);
    });

    testWidgets('Keep dismisses the cleanup offer without deleting', (
      tester,
    ) async {
      final handles = await pumpPage(
        tester,
        selectedProvider: CloudProviderType.icloud,
        syncState: const SyncState(cleanupOldBackendProviderId: 's3'),
      );

      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();

      expect(handles.sync.dismissOldBackendCleanupCalls, 1);
      expect(handles.sync.cleanupOldBackendDataCalls, 0);
    });

    testWidgets('switching backends with sync history confirms and records '
        'the departure', (tester) async {
      final handles = await pumpPage(
        tester,
        selectedProvider: CloudProviderType.s3,
        // A prior sync against the current (S3) backend -> has history.
        syncState: SyncState(lastSync: DateTime(2026, 1, 1)),
      );

      // Tap the iCloud tile (available on macOS host) to switch away from S3.
      await tester.tap(find.text('iCloud'));
      await tester.pumpAndSettle();

      // The confirmation dialog explains the consequences.
      expect(find.text('Switch sync backend?'), findsOneWidget);
      expect(handles.sync.recordBackendDepartureCalls, 0);

      await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
      await tester.pumpAndSettle();

      expect(handles.sync.recordBackendDepartureCalls, 1);
    }, skip: tapUnavailable);

    testWidgets('cancelling the backend-switch dialog records nothing', (
      tester,
    ) async {
      final handles = await pumpPage(
        tester,
        selectedProvider: CloudProviderType.s3,
        syncState: SyncState(lastSync: DateTime(2026, 1, 1)),
      );

      await tester.tap(find.text('iCloud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(handles.sync.recordBackendDepartureCalls, 0);
    }, skip: tapUnavailable);

    testWidgets(
      'Sync Now offers the adopt dialog; adopting backs up then adopts',
      (tester) async {
        final handles = await pumpPage(
          tester,
          selectedProvider: CloudProviderType.icloud,
        );
        handles.sync.replaceInfo = const LibraryEpochMarker(
          epochId: 'e1',
          replacedAt: 1764000000000,
          deviceId: 'd1',
          deviceName: 'Eric Mac',
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Sync Now'));
        await tester.pumpAndSettle();

        expect(find.text('Adopt Restored Library?'), findsOneWidget);
        expect(handles.sync.adoptCalls, 0);

        await tester.tap(find.text('Adopt Restored Library'));
        await tester.pumpAndSettle();

        expect(
          handles.backup.performBackupCalls,
          1,
          reason: 'a safety backup must precede adoption',
        );
        expect(handles.sync.adoptCalls, 1);
      },
    );

    testWidgets('Not Now defers adoption without backing up', (tester) async {
      final handles = await pumpPage(
        tester,
        selectedProvider: CloudProviderType.icloud,
      );
      handles.sync.replaceInfo = const LibraryEpochMarker(
        epochId: 'e1',
        replacedAt: 1764000000000,
        deviceId: 'd1',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Sync Now'));
      await tester.pumpAndSettle();

      expect(find.text('Adopt Restored Library?'), findsOneWidget);

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(handles.sync.adoptCalls, 0);
      expect(handles.backup.performBackupCalls, 0);
      expect(handles.sync.performSyncCalls, 0);
    });
  });

  group('CloudSyncPage - conflicts section', () {
    testWidgets('shows conflicts section when conflicts > 0 (plural)', (
      tester,
    ) async {
      await pumpPage(tester, syncState: const SyncState(conflicts: 3));
      expect(find.text('Conflicts (3)'), findsOneWidget);
      expect(find.text('Resolve Conflicts'), findsOneWidget);
      expect(find.text('3 items need attention'), findsOneWidget);
    });

    testWidgets('shows singular wording when conflicts == 1', (tester) async {
      await pumpPage(tester, syncState: const SyncState(conflicts: 1));
      expect(find.text('Conflicts (1)'), findsOneWidget);
      expect(find.text('1 item needs attention'), findsOneWidget);
    });

    testWidgets('tapping Resolve Conflicts opens dialog and refreshes', (
      tester,
    ) async {
      final handles = await pumpPage(
        tester,
        syncState: const SyncState(conflicts: 2),
      );

      await tester.tap(find.text('Resolve Conflicts'));
      await tester.pumpAndSettle();

      // The ConflictResolutionDialog renders (no conflicts -> "all resolved"
      // content). Dismiss it via back to trigger the post-dialog refresh.
      expect(find.byType(Dialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(Dialog))).pop();
      await tester.pumpAndSettle();
      expect(handles.sync.refreshStateCalls, greaterThan(0));
    });
  });

  group('CloudSyncPage - behavior switches', () {
    testWidgets('toggling Auto Sync flips its switch value', (tester) async {
      await pumpPage(tester);
      final autoSwitch = find.widgetWithText(SwitchListTile, 'Auto Sync');
      expect(tester.widget<SwitchListTile>(autoSwitch).value, isFalse);

      await tester.tap(autoSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(autoSwitch).value, isTrue);
    });

    testWidgets('toggling Sync on Launch and Resume flips values', (
      tester,
    ) async {
      await pumpPage(tester);

      final launch = find.widgetWithText(SwitchListTile, 'Sync on Launch');
      await tester.tap(launch);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(launch).value, isTrue);

      final resume = find.widgetWithText(SwitchListTile, 'Sync on Resume');
      await tester.tap(resume);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(resume).value, isTrue);
    });
  });

  group('CloudSyncPage - reset sync state dialog', () {
    testWidgets('cancel does not call resetSyncState', (tester) async {
      final handles = await pumpPage(tester);

      await tester.tap(find.text('Reset Sync State'));
      await tester.pumpAndSettle();
      expect(find.text('Reset Sync State?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(handles.sync.resetSyncStateCalls, 0);
    });

    testWidgets('confirm calls resetSyncState and shows snackbar', (
      tester,
    ) async {
      final handles = await pumpPage(tester);

      await tester.tap(find.text('Reset Sync State'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Reset'));
      await tester.pumpAndSettle();

      expect(handles.sync.resetSyncStateCalls, 1);
      expect(find.text('Sync state reset'), findsOneWidget);
    });
  });

  group('CloudSyncPage - sign out dialog', () {
    testWidgets('cancel does not call signOut', (tester) async {
      final handles = await pumpPage(tester);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.text('Sign Out?'), findsOneWidget);

      // Cancel button inside the dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(handles.sync.signOutCalls, 0);
    });

    testWidgets('confirm calls signOut and shows snackbar', (tester) async {
      final handles = await pumpPage(tester);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      // The confirm action button (the second "Sign Out" text, inside dialog).
      await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(handles.sync.signOutCalls, 1);
      expect(find.text('Signed out from cloud provider'), findsOneWidget);
    });

    testWidgets('warns about cloud backup and disables it on confirm', (
      tester,
    ) async {
      final handles = await pumpPage(tester);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('backup_cloud_enabled', true);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Cloud backup will be turned off'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(handles.sync.signOutCalls, 1);
      expect(prefs.getBool('backup_cloud_enabled'), isFalse);
    });

    testWidgets('no cloud backup warning when it was already off', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign Out?'), findsOneWidget);
      expect(
        find.textContaining('Cloud backup will be turned off'),
        findsNothing,
      );
    });
  });

  group('CloudSyncPage - duplicate divers banner', () {
    testWidgets('shows banner with group label when duplicates exist', (
      tester,
    ) async {
      await pumpPage(
        tester,
        duplicateGroups: [makeGroup(name: 'Alice', duplicateCount: 1)],
      );

      expect(find.text('Duplicate diver profiles'), findsOneWidget);
      expect(find.byIcon(Icons.merge_type), findsWidgets);
      // groupLabel: "{name} ({count} profiles)" with count = duplicates + 1.
      expect(find.text('Alice (2 profiles)'), findsOneWidget);
      expect(find.text('Merge'), findsOneWidget);
    });

    testWidgets('merge confirm cancel does not merge', (tester) async {
      final handles = await pumpPage(
        tester,
        duplicateGroups: [makeGroup(name: 'Bob', duplicateCount: 1)],
      );

      await tester.tap(find.text('Merge'));
      await tester.pumpAndSettle();
      expect(find.text('Merge diver profiles?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(handles.merge.mergeCalls, 0);
    });

    testWidgets('merge confirm runs merge and shows undo snackbar', (
      tester,
    ) async {
      final handles = await pumpPage(
        tester,
        duplicateGroups: [makeGroup(name: 'Carol', duplicateCount: 2)],
      );

      await tester.tap(find.text('Merge'));
      await tester.pumpAndSettle();
      // Confirm via the FilledButton labelled "Merge" inside the dialog (the
      // banner button is a FilledButton.tonal, so scope to the AlertDialog).
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Merge'),
        ),
      );
      await tester.pumpAndSettle();

      // Two duplicates => two merge calls.
      expect(handles.merge.mergeCalls, 2);
      expect(find.text('Merged into Carol'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('tapping Undo on snackbar runs undoMerge', (tester) async {
      final handles = await pumpPage(
        tester,
        duplicateGroups: [makeGroup(name: 'Dave', duplicateCount: 2)],
      );

      await tester.tap(find.text('Merge'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Merge'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      // undoMerge invoked once per snapshot (2 duplicates).
      expect(handles.merge.undoCalls, 2);
    });

    testWidgets('merge failure shows failure snackbar', (tester) async {
      await pumpPage(
        tester,
        duplicateGroups: [makeGroup(name: 'Eve', duplicateCount: 1)],
        mergeThrows: true,
      );

      await tester.tap(find.text('Merge'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Merge'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Merge failed:'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // S3 provider tile
  // ---------------------------------------------------------------------------

  group('S3 provider tile', () {
    testWidgets('renders title and marketing subtitle when unconfigured', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('S3-Compatible Storage'), findsOneWidget);
      expect(
        find.text('Works with any S3-compatible storage service'),
        findsOneWidget,
      );
    });

    testWidgets('subtitle shows bucket @ host when configured', (tester) async {
      final config = S3Config(
        endpoint: 'http://nas.local:9000',
        bucket: 'dive-sync',
        accessKeyId: 'ak',
        secretAccessKey: 'sk',
      );
      await pumpPage(tester, s3Config: config);

      expect(find.text('dive-sync @ nas.local'), findsOneWidget);
    });

    testWidgets('check_circle appears when S3 is the selected provider', (
      tester,
    ) async {
      // Not selected: no checkmark on the S3 tile (one checkmark only appears
      // when a provider is selected, and here we select iCloud instead).
      await pumpPage(tester, selectedProvider: CloudProviderType.icloud);
      // Only one check_circle -- for iCloud, not S3.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Now select S3: the checkmark moves to the S3 tile.  With no other
      // provider selected there is exactly one check_circle on screen.
      await pumpPage(tester, selectedProvider: CloudProviderType.s3);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('check_circle absent when no provider is selected', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('tapping unconfigured tile navigates to s3-config route', (
      tester,
    ) async {
      final base = await getBaseOverrides();
      await tester.binding.setSurfaceSize(const Size(500, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/settings/cloud-sync',
        routes: [
          GoRoute(
            path: '/settings/cloud-sync',
            builder: (context, state) => const CloudSyncPage(),
          ),
          GoRoute(
            path: '/settings/cloud-sync/s3-config',
            builder: (context, state) =>
                const Scaffold(body: Text('s3-config-stub')),
          ),
          GoRoute(
            path: '/settings/storage',
            builder: (context, state) => const Scaffold(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...base,
            syncStateProvider.overrideWith(
              (ref) => _FakeSyncNotifier(const SyncState()),
            ),
            syncBehaviorProvider.overrideWith(
              (ref) => _FakeSyncBehaviorNotifier(
                const SyncBehaviorSettings(
                  autoSyncEnabled: false,
                  syncOnLaunch: false,
                  syncOnResume: false,
                ),
              ),
            ),
            selectedCloudProviderTypeProvider.overrideWith((ref) => null),
            isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(false),
            duplicateDiverGroupsProvider.overrideWith((ref) async => const []),
            allDiversProvider.overrideWith((ref) async => const <Diver>[]),
            diverMergeRepositoryProvider.overrideWithValue(
              _FakeDiverMergeRepository(),
            ),
            cloudStorageProviderProvider.overrideWithValue(
              FakeCloudStorageProvider(),
            ),
            conflictsProvider.overrideWith((ref) async => const []),
            // Unconfigured: no S3 config stored.
            s3ConfigProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('S3-Compatible Storage'));
      await tester.pumpAndSettle();

      expect(find.text('s3-config-stub'), findsOneWidget);
    });

    testWidgets(
      'gear icon always navigates to s3-config route even when configured',
      (tester) async {
        final base = await getBaseOverrides();
        await tester.binding.setSurfaceSize(const Size(500, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final router = GoRouter(
          initialLocation: '/settings/cloud-sync',
          routes: [
            GoRoute(
              path: '/settings/cloud-sync',
              builder: (context, state) => const CloudSyncPage(),
            ),
            GoRoute(
              path: '/settings/cloud-sync/s3-config',
              builder: (context, state) =>
                  const Scaffold(body: Text('s3-config-stub')),
            ),
            GoRoute(
              path: '/settings/storage',
              builder: (context, state) => const Scaffold(),
            ),
          ],
        );

        final config = S3Config(
          endpoint: 'http://nas.local:9000',
          bucket: 'dive-sync',
          accessKeyId: 'ak',
          secretAccessKey: 'sk',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...base,
              syncStateProvider.overrideWith(
                (ref) => _FakeSyncNotifier(const SyncState()),
              ),
              syncBehaviorProvider.overrideWith(
                (ref) => _FakeSyncBehaviorNotifier(
                  const SyncBehaviorSettings(
                    autoSyncEnabled: false,
                    syncOnLaunch: false,
                    syncOnResume: false,
                  ),
                ),
              ),
              selectedCloudProviderTypeProvider.overrideWith(
                (ref) => CloudProviderType.s3,
              ),
              isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(
                false,
              ),
              duplicateDiverGroupsProvider.overrideWith(
                (ref) async => const [],
              ),
              allDiversProvider.overrideWith((ref) async => const <Diver>[]),
              diverMergeRepositoryProvider.overrideWithValue(
                _FakeDiverMergeRepository(),
              ),
              cloudStorageProviderProvider.overrideWithValue(
                FakeCloudStorageProvider(),
              ),
              conflictsProvider.overrideWith((ref) async => const []),
              s3ConfigProvider.overrideWith((ref) async => config),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the gear icon (settings_outlined), not the tile body.
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();

        expect(find.text('s3-config-stub'), findsOneWidget);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // SyncNotifier.signOut -- S3 credential-retention branch
  // ---------------------------------------------------------------------------

  group('SyncNotifier.signOut S3 branch', () {
    /// Build a [ProviderContainer] wired with fake sync infrastructure.
    /// [initialProvider] seeds [selectedCloudProviderTypeProvider] so signOut
    /// can read the correct current selection.
    Future<({ProviderContainer container, _FakeSyncService fakeService})>
    buildContainer({
      required CloudProviderType? initialProvider,
      _MemoryCredentialsStore? store,
    }) async {
      SharedPreferences.setMockInitialValues({
        if (initialProvider != null) 'sync_last_provider': initialProvider.name,
      });
      final prefs = await SharedPreferences.getInstance();
      final credStore = store ?? _MemoryCredentialsStore();
      final fakeRepo = _FakeSyncRepository();
      final fakeSvc = _FakeSyncService(fakeRepo);
      final s3Provider = S3StorageProvider(store: credStore);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          syncRepositoryProvider.overrideWithValue(fakeRepo),
          syncServiceProvider.overrideWithValue(fakeSvc),
          s3StorageProviderInstanceProvider.overrideWithValue(s3Provider),
          selectedCloudProviderTypeProvider.overrideWith(
            (ref) => initialProvider,
          ),
          isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      // Allow _initialize / refreshState to complete.
      await container.read(syncStateProvider.notifier).refreshState();
      return (container: container, fakeService: fakeSvc);
    }

    test('S3 signOut does NOT call syncService.signOut', () async {
      final credStore = _MemoryCredentialsStore()
        ..stored = S3Config(
          endpoint: 'http://nas.local:9000',
          bucket: 'dive-sync',
          accessKeyId: 'ak',
          secretAccessKey: 'sk',
        );

      final (:container, fakeService: svc) = await buildContainer(
        initialProvider: CloudProviderType.s3,
        store: credStore,
      );

      await container.read(syncStateProvider.notifier).signOut();

      // The S3 path must NOT touch the cloud sign-out chain.
      expect(svc.signOutCalled, isFalse);
      // ...but it must still clear the sync metadata like a normal
      // sign-out would.
      final repo =
          container.read(syncRepositoryProvider) as _FakeSyncRepository;
      expect(repo.signOutCalls, 1);
    });

    test('S3 signOut preserves stored S3 credentials', () async {
      final credStore = _MemoryCredentialsStore()
        ..stored = S3Config(
          endpoint: 'http://nas.local:9000',
          bucket: 'dive-sync',
          accessKeyId: 'ak',
          secretAccessKey: 'sk',
        );

      final (:container, fakeService: _) = await buildContainer(
        initialProvider: CloudProviderType.s3,
        store: credStore,
      );

      await container.read(syncStateProvider.notifier).signOut();

      // Credentials must survive the deselect.
      expect(credStore.stored, isNotNull);
      expect(credStore.stored!.bucket, 'dive-sync');
    });

    test(
      'S3 signOut deselects provider and clears persisted selection',
      () async {
        final (:container, fakeService: _) = await buildContainer(
          initialProvider: CloudProviderType.s3,
        );

        await container.read(syncStateProvider.notifier).signOut();

        expect(container.read(selectedCloudProviderTypeProvider), isNull);
        // SharedPreferences key must be gone.
        final prefs = container.read(sharedPreferencesProvider);
        expect(prefs.getString('sync_last_provider'), isNull);
      },
    );

    test('non-S3 signOut calls syncService.signOut', () async {
      final (:container, fakeService: svc) = await buildContainer(
        initialProvider: CloudProviderType.googledrive,
      );

      await container.read(syncStateProvider.notifier).signOut();

      expect(svc.signOutCalled, isTrue);
    });
  });
}
