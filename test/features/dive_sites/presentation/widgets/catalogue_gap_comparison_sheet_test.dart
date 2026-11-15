import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_site_catalogue.dart';
import '../../../../helpers/mock_providers.dart';

const _wreckAt = GeoPoint(27.8138, 33.9200);
// About 40 m north.
const _siteAt = GeoPoint(27.81416, 33.9200);

const _record = CatalogueSite(
  id: 'ukho_1',
  name: 'SS Thistlegorm',
  location: _wreckAt,
  country: 'Egypt',
  region: 'Red Sea',
  maxDepth: 32,
  minDepth: 16,
  typeIds: ['wreck'],
  description: 'Cargo ship, lost 1941',
  source: 'ukho',
);

const _nearby = CataloguePair(
  site: DiveSite(id: 's1', name: 'Thistlegorm', location: _siteAt),
  record: _record,
  kind: CataloguePairKind.nearby,
  fields: {
    CatalogueGapField.depth,
    CatalogueGapField.siteTypes,
    CatalogueGapField.description,
  },
  distanceMeters: 40,
);

const _linked = CataloguePair(
  site: DiveSite(
    id: 's1',
    name: 'Thistlegorm',
    location: _siteAt,
    catalogueId: 'ukho_1',
  ),
  record: _record,
  kind: CataloguePairKind.linked,
  fields: {CatalogueGapField.depth},
  distanceMeters: 40,
);

const _named = CataloguePair(
  site: DiveSite(id: 's1', name: 'Thistlegorm'),
  record: _record,
  kind: CataloguePairKind.named,
  fields: {CatalogueGapField.position, CatalogueGapField.country},
);

void main() {
  CatalogueComparisonResult? result;
  var closed = false;

  Future<void> open(
    WidgetTester tester,
    CataloguePair pair, {
    Set<CatalogueGapField>? initial,
    DepthUnit depthUnit = DepthUnit.meters,
  }) async {
    result = null;
    closed = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1200);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(AppSettings(depthUnit: depthUnit)),
          ),
          siteCatalogueProvider.overrideWithValue(
            FakeSiteCatalogue(const [], const {
              'ukho': CatalogueSource(
                key: 'ukho',
                name: 'UK Hydrographic Office',
                licence: 'OGL-UK-3.0',
                credit: 'UK Hydrographic Office',
              ),
            }),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showCatalogueGapComparison(
                    context,
                    pair: pair,
                    initialFields: initial,
                  );
                  closed = true;
                },
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

  Finder tick(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(CheckboxListTile),
    ),
    matching: find.byType(Checkbox),
  );

  bool isTicked(WidgetTester tester, String label) =>
      tester.widget<Checkbox>(tick(label)).value!;

  testWidgets('a researched record is marked and explained', (tester) async {
    const pair = CataloguePair(
      site: DiveSite(id: 's1', name: 'Liberty', location: _siteAt),
      record: CatalogueSite(
        id: 'research_id_usat_liberty',
        name: 'USAT Liberty',
        location: _wreckAt,
        maxDepth: 30,
        source: 'research',
        trust: CatalogueTrust.researched,
      ),
      kind: CataloguePairKind.nearby,
      fields: {CatalogueGapField.depth},
      distanceMeters: 40,
    );
    await open(tester, pair);

    expect(find.text('Not verified'), findsOneWidget);
    expect(
      find.text(
        'Gathered from published sources, not from a survey. Check the '
        'position locally before you rely on it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a verified record carries neither', (tester) async {
    await open(tester, _nearby);

    expect(find.text('Not verified'), findsNothing);
  });

  testWidgets('shows the site, the record and where the record is from', (
    tester,
  ) async {
    await open(tester, _nearby);

    expect(find.text('Thistlegorm'), findsWidgets);
    expect(find.text('SS Thistlegorm'), findsWidgets);
    expect(find.text('Red Sea, Egypt'), findsOneWidget);
    expect(
      find.text(
        'From the built-in site catalogue. Source: UK Hydrographic Office',
      ),
      findsOneWidget,
    );
  });

  testWidgets('every offered field is listed, ticked, with its value', (
    tester,
  ) async {
    await open(tester, _nearby);

    for (final label in ['Depth Range', 'Site types', 'Description']) {
      expect(isTicked(tester, label), isTrue, reason: label);
    }
    expect(find.text('16m–32m'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('Cargo ship, lost 1941'), findsOneWidget);
    expect(find.text('(empty)'), findsNWidgets(3));
    expect(find.text('Fill in (3)'), findsOneWidget);
  });

  testWidgets('what stays the diver\'s is shown, without a tick', (
    tester,
  ) async {
    await open(tester, _nearby);

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('GPS Coordinates'), findsOneWidget);
    expect(find.text('27.8142, 33.9200'), findsOneWidget);
    expect(find.text('27.8138, 33.9200'), findsOneWidget);
    expect(find.textContaining('yours stays'), findsNWidgets(2));
    expect(find.textContaining('40m apart'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));
  });

  testWidgets('un-ticking a field changes what the button will fill', (
    tester,
  ) async {
    await open(tester, _nearby);

    await tester.tap(tick('Description'));
    await tester.pump();

    expect(isTicked(tester, 'Description'), isFalse);
    expect(find.text('Fill in (2)'), findsOneWidget);
  });

  testWidgets('the primary button returns the ticked fields to apply', (
    tester,
  ) async {
    await open(tester, _nearby);
    await tester.tap(tick('Description'));
    await tester.pump();

    await tester.tap(find.text('Fill in (2)'));
    await tester.pumpAndSettle();

    expect(result, isA<ComparisonApply>());
    expect((result! as ComparisonApply).fields, {
      CatalogueGapField.depth,
      CatalogueGapField.siteTypes,
    });
  });

  testWidgets('with nothing ticked an unlinked pair can still be linked', (
    tester,
  ) async {
    await open(tester, _nearby, initial: const {});

    expect(find.text('Link only'), findsOneWidget);
    await tester.tap(find.text('Link only'));
    await tester.pumpAndSettle();

    expect(result, isA<ComparisonApply>());
    expect((result! as ComparisonApply).fields, isEmpty);
  });

  testWidgets('an unlinked pair can be answered "Not the same site"', (
    tester,
  ) async {
    await open(tester, _nearby);

    expect(find.text('No thanks'), findsNothing);
    await tester.tap(find.text('Not the same site'));
    await tester.pumpAndSettle();

    expect(result, isA<ComparisonNotSame>());
  });

  testWidgets('a linked pair offers "No thanks", and no way to unlink', (
    tester,
  ) async {
    await open(tester, _linked);

    expect(find.text('Not the same site'), findsNothing);
    await tester.tap(find.text('No thanks'));
    await tester.pumpAndSettle();

    expect(result, isA<ComparisonNoThanks>());
  });

  testWidgets('a linked pair with nothing ticked has nothing to fill', (
    tester,
  ) async {
    await open(tester, _linked);

    await tester.tap(tick('Depth Range'));
    await tester.pump();

    expect(find.text('Link only'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('closing without acting hands back the ticks as they stand', (
    tester,
  ) async {
    await open(tester, _nearby);
    await tester.tap(tick('Description'));
    await tester.pump();

    // A tap on the scrim above the sheet dismisses it.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isA<ComparisonKept>());
    expect((result! as ComparisonKept).fields, {
      CatalogueGapField.depth,
      CatalogueGapField.siteTypes,
    });
  });

  testWidgets('the ticks it opens with are the ones handed in', (tester) async {
    await open(tester, _nearby, initial: {CatalogueGapField.depth});

    expect(isTicked(tester, 'Depth Range'), isTrue);
    expect(isTicked(tester, 'Site types'), isFalse);
    expect(find.text('Fill in (1)'), findsOneWidget);
  });

  testWidgets('a pair that gives a position shows where that is', (
    tester,
  ) async {
    await open(tester, _named);

    expect(isTicked(tester, 'GPS Coordinates'), isTrue);
    expect(find.text('27.8138, 33.9200'), findsOneWidget);
    expect(find.text('Red Sea, Egypt'), findsOneWidget);
    // Nothing of the diver's to compare a position with.
    expect(find.textContaining('apart'), findsNothing);
  });

  testWidgets('depths follow the diver\'s unit', (tester) async {
    await open(tester, _nearby, depthUnit: DepthUnit.feet);

    expect(find.text('52ft–105ft'), findsOneWidget);
    expect(find.textContaining('131ft apart'), findsOneWidget);
  });
}
