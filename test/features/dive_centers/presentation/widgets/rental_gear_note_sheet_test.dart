import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_note_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveCenterGearNoteRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveCenterGearNoteRepository();
    await db
        .into(db.diveCenters)
        .insert(
          const DiveCentersCompanion(
            id: Value('c1'),
            name: Value('Reef Divers'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    // The dive the sheet is opened from; the note's dive link references it.
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('d1'),
            diveDateTime: Value(0),
            diveCenterId: Value('c1'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(
    WidgetTester tester, {
    DiveCenterGearNote? editing,
    MockSettingsNotifier? settings,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => settings ?? MockSettingsNotifier(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRentalGearNoteSheet(
                  context,
                  diveCenterId: 'c1',
                  diveId: 'd1',
                  editing: editing,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder fieldLabelled(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  /// Opens the gear type menu and picks [label]. The menu opens scrolled to
  /// the selected type, so an item near the top must be scrolled into view
  /// before it exists in the tree.
  Future<void> pickGearType(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<EquipmentType>));
    await tester.pumpAndSettle();
    // With the menu open the closed field still reads the old type, so the
    // label exists once, in the menu.
    await tester.scrollUntilVisible(
      find.text(label),
      -100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('creates a note with the typed fields converted to metric', (
    tester,
  ) async {
    final imperial = MockSettingsNotifier();
    await imperial.setImperial();
    await pumpAndOpen(tester, settings: imperial);
    expect(find.text('New rental note'), findsOneWidget);
    // The volume field only shows for tanks.
    expect(find.text('Actual capacity (cuft)'), findsNothing);

    await pickGearType(tester, 'BCD');
    await tester.enterText(fieldLabelled('Label or number'), 'blue 3');
    await tester.enterText(fieldLabelled('Size'), 'L');
    await tester.tap(find.text('Avoid'));
    await tester.enterText(fieldLabelled('Extra lead needed (lbs)'), '4.4');
    await tester.enterText(fieldLabelled('Note'), 'inflator sticks');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getForCenter('c1')).single;
    expect(stored.gearType, EquipmentType.bcd);
    expect(stored.label, 'blue 3');
    expect(stored.size, 'L');
    expect(stored.verdict, RentalVerdict.avoid);
    expect(stored.leadAdjustmentKg, closeTo(2.0, 0.01));
    expect(stored.volumeLiters, isNull);
    expect(stored.note, 'inflator sticks');
    expect(stored.diveId, 'd1');
    // The sheet closed.
    expect(find.text('New rental note'), findsNothing);
  });

  testWidgets('a tank note shows and stores the actual capacity', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await pickGearType(tester, 'Tank');
    expect(find.text('Actual capacity (L)'), findsOneWidget);
    await tester.enterText(fieldLabelled('Label or number'), 'AL80');
    await tester.enterText(fieldLabelled('Actual capacity (L)'), '11.1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getForCenter('c1')).single;
    expect(stored.gearType, EquipmentType.tank);
    expect(stored.volumeLiters, 11.1);
    expect(stored.verdict, RentalVerdict.worked);
  });

  testWidgets('editing seeds the fields and saves over the row', (
    tester,
  ) async {
    final existing = await repo.create(
      DiveCenterGearNote(
        id: '',
        diveCenterId: 'c1',
        gearType: EquipmentType.regulator,
        label: '14',
        verdict: RentalVerdict.avoid,
        leadAdjustmentKg: 1.5,
        note: 'wet',
        notedAt: DateTime.utc(2026, 9, 1),
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await pumpAndOpen(tester, editing: existing);
    expect(find.text('Edit rental note'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('wet'), findsOneWidget);

    await tester.enterText(fieldLabelled('Note'), 'fine after service');
    await tester.tap(find.text('Worked'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = (await repo.getForCenter('c1')).single;
    expect(stored.id, existing.id);
    expect(stored.verdict, RentalVerdict.worked);
    expect(stored.note, 'fine after service');
    expect(stored.leadAdjustmentKg, 1.5);
  });

  testWidgets('delete asks first, then removes the note', (tester) async {
    final existing = await repo.create(
      DiveCenterGearNote(
        id: '',
        diveCenterId: 'c1',
        gearType: EquipmentType.wetsuit,
        size: 'L',
        verdict: RentalVerdict.avoid,
        note: 'runs small',
        notedAt: DateTime.utc(2026, 9, 1),
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await pumpAndOpen(tester, editing: existing);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this rental note?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await repo.getForCenter('c1'), isEmpty);
    expect(find.text('Edit rental note'), findsNothing);
  });

  testWidgets('unreadable lead is refused and nothing is saved', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.enterText(fieldLabelled('Extra lead needed (kg)'), 'two');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid number'), findsOneWidget);
    expect(await repo.getForCenter('c1'), isEmpty);
    expect(find.text('New rental note'), findsOneWidget);
  });

  testWidgets('a failed save keeps the editor open with an error', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    // The center disappears under the open sheet (a sync delete), so the
    // insert fails its foreign key.
    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();
    await (db.delete(db.diveCenters)..where((t) => t.id.equals('c1'))).go();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('New rental note'), findsOneWidget);
  });

  testWidgets('cancel closes without saving', (tester) async {
    await pumpAndOpen(tester);
    await tester.enterText(fieldLabelled('Note'), 'never saved');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('New rental note'), findsNothing);
    expect(await repo.getForCenter('c1'), isEmpty);
  });

  testWidgets('editing a tank note seeds its capacity', (tester) async {
    final existing = await repo.create(
      DiveCenterGearNote(
        id: '',
        diveCenterId: 'c1',
        gearType: EquipmentType.tank,
        label: 'AL80',
        volumeLiters: 11.1,
        notedAt: DateTime.utc(2026, 9, 1),
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await pumpAndOpen(tester, editing: existing);
    expect(find.widgetWithText(TextField, '11.1'), findsOneWidget);
  });

  testWidgets('declining the delete keeps the note', (tester) async {
    final existing = await repo.create(
      DiveCenterGearNote(
        id: '',
        diveCenterId: 'c1',
        gearType: EquipmentType.fins,
        notedAt: DateTime.utc(2026, 9, 1),
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ),
    );
    await pumpAndOpen(tester, editing: existing);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();

    expect(await repo.getForCenter('c1'), hasLength(1));
    expect(find.text('Edit rental note'), findsOneWidget);
  });
}
