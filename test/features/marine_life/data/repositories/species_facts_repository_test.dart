import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/repositories/species_facts_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_gallery_fixtures.dart';

/// diver-a: d1 (Jan 2024, Bonaire, Reef), d2 (Jan 2025, Bonaire, Wall),
/// d3 (Mar 2025, no trip, no site); diver-b: d4 (Mar 2025).
/// Grouper seen on d1 twice (two sightings), d2, d3; diver-b sees it on d4.
Future<void> _seed() async {
  await insertTestDiver('diver-a');
  await insertTestDiver('diver-b');
  await insertTestSite('reef', 'Reef');
  await insertTestSite('wall', 'Wall');
  await insertTestTrip('bonaire', 'Bonaire', DateTime.utc(2024, 1, 1));
  await insertTestTrip('cozumel', 'Cozumel', DateTime.utc(2025, 1, 1));
  await insertTestDive(
    id: 'd1',
    at: DateTime.utc(2024, 1, 10),
    diverId: 'diver-a',
    siteId: 'reef',
  );
  await insertTestDive(
    id: 'd2',
    at: DateTime.utc(2025, 1, 20),
    diverId: 'diver-a',
    siteId: 'wall',
  );
  await insertTestDive(
    id: 'd3',
    at: DateTime.utc(2025, 3, 5),
    diverId: 'diver-a',
  );
  await insertTestDive(
    id: 'd4',
    at: DateTime.utc(2025, 3, 5),
    diverId: 'diver-b',
  );
  await setDiveTrip('d1', 'bonaire');
  await setDiveTrip('d2', 'cozumel');
  await insertTestSpecies(id: 'grouper', name: 'Grouper');
  await insertTestSighting(id: 's1', diveId: 'd1', speciesId: 'grouper');
  await insertTestSighting(id: 's1b', diveId: 'd1', speciesId: 'grouper');
  await insertTestSighting(id: 's2', diveId: 'd2', speciesId: 'grouper');
  await insertTestSighting(id: 's3', diveId: 'd3', speciesId: 'grouper');
  await insertTestSighting(id: 's4', diveId: 'd4', speciesId: 'grouper');
}

void main() {
  late SpeciesFactsRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesFactsRepository();
    await _seed();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'places lists each trip once per species, a dive with no trip as No trip',
    () async {
      final places = await repository.places(diverId: 'diver-a');

      final trips = places.tripsBySpecies['grouper']!;
      expect(trips.map((t) => t.id).toSet(), {'bonaire', 'cozumel', null});
      expect(trips, hasLength(3));
      final cozumel = trips.firstWhere((t) => t.id == 'cozumel');
      expect(cozumel.name, 'Cozumel');
      expect(cozumel.sortDate, DateTime.utc(2025, 1, 1));
      expect(places.sitesBySpecies['grouper']!.map((s) => s.id).toSet(), {
        'reef',
        'wall',
        null,
      });
    },
  );

  test('firstTripBySpecies is the trip of the earliest sighting', () async {
    final places = await repository.places(diverId: 'diver-a');

    expect(places.firstTripBySpecies['grouper'], 'bonaire');
    expect(places.firstSiteBySpecies['grouper'], 'reef');
  });

  test('month counts count dives, not sightings, by calendar month', () async {
    final months = await repository.monthCounts('grouper', diverId: 'diver-a');

    expect(months, hasLength(12));
    expect(months[0], 2);
    expect(months[2], 1);
    expect(months.fold<int>(0, (a, b) => a + b), 3);
  });

  test(
    'photo depths come from tagged media on the diver dives and skip null depths',
    () async {
      await insertTestMedia(id: 'p1', diveId: 'd1');
      await insertTestMedia(id: 'p2', diveId: 'd2');
      await insertTestMedia(id: 'p3', diveId: 'd4');
      await insertTestMedia(id: 'p4', diveId: 'd2');
      await insertTestTag(mediaId: 'p1', speciesId: 'grouper');
      await insertTestTag(mediaId: 'p2', speciesId: 'grouper');
      await insertTestTag(mediaId: 'p3', speciesId: 'grouper');
      await insertTestDepth(mediaId: 'p1', diveId: 'd1', depth: 8.5);
      await insertTestDepth(mediaId: 'p2', diveId: 'd2');
      await insertTestDepth(mediaId: 'p3', diveId: 'd4', depth: 30);
      await insertTestDepth(mediaId: 'p4', diveId: 'd2', depth: 12);

      final depths = await repository.photoDepths(
        'grouper',
        diverId: 'diver-a',
      );

      expect(depths, [8.5]);
    },
  );

  test('a photo with two enrichment rows gives one depth', () async {
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestTag(mediaId: 'p1', speciesId: 'grouper');
    await insertTestDepth(mediaId: 'p1', diveId: 'd1', depth: 8);
    await insertTestDepth(mediaId: 'p1', diveId: 'd1', depth: 9, id: 'enr_b');

    final depths = await repository.photoDepths('grouper', diverId: 'diver-a');

    expect(depths, hasLength(1));
  });

  test('depth changes tick', () async {
    await insertTestMedia(id: 'p1', diveId: 'd1');
    final tick = repository.watchDepthChanges().first;
    await insertTestDepth(mediaId: 'p1', diveId: 'd1', depth: 8);
    await expectLater(tick, completes);
  });
}
