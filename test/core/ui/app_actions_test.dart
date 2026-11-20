import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/ui/app_actions.dart';

/// Tests default to TargetPlatform.android and tap with a touch pointer, the
/// case Flutter's own default leaves focused (#4813).
void main() {
  const fieldKey = Key('field');

  Widget host({required bool withAppActions, Widget? beside}) => MaterialApp(
    actions: withAppActions ? appActions() : null,
    home: Scaffold(
      body: Column(
        children: [
          const TextField(key: fieldKey),
          ?beside,
          const SizedBox(height: 200, child: Center(child: Text('elsewhere'))),
        ],
      ),
    ),
  );

  bool fieldFocused(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(fieldKey),
          matching: find.byType(EditableText),
        ),
      )
      .focusNode
      .hasFocus;

  testWidgets('Flutter alone keeps a field focused on a touch tap off it', (
    tester,
  ) async {
    await tester.pumpWidget(host(withAppActions: false));
    await tester.tap(find.byKey(fieldKey));
    await tester.pump();

    await tester.tap(find.text('elsewhere'));
    await tester.pump();

    expect(fieldFocused(tester), isTrue);
  });

  testWidgets('a touch tap off a focused field puts the keyboard away', (
    tester,
  ) async {
    await tester.pumpWidget(host(withAppActions: true));
    await tester.tap(find.byKey(fieldKey));
    await tester.pump();
    expect(fieldFocused(tester), isTrue);

    await tester.tap(find.text('elsewhere'));
    await tester.pump();

    expect(fieldFocused(tester), isFalse);
  });

  testWidgets('a control in the field\'s tap region keeps it focused', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      host(
        withAppActions: true,
        beside: TextFieldTapRegion(
          child: TextButton(
            onPressed: () => pressed = true,
            child: const Text('part of the field'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(fieldKey));
    await tester.pump();

    await tester.tap(find.text('part of the field'));
    await tester.pump();

    expect(pressed, isTrue);
    expect(fieldFocused(tester), isTrue);
  });

  test('is the same map every call, so a rebuild changes nothing', () {
    expect(identical(appActions(), appActions()), isTrue);
  });

  test('keeps every one of Flutter\'s default actions', () {
    expect(appActions().keys, containsAll(WidgetsApp.defaultActions.keys));
  });
}
