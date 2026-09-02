import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';

import '../../../../helpers/test_database.dart';
import '../repositories/species_photo_fixtures.dart';

void main() {
  late SpeciesRepository species;
  late MediaSpeciesRepository tags;
  late SpeciesTaggingService service;

  setUp(() async {
    await setUpTestDatabase();
    species = SpeciesRepository();
    tags = MediaSpeciesRepository();
    service = SpeciesTaggingService(
      tags: tags,
      media: MediaRepository(),
      species: species,
    );
    await insertTestSite('s1', 'Blue Hole');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), siteId: 's1');
    await insertTestSpecies(id: 'sp_whale_shark', name: 'Whale Shark');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await insertTestMedia(id: 'site-photo', siteId: 's1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('tagging adds the missing sighting and links the tag to it', () async {
    expect(await species.getSightingsForDive('d1'), isEmpty);

    final tag = await service.tagPhoto(
      mediaId: 'p1',
      speciesId: 'sp_whale_shark',
    );

    final sightings = await species.getSightingsForDive('d1');
    expect(sightings.single.speciesId, 'sp_whale_shark');
    expect(sightings.single.count, 1);
    expect(tag.sightingId, sightings.single.id);
  });

  test('a second photo on the same dive reuses the sighting', () async {
    final first = await service.tagPhoto(
      mediaId: 'p1',
      speciesId: 'sp_whale_shark',
    );
    final second = await service.tagPhoto(
      mediaId: 'p2',
      speciesId: 'sp_whale_shark',
    );

    expect(second.sightingId, first.sightingId);
    expect(await species.getSightingsForDive('d1'), hasLength(1));
  });

  test('an existing sighting is linked, not duplicated', () async {
    final existing = await species.addSighting(
      diveId: 'd1',
      speciesId: 'sp_whale_shark',
      count: 3,
    );

    final tag = await service.tagPhoto(
      mediaId: 'p1',
      speciesId: 'sp_whale_shark',
    );

    expect(tag.sightingId, existing.id);
    expect((await species.getSightingsForDive('d1')).single.count, 3);
  });

  test('a site-only photo is tagged without a sighting', () async {
    final tag = await service.tagPhoto(
      mediaId: 'site-photo',
      speciesId: 'sp_whale_shark',
    );

    expect(tag.sightingId, isNull);
    expect(await species.getSightingsForDive('d1'), isEmpty);
  });

  test('untagging keeps the sighting', () async {
    await service.tagPhoto(mediaId: 'p1', speciesId: 'sp_whale_shark');

    await service.untagPhoto(mediaId: 'p1', speciesId: 'sp_whale_shark');

    expect(await tags.getTagsForMedia('p1'), isEmpty);
    expect(await species.getSightingsForDive('d1'), hasLength(1));
  });

  test('tagPhotos tags what it can and reports the rest', () async {
    final result = await service.tagPhotos(
      mediaIds: ['p1', 'missing', 'p2'],
      speciesId: 'sp_whale_shark',
    );

    expect(result.tagged, 2);
    expect(result.failures.keys, ['missing']);
    expect(await tags.getTagsForMedia('p1'), hasLength(1));
    expect(await tags.getTagsForMedia('p2'), hasLength(1));
  });
}
