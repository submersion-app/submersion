import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/restore_mode.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_confirmation_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final record = BackupRecord(
    id: 'temp',
    filename: 'backup.db',
    timestamp: DateTime(2026, 6, 1, 12),
    sizeBytes: 1024,
    location: BackupLocation.local,
    diveCount: 5,
    siteCount: 2,
  );

  /// Pumps a host app with an "open" button that shows the dialog and
  /// captures its result. Returns a getter for the captured result.
  Future<RestoreMode? Function()> pumpAndOpen(
    WidgetTester tester, {
    required bool offerReplace,
  }) async {
    RestoreMode? result;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await RestoreConfirmationDialog.show(
                context,
                record,
                currentSchemaVersion: 80,
                offerReplace: offerReplace,
              );
              completed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () {
      expect(completed, isTrue, reason: 'dialog must have closed');
      return result;
    };
  }

  testWidgets('without offerReplace there is no mode choice', (tester) async {
    final getResult = await pumpAndOpen(tester, offerReplace: false);
    expect(find.text('Merge on next sync'), findsNothing);
    expect(find.text('Replace everywhere'), findsNothing);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(getResult(), RestoreMode.merge);
  });

  testWidgets('confirming with merge selected returns merge', (tester) async {
    final getResult = await pumpAndOpen(tester, offerReplace: true);
    expect(find.text('Merge on next sync'), findsOneWidget);
    expect(find.text('Replace everywhere'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(getResult(), RestoreMode.merge);
  });

  testWidgets('replace requires the second confirmation', (tester) async {
    final getResult = await pumpAndOpen(tester, offerReplace: true);

    await tester.tap(find.text('Replace everywhere'));
    await tester.pumpAndSettle();
    expect(find.text('Restore and Replace Everywhere'), findsOneWidget);

    await tester.tap(find.text('Restore and Replace Everywhere'));
    await tester.pumpAndSettle();
    expect(find.text('Replace Library Everywhere?'), findsOneWidget);

    await tester.tap(find.text('Replace Everywhere'));
    await tester.pumpAndSettle();
    expect(getResult(), RestoreMode.replace);
  });

  testWidgets('cancelling the second confirmation keeps the dialog open', (
    tester,
  ) async {
    await pumpAndOpen(tester, offerReplace: true);

    await tester.tap(find.text('Replace everywhere'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore and Replace Everywhere'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    // Back on the restore dialog, nothing resolved.
    expect(find.text('Restore and Replace Everywhere'), findsOneWidget);
  });

  testWidgets('cancel returns null', (tester) async {
    final getResult = await pumpAndOpen(tester, offerReplace: true);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(getResult(), isNull);
  });
}
