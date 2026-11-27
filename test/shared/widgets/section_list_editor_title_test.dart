import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/section_list_editor.dart';

/// A section title as it is typed reaches [SectionListEditor.onTitleChanged]
/// at once, before the rename that commits it when the field loses focus.
void main() {
  Future<({List<(String, String)> typed, List<(String, String)> renamed})> pump(
    WidgetTester tester,
  ) async {
    final typed = <(String, String)>[];
    final renamed = <(String, String)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SectionListEditor<String>(
              sections: const [
                SectionGroup(id: 's1', title: 'Gear', items: ['Fins']),
              ],
              itemId: (item) => item,
              itemBuilder: (_, item) => Text(item),
              addSectionLabel: 'Add section',
              newSectionTitle: 'New section',
              noSectionLabel: 'No section',
              onTitleChanged: (id, text) => typed.add((id, text)),
              onAddSection: (_) async {},
              onRenameSection: (id, title) async => renamed.add((id, title)),
              onReorderSections: (_) async {},
              onDeleteSection: (_, {moveItemsToSectionId}) async {},
              onMoveItem: (_, _, _) async {},
              onDeleteItem: (_) async {},
            ),
          ),
        ),
      ),
    );
    return (typed: typed, renamed: renamed);
  }

  testWidgets('each keystroke in a section title is reported', (tester) async {
    final calls = await pump(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Gear'), 'Dive gear');
    await tester.pump();

    expect(calls.typed, [('s1', 'Dive gear')]);
    // Still focused: the rename itself waits for the field to let go.
    expect(calls.renamed, isEmpty);
  });

  testWidgets('a rename still commits when the field loses focus', (
    tester,
  ) async {
    final calls = await pump(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Gear'), 'Dive gear');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(calls.renamed, [('s1', 'Dive gear')]);
  });
}
