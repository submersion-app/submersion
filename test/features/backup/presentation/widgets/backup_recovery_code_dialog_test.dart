import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/backup/presentation/widgets/backup_recovery_code_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _open(WidgetTester tester, {required String code}) async {
  await tester.pumpWidget(
    MaterialApp(
      // Pinned: the assertions match English strings.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showBackupRecoveryCodeDialog(context, code: code),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

FilledButton _doneButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'));

void main() {
  testWidgets('shows the code and gates Done behind the saved checkbox', (
    tester,
  ) async {
    await _open(tester, code: 'alpha-bravo-charlie-delta');

    expect(find.textContaining('alpha-bravo-charlie-delta'), findsOneWidget);
    // Done stays disabled until the user confirms they saved the code.
    expect(_doneButton(tester).onPressed, isNull);

    // Tapping Done while gated is a no-op: the dialog remains.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(BackupRecoveryCodeDialog), findsOneWidget);
  });

  testWidgets('ticking the checkbox enables Done and dismisses the dialog', (
    tester,
  ) async {
    await _open(tester, code: 'echo-foxtrot-golf-hotel');

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(_doneButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(BackupRecoveryCodeDialog), findsNothing);
  });

  testWidgets('is not dismissible by tapping the barrier', (tester) async {
    await _open(tester, code: 'india-juliet-kilo-lima');

    // Tap top-left, well outside the dialog: barrierDismissible is false, so
    // the recovery code cannot be discarded by a stray tap.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(BackupRecoveryCodeDialog), findsOneWidget);
  });
}
