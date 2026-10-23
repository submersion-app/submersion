import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
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
        entryMethods: [EntryMethod.boat],
        exitMethods: [EntryMethod.ladder],
      ),
    );
    await expandAccess(tester);

    expect(find.text('Boat'), findsOneWidget);
    expect(find.text('Ladder'), findsOneWidget);
  });

  testWidgets('ticking two entry methods shows both on the row (#2054)', (
    tester,
  ) async {
    await pumpSiteEdit(tester);
    await expandAccess(tester);

    await tester.tap(find.text('Entry Method'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Back Roll'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Giant Stride'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(CheckboxListTile).first)).pop();
    await tester.pumpAndSettle();

    // Declaration order, not tick order.
    expect(find.text('Back Roll, Giant Stride'), findsOneWidget);
  });

  testWidgets('ticking exit methods shows them on the exit row', (
    tester,
  ) async {
    await pumpSiteEdit(tester);
    await expandAccess(tester);

    await tester.tap(find.text('Exit Method'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Platform'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Ladder'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(CheckboxListTile).first)).pop();
    await tester.pumpAndSettle();

    expect(find.text('Ladder, Platform'), findsOneWidget);
  });

  testWidgets('an existing site seeds every listed method', (tester) async {
    await pumpSiteEdit(
      tester,
      site: const DiveSite(
        id: 'site-3',
        name: 'Wall',
        entryMethods: [EntryMethod.backRoll, EntryMethod.giantStride],
        exitMethods: [EntryMethod.ladder, EntryMethod.platform],
      ),
    );
    await expandAccess(tester);

    expect(find.text('Back Roll, Giant Stride'), findsOneWidget);
    expect(find.text('Ladder, Platform'), findsOneWidget);
  });

  testWidgets('saving stores every ticked method', (tester) async {
    final created = await SiteRepository().createSite(
      const DiveSite(id: '', name: 'Wall'),
    );
    await pumpSiteEdit(tester, site: created);
    await expandAccess(tester);

    await tester.tap(find.text('Entry Method'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Giant Stride'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Back Roll'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(CheckboxListTile).first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await SiteRepository().getSiteById(created.id);
    expect(saved!.entryMethods, [
      EntryMethod.backRoll,
      EntryMethod.giantStride,
    ]);
  });

  testWidgets('a site with only an entry method still summarises', (
    tester,
  ) async {
    await pumpSiteEdit(
      tester,
      site: const DiveSite(
        id: 'site-2',
        name: 'Shore Spot',
        entryMethods: [EntryMethod.shore],
      ),
    );

    // Collapsed section: the summary line carries the value, which also
    // proves the section is not treated as empty.
    expect(find.text('Shore'), findsOneWidget);
  });
}
