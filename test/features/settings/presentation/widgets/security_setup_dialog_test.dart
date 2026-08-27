import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/theme/full_themes/submersion_theme.dart';
import 'package:submersion/features/settings/presentation/widgets/security_setup_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<List<Object?>> _pumpSetup(
  WidgetTester tester, {
  required Future<String> Function(String password) onSetPassword,
  ThemeData? theme,
}) async {
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => results.add(
              await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    SecuritySetupDialog(onSetPassword: onSetPassword),
              ),
            ),
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
  testWidgets('keeps the confirm field clear of the password field above it', (
    tester,
  ) async {
    // The app theme uses filled fields with an OutlineInputBorder. Flutter
    // floats such a label so it straddles the top border and reserves no
    // space above the box for it, so two fields stacked flush let the confirm
    // label paint over the password field. Pump the real theme, not a bare
    // MaterialApp, or the overlap cannot reproduce.
    await _pumpSetup(
      tester,
      theme: submersionLight,
      onSetPassword: (_) async => 'a-b-c-d',
    );

    // Both labels must be floating: that is the state the overlap appears in.
    await tester.enterText(find.byType(TextField).at(0), 'hunter2!');
    await tester.enterText(find.byType(TextField).at(1), 'hunter2!');
    await tester.pumpAndSettle();

    final passwordField = tester.getRect(find.byType(TextField).at(0));
    final confirmLabel = tester.getRect(find.text('Confirm password'));

    expect(
      confirmLabel.top,
      greaterThanOrEqualTo(passwordField.bottom),
      reason:
          'the floating "Confirm password" label paints ${passwordField.bottom - confirmLabel.top}px '
          'inside the password field above it',
    );
  });

  testWidgets('rejects a short password and a mismatch before minting a key', (
    tester,
  ) async {
    var calls = 0;
    await _pumpSetup(
      tester,
      onSetPassword: (_) async {
        calls++;
        return 'a-b-c-d-e-f-g-h';
      },
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ab');
    await tester.enterText(fields.at(1), 'ab');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('at least 4 characters'), findsOneWidget);
    expect(calls, 0, reason: 'must not mint a key for an invalid password');

    await tester.enterText(fields.at(0), 'hunter2!');
    await tester.enterText(fields.at(1), 'different');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('shows the recovery code and gates Done behind the saved '
      'checkbox', (tester) async {
    final results = await _pumpSetup(
      tester,
      onSetPassword: (_) async => 'alpha-bravo-charlie-delta',
    );

    await tester.enterText(find.byType(TextField).at(0), 'hunter2!');
    await tester.enterText(find.byType(TextField).at(1), 'hunter2!');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // The code must be visible, and Done must stay disabled until the user
    // confirms they saved it — losing this code can mean permanent lockout.
    expect(find.text('alpha-bravo-charlie-delta'), findsOneWidget);
    FilledButton done() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'));
    expect(done().onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(done().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('surfaces an enable failure and returns to the form', (
    tester,
  ) async {
    await _pumpSetup(
      tester,
      onSetPassword: (_) async => throw StateError('keychain unavailable'),
    );

    await tester.enterText(find.byType(TextField).at(0), 'hunter2!');
    await tester.enterText(find.byType(TextField).at(1), 'hunter2!');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('keychain unavailable'), findsOneWidget);
    // Back on the form (not stranded on the non-poppable spinner).
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
  });
}
