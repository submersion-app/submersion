import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import '../../../helpers/test_app.dart';

/// A row below a button that holds focus, as the button a screen reader last
/// activated does in a browser: the web engine hands DOM focus on a semantics
/// node back to the framework as focus on that widget.
Widget _host(FormRow row, FocusNode buttonFocus) => testApp(
  locale: const Locale('en'),
  child: Column(
    children: [
      TextButton(
        focusNode: buttonFocus,
        onPressed: () {},
        child: const Text('Section'),
      ),
      row,
    ],
  ),
);

Future<TextEditingController> _openRow(
  WidgetTester tester, {
  required bool markdown,
  required String label,
  required String text,
}) async {
  final controller = TextEditingController(text: text);
  addTearDown(controller.dispose);
  final buttonFocus = FocusNode();
  addTearDown(buttonFocus.dispose);
  await tester.pumpWidget(
    _host(
      markdown
          ? FormRow.text(
              label: label,
              controller: controller,
              maxLines: 5,
              markdown: true,
            )
          : FormRow.text(label: label, controller: controller),
      buttonFocus,
    ),
  );
  buttonFocus.requestFocus();
  await tester.pump();
  expect(buttonFocus.hasFocus, isTrue);

  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
  return controller;
}

SemanticsNode _fieldNode(WidgetTester tester) =>
    tester.getSemantics(find.byType(EditableText));

void main() {
  group('FormRow.text with a screen reader (#4166)', () {
    for (final markdown in [false, true]) {
      final kind = markdown ? 'Markdown' : 'plain';

      testWidgets('an opened $kind row takes focus from the control that '
          'held it', (tester) async {
        await _openRow(tester, markdown: markdown, label: 'Notes', text: 'Ok');

        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(editable.widget.focusNode.hasFocus, isTrue);

        await tester.enterText(find.byType(EditableText), 'Typed');
        expect(find.text('Typed'), findsOneWidget);
      });

      testWidgets('an opened $kind row names its field after the row', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _openRow(tester, markdown: markdown, label: 'Notes', text: 'Ok');

        final node = _fieldNode(tester);
        expect(node.flagsCollection.isTextField, isTrue);
        expect(node.label, startsWith('Notes'));
        expect(node.value, 'Ok');
        semantics.dispose();
      });
    }
  });

  group('SuggestionFormRow with a screen reader (#4166)', () {
    for (final markdown in [false, true]) {
      final kind = markdown ? 'Markdown' : 'plain';

      testWidgets('a $kind row names its field after the row', (tester) async {
        final semantics = tester.ensureSemantics();
        final controller = TextEditingController(text: 'Ok');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          testApp(
            locale: const Locale('en'),
            child: SuggestionFormRow(
              label: 'Buddy',
              controller: controller,
              suggestions: const [],
              maxLines: markdown ? 5 : 1,
              markdown: markdown,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final node = _fieldNode(tester);
        expect(node.flagsCollection.isTextField, isTrue);
        expect(node.label, startsWith('Buddy'));
        expect(node.value, 'Ok');
        semantics.dispose();
      });
    }
  });

  group('FormRow.rating with a screen reader (#4166)', () {
    testWidgets('names each star by the rating it sets', (tester) async {
      final semantics = tester.ensureSemantics();
      var rating = 0;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: FormRow.rating(
            label: 'Rating',
            value: 2,
            onChanged: (value) => rating = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('1 star'), findsOneWidget);
      expect(find.bySemanticsLabel('5 stars'), findsOneWidget);
      // The filled stars read as selected, so the rating is heard, not
      // only seen.
      expect(
        tester.getSemantics(find.bySemanticsLabel('2 stars')),
        isSemantics(label: '2 stars', isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('3 stars')),
        isSemantics(label: '3 stars', isSelected: false, hasTapAction: true),
      );
      await tester.tap(find.bySemanticsLabel('4 stars'));
      expect(rating, 4);
      semantics.dispose();
    });
  });
}
