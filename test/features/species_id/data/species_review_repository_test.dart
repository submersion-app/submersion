import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/repositories/species_review_repository.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';

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
    await insertTestDiver('me');
    await insertTestDiver('other');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'me');
    await insertTestDive(id: 'd2', at: DateTime(2024, 1, 11), diverId: 'me');
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

  test('the log is the active diver\'s: another diver\'s dives are left out, '
      'site photos kept', () async {
    await insertTestSite('s1', 'Blue Hole');
    await insertTestDive(id: 'd3', at: DateTime(2024, 1, 12), diverId: 'other');
    await insertTestMedia(id: 'r1', diveId: 'd3');
    await insertTestMedia(id: 'site1', siteId: 's1');
    for (final id in ['r1', 'site1']) {
      await tags.addTag(
        mediaId: id,
        speciesId: 'sp_blue_tang',
        unconfirmed: true,
      );
    }

    final groups = await review.load(
      const LogReviewScope(),
      withSuggestions: true,
      diverId: 'me',
    );

    expect(
      {for (final g in groups) g.diveId ?? g.kind.name},
      {'d1', 'd2', 'sitePhotos'},
    );
  });

  test('a looser naming level suggests a crop below the pack\'s bar', () async {
    await insertTestMedia(id: 'p3', diveId: 'd1');
    await identifications.storeRun(
      run(mediaId: 'p3'),
      insert: [
        identification('i-p3', mediaId: 'p3').copyWith(suggestable: false),
      ],
      deleteIds: const [],
    );
    const level = LevelInForce(
      level: NamingLevel.eager,
      packVersion: '2026.11.1',
      minCropSide: 64,
      minOpenScore: 0.1,
      suggestScore: 0.3,
      suggestScoreNoLocation: 0.3,
    );

    final stored = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: true,
    );
    final loose = await review.load(
      const DiveReviewScope('d1'),
      withSuggestions: true,
      level: level,
    );

    int suggested(List<ReviewGroup> g) =>
        g.single.suggested.fold(0, (n, r) => n + r.items.length);
    expect(suggested(loose), suggested(stored) + 1);
  });
}
