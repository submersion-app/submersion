import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';

import '../../../../helpers/test_database.dart';
import '../repositories/species_photo_fixtures.dart';

/// Moving media onto a dive takes its species tags along (issue #5122): a
/// clip identified with no dive, or on the wrong dive, records its species
/// on the dive it is moved to.
void main() {
  late AppDatabase db;
  late SpeciesRepository species;
  late MediaSpeciesRepository tags;
  late MediaRepository media;
  late SpeciesTaggingService service;
  final changeLog = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    species = SpeciesRepository();
    tags = MediaSpeciesRepository();
    media = MediaRepository();
    service = SpeciesTaggingService(tags: tags, media: media, species: species);
    await insertTestSite('s1', 'Blue Hole');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), siteId: 's1');
    await insertTestDive(id: 'd2', at: DateTime(2024, 1, 11), siteId: 's1');
    await insertTestSpecies(id: 'sp_a', name: 'Queen Parrotfish');
    await insertTestMedia(id: 'free');
    await insertTestMedia(id: 'p1', diveId: 'd1');
  });

  tearDown(tearDownTestDatabase);

  test('a hand tag on media with no dive gets the dive\'s sighting', () async {
    await service.tagPhoto(mediaId: 'free', speciesId: 'sp_a');

    await service.moveMediaToDive(['free'], 'd2');

    final sightings = await species.getSightingsForDive('d2');
    expect(sightings.map((s) => s.speciesId), ['sp_a']);
    final tag = await tags.findTag('free', 'sp_a');
    expect(tag!.sightingId, sightings.single.id);
    expect((await media.getMediaById('free'))!.diveId, 'd2');
  });

  test('a confirmed tag reuses a sighting already on the new dive', () async {
    final logged = await species.addSighting(diveId: 'd2', speciesId: 'sp_a');
    await service.tagPhoto(mediaId: 'p1', speciesId: 'sp_a');

    await service.moveMediaToDive(['p1'], 'd2');

    expect(await species.getSightingsForDive('d2'), hasLength(1));
    expect((await tags.findTag('p1', 'sp_a'))!.sightingId, logged.id);
  });

  test('the old dive keeps its sighting', () async {
    await service.tagPhoto(mediaId: 'p1', speciesId: 'sp_a');

    await service.moveMediaToDive(['p1'], 'd2');

    expect(await species.getSightingsForDive('d1'), hasLength(1));
    expect(await species.getSightingsForDive('d2'), hasLength(1));
  });

  test('an unconfirmed app tag drops its old dive\'s sighting when the new '
      'dive has none', () async {
    await service.applyAppTag(
      mediaId: 'p1',
      speciesId: 'sp_a',
      timing: SightingTiming.straightAway,
      createdSpecies: false,
    );

    await service.moveMediaToDive(['p1'], 'd2');

    final tag = await tags.findTag('p1', 'sp_a');
    expect(tag!.unconfirmed, isTrue);
    expect(tag.sightingId, isNull);
    expect(tag.createdSighting, isFalse);
    expect(await species.getSightingsForDive('d2'), isEmpty);
  });

  test(
    'confirming it after the move creates the sighting on the new dive',
    () async {
      await service.applyAppTag(
        mediaId: 'p1',
        speciesId: 'sp_a',
        timing: SightingTiming.straightAway,
        createdSpecies: false,
      );
      await service.moveMediaToDive(['p1'], 'd2');

      await service.confirmTag(mediaId: 'p1', speciesId: 'sp_a');

      final sightings = await species.getSightingsForDive('d2');
      expect(sightings, hasLength(1));
      expect(
        (await tags.findTag('p1', 'sp_a'))!.sightingId,
        sightings.single.id,
      );
    },
  );

  test('an unconfirmed app tag links a sighting the diver logged on the new '
      'dive', () async {
    final logged = await species.addSighting(diveId: 'd2', speciesId: 'sp_a');
    await service.applyAppTag(
      mediaId: 'free',
      speciesId: 'sp_a',
      timing: SightingTiming.onConfirm,
      createdSpecies: false,
    );

    await service.moveMediaToDive(['free'], 'd2');

    expect((await tags.findTag('free', 'sp_a'))!.sightingId, logged.id);
  });

  test('moving onto the dive it is on adds no second sighting', () async {
    await service.tagPhoto(mediaId: 'p1', speciesId: 'sp_a');

    await service.moveMediaToDive(['p1'], 'd1');

    expect(await species.getSightingsForDive('d1'), hasLength(1));
  });

  test(
    'a move with its tags is one History entry, labelled as a move',
    () async {
      await service.tagPhoto(mediaId: 'free', speciesId: 'sp_a');
      await changeLog.settleAll();
      await db.customStatement('DELETE FROM change_log_operations');
      await db.customStatement('DELETE FROM change_log_events');

      await service.moveMediaToDive(['free'], 'd2');

      await changeLog.settleAll();
      final rows = await db
          .customSelect('SELECT label FROM change_log_operations')
          .get();
      expect(
        [for (final row in rows) row.read<String?>('label')],
        [ChangeLogLabels.moveMedia],
      );
    },
  );
}
