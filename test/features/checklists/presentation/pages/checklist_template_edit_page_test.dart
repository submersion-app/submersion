import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_edit_page.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Finds the first TextFormField inside the open AlertDialog (the item's
/// title field), never the page's own name/description fields.
Finder dialogTitleField() => find
    .descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    )
    .first;

void main() {
  testWidgets('adding an item to an existing template does not throw', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    final repo = ChecklistTemplateRepository();
    final created = await repo.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await repo.saveItems(created.id, [
      ChecklistTemplateItem(
        id: '',
        templateId: created.id,
        title: 'Wetsuit',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      ChecklistTemplateItem(
        id: '',
        templateId: created.id,
        title: 'Fins',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      testApp(child: ChecklistTemplateEditPage(templateId: created.id)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wetsuit'), findsOneWidget);
    expect(find.text('Fins'), findsOneWidget);

    // Open the add-item dialog, fill the title, confirm. The dialog owns
    // ephemeral controllers; disposing them at the wrong time throws
    // "TextEditingController used after being disposed" (or trips the
    // InheritedElement _dependents assertion) during the exit animation.
    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTitleField(), 'Mask');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Mask'), findsOneWidget);
  });

  testWidgets('cancelling the item dialog does not throw', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    await tester.pumpWidget(testApp(child: const ChecklistTemplateEditPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTitleField(), 'Discarded');
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Discarded'), findsNothing);
  });

  testWidgets('editing an existing item updates its title', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    final repo = ChecklistTemplateRepository();
    final created = await repo.createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Packing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await repo.saveItems(created.id, [
      ChecklistTemplateItem(
        id: '',
        templateId: created.id,
        title: 'Wetsuit',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      testApp(child: ChecklistTemplateEditPage(templateId: created.id)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wetsuit'));
    await tester.pumpAndSettle();
    // Dialog pre-fills the existing title.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Wetsuit'),
      ),
      findsOneWidget,
    );
    await tester.enterText(dialogTitleField(), 'Drysuit');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Drysuit'), findsOneWidget);
    expect(find.text('Wetsuit'), findsNothing);
  });
}
