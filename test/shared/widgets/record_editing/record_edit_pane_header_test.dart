import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_pane_header.dart';

Widget _host({
  bool canSave = true,
  bool isSaving = false,
  bool isBusy = false,
  VoidCallback? onCancel,
  VoidCallback? onSave,
  String? saveLabel,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: RecordEditPaneHeader(
        title: 'Editing Blue Hole',
        canSave: canSave,
        isSaving: isSaving,
        isBusy: isBusy,
        onCancel: onCancel ?? () {},
        onSave: onSave ?? () {},
        menu: const Icon(Icons.more_vert, key: ValueKey('menu')),
        saveLabel: saveLabel,
      ),
    ),
  );
}

RecordEditAction _action(WidgetTester tester, String label) =>
    tester.widget<RecordEditAction>(
      find.byWidgetPredicate((w) => w is RecordEditAction && w.label == label),
    );

/// The list pane's header row while its record is unlocked (issue #4527).
void main() {
  testWidgets('shows the title and the menu', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text('Editing Blue Hole'), findsOneWidget);
    expect(find.byKey(const ValueKey('menu')), findsOneWidget);
  });

  testWidgets('Cancel and Save call back', (tester) async {
    var cancelled = 0;
    var saved = 0;
    await tester.pumpWidget(
      _host(onCancel: () => cancelled++, onSave: () => saved++),
    );

    await tester.tap(find.text('Cancel'));
    await tester.tap(find.text('Save'));

    expect(cancelled, 1);
    expect(saved, 1);
  });

  testWidgets('Save waits for something to save', (tester) async {
    await tester.pumpWidget(_host(canSave: false));

    expect(_action(tester, 'Save').onPressed, isNull);
  });

  testWidgets('an operation running disables Cancel and Save', (tester) async {
    await tester.pumpWidget(_host(isBusy: true));

    expect(_action(tester, 'Save').onPressed, isNull);
    expect(_action(tester, 'Cancel').onPressed, isNull);
  });

  testWidgets('Cancel waits while saving', (tester) async {
    await tester.pumpWidget(_host(isSaving: true));

    expect(_action(tester, 'Cancel').onPressed, isNull);
  });

  // The same amber as the full page's bar (issue #5034).
  testWidgets('Cancel is a ring and Save is filled', (tester) async {
    await tester.pumpWidget(_host());

    expect(_action(tester, 'Cancel').style, RecordEditActionStyle.ring);
    expect(_action(tester, 'Save').style, RecordEditActionStyle.filled);

    await tester.pumpWidget(_host(saveLabel: 'Send'));

    expect(_action(tester, 'Send').style, RecordEditActionStyle.filled);
  });

  testWidgets('a save label replaces Save', (tester) async {
    var saved = 0;
    await tester.pumpWidget(_host(saveLabel: 'Send', onSave: () => saved++));

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await tester.tap(find.text('Send'));
    expect(saved, 1);
  });
}
