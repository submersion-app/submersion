import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/import_candidate.dart';
import 'package:submersion/features/media/presentation/helpers/species_photo_import_helper.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';

void main() {
  late SpeciesTaggingService service;
  late MediaSpeciesRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    tags = MediaSpeciesRepository();
    service = SpeciesTaggingService(
      tags: tags,
      media: MediaRepository(),
      species: SpeciesRepository(),
    );
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestSpecies(id: 'sp_whale_shark', name: 'Whale Shark');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'tags every imported row and folds the counts into one outcome',
    () async {
      const review = ImportReviewResult(
        linked: 2,
        skipped: 1,
        failures: {'asset-x': 'no dive'},
        importedIds: ['p1', 'p2', 'gone'],
      );

      final outcome = await SpeciesPhotoImportHelper.tagImported(
        review: review,
        service: service,
        speciesId: 'sp_whale_shark',
      );

      expect(outcome.added, 2);
      expect(outcome.skipped, 1);
      // One import failure plus one tag failure (the row that does not exist).
      expect(outcome.failed, 2);
      expect(await tags.getTagsForMedia('p1'), hasLength(1));
      expect(await tags.getTagsForMedia('p2'), hasLength(1));
    },
  );

  test('ImportReviewResult defaults to no imported ids', () {
    const review = ImportReviewResult(linked: 0, skipped: 0);
    expect(review.importedIds, isEmpty);
  });
}
