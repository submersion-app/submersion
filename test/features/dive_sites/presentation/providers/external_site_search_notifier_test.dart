import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_classification.dart';
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

/// A repository whose read of every site waits until the test lets it go.
class _HeldSites extends SiteRepository {
  _HeldSites(this.held);

  final Completer<void> held;

  @override
  Future<List<DiveSite>> getAllSites({
    String? diverId,
    List<String>? ids,
  }) async {
    await held.future;
    return super.getAllSites(diverId: diverId, ids: ids);
  }
}

/// A repository that cannot write a site, or cannot search, as a test asks.
class _BrokenSites extends SiteRepository {
  _BrokenSites({this.failCreate = false, this.failSearch = false});

  final bool failCreate;
  final bool failSearch;

  @override
  Future<DiveSite> createSite(
    DiveSite site, {
    SiteClassification? classification,
  }) {
    if (failCreate) throw StateError('disk full');
    return super.createSite(site, classification: classification);
  }

  @override
  Future<List<DiveSite>> searchSites(String query, {String? diverId}) {
    if (failSearch) throw StateError('database closed');
    return super.searchSites(query, diverId: diverId);
  }
}

/// The import page's search: the diver's own sites and the built-in
/// catalogue, with the catalogue sites they already adopted marked.
void main() {
  late ProviderContainer container;
  late SiteRepository sites;
  late _GatedCatalogue catalogue;

  late SharedPreferences prefs;

  ProviderContainer containerFor(SiteRepository repository) =>
      ProviderContainer(
        overrides: [
          siteRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(prefs),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          siteCatalogueProvider.overrideWithValue(catalogue),
          // No elevation lookups from a test.
          catalogueAdoptionServiceProvider.overrideWithValue(
            CatalogueAdoptionService(siteRepository: repository),
          ),
        ],
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    sites = SiteRepository();
    catalogue = _GatedCatalogue([_blueHole, _blueCorner]);
    container = containerFor(sites);
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

  test("the catalogue is searched while the diver's sites are read", () async {
    // Three independent reads: none should wait for another.
    final held = Completer<void>();
    final slow = containerFor(_HeldSites(held));
    addTearDown(slow.dispose);

    final searching = slow
        .read(externalSiteSearchProvider.notifier)
        .search('blue');
    await pumpEventQueue();

    expect(catalogue.searchCalls, 1);
    held.complete();
    await searching;
    expect(slow.read(externalSiteSearchProvider).sites.map((s) => s.id), [
      'osm_node_2',
      'osm_node_1',
    ]);
  });

  test('a search made before the catalogue was loaded is run again when it '
      'is', () async {
    // The catalogue is imported after the first frame of an app run. A
    // search made in that window found nothing; it must not stay that way.
    catalogue.sites = [];
    await notifier().search('blue');
    expect(state().sites, isEmpty);

    catalogue.sites = [_blueHole, _blueCorner];
    container.read(siteCatalogueRevisionProvider.notifier).state++;
    await pumpEventQueue();

    expect(state().query, 'blue');
    expect(state().sites.map((s) => s.id), ['osm_node_2', 'osm_node_1']);
  });

  test(
    'a catalogue import with no search on the page searches nothing',
    () async {
      notifier();
      container.read(siteCatalogueRevisionProvider.notifier).state++;
      await pumpEventQueue();

      expect(catalogue.searchCalls, 0);
      expect(state().query, isEmpty);
    },
  );

  test('a failed import leaves the search results on the page', () async {
    // The page says the import failed in a snackbar. Its results must stay:
    // an error in the state swaps the whole list for the error screen.
    final broken = containerFor(_BrokenSites(failCreate: true));
    addTearDown(broken.dispose);
    final search = broken.read(externalSiteSearchProvider.notifier);
    await search.search('blue');

    final adoption = await search.importSite(_blueHole);

    final after = broken.read(externalSiteSearchProvider);
    expect(adoption, isNull);
    expect(after.hasError, isFalse);
    expect(after.sites.map((s) => s.id), ['osm_node_2', 'osm_node_1']);
    expect(after.linkedCatalogueIds, isEmpty);
  });

  test(
    'a failed search reports the error as it is, with no English prefix',
    () async {
      // The page puts it under a translated "Search Error" title.
      final broken = containerFor(_BrokenSites(failSearch: true));
      addTearDown(broken.dispose);

      await broken.read(externalSiteSearchProvider.notifier).search('blue');

      final after = broken.read(externalSiteSearchProvider);
      expect(after.isLoading, isFalse);
      expect(after.errorMessage, 'Bad state: database closed');
    },
  );

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
