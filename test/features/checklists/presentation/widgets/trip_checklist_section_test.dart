import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
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
  String? category,
  bool isDone = false,
  DateTime? dueDate,
}) => TripChecklistItem(
  id: id,
  tripId: 't1',
  title: title,
  category: category,
  isDone: isDone,
  dueDate: dueDate,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('groups items by category and shows checkboxes', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith(
            (ref) async => [
              _item(id: 'i1', title: 'Service regulator', category: 'Gear'),
              _item(id: 'i2', title: 'Book flights', category: 'Bookings'),
              _item(id: 'i3', title: 'Passport check'),
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

  testWidgets('shows overdue chip only for upcoming trips', (tester) async {
    final overdue = _item(
      dueDate: DateTime.now().subtract(const Duration(days: 3)),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          tripChecklistProvider('t1').overrideWith((ref) async => [overdue]),
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

    testWidgets('editing an item via the tile menu updates it', (tester) async {
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

      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit item'));
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

    testWidgets('deleting an item via the tile menu removes it', (
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
      expect(find.text('Fins'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete item'));
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
  });
}
