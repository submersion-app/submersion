import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_fill_hours_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  group('fillHoursProblem', () {
    test('neither time is fine', () {
      expect(fillHoursProblem(null, null), isNull);
    });
    test('one time alone is not', () {
      expect(fillHoursProblem(480, null), FillHoursProblem.missingOne);
      expect(fillHoursProblem(null, 1020), FillHoursProblem.missingOne);
    });
    test('closing must follow opening', () {
      expect(fillHoursProblem(480, 1020), isNull);
      expect(fillHoursProblem(1020, 480), FillHoursProblem.closesBeforeOpens);
      expect(fillHoursProblem(480, 480), FillHoursProblem.closesBeforeOpens);
    });
  });

  Future<void> pumpPage(WidgetTester tester, {String? centerId}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveCenterEditPage(
              centerId: centerId,
              embedded: true,
              onSaved: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickDefault(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
  }

  testWidgets('the fill hours save with a new center', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Dive Friends');
    // The pickers open at 08:00 and 17:00.
    await pickDefault(tester, 'fill-hours-opens');
    await pickDefault(tester, 'fill-hours-closes');
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('5:00 PM'), findsOneWidget);
    await save(tester);

    final saved = (await DiveCenterRepository().getAllDiveCenters()).single;
    expect(saved.fillOpensAt, 480);
    expect(saved.fillClosesAt, 1020);
  });

  testWidgets('one time alone blocks the save', (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Dive Friends');
    await pickDefault(tester, 'fill-hours-opens');
    await save(tester);
    expect(find.text('Set both times, or neither.'), findsOneWidget);
    expect(await DiveCenterRepository().getAllDiveCenters(), isEmpty);
  });

  testWidgets('editing keeps the fill hours', (tester) async {
    final now = DateTime(2026);
    final center = await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        name: 'Dive Friends',
        fillOpensAt: 480,
        fillClosesAt: 1020,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpPage(tester, centerId: center.id);
    await tester.enterText(find.byType(TextFormField).first, 'Dive Friends 2');
    await save(tester);
    final saved = await DiveCenterRepository().getDiveCenterById(center.id);
    expect(saved!.name, 'Dive Friends 2');
    expect(saved.fillOpensAt, 480);
    expect(saved.fillClosesAt, 1020);
  });

  testWidgets('clear removes the fill hours', (tester) async {
    final now = DateTime(2026);
    final center = await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        name: 'Dive Friends',
        fillOpensAt: 480,
        fillClosesAt: 1020,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await pumpPage(tester, centerId: center.id);
    await tester.ensureVisible(find.byKey(const Key('fill-hours-clear')));
    await tester.tap(find.byKey(const Key('fill-hours-clear')));
    await tester.pumpAndSettle();
    await save(tester);
    final saved = await DiveCenterRepository().getDiveCenterById(center.id);
    expect(saved!.fillOpensAt, isNull);
    expect(saved.fillClosesAt, isNull);
  });
}
