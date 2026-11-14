import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/set_weights_choice_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The question asked when a picked set carries weights and the dive
/// already has some (issue #4525).
void main() {
  Future<SetWeightsChoice?> ask(WidgetTester tester, String button) async {
    SetWeightsChoice? answer;
    var answered = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              answer = await showSetWeightsChoiceDialog(
                context,
                setName: 'BP + camera',
                setTotal: '12.0 lbs',
                currentTotal: '14.0 lbs',
              );
              answered = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Use the weights from BP + camera?'), findsOneWidget);
    expect(
      find.text('This dive already has 14.0 lbs. The set carries 12.0 lbs.'),
      findsOneWidget,
    );
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    expect(answered, isTrue);
    return answer;
  }

  testWidgets('Add answers add', (tester) async {
    expect(await ask(tester, 'Add'), SetWeightsChoice.add);
  });

  testWidgets('Replace answers replace', (tester) async {
    expect(await ask(tester, 'Replace'), SetWeightsChoice.replace);
  });

  testWidgets('Keep current answers keep', (tester) async {
    expect(await ask(tester, 'Keep current'), SetWeightsChoice.keep);
  });
}
