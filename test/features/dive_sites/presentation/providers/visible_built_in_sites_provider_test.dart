import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

import '../../../../helpers/fake_site_catalogue.dart';

CatalogueSite _at(
  String id,
  double lat,
  double lng, {
  CatalogueKind kind = CatalogueKind.site,
}) => CatalogueSite(
  id: id,
  name: id,
  location: GeoPoint(lat, lng),
  source: 'osm',
  kind: kind,
);

SiteWithDiveCount _mine(DiveSite site) =>
    SiteWithDiveCount(site: site, diveCount: 0);

const _tropics = CatalogueBounds(south: 0, west: -80, north: 30, east: -60);
const _north = CatalogueBounds(south: 40, west: -10, north: 60, east: 10);

/// A container over [catalogue] whose overlay providers stay alive for
/// the test, as a map on screen keeps them.
ProviderContainer _container(
  FakeSiteCatalogue catalogue, {
  List<DiveSite> mine = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      siteCatalogueProvider.overrideWithValue(catalogue),
      sitesWithCountsProvider.overrideWith(
        (ref) async => mine.map(_mine).toList(),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(visibleBuiltInSitesProvider, (_, _) {});
  container.listen(builtInOverlayTruncatedProvider, (_, _) {});
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('showBuiltInSitesProvider defaults to false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(showBuiltInSitesProvider), isFalse);
  });

  test('with no bounds reported, nothing is read', () async {
    final catalogue = FakeSiteCatalogue([_at('a', 12, -68)]);
    final container = _container(catalogue);

    expect(await container.read(visibleBuiltInSitesProvider.future), isEmpty);
    expect(catalogue.inBoundsCalls, 0);
    expect(container.read(builtInOverlayTruncatedProvider), isFalse);
  });

  test('the sites in the reported bounds are read, with the marker '
      'limit', () async {
    final catalogue = FakeSiteCatalogue([
      _at('bonaire', 12, -68),
      _at('scapa', 58.9, -3.1),
    ]);
    final container = _container(catalogue);

    container.read(builtInOverlayBoundsProvider.notifier).state = _tropics;
    final sites = await container.read(visibleBuiltInSitesProvider.future);

    expect(sites.map((s) => s.id), ['bonaire']);
    expect(catalogue.boundsAsked, [_tropics]);
    expect(kBuiltInOverlayMarkerLimit, 1500);
  });

  test('new bounds read again; the same bounds do not', () async {
    final catalogue = FakeSiteCatalogue([
      _at('bonaire', 12, -68),
      _at('dover', 51.1, 1.4),
    ]);
    final container = _container(catalogue);
    final bounds = container.read(builtInOverlayBoundsProvider.notifier);

    bounds.state = _tropics;
    await container.read(visibleBuiltInSitesProvider.future);
    bounds.state = const CatalogueBounds(
      south: 0,
      west: -80,
      north: 30,
      east: -60,
    );
    await container.read(visibleBuiltInSitesProvider.future);
    expect(catalogue.inBoundsCalls, 1);

    bounds.state = _north;
    final sites = await container.read(visibleBuiltInSitesProvider.future);
    expect(sites.map((s) => s.id), ['dover']);
    expect(catalogue.inBoundsCalls, 2);
  });

  test('an imported catalogue is read again for the same bounds', () async {
    final catalogue = FakeSiteCatalogue();
    final container = _container(catalogue);
    container.read(builtInOverlayBoundsProvider.notifier).state = _tropics;
    expect(await container.read(visibleBuiltInSitesProvider.future), isEmpty);

    catalogue.sites = [_at('bonaire', 12, -68)];
    container.read(siteCatalogueRevisionProvider.notifier).state++;

    final sites = await container.read(visibleBuiltInSitesProvider.future);
    expect(sites.map((s) => s.id), ['bonaire']);
  });

  test('a box holding more than the limit says so', () async {
    final catalogue = FakeSiteCatalogue([
      for (var i = 0; i < kBuiltInOverlayMarkerLimit + 5; i++)
        _at('w$i', 10 + i * 0.001, -70, kind: CatalogueKind.register),
    ]);
    final container = _container(catalogue);

    container.read(builtInOverlayBoundsProvider.notifier).state = _tropics;
    final sites = await container.read(visibleBuiltInSitesProvider.future);

    expect(sites, hasLength(kBuiltInOverlayMarkerLimit));
    expect(container.read(builtInOverlayTruncatedProvider), isTrue);

    container.read(builtInOverlayBoundsProvider.notifier).state = _north;
    await container.read(visibleBuiltInSitesProvider.future);
    expect(container.read(builtInOverlayTruncatedProvider), isFalse);
  });

  test('a record an unlinked site of the diver sits on is hidden', () async {
    final container = _container(
      FakeSiteCatalogue([_at('keep', 12.0, -68.0), _at('dupe', 10.0, -70.0)]),
      mine: const [DiveSite(id: 'u', name: 'u', location: GeoPoint(10, -70))],
    );

    container.read(builtInOverlayBoundsProvider.notifier).state = _tropics;
    final result = await container.read(visibleBuiltInSitesProvider.future);

    expect(result.map((s) => s.id), ['keep']);
  });

  test('an adopted record is hidden but not its neighbour', () async {
    final container = _container(
      // About 100 m apart.
      FakeSiteCatalogue([
        _at('east', 12.0, -68.0),
        _at('west', 12.0009, -68.0),
      ]),
      mine: const [
        DiveSite(
          id: 'u',
          name: 'East',
          location: GeoPoint(12.0, -68.0),
          catalogueId: 'east',
        ),
      ],
    );

    container.read(builtInOverlayBoundsProvider.notifier).state = _tropics;
    final result = await container.read(visibleBuiltInSitesProvider.future);

    expect(result.map((s) => s.id), ['west']);
  });
}
