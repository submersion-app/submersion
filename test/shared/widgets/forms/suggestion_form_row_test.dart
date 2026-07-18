import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

void main() {
  testWidgets('typing surfaces suggestions; tapping one fills controller', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: SuggestionFormRow(
              label: 'Country',
              controller: controller,
              suggestions: const ['Nederland', 'Mexico', 'USA'],
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Ned');
    await tester.pumpAndSettle();
    expect(find.text('Nederland'), findsOneWidget);
    await tester.tap(find.text('Nederland'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Nederland');
  });

  testWidgets('validator error renders; caption and trailing render', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: Form(
              key: formKey,
              child: SuggestionFormRow(
                label: 'Name',
                controller: controller,
                suggestions: const [],
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Name required' : null,
                caption: 'From: Alice in Wonderland (1/2)',
                trailing: const Icon(Icons.sync_alt),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('From: Alice in Wonderland (1/2)'), findsOneWidget);
    expect(find.byIcon(Icons.sync_alt), findsOneWidget);
    formKey.currentState!.validate();
    await tester.pump();
    expect(find.text('Name required'), findsOneWidget);
  });
}
