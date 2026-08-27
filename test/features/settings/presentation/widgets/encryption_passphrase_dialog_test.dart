import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/features/settings/presentation/widgets/encryption_passphrase_dialog.dart';

import '../../../../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mounts a button that opens [dialog] and records the resolved value.
  Future<void> pumpOpener(
    WidgetTester tester,
    Future<Object?> Function(BuildContext context) dialog,
    List<Object?> sink,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async => sink.add(await dialog(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('showEncryptionPassphraseDialog', () {
    testWidgets('submits the secret and pops with it', (tester) async {
      final results = <Object?>[];
      String? seen;
      await pumpOpener(
        tester,
        (context) => showEncryptionPassphraseDialog(
          context,
          title: 'Enter key',
          onSubmit: (secret) async => seen = secret,
        ),
        results,
      );

      await tester.enterText(find.byType(TextField), 'my secret');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();

      expect(seen, 'my secret');
      expect(results.single, 'my secret');
    });

    testWidgets(
      'success navigation that clears the stack does not over-pop the navigator',
      (tester) async {
        // Reproduces the encrypted-restore crash: on a successful restore the
        // page listener runs RestoreCompletePage.show(), which does
        // pushAndRemoveUntil(..., (_) => false) -- wiping every route including
        // this dialog and leaving exactly one route. The dialog's own success
        // pop then removed that last route, emptying the navigator history and
        // tripping `NavigatorState.build`'s `_history.isNotEmpty` assertion.
        await tester.pumpWidget(
          testApp(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEncryptionPassphraseDialog(
                  context,
                  title: 'Enter key',
                  onSubmit: (_) async {
                    Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(body: Text('restored')),
                      ),
                      (_) => false,
                    );
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'correct');
        await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('restored'), findsOneWidget);
      },
    );

    testWidgets('empty input does not call onSubmit', (tester) async {
      var calls = 0;
      await pumpOpener(
        tester,
        (context) => showEncryptionPassphraseDialog(
          context,
          title: 'Enter key',
          onSubmit: (_) async => calls++,
        ),
        <Object?>[],
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      // Dialog stays open.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('wrong passphrase shows inline error and stays open', (
      tester,
    ) async {
      await pumpOpener(
        tester,
        (context) => showEncryptionPassphraseDialog(
          context,
          title: 'Enter key',
          onSubmit: (_) async => throw const WrongPassphraseException(),
        ),
        <Object?>[],
      );

      await tester.enterText(find.byType(TextField), 'bad');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();

      expect(
        find.text('Incorrect passphrase or recovery code'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('generic error is surfaced inline', (tester) async {
      await pumpOpener(
        tester,
        (context) => showEncryptionPassphraseDialog(
          context,
          title: 'Enter key',
          onSubmit: (_) async => throw Exception('boom'),
        ),
        <Object?>[],
      );

      await tester.enterText(find.byType(TextField), 'x');
      await tester.tap(find.widgetWithText(FilledButton, 'Unlock'));
      await tester.pumpAndSettle();

      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('cancel returns null without calling onSubmit', (tester) async {
      final results = <Object?>[];
      var calls = 0;
      await pumpOpener(
        tester,
        (context) => showEncryptionPassphraseDialog(
          context,
          title: 'Enter key',
          onSubmit: (_) async => calls++,
        ),
        results,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(results.single, isNull);
    });

    testWidgets('submitting via the keyboard action works', (tester) async {
      String? seen;
      await pumpOpener(
        tester,
        (context) => showEncryptionPassphraseDialog(
          context,
          title: 'Enter key',
          onSubmit: (secret) async => seen = secret,
        ),
        <Object?>[],
      );

      await tester.enterText(find.byType(TextField), 'kbd');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(seen, 'kbd');
    });
  });

  group('showChangePassphraseDialog', () {
    Future<void> openChange(
      WidgetTester tester,
      Future<void> Function(String current, String next) onSubmit,
      List<Object?> sink,
    ) => pumpOpener(
      tester,
      (context) => showChangePassphraseDialog(context, onSubmit: onSubmit),
      sink,
    );

    Finder fieldFor(String label) => find.widgetWithText(TextField, label);

    testWidgets('too-short new passphrase blocks submit', (tester) async {
      var calls = 0;
      await openChange(tester, (_, _) async => calls++, <Object?>[]);

      await tester.enterText(fieldFor('Current passphrase'), 'oldsecret1');
      await tester.enterText(fieldFor('New passphrase'), 'short');
      await tester.enterText(fieldFor('Confirm passphrase'), 'short');
      await tester.tap(find.widgetWithText(FilledButton, 'Change passphrase'));
      await tester.pumpAndSettle();

      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('mismatched confirm blocks submit', (tester) async {
      var calls = 0;
      await openChange(tester, (_, _) async => calls++, <Object?>[]);

      await tester.enterText(fieldFor('Current passphrase'), 'oldsecret1');
      await tester.enterText(fieldFor('New passphrase'), 'newsecret1');
      await tester.enterText(fieldFor('Confirm passphrase'), 'different1');
      await tester.tap(find.widgetWithText(FilledButton, 'Change passphrase'));
      await tester.pumpAndSettle();

      expect(find.text('Passphrases do not match'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('valid change calls onSubmit and returns true', (tester) async {
      final results = <Object?>[];
      String? gotCurrent;
      String? gotNext;
      await openChange(tester, (current, next) async {
        gotCurrent = current;
        gotNext = next;
      }, results);

      await tester.enterText(fieldFor('Current passphrase'), 'oldsecret1');
      await tester.enterText(fieldFor('New passphrase'), 'newsecret1');
      await tester.enterText(fieldFor('Confirm passphrase'), 'newsecret1');
      await tester.tap(find.widgetWithText(FilledButton, 'Change passphrase'));
      await tester.pumpAndSettle();

      expect(gotCurrent, 'oldsecret1');
      expect(gotNext, 'newsecret1');
      expect(results.single, isTrue);
    });

    testWidgets('wrong current passphrase shows an inline error', (
      tester,
    ) async {
      await openChange(
        tester,
        (_, _) async => throw const WrongPassphraseException(),
        <Object?>[],
      );

      await tester.enterText(fieldFor('Current passphrase'), 'wrong1234');
      await tester.enterText(fieldFor('New passphrase'), 'newsecret1');
      await tester.enterText(fieldFor('Confirm passphrase'), 'newsecret1');
      await tester.tap(find.widgetWithText(FilledButton, 'Change passphrase'));
      await tester.pumpAndSettle();

      expect(
        find.text('Incorrect passphrase or recovery code'),
        findsOneWidget,
      );
    });

    testWidgets('generic error surfaces on the current field', (tester) async {
      await openChange(
        tester,
        (_, _) async => throw Exception('kaboom'),
        <Object?>[],
      );

      await tester.enterText(fieldFor('Current passphrase'), 'oldsecret1');
      await tester.enterText(fieldFor('New passphrase'), 'newsecret1');
      await tester.enterText(fieldFor('Confirm passphrase'), 'newsecret1');
      await tester.tap(find.widgetWithText(FilledButton, 'Change passphrase'));
      await tester.pumpAndSettle();

      expect(find.textContaining('kaboom'), findsOneWidget);
    });

    testWidgets('cancel returns false', (tester) async {
      final results = <Object?>[];
      await openChange(tester, (_, _) async {}, results);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(results.single, isFalse);
    });
  });
}
