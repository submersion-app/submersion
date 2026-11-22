import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/presentation/widgets/buddy_country_field.dart';

/// The buddy Country field (issue #4457): free text that offers the
/// countries containing what was typed.
void main() {
  Future<TextEditingController> pump(WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuddyCountryField(
            controller: controller,
            suggestions: const ['Italy', 'Malta', 'Mexico'],
            decoration: const InputDecoration(labelText: 'Country'),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('typing offers the countries that contain it', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Ita');
    await tester.pumpAndSettle();

    expect(find.text('Italy'), findsOneWidget);
    expect(find.text('Malta'), findsNothing);
  });

  testWidgets('submitting takes the first suggestion', (tester) async {
    final controller = await pump(tester);

    await tester.enterText(find.byType(TextField), 'Ital');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.text, 'Italy');
  });
}
