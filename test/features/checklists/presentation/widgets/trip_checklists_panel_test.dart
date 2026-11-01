import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/widgets/trip_checklists_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late TripRepository tripRepository;
  late TripChecklistsRepository checklistsRepository;
  late Trip upcomingTrip;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tripRepository = TripRepository();
    checklistsRepository = TripChecklistsRepository();
    upcomingTrip = await tripRepository.createTrip(
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

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: SingleChildScrollView(
          child: TripChecklistsPanel(trip: upcomingTrip),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a trip with no checklists shows the empty state and the "add '
      'checklist" row', (tester) async {
    await pumpPanel(tester);

    expect(
      find.text('No checklists yet - add one to start planning'),
      findsOneWidget,
    );
    expect(find.text('Add checklist'), findsOneWidget);
  });

  testWidgets(
    'picking a template on the "add checklist" row creates a new checklist '
    'named after it and applies its items, no name prompt involved',
    (tester) async {
      final template = await ChecklistTemplateRepository().createTemplate(
        ChecklistTemplate(
          id: '',
          name: 'Dive equipment',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await ChecklistTemplateRepository().saveItems(template.id, [
        ChecklistTemplateItem(
          id: '',
          templateId: template.id,
          title: 'Mask',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      await pumpPanel(tester);
      // Not find.byType(PopupMenuButton<String>): the "add checklist" row's
      // menu opens from tapping the row itself now, same as tapping its
      // trailing icon (issue #3356 maintainer feedback).
      await tester.tap(find.widgetWithText(ListTile, 'Add checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply template...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dive equipment'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final checklists = await checklistsRepository.getChecklistsForTrip(
        upcomingTrip.id,
      );
      expect(checklists.single.name, 'Dive equipment');
      expect(find.text('Dive equipment'), findsOneWidget);
      // A just-created checklist renders expanded (maintainer feedback
      // after testing): "Mask" is visible without an extra tap.
      expect(find.text('Mask'), findsOneWidget);
    },
  );

  testWidgets(
    '"New checklist..." prompts for a name, creates an empty checklist and '
    'renders it expanded',
    (tester) async {
      await pumpPanel(tester);

      await tester.tap(find.widgetWithText(ListTile, 'Add checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New checklist...'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Checklist name'),
        'Beach vacation',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final checklists = await checklistsRepository.getChecklistsForTrip(
        upcomingTrip.id,
      );
      expect(checklists.single.name, 'Beach vacation');
      expect(find.text('Beach vacation'), findsOneWidget);
      // Renders expanded, like a template-created checklist: the empty
      // state's "Add section" affordance is already on screen.
      expect(find.text('Add section'), findsOneWidget);
    },
  );

  testWidgets('picking the same template twice creates two separately-named '
      'checklists, not one overwriting the other', (tester) async {
    await ChecklistTemplateRepository().createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Dive equipment',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await pumpPanel(tester);
    for (var i = 0; i < 2; i++) {
      // Not find.byType(PopupMenuButton<String>).last: on the second pass
      // that would hit the checklist block's own menu instead of the "add
      // checklist" row's, now that the row opens its menu via a plain
      // IconButton/row tap rather than PopupMenuButton.
      await tester.tap(find.widgetWithText(ListTile, 'Add checklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply template...'));
      await tester.pumpAndSettle();
      // Not find.text('Dive equipment') or find.widgetWithText(ListTile,
      // ...): on the second pass, a checklist block from the first pass
      // already renders its own ExpansionTile ListTile with that same
      // name, so only scoping to the picker's BottomSheet disambiguates
      // which ListTile to tap.
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.widgetWithText(ListTile, 'Dive equipment'),
        ),
      );
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    final checklists = await checklistsRepository.getChecklistsForTrip(
      upcomingTrip.id,
    );
    expect(checklists, hasLength(2));
    expect(checklists.every((c) => c.name == 'Dive equipment'), isTrue);
    expect(find.text('Dive equipment'), findsNWidgets(2));
  });

  testWidgets('several checklists render as collapsed blocks, none '
      'auto-expanded', (tester) async {
    await checklistsRepository.createChecklist(
      tripId: upcomingTrip.id,
      name: 'Dive equipment',
    );
    await checklistsRepository.createChecklist(
      tripId: upcomingTrip.id,
      name: 'Clothing',
    );
    await pumpPanel(tester);

    expect(find.text('Dive equipment'), findsOneWidget);
    expect(find.text('Clothing'), findsOneWidget);
    // Neither checklist is auto-expanded, so neither's "Add item"
    // affordance (only rendered when expanded) is on screen yet.
    expect(find.text('Add item'), findsNothing);
  });

  testWidgets('the up/down arrows reorder checklists', (tester) async {
    await checklistsRepository.createChecklist(
      tripId: upcomingTrip.id,
      name: 'A',
    );
    await checklistsRepository.createChecklist(
      tripId: upcomingTrip.id,
      name: 'B',
    );
    await pumpPanel(tester);

    // The first checklist's down arrow is the first one on screen (the
    // "add checklist" row has no reorder arrows of its own).
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final checklists = await checklistsRepository.getChecklistsForTrip(
      upcomingTrip.id,
    );
    expect(checklists.map((c) => c.name).toList(), ['B', 'A']);
  });

  testWidgets(
    'the first checklist\'s up arrow and the last one\'s down arrow are '
    'disabled',
    (tester) async {
      await checklistsRepository.createChecklist(
        tripId: upcomingTrip.id,
        name: 'A',
      );
      await checklistsRepository.createChecklist(
        tripId: upcomingTrip.id,
        name: 'B',
      );
      await pumpPanel(tester);

      final firstUp = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up).first,
      );
      final lastDown = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down).last,
      );
      expect(firstUp.onPressed, isNull);
      expect(lastDown.onPressed, isNull);
    },
  );
}
