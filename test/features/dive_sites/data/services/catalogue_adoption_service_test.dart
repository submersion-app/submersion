import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/geocoding/sea_area_index.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

const _saltPier = CatalogueSite(
  id: 'osm_node_1',
  name: 'Salt Pier',
  location: GeoPoint(12.08, -68.28),
  countryCode: 'BQ',
  country: 'Caribbean Netherlands',
  island: 'Bonaire',
  maxDepth: 15,
  typeIds: ['reef', 'pier'],
  entryMethods: [EntryMethod.shore],
  description: 'Pillars.',
  source: 'osm',
);

const _unlocated = CatalogueSite(
  id: 'osm_way_2',
  name: 'Somewhere',
  source: 'osm',
);

Future<void> _createDiver(String id) async {
  final now = DateTime.now();
  await DiverRepository().createDiver(
    Diver(id: id, name: id, createdAt: now, updatedAt: now),
  );
}

void main() {
  late SiteRepository sites;

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(tearDownTestDatabase);

  CatalogueAdoptionService service({
    Future<double?> Function(GeoPoint point)? fetchElevation,
    Future<SeaAreaIndex?> Function()? loadSeas,
    String Function()? placeNameLanguage,
  }) => CatalogueAdoptionService(
    siteRepository: sites,
    fetchElevation: fetchElevation,
    loadSeas: loadSeas,
    placeNameLanguage: placeNameLanguage,
  );

  group('the sea of an adopted site', () {
    // One sea: the square from the equator and the prime meridian to 10
    // degrees north and east, with a German name.
    final seas = SeaAreaIndex.fromJson(<String, dynamic>{
      'areas': <dynamic>[
        <String, dynamic>{
          'name': 'Test Sea',
          'bbox': <dynamic>[0, 0, 10, 10],
          'area': 100.0,
          'polygons': <dynamic>[
            <String, dynamic>{
              'outer': <dynamic>[0, 0, 10, 0, 10, 10, 0, 10, 0, 0],
            },
          ],
          'names': <String, dynamic>{'de': 'Testmeer'},
        },
      ],
    });
    const inTheSea = CatalogueSite(
      id: 'osm_node_9',
      name: 'Shark Reef',
      location: GeoPoint(5, 5),
      bodyOfWater: 'Test Sea',
      source: 'osm',
    );

    Future<String?> adoptedSea(
      CatalogueSite site, {
      Future<SeaAreaIndex?> Function()? loadSeas,
      String language = 'de',
    }) async {
      final adoption = await service(
        loadSeas: loadSeas,
        placeNameLanguage: () => language,
      ).adopt(site, diverId: null);
      return (await sites.getSiteById(adoption.site.id))!.bodyOfWater;
    }

    test("is named in the diver's place-name language", () async {
      // As every other route that names a site's sea does: one column must
      // not hold "Red Sea" on one site and "Rotes Meer" on the next.
      expect(
        await adoptedSea(inTheSea, loadSeas: () async => seas),
        'Testmeer',
      );
    });

    test(
      'stays as the catalogue has it for a language the table lacks',
      () async {
        expect(
          await adoptedSea(
            inTheSea,
            loadSeas: () async => seas,
            language: 'fr',
          ),
          'Test Sea',
        );
      },
    );

    test('is kept when the sea table did not give it', () async {
      // A record that came with its own body of water is not renamed.
      const lagoon = CatalogueSite(
        id: 'osm_node_10',
        name: 'Lagoon Wall',
        location: GeoPoint(5, 5),
        bodyOfWater: 'Blue Lagoon',
        source: 'osm',
      );

      expect(
        await adoptedSea(lagoon, loadSeas: () async => seas),
        'Blue Lagoon',
      );
    });

    test('is kept when the sea table cannot be read', () async {
      expect(
        await adoptedSea(inTheSea, loadSeas: () async => null),
        'Test Sea',
      );
      expect(
        await adoptedSea(
          const CatalogueSite(
            id: 'osm_node_11',
            name: 'Other Reef',
            location: GeoPoint(5, 5),
            bodyOfWater: 'Test Sea',
            source: 'osm',
          ),
          loadSeas: () async => throw StateError('no asset'),
        ),
        'Test Sea',
      );
    });
  });

  test('adopting creates the site with its details, types and link', () async {
    final adoption = await service().adopt(_saltPier, diverId: null);
    final adopted = adoption.site;

    expect(adoption.created, isTrue);
    final stored = (await sites.getSiteById(adopted.id))!;
    expect(stored.name, 'Salt Pier');
    expect(stored.catalogueId, 'osm_node_1');
    expect(stored.location, const GeoPoint(12.08, -68.28));
    expect(stored.maxDepth, 15);
    expect(stored.countryCode, 'BQ');
    expect(stored.island, 'Bonaire');
    expect(stored.entryMethods, [EntryMethod.shore]);
    expect(stored.description, 'Pillars.');
    expect(stored.notes, '');
    final types = await SiteClassificationRepository().getTypesForSite(
      adopted.id,
    );
    expect(types.map((t) => t.id).toSet(), {'reef', 'pier'});
  });

  test('adopting twice returns the first site', () async {
    final first = await service().adopt(_saltPier, diverId: null);
    final second = await service().adopt(_saltPier, diverId: null);

    expect(first.created, isTrue);
    // Nothing was created the second time: callers run no "after create"
    // rules on it.
    expect(second.created, isFalse);
    expect(second.site.id, first.site.id);
    expect(await sites.getAllSites(), hasLength(1));
  });

  test('two divers each get their own site', () async {
    await _createDiver('ana');
    await _createDiver('ben');

    final anas = (await service().adopt(_saltPier, diverId: 'ana')).site;
    final bens = (await service().adopt(_saltPier, diverId: 'ben')).site;

    expect(anas.id, isNot(bens.id));
    expect(anas.diverId, 'ana');
    expect(bens.diverId, 'ben');
    expect((await service().adopt(_saltPier, diverId: 'ana')).site.id, anas.id);
  });

  test('altitude is filled after the site exists', () async {
    final asked = <GeoPoint>[];
    final adopted = (await service(
      fetchElevation: (point) async {
        asked.add(point);
        return 120;
      },
    ).adopt(_saltPier, diverId: null)).site;

    // The lookup runs behind the returned site.
    await pumpEventQueue();

    expect(asked, [const GeoPoint(12.08, -68.28)]);
    expect((await sites.getSiteById(adopted.id))!.altitude, 120);
  });

  test('adopt does not wait for the elevation lookup', () async {
    final never = Completer<double?>();

    final adoption = await service(
      fetchElevation: (_) => never.future,
    ).adopt(_saltPier, diverId: null).timeout(const Duration(seconds: 5));

    expect(adoption.site.catalogueId, 'osm_node_1');
  });

  test('fillAltitude false never asks for an elevation', () async {
    var asked = 0;

    await service(
      fetchElevation: (_) async {
        asked++;
        return 120;
      },
    ).adopt(_saltPier, diverId: null, fillAltitude: false);
    await pumpEventQueue();

    expect(asked, 0);
  });

  test('a failing elevation lookup is swallowed', () async {
    final adopted = (await service(
      fetchElevation: (_) async => throw StateError('offline'),
    ).adopt(_saltPier, diverId: null)).site;
    await pumpEventQueue();

    expect((await sites.getSiteById(adopted.id))!.altitude, isNull);
  });

  test('a site without coordinates is adopted without a lookup', () async {
    var asked = 0;

    final adopted = (await service(
      fetchElevation: (_) async {
        asked++;
        return 120;
      },
    ).adopt(_unlocated, diverId: null)).site;
    await pumpEventQueue();

    expect(asked, 0);
    final stored = (await sites.getSiteById(adopted.id))!;
    expect(stored.location, isNull);
    expect(stored.catalogueId, 'osm_way_2');
  });

  test('two adoptions at once make one site', () async {
    // The map and the picker, or a second window: both ask before either
    // has written.
    final shared = service();

    final results = await Future.wait([
      shared.adopt(_saltPier, diverId: null),
      shared.adopt(_saltPier, diverId: null),
    ]);

    expect(await sites.getAllSites(), hasLength(1));
    expect(results[0].site.id, results[1].site.id);
    // Created once: the rules run for one of them only.
    expect(results.where((r) => r.created), hasLength(1));
  });

  test('a failed adoption does not block the next try', () async {
    final shared = service();
    await sites.createSite(const DiveSite(id: 'taken', name: 'x'));

    // A catalogue record whose site cannot be written.
    await expectLater(
      shared.adopt(
        const CatalogueSite(id: 'bad', name: 'Bad', source: 'osm'),
        diverId: 'no-such-diver',
      ),
      throwsA(anything),
    );

    final retry = await shared.adopt(
      const CatalogueSite(id: 'bad', name: 'Bad', source: 'osm'),
      diverId: null,
    );
    expect(retry.created, isTrue);
  });

  test('an already adopted site is not looked up again', () async {
    var asked = 0;
    Future<double?> fetch(GeoPoint _) async {
      asked++;
      return 120;
    }

    await service(fetchElevation: fetch).adopt(_saltPier, diverId: null);
    await pumpEventQueue();
    await service(fetchElevation: fetch).adopt(_saltPier, diverId: null);
    await pumpEventQueue();

    expect(asked, 1);
  });
}
