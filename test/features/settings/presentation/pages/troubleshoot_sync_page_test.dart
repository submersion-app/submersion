import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart' show StateNotifier;
import 'package:submersion/core/services/screen_awake.dart';
import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/settings/presentation/pages/troubleshoot_sync_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// A key notifier pre-seeded with an unlocked session, so the page renders the
/// "Encryption is on" state without running real crypto.
class _SeededKeyNotifier extends EncryptionKeyNotifier {
  _SeededKeyNotifier(
    super.keyStore,
    super.preferences,
    EncryptionSessionState seeded,
  ) {
    state = seeded;
  }
}

/// Records the recovery calls the Troubleshoot page routes to the notifier so
/// the tap-through tests can assert each confirm flow fires exactly once. All
/// other SyncNotifier members fall through to noSuchMethod (unused here).
class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier() : super(const SyncState());

  int repairSyncCalls = 0;

  /// When set, [repairSync] blocks on it, so a test can inspect the screen
  /// while the repair is still running.
  Completer<void>? repairGate;

  int removeThisDeviceCalls = 0;
  int wipeAllCalls = 0;
  int rebuildCalls = 0;

  /// When set, [rebuildBackendFromThisDevice] models a failure by leaving the
  /// state in [SyncStatus.error] with this message (mirrors the real notifier).
  String? rebuildFailureMessage;

  /// What the cleanup calls report back. Defaults to a clean no-op; tests that
  /// care about partial failure override it (issue #1032).
  SyncCleanupOutcome cleanupOutcome = const SyncCleanupOutcome();

  @override
  Future<void> repairSync() async {
    repairSyncCalls++;
    await repairGate?.future;
  }

  @override
  Future<SyncCleanupOutcome> removeThisDeviceCloudFiles({
    SyncCleanupProgress? onProgress,
  }) async {
    removeThisDeviceCalls++;
    return cleanupOutcome;
  }

  @override
  Future<SyncCleanupOutcome> wipeAllCloudSyncData({
    SyncCleanupProgress? onProgress,
  }) async {
    wipeAllCalls++;
    return cleanupOutcome;
  }

  @override
  Future<void> rebuildBackendFromThisDevice({
    SyncCleanupProgress? onProgress,
    void Function()? onPublishStarted,
  }) async {
    rebuildCalls++;
    final msg = rebuildFailureMessage;
    if (msg != null) {
      state = SyncState(status: SyncStatus.error, message: msg);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pumps the page with [fake] backing syncStateProvider. Returns the fake.
/// SharedPreferences backs the encryption-status row (preference flag read).
/// The page is a ListView of tall, wordy tiles and keeps gaining rows (the
/// device browser landed in #1032). Off-screen ListView children are never
/// built, so on the default 800x600 surface the last action silently stops
/// existing and every finder for it reports "found 0". Give the tests room for
/// the whole page rather than teaching each one to scroll.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<_FakeSyncNotifier> _pump(WidgetTester tester) async {
  final fake = _FakeSyncNotifier();
  _useTallSurface(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        syncStateProvider.overrideWith((ref) => fake),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TroubleshootSyncPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

/// Pump without a fake notifier, for display-only assertions. Preferences
/// still need backing (the encryption-status row reads the flag).
Future<void> _pumpBare(WidgetTester tester) async {
  _useTallSurface(tester);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TroubleshootSyncPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows Repair Sync action with an explanation', (tester) async {
    await _pumpBare(tester);

    expect(find.text('Repair Sync'), findsOneWidget);
    // The explanation must reassure the user their dive data is safe.
    expect(find.textContaining('dive data'), findsWidgets);
  });

  testWidgets('encryption status row shows Off by default', (tester) async {
    await _pumpBare(tester);
    expect(find.text('End-to-end encryption'), findsOneWidget);
    expect(find.text('Encryption is off'), findsOneWidget);
  });

  testWidgets('encryption status row shows the locked state when enabled '
      'without a session', (tester) async {
    SharedPreferences.setMockInitialValues({'sync_encryption_enabled': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TroubleshootSyncPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Enter the passphrase to sync on this device'),
      findsOneWidget,
    );
  });

  testWidgets('encryption status row shows On when enabled and unlocked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'sync_encryption_enabled': true});
    final prefs = await SharedPreferences.getInstance();
    final session = EncryptionSessionState(
      key: UnlockedKey(
        libraryKeyId: 'k',
        mlk: SecretKey(List<int>.filled(32, 1)),
      ),
      dataKey: SecretKey(List<int>.filled(32, 2)),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          encryptionKeyNotifierProvider.overrideWith(
            (ref) => _SeededKeyNotifier(
              ref.watch(encryptionKeyStoreProvider),
              ref.watch(syncPreferencesProvider),
              session,
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TroubleshootSyncPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Encryption is on'), findsOneWidget);
  });

  testWidgets('tapping the locked encryption row runs the unlock flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'sync_encryption_enabled': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // No provider configured: the unlock flow bails without a dialog,
          // but the row's onTap closure still executes.
          cloudStorageProviderProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TroubleshootSyncPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('End-to-end encryption'));
    await tester.pumpAndSettle();
    // With no cloud provider the unlock flow returns without opening a dialog.
    expect(find.widgetWithText(FilledButton, 'Unlock'), findsNothing);
  });

  testWidgets('shows both cloud-clear actions', (tester) async {
    await _pumpBare(tester);

    expect(find.text('Remove this device’s cloud files'), findsOneWidget);
    expect(find.text('Wipe all sync data on this backend'), findsOneWidget);
  });

  testWidgets('shows the rebuild-from-this-device action and confirm dialog', (
    tester,
  ) async {
    await _pumpBare(tester);

    expect(find.text('Rebuild backend from this device'), findsOneWidget);

    await tester.tap(find.text('Rebuild backend from this device'));
    await tester.pumpAndSettle();

    // Confirm dialog appears (title ends with '?').
    expect(find.text('Rebuild backend from this device?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Rebuild'), findsOneWidget);
  });

  testWidgets('wipe-all requires typed confirmation', (tester) async {
    await _pumpBare(tester);

    await tester.tap(find.text('Wipe all sync data on this backend'));
    await tester.pumpAndSettle();

    final confirmBtn = find.widgetWithText(FilledButton, 'Wipe everything');
    expect(
      tester.widget<FilledButton>(confirmBtn).onPressed,
      isNull,
      reason: 'disabled until the confirmation word is typed',
    );

    await tester.enterText(find.byType(TextField), 'WIPE');
    await tester.pump();

    expect(
      tester.widget<FilledButton>(confirmBtn).onPressed,
      isNotNull,
      reason: 'enabled once the user types WIPE',
    );
  });

  // ---------------------------------------------------------------------------
  // Tap-through flows: each confirm invokes the notifier and shows a snackbar.
  // ---------------------------------------------------------------------------

  testWidgets('Repair confirm calls repairSync and shows a snackbar', (
    tester,
  ) async {
    final fake = await _pump(tester);

    await tester.tap(find.text('Repair Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Repair'));
    await tester.pumpAndSettle();

    expect(fake.repairSyncCalls, 1);
    expect(find.text('Sync repaired'), findsOneWidget);
  });

  // Issue #1194: repair ran behind a live page, so a long repair looked like
  // nothing happening and the phone was free to lock and suspend it.
  testWidgets('Repair runs behind the blocking dialog, screen held awake', (
    tester,
  ) async {
    final toggles = <bool>[];
    ScreenAwake.debugToggle = ({required bool enable}) async =>
        toggles.add(enable);
    addTearDown(ScreenAwake.debugReset);

    final fake = await _pump(tester);
    final gate = Completer<void>();
    fake.repairGate = gate;

    await tester.tap(find.text('Repair Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Repair'));
    await tester.pump();

    expect(find.text('Repairing sync'), findsOneWidget);
    expect(find.text('Clearing local sync state'), findsOneWidget);
    expect(
      find.textContaining('Keep the app open'),
      findsOneWidget,
      reason: 'the same promise the other maintenance actions make',
    );
    expect(toggles, [true]);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(toggles, [true, false]);
    expect(find.text('Sync repaired'), findsOneWidget);
  });

  testWidgets('Repair cancel does not call repairSync', (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.text('Repair Sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(fake.repairSyncCalls, 0);
  });

  testWidgets('Rebuild confirm calls rebuildBackendFromThisDevice', (
    tester,
  ) async {
    final fake = await _pump(tester);

    await tester.tap(find.text('Rebuild backend from this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Rebuild'));
    await tester.pumpAndSettle();

    expect(fake.rebuildCalls, 1);
    expect(find.text('Rebuilt backend from this device'), findsOneWidget);
  });

  testWidgets('Rebuild failure shows the error, not a success snackbar', (
    tester,
  ) async {
    final fake = await _pump(tester);
    fake.rebuildFailureMessage = 'No library replacement to rebuild from';

    await tester.tap(find.text('Rebuild backend from this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Rebuild'));
    await tester.pumpAndSettle();

    expect(find.text('No library replacement to rebuild from'), findsOneWidget);
    expect(find.text('Rebuilt backend from this device'), findsNothing);
  });

  testWidgets('Remove-this-device confirm calls the notifier', (tester) async {
    final fake = await _pump(tester);

    await tester.tap(find.text('Remove this device’s cloud files'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(fake.removeThisDeviceCalls, 1);
    // The snackbar now reports what was actually removed rather than asserting
    // success unconditionally (issue #1032). The fake returns an empty outcome.
    expect(find.text('Removed 0 files'), findsOneWidget);
  });

  testWidgets('Wipe-all confirm (after typing WIPE) calls the notifier', (
    tester,
  ) async {
    final fake = await _pump(tester);

    await tester.tap(find.text('Wipe all sync data on this backend'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'WIPE');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Wipe everything'));
    await tester.pumpAndSettle();

    expect(fake.wipeAllCalls, 1);
    expect(find.text('Wiped 0 files'), findsOneWidget);
  });

  testWidgets('a partial wipe says so instead of claiming success', (
    tester,
  ) async {
    // The reported failure mode: the marker listing timed out, files survived,
    // and the app still said "Wiped all sync data" (issue #1032).
    final fake = await _pump(tester);
    fake.cleanupOutcome = const SyncCleanupOutcome(
      deleted: 400,
      failed: 3,
      listIncomplete: true,
    );

    await tester.tap(find.text('Wipe all sync data on this backend'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'WIPE');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Wipe everything'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('3 could not be deleted'),
      findsOneWidget,
      reason: 'the user must learn the backend is not actually clean',
    );
    expect(find.textContaining('could not be listed'), findsOneWidget);
  });

  testWidgets('cancelling each dialog invokes no notifier action', (
    tester,
  ) async {
    final fake = await _pump(tester);

    for (final tile in const [
      'Rebuild backend from this device',
      'Remove this device’s cloud files',
      'Wipe all sync data on this backend',
    ]) {
      await tester.tap(find.text(tile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
    }

    expect(fake.rebuildCalls, 0);
    expect(fake.removeThisDeviceCalls, 0);
    expect(fake.wipeAllCalls, 0);
  });
}
