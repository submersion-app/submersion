import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/repositories/species_gallery_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_gallery_fixtures.dart';

/// diver-a: dive d1 (Jan) with photos p1, p2 and video v1; diver-b: dive d2
/// with photo p3; photo p0 has no dive. Species grouper (seen on d1) and
/// snapper (seen on d2 only).
Future<void> _seed() async {
  await insertTestDiver('diver-a');
  await insertTestDiver('diver-b');
  await insertTestDive(
    id: 'd1',
    at: DateTime.utc(2024, 1, 10),
    diverId: 'diver-a',
  );
  await insertTestDive(
    id: 'd2',
    at: DateTime.utc(2024, 2, 10),
    diverId: 'diver-b',
  );
  await insertTestSpecies(id: 'grouper', name: 'Grouper');
  await insertTestSpecies(id: 'snapper', name: 'Snapper');
  await insertTestSighting(id: 's1', diveId: 'd1', speciesId: 'grouper');
  await insertTestSighting(id: 's2', diveId: 'd2', speciesId: 'snapper');
  await insertTestMedia(id: 'p0', takenAt: DateTime.utc(2024, 3, 1));
  await insertTestMedia(
    id: 'p1',
    diveId: 'd1',
    takenAt: DateTime.utc(2024, 1, 10, 9),
  );
  await insertTestMedia(
    id: 'p2',
    diveId: 'd1',
    takenAt: DateTime.utc(2024, 1, 10, 10),
  );
  await insertTestMedia(
    id: 'v1',
    diveId: 'd1',
    fileType: 'video',
    takenAt: DateTime.utc(2024, 1, 10, 11),
  );
  await insertTestMedia(
    id: 'p3',
    diveId: 'd2',
    takenAt: DateTime.utc(2024, 2, 10),
  );
}

void main() {
  late SpeciesGalleryRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesGalleryRepository();
    await _seed();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'best crop is the largest box among accepted identifications with a tag',
    () async {
      await insertTestTag(mediaId: 'p1', speciesId: 'grouper');
      await insertTestTag(mediaId: 'p2', speciesId: 'grouper');
      await insertTestIdentification(
        id: 'i1',
        mediaId: 'p1',
        speciesId: 'grouper',
        width: 300,
        height: 120,
      );
      await insertTestIdentification(
        id: 'i2',
        mediaId: 'p2',
        speciesId: 'grouper',
        width: 250,
        height: 250,
      );

      final best = await repository.bestCropBySpecies(diverId: 'diver-a');

      expect(best['grouper']!.identificationId, 'i2');
      expect(best['grouper']!.shorterSide, 250);
    },
  );

  test('a rejected or undecided identification never counts', () async {
    await insertTestTag(mediaId: 'p1', speciesId: 'grouper');
    await insertTestIdentification(
      id: 'i1',
      mediaId: 'p1',
      speciesId: 'grouper',
      decision: 'rejected',
    );
    await insertTestIdentification(
      id: 'i2',
      mediaId: 'p1',
      speciesId: 'grouper',
      decision: 'undecided',
    );

    expect(await repository.bestCropBySpecies(diverId: 'diver-a'), isEmpty);
    expect(
      await repository.cropsForSpecies('grouper', diverId: 'diver-a'),
      isEmpty,
    );
  });

  test(
    'an accepted identification whose tag was removed does not count',
    () async {
      await insertTestIdentification(
        id: 'i1',
        mediaId: 'p1',
        speciesId: 'grouper',
      );

      expect(await repository.bestCropBySpecies(diverId: 'diver-a'), isEmpty);
    },
  );

  test('20 crops on one photo give one crop for that photo', () async {
    await insertTestTag(mediaId: 'p1', speciesId: 'grouper');
    for (var i = 0; i < 20; i++) {
      await insertTestIdentification(
        id: 'school$i',
        mediaId: 'p1',
        speciesId: 'grouper',
        width: 100 + i,
        height: 400,
      );
    }

    final crops = await repository.cropsForSpecies(
      'grouper',
      diverId: 'diver-a',
    );

    expect(crops, hasLength(1));
    expect(crops.single.identificationId, 'school19');
  });

  test('crops are newest first and carry the video moment', () async {
    await insertTestTag(mediaId: 'p1', speciesId: 'grouper');
    await insertTestTag(mediaId: 'v1', speciesId: 'grouper');
    await insertTestIdentification(
      id: 'i1',
      mediaId: 'p1',
      speciesId: 'grouper',
    );
    await insertTestIdentification(
      id: 'i2',
      mediaId: 'v1',
      speciesId: 'grouper',
      bestMs: 4200,
    );

    final crops = await repository.cropsForSpecies(
      'grouper',
      diverId: 'diver-a',
    );

    expect(crops.map((c) => c.mediaId), ['v1', 'p1']);
    expect(crops.first.isVideo, isTrue);
    expect(crops.first.bestMs, 4200);
    expect(crops.last.isVideo, isFalse);
  });

  test(
    'media of another diver is excluded, media with no dive is included',
    () async {
      await insertTestTag(mediaId: 'p3', speciesId: 'grouper');
      await insertTestTag(mediaId: 'p0', speciesId: 'grouper');
      await insertTestIdentification(
        id: 'i3',
        mediaId: 'p3',
        speciesId: 'grouper',
      );
      await insertTestIdentification(
        id: 'i0',
        mediaId: 'p0',
        speciesId: 'grouper',
      );

      final crops = await repository.cropsForSpecies(
        'grouper',
        diverId: 'diver-a',
      );

      expect(crops.map((c) => c.mediaId), ['p0']);
    },
  );

  test(
    'practice pool skips unconfirmed tags and species not on the life list',
    () async {
      await insertTestTag(mediaId: 'p1', speciesId: 'grouper');
      await insertTestTag(
        mediaId: 'p2',
        speciesId: 'grouper',
        unconfirmed: true,
      );
      await insertTestTag(mediaId: 'p0', speciesId: 'snapper');
      await insertTestIdentification(
        id: 'i1',
        mediaId: 'p1',
        speciesId: 'grouper',
      );
      await insertTestIdentification(
        id: 'i2',
        mediaId: 'p2',
        speciesId: 'grouper',
      );
      await insertTestIdentification(
        id: 'i0',
        mediaId: 'p0',
        speciesId: 'snapper',
      );

      final pool = await repository.practicePool(diverId: 'diver-a');

      expect(pool.keys, ['grouper']);
      expect(pool['grouper']!.map((c) => c.identificationId), ['i1']);
    },
  );

  test('confirmed reflects the tag', () async {
    await insertTestTag(mediaId: 'p1', speciesId: 'grouper', unconfirmed: true);
    await insertTestIdentification(
      id: 'i1',
      mediaId: 'p1',
      speciesId: 'grouper',
    );

    final crops = await repository.cropsForSpecies(
      'grouper',
      diverId: 'diver-a',
    );

    expect(crops.single.confirmed, isFalse);
  });
}
