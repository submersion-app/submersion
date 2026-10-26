import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

import '../../../helpers/test_app.dart';

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;
  late List<bool> previews;
  late List<String> changes;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
    previews = [];
    changes = [];
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    String text = '',
    GlobalKey<FormState>? formKey,
    FormFieldValidator<String>? validator,
  }) async {
    controller.text = text;
    final field = MarkdownNotesField(
      controller: controller,
      focusNode: focusNode,
      decoration: const InputDecoration(labelText: 'Notes'),
      validator: validator,
      onChanged: changes.add,
      onPreviewChanged: previews.add,
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: formKey == null ? field : Form(key: formKey, child: field),
      ),
    );
    await tester.pumpAndSettle();
  }

  void select(int start, int end) {
    controller.selection = TextSelection(baseOffset: start, extentOffset: end);
  }

  Finder button(String tooltip) => find.byTooltip(tooltip);

  testWidgets('shows the five formatting buttons and Preview', (tester) async {
    await pump(tester);
    for (final tooltip in [
      'Heading',
      'Bold',
      'Italic',
      'Bulleted list',
      'Numbered list',
    ]) {
      expect(button(tooltip), findsOneWidget, reason: tooltip);
    }
    expect(find.text('Preview'), findsOneWidget);
    expect(find.byTooltip('Underline'), findsNothing);
  });

  testWidgets('Bold wraps the selection and reports the change', (
    tester,
  ) async {
    await pump(tester, text: 'a big turtle');
    select(2, 5);
    await tester.tap(button('Bold'));
    await tester.pump();
    expect(controller.text, 'a **big** turtle');
    expect(changes.last, 'a **big** turtle');
  });

  testWidgets('a list button acts on the caret line', (tester) async {
    await pump(tester, text: 'turtles');
    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.tap(button('Bulleted list'));
    await tester.pump();
    expect(controller.text, '- turtles');
  });

  testWidgets('tapping a button keeps focus in the field', (tester) async {
    await pump(tester, text: 'a big turtle');
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    select(2, 5);
    await tester.tap(button('Italic'));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    expect(controller.text, 'a *big* turtle');
  });

  testWidgets(
    'Cmd+B bolds on Apple platforms',
    (tester) async {
      await pump(tester, text: 'a big turtle');
      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      select(2, 5);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(controller.text, 'a **big** turtle');
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'Ctrl+I italicises elsewhere',
    (tester) async {
      await pump(tester, text: 'a big turtle');
      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      select(2, 5);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.text, 'a *big* turtle');
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.android,
    }),
  );

  testWidgets('Enter continues a list', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextFormField), '- a');
    await tester.enterText(find.byType(TextFormField), '- a\n');
    expect(controller.text, '- a\n- ');
  });

  testWidgets('Preview shows formatting and disables the buttons', (
    tester,
  ) async {
    await pump(tester, text: '# On the wreck\n**great**');
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(previews, [true]);
    expect(find.byType(MarkdownNotesView), findsOneWidget);
    expect(find.byType(EditableText).hitTestable(), findsNothing);
    final bold = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.format_bold),
        matching: find.byType(IconButton),
      ),
    );
    expect(bold.onPressed, isNull);
  });

  testWidgets('Preview off brings the field back with its selection', (
    tester,
  ) async {
    await pump(tester, text: 'a big turtle');
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    select(2, 5);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();

    expect(previews, [true, false]);
    expect(find.byType(MarkdownNotesView), findsNothing);
    expect(find.byType(EditableText).hitTestable(), findsOneWidget);
    expect(focusNode.hasFocus, isTrue);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 2, extentOffset: 5),
    );
  });

  testWidgets('Preview keeps the field height', (tester) async {
    await pump(tester, text: 'one line');
    final before = tester.getSize(find.byType(TextFormField)).height;
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    final box = tester.getSize(
      find.ancestor(
        of: find.byType(MarkdownNotesView),
        matching: find.byKey(const ValueKey('markdownNotesPreview')),
      ),
    );
    expect(box.height, before);
  });

  testWidgets('the validator still runs while previewing', (tester) async {
    final formKey = GlobalKey<FormState>();
    await pump(
      tester,
      text: 'x',
      formKey: formKey,
      validator: (value) => 'always wrong',
    );
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(formKey.currentState!.validate(), isFalse);
  });

  testWidgets('the formatting bar fits a narrow phone', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(280, 600);
    addTearDown(tester.view.reset);
    await pump(tester, text: 'x');
    expect(tester.takeException(), isNull);
    expect(find.text('Preview'), findsOneWidget);
  });
}
