import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart'
    as domain;
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_block.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Split out of trip_checklist_block_test.dart to keep both files under the
/// project's 800-line cap: that file covers rendering against stubbed
/// providers, this one exercises the widget against a real database (issue
/// #3356).
///
/// Every checklist starts collapsed (issue #3356); tapping its title
/// expands it, the same gesture `ExpansionTile` exposes natively.
Future<void> _expand(WidgetTester tester, {String title = 'Checklist'}) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  group('real-database interactions', () {
    late TripRepository tripRepository;
    late TripChecklistRepository checklistRepository;
    late TripChecklistsRepository checklistsRepository;
    late Trip trip;
    late domain.TripChecklist checklist;
    late SharedPreferences prefs;

    setUp(() async {
      await setUpTestDatabase();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      tripRepository = TripRepository();
      checklistRepository = TripChecklistRepository();
      checklistsRepository = TripChecklistsRepository();
      trip = await tripRepository.createTrip(
        Trip(
          id: '',
          name: 'Red Sea',
          startDate: DateTime.now().add(const Duration(days: 10)),
          endDate: DateTime.now().add(const Duration(days: 17)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      checklist = await checklistsRepository.createChecklist(
        tripId: trip.id,
        name: 'Checklist',
      );
    });

    tearDown(tearDownTestDatabase);

    Future<void> pumpBlockReal(
      WidgetTester tester, {
      List<dynamic> overrides = const [],
    }) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...overrides,
          ],
          child: SingleChildScrollView(
            child: TripChecklistBlock(trip: trip, checklist: checklist),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('toggling the checkbox persists via the repository', (
      tester,
    ) async {
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Service regulator',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.single.isDone, isTrue);
    });

    testWidgets('tapping an item opens the edit sheet and updates it', (
      tester,
    ) async {
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Fins',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.tap(find.widgetWithText(ListTile, 'Fins'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Split fins',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.single.title, 'Split fins');
    });

    testWidgets('tapping an item\'s delete icon removes it', (tester) async {
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Fins',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpBlockReal(tester);
      await _expand(tester);
      expect(find.text('Fins'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fins'), findsNothing);
      expect(await checklistRepository.getByChecklistId(checklist.id), isEmpty);
    });

    testWidgets('the add-item button opens the edit sheet and persists a '
        'new item', (tester) async {
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Passport check',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.single.title, 'Passport check');
    });

    testWidgets("the checklist's overflow menu apply-template entry opens the "
        'template picker', (tester) async {
      await pumpBlockReal(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply template...'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Apply template'), findsOneWidget);
      expect(
        find.text('No templates yet. Create them in Settings.'),
        findsOneWidget,
      );
    });

    testWidgets('picking a template replaces the checklist content after '
        'confirmation, dropping the old section too', (tester) async {
      final oldSection = await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'Old gear',
      );
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Old mask',
          sectionId: oldSection.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final template = await ChecklistTemplateRepository().createTemplate(
        ChecklistTemplate(
          id: '',
          name: 'Clothing',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await ChecklistTemplateRepository().saveItems(template.id, [
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Swimsuit',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      await pumpBlockReal(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply template...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clothing'));
      await tester.pumpAndSettle();

      // Destructive-replace confirmation, naming both the checklist and
      // the chosen template.
      expect(
        find.text(
          'Replace all current items of "Checklist" with the items '
          'from "Clothing"? This cannot be undone.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.map((i) => i.title).toList(), ['Swimsuit']);
      final sections = await checklistRepository.getSectionsForChecklist(
        checklist.id,
      );
      expect(sections, isEmpty);
    });

    Future<ChecklistTemplate> clothingTemplate() async {
      final template = await ChecklistTemplateRepository().createTemplate(
        ChecklistTemplate(
          id: '',
          name: 'Clothing',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await ChecklistTemplateRepository().saveItems(template.id, [
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Swimsuit',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      return template;
    }

    Future<void> pickClothing(WidgetTester tester) async {
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply template...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clothing'));
      await tester.pumpAndSettle();
    }

    testWidgets('an empty checklist takes a template with nothing to confirm', (
      tester,
    ) async {
      await clothingTemplate();

      await pumpBlockReal(tester);
      await pickClothing(tester);

      expect(find.byType(AlertDialog), findsNothing);
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.map((i) => i.title).toList(), ['Swimsuit']);
    });

    testWidgets('items arriving while the picker is open still get the '
        'warning', (tester) async {
      await clothingTemplate();

      await pumpBlockReal(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply template...'));
      await tester.pumpAndSettle();
      // A sync landing here, after the menu read the checklist as empty.
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Synced mask',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await tester.tap(find.text('Clothing'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('a checklist holding only sections still asks first, since '
        'they go too', (tester) async {
      await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'Old gear',
      );
      await clothingTemplate();

      await pumpBlockReal(tester);
      await pickClothing(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('a template gone by the time it is read says so', (
      tester,
    ) async {
      final template = await clothingTemplate();

      await pumpBlockReal(
        tester,
        overrides: [
          checklistTemplateProvider(
            template.id,
          ).overrideWith((ref) async => null),
        ],
      );
      await pickClothing(tester);

      expect(find.text('Template no longer exists'), findsOneWidget);
    });

    testWidgets('shows whether a block is open, apart from the reorder '
        'arrows', (tester) async {
      await pumpBlockReal(tester);

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('cancelling the replace confirmation keeps the old content', (
      tester,
    ) async {
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Old mask',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await ChecklistTemplateRepository().createTemplate(
        ChecklistTemplate(
          id: '',
          name: 'Clothing',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await pumpBlockReal(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply template...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clothing'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.map((i) => i.title).toList(), ['Old mask']);
    });

    testWidgets(
      "the checklist's overflow menu save-as-template entry snapshots it",
      (tester) async {
        await checklistRepository.createItem(
          TripChecklistItem(
            id: '',
            checklistId: checklist.id,
            title: 'Fins',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await pumpBlockReal(tester);

        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save as template...'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Prep list');
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final templates = await ChecklistTemplateRepository().getAllTemplates();
        expect(templates.single.name, 'Prep list');
      },
    );

    testWidgets('save-as-template is disabled in the overflow menu when the '
        'checklist is empty', (tester) async {
      await pumpBlockReal(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      final saveItem = tester.widget<PopupMenuItem<String>>(
        find.ancestor(
          of: find.text('Save as template...'),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );
      expect(saveItem.enabled, isFalse);
    });

    testWidgets('clear-checklist wipes every item after confirmation', (
      tester,
    ) async {
      for (final title in ['Fins', 'Mask', 'Passport']) {
        await checklistRepository.createItem(
          TripChecklistItem(
            id: '',
            checklistId: checklist.id,
            title: title,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      await pumpBlockReal(tester);
      await _expand(tester);
      expect(find.text('Fins'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear checklist...'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Delete all 3 items from this checklist? '
          'Templates are not affected.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fins'), findsNothing);
      expect(await checklistRepository.getByChecklistId(checklist.id), isEmpty);
      // The block is still mounted here, so the mounted guard around the
      // confirmation must not swallow it.
      expect(find.text('3 items removed'), findsOneWidget);
    });

    testWidgets('cancelling the clear-checklist dialog keeps every item', (
      tester,
    ) async {
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Fins',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear checklist...'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Fins'), findsOneWidget);
      expect(
        await checklistRepository.getByChecklistId(checklist.id),
        hasLength(1),
      );
    });

    testWidgets('clear-checklist is disabled in the overflow menu when the '
        'checklist is empty', (tester) async {
      await pumpBlockReal(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      final clearItem = tester.widget<PopupMenuItem<String>>(
        find.ancestor(
          of: find.text('Clear checklist...'),
          matching: find.byType(PopupMenuItem<String>),
        ),
      );
      expect(clearItem.enabled, isFalse);
    });

    testWidgets('renaming the checklist via the overflow menu persists it '
        '(no effect on any template)', (tester) async {
      await pumpBlockReal(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename...'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Checklist name'),
        'Dive equipment',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final checklists = await checklistsRepository.getChecklistsForTrip(
        trip.id,
      );
      expect(checklists.single.name, 'Dive equipment');
    });

    testWidgets('deleting the checklist via the overflow menu removes it', (
      tester,
    ) async {
      await pumpBlockReal(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete...'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await checklistsRepository.getChecklistsForTrip(trip.id), isEmpty);
    });

    testWidgets('the checklist-level up/down arrows are disabled when no '
        'move callback is supplied', (tester) async {
      await pumpBlockReal(tester);

      final upButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up).first,
      );
      final downButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down).first,
      );
      expect(upButton.onPressed, isNull);
      expect(downButton.onPressed, isNull);
    });

    testWidgets('renaming a section via its title field persists it', (
      tester,
    ) async {
      await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'Assembly',
      );
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Assembly'),
        'Prep',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final sections = await checklistRepository.getSectionsForChecklist(
        checklist.id,
      );
      expect(sections.single.title, 'Prep');
    });

    testWidgets('renaming a section back to its original title persists it', (
      tester,
    ) async {
      await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'Assembly',
      );
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Assembly'),
        'Prep',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // Committed by leaving the field (a blur, not Enter): the blur path is
      // the one that used to compare against the title from the first
      // build.
      await tester.enterText(
        find.widgetWithText(TextField, 'Prep'),
        'Assembly',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final sections = await checklistRepository.getSectionsForChecklist(
        checklist.id,
      );
      expect(sections.single.title, 'Assembly');
    });

    testWidgets('the delete icon is disabled for the only remaining section', (
      tester,
    ) async {
      await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'Assembly',
      );
      await pumpBlockReal(tester);
      await _expand(tester);

      final deleteButton = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byIcon(Icons.delete_outline).first,
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(deleteButton.onPressed, isNull);
    });

    testWidgets(
      'deleting a section with a sibling offers moving its items there',
      (tester) async {
        final assembly = await checklistRepository.createSection(
          checklistId: checklist.id,
          title: 'Assembly',
        );
        final cells = await checklistRepository.createSection(
          checklistId: checklist.id,
          title: 'Cells',
        );
        final item = await checklistRepository.createItem(
          TripChecklistItem(
            id: '',
            checklistId: checklist.id,
            title: 'Check O-rings',
            sectionId: assembly.id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await pumpBlockReal(tester);
        await _expand(tester);

        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Move items to "Cells"'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final sections = await checklistRepository.getSectionsForChecklist(
          checklist.id,
        );
        expect(sections.map((s) => s.id), [cells.id]);
        final items = await checklistRepository.getByChecklistId(checklist.id);
        expect(items.single.id, item.id);
        expect(items.single.sectionId, cells.id);
      },
    );

    testWidgets('deleting a section can delete its items instead', (
      tester,
    ) async {
      final assembly = await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'Assembly',
      );
      await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'Cells',
      );
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Check O-rings',
          sectionId: assembly.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete items too'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await checklistRepository.getByChecklistId(checklist.id), isEmpty);
    });

    testWidgets('the up arrow reorders sections', (tester) async {
      await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'A',
      );
      await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'B',
      );
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up).last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final sections = await checklistRepository.getSectionsForChecklist(
        checklist.id,
      );
      expect(sections.map((s) => s.title).toList(), ['B', 'A']);
    });

    testWidgets("an item's down arrow reorders items within its section", (
      tester,
    ) async {
      final section = await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'Gear',
      );
      final first = await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Mask',
          sectionId: section.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final second = await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          checklistId: checklist.id,
          title: 'Fins',
          sectionId: section.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpBlockReal(tester);
      await _expand(tester);

      // Index 0 is the checklist's own (disabled, no callback supplied) down
      // arrow; index 1 is the section's; index 2 is the first item's.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down).at(2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.map((i) => i.id).toList(), [second.id, first.id]);
    });
  });
}
