import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_map_layers_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/fake_site_catalogue.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// What both Sites maps do with the built-in catalogue, tested once and run
/// against each: the phone's map page and the split pane's map.
///
/// The two are separate widgets that share `BuiltInMapSelection`. A case
/// added here holds for both, which is the point of sharing it.

/// A built-in dive site at the maps' default centre, so it is within the
/// zoom-3 viewport (the marker cluster layer culls off-screen markers).
const builtInA = CatalogueSite(
  id: 'a',
  name: 'A',
  location: GeoPoint(20, -157),
  source: 'osm',
);

/// A charted wreck in the same default view as [builtInA], far enough
/// east of it (150 px at zoom 3) that the two do not cluster.
const wreckB = CatalogueSite(
  id: 'b',
  name: 'B',
  location: GeoPoint(20, -130),
  source: 'ukho',
  kind: CatalogueKind.register,
);

/// The built-in pins in view, for a test that moves them while the map is
/// up.
final shownProvider = StateProvider<List<CatalogueSite>>(
  (ref) => const [builtInA],
);

/// The diver's sites, for a test that changes them while the map is up.
final mineProvider = StateProvider<List<SiteWithDiveCount>>((ref) => const []);

/// A repository whose createSite always fails, to exercise the add-error
/// path.
class ThrowingSiteRepository extends SiteRepository {
  @override
  Future<List<DiveSite>> getAllSites({
    String? diverId,
    List<String>? ids,
  }) async => [];

  @override
  Future<DiveSite> createSite(
    DiveSite site, {
    SiteClassification? classification,
  }) async => throw Exception('write failed');
}

/// Invokes a marker's onTap via its semantics action. The cluster plugin
/// keeps markers behind an IgnorePointer during its fade-in, so a pointer
/// tap never lands; the semantics tap drives the same GestureDetector.
Future<void> semanticsTap(WidgetTester tester, String label) async {
  tester.semantics.tap(find.semantics.byLabel(label));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Pumps [map]. With [withRouter] it sits in a router that also knows a
/// built-in record's page, for a test that follows the card's Details.
Future<ProviderContainer> pumpBuiltInMap(
  WidgetTester tester, {
  required Widget Function() map,
  required List<Override> extraOverrides,
  Override? sites,
  bool withRouter = false,
  Locale? locale,
}) async {
  final base = await getBaseOverrides();
  late ProviderContainer container;
  Widget build(BuildContext context) {
    container = ProviderScope.containerOf(context);
    return map();
  }

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, _) => build(context)),
      GoRoute(
        path: '/sites/catalogue/:id',
        builder: (_, state) =>
            Scaffold(body: Text('built-in page ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        sites ?? sitesWithCountsProvider.overrideWith((ref) async => []),
        siteCoverageHeatMapProvider.overrideWith(
          (ref) async => <HeatMapPoint>[],
        ),
        ...extraOverrides,
      ],
      child: withRouter
          ? MaterialApp.router(
              routerConfig: router,
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            )
          : MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(builder: build),
            ),
    ),
  );
  // Avoid pumpAndSettle: the FlutterMap tile layer animates indefinitely.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return container;
}

/// Registers the tests every Sites map must pass. [map] builds the map
/// under test; [surface] sets the window it is tested at, if it needs one.
void builtInMapContract({
  required Widget Function() map,
  void Function(WidgetTester tester)? surface,
}) {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required List<Override> extraOverrides,
    Override? sites,
    bool withRouter = false,
  }) {
    surface?.call(tester);
    return pumpBuiltInMap(
      tester,
      map: map,
      extraOverrides: extraOverrides,
      sites: sites,
      withRouter: withRouter,
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  /// The overrides of a map with [builtInA] as its one pin, selected by
  /// the tests that are about its card.
  List<Override> onePin({SiteRepository? repository}) => [
    heatMapSettingsProvider.overrideWith(
      (ref) => const HeatMapSettings(isVisible: false),
    ),
    if (repository != null)
      siteRepositoryProvider.overrideWithValue(repository),
    visibleBuiltInSitesProvider.overrideWith((ref) async => const [builtInA]),
  ];

  group('by default', () {
    testWidgets('built-in dive site pins show with nothing switched on, '
        'and charted wrecks do not', (tester) async {
      await pump(
        tester,
        extraOverrides: [
          siteCatalogueProvider.overrideWithValue(
            FakeSiteCatalogue(const [builtInA, wreckB]),
          ),
        ],
      );

      expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);
      expect(find.byKey(const Key('builtInPin_b')), findsNothing);
    });

    testWidgets('the wreck layer adds the wrecks, and both layers off '
        'removes every pin', (tester) async {
      final container = await pump(
        tester,
        extraOverrides: [
          siteCatalogueProvider.overrideWithValue(
            FakeSiteCatalogue(const [builtInA, wreckB]),
          ),
        ],
      );
      final layers = container.read(builtInMapLayersNotifierProvider.notifier);

      await layers.setLayer(CatalogueKind.register, true);
      await settle(tester);
      expect(find.byKey(const Key('builtInPin_b')), findsOneWidget);

      await layers.setLayer(CatalogueKind.register, false);
      await layers.setLayer(CatalogueKind.site, false);
      await settle(tester);
      expect(find.byKey(const Key('builtInPin_a')), findsNothing);
      expect(find.byKey(const Key('builtInPin_b')), findsNothing);
    });

    testWidgets('a diver with no sites sees built-in pins, not the empty '
        'card, until every layer is off', (tester) async {
      final container = await pump(
        tester,
        extraOverrides: [
          siteCatalogueProvider.overrideWithValue(
            FakeSiteCatalogue(const [builtInA]),
          ),
        ],
      );

      expect(find.text('No sites with coordinates'), findsNothing);
      expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);

      await container
          .read(builtInMapLayersNotifierProvider.notifier)
          .setLayer(CatalogueKind.site, false);
      await settle(tester);

      expect(find.text('No sites with coordinates'), findsOneWidget);
    });
  });

  group('built-in selection and import', () {
    setUp(() async {
      await setUpTestDatabase();
    });
    tearDown(() async {
      await tearDownTestDatabase();
    });

    testWidgets('selecting a pin shows its info card and adding imports it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, extraOverrides: onePin(repository: SiteRepository()));

      // Selecting the pin shows the built-in info card with its add action.
      await semanticsTap(tester, 'Built-in dive site: A');
      expect(find.text('Add to my sites'), findsOneWidget);

      // Adding imports the site and confirms via a snackbar, clearing the
      // card.
      await tester.tap(find.text('Add to my sites'));
      await settle(tester);
      expect(find.text('Added to your sites'), findsOneWidget);
      // The new site remembers the catalogue record it came from.
      final added = await tester.runAsync(SiteRepository().getAllSites);
      expect(added!.single.catalogueId, 'a');
      expect(find.text('Add to my sites'), findsNothing);

      handle.dispose();
    });

    testWidgets('shows an error snackbar when adding a built-in site fails', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        extraOverrides: onePin(repository: ThrowingSiteRepository()),
      );

      await semanticsTap(tester, 'Built-in dive site: A');
      await tester.tap(find.text('Add to my sites'));
      await settle(tester);

      expect(find.text("Couldn't add site. Please try again."), findsOneWidget);
      // The card stays so the user can retry.
      expect(find.text('Add to my sites'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('turning a selected pin\'s layer off clears its card', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final container = await pump(
        tester,
        extraOverrides: onePin(repository: SiteRepository()),
      );

      await semanticsTap(tester, 'Built-in dive site: A');
      expect(find.text('Add to my sites'), findsOneWidget);

      await container
          .read(builtInMapLayersNotifierProvider.notifier)
          .setLayer(CatalogueKind.site, false);
      await settle(tester);
      expect(find.text('Add to my sites'), findsNothing);

      handle.dispose();
    });

    testWidgets('the card\'s Details opens the record\'s own page', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, withRouter: true, extraOverrides: onePin());

      await semanticsTap(tester, 'Built-in dive site: A');
      await tester.tap(find.text('Details'));
      await settle(tester);

      expect(find.text('built-in page a'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('a tap on the bare map puts the card away', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, extraOverrides: onePin());

      await semanticsTap(tester, 'Built-in dive site: A');
      expect(find.text('Add to my sites'), findsOneWidget);

      // A corner of the map, away from the pin at its centre.
      await tester.tapAt(
        tester.getTopLeft(find.byType(FlutterMap)) + const Offset(5, 5),
      );
      // The map waits out a possible double tap before it reports one.
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      expect(find.text('Add to my sites'), findsNothing);
      handle.dispose();
    });

    group('a selected record whose pin leaves the map', () {
      /// A map over [catalogue] whose pins are whatever [shownProvider]
      /// holds, with [builtInA] selected.
      Future<ProviderContainer> selected(
        WidgetTester tester,
        FakeSiteCatalogue catalogue,
      ) async {
        final container = await pump(
          tester,
          extraOverrides: [
            heatMapSettingsProvider.overrideWith(
              (ref) => const HeatMapSettings(isVisible: false),
            ),
            siteCatalogueProvider.overrideWithValue(catalogue),
            visibleBuiltInSitesProvider.overrideWith(
              (ref) async => ref.watch(shownProvider),
            ),
          ],
        );
        await semanticsTap(tester, 'Built-in dive site: A');
        expect(find.text('Add to my sites'), findsOneWidget);
        return container;
      }

      testWidgets('keeps its card while it is only off screen', (tester) async {
        final handle = tester.ensureSemantics();
        final container = await selected(
          tester,
          FakeSiteCatalogue(const [builtInA]),
        );

        // The map was moved: the record is out of view, and still there.
        container.read(shownProvider.notifier).state = const [];
        await settle(tester);
        await settle(tester);

        expect(find.text('Add to my sites'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('loses its card when a new catalogue no longer holds it: '
          'there is nothing left to add', (tester) async {
        final handle = tester.ensureSemantics();
        final catalogue = FakeSiteCatalogue(const [builtInA]);
        final container = await selected(tester, catalogue);

        // An import replaces the catalogue with one that dropped the record.
        catalogue.sites = [];
        container.read(siteCatalogueRevisionProvider.notifier).state++;
        container.read(shownProvider.notifier).state = const [];
        // The pin goes, then the catalogue is asked, then the card goes:
        // each takes a frame.
        await settle(tester);
        await settle(tester);

        expect(find.text('Add to my sites'), findsNothing);
        handle.dispose();
      });
    });

    group('a selected record the diver comes to have loses its card:', () {
      Future<ProviderContainer> selected(WidgetTester tester) async {
        final container = await pump(
          tester,
          sites: sitesWithCountsProvider.overrideWith(
            (ref) async => ref.watch(mineProvider),
          ),
          extraOverrides: onePin(),
        );
        await semanticsTap(tester, 'Built-in dive site: A');
        expect(find.text('Add to my sites'), findsOneWidget);
        return container;
      }

      testWidgets('added somewhere else, from its page or by a sync', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final container = await selected(tester);

        container.read(mineProvider.notifier).state = const [
          SiteWithDiveCount(
            site: DiveSite(
              id: 'mine',
              name: 'A',
              location: GeoPoint(20, -157),
              catalogueId: 'a',
            ),
            diveCount: 0,
          ),
        ];
        await settle(tester);

        expect(find.text('Add to my sites'), findsNothing);
        handle.dispose();
      });

      testWidgets('a site of their own made on the same spot, which hides '
          'the pin as it does everywhere', (tester) async {
        final handle = tester.ensureSemantics();
        final container = await selected(tester);

        // Made by hand, so not linked to the record: 60 m from it.
        container.read(mineProvider.notifier).state = const [
          SiteWithDiveCount(
            site: DiveSite(
              id: 'hand_made',
              name: 'My spot',
              location: GeoPoint(20.0005, -157),
            ),
            diveCount: 0,
          ),
        ];
        await settle(tester);

        expect(find.text('Add to my sites'), findsNothing);
        handle.dispose();
      });

      testWidgets('but not a site of theirs somewhere else', (tester) async {
        final handle = tester.ensureSemantics();
        final container = await selected(tester);

        container.read(mineProvider.notifier).state = const [
          SiteWithDiveCount(
            site: DiveSite(
              id: 'elsewhere',
              name: 'Elsewhere',
              location: GeoPoint(21, -157),
            ),
            diveCount: 0,
          ),
        ];
        await settle(tester);

        expect(find.text('Add to my sites'), findsOneWidget);
        handle.dispose();
      });
    });
  });
}
