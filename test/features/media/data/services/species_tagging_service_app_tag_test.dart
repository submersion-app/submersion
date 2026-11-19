import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';

import '../../../../helpers/test_database.dart';
import '../repositories/species_photo_fixtures.dart';

/// Tags the app applies, and what confirming or rejecting one does to the
/// dive's sightings and the diver's species (issue #4727).
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
    await insertTestSpecies(id: 'sp_a', name: 'Queen Parrotfish');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await insertTestMedia(id: 'site-photo', siteId: 's1');
  });

  tearDown(tearDownTestDatabase);

  group('applyAppTag', () {
    test('when I confirm, with no sighting, tags without one', () async {
      final tag = await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.onConfirm,
        createdSpecies: false,
      );

      expect(tag.unconfirmed, isTrue);
      expect(tag.sightingId, isNull);
      expect(await species.getSightingsForDive('d1'), isEmpty);
    });

    test('when I confirm, links a sighting the diver logged', () async {
      final logged = await species.addSighting(diveId: 'd1', speciesId: 'sp_a');

      final tag = await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.onConfirm,
        createdSpecies: false,
      );

      expect(tag.sightingId, logged.id);
      expect(tag.createdSighting, isFalse);
      expect(await species.getSightingsForDive('d1'), hasLength(1));
    });

    test('straight away creates the sighting and says so', () async {
      final tag = await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );

      final sightings = await species.getSightingsForDive('d1');
      expect(tag.sightingId, sightings.single.id);
      expect(tag.createdSighting, isTrue);
    });

    test('a second photo straight away links and did not create', () async {
      final first = await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );
      final second = await service.applyAppTag(
        mediaId: 'p2',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );

      expect(second.sightingId, first.sightingId);
      expect(second.createdSighting, isFalse);
    });

    test('a site photo gets no sighting', () async {
      final tag = await service.applyAppTag(
        mediaId: 'site-photo',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );

      expect(tag.sightingId, isNull);
      expect(tag.createdSighting, isFalse);
    });

    test('an existing tag is left as it is', () async {
      final hand = await service.tagPhoto(mediaId: 'p1', speciesId: 'sp_a');

      final again = await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.onConfirm,
        createdSpecies: false,
      );

      expect(again.id, hand.id);
      expect(again.unconfirmed, isFalse);
    });
  });

  group('tagPhoto', () {
    test('a hand tag over the app\'s tag confirms it and logs the '
        'sighting', () async {
      await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.onConfirm,
        createdSpecies: false,
      );

      final tag = await service.tagPhoto(mediaId: 'p1', speciesId: 'sp_a');

      expect(tag.unconfirmed, isFalse);
      expect((await tags.findTag('p1', 'sp_a'))!.unconfirmed, isFalse);
      expect(await species.getSightingsForDive('d1'), hasLength(1));
    });
  });

  group('confirmTag', () {
    test('logs the sighting and clears the marks', () async {
      await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.onConfirm,
        createdSpecies: true,
      );

      await service.confirmTag(mediaId: 'p1', speciesId: 'sp_a');

      final tag = await tags.findTag('p1', 'sp_a');
      final sightings = await species.getSightingsForDive('d1');
      expect(tag!.unconfirmed, isFalse);
      expect(tag.createdSpecies, isFalse);
      expect(tag.sightingId, sightings.single.id);
    });
  });

  group('rejectTag', () {
    test('takes a created sighting and species nothing else uses', () async {
      final own = await species.createSpecies(
        commonName: 'Creole Wrasse',
        scientificName: 'Clepticus parrae',
        category: SpeciesCategory.fish,
      );
      await service.applyAppTag(
        mediaId: 'p1',
        speciesId: own.id,
        timing: SightingTiming.straightAway,
        createdSpecies: true,
      );

      await service.rejectTag(mediaId: 'p1', speciesId: own.id);

      expect(await tags.findTag('p1', own.id), isNull);
      expect(await species.getSightingsForDive('d1'), isEmpty);
      expect(await species.getSpeciesById(own.id), isNull);
    });

    test('takes the sighting it created even after the photo moved to '
        'another dive', () async {
      await insertTestDive(id: 'd2', at: DateTime(2024, 1, 11));
      await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );
      await MediaRepository().reassignMediaToDive(['p1'], 'd2');

      await service.rejectTag(mediaId: 'p1', speciesId: 'sp_a');

      expect(await species.getSightingsForDive('d1'), isEmpty);
    });

    test('keeps the sighting while another tag points at it', () async {
      await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );
      await service.applyAppTag(
        mediaId: 'p2',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );

      await service.rejectTag(mediaId: 'p1', speciesId: 'sp_a');

      expect(await species.getSightingsForDive('d1'), hasLength(1));
    });

    test('keeps a sighting the diver changed', () async {
      final tag = await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );
      final sighting = (await species.getSightingsForDive('d1')).single;
      await species.updateSighting(
        sighting.copyWith(abundance: SightingAbundance.exact, count: 4),
      );

      await service.rejectTag(mediaId: 'p1', speciesId: 'sp_a');

      expect(await tags.findTag('p1', 'sp_a'), isNull);
      expect(
        (await species.getSightingsForDive('d1')).single.id,
        tag.sightingId,
      );
    });

    test('keeps a species the diver edited after the tag', () async {
      final own = await species.createSpecies(
        commonName: 'Creole Wrasse',
        scientificName: 'Clepticus parrae',
        category: SpeciesCategory.fish,
      );
      await service.applyAppTag(
        mediaId: 'p1',
        speciesId: own.id,
        timing: SightingTiming.onConfirm,
        createdSpecies: true,
      );
      await species.updateSpecies(own.copyWith(description: 'Blue school'));

      await service.rejectTag(mediaId: 'p1', speciesId: own.id);

      expect(await species.getSpeciesById(own.id), isNotNull);
    });

    test('a confirmed tag never takes its sighting', () async {
      await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );
      await service.confirmTag(mediaId: 'p1', speciesId: 'sp_a');

      await service.rejectTag(mediaId: 'p1', speciesId: 'sp_a');

      expect(await tags.findTag('p1', 'sp_a'), isNull);
      expect(await species.getSightingsForDive('d1'), hasLength(1));
    });
  });

  group('several app tags share what one created', () {
    late String own;

    setUp(() async {
      own = (await species.createSpecies(
        commonName: 'Creole Wrasse',
        scientificName: 'Clepticus parrae',
        category: SpeciesCategory.fish,
      )).id;
      for (final (mediaId, created) in [('p1', true), ('p2', false)]) {
        await service.applyAppTag(
          mediaId: mediaId,
          speciesId: own,
          timing: SightingTiming.straightAway,
          createdSpecies: created,
        );
      }
    });

    for (final order in [
      ['p1', 'p2'],
      ['p2', 'p1'],
    ]) {
      test('removing them all (${order.join(' then ')}) takes the sighting '
          'and the species', () async {
        for (final mediaId in order) {
          await service.rejectTag(mediaId: mediaId, speciesId: own);
        }
        expect(await species.getSightingsForDive('d1'), isEmpty);
        expect(await species.getSpeciesById(own), isNull);
      });
    }

    test('a confirmed tag left behind keeps both, and takes no mark', () async {
      await service.confirmTag(mediaId: 'p2', speciesId: own);

      await service.rejectTag(mediaId: 'p1', speciesId: own);

      expect(await species.getSightingsForDive('d1'), hasLength(1));
      expect(await species.getSpeciesById(own), isNotNull);
      final kept = await tags.findTag('p2', own);
      expect(kept!.createdSighting, isFalse);
      expect(kept.createdSpecies, isFalse);
    });

    test('removing the creating tag hands its marks on', () async {
      await service.rejectTag(mediaId: 'p1', speciesId: own);

      final left = await tags.findTag('p2', own);
      expect(left!.createdSighting, isTrue);
      expect(left.createdSpecies, isTrue);
    });
  });
}
