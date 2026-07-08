import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart' show StateNotifier;
import 'package:submersion/features/settings/presentation/pages/troubleshoot_sync_page.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

/// Records the recovery calls the Troubleshoot page routes to the notifier so
/// the tap-through tests can assert each confirm flow fires exactly once. All
/// other SyncNotifier members fall through to noSuchMethod (unused here).
class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier() : super(const SyncState());

  int repairSyncCalls = 0;
  int removeThisDeviceCalls = 0;
  int wipeAllCalls = 0;
  int rebuildCalls = 0;

  /// When set, [rebuildBackendFromThisDevice] models a failure by leaving the
  /// state in [SyncStatus.error] with this message (mirrors the real notifier).
  String? rebuildFailureMessage;

  @override
  Future<void> repairSync() async => repairSyncCalls++;

  @override
  Future<void> removeThisDeviceCloudFiles() async => removeThisDeviceCalls++;

  @override
  Future<void> wipeAllCloudSyncData() async => wipeAllCalls++;

  @override
  Future<void> rebuildBackendFromThisDevice() async {
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
Future<_FakeSyncNotifier> _pump(WidgetTester tester) async {
  final fake = _FakeSyncNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [syncStateProvider.overrideWith((ref) => fake)],
      child: const MaterialApp(home: TroubleshootSyncPage()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('shows Repair Sync action with an explanation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TroubleshootSyncPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Repair Sync'), findsOneWidget);
    // The explanation must reassure the user their dive data is safe.
    expect(find.textContaining('dive data'), findsWidgets);
  });

  testWidgets('shows both cloud-clear actions', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TroubleshootSyncPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remove this device’s cloud files'), findsOneWidget);
    expect(find.text('Wipe all sync data on this backend'), findsOneWidget);
  });

  testWidgets('shows the rebuild-from-this-device action and confirm dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TroubleshootSyncPage())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rebuild backend from this device'), findsOneWidget);

    await tester.tap(find.text('Rebuild backend from this device'));
    await tester.pumpAndSettle();

    // Confirm dialog appears (title ends with '?').
    expect(find.text('Rebuild backend from this device?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Rebuild'), findsOneWidget);
  });

  testWidgets('wipe-all requires typed confirmation', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TroubleshootSyncPage())),
    );
    await tester.pumpAndSettle();

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
    expect(find.text('Removed this device’s cloud files'), findsOneWidget);
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
    expect(find.text('Wiped all sync data'), findsOneWidget);
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
