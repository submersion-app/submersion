import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('a markdown row keeps the merge caption and cycle button', (
    tester,
  ) async {
    final controller = TextEditingController(text: '- turtles');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: SuggestionFormRow(
          label: 'Notes',
          controller: controller,
          suggestions: const [],
          maxLines: 4,
          markdown: true,
          caption: 'From Site A',
          trailing: const Icon(Icons.sync, key: ValueKey('cycle')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownNotesField), findsOneWidget);
    expect(find.byType(RawAutocomplete<String>), findsNothing);
    expect(find.text('From Site A'), findsOneWidget);
    expect(find.byKey(const ValueKey('cycle')), findsOneWidget);
    expect(find.text('- turtles'), findsOneWidget);
  });

  testWidgets('a plain suggestion row still autocompletes', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      testApp(
        child: SuggestionFormRow(
          label: 'Name',
          controller: controller,
          suggestions: const ['Blue Hole'],
        ),
      ),
    );
    expect(find.byType(RawAutocomplete<String>), findsOneWidget);
    expect(find.byType(MarkdownNotesField), findsNothing);
  });
}
