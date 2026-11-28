import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/repositories/dive_media_batch_repository.dart';

import '../../../helpers/test_database.dart';
import '../../media/data/repositories/species_photo_fixtures.dart';

/// The media of many dives, read for counting Find species over them
/// (issue #5127).
void main() {
  late DiveMediaBatchRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveMediaBatchRepository();
    await insertTestDiver('me');
    await insertTestDiver('other');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'me');
    await insertTestDive(id: 'd2', at: DateTime(2024, 3, 2), diverId: 'me');
    await insertTestDive(id: 'd3', at: DateTime(2024, 2, 1), diverId: 'me');
    await insertTestDive(id: 'x1', at: DateTime(2024, 2, 5), diverId: 'other');
  });
  tearDown(tearDownTestDatabase);

  group('mediaForDives', () {
    test('groups each dive\'s media, oldest first', () async {
      await insertTestMedia(
        id: 'b',
        diveId: 'd1',
        takenAt: DateTime(2024, 1, 10, 11),
      );
      await insertTestMedia(
        id: 'a',
        diveId: 'd1',
        takenAt: DateTime(2024, 1, 10, 10),
      );
      await insertTestMedia(id: 'c', diveId: 'd2', fileType: 'video');

      final media = await repository.mediaForDives(['d1', 'd2', 'd3']);

      expect(media['d1']!.map((m) => m.id), ['a', 'b']);
      expect(media['d2']!.single.mediaType, MediaType.video);
      expect(media['d3'], isEmpty);
    });

    test('more dives than one statement takes', () async {
      await insertTestMedia(id: 'a', diveId: 'd1');
      final ids = ['d1', for (var i = 0; i < 1500; i++) 'none$i'];

      final media = await repository.mediaForDives(ids);

      expect(media, hasLength(1501));
      expect(media['d1']!.single.id, 'a');
    });

    test('no dives, no query', () async {
      expect(await repository.mediaForDives(const []), isEmpty);
    });
  });

  group('diveIdsWithMedia', () {
    test('the diver\'s dives with a photo or video, newest first', () async {
      await insertTestMedia(id: 'a', diveId: 'd1');
      await insertTestMedia(id: 'b', diveId: 'd1');
      await insertTestMedia(id: 'c', diveId: 'd2', fileType: 'video');
      await insertTestMedia(
        id: 's',
        diveId: 'd3',
        fileType: 'instructor_signature',
      );
      await insertTestMedia(id: 'x', diveId: 'x1');

      expect(await repository.diveIdsWithMedia(diverId: 'me'), ['d2', 'd1']);
    });

    test('without a diver, every dive with media', () async {
      await insertTestMedia(id: 'a', diveId: 'd1');
      await insertTestMedia(id: 'x', diveId: 'x1');

      expect(await repository.diveIdsWithMedia(), ['x1', 'd1']);
    });
  });
}
