import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_catalogue_offer_line.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_catalogue_gap_service.dart';
import '../../../../helpers/mock_providers.dart';

const _here = GeoPoint(27.8138, 33.92);
const _record = CatalogueSite(
  id: 'ukho_1',
  name: 'SS Thistlegorm',
  location: _here,
  maxDepth: 32,
  source: 'ukho',
);
const _unlinkedSite = DiveSite(id: 's1', name: 'Thistlegorm', location: _here);
const _linkedSite = DiveSite(
  id: 's1',
  name: 'Thistlegorm',
  location: _here,
  catalogueId: 'ukho_1',
);

const _nearby = CataloguePair(
  site: _unlinkedSite,
  record: _record,
  kind: CataloguePairKind.nearby,
  fields: {CatalogueGapField.depth},
  distanceMeters: 0,
);
const _linked = CataloguePair(
  site: _linkedSite,
  record: _record,
  kind: CataloguePairKind.linked,
  fields: {CatalogueGapField.depth},
  distanceMeters: 0,
);

final _pairs = StateProvider<List<CataloguePair>>((ref) => const []);

void main() {
  late FakeCatalogueGapService service;
  late ProviderContainer container;

  /// How many times the pairs have been looked for.
  var searches = 0;

  Future<void> pump(
    WidgetTester tester,
    DiveSite site, {
    required List<CataloguePair> pairs,
    void Function(CataloguePair, CatalogueComparisonResult)? onReviewed,
    bool reviewable = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1200);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = FakeCatalogueGapService();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        catalogueGapServiceProvider.overrideWithValue(service),
        _pairs.overrideWith((ref) => pairs),
        catalogueGapPairsProvider.overrideWith((ref) async {
          searches++;
          return ref.watch(_pairs);
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SiteCatalogueOfferLine(
              site: site,
              onReviewed: onReviewed,
              reviewable: reviewable,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a site with no pair shows nothing', (tester) async {
    await pump(tester, _unlinkedSite, pairs: const []);

    expect(find.text('Review'), findsNothing);
    expect(tester.getSize(find.byType(SiteCatalogueOfferLine)).height, 0);
  });

  testWidgets('an unlinked pair says the catalogue may hold the site', (
    tester,
  ) async {
    await pump(tester, _unlinkedSite, pairs: [_nearby]);

    expect(
      find.text('The built-in catalogue may hold this site.'),
      findsOneWidget,
    );
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('a linked pair says the catalogue has more details', (
    tester,
  ) async {
    await pump(tester, _linkedSite, pairs: [_linked]);

    expect(
      find.text('The built-in catalogue has more details for this site.'),
      findsOneWidget,
    );
  });

  testWidgets('Review opens the comparison, and its button applies', (
    tester,
  ) async {
    await pump(tester, _unlinkedSite, pairs: [_nearby]);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Fill in (1)'), findsOneWidget);
    await tester.tap(find.text('Fill in (1)'));
    await tester.pumpAndSettle();

    expect(service.applied.single.single.pair.site.id, 's1');
    expect(service.applied.single.single.fields, {CatalogueGapField.depth});
    expect(
      find.text('Sites linked: 1. Sites with details filled: 1.'),
      findsOneWidget,
    );
  });

  testWidgets('the line goes once the pair is dealt with', (tester) async {
    await pump(tester, _unlinkedSite, pairs: [_nearby]);

    container.read(_pairs.notifier).state = const [];
    await tester.pumpAndSettle();

    expect(find.text('Review'), findsNothing);
  });

  testWidgets('"Not the same site" is remembered', (tester) async {
    await pump(tester, _unlinkedSite, pairs: [_nearby]);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not the same site'));
    await tester.pumpAndSettle();

    expect(service.notSame, ['s1']);
    expect(service.applied, isEmpty);
  });

  testWidgets('"No thanks" turns the details down', (tester) async {
    await pump(tester, _linkedSite, pairs: [_linked]);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No thanks'));
    await tester.pumpAndSettle();

    expect(service.declined, ['s1']);
  });

  testWidgets('closing the comparison writes nothing', (tester) async {
    await pump(tester, _unlinkedSite, pairs: [_nearby]);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(service.applied, isEmpty);
    expect(service.notSame, isEmpty);
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('an apply still under way when the page goes is finished '
      'without complaint', (tester) async {
    await pump(tester, _unlinkedSite, pairs: [_nearby]);
    service.gate = Completer<void>();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill in (1)'));
    await tester.pumpAndSettle();
    // The diver moves on: the site's page leaves the screen.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: Text('elsewhere'))),
      ),
    );
    service.gate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(service.applied.single.single.pair.site.id, 's1');
    // The pairs are looked for again, as after any apply.
    final before = searches;
    await container.read(catalogueGapPairsProvider.future);
    expect(searches, before + 1);
  });

  testWidgets('a failed apply says so', (tester) async {
    await pump(tester, _unlinkedSite, pairs: [_nearby]);
    service.failure = StateError('disk full');

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fill in (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Could not apply the changes'), findsOneWidget);
  });

  testWidgets('with onReviewed the result is handed over and nothing is '
      'written', (tester) async {
    final handed = <CatalogueComparisonResult>[];
    await pump(
      tester,
      _unlinkedSite,
      pairs: [_nearby],
      onReviewed: (_, result) => handed.add(result),
    );

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not the same site'));
    await tester.pumpAndSettle();

    expect(handed.single, isA<ComparisonNotSame>());
    expect(service.notSame, isEmpty);
    expect(service.applied, isEmpty);
  });

  testWidgets('not reviewable shows the line without Review', (tester) async {
    await pump(tester, _unlinkedSite, pairs: [_nearby], reviewable: false);

    expect(find.text('Review'), findsNothing);
  });
}
