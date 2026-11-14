import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_weight_entry_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/settings/presentation/pages/body_weight_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const diverId = 'test-diver-id';

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('$diverId', 'Eric', 1000, 1000)",
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    DiverBodyProfile bodyProfile = (sex: null, ageYears: null),
    Diver? diver,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
          diverBodyProfileProvider.overrideWith((ref) async => bodyProfile),
          if (diver != null)
            currentDiverProvider.overrideWith((ref) async => diver),
        ],
        child: const BodyWeightEditPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('adds a measurement through the dialog', (tester) async {
    await pumpPage(tester);
    expect(find.text('Not recorded'), findsOneWidget);

    await tester.tap(find.text('Add measurement'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Weight (kg)'),
      '82.5',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('82.5 kg'), findsOneWidget);
    final entries = await DiverWeightEntryRepository().getEntriesForDiver(
      diverId,
    );
    expect(entries.single.weightKg, 82.5);
  });

  testWidgets('an unreadable weight keeps the dialog open and says why '
      '(#1900)', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Add measurement'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Weight (kg)'),
      '8..25',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enter a valid number'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget, reason: 'dialog still open');
    final entries = await DiverWeightEntryRepository().getEntriesForDiver(
      diverId,
    );
    expect(entries, isEmpty);
  });

  testWidgets('dialog cancel adds nothing; height renders in the subtitle', (
    tester,
  ) async {
    final repository = DiverWeightEntryRepository();
    final now = DateTime(2026, 6, 1);
    await repository.createEntry(
      DiverWeightEntry(
        id: '',
        diverId: diverId,
        measuredAt: now,
        weightKg: 80.0,
        heightCm: 180.0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpPage(tester);
    expect(find.textContaining('180 cm'), findsOneWidget);

    await tester.tap(find.text('Add measurement'));
    await tester.pumpAndSettle();
    // Exercise the date picker row, then back out of both dialogs.
    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await repository.getEntriesForDiver(diverId), hasLength(1));
  });

  testWidgets('imperial units enter and render height as feet and inches', (
    tester,
  ) async {
    await pumpPage(tester);

    // Switch to imperial (depth unit feet drives height units) before opening
    // the dialog, which reads the unit preference when it builds.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BodyWeightEditPage)),
    );
    await container
        .read(settingsProvider.notifier)
        .setDepthUnit(DepthUnit.feet);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add measurement'));
    await tester.pumpAndSettle();

    // Metric single field is gone; imperial shows two fields.
    expect(find.widgetWithText(TextField, 'Height (cm)'), findsNothing);
    expect(find.widgetWithText(TextField, 'Height (ft)'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Inches'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Weight (kg)'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'Height (ft)'), '5');
    await tester.enterText(find.widgetWithText(TextField, 'Inches'), '9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.textContaining('5\' 9"'), findsOneWidget);
    final entries = await DiverWeightEntryRepository().getEntriesForDiver(
      diverId,
    );
    expect(entries.single.heightCm, closeTo(175.26, 1e-9));
  });

  testWidgets('deletes a measurement from the list', (tester) async {
    final repository = DiverWeightEntryRepository();
    final now = DateTime(2026, 6, 1);
    await repository.createEntry(
      DiverWeightEntry(
        id: '',
        diverId: diverId,
        measuredAt: now,
        weightKg: 80.0,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await pumpPage(tester);
    expect(find.text('80.0 kg'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete entry'));
    await tester.pumpAndSettle();

    expect(find.text('Not recorded'), findsOneWidget);
    expect(await repository.getEntriesForDiver(diverId), isEmpty);
  });

  group('body fat (issue #4525)', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Add measurement'));
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    Future<List<DiverWeightEntry>> saved() =>
        DiverWeightEntryRepository().getEntriesForDiver(diverId);

    testWidgets('saving with a body fat stores it', (tester) async {
      await pumpPage(tester);
      await openDialog(tester);
      await tester.enterText(field('Weight (kg)'), '80');
      await tester.enterText(field('Body fat (%)'), '22.5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect((await saved()).single.bodyFatPercent, 22.5);
      expect(find.textContaining('22.5% body fat'), findsOneWidget);
    });

    testWidgets('leaving it blank stores none', (tester) async {
      await pumpPage(tester);
      await openDialog(tester);
      await tester.enterText(field('Weight (kg)'), '80');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect((await saved()).single.bodyFatPercent, isNull);
      expect(find.textContaining('body fat'), findsNothing);
    });

    testWidgets('a value outside 3 to 60 is rejected', (tester) async {
      await pumpPage(tester);
      await openDialog(tester);
      await tester.enterText(field('Weight (kg)'), '80');
      for (final bad in ['2', '75']) {
        await tester.enterText(field('Body fat (%)'), bad);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a value from 3 to 60'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget, reason: 'dialog still open');
      }
      expect(await saved(), isEmpty);
    });

    testWidgets('the estimate shows once weight, height, sex and birth year '
        'are known', (tester) async {
      await pumpPage(tester, bodyProfile: (sex: DiverSex.male, ageYears: 40));
      await openDialog(tester);
      expect(find.textContaining('Estimated: about'), findsNothing);

      await tester.enterText(field('Weight (kg)'), '80');
      await tester.enterText(field('Height (cm)'), '175');
      await tester.pumpAndSettle();
      // 1.20 * 26.12 + 0.23 * 40 - 10.8 - 5.4 = 24.3
      expect(find.text('Estimated: about 24%'), findsOneWidget);
      expect(find.textContaining('Add sex and birth year'), findsNothing);
    });

    testWidgets('the estimate falls back to the last recorded height', (
      tester,
    ) async {
      final at = DateTime(2026, 6, 1);
      await DiverWeightEntryRepository().createEntry(
        DiverWeightEntry(
          id: '',
          diverId: diverId,
          measuredAt: at,
          weightKg: 90,
          heightCm: 175,
          createdAt: at,
          updatedAt: at,
        ),
      );
      await pumpPage(tester, bodyProfile: (sex: DiverSex.male, ageYears: 40));
      await openDialog(tester);
      await tester.enterText(field('Weight (kg)'), '80');
      await tester.pumpAndSettle();
      expect(find.text('Estimated: about 24%'), findsOneWidget);
    });

    testWidgets('without sex or birth year a hint says where to add them', (
      tester,
    ) async {
      await pumpPage(tester, bodyProfile: (sex: DiverSex.male, ageYears: null));
      await openDialog(tester);
      await tester.enterText(field('Weight (kg)'), '80');
      await tester.enterText(field('Height (cm)'), '175');
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Add sex and birth year under Personal info to see an estimate.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Estimated: about'), findsNothing);
    });

    // The adult formula does not cover a junior diver, so their age reads
    // as unknown. Both fields are filled in all the same: there is nothing
    // to add, and no estimate to show.
    testWidgets('a birth year the estimate cannot use asks for nothing', (
      tester,
    ) async {
      final at = DateTime(2026, 6, 1);
      await pumpPage(
        tester,
        bodyProfile: (sex: DiverSex.male, ageYears: null),
        diver: Diver(
          id: diverId,
          name: 'Eric',
          sex: DiverSex.male,
          birthYear: DateTime.now().year - 12,
          createdAt: at,
          updatedAt: at,
        ),
      );
      await openDialog(tester);
      await tester.enterText(field('Weight (kg)'), '45');
      await tester.enterText(field('Height (cm)'), '150');
      await tester.pumpAndSettle();

      expect(find.textContaining('Add sex and birth year'), findsNothing);
      expect(find.textContaining('Estimated: about'), findsNothing);
    });

    testWidgets('the list shows body fat only on entries that have it', (
      tester,
    ) async {
      final repository = DiverWeightEntryRepository();
      for (final (day, fat) in [(1, 20.0), (2, null)]) {
        final at = DateTime(2026, 6, day);
        await repository.createEntry(
          DiverWeightEntry(
            id: '',
            diverId: diverId,
            measuredAt: at,
            weightKg: 80,
            heightCm: 180,
            bodyFatPercent: fat,
            createdAt: at,
            updatedAt: at,
          ),
        );
      }
      await pumpPage(tester);
      expect(find.textContaining('20% body fat'), findsOneWidget);
      expect(find.textContaining('180 cm'), findsNWidgets(2));
    });
  });
}
