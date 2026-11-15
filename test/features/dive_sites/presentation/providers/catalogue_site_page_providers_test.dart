import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/catalogue_site_page_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/fake_site_catalogue.dart';

const _here = CatalogueSite(
  id: 'here',
  name: 'Blockship Tabarka',
  location: GeoPoint(58.9, -3.1),
  bodyOfWater: 'North Sea',
  source: 'ukho',
  kind: CatalogueKind.register,
);

SiteWithDiveCount _mine(
  String id, {
  String? catalogueId,
  Set<String> also = const {},
  GeoPoint? location,
  int dives = 0,
}) => SiteWithDiveCount(
  site: DiveSite(
    id: id,
    name: id,
    location: location,
    catalogueId: catalogueId,
    catalogueAnswers: SiteCatalogueAnswers(also: also),
  ),
  diveCount: dives,
);

final _mineProvider = StateProvider<List<SiteWithDiveCount>>((ref) => const []);

ProviderContainer _container(
  FakeSiteCatalogue catalogue, {
  List<SiteWithDiveCount> mine = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      siteCatalogueProvider.overrideWithValue(catalogue),
      _mineProvider.overrideWith((ref) => mine),
      sitesWithCountsProvider.overrideWith(
        (ref) async => ref.watch(_mineProvider),
      ),
      placeNameLanguageProvider.overrideWithValue('en'),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('catalogueOwnerSiteIdProvider', () {
    Future<String?> owner(ProviderContainer container, String id) async {
      container.listen(catalogueOwnerSiteIdProvider(id), (_, _) {});
      await container.read(sitesWithCountsProvider.future);
      return container.read(catalogueOwnerSiteIdProvider(id));
    }

    test('the site adopted from the record', () async {
      final container = _container(
        FakeSiteCatalogue(),
        mine: [
          _mine('other', catalogueId: 'elsewhere'),
          _mine('mine', catalogueId: 'here'),
        ],
      );

      expect(await owner(container, 'here'), 'mine');
    });

    test('failing that, the site a merge folded it into', () async {
      final container = _container(
        FakeSiteCatalogue(),
        mine: [
          _mine('survivor', catalogueId: 'elsewhere', also: {'here'}),
        ],
      );

      expect(await owner(container, 'here'), 'survivor');
    });

    test('the adopted site wins over a merged one', () async {
      final container = _container(
        FakeSiteCatalogue(),
        mine: [
          _mine('survivor', catalogueId: 'elsewhere', also: {'here'}),
          _mine('adopted', catalogueId: 'here'),
        ],
      );

      expect(await owner(container, 'here'), 'adopted');
    });

    test('null when the record is not the diver\'s', () async {
      final container = _container(
        FakeSiteCatalogue(),
        mine: [_mine('other', catalogueId: 'elsewhere')],
      );

      expect(await owner(container, 'here'), isNull);
    });

    test('follows the diver\'s sites as they change', () async {
      final container = _container(FakeSiteCatalogue());
      expect(await owner(container, 'here'), isNull);

      container.read(_mineProvider.notifier).state = [
        _mine('added', catalogueId: 'here'),
      ];
      await container.read(sitesWithCountsProvider.future);

      expect(container.read(catalogueOwnerSiteIdProvider('here')), 'added');
    });
  });

  group('catalogueNearbyProvider', () {
    test(
      'reads the records around the record and the diver\'s sites',
      () async {
        final catalogue = FakeSiteCatalogue(const [
          _here,
          CatalogueSite(
            id: 'neighbour',
            name: 'Inganess Bay',
            location: GeoPoint(58.91, -3.1),
            source: 'osm',
          ),
          CatalogueSite(
            id: 'far',
            name: 'Dover',
            location: GeoPoint(51.1, 1.4),
            source: 'osm',
          ),
        ]);
        final container = _container(
          catalogue,
          mine: [
            _mine('barriers', location: const GeoPoint(58.89, -3.1), dives: 3),
          ],
        );

        final nearby = await container.read(
          catalogueNearbyProvider('here').future,
        );

        expect(nearby.builtIn.map((r) => r.record.id), ['neighbour']);
        expect(nearby.yours.single.site.id, 'barriers');
        expect(nearby.yours.single.diveCount, 3);
        // One small read per kind, not everything in the radius.
        expect(catalogue.nearCalls, 2);
      },
    );

    test('empty for a record the catalogue does not hold', () async {
      final container = _container(FakeSiteCatalogue());

      final nearby = await container.read(
        catalogueNearbyProvider('gone').future,
      );

      expect(nearby.isEmpty, isTrue);
    });

    test('empty, and nothing read, for a record without coordinates', () async {
      final catalogue = FakeSiteCatalogue(const [
        CatalogueSite(id: 'nowhere', name: 'x', source: 'osm'),
      ]);
      final container = _container(catalogue);

      final nearby = await container.read(
        catalogueNearbyProvider('nowhere').future,
      );

      expect(nearby.isEmpty, isTrue);
      expect(catalogue.nearCalls, 0);
    });
  });

  group('catalogueSeaNameProvider', () {
    test('in English the catalogue\'s own name stands', () async {
      final container = _container(FakeSiteCatalogue(const [_here]));

      expect(
        await container.read(catalogueSeaNameProvider('here').future),
        'North Sea',
      );
    });

    test('null for a record with no sea, or no record', () async {
      final container = _container(
        FakeSiteCatalogue(const [
          CatalogueSite(id: 'lake', name: 'Lake', source: 'osm'),
        ]),
      );

      expect(
        await container.read(catalogueSeaNameProvider('lake').future),
        isNull,
      );
      expect(
        await container.read(catalogueSeaNameProvider('gone').future),
        isNull,
      );
    });
  });
}
