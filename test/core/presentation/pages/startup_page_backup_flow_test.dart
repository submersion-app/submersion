import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/presentation/widgets/backup_status_views.dart';
import 'package:submersion/features/backup/domain/exceptions/backup_failed_exception.dart';

void main() {
  testWidgets('BackingUpView shows spinner + explanation copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BackingUpView())),
    );
    expect(find.text('Backing up your data'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('before updating'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Cancel'), findsNothing);
  });

  testWidgets('BackupFailedView surfaces classified message + Retry and Quit', (
    tester,
  ) async {
    var retried = 0;
    var quit = 0;
    const error = BackupFailedException(
      cause: BackupFailureCause.diskFull,
      userMessage: 'Not enough free disk space to back up your data.',
      technicalDetails: 'FileSystemException(28)',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupFailedView(
            error: error,
            onRetry: () => retried++,
            onQuit: () => quit++,
          ),
        ),
      ),
    );
    expect(find.text("Couldn't back up your data"), findsOneWidget);
    expect(
      find.text('Not enough free disk space to back up your data.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pump();
    expect(retried, 1);
    expect(quit, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Quit'));
    await tester.pump();
    expect(quit, 1);
  });

  testWidgets('BackupFailedView technical details are hidden until expanded', (
    tester,
  ) async {
    const error = BackupFailedException(
      cause: BackupFailureCause.unknown,
      userMessage: 'Backup failed: something odd.',
      technicalDetails: 'unique-detail-12345',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupFailedView(error: error, onRetry: () {}, onQuit: () {}),
        ),
      ),
    );
    expect(find.text('unique-detail-12345'), findsNothing);
    await tester.tap(find.text('Technical details'));
    await tester.pumpAndSettle();
    expect(find.text('unique-detail-12345'), findsOneWidget);
  });
}
