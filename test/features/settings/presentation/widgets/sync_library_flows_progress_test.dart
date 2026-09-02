import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart' show StateNotifier;
import 'package:submersion/core/services/screen_awake.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/adopt_replaced_library_dialog.dart';
import 'package:submersion/features/settings/presentation/widgets/replace_cloud_library_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #1194: replacing the cloud library and adopting a replaced one each
/// run a whole-library safety backup and then a whole-library transfer, and
/// both used to happen behind a live page. The user saw nothing, so they had
/// no reason not to walk away and let the phone lock, which suspended the very
/// work they had been told to wait for.

/// No-op database adapter so [_FakeBackupService] never touches a real DB.
class _NoopBackupAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath) async {}

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/noop';

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

class _FakeBackupService extends BackupService {
  _FakeBackupService(BackupPreferences prefs)
    : super(dbAdapter: _NoopBackupAdapter(), preferences: prefs);

  int performBackupCalls = 0;

  /// When set, the backup blocks on it, so a test can inspect the screen while
  /// the first phase is still running.
  Completer<void>? gate;

  @override
  Future<BackupRecord> performBackup({bool isAutomatic = false}) async {
    performBackupCalls++;
    await gate?.future;
    return BackupRecord(
      id: 'fake-safety',
      filename: 'fake.db',
      timestamp: DateTime(2026),
      sizeBytes: 1,
      location: BackupLocation.local,
    );
  }
}

class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier() : super(const SyncState());

  int replaceCalls = 0;
  int adoptCalls = 0;

  @override
  Future<void> replaceCloudLibraryFromThisDevice() async => replaceCalls++;

  @override
  Future<void> adoptReplacedLibrary() async => adoptCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

typedef _Handles = ({_FakeBackupService backup, _FakeSyncNotifier sync});

void main() {
  late List<bool> toggles;

  setUp(() {
    toggles = [];
    ScreenAwake.debugToggle = ({required bool enable}) async =>
        toggles.add(enable);
  });

  tearDown(ScreenAwake.debugReset);

  /// Pumps a page whose one button opens [open], with fake backup and sync.
  Future<_Handles> pump(
    WidgetTester tester,
    Future<void> Function(BuildContext context, WidgetRef ref) open,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final backup = _FakeBackupService(
      BackupPreferences(await SharedPreferences.getInstance()),
    );
    final sync = _FakeSyncNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupServiceProvider.overrideWithValue(backup),
          syncStateProvider.overrideWith((ref) => sync),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => open(context, ref),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (backup: backup, sync: sync);
  }

  testWidgets('replacing the cloud library reports both of its phases', (
    tester,
  ) async {
    final handles = await pump(
      tester,
      (context, ref) => showReplaceCloudLibraryDialog(
        context,
        ref,
        const ReplacePreflight(localDiveCount: 12, peerFileCount: 1),
      ),
    );
    final gate = Completer<void>();
    handles.backup.gate = gate;

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Replace');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
    await tester.pump();

    expect(find.text('Replacing the cloud library'), findsOneWidget);
    expect(
      find.text('Backing up this device'),
      findsOneWidget,
      reason: 'the safety backup is minutes of work with nothing on screen',
    );
    expect(find.textContaining('Keep the app open'), findsOneWidget);
    expect(toggles, [true]);
    expect(handles.sync.replaceCalls, 0, reason: 'still backing up');

    gate.complete();
    await tester.pumpAndSettle();

    expect(handles.backup.performBackupCalls, 1);
    expect(handles.sync.replaceCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(toggles, [true, false]);
  });

  testWidgets('adopting a restored library reports both of its phases', (
    tester,
  ) async {
    final handles = await pump(
      tester,
      (context, ref) => showAdoptReplacedLibraryDialog(
        context,
        ref,
        const LibraryEpochMarker(
          epochId: 'e1',
          replacedAt: 1764000000000,
          deviceId: 'd1',
          deviceName: 'Eric Mac',
        ),
      ),
    );
    final gate = Completer<void>();
    handles.backup.gate = gate;

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adopt Restored Library'));
    await tester.pump();

    expect(find.text('Adopting the restored library'), findsOneWidget);
    expect(find.text('Backing up this device'), findsOneWidget);
    expect(toggles, [true]);
    expect(handles.sync.adoptCalls, 0, reason: 'still backing up');

    gate.complete();
    await tester.pumpAndSettle();

    expect(handles.backup.performBackupCalls, 1);
    expect(handles.sync.adoptCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(toggles, [true, false]);
  });

  testWidgets('declining adoption runs nothing and takes no lock', (
    tester,
  ) async {
    final handles = await pump(
      tester,
      (context, ref) => showAdoptReplacedLibraryDialog(
        context,
        ref,
        const LibraryEpochMarker(
          epochId: 'e1',
          replacedAt: 1764000000000,
          deviceId: 'd1',
          deviceName: 'Eric Mac',
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();

    expect(handles.backup.performBackupCalls, 0);
    expect(handles.sync.adoptCalls, 0);
    expect(toggles, isEmpty);
  });
}
