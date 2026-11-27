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
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Split out of trip_checklist_block_test.dart to keep both files under the
/// project's 800-line cap: that file covers rendering against stubbed
/// providers, this one exercises the widget against a real database (issue
/// #3356). Every change is held in the trip page's sitting and written at
/// Save (issue #4527), so each case acts in a sitting and then either reads
/// what the sitting holds or runs Save's writes and reads the store.
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
    late EditSession<Trip> session;
    late SittingList<Trip, TripChecklistsHeld> list;
    late HeldTripChecklistWrites writes;

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

    /// Stores an item titled [title] in the checklist, before a sitting.
    Future<TripChecklistItem> addItem(String title, {String? sectionId}) =>
        checklistRepository.createItem(
          TripChecklistItem(
            id: '',
            checklistId: checklist.id,
            title: title,
            sectionId: sectionId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

    /// Opens a sitting over the trip, reading what is stored now, and pumps
    /// the trip's checklists in it as an unlocked trip page draws them: from
    /// the rows the sitting holds. [locked] pumps the block with no sitting,
    /// as a locked page does.
    Future<void> pumpBlockReal(
      WidgetTester tester, {
      List<dynamic> overrides = const [],
      bool locked = false,
    }) async {
      session = EditSession<Trip>(trip);
      addTearDown(session.dispose);
      list = tripChecklistsList(
        checklists: checklistsRepository,
        items: checklistRepository,
      );
      await list.load(session);
      writes = HeldTripChecklistWrites(
        session: session,
        list: list,
        templates: ChecklistTemplateRepository(),
      );
      await tester.pumpWidget(
        testApp(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ...overrides,
          ],
          child: SingleChildScrollView(
            child: locked
                ? TripChecklistBlock(trip: trip, checklist: checklist)
                : ListenableBuilder(
                    listenable: list.changes(session),
                    builder: (context, _) {
                      final held = heldChecklistsOf(session, list)!;
                      return Column(
                        children: [
                          for (final c in held.checklists)
                            TripChecklistBlock(
                              trip: trip,
                              checklist: c,
                              held: held,
                              writes: writes,
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The checklists the sitting holds.
    TripChecklistsHeld held() => heldChecklistsOf(session, list)!;

    /// Save's writes: what the sitting holds, written to the store.
    Future<void> save() => session.runHeldWrites();

    testWidgets('ticking an item is held until Save, which stores it', (
      tester,
    ) async {
      await addItem('Service regulator');
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(
        (await checklistRepository.getByChecklistId(
          checklist.id,
        )).single.isDone,
        isFalse,
      );

      await save();

      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.single.isDone, isTrue);
    });

    testWidgets('tapping an item opens the edit sheet, and its change is '
        'stored at Save', (tester) async {
      await addItem('Fins');
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
      expect(find.text('Split fins'), findsOneWidget);
      await save();
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.single.title, 'Split fins');
    });

    testWidgets('tapping an item\'s delete icon removes it', (tester) async {
      await addItem('Fins');
      await pumpBlockReal(tester);
      await _expand(tester);
      expect(find.text('Fins'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fins'), findsNothing);
      await save();
      expect(await checklistRepository.getByChecklistId(checklist.id), isEmpty);
    });

    testWidgets('the add-item button opens the edit sheet and holds a new '
        'item, stored at Save', (tester) async {
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
      expect(find.text('Passport check'), findsOneWidget);
      await save();
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

    testWidgets('picking a template replaces the checklist content after '
        'confirmation, dropping the old section too', (tester) async {
      final oldSection = await checklistRepository.createSection(
        checklistId: checklist.id,
        title: 'Old gear',
      );
      await addItem('Old mask', sectionId: oldSection.id);
      await clothingTemplate();

      await pumpBlockReal(tester);
      await pickClothing(tester);

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
      expect(held().itemsOf(checklist.id).map((i) => i.title).toList(), [
        'Swimsuit',
      ]);
      await save();
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.map((i) => i.title).toList(), ['Swimsuit']);
      final sections = await checklistRepository.getSectionsForChecklist(
        checklist.id,
      );
      expect(sections, isEmpty);
    });

    testWidgets('an empty checklist takes a template with nothing to confirm', (
      tester,
    ) async {
      await clothingTemplate();

      await pumpBlockReal(tester);
      await pickClothing(tester);

      expect(find.byType(AlertDialog), findsNothing);
      await save();
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.map((i) => i.title).toList(), ['Swimsuit']);
    });

    testWidgets('an item held while the picker is open still gets the '
        'warning', (tester) async {
      await clothingTemplate();

      await pumpBlockReal(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply template...'));
      await tester.pumpAndSettle();
      // Held here, after the menu found the checklist empty: the warning
      // reads what the sitting holds once the template is picked.
      await writes.createItem(
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
      await addItem('Old mask');
      await clothingTemplate();

      await pumpBlockReal(tester);
      await pickClothing(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(held().itemsOf(checklist.id).map((i) => i.title).toList(), [
        'Old mask',
      ]);
      expect(session.changedCardIds, isEmpty);
    });

    testWidgets(
      "the checklist's overflow menu save-as-template entry snapshots it at "
      'once, holding nothing',
      (tester) async {
        await addItem('Fins');
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
        expect(session.changedCardIds, isEmpty);
      },
    );

    testWidgets('locked, the menu only saves the checklist as a template, '
        'which it makes at once', (tester) async {
      await addItem('Fins');
      await pumpBlockReal(tester, locked: true);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsOneWidget);
      await tester.tap(find.text('Save as template...'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'Prep list');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final templates = await ChecklistTemplateRepository().getAllTemplates();
      expect(templates.single.name, 'Prep list');
      expect(
        (await ChecklistTemplateRepository().getItemsForTemplate(
          templates.single.id,
        )).single.title,
        'Fins',
      );
    });

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

    testWidgets('clear-checklist wipes every item after confirmation, '
        'stored at Save', (tester) async {
      for (final title in ['Fins', 'Mask', 'Passport']) {
        await addItem(title);
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
      await save();
      expect(await checklistRepository.getByChecklistId(checklist.id), isEmpty);
      // The block is still mounted here, so the mounted guard around the
      // confirmation must not swallow it.
      expect(find.text('3 items removed'), findsOneWidget);
    });

    testWidgets('cancelling the clear-checklist dialog keeps every item', (
      tester,
    ) async {
      await addItem('Fins');
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear checklist...'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Fins'), findsOneWidget);
      expect(held().itemsOf(checklist.id), hasLength(1));
      expect(session.changedCardIds, isEmpty);
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

    testWidgets('renaming the checklist via the overflow menu is stored at '
        'Save (no effect on any template)', (tester) async {
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
      expect(find.text('Dive equipment'), findsOneWidget);
      await save();
      final checklists = await checklistsRepository.getChecklistsForTrip(
        trip.id,
      );
      expect(checklists.single.name, 'Dive equipment');
    });

    testWidgets('deleting the checklist via the overflow menu removes it, '
        'stored at Save', (tester) async {
      await pumpBlockReal(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete...'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Checklist'), findsNothing);
      expect(
        await checklistsRepository.getChecklistsForTrip(trip.id),
        hasLength(1),
      );
      await save();
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

    testWidgets('renaming a section via its title field is stored at Save', (
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
      await save();
      final sections = await checklistRepository.getSectionsForChecklist(
        checklist.id,
      );
      expect(sections.single.title, 'Prep');
    });

    testWidgets('renaming a section back to its original title keeps it', (
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

      expect(held().sectionsOf(checklist.id).single.title, 'Assembly');
      await save();
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
        final item = await addItem('Check O-rings', sectionId: assembly.id);
        await pumpBlockReal(tester);
        await _expand(tester);

        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Move items to "Cells"'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        await save();
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
      await addItem('Check O-rings', sectionId: assembly.id);
      await pumpBlockReal(tester);
      await _expand(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete items too'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await save();
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
      await save();
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
      final first = await addItem('Mask', sectionId: section.id);
      final second = await addItem('Fins', sectionId: section.id);
      await pumpBlockReal(tester);
      await _expand(tester);

      // Index 0 is the checklist's own (disabled, no callback supplied) down
      // arrow; index 1 is the section's; index 2 is the first item's.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down).at(2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await save();
      final items = await checklistRepository.getByChecklistId(checklist.id);
      expect(items.map((i) => i.id).toList(), [second.id, first.id]);
    });
  });
}
