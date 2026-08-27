import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/presentation/widgets/unlock_form.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('submits secret and shows error on rejection', (tester) async {
    final submitted = <String>[];
    var accept = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: UnlockForm(
            autoFireBiometric: false,
            onBiometric: null,
            onSubmitSecret: (s) async {
              submitted.add(s);
              return accept;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'wrong-pw');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(submitted, ['wrong-pw']);
    expect(find.text('Incorrect password. Try again.'), findsOneWidget);

    accept = true;
    await tester.enterText(find.byType(TextField), 'right-pw');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(submitted, ['wrong-pw', 'right-pw']);
    expect(find.text('Incorrect password. Try again.'), findsNothing);
  });

  testWidgets('shows biometric button when available', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: UnlockForm(
            autoFireBiometric: false,
            onBiometric: () async {
              fired++;
              return true;
            },
            onSubmitSecret: (_) async => false,
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pumpAndSettle();
    expect(fired, 1);
  });

  testWidgets('auto-fires biometric once when enabled', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: UnlockForm(
            onBiometric: () async {
              fired++;
              return false;
            },
            onSubmitSecret: (_) async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(fired, 1);
  });
}
