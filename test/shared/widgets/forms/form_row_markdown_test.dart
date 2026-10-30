import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

import '../../../helpers/test_app.dart';

void main() {
  late TextEditingController controller;

  setUp(() => controller = TextEditingController());
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, String text) async {
    controller.text = text;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Column(
          children: [
            FormRow.text(
              label: 'Notes',
              controller: controller,
              maxLines: 5,
              markdown: true,
            ),
            const SizedBox(height: 200),
            const Text('elsewhere'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
  }

  testWidgets('a resting markdown row shows plain words', (tester) async {
    await pump(tester, '# Descent\n**great** viz');
    expect(find.textContaining('Descent'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('#'), findsNothing);
    expect(find.byType(MarkdownNotesField), findsNothing);
  });

  testWidgets('tapping a markdown row opens the notes editor', (tester) async {
    await pump(tester, 'turtles');
    await open(tester);
    expect(find.byType(MarkdownNotesField), findsOneWidget);
    expect(find.byTooltip('Bold'), findsOneWidget);
  });

  testWidgets('formatting taps keep the row open', (tester) async {
    await pump(tester, 'a big turtle');
    await open(tester);
    controller.selection = const TextSelection(baseOffset: 2, extentOffset: 5);
    await tester.tap(find.byTooltip('Bold'));
    await tester.pumpAndSettle();
    expect(controller.text, 'a **big** turtle');
    expect(find.byType(MarkdownNotesField), findsOneWidget);
  });

  testWidgets('preview keeps the row open; tapping outside rests it', (
    tester,
  ) async {
    await pump(tester, '**great**');
    await open(tester);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownNotesView), findsOneWidget);
    expect(find.byType(MarkdownNotesField), findsOneWidget);

    await tester.tap(find.text('elsewhere'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownNotesField), findsNothing);
    expect(find.text('great'), findsOneWidget);
  });

  testWidgets('a plain text row is unchanged', (tester) async {
    controller.text = 'x';
    await tester.pumpWidget(
      testApp(
        child: FormRow.text(label: 'Name', controller: controller),
      ),
    );
    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byType(MarkdownNotesField), findsNothing);
  });

  testWidgets('a tap outside while typing leaves resting to focus', (
    tester,
  ) async {
    await pump(tester, 'turtles');
    await open(tester);
    await tester.tap(find.text('elsewhere'));
    await tester.pumpAndSettle();
    // On a phone a tap outside does not take focus from the field, so the
    // row stays open, as a plain row does; scrolling must not close it.
    expect(find.byType(MarkdownNotesField), findsOneWidget);
  });

  test('a Markdown row refuses parameters it cannot honour', () {
    final c = TextEditingController();
    addTearDown(c.dispose);
    expect(
      () => FormRow.text(
        label: 'Notes',
        controller: c,
        markdown: true,
        suffixText: 'm',
      ),
      throwsAssertionError,
    );
    expect(
      () => FormRow.text(
        label: 'Notes',
        controller: c,
        markdown: true,
        inputValidator: (_) => null,
      ),
      throwsAssertionError,
    );
  });
}
