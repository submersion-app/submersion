import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/presentation/pages/restore_complete_page.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/restore_step.dart';

import '../../../../../helpers/test_app.dart';

class _FakeBackupOp extends StateNotifier<BackupOperationState>
    implements BackupOperationNotifier {
  _FakeBackupOp(super.state);

  void push(BackupOperationState next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget build(_FakeBackupOp fake) => testApp(
    overrides: [backupOperationProvider.overrideWith((ref) => fake)],
    child: const RestoreStep(),
  );

  testWidgets('idle shows the choose-file button', (tester) async {
    await tester.pumpWidget(build(_FakeBackupOp(const BackupOperationState())));
    expect(find.text('Choose backup file'), findsOneWidget);
  });

  testWidgets('cancelled picker returns to idle without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(build(_FakeBackupOp(const BackupOperationState())));
    // FilePicker returns no selection under test; the step must handle it.
    await tester.tap(find.text('Choose backup file'));
    await tester.pumpAndSettle();
    expect(find.text('Restore backup'), findsOneWidget);
    expect(find.text('Choose backup file'), findsOneWidget);
  });

  testWidgets('in-progress shows a spinner and message', (tester) async {
    await tester.pumpWidget(
      build(
        _FakeBackupOp(
          const BackupOperationState(
            status: BackupOperationStatus.inProgress,
            message: 'Restoring backup...',
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Restoring backup...'), findsOneWidget);
    expect(find.text('Choose backup file'), findsNothing);
  });

  testWidgets('error state shows the message and keeps the button', (
    tester,
  ) async {
    await tester.pumpWidget(
      build(
        _FakeBackupOp(
          const BackupOperationState(
            status: BackupOperationStatus.error,
            message: 'Restore failed: bad file',
          ),
        ),
      ),
    );
    expect(find.text('Restore failed: bad file'), findsOneWidget);
    expect(find.text('Choose backup file'), findsOneWidget);
  });

  testWidgets('picking a file opens the restore confirmation dialog', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('restore_step_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final backup = File('${dir.path}/backup.db')..writeAsBytesSync([1, 2, 3]);

    await tester.pumpWidget(
      testApp(
        overrides: [
          backupOperationProvider.overrideWith(
            (ref) => _FakeBackupOp(const BackupOperationState()),
          ),
        ],
        child: RestoreStep(
          pickBackupFile: () async => (path: backup.path, name: 'backup.db'),
        ),
      ),
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('Choose backup file'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.byType(RestoreConfirmationDialog), findsOneWidget);
  });

  testWidgets('restoreComplete transition shows the completion page', (
    tester,
  ) async {
    final fake = _FakeBackupOp(const BackupOperationState());
    await tester.pumpWidget(build(fake));
    await tester.pumpAndSettle();

    fake.push(
      const BackupOperationState(status: BackupOperationStatus.restoreComplete),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RestoreCompletePage), findsOneWidget);
  });
}
