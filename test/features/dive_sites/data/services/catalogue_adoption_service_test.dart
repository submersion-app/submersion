import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
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
  }) => CatalogueAdoptionService(
    siteRepository: sites,
    fetchElevation: fetchElevation,
  );

  test('adopting creates the site with its details, types and link', () async {
    final adopted = await service().adopt(_saltPier, diverId: null);

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

    expect(second.id, first.id);
    expect(await sites.getAllSites(), hasLength(1));
  });

  test('two divers each get their own site', () async {
    await _createDiver('ana');
    await _createDiver('ben');

    final anas = await service().adopt(_saltPier, diverId: 'ana');
    final bens = await service().adopt(_saltPier, diverId: 'ben');

    expect(anas.id, isNot(bens.id));
    expect(anas.diverId, 'ana');
    expect(bens.diverId, 'ben');
    expect((await service().adopt(_saltPier, diverId: 'ana')).id, anas.id);
  });

  test('altitude is filled after the site exists', () async {
    final asked = <GeoPoint>[];
    final adopted = await service(
      fetchElevation: (point) async {
        asked.add(point);
        return 120;
      },
    ).adopt(_saltPier, diverId: null);

    // The lookup runs behind the returned site.
    await pumpEventQueue();

    expect(asked, [const GeoPoint(12.08, -68.28)]);
    expect((await sites.getSiteById(adopted.id))!.altitude, 120);
  });

  test('adopt does not wait for the elevation lookup', () async {
    final never = Completer<double?>();

    final adopted = await service(
      fetchElevation: (_) => never.future,
    ).adopt(_saltPier, diverId: null).timeout(const Duration(seconds: 5));

    expect(adopted.catalogueId, 'osm_node_1');
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
    final adopted = await service(
      fetchElevation: (_) async => throw StateError('offline'),
    ).adopt(_saltPier, diverId: null);
    await pumpEventQueue();

    expect((await sites.getSiteById(adopted.id))!.altitude, isNull);
  });

  test('a site without coordinates is adopted without a lookup', () async {
    var asked = 0;

    final adopted = await service(
      fetchElevation: (_) async {
        asked++;
        return 120;
      },
    ).adopt(_unlocated, diverId: null);
    await pumpEventQueue();

    expect(asked, 0);
    final stored = (await sites.getSiteById(adopted.id))!;
    expect(stored.location, isNull);
    expect(stored.catalogueId, 'osm_way_2');
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
