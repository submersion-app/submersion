import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_item_edit_sheet.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Pumps a host page with a button that opens the sheet for [tripId], seeded
/// with an optional existing [item] and [categorySuggestions].
Future<void> _openSheet(
  WidgetTester tester, {
  required String tripId,
  TripChecklistItem? item,
  List<String> categorySuggestions = const [],
}) async {
  await tester.pumpWidget(
    testApp(
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => showChecklistItemEditSheet(
            context: context,
            tripId: tripId,
            item: item,
            categorySuggestions: categorySuggestions,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late TripRepository tripRepository;
  late TripChecklistRepository checklistRepository;
  late Trip trip;

  setUp(() async {
    await setUpTestDatabase();
    tripRepository = TripRepository();
    checklistRepository = TripChecklistRepository();
    trip = await tripRepository.createTrip(
      Trip(
        id: '',
        name: 'Red Sea',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 17),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  testWidgets('creating a new item persists it via the repository', (
    tester,
  ) async {
    await _openSheet(tester, tripId: trip.id);

    expect(find.text('Title'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Mask');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notes'),
      'annual check',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final items = await checklistRepository.getByTripId(trip.id);
    expect(items, hasLength(1));
    expect(items.single.title, 'Mask');
    expect(items.single.notes, 'annual check');
  });

  testWidgets('empty title fails validation and does not persist', (
    tester,
  ) async {
    await _openSheet(tester, tripId: trip.id);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect(await checklistRepository.getByTripId(trip.id), isEmpty);
  });

  testWidgets('editing an existing item updates it in place', (tester) async {
    final existing = await checklistRepository.createItem(
      TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Fins',
        category: 'Gear',
        notes: 'old notes',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await _openSheet(
      tester,
      tripId: trip.id,
      item: existing,
      categorySuggestions: const ['Gear', 'Bookings'],
    );

    // Prefilled fields.
    expect(find.text('Fins'), findsOneWidget);
    expect(find.text('old notes'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Split fins',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final items = await checklistRepository.getByTripId(trip.id);
    expect(items, hasLength(1));
    expect(items.single.title, 'Split fins');
    expect(items.single.id, existing.id);
  });

  testWidgets('clearing an existing due date removes it on save', (
    tester,
  ) async {
    final existing = await checklistRepository.createItem(
      TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Book flights',
        dueDate: DateTime(2026, 8, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await _openSheet(tester, tripId: trip.id, item: existing);

    // Due-date chip renders the formatted date and a clear button when set.
    expect(find.text('Aug 1, 2026'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();
    expect(find.text('-'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final items = await checklistRepository.getByTripId(trip.id);
    expect(items.single.dueDate, isNull);
  });

  testWidgets(
    'the category field offers matching suggestions and selecting one '
    'fills it in',
    (tester) async {
      await _openSheet(
        tester,
        tripId: trip.id,
        categorySuggestions: const ['Gear', 'Bookings'],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Category'),
        'Ge',
      );
      await tester.pumpAndSettle();

      // The autocomplete options overlay shows the matching suggestion but
      // not the non-matching one.
      expect(find.widgetWithText(ListTile, 'Gear'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Bookings'), findsNothing);

      await tester.tap(find.widgetWithText(ListTile, 'Gear'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Category'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Wetsuit',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByTripId(trip.id);
      expect(items.single.category, 'Gear');
    },
  );

  testWidgets('due date field with no date shows a calendar affordance', (
    tester,
  ) async {
    await _openSheet(tester, tripId: trip.id);
    expect(find.text('-'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsNothing);
  });

  testWidgets('tapping the due date row opens the date picker and picking '
      'a day sets it', (tester) async {
    await _openSheet(tester, tripId: trip.id);

    await tester.tap(find.text('Due date'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Confirm the pre-selected initial date (today) via the OK action.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // A due-date chip with a clear button now replaces the calendar icon.
    expect(find.byIcon(Icons.clear), findsOneWidget);
  });
}
