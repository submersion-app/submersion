import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_search_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/fake_site_catalogue.dart';
import '../../../../helpers/test_database.dart';

const _blueHole = CatalogueSite(
  id: 'osm_node_1',
  name: 'Blue Hole',
  location: GeoPoint(28.57, 34.54),
  country: 'Egypt',
  region: 'Dahab',
  maxDepth: 100,
  typeIds: ['blue_hole'],
  source: 'osm',
);
const _blueCorner = CatalogueSite(
  id: 'osm_node_2',
  name: 'Blue Corner',
  location: GeoPoint(7.13, 134.22),
  country: 'Palau',
  source: 'osm',
);

/// A catalogue whose search for a given text waits until the test lets it
/// go, so a test can finish two searches in the order it chooses.
class _GatedCatalogue extends FakeSiteCatalogue {
  _GatedCatalogue(super.sites);

  final Map<String, Completer<void>> gates = {};

  @override
  Future<List<CatalogueSite>> search(
    String query, {
    GeoPoint? areaFirst,
    double areaRadiusMeters = 50000,
    int limit = 50,
  }) async {
    await gates[query]?.future;
    return super.search(
      query,
      areaFirst: areaFirst,
      areaRadiusMeters: areaRadiusMeters,
      limit: limit,
    );
  }
}

/// The import page's search: the diver's own sites and the built-in
/// catalogue, with the catalogue sites they already adopted marked.
void main() {
  late ProviderContainer container;
  late SiteRepository sites;
  late _GatedCatalogue catalogue;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    sites = SiteRepository();
    catalogue = _GatedCatalogue([_blueHole, _blueCorner]);
    container = ProviderContainer(
      overrides: [
        siteRepositoryProvider.overrideWithValue(sites),
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        siteCatalogueProvider.overrideWithValue(catalogue),
        // No elevation lookups from a test.
        catalogueAdoptionServiceProvider.overrideWithValue(
          CatalogueAdoptionService(siteRepository: sites),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  ExternalSiteSearchNotifier notifier() =>
      container.read(externalSiteSearchProvider.notifier);
  ExternalSiteSearchState state() => container.read(externalSiteSearchProvider);

  test('a search finds catalogue sites and the diver\'s own', () async {
    await sites.createSite(const DiveSite(id: 'mine', name: 'Blue Lagoon'));

    await notifier().search('blue');

    expect(state().isLoading, isFalse);
    expect(state().hasError, isFalse);
    expect(state().sites.map((s) => s.id), ['osm_node_2', 'osm_node_1']);
    expect(state().localSites.map((s) => s.id), ['mine']);
    expect(state().linkedCatalogueIds, isEmpty);
  });

  test('a search asks the catalogue for up to 200 sites', () async {
    catalogue.sites = [
      for (var i = 0; i < 250; i++)
        CatalogueSite(id: 'r$i', name: 'Reef $i', source: 'osm'),
    ];

    await notifier().search('reef');

    expect(state().sites, hasLength(200));
  });

  test('a search that matches nothing is not an error', () async {
    await notifier().search('zzzz');

    expect(state().hasError, isFalse);
    expect(state().hasResults, isFalse);
    expect(state().query, 'zzzz');
  });

  test('a blank search clears the results', () async {
    await notifier().search('blue');

    await notifier().search('   ');

    expect(state().query, '');
    expect(state().sites, isEmpty);
  });

  test('a site the diver already adopted is marked from the start', () async {
    await sites.createSite(
      const DiveSite(id: 'mine', name: 'Blue Hole', catalogueId: 'osm_node_1'),
    );

    await notifier().search('blue');

    expect(state().linkedCatalogueIds, {'osm_node_1'});
    // Still listed: the page shows it as already in the diver's sites.
    expect(state().sites.map((s) => s.id), contains('osm_node_1'));
  });

  test('a catalogue site beside an unlinked site of the diver\'s is still '
      'offered', () async {
    await sites.createSite(
      const DiveSite(
        id: 'mine',
        name: 'My Blue Hole',
        location: GeoPoint(28.57, 34.54),
      ),
    );

    await notifier().search('blue hole');

    expect(state().sites.map((s) => s.id), ['osm_node_1']);
    expect(state().linkedCatalogueIds, isEmpty);
  });

  test('importing adopts the site with its details and marks it', () async {
    await notifier().search('blue');

    final adoption = await notifier().importSite(_blueHole);

    expect(adoption, isNotNull);
    expect(adoption!.created, isTrue);
    final imported = adoption.site;
    final stored = (await sites.getSiteById(imported.id))!;
    expect(stored.catalogueId, 'osm_node_1');
    expect(stored.maxDepth, 100);
    expect(stored.country, 'Egypt');
    expect(stored.notes, '');
    final types = await SiteClassificationRepository().getTypesForSite(
      imported.id,
    );
    expect(types.map((t) => t.id), ['blue_hole']);
    expect(state().linkedCatalogueIds, {'osm_node_1'});
  });

  test('importing the same site twice makes one site', () async {
    final first = await notifier().importSite(_blueHole);
    final second = await notifier().importSite(_blueHole);

    expect(second!.site.id, first!.site.id);
    // The second import made nothing: the page runs no rules for it.
    expect(second.created, isFalse);
    expect(await sites.getAllSites(), hasLength(1));
  });

  test('a search that finishes late does not replace a newer one', () async {
    final hole = Completer<void>();
    catalogue.gates['hole'] = hole;

    final slow = notifier().search('hole');
    await notifier().search('corner');
    hole.complete();
    await slow;

    expect(state().query, 'corner');
    expect(state().sites.map((s) => s.id), ['osm_node_2']);
    expect(state().isLoading, isFalse);
  });

  test('a search still out when the page is cleared shows nothing', () async {
    final hole = Completer<void>();
    catalogue.gates['hole'] = hole;

    final slow = notifier().search('hole');
    await pumpEventQueue();
    notifier().clear();
    hole.complete();
    await slow;

    expect(state().query, isEmpty);
    expect(state().sites, isEmpty);
    expect(state().isLoading, isFalse);
  });

  test('says when the catalogue has more matches than it lists', () async {
    catalogue.sites = [
      for (var i = 0; i < 201; i++)
        CatalogueSite(
          id: 'reef_$i',
          name: 'Reef ${i.toString().padLeft(3, '0')}',
          source: 'osm',
        ),
    ];

    await notifier().search('reef');

    expect(state().sites, hasLength(200));
    expect(state().sites.last.name, 'Reef 199');
    expect(state().isTruncated, isTrue);
  });

  test('a list that holds every match is not marked as cut short', () async {
    await notifier().search('blue');

    expect(state().sites, hasLength(2));
    expect(state().isTruncated, isFalse);
  });
}
