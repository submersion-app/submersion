import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_map_layers_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_map_content.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';

import '../../../../helpers/fake_site_catalogue.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _builtInA = CatalogueSite(
  id: 'a',
  name: 'A',
  // At the page's default center so it is within the zoom-3 viewport (the
  // marker cluster layer culls off-screen markers).
  location: GeoPoint(20, -157),
  source: 'osm',
);

/// A charted wreck in the same default view as [_builtInA], far enough
/// east of it (150 px at zoom 3) that the two do not cluster.
const _wreckB = CatalogueSite(
  id: 'b',
  name: 'B',
  location: GeoPoint(20, -130),
  source: 'ukho',
  kind: CatalogueKind.register,
);

/// The diver's sites, for a test that changes them while the map is up.
final _mineProvider = StateProvider<List<SiteWithDiveCount>>((ref) => const []);

/// A repository whose createSite always fails, to exercise the add-error path.
class _ThrowingSiteRepository extends SiteRepository {
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

Future<void> _semanticsTap(WidgetTester tester, String label) async {
  tester.semantics.tap(find.semantics.byLabel(label));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Pumps the map. With [withRouter] it sits in a router that also knows
/// a built-in record's page, for a test that follows the card's Details.
Future<ProviderContainer> _pumpContent(
  WidgetTester tester, {
  required List<Override> extraOverrides,
  Override? sites,
  bool withRouter = false,
}) async {
  final base = await getBaseOverrides();
  late ProviderContainer container;
  Widget map(BuildContext context) {
    container = ProviderScope.containerOf(context);
    return Scaffold(body: SiteMapContent(onItemSelected: (_) {}));
  }

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, _) => map(context)),
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            )
          : MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(builder: map),
            ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return container;
}

void main() {
  group('by default', () {
    testWidgets('built-in dive site pins show with nothing switched on, '
        'and charted wrecks do not', (tester) async {
      await _pumpContent(
        tester,
        extraOverrides: [
          siteCatalogueProvider.overrideWithValue(
            FakeSiteCatalogue(const [_builtInA, _wreckB]),
          ),
        ],
      );

      expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);
      expect(find.byKey(const Key('builtInPin_b')), findsNothing);
    });

    testWidgets('the wreck layer adds the wrecks, and both layers off '
        'removes every pin', (tester) async {
      final container = await _pumpContent(
        tester,
        extraOverrides: [
          siteCatalogueProvider.overrideWithValue(
            FakeSiteCatalogue(const [_builtInA, _wreckB]),
          ),
        ],
      );
      final layers = container.read(builtInMapLayersProvider.notifier);

      await layers.setLayer(CatalogueKind.register, true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('builtInPin_b')), findsOneWidget);

      await layers.setLayer(CatalogueKind.register, false);
      await layers.setLayer(CatalogueKind.site, false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('builtInPin_a')), findsNothing);
      expect(find.byKey(const Key('builtInPin_b')), findsNothing);
    });

    testWidgets('a diver with no sites sees built-in pins, not the empty '
        'card, until every layer is off', (tester) async {
      final container = await _pumpContent(
        tester,
        extraOverrides: [
          siteCatalogueProvider.overrideWithValue(
            FakeSiteCatalogue(const [_builtInA]),
          ),
        ],
      );

      expect(find.text('No sites with coordinates'), findsNothing);
      expect(find.byKey(const Key('builtInPin_a')), findsOneWidget);

      await container
          .read(builtInMapLayersProvider.notifier)
          .setLayer(CatalogueKind.site, false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

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

      await _pumpContent(
        tester,
        extraOverrides: [
          heatMapSettingsProvider.overrideWith(
            (ref) => const HeatMapSettings(isVisible: false),
          ),
          siteRepositoryProvider.overrideWithValue(SiteRepository()),
          visibleBuiltInSitesProvider.overrideWith(
            (ref) async => const [_builtInA],
          ),
        ],
      );

      await _semanticsTap(tester, 'Built-in dive site: A');
      expect(find.text('Add to my sites'), findsOneWidget);

      await tester.tap(find.text('Add to my sites'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
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

      await _pumpContent(
        tester,
        extraOverrides: [
          heatMapSettingsProvider.overrideWith(
            (ref) => const HeatMapSettings(isVisible: false),
          ),
          siteRepositoryProvider.overrideWithValue(_ThrowingSiteRepository()),
          visibleBuiltInSitesProvider.overrideWith(
            (ref) async => const [_builtInA],
          ),
        ],
      );

      await _semanticsTap(tester, 'Built-in dive site: A');
      await tester.tap(find.text('Add to my sites'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text("Couldn't add site. Please try again."), findsOneWidget);
      expect(find.text('Add to my sites'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('hiding built-in sites clears the selected info card', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      final container = await _pumpContent(
        tester,
        extraOverrides: [
          heatMapSettingsProvider.overrideWith(
            (ref) => const HeatMapSettings(isVisible: false),
          ),
          siteRepositoryProvider.overrideWithValue(SiteRepository()),
          visibleBuiltInSitesProvider.overrideWith(
            (ref) async => const [_builtInA],
          ),
        ],
      );

      await _semanticsTap(tester, 'Built-in dive site: A');
      expect(find.text('Add to my sites'), findsOneWidget);

      await container
          .read(builtInMapLayersProvider.notifier)
          .setLayer(CatalogueKind.site, false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Add to my sites'), findsNothing);

      handle.dispose();
    });

    testWidgets('the card\'s Details opens the record\'s own page', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await _pumpContent(
        tester,
        withRouter: true,
        extraOverrides: [
          heatMapSettingsProvider.overrideWith(
            (ref) => const HeatMapSettings(isVisible: false),
          ),
          visibleBuiltInSitesProvider.overrideWith(
            (ref) async => const [_builtInA],
          ),
        ],
      );

      await _semanticsTap(tester, 'Built-in dive site: A');
      await tester.tap(find.text('Details'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('built-in page a'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('a selected record that becomes the diver\'s own loses its '
        'card', (tester) async {
      final handle = tester.ensureSemantics();

      final container = await _pumpContent(
        tester,
        sites: sitesWithCountsProvider.overrideWith(
          (ref) async => ref.watch(_mineProvider),
        ),
        extraOverrides: [
          heatMapSettingsProvider.overrideWith(
            (ref) => const HeatMapSettings(isVisible: false),
          ),
          visibleBuiltInSitesProvider.overrideWith(
            (ref) async => const [_builtInA],
          ),
        ],
      );

      await _semanticsTap(tester, 'Built-in dive site: A');
      expect(find.text('Add to my sites'), findsOneWidget);

      // Added somewhere else: from the record's page, or by a sync.
      container.read(_mineProvider.notifier).state = const [
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
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Add to my sites'), findsNothing);

      handle.dispose();
    });
  });
}
