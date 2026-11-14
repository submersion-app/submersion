import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_gap_service.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/catalogue_gap_review_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/catalogue_gap_review_notifier.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_site_catalogue.dart';
import '../../../../helpers/mock_providers.dart';

const _here = GeoPoint(12.0835, -68.2826);

final _saltPier = CataloguePair(
  site: const DiveSite(id: 'pier', name: 'Salt Pier', location: _here),
  record: const CatalogueSite(
    id: 'r_pier',
    name: 'Salt Pier',
    location: _here,
    maxDepth: 15,
    minDepth: 5,
    typeIds: ['reef'],
    source: 'osm',
  ),
  kind: CataloguePairKind.sure,
  fields: const {CatalogueGapField.depth, CatalogueGapField.siteTypes},
  distanceMeters: 0,
);

final _hooker = CataloguePair(
  site: const DiveSite(
    id: 'hooker',
    name: 'Hilma Hooker',
    location: _here,
    catalogueId: 'r_hooker',
  ),
  record: const CatalogueSite(
    id: 'r_hooker',
    name: 'Hilma Hooker',
    location: _here,
    description: 'Freighter, sunk 1984',
    source: 'osm',
  ),
  kind: CataloguePairKind.linked,
  fields: const {CatalogueGapField.description},
  distanceMeters: 0,
);

final _thistlegorm = CataloguePair(
  site: const DiveSite(id: 'wreck', name: 'Thistlegorm', location: _here),
  record: const CatalogueSite(
    id: 'r_wreck',
    name: 'SS Thistlegorm',
    location: _here,
    maxDepth: 32,
    source: 'ukho',
  ),
  kind: CataloguePairKind.nearby,
  fields: const {CatalogueGapField.depth},
  distanceMeters: 40,
);

final _blueHole = CataloguePair(
  site: const DiveSite(id: 'hole', name: 'Blue Hole'),
  record: const CatalogueSite(
    id: 'r_hole',
    name: 'Blue Hole',
    location: GeoPoint(28.5722, 34.5370),
    country: 'Egypt',
    region: 'South Sinai',
    source: 'osm',
  ),
  kind: CataloguePairKind.named,
  fields: const {CatalogueGapField.position, CatalogueGapField.country},
);

/// A service that records what it is asked and answers when told to.
class _Service extends CatalogueGapService {
  _Service()
    : super(
        siteRepository: SiteRepository(),
        catalogue: FakeSiteCatalogue(),
        classification: SiteClassificationRepository(),
        fills: SiteCatalogueFillRepository(),
      );

  final applied = <List<CatalogueApplyRequest>>[];
  CatalogueApplyResult result = const CatalogueApplyResult(
    linked: 1,
    filled: 2,
  );

  /// When set, an apply waits for it.
  Completer<void>? gate;
  Object? failure;

  @override
  Future<CatalogueApplyResult> apply(
    List<CatalogueApplyRequest> requests, {
    required String? diverId,
  }) async {
    applied.add(requests);
    await gate?.future;
    if (failure != null) throw failure!;
    return result;
  }
}

final _pairs = StateProvider<List<CataloguePair>?>((ref) => null);

void main() {
  late _Service service;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    required List<CataloguePair>? pairs,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = _Service();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        catalogueGapServiceProvider.overrideWithValue(service),
        _pairs.overrideWith((ref) => pairs),
        catalogueGapPairsProvider.overrideWith((ref) {
          final now = ref.watch(_pairs);
          // Null stands for a catalogue that has not been read yet.
          return now == null
              ? Completer<List<CataloguePair>>().future
              : Future.value(now);
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CatalogueGapReviewPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder checkboxFor(String siteName) => find.descendant(
    of: find.ancestor(of: find.text(siteName), matching: find.byType(ListTile)),
    matching: find.byType(Checkbox),
  );

  bool ticked(WidgetTester tester, String siteName) =>
      tester.widget<Checkbox>(checkboxFor(siteName)).value!;

  testWidgets('pairs are listed in two sections with their counts', (
    tester,
  ) async {
    await pump(tester, pairs: [_saltPier, _hooker, _thistlegorm, _blueHole]);

    expect(find.text('Built-in details for your sites'), findsOneWidget);
    expect(find.text('Same site (2)'), findsOneWidget);
    expect(find.text('Check these (2)'), findsOneWidget);
    expect(find.text('Salt Pier'), findsOneWidget);
    expect(find.text('Adds: link, 5m–15m, Reef'), findsOneWidget);
    expect(find.text('Adds: Description'), findsOneWidget);
    expect(find.text('40m from "SS Thistlegorm"'), findsOneWidget);
    expect(
      find.text('No position. "Blue Hole", South Sinai, Egypt'),
      findsOneWidget,
    );
  });

  testWidgets('a section with nothing in it is not shown', (tester) async {
    await pump(tester, pairs: [_saltPier]);

    expect(find.text('Same site (1)'), findsOneWidget);
    expect(find.textContaining('Check these'), findsNothing);
  });

  testWidgets('sure pairs start ticked, the others do not', (tester) async {
    await pump(tester, pairs: [_saltPier, _hooker, _thistlegorm, _blueHole]);

    expect(ticked(tester, 'Salt Pier'), isTrue);
    expect(ticked(tester, 'Hilma Hooker'), isTrue);
    expect(ticked(tester, 'Thistlegorm'), isFalse);
    expect(ticked(tester, 'Blue Hole'), isFalse);
    expect(find.text('Apply (2)'), findsOneWidget);
  });

  testWidgets('ticking a row changes what Apply will do', (tester) async {
    await pump(tester, pairs: [_saltPier, _thistlegorm]);

    await tester.tap(checkboxFor('Thistlegorm'));
    await tester.pump();
    expect(find.text('Apply (2)'), findsOneWidget);

    await tester.tap(checkboxFor('Salt Pier'));
    await tester.tap(checkboxFor('Thistlegorm'));
    await tester.pump();
    expect(find.text('Apply (0)'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('Apply sends the ticked rows only, with their fields', (
    tester,
  ) async {
    await pump(tester, pairs: [_saltPier, _hooker, _thistlegorm]);

    await tester.tap(find.text('Apply (2)'));
    await tester.pumpAndSettle();

    final requests = service.applied.single;
    expect([for (final r in requests) r.pair.site.id], ['pier', 'hooker']);
    expect(requests.first.fields, _saltPier.fields);
    // It stays on the page and says what happened.
    expect(find.byType(CatalogueGapReviewPage), findsOneWidget);
    expect(
      find.text('Sites linked: 1. Sites with details filled: 2.'),
      findsOneWidget,
    );
  });

  testWidgets('pairs that could not be applied are counted in the message', (
    tester,
  ) async {
    await pump(tester, pairs: [_saltPier]);
    service.result = const CatalogueApplyResult(linked: 0, notApplied: 1);

    await tester.tap(find.text('Apply (1)'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Sites linked: 0. Sites with details filled: 0. Not applied: 1.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed apply says so and leaves the rows', (tester) async {
    await pump(tester, pairs: [_saltPier]);
    service.failure = StateError('disk full');

    await tester.tap(find.text('Apply (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Could not apply the changes'), findsOneWidget);
    expect(find.text('Salt Pier'), findsOneWidget);
    expect(find.text('Apply (1)'), findsOneWidget);
  });

  testWidgets('a second Apply while the first runs sends nothing', (
    tester,
  ) async {
    await pump(tester, pairs: [_saltPier]);
    service.gate = Completer<void>();

    await tester.tap(find.text('Apply (1)'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    // The notifier refuses too, whatever the button's state.
    expect(
      await container.read(catalogueGapReviewProvider.notifier).applyTicked(),
      isNull,
    );

    service.gate!.complete();
    await tester.pumpAndSettle();

    expect(service.applied, hasLength(1));
  });

  testWidgets('applied rows leave, the rest stay', (tester) async {
    await pump(tester, pairs: [_saltPier, _thistlegorm]);

    await tester.tap(find.text('Apply (1)'));
    await tester.pumpAndSettle();
    // The pairs are found again once the sites have changed.
    container.read(_pairs.notifier).state = [_thistlegorm];
    await tester.pumpAndSettle();

    expect(find.text('Salt Pier'), findsNothing);
    expect(find.text('Thistlegorm'), findsOneWidget);
    expect(ticked(tester, 'Thistlegorm'), isFalse);
    expect(find.text('Apply (0)'), findsOneWidget);
  });

  testWidgets('a row the diver un-ticked stays un-ticked when the pairs '
      'are found again', (tester) async {
    await pump(tester, pairs: [_saltPier, _hooker]);
    await tester.tap(checkboxFor('Salt Pier'));
    await tester.pump();

    container.read(_pairs.notifier).state = [_saltPier, _hooker, _thistlegorm];
    await tester.pumpAndSettle();

    expect(ticked(tester, 'Salt Pier'), isFalse);
    expect(ticked(tester, 'Hilma Hooker'), isTrue);
  });

  testWidgets('a pair that appears later is seeded like the first ones', (
    tester,
  ) async {
    await pump(tester, pairs: [_thistlegorm]);

    container.read(_pairs.notifier).state = [_thistlegorm, _saltPier];
    await tester.pumpAndSettle();

    expect(ticked(tester, 'Salt Pier'), isTrue);
    expect(ticked(tester, 'Thistlegorm'), isFalse);
  });

  testWidgets('with nothing to offer the page says so', (tester) async {
    await pump(tester, pairs: const []);

    expect(
      find.textContaining('already carry everything the built-in catalogue'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('a catalogue not read yet shows the same, with no spinner', (
    tester,
  ) async {
    await pump(tester, pairs: null);

    expect(
      find.textContaining('already carry everything the built-in catalogue'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // The rows appear when the catalogue has been read.
    container.read(_pairs.notifier).state = [_saltPier];
    await tester.pumpAndSettle();
    expect(find.text('Salt Pier'), findsOneWidget);
  });

  testWidgets('depths follow the diver\'s unit', (tester) async {
    await pump(tester, pairs: [_thistlegorm]);

    expect(find.text('Adds: link, 32m'), findsOneWidget);
  });
}
