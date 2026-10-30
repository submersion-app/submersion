import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart'
    as domain;
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

Trip _trip({required bool upcoming}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = upcoming
      ? today.add(const Duration(days: 10))
      : today.subtract(const Duration(days: 20));
  return Trip(
    id: 't1',
    name: 'Test',
    startDate: start,
    endDate: start.add(const Duration(days: 7)),
    createdAt: today,
    updatedAt: today,
  );
}

TripChecklistItem _item({
  String id = 'i1',
  String title = 'Service regulator',
  String? sectionId,
  bool isDone = false,
  DateTime? dueDate,
}) => TripChecklistItem(
  id: id,
  tripId: 't1',
  title: title,
  sectionId: sectionId,
  isDone: isDone,
  dueDate: dueDate,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

domain.TripChecklistSection _section({
  required String id,
  required String title,
  int sortOrder = 0,
}) => domain.TripChecklistSection(
  id: id,
  tripId: 't1',
  title: title,
  sortOrder: sortOrder,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('groups items by section and shows checkboxes', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith(
            (ref) async => [
              _item(id: 'i1', title: 'Service regulator', sectionId: 'gear'),
              _item(id: 'i2', title: 'Book flights', sectionId: 'bookings'),
              _item(id: 'i3', title: 'Passport check'),
            ],
          ),
          tripChecklistSectionsProvider('t1').overrideWith(
            (ref) async => [
              _section(id: 'gear', title: 'Gear'),
              _section(id: 'bookings', title: 'Bookings', sortOrder: 1),
            ],
          ),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gear'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Service regulator'), findsOneWidget);
    expect(find.text('Passport check'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
  });

  testWidgets(
    'an item whose sectionId is not in the loaded sections renders without '
    'throwing (#3360)',
    (tester) async {
      // Reachable under sync: a section's delete can apply before this
      // item's own sectionId update does, since the two sync as
      // independent HLC records with no guaranteed arrival order.
      await tester.pumpWidget(
        testApp(
          overrides: [
            tripChecklistProvider('t1').overrideWith(
              (ref) async => [
                _item(id: 'i1', title: 'Service regulator', sectionId: 'gone'),
              ],
            ),
            tripChecklistSectionsProvider('t1').overrideWith(
              (ref) async => [_section(id: 'gear', title: 'Gear')],
            ),
          ],
          child: SingleChildScrollView(
            child: TripChecklistSection(trip: _trip(upcoming: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Service regulator'), findsOneWidget);
    },
  );

  testWidgets('shows overdue chip only for upcoming trips', (tester) async {
    final overdue = _item(
      dueDate: DateTime.now().subtract(const Duration(days: 3)),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith((ref) async => [overdue]),
          tripChecklistSectionsProvider('t1').overrideWith((ref) async => []),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Overdue'), findsOneWidget);

    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith((ref) async => [overdue]),
          tripChecklistSectionsProvider('t1').overrideWith((ref) async => []),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Overdue'), findsNothing);
  });

  testWidgets('empty upcoming trip shows planning invitation', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith((ref) async => []),
          tripChecklistSectionsProvider('t1').overrideWith((ref) async => []),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Plan your trip - add to-dos or apply a template'),
      findsOneWidget,
    );
  });

  testWidgets('a brand new trip still offers "+ Add section" alongside the '
      'planning invitation', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith((ref) async => []),
          tripChecklistSectionsProvider('t1').overrideWith((ref) async => []),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Plan your trip - add to-dos or apply a template'),
      findsOneWidget,
    );
    // The only way to create the feature's "empty section laid out in
    // advance" case is this button; a trip with no items and no sections
    // yet must not hide it behind the empty-state message (issue #3360).
    expect(find.text('Add section'), findsOneWidget);
  });

  testWidgets('a sections-provider failure shows the error, not a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith((ref) async => []),
          tripChecklistSectionsProvider(
            't1',
          ).overrideWith((ref) => Future.error('section load boom')),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('section load boom'), findsOneWidget);
  });

  group('real-database interactions', () {
    late TripRepository tripRepository;
    late TripChecklistRepository checklistRepository;
    late Trip trip;
    late SharedPreferences prefs;

    setUp(() async {
      await setUpTestDatabase();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      tripRepository = TripRepository();
      checklistRepository = TripChecklistRepository();
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
    });

    tearDown(tearDownTestDatabase);

    Future<void> pumpSection(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: SingleChildScrollView(child: TripChecklistSection(trip: trip)),
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
          tripId: trip.id,
          title: 'Service regulator',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpSection(tester);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByTripId(trip.id);
      expect(items.single.isDone, isTrue);
    });

    testWidgets('tapping an item opens the edit sheet and updates it', (
      tester,
    ) async {
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Fins',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpSection(tester);

      await tester.tap(find.widgetWithText(ListTile, 'Fins'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Split fins',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByTripId(trip.id);
      expect(items.single.title, 'Split fins');
    });

    testWidgets('tapping an item\'s delete icon removes it', (tester) async {
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Fins',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpSection(tester);
      expect(find.text('Fins'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Fins'), findsNothing);
      expect(await checklistRepository.getByTripId(trip.id), isEmpty);
    });

    testWidgets('the add-item button opens the edit sheet and persists a '
        'new item', (tester) async {
      await pumpSection(tester);

      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Passport check',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByTripId(trip.id);
      expect(items.single.title, 'Passport check');
    });

    testWidgets(
      "the section's overflow menu apply-template entry opens the apply "
      'sheet',
      (tester) async {
        await pumpSection(tester);

        // The section-level overflow menu is the first PopupMenuButton.
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
      },
    );

    testWidgets(
      "the section's overflow menu save-as-template entry snapshots the "
      'checklist',
      (tester) async {
        await checklistRepository.createItem(
          TripChecklistItem(
            id: '',
            tripId: trip.id,
            title: 'Fins',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await pumpSection(tester);

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
      await pumpSection(tester);

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
            tripId: trip.id,
            title: title,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      await pumpSection(tester);
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
      expect(await checklistRepository.getByTripId(trip.id), isEmpty);
      // The section is still mounted here, so the mounted guard around the
      // confirmation must not swallow it.
      expect(find.text('3 items removed'), findsOneWidget);
    });

    testWidgets('cancelling the clear-checklist dialog keeps every item', (
      tester,
    ) async {
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Fins',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpSection(tester);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear checklist...'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Fins'), findsOneWidget);
      expect(await checklistRepository.getByTripId(trip.id), hasLength(1));
    });

    testWidgets('clear-checklist is disabled in the overflow menu when the '
        'checklist is empty', (tester) async {
      await pumpSection(tester);

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

    testWidgets('renaming a section via its title field persists it', (
      tester,
    ) async {
      await checklistRepository.createSection(
        tripId: trip.id,
        title: 'Assembly',
      );
      await pumpSection(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Assembly'),
        'Prep',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final sections = await checklistRepository.getSectionsForTrip(trip.id);
      expect(sections.single.title, 'Prep');
    });

    testWidgets('renaming a section back to its original title persists it', (
      tester,
    ) async {
      await checklistRepository.createSection(
        tripId: trip.id,
        title: 'Assembly',
      );
      await pumpSection(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Assembly'),
        'Prep',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // Committed by leaving the field (a blur, not Enter): the blur path is
      // the one that used to compare against the title from the first build.
      await tester.enterText(
        find.widgetWithText(TextField, 'Prep'),
        'Assembly',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final sections = await checklistRepository.getSectionsForTrip(trip.id);
      expect(sections.single.title, 'Assembly');
    });

    testWidgets('the delete icon is disabled for the only remaining section', (
      tester,
    ) async {
      await checklistRepository.createSection(
        tripId: trip.id,
        title: 'Assembly',
      );
      await pumpSection(tester);

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
          tripId: trip.id,
          title: 'Assembly',
        );
        final cells = await checklistRepository.createSection(
          tripId: trip.id,
          title: 'Cells',
        );
        final item = await checklistRepository.createItem(
          TripChecklistItem(
            id: '',
            tripId: trip.id,
            title: 'Check O-rings',
            sectionId: assembly.id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        await pumpSection(tester);

        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Move items to "Cells"'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final sections = await checklistRepository.getSectionsForTrip(trip.id);
        expect(sections.map((s) => s.id), [cells.id]);
        final items = await checklistRepository.getByTripId(trip.id);
        expect(items.single.id, item.id);
        expect(items.single.sectionId, cells.id);
      },
    );

    testWidgets('deleting a section can delete its items instead', (
      tester,
    ) async {
      final assembly = await checklistRepository.createSection(
        tripId: trip.id,
        title: 'Assembly',
      );
      await checklistRepository.createSection(tripId: trip.id, title: 'Cells');
      await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Check O-rings',
          sectionId: assembly.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpSection(tester);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete items too'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(await checklistRepository.getByTripId(trip.id), isEmpty);
    });

    testWidgets('the up arrow reorders sections', (tester) async {
      await checklistRepository.createSection(tripId: trip.id, title: 'A');
      await checklistRepository.createSection(tripId: trip.id, title: 'B');
      await pumpSection(tester);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up).last);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final sections = await checklistRepository.getSectionsForTrip(trip.id);
      expect(sections.map((s) => s.title).toList(), ['B', 'A']);
    });

    testWidgets('an item\'s down arrow reorders items within its section', (
      tester,
    ) async {
      final section = await checklistRepository.createSection(
        tripId: trip.id,
        title: 'Gear',
      );
      final first = await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Mask',
          sectionId: section.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final second = await checklistRepository.createItem(
        TripChecklistItem(
          id: '',
          tripId: trip.id,
          title: 'Fins',
          sectionId: section.id,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await pumpSection(tester);

      // Index 0 is the section's own (disabled, since there is only one
      // section) down arrow; index 1 is the first item's.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down).at(1));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByTripId(trip.id);
      expect(items.map((i) => i.id).toList(), [second.id, first.id]);
    });
  });

  // Case-insensitive folding of a typed category onto an existing section
  // now happens once, at write time, in
  // TripChecklistRepository.findOrCreateSectionId -- covered by
  // trip_checklist_repository_test.dart's "sections" group. Rendering here
  // only ever groups by sectionId, so this widget's own thing to prove is
  // that groups render in the sections' own sort order.
  testWidgets('sections render in their own sort order, not item order', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith(
            (ref) async => [
              // The first item in the list belongs to the section sorted
              // second, so a correct render still shows Bookings first.
              _item(id: 'i1', title: 'Pack fins', sectionId: 'diving'),
              _item(id: 'i2', title: 'Book flights', sectionId: 'bookings'),
            ],
          ),
          tripChecklistSectionsProvider('t1').overrideWith(
            (ref) async => [
              _section(id: 'bookings', title: 'Bookings'),
              _section(id: 'diving', title: 'Diving', sortOrder: 1),
            ],
          ),
        ],
        child: SingleChildScrollView(
          child: TripChecklistSection(trip: _trip(upcoming: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bookingsHeader = tester.getTopLeft(find.text('Bookings'));
    final divingHeader = tester.getTopLeft(find.text('Diving'));
    expect(bookingsHeader.dy, lessThan(divingHeader.dy));
  });
}
