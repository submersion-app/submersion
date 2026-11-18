import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
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

import '../../../../helpers/fake_catalogue_gap_service.dart';
import '../../../../helpers/mock_providers.dart';

const _here = GeoPoint(12.0835, -68.2826);

const _saltPier = CataloguePair(
  site: DiveSite(id: 'pier', name: 'Salt Pier', location: _here),
  record: CatalogueSite(
    id: 'r_pier',
    name: 'Salt Pier',
    location: _here,
    maxDepth: 15,
    minDepth: 5,
    typeIds: ['reef'],
    source: 'osm',
  ),
  kind: CataloguePairKind.sure,
  fields: {CatalogueGapField.depth, CatalogueGapField.siteTypes},
  distanceMeters: 0,
);

const _hooker = CataloguePair(
  site: DiveSite(
    id: 'hooker',
    name: 'Hilma Hooker',
    location: _here,
    catalogueId: 'r_hooker',
  ),
  record: CatalogueSite(
    id: 'r_hooker',
    name: 'Hilma Hooker',
    location: _here,
    description: 'Freighter, sunk 1984',
    source: 'osm',
  ),
  kind: CataloguePairKind.linked,
  fields: {CatalogueGapField.description},
  distanceMeters: 0,
);

const _thistlegorm = CataloguePair(
  site: DiveSite(id: 'wreck', name: 'Thistlegorm', location: _here),
  record: CatalogueSite(
    id: 'r_wreck',
    name: 'SS Thistlegorm',
    location: _here,
    maxDepth: 32,
    source: 'ukho',
  ),
  kind: CataloguePairKind.nearby,
  fields: {CatalogueGapField.depth},
  distanceMeters: 40,
);

const _blueHole = CataloguePair(
  site: DiveSite(id: 'hole', name: 'Blue Hole'),
  record: CatalogueSite(
    id: 'r_hole',
    name: 'Blue Hole',
    location: GeoPoint(28.5722, 34.5370),
    country: 'Egypt',
    region: 'South Sinai',
    source: 'osm',
  ),
  kind: CataloguePairKind.named,
  fields: {CatalogueGapField.position, CatalogueGapField.country},
);

final _pairs = StateProvider<List<CataloguePair>?>((ref) => null);

void main() {
  late FakeCatalogueGapService service;
  late ProviderContainer container;

  /// How many times the pairs have been looked for.
  var searches = 0;

  /// When set, a search for the pairs waits for it before it answers.
  Completer<void>? searchGate;

  Future<void> pump(
    WidgetTester tester, {
    required List<CataloguePair>? pairs,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = FakeCatalogueGapService();
    searches = 0;
    searchGate = null;
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        catalogueGapServiceProvider.overrideWithValue(service),
        _pairs.overrideWith((ref) => pairs),
        catalogueGapPairsProvider.overrideWith((ref) async {
          final now = ref.watch(_pairs);
          searches++;
          // Null stands for a catalogue that has not been read yet.
          if (now == null) return Completer<List<CataloguePair>>().future;
          await searchGate?.future;
          return now;
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

  testWidgets('a researched record is marked Not verified on its row', (
    tester,
  ) async {
    const researched = CataloguePair(
      site: DiveSite(
        id: 's9',
        name: 'Liberty',
        location: GeoPoint(-8.27, 115.59),
      ),
      record: CatalogueSite(
        id: 'research_id_usat_liberty',
        name: 'USAT Liberty',
        location: GeoPoint(-8.2703, 115.59),
        maxDepth: 30,
        source: 'research',
        trust: CatalogueTrust.researched,
      ),
      kind: CataloguePairKind.nearby,
      fields: {CatalogueGapField.depth},
      distanceMeters: 33,
    );
    await pump(tester, pairs: [_saltPier, researched]);

    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Liberty'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('Not verified'),
      ),
      findsOneWidget,
    );
    expect(find.text('Not verified'), findsOneWidget);
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

    service.result = const CatalogueApplyResult(linked: 1, filled: 2);

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

  testWidgets('a site paired with a different record is reviewed afresh', (
    tester,
  ) async {
    // The diver ticks the nearby pair and chooses its fields.
    await pump(tester, pairs: [_thistlegorm]);
    await tester.tap(checkboxFor('Thistlegorm'));
    await tester.pump();
    container
        .read(catalogueGapReviewProvider.notifier)
        .setFields(_thistlegorm, const {});
    expect(ticked(tester, 'Thistlegorm'), isTrue);

    // A catalogue import lands: the same site now pairs with another record.
    final other = CataloguePair(
      site: _thistlegorm.site,
      record: const CatalogueSite(
        id: 'r_other',
        name: 'Tug Boat',
        location: _here,
        maxDepth: 12,
        source: 'osm',
      ),
      kind: CataloguePairKind.nearby,
      fields: const {CatalogueGapField.depth},
      distanceMeters: 60,
    );
    container.read(_pairs.notifier).state = [other];
    await tester.pumpAndSettle();

    expect(ticked(tester, 'Thistlegorm'), isFalse);
    expect(
      container.read(catalogueGapReviewProvider).fieldsFor(other),
      other.fields,
    );
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

  testWidgets('Apply stays off until the pairs have been found again', (
    tester,
  ) async {
    await pump(tester, pairs: [_saltPier]);
    searchGate = Completer<void>();

    await tester.tap(find.text('Apply (1)'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    // The write is done, and the list still shows the row it applied: a
    // second tap would send that row again.
    expect(service.applied, hasLength(1));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    searchGate!.complete();
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('an apply still running when the page goes finds the pairs '
      'again', (tester) async {
    await pump(tester, pairs: [_saltPier]);
    service.gate = Completer<void>();

    await tester.tap(find.text('Apply (1)'));
    await tester.pump();
    // The diver leaves: the page goes, and its ticks with it.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: Text('elsewhere'))),
      ),
    );
    await tester.pump();
    final before = searches;
    service.gate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(service.applied, hasLength(1));
    await container.read(catalogueGapPairsProvider.future);
    expect(searches, before + 1);
  });

  testWidgets('the rows are built as they scroll into view', (tester) async {
    await pump(tester, pairs: [_saltPier, _thistlegorm]);

    expect(
      tester.widget<ListView>(find.byType(ListView)).childrenDelegate,
      isA<SliverChildBuilderDelegate>(),
    );
  });

  testWidgets('a tick is named after its site for a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, pairs: [_saltPier]);

    expect(tester.getSemantics(checkboxFor('Salt Pier')).label, 'Salt Pier');
    semantics.dispose();
  });

  group('the comparison', () {
    Future<void> openRow(WidgetTester tester, String siteName) async {
      await tester.tap(find.text(siteName));
      await tester.pumpAndSettle();
    }

    /// Un-ticks [fieldLabel] in the open comparison and closes it without
    /// applying.
    Future<void> untickAndClose(WidgetTester tester, String fieldLabel) async {
      await tester.tap(find.text(fieldLabel));
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }

    testWidgets('the row names only the details still ticked', (tester) async {
      await pump(tester, pairs: [_saltPier]);
      expect(find.text('Adds: link, 5m–15m, Reef'), findsOneWidget);

      await openRow(tester, 'Salt Pier');
      await untickAndClose(tester, 'Site types');

      expect(find.text('Adds: link, 5m–15m'), findsOneWidget);
    });

    testWidgets('a detail the record gains later is filled, not turned down '
        'unseen', (tester) async {
      await pump(tester, pairs: [_saltPier]);
      await openRow(tester, 'Salt Pier');
      await untickAndClose(tester, 'Site types');

      // A catalogue import lands: the record now has a description too.
      final grown = CataloguePair(
        site: _saltPier.site,
        record: const CatalogueSite(
          id: 'r_pier',
          name: 'Salt Pier',
          location: _here,
          maxDepth: 15,
          minDepth: 5,
          typeIds: ['reef'],
          description: 'Pillars covered in sponges',
          source: 'osm',
        ),
        kind: CataloguePairKind.sure,
        fields: const {
          CatalogueGapField.depth,
          CatalogueGapField.siteTypes,
          CatalogueGapField.description,
        },
        distanceMeters: 0,
      );
      container.read(_pairs.notifier).state = [grown];
      await tester.pumpAndSettle();
      // What the diver un-ticked stays un-ticked.
      expect(find.text('Adds: link, 5m–15m, Description'), findsOneWidget);

      await tester.tap(find.text('Apply (1)'));
      await tester.pumpAndSettle();

      expect(service.applied.single.single.fields, {
        CatalogueGapField.depth,
        CatalogueGapField.description,
      });
    });

    testWidgets('a linked site with every detail un-ticked says what '
        'applying it does', (tester) async {
      await pump(tester, pairs: [_hooker]);

      await openRow(tester, 'Hilma Hooker');
      await untickAndClose(tester, 'Description');

      expect(find.textContaining('Adds:'), findsNothing);
      expect(find.text('No thanks'), findsOneWidget);
    });

    testWidgets('opens from a row with every offered field ticked', (
      tester,
    ) async {
      await pump(tester, pairs: [_saltPier]);

      await openRow(tester, 'Salt Pier');

      expect(find.text('Fill in (2)'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
    });

    testWidgets('a choice made there and closed is what the row applies', (
      tester,
    ) async {
      await pump(tester, pairs: [_saltPier]);
      await openRow(tester, 'Salt Pier');
      await tester.tap(find.text('Site types'));
      await tester.pump();
      // Dismissed, not applied.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(service.applied, isEmpty);

      await tester.tap(find.text('Apply (1)'));
      await tester.pumpAndSettle();

      expect(service.applied.single.single.fields, {CatalogueGapField.depth});
    });

    testWidgets('the choice is still there when the row is opened again', (
      tester,
    ) async {
      await pump(tester, pairs: [_saltPier]);
      await openRow(tester, 'Salt Pier');
      await tester.tap(find.text('Site types'));
      await tester.pump();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await openRow(tester, 'Salt Pier');

      expect(find.text('Fill in (1)'), findsOneWidget);
    });

    testWidgets('its button applies that one pair at once', (tester) async {
      await pump(tester, pairs: [_saltPier, _thistlegorm]);
      service.result = const CatalogueApplyResult(linked: 1, filled: 1);

      await openRow(tester, 'Thistlegorm');
      await tester.tap(find.text('Fill in (1)'));
      await tester.pumpAndSettle();

      final request = service.applied.single.single;
      expect(request.pair.site.id, 'wreck');
      expect(request.fields, {CatalogueGapField.depth});
      expect(
        find.text('Sites linked: 1. Sites with details filled: 1.'),
        findsOneWidget,
      );
      expect(find.byType(CatalogueGapReviewPage), findsOneWidget);
    });

    testWidgets('"Not the same site" is remembered', (tester) async {
      await pump(tester, pairs: [_thistlegorm]);

      await openRow(tester, 'Thistlegorm');
      await tester.tap(find.text('Not the same site'));
      await tester.pumpAndSettle();

      expect(service.notSame, ['wreck']);
      expect(service.applied, isEmpty);
    });

    testWidgets('"No thanks" on a linked site turns the details down', (
      tester,
    ) async {
      await pump(tester, pairs: [_hooker]);

      await openRow(tester, 'Hilma Hooker');
      await tester.tap(find.text('No thanks'));
      await tester.pumpAndSettle();

      expect(service.declined, ['hooker']);
      expect(service.applied, isEmpty);
    });
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
