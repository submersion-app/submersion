import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

import '../../../../helpers/fake_site_catalogue.dart';

CatalogueSite _at(String id, double lat, double lng) => CatalogueSite(
  id: id,
  name: id,
  location: GeoPoint(lat, lng),
  source: 'osm',
);

SiteWithDiveCount _mine(DiveSite site) =>
    SiteWithDiveCount(site: site, diveCount: 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('showBuiltInSitesProvider defaults to false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(showBuiltInSitesProvider), isFalse);
  });

  test('builtInSitesProvider reads the catalogue sites that have '
      'coordinates', () async {
    final container = ProviderContainer(
      overrides: [
        siteCatalogueProvider.overrideWithValue(
          FakeSiteCatalogue([
            _at('a', 1, 1),
            const CatalogueSite(id: 'nowhere', name: 'N', source: 'osm'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final sites = await container.read(builtInSitesProvider.future);

    expect(sites.map((s) => s.id), ['a']);
  });

  test('builtInSitesProvider reads again when the catalogue is '
      'imported', () async {
    final catalogue = FakeSiteCatalogue();
    final container = ProviderContainer(
      overrides: [siteCatalogueProvider.overrideWithValue(catalogue)],
    );
    addTearDown(container.dispose);
    expect(await container.read(builtInSitesProvider.future), isEmpty);

    catalogue.sites = [_at('a', 1, 1)];
    container.read(siteCatalogueRevisionProvider.notifier).state++;

    final sites = await container.read(builtInSitesProvider.future);
    expect(sites.map((s) => s.id), ['a']);
  });

  test('visibleBuiltInSitesProvider hides a record an unlinked site of '
      'the diver sits on', () async {
    final container = ProviderContainer(
      overrides: [
        builtInSitesProvider.overrideWith(
          (ref) async => [_at('keep', 50.0, 50.0), _at('dupe', 10.0, 20.0)],
        ),
        sitesWithCountsProvider.overrideWith(
          (ref) async => [
            _mine(
              const DiveSite(id: 'u', name: 'u', location: GeoPoint(10, 20)),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(visibleBuiltInSitesProvider.future);

    expect(result.map((s) => s.id), ['keep']);
  });

  test('visibleBuiltInSitesProvider hides an adopted record but not its '
      'neighbour', () async {
    final container = ProviderContainer(
      overrides: [
        builtInSitesProvider.overrideWith(
          // About 100 m apart.
          (ref) async => [
            _at('east', 12.0, -68.0),
            _at('west', 12.0009, -68.0),
          ],
        ),
        sitesWithCountsProvider.overrideWith(
          (ref) async => [
            _mine(
              const DiveSite(
                id: 'u',
                name: 'East',
                location: GeoPoint(12.0, -68.0),
                catalogueId: 'east',
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(visibleBuiltInSitesProvider.future);

    expect(result.map((s) => s.id), ['west']);
  });
}
