import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/typed_word_confirm_dialog.dart';

void main() {
  late bool? result;

  Future<void> open(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await TypedWordConfirmDialog.show(
                context,
                title: 'Replace the dives here?',
                paragraphs: const ['They are set aside first.'],
                word: 'Replace',
                hint: 'Type "Replace" to confirm',
                confirmLabel: 'Replace',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  FilledButton confirm(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('confirms only once the word is typed', (tester) async {
    await open(tester);
    expect(find.text('They are set aside first.'), findsOneWidget);
    expect(confirm(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Repl');
    await tester.pump();
    expect(confirm(tester).onPressed, isNull);

    // Spaces around the word are forgiven.
    await tester.enterText(find.byType(TextField), ' Replace ');
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Cancel confirms nothing', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
