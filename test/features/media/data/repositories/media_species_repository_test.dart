import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_photo_fixtures.dart';

void main() {
  late MediaSpeciesRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaSpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'sp_whale_shark', name: 'Whale Shark');
    await insertTestSpecies(id: 'c1', name: 'My Nudibranch');
    await insertTestSighting(
      id: 'sg1',
      diveId: 'd1',
      speciesId: 'sp_whale_shark',
    );
    await insertTestMedia(id: 'm1', diveId: 'd1');
    await insertTestMedia(id: 'm2', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a photo starts with no tags', () async {
    expect(await repository.getTagsForMedia('m1'), isEmpty);
  });

  test('addTag inserts a row linked to the sighting', () async {
    final tag = await repository.addTag(
      mediaId: 'm1',
      speciesId: 'sp_whale_shark',
      sightingId: 'sg1',
    );

    expect(tag.mediaId, 'm1');
    expect(tag.speciesId, 'sp_whale_shark');
    expect(tag.sightingId, 'sg1');
    final tags = await repository.getTagsForMedia('m1');
    expect(tags.single.id, tag.id);
  });

  test('addTag is idempotent for the same photo and species', () async {
    final first = await repository.addTag(mediaId: 'm1', speciesId: 'c1');
    final second = await repository.addTag(mediaId: 'm1', speciesId: 'c1');

    expect(second.id, first.id);
    expect(await repository.getTagsForMedia('m1'), hasLength(1));
  });

  test(
    'getTagsForMediaIds groups tags by photo and skips untagged ones',
    () async {
      await repository.addTag(mediaId: 'm1', speciesId: 'sp_whale_shark');
      await repository.addTag(mediaId: 'm1', speciesId: 'c1');

      final byMedia = await repository.getTagsForMediaIds(['m1', 'm2']);

      expect(byMedia.keys, ['m1']);
      expect(byMedia['m1']!.map((t) => t.speciesId).toSet(), {
        'sp_whale_shark',
        'c1',
      });
    },
  );

  test('removeTag deletes the pair and is a no-op when absent', () async {
    await repository.addTag(mediaId: 'm1', speciesId: 'c1');

    await repository.removeTag(mediaId: 'm1', speciesId: 'c1');
    await repository.removeTag(mediaId: 'm1', speciesId: 'c1');

    expect(await repository.getTagsForMedia('m1'), isEmpty);
  });

  test('watchTagChanges ticks when a tag is written', () async {
    final ticks = <void>[];
    final sub = repository.watchTagChanges().listen(ticks.add);
    addTearDown(sub.cancel);

    await repository.addTag(mediaId: 'm2', speciesId: 'c1');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(ticks, isNotEmpty);
    // The database is what ticked, not the repository: a sync writing the
    // row directly must reach the same watchers.
    final db = DatabaseService.instance.database;
    expect(await db.select(db.mediaSpecies).get(), hasLength(1));
  });

  test('getMediaForSpecies narrows to one dive in SQL when asked', () async {
    await insertTestDive(id: 'd2', at: DateTime(2024, 2, 10));
    await insertTestMedia(id: 'm3', diveId: 'd2');
    await repository.addTag(mediaId: 'm1', speciesId: 'c1');
    await repository.addTag(mediaId: 'm3', speciesId: 'c1');

    final all = await repository.getMediaForSpecies('c1');
    final onDive = await repository.getMediaForSpecies('c1', diveId: 'd2');

    expect(all.map((m) => m.id).toSet(), {'m1', 'm3'});
    expect(onDive.map((m) => m.id).toList(), ['m3']);
  });
}
