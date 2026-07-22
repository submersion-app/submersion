import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/app.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart'
    show DeviceIdentityStatus;
import 'package:submersion/core/services/sync/sync_service.dart'
    show ConflictResolution;
import 'package:submersion/features/backup/presentation/pages/restore_complete_page.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import 'helpers/mock_providers.dart';

/// A [SyncNotifier] stand-in whose state can be driven directly from a test,
/// so the app-root `ref.listen` callback can be exercised through real state
/// transitions without instantiating the database-backed notifier.
class _DrivableSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _DrivableSyncNotifier(super.state);

  /// Push a new state, firing listeners exactly as the real notifier would.
  void emit(SyncState next) => state = next;

  @override
  Future<void> performSync({bool auto = false}) async {}

  @override
  Future<void> disableForDatabaseReset() async {}

  @override
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async => null;

  @override
  Future<LibraryEpochMarker?> libraryReplaceInfo() async => null;

  @override
  Future<void> adoptReplacedLibrary() async {}

  @override
  Future<void> acknowledgeMoved() async {}

  @override
  Future<void> checkLibraryMoved() async {}

  @override
  Future<void> cleanupOldBackendData() async {}

  @override
  Future<void> dismissOldBackendCleanup() async {}

  @override
  Future<void> recordBackendDeparture({
    required CloudStorageProvider oldProvider,
    required String toProviderId,
    String? toProviderName,
  }) async {}

  @override
  Future<void> refreshState() async {}

  @override
  Future<void> resetSyncState() async {}

  @override
  Future<void> repairSync() async {}

  @override
  Future<void> removeThisDeviceCloudFiles() async {}

  @override
  Future<void> wipeAllCloudSyncData() async {}

  @override
  Future<void> rebuildBackendFromThisDevice() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resolveConflict(
    String entityType,
    String recordId,
    ConflictResolution resolution,
  ) async {}
}

/// A [BackupOperationNotifier] stand-in so a test can drive the app-root
/// restore-completion listener through real state transitions.
class _DrivableBackupOp extends StateNotifier<BackupOperationState>
    implements BackupOperationNotifier {
  _DrivableBackupOp() : super(const BackupOperationState());

  void emit(BackupOperationState next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal router wired to the real [rootNavigatorKey] so the app-root adopt
/// dialog (which reads `rootNavigatorKey.currentContext`) can surface.
GoRouter _testRouter() => GoRouter(
  navigatorKey: rootNavigatorKey,
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
    ),
  ],
);

LibraryEpochMarker _marker() => const LibraryEpochMarker(
  epochId: 'epoch-1',
  replacedAt: 1700000000000,
  deviceId: 'device-1',
  deviceName: 'Eric Mac',
);

void main() {
  /// Pumps [SubmersionApp] with the providers its build/launch path reads
  /// stubbed out, leaving [sync] as the driver for the app-root listener.
  Future<void> pumpApp(
    WidgetTester tester,
    _DrivableSyncNotifier sync, {
    _DrivableBackupOp? backupOp,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          appRouterProvider.overrideWithValue(_testRouter()),
          syncStateProvider.overrideWith((ref) => sync),
          if (backupOp != null)
            backupOperationProvider.overrideWith((ref) => backupOp),
          reconcileDeviceIdentityProvider.overrideWith(
            (ref) async => DeviceIdentityStatus.unchanged,
          ),
          restoreLastProviderProvider.overrideWith((ref) async {}),
        ],
        child: const SubmersionApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the post-restore syncing notice when sync begins', (
    tester,
  ) async {
    final sync = _DrivableSyncNotifier(const SyncState());
    await pumpApp(tester, sync);

    sync.emit(const SyncState(postRestoreSyncing: true));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Syncing your restored library with the cloud…'),
      findsOneWidget,
    );
  });

  testWidgets('shows the synced notice when the post-restore sync completes', (
    tester,
  ) async {
    final sync = _DrivableSyncNotifier(
      const SyncState(postRestoreSyncing: true),
    );
    await pumpApp(tester, sync);

    sync.emit(const SyncState(status: SyncStatus.success));
    await tester.pump();
    await tester.pump();

    expect(find.text('Restored library synced.'), findsOneWidget);
  });

  testWidgets('also surfaces the synced notice on a conflict outcome', (
    tester,
  ) async {
    final sync = _DrivableSyncNotifier(
      const SyncState(postRestoreSyncing: true),
    );
    await pumpApp(tester, sync);

    sync.emit(const SyncState(status: SyncStatus.hasConflicts));
    await tester.pump();
    await tester.pump();

    expect(find.text('Restored library synced.'), findsOneWidget);
  });

  testWidgets('surfaces the replaced-library banner and adopt dialog', (
    tester,
  ) async {
    final sync = _DrivableSyncNotifier(const SyncState());
    await pumpApp(tester, sync);

    sync.emit(
      SyncState(replaceAwaitingAdoption: true, replaceMarker: _marker()),
    );
    await tester.pumpAndSettle();

    // Persistent banner rides across screens.
    expect(find.textContaining('Sync is paused'), findsOneWidget);
    // Once-per-session modal auto-opens.
    expect(find.text('Adopt Restored Library?'), findsOneWidget);
  });

  testWidgets('does not surface a banner when the replace marker is missing', (
    tester,
  ) async {
    final sync = _DrivableSyncNotifier(const SyncState());
    await pumpApp(tester, sync);

    // replaceAwaitingAdoption with no marker is a no-op (guard clause).
    sync.emit(const SyncState(replaceAwaitingAdoption: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sync is paused'), findsNothing);
    expect(find.text('Adopt Restored Library?'), findsNothing);
  });

  testWidgets('clears the banner once adoption is resolved', (tester) async {
    final sync = _DrivableSyncNotifier(const SyncState());
    await pumpApp(tester, sync);

    sync.emit(
      SyncState(replaceAwaitingAdoption: true, replaceMarker: _marker()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Sync is paused'), findsOneWidget);

    // Dismiss the auto-opened modal, leaving the banner behind.
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();

    sync.emit(const SyncState());
    await tester.pumpAndSettle();

    expect(find.textContaining('Sync is paused'), findsNothing);
  });

  testWidgets('restore completion routes to RestoreCompletePage app-wide', (
    tester,
  ) async {
    // Even though no page-local listener is involved, a restoreComplete
    // transition on the operation provider must hand off to RestoreCompletePage
    // from the app root -- so a restore whose triggering page was disposed
    // still restarts instead of stranding the user on a stale screen.
    final sync = _DrivableSyncNotifier(const SyncState());
    final backupOp = _DrivableBackupOp();
    await pumpApp(tester, sync, backupOp: backupOp);

    expect(find.byType(RestoreCompletePage), findsNothing);

    backupOp.emit(
      const BackupOperationState(status: BackupOperationStatus.restoreComplete),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RestoreCompletePage), findsOneWidget);
  });

  testWidgets('the banner Review action reopens the adopt dialog', (
    tester,
  ) async {
    final sync = _DrivableSyncNotifier(const SyncState());
    await pumpApp(tester, sync);

    sync.emit(
      SyncState(replaceAwaitingAdoption: true, replaceMarker: _marker()),
    );
    await tester.pumpAndSettle();

    // Close the once-per-session auto modal; the banner persists.
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(find.text('Adopt Restored Library?'), findsNothing);

    // Tapping the banner's Review action reopens the dialog.
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Adopt Restored Library?'), findsOneWidget);
  });
}
