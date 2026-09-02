import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_photo_fixtures.dart';

void main() {
  late MediaRepository media;
  late MediaSpeciesRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    media = MediaRepository();
    tags = MediaSpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('a tagged photo counts as carrying user metadata', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');

    expect(await media.idsWithUserMetadata(['p1', 'p2']), {'p1'});
  });

  test('watchMediaChanges ticks when a tag is written', () async {
    final ticks = <void>[];
    final sub = media.watchMediaChanges().listen(ticks.add);
    addTearDown(sub.cancel);

    await tags.addTag(mediaId: 'p2', speciesId: 'c1');
    // The stream is debounced; give it time to flush.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(ticks, isNotEmpty);
  });
}
