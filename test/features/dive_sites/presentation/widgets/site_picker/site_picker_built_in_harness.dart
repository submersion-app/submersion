import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
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

/// What the built-in site picker tests share: a small catalogue around
/// Salt Pier, stand-ins for the location service and the adoption, and the
/// pump that opens the sheet over them.

/// Salt Pier, Bonaire.
const saltPier = GeoPoint(12.0800, -68.2800);

CatalogueSite builtInSite(
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
  location: GeoPoint(saltPier.latitude + north / 111194.93, saltPier.longitude),
  island: island,
  maxDepth: maxDepth,
  entryMethods: const [EntryMethod.shore],
  source: 'osm',
);

/// Nine Bonaire sites, in an order that is neither by name nor by distance.
final bonaireSites = [
  builtInSite('c3', 'Cliff', north: 3000),
  builtInSite('c1', 'Angel City', north: 9000, maxDepth: 30),
  builtInSite('c9', 'Windsock', north: 500),
  builtInSite('c2', 'Bari Reef', north: 8000),
  builtInSite('c5', 'Hilma Hooker', north: 1000),
  builtInSite('c4', 'Front Porch', north: 7000),
  builtInSite('c6', 'Invisibles', north: 6000),
  builtInSite('c7', 'Karpata', north: 5000),
  builtInSite('c8', 'Oil Slick Leap', north: 4000),
];

class PickerSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  PickerSettingsNotifier(super.state);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PickerLocationService implements LocationService {
  PickerLocationService({this.result, this.gate});

  final LocationResult? result;

  /// Completed by a test that wants the fix to arrive late.
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async {
    calls++;
    await gate?.future;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for the database behind an adoption: makes a site from the
/// record, and serves it back the way the repository would.
class PickerAdoptions extends SiteRepository {
  final adopted = <CatalogueSite>[];
  final order = <String>[];

  /// Completed by a test that wants an adoption held in flight.
  Completer<void>? gate;
  bool fail = false;

  /// What the logbook rules "changed" the site's name to, once they ran.
  String? renamedByRules;

  /// False to answer as when the diver already had the site.
  bool created = true;

  Future<CatalogueAdoption> adopt(CatalogueSite site) async {
    adopted.add(site);
    order.add('adopt');
    await gate?.future;
    if (fail) throw StateError('write failed');
    return CatalogueAdoption(
      site: DiveSite(
        id: 'adopted-${site.id}',
        name: site.name,
        location: site.location,
        catalogueId: site.id,
      ),
      created: created,
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

class RenamingRuleEngine extends RuleEngine {
  RenamingRuleEngine(this.adoptions)
    : super(names: (_) async => NameIndex(const []));

  final PickerAdoptions adoptions;

  @override
  Future<RuleRunResult> run(RuleRunRequest request) async {
    adoptions.order.add('rules');
    adoptions.renamedByRules = 'Renamed By A Rule';
    return RuleRunResult.noRules;
  }
}

class PickerHarness {
  PickerHarness(this.catalogue, this.adoptions, this.location);

  final FakeSiteCatalogue catalogue;
  final PickerAdoptions adoptions;
  final PickerLocationService location;
  final picked = <DiveSite>[];
  late ProviderContainer container;
}

Future<PickerHarness> pumpPicker(
  WidgetTester tester, {
  List<DiveSite> sites = const [],
  List<CatalogueSite>? catalogueSites,
  bool showBuiltIn = true,
  GeoPoint? diveLocation,
  SiteAreaAnchor? areaAnchor,
  LocationResult? deviceLocation,
  Completer<void>? locationGate,
  bool withCatalogue = true,
  bool withRules = false,
  void Function(String query)? onCreateNewSite,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final adoptions = PickerAdoptions();
  final harness = PickerHarness(
    FakeSiteCatalogue(catalogueSites ?? bonaireSites),
    adoptions,
    PickerLocationService(result: deviceLocation, gate: locationGate),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sitesProvider.overrideWith((ref) async => sites),
        settingsProvider.overrideWith(
          (ref) => PickerSettingsNotifier(const AppSettings()),
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
          ruleEngineProvider.overrideWithValue(RenamingRuleEngine(adoptions)),
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
List<String> pickerRowTitles(WidgetTester tester) => tester
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

List<String> builtInTitles(WidgetTester tester) => tester
    .widgetList<CatalogueSiteTile>(find.byType(CatalogueSiteTile))
    .map((tile) => tile.site.name)
    .toList();

const inferredBonaire = SiteAreaAnchor(point: saltPier, placeLabel: 'Bonaire');
