import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/pages/catalogue_site_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_site_catalogue.dart';
import '../../../../helpers/mock_providers.dart';

/// What the built-in site page's tests share: fixture records, and a
/// router with a home page, the page under test and a stand-in for the
/// diver's own site page.

const osmSource = CatalogueSource(
  key: 'osm',
  name: 'OpenStreetMap',
  licence: 'ODbL-1.0',
  licenceUrl: 'https://www.openstreetmap.org/copyright',
  credit: 'OpenStreetMap contributors',
);

const ukhoSource = CatalogueSource(
  key: 'ukho',
  name: 'UK Hydrographic Office Wrecks and Obstructions',
  licence: 'OGL-UK-3.0',
  licenceUrl:
      'https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/',
  credit: 'UK Hydrographic Office',
);

const pageSources = {'osm': osmSource, 'ukho': ukhoSource};

/// A dive site record that carries everything a record can.
const saltPier = CatalogueSite(
  id: 'osm_node_1',
  name: 'Salt Pier',
  location: GeoPoint(12.08, -68.28),
  countryCode: 'BQ',
  country: 'Caribbean Netherlands',
  region: 'Bonaire',
  locality: 'Kralendijk',
  island: 'Bonaire Island',
  bodyOfWater: 'Caribbean Sea',
  minDepth: 5,
  maxDepth: 15,
  typeIds: ['reef'],
  entryMethods: [EntryMethod.shore],
  hazards: 'Boat traffic at the pier',
  description: 'Pillars covered in sponges.',
  website: 'https://example.org/salt-pier',
  source: 'osm',
  sourceRef: 'https://www.openstreetmap.org/node/1',
);

/// A dive site record that is no more than a name and a position.
const thin = CatalogueSite(
  id: 'osm_node_2',
  name: 'Bari Reef',
  location: GeoPoint(12.16, -68.29),
  source: 'osm',
);

/// A charted wreck from a register.
const tabarka = CatalogueSite(
  id: 'ukho_1',
  name: 'Blockship Tabarka',
  location: GeoPoint(58.9, -3.1),
  country: 'United Kingdom',
  maxDepth: 18,
  typeIds: ['wreck'],
  description: 'Charted wreck.',
  source: 'ukho',
  sourceRef: 'https://datahub.admiralty.co.uk/portal/apps/sites/#/x',
  kind: CatalogueKind.register,
);

/// The diver's sites, for a test that changes them while the page is up.
final mineProvider = StateProvider<List<SiteWithDiveCount>>((ref) => const []);

SiteWithDiveCount own(
  String id, {
  String? name,
  GeoPoint? location,
  String? catalogueId,
  int dives = 0,
}) => SiteWithDiveCount(
  site: DiveSite(
    id: id,
    name: name ?? id,
    location: location,
    catalogueId: catalogueId,
  ),
  diveCount: dives,
);

/// Notes the sites the diver's "after creating by hand" rules were run
/// on, and changes nothing.
class RecordingRuleEngine extends RuleEngine {
  RecordingRuleEngine() : super(names: (_) async => NameIndex(const []));

  /// The site ids of every run, in order.
  final List<Set<String>> runs = [];

  @override
  Future<RuleRunResult> run(RuleRunRequest request) async {
    runs.add(request.targets[RuleSubject.sites] ?? const {});
    return RuleRunResult.noRules;
  }
}

/// The text on the stand-in for the diver's own page of site [id].
String ownPageText(String id) => 'own page $id';

/// The text on the home page beneath a pushed built-in page.
const homeText = 'home';

/// Where a test pushes a page over the built-in page, and its text.
const otherPath = '/other';
const otherText = 'another page';

/// Pumps a built-in record's page.
///
/// By default the page is the only one on the stack. With [fromHome] it is
/// pushed from a home page, as the map pushes it, so a test can go back.
Future<ProviderContainer> pumpCataloguePage(
  WidgetTester tester, {
  required String id,
  List<CatalogueSite> records = const [saltPier, thin, tabarka],
  List<SiteWithDiveCount> mine = const [],
  AppSettings settings = const AppSettings(),
  Size size = const Size(420, 900),
  Locale locale = const Locale('en'),
  bool fromHome = false,
  Future<CatalogueAdoption> Function(CatalogueSite site)? adopter,
  RecordingRuleEngine? rules,
  Object? sitesError,
  bool? tideData,
  bool importing = false,
  bool settled = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final base = await getBaseOverrides(
    settingsNotifier: MockSettingsNotifier(settings),
  );
  late ProviderContainer container;
  final router = GoRouter(
    initialLocation: fromHome ? '/' : catalogueSitePath(id),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push(catalogueSitePath(id)),
              child: const Text(homeText),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/sites/catalogue/:catalogueId',
        builder: (_, state) => CatalogueSitePage(
          catalogueId: state.pathParameters['catalogueId']!,
        ),
      ),
      GoRoute(
        path: otherPath,
        builder: (_, _) =>
            Scaffold(appBar: AppBar(), body: const Text(otherText)),
      ),
      GoRoute(
        path: '/sites/:siteId',
        builder: (_, state) => Scaffold(
          appBar: AppBar(),
          body: Text(ownPageText(state.pathParameters['siteId']!)),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...base,
        siteCatalogueProvider.overrideWithValue(
          FakeSiteCatalogue(records, pageSources),
        ),
        mineProvider.overrideWith((ref) => mine),
        sitesWithCountsProvider.overrideWith((ref) async {
          // A read of the diver's sites that fails, for the test that is
          // about the page not waiting on it.
          if (sitesError != null) throw sitesError;
          return ref.watch(mineProvider);
        }),
        placeNameLanguageProvider.overrideWithValue('en'),
        siteCatalogueImportingProvider.overrideWith((ref) => importing),
        // The cards that fetch: fixed, so a test never reaches a network.
        // Whether the position has tide data is still being found out
        // unless a test says ([tideData]); the Tides card then shows its
        // own waiting state, with nothing behind it to fetch.
        hasTideDataProvider.overrideWith(
          (ref, location) => tideData ?? Completer<bool>().future,
        ),
        reefHabitatProvider.overrideWith(
          (ref, location) async => const ReefPart.empty(),
        ),
        reefCurrentHealthProvider.overrideWith(
          (ref, location) async => const ReefPart.empty(),
        ),
        reefProtectionProvider.overrideWith(
          (ref, location) async => const ReefPart.empty(),
        ),
        bathymetryGridProvider.overrideWith((ref, cell) async => null),
        if (adopter != null)
          catalogueSiteAdopterProvider.overrideWithValue(adopter),
        // Adding a site runs the diver's rules on it; these tests have no
        // database for the real engine.
        ruleEngineProvider.overrideWithValue(rules ?? RecordingRuleEngine()),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp.router(
            routerConfig: router,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    ),
  );
  if (!settled) return container;
  await settle(tester);
  if (fromHome) {
    await tester.tap(find.text(homeText));
    await settle(tester);
  }
  return container;
}

/// Lets the page's reads land. Never `pumpAndSettle`: the map's tile
/// layer and a progress indicator animate for as long as they are up.
Future<void> settle(WidgetTester tester) async {
  // A read, then what it leads to (a second read, a page replaced, a
  // route's transition), each needs a frame of its own.
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}
