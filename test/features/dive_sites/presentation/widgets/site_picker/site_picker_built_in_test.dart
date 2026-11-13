import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/site_area_anchor.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/catalogue_site_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/rules/data/services/rule_engine.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/fake_site_catalogue.dart';

/// Salt Pier, Bonaire.
const _pier = GeoPoint(12.0800, -68.2800);

CatalogueSite _cat(
  String id,
  String name, {
  double north = 0,
  String? island = 'Bonaire',
  double? maxDepth,
}) => CatalogueSite(
  id: id,
  name: name,
  // [north] metres north of Salt Pier, on the sphere distances are
  // measured on (one degree of latitude is 111,194.93 m there).
  location: GeoPoint(_pier.latitude + north / 111194.93, _pier.longitude),
  island: island,
  maxDepth: maxDepth,
  entryMethods: const [EntryMethod.shore],
  source: 'osm',
);

/// Nine Bonaire sites, in an order that is neither by name nor by distance.
final _bonaire = [
  _cat('c3', 'Cliff', north: 3000),
  _cat('c1', 'Angel City', north: 9000, maxDepth: 30),
  _cat('c9', 'Windsock', north: 500),
  _cat('c2', 'Bari Reef', north: 8000),
  _cat('c5', 'Hilma Hooker', north: 1000),
  _cat('c4', 'Front Porch', north: 7000),
  _cat('c6', 'Invisibles', north: 6000),
  _cat('c7', 'Karpata', north: 5000),
  _cat('c8', 'Oil Slick Leap', north: 4000),
];

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocationService implements LocationService {
  _FakeLocationService({this.result});

  final LocationResult? result;
  int calls = 0;

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async {
    calls++;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for the database behind an adoption: makes a site from the
/// record, and serves it back the way the repository would.
class _Adoptions extends SiteRepository {
  final adopted = <CatalogueSite>[];
  final order = <String>[];

  /// Completed by a test that wants an adoption held in flight.
  Completer<void>? gate;
  bool fail = false;

  /// What the logbook rules "changed" the site's name to, once they ran.
  String? renamedByRules;

  Future<DiveSite> adopt(CatalogueSite site) async {
    adopted.add(site);
    order.add('adopt');
    await gate?.future;
    if (fail) throw StateError('write failed');
    return DiveSite(
      id: 'adopted-${site.id}',
      name: site.name,
      location: site.location,
      catalogueId: site.id,
    );
  }

  @override
  Future<DiveSite?> getSiteById(String id) async {
    order.add('read');
    final source = adopted.firstWhere((s) => 'adopted-${s.id}' == id);
    return DiveSite(
      id: id,
      name: renamedByRules ?? source.name,
      location: source.location,
      catalogueId: source.id,
    );
  }
}

class _RenamingEngine extends RuleEngine {
  _RenamingEngine(this.adoptions)
    : super(names: (_) async => NameIndex(const []));

  final _Adoptions adoptions;

  @override
  Future<RuleRunResult> run(RuleRunRequest request) async {
    adoptions.order.add('rules');
    adoptions.renamedByRules = 'Renamed By A Rule';
    return RuleRunResult.noRules;
  }
}

class _Harness {
  _Harness(this.catalogue, this.adoptions, this.location);

  final FakeSiteCatalogue catalogue;
  final _Adoptions adoptions;
  final _FakeLocationService location;
  final picked = <DiveSite>[];
  late ProviderContainer container;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<DiveSite> sites = const [],
  List<CatalogueSite>? catalogueSites,
  bool showBuiltIn = true,
  GeoPoint? diveLocation,
  SiteAreaAnchor? areaAnchor,
  LocationResult? deviceLocation,
  bool withCatalogue = true,
  bool withRules = false,
  void Function(String query)? onCreateNewSite,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final adoptions = _Adoptions();
  final harness = _Harness(
    FakeSiteCatalogue(catalogueSites ?? _bonaire),
    adoptions,
    _FakeLocationService(result: deviceLocation),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sitesProvider.overrideWith((ref) async => sites),
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
        locationServiceProvider.overrideWithValue(harness.location),
        if (withCatalogue)
          siteCatalogueProvider.overrideWithValue(harness.catalogue),
        catalogueSiteAdopterProvider.overrideWithValue(adoptions.adopt),
        siteRepositoryProvider.overrideWithValue(adoptions),
        validatedCurrentDiverIdProvider.overrideWith(
          (ref) async => withRules ? 'diver-1' : null,
        ),
        if (withRules)
          ruleEngineProvider.overrideWithValue(_RenamingEngine(adoptions)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              harness.container = ProviderScope.containerOf(context);
              return SitePickerSheet(
                scrollController: ScrollController(),
                selectedSiteId: null,
                diveLocation: diveLocation,
                areaAnchor: areaAnchor,
                showBuiltIn: showBuiltIn,
                onSiteSelected: harness.picked.add,
                onCreateNewSite: onCreateNewSite,
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

/// The titles of every row in the picker list, top to bottom: the diver's
/// own sites and the built-in ones alike.
List<String> _rowTitles(WidgetTester tester) => tester
    .widgetList<ListTile>(
      find.descendant(
        of: find.byKey(sitePickerListKey),
        matching: find.byType(ListTile),
      ),
    )
    .map((tile) => tile.title)
    .whereType<Text>()
    .map((text) => text.data!)
    .toList();

List<String> _builtInTitles(WidgetTester tester) => tester
    .widgetList<CatalogueSiteTile>(find.byType(CatalogueSiteTile))
    .map((tile) => tile.site.name)
    .toList();

const _inferred = SiteAreaAnchor(point: _pier, placeLabel: 'Bonaire');

void main() {
  group('with the flag off', () {
    testWidgets('shows no built-in sites and never asks the catalogue', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        showBuiltIn: false,
        diveLocation: _pier,
        sites: const [DiveSite(id: 'mine', name: 'My Reef', location: _pier)],
      );

      await tester.enterText(find.byType(TextField), 'angel');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(CatalogueSiteTile), findsNothing);
      expect(h.catalogue.nearCalls, 0);
      expect(h.catalogue.searchCalls, 0);
    });
  });

  group('by area', () {
    testWidgets('a dive location lists built-in sites nearest first, with '
        'distances', (tester) async {
      await _pump(tester, diveLocation: _pier);

      expect(find.text('More sites nearby'), findsOneWidget);
      expect(_builtInTitles(tester), [
        'Windsock',
        'Hilma Hooker',
        'Cliff',
        'Oil Slick Leap',
        'Karpata',
      ]);
      // Windsock is 500 m from the dive, in the diver's distance unit.
      final halfKm = const UnitFormatter(AppSettings()).formatGeoDistance(500);
      expect(find.text('$halfKm away'), findsOneWidget);
      expect(find.textContaining(' away'), findsNWidgets(5));
    });

    testWidgets('an inferred area lists them by name under the place, with '
        'no distances', (tester) async {
      await _pump(tester, areaAnchor: _inferred);

      expect(find.text('More sites near Bonaire'), findsOneWidget);
      expect(_builtInTitles(tester), [
        'Angel City',
        'Bari Reef',
        'Cliff',
        'Front Porch',
        'Hilma Hooker',
      ]);
      expect(find.textContaining(' away'), findsNothing);
      expect(find.text('Near the sites of your other dives'), findsOneWidget);
    });

    testWidgets('an inferred area without a place name says nearby', (
      tester,
    ) async {
      await _pump(tester, areaAnchor: const SiteAreaAnchor(point: _pier));

      expect(find.text('More sites nearby'), findsOneWidget);
    });

    testWidgets("an inferred area lists the diver's own nearby sites by "
        'name too', (tester) async {
      await _pump(
        tester,
        areaAnchor: _inferred,
        catalogueSites: const [],
        sites: [
          DiveSite(
            id: 'z',
            name: 'Zebra Reef',
            location: GeoPoint(_pier.latitude + 0.001, _pier.longitude),
          ),
          DiveSite(
            id: 'a',
            name: 'Alpha Reef',
            location: GeoPoint(_pier.latitude + 0.05, _pier.longitude),
          ),
        ],
      );

      expect(_rowTitles(tester).take(2), ['Alpha Reef', 'Zebra Reef']);
      expect(find.textContaining(' away'), findsNothing);
    });

    testWidgets('an inferred area does not ask the device where it is', (
      tester,
    ) async {
      final h = await _pump(tester, areaAnchor: _inferred);

      expect(h.location.calls, 0);
    });

    testWidgets('with no dive location or area the device fix is used', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        deviceLocation: LocationResult(
          latitude: _pier.latitude,
          longitude: _pier.longitude,
        ),
      );

      expect(h.location.calls, 1);
      expect(find.text('More sites nearby'), findsOneWidget);
      expect(_builtInTitles(tester).first, 'Windsock');
    });

    testWidgets('five rows show, then "Show all" expands in place', (
      tester,
    ) async {
      await _pump(tester, areaAnchor: _inferred);

      expect(_builtInTitles(tester), hasLength(5));
      expect(find.text('Show all 9'), findsOneWidget);

      await tester.tap(find.text('Show all 9'));
      await tester.pumpAndSettle();

      expect(_builtInTitles(tester), hasLength(9));
      expect(find.text('Show all 9'), findsNothing);
    });

    testWidgets('five or fewer sites show no "Show all" row', (tester) async {
      await _pump(
        tester,
        areaAnchor: _inferred,
        catalogueSites: _bonaire.take(5).toList(),
      );

      expect(_builtInTitles(tester), hasLength(5));
      expect(find.textContaining('Show all'), findsNothing);
    });

    testWidgets("the diver's nearby sites come first, then built-in sites, "
        'then the grouped list', (tester) async {
      await _pump(
        tester,
        diveLocation: _pier,
        catalogueSites: [_cat('c1', 'Angel City', north: 9000)],
        sites: const [
          DiveSite(id: 'near', name: 'My House Reef', location: _pier),
          DiveSite(
            id: 'far',
            name: 'Blue Hole',
            location: GeoPoint(28.57, 34.54),
            country: 'Egypt',
          ),
        ],
      );

      final titles = _rowTitles(tester);
      expect(titles.indexOf('My House Reef'), 0);
      expect(titles.indexOf('Angel City'), 1);
      // The grouped list follows: its Egypt group sits below the built-in
      // row (folded, so Blue Hole itself is not a row yet).
      expect(
        tester.getTopLeft(find.text('Egypt')).dy,
        greaterThan(tester.getTopLeft(find.text('Angel City')).dy),
      );
    });

    testWidgets('a diver with no sites still sees the built-in section', (
      tester,
    ) async {
      await _pump(tester, areaAnchor: _inferred);

      expect(find.text('More sites near Bonaire'), findsOneWidget);
      expect(_builtInTitles(tester), isNotEmpty);
    });

    testWidgets('a diver with no sites and no built-in sites sees the empty '
        'state', (tester) async {
      await _pump(tester, areaAnchor: _inferred, catalogueSites: const []);

      expect(find.text('No dive sites yet'), findsOneWidget);
    });

    testWidgets('an adopted site is not offered, its neighbour 100 m away '
        'is', (tester) async {
      await _pump(
        tester,
        areaAnchor: _inferred,
        catalogueSites: [
          _cat('east', 'Barracuda East'),
          _cat('west', 'Barracuda West', north: 100),
        ],
        sites: const [
          DiveSite(
            id: 'mine',
            name: 'Barracuda East',
            location: _pier,
            catalogueId: 'east',
          ),
        ],
      );

      expect(_builtInTitles(tester), ['Barracuda West']);
    });

    testWidgets("a site beside the diver's own unlinked site is hidden", (
      tester,
    ) async {
      await _pump(
        tester,
        areaAnchor: _inferred,
        catalogueSites: [
          _cat('east', 'Barracuda East'),
          _cat('far', 'Cliff', north: 3000),
        ],
        sites: const [
          DiveSite(id: 'mine', name: 'My Barracuda', location: _pier),
        ],
      );

      expect(_builtInTitles(tester), ['Cliff']);
    });

    testWidgets('built-in sites appear when the catalogue becomes ready', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        areaAnchor: _inferred,
        catalogueSites: const [],
      );
      expect(find.byType(CatalogueSiteTile), findsNothing);

      // The first import of this app run lands.
      h.catalogue.sites = _bonaire;
      h.container.read(siteCatalogueRevisionProvider.notifier).state++;
      await tester.pumpAndSettle();

      expect(_builtInTitles(tester), hasLength(5));
    });
  });

  group('searching', () {
    testWidgets('two characters search the catalogue, one does not', (
      tester,
    ) async {
      final h = await _pump(tester, areaAnchor: _inferred);

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(h.catalogue.searchCalls, 0);

      await tester.enterText(find.byType(TextField), 'an');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(h.catalogue.searches, ['an']);
      expect(find.text('Built-in sites'), findsOneWidget);
      expect(_builtInTitles(tester), ['Angel City']);
    });

    testWidgets('typing quickly searches once, for the last text', (
      tester,
    ) async {
      final h = await _pump(tester, areaAnchor: _inferred);

      await tester.enterText(find.byType(TextField), 'an');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'ang');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'ange');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(h.catalogue.searches, ['ange']);
    });

    testWidgets('clearing the search brings the area list back', (
      tester,
    ) async {
      await _pump(tester, areaAnchor: _inferred);
      await tester.enterText(find.byType(TextField), 'angel');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Built-in sites'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('Built-in sites'), findsNothing);
      expect(find.text('More sites near Bonaire'), findsOneWidget);
    });

    testWidgets("a match shows even when none of the diver's sites match", (
      tester,
    ) async {
      await _pump(
        tester,
        areaAnchor: _inferred,
        sites: const [DiveSite(id: 'mine', name: 'My Reef')],
      );

      await tester.enterText(find.byType(TextField), 'angel');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(_builtInTitles(tester), ['Angel City']);
    });

    testWidgets('search results skip the position rule but not the link '
        'rule', (tester) async {
      await _pump(
        tester,
        catalogueSites: [
          _cat('east', 'Barracuda East'),
          _cat('west', 'Barracuda West', north: 100),
        ],
        sites: [
          const DiveSite(
            id: 'adopted',
            name: 'Barracuda East',
            location: _pier,
            catalogueId: 'east',
          ),
          // Unlinked, and on top of Barracuda West.
          DiveSite(
            id: 'mine',
            name: 'My Spot',
            location: GeoPoint(_pier.latitude + 100 / 111320.0, -68.28),
          ),
        ],
      );

      await tester.enterText(find.byType(TextField), 'barracuda');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(_builtInTitles(tester), ['Barracuda West']);
    });

    testWidgets('closing the sheet with a search pending leaves no timer', (
      tester,
    ) async {
      await _pump(tester, areaAnchor: _inferred);

      await tester.enterText(find.byType(TextField), 'angel');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox());
      // The test framework fails a test that ends with a timer pending.
    });
  });

  group('adopting', () {
    testWidgets('tapping a built-in row adopts once and returns the site', (
      tester,
    ) async {
      final h = await _pump(tester, areaAnchor: _inferred);
      h.adoptions.gate = Completer<void>();

      await tester.tap(find.text('Angel City'));
      await tester.pump();
      await tester.tap(find.text('Angel City'), warnIfMissed: false);
      await tester.tap(find.text('Bari Reef'), warnIfMissed: false);
      await tester.pump();
      h.adoptions.gate!.complete();
      await tester.pumpAndSettle();

      expect(h.adoptions.adopted.map((s) => s.id), ['c1']);
      expect(h.picked.single.catalogueId, 'c1');
      expect(h.picked.single.id, 'adopted-c1');
    });

    testWidgets('the after-create rules run before the site is returned', (
      tester,
    ) async {
      final h = await _pump(tester, areaAnchor: _inferred, withRules: true);

      await tester.tap(find.text('Angel City'));
      await tester.pumpAndSettle();

      expect(h.adoptions.order, ['adopt', 'rules', 'read']);
      // The dive form gets the site as the rules left it.
      expect(h.picked.single.name, 'Renamed By A Rule');
    });

    testWidgets('a failed adoption keeps the picker open and says so', (
      tester,
    ) async {
      final h = await _pump(tester, areaAnchor: _inferred);
      h.adoptions.fail = true;

      await tester.tap(find.text('Angel City'));
      await tester.pumpAndSettle();

      expect(h.picked, isEmpty);
      expect(find.text('Could not add this site'), findsOneWidget);
      expect(find.text('Angel City'), findsOneWidget);

      // And it can be tried again.
      h.adoptions.fail = false;
      await tester.tap(find.text('Angel City'));
      await tester.pumpAndSettle();
      expect(h.picked.single.catalogueId, 'c1');
      expect(find.text('Could not add this site'), findsNothing);
    });

    testWidgets('the details button opens the card, whose action adopts', (
      tester,
    ) async {
      final h = await _pump(tester, areaAnchor: _inferred);

      await tester.tap(find.byTooltip('Site details').first);
      await tester.pumpAndSettle();

      expect(find.text('Use this site'), findsOneWidget);
      // The card shows the depth the row had no room to explain.
      expect(find.text('30m'), findsWidgets);
      expect(h.adoptions.adopted, isEmpty);

      await tester.tap(find.text('Use this site'));
      await tester.pumpAndSettle();

      expect(h.adoptions.adopted.map((s) => s.id), ['c1']);
      expect(h.picked.single.catalogueId, 'c1');
    });
  });

  testWidgets('a catalogue that is not open behaves like an empty one', (
    tester,
  ) async {
    LocalCacheDatabaseService.instance.resetForTesting();
    addTearDown(LocalCacheDatabaseService.instance.resetForTesting);

    await _pump(
      tester,
      withCatalogue: false,
      areaAnchor: _inferred,
      sites: const [DiveSite(id: 'mine', name: 'My Reef', location: _pier)],
    );
    await tester.enterText(find.byType(TextField), 'my');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    // Under Nearby and again in the grouped list.
    expect(find.text('My Reef'), findsWidgets);
    expect(find.byType(CatalogueSiteTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
