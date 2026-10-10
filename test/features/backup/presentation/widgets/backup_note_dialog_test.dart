import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/presentation/widgets/backup_note_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  /// Opens the dialog from a host button; the returned getter checks the
  /// dialog closed and hands back what it returned.
  Future<BackupNoteResult? Function()> open(WidgetTester tester) async {
    BackupNoteResult? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        // Pinned: flutter_test forwards the host machine's locale list, and
        // the English assertions below would find nothing on a translated
        // build.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await BackupNoteDialog.show(context);
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () {
      expect(closed, isTrue, reason: 'the dialog must have closed');
      return result;
    };
  }

  testWidgets('Cancel returns null so no backup runs', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });

  testWidgets('Back Up with an empty field backs up without a note', (
    tester,
  ) async {
    final result = await open(tester);
    await tester.tap(find.text('Back Up'));
    await tester.pumpAndSettle();
    expect(result(), isNotNull);
    expect(result()!.note, isNull);
  });

  testWidgets('the typed note is returned trimmed', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), '  Before the trip  ');
    await tester.tap(find.text('Back Up'));
    await tester.pumpAndSettle();
    expect(result()!.note, 'Before the trip');
  });

  testWidgets('Enter submits', (tester) async {
    final result = await open(tester);
    await tester.enterText(find.byType(TextField), 'Quick');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result()!.note, 'Quick');
  });

  testWidgets('the field shows its label and caps its length', (tester) async {
    await open(tester);
    expect(find.text('Back up now'), findsOneWidget);
    expect(find.text('Note (optional)'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 200);
  });
}
