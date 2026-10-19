import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_item_edit_sheet.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Pumps a host page with a button that opens the sheet for [tripId], seeded
/// with an optional existing [item], [categorySuggestions] (section titles)
/// and the [item]'s [currentSectionTitle].
Future<void> _openSheet(
  WidgetTester tester, {
  required String tripId,
  TripChecklistItem? item,
  List<String> categorySuggestions = const [],
  String? currentSectionTitle,
}) async {
  await tester.pumpWidget(
    testApp(
      // Every finder below matches a localized label, so the UI language has
      // to be deterministic rather than the host machine's.
      locale: const Locale('en'),
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () => showChecklistItemEditSheet(
            context: context,
            tripId: tripId,
            item: item,
            categorySuggestions: categorySuggestions,
            currentSectionTitle: currentSectionTitle,
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

  /// The title of the section [item] is grouped under, resolving `null` for
  /// an unsectioned item, mirroring what the real caller
  /// (TripChecklistSection widget) passes as `currentSectionTitle`.
  Future<String?> sectionTitleOf(TripChecklistItem item) async {
    if (item.sectionId == null) return null;
    final sections = await checklistRepository.getSectionsForTrip(trip.id);
    return sections.firstWhere((s) => s.id == item.sectionId).title;
  }

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
    final section = await checklistRepository.createSection(
      tripId: trip.id,
      title: 'Gear',
    );
    final existing = await checklistRepository.createItem(
      TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Fins',
        sectionId: section.id,
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
      currentSectionTitle: 'Gear',
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

  testWidgets('editing an item in the second of two same-titled sections '
      'keeps it there', (tester) async {
    await checklistRepository.createSection(
      tripId: trip.id,
      title: 'New section',
    );
    final second = await checklistRepository.createSection(
      tripId: trip.id,
      title: 'New section',
    );
    final existing = await checklistRepository.createItem(
      TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Fins',
        sectionId: second.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await _openSheet(
      tester,
      tripId: trip.id,
      item: existing,
      categorySuggestions: const ['New section'],
      currentSectionTitle: 'New section',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Split fins',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final items = await checklistRepository.getByTripId(trip.id);
    expect(items.single.title, 'Split fins');
    expect(items.single.sectionId, second.id);
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
    // Compute the expected label with the same formatter the widget uses
    // (DateFormat.yMMMd) so the assertion is locale-independent.
    expect(
      find.text(DateFormat.yMMMd().format(DateTime(2026, 8, 1))),
      findsOneWidget,
    );
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
      expect(await sectionTitleOf(items.single), 'Gear');
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

  testWidgets(
    'the category suggestion list is navigable with the arrow keys and '
    'committed with Enter',
    (tester) async {
      await _openSheet(
        tester,
        tripId: trip.id,
        categorySuggestions: const ['Gases', 'Galley', 'Bookings'],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Category'),
        'Ga',
      );
      await tester.pumpAndSettle();

      // Both matches are offered, with the first one highlighted.
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Gases'))
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Galley'))
            .selected,
        isFalse,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Galley'))
            .selected,
        isTrue,
      );

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Fill twinset',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByTripId(trip.id);
      expect(await sectionTitleOf(items.single), 'Galley');
    },
  );

  testWidgets('a category typed in a different case folds onto the existing '
      'one', (tester) async {
    final diving = await checklistRepository.createSection(
      tripId: trip.id,
      title: 'Diving',
    );
    await _openSheet(
      tester,
      tripId: trip.id,
      categorySuggestions: const ['Diving', 'Bookings'],
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Check torch',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Category'),
      'diving',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final items = await checklistRepository.getByTripId(trip.id);
    // Folds onto the existing section rather than creating 'diving' anew.
    expect(items.single.sectionId, diving.id);
    expect(await checklistRepository.getSectionsForTrip(trip.id), hasLength(1));
  });

  testWidgets(
    'a category with no case-insensitive match keeps what was typed',
    (tester) async {
      await _openSheet(
        tester,
        tripId: trip.id,
        categorySuggestions: const ['Diving'],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Renew insurance',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Category'),
        'paperwork',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final items = await checklistRepository.getByTripId(trip.id);
      expect(await sectionTitleOf(items.single), 'paperwork');
    },
  );
}
