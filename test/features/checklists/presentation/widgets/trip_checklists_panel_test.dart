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
      await tester.tap(find.byType(PopupMenuButton<String>));
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
      // The checklist row itself shows its new name; expanding it would
      // show "Mask" too, covered by trip_checklist_block_test.dart.
      expect(find.text('Dive equipment'), findsOneWidget);
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
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply template...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dive equipment'));
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
