import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The permanently closed switch on the dive center edit page (#3379).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<DiveCenter> seed({bool closed = false}) {
    final now = DateTime(2026);
    return DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        name: 'Toucan Diving',
        isPermanentlyClosed: closed,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> pumpPage(WidgetTester tester, String centerId) async {
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

  Finder closedSwitch() =>
      find.widgetWithText(SwitchListTile, 'Permanently closed');

  testWidgets('a closed center opens with the switch on', (tester) async {
    final center = await seed(closed: true);
    await pumpPage(tester, center.id);

    expect(tester.widget<SwitchListTile>(closedSwitch()).value, isTrue);
    expect(
      find.text(
        'Still kept for past dives; left out of nearby centers in the picker.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('flipping only the switch saves it', (tester) async {
    final center = await seed();
    await pumpPage(tester, center.id);

    expect(tester.widget<SwitchListTile>(closedSwitch()).value, isFalse);
    await tester.ensureVisible(closedSwitch());
    await tester.tap(closedSwitch());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final saved = await DiveCenterRepository().getDiveCenterById(center.id);
    expect(saved!.isPermanentlyClosed, isTrue);
    expect(saved.name, 'Toucan Diving');
  });
}
