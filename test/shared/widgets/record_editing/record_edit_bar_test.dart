import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

Widget _host({
  bool canSave = true,
  bool isSaving = false,
  VoidCallback? onCancel,
  VoidCallback? onSave,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: RecordEditBar(
        title: 'Editing dive 214',
        canSave: canSave,
        isSaving: isSaving,
        onCancel: onCancel ?? () {},
        onSave: onSave ?? () {},
      ),
    ),
  );
}

AppBarTextAction _action(WidgetTester tester, String label) =>
    tester.widget<AppBarTextAction>(
      find.byWidgetPredicate((w) => w is AppBarTextAction && w.label == label),
    );

void main() {
  testWidgets('shows Cancel, the title and Save', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Editing dive 214'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Save and Cancel call back', (tester) async {
    var saved = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      _host(onSave: () => saved++, onCancel: () => cancelled++),
    );

    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Cancel'));

    expect(saved, 1);
    expect(cancelled, 1);
  });

  testWidgets('Save is disabled when there is nothing to save', (tester) async {
    var saved = 0;
    await tester.pumpWidget(_host(canSave: false, onSave: () => saved++));

    await tester.tap(find.text('Save'));

    expect(saved, 0);
    expect(_action(tester, 'Save').onPressed, isNull);
    expect(_action(tester, 'Cancel').onPressed, isNotNull);
  });

  testWidgets('both actions are inert, and Save busy, while saving', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isSaving: true));

    expect(_action(tester, 'Save').busy, isTrue);
    expect(_action(tester, 'Save').onPressed, isNull);
    expect(_action(tester, 'Cancel').onPressed, isNull);
  });

  testWidgets('there is no back arrow, even on a pushed page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: RecordEditBar(
                    title: 'Editing dive 214',
                    canSave: false,
                    isSaving: false,
                    onCancel: () {},
                    onSave: () {},
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Editing dive 214'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  for (final theme in [ThemeData.light(), ThemeData.dark()]) {
    testWidgets('the bar background is opaque (${theme.brightness.name})', (
      tester,
    ) async {
      await tester.pumpWidget(_host(theme: theme));

      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, isNotNull);
      expect(bar.backgroundColor!.a, 1.0);
      expect(bar.backgroundColor, isNot(theme.colorScheme.surface));
    });
  }
}
