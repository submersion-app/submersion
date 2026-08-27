import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/pages/lock_escape_dialogs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Pumps a host with a button that opens [open] and records its result.
Future<List<Object?>> _pumpDialogHost(
  WidgetTester tester,
  Future<Object?> Function(BuildContext context) open,
) async {
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => results.add(await open(context)),
            child: const Text('OPEN'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  group('start fresh confirmation', () {
    // This dialog gates a destructive action: it sets the user's database
    // aside. The typed confirmation is the only thing standing between a
    // mistaken tap and an apparently-vanished dive log.
    testWidgets('confirm stays disabled until START FRESH is typed exactly', (
      tester,
    ) async {
      final results = await _pumpDialogHost(
        tester,
        (context) => showStartFreshConfirmDialog(context),
      );

      FilledButton confirmButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Set aside and start fresh'),
      );

      expect(confirmButton().onPressed, isNull, reason: 'disabled initially');

      await tester.enterText(find.byType(TextField), 'start fresh');
      await tester.pump();
      expect(
        confirmButton().onPressed,
        isNull,
        reason: 'lowercase must not satisfy the confirmation',
      );

      await tester.enterText(find.byType(TextField), 'START FRESH');
      await tester.pump();
      expect(confirmButton().onPressed, isNotNull);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Set aside and start fresh'),
      );
      await tester.pumpAndSettle();
      expect(results, [true]);
    });

    testWidgets('cancel returns false without confirming', (tester) async {
      final results = await _pumpDialogHost(
        tester,
        (context) => showStartFreshConfirmDialog(context),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(results, [false]);
    });

    testWidgets('explains that nothing is deleted and sync is turned off', (
      tester,
    ) async {
      await _pumpDialogHost(
        tester,
        (context) => showStartFreshConfirmDialog(context),
      );
      expect(find.textContaining('nothing is deleted'), findsOneWidget);
      expect(find.textContaining('Cloud sync will be'), findsOneWidget);
    });
  });

  group('recovery code unlock', () {
    testWidgets('shows an inline error when the code is rejected, then pops '
        'true once accepted', (tester) async {
      var accept = false;
      final submitted = <String>[];
      final results = await _pumpDialogHost(
        tester,
        (context) => showRecoveryCodeUnlockDialog(
          context,
          onSubmit: (code) async {
            submitted.add(code);
            return accept;
          },
        ),
      );

      await tester.enterText(find.byType(TextField), 'wrong-code');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();
      expect(submitted, ['wrong-code']);
      expect(find.text('Incorrect recovery code.'), findsOneWidget);
      expect(results, isEmpty, reason: 'must stay open on rejection');

      accept = true;
      await tester.enterText(find.byType(TextField), 'right-code');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();
      expect(results, [true]);
    });
  });

  group('forced password reset', () {
    testWidgets('rejects a mismatch and a too-short password, then submits', (
      tester,
    ) async {
      final submitted = <String>[];
      await _pumpDialogHost(
        tester,
        (context) => showForcedPasswordResetDialog(
          context,
          onSubmit: (pw) async => submitted.add(pw),
        ),
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'ab');
      await tester.enterText(fields.at(1), 'ab');
      await tester.tap(find.widgetWithText(FilledButton, 'Set password'));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 4 characters'), findsOneWidget);
      expect(submitted, isEmpty);

      await tester.enterText(fields.at(0), 'good-password');
      await tester.enterText(fields.at(1), 'different');
      await tester.tap(find.widgetWithText(FilledButton, 'Set password'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(submitted, isEmpty);

      await tester.enterText(fields.at(1), 'good-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Set password'));
      await tester.pumpAndSettle();
      expect(submitted, ['good-password']);
    });
  });

  group('sidecar repair', () {
    testWidgets('states that the entered password becomes the app password', (
      tester,
    ) async {
      await _pumpDialogHost(
        tester,
        (context) =>
            showSidecarRepairDialog(context, onSubmit: (_) async => true),
      );
      // The trust anchor here is the keychain, not the password, so the copy
      // must not imply the old password is being verified.
      expect(find.textContaining('becomes the app password'), findsOneWidget);
    });
  });

  group('new recovery code display', () {
    testWidgets('shows the code and dismisses on confirm', (tester) async {
      await _pumpDialogHost(
        tester,
        (context) => showNewRecoveryCodeDialog(context, 'alpha-bravo-charlie'),
      );
      expect(find.text('alpha-bravo-charlie'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'I saved my recovery code'),
      );
      await tester.pumpAndSettle();
      expect(find.text('alpha-bravo-charlie'), findsNothing);
    });
  });
}
