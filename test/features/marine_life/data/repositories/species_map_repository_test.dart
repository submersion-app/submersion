import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_map_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';

import '../../../../helpers/test_database.dart';

AppDatabase get _db => DatabaseService.instance.database;
int get _now => DateTime.now().millisecondsSinceEpoch;

Future<void> _diver(String id) => _db
    .into(_db.divers)
    .insert(
      DiversCompanion(
        id: Value(id),
        name: Value('Diver $id'),
        createdAt: Value(_now),
        updatedAt: Value(_now),
      ),
    );

Future<void> _site(
  String id,
  String name, {
  double? lat,
  double? lng,
  String? diverId,
  bool shared = false,
}) => _db
    .into(_db.diveSites)
    .insert(
      DiveSitesCompanion(
        id: Value(id),
        name: Value(name),
        latitude: Value(lat),
        longitude: Value(lng),
        diverId: Value(diverId),
        isShared: Value(shared),
        createdAt: Value(_now),
        updatedAt: Value(_now),
      ),
    );

Future<void> _dive(
  String id, {
  required String diverId,
  String? siteId,
  bool excluded = false,
  bool planned = false,
}) => _db
    .into(_db.dives)
    .insert(
      DivesCompanion(
        id: Value(id),
        diveDateTime: Value(DateTime.utc(2024, 1, 1).millisecondsSinceEpoch),
        diverId: Value(diverId),
        siteId: Value(siteId),
        excludedFromStats: Value(excluded),
        isPlanned: Value(planned),
        createdAt: Value(_now),
        updatedAt: Value(_now),
      ),
    );

Future<void> _species(String id) => _db
    .into(_db.species)
    .insert(
      SpeciesCompanion(
        id: Value(id),
        commonName: Value('Species $id'),
        category: const Value('fish'),
      ),
    );

var _sightingSeq = 0;
Future<void> _sighting(String diveId, String speciesId, {int count = 1}) => _db
    .into(_db.sightings)
    .insert(
      SightingsCompanion(
        id: Value('sg${_sightingSeq++}'),
        diveId: Value(diveId),
        speciesId: Value(speciesId),
        count: Value(count),
      ),
    );

var _expectedSeq = 0;
Future<void> _expected(String siteId, String speciesId) => _db
    .into(_db.siteSpecies)
    .insert(
      SiteSpeciesCompanion(
        id: Value('ss${_expectedSeq++}'),
        siteId: Value(siteId),
        speciesId: Value(speciesId),
        createdAt: Value(_now),
      ),
    );

Future<void> _hide(String siteId, String diverId) => _db
    .into(_db.siteHides)
    .insert(
      SiteHidesCompanion(
        id: Value('h-$siteId-$diverId'),
        siteId: Value(siteId),
        diverId: Value(diverId),
        createdAt: Value(_now),
      ),
    );

/// diver-a owns s1 (Blue Hole) and s2 (Shark Point); s3 (Far Reef) belongs to
/// diver-b and is unshared; s4 has no coordinates; s5 has a latitude of 95.
/// sp-shark: d1 at s1 x2, d2 at s1 x1, d3 at s2 x4, d4 no site x3,
///           d5 at s4 x1, d6 at s5 x1, d7 (diver-b) at s3 x5
/// sp-turtle: d1 at s1 x1
Future<void> _seed() async {
  await _diver('diver-a');
  await _diver('diver-b');
  await _site('s1', 'Blue Hole', lat: 10, lng: 20, diverId: 'diver-a');
  await _site('s2', 'Shark Point', lat: 11, lng: 21, diverId: 'diver-a');
  await _site('s3', 'Far Reef', lat: 12, lng: 22, diverId: 'diver-b');
  await _site('s4', 'No Location', diverId: 'diver-a');
  await _site('s5', 'Bad Latitude', lat: 95, lng: 0, diverId: 'diver-a');
  await _species('sp-shark');
  await _species('sp-turtle');
  await _dive('d1', diverId: 'diver-a', siteId: 's1');
  await _dive('d2', diverId: 'diver-a', siteId: 's1');
  await _dive('d3', diverId: 'diver-a', siteId: 's2');
  await _dive('d4', diverId: 'diver-a');
  await _dive('d5', diverId: 'diver-a', siteId: 's4');
  await _dive('d6', diverId: 'diver-a', siteId: 's5');
  await _dive('d7', diverId: 'diver-b', siteId: 's3');
  await _sighting('d1', 'sp-shark', count: 2);
  await _sighting('d1', 'sp-turtle');
  await _sighting('d2', 'sp-shark');
  await _sighting('d3', 'sp-shark', count: 4);
  await _sighting('d4', 'sp-shark', count: 3);
  await _sighting('d5', 'sp-shark');
  await _sighting('d6', 'sp-shark');
  await _sighting('d7', 'sp-shark', count: 5);
}

void main() {
  late SpeciesMapRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesMapRepository();
    await _seed();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getSitePins', () {
    test(
      'counts distinct species and summed sightings per site, for the diver',
      () async {
        final pins = await repository.getSitePins(diverId: 'diver-a');
        final byId = {for (final p in pins) p.siteId: p};

        expect(byId.keys, unorderedEquals(['s1', 's2']));
        expect(byId['s1']!.speciesCount, 2);
        expect(byId['s1']!.sightingCount, 4);
        expect(byId['s1']!.siteName, 'Blue Hole');
        expect(byId['s1']!.latitude, 10);
        expect(byId['s1']!.longitude, 20);
        expect(byId['s2']!.speciesCount, 1);
        expect(byId['s2']!.sightingCount, 4);
      },
    );

    test('with no diver covers every diver', () async {
      final pins = await repository.getSitePins();

      expect(pins.map((p) => p.siteId), unorderedEquals(['s1', 's2', 's3']));
    });

    test(
      'drops sites without valid coordinates and dives without a site',
      () async {
        final pins = await repository.getSitePins(diverId: 'diver-a');

        expect(pins.map((p) => p.siteId), isNot(contains('s4')));
        expect(pins.map((p) => p.siteId), isNot(contains('s5')));
      },
    );

    test('honours the statistics scope', () async {
      await _dive('dx', diverId: 'diver-a', siteId: 's2', excluded: true);
      await _dive('dp', diverId: 'diver-a', siteId: 's2', planned: true);
      await _sighting('dx', 'sp-turtle', count: 9);
      await _sighting('dp', 'sp-turtle', count: 9);

      final pins = await repository.getSitePins(diverId: 'diver-a');
      final s2 = pins.singleWhere((p) => p.siteId == 's2');

      expect(s2.speciesCount, 1);
      expect(s2.sightingCount, 4);
    });
  });

  group('getPinsForSpecies', () {
    test('returns logged pins with summed counts', () async {
      final pins = await repository.getPinsForSpecies(
        'sp-shark',
        diverId: 'diver-a',
      );
      final logged = pins.where((p) => p.kind == SpeciesPinKind.logged);

      expect(
        {for (final p in logged) p.siteId: p.sightingCount},
        {'s1': 3, 's2': 4},
      );
    });

    test('adds expected pins only where not logged', () async {
      await _expected('s1', 'sp-turtle');
      await _expected('s2', 'sp-turtle');

      final pins = await repository.getPinsForSpecies(
        'sp-turtle',
        diverId: 'diver-a',
      );

      expect(pins, hasLength(2));
      final s1 = pins.singleWhere((p) => p.siteId == 's1');
      final s2 = pins.singleWhere((p) => p.siteId == 's2');
      expect(s1.kind, SpeciesPinKind.logged);
      expect(s2.kind, SpeciesPinKind.expected);
      expect(s2.sightingCount, 0);
    });

    test('mine scope keeps sites the diver owns or has dived', () async {
      // s3 belongs to diver-b and diver-a has never dived it.
      await _expected('s3', 'sp-turtle');
      // s6 belongs to diver-b too, but diver-a has dived it.
      await _site('s6', 'Visited Reef', lat: 13, lng: 23, diverId: 'diver-b');
      await _dive('d8', diverId: 'diver-a', siteId: 's6');
      await _expected('s6', 'sp-turtle');

      final pins = await repository.getPinsForSpecies(
        'sp-turtle',
        diverId: 'diver-a',
      );

      expect(pins.map((p) => p.siteId), isNot(contains('s3')));
      expect(pins.map((p) => p.siteId), contains('s6'));
    });

    test('allVisible scope follows the visibility rule', () async {
      await _site(
        's7',
        'Shared Reef',
        lat: 14,
        lng: 24,
        diverId: 'diver-b',
        shared: true,
      );
      await _expected('s7', 'sp-turtle');
      await _expected('s3', 'sp-turtle');
      // Dived by diver-a but owned by diver-b and unshared: in "mine", and
      // so in "all visible" too, which is never narrower.
      await _site('s6', 'Visited Reef', lat: 13, lng: 23, diverId: 'diver-b');
      await _dive('d8', diverId: 'diver-a', siteId: 's6');
      await _expected('s6', 'sp-turtle');

      final mine = await repository.getPinsForSpecies(
        'sp-turtle',
        diverId: 'diver-a',
      );
      final visible = await repository.getPinsForSpecies(
        'sp-turtle',
        diverId: 'diver-a',
        scope: ExpectedSiteScope.allVisible,
      );

      expect(mine.map((p) => p.siteId), isNot(contains('s7')));
      expect(visible.map((p) => p.siteId), contains('s7'));
      expect(visible.map((p) => p.siteId), contains('s6'));
      // Visible, but neither owned, shared nor dived.
      expect(visible.map((p) => p.siteId), isNot(contains('s3')));
    });

    test('allVisible scope drops a site the diver has hidden', () async {
      await _site(
        's7',
        'Shared Reef',
        lat: 14,
        lng: 24,
        diverId: 'diver-b',
        shared: true,
      );
      await _expected('s7', 'sp-turtle');
      await _hide('s7', 'diver-a');

      final pins = await repository.getPinsForSpecies(
        'sp-turtle',
        diverId: 'diver-a',
        scope: ExpectedSiteScope.allVisible,
      );

      expect(pins.map((p) => p.siteId), isNot(contains('s7')));
    });

    test('expected pins skip sites without valid coordinates', () async {
      await _expected('s4', 'sp-turtle');
      await _expected('s5', 'sp-turtle');

      final pins = await repository.getPinsForSpecies(
        'sp-turtle',
        diverId: 'diver-a',
      );

      expect(pins.map((p) => p.siteId), ['s1']);
    });
  });

  group('countUnplacedSightings', () {
    test('sums sightings on site-less and coordinate-less dives', () async {
      expect(
        await repository.countUnplacedSightings(
          speciesId: 'sp-shark',
          diverId: 'diver-a',
        ),
        5,
      );
      expect(
        await repository.countUnplacedSightings(
          speciesId: 'sp-turtle',
          diverId: 'diver-a',
        ),
        0,
      );
    });

    test('with no species counts every species', () async {
      await _sighting('d4', 'sp-turtle', count: 2);

      expect(await repository.countUnplacedSightings(diverId: 'diver-a'), 7);
    });
  });

  group('getLoggedSpeciesAtSite', () {
    test('is diver-scoped and ordered by count', () async {
      await _dive('d9', diverId: 'diver-b', siteId: 's1');
      await _sighting('d9', 'sp-turtle', count: 50);

      final logged = await repository.getLoggedSpeciesAtSite(
        's1',
        diverId: 'diver-a',
      );

      expect(logged, const [
        LoggedSpeciesAtSite(speciesId: 'sp-shark', sightingCount: 3),
        LoggedSpeciesAtSite(speciesId: 'sp-turtle', sightingCount: 1),
      ]);
    });
  });
}
