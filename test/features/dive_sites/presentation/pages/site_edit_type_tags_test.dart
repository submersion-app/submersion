import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// The Type & Tags section on the real site edit page (issue #1765).
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    await SiteRepository().createSite(
      const DiveSite(id: 'site-1', name: 'Quarry wall'),
      classification: const SiteClassification(typeIds: ['wall']),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<void> pumpEdit(
    WidgetTester tester, {
    void Function(String)? onSaved,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => const <Diver>[]),
          shareByDefaultProvider.overrideWith((_) async => false),
          validatedCurrentDiverIdProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteEditPage(
              siteId: 'site-1',
              embedded: true,
              onSaved: onSaved ?? (_) {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an existing site shows its types selected', (tester) async {
    await pumpEdit(tester);

    expect(find.text('Type & Tags'), findsOneWidget);
    final wall = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Wall'),
    );
    final lake = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Lake'),
    );
    expect(wall.selected, isTrue);
    expect(lake.selected, isFalse);
  });

  testWidgets('saving writes the chosen types', (tester) async {
    String? savedId;
    await pumpEdit(tester, onSaved: (id) => savedId = id);

    await tester.tap(find.widgetWithText(FilterChip, 'Lake'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(savedId, 'site-1');
    final types = await tester.runAsync(
      () => SiteClassificationRepository().getTypesForSite('site-1'),
    );
    expect(types!.map((t) => t.id), ['wall', 'lake']);
  });
}
