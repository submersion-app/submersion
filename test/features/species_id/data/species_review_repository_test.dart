import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/repositories/species_review_repository.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';

import '../../../helpers/test_database.dart';
import '../../media/data/repositories/species_photo_fixtures.dart';
import 'identification_fixtures.dart';

/// Gathering what Species to review shows, for a dive or the log (issue
/// #4727).
void main() {
  late SpeciesReviewRepository review;
  late MediaSpeciesRepository tags;
  late MediaIdentificationRepository identifications;

  setUp(() async {
    await setUpTestDatabase();
    tags = MediaSpeciesRepository();
    identifications = MediaIdentificationRepository();
    review = SpeciesReviewRepository(
      tags: tags,
      identifications: identifications,
      media: MediaRepository(),
      species: SpeciesRepository(),
      dives: DiveRepository(),
    );
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestDive(id: 'd2', at: DateTime(2024, 1, 11));
    await insertTestSpecies(id: 'sp_blue_tang', name: 'Blue Tang');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await insertTestMedia(id: 'q1', diveId: 'd2');
    await tags.addTag(
      mediaId: 'p1',
      speciesId: 'sp_blue_tang',
      unconfirmed: true,
    );
    await tags.addTag(
      mediaId: 'q1',
      speciesId: 'sp_blue_tang',
      unconfirmed: true,
    );
    await identifications.storeRun(
      run(mediaId: 'p2'),
      insert: [identification('i-p2', mediaId: 'p2')],
      deleteIds: const [],
    );
  });

  tearDown(tearDownTestDatabase);

  test('a dive: its unconfirmed tags and its suggestions', () async {
    final groups = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: true,
    );
    final g = groups.single;
    expect(g.diveId, 'd1');
    expect(g.tagged.single.speciesId, 'sp_blue_tang');
    expect(g.suggested.single.candidate!.scientificName, 'Scarus vetula');
  });

  test('the log: every dive with something to review', () async {
    final groups = await review.load(
      const LogReviewScope(),
      withSuggestions: true,
    );
    expect({for (final g in groups) g.diveId}, {'d1', 'd2'});
  });

  test('with the feature off, tags only', () async {
    final groups = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: false,
    );
    expect(groups.single.suggested, isEmpty);
    expect(groups.single.tagged, hasLength(1));
  });
}
