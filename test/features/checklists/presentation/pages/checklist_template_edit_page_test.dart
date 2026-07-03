import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Renders [ChecklistTemplateEditPage] with [sharedPreferencesProvider]
/// overridden, needed because saving a brand-new template resolves
/// `validatedCurrentDiverIdProvider`, which watches `currentDiverIdProvider`,
/// which reads `sharedPreferencesProvider` (throws unless overridden).
Widget _appWithPrefs(SharedPreferences prefs, Widget child) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

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

  testWidgets('saving a new template with items persists them via the '
      'repository', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _appWithPrefs(prefs, const ChecklistTemplateEditPage()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Egypt prep',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Liveaboard packing',
    );

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTitleField(), 'Mask');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final repo = ChecklistTemplateRepository();
    final all = await repo.getAllTemplates();
    expect(all, hasLength(1));
    expect(all.single.name, 'Egypt prep');
    expect(all.single.description, 'Liveaboard packing');
    final items = await repo.getItemsForTemplate(all.single.id);
    expect(items.single.title, 'Mask');
  });

  testWidgets('empty template name fails validation and does not save', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _appWithPrefs(prefs, const ChecklistTemplateEditPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    final repo = ChecklistTemplateRepository();
    expect(await repo.getAllTemplates(), isEmpty);
  });

  testWidgets('an invalid due offset shows a validation error in the item '
      'dialog', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    await tester.pumpWidget(testApp(child: const ChecklistTemplateEditPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTitleField(), 'Book flights');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Days before trip start'),
      '-3',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(find.text('Enter 0 or more days'), findsOneWidget);
    // Dialog stays open on validation failure -- nothing was added.
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty item title shows a validation error in the item '
      'dialog', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    await tester.pumpWidget(testApp(child: const ChecklistTemplateEditPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting an item removes it from the list', (tester) async {
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
        category: 'Gear',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      testApp(child: ChecklistTemplateEditPage(templateId: created.id)),
    );
    await tester.pumpAndSettle();

    // The category subtitle renders for items with a category.
    expect(find.text('Gear'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Wetsuit'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(await repo.getItemsForTemplate(created.id), isEmpty);
  });

  testWidgets('the item dialog carries over category, notes, and due '
      'offset fields', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);

    await tester.pumpWidget(testApp(child: const ChecklistTemplateEditPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(dialogTitleField(), 'Book flights');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Category'),
      'Bookings',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notes'),
      'window seat',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Days before trip start'),
      '60',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bookings'), findsOneWidget);

    // Re-open the item to confirm the fields round-tripped.
    await tester.tap(find.text('Book flights'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('window seat'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('60')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
