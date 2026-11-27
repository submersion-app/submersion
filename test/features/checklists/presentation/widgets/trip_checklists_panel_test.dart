import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklists_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/trip_checklists_panel.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_checklists_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Holds a template's items back until [gate] opens, so applying it waits.
class _GatedItemsRepository extends ChecklistTemplateRepository {
  _GatedItemsRepository(this.gate);

  final Future<void> gate;

  @override
  Future<List<ChecklistTemplateItem>> getItemsForTemplate(
    String templateId,
  ) async {
    await gate;
    return super.getItemsForTemplate(templateId);
  }
}

/// Fails to read a template's items, so applying it fails.
class _FailingItemsRepository extends ChecklistTemplateRepository {
  @override
  Future<List<ChecklistTemplateItem>> getItemsForTemplate(
    String templateId,
  ) async => throw Exception('disk full');
}

void main() {
  late TripRepository tripRepository;
  late TripChecklistsRepository checklistsRepository;
  late SittingList<Trip, TripChecklistsHeld> list;
  late Trip upcomingTrip;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tripRepository = TripRepository();
    checklistsRepository = TripChecklistsRepository();
    list = tripChecklistsList(
      checklists: checklistsRepository,
      items: TripChecklistRepository(),
    );
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

  /// A sitting over the trip with its checklists read, as the trip page
  /// opens one when the diver unlocks it (issue #4527).
  Future<EditSession<Trip>> openSitting() async {
    final session = EditSession<Trip>(upcomingTrip);
    addTearDown(session.dispose);
    await list.load(session);
    return session;
  }

  /// The checklists [session] holds, in their order.
  TripChecklistsHeld heldOf(EditSession<Trip> session) =>
      heldChecklistsOf(session, list)!;

  Future<void> pumpPanel(
    WidgetTester tester, {
    EditSession<Trip>? editing,
    List<dynamic> overrides = const [],
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...overrides,
        ],
        child: SingleChildScrollView(
          child: TripChecklistsPanel(trip: upcomingTrip, editing: editing),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('in a sitting, a trip with no checklists shows the empty state '
      'and the "add checklist" row', (tester) async {
    await pumpPanel(tester, editing: await openSitting());

    expect(
      find.text('No checklists yet - add one to start planning'),
      findsOneWidget,
    );
    expect(find.text('Add checklist'), findsOneWidget);
  });

  testWidgets('locked, a trip with no checklists shows the empty state and no '
      '"add checklist" row', (tester) async {
    await pumpPanel(tester);

    expect(
      find.text('No checklists yet - add one to start planning'),
      findsOneWidget,
    );
    expect(find.text('Add checklist'), findsNothing);
  });

  testWidgets('locked, the checklists show with no reorder arrows and no '
      '"add checklist" row', (tester) async {
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
    expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(find.text('Add checklist'), findsNothing);
  });

  testWidgets(
    'picking a template on the "add checklist" row holds a new checklist '
    'named after it with its items, no name prompt involved',
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

      final session = await openSitting();
      await pumpPanel(tester, editing: session);
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
      final held = heldOf(session);
      expect(held.checklists.single.name, 'Dive equipment');
      expect(
        [for (final i in held.itemsOf(held.checklists.single.id)) i.title],
        ['Mask'],
      );
      // Nothing is written until Save.
      expect(
        await checklistsRepository.getChecklistsForTrip(upcomingTrip.id),
        isEmpty,
      );
      expect(find.text('Dive equipment'), findsOneWidget);
      // A just-created checklist renders expanded (maintainer feedback
      // after testing): "Mask" is visible without an extra tap.
      expect(find.text('Mask'), findsOneWidget);
    },
  );

  Future<void> seedTemplate() async {
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
  }

  Future<void> addFromTemplate(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ListTile, 'Add checklist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply template...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dive equipment'));
    await tester.pumpAndSettle();
  }

  testWidgets('a new checklist opens even when its row reached the list '
      'before the template finished applying', (tester) async {
    // The sitting holds the new checklist at once, so the panel rebuilds
    // with its row while the template's items are still being read.
    await seedTemplate();
    final gate = Completer<void>();

    await pumpPanel(
      tester,
      editing: await openSitting(),
      overrides: [
        checklistTemplateRepositoryProvider.overrideWithValue(
          _GatedItemsRepository(gate.future),
        ),
      ],
    );
    await addFromTemplate(tester);
    expect(
      find.widgetWithText(ExpansionTile, 'Dive equipment'),
      findsOneWidget,
    );

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Mask'), findsOneWidget);
  });

  testWidgets('the panel going away while a template is applied still holds '
      'the whole checklist', (tester) async {
    await seedTemplate();
    final gate = Completer<void>();
    final session = await openSitting();

    await pumpPanel(
      tester,
      editing: session,
      overrides: [
        checklistTemplateRepositoryProvider.overrideWithValue(
          _GatedItemsRepository(gate.future),
        ),
      ],
    );
    await addFromTemplate(tester);

    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.pumpAndSettle();

    final held = heldOf(session);
    expect(held.checklists.single.name, 'Dive equipment');
    expect(
      [for (final i in held.itemsOf(held.checklists.single.id)) i.title],
      ['Mask'],
    );
  });

  testWidgets('a failed apply leaves no empty checklist behind', (
    tester,
  ) async {
    await seedTemplate();
    final session = await openSitting();

    await pumpPanel(
      tester,
      editing: session,
      overrides: [
        checklistTemplateRepositoryProvider.overrideWithValue(
          _FailingItemsRepository(),
        ),
      ],
    );
    await addFromTemplate(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(heldOf(session).checklists, isEmpty);
    expect(session.changedCardIds, isEmpty);
  });

  testWidgets('a block stays open across a tab switch', (tester) async {
    await checklistsRepository.createChecklist(
      tripId: upcomingTrip.id,
      name: 'Clothing',
    );
    final session = await openSitting();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Lists'),
                  Tab(text: 'Other'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      child: TripChecklistsPanel(
                        trip: upcomingTrip,
                        editing: session,
                      ),
                    ),
                    const SizedBox(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clothing'));
    await tester.pumpAndSettle();
    expect(find.text('Add section'), findsOneWidget);

    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();

    expect(find.text('Add section'), findsOneWidget);
  });

  testWidgets(
    '"New checklist..." prompts for a name, holds an empty checklist and '
    'renders it expanded',
    (tester) async {
      final session = await openSitting();
      await pumpPanel(tester, editing: session);

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
      expect(heldOf(session).checklists.single.name, 'Beach vacation');
      expect(find.text('Beach vacation'), findsOneWidget);
      // Renders expanded, like a template-created checklist: the empty
      // state's "Add section" affordance is already on screen.
      expect(find.text('Add section'), findsOneWidget);
    },
  );

  testWidgets('picking the same template twice holds two separately-named '
      'checklists, not one overwriting the other', (tester) async {
    await ChecklistTemplateRepository().createTemplate(
      ChecklistTemplate(
        id: '',
        name: 'Dive equipment',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final session = await openSitting();
    await pumpPanel(tester, editing: session);
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
    final checklists = heldOf(session).checklists;
    expect(checklists, hasLength(2));
    expect(checklists.every((c) => c.name == 'Dive equipment'), isTrue);
    expect({for (final c in checklists) c.id}, hasLength(2));
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
    await pumpPanel(tester, editing: await openSitting());

    expect(find.text('Dive equipment'), findsOneWidget);
    expect(find.text('Clothing'), findsOneWidget);
    // Neither checklist is auto-expanded, so neither's "Add item"
    // affordance (only rendered when expanded) is on screen yet.
    expect(find.text('Add item'), findsNothing);
  });

  testWidgets('the up/down arrows reorder checklists, written at Save', (
    tester,
  ) async {
    await checklistsRepository.createChecklist(
      tripId: upcomingTrip.id,
      name: 'A',
    );
    await checklistsRepository.createChecklist(
      tripId: upcomingTrip.id,
      name: 'B',
    );
    final session = await openSitting();
    await pumpPanel(tester, editing: session);

    // The first checklist's down arrow is the first one on screen (the
    // "add checklist" row has no reorder arrows of its own).
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(heldOf(session).checklists.map((c) => c.name).toList(), ['B', 'A']);
    // The new order shows at once, before anything is written.
    expect(
      tester.getTopLeft(find.text('B')).dy,
      lessThan(tester.getTopLeft(find.text('A')).dy),
    );

    await session.runHeldWrites();

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
      await pumpPanel(tester, editing: await openSitting());

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
