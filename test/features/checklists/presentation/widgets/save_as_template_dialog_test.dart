import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/data/repositories/trip_checklist_repository.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/widgets/save_as_template_dialog.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late TripRepository tripRepository;
  late TripChecklistRepository checklistRepository;
  late ChecklistTemplateRepository templateRepository;
  late Trip trip;

  setUp(() async {
    await setUpTestDatabase();
    tripRepository = TripRepository();
    checklistRepository = TripChecklistRepository();
    templateRepository = ChecklistTemplateRepository();
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
    await checklistRepository.createItem(
      TripChecklistItem(
        id: '',
        tripId: trip.id,
        title: 'Book flights',
        category: 'Bookings',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showSaveAsTemplateDialog(context: context, trip: trip),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty name fails validation and does not save', (tester) async {
    await openDialog(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(await templateRepository.getAllTemplates(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'entering a name and saving snapshots the checklist as a template '
    'and shows a success snackbar',
    (tester) async {
      await openDialog(tester);

      await tester.enterText(find.byType(TextFormField), 'Egypt prep');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Template saved'), findsOneWidget);

      final templates = await templateRepository.getAllTemplates();
      expect(templates, hasLength(1));
      expect(templates.single.name, 'Egypt prep');
      final items = await templateRepository.getItemsForTemplate(
        templates.single.id,
      );
      expect(items.single.title, 'Book flights');
      expect(items.single.category, 'Bookings');

      // Dialog is dismissed on success.
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('cancel dismisses the dialog without saving', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField), 'Discarded');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(await templateRepository.getAllTemplates(), isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('rapid double-tap on Save only saves once', (tester) async {
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField), 'Egypt prep');
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    // Two taps before the async save settles; the _saving guard + disabled
    // button must prevent a second saveAsTemplate.
    await tester.tap(saveButton);
    await tester.tap(saveButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(await templateRepository.getAllTemplates(), hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('dialog is not barrier-dismissible', (tester) async {
    await openDialog(tester);

    // Tapping the modal barrier (outside the dialog) must NOT dismiss it.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
