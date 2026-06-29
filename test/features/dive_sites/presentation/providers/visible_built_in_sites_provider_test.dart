import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/built_in_sites_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

ExternalDiveSite ext(String id, double lat, double lng) => ExternalDiveSite(
  externalId: id,
  name: id,
  latitude: lat,
  longitude: lng,
  source: 't',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('showBuiltInSitesProvider defaults to false', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(showBuiltInSitesProvider), isFalse);
  });

  test(
    'builtInSitesProvider loads bundled sites that all have coordinates',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sites = await container.read(builtInSitesProvider.future);
      expect(sites, isNotEmpty);
      expect(sites.every((s) => s.hasCoordinates), isTrue);
    },
  );

  test(
    'visibleBuiltInSitesProvider removes built-ins matching user sites',
    () async {
      final container = ProviderContainer(
        overrides: [
          builtInSitesProvider.overrideWith(
            (ref) async => [ext('keep', 50.0, 50.0), ext('dupe', 10.0, 20.0)],
          ),
          sitesWithCountsProvider.overrideWith(
            (ref) async => [
              SiteWithDiveCount(
                site: const DiveSite(
                  id: 'u',
                  name: 'u',
                  location: GeoPoint(10.0, 20.0),
                ),
                diveCount: 0,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(visibleBuiltInSitesProvider.future);
      expect(result.map((s) => s.externalId), ['keep']);
    },
  );
}
