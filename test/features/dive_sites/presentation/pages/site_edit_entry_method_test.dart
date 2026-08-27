import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  final divers = [
    Diver(
      id: 'd1',
      name: 'One',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    ),
  ];

  Future<void> pumpSiteEdit(WidgetTester tester, {DiveSite? site}) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          allDiversProvider.overrideWith((_) async => divers),
          shareByDefaultProvider.overrideWith((_) async => false),
          if (site != null)
            siteProvider(site.id).overrideWith((_) async => site),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: site == null
              ? const SiteEditPage()
              : SiteEditPage(siteId: site.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The Access & safety group rests collapsed; the header row is the toggle.
  Future<void> expandAccess(WidgetTester tester) async {
    final header = find.text('Access & safety');
    await tester.scrollUntilVisible(
      header,
      50.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  testWidgets('the access section shows entry and exit method rows', (
    tester,
  ) async {
    await pumpSiteEdit(tester);
    await expandAccess(tester);

    expect(find.text('Entry Method'), findsOneWidget);
    expect(find.text('Exit Method'), findsOneWidget);
  });

  testWidgets('an existing site seeds both pickers', (tester) async {
    await pumpSiteEdit(
      tester,
      site: const DiveSite(
        id: 'site-1',
        name: 'Blue Hole',
        entryMethod: EntryMethod.boat,
        exitMethod: EntryMethod.ladder,
      ),
    );
    await expandAccess(tester);

    expect(find.text('Boat Entry'), findsOneWidget);
    expect(find.text('Ladder'), findsOneWidget);
  });

  testWidgets('picking an entry method updates the row', (tester) async {
    await pumpSiteEdit(tester);
    await expandAccess(tester);

    await tester.tap(find.text('Entry Method'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Shore Entry'));
    await tester.pumpAndSettle();

    expect(find.text('Shore Entry'), findsOneWidget);
  });

  testWidgets('a site with only an entry method still summarises', (
    tester,
  ) async {
    await pumpSiteEdit(
      tester,
      site: const DiveSite(
        id: 'site-2',
        name: 'Shore Spot',
        entryMethod: EntryMethod.shore,
      ),
    );

    // Collapsed section: the summary line carries the value, which also
    // proves the section is not treated as empty.
    expect(find.text('Shore Entry'), findsOneWidget);
  });
}
