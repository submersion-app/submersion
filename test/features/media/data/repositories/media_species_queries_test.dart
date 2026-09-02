import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_photo_fixtures.dart';

/// diver-a: d1 (Blue Hole, Jan, #101) with photos p1, p2, p3 and a PDF doc1;
///          d2 (no site, Mar, #102) with photo p4.
/// diver-b: d3 (Shark Point, May) with photo p5.
/// site-only photo s1 (Blue Hole, no dive).
/// Whale shark sighted on d1 (sg1), d2 (sg2), d3 (sg3). Turtle on d1 (sg4).
Future<void> seed() async {
  await insertTestDiver('diver-a');
  await insertTestDiver('diver-b');
  await insertTestSite('s1', 'Blue Hole');
  await insertTestSite('s2', 'Shark Point');
  await insertTestDive(
    id: 'd1',
    at: DateTime(2024, 1, 10),
    diverId: 'diver-a',
    siteId: 's1',
    number: 101,
  );
  await insertTestDive(
    id: 'd2',
    at: DateTime(2024, 3, 5),
    diverId: 'diver-a',
    number: 102,
  );
  await insertTestDive(
    id: 'd3',
    at: DateTime(2024, 5, 1),
    diverId: 'diver-b',
    siteId: 's2',
    number: 7,
  );
  await insertTestSpecies(
    id: 'sp_whale_shark',
    name: 'Whale Shark',
    category: SpeciesCategory.shark,
    builtIn: true,
  );
  await insertTestSpecies(
    id: 'sp_green_sea_turtle',
    name: 'Green Sea Turtle',
    category: SpeciesCategory.turtle,
    builtIn: true,
  );
  await insertTestSighting(
    id: 'sg1',
    diveId: 'd1',
    speciesId: 'sp_whale_shark',
  );
  await insertTestSighting(
    id: 'sg2',
    diveId: 'd2',
    speciesId: 'sp_whale_shark',
  );
  await insertTestSighting(
    id: 'sg3',
    diveId: 'd3',
    speciesId: 'sp_whale_shark',
  );
  await insertTestSighting(
    id: 'sg4',
    diveId: 'd1',
    speciesId: 'sp_green_sea_turtle',
  );
  await insertTestMedia(
    id: 'p1',
    diveId: 'd1',
    takenAt: DateTime(2024, 1, 10, 9),
  );
  await insertTestMedia(
    id: 'p2',
    diveId: 'd1',
    takenAt: DateTime(2024, 1, 10, 10),
  );
  await insertTestMedia(
    id: 'p3',
    diveId: 'd1',
    takenAt: DateTime(2024, 1, 10, 11),
  );
  await insertTestMedia(id: 'doc1', diveId: 'd1', fileType: 'document');
  await insertTestMedia(
    id: 'p4',
    diveId: 'd2',
    takenAt: DateTime(2024, 3, 5, 9),
  );
  await insertTestMedia(
    id: 'p5',
    diveId: 'd3',
    takenAt: DateTime(2024, 5, 1, 9),
  );
  await insertTestMedia(id: 's1', siteId: 's1', takenAt: DateTime(2024, 6, 1));
}

void main() {
  late MediaSpeciesRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaSpeciesRepository();
    await seed();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getMediaForSpecies', () {
    test(
      'returns tagged photos newest first, once each, scoped to the diver',
      () async {
        await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');
        await repository.addTag(mediaId: 'p4', speciesId: 'sp_whale_shark');
        await repository.addTag(mediaId: 'p5', speciesId: 'sp_whale_shark');
        await repository.addTag(
          mediaId: 'p2',
          speciesId: 'sp_green_sea_turtle',
        );

        final mine = await repository.getMediaForSpecies(
          'sp_whale_shark',
          diverId: 'diver-a',
        );
        final everyone = await repository.getMediaForSpecies('sp_whale_shark');

        expect(mine.map((m) => m.id).toList(), ['p4', 'p1']);
        expect(everyone.map((m) => m.id).toList(), ['p5', 'p4', 'p1']);
      },
    );

    test('keeps a site-only photo under a diver scope', () async {
      await repository.addTag(mediaId: 's1', speciesId: 'sp_whale_shark');

      final mine = await repository.getMediaForSpecies(
        'sp_whale_shark',
        diverId: 'diver-a',
      );

      expect(mine.map((m) => m.id).toList(), ['s1']);
    });
  });

  group('getTagCandidatesForSpecies', () {
    test(
      'groups untagged photos by dive with the sighting, newest dive first',
      () async {
        await repository.addTag(
          mediaId: 'p1',
          speciesId: 'sp_whale_shark',
          sightingId: 'sg1',
        );

        final groups = await repository.getTagCandidatesForSpecies(
          'sp_whale_shark',
          diverId: 'diver-a',
        );

        expect(groups.map((g) => g.diveId).toList(), ['d2', 'd1']);
        final d1 = groups.last;
        expect(d1.sightingId, 'sg1');
        expect(d1.diveNumber, 101);
        expect(d1.siteName, 'Blue Hole');
        // p1 is already tagged and doc1 is a document: both excluded.
        expect(d1.items.map((m) => m.id).toSet(), {'p2', 'p3'});
        expect(groups.first.siteName, isNull);
        expect(groups.first.items.map((m) => m.id).toList(), ['p4']);
      },
    );

    test(
      "omits dives whose photos are all tagged and other divers' dives",
      () async {
        await repository.addTag(mediaId: 'p4', speciesId: 'sp_whale_shark');

        final groups = await repository.getTagCandidatesForSpecies(
          'sp_whale_shark',
          diverId: 'diver-a',
        );

        expect(groups.map((g) => g.diveId).toList(), ['d1']);
      },
    );

    test('is empty for a species never sighted', () async {
      await insertTestSpecies(id: 'c9', name: 'Nobody');
      expect(await repository.getTagCandidatesForSpecies('c9'), isEmpty);
    });
  });

  test('getTagChipsForMedia joins the species row in tag order', () async {
    await repository.addTag(mediaId: 'p1', speciesId: 'sp_green_sea_turtle');
    await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');

    final chips = await repository.getTagChipsForMedia('p1');

    expect(chips.map((c) => c.speciesId).toList(), [
      'sp_green_sea_turtle',
      'sp_whale_shark',
    ]);
    expect(chips.first.storedName, 'Green Sea Turtle');
    expect(chips.first.category, SpeciesCategory.turtle);
    expect(chips.first.isBuiltIn, isTrue);
  });

  test(
    'getPhotoCountsBySpeciesForDive counts distinct photos per species',
    () async {
      await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');
      await repository.addTag(mediaId: 'p2', speciesId: 'sp_whale_shark');
      await repository.addTag(mediaId: 'p2', speciesId: 'sp_green_sea_turtle');
      await repository.addTag(mediaId: 'p4', speciesId: 'sp_whale_shark');

      final counts = await repository.getPhotoCountsBySpeciesForDive('d1');

      expect(counts, {'sp_whale_shark': 2, 'sp_green_sea_turtle': 1});
    },
  );

  test(
    'getCoverMediaBySpecies picks the newest tagged photo per species',
    () async {
      await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');
      await repository.addTag(mediaId: 'p4', speciesId: 'sp_whale_shark');
      await repository.addTag(mediaId: 'p5', speciesId: 'sp_whale_shark');
      await repository.addTag(mediaId: 'p2', speciesId: 'sp_green_sea_turtle');

      final mine = await repository.getCoverMediaBySpecies(diverId: 'diver-a');
      final everyone = await repository.getCoverMediaBySpecies();

      expect(mine['sp_whale_shark']!.id, 'p4');
      expect(mine['sp_green_sea_turtle']!.id, 'p2');
      expect(everyone['sp_whale_shark']!.id, 'p5');
    },
  );

  test('tagCountsBySpecies counts rows per species', () async {
    await repository.addTag(mediaId: 'p1', speciesId: 'sp_whale_shark');
    await repository.addTag(mediaId: 'p2', speciesId: 'sp_whale_shark');

    expect(await repository.tagCountsBySpecies(), {'sp_whale_shark': 2});
  });
}
